-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Picking stops, and then somebody has to decide what happens to the
--           fruit: it goes cold, it gets processed, or it leaves."
-- Depends on: [supabase/migrations/0030_writable_columns.sql,
--              supabase/migrations/0033_intake.sql,
--              supabase/migrations/0043_record_propagation.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0045_press_detail.sql]
-- Axioms enforced: T0-5 (a departure is an event and is not unmade; a plan is
--                  not an event and may be changed), T1-4 (finishing says what
--                  is still incomplete rather than refusing)
-- Open sorries: S-60 (a plan is not connected to the work that fulfils it)
-- ---------------------------------------------------------------------------
--
-- Asked for after the first pick: "a pick should be able to called finished,
-- where it then presents the results, then you assign the bins to going to cold
-- storage or processing now or sending to another winery, and then from there
-- you can add them to a queue."
--
-- **Finishing is not closing.** A pick closes when its fruit has gone through a
-- press, which `0013` decides from the quantity. Finishing means no more bins
-- are coming, which is a different fact and an earlier one, and the fruit is
-- very much still there. So it is an attribute rather than a status.
--
-- **It reports rather than refuses.** A pick finished with bins nobody weighed
-- is a real situation at the end of a long day, and refusing would push somebody
-- into not finishing it at all, which loses the signal entirely. So the totals
-- come back with the unweighed count beside them and the screen can be loud.
--
-- **A plan is not an event.** The winemaker's words: "as a plan, so it could be
-- changed." That is the distinction T0-5 turns on. An observation is not unmade,
-- and an intention is nothing but changeable, so planning to press on Thursday
-- uses `task`, which is core, generic since `AR-E6`, and already has a due
-- window, a status and a claim. No queue is invented here: a plan is a set of
-- tasks that share a date and an operation, and the grouping is derived.
--
-- **Where fruit goes when it leaves depends on whose it is.** Sold fruit stops
-- being this winery's problem and the pick closes carrying the weight that left,
-- because that weight is the thing anybody would later be asked about. Fruit
-- sent out to be made and coming back is still this winery's wine, so the pick
-- stays open and only the bins are released. The screen asks which, because they
-- are different facts and only one of them ends in a wine you bottle.

begin;

-- ---------------------------------------------------------------------------
-- A cellar hand may move a vessel
-- ---------------------------------------------------------------------------

-- `move_vessel` has been an operation since `0004` and nothing could perform it:
-- the cellar write allow-list on `vessel` covers the jacket and nothing else, so
-- putting bins in the cold room was an administrator's job. Moving things is
-- what a cellar hand does all day, and the operation vocabulary has said so from
-- the beginning.
drop trigger if exists vessel_cellar_columns on vessel;
create trigger vessel_cellar_columns
  before update on vessel
  for each row execute function cellar_writable_columns(
    'has_glycol', 'setpoint_c', 'mode', 'location_id');

-- Fruit going somewhere else. A movement, because that is what it is: the fruit
-- leaves, and whether it comes back is recorded rather than assumed.
insert into term (kind, value, label, attributes)
values ('operation', 'depart', 'Sent away',
        jsonb_build_object('effect', 'movement'))
on conflict (kind, value) do update
  set label = excluded.label,
      attributes = term.attributes || excluded.attributes;

-- ---------------------------------------------------------------------------
-- Picking has stopped
-- ---------------------------------------------------------------------------

create or replace function finish_pick(p_node_id uuid)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  n         node%rowtype;
  waiting   int;
  bins      int;
