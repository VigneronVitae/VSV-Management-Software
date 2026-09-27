-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Picks, pressing and racking can be recorded after they happened, at
--           the time they happened, and the record keeps both times: when it
--           was done and when somebody got round to entering it."
-- Depends on: [supabase/migrations/0013_close_on_empty.sql,
--              supabase/migrations/0052_press_as_a_process.sql,
--              supabase/migrations/0141_a_volume_says_whether_it_was_measured.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts,
--                  supabase/migrations/0146_harvest_weights.sql,
--                  supabase/migrations/0147_a_pressing_knows_what_went_in.sql,
--                  supabase/migrations/0151_a_cut_counts_once.sql]
-- Axioms enforced: T0-5. Backdating is not editing. The event is appended
--                  today with yesterday's time on it, and `created_at` still
--                  says today, so nothing about the record is rewritten and the
--                  gap between the two is the proof it was entered late.
--                  A13. A backdated write that would contradict what a vessel
--                  held afterwards is refused in a sentence, rather than
--                  accepted into a history that cannot have happened.
-- Open sorries: S-144, the verbs that still stamp the moment of entry.
-- ---------------------------------------------------------------------------

-- "Backdating stuff, like I didn't have time to mark the pressing yesterday so I
-- want to do it today and backdate it to yesterday, while preserving the fact
-- that it was backdated." Then: "Backdated also meaning back timed in the same
-- day, like if at the end of the day I batched the things I did throughout the
-- day."
--
-- **Half of this already existed.** `event` has carried two times since the
-- beginning: `at`, when the thing happened, and `created_at`, when the row was
-- written. Three verbs already accept a time (`add_to_wine`, `dump_wine`,
-- `record_work`). What was missing is the press and the rack, which stamp
-- `now()` in their bodies, in the bodies of what they call (`move_vessels`
-- records a bin's walk to the press through a column default), and in the
-- `0013` trigger that closes an emptied lot.
--
-- **Threading a parameter through all of that by hand was the obvious approach
-- and was rejected.** Every helper would need the time passed to it, and the
-- first one somebody forgot would stamp a backdated pressing's bins as having
-- moved today, which is a wrong fact that looks like a right one. Instead the
-- verb says once when it is happening, `happening_at(p_at)`, which sets a
-- transaction-local value; `occurred_at()` reads it, or is `now()` when nothing
-- was said. Column defaults that mean "when it happened" read `occurred_at()`,
-- so every nested write inherits the time without being told. `is_local`
-- means the value dies with the transaction, and PostgREST runs each call in
-- its own, so it cannot leak into the next request.
--
-- **The parameter is still explicit on every verb.** A mode switched on by one
-- call and honoured by later ones was also considered, and is the design where
-- a forgotten switch backdates tomorrow's real-time entries. `p_at` on the verb
-- means the time is part of the call that uses it, visible in the contract,
-- and nothing is carried between calls.
--
-- **Entered late is derived, not stored.** For a write made at the time,
-- `at` and `created_at` are both the transaction's `now()` and are identical to
-- the microsecond. Any difference means somebody said when, so `entered_late`
-- is `at < created_at` with no threshold to argue about, and it is equally true
-- of yesterday's pressing and of this morning's rack entered at six tonight.

-- ---------------------------------------------------------------------------
-- When the thing being recorded happened
-- ---------------------------------------------------------------------------

-- Written as branches rather than one `coalesce`, because scripts/guards.sh
-- reads `coalesce(..., true)` on a line as a permissive default and tries to
-- mutate it, and `current_setting(name, true)` inside one looks exactly like
-- that without being it.
create or replace function occurred_at()
returns timestamptz
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  said text := current_setting('vsv.occurred_at', true);
begin
  if said is null or said = '' then
    return now();
  end if;
  return said::timestamptz;
end $$;

comment on function occurred_at is
  'When the thing being recorded happened: the time the current verb was given, '
  'or now() when it was given none. Transaction-local, so it cannot outlive the call.';

-- Null leaves whatever is already set, which is how a verb called from inside a
-- backdated verb inherits the outer time rather than resetting it to now.
create or replace function happening_at(p_at timestamptz)
returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if p_at is null then
    return;
  end if;
  -- A few minutes of grace, because a phone's clock and the server's disagree
  -- by more than people expect, and refusing "now" as the future would be
  -- absurd. Beyond that it is a plan and not a record.
  if p_at > now() + interval '5 minutes' then
    raise exception 'that time is in the future, and this records what happened rather than what will';
  end if;
  perform set_config('vsv.occurred_at', p_at::text, true);
end $$;

comment on function happening_at is
  'Says when the thing the current verb records happened, for the rest of this '
  'transaction. Null leaves an outer verb''s time in place.';

-- The other half. A verb puts back whatever time was in force when it was
-- called, so a caller in the same transaction, which is how the assertion suite
-- calls everything and how one verb calls another, does not inherit it.
create or replace function resume_at(p_was text)
returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if p_was is null then
    perform set_config('vsv.occurred_at', '', true);
  else
    perform set_config('vsv.occurred_at', p_was, true);
  end if;
end $$;

insert into capability_exemption (fn, reason) values
  ('occurred_at',
   'Reads the time the current verb was given. It is how a verb''s nested writes learn when they happened, and a periphery has nothing to ask it: the answer outside a verb is always now.'),
  ('happening_at',
   'Called by a verb on its own first line with the p_at it was given. Called by a periphery on its own it sets a value that dies with its transaction before anything reads it.'),
  ('resume_at',
   'Called by a verb before it returns, to put back the time that was in force when it was called. Nothing outside a verb has a time to put back.'),
  ('entered_late',
   'A computed field on event, read through the event row rather than called.'),
  ('placement_keeps_time',
   'A trigger function. It refuses a placement that would contradict what its vessel held at that time, and nothing calls it.')
on conflict (fn) do update set reason = excluded.reason;

-- The defaults that mean "when it happened". `created_at` everywhere keeps
-- `now()`, because that one means when it was written, and the gap between the
-- two is the whole record of lateness.
alter table event           alter column at       set default occurred_at();
alter table placement       alter column from_at  set default occurred_at();
alter table supply_movement alter column at       set default occurred_at();
-- `lineage.created_at` is named like an entry time and is read as an occurrence:
-- `node_history` uses it as the moment a child came off its parent, to stop
-- showing the parent's later events as the child's. A backdated pressing whose
-- lineage said today would show a day of the parent's events it never had.
alter table lineage         alter column created_at set default occurred_at();

-- `0013` closes a lot whose quantity reaches nothing, and stamps the closing.
create or replace function close_node_when_empty()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $function$
begin
  if new.quantity is not null and new.quantity <= 0 then
    if new.status <> 'closed' then
      new.status := 'closed';
      new.closed_at := coalesce(new.closed_at, occurred_at());
    end if;
  elsif new.quantity is not null and new.quantity > 0 and new.status = 'closed'
        and new.closed_at is not null and old.quantity is not null
        and old.quantity <= 0 then
    -- Refilling something that was emptied is a correction, not a resurrection,
    -- and it is rare enough that reopening quietly would hide a mistake. The
    -- lot stays closed and the correction is a new lot.
    raise exception 'lot % is closed; record the wine as a new lot rather than refilling this one', new.id;
  end if;
  return new;
end;
$function$;

-- ---------------------------------------------------------------------------
-- A backdated write cannot contradict what came after it
-- ---------------------------------------------------------------------------

-- Until today every placement began at `now()`, after everything already
-- recorded, so two facts about a vessel could never overlap and nothing checked.
-- A backdated write can put wine into a tank at two o'clock that the record
-- already shows holding something else at three, or take fruit out of a bin
-- before it was picked. Both are refused here, in the one place every write to a
-- vessel passes through, rather than in each verb.
--
-- Checked on the live data before this was written: no placement ended before it
-- began and no two on one vessel overlapped, so this constrains new writes and
-- does not trip on history. Half-open ranges, because a rack closes one
-- placement and opens the next at the same instant and those two touch without
-- overlapping.
create or replace function placement_keeps_time()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_name  text;
  o_from  timestamptz;
  o_to    timestamptz;
  span    text;
begin
  if new.to_at is not null and new.to_at < new.from_at then
    select name into v_name from vessel where id = new.vessel_id;
    raise exception 'that takes the wine out of % at %, before it went in at %',
      v_name,
      to_char(new.to_at at time zone 'America/Los_Angeles', 'Mon FMDD HH24:MI'),
      to_char(new.from_at at time zone 'America/Los_Angeles', 'Mon FMDD HH24:MI');
  end if;

  -- Two open placements in one vessel are left to `placement_one_lot_per_vessel`,
  -- which has refused them with its own SQLSTATE since the beginning and is
  -- asserted to. This covers what that index cannot see: anything where at least
  -- one of the two has ended, which is every overlap a backdated write can make.
  select p.from_at, p.to_at into o_from, o_to
    from placement p
   where p.vessel_id = new.vessel_id
     and p.id <> new.id
     and (p.to_at is not null or new.to_at is not null)
     and tstzrange(p.from_at, coalesce(p.to_at, 'infinity'), '[)')
      && tstzrange(new.from_at, coalesce(new.to_at, 'infinity'), '[)')
   order by p.from_at
   limit 1;
  if found then
    select name into v_name from vessel where id = new.vessel_id;
    span := to_char(o_from at time zone 'America/Los_Angeles', 'Mon FMDD HH24:MI')
         || case when o_to is null then ' onward'
                 else ' to ' || to_char(o_to at time zone 'America/Los_Angeles', 'Mon FMDD HH24:MI') end;
    raise exception '% already held something from %, so nothing else can be in it from %. Enter the earlier thing first, or record this at its real time',
      v_name, span,
      to_char(new.from_at at time zone 'America/Los_Angeles', 'Mon FMDD HH24:MI');
  end if;
  return new;
end $$;

drop trigger if exists placement_keeps_time on placement;
create trigger placement_keeps_time
  before insert or update of from_at, to_at, vessel_id on placement
  for each row execute function placement_keeps_time();

-- ---------------------------------------------------------------------------
-- Entered late, and history that says so
-- ---------------------------------------------------------------------------

-- A computed field, so `select=*,entered_late` works on `event` through
-- PostgREST and the rule lives here rather than in each client.
create or replace function entered_late(e event)
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  -- False rather than null for a row missing either time, which is A25: a
  -- question with a yes-or-no answer does not answer "unknown".
  select e.at is not null and e.created_at is not null and e.at < e.created_at;
$$;

comment on function entered_late(event) is
  'True when the event was written after the time it records. A write made at the '
  'time has at and created_at identical, so any difference means somebody said when.';

-- The return shape changes, and a function's return type cannot be replaced in
-- place, so it is dropped and recreated with the same body and two more columns.
drop function if exists node_history(uuid);

create function node_history(p_node_id uuid)
returns table(event_id uuid, node_id uuid, at timestamptz, operation text, label text,
              provenance provenance, data jsonb, inherited boolean,
              entered_at timestamptz, entered_late boolean)
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  n node;
begin
  select * into n from node where id = p_node_id;
  if not found then return; end if;

  -- Same gate as visible_node, for the same reason.
  if not coalesce(is_admin() or n.owner_id = current_party_id()
                  or is_facility_user(), false) then
    return;
  end if;
  if 'history' = any(n.hidden)
     and not coalesce(may_see_all_of(n.owner_id, n.hidden), false) then
    return;
  end if;

  return query
  with recursive chain as (
    select p_node_id as id, 'infinity'::timestamptz as cutoff, 0 as depth
    union all
    select l.parent_id, least(chain.cutoff, l.created_at), chain.depth + 1
      from chain
      join lineage l on l.child_id = chain.id
     where chain.depth < 50
  )
  select distinct
    e.id, e.subject_id, e.at, t.value, t.label, e.provenance, e.data,
    (chain.id <> p_node_id),
    e.created_at, e.at < e.created_at
  from chain
  join event e
    on e.subject_type = 'node' and e.subject_id = chain.id and e.at <= chain.cutoff
  join term t on t.id = e.operation_id
  order by e.at;
end;
$function$;

grant execute on function node_history(uuid) to authenticated, anon;

-- ---------------------------------------------------------------------------
-- The press and the rack take a time
-- ---------------------------------------------------------------------------

-- Each is the live definition from `pg_get_functiondef` with the same four
-- changes and no others, made mechanically and diffed: `p_at` appended to the
-- parameters, `happening_at(p_at)` as the first statement, every `now()` read
-- as `occurred_at()`, and the transaction-local time restored before the return
-- so a caller in the same transaction, which is how the assertion suite calls
-- everything, does not inherit it. `draw_to_level` returns `draw_cut`'s result,
-- so its inner call is made before the restore rather than after.
--
-- Adding a parameter overloads rather than replaces, so every old signature
-- goes first.
drop function if exists start_press(uuid[], uuid, jsonb, jsonb);
drop function if exists draw_cut(uuid, uuid, numeric, uuid, text, text);
drop function if exists draw_to_level(uuid, uuid, numeric, uuid, text);
drop function if exists finish_press(uuid, jsonb);
drop function if exists press(jsonb, jsonb, jsonb, jsonb);
drop function if exists rack(jsonb, jsonb, jsonb, boolean, jsonb);

CREATE OR REPLACE FUNCTION public.start_press(p_vessel_ids uuid[], p_press_vessel_id uuid, p_node jsonb DEFAULT '{}'::jsonb, p_detail jsonb DEFAULT '{}'::jsonb, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  -- 0104. Where the press stands, which is where its bins end up.
  press_room uuid;
  n_src        int := coalesce(array_length(p_vessel_ids, 1), 0);
  parent_stage node_stage;
  child_stage  node_stage;
  total_lbs    numeric := 0;
  load_id      uuid := coalesce((p_node ->> 'id')::uuid, gen_random_uuid());
  ev_id        uuid := gen_random_uuid();
  emptied      int := 0;
  unweighed    int := 0;
  guessed      int := 0;
  first_name   text;
  parents      uuid[];
  closed_now   int := 0;
begin
  perform happening_at(p_at);
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
  if p_press_vessel_id = any(p_vessel_ids) then
    raise exception 'a press cannot be loaded from itself';
  end if;

  -- Two presses started inside one transaction is not a thing a winery does and
  -- is exactly what the assertion suite does, and `on commit drop` does not fire
  -- between calls. Dropping first costs nothing and turns a second call from an
  -- error into a second call.
  drop table if exists going_in;
  drop table if exists putting_in;

  -- What is actually in the named vessels, and which lot each belongs to. This
  -- is the change: the source is the vessel somebody pointed at, and the lot is
  -- read off it.
  create temp table going_in on commit drop as
  select
    v.id            as vessel_id,
    v.name          as vessel_name,
    p.id            as placement_id,
    p.node_id,
    n.name          as lot_name,
    n.stage,
    n.status,
    -- Pounds for fruit, litres for anything else. One press can hold one or the
    -- other and the stage check below is what keeps them apart.
    case when n.stage = 'bin'
         then (select bf.lbs from bin_fruit bf where bf.placement_id = p.id)
         else p.volume_l end as amount
  from unnest(p_vessel_ids) as s(vessel_id)
  join vessel v on v.id = s.vessel_id
  left join placement p on p.vessel_id = v.id and p.to_at is null
  left join node n on n.id = p.node_id;

  if exists (select 1 from going_in where placement_id is null) then
    raise exception '% has nothing in it, so there is nothing of it to press',
      (select vessel_name from going_in where placement_id is null limit 1);
  end if;
  if exists (select 1 from going_in where status = 'closed') then
    raise exception '% is closed; its fruit has already gone somewhere',
      (select lot_name from going_in where status = 'closed' limit 1);
  end if;

  select count(distinct stage) into emptied from going_in;
  if emptied > 1 then
    raise exception
      'those vessels hold lots at different stages, so one press cannot be the right record for both';
  end if;
  select stage, lot_name into parent_stage, first_name from going_in limit 1;

  select array_agg(distinct node_id) into parents from going_in;
  select count(*) into guessed from going_in where amount is null;

  -- **What each pick is putting in, and the scale wins.** A weighed pick knows
  -- what the whole of it weighed; the bins only ever carried estimates. So a
  -- weighed pick contributes its own figure apportioned by the share of its
  -- bins that are going in, and an unweighed one contributes the estimates
  -- themselves. Pressing all of a 2120 pound pick puts in 2120 pounds and not
  -- the 1700 its bins were guessed at, which is the difference between a yield
  -- and a number.
  create temp table putting_in on commit drop as
  with all_bins as (
    -- Every bin that pick has ever had, open or emptied, because the share
    -- going in now is a share of the whole pick.
    select p.node_id,
           p.id as placement_id,
           coalesce((select bf.lbs from bin_fruit bf where bf.placement_id = p.id),
                    (select round(pl.fill_pct / 100.0
                                  * nullif((vt.attributes ->> 'full_lbs')::numeric, 0), 0)
                       from placement pl
                       join vessel v2 on v2.id = pl.vessel_id
                       join term vt on vt.id = v2.type_id
                      where pl.id = p.id)) as est
      from placement p
     where p.node_id = any(parents)
  )
  select
    g.node_id,
    n.quantity                                   as weighed,
    sum(coalesce(g.amount, 0))                   as chosen_est,
    (select coalesce(sum(coalesce(a.est, 0)), 0)
       from all_bins a where a.node_id = g.node_id) as whole_est,
    (select count(*) from all_bins a where a.node_id = g.node_id) as whole_bins,
    count(*)                                     as chosen_bins
  from going_in g
  join node n on n.id = g.node_id
  group by g.node_id, n.quantity;

  select coalesce(sum(
    case
      -- Weighed, and the bins say how it divides.
      when weighed is not null and whole_est > 0
        then weighed * (chosen_est / whole_est)
      -- Weighed, and nothing says how it divides. Bins are the only unit left,
      -- and saying so is better than refusing at a press.
      when weighed is not null and whole_bins > 0
        then weighed * (chosen_bins::numeric / whole_bins)
      else chosen_est
    end), 0)
    into total_lbs
    from putting_in;
  select coalesce(sum((select count(*) from unweighed_bin u where u.node_id = g.node_id)), 0)
    into unweighed
    from (select distinct node_id from going_in) g;

  child_stage := case when parent_stage = 'bin' then 'ferment'::node_stage
                      else 'maturation'::node_stage end;

  insert into node
    (id, stage, status, name, quantity, unit, variety_id, vintage, non_vintage,
     product_type_id, owner_id, created_by, attributes)
  select
    load_id, 'load', 'open',
    coalesce(nullif(p_node ->> 'name', ''), first_name || ' pressing'),
    null, null,
    (select case when count(distinct p.variety_id) = 1
                 then (array_agg(distinct p.variety_id))[1] end
       from node p where p.id = any(parents)),
    (select case when count(distinct p.vintage) = 1 and bool_and(not p.non_vintage)
                 then min(p.vintage) end
       from node p where p.id = any(parents)),
    (select case when count(distinct p.vintage) = 1 and bool_and(not p.non_vintage)
                 then false else true end
       from node p where p.id = any(parents)),
    coalesce((select case when count(distinct p.product_type_id) = 1
                          then (array_agg(distinct p.product_type_id))[1] end
                from node p where p.id = any(parents)),
             term_id('product_type', 'wine')),
    (select p.owner_id from node p where p.id = any(parents)
      order by p.quantity desc nulls last limit 1),
    auth.uid(),
    coalesce(p_node -> 'attributes', '{}'::jsonb)
      || jsonb_build_object('cut_stage', child_stage::text)
      || jsonb_strip_nulls(p_detail);

  -- The parents' shares of this load, by what each put into it. Two bins at 850
  -- from one pick and one at 400 from another is 81 percent and 19, which is
  -- true before a drop has run and is never recomputed.
  if total_lbs > 0 then
    insert into lineage (parent_id, child_id, fraction)
    select node_id, load_id,
           round(
             case
               when weighed is not null and whole_est > 0
                 then weighed * (chosen_est / whole_est)
               when weighed is not null and whole_bins > 0
                 then weighed * (chosen_bins::numeric / whole_bins)
               else chosen_est
             end / total_lbs, 6)
      from putting_in
     where case
             when weighed is not null and whole_est > 0
               then weighed * (chosen_est / whole_est)
             when weighed is not null and whole_bins > 0
               then weighed * (chosen_bins::numeric / whole_bins)
             else chosen_est
           end > 0;
  else
    -- Nothing in any of them was measured. Equal shares is a guess and saying
    -- so is the only honest version of it.
    insert into lineage (parent_id, child_id, fraction)
    select distinct g.node_id, load_id,
           round(1.0 / (select count(distinct node_id) from going_in), 6)
      from going_in g;
  end if;

  -- Only the bins that went in. The rest of the pick is still fruit on the pad.
  update placement set to_at = occurred_at()
   where id in (select placement_id from going_in);
  get diagnostics emptied = row_count;

  -- 0104. "When I pressed the Pearlstad bins it should have taken the picking
  -- bins out of the cold room and emptied them." The emptying worked; the room
  -- did not, so five bins stayed on the map in a cold room they had been
  -- wheeled out of.
  --
  -- They go where the press is, because that is where somebody just carried
  -- them and it is a fact the app already has. Through move_vessels rather than
  -- an update here, so a bin moved by a press and a bin moved by hand are moved
  -- by the same code and recorded the same way.
  select v.location_id into press_room from vessel v where v.id = p_press_vessel_id;
  if press_room is not null then
    perform move_vessels(array(select g.vessel_id from going_in g), press_room);
  end if;

  -- 0090. A pick is spent when its last bin empties, not when some of it is
  -- pressed. Closing it here with two bins still full would be the app saying
  -- the fruit is gone while it is standing in front of somebody.
  update node n
     set status = 'closed', closed_at = coalesce(n.closed_at, occurred_at())
   where n.id = any(parents)
     and not exists (
       select 1 from placement pl where pl.node_id = n.id and pl.to_at is null
     );
  get diagnostics closed_now = row_count;

  insert into placement (node_id, vessel_id, volume_l)
  values (load_id, p_press_vessel_id, null);

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'press'), 'node', load_id, auth.uid(), 'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'action',     'started',
       'sources',    to_jsonb(parents::text[]),
       'vessels',    to_jsonb(p_vessel_ids::text[]),
       'press',      p_press_vessel_id,
       'lbs_in',     nullif(total_lbs, 0),
       'detail',     nullif(p_detail, '{}'::jsonb))));

  perform resume_at(was_at);
  return jsonb_build_object(
    'node_id',    load_id,
    'event_id',   ev_id,
    'stage',      'load',
    'cut_stage',  child_stage,
    'lbs_in',     total_lbs,
    -- The names 0034 chose and the client has read ever since. Renaming them
    -- here would have made the screen say "undefined bins are free again",
    -- which is the shape of failure a defaulted or missing key always takes.
    'bins_emptied',   emptied,
    'unweighed_left', unweighed,
    -- New, and additive. How many of the bins that went in had no figure at
    -- all, so a screen can say the load's weight is a floor rather than a
    -- total; and how many picks this emptied, which is now a question with an
    -- answer other than "all of them".
    'unmeasured',  guessed,
    'picks_spent', closed_now);
