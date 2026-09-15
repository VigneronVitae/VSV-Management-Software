-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "One list of everything that can be sampled, each row saying which
--           of the three kinds of sampling it belongs to, so the picker and the
--           filter are the same separation rather than two that drift."
-- Depends on: [supabase/migrations/0082_three_kinds_of_sampling.sql,
--              supabase/migrations/0081_a_borrowed_bin_is_not_ours.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0084_a_bin_of_fruit_is_not_juice.sql]
-- Axioms enforced: R-4 (the client was assembling this from four reads and
--                  deciding the groups itself), AR-Q8 (one declared read a
--                  second periphery can use to build the same screen)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- `0082` separates samples that have been taken. This separates the things you
-- can take one from, which is the other half of the winemaker's ask: a filter
-- that hides last vintage's barrels from the list but still offers all of them
-- in the picker has not separated anything.
--
-- **The client was building this list itself**, out of `vineyards()`,
-- `blocks()`, `plantings()` and `vessels()`, with the group headings written
-- into the screen. That is four round trips and a fifth piece of knowledge, the
-- grouping, living somewhere only this client can see it. A second periphery
-- would have had to invent the same four-way union and guess the same headings.
--
-- **Kind is derived the same way it is on the sample**, so a vessel that reads
-- `juice` here produces samples that read `juice` there. Two derivations of one
-- rule is how the picker and the filter drift apart, so there is one.

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
-- A vessel with wine in it. Juice or wine by the same rule 0082 uses, so the
-- picker and the list cannot disagree about which a thing is.
select
  case
    when n.stage in ('bin', 'load', 'ferment') then 'juice'
    when n.stage in ('maturation', 'finished') then 'wine'
    else 'unknown'
  end,
  'vessel', ve.id,
  ve.name,
  n.name || coalesce(', ' || n.vintage::text, ''),
  case
    when n.stage in ('bin', 'load', 'ferment') then 'Juice and ferments'
    else 'Wine in vessels'
  end,
  40
from vessel ve
join placement p on p.vessel_id = ve.id and p.to_at is null
join node n on n.id = p.node_id
where ve.active;

comment on view sample_target is
  'Everything that can be sampled, with which of the three kinds of sampling it '
  'belongs to. The picker and the filter read the same rows, so they cannot '
  'disagree about whether a thing is juice or wine. See 0083.';

grant select on sample_target to authenticated;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.sample_targets', 'cellar', 'What can be sampled',
   'Vineyards, blocks and varieties for watching fruit ripen; vessels for juice '
   'and for wine. Each row says which of the three it is.',
   'sample_target', 'subject_id', 'label', 145)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

commit;
