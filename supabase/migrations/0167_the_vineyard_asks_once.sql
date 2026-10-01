-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Reading the vineyard asks once whether the reader may, not once a
--           vine."
-- Depends on: [supabase/migrations/0116_the_vineyard_is_not_everybodys_business.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: none new; the same people read and write the same rows.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- "Download still says working but it's probably been like 45 seconds." The
-- vine map export reads 13,539 plant spaces through `plant_space_now`, in
-- pages of a thousand. Each page took 3.4 seconds signed in and 0.09 as the
-- database's owner. The difference was row level security: `vine_row`,
-- `plant_space` and `plant_change` each asked `is_facility_user()` or
-- `is_admin()` for every row a query touched, and the view looks up every
-- space's latest change, so one page asked tens of thousands of times a
-- question whose answer cannot change within the query. The whole export
-- spent a minute on it.
--
-- Wrapped in a sub-select, Postgres asks once per query and remembers. Same
-- predicates, same people, same rows; a page now takes about 0.1 seconds.
-- `alter policy` rather than drop and create, so nothing is ever unguarded,
-- even inside this migration.

alter policy vine_row_read on vine_row using ((select is_facility_user()));
alter policy plant_space_read on plant_space using ((select is_facility_user()));
alter policy plant_change_read on plant_change using ((select is_facility_user()));
alter policy vine_row_admin_write on vine_row
  using ((select is_admin())) with check ((select is_admin()));
alter policy plant_space_admin_write on plant_space
  using ((select is_admin())) with check ((select is_admin()));
alter policy plant_change_write on plant_change
  using ((select is_admin())) with check ((select is_admin()));

-- And the export asks once. Fourteen pages of a thousand through an offset
-- each made the database work out the whole map again to skip to its page.
-- One call returns every plant space as one document, in the order the map
-- is drawn, worked out once. A function returning one row is not cut off at
-- the API's thousand-row ceiling, which is why paging existed at all.
create or replace function vine_map_spaces()
returns jsonb
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select coalesce(jsonb_agg(to_jsonb(p) order by p.block, p.row_number, p.space_number), '[]'::jsonb)
    from plant_space_now p;
$$;

comment on function vine_map_spaces is
  'Every plant space with what stands in it, as one document, for the vine map export.';

grant execute on function vine_map_spaces() to authenticated;

insert into capability_exemption (fn, reason) values
  ('vine_map_spaces', 'Reads every plant space for the vine map export in one call. It changes nothing.')
on conflict (fn) do update set reason = excluded.reason;
