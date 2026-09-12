-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Removes the last place where a core object names a module table
--           declaratively. task_board's CASE over subject_type named node,
--           vessel, location and block, which Postgres recorded in pg_rewrite,
--           which is why dropping the vineyard module took the task board with
--           it."
-- Depends on: [supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0004_terms_and_effects.sql,
--              supabase/migrations/0023_subject_resolver.sql,
--              docs/architecture-rulings.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-2, in that the subject's name stays derived on read.
-- Open sorries: S-42, which this makes load-bearing rather than theoretical.
-- ---------------------------------------------------------------------------

-- AR-E6 names this as the thing blocking the scheduling move: "task_board, a
-- core view whose CASE over subject_type names node, vessel and block
-- declaratively. That single view is why core as drawn cannot install alone."
-- The survey probed it: `drop table block cascade` reports the cascade to
-- task_board. So does this tree, today, and an assertion added in 0023 says so.
--
-- The replacement calls resolve_subject_name, which reads the registry and
-- builds its statement at run time. A function body is not tracked in pg_depend,
-- and this one does not name a module relation even in its body, because the
-- relation arrives as text from a row. After this the view depends on task,
-- term, app_user and subject_resolver, all of them core.
--
-- **A deviation from the prompt, recorded rather than hidden.** W-2 says to
-- rewrite this as a lateral join, and AR-E5 uses the same phrase. A lateral join
-- needs the relation known when the statement is planned, and the whole point
-- here is that it is not known until a row is read, so a view cannot have one. A
-- scalar call is the achievable form of the same idea and it buys the same
-- property, which is that core names no module table. The cost is S-42, one
-- dynamic query per row, which was filed in 0023 as a trade and is now being
-- taken rather than contemplated. If the board is ever slow enough to measure,
-- the answer is a per-type contract view and a real lateral join over the union,
-- which is AR-B4's shape and belongs with the manifest work in phase 8.
--
-- create or replace, not drop and create: the column list, order and types are
-- unchanged, so anything selecting from this view keeps working and no grant is
-- lost. subject_name was text and stays text.

create or replace view task_board
with (security_invoker = true) as
  select
    t.id,
    t.subject_type,
    t.subject_id,
    t.due_from,
    t.due_to,
    t.assignee,
    t.claimed_at,
    t.claimed_by,
    t.status,
    t.instructions,
    t.recurrence,
    t.created_from,
    t.created_at,
    t.created_by,
    t.operation_id,
    t.operation_kind,
    op.value as operation,
    op.label as operation_label,

    -- Was a CASE naming four tables. A task whose subject cannot be resolved,
    -- because the module is absent or the row is gone or the caller cannot see
    -- it, shows a null name and still appears on the board. That is the same
    -- answer the CASE gave for an unknown subject_type, and it is AR-G2: a
    -- consumer renders an unresolved subject rather than erroring or hiding it.
    resolve_subject_name(t.subject_type, t.subject_id) as subject_name,

    u.name as claimed_by_name,
    a.name as assignee_name
  from task t
  join term op on op.id = t.operation_id
  left join app_user u on u.id = t.claimed_by
  left join app_user a on a.id = t.assignee
 where t.status in ('open', 'claimed');

comment on view task_board is
  'The claimable board. Names its subjects through subject_resolver rather than through a CASE, so core declares no dependency on node, vessel, location or block. Dropping a module makes its tasks render with a null subject name instead of dropping this view.';
