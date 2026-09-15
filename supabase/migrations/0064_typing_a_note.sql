-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A note is an untyped fact. Typing it keeps the prose and adds a
--           registered kind and a value, so the thing that can be reported on
--           and the thing somebody actually said are one object."
-- Depends on: [supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0062_a_note_on_anything.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0065_confirming_without_owning.sql, supabase/migrations/0067_sampling.sql]
-- Axioms enforced: T0-4 (an agent may write inferred and may never write
--                  confirmed), AR-E6 (the list of fact kinds is registry rows,
--                  so an unsettled list is data rather than schema)
-- Open sorries: S-74 (nothing reads a typed fact yet), S-75 (a unit is declared
--                and never checked)
-- ---------------------------------------------------------------------------
--
-- The winemaker: "how could the notes contribute to the field? Or become a
-- field? Tags in notes?" Then, a minute later, the thing that settled it: "we
-- might think of the untyped type here a la epistack."
--
-- **This system already has that idea and already asserts it, one level down.**
-- spec.md calls it the untyped floor: "nothing is refused, and what is unknown
-- stays unknown until somebody supplies it", and for an arriving lot, it "should
-- land, be addressable, and drive nothing until somebody here types it". The
-- suite has proved that for operations since early on: an operation the kernel
-- has never seen records an event and changes no lineage.
--
-- `0062` built the same floor for facts without noticing. A note lands, is
-- addressable, and drives nothing. **Typing it is the other half that was
-- always implied.**
--
-- **Typing is not copying the text into a column.** A column throws the prose
-- away, and "22.4 Brix" and "22.4, but the sample was off the top of the tank"
-- are different facts of which a column keeps one. So the note gains a kind and
-- a value and keeps its body. What can be reported on and what somebody actually
-- said stay one object.
--
-- **The kinds are terms, which is the whole reason this is worth building now.**
-- `docs/record-requirements.md` already specified it: "a measurement that
-- carries named readings, with the parameter list as registry rows the way 0027
-- made every other list a row, covers all four forms at once and the fifth form
-- nobody has handed over yet." The winemaker put readings below press detail
-- because "the chemistry specification is not finished", and building against an
-- unfinished list would mean building twice. With the list as rows, an unsettled
-- list is data. **The reason to defer stops applying.**
--
-- Only one kind is seeded, which is the one he asked about. Deciding Alexis's
-- chemistry vocabulary is not this migration's business and is now a thing
-- somebody does in the app in ten seconds.

begin;

-- ---------------------------------------------------------------------------
-- What kinds of fact there are
-- ---------------------------------------------------------------------------

insert into term_kind (kind, module, label, sort_order)
values ('fact_kind', 'core', 'Kind of fact', 95)
on conflict (kind) do update set label = excluded.label, module = excluded.module;

-- A fact kind declares what shape its value is, and may declare a unit. The
-- unit is recorded and not checked, which is S-75 and is the same missing
-- answer as S-63.
--
-- `value_type` is `number` or `text`. There is deliberately no boolean: a
-- boolean is a text with two values and somebody would immediately want a third,
-- which is how "sound" and "mostly sound" and "some botrytis" happen.
insert into term (kind, value, label, sort_order, attributes)
values ('fact_kind', 'fruit_condition', 'Fruit condition', 10,
        '{"value_type": "text",
          "hint": "How the fruit looked coming in. Alexis''s receiving form asks for it."}'::jsonb)
on conflict (kind, value) do update set
  label = excluded.label, attributes = excluded.attributes;

-- ---------------------------------------------------------------------------
-- A note that has been typed
-- ---------------------------------------------------------------------------

alter table note
  add column if not exists kind_id    uuid references term (id),
  add column if not exists value_num  numeric,
  add column if not exists value_text text,
  -- Who says so, and how much anybody has checked it. The vocabulary already
  -- existed and this is what it was for: a fact typed by the person who saw it
  -- is observed, a fact typed by something reading a tag is inferred, and only a
  -- person makes one confirmed. T0-4.
  add column if not exists provenance provenance not null default 'observed';

-- The composite pin every other pointer into the vocabulary uses, so a note
-- cannot be typed with a variety by mistake.
alter table note
  add column if not exists kind_kind text
    generated always as ('fact_kind') stored;

