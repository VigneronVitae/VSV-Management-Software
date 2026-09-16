-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Anything can be marked as worth watching, with what you expect of
--           it, so the difference between what you expected and what turned up
--           is a number the app can show rather than one you hold in your head."
-- Depends on: [supabase/migrations/0095_what_is_running.sql,
--              supabase/migrations/0026_subject_type_registry.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-4 (an expectation is told and stays an expectation; it
--                  never becomes a measurement), T0-5 (changing your mind is a
--                  new statement rather than an edit to the old one)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker, minutes after starting a press: *"also similarly something like
-- a hot list"*, and then the example that defines it: *"well like for instance
-- the first press just started. I imagine by the time it's finished it'll be
-- more like 450 liters."*
--
-- **That is a number he already has and the app has nowhere to put.** The press
-- has drawn 150 litres off 1,733 pounds. Whether that is going well is not
-- answerable from either figure: it is answerable from 150 against the 450 he
-- expects, and that expectation lives in his head until the press is finished
-- and it is too late for it to have been useful.
--
-- **An expectation is told, and it never becomes a measurement.** It is written
-- as an event, so it has an author and a time, and the press's actual litres
-- keep coming from the draws. Nothing here can make a yield look better than it
-- was: the two numbers sit side by side and the gap is the point.
--
-- **Changing your mind is a new statement.** Expectations are appended, and the
-- most recent one is what the screens read, which means "I thought 450 and by
-- the second cut I thought 380" is a record of how the day went rather than a
-- field that was overwritten.
--
-- **The hot list is the same mechanism.** A thing can be watched with no number
-- at all, which is "keep this in front of me", and that is what `0095`'s
-- running list cannot express: a barrel nobody has touched for a fortnight is
-- not running and may still be the thing on your mind.

begin;

insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'watch', 'Watching', 74, '{"effect": "measurement"}'::jsonb),
  ('operation', 'unwatch', 'Stopped watching', 75, '{"effect": "measurement"}'::jsonb)
on conflict (kind, value) do nothing;

-- Anything with a subject type can be watched, which is the registry from 0026
-- doing its job: a vineyard block in the week before picking is as watchable as
-- a press, and neither needed a column.
create or replace function watch_subject(
  p_subject_type text,
  p_subject_id   uuid,
  p_expect       numeric default null,
  p_unit         text    default null,
  p_note         text    default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  eid  uuid;
  what text;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here decides what is worth watching'
      using errcode = 'insufficient_privilege';
  end if;

  if not exists (select 1 from subject_resolver where subject_type = p_subject_type) then
    raise exception '% is not a kind of thing this winery records', p_subject_type;
  end if;

  what := resolve_subject_name(p_subject_type, p_subject_id);
  if what is null then
    raise exception 'there is no % with that id to watch', p_subject_type;
  end if;

  -- A number with no unit is a number nobody can read back. 450 of what.
  if p_expect is not null and nullif(btrim(coalesce(p_unit, '')), '') is null then
    raise exception 'say what % is measured in', p_expect;
  end if;
  if p_expect is not null and p_expect <= 0 then
    raise exception 'an expectation of % is not something to watch for', p_expect;
  end if;

  insert into event (operation_id, subject_type, subject_id, by_user, provenance, data)
  values (term_id('operation', 'watch'), p_subject_type, p_subject_id, auth.uid(),
          -- Observed: he did say it. What it is *about* has not happened yet,
          -- which is a different thing from the saying being uncertain.
          'observed',
          jsonb_strip_nulls(jsonb_build_object(
            'expect', p_expect,
            'unit',   nullif(btrim(coalesce(p_unit, '')), ''),
            'note',   nullif(btrim(coalesce(p_note, '')), ''))))
  returning id into eid;

  return jsonb_build_object('event', eid, 'what', what,
                            'expect', p_expect, 'unit', p_unit);
end;
$$;

revoke all on function watch_subject(text, uuid, numeric, text, text) from public;
grant execute on function watch_subject(text, uuid, numeric, text, text) to authenticated;

create or replace function unwatch_subject(
  p_subject_type text,
  p_subject_id   uuid
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare eid uuid;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here decides what is worth watching'
      using errcode = 'insufficient_privilege';
  end if;

  if not exists (
    select 1 from event
     where subject_type = p_subject_type and subject_id = p_subject_id
       and operation_id = term_id('operation', 'watch')
  ) then
    raise exception 'that was not being watched';
  end if;

  -- Appended, not deleted. That it was watched, and by whom, and what they
  -- expected, is the record of somebody's attention and is worth keeping.
  insert into event (operation_id, subject_type, subject_id, by_user, provenance)
  values (term_id('operation', 'unwatch'), p_subject_type, p_subject_id,
          auth.uid(), 'observed')
  returning id into eid;

  return jsonb_build_object('event', eid, 'watching', false);
end;
$$;

revoke all on function unwatch_subject(text, uuid) from public;
grant execute on function unwatch_subject(text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- The hot list
-- ---------------------------------------------------------------------------

create or replace view watching with (security_invoker = true) as
with said as (
  -- The latest thing anybody said about watching each subject, whichever way.
  select distinct on (e.subject_type, e.subject_id)
    e.subject_type,
    e.subject_id,
    e.operation_id,
    e.at,
    (e.data ->> 'expect')::numeric as expect,
    e.data ->> 'unit'              as unit,
    e.data ->> 'note'              as note,
    e.by_user
  from event e
  where e.operation_id in (term_id('operation', 'watch'),
                           term_id('operation', 'unwatch'))
  order by e.subject_type, e.subject_id, e.at desc, e.created_at desc
)
select
  s.subject_type,
  s.subject_id,
  resolve_subject_name(s.subject_type, s.subject_id) as what,
  s.expect,
  s.unit,
  s.note,
  s.at        as since,
  u.name      as by_name,
  -- What it has actually reached, where the app knows. Today that is a press,
  -- which is the case he asked for; anything else reports null rather than
  -- pretending to a number.
  case
    when s.subject_type = 'node' then
      (select pip.litres_so_far from press_in_progress pip where pip.node_id = s.subject_id)
  end         as so_far
from said s
left join app_user u on u.id = s.by_user
where s.operation_id = term_id('operation', 'watch');

comment on view watching is
  'The hot list: everything somebody said to keep in front of them, with what '
  'they expected of it and what it has reached so far. An expectation is told '
  'and never becomes a measurement. See 0096.';

grant select on watching to authenticated;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.watching', 'cellar', 'What you are watching',
   'Things somebody asked to keep in front of them, with what they expected.',
   'watching', 'subject_id', 'what', 6)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('cellar.watch_subject', 'cellar', 'Watch this',
   'Keep it in front of you, and say what you expect of it if you have a number '
   'in mind. The expectation never becomes a measurement.',
   'watch_subject', null,
   '[{"key":"subject_type","param":"p_subject_type","type":"text","required":true,
      "label":"What kind of thing"},
     {"key":"subject_id","param":"p_subject_id","type":"uuid","required":true,
      "label":"Which one"},
     {"key":"expect","param":"p_expect","type":"numeric","required":false,
      "label":"What you expect",
      "note":"A press you think will give 450 litres, say."},
     {"key":"unit","param":"p_unit","type":"text","required":false,
      "label":"Of what",
      "note":"Litres, pounds, Brix. Required if you gave a number."},
     {"key":"note","param":"p_note","type":"text","required":false,
      "label":"Why you are watching it"}]'::jsonb, 280)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

insert into capability_exemption (fn, reason) values
  ('unwatch_subject', 'The other half of watch_subject. A periphery that can watch can stop.')
on conflict (fn) do nothing;

commit;
