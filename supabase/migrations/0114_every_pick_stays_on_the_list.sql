-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "One row per pick, open or finished, with what it was and what it
--           weighed. A pick used to leave the only list it was on at the moment
--           it became history."
-- Depends on: [supabase/migrations/0033_intake.sql,
--              supabase/migrations/0039_vineyard.sql,
--              supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0058_an_open_pick_is_a_view.sql,
--              supabase/migrations/0101_a_note_can_be_about_a_screen.sql]
-- Depended on by: [docs/status-ledger.md, scripts/screens.sh]
-- Axioms enforced: T0-2, nothing here is stored. A13: a finished pick used to
--                  read as zero bins, which is a refusal shaped like an answer.
-- Open sorries: none new. See S-96 for importing previous years.
-- ---------------------------------------------------------------------------

-- "I want to be able to look at picks after they are done, see how many bins of
-- each variety, etc. Like how do I check out the bins from yesterday's Pinot
-- Gris pick?"
--
-- He could not, and there were two reasons stacked on each other.
--
-- **The list ends at the press.** `open_pick` is `status <> 'closed'` and
-- pressing closes a pick, so the intake screen drops a pick at exactly the
-- moment it stops being a plan and becomes a record. Nothing else lists picks.
--
-- **And the obvious way to count its bins reports nothing.** `pick_bin` joins
-- the bins a pick is in, present tense, and pressing empties them. Every
-- finished pick therefore reads as zero bins and no weight, which is A13 in its
-- purest form: a number that looks like an answer and means "I stopped
-- looking". The bins are in `placement`, which is append-only, and the count
-- below comes from there. `to_at is not null` is a bin that has been emptied,
-- not a bin that was never there.
--
-- The weight needed no rescuing. `0033` already writes the pick's total to
-- `node.quantity` as the bins are weighed, and that survives pressing. It is
-- read here rather than resummed, because resumming it would be a second
-- answer to a question the kernel has already answered, and two answers
-- eventually disagree.
create or replace view fruit_log with (security_invoker = true) as
select
  n.id,
  n.name,
  -- The day it was picked. `created_at` is when the first bin landed, which is
  -- the pick happening, because a pick does not exist until then.
  (n.created_at at time zone 'UTC')::date as picked,
  n.created_at,
  n.vintage,
  n.non_vintage,
  n.status,
  t.label   as variety,
  vy.name   as vineyard,
  b.name    as block,
  n.quantity as lbs,
  -- Tons because that is the unit a contract and a conversation are in, and
  -- doing the division in three clients is how two of them get it wrong.
  round(n.quantity / 2000.0, 3) as tons,
  (select count(*) from placement p where p.node_id = n.id) as bins,
  (select count(*) from placement p
    where p.node_id = n.id and p.to_at is null) as bins_held,
  -- How much of the weight is actually known. A pick with four bins and three
  -- weighings has a number that is not its whole weight, and a table that does
  -- not say so invites somebody to add a column up and believe it.
  (select count(distinct (e.data -> 'bins' ->> 0))
     from event e
    where e.subject_type = 'node' and e.subject_id = n.id
      and e.operation_id = term_id('operation', 'weigh')) as bins_weighed
from node n
left join term t on t.id = n.variety_id
left join block b on b.id = n.block_id
left join vineyard vy on vy.id = b.vineyard_id
where n.stage = 'bin';

comment on view fruit_log is
  'Every pick, open or finished, with variety, vineyard, block, bins and weight. '
  'Bins come from placement rather than from what a bin holds now, because '
  'pressing empties the bins and the present tense reports finished picks as '
  'nothing. Weight is read from node.quantity, which intake already maintains.';

-- The contract. A periphery reads this rather than working out what a pick
-- weighed from three tables, which is the whole point of naming a readable.
insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.fruit_log', 'cellar', 'Every pick',
   'One row per pick, open or finished: variety, vineyard, block, date, bins and weight. Sortable by any of them.',
   'fruit_log', 'id', 'name', 128)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into screen (key, label) values
  ('fruit', 'Every pick')
on conflict (key) do nothing;
