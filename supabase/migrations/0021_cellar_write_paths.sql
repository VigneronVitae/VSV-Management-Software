-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Lets a cellar user rack, fork and set a jacket, which every write
--           path built since 0007 assumed they could and none of them could.
--           The policies from 0002 made every update on node, placement and
--           vessel admin only, and an update refused by row level security
--           matches zero rows and raises nothing, so five kernel functions
--           reported success and changed nothing."
-- Depends on: [supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0007_vessel_edit.sql,
--              supabase/migrations/0014_rack.sql,
--              supabase/migrations/0015_fork_and_history.sql,
--              supabase/migrations/0018_lot_privacy.sql,
--              supabase/migrations/0020_pin_search_path.sql,
--              docs/findings-ledger.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-4, in that nothing here lets a producer widen its own
--                  standing: the columns a cellar user may write are the
--                  operational ones, and owner_id and hidden are not among them.
-- Open sorries: S-36, S-37
-- ---------------------------------------------------------------------------

-- What was wrong, measured rather than reasoned. As a cellar user, against this
-- database, with the row present and visible:
--
--   update placement set to_at = now()   ->  UPDATE 0
--   update node set status = 'closed'    ->  UPDATE 0
--   update vessel set capacity_l = 900   ->  UPDATE 0
--
-- Three zero-row updates, no error, no message. 0002 put
-- `%I_admin_update ... using (is_admin())` on node, placement and vessel, on the
-- stated premise that cellar users create these rows and only admins edit them.
-- That premise was right about a correction and wrong about an operation.
-- Racking closes a placement and decrements a quantity. Forking moves a
-- placement to a child. Turning on a jacket sets three columns on a vessel.
-- None of those is an edit of a mistake; all of them are the job.
--
-- The consequence was worse than nothing happening. rack() closes the source
-- placement and inserts the destination one, and inserts were open while updates
-- were not, so a cellar user racking a barrel got the destination without losing
-- the source: the same wine in two vessels, and the kernel returning its success
-- payload. update_vessel() reads the row into `was`, updates, and reads the
-- result into `now_` with `returning *`. A filtered update returns no row, `now_`
-- is entirely null, the thermal comparison against null is distinct from
-- anything, and the function then writes a setpoint_change event recording that
-- the vessel now has no jacket, no setpoint and no mode. A silent refusal
-- produced a confident false record.
--
-- This was found by the A14 entry in the review corpus, which predicted it four
-- days before the racking screen existed: admin-only close, so racking is
-- refused the day it is built, silently.

-- ---------------------------------------------------------------------------
-- Who counts as cellar staff
-- ---------------------------------------------------------------------------

-- is_facility_user() is the existing predicate and it is not the right one here,
-- for a reason that is its own ledger entry rather than this migration's work:
-- it coalesces a missing party row to true, so it answers true for a client whose
-- party has been deactivated. Widening writes on that predicate would hand the
-- cellar to exactly the login deactivation was meant to close.
--
-- This asks a narrower question with no three-valued logic in it. Every branch
-- is an exists, which is true or false and never null.
create or replace function is_cellar_staff()
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

comment on function is_cellar_staff() is
  'Someone who works in the cellar: an admin, or an active account not linked to a client party. Unlike is_facility_user() it refuses a client party whether that party is active or not, and it refuses an authenticated principal with no app_user row at all.';

-- ---------------------------------------------------------------------------
-- The rows: permissive policies alongside the admin ones, not instead of them
-- ---------------------------------------------------------------------------

-- Permissive policies are OR'd, so adding one leaves every admin path exactly as
-- it was. Nothing below is dropped and no existing grade changes.

create policy node_cellar_update on node
  for update to authenticated
  using (is_cellar_staff()) with check (is_cellar_staff());

create policy placement_cellar_update on placement
  for update to authenticated
  using (is_cellar_staff()) with check (is_cellar_staff());

-- Creating a vessel stays admin only, and the assertion suite says so on purpose:
-- a vessel is a structural fact about the winery in the same class as a location
-- or a term. Turning its jacket on is not. 0007 already draws that line in its own
-- comment, where a thermal change is a decision and a rename is a correction, and
-- this policy is that line expressed where it can refuse something.
create policy vessel_cellar_update on vessel
  for update to authenticated
  using (is_cellar_staff()) with check (is_cellar_staff());

-- ---------------------------------------------------------------------------
-- The columns: row level security cannot say which, so a trigger does
-- ---------------------------------------------------------------------------

-- A policy decides rows. It cannot decide columns, and the columns are the whole
-- question here: a cellar user must be able to move wine and must not be able to
-- move who owns it. Column grants could express this and are rejected, because a
-- column added in a later migration would silently default to ungranted and the
-- failure would surface as a kernel function that stopped working for reasons
-- nobody could see. An allow-list in one place fails the same way but says so.
--
-- The list is an allow-list rather than a deny-list so that a column added later
-- defaults to protected. That is the deflationary direction: a new column is not
-- writable by the cellar until somebody decides it is.
create or replace function cellar_writable_columns()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  changed text;
begin
  -- This guards the direct table surface that PostgREST exposes. A security
  -- definer kernel function runs as its owner rather than as authenticated,
  -- and has already decided who may call it: set_lot_hidden writes node.hidden
  -- on behalf of a client who is deliberately not staff, and would be refused
  -- here otherwise. S-36 holds what that exemption costs.
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  if is_admin() then
    return new;
  end if;

  -- Generated columns are excluded, and finding that out cost a probe. A column
  -- declared `generated always as ... stored` is computed after every before
  -- trigger has run, so it reads null in NEW while OLD carries its real value,
  -- and a plain comparison reports node.product_kind as changed on every update
  -- anybody makes. Nobody can write a generated column in any case, so it can
  -- never be a privilege question.
  for changed in
    select k.key
      from jsonb_each(to_jsonb(new)) k
     where k.value is distinct from (to_jsonb(old) -> k.key)
       and not exists (
         select 1 from pg_attribute a
          where a.attrelid = tg_relid
            and a.attname = k.key
            and a.attgenerated <> ''
       )
  loop
    if not (changed = any(tg_argv)) then
      raise exception
        'a cellar user may not change %.%; ask an administrator',
        tg_table_name, changed
        using errcode = 'insufficient_privilege';
    end if;
  end loop;

  return new;
end;
$$;

-- quantity, status and closed_at are what racking and forking move. stage is the
-- lot progressing. attributes is the untyped floor. Everything absent is absent
-- on purpose: owner_id is whose wine it is and is TTB relevant, hidden is the
-- privacy edge and belongs to set_lot_hidden, name and variety_id and vintage
-- and product_type_id are the lot's identity rather than its state.
create trigger node_cellar_columns
  before update on node
  for each row execute function cellar_writable_columns(
    'quantity', 'status', 'closed_at', 'stage', 'attributes');

-- to_at closes a placement, volume_l is what is left in it, node_id is how a fork
-- hands a placement to the child. vessel_id is not here: moving a placement to a
-- different vessel without closing and opening one is how the history stops being
-- a history.
create trigger placement_cellar_columns
  before update on placement
  for each row execute function cellar_writable_columns(
    'to_at', 'volume_l', 'node_id');

-- The thermal triple and nothing else. has_glycol is on the list because the
-- check constraint from 0006 refuses a mode without a jacket, so a tank created
-- without the flag could not be cooled by the person standing in front of it.
create trigger vessel_cellar_columns
  before update on vessel
  for each row execute function cellar_writable_columns(
    'has_glycol', 'setpoint_c', 'mode');
