-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A wine can say which blocks it came from again: the function that
--           answers it had been failing on every call since the vineyard
--           became a table."
-- Depends on: [supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0039_vineyard.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  supabase/migrations/0161_what_each_wine_is_made_of.sql]
-- Axioms enforced: T0-2. Block composition is a function and not a column;
--                  this is the function working.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- CLAUDE.md's first example of "never store what is derived" is block
-- composition, and `block_composition` (0002) is the function it means. It
-- read `block.vineyard`, a text column, and 0039 replaced that with
-- `vineyard_id` when a vineyard became a thing of its own. A SQL function's
-- body is checked when it is created and not again, so the column went and the
-- function stayed, and from then on every call failed with "column b.vineyard
-- does not exist". Nothing in the apps asked it yet, and no assertion called
-- it, so nobody saw. Found building a screen that would have.
--
-- The same shape cannot pass silently again: the assertion suite now
-- recompiles every SQL function in the schema against the schema as it is.

create or replace function block_composition(p_node_id uuid)
returns table (block_id uuid, vineyard text, block_name text, share numeric)
language sql
stable
set search_path = public, pg_temp
as $$
  select b.id, vy.name, b.name, sum(s.share)
    from node_bin_shares(p_node_id) s
    join node n on n.id = s.bin_id
    join block b on b.id = n.block_id
    left join vineyard vy on vy.id = b.vineyard_id
   group by b.id, vy.name, b.name
   order by 4 desc;
$$;
