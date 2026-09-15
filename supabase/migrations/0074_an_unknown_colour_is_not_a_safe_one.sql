-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "colour_stains answers false rather than null, and every caller asks
--           whether the colour is known before it asks whether it stains."
-- Depends on: [supabase/migrations/0071_a_wine_says_its_colour.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: A25 (the null-permit class: a predicate that answers null
--                  where a caller expects false permits whatever it guards)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- Caught by the A25 validator in the assertion suite within a minute of `0071`
-- being written, which is the entire reason that validator exists. `select
-- coalesce(...) from term where id = p_colour_id` returns **no rows** for an id
-- that is not a colour, and a scalar subquery over no rows is null, not false.
-- The coalesce guards the attribute and not the absence of the row.
--
-- **The danger is specific and it is this feature's own danger.** A caller
-- writing `where colour_stains(x)` gets nothing for an untold colour, which is
-- correct, and a caller writing `where not colour_stains(x)` gets nothing too,
-- which is not. The second is the shape `white_in_a_red_barrel` uses. Null is
-- the worst possible answer here because the whole point of the three states is
-- that an untold colour is not evidence of a harmless one.
--
-- **False is the right answer, and it is only right because the callers ask in
-- the right order.** `barrel_colour` tests for a stain first and for an untold
-- colour second, so an untold lot falls through to `unknown` rather than to
-- `white`. `barrel_warning` tests null before it tests staining.
-- `white_in_a_red_barrel` joins the colour vocabulary, so an untold lot is not
-- in it at all. Each of those is asserted.

begin;

create or replace function colour_stains(p_colour_id uuid)
returns boolean
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
  -- The aggregate, rather than a bare select, is what makes the no-row case
  -- false instead of null: bool_or over an empty set is null and the coalesce
  -- outside it is then reached, which is the thing the inner one could not do.
  select coalesce(
    (select bool_or(coalesce((t.attributes ->> 'stains')::boolean, false))
       from term t
      where t.id = p_colour_id and t.kind = 'wine_colour'),
    false);
$$;

comment on function colour_stains(uuid) is
  'Whether wine of this colour leaves colour in oak. False for a colour nobody '
  'has said, which is safe only because every caller asks whether the colour is '
  'known before it asks this. See 0074 and ledger A25.';

commit;
