-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The one refusal site in this schema that the mutation harness could
--           not weaken, rewritten so that it can."
-- Depends on: [supabase/migrations/0065_confirming_without_owning.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: none. This makes an existing refusal measurable.
-- ---------------------------------------------------------------------------
--
-- `0065` guarded confirming with
-- `coalesce(current_setting('vsv.confirming_note', true), '') <> 'yes'`, and
-- `scripts/guards.sh` reported it as the only one of 464 enumerated refusal
-- sites it could not substitute. Its permissive mutation turns a coalesce
-- default from false to true, and this one coalesces to a string, so the harness
-- had no weakened form to write.
--
-- **A refusal nothing can weaken is a refusal nothing has proved matters.** The
-- whole apparatus in `scripts/mutate.sh` exists to answer "would the suite
-- notice if this stopped refusing", and it could not ask the question here.
--
-- `is distinct from` says the same thing without a default. `current_setting`
-- with `true` returns null when unset, and null is distinct from 'yes', so the
-- guard still fires for every caller that did not go through `confirm_note`.
-- It is shorter, it is the idiom this schema already uses for exactly this kind
-- of comparison, and it can be weakened, which is the point.

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
     -- Set by `confirm_note` and by nothing else, for one transaction. Unset
     -- reads as null, and null is distinct from 'yes', so the guard fires.
     and current_setting('vsv.confirming_note', true) is distinct from 'yes' then
    raise exception
      'confirming is its own act; use confirm_note so that who confirmed it is recorded';
  end if;

  return new;
end;
$$;

commit;
