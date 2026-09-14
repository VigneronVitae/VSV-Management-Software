-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Everything the person asking may read, as one document they can put
--           on their phone, because the database lives on one desktop and that
--           is the whole of the risk."
-- Depends on: [supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0036_bins_on_loan.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0038_cancel_a_pick.sql]
-- Axioms enforced: T0-3 (an export is a copy of the record, and carries the
--                  provenance of every row rather than flattening it)
-- Open sorries: S-54 (an export is not a restore, and looks like one)
-- ---------------------------------------------------------------------------
--
-- Asked for on the morning of the first pick, after a backup that turned out not
-- to exist. Two different things were wanted and they are worth keeping apart:
--
-- **A backup** is `pg_dump`, runs on the machine holding the database, contains
-- the sign-ins and the sequences, and can be restored. `scripts/db-backup.sh`.
--
-- **An export** is this. It runs as whoever asked, through the same row level
-- security every screen goes through, and it is a copy of the record rather than
-- a copy of the database. It cannot contain what the asker may not read, which
-- is the point: a cellar hand's export is smaller than an administrator's and
-- neither of them is wrong.
--
-- The export is the one that survives the desktop dying, because it ends up on a
-- phone in somebody's pocket. That is the actual failure being insured against.
--
-- **It reads the table list from the catalog rather than naming tables.** This is
-- the one place in this schema where enumerating by hand would be worse: a table
-- added next session and forgotten here would not fail, it would quietly export
-- less, and nobody would find out until they needed it. The assertion beside this
-- requires every base table to appear, so the catalog and the export cannot
-- disagree. Dynamic SQL is safe here because the identifiers come from
-- `pg_class` and go through `%I`.

begin;

create or replace function export_cellar()
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  t       record;
  tables  jsonb := '{}'::jsonb;
  rows_js jsonb;
  total   int := 0;
begin
  for t in
    select c.relname as tbl
      from pg_class c
      join pg_namespace ns on ns.oid = c.relnamespace
     where ns.nspname = 'public'
       and c.relkind = 'r'
     order by c.relname
  loop
    -- Runs as the caller, so row level security decides what lands in the file.
    -- An empty array is a real answer and is kept: "this table has nothing you
    -- may read" and "this table was skipped" must not look the same.
    execute format(
      'select coalesce(jsonb_agg(to_jsonb(x) order by x), %L::jsonb) from public.%I x',
      '[]', t.tbl)
      into rows_js;
    tables := tables || jsonb_build_object(t.tbl, rows_js);
    total  := total + jsonb_array_length(rows_js);
  end loop;

  return jsonb_build_object(
    'exported_at', now(),
    'by',          auth.uid(),
    'rows',        total,
    -- This used to stamp the migration count, which read
    -- `supabase_migrations.schema_migrations`: a schema the `authenticated` role
    -- has no rights to at all. So the whole export died on a decoration, and
    -- died as "permission denied for schema", which the client then had to
    -- render as a refusal about standing. The shape of the file is already in
    -- the table list, which is the thing anybody matching a file to a database
    -- would actually compare, so the stamp is the count of tables in it.
    'table_count', (select count(*) from jsonb_object_keys(tables)),
    'tables',      tables
  );
end;
$$;

comment on function export_cellar is
  'Everything the caller may read, as one jsonb document. Runs as the caller, so '
  'row level security applies and two people get two different files, both '
  'correct. Not a backup: see scripts/db-backup.sh and sorry S-54.';

commit;
