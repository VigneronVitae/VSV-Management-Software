-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Say fruit where it is fruit, and drop a branch of the kind rule
--           that nothing can reach."
-- Depends on: [supabase/migrations/0083_what_you_can_sample.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: A13 (a branch no input can reach looks like a handled case
--                  and handles nothing)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- Two things visible the moment `0083` ran against the real cellar.
--
-- **Five bins of Chardonnay appeared under "Juice and ferments".** They are
-- fruit: whole clusters in a picking bin that has not seen a press. The kind is
-- right, because the winemaker named three and this is the one that is not
-- vineyard and not wine, and sampling a bin is the same act as sampling a
-- ferment for the same reason. The heading was wrong, and a heading somebody
-- reads at a crush pad should say what is in front of them.
--
-- **The `unknown` branch could not be reached.** `sample_target` joins
-- `placement` and `node` inner, so a vessel with nothing in it is not a row at
-- all, and the `else 'unknown'` sat there looking like a handled case. On
-- `sample` the same branch is real and stays: a vessel can be sampled and then
-- emptied, and a sample of a vessel that held nothing at the time is a question
-- rather than a category.

begin;

create or replace view sample_target with (security_invoker = true) as
select
  'vineyard'::text as kind,
  'vineyard'::text as subject_type,
  v.id             as subject_id,
  v.name           as label,
  null::text       as detail,
  'Vineyards'::text as grouping,
  10               as sort_order
from vineyard v

union all
select
  'vineyard', 'block', b.id,
  btrim(coalesce(vy.name, '') || ' ' || b.name),
  null,
  'Blocks', 20
from block b
left join vineyard vy on vy.id = b.vineyard_id

union all
select
  'vineyard', 'planting', p.planting_id,
  btrim(coalesce(p.block_name, '') || ' ' || coalesce(p.variety, '')),
  p.variety,
  'Varieties in a block', 30
from planting_detail p

union all
select
  case when n.stage in ('bin', 'load', 'ferment') then 'juice' else 'wine' end,
  'vessel', ve.id,
  ve.name,
  n.name || coalesce(', ' || n.vintage::text, ''),
  -- Fruit, because five bins of whole clusters are not juice and the person
  -- reading this is standing in front of them.
  case
    when n.stage = 'bin' then 'Fruit in bins'
    when n.stage in ('load', 'ferment') then 'Juice and ferments'
    else 'Wine in vessels'
  end,
  case when n.stage = 'bin' then 40 else 50 end
from vessel ve
join placement p on p.vessel_id = ve.id and p.to_at is null
join node n on n.id = p.node_id
where ve.active;

comment on view sample_target is
  'Everything that can be sampled, with which of the three kinds of sampling it '
  'belongs to. The picker and the filter read the same rows, so they cannot '
  'disagree about whether a thing is juice or wine. Fruit in bins is grouped '
  'apart and counts as juice, because sampling it is the same act for the same '
  'reason. See 0083 and 0084.';

commit;
