-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A pick of red fruit can be sorted, destemmed or kept whole cluster,
--           and put into fermentation bins as one lot or several, the way a
--           press does it for whites."
-- Depends on: [supabase/migrations/0147_a_pressing_knows_what_went_in.sql,
--              supabase/migrations/0033_intake.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts,
--                  supabase/migrations/0150_off_the_skins.sql]
-- Axioms enforced: T0-2. What each fermenter was said to hold is stored as it
--                  was said (pounds, a fill, or nothing); the share of the
--                  pick's weight each lot got is worked out once, at the
--                  moment it happened, the same as a press's pounds in.
--                  T0-5. The bins empty by closing their placements; nothing
--                  is deleted, and each new lot's lineage names its picks.
-- Open sorries: S-146, the weight-in rule written twice; S-147, pressing a
--               red off its skins out of fermenters that hold pounds.
-- ---------------------------------------------------------------------------

-- "Can you add a processing equivalent of the press page for skin contact
-- wines? I am about to take the bins that we picked of Pinot and we are going
-- to sort it, then destem some of the fruit or keep it whole cluster, but it's
-- going into macrobins now. It's like the press equivalent of whites." Asked:
-- one lot across several bins, or a lot per bin? "Both." Whole cluster per
-- fermenter, for the whole lot, or per picking bin? "Any of those." Pounds or a
-- fill? "Either." Sorting: "additions should be an option, plus options for
-- weight discarded, sorting type, etc."
--
-- **So this is start_press without the press.** The bins going in, and the
-- pounds they carry, are worked out exactly as a press works them out after
-- 0147. Instead of a load waiting in a press for its cuts, the fruit goes
-- straight into the fermenters named, as one lot or several: each destination
-- says which lot it belongs to, and destinations sharing a key are one lot.
-- Each lot starts at `ferment`, the stage a press's cuts start at for whites,
-- in pounds, because what is in a fermentation bin today is fruit and nobody
-- has a litre figure for it until it is pressed.
--
-- **What a fermenter holds is stored as it was said.** Pounds if somebody said
-- pounds, a fill if they said a fill, nothing if they said nothing. The lot's
-- own quantity is its share of the pick's weight less what was sorted out,
-- split by what was said: stated pounds first, then the rest in proportion to
-- fills, or evenly. That split is arithmetic, done once and kept on the lot and
-- in the event, the same way a press keeps its pounds in; it is never written
-- into a placement as though somebody had weighed the fermenter.
--
-- **When several picks go into one processing, each lot gets the same share of
-- each pick.** Which pick's fruit landed in which fermenter is not something
-- anybody records at a crusher, and inventing it would be worse than saying the
-- fruit was mixed, which it was.

-- ---------------------------------------------------------------------------
-- How it was sorted
-- ---------------------------------------------------------------------------

insert into term_kind (kind, label, module, sort_order) values
  ('sort_method', 'How it was sorted', 'winemaking', 133)
on conflict (kind) do update set
  label = excluded.label, module = excluded.module, sort_order = excluded.sort_order;

-- The four any winery could say, and a picker that adds a fifth. Not sorted is
-- an answer, not an absence: fruit that went in straight from the bin is a
-- fact worth being able to count.
insert into term (kind, value, label, sort_order) values
  ('sort_method', 'hand',    'By hand',        100),
  ('sort_method', 'table',   'Sorting table',  200),
  ('sort_method', 'optical', 'Optical sorter', 300),
  ('sort_method', 'none',    'Not sorted',     400)
on conflict (kind, value) do update set
  label = excluded.label, sort_order = excluded.sort_order, active = true;

-- ---------------------------------------------------------------------------
-- The pounds going in, as one rule
-- ---------------------------------------------------------------------------