alter table note drop constraint if exists note_kind_is_a_fact_kind;
alter table note
  add constraint note_kind_is_a_fact_kind
  foreign key (kind_id, kind_kind) references term (id, kind);

-- A value without a kind is a number nobody can interpret.
alter table note drop constraint if exists note_value_needs_a_kind;
alter table note
  add constraint note_value_needs_a_kind
  check (kind_id is not null
         or (value_num is null and value_text is null));

create index if not exists note_kind_idx on note (kind_id) where kind_id is not null;

comment on column note.kind_id is
  'What kind of fact this note carries, once somebody has typed it. Null is the '
  'untyped floor: the note is addressable and drives nothing. See 0064.';

-- ---------------------------------------------------------------------------
-- The gate
-- ---------------------------------------------------------------------------

-- A typed note must carry the shape its kind declares, and must carry something.
-- This is the half that makes typing mean anything: without it, "typed" is a
-- pointer at a vocabulary row and the value is still prose.
create or replace function note_value_matches_its_kind()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  want text;
  label text;
begin
  if new.kind_id is null then
    -- The untyped floor. Nothing is required and nothing is refused.
    return new;
  end if;

  select t.attributes ->> 'value_type', t.label into want, label
    from term t where t.id = new.kind_id;

  if new.value_num is null and new.value_text is null then
    raise exception
      'a note typed as % has no value, and a kind without a value says less than the sentence did',
      coalesce(label, 'that');
  end if;

  if want = 'number' and new.value_num is null then
    raise exception '% is a number, and this one was given words', coalesce(label, 'that kind');
  end if;
  if want = 'text' and new.value_text is null then
    raise exception '% is written out, and this one was given a number',
      coalesce(label, 'that kind');
  end if;
  if want = 'number' and new.value_text is not null then
    raise exception '% is a number; put the rest in the note itself', coalesce(label, 'that kind');
  end if;

  return new;
end;
$$;

drop trigger if exists note_carries_what_its_kind_declares on note;
create trigger note_carries_what_its_kind_declares
  before insert or update on note
  for each row execute function note_value_matches_its_kind();

-- T0-4, mechanically. Nothing but a person's deliberate act makes a fact
-- confirmed, and the act is `confirm_note` below rather than an update somebody
-- can make by accident while rewording.
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
     and new.provenance = 'confirmed' then
    raise exception
      'confirming is its own act; use confirm_note so that who confirmed it is recorded';
  end if;
  return new;
end;
$$;

drop trigger if exists note_provenance_is_earned on note;
create trigger note_provenance_is_earned
  before insert or update on note
  for each row execute function note_provenance_is_not_self_granted();

-- ---------------------------------------------------------------------------
-- Typing one
-- ---------------------------------------------------------------------------

