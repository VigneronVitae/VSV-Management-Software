-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "One bin can be tipped into another, and a bin's fruit can be
--           thrown away, and the pick's weights, its pressing and the harvest
--           totals all know which happened."
-- Depends on: [supabase/migrations/0146_harvest_weights.sql,
--              supabase/migrations/0147_a_pressing_knows_what_went_in.sql,
--              supabase/migrations/0148_reds_go_into_fermenters.sql,
--              supabase/migrations/0159_what_an_acre_gave.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts, scripts/smoke.ts]
-- Axioms enforced: T0-5. Both are events on the pick naming the bins; the
--                  placements close at the time they happened, and nothing is
--                  rewritten. A13. A tip that would weigh fruit twice, or never,
--                  is refused in a sentence.
-- Open sorries: S-146 still stands: start_press and fruit_going_in each carry
--               the rule, and both now carry this exclusion.
-- ---------------------------------------------------------------------------

-- The Müller Thurgau of 2026-09-23 was picked into PB4 and PB5 and "combined
-- into one as it was light". Nothing could record that, so PB5 stayed in the
-- pick until the press, never weighed, and Harvest weights has said "1 to
-- weigh" about it ever since. Asked for a way to combine bins, the winemaker
-- asked for that and for a way to throw a bin's fruit away, and, asked whether
-- thrown fruit counts as picked: "should be a choice".
--
-- **Tipping** moves all of one bin into another of the same pick. The fruit
-- stays the pick's; the emptied bin's placement closes and it stops counting
-- as a bin of the pick, for the weights and for pressing. Only where the
-- scale can still see all of it: an unweighed bin into an unweighed one, or a
-- weighed one into a weighed one. A weighed bin into an unweighed one would be
-- weighed again inside it; an unweighed one into a weighed one would never be
-- weighed at all. Both are refused, saying which to weigh first.
--
-- **Throwing away** closes the bins with a reason from the same list a dumped
-- wine uses, and says how many pounds went. A weighed bin's pounds are its
-- reading when the reading was of discarded bins only; otherwise the person
-- says. An unweighed bin's pounds are whatever the person says, or unknown.
-- The pick's own weight does not change: it is what came off the vineyard.
-- What changes is what is left to press, which is the weight less what was
-- thrown away after the scale, shared among the bins that are left, and the
-- harvest totals, which now report the pounds picked, thrown away and kept,
-- so the screen can count either way.

insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'tip_bin', 'Bin tipped into another', 727, '{"effect": "movement"}'),
  ('operation', 'discard_fruit', 'Fruit thrown away', 728, '{"effect": "movement"}')
on conflict (kind, value) do update set label = excluded.label, active = true;

-- Whether a bin still counts as one of its pick's: not if it was tipped into
-- another, and not if its fruit was thrown away. Pressing takes a share of the
-- pick's weight by its bins, so a gone bin has to leave both halves of that
-- share: the bins, here, and its pounds, below.
create or replace function bin_counts(p_placement_id uuid)
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select not exists (
    select 1 from event e
     where e.operation_id = term_id('operation', 'tip_bin')
       and e.data ->> 'from_placement' = p_placement_id::text
  ) and not exists (
    select 1 from event e
     where e.operation_id = term_id('operation', 'discard_fruit')
       and e.data -> 'placements' ? p_placement_id::text
  );
$$;

comment on function bin_counts is
  'False for a bin tipped into another of its pick, or whose fruit was thrown away: it is not one of the pick''s bins any more.';

grant execute on function bin_counts(uuid) to authenticated;

-- What is left of a pick's weight: what the scale said, less what was thrown
-- away after the scale. Fruit thrown away before it was never in the weight.
-- Null while nothing has been weighed, which is how pressing tells an
-- unweighed pick from a weighed one.
create or replace function pick_weight_left(p_node_id uuid)
returns numeric
language sql
stable
set search_path = public, pg_temp
as $$
  select n.quantity - coalesce((
           select sum((e.data ->> 'lbs')::numeric)
             from event e
            where e.subject_type = 'node' and e.subject_id = n.id
              and e.operation_id = term_id('operation', 'discard_fruit')
              and coalesce((e.data ->> 'weighed')::boolean, false)), 0)
    from node n
   where n.id = p_node_id;
