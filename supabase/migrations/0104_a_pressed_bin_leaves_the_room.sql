-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Three things the winemaker found in one message: a client's tank is
--           not a bin to return, the bins to return list is about bins, and
--           bins that go into a press leave the room they were standing in."
-- Depends on: [supabase/migrations/0036_bins_on_loan.sql,
--              supabase/migrations/0090_a_press_takes_bins.sql,
--              supabase/migrations/0098_a_vessel_arrives_in_a_number.sql,
--              supabase/migrations/0103_racking_keeps_what_was_already_there.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (where a bin is follows from what was done with it),
--                  AR-E7 (a rule about picking bins does not become a rule about
--                  every vessel by being moved into a general function)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- *"I added 4 grundies for Domain Publique but they're showing up in bins to
-- return. Also when I pressed the Pearlstad bins it should have taken the
-- picking bins out of the cold room and emptied them."*
--
-- **The first one is mine, from `0098`.** `register_bins` in `0085` marked a bin
-- borrowed when a party other than this winery owned it, which is right for a
-- picking bin: somebody else's bin goes back. `0098` generalised that function
-- into `add_vessels` and carried the rule with it, so every vessel a client owns
-- became a thing to return. Four Grundy tanks belonging to Domain Publique were
-- the first to arrive through the new path and went straight onto the list.
--
-- A lender still marks anything borrowed, because naming a lender is a statement
-- that the thing goes back. Party ownership no longer does, except for bins,
-- where it is `0036`'s rule and stays.
--
-- **The second one was waiting to happen.** `bin_to_return` selects any active
-- vessel flagged borrowed and empty, with nothing about it being a bin, on a
-- screen called Bins to return. Even with `add_vessels` fixed, one tank marked
-- on loan would have appeared there. It is now typed, which is what the name
-- always claimed.
--
-- **The third is a fact the app had and did not use.** `start_press` empties the
-- bins that go into it, which is `0090` and which worked: the five Pearlstad
-- bins hold nothing. What it did not do is move them, so they stayed on the map
-- in the cold room they had been wheeled out of. They now go to where the press
-- stands, through `move_vessels`, so a bin moved by a press and a bin moved by
-- hand are moved by the same code.
--
-- Where the press has no room of its own, nothing moves: an unassigned vessel is
-- one nobody can find, and that is worse than one in the wrong room.

begin;

-- ---------------------------------------------------------------------------
-- A client's tank is not on loan
-- ---------------------------------------------------------------------------

create or replace function add_vessels(
  p_vessel jsonb,
  p_count  int default 1
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  want    int    := coalesce(p_count, 1);
  lender  text   := nullif(btrim(coalesce(p_vessel -> 'attributes' ->> 'on_loan_from', '')), '');
  owner   uuid   := (p_vessel ->> 'owner_id')::uuid;
  given   text   := btrim(coalesce(p_vessel ->> 'name', ''));
  bag     jsonb  := coalesce(p_vessel -> 'attributes', '{}'::jsonb);
  is_bin  boolean;
  prefix  text;
  next_n  int;
  made    text[] := '{}';
  ids     uuid[] := '{}';
  one     uuid;
  nm      text;
  i       int;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here adds a vessel'
      using errcode = 'insufficient_privilege';
  end if;

  if want <= 0 then
    raise exception 'how many vessels?';
  end if;
  if want > 40 then
    raise exception '% is not a number of vessels to add at once', want;
  end if;

  if (p_vessel ->> 'type_id') is null then
    raise exception 'a vessel is of some type, and this one says none';
  end if;

  if lender is not null and owner is not null then
    raise exception
      'a vessel is either on loan from % or owned by a party here, and this says both', lender;
  end if;

  select coalesce((t.attributes ->> 'intake_bin')::boolean, false) into is_bin
    from term t where t.id = (p_vessel ->> 'type_id')::uuid;

  if lender is not null then
    -- Naming a lender says it goes back, whatever kind of thing it is.
    bag := bag || jsonb_build_object('borrowed', true, 'on_loan_from', lender);
  elsif is_bin and owner is not null and owner is distinct from facility_party_id() then
    -- 0036's rule, and it is about bins. A client's tank standing in this
    -- winery is theirs and is not a thing on the returns list, which is what
    -- 0098 accidentally said by carrying this line out of register_bins.
    bag := bag || jsonb_build_object('borrowed', true);
  end if;

  if given = '' then
    if lender is null then
      raise exception 'a new vessel needs something to be called';
    end if;
    prefix := lender_prefix(lender);
  else
    prefix := btrim(regexp_replace(given, '\s*\d+$', ''));
    if prefix = '' then
      prefix := given;
    end if;
  end if;

  if want = 1 and given <> '' then
    one := coalesce((p_vessel ->> 'id')::uuid, gen_random_uuid());
    insert into vessel
      (id, type_id, name, capacity_l, location_id, owner_id, attributes,
       has_glycol, setpoint_c, mode)
    values
      (one, (p_vessel ->> 'type_id')::uuid, given,
       (p_vessel ->> 'capacity_l')::numeric,
       (p_vessel ->> 'location_id')::uuid,
       owner, bag,
       coalesce((p_vessel ->> 'has_glycol')::boolean, false),
       (p_vessel ->> 'setpoint_c')::numeric,
       coalesce((p_vessel ->> 'mode')::thermal_mode, 'off'));
    return jsonb_build_object(
      'made', to_jsonb(array[given]), 'ids', to_jsonb(array[one]),
      'count', 1, 'from', given, 'to', given, 'prefix', prefix);
  end if;

  select coalesce(max((regexp_match(v.name, '^' || prefix || '\s*(\d+)$'))[1]::int), 0) + 1
    into next_n
    from vessel v
   where v.name ~ ('^' || prefix || '\s*\d+$');

  for i in 0 .. want - 1
  loop
    nm  := prefix || (next_n + i)::text;
    one := gen_random_uuid();
    insert into vessel
      (id, type_id, name, capacity_l, location_id, owner_id, attributes,
       has_glycol, setpoint_c, mode)
    values
      (one, (p_vessel ->> 'type_id')::uuid, nm,
       (p_vessel ->> 'capacity_l')::numeric,
       (p_vessel ->> 'location_id')::uuid,
       owner, bag,
       coalesce((p_vessel ->> 'has_glycol')::boolean, false),
       (p_vessel ->> 'setpoint_c')::numeric,
       coalesce((p_vessel ->> 'mode')::thermal_mode, 'off'));
    made := made || nm;
    ids  := ids || one;
  end loop;

  return jsonb_build_object(
    'made',   to_jsonb(made),
    'ids',    to_jsonb(ids),
    'count',  want,
    'from',   made[1],
    'to',     made[array_length(made, 1)],
    'prefix', prefix);
end;
$$;

revoke all on function add_vessels(jsonb, int) from public;
grant execute on function add_vessels(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------------
-- The bins to return list is about bins
-- ---------------------------------------------------------------------------

create or replace view bin_to_return with (security_invoker = true) as
select
  v.id      as vessel_id,
  v.name    as bin_name,
  vt.label  as bin_type,
  v.owner_id,
  coalesce(nullif(btrim(v.attributes ->> 'on_loan_from'), ''), p.name) as owed_to,
  v.location_id
from vessel v
join term vt on vt.id = v.type_id and vt.kind = 'vessel_type'
  -- 0104. What the screen has always been called. Without this, anything
  -- flagged borrowed lands on it, which is how four tanks belonging to a
  -- client appeared on a list of bins.
  and coalesce((vt.attributes ->> 'intake_bin')::boolean, false)
left join party p on p.id = v.owner_id
where v.active
  and coalesce((v.attributes ->> 'borrowed')::boolean, false)
  and not exists (
    select 1 from placement pl where pl.vessel_id = v.id and pl.to_at is null);

comment on view bin_to_return is
  'Picking bins that belong to somebody else and are empty. Bins only: a '
  'borrowed tank is somebody else''s tank and is not on a returns list. See '
  '0036 and 0104.';

-- ---------------------------------------------------------------------------
-- Bins that go into a press leave the room they were in
-- ---------------------------------------------------------------------------

create or replace function start_press(
  p_vessel_ids      uuid[],
  p_press_vessel_id uuid,
  p_node            jsonb default '{}'::jsonb,
  p_detail          jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
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
  update placement set to_at = now()
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
     set status = 'closed', closed_at = coalesce(n.closed_at, now())
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
$$;


commit;
