-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Every pick of the vintage with where its fruit is now: how many bins
--           and pounds came off, and how many litres of it are sitting in which
--           vessels at which stage today."
-- Depends on: [supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0114_every_pick_stays_on_the_list.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  supabase/migrations/0141_a_volume_says_whether_it_was_measured.sql]
-- Axioms enforced: T0-2, throughout. Nothing here is stored. A pick's present
--                  whereabouts is a walk of `lineage` and a sum over open
--                  placements, and it changes every time anybody racks anything.
--                  A25, in the arithmetic. A pick whose fruit has been pressed
--                  and a pick whose fruit is still in bins both have to be
--                  distinguishable from a pick nobody has touched.
-- Open sorries: none new. See S-138 note below on juice against wine.
-- ---------------------------------------------------------------------------

-- "I want a harvest so far section that will eventually be a snapshot of harvest
-- following each grape from pick to press to racking, etc. So harvest so far
-- will have all of the picks with the current status of that wine." Then: "it
-- should include weights of bins and volume of juice and wine."
--
-- **The attribution already exists and this does not rewrite it.** `node_bin_shares`
-- walks `lineage` upward from a lot, multiplying `fraction` at each hop, and
-- returns the bin-stage ancestors with the share of that lot which came from
-- each. It is `security definer` and does its own checks on ownership and on
-- hidden composition, which is why it is called laterally here rather than
-- reimplemented as a second recursive CTE. Two walks of the same lineage would
-- eventually disagree, and the one that disagreed would be this one.
--
-- The shares matter because fruit converges. A blend already in this vintage
-- draws from more than one pressing, and without the fractions "how much of the
-- Amica Luna is left" would be answered with the whole blend.
--
-- **Volume is read from open placements rather than from `node.quantity`.** A
-- lot's quantity is what somebody recorded it as; its placements are where the
-- liquid physically is, split across however many vessels it occupies. For a
-- question phrased as "where is it now" the second is the truthful one, and it
-- is also the only one that can name the vessels.
--
-- **What this deliberately does not do is decide where juice becomes wine.**
-- Volume is reported per stage and the stages are the kernel's own: load,
-- ferment, maturation. Whether the tank that finished fermenting last night is
-- juice or wine is a winemaking judgement nobody has been asked for, and a view
-- that quietly picked a boundary would be putting that judgement in a column.

-- ---------------------------------------------------------------------------
-- Where each pick's fruit is now, one row per pick per lot that still holds it
-- ---------------------------------------------------------------------------

create or replace view harvest_lot_now with (security_invoker = true) as
select
  b.id            as pick_id,
  b.name          as pick,
  n.id            as lot_id,
  n.name          as lot,
  n.stage,
  n.status,
  s.share,
  -- Where the liquid is, summed over every vessel this lot currently occupies.
  (select sum(p.volume_l)
     from placement p
    where p.node_id = n.id and p.to_at is null) as lot_l,
  -- The part of that attributable to this pick. For a lot with one source the
  -- share is 1 and these agree; for a blend they do not, and the difference is
  -- the whole reason `lineage.fraction` exists.
  round(
    coalesce((select sum(p.volume_l)
                from placement p
               where p.node_id = n.id and p.to_at is null), 0) * s.share, 1) as share_l,
  -- `vessel.name` and not `vessel_code.code`. A code is a sticker somebody
  -- scans and exactly one vessel in this cellar has one; a name is what the tank
  -- is called out loud, which is what a person reading this list needs. Found by
  -- running the view: every row came back with no vessel at all.
  (select string_agg(distinct v.name, ', ' order by v.name)
     from placement p
     join vessel v on v.id = p.vessel_id
    where p.node_id = n.id and p.to_at is null) as vessels
from node n
cross join lateral node_bin_shares(n.id) s
join node b on b.id = s.bin_id
-- Open lots only. A closed lot is one whose contents went somewhere else, and
-- that somewhere else is itself in this list; counting both would double the
-- vintage.
where n.status = 'open';

comment on view harvest_lot_now is
  'Every pick paired with every open lot that still holds some of its fruit, '
  'with the share and the litres attributable to that pick.';

-- ---------------------------------------------------------------------------
-- Harvest so far
-- ---------------------------------------------------------------------------

create or replace view harvest_so_far with (security_invoker = true) as
select
  f.id,
  f.name,
  f.picked,
  f.vintage,
  f.variety,
  f.vineyard,
  f.block,
  -- What came off the vine.
  f.bins,
  f.bins_weighed,
  f.lbs,
  f.tons,
  f.status                         as pick_status,
  -- Where it is now.
  count(h.lot_id)                  as lots_now,
  -- The furthest any of this fruit has got. `node_stage` is an ordered enum, so
  -- max is the right word and not a trick: bin, load, ferment, maturation,
  -- finished, in that order.
  max(h.stage)                     as furthest_stage,
  round(sum(h.share_l), 1)         as litres_now,
  round(sum(h.share_l) filter (where h.stage = 'load'), 1)       as litres_at_load,
  round(sum(h.share_l) filter (where h.stage = 'ferment'), 1)    as litres_fermenting,
  round(sum(h.share_l) filter (where h.stage = 'maturation'), 1) as litres_maturing,
  round(sum(h.share_l) filter (where h.stage = 'finished'), 1)   as litres_finished,
  (select string_agg(distinct x.vessels, ', ')
     from harvest_lot_now x where x.pick_id = f.id and x.vessels is not null) as vessels,
  -- Litres per ton, which is the number a winemaker actually reads a vintage by,
  -- and null rather than zero where nothing has been pressed yet: a pick still
  -- in bins has no yield, and reporting 0 would say its yield was nothing.
  case
    when f.tons > 0 and sum(h.share_l) > 0
      then round(sum(h.share_l) / f.tons, 1)
  end                              as litres_per_ton
from fruit_log f
-- Left, so a pick that has been made and not yet touched is on the list with
-- nothing after it rather than absent. A13: a pick with nowhere to be and a pick
-- that does not exist are different, and this is the list somebody checks to
-- find the first kind.
left join harvest_lot_now h on h.pick_id = f.id
group by f.id, f.name, f.picked, f.vintage, f.variety, f.vineyard, f.block,
         f.bins, f.bins_weighed, f.lbs, f.tons, f.status;

comment on view harvest_so_far is
  'Every pick of the vintage with where its fruit is now: bins and pounds off '
  'the vine, litres by stage, and the vessels holding them. All derived, and it '
  'changes the moment anybody racks anything.';

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.harvest_so_far', 'cellar', 'Harvest so far',
   'Every pick with the current state of its wine: bins and pounds off the vine, litres by stage, the vessels holding them, and litres per ton where anything has been pressed.',
   'harvest_so_far', 'id', 'name', 12),
  ('cellar.harvest_lot_now', 'cellar', 'Where a pick''s fruit is now',
   'Each pick paired with every open lot still holding some of it, with the share and litres attributable. The detail behind a row of harvest so far.',
   'harvest_lot_now', 'lot_id', 'lot', 13)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into screen (key, label) values
  ('harvest', 'Harvest so far')
on conflict (key) do nothing;

do $$
declare
  picks int;
  rows_ int;
begin
  select count(*) into picks from fruit_log;
  select count(*) into rows_ from harvest_so_far;
  -- The property that makes this a list somebody can trust: every pick appears,
  -- including one whose fruit has gone nowhere yet. A view that quietly dropped
  -- those would be most wrong exactly when it mattered, during picking.
  if picks <> rows_ then
    raise exception
      'harvest_so_far has % rows against % picks, so some pick is missing from the list', rows_, picks;
  end if;
end $$;