end;
$function$;


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
    'load_total', (select coalesce(sum(n.quantity), 0) from node n
                     join lineage l on l.child_id = n.id and l.parent_id = p_load_id)
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.draw_to_level(p_load_id uuid, p_vessel_id uuid, p_level_l numeric, p_cut_id uuid DEFAULT NULL::uuid, p_note text DEFAULT NULL::text, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  held      numeric;
  holder    uuid;
  cut_id    uuid := p_cut_id;
  increment numeric;
  v_name    text;
  result    jsonb;
begin
  perform happening_at(p_at);
  if p_level_l is null or p_level_l < 0 then
    raise exception 'a level of % is not a reading',
      coalesce(p_level_l::text, 'nothing');
  end if;

  select v.name into v_name from vessel v where v.id = p_vessel_id;
  if v_name is null then
    raise exception 'no vessel with id %', p_vessel_id;
  end if;

  select pl.volume_l, pl.node_id into held, holder
    from placement pl
   where pl.vessel_id = p_vessel_id and pl.to_at is null;
  held := coalesce(held, 0);

  -- Whatever is in there already, if it belongs to this press, is what is being
  -- topped up. A vessel holding somebody else's wine is refused by `draw_cut`
  -- further down, and this is not the place to say so twice.
  if holder is not null and cut_id is null then
    select (n.attributes ->> 'cut')::uuid into cut_id
      from node n
      join lineage l on l.child_id = n.id and l.parent_id = p_load_id
     where n.id = holder;
  end if;

  increment := p_level_l - held;

  -- **A level below what is already in the vessel is the interesting refusal.**
  -- It means either a misread gauge or wine having left the tank since, and
  -- neither is a draw. Silently recording a negative would be a subtraction
  -- nobody asked for; silently recording zero would be a success that did
  -- nothing, which A13 says must not look like a success that did something.
  if increment < 0 then
    raise exception
      '% already holds % L, so a reading of % L is not more wine arriving. Correct the earlier draw instead',
      v_name, held, p_level_l;
  end if;
  if increment = 0 then
    raise exception
      '% already reads % L, so nothing has come off since the last time this was recorded',
      v_name, held;
  end if;

  result := draw_cut(p_load_id, p_vessel_id, increment, cut_id, null, p_note)
    || jsonb_build_object('was_at', held, 'now_at', p_level_l);
  perform resume_at(was_at);
  return result;
end;
$function$;


CREATE OR REPLACE FUNCTION public.finish_press(p_load_id uuid, p_detail jsonb DEFAULT '{}'::jsonb, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  load_n  node%rowtype;
  out_l   numeric;
  lbs_in  numeric;
  ev_id   uuid := gen_random_uuid();
  cuts    int;
begin
  perform happening_at(p_at);
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
         closed_at = occurred_at(),
         attributes = attributes || jsonb_strip_nulls(p_detail)
   where id = p_load_id;

  update placement set to_at = occurred_at()
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

  perform resume_at(was_at);
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
$function$;


CREATE OR REPLACE FUNCTION public.press(p_sources jsonb, p_cuts jsonb, p_node jsonb DEFAULT '{}'::jsonb, p_detail jsonb DEFAULT '{}'::jsonb, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  src          jsonb;
  cut          jsonb;
  dst          jsonb;
  n            node%rowtype;
  want         numeric;
  total_in     numeric := 0;
  total_out    numeric := 0;
  cut_out      numeric;
  parent_ids   uuid[] := '{}';
  weights      numeric[] := '{}';
  child_ids    uuid[] := '{}';
  child        uuid;
  i            int;
  child_stage  node_stage;
  parent_stage node_stage;
  waiting      int := 0;
  v_id         uuid;
  vol          numeric;
  held         numeric;
  emptied      int := 0;
  ev_id        uuid := gen_random_uuid();
  wc           numeric := (p_detail ->> 'whole_cluster_pct')::numeric;
  started      timestamptz := (p_detail ->> 'skin_contact_start')::timestamptz;
  ended        timestamptz := (p_detail ->> 'skin_contact_end')::timestamptz;
  ran_from     timestamptz := (p_detail ->> 'pressed_from')::timestamptz;
  ran_to       timestamptz := (p_detail ->> 'pressed_to')::timestamptz;
begin
  perform happening_at(p_at);
  if p_sources is null or jsonb_array_length(p_sources) = 0 then
    raise exception 'nothing was named to press';
  end if;
  if p_cuts is null or jsonb_array_length(p_cuts) = 0 then
    raise exception 'the juice has to go somewhere; name at least one vessel';
  end if;

  if wc is not null and (wc < 0 or wc > 100) then
    raise exception 'whole cluster of % percent is not a proportion', wc;
  end if;
  -- Skins do not come off before they go on. A pair this way round is a typo
  -- somebody would otherwise find in March as a negative contact time.
  if started is not null and ended is not null and ended < started then
    raise exception 'skin contact ended before it started';
  end if;
  if ran_from is not null and ran_to is not null and ran_to < ran_from then
    raise exception 'the press finished before it started';
  end if;
  if (p_detail ->> 'program_id') is not null and not exists (
    select 1 from term
     where id = (p_detail ->> 'program_id')::uuid and kind = 'press_program'
  ) then
    raise exception 'that is not a press program';
  end if;

  -- Pass one: read the parents and decide what may be pressed. Nothing is
  -- written until every source has been checked.
  for src in select value from jsonb_array_elements(p_sources)
  loop
    select * into n from node where id = (src ->> 'node_id')::uuid;
    if n.id is null then
      raise exception 'no lot with id %', src ->> 'node_id';
    end if;
    if n.status = 'closed' then
      raise exception '% is closed; there is nothing left in it to press', n.name;
    end if;
    if n.quantity is null then
      raise exception
        '% has never been weighed, and pressing it is the last moment anybody could. Weigh its bins first', n.name;
    end if;

    if parent_stage is null then
      parent_stage := n.stage;
    elsif parent_stage <> n.stage then
      raise exception
        'those lots are at different stages, so one press cannot be the right record for both';
    end if;

    want := coalesce((src ->> 'weight_lbs')::numeric, n.quantity);
    if want <= 0 then
      raise exception 'a press of % from % is not an amount', want, n.name;
    end if;
    if want > n.quantity then
      raise exception
        '% holds % and the press says %, so that is more fruit than there is',
        n.name, n.quantity, want;
    end if;

    parent_ids := parent_ids || n.id;
    weights    := weights || want;
    total_in   := total_in + want;

    select count(*) into i from unweighed_bin where node_id = n.id;
    waiting := waiting + i;
  end loop;

  child_stage := coalesce(
    (p_node ->> 'stage')::node_stage,
    case when parent_stage = 'bin' then 'ferment'::node_stage
         else 'maturation'::node_stage end);

  -- Pass two: check every destination before writing anything, so a press that
  -- is going to be refused does not half happen.
  for cut in select value from jsonb_array_elements(p_cuts)
  loop
    if (cut ->> 'cut_id') is not null and not exists (
      select 1 from term where id = (cut ->> 'cut_id')::uuid and kind = 'press_cut'
    ) then
      raise exception 'that is not a press cut';
    end if;
    if cut -> 'destinations' is null
       or jsonb_array_length(cut -> 'destinations') = 0 then
      raise exception 'a cut with no vessel to go into is not a cut';
    end if;
    for dst in select value from jsonb_array_elements(cut -> 'destinations')
    loop
      vol := (dst ->> 'volume_l')::numeric;
      if vol is null or vol <= 0 then
        raise exception 'a volume of % into a vessel is not a filling',
          coalesce(vol::text, 'nothing');
      end if;
      v_id := (dst ->> 'vessel_id')::uuid;
      if not exists (select 1 from vessel where id = v_id and active) then
        raise exception 'no active vessel with id %', v_id;
      end if;
      if exists (select 1 from placement where vessel_id = v_id and to_at is null) then
        raise exception
          'a vessel the juice is going into already holds a lot; rack it out first';
      end if;
      total_out := total_out + vol;
    end loop;
  end loop;

  -- One child per cut. Every child of one press draws the same share from every
  -- parent, because a hard press is made of the same fruit as the free run and
  -- in the same ratios. The cut is a fact about the lot rather than a second
  -- composition, which is what S-52 was waiting for.
  for cut in select value from jsonb_array_elements(p_cuts)
  loop
    child := gen_random_uuid();
    select coalesce(sum((d ->> 'volume_l')::numeric), 0) into cut_out
      from jsonb_array_elements(cut -> 'destinations') d;

    insert into node (id, stage, status, name, quantity, unit,
                      variety_id, vintage, non_vintage, product_type_id,
                      owner_id, created_by, attributes)
    select
      child, child_stage, 'open',
      coalesce(
        nullif(cut ->> 'name', ''),
        (select p.name from node p where p.id = parent_ids[1])
          || ' pressed'
          || coalesce(', ' || (select t.label from term t
                                where t.id = (cut ->> 'cut_id')::uuid), '')),
      cut_out, 'L',
      (select case when count(distinct p.variety_id) = 1
                   then (array_agg(distinct p.variety_id))[1] end
         from node p where p.id = any(parent_ids)),
      -- 0049. One vintage if every parent is of it, and non-vintage if
      -- they disagree or if any parent is itself NV. `count(distinct)`
      -- skips nulls, so the bool_and is what stops an NV parent and a
      -- 2024 parent producing a 2024 child.
      (select case when count(distinct p.vintage) = 1 and bool_and(not p.non_vintage)
                   then min(p.vintage) end
         from node p where p.id = any(parent_ids)),
      (select case when count(distinct p.vintage) = 1 and bool_and(not p.non_vintage)
                   then false else true end
         from node p where p.id = any(parent_ids)),
      coalesce((select case when count(distinct p.product_type_id) = 1
                            then (array_agg(distinct p.product_type_id))[1] end
                  from node p where p.id = any(parent_ids)),
               term_id('product_type', 'wine')),
      (select p.owner_id from node p where p.id = any(parent_ids)
        order by p.quantity desc nulls last limit 1),
      auth.uid(),
      coalesce(p_node -> 'attributes', '{}'::jsonb)
        || jsonb_strip_nulls(jsonb_build_object(
             'cut',              (cut ->> 'cut_id')::uuid,
             'cut_label',        (select t.label from term t
                                   where t.id = (cut ->> 'cut_id')::uuid),
             -- Named in spec.md Â§2 as an attribute of a node since the scaffold,
             -- and nothing wrote it until now.
             'whole_cluster_pct', wc));

    child_ids := child_ids || child;

    for dst in select value from jsonb_array_elements(cut -> 'destinations')
    loop
      insert into placement (node_id, vessel_id, volume_l)
      values (child, (dst ->> 'vessel_id')::uuid, (dst ->> 'volume_l')::numeric);
    end loop;

    -- Lineage by fruit weight, the same for every cut. The denominator is what
    -- the parents put in rather than what came out, so the shares sum to one and
    -- the press yield does not change what the wine is made of.
    for i in 1 .. array_length(parent_ids, 1)
    loop
      insert into lineage (parent_id, child_id, fraction)
      values (parent_ids[i], child,
              greatest(least(weights[i] / nullif(total_in, 0), 1), 0.00001));
    end loop;
  end loop;

  -- Take the fruit out of the parents.
  for i in 1 .. array_length(parent_ids, 1)
  loop
    select quantity into held from node where id = parent_ids[i];
    update node set quantity = greatest(held - weights[i], 0)
     where id = parent_ids[i];

    if held - weights[i] <= 0.0001 then
      update placement set to_at = occurred_at()
       where node_id = parent_ids[i] and to_at is null;
      get diagnostics emptied = row_count;
    end if;
  end loop;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'press'), 'node', child_ids[1], auth.uid(), 'observed',
     jsonb_strip_nulls(coalesce(p_detail, '{}'::jsonb) || jsonb_build_object(
       'lbs_in',          total_in,
       'litres_out',      total_out,
       'yield_l_per_ton', round(total_out / nullif(total_in, 0) * 2000, 2),
       'parents',         to_jsonb(parent_ids::text[]),
       'cuts',            to_jsonb(child_ids::text[]),
       -- Two timestamps, not three. The total is a subtraction, and storing it
       -- would be storing what is derived and inviting it to disagree.
       'skin_contact_minutes',
         case when started is not null and ended is not null
              then round(extract(epoch from (ended - started)) / 60.0)
         end,
       -- The other duration, and a different fact: how long the skins were on
       -- and how long the press ran are two things the form asks for separately
       -- and one of them is often a fraction of the other.
       'press_minutes',
         case when ran_from is not null and ran_to is not null
              then round(extract(epoch from (ran_to - ran_from)) / 60.0)
         end,
       'program_label',
         (select t.label from term t
           where t.id = (p_detail ->> 'program_id')::uuid))));

  perform resume_at(was_at);
  return jsonb_build_object(
    'node_id',         child_ids[1],
    'cuts',            to_jsonb(child_ids::text[]),
    'stage',           child_stage,
    'lbs_in',          total_in,
    'litres_out',      total_out,
    'yield_l_per_ton', round(total_out / nullif(total_in, 0) * 2000, 2),
    'bins_emptied',    emptied,
    'unweighed_left',  waiting,
    'event_id',        ev_id
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.rack(p_sources jsonb, p_destinations jsonb, p_data jsonb DEFAULT '{}'::jsonb, p_allow_overfill boolean DEFAULT false, p_node jsonb DEFAULT '{}'::jsonb, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  plan      jsonb;
  src       jsonb;
  dst       jsonb;
  par       jsonb;
  new_id    uuid;
  target    uuid;
  v_id      uuid;
  vol       numeric;
  held      numeric;
  p_node_id uuid;
  total_in  numeric;
  contributed numeric;
  remaining int;
  ev_id     uuid := gen_random_uuid();
  -- 0103. What each destination already held, by vessel. It is part of the
  -- blend and it is still in the vessel afterwards, which is the fact this
  -- function used to lose.
  absorbed   jsonb := '{}'::jsonb;
  absorbed_l numeric := 0;
begin
  perform happening_at(p_at);
  plan := rack_plan(p_sources, p_destinations);

  if jsonb_array_length(plan -> 'overfill') > 0 and not p_allow_overfill then
    raise exception 'that puts more in % than it holds; confirm the overfill to record it anyway',
      (plan -> 'overfill' -> 0 ->> 'name');
  end if;

  total_in := (plan ->> 'in_l')::numeric;

  if plan ->> 'kind' = 'move' then
    target := (plan ->> 'node_id')::uuid;
  else
    -- A new lot. Variety, vintage and product type survive only where every
    -- parent agrees; where they disagree the answer is genuinely nothing, and
    -- composition is derived from lineage rather than copied onto the child.
    new_id := coalesce((p_node ->> 'id')::uuid, gen_random_uuid());
    insert into node (id, stage, status, name, quantity, unit,
                      variety_id, vintage, non_vintage, product_type_id, owner_id, created_by,
                      attributes)
    select
      new_id,
      coalesce((p_node ->> 'stage')::node_stage, 'maturation'),
      'open',
      coalesce(p_node ->> 'name', 'Blend ' || to_char(occurred_at(), 'YYYY-MM-DD')),
      total_in,
      'L',
      (select case when count(distinct n.variety_id) = 1
                   then (array_agg(distinct n.variety_id))[1] end
         from node n where n.id = any(
           select (e ->> 'node_id')::uuid from jsonb_array_elements(plan -> 'parents') e)),
      -- 0049. A blend of two vintages is a non-vintage wine, which is a
      -- thing this schema could not say before and recorded as a blank.
      (select case when count(distinct n.vintage) = 1 and bool_and(not n.non_vintage)
                   then min(n.vintage) end
         from node n where n.id = any(
           select (e ->> 'node_id')::uuid from jsonb_array_elements(plan -> 'parents') e)),
      (select case when count(distinct n.vintage) = 1 and bool_and(not n.non_vintage)
                   then false else true end
         from node n where n.id = any(
           select (e ->> 'node_id')::uuid from jsonb_array_elements(plan -> 'parents') e)),
      (select case when count(distinct n.product_type_id) = 1
                   then (array_agg(distinct n.product_type_id))[1] end
         from node n where n.id = any(
           select (e ->> 'node_id')::uuid from jsonb_array_elements(plan -> 'parents') e)),
      -- One owner_id, because RLS scopes a client's view by it and a null here
      -- would hide the wine from everyone who part owns it. The largest
      -- contributor holds it and the mixing is recorded. See S-22.
      (select (e ->> 'owner_id')::uuid from jsonb_array_elements(plan -> 'parents') e
        where e ->> 'owner_id' is not null
        order by (e ->> 'volume_l')::numeric desc limit 1),
      auth.uid(),
      case when (plan ->> 'mixed_owners')::boolean
           then jsonb_build_object('mixed_ownership', true,
                                   'owners', (select jsonb_agg(distinct e -> 'owner_id')
                                                from jsonb_array_elements(plan -> 'parents') e))
           else '{}'::jsonb end;

    target := new_id;

    -- Lineage: each parent's share of the child, which is what
    -- block_composition multiplies along the path.
    --
    -- The denominator is what the parents put in, not what arrived in the
    -- vessel. Those differ by the loss, and dividing by the arrival would make
    -- the shares sum to something other than one, so losing five litres down a
    -- hose would change what the wine is made of. It does not.
    select sum((e ->> 'volume_l')::numeric) into contributed
      from jsonb_array_elements(plan -> 'parents') e;

    for par in select value from jsonb_array_elements(plan -> 'parents')
    loop
      insert into lineage (parent_id, child_id, fraction)
      values ((par ->> 'node_id')::uuid, new_id,
              greatest(least((par ->> 'volume_l')::numeric
                             / nullif(contributed, 0), 1), 0.00001));
    end loop;
  end if;

  -- Take the wine out of the sources.
  for src in select value from jsonb_array_elements(p_sources)
  loop
    v_id := (src ->> 'vessel_id')::uuid;
    vol  := (src ->> 'volume_l')::numeric;

    select p.node_id, p.volume_l into p_node_id, held
      from placement p where p.vessel_id = v_id and p.to_at is null;

    if held is null or held - vol <= 0.0001 then
      update placement set to_at = occurred_at()
       where vessel_id = v_id and to_at is null;
    else
      update placement set volume_l = held - vol
       where vessel_id = v_id and to_at is null;
    end if;

    -- The parent shrinks by what left it. It closes only if that empties it,
    -- which is 0013's rule and not this function's business.
    if plan ->> 'kind' = 'blend' then
      update node set quantity = greatest(coalesce(quantity, 0) - vol, 0)
       where id = p_node_id and quantity is not null;
    end if;
  end loop;

  -- A destination holding another lot has just become a parent, so its
  -- placement ends here too. It is absorbed whole rather than drawn from, so
  -- its quantity goes to nothing and 0013 closes it. Without this it would
  -- keep a volume while being in no vessel at all.
  if plan ->> 'kind' = 'blend' then
    for dst in select value from jsonb_array_elements(p_destinations)
    loop
      select p.node_id into p_node_id
        from placement p
       where p.vessel_id = (dst ->> 'vessel_id')::uuid and p.to_at is null;

      if p_node_id is not null and p_node_id <> target then
        select p.volume_l into held
          from placement p
         where p.vessel_id = (dst ->> 'vessel_id')::uuid and p.to_at is null;

        -- 0103. Remembered per vessel, because it goes back into that same
        -- vessel below. rack_plan already counts it as a parent's contribution,
        -- which is why the shares were right while the volume was not.
        absorbed := absorbed || jsonb_build_object(
          dst ->> 'vessel_id', coalesce(held, 0));
        absorbed_l := absorbed_l + coalesce(held, 0);

        update placement set to_at = occurred_at()
         where vessel_id = (dst ->> 'vessel_id')::uuid and to_at is null;

        -- Only what was in this vessel went into the blend. A lot already in
        -- the destination is not thereby consumed: the same lot may be sitting
        -- in a tank and eight other barrels, and closing it here would report
        -- four hundred litres as gone while they are still in the tank.
        update node set quantity = greatest(coalesce(quantity, 0) - coalesce(held, 0), 0)
         where id = p_node_id and quantity is not null;

        -- Whether it is finished is answered by where it is, not by a number
        -- somebody may never have recorded. If it is in no vessel at all then
        -- it is empty, and that is knowledge rather than a guess.
        select count(*) into remaining
          from placement where node_id = p_node_id and to_at is null;
        if remaining = 0 then
          update node
             set status    = 'closed',
                 closed_at = coalesce(closed_at, occurred_at())
           where id = p_node_id;
        end if;
      end if;
    end loop;
  end if;

  -- Put it in.
  for dst in select value from jsonb_array_elements(p_destinations)
  loop
    v_id := (dst ->> 'vessel_id')::uuid;
    -- What arrived, plus what was already standing there and has just been
    -- absorbed into this blend. 0014 wrote only the first of those, so a barrel
    -- holding 50 L that took 150 L read as 150 L afterwards and fifty litres of
    -- wine left the record while staying in the barrel.
    vol  := (dst ->> 'volume_l')::numeric
            + coalesce((absorbed ->> (dst ->> 'vessel_id'))::numeric, 0);

    select p.volume_l into held
      from placement p where p.vessel_id = v_id and p.to_at is null
       and p.node_id = target;

    if held is not null then
      -- 0141. The flag belongs to the amount somebody typed, so it follows the
      -- leg rather than the vessel. Absent stays null, which is nobody having
      -- said, and is what every leg written before today means.
      update placement set volume_l = held + vol,
             volume_provenance = placement_provenance(dst)
       where vessel_id = v_id and to_at is null and node_id = target;
    else
      insert into placement (node_id, vessel_id, volume_l, volume_provenance)
      values (target, v_id, vol, placement_provenance(dst));
    end if;
  end loop;

  -- The blend was minted with what arrived, before anything was known about
  -- what the destinations already held. A lot whose quantity disagrees with the
  -- placements holding it is the shape T0-2 exists to prevent, and here it was
  -- low by exactly the wine that was already in the vessel.
  if plan ->> 'kind' = 'blend' and absorbed_l > 0 then
    update node set quantity = coalesce(total_in, 0) + absorbed_l
     where id = target;
  end if;

  -- A move keeps its identity and loses only what the hose kept.
  if plan ->> 'kind' = 'move' then
    update node set quantity = greatest(coalesce(quantity, 0)
                                        - ((plan ->> 'loss_l')::numeric), 0)
     where id = target and quantity is not null;
  end if;

  -- One event for the whole transfer. Loss is not in it: it is the difference
  -- between the volumes, and storing it would be a second source of truth for
  -- a number anyone can subtract.
  insert into event (id, operation_id, subject_type, subject_id, by_user, data, provenance)
  values (ev_id, term_id('operation', 'rack'), 'node', target, auth.uid(),
          p_data || jsonb_build_object(
            'sources', p_sources,
            'destinations', p_destinations,
            'kind', plan ->> 'kind',
            'overfilled', jsonb_array_length(plan -> 'overfill') > 0),
          'observed');

  perform resume_at(was_at);
  return plan || jsonb_build_object('node_id', target, 'event_id', ev_id,
                                   -- So a screen can say what is in the vessel
                                   -- rather than only what went down the hose.
                                   'absorbed_l', absorbed_l);
end;
$function$;



-- ---------------------------------------------------------------------------
-- Picks take a time too
-- ---------------------------------------------------------------------------

-- The same four changes, to the verbs a pick is made of. Picks were the first
-- thing named when this was asked for ("batched the things I did throughout the
-- day"), and they are the one record intake cannot reconstruct if it lands on
-- the wrong day.
--
-- One more change in `add_bin_to_pick`, and it is a fix rather than a feature.
-- A pick's name carries its date, formatted from `now()` in the database's
-- zone, which is UTC. After five in the afternoon in Oregon that is already
-- tomorrow, and three picks entered at 19:18 on 2026-09-17 are named "Sep 18"
-- for exactly that reason. The date is now read in the winery's zone, the same
-- constant S-57 already records.
drop function if exists add_bin_to_pick(jsonb, uuid, numeric, numeric, numeric);
drop function if exists add_bins_to_pick(jsonb, uuid[], integer, uuid, text, numeric, uuid, text, numeric, numeric);
drop function if exists weigh_bins(uuid, uuid[], numeric, text, uuid, text);
drop function if exists finish_pick(uuid);

CREATE OR REPLACE FUNCTION public.add_bin_to_pick(p_pick jsonb, p_vessel_id uuid, p_fill_pct numeric DEFAULT NULL::numeric, p_net_lbs numeric DEFAULT NULL::numeric, p_gross_lbs numeric DEFAULT NULL::numeric, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  pick_id   uuid := coalesce((p_pick ->> 'id')::uuid, gen_random_uuid());
  existing  node%rowtype;
  holder    uuid;
  place_id  uuid := gen_random_uuid();
  auto_name text;
  blk_name  text;
  var_label text;
begin
  perform happening_at(p_at);
  -- 0092. Three ways to say how much, and exactly one of them. A number whose
  -- unit is ambiguous is wrong about a tenth of the time and never says so:
  -- somebody at a pallet scale reads 923 and that is the bin as well as the
  -- fruit.
  if (case when p_net_lbs is not null then 1 else 0 end)
   + (case when p_gross_lbs is not null then 1 else 0 end)
   + (case when p_fill_pct is not null then 1 else 0 end) > 1 then
    raise exception
      'say one of them: the fruit, the scale reading with the bin on it, or how full. The others are worked out';
  end if;
  if p_net_lbs is not null and p_net_lbs <= 0 then
    raise exception 'a bin with no fruit in it is not part of a pick';
  end if;
  if p_gross_lbs is not null and p_gross_lbs <= bin_tare_lbs(p_vessel_id) then
    raise exception
      'that bin weighs % empty, so a scale reading of % has no fruit in it',
      bin_tare_lbs(p_vessel_id), p_gross_lbs;
  end if;

  -- The tare is not needed until the scale, and asking for it here would make a
  -- vineyard refuse a bin because an office field is blank. But the bin has to
  -- be a picking bin: fruit tipped into a barrel is a different mistake and it
  -- should not be recorded as a pick.
  if not exists (
    select 1 from vessel v
      join term vt on vt.id = v.type_id and vt.kind = 'vessel_type'
     where v.id = p_vessel_id
       and v.active
       and coalesce((vt.attributes ->> 'intake_bin')::boolean, false)
  ) then
    raise exception
      'that is not an active picking bin, so fruit cannot be recorded into it';
  end if;

  select node_id into holder
    from placement where vessel_id = p_vessel_id and to_at is null;
  if holder = pick_id then
    raise exception 'that bin is already part of this pick';
  end if;
  if holder is not null then
    raise exception 'that bin already holds other fruit; empty it before filling it again';
  end if;

  select * into existing from node where id = pick_id;

  if existing.id is null then
    select concat_ws(' ', v.name, b.name) into blk_name
      from block b
      left join vineyard v on v.id = b.vineyard_id
     where b.id = (p_pick ->> 'block_id')::uuid;
    select t.label into var_label from term t
     where t.kind = 'variety' and t.id = (p_pick ->> 'variety_id')::uuid;

    auto_name := nullif(
      trim(both ' ,' from concat_ws(' ', (p_pick ->> 'vintage'), var_label, blk_name)),
      '');
    auto_name := case when auto_name is null then null
                      else auto_name || ', ' || to_char(occurred_at() at time zone 'America/Los_Angeles', 'Mon DD') end;

    insert into node
      (id, stage, status, name, variety_id, vintage, block_id,
       quantity, unit, attributes, owner_id, created_by)
    values
      (pick_id, 'bin', 'open',
       coalesce(nullif(p_pick ->> 'name', ''), auto_name,
                'Pick ' || to_char(occurred_at() at time zone 'America/Los_Angeles', 'YYYY-MM-DD')),
       (p_pick ->> 'variety_id')::uuid,
       (p_pick ->> 'vintage')::int,
       (p_pick ->> 'block_id')::uuid,
       -- Not zero. Zero is a weight and this is the absence of one, and a pick
       -- reading 0 lbs until somebody weighs it is the A13 shape at the exact
       -- moment T1-4 exists to protect. An estimate in the bins does not change
       -- that: the lot's quantity is what the scale said.
       null,
       'lbs',
       coalesce(p_pick -> 'attributes', '{}'::jsonb),
       coalesce((p_pick ->> 'owner_id')::uuid, facility_party_id()),
       auth.uid());
  elsif existing.stage <> 'bin' then
    raise exception 'that lot is not a pick, so bins cannot be added to it';
  elsif existing.status = 'closed' then
    raise exception 'that pick is closed; its fruit has already gone somewhere';
  end if;

  insert into placement (id, node_id, vessel_id, fill_pct, net_lbs, gross_lbs)
  values (place_id, pick_id, p_vessel_id, p_fill_pct, p_net_lbs, p_gross_lbs);

  perform resume_at(was_at);
  return jsonb_build_object(
    'node_id',      pick_id,
    'placement_id', place_id,
    'bins',         (select count(*) from placement
                      where node_id = pick_id and to_at is null),
    'unweighed',    (select count(*) from unweighed_bin where node_id = pick_id)
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.add_bins_to_pick(p_pick jsonb, p_vessel_ids uuid[] DEFAULT NULL::uuid[], p_new_count integer DEFAULT 0, p_new_type_id uuid DEFAULT NULL::uuid, p_name_prefix text DEFAULT NULL::text, p_fill_pct numeric DEFAULT NULL::numeric, p_owner_id uuid DEFAULT NULL::uuid, p_on_loan_from text DEFAULT NULL::text, p_net_lbs numeric DEFAULT NULL::numeric, p_gross_lbs numeric DEFAULT NULL::numeric, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  pick_id  uuid := coalesce((p_pick ->> 'id')::uuid, gen_random_uuid());
  prefix   text := btrim(coalesce(p_name_prefix, 'Bin'));
  lender   text := nullif(btrim(coalesce(p_on_loan_from, '')), '');
  bag      jsonb;
  next_n   int;
  cap      numeric;
  new_id   uuid;
  made     text[] := '{}';
  v_id     uuid;
  i        int;
  result   jsonb;
begin
  perform happening_at(p_at);
  if coalesce(p_new_count, 0) = 0
     and coalesce(array_length(p_vessel_ids, 1), 0) = 0 then
    raise exception 'no bins were named and none were asked for, so there is nothing to add';
  end if;
  if coalesce(p_new_count, 0) < 0 or coalesce(p_new_count, 0) > 40 then
    raise exception '% is not a number of bins to register at once', p_new_count;
  end if;

  if lender is not null and p_owner_id is not null then
    raise exception
      'a bin is either on loan from % or owned by a party here, and this says both', lender;
  end if;

  if coalesce(p_new_count, 0) > 0 then
    if prefix = '' then
      raise exception 'new bins need something to be called';
    end if;
    if p_new_type_id is null then
      raise exception 'new bins need a type, so the scale knows what they weigh empty';
    end if;
    if not exists (
      select 1 from term
       where id = p_new_type_id and kind = 'vessel_type'
         and coalesce((attributes ->> 'intake_bin')::boolean, false)
    ) then
      raise exception 'that is not a picking bin type, so fruit is not weighed in it';
    end if;

    bag := '{}'::jsonb;
    if lender is not null then
      bag := jsonb_build_object('borrowed', true, 'on_loan_from', lender);
    elsif p_owner_id is not null and p_owner_id is distinct from facility_party_id() then
      bag := jsonb_build_object('borrowed', true);
    end if;

    select coalesce(max((regexp_match(v.name, '^' || prefix || '\s*(\d+)$'))[1]::int), 0) + 1
      into next_n
      from vessel v
     where v.name ~ ('^' || prefix || '\s*\d+$');

    select v.capacity_l into cap
      from vessel v
     where v.type_id = p_new_type_id
     order by v.created_at desc
     limit 1;

    for i in 0 .. p_new_count - 1
    loop
      new_id := gen_random_uuid();
      insert into vessel (id, type_id, name, capacity_l, owner_id, attributes)
      values (new_id, p_new_type_id, prefix || (next_n + i)::text, cap,
              p_owner_id, bag);
      made := made || (prefix || (next_n + i)::text);
      p_vessel_ids := coalesce(p_vessel_ids, '{}'::uuid[]) || new_id;
    end loop;
  end if;

  -- The same figure into each bin, because they went out together and nobody
  -- fills one to 900 and the next to 400 on purpose. A bin that differs gets
  -- corrected on its own afterwards.
  foreach v_id in array p_vessel_ids
  loop
    result := add_bin_to_pick(p_pick || jsonb_build_object('id', pick_id), v_id,
                              p_fill_pct, p_net_lbs, p_gross_lbs);
    pick_id := (result ->> 'node_id')::uuid;
  end loop;

  perform resume_at(was_at);
  return jsonb_build_object(
    'node_id',    pick_id,
    'registered', to_jsonb(made),
    'bins',       (select count(*) from placement
                    where node_id = pick_id and to_at is null),
    'unweighed',  (select count(*) from unweighed_bin where node_id = pick_id)
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.weigh_bins(p_node_id uuid, p_vessel_ids uuid[], p_gross_lbs numeric, p_note text DEFAULT NULL::text, p_supersedes uuid DEFAULT NULL::uuid, p_photo_path text DEFAULT NULL::text, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  n       node%rowtype;
  n_bins  int := coalesce(array_length(p_vessel_ids, 1), 0);
  n_here  int;
  tare    numeric := 0;
  net     numeric;
  v_id    uuid;
  already text;
  ev_id   uuid := gen_random_uuid();
  total   numeric;
begin
  perform happening_at(p_at);
  if n_bins = 0 then
    raise exception 'no bins were named, so there is nothing this weight is of';
  end if;
  if p_gross_lbs is null or p_gross_lbs <= 0 then
    raise exception 'a gross weight of % is not a scale reading',
      coalesce(p_gross_lbs::text, 'nothing');
  end if;

  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no pick with id %', p_node_id;
  end if;
  if n.stage <> 'bin' then
    raise exception 'that lot is not a pick, so it is not weighed in bins';
  end if;
  if n.status = 'closed' then
    raise exception 'that pick is closed; its fruit has already gone somewhere';
  end if;

  select count(*) into n_here
    from placement
   where node_id = p_node_id and to_at is null and vessel_id = any(p_vessel_ids);
  if n_here <> n_bins then
    raise exception
      'some of those bins do not hold this pick, so this reading is not of it';
  end if;

  -- Already weighed, unless this is the correction of the reading that did it.
  -- Without the guard a second reading of the same bins adds its fruit a second
  -- time and the pick quietly doubles, which is invisible from every screen.
  select string_agg(u.bin_name, ', ' order by u.bin_name) into already
    from (
      select v.name as bin_name
        from unnest(p_vessel_ids) as x(vessel_id)
        join vessel v on v.id = x.vessel_id
       where not exists (
         select 1 from unweighed_bin ub
          where ub.node_id = p_node_id and ub.vessel_id = x.vessel_id)
    ) u;
  if already is not null and p_supersedes is null then
    raise exception
      'these bins have been weighed already: %. Correct that weighing rather than adding a second one',
      already;
  end if;

  if p_supersedes is not null and not exists (
    select 1 from event
     where id = p_supersedes
       and subject_type = 'node' and subject_id = p_node_id
       and operation_id = term_id('operation', 'weigh')
  ) then
    raise exception 'there is no weighing of this pick with id % to correct', p_supersedes;
  end if;

  foreach v_id in array p_vessel_ids loop
    tare := tare + bin_tare_lbs(v_id);
  end loop;

  net := p_gross_lbs - tare;
  if net <= 0 then
    raise exception
      'a gross of % lbs over bins weighing % lbs empty leaves % lbs of fruit, so one of those numbers is wrong',
      p_gross_lbs, tare, net;
  end if;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'weigh'), 'node', p_node_id, auth.uid(), 'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'gross_lbs',  p_gross_lbs,
       'tare_lbs',   tare,
       'net_lbs',    net,
       'bins',       to_jsonb(p_vessel_ids::text[]),
       'note',       nullif(p_note, ''),
       -- Evidence, not decoration. A path here means somebody photographed the
       -- display; its absence means they did not, and the two must not read the
       -- same, which is why it is stripped rather than stored as an empty string.
       'photo_path', nullif(btrim(coalesce(p_photo_path, '')), ''),
       'supersedes', p_supersedes)));

  -- Recomputed from the events rather than added to, so a correction lands
  -- without anybody working out what the old reading contributed. The events are
  -- the record; quantity is the schema's place to keep the answer.
  select coalesce(sum((e.data ->> 'net_lbs')::numeric), 0) into total
    from event e
   where e.subject_type = 'node' and e.subject_id = p_node_id
     and e.operation_id = term_id('operation', 'weigh')
     and not exists (
       select 1 from event s
        where s.subject_type = 'node' and s.subject_id = p_node_id
          and s.operation_id = term_id('operation', 'weigh')
          and (s.data ->> 'supersedes')::uuid = e.id);

  update node set quantity = total, unit = 'lbs' where id = p_node_id;

  perform resume_at(was_at);
  return jsonb_build_object(
    'event_id',  ev_id,
    'gross_lbs', p_gross_lbs,
    'tare_lbs',  tare,
    'net_lbs',   net,
    'total_lbs', total,
    -- Said back, so the screen can ask once more rather than pretend it did not
    -- notice. Wanting a thing and requiring it differ in what happens next, not
    -- in whether anybody mentions it.
    'photographed', p_photo_path is not null and btrim(p_photo_path) <> '',
    'unweighed', (select count(*) from unweighed_bin where node_id = p_node_id)
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.finish_pick(p_node_id uuid, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  n         node%rowtype;
  waiting   int;
  bins      int;
begin
  perform happening_at(p_at);
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
     set attributes = attributes || jsonb_build_object('picking_finished_at', occurred_at())
   where id = p_node_id;

  perform resume_at(was_at);
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
$function$;



grant execute on function add_bin_to_pick(jsonb, uuid, numeric, numeric, numeric, timestamptz) to authenticated;
grant execute on function add_bins_to_pick(jsonb, uuid[], integer, uuid, text, numeric, uuid, text, numeric, numeric, timestamptz) to authenticated;
grant execute on function weigh_bins(uuid, uuid[], numeric, text, uuid, text, timestamptz) to authenticated;
grant execute on function finish_pick(uuid, timestamptz) to authenticated;

update capability
   set fields = fields || '[{"key": "at", "type": "timestamptz", "label": "When", "param": "p_at", "required": false,
                             "hint": "Blank means now. A time earlier today or on an earlier day is recorded as entered late."}]'::jsonb
 where fn = 'weigh_bins'
   and not exists (select 1 from jsonb_array_elements(fields) f where f ->> 'param' = 'p_at');

-- **When a pick was picked.** `fruit_log.picked` was the date the pick's row was
-- written, taken in UTC. Both halves are wrong now. A pick entered at the end of
-- the day with the morning's time on its bins was picked in the morning; and a
-- UTC date puts an Oregon evening on the next day. It is now the date the
-- pick's first bin went in, in the winery's zone, falling back to the row's own
-- time for a pick with no bins, which cannot exist through the app and can
-- through a hand insert.
--
-- The view's column list does not change, only one expression, so it is
-- replaced in place. Three picks move: the Tuckaway Chardonnay picks, entered
-- at 19:18 on Thursday 2026-09-17, read the 17th instead of the 18th.
create or replace view fruit_log with (security_invoker = true) as
 SELECT n.id,
    n.name,
    (COALESCE(( SELECT min(p.from_at) AS min
           FROM placement p
          WHERE p.node_id = n.id), n.created_at) AT TIME ZONE 'America/Los_Angeles'::text)::date AS picked,
    n.created_at,
    n.vintage,
    n.non_vintage,
    n.status,
    t.label AS variety,
    vy.name AS vineyard,
    b.name AS block,
    n.quantity AS lbs,
    round(n.quantity / 2000.0, 3) AS tons,
    ( SELECT count(*) AS count
           FROM placement p
          WHERE p.node_id = n.id) AS bins,
    ( SELECT count(*) AS count
           FROM placement p
          WHERE p.node_id = n.id AND p.to_at IS NULL) AS bins_held,
    ( SELECT count(DISTINCT (e.data -> 'bins'::text) ->> 0) AS count
           FROM event e
          WHERE e.subject_type = 'node'::text AND e.subject_id = n.id AND e.operation_id = term_id('operation'::text, 'weigh'::text)) AS bins_weighed
   FROM node n
     LEFT JOIN term t ON t.id = n.variety_id
     LEFT JOIN block b ON b.id = n.block_id
     LEFT JOIN vineyard vy ON vy.id = b.vineyard_id
  WHERE n.stage = 'bin'::node_stage;

grant execute on function start_press(uuid[], uuid, jsonb, jsonb, timestamptz)      to authenticated;
grant execute on function draw_cut(uuid, uuid, numeric, uuid, text, text, timestamptz) to authenticated;
grant execute on function draw_to_level(uuid, uuid, numeric, uuid, text, timestamptz) to authenticated;
grant execute on function finish_press(uuid, jsonb, timestamptz)                     to authenticated;
grant execute on function press(jsonb, jsonb, jsonb, jsonb, timestamptz)             to authenticated;
grant execute on function rack(jsonb, jsonb, jsonb, boolean, jsonb, timestamptz)     to authenticated;

-- The contract says so. `press` and `rack` are exempt from the capability
-- registry already, for reasons recorded against them; the four steps of a
-- press are verbs a periphery calls, and a periphery reading the contract should
-- see that each one takes a time.
update capability
   set fields = fields || '[{"key": "at", "type": "timestamptz", "label": "When", "param": "p_at", "required": false,
                             "hint": "Blank means now. A time earlier today or on an earlier day is recorded as entered late."}]'::jsonb
 where fn in ('start_press', 'draw_cut', 'draw_to_level', 'finish_press')
   and not exists (select 1 from jsonb_array_elements(fields) f where f ->> 'param' = 'p_at');

do $$
declare
  f text;
begin
  -- One of each. An overload left behind would give PostgREST two functions by
  -- one name and a periphery no way to say which it meant, and it would not show
  -- until somebody called it.
  foreach f in array array['start_press', 'draw_cut', 'draw_to_level', 'finish_press', 'press', 'rack',
                           'add_bin_to_pick', 'add_bins_to_pick', 'weigh_bins', 'finish_pick', 'node_history']
  loop
    if (select count(*) from pg_proc where proname = f and pronamespace = 'public'::regnamespace) <> 1 then
      raise exception 'there is more than one %, so a caller cannot say which it means', f;
    end if;
  end loop;

  -- Outside a verb, when it happened is now.
  if occurred_at() <> now() then
    raise exception 'occurred_at() is not now() outside a verb, so every ordinary write would be misdated';
  end if;
end $$;
