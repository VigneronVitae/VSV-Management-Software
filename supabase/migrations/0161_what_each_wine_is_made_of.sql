-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Every wine in a vessel says which blocks and which varieties it
--           is made of, in shares, walked back through every press and blend
--           to the picks."
-- Depends on: [supabase/migrations/0160_block_composition_works_again.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts]
-- Axioms enforced: T0-2. Read from lineage on every call; nothing is copied
--                  onto the lot, which is the reason compost entry C-3 exists.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- The kernel has been able to answer "what is this made of" since 0002 and no
-- screen ever asked. With the vintage now in tanks, barrels and macrobins, and
-- the Grüner Veltliner and Müller Thurgau already restated by juice (0149),
-- it is worth being able to see. One row a lot in a vessel now, its blocks and
-- its varieties as ordered lists of shares.
--
-- **Only what the kernel knows, with no thresholds.** A label has rules about
-- what share of a variety or a place it must hold before it may be named, and
-- those are compliance questions this app has been told to leave to the
-- winery's advisor (S-8 to S-12). This shows the shares; what they permit on a
-- label is not its business.

create or replace view lot_makeup with (security_invoker = true) as
select n.id                                 as node_id,
       n.name,
       n.stage,
       n.vintage,
       n.quantity,
       n.unit,
       array_agg(v.name order by v.name)    as vessels,
       (select coalesce(jsonb_agg(jsonb_build_object(
                  'vineyard', bc.vineyard, 'block', bc.block_name,
                  'share', round(bc.share, 4)) order by bc.share desc), '[]'::jsonb)
          from block_composition(n.id) bc)  as blocks,
       (select coalesce(jsonb_agg(jsonb_build_object(
                  'variety', vc.variety, 'share', round(vc.share, 4)) order by vc.share desc), '[]'::jsonb)
          from variety_composition(n.id) vc) as varieties
  from node n
  join placement p on p.node_id = n.id and p.to_at is null
  join vessel v on v.id = p.vessel_id
 where n.status = 'open' and n.stage <> 'bin'
 group by n.id;

comment on view lot_makeup is
  'Every lot in a vessel with the blocks and varieties it is made of, as shares, '
  'walked back through lineage to the picks. Derived on every read.';

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.lot_makeup', 'cellar', 'What each wine is made of',
   'Blocks and varieties, as shares, for every lot in a vessel.',
   'lot_makeup', 'node_id', 'name', 21)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into screen (key, label) values ('makeup', 'What each wine is made of')
on conflict (key) do nothing;
