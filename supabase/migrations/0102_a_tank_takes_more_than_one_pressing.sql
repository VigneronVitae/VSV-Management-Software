-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Drawing a cut into a tank that already holds wine is a blend, not an
--           error. The tank keeps its lot, the lot grows, and every pressing
--           that fed it is in its lineage."
-- Depends on: [supabase/migrations/0014_rack.sql,
--              supabase/migrations/0052_press_as_a_process.sql,
--              supabase/migrations/0101_a_note_can_be_about_a_screen.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (what a lot is made of is its lineage, recomputed from
--                  the volumes that went in, never a second stored fact), A13
--                  (a refusal in the middle of a press is a number nobody
--                  records)
-- Open sorries: S-90
-- ---------------------------------------------------------------------------
--
-- The winemaker, mid press: *"It's not letting me press a second lot into the
-- second tank as the first because 'Skinny Boy already holds wine'. The big tank
-- will hold multiple pressings of the same variety."*
--
-- And asked what the tank should hold afterwards: *"Well like this is all
-- Pearlstaad Chardonnay so it should carry the lineage from the pressings but
-- also be just Pearlstaad chardonnay."*
--
-- **The rule was already written down, in the other place it applies.** `0014`
-- says it plainly: "a destination that already holds a different lot is not an
-- error, it is a blend, and the lot already in there is another parent". Racking
-- has worked that way since the beginning. `draw_cut` never learned it and
-- refused instead, which is a refusal arriving while juice is running.
--
-- **It is wider than the case he hit.** The same refusal stops free run and hard
-- press going into one tank, because each cut is its own lot. Two loads into one
-- tank and two cuts into one tank are the same act and were both blocked.
--
-- **The tank keeps its lot rather than minting a new one.** This is the one
-- place this migration departs from rack, and it is his answer: rack mints a
-- blend node because racking is a deliberate act of combining two wines, while
-- filling a tank over a day of pressing is one wine being made. Minting per draw
-- would give four generations of lot for one tank of Chardonnay, each with a
-- name nobody chose.
--
-- So the lineage carries it. The resident lot gains the cut as a parent, and
-- every parent's share is rescaled by what it actually contributed, which is the
-- same arithmetic `0014` uses: volume in over volume total. Composition stays
-- derived, so what the tank is made of follows from the draws rather than from
-- anybody writing it down.
--
-- **A different variety is said, not refused.** His ruling, the same one he gave
-- for barrels: somebody can pour before telling the app, and a refusal at the
-- press loses the number. It comes back on the result so the screen can say it
-- while the person is still standing there.

begin;

create or replace function draw_cut(
  p_load_id    uuid,
  p_vessel_id  uuid,
  p_volume_l   numeric,
  p_cut_id     uuid default null,
  p_name       text default null,
  p_note       text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
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

      -- Every parent's share is what it contributed over what is now there. The
      -- existing parents kept `held` between them, so they keep held/new_total
      -- of what they had, and the arriving cut takes the rest. Clamped the way
      -- 0014 clamps, because the constraint is fraction > 0.
      update lineage
         set fraction = greatest(
               least(fraction * held / nullif(new_total, 0), 1), 0.00001)
       where child_id = resident;

      -- The cut may already be a parent, from an earlier draw into this same
      -- tank, in which case its share grows rather than being written twice.
      insert into lineage (parent_id, child_id, fraction)
      values (cut_id, resident,
              greatest(least(p_volume_l / nullif(new_total, 0), 1), 0.00001))
      on conflict (parent_id, child_id) do update
        set fraction = least(lineage.fraction + excluded.fraction, 1);

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
    'load_total', (select coalesce(sum(n.quantity), 0) from node n
                     join lineage l on l.child_id = n.id and l.parent_id = p_load_id)
  );
end;
$$;

revoke all on function draw_cut(uuid, uuid, numeric, uuid, text, text) from public;
grant execute on function draw_cut(uuid, uuid, numeric, uuid, text, text) to authenticated;

comment on function draw_cut(uuid, uuid, numeric, uuid, text, text) is
  'Draws a cut off a press into a vessel. A vessel that already holds another '
  'lot is a blend, not a refusal: the lot there keeps its identity and gains '
  'the cut as a parent. See 0052 and 0102.';

commit;