-- The rule 0147 fixed inside start_press, as a function of its own so the next
-- verb uses it rather than copying it. A weighed pick contributes its scale
-- weight in proportion to the estimate of the bins going in over the estimate
-- of all its bins, both estimated the same way; with no estimate on the bins
-- going in, in proportion to how many bins; an unweighed pick contributes only
-- what somebody measured on the bins themselves. start_press still carries its
-- own copy (S-146) and the two are asserted to agree.
create or replace function fruit_going_in(p_vessel_ids uuid[])
returns table(node_id uuid, lbs numeric, weighed boolean)
language sql
stable
set search_path = public, pg_temp
as $$
  with going as (
    select p.id as placement_id, p.node_id,
           (select bf.lbs from bin_fruit bf where bf.placement_id = p.id) as amount
      from unnest(p_vessel_ids) s(vessel_id)
      join placement p on p.vessel_id = s.vessel_id and p.to_at is null
  ),
  all_bins as (
    select p.node_id, p.id as placement_id,
           coalesce((select bf.lbs from bin_fruit bf where bf.placement_id = p.id),
                    round(p.fill_pct / 100.0 * nullif((vt.attributes ->> 'full_lbs')::numeric, 0), 0)) as est
      from placement p
      join vessel v on v.id = p.vessel_id
      join term vt on vt.id = v.type_id
     where p.node_id in (select g.node_id from going g)
  ),
  per_pick as (
    select g.node_id,
           n.quantity as weighed,
           sum(coalesce(g.amount, 0)) as chosen_est,
           (select coalesce(sum(coalesce(a.est, 0)), 0) from all_bins a
             where a.placement_id in (select g2.placement_id from going g2 where g2.node_id = g.node_id)) as share_est,
           (select coalesce(sum(coalesce(a.est, 0)), 0) from all_bins a where a.node_id = g.node_id) as whole_est,
           (select count(*) from all_bins a where a.node_id = g.node_id) as whole_bins,
           count(*) as chosen_bins
      from going g
      join node n on n.id = g.node_id
     group by g.node_id, n.quantity
  )
  select node_id,
         case
           when weighed is not null and whole_est > 0 and share_est > 0
             then weighed * (share_est / whole_est)
           when weighed is not null and whole_bins > 0
             then weighed * (chosen_bins::numeric / whole_bins)
           else chosen_est
         end,
         weighed is not null
    from per_pick;
$$;

comment on function fruit_going_in is
  'The pounds each pick contributes when these bins are emptied into something: '
  'the rule a press uses since 0147, as one function.';

-- ---------------------------------------------------------------------------
-- The verb
-- ---------------------------------------------------------------------------

create or replace function process_fruit(
  p_vessel_ids   uuid[],
  p_destinations jsonb,
  p_detail       jsonb       default '{}'::jsonb,
  p_lots         jsonb       default '{}'::jsonb,
  p_at           timestamptz default null
)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  was_at      text := current_setting('vsv.occurred_at', true);
  n_src       int := coalesce(array_length(p_vessel_ids, 1), 0);
  parents     uuid[];
  first_name  text;
  total_lbs   numeric := 0;
  sorted_out  numeric := coalesce((p_detail ->> 'sorted_out_lbs')::numeric, 0);
  net_in      numeric;
  said_lbs    numeric;
  unsaid      int;
  fill_sum    numeric;
  fill_avg    numeric;
  rest        numeric;
  g_row       record;
  n_groups    int;
  lot_id      uuid;
  lot_lbs     numeric;
  lot_wc      numeric;
  lots        jsonb := '[]'::jsonb;
  emptied     int := 0;
  closed_now  int := 0;
  v_name      text;
  bad         text;
