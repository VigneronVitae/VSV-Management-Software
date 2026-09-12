-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Closes the four cheapest exploitable findings in the review corpus:
--           deactivating a client promoted their login, any signed-in person
--           could write an event in somebody else's name, every login could
--           read every vessel photograph, and claiming a task needed neither
--           an identity nor an entitlement."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0003_parties_and_products.sql,
--              supabase/migrations/0005_account_and_walk.sql,
--              supabase/migrations/0021_cellar_write_paths.sql,
--              docs/findings-ledger.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-3, in that an event now always names the person who
--                  observed it and can no longer name somebody else.
--                  T0-4, in that nobody can widen their own standing by
--                  deactivating a row or by filling in a column.
-- Open sorries: S-39, S-40. Discharges S-25.
-- ---------------------------------------------------------------------------

-- A1, A3, A6 and A8 from docs/findings-ledger.md, which are the four one-line
-- defects with the worst consequences. Six independent review runs found A1;
-- five found A3; five found A6; three found A8. The rest of section A is larger
-- work and is not here.

-- ---------------------------------------------------------------------------
-- A1. Deactivation escalated instead of revoking
-- ---------------------------------------------------------------------------

-- Probed before the fix, in one transaction, as one client login:
--
--   party.active = true   ->  is_facility_user() false, 0 nodes visible
--   party.active = false  ->  is_facility_user() true,  the facility's lot visible
--
-- The cause is one coalesce. The old body asked whether a linked party was a
-- facility, and defaulted a missing answer to true so that a harvest intern with
-- no party row could see the cellar. But `where app_user_id = auth.uid() and
-- active` finds no row for a deactivated client either, so the two cases became
-- the same case, and the account you had just switched off became staff.
--
-- The question the intern case actually asks is not "is your party a facility",
-- it is "are you a client". Asked that way there is no default to choose: a
-- login with no party row is not a client and is staff, a login attached to a
-- client party is a client whether that party is active or not, and `exists` is
-- never null so nothing here can answer maybe.
--
-- Requiring an active app_user row at the same time discharges S-25: an
-- authenticated identity that has never called claim_account() is nobody here.
-- claim_account() is security definer and does not read this function, so the
-- walk's first run is unaffected.
create or replace function is_facility_user()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select is_admin() or (
    exists (select 1 from app_user where id = auth.uid() and active)
    and not exists (
      select 1 from party
       where app_user_id = auth.uid() and kind = 'client'
    )
  );
$$;

comment on function is_facility_user() is
  'Somebody who works here: an admin, or an active account not attached to a client party. A login with no party at all is the harvest intern and counts. A login attached to a client party does not, whether that party is active or not.';

-- 0021 introduced is_cellar_staff() because is_facility_user() could not be
-- trusted to answer this question. Fixing A1 made the two bodies identical, and
-- two names for one predicate is duplication that will drift, so the newer name
-- goes and the older one, which twenty call sites already use, stays. The three
-- policies from 0021 are recreated against it; nothing about what they permit
-- changes.
drop policy node_cellar_update on node;
drop policy placement_cellar_update on placement;
drop policy vessel_cellar_update on vessel;
drop function is_cellar_staff();

create policy node_cellar_update on node
  for update to authenticated
  using (is_facility_user()) with check (is_facility_user());

create policy placement_cellar_update on placement
  for update to authenticated
  using (is_facility_user()) with check (is_facility_user());

create policy vessel_cellar_update on vessel
  for update to authenticated
  using (is_facility_user()) with check (is_facility_user());

-- ---------------------------------------------------------------------------
-- A3. Any signed-in person could write history in somebody else's name
-- ---------------------------------------------------------------------------

-- The old check was `by_user = auth.uid() or by_sensor is not null`. The second
-- branch is an escape hatch with no lock on it: put any string in by_sensor and
-- the first branch stops being evaluated, so by_user can name anybody. Probed:
-- user A inserted an event carrying user B's uuid and the word 'anything', and
-- it was accepted.
--
-- An event is the unit of provenance in this schema and T0-3 says every one
-- carries it. An author that can be chosen is not provenance.
--
-- The fix refuses the sensor branch entirely for the authenticated role rather
-- than trying to make a free-text column trustworthy. The has_an_author
-- constraint from 0001 still permits a sensor row, and nothing can currently
-- write one, which is S-39: a sensor needs an identity and a role that is not a
-- person's, and it will get both when a sensor exists.
drop policy event_insert on event;

