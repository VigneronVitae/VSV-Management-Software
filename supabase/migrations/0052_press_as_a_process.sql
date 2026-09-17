-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A press starts, is drawn off however many times over however many
--           hours, and finishes, because nobody knows the litres before they
--           have pressed."
-- Depends on: [supabase/migrations/0034_press.sql,
--              supabase/migrations/0045_press_detail.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0053_a_press_is_a_vessel.sql, supabase/migrations/0054_a_spent_pick_is_spent.sql, supabase/migrations/0055_press_draws.sql, supabase/migrations/0056_draw_to_a_level.sql, supabase/migrations/0057_the_contract.sql,
--                  supabase/migrations/0095_what_is_running.sql,
--                  supabase/migrations/0102_a_tank_takes_more_than_one_pressing.sql]
-- Axioms enforced: T1-4 (the load exists before its volume is known, the same
--                  way a bin exists before it is weighed), T0-5 (every draw is
--                  an event and the quantity is recomputed from them)
-- Open sorries: S-71 (the one-shot press from 0034 is still here, so the same
--                event can be recorded two ways with different lineage depth)
-- ---------------------------------------------------------------------------
--
-- The winemaker, on the morning of the first press: "pressing needs to be a
-- process instead of an entry at the end. Like I wanted to start a press but I
-- can't know how many liters until after I've pressed." And then, exactly:
--
--   "maybe you start pressing and then finish pressing. You don't have to stay
--   in the app the whole time, you can pop off to other vessels and stuff and
--   pop back in and update the liters/etc. so you might update the liters
--   multiple times, or after different pressures or whatever you want"
--
-- **That is the same shape as a bin with no weight, and this schema already has
-- a name for it.** T1-4 says intake must be fast before it is complete: a bin
-- exists, holds known fruit, and has no weight until somebody gets to a scale.
-- A load in the press is that again. It exists, it is made of known fruit, and
-- its volume is unknown until juice comes out. `0033` took the same decision for
-- the same reason and wrote `null` rather than `0`, because zero is a
-- measurement and this is the absence of one.
--
-- **The stage was already there.** `node_stage` has carried `load` between `bin`
-- and `ferment` since `0001` and nothing has ever written one. Fruit that has
-- left the bins and is in the press is what that stage is for, and it is the
-- reason a press is not just a rename of the pick: the bins empty at the start,
-- which matters when there are three picking bins and more fruit coming.
--
-- **Every cut is entirely made of the load.** That is what lets a draw be
-- recorded the moment it happens rather than at the end. `lineage.fraction` is
-- the share of the child that came from each parent, so a cut with one parent is
-- 1.0 whatever volume it turns out to be, and the picks' shares live one
-- generation up on the load where they were known all along. Nothing has to be
-- rewritten when the next pressure comes off.
--
-- **Drawing the same cut again adds to it.** Free run into a tank, then more free
-- run into the same tank an hour later, is one cut that got bigger. The quantity
-- is recomputed from the draw events rather than added to, which is what
-- `weigh_bins` does and for the same reason: a correction then lands without
-- anybody working out what the old number contributed.

begin;

-- ---------------------------------------------------------------------------
-- Starting
-- ---------------------------------------------------------------------------

