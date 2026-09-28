-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The file a person takes away says what it is: a copy of the
--           record, not a restore point, and without the photographs."
-- Depends on: [supabase/migrations/0037_export.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: A13. A file that looks like a backup and is not one is a
--                  refusal that looks like success, delayed until the day it
--                  is needed.
-- Open sorries: S-54 and S-68 are narrowed to the importer and the bytes.
-- ---------------------------------------------------------------------------

-- S-54 and S-68 each resolved on either of two things: the real fix, an
-- importer and a file carrying the photographs, or the honest one, the file
-- saying in words what it can and cannot do. The screen has said "not a
-- restore point" since 0037. The file never did, and neither said the
-- photographs were missing. Since 2026-09-27 the nightly backup carries both
-- and has been restored table for table against the cellar, so there is now a
-- real restore point to point at.
--
-- Replaced in place: one key is added and nothing else moves.

CREATE OR REPLACE FUNCTION public.export_cellar()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
    -- 0157. What the file is, in the file. S-54: somebody holding it will
    -- reasonably believe they are covered, and the screen that said otherwise
    -- is not in their hand when they need to know.
    'about',       'A copy of every row the person who took it could read, as of exported_at. '
                   'It is a record, not a restore point: nothing loads it back in, and the '
                   'photographs are named by their paths and are not in it. The restore '
                   'point is the backup taken on the winery''s own computer every night, '
                   'which carries the rows and the photographs together.',
    'table_count', (select count(*) from jsonb_object_keys(tables)),
    'tables',      tables
  );
end;
$function$;
