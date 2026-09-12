-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Makes vessel_state obey row level security. It did not, so every
--           custom crush client could read every lot in the cellar by name
--           through the vessel list, which is the screen they would open first."
-- Depends on: [supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0016_lot_owner_name.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql, supabase/migrations/0018_lot_privacy.sql]
-- Axioms enforced: T0-1 (the database refuses, rather than the screen omitting)
-- Open sorries: none new
-- ---------------------------------------------------------------------------

-- A view runs with its owner's rights unless it says otherwise, so RLS on the
-- tables underneath does nothing. lot_state and task_board were both created
-- with security_invoker and vessel_state was not, which is the kind of
-- inconsistency that looks like nothing in a diff and is a confidentiality
-- breach in a cellar with two clients in it.
--
-- Measured before the fix, acting as a client with one lot of their own:
--
--   via node table      1 row
--   via lot_state       1 row
--   via vessel_state    2 rows, including the other party's lot by name
--
-- node_read has been correct since 0003. Nothing consulted it, because the
-- screens read the view. The assertions did not catch it because they queried
-- the table directly, which is the lesson worth keeping: test the thing the
-- app actually reads.
--
-- Setting this changes what a client sees and nothing about what staff see,
-- because is_facility_user() already returns true for them.

alter view vessel_state set (security_invoker = true);

-- vessel_read and placement_read are both `true`, so a client still sees that a
-- vessel exists and that something is in it. What they can no longer see is
-- whose it is or what it is, because those columns come from node. That is the
-- shape of the thing rather than its identity, and it is the correct amount for
-- somebody walking their own barrels in a shared cellar.