begin
  perform happening_at(p_at);

  if not is_facility_user() then
    raise exception 'fruit is processed by people who work here';
  end if;
  if n_src = 0 then
    raise exception 'no bins were named, so there is no fruit to process';
  end if;
  if p_destinations is null or jsonb_typeof(p_destinations) <> 'array'
     or jsonb_array_length(p_destinations) = 0 then
    raise exception 'say which fermenters the fruit is going into';
  end if;
  if sorted_out < 0 then
    raise exception 'what was sorted out cannot be less than nothing';
  end if;
  if nullif(p_detail ->> 'sort_method', '') is not null
     and not exists (select 1 from term where kind = 'sort_method'
                        and value = p_detail ->> 'sort_method' and active) then
    raise exception '"%" is not a way of sorting on the list', p_detail ->> 'sort_method';
  end if;
  if (p_detail ->> 'whole_cluster_pct')::numeric not between 0 and 100 then
    raise exception 'whole cluster is a percentage, and % is not one', p_detail ->> 'whole_cluster_pct';
  end if;

  -- Two processings in one transaction is not a thing a winery does and is
  -- exactly what the assertion suite does. Dropping first turns a second call
  -- from an error into a second call, as in start_press.
  drop table if exists fruit_in;
  drop table if exists fruit_to;
  drop table if exists fruit_share;

  -- What is in the bins named, read off the bins, as a press reads them.
  create temp table fruit_in on commit drop as
  select v.id as vessel_id, v.name as vessel_name, p.id as placement_id,
         p.node_id, n.name as lot_name, n.stage, n.status
    from unnest(p_vessel_ids) as s(vessel_id)
    join vessel v on v.id = s.vessel_id
    left join placement p on p.vessel_id = v.id and p.to_at is null
    left join node n on n.id = p.node_id;

  select vessel_name into v_name from fruit_in where placement_id is null limit 1;
  if v_name is not null then
    raise exception '% has nothing in it, so there is nothing of it to process', v_name;
  end if;
  select lot_name into v_name from fruit_in where stage <> 'bin' limit 1;
  if v_name is not null then
    raise exception '% is not fruit in a bin, so it is not something to destem', v_name;
  end if;
  select lot_name into v_name from fruit_in where status = 'closed' limit 1;
  if v_name is not null then
    raise exception '% is closed; its fruit has already gone somewhere', v_name;
  end if;

  select array_agg(distinct node_id) into parents from fruit_in;
  select lot_name into first_name from fruit_in order by lot_name limit 1;

  create temp table fruit_share on commit drop as
  select * from fruit_going_in(p_vessel_ids);
  select coalesce(sum(lbs), 0) into total_lbs from fruit_share;

  if total_lbs > 0 and sorted_out >= total_lbs then
    raise exception 'that sorts out % lbs from % lbs going in, which leaves nothing to ferment',
      sorted_out, round(total_lbs);
  end if;
  net_in := greatest(total_lbs - sorted_out, 0);

  -- Where it is going. Each destination may name the lot it belongs to; the
  -- ones that do not are one lot together.
  create temp table fruit_to on commit drop as
  select (d ->> 'vessel_id')::uuid                 as vessel_id,
         coalesce(nullif(d ->> 'lot', ''), 'a')    as grp,
         (d ->> 'net_lbs')::numeric                as net_lbs,
         (d ->> 'fill_pct')::numeric               as fill_pct,
         (d ->> 'whole_cluster_pct')::numeric      as wc_pct,
         ord                                       as ord,
         null::numeric                             as lbs
    from jsonb_array_elements(p_destinations) with ordinality as x(d, ord);

  select string_agg(coalesce(v.name, t.vessel_id::text), ', ') into bad
    from fruit_to t left join vessel v on v.id = t.vessel_id and v.active
   where v.id is null;
  if bad is not null then
    raise exception 'no active vessel %', bad;
  end if;
  select string_agg(v.name, ', ') into bad
    from fruit_to t join vessel v on v.id = t.vessel_id
   where exists (select 1 from placement p where p.vessel_id = t.vessel_id and p.to_at is null);
  if bad is not null then
    raise exception '% already holds something, so the fruit cannot go in', bad;
  end if;
  select string_agg(v.name, ', ') into bad
    from fruit_to t join vessel v on v.id = t.vessel_id
    join term vt on vt.id = v.type_id
   where coalesce((vt.attributes ->> 'intake_bin')::boolean, false) or vt.value = 'press';
  if bad is not null then
    raise exception '% is a picking bin or a press, not somewhere to ferment', bad;
  end if;
  if (select count(*) from fruit_to) <> (select count(distinct vessel_id) from fruit_to) then
    raise exception 'the same fermenter is named twice';
  end if;
  if exists (select 1 from fruit_to where net_lbs is not null and net_lbs <= 0) then
    raise exception 'a fermenter said to hold % lbs holds nothing', (select min(net_lbs) from fruit_to where net_lbs <= 0);
  end if;
  if exists (select 1 from fruit_to where net_lbs is not null and fill_pct is not null) then
    raise exception 'say pounds or a fill for a fermenter, not both: two figures for one amount is one of them wrong';
  end if;
  if exists (select 1 from fruit_to where fill_pct is not null and (fill_pct <= 0 or fill_pct > 200))
     or exists (select 1 from fruit_to where wc_pct is not null and wc_pct not between 0 and 100) then
    raise exception 'a fill or a whole cluster figure is outside what a percentage can be';
  end if;

  -- The split. Stated pounds are kept as stated; the rest of what went in is
  -- shared among the others by their fills, a fermenter with no fill counting
  -- as the average of the ones that have one, or evenly when none do.
  update fruit_to set lbs = net_lbs where net_lbs is not null;
  select coalesce(sum(net_lbs), 0) into said_lbs from fruit_to;
  select count(*) into unsaid from fruit_to where net_lbs is null;
  rest := greatest(net_in - said_lbs, 0);
  if unsaid > 0 then
    select avg(fill_pct) into fill_avg from fruit_to where net_lbs is null and fill_pct is not null;
    if fill_avg is null then
      update fruit_to set lbs = round(rest / unsaid, 1) where net_lbs is null;
    else
      select sum(coalesce(fill_pct, fill_avg)) into fill_sum from fruit_to where net_lbs is null;
      update fruit_to set lbs = round(rest * coalesce(fill_pct, fill_avg) / fill_sum, 1)
       where net_lbs is null;
    end if;
  end if;

  -- The bins empty.
  update placement set to_at = occurred_at()
   where id in (select placement_id from fruit_in);
  get diagnostics emptied = row_count;

  -- A pick is spent when its last bin empties, as 0090 has it for a press.
  update node n
     set status = 'closed', closed_at = coalesce(n.closed_at, occurred_at())
   where n.id = any(parents)
     and not exists (select 1 from placement pl where pl.node_id = n.id and pl.to_at is null);
  get diagnostics closed_now = row_count;

  select count(distinct grp) into n_groups from fruit_to;

  for g_row in
    select t.grp, min(t.ord) as first_ord
      from fruit_to t group by t.grp order by min(t.ord)
  loop
    lot_id := coalesce((p_lots -> g_row.grp ->> 'id')::uuid, gen_random_uuid());
    select coalesce(sum(lbs), 0) into lot_lbs from fruit_to where fruit_to.grp = g_row.grp;
    -- The lot's whole cluster: its fermenters' own figures weighted by what
    -- each holds, or the processing's figure, or nothing said.
    select case when sum(lbs) filter (where wc_pct is not null) > 0
                then round(sum(wc_pct * lbs) filter (where wc_pct is not null)
                           / sum(lbs) filter (where wc_pct is not null), 1)
                else (select avg(wc_pct) from fruit_to f2 where f2.grp = g_row.grp) end
      into lot_wc
      from fruit_to where fruit_to.grp = g_row.grp;
    lot_wc := coalesce(lot_wc, (p_detail ->> 'whole_cluster_pct')::numeric);

    insert into node
      (id, stage, status, name, quantity, unit, variety_id, vintage, non_vintage,
       product_type_id, owner_id, created_by, attributes)
    select
      lot_id, 'ferment', 'open',
      coalesce(nullif(p_lots -> g_row.grp ->> 'name', ''),
               first_name || case when n_groups > 1 then ' ' || upper(g_row.grp) else '' end),
      nullif(round(lot_lbs, 1), 0), 'lbs',
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
      jsonb_strip_nulls(jsonb_build_object(
        'whole_cluster_pct', lot_wc,
        'sort_method', nullif(p_detail ->> 'sort_method', ''),
        'on_skins', true));

    -- Every lot gets every pick's share of the whole, because the fruit was
    -- mixed at the crusher and nothing says otherwise.
    if total_lbs > 0 then
      insert into lineage (parent_id, child_id, fraction)
      select s.node_id, lot_id, round(s.lbs / total_lbs, 6)
        from fruit_share s where s.lbs > 0;
    else
      insert into lineage (parent_id, child_id, fraction)
      select distinct f.node_id, lot_id, round(1.0 / array_length(parents, 1), 6)
        from fruit_in f;
    end if;

    -- In each fermenter, stored as it was said.
    insert into placement (node_id, vessel_id, net_lbs, fill_pct)
    select lot_id, t.vessel_id, t.net_lbs, t.fill_pct
      from fruit_to t where t.grp = g_row.grp order by t.ord;

    insert into event (operation_id, subject_type, subject_id, by_user, provenance, data)
    values (term_id('operation', 'destem'), 'node', lot_id, auth.uid(), 'observed',
      jsonb_strip_nulls(jsonb_build_object(
        'action',            'processed',
        'sources',           to_jsonb(parents::text[]),
        'bins',              to_jsonb(p_vessel_ids::text[]),
        'lbs_in',            nullif(round(total_lbs, 1), 0),
        'sorted_out_lbs',    nullif(sorted_out, 0),
        'lbs_to_this_lot',   nullif(round(lot_lbs, 1), 0),
        'sort_method',       nullif(p_detail ->> 'sort_method', ''),
        'whole_cluster_pct', lot_wc,
        'whole_cluster_bins', p_detail -> 'whole_cluster_bins',
        'note',              nullif(p_detail ->> 'note', ''),
        'fermenters',        (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                 'vessel_id', t.vessel_id, 'lbs', t.lbs,
                                 'said_lbs', t.net_lbs, 'said_fill_pct', t.fill_pct,
                                 'whole_cluster_pct', t.wc_pct)) order by t.ord)
                                from fruit_to t where t.grp = g_row.grp))));

    lots := lots || jsonb_build_array(jsonb_build_object(
      'node_id', lot_id,
      'name', (select name from node where id = lot_id),
      'lbs', nullif(round(lot_lbs, 1), 0),
      'fermenters', (select count(*) from fruit_to t where t.grp = g_row.grp)));
  end loop;

  perform resume_at(was_at);
  return jsonb_build_object(
    'lots',           lots,
    'lbs_in',         round(total_lbs, 1),
    'sorted_out_lbs', sorted_out,
    'bins_emptied',   emptied,
    'picks_spent',    closed_now,
    'measured',       coalesce((select bool_and(weighed) from fruit_share), false));
