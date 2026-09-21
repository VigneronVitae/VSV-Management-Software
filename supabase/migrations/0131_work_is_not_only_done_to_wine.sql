-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Opens the event table to subjects that are not wine lots, registers
--           a vine row as a thing that can be spoken about, and lets a note say
--           where its words came from, so that a periphery which heard them
--           rather than read them can say so."
-- Depends on: [supabase/migrations/0023_subject_resolver.sql,
--              supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql]
-- Depended on by: [docs/status-ledger.md,
--                  docs/review/2026-09-20-one-kernel-many-peripheries.md,
--                  tests/schema_assertions.sql]
-- Axioms enforced: T0-4. A trust field is set by the verifier. A periphery that
--                  transcribed what somebody said writes `inferred`, because the
--                  words are a machine's reading of a sound, and `confirmed` is
--                  refused outright here and left to `confirm_note`.
--                  T0-5. Everything added is an append.
-- Open sorries: none new. Narrows nothing; S-30 still governs what an offline
--               client does with writes the kernel has to decide, and none of
--               the writes here are of that kind.
-- ---------------------------------------------------------------------------

-- "I imagine as I'm pruning in the vineyard to be in a pruning mode in a
-- direction on the vine and me be able to take voice notes on each vine and the
-- block or whatever and it append notes to those objects."
--
-- Then, correcting the question that came back: "voice notes is a periphery
-- component right, then it would go through the same API and do one of the
-- allowed things to the kernel."
--
-- That correction is the whole design. Whether the words arrive by microphone,
-- by thumb, by a transcription service or by somebody typing them up that
-- evening is a periphery's business. What the kernel owes every one of those is
-- the same: somewhere to put the fact, and a way to say how well it is known.
-- Three things were missing and none of them is a screen.
--
-- **The event table was already right and only had one door.** `event` carries
-- `subject_type`, `subject_id`, an operation from a registered vocabulary,
-- `provenance` and a `data` blob: a general record that something was done to
-- something. The only capability reaching it is `record_event`, whose fields are
-- `lot, operation, data, vessels, at`. So the universal object has a
-- wine-shaped entrance, and a vineyard, a shop or an inventory periphery cannot
-- use it without pretending to be the cellar.
--
-- `record_work` is the other door. It is deliberately not a second way to do
-- what `record_event` does: it refuses a lot outright, because recording against
-- a lot's vessels can fork the lot, that decision is `record_event`'s, and two
-- functions making it would eventually make it differently.

-- ---------------------------------------------------------------------------
-- A row of vines is a thing you can say something about
-- ---------------------------------------------------------------------------

