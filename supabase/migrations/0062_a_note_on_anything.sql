-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Anything in this system can be said more about, afterwards, by
--           whoever knows, without the saying ever counting as evidence."
-- Depends on: [supabase/migrations/0023_subject_resolver.sql,
--              supabase/migrations/0047_attachments.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0063_a_note_is_a_thing_too.sql, supabase/migrations/0064_typing_a_note.sql,
--                  supabase/migrations/0078_the_wine_in_a_vessel.sql]
-- Axioms enforced: T0-3 (a note carries who said it and when), T0-5 (a note is
--                  appended; removing one is an administrator's act)
-- Open sorries: S-73 (day_note and vessel_type_note are not subsumed, so there
--                are three note tables), S-65's shape again (facility only)
-- ---------------------------------------------------------------------------
--
-- The winemaker, after two days of using this: "I feel like everything needs to
-- be an item that I can add more detail to. Like the fruit condition was mostly
-- good in the PG. How do I add that to the bins now? I know I could in the daily
-- notes, but..."
--
-- The "but" is the whole thing. **A daily note is a fact about a day and fruit
-- condition is a fact about fruit.** Putting it in the day means that in March,
-- looking at the Pinot Gris, there is nothing there, and the thing that would
-- have told you is filed under the fifteenth of September with everything else
-- that happened that afternoon.
--
-- **This is the third time a note table has been invented here**, which is the
-- argument for the general one. `day_note` belongs to a date. `vessel_type_note`
-- belongs to a vessel type. Both were right for what they were and neither
-- helps a bin. A note belongs to whatever it is about, and what things exist is
-- a question `subject_resolver` has answered since `0023`.
--
-- It is `attachment` with prose instead of a path, deliberately: a photograph of
-- the fruit and a sentence about the fruit are the same act, done twice, and
-- they should attach the same way and be findable in the same place.
--
-- **The rule that matters is his reference's.** Knowledge Game keeps comments as
-- "discussion threads that carry no grade and can never be cited as support", so
-- that "talking never masquerades as evidence", and says the separation is
-- enforced mechanically rather than by policy. Here that means exactly this: a
-- note is never read by anything that computes. It does not change a quantity,
-- it does not clear a worklist, and it cannot discharge a propagation or satisfy
-- a paper form. Those are asserted rather than intended, because an intention is
-- what this project calls a comment restating the code.
--
-- **So a note is not a substitute for a field.** Fruit condition is on Alexis's
-- receiving form, which means somebody will want to count how many loads came in
-- sound. A note cannot answer that and is not trying to: it is where the nuance
-- goes once the field has the answer. The field is still item 2 of the build
-- order in docs/record-requirements.md and this does not do it.

begin;

create table if not exists note (
  id           uuid primary key default gen_random_uuid(),
  -- The same registry `event` and `attachment` pin against.
  subject_type text not null references subject_resolver (subject_type)
                 on delete restrict,
  subject_id   uuid not null,
  -- Optional, and a real foreign key. "About that weighing" rather than "about
  -- this pick" is a distinction somebody wants the moment a pick has three of
  -- them, and `attachment` learned it in 0047 for the same reason.
  about_event  uuid references event (id) on delete restrict,
  body         text not null,
  by_user      uuid references app_user (id),
  -- When it is about, which is not always when it was typed. "The fruit was
  -- mostly good" written in the evening is about the morning.
  at           timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  edited_at    timestamptz,
  constraint note_says_something check (btrim(body) <> '')
);

create index if not exists note_subject_idx
  on note (subject_type, subject_id, at desc);
create index if not exists note_event_idx
  on note (about_event) where about_event is not null;

-- The same guard `attachment` carries: a note that names an event must be about
-- what that event was about, or it can claim one pick's weighing while filed
-- under another and both screens show it correctly.
create or replace function note_event_matches_subject()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare e event%rowtype;
begin
  if new.about_event is null then
    return new;
  end if;
  select * into e from event where id = new.about_event;
  if e.id is null then
    raise exception 'there is no event % for this note to be about', new.about_event;
  end if;
  if e.subject_type <> new.subject_type or e.subject_id <> new.subject_id then
    raise exception
      'that note is filed under % % and names an event about % %, so one of the two is wrong',
      new.subject_type, new.subject_id, e.subject_type, e.subject_id;
  end if;
  return new;
end;
$$;

drop trigger if exists note_event_is_about_the_same_thing on note;
create trigger note_event_is_about_the_same_thing
  before insert or update on note
  for each row execute function note_event_matches_subject();

-- What may change afterwards. The words can be corrected by whoever wrote them,
-- and an edit says so, because a note that changed silently is a note nobody can
-- rely on having read. Where it is filed cannot move: that is the same reasoning
-- `attachment` uses, and refiling is attaching a new one.
create or replace function note_is_not_refiled()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
begin
  if new.subject_type <> old.subject_type
     or new.subject_id <> old.subject_id
     or new.about_event is distinct from old.about_event
     or new.by_user is distinct from old.by_user then
    raise exception
      'a note can be reworded but not refiled; write a new one on the right thing';
  end if;
  if new.body <> old.body then
    new.edited_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists note_only_the_words_change on note;
create trigger note_only_the_words_change
  before update on note
  for each row execute function note_is_not_refiled();

alter table note enable row level security;

-- Facility only, the same as attachments and for the same unresolved reason.
-- S-65 argues this is too narrow for a client looking at their own wine.
drop policy if exists note_read on note;
create policy note_read on note for select to authenticated using (is_facility_user());

drop policy if exists note_insert on note;
create policy note_insert on note for insert to authenticated
  with check (is_facility_user() and by_user = auth.uid());

drop policy if exists note_edit on note;
create policy note_edit on note for update to authenticated
  using (is_facility_user() and by_user = auth.uid())
  with check (is_facility_user() and by_user = auth.uid());

drop policy if exists note_admin_delete on note;
create policy note_admin_delete on note for delete to authenticated
  using (is_admin());

comment on table note is
  'Something somebody said about anything the resolver knows, at any time. '
  'Never read by anything that computes: a note changes no quantity, clears no '
  'worklist and satisfies no form. Talking does not masquerade as evidence. '
  'See 0062, and S-73 for the two older note tables it does not yet replace.';

-- ---------------------------------------------------------------------------
-- Writing one
-- ---------------------------------------------------------------------------

create or replace function add_note(
  p_subject_type text,
  p_subject_id   uuid,
  p_body         text,
  p_about_event  uuid default null,
  p_at           timestamptz default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
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

  insert into note (subject_type, subject_id, about_event, body, by_user, at)
  values (p_subject_type, p_subject_id, p_about_event, btrim(p_body), auth.uid(),
          coalesce(p_at, now()))
  returning * into n;

  return jsonb_build_object('id', n.id, 'at', n.at);
end;
$$;

revoke all on function add_note(text, uuid, text, uuid, timestamptz) from public;
grant execute on function add_note(text, uuid, text, uuid, timestamptz) to authenticated;

-- What has been said about anything, with who said it.
create or replace view subject_note with (security_invoker = true) as
select
  n.id,
  n.subject_type,
  n.subject_id,
  n.about_event,
  n.body,
  n.at,
  n.edited_at,
  u.name as by_name,
  n.by_user
from note n
left join app_user u on u.id = n.by_user;

comment on view subject_note is
  'Notes with the name of whoever wrote them. See 0062.';

-- ---------------------------------------------------------------------------
-- The contract learns about it
-- ---------------------------------------------------------------------------

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order)
values ('cellar.notes', 'cellar', 'What people have said',
        'Notes on anything. Never evidence: a note changes nothing and satisfies nothing.',
        'subject_note', 'id', 'body', 110)
on conflict (key) do update set
  label = excluded.label, note = excluded.note, relation = excluded.relation,
  id_column = excluded.id_column, label_column = excluded.label_column;

insert into capability (key, module, label, note, fn, subject, fields, sort_order)
values ('cellar.add_note', 'cellar', 'Say something about anything',
        'A note on a lot, a bin, a vessel, a block. Added whenever somebody gets to it, and never counted as evidence.',
        'add_note', null,
        '[{"key":"subject_type","param":"p_subject_type","type":"text","required":true,
           "label":"About what kind of thing"},
          {"key":"subject_id","param":"p_subject_id","type":"uuid","required":true,
           "label":"About which one"},
          {"key":"body","param":"p_body","type":"text","required":true,"label":"What to say"},
          {"key":"about_event","param":"p_about_event","type":"uuid","required":false,
           "label":"About which event, if it is about one"},
          {"key":"at","param":"p_at","type":"timestamptz","required":false,
           "label":"When it is about","hint":"Blank means now."}]'::jsonb, 240)
on conflict (key) do update set
  label = excluded.label, note = excluded.note, fn = excluded.fn,
  fields = excluded.fields, sort_order = excluded.sort_order;

commit;