create or replace function start_press(
  p_source_ids      uuid[],
  p_press_vessel_id uuid,
  p_node            jsonb default '{}'::jsonb,
  p_detail          jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  n_src        int := coalesce(array_length(p_source_ids, 1), 0);
  parent_stage node_stage;
  child_stage  node_stage;
  n            node%rowtype;
  total_lbs    numeric := 0;
  load_id      uuid := coalesce((p_node ->> 'id')::uuid, gen_random_uuid());
  ev_id        uuid := gen_random_uuid();
  src          uuid;
  emptied      int := 0;
  unweighed    int := 0;
  first_name   text;
begin
  if n_src = 0 then
    raise exception 'nothing was named to press';
  end if;
  if p_press_vessel_id is null then
    raise exception 'say which press this is going into, so the fruit is somewhere';
  end if;
  if not exists (select 1 from vessel where id = p_press_vessel_id and active) then
    raise exception 'that press is not an active vessel';
  end if;
  if exists (select 1 from placement
              where vessel_id = p_press_vessel_id and to_at is null) then
    raise exception
      'that press already has a load in it; finish that press before starting another';
  end if;

  foreach src in array p_source_ids loop
    select * into n from node where id = src;
    if n.id is null then
      raise exception 'no lot with id %', src;
    end if;
    if n.status = 'closed' then
      raise exception '% is closed; its fruit has already gone somewhere', n.name;
    end if;
    if parent_stage is null then
      parent_stage := n.stage;
      first_name := n.name;
    elsif parent_stage <> n.stage then
      raise exception
        'those lots are at different stages, so one press cannot be the right record for both';
    end if;
    total_lbs := total_lbs + coalesce(n.quantity, 0);
    unweighed := unweighed + (select count(*) from unweighed_bin where node_id = src);
  end loop;

  -- Where the juice lands when it comes off. Decided here rather than at each
  -- draw, because it is a fact about what went in and somebody drawing the third
  -- pressure should not be asked it again.
  child_stage := case when parent_stage = 'bin' then 'ferment'::node_stage
                      else 'maturation'::node_stage end;

  -- Quantity null, unit null. T1-4: the load exists before anybody knows how
  -- much of it there is, the same way a bin does, and zero would be a lie about
  -- a measurement nobody has made.
  insert into node
    (id, stage, status, name, quantity, unit, variety_id, vintage, non_vintage,
     product_type_id, owner_id, created_by, attributes)
  select
    load_id, 'load', 'open',
    coalesce(nullif(p_node ->> 'name', ''), first_name || ' pressing'),
    null, null,
    (select case when count(distinct p.variety_id) = 1
                 then (array_agg(distinct p.variety_id))[1] end
       from node p where p.id = any(p_source_ids)),
    (select case when count(distinct p.vintage) = 1 and bool_and(not p.non_vintage)
                 then min(p.vintage) end
       from node p where p.id = any(p_source_ids)),
    (select case when count(distinct p.vintage) = 1 and bool_and(not p.non_vintage)
                 then false else true end
       from node p where p.id = any(p_source_ids)),
    coalesce((select case when count(distinct p.product_type_id) = 1
                          then (array_agg(distinct p.product_type_id))[1] end
                from node p where p.id = any(p_source_ids)),
             term_id('product_type', 'wine')),
    (select p.owner_id from node p where p.id = any(p_source_ids)
      order by p.quantity desc nulls last limit 1),
    auth.uid(),
    coalesce(p_node -> 'attributes', '{}'::jsonb)
      || jsonb_build_object('cut_stage', child_stage::text)
      || jsonb_strip_nulls(p_detail);

  -- The picks' shares, known now and never recomputed. A load made of 2000 lbs
  -- and 1000 lbs is two thirds and one third of whatever comes out of it, which
  -- is true before a drop has run.
  if total_lbs > 0 then
    insert into lineage (parent_id, child_id, fraction)
    select p.id, load_id, round(coalesce(p.quantity, 0) / total_lbs, 6)
      from node p where p.id = any(p_source_ids) and coalesce(p.quantity, 0) > 0;
  else
    -- Nothing was weighed. Equal shares is a guess and saying so is the only
    -- honest version of it, so the fractions go in evenly and the caller is told
    -- how many bins never reached a scale.
    insert into lineage (parent_id, child_id, fraction)
    select p.id, load_id, round(1.0 / n_src, 6)
      from node p where p.id = any(p_source_ids);
  end if;

  -- The bins empty here, which is the point of starting rather than recording at
  -- the end: they are available for the next pick while the press runs.
  for src in select unnest(p_source_ids) loop
    update placement set to_at = now()
     where node_id = src and to_at is null;
    get diagnostics emptied = row_count;
  end loop;
  select count(*) into emptied
    from placement where node_id = any(p_source_ids) and to_at is not null;

  -- Volume null: there is fruit in the press and nobody knows what it will give.
  insert into placement (node_id, vessel_id, volume_l)
  values (load_id, p_press_vessel_id, null);

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'press'), 'node', load_id, auth.uid(), 'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'action',     'started',
       'sources',    to_jsonb(p_source_ids::text[]),
       'press',      p_press_vessel_id,
       'lbs_in',     nullif(total_lbs, 0),
       'detail',     nullif(p_detail, '{}'::jsonb))));

  return jsonb_build_object(
    'node_id',    load_id,
    'event_id',   ev_id,
    'stage',      'load',
    'cut_stage',  child_stage,
    'lbs_in',     total_lbs,
    'bins_emptied', emptied,
    -- Not fatal and not silent, the same as the one-shot press: the fruit went
    -- in with containers that never reached a scale, and somebody should know
    -- while the pick can still be corrected.
    'unweighed_left', unweighed
  );
end;
$$;

