-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "One list of everything that has been started and not finished, so
--           what is in flight is a place rather than five badges somebody has
--           to already know to look for."
-- Depends on: [supabase/migrations/0052_press_as_a_process.sql,
--              supabase/migrations/0094_an_import_is_a_proposal.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0096_what_you_are_watching.sql]
-- Axioms enforced: T0-2 (running is derived from the absence of an ending,
--                  never a flag anybody sets or clears)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"There should also be a tab called running operations that
-- has open things: press going, pick going, etc."*
--
-- **Every one of these already existed as its own badge.** A press in progress
-- is on the home screen because a press is deliberately unfinished for hours. A
-- pick with unweighed bins is there because T1-4 lets a bin exist before its
-- weight. Both were put there one at a time, each time somebody noticed a thing
-- going missing, and the result is that knowing what is in flight requires
-- knowing which badges to read.
--
-- **Running is derived from the absence of an ending, in every case.** A press
-- is running because nothing finished it. A pick is open because its fruit is
-- still in bins. A procedure run is going because it has a start and no finish.
-- Not one of these is a flag, so not one of them can be left set by somebody who
-- walked away, which is the failure a "status: in progress" column always
-- eventually has.
--
-- **Two are empty today and are here anyway.** `procedure_run` and `task` have
-- no rows: the procedure runner and the task board are specified and unbuilt. A
-- union that omits them would have to be edited when they arrive, and the edit
-- is the thing that gets forgotten. They cost a branch each and they will light
-- up on their own.
--
-- The ordering is by how long it has been going, oldest first, because the
-- press somebody started four hours ago is the one worth asking about.

begin;

create or replace view running_operation with (security_invoker = true) as

-- A press with fruit in it and no finish. The one thing in this app that is
-- meant to stay unfinished for hours.
select
  'press'::text   as kind,
  'Press'::text   as heading,
  p.name          as what,
  coalesce(v.name, 'a press') || ', started '
    || to_char(p.started_at, 'HH24:MI') as detail,
  p.started_at    as since,
  'node'::text    as subject_type,
  p.node_id       as subject_id
from press_in_progress p
left join vessel v on v.id = p.press_vessel_id

union all

-- A pick whose fruit is still in bins. Closed when the last bin empties, which
-- is 0090, so this is exactly "there is fruit on the pad".
select
  'pick',
  'Picking',
  n.name,
  (select count(*)::text from placement pl
    where pl.node_id = n.id and pl.to_at is null)
    || ' bin(s) still full'
    || case when (select count(*) from unweighed_bin u where u.node_id = n.id) > 0
            then ', ' || (select count(*) from unweighed_bin u where u.node_id = n.id)::text
                 || ' waiting for the scale'
            else '' end,
  n.created_at,
  'node',
  n.id
from node n
where n.stage = 'bin'
  and n.status = 'open'
  and exists (select 1 from placement pl
               where pl.node_id = n.id and pl.to_at is null)

union all

-- A procedure somebody started and did not finish. No rows today: the runner is
-- specified and unbuilt, and this branch is here so that it appears by itself
-- rather than waiting for somebody to remember this view.
select
  'procedure',
  'Procedures',
  coalesce(pr.name, 'a procedure') || ' on ' || coalesce(v.name, 'a vessel'),
  'started ' || to_char(r.started_at, 'HH24:MI'),
  r.started_at,
  'vessel',
  r.vessel_id
from procedure_run r
join procedure_session s on s.id = r.session_id
left join procedure pr on pr.id = s.procedure_id
left join vessel v on v.id = r.vessel_id
where r.started_at is not null and r.finished_at is null

union all

-- A task somebody has picked up and not finished. Also empty today.
select
  'task',
  'Tasks',
  coalesce(t.instructions, 'a task'),
  'claimed ' || to_char(t.claimed_at, 'HH24:MI'),
  t.claimed_at,
  t.subject_type,
  t.subject_id
from task t
where t.status = 'claimed'

union all

-- An import part way through. A batch with steps nobody has decided is somebody
-- halfway down a spreadsheet, which is exactly the shape this list is for.
select
  'import',
  'Imports',
  b.source,
  w.waiting::text || ' of ' || w.steps::text || ' still to decide, read by ' || b.reader,
  b.created_at,
  'import'::text,
  b.id
from import_batch b
join import_waiting w on w.batch_id = b.id
where b.closed_at is null and w.waiting > 0;

comment on view running_operation is
  'Everything started and not finished, in one list. Running is derived from '
  'the absence of an ending in every case, so nothing here can be left set by '
  'somebody who walked away. See 0095.';

grant select on running_operation to authenticated;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.running', 'cellar', 'What is running',
   'Everything started and not finished: a press going, a pick with fruit still '
   'in bins, an import half decided.',
   'running_operation', 'subject_id', 'what', 5)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

commit;