create policy event_insert on event
  for insert to authenticated
  with check (by_user = auth.uid() and by_sensor is null);

-- ---------------------------------------------------------------------------
-- A6. Every login could read every vessel photograph
-- ---------------------------------------------------------------------------

-- Both policies were `to authenticated using (bucket_id = 'vessel-photos')`,
-- eighteen lines below the comment in 0005 explaining that the bucket is private
-- because a barrel photo shows a chalk mark with a client's lot on it. The
-- comment was right and the policy did not implement it.
--
-- The same guard as 0005 for the same reason: outside Supabase there is no
-- storage schema and this block does nothing rather than failing halfway.
do $$
begin
  if not exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    raise notice 'storage schema absent, skipping the vessel-photos policies';
    return;
  end if;

  drop policy if exists vessel_photos_read on storage.objects;
  drop policy if exists vessel_photos_insert on storage.objects;
  drop policy if exists vessel_photos_update on storage.objects;

  -- Staff only, in both directions. A client sees no vessel photographs at all,
  -- which is deflationary and is the honest answer until a photo records what was
  -- in the vessel when it was taken. Deriving the owner from the current
  -- placement would show a barrel's old photograph to whoever holds it now and
  -- hide it from the person whose wine it shows. S-40.
  execute $p$
    create policy vessel_photos_read on storage.objects
      for select to authenticated
      using (bucket_id = 'vessel-photos' and public.is_facility_user())
  $p$;

  execute $p$
    create policy vessel_photos_insert on storage.objects
      for insert to authenticated
      with check (bucket_id = 'vessel-photos' and public.is_facility_user())
  $p$;

  -- Not in 0005 and needed. uploadVesselPhoto passes upsert: true and writes to
  -- the fixed path <vessel_id>/photo.<ext>, so photographing a vessel a second
  -- time is an update to an existing object. With insert alone the first photo
  -- succeeds and every later one fails, which nobody would have found until
  -- somebody re-photographed a barrel.
  execute $p$
    create policy vessel_photos_update on storage.objects
      for update to authenticated
      using (bucket_id = 'vessel-photos' and public.is_facility_user())
      with check (bucket_id = 'vessel-photos' and public.is_facility_user())
  $p$;
end $$;

-- ---------------------------------------------------------------------------
-- A8. Claiming a task needed neither an identity nor an entitlement
-- ---------------------------------------------------------------------------

-- The old body was security definer, took no view on who was calling, and set
-- claimed_by = auth.uid() unconditionally. Three consequences. An unclaimed
-- account with a token could take a task. A caller with a null uid wrote null
-- into claimed_by while setting status to 'claimed', which satisfies neither the
-- `status = 'open'` nor the `claimed_by is null` guard on any later attempt, so
-- the task was wedged and no cellar user could recover it. And an open task
-- assigned to a named person could be taken by anybody, which makes assignment
-- decorative.
--
-- The definer stays, because claiming has to be one atomic update and the task
-- policies would otherwise refuse a cellar user the write. What was missing is
-- the check that a definer function owes: it decides who may call it, because
-- nothing else will.
create or replace function claim_task(p_task_id uuid)
returns task
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  claimed task;
  who     uuid := auth.uid();
begin
  -- Refused in words rather than by writing a null. A wedged task is worse than
  -- a refused one, because the refusal is visible and the wedge is not.
  if who is null then
    raise exception 'not signed in, so there is nobody to claim this task for'
      using errcode = 'insufficient_privilege';
  end if;

  if not is_facility_user() then
    raise exception 'only somebody who works here may claim a task'
      using errcode = 'insufficient_privilege';
  end if;

  update task
     set status = 'claimed',
         claimed_by = who,
         claimed_at = now()
   where id = p_task_id
     and status = 'open'
     and claimed_by is null
     -- An unassigned task is anyone's. An assigned one is theirs, and an admin
     -- reassigns it rather than a passer-by taking it.
     and (assignee is null or assignee = who)
  returning * into claimed;

  if claimed.id is null then
    raise exception 'task % is not available to you', p_task_id
      using errcode = 'lock_not_available';
  end if;

  return claimed;
end;
$$;
