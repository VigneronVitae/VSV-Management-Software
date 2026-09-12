-- ---------------------------------------------------------------------------
-- Type: test
-- Purpose: "Stands up the parts of a Supabase instance that the migrations
--           reference, so a bare Postgres can apply all of them from empty and
--           run the assertions. Four grades in the status ledger rested on an
--           artifact like this for eight sessions and it was never in the tree."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0002_derived_and_rls.sql]
-- Depended on by: [scripts/green.sh, docs/status-ledger.md, scripts/mutate.sh]
-- Axioms enforced: none. This is scaffolding, and it is deliberately less than
--                  Supabase rather than a reimplementation of it.
-- Open sorries: S-7, which this narrows and does not close.
-- ---------------------------------------------------------------------------
--
-- Three separate review runs reconstructed something like this, applied the
-- migrations and ran the assertions. None of them committed it, and they
-- disagreed about the assertion count until a third run settled it, which is why
-- this file exists and why it is specified rather than improvised. That is
-- ledger entry D1.
--
-- **Which migration needs which part.** This matters more than the code, because
-- the next person will otherwise assume the whole file is optional:
--
--   0002 needs the `supabase_realtime` publication and cannot apply without it.
--        It has no guard. This shim is a dependency, not a convenience.
--   0002 and everything after need `auth.uid()`, because every policy calls it.
--   0001 needs a `pgcrypto` that is not in `public`. See the note below.
--   0005 needs nothing here. It guards its storage block on the schema existing
--        and skips with a notice, so this shim deliberately creates no storage
--        schema and 0005 says so out loud when it runs.
--   0022 does the same for the vessel-photos policies, for the same reason.
--
-- What this does not reproduce is the half S-7 names: GoTrue minting a real JWT
-- and PostgREST mapping it to a role and a claim. Everything run against this
-- shim is a claim about Postgres policy evaluation and assumes the plumbing.

-- ---------------------------------------------------------------------------
-- pgcrypto, and why it is not in public
-- ---------------------------------------------------------------------------

-- 0001 says `create extension if not exists "pgcrypto"`, which without a schema
-- lands in public. 0020 then pins search_path on every function in public that
-- has no proconfig, which on such an install includes pgcrypto's own functions,
-- and the migration fails with "must be owner of function digest".
--
-- Supabase puts extensions in their own schema, so this never bites there. It
-- bites the first person to apply these migrations to a plain Postgres, which is
-- exactly the case 0005 guards for. Putting pgcrypto where Supabase puts it
-- makes the shim match the real thing; it does not fix 0020, and that defect is
-- recorded rather than papered over here.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- The auth schema
-- ---------------------------------------------------------------------------

create schema if not exists auth;

-- Only the column the migrations reference. app_user.id has a foreign key to
-- this table and nothing in the tree reads any other column of it.
create table if not exists auth.users (
  id uuid primary key
);

-- Supabase's auth.uid() reads the singular claim first and falls back to the
-- claims blob, and the assertion suite's test_act_as() writes both, so both
-- paths are exercised by the suite rather than assumed.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::json ->> 'sub'
  )::uuid;
$$;

-- ---------------------------------------------------------------------------
-- The roles PostgREST maps to
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end $$;

grant usage on schema public, extensions, auth to anon, authenticated, service_role;
grant execute on all functions in schema extensions to anon, authenticated, service_role;
grant execute on all functions in schema auth to anon, authenticated, service_role;
grant select on auth.users to anon, authenticated, service_role;

-- Supabase's defaults on public. Row level security is what refuses things here,
-- not the grants, which is the same posture the hosted project has and is the
-- reason a missing policy is a hole rather than an error.
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

-- Empty on purpose. 0002 adds tables to it, and E7 in the findings ledger is
-- open on whether row level security applies to the hosted replication stream at
-- all, so this reproduces the publication's existence and claims nothing about
-- its behaviour.
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

-- No storage schema. 0005 and 0022 both guard on it and both say so when they
-- skip, and a shim that stood storage up would change the assertion count, which
-- is the disagreement that took three review runs to settle.
