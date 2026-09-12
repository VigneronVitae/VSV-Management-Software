-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Gives core a way to check a polymorphic pointer at runtime without
--           naming a module table anywhere. task.subject_type and
--           task.subject_id cannot carry a foreign key, because a core table
--           cannot reference a module that may not be installed. A registry is
--           how the pointer becomes checkable anyway."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0004_terms_and_effects.sql,
--              supabase/migrations/0022_admission_and_authorship.sql,
--              docs/architecture-rulings.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql, supabase/migrations/0024_task_board_via_registry.sql, supabase/migrations/0026_subject_type_registry.sql]
-- Axioms enforced: T0-2, in that what a subject is called is derived on read
--                  rather than copied onto the task.
-- Open sorries: S-41, S-42
-- ---------------------------------------------------------------------------

-- AR-E5. The polymorphic task subject stays polymorphic and resolvers are
-- registered. The A-1 survey measured that building this before the scheduling
-- move costs under a day and building it after costs half again, because
-- task_board's CASE becomes a lateral join rather than being rewritten twice.
--
-- The whole point is the absence of a declarative edge. `relation` is text and
-- not regclass on purpose: a regclass column would record a dependency in
-- pg_depend, which is exactly the wrong-way edge AR-A3 forbids and exactly what
-- makes `drop table block cascade` reach into core today. Text is resolved at
-- runtime by to_regclass, which answers null for something that is not there.

create table subject_resolver (
  subject_type     subject_type primary key,

  -- Unqualified relation name in public. Quoted as an identifier when used, so
  -- this half cannot be injected into.
  relation         text not null,

  -- A SQL expression over that relation producing the display name. Cannot be
  -- quoted, because it is an expression rather than an identifier. S-41.
  name_expression  text not null,

  -- Which module claims to provide this. Not enforced against anything yet;
  -- phase 8 is where a manifest makes it mean something.
  module           text not null,

  registered_at    timestamptz not null default now(),

  constraint relation_is_a_bare_name
    check (relation ~ '^[a-z_][a-z0-9_]*$'),
  constraint name_expression_is_not_empty
    check (length(btrim(name_expression)) > 0),
  constraint module_is_a_bare_name
    check (module ~ '^[a-z_][a-z0-9_]*$')
);

comment on table subject_resolver is
  'How a subject type is rendered, registered as a row rather than compiled into a view. relation is text and not regclass on purpose: a regclass would be a declarative dependency from core on a module table, which is the edge this table exists to remove.';

alter table subject_resolver enable row level security;

-- Everyone signed in reads it, because rendering a task board needs it and
-- knowing that `node` renders as its name discloses nothing.
create policy subject_resolver_read on subject_resolver
  for select to authenticated using (true);

create policy subject_resolver_admin_write on subject_resolver
  for all to authenticated
  using (is_admin()) with check (is_admin());

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

-- A module registers by writing a row. That is the AR-B1 shape: core holds a
-- registry rather than an enumeration, and adding a subject type is a row and
-- never a core migration.
create or replace function register_subject_resolver(
  p_subject_type    subject_type,
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

-- ---------------------------------------------------------------------------
-- Resolution
-- ---------------------------------------------------------------------------

-- Deflationary at every step, per AR-B7 and AR-G2. No resolver registered, the
-- module absent, the row gone, or the row invisible to this caller: all of them
-- answer null. None of them raises. A consumer renders what it got and shows
-- nothing where there is nothing, which is the direction-of-error rule applied
-- to depth rather than to presence.
--
-- Security invoker on purpose, twice over. The expression runs with the caller's
-- own rights, so a registry row cannot become an escalation; and row level
-- security still evaluates as the caller, so a client asking the name of a lot
-- they cannot see gets null rather than the name.
create or replace function resolve_subject_name(
  p_subject_type subject_type,
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

  -- The module may not be installed. to_regclass answers null rather than
  -- raising, which is the whole reason relation is text.
  if to_regclass('public.' || quote_ident(r.relation)) is null then
    return null;
  end if;

  begin
    execute format('select (%s)::text from public.%I where id = $1',
                   r.name_expression, r.relation)
      into result
     using p_subject_id;
  exception when others then
    -- A registry row that does not fit its relation is a broken registration,
    -- not a reason for a task board to fail to render.
    return null;
  end;

  return result;
end;
$$;

-- Whether anything provides this subject type at all, which is the question a
-- consumer asks before deciding a set is empty rather than unresolved.
create or replace function subject_is_resolvable(p_subject_type subject_type)
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
-- The four that exist today
-- ---------------------------------------------------------------------------

-- Registered as data, which is the point. These four rows say exactly what
-- task_board's CASE says today, and phase 4 deletes the CASE rather than
-- teaching it a fifth case. A winery with no vineyard module deletes the block
-- row and everything else keeps working.
insert into subject_resolver (subject_type, relation, name_expression, module) values
  ('node',     'node',     'name',                        'winemaking'),
  ('vessel',   'vessel',   'name',                        'winemaking'),
  ('location', 'location', 'name',                        'core'),
  ('block',    'block',    'vineyard || '' '' || name',   'vineyard')
on conflict (subject_type) do nothing;
