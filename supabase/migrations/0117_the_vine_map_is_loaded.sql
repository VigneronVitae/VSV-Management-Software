-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Acreage counted from plant spaces rather than typed, and the
--           varieties a vine map turned out to need."
-- Depends on: [supabase/migrations/0039_vineyard.sql,
--              supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql,
--              supabase/migrations/0116_the_vineyard_is_not_everybodys_business.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  supabase/migrations/0118_the_vineyard_has_a_door.sql,
--                  scripts/import-vinemap.py,
--                  packages/vineyard/src/vineyard.ts]
-- Axioms enforced: T0-2, acreage is counted and not stored.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- **This migration used to load one winery's vineyard and no longer does.**
--
-- It carried 190 encoded rows: the whole of Vitae Springs, block by block, row
-- by row, 13,539 plant spaces with what stands in each. That was the wrong place
-- for it. The repository says what can exist; it does not say what does. A
-- vineyard belongs to a winery, not to the software, and a repository holding
-- one winery's vineyard cannot be handed to another, which CLAUDE.md says is the
-- point of building it this way.
--
-- The map now lives in `data/vineyard/`, which is not committed, and
-- `scripts/import-vinemap.py` loads it. The reconciliation that used to run here
-- runs there, against the same legend counts, so the decode is still checked
-- against the winemaker's own arithmetic every time it is imported.
--
-- What stays below is structure: grape varieties, which are not anybody's
-- property, and the acreage derivation, which is a function.
--
-- `scripts/data-surface.py` is what keeps this true from now on.

-- The varieties a vine map turned out to need. Wine grapes are not one
-- winery's data, whoever happens to have planted them.
insert into term (kind, value, label, sort_order) values
  ('variety', 'pinot_meunier', 'Pinot Meunier', 70),
  ('variety', 'gamay',         'Gamay',         80),
  ('variety', 'pinot_blanc',   'Pinot Blanc',   90),
  ('variety', 'table_grapes',  'Table grapes',  900)
on conflict (kind, value) do nothing;

-- ---------------------------------------------------------------------------
-- Acreage counts everything in the ground
-- ---------------------------------------------------------------------------

-- 0115's `block_planting` filters to rows with a variety, which drops the
-- rootstock, and a rootstock is a plant: it is in the ground and it occupies a
-- space. So the acreage of a block counts every position that is not empty,
-- while the planting breakdown keeps its variety filter, because a rootstock
-- is not a variety yet.
create or replace view block_acreage with (security_invoker = true) as
select
  b.id   as block_id,
  b.name as block,
  v.id   as vineyard_id,
  v.name as vineyard,
  b.vines_per_acre,
  count(*) filter (where n.state is distinct from 'empty' and n.state is not null) as plants,
  count(*) filter (where n.state = 'empty') as gaps,
  count(*) as spaces,
  round(
    count(*) filter (where n.state is distinct from 'empty' and n.state is not null)
    / nullif(b.vines_per_acre, 0), 4) as acres
from block b
left join vineyard v on v.id = b.vineyard_id
join plant_space_now n on n.block_id = b.id
group by b.id, b.name, v.id, v.name, b.vines_per_acre;

comment on view block_acreage is
  'Plants, gaps and derived acreage per block, counted from the plant spaces. A '
  'rootstock counts as a plant, which is how the winemaker counts and what makes '
  'the figures reconcile.';

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('vineyard.block_acreage', 'vineyard', 'Acreage, counted',
   'Plants, gaps and acreage per block, derived from the plant spaces rather than typed.',
   'block_acreage', 'block_id', 'block', 412)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

-- The reconciliation that used to close this file went to
-- `scripts/import-vinemap.py` with the data it was checking. There is nothing
-- here to reconcile any more: this migration carries a view and a vocabulary.