revoke all on function start_press(uuid[], uuid, jsonb, jsonb) from public;
grant execute on function start_press(uuid[], uuid, jsonb, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Drawing off, as many times as it takes
-- ---------------------------------------------------------------------------

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
  -- Free run into a tank and then more free run into it an hour later is one
  -- cut, which is the winemaker's "update the liters multiple times".
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
    -- Entirely made of the load, whatever it ends up weighing. This is what lets
    -- the share be written now instead of at the end: the picks' proportions are
    -- one generation up, on the load, where they were known before a drop ran.
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

  -- Recomputed from the draws rather than added to, so a corrected draw lands
  -- without anybody working out what the old one contributed. Same reason as
  -- `weigh_bins`.
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
    if exists (select 1 from placement
                where vessel_id = p_vessel_id and to_at is null and node_id <> cut_id) then
      raise exception '% already holds other wine',
        (select name from vessel where id = p_vessel_id);
    end if;
    insert into placement (node_id, vessel_id, volume_l)
    values (cut_id, p_vessel_id, in_vessel);
  end if;

  select capacity_l into cap from vessel where id = p_vessel_id;

  return jsonb_build_object(
    'cut_id',     cut_id,
    'event_id',   ev_id,
    'cut',        cut_label,
    'volume_l',   p_volume_l,
    'cut_total',  total,
    'in_vessel',  in_vessel,
    -- Said, not refused. Somebody at a press who has just filled a tank past its
    -- capacity has a real problem and a refusal at this point loses the number.
    'over_capacity', cap is not null and in_vessel > cap,
    'load_total', (select coalesce(sum(n.quantity), 0) from node n
                     join lineage l on l.child_id = n.id and l.parent_id = p_load_id)
  );
end;
$$;

revoke all on function draw_cut(uuid, uuid, numeric, uuid, text, text) from public;
grant execute on function draw_cut(uuid, uuid, numeric, uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Finishing
-- ---------------------------------------------------------------------------

create or replace function finish_press(
  p_load_id uuid,
  p_detail  jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  load_n  node%rowtype;
  out_l   numeric;
  lbs_in  numeric;
  ev_id   uuid := gen_random_uuid();
  cuts    int;
begin
  select * into load_n from node where id = p_load_id;
  if load_n.id is null then
    raise exception 'no load with id %', p_load_id;
  end if;
  if load_n.stage <> 'load' then
    raise exception 'that lot is not in a press';
  end if;
  if load_n.status = 'closed' then
    raise exception 'that press is already finished';
  end if;

  select count(*), coalesce(sum(n.quantity), 0) into cuts, out_l
    from node n join lineage l on l.child_id = n.id and l.parent_id = p_load_id;

  if cuts = 0 then
    raise exception
      'nothing has been drawn off this press yet, so finishing it would record a press that produced nothing';
  end if;

  select coalesce(sum((e.data ->> 'lbs_in')::numeric), 0) into lbs_in
    from event e
   where e.subject_type = 'node' and e.subject_id = p_load_id
     and e.operation_id = term_id('operation', 'press')
     and e.data ->> 'action' = 'started';

  -- The load is spent: what went in came out as the cuts. Its quantity is set to
  -- what it gave rather than left null, because by now it is known.
  update node
     set quantity = out_l,
         unit = 'L',
         status = 'closed',
         closed_at = now(),
         attributes = attributes || jsonb_strip_nulls(p_detail)
   where id = p_load_id;

  update placement set to_at = now()
   where node_id = p_load_id and to_at is null;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'press'), 'node', p_load_id, auth.uid(), 'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'action',    'finished',
       'litres_out', out_l,
       'cuts',      cuts,
       'detail',    nullif(p_detail, '{}'::jsonb))));

  return jsonb_build_object(
    'node_id',    p_load_id,
    'event_id',   ev_id,
    'lbs_in',     lbs_in,
    'litres_out', out_l,
    'cuts',       cuts,
    -- The number the whole exercise is for. Null rather than zero when nothing
    -- was weighed, because a yield computed from no weight is not a yield.
    'yield_l_per_ton',
      case when lbs_in > 0 then round(out_l / (lbs_in / 2000.0), 2) end
  );
end;
$$;

revoke all on function finish_press(uuid, jsonb) from public;
grant execute on function finish_press(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- What is in a press right now
-- ---------------------------------------------------------------------------

-- The list that makes "pop off to other vessels and pop back in" work. A press
-- somebody started and has not finished is the one thing in this system that is
-- deliberately unfinished for hours, so it has to be findable without
-- remembering where it was.
create or replace view press_in_progress with (security_invoker = true) as
select
  n.id            as node_id,
  n.name,
  n.created_at    as started_at,
  v.id            as press_vessel_id,
  v.name          as press_name,
  (select coalesce(sum((e.data ->> 'lbs_in')::numeric), 0)
     from event e
    where e.subject_type = 'node' and e.subject_id = n.id
      and e.data ->> 'action' = 'started')            as lbs_in,
  (select count(*) from lineage l where l.parent_id = n.id)   as cuts,
  (select coalesce(sum(c.quantity), 0) from node c
     join lineage l on l.child_id = c.id and l.parent_id = n.id) as litres_so_far
from node n
left join placement p on p.node_id = n.id and p.to_at is null
left join vessel v on v.id = p.vessel_id
where n.stage = 'load' and n.status <> 'closed';

comment on view press_in_progress is
  'Presses that were started and not finished. The litres are what has been '
  'drawn off so far, which is the number that changes every time somebody goes '
  'back to the press. See 0052.';

commit;
