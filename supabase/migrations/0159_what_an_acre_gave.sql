-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "What each block gave this vintage, per acre and per vine, derived
--           from the picks and the vineyard map, never typed."
-- Depends on: [supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql,
--              supabase/migrations/0146_harvest_weights.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts]
-- Axioms enforced: T0-2. Tons from the picks, acres from the plant spaces,
--                  both computed on read. A13. A block with no map says it has
--                  no acreage rather than dividing by a guess, and a total
--                  with bins still to weigh says it is short.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- 0115 made acreage a count of plant spaces over the block's density, because
-- the winemaker's own sheet had been dividing by 1089 and 1245 all along. The
-- picks carry their block and variety. Put the two together and every block
-- says what it gave: tons an acre and pounds a vine, the two numbers a
-- vineyard is talked about in.
--
-- **Bearing vines only.** The map records young scions and rootstock
-- separately from vines, and a scion grafted this spring carries no fruit, so
-- counting it would make every replanted block look worse than it is. The
-- acreage here is of the vines that could have been picked, and the column says
-- so. The planted acreage is still `block_planting`'s.
--
-- **By block and variety together**, because that is what a pick is: Tudor
-- North's Grüner Veltliner and its Müller Thurgau are two rows, each against
-- the acres of that variety in that block. A block the map does not cover,
-- which is every block outside Vitae Springs today, gives its tons and says it
-- has no acreage.

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
         max(f.picked)                     as last_picked
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
       p.last_picked
  from picked p
  join block b on b.id = p.block_id
  left join vineyard vy on vy.id = b.vineyard_id
  left join term t on t.id = p.variety_id
  left join bearing br on br.block_id = p.block_id and br.variety_id = p.variety_id;

comment on view block_yield is
  'What each block and variety gave in a vintage: tons from the picks, bearing acres '
  'and vines from the plant spaces, tons an acre and pounds a vine. Derived.';

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.block_yield', 'cellar', 'What each block gave',
   'Tons an acre and pounds a vine, by block and variety, from the picks and the vineyard map.',
   'block_yield', 'block', 'block', 20)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;
