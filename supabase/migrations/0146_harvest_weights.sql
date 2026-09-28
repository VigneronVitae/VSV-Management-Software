-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Harvest weights so far, totalled by variety, by the day it was
--           picked, and by both, so the screen and the spreadsheet it exports
--           add up the same way."
-- Depends on: [supabase/migrations/0114_every_pick_stays_on_the_list.sql,
--              supabase/migrations/0143_a_record_can_say_when.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts,
--                  supabase/migrations/0153_a_bin_can_change_parts.sql,
--                  supabase/migrations/0159_what_an_acre_gave.sql,
--                  supabase/migrations/0163_a_bin_tipped_or_thrown_away.sql]
-- Axioms enforced: T0-2. Three views over `fruit_log`, nothing stored.
--                  A13. A pick with bins nobody has weighed yet is counted as
--                  such, so a total that is short says it is short.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- "There should specifically be a section for harvest weights so far that has
-- all of the picks and weights grouped by variety and/or pick date and it can
-- export into at least an excel." And just before it: "the weighing and
-- picking might be on different days."
--
-- **Grouped by the day it was picked, never the day it was weighed.** A pick
-- weighed the next morning is still that day's fruit. `fruit_log.picked` is the
-- day the first bin went in, in the winery's zone, since 0143; nothing here
-- reads a weighing's date.
--
-- **The totals are the kernel's.** A total is a rule about what gets added up:
-- whether an unweighed pick is zero or missing, whether a pick with half its
-- bins weighed counts. The screen and the spreadsheet both read these views, so
-- the number on the phone and the number in Excel cannot disagree.
--
-- **What is short says so.** `lbs` is what the scale has said, which for a pick
-- with bins still to weigh is less than what came in. Every row carries
-- `bins_unweighed` beside the weight, so nobody reads a partial total as the
-- whole one.

-- ---------------------------------------------------------------------------
-- First, a count that was wrong
-- ---------------------------------------------------------------------------
--
-- `fruit_log.bins_weighed` counted weighings, not bins: `count(distinct
-- data -> 'bins' ->> 0)` is the number of scale readings, because a reading
-- names the bins that were on the scale and only its first was counted. Two
-- bins weighed together read as one weighed. Found by building this screen
-- against the cellar: the Grüner Veltliner said one of two bins weighed and the
-- ESV Chardonnay three of five, and every bin of both had been on the scale.
--
-- It is now the pick's bins that a standing weighing names, where standing
-- means no later weighing supersedes it, which is the same test `unweighed_bin`
-- has always used. Replaced in place: one expression changes and the columns
-- do not. `picked` stays as 0143 made it.
create or replace view fruit_log with (security_invoker = true) as
 SELECT n.id,
    n.name,
    (COALESCE(( SELECT min(p.from_at) AS min
           FROM placement p
          WHERE p.node_id = n.id), n.created_at) AT TIME ZONE 'America/Los_Angeles'::text)::date AS picked,
    n.created_at,
    n.vintage,
    n.non_vintage,
    n.status,
    t.label AS variety,
    vy.name AS vineyard,
    b.name AS block,
    n.quantity AS lbs,
    round(n.quantity / 2000.0, 3) AS tons,
    ( SELECT count(*) AS count
           FROM placement p
          WHERE p.node_id = n.id) AS bins,
    ( SELECT count(*) AS count
           FROM placement p
          WHERE p.node_id = n.id AND p.to_at IS NULL) AS bins_held,
    ( SELECT count(*) AS count
           FROM placement p
          WHERE p.node_id = n.id
            AND EXISTS ( SELECT 1
                   FROM event e
                  WHERE e.subject_type = 'node'::text AND e.subject_id = n.id
                    AND e.operation_id = term_id('operation'::text, 'weigh'::text)
                    AND (e.data -> 'bins'::text) ? p.vessel_id::text
                    AND NOT EXISTS ( SELECT 1
                           FROM event s
                          WHERE s.subject_type = 'node'::text AND s.subject_id = n.id
                            AND s.operation_id = term_id('operation'::text, 'weigh'::text)
                            AND (s.data ->> 'supersedes'::text)::uuid = e.id))) AS bins_weighed
   FROM node n
     LEFT JOIN term t ON t.id = n.variety_id
     LEFT JOIN block b ON b.id = n.block_id
     LEFT JOIN vineyard vy ON vy.id = b.vineyard_id
  WHERE n.stage = 'bin'::node_stage;

-- ---------------------------------------------------------------------------
-- The three ways of adding it up
-- ---------------------------------------------------------------------------

create or replace view harvest_weights_by_variety with (security_invoker = true) as
select
  f.vintage,
  coalesce(f.variety, 'No variety said') as variety,
  count(*)                               as picks,
  sum(f.bins)                            as bins,
  sum(f.bins) - sum(f.bins_weighed)      as bins_unweighed,
  round(sum(f.lbs), 1)                   as lbs,
  round(sum(f.lbs) / 2000.0, 3)          as tons,
  min(f.picked)                          as first_picked,
  max(f.picked)                          as last_picked
from fruit_log f
group by f.vintage, coalesce(f.variety, 'No variety said');

comment on view harvest_weights_by_variety is
  'Every variety''s fruit for a vintage: picks, bins, what the scale has said, '
  'and how many bins it has not said anything about yet.';

create or replace view harvest_weights_by_day with (security_invoker = true) as
select
  f.vintage,
  f.picked,
  count(*)                               as picks,
  sum(f.bins)                            as bins,
  sum(f.bins) - sum(f.bins_weighed)      as bins_unweighed,
  round(sum(f.lbs), 1)                   as lbs,
  round(sum(f.lbs) / 2000.0, 3)          as tons,
  string_agg(distinct coalesce(f.variety, 'No variety said'), ', ') as varieties
from fruit_log f
group by f.vintage, f.picked;

comment on view harvest_weights_by_day is
  'Each picking day''s fruit, by the day it was picked and not the day it was weighed.';

create or replace view harvest_weights_by_day_variety with (security_invoker = true) as
select
  f.vintage,
  f.picked,
  coalesce(f.variety, 'No variety said') as variety,
  count(*)                               as picks,
  sum(f.bins)                            as bins,
  sum(f.bins) - sum(f.bins_weighed)      as bins_unweighed,
  round(sum(f.lbs), 1)                   as lbs,
  round(sum(f.lbs) / 2000.0, 3)          as tons
from fruit_log f
group by f.vintage, f.picked, coalesce(f.variety, 'No variety said');

comment on view harvest_weights_by_day_variety is
  'Each variety on each picking day.';

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.weights_by_variety', 'cellar', 'Harvest weights by variety',
   'Picks, bins, pounds and tons for each variety in a vintage, with how many bins are still to weigh.',
   'harvest_weights_by_variety', 'variety', 'variety', 14),
  ('cellar.weights_by_day', 'cellar', 'Harvest weights by picking day',
   'Picks, bins, pounds and tons for each day fruit was picked, by the day it was picked.',
   'harvest_weights_by_day', 'picked', 'picked', 15),
  ('cellar.weights_by_day_variety', 'cellar', 'Harvest weights by day and variety',
   'Each variety on each picking day.',
   'harvest_weights_by_day_variety', 'picked', 'variety', 16)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into screen (key, label) values
  ('weights', 'Harvest weights')
on conflict (key) do nothing;
