-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The books module gets a periphery, so the eight hundred imported
--           transactions become something a thumb can work through rather than
--           a count in a query."
-- Depends on: [supabase/migrations/0101_a_note_can_be_about_a_screen.sql,
--              supabase/migrations/0109_a_module_says_where_it_lives.sql,
--              supabase/migrations/0122_money_that_has_already_moved.sql,
--              supabase/migrations/0126_only_a_person_confirms.sql]
-- Depended on by: [scripts/screens.sh, docs/status-ledger.md,
--                  packages/books/src/places.ts]
-- Axioms enforced: none new.
-- Open sorries: narrows S-94, the front door listing modules nobody can open.
--               One of the six is still shut, and it is `marketing`.
-- ---------------------------------------------------------------------------

-- The kernel and the data landed first and the door did not, which put `books`
-- in exactly the state the vineyard was in when he asked why the home page had
-- it greyed out. `module.path` is null, the launcher draws a module with no path
-- as a shut div rather than a link, and that was honest right up until there was
-- an app behind it.
--
-- The screen registry is what a note points at, so a screen the client routes to
-- and the registry has never heard of reads, to the person standing on it, as
-- the notes feature being broken. scripts/screens.sh is the check and it reads
-- places.ts, so these rows and that place list go in together or the gate fails.

insert into screen (key, label) values
  ('money',     'The books'),
  ('pile',      'A pile of transactions'),
  ('line',      'One transaction'),
  ('merchants', 'What a merchant has been called')
on conflict (key) do nothing;

-- Same origin as the other four, which is what makes one sign-in serve all of
-- them: supabase-js keeps the session in localStorage and localStorage is per
-- origin. This matters more here than anywhere else, because the books are the
-- one app somebody opens for ten minutes on a sofa rather than for an hour in a
-- barn, and a sign-in at that moment is a reason not to bother.
update module set path = '/books/' where key = 'books';

do $$
begin
  if not exists (select 1 from module where key = 'books' and path = '/books/') then
    raise exception 'the books module has no path, so the front door would still draw it shut';
  end if;
end $$;
