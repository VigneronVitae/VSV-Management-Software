-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Which way a room is held is derived from how far it sits from room
--           temperature, because that is the comparison a person makes, and the
--           told direction becomes an override rather than a chore."
-- Depends on: [supabase/migrations/0079_a_room_says_which_way_it_is_held.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (which way a room is held follows from its temperature
--                  and is not a second fact to maintain), R-4 (asking somebody
--                  for an answer the database can work out)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"I think a room is departure from room temperature not outside
-- temperature."*
--
-- **`0079` asked him to tell it, and that was the wrong call.** The reasoning
-- was that 15.5C is cooling in September and heating in January, which is true
-- of the *outside*, and the outside is not what a cellar is measured against. A
-- room is cold or warm relative to what a room is, and a barrel room at 15.5 is
-- being held below that in every month of the year.
--
-- So the direction is derived, and the column `0079` added becomes an override
-- for the case where the number is misleading: a room held at 19 that is
-- genuinely being heated up to that from a cold slab, say.
--
-- **Room temperature is measured rather than assumed where it can be.** The
-- uncontrolled rooms are what a room is here when nobody does anything to it,
-- so their average is the baseline. This winery has not given any of them a
-- temperature yet, so the fallback is 20C, which is room temperature in the
-- ordinary sense of the phrase, and it is one number in one place.
--
-- **Two degrees of slack, and it is the point of the whole thing.** A room
-- within two degrees of room temperature is held at room temperature, not
-- cooled: without that, a baseline of 20 would call a room at 19.5 a cold room
-- and the map would light up over nothing.

begin;

create or replace function room_temperature()
returns numeric
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
  -- What a room is here when nobody is doing anything to it. Falls back to 20,
  -- which is what the phrase means when nobody has measured.
  select coalesce(
    (select round(avg(ambient_c), 1) from location
      where not controlled and ambient_c is not null),
    20.0);
$$;

comment on function room_temperature() is
  'The baseline a controlled room is judged against: the average of the rooms '
  'nobody is holding at anything, or 20C when none of them says. See 0097.';

create or replace view room_climate with (security_invoker = true) as
select
  l.id,
  l.name,
  k.label       as kind,
  l.controlled,
  -- What somebody said, which is now an override rather than the answer.
  l.mode::text  as mode,
  l.ambient_c,
  (select count(*) from vessel v where v.location_id = l.id and v.active) as vessels,
  -- Appended, because `create or replace view` cannot put a column in the
  -- middle of one. 0092 hit the same wall from the other side and had to drop
  -- three views to rename a column; new columns going on the end is the version
  -- of that rule which costs nothing.
  room_temperature() as room_temp_c,
  -- Which way it is actually held. The told direction wins where there is one,
  -- because somebody standing in the room knows something the number does not.
  case
    when l.mode <> 'off' then l.mode::text
    when l.ambient_c is null then 'off'
    when l.ambient_c < room_temperature() - 2 then 'cooling'
    when l.ambient_c > room_temperature() + 2 then 'heating'
    else 'off'
  end           as held,
  -- So a screen can say why, which matters when the two disagree: a room told
  -- it is heating while sitting at 4 degrees is worth somebody looking at.
  (l.mode <> 'off') as direction_was_told
from location l
left join term k on k.id = l.kind_id;

comment on view room_climate is
  'Rooms, with which way each is held and at what. `held` is derived from how '
  'far the room sits from room temperature, which is the comparison a person '
  'makes; `mode` is what somebody said, and it wins where it was said. See '
  '0079 and 0097.';

-- Not a capability. It answers what a room is here, which arrives on every row
-- of room_climate already; a periphery asking it directly would be a screen
-- doing arithmetic the view has done.
insert into capability_exemption (fn, reason) values
  ('room_temperature', 'Answers what a room is here when nobody holds it at anything. Arrives on every room_climate row.')
on conflict (fn) do nothing;

-- The constraint 0079 added said a room held in a direction must be controlled.
-- That was about the told column and it still is: a room can now read as
-- cooling because it is cold without anybody having marked it controlled, which
-- is exactly the case this is for.

commit;
