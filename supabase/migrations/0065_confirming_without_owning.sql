-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "confirm_note could only be run by somebody who owns the table,
--           which is nobody who uses this app."
-- Depends on: [supabase/migrations/0064_typing_a_note.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0066_a_guard_that_can_be_weakened.sql]
-- Axioms enforced: T0-4 (only a person's deliberate act writes confirmed, and
--                  the act is still the only path)
-- ---------------------------------------------------------------------------
--
-- `0064` guards `provenance` with a trigger that refuses any update to
-- `confirmed`, so that confirming has to go through `confirm_note` and be
-- recorded. `confirm_note` then got past its own guard with `alter table note
-- disable trigger`, which requires owning the table. `authenticated` does not
-- own it, so every real caller got `must be owner of table note`.
--
-- Found by running it as a signed-in user rather than as `postgres`, which is
-- the only way this class of defect is ever found: as the owner it works
-- perfectly.
--
-- The fix is the mechanism this repository already uses for exactly this. A
-- transaction-local setting, set by the one function allowed to confirm and
-- readable by the trigger, so the trigger can tell "somebody called
-- `confirm_note`" from "somebody wrote confirmed into an update". It is local to
-- the transaction, so it cannot leak into the next statement, and it is set by a
-- function whose whole body is the deliberate act T0-4 is about.

begin;

create or replace function note_provenance_is_not_self_granted()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
begin
  if tg_op = 'INSERT' and new.provenance = 'confirmed' then
    raise exception
      'a fact cannot be born confirmed; record it, then confirm it once somebody has checked it';
  end if;

  if tg_op = 'UPDATE' and new.provenance <> old.provenance
     and new.provenance = 'confirmed'
     -- Set by `confirm_note` and by nothing else, for the length of one
     -- transaction. `true` as the second argument means "null if unset" rather
     -- than an error, which is what makes this safe to read on every update.
     and coalesce(current_setting('vsv.confirming_note', true), '') <> 'yes' then
    raise exception
      'confirming is its own act; use confirm_note so that who confirmed it is recorded';
  end if;

  return new;
end;
$$;

create or replace function confirm_note(p_note_id uuid)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare n note%rowtype;
begin
  select * into n from note where id = p_note_id;
  if n.id is null then
    raise exception 'there is no note with id %', p_note_id;
  end if;
  if n.kind_id is null then
    raise exception 'that note has not been typed, so there is no fact in it to confirm';
  end if;
  if n.provenance = 'confirmed' then
    -- Already done is not a failure and must not read like one. A13.
    return jsonb_build_object('id', p_note_id, 'provenance', 'confirmed', 'already', true);
  end if;

  perform set_config('vsv.confirming_note', 'yes', true);
  update note set provenance = 'confirmed' where id = p_note_id;
  perform set_config('vsv.confirming_note', '', true);

  -- The confirming is itself a note on the fact, so that who checked it and
  -- when is in the record rather than in a column nobody displays. 0063 made a
  -- note a subject, which is what allows this.
  insert into note (subject_type, subject_id, body, by_user)
  values ('note', p_note_id, 'checked and confirmed', auth.uid());

  return jsonb_build_object('id', p_note_id, 'provenance', 'confirmed', 'already', false);
end;
$$;

revoke all on function confirm_note(uuid) from public;
grant execute on function confirm_note(uuid) to authenticated;

commit;
