-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The list of modules is readable before sign-in, because the front
--           door draws itself before it knows who is looking."
-- Depends on: [supabase/migrations/0109_a_module_says_where_it_lives.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0111_a_count_that_reads_zero_is_a_lie.sql]
-- Axioms enforced: A13 (a chooser with nothing on it and no explanation reads
--                  as an app with nothing in it)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- `0109` scoped the module list to `authenticated`, which was the reflex and was
-- wrong. The front door is the first thing anybody opens and it draws before
-- there is a session: an intern following a link for the first time got a
-- heading, the words "pick what you are doing", and nothing to pick. Found by
-- opening it rather than by reasoning about it.
--
-- **What this exposes, weighed rather than waved through.** Five rows saying
-- Cellar, Shop, Stores, Vineyards and Marketing, with a count of how many things
-- each one can do. No wine, no names, no quantities, nothing about whose fruit is
-- whose. It is the list of doors, not what is behind them, and each door still
-- refuses anybody who is not signed in.
--
-- S-77 still stands: none of this is reachable from outside the tailnet, and
-- this migration does not change that. What it changes is that the first screen
-- somebody sees works before they have signed in, which is the difference
-- between an app that looks empty and one that looks like an app.

begin;

drop policy if exists module_read on module;

-- `public` rather than `authenticated`: both the signed-in and the not-yet roles.
create policy module_read on module for select to public using (true);

grant select on module_detail to anon;

comment on view module_detail is
  'The modules, with how much of the contract each one owns. Readable before '
  'sign-in, because the front door draws itself before it knows who is looking '
  'and a chooser with nothing on it is worse than a sign-in prompt. See 0109 '
  'and 0110.';

commit;
