-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A press started from bins that were weighed together records the
--           weight that went in, and a cellar hand can finish a press."
-- Depends on: [supabase/migrations/0143_a_record_can_say_when.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  scripts/smoke.ts,
--                  supabase/migrations/0148_reds_go_into_fermenters.sql,
--                  supabase/migrations/0149_a_blend_can_be_split_by_juice.sql]
-- Axioms enforced: A13. A press that took in a weighed pick and recorded
--                  nothing going in was a success that lost the number every
--                  yield is read from.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- Both found on 2026-09-27 by scripts/smoke.ts, the first thing in this
-- repository to run a harvest day through the apps' own client code as an
-- ordinary cellar hand.
--
-- **A weighed pick pressed as nothing.** A weighed pick contributes its scale
-- weight in proportion to the share of it going in: the estimate of the bins
-- going in over the estimate of all its bins. The two halves were not the same
-- kind of number. The whole used `bin_fruit.lbs`, falling back to the fill
-- percentage times a full bin; the share going in used `bin_fruit.lbs` alone.
-- `bin_fruit.lbs` is only known for a bin weighed on its own or typed in, so a
-- pick entered by fill percentage and weighed two bins at a time, which is how
-- this winery picks, had a share of zero: 1336 lbs weighed, 0 lbs in, no yield.
-- The Grüner Veltliner and the ESV Chardonnay were both weighed that way and
-- neither had been pressed yet. The share now uses the same estimate as the
-- whole, and a share with no estimate at all falls to counting bins, which is
-- what the next branch already did. An unweighed pick is unchanged: its bins
-- still contribute only what somebody measured, and the press says "at least".
--
-- **A cellar hand could not finish a press.** `finish_press` sets the load's
-- unit to litres, the load was created with no unit, and `unit` is not one of
-- the columns a cellar user may change (`node_cellar_columns`). Every finish by
-- anybody but an administrator was refused. A load now starts in litres, which
-- is what its quantity is in from the moment it has one, so finishing changes
-- nothing a cellar hand is barred from. Open loads made before this get the
-- same unit, so a press already running can be finished too.

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
    -- 0147. What the bins going in are estimated at, the same way the whole
    -- pick is below, so the two halves of the ratio are the same kind of number.
    (select coalesce(sum(coalesce(a.est, 0)), 0)
       from all_bins a
      where a.placement_id in (select g2.placement_id from going_in g2
                                where g2.node_id = g.node_id)) as share_est,
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
      when weighed is not null and whole_est > 0 and share_est > 0
        then weighed * (share_est / whole_est)
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
    null, 'L',
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
               when weighed is not null and whole_est > 0 and share_est > 0
                 then weighed * (share_est / whole_est)
               when weighed is not null and whole_bins > 0
                 then weighed * (chosen_bins::numeric / whole_bins)
               else chosen_est
             end / total_lbs, 6)
      from putting_in
     where case
             when weighed is not null and whole_est > 0 and share_est > 0
               then weighed * (share_est / whole_est)
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


update node set unit = 'L' where stage = 'load' and status = 'open' and unit is null;

grant execute on function start_press(uuid[], uuid, jsonb, jsonb, timestamptz) to authenticated;
