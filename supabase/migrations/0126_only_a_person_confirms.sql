-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The only way a line attestation is marked observed is for the caller
--           to say so outright. Omitting the question yields inferred, which is
--           the direction T0-4 allows a machine to write in."
-- Depends on: [supabase/migrations/0122_money_that_has_already_moved.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  supabase/migrations/0127_the_books_have_a_door.sql,
--                  packages/books/src/books.ts,
--                  scripts/import-ledger.py,
--                  supabase/migrations/0145_the_books_keep_score.sql]
-- Axioms enforced: T0-4. A trust field is set by the verifier. An agent may
--                  write `inferred` and may never write anything stronger, and
--                  a default that quietly upgrades a silent caller is the same
--                  violation performed by omission.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- 0122 wrote `coalesce(p_confirm, true)`, on the reasoning that a person calling
-- this is confirming and the importer would pass false. The second half of that
-- is a convention rather than a constraint: any caller that omits the argument
-- gets `observed` written under its name, and the callers most likely to omit it
-- are the ones with nobody sitting behind them.
--
-- The winemaker settled the surrounding question while this was open. The point
-- of the books module is that the matching happens on a phone, by a person, one
-- transaction at a time. Nothing machine-generated should reach this table at
-- all: a suggestion belongs in `merchant_suggestion`, which is a view over
-- attestations already confirmed, and it stays a suggestion until somebody taps
-- it. So the permissive default had no caller it was serving.
--
-- Now: explicit true is the only thing that yields `observed`. Null and omission
-- both yield `inferred`, and the contract marks the field required so that a
-- periphery built from the contract asks the question rather than defaulting it.

create or replace function attest_line(
  p_line_id uuid,
  p_class   text,
  p_note    text default null,
  p_confirm boolean default null
)
returns line_attestation
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  made line_attestation;
  cls  uuid;
begin
  if not is_admin() then
    raise exception 'only an administrator may say what a transaction was for';
  end if;

  select t.id into cls from term t
   where t.kind = 'money_class' and t.value = p_class and t.active;
  if cls is null then
    raise exception 'there is no class of transaction called %', p_class;
  end if;

  if not exists (select 1 from bank_line where id = p_line_id) then
    raise exception 'that transaction is not there to say anything about';
  end if;

  insert into line_attestation (line_id, class_id, note, by_user, provenance)
  values (
    p_line_id, cls, p_note, auth.uid(),
    -- T0-4. Only an outright yes is a confirmation. Silence is a guess.
    case when p_confirm is true then 'observed' else 'inferred' end)
  returning * into made;

  return made;
end $$;

-- The field was optional, which is how the default came to matter. A periphery
-- built from the contract now has to put the question on the screen.
update capability
   set fields = jsonb_set(
         fields,
         '{3}',
         '{"key": "confirm", "type": "boolean", "param": "p_confirm", "required": true,
           "label": "You are confirming this rather than guessing"}'::jsonb)
 where key = 'books.attest_line'
   and fields -> 3 ->> 'key' = 'confirm';

do $$
begin
  if not exists (
    select 1 from capability
     where key = 'books.attest_line'
       and fields -> 3 ->> 'key' = 'confirm'
       and (fields -> 3 ->> 'required')::boolean
  ) then
    raise exception
      'the confirm field did not end up required, so a periphery could still omit it';
  end if;
end $$;
