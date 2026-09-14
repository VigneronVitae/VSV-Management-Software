-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A day, as the cellar actually spent it: what the record already
--           knows, and the things it has no column for and never will."
-- Depends on: [supabase/migrations/0028_redaction_is_row_level.sql,
--              supabase/migrations/0040_block_variety_is_history.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0042_weighing_photo.sql]
-- Axioms enforced: T0-2 (the day's activity is derived by asking, never
--                  written down twice), T0-3 (an inferred event still says so
--                  in the log)
-- Open sorries: S-57 (the winery's timezone is a constant in a function)
-- ---------------------------------------------------------------------------
--
-- Asked for during the first pick, and the winemaker split it himself: "both,
-- on one screen", and "a public note board and private notes".
--
-- **The spine is derived.** What happened today is already in the record:
-- weighings, presses, racks, and the lots that came into existence. Writing a
-- second copy of that into a log table would be a copy that can disagree with
-- its source, which is T0-2, and it would go stale the first time somebody
-- corrected a weighing. So `day_log` asks.
--
-- **The notes are not derived and could not be.** Weather, who turned up, how
-- the fruit looked, what went wrong and what somebody decided to do about it.
-- There is no column for any of that and there should not be: the point of a
-- note is that it is the thing the schema did not anticipate.
--
-- **Two visibilities, because he asked for two.** A note on the board is for
-- everybody who works here and is hidden from custom crush clients, who sign in
-- to see their own wine and have no business reading the winery's day. A private
-- note is for its author alone. Both are enforced by row level security rather
-- than by a screen deciding what to draw, because a screen that decides is a
-- screen somebody can go around.

begin;

-- ---------------------------------------------------------------------------
-- The notes
-- ---------------------------------------------------------------------------

create table if not exists day_note (
  id         uuid primary key default gen_random_uuid(),
  -- The day it is about, which is not always the day it was typed: a note
  -- written at midnight about the afternoon belongs to the afternoon.
  on_date    date not null default current_date,
  body       text not null,
  private    boolean not null default false,
  author_id  uuid references app_user (id),
  created_at timestamptz not null default now(),
  constraint day_note_says_something check (btrim(body) <> '')
);

create index if not exists day_note_on_date_idx on day_note (on_date desc);

alter table day_note enable row level security;

-- The board: everybody who works here, and nobody who does not. A client party
-- is excluded by `is_facility_user`, which is the same predicate that decides
-- whether somebody sees the cellar at all.
drop policy if exists day_note_read on day_note;
create policy day_note_read on day_note for select to authenticated
  using (
    (not private and is_facility_user())
    or author_id = auth.uid()
  );

-- Anybody who works here may write on the board. A note is not a trust field
-- and not a measurement: it is somebody saying something, and the author is
-- recorded so it is clear who.
drop policy if exists day_note_insert on day_note;
create policy day_note_insert on day_note for insert to authenticated
  with check (is_facility_user() and author_id = auth.uid());

-- Yours to change, and nobody else's. Not append only, because this is the one
-- surface in the app that is somebody's own words rather than a record of what
-- happened, and correcting a sentence you wrote is not falsifying a measurement.
drop policy if exists day_note_own_update on day_note;
create policy day_note_own_update on day_note for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());

drop policy if exists day_note_own_delete on day_note;
create policy day_note_own_delete on day_note for delete to authenticated
  using (author_id = auth.uid());

comment on table day_note is
  'What somebody wrote about a day. Not derived and not derivable: the point of '
  'a note is that it is what the schema did not anticipate. Private notes are '
  'their author''s alone; the rest are the facility''s board and are hidden from '
  'clients. See 0041.';

-- ---------------------------------------------------------------------------
-- The day itself
-- ---------------------------------------------------------------------------

-- Derived on every call. Runs as the caller, so a client asking for a day sees
-- their own wine's events and nothing else, which is `0028` doing its job one
-- screen further out.
--
-- **The timezone is the interesting part.** `at` is stored with a zone and the
-- database thinks in UTC, so an event at five in the afternoon in Oregon belongs
-- to tomorrow if you ask naively. A daily log that puts the afternoon's pressing
-- on the wrong day is worse than no daily log. The zone is a constant here and
-- that is S-57.
create or replace function day_log(
  p_on   date default null,
  p_zone text default 'America/Los_Angeles'
)
returns table (
  at         timestamptz,
  kind       text,
  headline   text,
  subject    text,
  detail     jsonb,
  provenance provenance
)
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
  with day as (
    select coalesce(p_on, (now() at time zone p_zone)::date) as d
  )
  select
    e.at,
    'event'::text,
    coalesce(t.label, 'Something'),
    coalesce(resolve_subject_name(e.subject_type, e.subject_id), e.subject_type),
    e.data,
    e.provenance
  from event e
  cross join day
  left join term t on t.id = e.operation_id and t.kind = 'operation'
  where (e.at at time zone p_zone)::date = day.d

  union all

  -- A lot coming into existence is not an event and would otherwise be absent
  -- from its own first day. A pick started in a vineyard is exactly this.
  select
    n.created_at,
    'lot'::text,
    case when n.stage = 'bin' then 'Pick started' else 'Lot created' end,
    n.name,
    jsonb_strip_nulls(jsonb_build_object(
      'stage', n.stage, 'quantity', n.quantity, 'unit', n.unit)),
    n.provenance
  from node n
  cross join day
  where (n.created_at at time zone p_zone)::date = day.d

  order by 1;
$$;

comment on function day_log is
  'What happened on a day, asked rather than stored. Runs as the caller, so two '
  'people get two different days and both are correct. See 0041 and sorry S-57.';

commit;
