-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A sample is an act against a place, and the numbers that came out
--           of it are facts about that act."
-- Depends on: [supabase/migrations/0039_vineyard.sql,
--              supabase/migrations/0064_typing_a_note.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (a sample stores no readings of its own; the readings
--                  are typed notes about it), AR-E5 (a planting becomes a
--                  subject by being registered, and nothing else changes)
-- Open sorries: S-76 (a variety across blocks is a query, not a subject)
-- ---------------------------------------------------------------------------
--
-- The winemaker: "samples should be able to be assigned to vineyards and blocks
-- and varieties, both as a sampling button and in the vineyard button."
--
-- **Two of those three are already subjects and the third is the interesting
-- one.** A variety is a `term`: a word. Sampling a word is not a thing somebody
-- does. What they do is walk into the Southeast block and pick Pinot Gris
-- berries, and "Pinot Gris in the Southeast block" is a `planting`, which `0039`
-- already made a row because "a block is not one thing, it is rows of different
-- varieties, rootstocks and planting age". So a planting becomes a subject and
-- the third case is covered by something that already existed.
--
-- The fourth case nobody asked for is covered by S-76 and deliberately not by
-- this: "every Pinot Gris we have" spans blocks and is a report with a decision
-- in it about what it averages, not a missing subject type.
--
-- **A sample carries no readings.** This is the part that would have been wrong
-- a week ago and is now obvious. A sample is an act: somebody went out and took
-- fruit. The Brix that came back is a fact about that act, which is a typed note
-- with `about_event` pointing at it, and `0064` built that. Putting a `brix`
-- column on a sample would be nine columns for four forms all over again, and
-- the parameter list would be schema instead of data.
--
-- So this migration is one registry row, one function that writes an event, and
-- a view that puts the readings back beside the sample they came from.

begin;

-- ---------------------------------------------------------------------------
-- A planting is a thing you can say something about
-- ---------------------------------------------------------------------------

insert into subject_resolver (subject_type, relation, name_expression, module)
values ('planting', 'planting',
        -- "Vitae Springs Vineyard Southeast Pinot Gris". Long, and it is what
        -- somebody needs to pick the right one out of a list of eleven.
        'coalesce((select concat_ws('' '', v.name, b.name) from block b '
        || 'left join vineyard v on v.id = b.vineyard_id where b.id = block_id), '''') '
        || '|| coalesce('' '' || (select t.label from term t where t.id = variety_id), '''')',
        'vineyard')
on conflict (subject_type) do update
  set relation = excluded.relation,
      name_expression = excluded.name_expression,
      module = excluded.module;

-- ---------------------------------------------------------------------------
-- Taking one
-- ---------------------------------------------------------------------------

create or replace function take_sample(
  p_subject_type text,
  p_subject_id   uuid,
  p_at           timestamptz default null,
  p_note         text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  ev_id uuid := gen_random_uuid();
  name  text;
begin
  if not is_facility_user() then
    raise exception 'samples are taken by people who work here';
  end if;
  if not exists (select 1 from subject_resolver where subject_type = p_subject_type) then
    raise exception 'nothing in this system is a %, so a sample cannot be of one',
      p_subject_type;
  end if;

  -- Resolving the name proves the row is there. `event.subject_id` cannot be a
  -- foreign key (S-4), so this is the only check available and it is worth
  -- making: a sample of a block somebody deleted is a reading of nothing.
  name := resolve_subject_name(p_subject_type, p_subject_id);
  if name is null then
    raise exception 'there is no % with id % to sample', p_subject_type, p_subject_id;
  end if;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, at, provenance, data)
  values
    (ev_id, term_id('operation', 'sample'), p_subject_type, p_subject_id,
     auth.uid(), coalesce(p_at, now()), 'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'note', nullif(btrim(coalesce(p_note, '')), ''))));

  -- The readings are not here on purpose. They are typed notes about this
  -- event, which is why the caller gets the event id back: it is the thing to
  -- hang them off.
  return jsonb_build_object(
    'event_id', ev_id,
    'subject_type', p_subject_type,
    'subject_id', p_subject_id,
    'of', name);
end;
$$;

revoke all on function take_sample(text, uuid, timestamptz, text) from public;
grant execute on function take_sample(text, uuid, timestamptz, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Reading them back
-- ---------------------------------------------------------------------------

-- A sample, what it was of, and how many readings came off it. The readings
-- themselves are `typed_fact` rows whose `about_event` is this sample, which is
-- how one sample carries a Brix and a pH and a note about the weather without a
-- column for any of them.
create or replace view sample with (security_invoker = true) as
select
  e.id            as event_id,
  e.subject_type,
  e.subject_id,
  resolve_subject_name(e.subject_type, e.subject_id) as of_what,
  e.at,
  e.data ->> 'note' as note,
  u.name          as by_name,
  (select count(*) from note n
    where n.about_event = e.id and n.kind_id is not null) as readings
from event e
left join app_user u on u.id = e.by_user
where e.operation_id = term_id('operation', 'sample');

comment on view sample is
  'Every sample, what it was of, and how many readings have been typed against '
  'it. A sample stores no readings of its own: they are typed notes whose '
  'about_event is the sample. See 0067.';

-- ---------------------------------------------------------------------------
-- The contract learns about it
-- ---------------------------------------------------------------------------

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order)
values
  ('cellar.samples', 'cellar', 'Samples',
   'What was sampled, when, and how many readings came off it.',
   'sample', 'event_id', 'of_what', 140),
  ('vineyard.plantings', 'vineyard', 'Plantings',
   'A variety in a block. What you sample when you sample a variety.',
   'planting_detail', 'planting_id', 'block_name', 150)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into capability (key, module, label, note, fn, subject, fields, sort_order)
values ('cellar.take_sample', 'cellar', 'Take a sample',
        'Record that somebody sampled something. The readings are typed onto it afterwards, which is what lets one sample carry a Brix and a pH and a remark about the weather.',
        'take_sample', null,
        '[{"key":"subject_type","param":"p_subject_type","type":"text","required":true,
           "label":"Of what kind of thing","hint":"A vineyard, a block, a planting, or a vessel."},
          {"key":"subject_id","param":"p_subject_id","type":"uuid","required":true,
           "label":"Of which one"},
          {"key":"at","param":"p_at","type":"timestamptz","required":false,
           "label":"When","hint":"Blank means now."},
          {"key":"note","param":"p_note","type":"text","required":false,
           "label":"Anything worth saying about the sample itself"}]'::jsonb, 270)
on conflict (key) do update set
  label = excluded.label, note = excluded.note, fn = excluded.fn,
  fields = excluded.fields, sort_order = excluded.sort_order;

commit;
