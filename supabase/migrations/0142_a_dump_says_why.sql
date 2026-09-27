-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The two answers 0139 and 0140 were waiting on: why wine gets dumped
--           becomes a short list, and the bulldog joins gravity and pump as a way
--           wine is moved."
-- Depends on: [supabase/migrations/0139_a_gas_is_a_term.sql,
--              supabase/migrations/0140_wine_can_go_on_the_ground.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts,
--                  supabase/migrations/0150_off_the_skins.sql]
-- Axioms enforced: AR-E5. Both are registry rows, so a third reason or a fourth
--                  method is an insert and not a migration.
--                  A13. A reason that is not on the list is refused in a
--                  sentence naming the ones that are, rather than stored as a
--                  word nothing will ever group with.
--                  T0-5. Dumps already recorded keep the free text they were
--                  written with. Nothing here rewrites an event.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- 0140 left the reason free text and said why: it was a winemaking question
-- nobody had been asked. Asked, the answer was "loss, flaw maybe?", and for
-- moving wine: "gravity/pump/bulldog (turns a barrel into a keg so it's inert gas
-- pushing the liquid out)".

-- ---------------------------------------------------------------------------
-- Why it was dumped
-- ---------------------------------------------------------------------------

insert into term_kind (kind, label, module, sort_order) values
  ('dump_reason', 'Why it was dumped', 'winemaking', 132)
on conflict (kind) do update set
  label = excluded.label, module = excluded.module, sort_order = excluded.sort_order;

-- Two, which is what he said, and the "maybe" is why there are not four. Loss is
-- wine that went somewhere nobody meant it to: a leak, a spill, a split hose.
-- Flaw is wine that was dumped on purpose because it had gone wrong. Which flaw
-- is the note's job, because volatile acidity and brett are diagnoses and the
-- list is for counting.
insert into term (kind, value, label, sort_order) values
  ('dump_reason', 'loss', 'Loss', 100),
  ('dump_reason', 'flaw', 'Flaw', 200)
on conflict (kind, value) do update set
  label = excluded.label, sort_order = excluded.sort_order, active = true;

-- ---------------------------------------------------------------------------
-- The third way wine moves
-- ---------------------------------------------------------------------------

-- 0139 said "a push under gas is arguably a third and arguably a pump; nobody
-- has been asked". It is a third. A bulldog bung turns a barrel into a keg and
-- inert gas pushes the wine out, which matters to the record for the same reason
-- the gas fields do: no pump, and the headspace behind the wine is argon or
-- nitrogen rather than air. The label says what it is, because the word is
-- cellar slang and the next person reading a rack log may not know it.
insert into term (kind, value, label, sort_order) values
  ('rack_method', 'bulldog', 'Bulldog (gas push)', 300)
on conflict (kind, value) do update set
  label = excluded.label, sort_order = excluded.sort_order, active = true;

-- ---------------------------------------------------------------------------
-- dump_wine checks the reason and takes a note
-- ---------------------------------------------------------------------------

-- A new parameter overloads rather than replaces, so the three-argument version
-- goes first. Leaving it would give PostgREST two functions called dump_wine and
-- a periphery no way to say which it meant.
drop function if exists dump_wine(jsonb, text, timestamptz);

create or replace function dump_wine(
  p_sources jsonb,
  p_reason  text        default null,
  p_at      timestamptz default null,
  p_note    text        default null
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

  -- The reason is still optional here, because the kernel has no business
  -- refusing a record for being terse. When one is given it has to be on the
  -- list, because the list is the only reason to have one.
  if p_reason is not null and not exists (
       select 1 from term where kind = 'dump_reason' and value = p_reason and active) then
    raise exception '"%" is not a reason for dumping on the list, which is: %', p_reason,
      (select string_agg(value, ', ' order by sort_order)
         from term where kind = 'dump_reason' and active);
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
              'note', p_note,
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
  'lot shrinks, and 0013 closes the lot if that empties it. The reason is a '
  'dump_reason term; the note says the rest.';

grant execute on function dump_wine(jsonb, text, timestamptz, text) to authenticated;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('cellar.dump_wine', 'cellar', 'Dump it',
   'Records wine poured away rather than moved: a barrel that went off, a leak, the last of a tank. The lot keeps its history and stops being anywhere.',
   'dump_wine',
   '[{"key": "sources", "type": "jsonb", "label": "Out of which vessels, and how much", "param": "p_sources", "required": true,
      "hint": "A list of vessel_id and volume_l, the same shape a rack takes."},
     {"key": "reason", "type": "text", "label": "Why", "param": "p_reason", "required": false,
      "hint": "A dump_reason value: loss or flaw."},
     {"key": "at", "type": "timestamptz", "label": "When", "param": "p_at", "required": false,
      "hint": "Blank means now."},
     {"key": "note", "type": "text", "label": "What happened", "param": "p_note", "required": false,
      "hint": "Which flaw, or where it leaked. The list is for counting and this is for reading."}]'::jsonb,
   120)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

do $$
begin
  if (select count(*) from term where kind = 'dump_reason' and active) < 2 then
    raise exception 'the dump reasons are short of the two he named';
  end if;
  if not exists (select 1 from term where kind = 'rack_method' and value = 'bulldog' and active) then
    raise exception 'the bulldog is not a way wine moves';
  end if;
  -- One dump_wine, not two. The overload is the failure this migration's drop
  -- exists to prevent, and it would not show up until a periphery called it.
  if (select count(*) from pg_proc where proname = 'dump_wine'
        and pronamespace = 'public'::regnamespace) <> 1 then
    raise exception 'there is more than one dump_wine, so a caller cannot say which it means';
  end if;
end $$;
