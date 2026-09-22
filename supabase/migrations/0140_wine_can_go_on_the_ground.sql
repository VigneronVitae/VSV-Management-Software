-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A way to record wine leaving a vessel and going nowhere, because
--           until now the only way out of a vessel was into another one and a
--           dumped barrel had to be lied about or left full."
-- Depends on: [supabase/migrations/0014_rack.sql,
--              supabase/migrations/0013_close_on_empty.sql,
--              supabase/migrations/0057_the_contract.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts,
--                  supabase/migrations/0142_a_dump_says_why.sql]
-- Axioms enforced: T0-5. A dump is an append: a placement closes, a quantity
--                  shrinks, an event says so. Nothing is deleted and the lot's
--                  history keeps the wine that used to be there.
--                  A13. Dumping more than a vessel holds is refused in a
--                  sentence rather than silently clamped, because a clamp would
--                  make a typo look like a successful dump.
-- Open sorries: none new. See the note on reasons at the end.
-- ---------------------------------------------------------------------------

-- "The existing one needs a way to rack to the ground or dump or whatever, which
-- we also need for being able to dump barrels."
--
-- `rack` refuses this outright and says so: "a rack needs somewhere to go". That
-- refusal is right. A rack moves wine and computes a loss as the difference
-- between what left and what arrived, and a rack with no destination would make
-- the entire volume a loss, which is arithmetically true and a lie about what
-- happened. Losing four litres in a hose and pouring two hundred down the drain
-- are different facts and a cellar needs to tell them apart afterwards.
--
-- So this is its own verb. What it does is the same drain `rack` performs on its
-- sources, without the half that fills anything:
--
--   * the placement closes if the dump empties the vessel, or shrinks if not,
--     which is exactly what `rack` does and is copied deliberately rather than
--     factored out, because factoring it out would put a shared function between
--     two callers with different rules about what happens next;
--   * the lot's quantity shrinks by what went, and `0013` closes the lot if that
--     takes it to nothing, which is that migration's rule and not this one's;
--   * an event records it, one per lot, with the volume and the reason.
--
-- **The wine stays in the history.** Nothing is deleted. A dumped lot still has
-- its picks, its pressings and its lineage, and `harvest_so_far` stops counting
-- it because the placement closed rather than because anything was erased.

insert into term (kind, value, label, sort_order) values
  ('operation', 'dump', 'Dump', 710)
on conflict (kind, value) do update set label = excluded.label, active = true;

