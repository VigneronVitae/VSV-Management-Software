-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Answers which columns of a table this caller may write, from the
--           trigger that enforces it, so that a form can ask instead of
--           remembering."
-- Depends on: [supabase/migrations/0021_cellar_write_paths.sql,
--              supabase/migrations/0029_viewer_scope.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0044_finishing_a_pick.sql]
-- Axioms enforced: R-4, a client may not encode a business rule.
-- Open sorries: S-45, column privileges cannot express this rule, so this reads
--               the trigger instead and there is no second mechanism to keep in
--               step. Named because the obvious next step is to add one.
-- ---------------------------------------------------------------------------
--
-- W-8: a cellar hand opens the vessel edit screen, sees fifteen fields, and may
-- write three. The form does not know which three. It knows the role, it renders
-- "Sam, cellar" at the top, and it offers every field anyway, so the hand fills
-- one in and is refused on save.
--
-- The obvious fix is a list of three column names in the client, which is the R-4
-- class and the reason section B exists. A rule the kernel owns, copied into a
-- client, drifting from the day it is written.
--
-- The next obvious fix is Postgres column privileges, which are queryable through
-- `information_schema.column_privileges`, and **they cannot express this rule**.
-- Grants are per role, and there are no per-role distinctions here: admin and
-- cellar are both `authenticated`, and which one you are is a row in `app_user`
-- rather than a database role. Today those views report every column of `vessel`
-- as writable by `authenticated` and by `anon`, which is true of the grants and
-- false of the system. Making them true would need two database roles, a mapping
-- from `app_user.role` to them, and then two mechanisms enforcing one rule with
-- nothing keeping them in step. That is S-45 and it is not this.
--
-- What is already true is that `cellar_writable_columns` carries its allow-list in
-- its own trigger arguments, and those are in the catalog. So the kernel can
-- answer the question from the same place it enforces it, which is the one shape
-- that cannot drift: if somebody edits the trigger, this answer changes with it.

begin;

create or replace function writable_columns(p_table text)
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    -- An administrator is not subject to the trigger, so the answer is every
    -- column that exists. Asking rather than assuming matters here too: the
    -- client should not be the thing that knows admins are exempt.
    when is_admin() then array(
      select a.attname::text from pg_attribute a
       where a.attrelid = to_regclass('public.' || quote_ident(p_table))
         and a.attnum > 0 and not a.attisdropped
    )
    else coalesce((
      select array(
        select btrim(x, ' ''')
          from unnest(string_to_array(
            (regexp_match(pg_get_triggerdef(t.oid),
                          'cellar_writable_columns\((.*)\)'))[1], ',')) as x
      )
      from pg_trigger t
      where t.tgrelid = to_regclass('public.' || quote_ident(p_table))
        and not t.tgisinternal
        and pg_get_triggerdef(t.oid) like '%cellar_writable_columns%'
      limit 1
    ), '{}'::text[])
  end;
$$;

comment on function writable_columns(text) is
  'Which columns of a table this caller may write, read from the trigger that '
  'enforces it rather than from a list somebody keeps in step. See 0030 and S-45.';

grant execute on function writable_columns(text) to authenticated;

commit;
