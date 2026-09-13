-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Takes the last winemaking edge out of the scheduling block, so that
--           template, template_step, task and task_claim_log are core."
-- Depends on: [supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0024_task_board_via_registry.sql,
--              supabase/migrations/0027_term_kind_registry.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: AR-E6, the scheduling block moves to core and points at a
--                  generic subject.
-- Open sorries: S-46, a template may declare it applies to a vocabulary nothing
--               generates from, and nothing says so.
-- ---------------------------------------------------------------------------
--
-- W-2 phase 6, five sessions late, and late for a reason worth recording: the
-- ruling said it was blocked by `task_board`, `0024` removed that blocker, and
-- the entry went on saying blocked because a blocking relationship lived in a
-- document that nothing re-read. `scripts/status.sh` exists so that the next one
-- is visible on a run rather than on a re-read.
--
-- What was actually left. Every outward edge of the four scheduling tables was
-- already core: `app_user`, `subject_resolver`, `term` of kind `operation`, which
-- `0027`'s registry records as core. Exactly one was not:
--
--   template.variety_id, with a generated variety_kind pinned to 'variety',
--   composite foreign key to term(id, kind)
--
-- `variety` is winemaking, which `term_kind` says in a row. So a core table
-- carried "a schedule is for a grape variety", which is the same wrong-way
-- knowledge `AR-E7` took out of two enums, in a column instead.
--
-- The fix is the same move a third time: **the vocabulary a template applies to is
-- a parameter rather than a fact about the table.** A spray schedule applies to a
-- variety. A steaming schedule applies to a vessel type. An opening checklist
-- applies to a location kind. The kind is recorded per row and the composite
-- foreign key still proves the term is of the kind claimed, so nothing is loosened:
-- what changes is that core stops naming which kind it is.
--
-- The knowledge moves to the caller, which is where it belongs.
-- `generate_inferred_history` is winemaking behaviour and it asks for
-- `applies_to_kind = 'variety'` itself.
--
-- **Two traps, both named by W-10 and both from `0027`.**
--
-- Dropping a generated column moves it to the end of the table and silently
-- rebinds any positional alias list. Avoided rather than checked: `variety_id`
-- is **renamed**, which holds its position, and `variety_kind` is the last column
-- already, so the column it is replaced by lands where it was. Nothing reads
-- `template` positionally today, and this way nothing has to be re-checked if
-- something does later.
--
-- A validator proving a vocabulary exists by casting and catching the failure
-- becomes always-succeeding when rewritten to text. Not applicable here and
-- checked rather than assumed: the proof that a term is of the kind claimed is a
-- composite foreign key, which is a constraint rather than a cast, and it is
-- recreated below against the same two columns it had before.

begin;

-- Renamed, not added and dropped. See the note above: this holds the column's
-- position and there is no reorder to hand-check.
alter table template rename column variety_id to applies_to_id;

alter table template
  drop constraint if exists template_variety_is_a_variety,
  drop constraint if exists template_variety_name_key;

-- The kind is a value now rather than a generated constant. It is the last
-- column and its replacement lands in the same place.
alter table template drop column variety_kind;
alter table template add column applies_to_kind text;

update template set applies_to_kind = 'variety' where applies_to_id is not null;

alter table template
  add constraint template_applies_to_a_registered_kind
    foreign key (applies_to_id, applies_to_kind) references term (id, kind),
  -- Both or neither. A template with a kind and no term names a vocabulary and
  -- no member of it, which reads as "applies to every variety" and is not what
  -- the composite key would enforce.
  add constraint template_applies_to_both_or_neither
    check ((applies_to_id is null) = (applies_to_kind is null)),
  -- Was unique (variety_id, name). Two templates of the same name against
  -- different vocabularies are different schedules, so the kind is part of it.
  add constraint template_applies_to_name_key
    unique (applies_to_id, applies_to_kind, name);

comment on column template.applies_to_kind is
  'Which registered vocabulary this schedule is written against. Core does not '
  'know which kinds exist; term_kind does, and the consumer asks for the one it '
  'understands. See 0031 and AR-E6.';

-- Winemaking behaviour, asking for winemaking vocabulary by name. This is the
-- whole of the move: the knowledge that history generation is keyed on variety
-- now lives in the function that generates history, not in the shape of a core
-- table.
--
-- Taken from the catalog and changed in one clause rather than retyped, per the
-- rule 0027 earned.
create or replace function generate_inferred_history(
  p_node_id uuid,
  p_from timestamp with time zone default now()
)
returns integer
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  n        node;
  tmpl     uuid;
  step     record;
  at_time  timestamptz;
  written  int := 0;
begin
  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no such node %', p_node_id;
  end if;
  if n.variety_id is null then
    return 0;
  end if;

  select t.id into tmpl
    from template t
   where t.active
     and t.applies_to_kind = 'variety'
     and t.applies_to_id = n.variety_id
   order by t.created_at
   limit 1;

  if tmpl is null then
    return 0;
  end if;

  at_time := p_from;

  for step in
    select * from template_step where template_id = tmpl order by step_order
  loop
    at_time := at_time + coalesce(step.offset_interval, interval '0');

    insert into event
      (operation_id, subject_type, subject_id, at, by_user, data, provenance)
    values
      (step.operation_id, 'node', p_node_id, at_time, auth.uid(),
       step.default_data, 'inferred');

    written := written + 1;
  end loop;

  return written;
end;
$function$;

commit;
