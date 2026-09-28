-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A cut drawn into a tank that already holds wine leaves that wine's
--           sources adding to one whole, whoever drew it."
-- Depends on: [supabase/migrations/0102_a_tank_takes_more_than_one_pressing.sql,
--              supabase/migrations/0155_doctor.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: A13. The rescale failed silently for a cellar hand; it now
--                  happens, or the draw is refused.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- Found by `doctor` on its first run against practice: two pressings off
-- skins whose tanks' lots came from their sources in shares adding to 1.18 and
-- 1.2. scripts/smoke.ts draws the free run and the 2nd free run into one tank,
-- as a cellar hand. `draw_cut` (0102) blends the second into the first: it
-- scales the shares already there by what was held over what is now there and
-- adds the arriving cut's. The scaling is an UPDATE on `lineage`, and only an
-- administrator may update lineage, so for anybody else row level security
-- filtered it to nothing without a word. The new share was inserted, the old
-- ones stayed whole, and every composition read from that tank would have
-- over-counted the first cut. The cellar's own pressings were all drawn by an
-- administrator, and doctor finds nothing wrong there.
--
-- **Not `draw_cut` as its definer.** That would fix this and also let it see,
-- and blend into, a client's lot the person drawing may not see. So the one
-- step that needs the right moves into a helper that has it and does only
-- that: scale a lot's shares for what arrived and add the arriving cut's. It
-- keeps a whole a whole whatever it is called with, it refuses anybody who
-- does not work here, and it refuses anything but a press cut going into a lot
-- that is in a vessel.

create or replace function blend_cut_shares(
  p_resident uuid,
  p_cut      uuid,
  p_volume_l numeric,
  p_held_l   numeric
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  new_total numeric;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here draws juice into a tank'
      using errcode = 'insufficient_privilege';
  end if;
  if p_volume_l is null or p_volume_l <= 0 or p_held_l is null or p_held_l < 0 then
    raise exception 'a blend needs what arrived and what was already there';
  end if;
  if not exists (select 1 from lineage l join node ld on ld.id = l.parent_id
                  where l.child_id = p_cut and ld.stage = 'load') then
    raise exception 'only a cut off a press blends into a tank this way';
  end if;
  if not exists (select 1 from placement where node_id = p_resident and to_at is null) then
    raise exception 'that lot is not in a vessel, so nothing can be drawn into it';
  end if;

  new_total := p_held_l + p_volume_l;

  -- Every parent's share is what it contributed over what is now there. The
  -- existing parents kept `held` between them, so they keep held/new_total of
  -- what they had, and the arriving cut takes the rest. Clamped the way 0014
  -- clamps, because the constraint is fraction > 0.
  update lineage
     set fraction = greatest(least(fraction * p_held_l / new_total, 1), 0.00001)
   where child_id = p_resident;

  -- The cut may already be a parent, from an earlier draw into this same tank,
  -- in which case its share grows rather than being written twice.
  insert into lineage (parent_id, child_id, fraction)
  values (p_cut, p_resident, greatest(least(p_volume_l / new_total, 1), 0.00001))
  on conflict (parent_id, child_id) do update
    set fraction = least(lineage.fraction + excluded.fraction, 1);
end $$;

comment on function blend_cut_shares is
  'Rescales a tank''s lot''s shares when a press cut is drawn into it. Called by draw_cut; '
  'runs as its definer because only administrators may change lineage directly.';

revoke all on function blend_cut_shares(uuid, uuid, numeric, numeric) from public;
grant execute on function blend_cut_shares(uuid, uuid, numeric, numeric) to authenticated;

insert into capability_exemption (fn, reason) values
  ('blend_cut_shares', 'The share arithmetic inside draw_cut, which needs a right a cellar hand does not have. Not a verb of its own.')
on conflict (fn) do update set reason = excluded.reason;

CREATE OR REPLACE FUNCTION public.draw_cut(p_load_id uuid, p_vessel_id uuid, p_volume_l numeric, p_cut_id uuid DEFAULT NULL::uuid, p_name text DEFAULT NULL::text, p_note text DEFAULT NULL::text, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  load_n    node%rowtype;
  cut_id    uuid;
  cut_n     node%rowtype;
  cut_stage node_stage;
  cut_label text;
  ev_id     uuid := gen_random_uuid();
  total     numeric;
  in_vessel numeric;
  cap       numeric;
  -- 0102. The lot already standing in the destination, if there is one.
  resident  uuid;
  held      numeric;
  new_total numeric;
  res_name  text;
  res_var   uuid;
  cut_var   uuid;
  blended   boolean := false;
begin
  perform happening_at(p_at);
  select * into load_n from node where id = p_load_id;
  if load_n.id is null then
    raise exception 'no load with id %', p_load_id;
  end if;
  if load_n.stage <> 'load' then
    raise exception 'that lot is not in a press, so nothing is being drawn off it';
  end if;
  if load_n.status = 'closed' then
    raise exception 'that press is finished; record a correction against it rather than drawing more';
  end if;
  if p_volume_l is null or p_volume_l <= 0 then
    raise exception 'a draw of % litres is not a volume',
      coalesce(p_volume_l::text, 'nothing');
  end if;
  if not exists (select 1 from vessel where id = p_vessel_id and active) then
    raise exception 'that vessel is not one juice can go into';
  end if;

  if p_cut_id is not null and not exists (
    select 1 from term where id = p_cut_id and kind = 'press_cut' and active) then
    raise exception 'that is not a press cut';
  end if;

  cut_stage := coalesce((load_n.attributes ->> 'cut_stage')::node_stage, 'ferment');
  cut_label := coalesce(
    nullif(btrim(coalesce(p_name, '')), ''),
    (select t.label from term t where t.id = p_cut_id),
    'Pressed');

  -- The same cut drawn again is the same lot getting bigger, not a second one.
  select n.* into cut_n
    from node n
    join lineage l on l.child_id = n.id and l.parent_id = p_load_id
   where n.status <> 'closed'
     and ((p_cut_id is not null and (n.attributes ->> 'cut')::uuid = p_cut_id)
       or (p_cut_id is null and n.attributes -> 'cut' is null
           and n.name = load_n.name || ' ' || cut_label))
   limit 1;

  if cut_n.id is null then
    cut_id := gen_random_uuid();
    insert into node
      (id, stage, status, name, quantity, unit, variety_id, vintage, non_vintage,
       product_type_id, owner_id, created_by, attributes)
    values
      (cut_id, cut_stage, 'open',
       load_n.name || ' ' || cut_label,
       0, 'L',
       load_n.variety_id, load_n.vintage, load_n.non_vintage,
       load_n.product_type_id, load_n.owner_id, auth.uid(),
       jsonb_strip_nulls(jsonb_build_object(
         'cut',       p_cut_id,
         'cut_label', cut_label)));
    insert into lineage (parent_id, child_id, fraction) values (p_load_id, cut_id, 1);
  else
    cut_id := cut_n.id;
  end if;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'press'), 'node', cut_id, auth.uid(), 'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'action',    'drawn',
       'load',      p_load_id,
       'vessel',    p_vessel_id,
       'volume_l',  p_volume_l,
       'cut',       p_cut_id,
       'note',      nullif(btrim(coalesce(p_note, '')), ''))));

  select coalesce(sum((e.data ->> 'volume_l')::numeric), 0) into total
    from event e
   where e.subject_type = 'node' and e.subject_id = cut_id
     and e.operation_id = term_id('operation', 'press')
     and e.data ->> 'action' = 'drawn'
     and not exists (
       select 1 from event s
        where s.subject_type = 'node' and s.subject_id = cut_id
          and (s.data ->> 'supersedes')::uuid = e.id);

  update node set quantity = total, unit = 'L' where id = cut_id;

  select coalesce(sum((e.data ->> 'volume_l')::numeric), 0) into in_vessel
    from event e
   where e.subject_type = 'node' and e.subject_id = cut_id
     and e.operation_id = term_id('operation', 'press')
     and e.data ->> 'action' = 'drawn'
     and (e.data ->> 'vessel')::uuid = p_vessel_id;

  if exists (select 1 from placement
              where node_id = cut_id and vessel_id = p_vessel_id and to_at is null) then
    update placement set volume_l = in_vessel
     where node_id = cut_id and vessel_id = p_vessel_id and to_at is null;
  else
    select p.node_id, p.volume_l, n.name, n.variety_id
      into resident, held, res_name, res_var
      from placement p join node n on n.id = p.node_id
     where p.vessel_id = p_vessel_id and p.to_at is null;

    if resident is null then
      insert into placement (node_id, vessel_id, volume_l)
      values (cut_id, p_vessel_id, in_vessel);

    else
      -- **The blend.** 0014's rule, now in the place a press needs it.
      blended   := true;
      held      := coalesce(held, 0);
      new_total := held + p_volume_l;

      -- 0156. The shares, through a helper that may change lineage, which a
      -- cellar hand may not. Written here directly, as 0102 did, the rescale
      -- of the parents already there was filtered out by row level security
      -- for anybody but an administrator, silently, and the tank's lot came
      -- from its sources in shares adding to more than one.
      perform blend_cut_shares(resident, cut_id, p_volume_l, held);

      update placement set volume_l = new_total
       where vessel_id = p_vessel_id and to_at is null;
      update node set quantity = new_total, unit = 'L' where id = resident;

      -- The tank's own lot says what arrived in it. Without this the history of
      -- the wine in the tank is only readable from the other lot's events,
      -- which is the wrong way round: somebody looking at the tank is looking
      -- at this lot.
      insert into event
        (id, operation_id, subject_type, subject_id, by_user, provenance, data)
      values
        (gen_random_uuid(), term_id('operation', 'press'), 'node', resident,
         auth.uid(), 'observed',
         jsonb_build_object(
           'action',    'received',
           'from_cut',  cut_id,
           'load',      p_load_id,
           'vessel',    p_vessel_id,
           'volume_l',  p_volume_l,
           'drawn_by',  ev_id));

      -- So the screen can say it while the person is still at the press. Told,
      -- not refused: his ruling for barrels, for the same reason.
      cut_var := coalesce(cut_n.variety_id, load_n.variety_id);

      -- What is in the tank now, so over_capacity below reads the tank rather
      -- than this one cut.
      in_vessel := new_total;

    end if;
  end if;

  select capacity_l into cap from vessel where id = p_vessel_id;

  perform resume_at(was_at);
  return jsonb_build_object(
    'cut_id',     cut_id,
    'event_id',   ev_id,
    'cut',        cut_label,
    'volume_l',   p_volume_l,
    'cut_total',  total,
    'in_vessel',  in_vessel,
    'over_capacity', cap is not null and in_vessel > cap,
    -- 0102. Null when the tank was empty, which is the ordinary case.
    'blended_into', case when blended then res_name else null end,
    'variety_differs',
      blended and cut_var is not null and res_var is not null and cut_var <> res_var,
    -- 0151. What this press has given is what was drawn off it. Summing its
    -- cuts' quantities counted a cut twice once it had gone into a tank
    -- holding another of the same press's cuts.
    'load_total', (select coalesce(sum((d.data ->> 'volume_l')::numeric), 0)
                     from event d
                    where d.operation_id = term_id('operation', 'press')
                      and d.data ->> 'action' = 'drawn'
                      and d.data ->> 'load' = p_load_id::text
                      and not exists (select 1 from event s
                                       where (s.data ->> 'supersedes')::uuid = d.id))
  );
end;
$function$;