begin
  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no pick with id %', p_node_id;
  end if;
  if n.stage <> 'bin' then
    raise exception '% is not a pick', n.name;
  end if;
  if n.status = 'closed' then
    raise exception '% is closed; its fruit has already gone somewhere', n.name;
  end if;

  select count(*) into bins
    from placement where node_id = p_node_id and to_at is null;
  select count(*) into waiting from unweighed_bin where node_id = p_node_id;

  update node
     set attributes = attributes || jsonb_build_object('picking_finished_at', now())
   where id = p_node_id;

  return jsonb_build_object(
    'node_id',    p_node_id,
    'name',       n.name,
    'bins',       bins,
    'net_lbs',    n.quantity,
    -- The number anybody actually says out loud about a pick. Derived here
    -- rather than in a screen, so two screens cannot disagree about what a ton
    -- is. S-49 is that the pound is a constant.
    'tons',       case when n.quantity is null then null
                       else round(n.quantity / 2000.0, 3) end,
    -- Reported, never refused. A pick finished with bins nobody weighed is a
    -- real end to a long day, and refusing would push somebody into not
    -- finishing it at all, which loses the signal this exists to give.
    'unweighed',  waiting
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Where the bins go
-- ---------------------------------------------------------------------------

-- Cold storage is a location, so going cold is a move. Writing the event as well
-- as the column is the point: the column says where a bin is and the event says
-- when it got there, and the second is the one that answers how long fruit sat.
create or replace function move_bins(
  p_vessel_ids uuid[],
  p_location_id uuid
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  v_id  uuid;
  moved int := 0;
begin
  if coalesce(array_length(p_vessel_ids, 1), 0) = 0 then
    raise exception 'no vessels were named, so there is nothing to move';
  end if;
  if not exists (select 1 from location where id = p_location_id) then
    raise exception 'there is no such location to move them to';
  end if;

  foreach v_id in array p_vessel_ids
  loop
    update vessel set location_id = p_location_id where id = v_id and active;
    if not found then
      raise exception 'no active vessel with id %', v_id;
    end if;
    insert into event (operation_id, subject_type, subject_id, by_user, provenance, data)
    values (term_id('operation', 'move_vessel'), 'vessel', v_id, auth.uid(), 'observed',
            jsonb_build_object('location_id', p_location_id));
    moved := moved + 1;
  end loop;

  return jsonb_build_object('moved', moved, 'location_id', p_location_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- The plan
-- ---------------------------------------------------------------------------

-- One task per bin, sharing a date and an operation, which is what a plan is.
-- Nothing new is invented: `task` is core, generic since AR-E6, and already
-- carries a due window, a status, an assignee and a claim. Changing the plan is
-- changing those rows, which is allowed precisely because a plan is not an
-- observation.
create or replace function plan_processing(
  p_vessel_ids   uuid[],
  p_operation_id uuid,
  p_on           date,
  p_instructions text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  v_id    uuid;
  planned int := 0;
begin
  if coalesce(array_length(p_vessel_ids, 1), 0) = 0 then
    raise exception 'no bins were named, so there is nothing to plan';
  end if;
  if p_on is null then
    raise exception 'a plan needs a day it is for';
  end if;
  if not exists (
    select 1 from term where id = p_operation_id and kind = 'operation'
  ) then
    raise exception 'that is not an operation, so it is not something to plan';
  end if;

  foreach v_id in array p_vessel_ids
  loop
    if not exists (select 1 from vessel where id = v_id and active) then
      raise exception 'no active vessel with id %', v_id;
    end if;
    insert into task (subject_type, subject_id, operation_id,
                      due_from, due_to, instructions, created_by)
    values ('vessel', v_id, p_operation_id,
            p_on::timestamptz, (p_on + 1)::timestamptz, p_instructions, auth.uid());
    planned := planned + 1;
  end loop;

  return jsonb_build_object('planned', planned, 'on', p_on);
end;
$$;

-- What is planned, grouped the way somebody would read it. Derived, so changing
-- a task changes the plan and there is no second copy to keep in step.
create or replace view processing_plan with (security_invoker = true) as
select
  t.due_from::date as planned_for,
  t.operation_id,
  coalesce(op.label, 'Something') as operation,
  count(*)                        as bins,
  string_agg(v.name, ', ' order by v.name) as bin_names,
  array_agg(v.id order by v.name)          as vessel_ids,
  min(t.instructions)             as instructions
from task t
join vessel v on v.id = t.subject_id and t.subject_type = 'vessel'
left join term op on op.id = t.operation_id and op.kind = 'operation'
where t.status in ('open', 'claimed')
group by t.due_from::date, t.operation_id, op.label;

comment on view processing_plan is
  'Bins planned for an operation on a day, grouped. A plan is a set of tasks '
  'sharing a date and an operation, and the grouping is derived so that changing '
  'a task changes the plan. See 0044.';

-- ---------------------------------------------------------------------------
-- Fruit that leaves
-- ---------------------------------------------------------------------------

create or replace function send_fruit_away(
  p_node_id     uuid,
  p_destination text,
  p_returning   boolean default false,
  p_note        text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  n      node%rowtype;
  freed  int := 0;
begin
  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no pick with id %', p_node_id;
  end if;
  if n.status = 'closed' then
    raise exception '% has already gone somewhere', n.name;
  end if;
  if nullif(btrim(coalesce(p_destination, '')), '') is null then
    raise exception 'fruit does not leave to nowhere; say where it went';
  end if;

  insert into event (operation_id, subject_type, subject_id, by_user, provenance, data)
  values (term_id('operation', 'depart'), 'node', p_node_id, auth.uid(), 'observed',
          jsonb_strip_nulls(jsonb_build_object(
            'destination', btrim(p_destination),
            'returning',   p_returning,
            'lbs',         n.quantity,
            'note',        nullif(btrim(coalesce(p_note, '')), ''))));

  -- The bins are released either way: the fruit is not in them any more, and a
  -- bin that still reads as full is a bin nobody can fill.
  update placement set to_at = now()
   where node_id = p_node_id and to_at is null;
  get diagnostics freed = row_count;

  -- Sold fruit stops being this winery's problem, and the weight that left stays
  -- on the row because that is the thing anybody would later be asked about.
  -- Fruit going out to be made and coming back is still this winery's wine, so
  -- the lot stays open with nothing to point at, which is true rather than tidy.
  if not p_returning then
    update node
       set status = 'closed',
           closed_at = coalesce(closed_at, now())
     where id = p_node_id;
  end if;

  return jsonb_build_object(
    'node_id',     p_node_id,
    'destination', btrim(p_destination),
    'returning',   p_returning,
    'bins_freed',  freed,
    'closed',      not p_returning
  );
end;
$$;

commit;
