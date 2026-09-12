-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Turns subject_type from a core enum naming three higher-module
--           tables into rows in the resolver registry. Adding a subject type is
--           now a row, and core no longer carries a fixed list of the things
--           other modules are allowed to be about."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0019_procedures.sql,
--              supabase/migrations/0023_subject_resolver.sql,
--              supabase/migrations/0024_task_board_via_registry.sql,
--              docs/architecture-rulings.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: none new. This removes a wrong-way edge rather than adding a
--                  rule: AR-A3 says dependency runs one way, and an enum in core
--                  listing node, vessel, location and block runs the other.
-- Open sorries: none new
-- ---------------------------------------------------------------------------

-- AR-E7, the first of its two halves. `subject_type` was an enum with four
-- labels, three of which name tables that belong to modules a given install may
-- not have. It never failed to install and it was always wrong, which is the
-- combination AR-E7 exists to describe.
--
-- The registry already exists. `0023` built `subject_resolver` so that a
-- polymorphic pointer could be checked at runtime, and its primary key is the
-- subject type. So the enum's job was already being done by a table, and this
-- migration deletes the enum rather than building a second registry beside it.
-- Registering a resolver is now what brings a subject type into existence.
--
-- **Following the precedent rather than inventing a pattern.** `0004` did this
-- once, moving the winemaking enums into `term` and replacing the columns with
-- references. The shape here is the same: the values become rows, the columns
-- become references, the type goes. The difference is that the rows land in a
-- registry that already existed rather than in `term`, because a subject type is
-- not vocabulary a person picks from, it is a statement about which module
-- resolves a pointer.

-- ---------------------------------------------------------------------------
-- The view and the functions have to go first
-- ---------------------------------------------------------------------------

-- A column's type cannot be altered while a view selects it, and task_board
-- selects subject_type. Dropped and recreated rather than replaced, because
-- `create or replace view` cannot change a column's type either. The definition
-- below is `0024`'s, unchanged except that the argument is now text.
drop view task_board;

drop function resolve_subject_name(subject_type, uuid);
drop function subject_is_resolvable(subject_type);
drop function register_subject_resolver(subject_type, text, text, text);

-- ---------------------------------------------------------------------------
-- The columns become text
-- ---------------------------------------------------------------------------

-- procedure.subject_type carries a default of 'vessel'::subject_type, and a
-- default is a dependency on the type in its own right: dropping the type with
-- the default still attached is refused, and the message names the default
-- rather than the column, which is a minute of confusion if you are not
-- expecting it.
alter table procedure alter column subject_type drop default;

alter table subject_resolver alter column subject_type type text;
alter table event            alter column subject_type type text;
alter table task             alter column subject_type type text;
alter table procedure        alter column subject_type type text;

alter table procedure alter column subject_type set default 'vessel';

drop type subject_type;

-- A subject type exists because a module registered a resolver for it. Restrict
-- rather than cascade: uninstalling a module while tasks still point at its
-- subjects should be refused and not silently take the tasks with it, which is
-- AR-A4's hard dependency blocking uninstall.
--
-- Note what this does not do. It does not make resolution fail when the module's
-- table is gone; `resolve_subject_name` still deflates to null for that, which is
-- AR-B7. This is about the registry row, not about the module's tables.
alter table event     add constraint event_subject_type_is_registered
  foreign key (subject_type) references subject_resolver(subject_type) on delete restrict;
alter table task      add constraint task_subject_type_is_registered
  foreign key (subject_type) references subject_resolver(subject_type) on delete restrict;
alter table procedure add constraint procedure_subject_type_is_registered
  foreign key (subject_type) references subject_resolver(subject_type) on delete restrict;

-- The bare-name rule the other registry columns already carry. Without it a
-- subject type could be written with a space or a quote in it, and it is
-- interpolated into dynamic SQL by resolve_subject_name.
alter table subject_resolver
  add constraint subject_type_is_a_bare_name
  check (subject_type ~ '^[a-z_][a-z0-9_]*$');

-- ---------------------------------------------------------------------------
-- The same three functions, taking text
-- ---------------------------------------------------------------------------

create or replace function register_subject_resolver(
  p_subject_type    text,
  p_relation        text,
  p_name_expression text,
  p_module          text
)
returns subject_resolver
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r subject_resolver;
begin
  if not is_admin() then
    raise exception 'only an administrator may register a resolver'
      using errcode = 'insufficient_privilege';
  end if;

  insert into subject_resolver (subject_type, relation, name_expression, module)
  values (p_subject_type, p_relation, p_name_expression, p_module)
  on conflict (subject_type) do update
     set relation        = excluded.relation,
         name_expression = excluded.name_expression,
         module          = excluded.module,
         registered_at   = now()
  returning * into r;

  return r;
end;
$$;

create or replace function resolve_subject_name(
  p_subject_type text,
  p_subject_id   uuid
)
returns text
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  r      subject_resolver;
  result text;
begin
  select * into r from subject_resolver where subject_type = p_subject_type;
  if not found then
    return null;
  end if;

  if to_regclass('public.' || quote_ident(r.relation)) is null then
    return null;
  end if;

  begin
    execute format('select (%s)::text from public.%I where id = $1',
                   r.name_expression, r.relation)
      into result
     using p_subject_id;
  exception when others then
    return null;
  end;

  return result;
end;
$$;

create or replace function subject_is_resolvable(p_subject_type text)
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from subject_resolver r
     where r.subject_type = p_subject_type
       and to_regclass('public.' || quote_ident(r.relation)) is not null
  );
$$;

-- ---------------------------------------------------------------------------
-- task_board again, unchanged apart from the argument type
-- ---------------------------------------------------------------------------

create view task_board
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
