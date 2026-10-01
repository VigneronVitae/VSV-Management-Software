-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Confirming somebody else's note confirms it, instead of saying it
--           did and leaving it as it was."
-- Depends on: [supabase/migrations/0065_confirming_without_owning.sql,
--              supabase/migrations/0164_a_claim_says_where_it_came_from.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/vineyard/src/claims.ts]
-- Axioms enforced: T0-4. Confirming is still only this function's act, and who
--                  did it is still recorded. A13. A confirmation that changes
--                  nothing is refused, not reported.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- Found building the confirm button for 0164's claims. `confirm_note` runs as
-- the person calling it, and the only update policy on `note` is `note_edit`,
-- which lets a person update their own notes. So confirming a note somebody
-- else wrote, which is the whole point of confirming, had its update filtered
-- to nothing by row level security, and the function went on to answer
-- `{"provenance": "confirmed"}` and write "checked and confirmed" beneath a
-- note that was still inferred. 0065 fixed the trigger and tested it on the
-- caller's own note, where the policy lets the update through; this is the
-- other case. Claims loaded by the importer have no author at all, so every
-- one of them would have failed this way.
--
-- The fix is the shape 0156 used: the one step that needs a right the caller
-- does not have runs as the function's owner, behind the checks that say who
-- may take it. Anybody who works here may confirm, as before. And the update is
-- counted, so if it ever changes nothing again the caller is told.

create or replace function confirm_note(p_note_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  n       note%rowtype;
  changed int;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here confirms a fact'
      using errcode = 'insufficient_privilege';
  end if;
  select * into n from note where id = p_note_id;
  if n.id is null then
    raise exception 'there is no note with id %', p_note_id;
  end if;
  if n.kind_id is null then
    raise exception 'that note has not been typed, so there is no fact in it to confirm';
  end if;
  if n.provenance = 'confirmed' then
    return jsonb_build_object('id', p_note_id, 'provenance', 'confirmed', 'already', true);
  end if;

  perform set_config('vsv.confirming_note', 'yes', true);
  update note set provenance = 'confirmed' where id = p_note_id;
  get diagnostics changed = row_count;
  perform set_config('vsv.confirming_note', '', true);
  if changed <> 1 then
    raise exception 'the note was not confirmed; nothing changed';
  end if;

  insert into note (subject_type, subject_id, body, by_user)
  values ('note', p_note_id, 'checked and confirmed', auth.uid());

  return jsonb_build_object('id', p_note_id, 'provenance', 'confirmed', 'already', false);
end $$;

comment on function confirm_note is
  'Promotes a typed note to confirmed, as the person calling it, recording that they did.';

revoke all on function confirm_note(uuid) from public;
grant execute on function confirm_note(uuid) to authenticated;
