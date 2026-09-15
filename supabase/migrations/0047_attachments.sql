-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A photograph of anything, attached whenever somebody gets to it,
--           rather than only at the moment the thing was recorded."
-- Depends on: [supabase/migrations/0023_subject_resolver.sql,
--              supabase/migrations/0042_weighing_photo.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0048_pick_weighing.sql, supabase/migrations/0062_a_note_on_anything.sql]
-- Axioms enforced: T0-3 (a photograph is evidence and carries who took it and
--                  when), T0-5 (an attachment is appended; removing one is an
--                  administrator's act rather than a correction)
-- Open sorries: S-65 (a client cannot see photographs of their own wine)
-- ---------------------------------------------------------------------------
--
-- Two things asked for on the same day, and they turn out to be one thing.
--
-- The winemaker weighed three loads, photographed the scale three times, and had
-- nowhere to put the photographs. `0042` put the photograph in the kernel and
-- never in the screen: `weigh_bins` would accept a path and nothing ever offered
-- to take one. His words: "I should be able to attach them later to the pick or
-- bins within." **Later is the important word.** A photograph that can only be
-- attached at the moment of recording is a photograph that does not get taken,
-- because the moment of recording is the moment both hands are full and the
-- truck is running.
--
-- And from the morning of the same day: vessels should hold more than one
-- photograph. A vessel carries `attributes.photo_path`, one path, replaced each
-- time, so photographing the second gauge loses the first.
--
-- Both are the same absence: there is nowhere to put a picture of a thing.
--
-- **So an attachment hangs off a subject, and a subject is anything the resolver
-- knows about.** That is the registry `0023` built, and using it is what lets
-- this cover a lot, a vessel, a block, a location and a vineyard without naming
-- any of them here, and cover whatever a later migration invents without being
-- touched.
--
-- **A photograph of a scale is evidence for one reading, not for the pick.**
-- Three weighings of one pick want three photographs told apart, so an
-- attachment may also name the event it is evidence for. That is a real foreign
-- key, unlike `subject_id`, which cannot be one (S-4). Naming the event is
-- optional: a picture of the fruit on the sorting table is about the pick and
-- about no particular event, and forcing it to choose one would be a lie.
--
-- **One place answers "is there a photograph of this".** `0042` wrote the path
-- into the weighing's own data, and leaving that as a second source would mean
-- two answers that can disagree. So a path handed to `weigh_bins` becomes an
-- attachment as well, and `weighing_without_photo` asks the attachments. Without
-- that, a weighing photographed in the evening would stay on the list of
-- weighings nobody photographed, which is the shape of wrong answer this project
-- exists to refuse.

begin;

create table if not exists attachment (
  id           uuid primary key default gen_random_uuid(),
  -- The same registry `event` pins its subject against. Nothing here names a
  -- table, so a photograph of something invented later needs no change to this.
  subject_type text not null references subject_resolver (subject_type)
                 on delete restrict,
  subject_id   uuid not null,
  -- Optional, and a real foreign key because an event has one table to point at.
  -- Set means "this is evidence for that particular thing that happened"; null
  -- means "this is a picture of the subject".
  about_event  uuid references event (id) on delete restrict,
  -- A path in the `vessel-photos` bucket, which has held every photograph in
  -- this system since 0005 and is now misnamed rather than misused. Renaming a
  -- bucket orphans every path already stored in it, so the name stays and this
  -- comment carries the correction.
  path         text not null,
  caption      text,
  by_user      uuid references app_user (id),
  -- When the photograph was taken, which is not always when it arrived. Three
  -- photographs of a scale uploaded in the evening were taken that morning, and
  -- the morning is the fact worth keeping; `created_at` keeps the evening.
  at           timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  constraint attachment_has_a_path check (btrim(path) <> ''),
  -- The same photograph attached twice to the same thing is a double tap on a
  -- phone with gloves on, not a second photograph.
  constraint attachment_once_per_subject unique (subject_type, subject_id, path)
);

create index if not exists attachment_subject_idx
  on attachment (subject_type, subject_id, at desc);
create index if not exists attachment_event_idx
  on attachment (about_event) where about_event is not null;

-- An attachment that names an event must be attached to what that event was
-- about. Otherwise a photograph can claim to be evidence for a weighing of one
-- pick while filed under another, and both screens would show it correctly.
create or replace function attachment_event_matches_subject()
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
    raise exception 'there is no event % for this photograph to be evidence of',
      new.about_event;
  end if;
  if e.subject_type <> new.subject_type or e.subject_id <> new.subject_id then
    raise exception
      'that photograph is filed under % % and names an event about % %, so one of the two is wrong',
      new.subject_type, new.subject_id, e.subject_type, e.subject_id;
  end if;
  return new;
end;
$$;

drop trigger if exists attachment_event_is_about_the_same_thing on attachment;
create trigger attachment_event_is_about_the_same_thing
  before insert or update on attachment
  for each row execute function attachment_event_matches_subject();

-- What may be changed after the fact. Row level security cannot say "these
-- columns only", so the refusal lives here: a caption is a label and can be
-- fixed, and everything else is what the photograph is.
create or replace function attachment_is_not_rewritten()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
begin
  if new.path <> old.path
     or new.subject_type <> old.subject_type
     or new.subject_id <> old.subject_id
     or new.about_event is distinct from old.about_event
     or new.by_user is distinct from old.by_user
     or new.at <> old.at then
    raise exception
      'a photograph can be captioned but not moved; attach a new one and have an administrator remove this';
  end if;
  return new;
end;
$$;

drop trigger if exists attachment_only_the_caption_changes on attachment;
create trigger attachment_only_the_caption_changes
  before update on attachment
  for each row execute function attachment_is_not_rewritten();

alter table attachment enable row level security;

-- Facility only for now, and that is a limitation rather than a decision: a
-- photograph of a client's own fruit is arguably theirs to see. S-65.
drop policy if exists attachment_read on attachment;
create policy attachment_read on attachment for select to authenticated
  using (is_facility_user());

-- Anybody who works here may attach one, as themselves. That is the whole point:
-- the person holding the phone is not always the person who recorded the thing,
-- and often not on the same day.
drop policy if exists attachment_insert on attachment;
create policy attachment_insert on attachment for insert to authenticated
  with check (is_facility_user() and by_user = auth.uid());

drop policy if exists attachment_caption on attachment;
create policy attachment_caption on attachment for update to authenticated
  using (is_facility_user() and by_user = auth.uid())
  with check (is_facility_user() and by_user = auth.uid());

-- Removing is an administrator's act. A photograph is evidence, and deleting one
-- should be a decision rather than a stray tap on a phone in a wet glove.
drop policy if exists attachment_admin_delete on attachment;
create policy attachment_admin_delete on attachment for delete to authenticated
  using (is_admin());

comment on table attachment is
  'A photograph of any subject the resolver knows, attached whenever somebody '
  'gets to it. `about_event` names the one thing it is evidence for, if it is '
  'evidence for one. `at` is when it was taken and `created_at` is when it '
  'arrived; they differ whenever a photograph waited for signal. See 0047.';

-- ---------------------------------------------------------------------------
-- Attaching one
-- ---------------------------------------------------------------------------

-- `by_user` is `auth.uid()` and is not a parameter, so nobody files a photograph
-- under somebody else's name. T0-3.
create or replace function attach_photo(
  p_subject_type text,
  p_subject_id   uuid,
  p_path         text,
  p_caption      text default null,
  p_about_event  uuid default null,
  p_taken_at     timestamptz default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare a attachment%rowtype;
begin
  -- Runs as the caller, so the insert policy is the thing that actually decides.
  -- This check exists to say why in words, because a bare policy violation and a
  -- succeeded insert are both silent and A13 says they must not read alike.
  if not is_facility_user() then
    raise exception 'photographs are attached by people who work here';
  end if;
  if p_path is null or btrim(p_path) = '' then
    raise exception 'there is no photograph here to attach';
  end if;
  if not exists (select 1 from subject_resolver where subject_type = p_subject_type) then
    raise exception 'nothing in this system is a %, so a photograph cannot be of one',
      p_subject_type;
  end if;

  insert into attachment
    (subject_type, subject_id, about_event, path, caption, by_user, at)
  values
    (p_subject_type, p_subject_id, p_about_event, btrim(p_path),
     nullif(btrim(coalesce(p_caption, '')), ''), auth.uid(),
     -- A photograph taken this morning and attached tonight is a photograph from
     -- this morning. Refusing a stated time would throw away the only fact the
     -- file itself might have carried.
     coalesce(p_taken_at, now()))
  on conflict (subject_type, subject_id, path) do nothing
  returning * into a;

  -- Attaching the same photograph twice is not a failure and must not read like
  -- one. A13: a refusal and a success have to look different, and so do a
  -- success and a no-op.
  if a.id is null then
    select * into a from attachment
     where subject_type = p_subject_type and subject_id = p_subject_id
       and path = btrim(p_path);
    return jsonb_build_object('id', a.id, 'already', true);
  end if;

  return jsonb_build_object('id', a.id, 'already', false);
end;
$$;

revoke all on function attach_photo(text, uuid, text, text, uuid, timestamptz) from public;
grant execute on function attach_photo(text, uuid, text, text, uuid, timestamptz) to authenticated;

-- A path given to `weigh_bins` becomes an attachment too, so the question has one
-- place to be asked. The path stays in the weighing's own data because that is
-- where it was written and removing it would rewrite history for no gain, but
-- nothing reads it to decide whether a photograph exists.
create or replace function attach_weighing_photo()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
begin
  if new.operation_id = term_id('operation', 'weigh')
     and new.subject_type = 'node'
     and coalesce(btrim(new.data ->> 'photo_path'), '') <> '' then
    insert into attachment
      (subject_type, subject_id, about_event, path, by_user, at)
    values
      ('node', new.subject_id, new.id, new.data ->> 'photo_path', new.by_user, new.at)
    on conflict (subject_type, subject_id, path) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists event_weighing_photo_is_an_attachment on event;
create trigger event_weighing_photo_is_an_attachment
  after insert on event
  for each row execute function attach_weighing_photo();

-- ---------------------------------------------------------------------------
-- What is photographed and what is not
-- ---------------------------------------------------------------------------

-- Asks the attachments, so a photograph attached in the evening counts exactly
-- as much as one taken at the scale.
--
-- Dropped rather than replaced: the column list is the same today, but a view
-- replaced in place refuses any later reordering, and this one has now been
-- rewritten twice.
drop view if exists weighing_without_photo;
create view weighing_without_photo with (security_invoker = true) as
select
  e.id         as event_id,
  e.subject_id as node_id,
  n.name       as pick_name,
  e.at,
  (e.data ->> 'net_lbs')::numeric as net_lbs
from event e
join node n on n.id = e.subject_id
where e.subject_type = 'node'
  and e.operation_id = term_id('operation', 'weigh')
  and not exists (
    select 1 from attachment a where a.about_event = e.id
  )
  and not exists (
    select 1 from event s
     where s.subject_type = 'node' and s.subject_id = e.subject_id
       and s.operation_id = term_id('operation', 'weigh')
       and (s.data ->> 'supersedes')::uuid = e.id
  );

comment on view weighing_without_photo is
  'Live weighings with no photograph naming them. Weaker evidence rather than '
  'unfinished work, which is why this is not counted anywhere that nags. A '
  'photograph attached to the pick without naming a reading does not clear one, '
  'because it is not evidence of that reading. See 0042 and 0047.';

commit;
