-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Pins search_path on every function in public. Without it a function
--           that names a type or a table unqualified works only while the
--           caller happens to have the right search_path, and a restore does
--           not: pg_dump sets it to empty on purpose."
-- Depends on: [supabase/migrations/0019_procedures.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: none. This is the schema being robust rather than correct.
-- Open sorries: none new
-- ---------------------------------------------------------------------------

-- Found by trying to restore a backup. pg_dump writes
--
--   select pg_catalog.set_config('search_path', '', false);
--
-- at the top of every dump, deliberately, so that a restore cannot be hijacked
-- by whatever happens to be on the path. Every trigger that fires during that
-- restore then runs with an empty path, and `'cooper'::term_kind` stops
-- resolving, because term_kind is in public and public is not on the path.
--
-- The failure was loud and the message was misleading: the validator's own
-- exception handler reported "field maker names vocabulary cooper, which does
-- not exist", which is true of the cast and false of the vocabulary.
--
-- Security definer functions were already pinned, which is the case where an
-- unpinned path is a privilege hole rather than a nuisance. This covers the
-- rest, and pg_temp goes last so nothing can shadow public with a temporary
-- object of the same name.
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proconfig is null
  loop
    execute format('alter function %s set search_path = public, pg_temp', f.sig);
  end loop;
end $$;

-- A function added after this migration will not be pinned by it. The
-- assertions check that none is unpinned, so the next one to forget fails the
-- suite rather than a restore six months later.