create or replace function type_note(
  p_note_id    uuid,
  p_kind       text,
  p_value_num  numeric default null,
  p_value_text text    default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  k term%rowtype;
  n note%rowtype;
begin
  select * into n from note where id = p_note_id;
  if n.id is null then
    raise exception 'there is no note with id %', p_note_id;
  end if;

  select * into k from term
   where kind = 'fact_kind' and value = p_kind and active;
  if k.id is null then
    raise exception
      'nothing here is a kind of fact called %. Add it first, which is a row rather than a change to this system',
      p_kind;
  end if;

  update note
     set kind_id = k.id,
         value_num = p_value_num,
         value_text = nullif(btrim(coalesce(p_value_text, '')), '')
   where id = p_note_id;

  return jsonb_build_object(
    'id', p_note_id, 'kind', k.value, 'label', k.label,
    'value', coalesce(p_value_num::text, p_value_text));
end;
$$;

revoke all on function type_note(uuid, text, numeric, text) from public;
grant execute on function type_note(uuid, text, numeric, text) to authenticated;

-- Confirming is its own act, so that who checked it is recorded. T0-4 again:
-- the agent that inferred a fact may never be the thing that confirms it.
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
    raise exception
      'that note has not been typed, so there is no fact in it to confirm';
  end if;

  -- The trigger refuses an update to confirmed, so this is the one path, and it
  -- writes a note about the confirming rather than a column nobody can see.
  alter table note disable trigger note_provenance_is_earned;
  update note set provenance = 'confirmed' where id = p_note_id;
  alter table note enable trigger note_provenance_is_earned;

  insert into note (subject_type, subject_id, body, by_user)
  values ('note', p_note_id, 'checked and confirmed', auth.uid());

  return jsonb_build_object('id', p_note_id, 'provenance', 'confirmed');
end;
$$;

revoke all on function confirm_note(uuid) from public;
grant execute on function confirm_note(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- What has been typed
-- ---------------------------------------------------------------------------

-- The reportable surface, and the answer to "become a field". A field is a
-- column somebody queries; this is a query. The difference is that the prose
-- survives beside the value rather than being thrown away to make room for it.
create or replace view typed_fact with (security_invoker = true) as
select
  n.id            as note_id,
  n.subject_type,
  n.subject_id,
  n.about_event,
  t.value         as kind,
  t.label         as kind_label,
  t.attributes ->> 'unit' as unit,
  n.value_num,
  n.value_text,
  coalesce(n.value_num::text, n.value_text) as value,
  n.body,
  n.provenance,
  n.at,
  u.name          as by_name
from note n
join term t on t.id = n.kind_id and t.kind = 'fact_kind'
left join app_user u on u.id = n.by_user;

comment on view typed_fact is
  'Notes somebody has typed: a registered kind, a value, and the sentence it '
  'came from. This is what "becoming a field" means here, and the prose beside '
  'the value is the reason it is better than a column. See 0064 and S-74.';

-- Untyped notes, which is the floor and also a worklist if anybody wants it:
-- things somebody said that nobody has turned into a fact.
create or replace view untyped_note with (security_invoker = true) as
select n.id, n.subject_type, n.subject_id, n.body, n.at, u.name as by_name
from note n
left join app_user u on u.id = n.by_user
where n.kind_id is null;

comment on view untyped_note is
  'Notes nobody has typed. The untyped floor: addressable, and driving nothing. '
  'Not a list that must be emptied, because most notes are just talking.';

-- ---------------------------------------------------------------------------
-- The contract learns about it
-- ---------------------------------------------------------------------------

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order)
values
  ('cellar.typed_facts', 'cellar', 'Facts',
   'Notes somebody has typed, with the sentence they came from.',
   'typed_fact', 'note_id', 'value', 120),
  ('cellar.untyped_notes', 'cellar', 'Notes nobody has typed',
   'The untyped floor. Addressable, driving nothing.',
   'untyped_note', 'id', 'body', 130)
on conflict (key) do update set
  label = excluded.label, note = excluded.note, relation = excluded.relation,
  id_column = excluded.id_column, label_column = excluded.label_column;

insert into capability (key, module, label, note, fn, subject, fields, sort_order)
values
  ('cellar.type_note', 'cellar', 'Turn a note into a fact',
   'Give a note a kind and a value. The words stay; the value becomes something you can ask about.',
   'type_note', 'cellar.untyped_notes',
   '[{"key":"note","param":"p_note_id","type":"uuid","required":true,"label":"Which note",
      "source":{"readable":"cellar.untyped_notes"}},
     {"key":"kind","param":"p_kind","type":"text","required":true,"label":"What kind of fact",
      "source":{"terms":"fact_kind"}},
     {"key":"number","param":"p_value_num","type":"numeric","required":false,
      "label":"The value, if it is a number"},
     {"key":"words","param":"p_value_text","type":"text","required":false,
      "label":"The value, if it is written out"}]'::jsonb, 250),
  ('cellar.confirm_note', 'cellar', 'Confirm a fact',
   'Somebody checked it. Only a person does this, and who did is recorded.',
   'confirm_note', 'cellar.typed_facts',
   '[{"key":"note","param":"p_note_id","type":"uuid","required":true,"label":"Which fact",
      "source":{"readable":"cellar.typed_facts"}}]'::jsonb, 260)
on conflict (key) do update set
  label = excluded.label, note = excluded.note, fn = excluded.fn,
  subject = excluded.subject, fields = excluded.fields, sort_order = excluded.sort_order;

commit;