end $$;

comment on function process_fruit is
  'Sorts, destems or keeps whole cluster, and puts a pick''s bins into fermenters '
  'as one lot or several. The red counterpart of starting a press.';

grant execute on function process_fruit(uuid[], jsonb, jsonb, jsonb, timestamptz) to authenticated;
grant execute on function fruit_going_in(uuid[]) to authenticated;

insert into capability_exemption (fn, reason) values
  ('fruit_going_in',
   'The pounds a set of bins would put into whatever they are emptied into, read and never written. It is the rule process_fruit uses, as a function so it is written once.')
on conflict (fn) do update set reason = excluded.reason;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('cellar.process_fruit', 'cellar', 'Sort and destem into fermenters',
   'Reds: bins of fruit, sorted, destemmed or kept whole cluster, into fermentation bins as one lot or several. What went in is worked out as a press works it out.',
   'process_fruit',
   '[{"key": "bins", "type": "uuid[]", "label": "Which bins", "param": "p_vessel_ids", "required": true},
     {"key": "destinations", "type": "jsonb", "label": "Into which fermenters", "param": "p_destinations", "required": true,
      "hint": "A list of vessel_id, and optionally lot (a key; the same key is one lot), net_lbs or fill_pct, and whole_cluster_pct."},
     {"key": "detail", "type": "jsonb", "label": "How it was done", "param": "p_detail", "required": false,
      "hint": "sort_method (a sort_method term), sorted_out_lbs, whole_cluster_pct, whole_cluster_bins, note."},
     {"key": "lots", "type": "jsonb", "label": "What to call the lots", "param": "p_lots", "required": false,
      "hint": "By lot key: name, and optionally id."},
     {"key": "at", "type": "timestamptz", "label": "When", "param": "p_at", "required": false,
      "hint": "Blank means now. A time earlier today or on an earlier day is recorded as entered late."}]'::jsonb,
   125)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into screen (key, label) values
  ('process', 'Sort and destem')
on conflict (key) do nothing;
