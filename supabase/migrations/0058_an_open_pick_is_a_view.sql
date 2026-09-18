-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "What counts as an open pick is a rule, so it stops being three
--           filters typed into a client."
-- Depends on: [supabase/migrations/0033_intake.sql,
--              supabase/migrations/0057_the_contract.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0114_every_pick_stays_on_the_list.sql]
-- Axioms enforced: R-4 (a client that hardcodes what the kernel could answer is
--                  a rule the next client gets wrong)
-- ---------------------------------------------------------------------------
--
-- Found by `0057` within a minute of applying it, which is the whole argument
-- for declaring a contract.
--
-- The contract says a periphery may read `cellar.open_picks`, and naming the
-- relation behind it turned up the fact that there is no relation behind it.
-- `openPicks()` in `kernel.ts` reads the `node` table with three filters typed
-- in TypeScript: stage is `bin`, status is not `closed`, newest first. **That is
-- a definition of what a pick is, living in a client**, which is R-4 and is the
-- exact thing a second periphery would have to guess at and guess differently.
--
-- It is a small one and that is the point. A contract is worth having because it
-- makes the small ones visible before they are three clients old.

begin;

create or replace view open_pick with (security_invoker = true) as
select
  n.id,
  n.name,
  n.stage,
  n.status,
  n.vintage,
  n.non_vintage,
  n.block_id,
  n.variety_id,
  n.quantity,
  n.unit,
  n.created_at,
  -- What a periphery would otherwise have to ask a second question for. A pick
  -- with bins still to weigh is the one fact anybody wants beside its name.
  (select count(*) from unweighed_bin u where u.node_id = n.id) as unweighed
from node n
where n.stage = 'bin'
  and n.status <> 'closed';

comment on view open_pick is
  'Fruit in bins that has not been pressed, cancelled or sent away, with how '
  'many of its bins are still waiting for a scale. What counts as open is this '
  'view rather than a filter in a client. See 0058.';

update readable set relation = 'open_pick' where key = 'cellar.open_picks';

commit;
