-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Every row of the vineyard says when it was planted, on what and at
--           what spacing, from the best claim there is, and says whether
--           anybody here has confirmed it."
-- Depends on: [supabase/migrations/0164_a_claim_says_where_it_came_from.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/vineyard/src/index.ts, packages/vineyard/src/export.ts,
--                  supabase/migrations/0168_a_claim_can_be_wrong.sql]
-- Axioms enforced: T0-2. Read from the claims on every call; a row stores no
--                  planting year. T0-4. A confirmed claim outranks an inferred
--                  one, and the view says which it used.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- The vine map export wants a planting year beside every row, and the block
-- map gives them by block and sometimes by rows within a block: Southeast's
-- rows 1 to 10 in 1989 and 11 to 43 in 1998. Which claim applies to a row is a
-- rule, and a rule written in the export would be written again by the next
-- screen that wants it, so it is here.
--
-- **Confirmed first, then the narrowest.** For each row and each of planting
-- year, rootstock and spacing: claims somebody here has confirmed outrank
-- inferred ones; within that, a claim about these rows outranks one about the
-- whole block. If what is left still disagrees, the row says both, joined by
-- "or", rather than this choosing.

create or replace view row_fact with (security_invoker = true) as
with candidate as (
  select vr.id     as row_id,
         vr.block_id,
         vr.number as row_number,
         sc.kind,
         sc.kind_label,
         sc.value,
         sc.provenance,
         sc.source_title,
         (sc.subject_type = 'vine_row' or sc.row_from is not null) as specific
    from vine_row vr
    join sourced_claim sc
      on (sc.subject_type = 'block' and sc.subject_id = vr.block_id
          and (sc.row_from is null or vr.number between sc.row_from and sc.row_to))
      or (sc.subject_type = 'vine_row' and sc.subject_id = vr.id)
   where sc.kind in ('planted_year', 'rootstock', 'spacing')
),
ranked as (
  select c.*,
         dense_rank() over (partition by c.row_id, c.kind
                            order by (c.provenance = 'confirmed') desc, c.specific desc) as rk
    from candidate c
)
select row_id,
       block_id,
       row_number,
       kind,
       min(kind_label)                                         as kind_label,
       string_agg(distinct value, ' or ' order by value)       as value,
       bool_and(provenance = 'confirmed')                      as confirmed,
       count(distinct value) > 1                               as disputed,
       string_agg(distinct source_title, '; ' order by source_title) as sources
  from ranked
 where rk = 1
 group by row_id, block_id, row_number, kind;

comment on view row_fact is
  'For every vine row, its planting year, rootstock and spacing from the best claim: confirmed before inferred, these rows before the whole block.';

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('vineyard.row_facts', 'vineyard', 'What each row is said to be',
   'Planting year, rootstock and spacing for every row, from the best claim there is.',
   'row_fact', 'row_id', 'value', 413)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into screen (key, label) values ('vineyard', 'A vineyard')
on conflict (key) do nothing;