$$;

comment on function pick_weight_left is
  'A pick''s weight less the weighed fruit thrown away from it: what pressing shares out.';

grant execute on function pick_weight_left(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Tipping one bin into another
-- ---------------------------------------------------------------------------

create or replace function tip_bin(
  p_from_vessel uuid,
  p_into_vessel uuid,
  p_at          timestamptz default null,
  p_note        text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  was_at    text := current_setting('vsv.occurred_at', true);
  at_       timestamptz;
  f         placement%rowtype;
  i         placement%rowtype;
  pick      node%rowtype;
  f_name    text;
  i_name    text;
  f_weighed boolean;
  i_weighed boolean;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here tips one bin into another'
      using errcode = 'insufficient_privilege';
  end if;
  perform happening_at(p_at);
  at_ := occurred_at();

  if p_from_vessel is null or p_into_vessel is null then
    raise exception 'say which bin was tipped, and into which';
  end if;
  if p_from_vessel = p_into_vessel then
    raise exception 'a bin cannot be tipped into itself';
  end if;
  select name into f_name from vessel where id = p_from_vessel;
  select name into i_name from vessel where id = p_into_vessel;
  select * into f from placement where vessel_id = p_from_vessel and to_at is null;
  select * into i from placement where vessel_id = p_into_vessel and to_at is null;
  if f.id is null then
    raise exception '% holds nothing, so there is nothing to tip', coalesce(f_name, 'that bin');
  end if;
  if i.id is null then
    raise exception '% is empty; fruit tipped into an empty bin is the same fruit in a different bin, which is a move',
      coalesce(i_name, 'that bin');
  end if;
  select * into pick from node where id = f.node_id;
  if pick.stage <> 'bin' or pick.status = 'closed' then
    raise exception '% is not holding fruit from an open pick', f_name;
  end if;
  if i.node_id <> f.node_id then
    raise exception '% and % hold different picks. Tipping them together would blend two picks in one bin; move the bin to the other part first',
      f_name, i_name;
  end if;
  if f.from_at > at_ or i.from_at > at_ then
    raise exception 'one of those bins had not been filled yet at that time';
  end if;

  f_weighed := not exists (select 1 from unweighed_bin u where u.vessel_id = p_from_vessel);
  i_weighed := not exists (select 1 from unweighed_bin u where u.vessel_id = p_into_vessel);
  if f_weighed and not i_weighed then
    raise exception '% has been weighed and % has not. Weigh % first, or its reading will count %''s fruit a second time',
      f_name, i_name, i_name, f_name;
  end if;
  if i_weighed and not f_weighed then
    raise exception '% was weighed without %''s fruit in it, so that fruit would never be weighed. Weigh % first',
      i_name, f_name, f_name;
  end if;

  update placement set to_at = at_ where id = f.id;

  insert into event (operation_id, subject_type, subject_id, by_user, at, provenance, data)
  values (term_id('operation', 'tip_bin'), 'node', pick.id, auth.uid(), at_, 'observed',
          jsonb_strip_nulls(jsonb_build_object(
            'from_bin',       p_from_vessel,
            'into_bin',       p_into_vessel,
            'from_placement', f.id,
            'note',           nullif(btrim(coalesce(p_note, '')), ''))));

  perform resume_at(was_at);
  return jsonb_build_object('pick', pick.name, 'from', f_name, 'into', i_name,
                            'bins', (select count(*) from placement
                                      where node_id = pick.id and to_at is null));
end $$;

comment on function tip_bin is
  'Records one bin of a pick tipped into another of the same pick: the emptied bin stops counting as one of the pick''s.';

grant execute on function tip_bin(uuid, uuid, timestamptz, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Throwing a bin's fruit away
-- ---------------------------------------------------------------------------

create or replace function discard_fruit(
  p_vessel_ids uuid[],
  p_reason     text,
  p_lbs        numeric default null,
  p_at         timestamptz default null,
  p_note       text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  was_at    text := current_setting('vsv.occurred_at', true);
  at_       timestamptz;
  pick      node%rowtype;
  picks     uuid[];
  places    uuid[];
  n_weighed int;
  n_all     int;
  weighed   boolean;
  lbs       numeric;
  said      boolean := false;
  stray     text;
  missing   text;
  names     text[];
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here throws fruit away'
      using errcode = 'insufficient_privilege';
  end if;
  perform happening_at(p_at);
  at_ := occurred_at();

  if p_vessel_ids is null or cardinality(p_vessel_ids) = 0 then
    raise exception 'say which bins';
  end if;
  if p_reason is null or not exists (select 1 from term where kind = 'dump_reason'
                                        and value = p_reason and active) then
    raise exception 'say why: %',
      (select string_agg(label, ', ' order by sort_order) from term
        where kind = 'dump_reason' and active);
  end if;
  if p_lbs is not null and p_lbs <= 0 then
    raise exception 'a weight of fruit thrown away is more than nothing';
  end if;

  select string_agg(v.name, ', ') into missing
    from vessel v
   where v.id = any (p_vessel_ids)
     and not exists (select 1 from placement p join node n on n.id = p.node_id
                      where p.vessel_id = v.id and p.to_at is null
                        and n.stage = 'bin' and n.status <> 'closed');
  if missing is not null then
    raise exception '% % not holding fruit from a pick', missing,
      case when missing like '%,%' then 'are' else 'is' end;
  end if;

  select array_agg(distinct p.node_id), array_agg(p.id)
    into picks, places
    from placement p
   where p.vessel_id = any (p_vessel_ids) and p.to_at is null;
  if cardinality(picks) > 1 then
    raise exception 'those bins are from different picks; throw away one pick''s at a time';
  end if;
  select * into pick from node where id = picks[1];

  select count(*) into n_weighed
    from unnest(p_vessel_ids) s(v)
   where not exists (select 1 from unweighed_bin u where u.vessel_id = s.v);
  n_all := cardinality(p_vessel_ids);
  if n_weighed > 0 and n_weighed < n_all then
    raise exception 'some of those bins have been weighed and some have not; throw them away separately, so the pounds can be said for each';
  end if;
  weighed := n_weighed > 0;
  select array_agg(x::text) into names from unnest(p_vessel_ids) x;

  if weighed then
    -- The readings that weighed these bins. If each of them weighed only
    -- bins being thrown away, their pounds are exactly what went; if one also
    -- weighed a bin being kept, only a person can say how it divided.
    select string_agg(distinct v.name, ', ') into stray
      from event e
      cross join lateral jsonb_array_elements_text(e.data -> 'bins') b(bin)
      join vessel v on v.id::text = b.bin
     where e.subject_type = 'node' and e.subject_id = pick.id
       and e.operation_id = term_id('operation', 'weigh')
       and not exists (select 1 from event s where (s.data ->> 'supersedes')::uuid = e.id)
       and e.data -> 'bins' ?| names
       and not (b.bin = any (names));
    if stray is not null and p_lbs is null then
      raise exception 'the reading that weighed those bins also weighed %, so say how many pounds were thrown away', stray;
    end if;
    if p_lbs is not null then
      lbs := p_lbs;
      said := true;
    else
      select sum((e.data ->> 'net_lbs')::numeric) into lbs
        from event e
       where e.subject_type = 'node' and e.subject_id = pick.id
         and e.operation_id = term_id('operation', 'weigh')
         and not exists (select 1 from event s where (s.data ->> 'supersedes')::uuid = e.id)
         and e.data -> 'bins' ?| names;
    end if;
  else
    lbs := p_lbs;
    said := p_lbs is not null;
  end if;

  update placement set to_at = at_ where id = any (places);

  insert into event (operation_id, subject_type, subject_id, by_user, at, provenance, data)
  values (term_id('operation', 'discard_fruit'), 'node', pick.id, auth.uid(), at_, 'observed',
          jsonb_strip_nulls(jsonb_build_object(
            'bins',       to_jsonb(p_vessel_ids),
            'placements', to_jsonb(places),
            'weighed',    weighed,
            'lbs',        lbs,
            'lbs_said',   said,
            'reason',     p_reason,
            'note',       nullif(btrim(coalesce(p_note, '')), ''))));

  -- A pick every bin of which has gone is closed, as 0155 closes one every bin
  -- of which has moved.
  if not exists (select 1 from placement where node_id = pick.id and to_at is null) then
    update node set status = 'closed', closed_at = at_ where id = pick.id;
  end if;

  perform resume_at(was_at);
  return jsonb_build_object('pick', pick.name, 'bins', n_all, 'weighed', weighed,
                            'lbs', lbs,
                            'left', (select count(*) from placement
                                      where node_id = pick.id and to_at is null));
end $$;

comment on function discard_fruit is
  'Throws away the fruit in some bins of one pick, with a reason and the pounds: the reading''s, or what somebody says.';

grant execute on function discard_fruit(uuid[], text, numeric, timestamptz, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Pressing and processing leave out the bins that no longer count
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fruit_going_in(p_vessel_ids uuid[])
 RETURNS TABLE(node_id uuid, lbs numeric, weighed boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
       -- 0163. A bin tipped into another, or whose fruit was thrown
       -- away, is not part of the whole this share is a share of.
       and bin_counts(p.id)
  ),
  per_pick as (
    select g.node_id,
           -- 0163. What the scale said less what was thrown away after it.
           pick_weight_left(n.id) as weighed,
           sum(coalesce(g.amount, 0)) as chosen_est,
           (select coalesce(sum(coalesce(a.est, 0)), 0) from all_bins a
             where a.placement_id in (select g2.placement_id from going g2 where g2.node_id = g.node_id)) as share_est,
           (select coalesce(sum(coalesce(a.est, 0)), 0) from all_bins a where a.node_id = g.node_id) as whole_est,
           (select count(*) from all_bins a where a.node_id = g.node_id) as whole_bins,
           count(*) as chosen_bins
      from going g
      join node n on n.id = g.node_id
     group by g.node_id, n.id
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
$function$;

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
       -- 0163. The same exclusion as fruit_going_in (S-146: still two copies).
       and bin_counts(p.id)
  )
  select
    g.node_id,
    -- 0163. What the scale said less what was thrown away after it.
    pick_weight_left(n.id)                       as weighed,
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
  group by g.node_id, n.id;

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

-- ---------------------------------------------------------------------------
-- The weights: bins that count, and fruit picked, thrown away and kept
-- ---------------------------------------------------------------------------

-- Replaced in place, columns kept and three appended. `bins` and
-- `bins_weighed` count only bins that still count, so a tipped bin is not "1
-- to weigh" forever. `lbs` stays what the scale said the pick weighed.
create or replace view fruit_log with (security_invoker = true) as
 SELECT n.id,
    n.name,
    ((COALESCE(( SELECT min(p.from_at) AS min
           FROM placement p
          WHERE (p.node_id = n.id)), n.created_at) AT TIME ZONE 'America/Los_Angeles'::text))::date AS picked,
    n.created_at,
    n.vintage,
    n.non_vintage,
    n.status,
    t.label AS variety,
    vy.name AS vineyard,
    b.name AS block,
    n.quantity AS lbs,
    round((n.quantity / 2000.0), 3) AS tons,
    ( SELECT count(*) AS count
           FROM placement p
          WHERE p.node_id = n.id AND bin_counts(p.id)) AS bins,
    ( SELECT count(*) AS count
           FROM placement p
          WHERE ((p.node_id = n.id) AND (p.to_at IS NULL))) AS bins_held,
    ( SELECT count(*) AS count
           FROM placement p
          WHERE p.node_id = n.id AND bin_counts(p.id) AND (EXISTS ( SELECT 1
                   FROM event e
                  WHERE ((e.subject_type = 'node'::text) AND (e.subject_id = n.id) AND (e.operation_id = term_id('operation'::text, 'weigh'::text)) AND ((e.data -> 'bins'::text) ? (p.vessel_id)::text) AND (NOT (EXISTS ( SELECT 1
                           FROM event s
                          WHERE ((s.subject_type = 'node'::text) AND (s.subject_id = n.id) AND (s.operation_id = term_id('operation'::text, 'weigh'::text)) AND (((s.data ->> 'supersedes'::text))::uuid = e.id))))))))) AS bins_weighed,
    ( SELECT coalesce(sum(jsonb_array_length(e.data -> 'bins')), 0)
           FROM event e
          WHERE e.subject_type = 'node' AND e.subject_id = n.id
            AND e.operation_id = term_id('operation', 'discard_fruit')) AS bins_discarded,
    -- Thrown away after the scale: already inside `lbs`.
    ( SELECT coalesce(sum((e.data ->> 'lbs')::numeric), 0)
           FROM event e
          WHERE e.subject_type = 'node' AND e.subject_id = n.id
            AND e.operation_id = term_id('operation', 'discard_fruit')
            AND coalesce((e.data ->> 'weighed')::boolean, false)) AS lbs_discarded_weighed,
    -- Thrown away before it: never inside `lbs`, and only what somebody said.
    ( SELECT coalesce(sum((e.data ->> 'lbs')::numeric), 0)
           FROM event e
          WHERE e.subject_type = 'node' AND e.subject_id = n.id
            AND e.operation_id = term_id('operation', 'discard_fruit')
            AND NOT coalesce((e.data ->> 'weighed')::boolean, false)) AS lbs_discarded_unweighed
   FROM (((node n
     LEFT JOIN term t ON ((t.id = n.variety_id)))
     LEFT JOIN block b ON ((b.id = n.block_id)))
     LEFT JOIN vineyard vy ON ((vy.id = b.vineyard_id)))
  WHERE (n.stage = 'bin'::node_stage);

-- Each total gains the ways of counting thrown fruit, so the screen chooses a
-- column rather than doing the arithmetic.
create or replace view harvest_weights_by_variety with (security_invoker = true) as
select
  f.vintage,
  coalesce(f.variety, 'No variety said') as variety,
  count(*)                               as picks,
  sum(f.bins)                            as bins,
  sum(f.bins) - sum(f.bins_weighed)      as bins_unweighed,
  round(sum(f.lbs), 1)                   as lbs,
  round(sum(f.lbs) / 2000.0, 3)          as tons,
  min(f.picked)                          as first_picked,
  max(f.picked)                          as last_picked,
  round(sum(f.lbs_discarded_weighed + f.lbs_discarded_unweighed), 1) as lbs_discarded,
  round(coalesce(sum(f.lbs), 0) + sum(f.lbs_discarded_unweighed), 1)  as lbs_picked,
  round(coalesce(sum(f.lbs), 0) - sum(f.lbs_discarded_weighed), 1)    as lbs_kept
from fruit_log f
group by f.vintage, coalesce(f.variety, 'No variety said');

create or replace view harvest_weights_by_day with (security_invoker = true) as
select
  f.vintage,
  f.picked,
  count(*)                               as picks,
  sum(f.bins)                            as bins,
  sum(f.bins) - sum(f.bins_weighed)      as bins_unweighed,
  round(sum(f.lbs), 1)                   as lbs,
  round(sum(f.lbs) / 2000.0, 3)          as tons,
  string_agg(distinct coalesce(f.variety, 'No variety said'), ', ') as varieties,
  round(sum(f.lbs_discarded_weighed + f.lbs_discarded_unweighed), 1) as lbs_discarded,
  round(coalesce(sum(f.lbs), 0) + sum(f.lbs_discarded_unweighed), 1)  as lbs_picked,
  round(coalesce(sum(f.lbs), 0) - sum(f.lbs_discarded_weighed), 1)    as lbs_kept
from fruit_log f
group by f.vintage, f.picked;

create or replace view harvest_weights_by_day_variety with (security_invoker = true) as
select
  f.vintage,
  f.picked,
  coalesce(f.variety, 'No variety said') as variety,
  count(*)                               as picks,
  sum(f.bins)                            as bins,
  sum(f.bins) - sum(f.bins_weighed)      as bins_unweighed,
  round(sum(f.lbs), 1)                   as lbs,
  round(sum(f.lbs) / 2000.0, 3)          as tons,
  round(sum(f.lbs_discarded_weighed + f.lbs_discarded_unweighed), 1) as lbs_discarded,
  round(coalesce(sum(f.lbs), 0) + sum(f.lbs_discarded_unweighed), 1)  as lbs_picked,
  round(coalesce(sum(f.lbs), 0) - sum(f.lbs_discarded_weighed), 1)    as lbs_kept
from fruit_log f
group by f.vintage, f.picked, coalesce(f.variety, 'No variety said');

-- And a block's yield both ways: an acre gave what was picked off it, and
-- kept what was not thrown away.
create or replace view block_yield with (security_invoker = true) as
with picked as (
  select f.vintage,
         n.block_id,
         n.variety_id,
         count(*)                          as picks,
         sum(f.bins)                       as bins,
         sum(f.bins) - sum(f.bins_weighed) as bins_unweighed,
         sum(f.lbs)                        as lbs,
         min(f.picked)                     as first_picked,
         max(f.picked)                     as last_picked,
         sum(f.lbs_discarded_weighed + f.lbs_discarded_unweighed) as lbs_discarded,
         coalesce(sum(f.lbs), 0) + sum(f.lbs_discarded_unweighed) as lbs_picked,
         coalesce(sum(f.lbs), 0) - sum(f.lbs_discarded_weighed)   as lbs_kept
    from fruit_log f
    join node n on n.id = f.id
   where n.block_id is not null
   group by f.vintage, n.block_id, n.variety_id
),
bearing as (
  select bp.block_id, bp.variety_id,
         sum(bp.plants) as vines,
         sum(bp.acres)  as acres
    from block_planting bp
   where bp.state = 'vine'
   group by bp.block_id, bp.variety_id
)
select p.vintage,
       vy.name                                     as vineyard,
       b.name                                      as block,
       t.label                                     as variety,
       p.picks,
       p.bins,
       p.bins_unweighed,
       round(p.lbs, 1)                             as lbs,
       round(p.lbs / 2000.0, 3)                    as tons,
       br.vines                                    as bearing_vines,
       round(br.acres, 3)                          as bearing_acres,
       round(p.lbs / 2000.0 / nullif(br.acres, 0), 2) as tons_per_acre,
       round(p.lbs / nullif(br.vines, 0), 2)       as lbs_per_vine,
       p.first_picked,
       p.last_picked,
       round(p.lbs_discarded, 1)                   as lbs_discarded,
       round(p.lbs_picked, 1)                      as lbs_picked,
       round(p.lbs_kept, 1)                        as lbs_kept,
       round(p.lbs_picked / 2000.0 / nullif(br.acres, 0), 2) as tons_per_acre_picked,
       round(p.lbs_kept / 2000.0 / nullif(br.acres, 0), 2)   as tons_per_acre_kept,
       round(p.lbs_picked / nullif(br.vines, 0), 2) as lbs_per_vine_picked,
       round(p.lbs_kept / nullif(br.vines, 0), 2)   as lbs_per_vine_kept
  from picked p
  join block b on b.id = p.block_id
  left join vineyard vy on vy.id = b.vineyard_id
  left join term t on t.id = p.variety_id
  left join bearing br on br.block_id = p.block_id and br.variety_id = p.variety_id;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('cellar.tip_bin', 'cellar', 'Tip one bin into another',
   'Both bins of the same pick, both weighed or both not. The emptied bin stops counting as one of the pick''s.',
   'tip_bin',
   '[{"key": "from", "type": "uuid", "label": "Which bin was tipped", "param": "p_from_vessel", "required": true},
     {"key": "into", "type": "uuid", "label": "Into which bin", "param": "p_into_vessel", "required": true},
     {"key": "at", "type": "timestamptz", "label": "When", "param": "p_at", "required": false},
     {"key": "note", "type": "text", "label": "Why", "param": "p_note", "required": false}]'::jsonb,
   129),
  ('cellar.discard_fruit', 'cellar', 'Throw fruit away',
   'Some bins of one pick, with a reason and the pounds if they are known.',
   'discard_fruit',
   '[{"key": "bins", "type": "uuid[]", "label": "Which bins", "param": "p_vessel_ids", "required": true},
     {"key": "reason", "type": "text", "label": "Why", "param": "p_reason", "required": true, "source": {"terms": "dump_reason"}},
     {"key": "lbs", "type": "numeric", "label": "Pounds thrown away", "param": "p_lbs", "required": false},
     {"key": "at", "type": "timestamptz", "label": "When", "param": "p_at", "required": false},
     {"key": "note", "type": "text", "label": "Anything else", "param": "p_note", "required": false}]'::jsonb,
   130)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into capability_exemption (fn, reason) values
  ('bin_counts', 'Answers whether a bin is still one of its pick''s. Read by the weights and pressing; it changes nothing.'),
  ('pick_weight_left', 'A pick''s weight less the weighed fruit thrown away. Read by pressing; it changes nothing.')
on conflict (fn) do update set reason = excluded.reason;