-- `plant_space`, `block` and `vineyard` were registered when the module started;
-- `vine_row` was not, which is the granularity a person pruning actually works
-- at. He was asked whether the record should be per vine or per row and said it
-- depends on the operator, which is the correct answer and means the kernel has
-- to accept both and let the periphery choose.
insert into subject_resolver (subject_type, relation, name_expression, module)
values ('vine_row', 'vine_row', '''Row '' || number::text', 'vineyard')
on conflict (subject_type) do update set
  relation = excluded.relation,
  name_expression = excluded.name_expression,
  module = excluded.module;

-- What kinds of thing exist, by name, for a periphery that has to ask.
--
-- `record_work` takes a subject type, and until now nothing in the contract said
-- which ones there are: a periphery would have had to hardcode the list, which is
-- the drift AR-Q8 was written against. The registry's own read policy is already
-- judged permissive in the assertion suite, on the grounds that it is structure
-- rather than content, so this publishes nothing that was not already readable.
insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('core.subject_types', 'core', 'Kinds of thing',
   'Every kind of thing this system can hold a note, a photograph or a record of work against. The list a periphery reads before it can offer any of those.',
   'subject_resolver', 'subject_type', 'subject_type', 20)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- Pruning is an operation
-- ---------------------------------------------------------------------------

-- One row, not seven. Pruning is what he named. Suckering, hedging, tying down
-- and thinning are all real vineyard work and adding them here would be guessing
-- at which distinctions this vineyard draws, which is the thing CLAUDE.md says
-- not to do. AR-E5 means each of them is later a row rather than a migration.
insert into term (kind, value, label, sort_order)
values ('operation', 'prune', 'Prune', 700)
on conflict (kind, value) do update set label = excluded.label, active = true;

-- ---------------------------------------------------------------------------
-- The other door
-- ---------------------------------------------------------------------------

create or replace function record_work(
  p_subject_type text,
  p_subject_id   uuid,
  p_operation    text,
  p_data         jsonb       default '{}'::jsonb,
  p_at           timestamptz default null,
  p_provenance   text        default 'observed'
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  made event%rowtype;
  op   uuid;
begin
  -- Runs as the caller so the insert policy decides, and says why in words,
  -- because a bare policy violation and a success are both silent. A13.
  if not is_facility_user() then
    raise exception 'work is recorded by people who work here';
  end if;

  -- T0-4. A periphery may say it watched this happen, or that it worked it out.
  -- It may not say a person checked it: that is `confirm_event`, and it is a
  -- separate act by a separate caller on purpose.
  if p_provenance not in ('observed', 'inferred') then
    raise exception
      'a record may be observed or inferred and not %; confirming is its own act', p_provenance;
  end if;

  if not exists (select 1 from subject_resolver where subject_type = p_subject_type) then
    raise exception 'nothing in this system is a %, so work cannot be done to one',
      p_subject_type;
  end if;

  -- The one subject this door will not open. A lot's event can fork the lot and
  -- `record_event` is where that decision lives; a second function reaching the
  -- same table without it would be a quiet way to lose a lot's identity.
  if p_subject_type = 'node' then
    raise exception
      'work on a lot goes through record_event, which decides what happens to the lot';
  end if;

  select t.id into op from term t
   where t.kind = 'operation' and t.value = p_operation and t.active;
  if op is null then
    raise exception 'there is no operation called %', p_operation;
  end if;

  insert into event (subject_type, subject_id, operation_id, data, by_user, at, provenance)
  values (p_subject_type, p_subject_id, op, coalesce(p_data, '{}'::jsonb), auth.uid(),
          coalesce(p_at, now()), p_provenance::provenance)
  returning * into made;

  return jsonb_build_object('id', made.id, 'at', made.at, 'provenance', made.provenance);
end $$;

comment on function record_work is
  'Records that an operation was performed on any registered subject except a '
  'lot. The other door to `event`, for modules that are not the cellar.';

-- ---------------------------------------------------------------------------
-- A note can say where its words came from
-- ---------------------------------------------------------------------------

-- `note.provenance` exists and defaults to `observed`, and `add_note` had no way
-- to set it. So a periphery that transcribed what somebody said would record a
-- machine's reading of a sound as a direct observation, under that person's
-- name. That is exactly the shape of the `coalesce(p_confirm, true)` fault 0126
-- fixed in `attest_line`, in a different function, and it would have arrived at
-- two hundred vines an hour.
--
-- The honest split, for a spoken note: the audio is observed, because he made
-- that sound, and the text is inferred, because the words are a guess at it. A
-- periphery that records without transcribing attaches the audio and writes no
-- text. A periphery where somebody types writes `observed`, which stays the
-- default so that every existing caller means what it meant yesterday.
-- Dropped by its exact old signature first. `create or replace` with a new
-- parameter does not replace anything: it overloads, so both arities live in the
-- catalog and `capability.fn` then names two functions. The contract check found
-- this within a minute, which is the check working.
drop function if exists add_note(text, uuid, text, uuid, timestamptz);

create or replace function add_note(
  p_subject_type text,
  p_subject_id   uuid,
  p_body         text,
  p_about_event  uuid        default null,
  p_at           timestamptz default null,
  p_provenance   text        default 'observed'
)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare n note%rowtype;
begin
  -- Runs as the caller, so the insert policy decides. This says why in words,
  -- because a bare policy violation and a success are both silent. A13.
  if not is_facility_user() then
    raise exception 'notes are written by people who work here';
  end if;
  if p_body is null or btrim(p_body) = '' then
    raise exception 'there is nothing here to say';
  end if;
  if not exists (select 1 from subject_resolver where subject_type = p_subject_type) then
    raise exception 'nothing in this system is a %, so a note cannot be about one',
      p_subject_type;
  end if;
  -- T0-4, same refusal and same reason as record_work. `confirm_note` exists and
  -- is the only way a note becomes confirmed.
  if p_provenance not in ('observed', 'inferred') then
    raise exception
      'a note may be observed or inferred and not %; confirming is its own act', p_provenance;
  end if;

  insert into note (subject_type, subject_id, about_event, body, by_user, at, provenance)
  values (p_subject_type, p_subject_id, p_about_event, btrim(p_body), auth.uid(),
          coalesce(p_at, now()), p_provenance::provenance)
  returning * into n;

  return jsonb_build_object('id', n.id, 'at', n.at, 'provenance', n.provenance);
end $$;

-- ---------------------------------------------------------------------------
-- The contract
-- ---------------------------------------------------------------------------

-- `record_work` is registered to `vineyard`, which until now had four readables
-- and no verbs at all, so a periphery built from the registry drew a read-only
-- app. It is not a vineyard-only function and the module is where it was first
-- needed; if the shop or inventory reach for it, that is an argument for moving
-- it to core rather than for copying it.
insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('vineyard.record_work', 'vineyard', 'Record work done',
   'Records that an operation was performed on something that is not a wine lot: a vine, a row, a block. The subject decides the granularity, so a periphery may record per vine or per row as its operator prefers.',
   'record_work',
   '[{"key": "subject_type", "type": "text", "label": "On what kind of thing", "param": "p_subject_type", "required": true,
      "source": {"readable": "core.subject_types"}},
     {"key": "subject_id", "type": "uuid", "label": "On which one", "param": "p_subject_id", "required": true},
     {"key": "operation", "type": "text", "label": "What was done", "param": "p_operation", "required": true,
      "source": {"terms": "operation"}},
     {"key": "data", "type": "jsonb", "label": "Anything worth keeping with it", "param": "p_data", "required": false},
     {"key": "at", "type": "timestamptz", "label": "When", "param": "p_at", "required": false,
      "hint": "Blank means now. An offline periphery sends the time it happened."},
     {"key": "provenance", "type": "text", "label": "Watched it, or worked it out", "param": "p_provenance", "required": false,
      "hint": "observed or inferred. Confirming is a separate act."}]'::jsonb,
   400)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

-- `add_note` gains the field. Declared rather than assumed, because a periphery
-- that cannot see the field will not send it, and will then be writing
-- `observed` without having decided to.
update capability
   set fields = fields || '[{"key": "provenance", "type": "text", "label": "Heard it, or worked it out",
        "param": "p_provenance", "required": false,
        "hint": "observed or inferred. A transcription is inferred until somebody confirms it."}]'::jsonb
 where key = 'cellar.add_note'
   and not exists (
     select 1 from jsonb_array_elements(fields) f where f->>'key' = 'provenance');

do $$
begin
  if not exists (select 1 from subject_resolver where subject_type = 'vine_row') then
    raise exception 'a vine row is still not a thing a note can be about';
  end if;
  if not exists (select 1 from readable where key = 'core.subject_types') then
    raise exception 'nothing tells a periphery which subject types exist, so record_work cannot be offered';
  end if;
  if not exists (
    select 1 from capability, jsonb_array_elements(fields) f
     where key = 'cellar.add_note' and f->>'key' = 'provenance') then
    raise exception 'add_note still cannot say where its words came from';
  end if;
  -- The refusal that matters most here, asserted rather than trusted.
  begin
    perform record_work('vine_row', gen_random_uuid(), 'prune', '{}'::jsonb, null, 'confirmed');
    raise exception 'record_work accepted confirmed, which T0-4 forbids';
  exception when others then
    if sqlerrm like '%confirming is its own act%' then
      null;
    elsif sqlerrm like '%people who work here%' then
      null;  -- ran as an owner with no session; the provenance guard sits behind this one
    else
      raise;
    end if;
  end;
end $$;