create or replace function dump_wine(
  p_sources jsonb,
  p_reason  text        default null,
  p_at      timestamptz default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  src      jsonb;
  v_id     uuid;
  v_name   text;
  vol      numeric;
  held     numeric;
  n_id     uuid;
  total    numeric := 0;
  touched  uuid[] := '{}';
  n        uuid;
  made     uuid;
  events   jsonb := '[]'::jsonb;
begin
  if not is_facility_user() then
    raise exception 'wine is dumped by people who work here';
  end if;
  if p_sources is null or jsonb_array_length(p_sources) = 0 then
    raise exception 'a dump needs somewhere to come from';
  end if;

  -- Checked in full before anything is drained, so a bad second entry does not
  -- leave the first vessel already emptied.
  for src in select value from jsonb_array_elements(p_sources)
  loop
    v_id := (src ->> 'vessel_id')::uuid;
    vol  := (src ->> 'volume_l')::numeric;

    select v.name into v_name from vessel v where v.id = v_id;
    if v_name is null then
      raise exception 'no vessel with id %', v_id;
    end if;
    if vol is null or vol <= 0 then
      raise exception 'how much came out of % is not recorded', v_name;
    end if;

    select p.volume_l, p.node_id into held, n_id
      from placement p where p.vessel_id = v_id and p.to_at is null;
    if held is null then
      raise exception '% is empty, so nothing can be dumped out of it', v_name;
    end if;
    -- Refused rather than clamped. A clamp would turn a typo into a dump that
    -- looks like it worked, which is the shape A13 is about.
    if vol - held > 0.0001 then
      raise exception '% holds % L and this pours % L out of it', v_name, held, vol;
    end if;
  end loop;

  for src in select value from jsonb_array_elements(p_sources)
  loop
    v_id := (src ->> 'vessel_id')::uuid;
    vol  := (src ->> 'volume_l')::numeric;

    select p.volume_l, p.node_id into held, n_id
      from placement p where p.vessel_id = v_id and p.to_at is null;

    if held - vol <= 0.0001 then
      update placement set to_at = coalesce(p_at, now())
       where vessel_id = v_id and to_at is null;
    else
      update placement set volume_l = held - vol
       where vessel_id = v_id and to_at is null;
    end if;

    -- Always, unlike a rack, where the quantity only moves on a blend because
    -- the wine became a child lot. Here there is no child: it is gone.
    update node set quantity = greatest(coalesce(quantity, 0) - vol, 0)
     where id = n_id and quantity is not null;

    total := total + vol;
    if not (n_id = any(touched)) then
      touched := touched || n_id;
    end if;
  end loop;

  -- One event per lot rather than per vessel, because "we dumped that barrel" is
  -- one thing that happened even when it took four barrels.
  foreach n in array touched
  loop
    insert into event (subject_type, subject_id, operation_id, at, by_user, data, provenance)
    values ('node', n, term_id('operation', 'dump'), coalesce(p_at, now()), auth.uid(),
            jsonb_build_object(
              'volume_l', (select sum((s ->> 'volume_l')::numeric)
                             from jsonb_array_elements(p_sources) s
                             join placement p on p.vessel_id = (s ->> 'vessel_id')::uuid
                            where p.node_id = n),
              'reason', p_reason,
              'vessels', (select jsonb_agg(s -> 'vessel_id')
                            from jsonb_array_elements(p_sources) s)),
            'observed')
    returning id into made;
    events := events || jsonb_build_array(jsonb_build_object('node_id', n, 'event_id', made));
  end loop;

  return jsonb_build_object('dumped_l', total, 'lots', events);
end $$;

comment on function dump_wine is
  'Records wine leaving a vessel and going nowhere. The placement closes, the '
  'lot shrinks, and 0013 closes the lot if that empties it.';

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('cellar.dump_wine', 'cellar', 'Dump it',
   'Records wine poured away rather than moved: a barrel that went off, lees, the last of a tank. The lot keeps its history and stops being anywhere.',
   'dump_wine',
   '[{"key": "sources", "type": "jsonb", "label": "Out of which vessels, and how much", "param": "p_sources", "required": true,
      "hint": "A list of vessel_id and volume_l, the same shape a rack takes."},
     {"key": "reason", "type": "text", "label": "Why", "param": "p_reason", "required": false},
     {"key": "at", "type": "timestamptz", "label": "When", "param": "p_at", "required": false,
      "hint": "Blank means now."}]'::jsonb,
   120)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

-- **Why the reason is free text.** Wine gets dumped for volatile acidity, for
-- brett, for a stuck ferment nobody could restart, for being the last inch over
-- the lees, and for having been left in a hot shed. Which of those this cellar
-- would want to count separately is a winemaking question nobody has been asked,
-- and a vocabulary guessed at now would be four wrong words people work around.
-- AR-E5 means it becomes a vocabulary the day he says what the words are, and
-- the free text in the meantime is what tells us.

do $$
declare
  v uuid; n uuid; vol numeric; before_l numeric; after_l numeric;
begin
  select p.vessel_id, p.node_id, p.volume_l into v, n, vol
    from placement p where p.to_at is null and p.volume_l > 1 limit 1;
  if v is null then
    return;  -- nothing in the cellar to prove it against, which is the from-empty case
  end if;

  -- The guard that matters most, because clamping instead of refusing would make
  -- a typo indistinguishable from a dump that worked.
  begin
    perform dump_wine(jsonb_build_array(
      jsonb_build_object('vessel_id', v, 'volume_l', vol + 1000)));
    raise exception 'dumping more than a vessel holds was accepted';
  exception when others then
    if sqlerrm not like '%pours%' and sqlerrm not like '%people who work here%' then
      raise;
    end if;
  end;
end $$;
