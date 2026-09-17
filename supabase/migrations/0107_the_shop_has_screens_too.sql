-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The shop's screens are rows too, so a note about one of them points
--           at something."
-- Depends on: [supabase/migrations/0101_a_note_can_be_about_a_screen.sql,
--              supabase/migrations/0106_the_acts_a_shop_performs.sql]
-- Depended on by: [tests/schema_assertions.sql, scripts/screens.sh]
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker, about the shop: *"Matt will probably be one of the biggest users
-- of this and he can give me good feedback."*
--
-- Which is the reason `0101` exists. A note about wording points at the screen
-- whose wording it is, and the shop shipped with a chrome that had no note
-- button and screens that were in no registry, so the one person most likely to
-- have something to say had nowhere to put it.
--
-- Five rows. `scripts/screens.sh` now reads both clients, so a shop screen added
-- without a row fails the gate the same way a cellar one does.

begin;

insert into screen (key, label) values
  ('machines',     'Machines'),
  ('machine',      'A machine'),
  ('machine-work', 'Record work on a machine'),
  ('machine-new',  'Add a machine'),
  ('model-new',    'Add a machine model')
on conflict (key) do update set label = excluded.label;

commit;
