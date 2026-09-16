-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A press is loaded with bins rather than with whole picks, because a
--           pick does not fit in a press and the fruit that is left is still
--           fruit that is left."
-- Depends on: [supabase/migrations/0054_a_spent_pick_is_spent.sql,
--              supabase/migrations/0087_a_bin_holds_pounds.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (a pick is spent when its last bin leaves, which is a
--                  fact about its placements rather than a flag somebody sets),
--                  A13 (a pick closed with fruit still in bins would be fruit
--                  the app says is gone)
-- Open sorries: S-85 (a part-pressed pick's weighed quantity still describes
--                the whole pick)
-- ---------------------------------------------------------------------------
--
-- The winemaker, with five bins of Chardonnay and a 1.2 tonne press: *"for the
-- press log it should be bins grouped by pick, not just selecting a whole pick.
-- Like I can't fit all 5 bins into one press."* And on the shape of it:
-- *"pressing just needs to click the Pearlstaad pick, then that brings up the 5
-- bins so I can select from them into the press."*
--
-- **`0052` took whole lots and `0054` closed them.** Starting a press emptied
-- every placement a source lot had and marked the lot spent, which was right
-- when a pick was assumed to go into a press in one go. It is wrong the moment
-- a pick is bigger than the press, which is most picks: five half tonne bins
-- against a 1.2 tonne press is two loads and a bit.
--
-- **So the source is a set of vessels, not a set of lots.** Somebody points at
-- three bins. The lots come from the bins rather than the other way round,
-- which is also how the screen he described works: open the pick, see its bins,
-- choose some.
--
-- **A pick is now spent when its last bin empties, and not before.** `0054`
-- closed the sources outright, and repeating that here would close a pick with
-- two bins still full of fruit, which is A13 with fruit in it: the app would
-- say the fruit is gone and it would be standing on the pad. The rule `0054`
-- was reaching for survives, in its true form: a pick with nothing in any
-- vessel is spent.
--
-- **Shares are by what went in.** A load made of two bins at 850 and one at 400
-- is not three equal thirds of anything, and `bin_fruit` has known what is in
-- each bin since `0087`. Where nothing is known the fallback is the one `0052`
-- already chose, equal shares, and the caller is told how many bins were guessed
-- at rather than measured.

begin;

-- Dropped rather than replaced. The first parameter meant lots and now means
-- the vessels holding them, and `create or replace` cannot rename a parameter,
-- so the old signature would have survived beside the new one, taking lot ids
-- into a list of vessels and finding nothing. Every caller is revisited because
-- the call stops working, which is the only reliable way to move a meaning.
drop function if exists start_press(uuid[], uuid, jsonb, jsonb);

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

revoke all on function start_press(uuid[], uuid, jsonb, jsonb) from public;
grant execute on function start_press(uuid[], uuid, jsonb, jsonb) to authenticated;

comment on function start_press(uuid[], uuid, jsonb, jsonb) is
  'Loads a press from a set of vessels, which for a pick means some of its bins. '
  'The lots come from the vessels. A pick is closed only when its last bin '
  'empties. See 0052, 0054 and 0090.';

-- ---------------------------------------------------------------------------
-- What is still on the pad
-- ---------------------------------------------------------------------------

-- The screen he described: click the pick, see its bins. A pick with bins still
-- full is a pick with fruit left, whether or not some of it is already juice.
create or replace view pick_bin with (security_invoker = true) as
select
  n.id            as node_id,
  n.name          as pick,
  n.status::text  as status,
  v.id            as vessel_id,
  v.name          as bin,
  bf.lbs,
  bf.tons,
  bf.said_as,
  bf.pct_full,
  p.from_at
from node n
join placement p on p.node_id = n.id and p.to_at is null
join vessel v on v.id = p.vessel_id
join term vt on vt.id = v.type_id
  and coalesce((vt.attributes ->> 'intake_bin')::boolean, false)
left join bin_fruit bf on bf.placement_id = p.id
where n.stage = 'bin';

comment on view pick_bin is
  'The bins still holding fruit, by pick, with what is in each. What a press '
  'screen offers once somebody has chosen a pick. See 0090.';

grant select on pick_bin to authenticated;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.pick_bins', 'cellar', 'Bins on a pick',
   'The bins still holding fruit, with what is in each. Choose from these to '
   'load a press.',
   'pick_bin', 'vessel_id', 'bin', 168)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

update capability
   set note = 'Loads a press from bins. A pick is usually more than one press, '
              'so choose which bins are going in.',
       fields = '[{"key":"vessels","param":"p_vessel_ids","type":"uuid[]","required":true,
                   "label":"Which bins",
                   "source":{"readable":"cellar.pick_bins"}},
                  {"key":"press","param":"p_press_vessel_id","type":"uuid","required":true,
                   "label":"Which press"}]'::jsonb
 where key = 'cellar.start_press';

commit;
