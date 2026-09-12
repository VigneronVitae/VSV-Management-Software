-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Lets a cellar hand put a new sticker on a barrel, and keeps moving
--           an existing sticker to a different barrel an admin's decision. The
--           split sits where the risk is: an unbindable code is obstructive
--           during harvest, and a silent rebind reattributes every future scan."
-- Depends on: [supabase/migrations/0003_parties_and_products.sql,
--              supabase/migrations/0021_cellar_write_paths.sql,
--              supabase/migrations/0022_admission_and_authorship.sql,
--              docs/findings-ledger.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-4, in that the narrow permission is granted rather than
--                  taken by making the function a definer.
-- Open sorries: S-43
-- ---------------------------------------------------------------------------

-- Ledger A22, found by the phase 2 read of the unreviewed range and ruled by the
-- winemaker: a cellar hand may bind an unbound code; only an admin may rebind one
-- already bound.
--
-- What was wrong. `bind_vessel_code` is `security invoker` and inserts into
-- `vessel_code`, whose only write policy was `vessel_code_admin_write` at
-- `is_admin()`. So a cellar hand could not put a sticker on a barrel at all. It
-- failed loudly rather than silently, because a refused INSERT violates a
-- `with check` and raises, which is why this is A22 and not another A14.
--
-- Why the split is here rather than somewhere simpler. An unbindable code means a
-- cellar hand cannot onboard the vessel they are about to record against, which
-- during harvest is obstruction. A rebind that nobody notices reattributes every
-- future scan of that sticker to a different barrel, which is A17's class, where
-- one button press put a lot under the wrong owner and the screen said it worked.
--
-- Done the way 0021 did it: a narrow permission on the row, not a blanket
-- `security definer` on the function. The function keeps running as the caller,
-- so nothing here can be used to reach past a policy.

-- Insert only. Update and delete stay with vessel_code_admin_write, so a cellar
-- hand cannot rebind by writing the table directly either, which is the hole a
-- function-only fix would have left open.
create policy vessel_code_cellar_insert on vessel_code
  for insert to authenticated
  with check (is_facility_user());

-- ---------------------------------------------------------------------------

-- The function gains the rebind path for admins and a refusal that is useful to
-- somebody standing in a barrel room. It used to name the vessel's uuid, which
-- is true and unreadable; a person holding a sticker needs the barrel's name.
create or replace function bind_vessel_code(
  p_vessel_id uuid,
  p_code      text,
  p_label     text default null,
  p_id        uuid default gen_random_uuid()
)
returns vessel_code
language plpgsql
set search_path = public, pg_temp
as $$
declare
  existing  vessel_code;
  held_by   text;
begin
  select * into existing from vessel_code where code = p_code;

  if found then
    -- Idempotent, unchanged: binding a code the vessel already carries returns
    -- the row rather than complaining.
    if existing.vessel_id = p_vessel_id then
      return existing;
    end if;

    select name into held_by from vessel where id = existing.vessel_id;

    if not is_admin() then
      raise exception
        'code % is already on %; only an administrator can move a sticker to another vessel',
        p_code, coalesce(held_by, 'a vessel that no longer exists')
        using errcode = 'insufficient_privilege';
    end if;

    -- An admin may move it, because a sticker does come off one barrel and go
    -- onto the next. Nothing records that it happened, which is S-43.
    update vessel_code
       set vessel_id = p_vessel_id,
           label     = coalesce(p_label, label)
     where id = existing.id
    returning * into existing;

    return existing;
  end if;

  insert into vessel_code (id, vessel_id, code, label)
  values (p_id, p_vessel_id, p_code, p_label)
  returning * into existing;

  return existing;
end;
$$;

comment on function bind_vessel_code(uuid, text, text, uuid) is
  'Binds a code to a vessel. Anyone who works here may bind an unbound code. Moving a code that is already on another vessel is an administrator''s decision, and the refusal names the vessel currently holding it. Binding a code the vessel already has returns the existing row.';
