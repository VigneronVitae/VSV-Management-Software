-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The vineyard module gets a periphery, so the front door stops
--           listing a thing nobody can open."
-- Depends on: [supabase/migrations/0101_a_note_can_be_about_a_screen.sql,
--              supabase/migrations/0109_a_module_says_where_it_lives.sql,
--              supabase/migrations/0117_the_vine_map_is_loaded.sql]
-- Depended on by: [scripts/screens.sh, docs/status-ledger.md]
-- Axioms enforced: none new.
-- Open sorries: narrows S-94, which is the front door listing modules nobody
--               can get. Two of the five are still shut.
-- ---------------------------------------------------------------------------

-- "How do I get to the vineyard module? The home page still has it grayed out."
--
-- Because `module.path` was null, and it was null because there was no app. The
-- launcher draws a module with no path as a `module-shut` div rather than a
-- link, which is honest and was the right thing to show. Now there is one.

insert into screen (key, label) values
  ('blocks', 'The vineyard'),
  ('block',  'A block'),
  ('row',    'A row of vines')
on conflict (key) do nothing;

-- Same origin as the cellar and the shop, which is what makes one sign-in serve
-- all three: supabase-js keeps the session in localStorage and localStorage is
-- per origin. A different host would mean signing in three times, which for
-- somebody in a vineyard means not signing in at all.
update module set path = '/vineyard/' where key = 'vineyard';
