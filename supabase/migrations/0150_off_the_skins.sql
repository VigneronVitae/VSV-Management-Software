-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A red on its skins can be found and pressed off them, its cuts
--           named the way this cellar names them, and a dump can say the
--           volume was over-counted."
-- Depends on: [supabase/migrations/0148_reds_go_into_fermenters.sql,
--              supabase/migrations/0142_a_dump_says_why.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts,
--                  supabase/migrations/0151_a_cut_counts_once.sql,
--                  supabase/migrations/0158_a_ferment_is_variables.sql]
-- Axioms enforced: T0-2. Which lots are on their skins is a view over what
--                  0148 wrote, never a flag kept up to date by hand.
-- Open sorries: none new. S-147 is discharged by this and the press screen.
-- ---------------------------------------------------------------------------

-- Three answers from 2026-09-27.
--
-- **Pressing off skins.** "Free run (pumping the juice out before pressing),
-- 2nd free run (from press before it actually starts pressing), press, hard
-- press. All in litres." S-147 feared that `start_press` would count nothing
-- going in for a lot held in pounds; tried against practice, it counts the
-- lot's pounds, shared across its fermenters, because a weighed quantity with
-- no per-vessel estimate falls to counting vessels, which is right here. So
-- the kernel needed only the cut it did not have, and a way for the press
-- screen to find what is on its skins.
--
-- **The free run is recorded as a cut of the pressing even though it is pumped
-- out of the fermenter before anything goes into the press.** Physically it
-- never touches the press; as a record it is the first thing the pressing gives,
-- and its litres belong in the pressing's yield. Starting the press when the
-- pumping starts is what makes that true.
--
-- **Dumping a count that was wrong.** "Maybe a third, of over counting? Like I
-- estimated 900 and it was 800." Skinny Boy's 110 L was exactly that, recorded
-- as a loss on the day before this reason existed; its note says so, and the
-- event is not rewritten.

insert into term (kind, value, label, sort_order) values
  ('dump_reason', 'overcount', 'Over-counted', 300)
on conflict (kind, value) do update set
  label = excluded.label, sort_order = excluded.sort_order, active = true;

-- Between the free run and the press, which is where it comes off.
insert into term (kind, value, label, sort_order) values
  ('press_cut', 'second_free_run', '2nd free run', 150)
on conflict (kind, value) do update set
  label = excluded.label, sort_order = excluded.sort_order, active = true;

create or replace view lot_on_skins with (security_invoker = true) as
select
  n.id                                            as node_id,
  n.name,
  n.quantity,
  n.unit,
  (n.attributes ->> 'whole_cluster_pct')::numeric as whole_cluster_pct,
  p.vessel_id,
  v.name                                          as vessel,
  p.net_lbs                                       as said_lbs,
  p.fill_pct                                      as said_fill_pct,
  p.from_at                                       as since
from node n
join placement p on p.node_id = n.id and p.to_at is null
join vessel v on v.id = p.vessel_id
where n.status = 'open'
  and n.stage = 'ferment'
  and coalesce((n.attributes ->> 'on_skins')::boolean, false);

comment on view lot_on_skins is
  'Every lot fermenting on its skins, one row per fermenter holding it. What the '
  'press screen offers to press off skins.';

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.on_skins', 'cellar', 'On skins',
   'Every red fermenting on its skins, with the fermenters holding it: what can be pressed off skins.',
   'lot_on_skins', 'vessel_id', 'name', 17)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;
