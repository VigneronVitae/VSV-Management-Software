-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Registers the vineyard screen, which the client did not have. A
--           vineyard was a heading on a list and a vineyard with no blocks was
--           a dead end."
-- Depends on: [supabase/migrations/0039_vineyard.sql,
--              supabase/migrations/0101_a_note_can_be_about_a_screen.sql]
-- Depended on by: [scripts/screens.sh, docs/status-ledger.md]
-- Axioms enforced: none new.
-- Open sorries: none new. S-51 still stands: `block` carries an admin-write
--               policy, so the adder this screen gains refuses for a cellar
--               hand, and it refuses visibly rather than silently.
-- ---------------------------------------------------------------------------

-- The screen registry is what a note points at, so a screen the client can
-- route to and the registry has never heard of reads to the person standing on
-- it as the notes feature being broken. scripts/screens.sh is the check, and it
-- reads places.ts, so this row and that place list go in together or the gate
-- fails. That is the intended behaviour and not a nuisance.
insert into screen (key, label) values
  ('vineyard', 'A vineyard')
on conflict (key) do nothing;
