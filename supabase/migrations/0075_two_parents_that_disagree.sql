-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "lot_colour counts the parents before it collapses them, so a blend
--           of a red and a white is untold rather than arbitrarily one of them."
-- Depends on: [supabase/migrations/0071_a_wine_says_its_colour.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-4 (a value nobody stated is not written on their behalf,
--                  and an arbitrary pick between two parents is exactly that)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- `0071` said the right thing in its comment and did the wrong thing in its
-- query. The intent: two parents of different colours leave a lot untold, since
-- deciding that red wins would be inventing a winemaking rule nobody stated.
-- What it did: `distinct on (depth)` collapsed the parents to one row **before**
-- the count that was meant to notice there were two, so the count was always
-- one and the answer was whichever colour sorted first by uuid.
--
-- **Arbitrary, and stable enough to look deliberate.** The same blend would
-- report the same colour every time, because the order came from the uuids,
-- which do not change. Nothing would have looked wrong until somebody noticed a
-- Pinot Noir and Chardonnay blend calling itself red because of a hex digit.
--
-- Found by the assertion written alongside it in the same hour, which is the
-- argument for writing the assertion in the same hour.

begin;

create or replace function lot_colour(p_node_id uuid)
returns uuid
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
  with recursive up as (
    select n.id, n.colour_id, 0 as depth
      from node n where n.id = p_node_id
    union all
    select p.id, p.colour_id, up.depth + 1
      from up
      join lineage l on l.child_id = up.id
      join node p on p.id = l.parent_id
     where up.colour_id is null and up.depth < 20
  )
  -- Everything told at the shallowest depth anything was told at, counted
  -- before it is collapsed. One distinct colour is an answer; two is a
  -- question, and a question is null.
  select case
           when count(distinct u.colour_id) = 1
           then (array_agg(distinct u.colour_id))[1]
         end
    from up u
   where u.colour_id is not null
     and u.depth = (select min(depth) from up where colour_id is not null);
$$;

comment on function lot_colour(uuid) is
  'The colour of a lot: what somebody said, or what its parents said if nobody '
  'has said about this one. Null when nobody has said, and null when two '
  'parents disagree. See 0071 and 0075.';

commit;
