-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The three tables 0115 added are readable by this winery rather than
--           by every signed-in account."
-- Depends on: [supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql]
-- Depended on by: [tests/schema_assertions.sql, docs/status-ledger.md,
--                  supabase/migrations/0117_the_vine_map_is_loaded.sql]
-- Axioms enforced: A5. Three more blanket reads would have widened a gap that
--                  is already filed rather than approved.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- 0115 wrote `using (true)` on all three reads, copying `vineyard_read` and
-- `block_read` from 0039. Those two are judged in the assertion suite as
-- **findings**, not as permissive: A5 says who this winery buys fruit from
-- should not be readable by every account including a custom crush client, and
-- they are named there as a gap that was inherited rather than chosen.
--
-- Copying a finding three more times is how a gap becomes the convention. 0112
-- already set the better precedent for exactly this question and gave the
-- reason: what the press is made of is this winery's business and a custom
-- crush client has no use for it. Which vine stands in row 4 of Tudor North is
-- the same kind of fact.
--
-- This does not fix `block_read`, `vineyard_read` or `planting_read`. Those
-- stay filed. It stops the new tables joining them.

drop policy if exists vine_row_read on vine_row;
create policy vine_row_read on vine_row for select to authenticated
  using (is_facility_user());

drop policy if exists plant_space_read on plant_space;
create policy plant_space_read on plant_space for select to authenticated
  using (is_facility_user());

drop policy if exists plant_change_read on plant_change;
create policy plant_change_read on plant_change for select to authenticated
  using (is_facility_user());
