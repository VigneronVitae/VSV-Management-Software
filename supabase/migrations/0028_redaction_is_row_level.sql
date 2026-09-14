-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Scopes the three blanket reads that carry wine by reference, so that
--           a viewer who cannot see a lot does not receive rows about it."
-- Depends on: [supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0003_parties_and_products.sql,
--              supabase/migrations/0018_lot_privacy.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0041_daily_log.sql]
-- Axioms enforced: AR-E10, redaction is row-level.
-- Open sorries: S-44, a vessel holding wine the viewer may not see now reports
--               as empty rather than as occupied. AR-E11 is the answer and is
--               deliberately unbuilt.
-- ---------------------------------------------------------------------------
--
-- Ledger A5, the part of it that carries wine.
--
-- `node_read` has been scoped since 0003 and the tables that point at `node`
-- have not. So the privacy model was enforced on one table and on nothing that
-- refers to it, and W-8 read the facility's entire movement history, its rack
-- events with volumes and method, and the lot ids behind a redacting view, while
-- signed into the real client as a custom crush client.
--
-- The predicate is deliberately not "the viewer may read the node". `node_read`
-- denies a facility user any lot with a hidden field, because `visible_node`
-- exists to redact those rather than hide them. Scoping placements that way would
-- take a hidden lot's placement away from the cellar hand who has to rack it, and
-- `rack` runs with invoker rights, so it would stop working on exactly the lots a
-- client cares most about.
--
-- What is wanted is the first gate `visible_node` applies and not the second:
-- admin, or facility staff, or the owner. Staff see the cellar they work in. A
-- client sees their own wine. That is the distinction the leak was about and it
-- is the whole of what these three policies now say.
--
-- The two disjuncts that do not touch `node` come first on purpose. A policy that
-- queries `node` has `node`'s own policies applied inside it, so for staff this
-- short-circuits before any recursion into the table whose visibility rule is the
-- thing being worked around.
--
-- `vessel_state` needs no change. It is `security_invoker`, it reaches `placement`
-- through a left join, and a placement the viewer cannot read now yields nulls in
-- `node_id` and `current_volume_l` rather than the values it used to leak past the
-- nulls it already produced for `lot_name` and `lot_owner_name`.

begin;

-- Which vessel holds which lot, how much of it, and when it moved.
drop policy if exists placement_read on placement;
create policy placement_read on placement for select
  using (
    is_admin()
    or is_facility_user()
    or exists (
      select 1 from node n
       where n.id = placement.node_id
         and n.owner_id = current_party_id()
    )
  );

-- What was done to a lot, with the payload. An event against a vessel rather
-- than a lot is facility business: a client is not told what happened to
-- equipment they do not own.
drop policy if exists event_read on event;
create policy event_read on event for select
  using (
    is_admin()
    or is_facility_user()
    or (
      subject_type = 'node'
      and exists (
        select 1 from node n
         where n.id = event.subject_id
           and n.owner_id = current_party_id()
      )
    )
  );

-- What a lot came out of. `node_bin_shares` has guarded composition since 0015
-- and the table under it did not, so the guard was walked around rather than
-- through. Scoped by the child, because an edge is a fact about the lot it made.
drop policy if exists lineage_read on lineage;
create policy lineage_read on lineage for select
  using (
    is_admin()
    or is_facility_user()
    or exists (
      select 1 from node n
       where n.id = lineage.child_id
         and n.owner_id = current_party_id()
    )
  );

commit;
