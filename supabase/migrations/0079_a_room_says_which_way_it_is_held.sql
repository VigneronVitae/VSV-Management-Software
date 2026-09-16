-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A controlled room says whether it is held cold or held warm, which
--           is a fact nothing in the schema could previously express and no
--           temperature can be read off."
-- Depends on: [supabase/migrations/0006_vessel_thermal.sql,
--              supabase/migrations/0057_the_contract.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0097_a_room_departs_from_room_temperature.sql]
-- Axioms enforced: T0-4 (the direction is told by somebody who knows, never
--                  inferred from a number), AR-E5 (the vocabulary already
--                  exists: a room is held the same three ways a vessel is)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker wants the map to show thermal state: vessels held cold drawn
-- light with a temperature beside them, rooms under cold control drawn light
-- behind the vessels standing in them, and the inverse for heat.
--
-- **The vessel half needed nothing.** `vessel.mode` has been cooling, heating or
-- off since `0006`, with a setpoint beside it. The map can draw that today.
--
-- **The room half could not be answered at all.** `location` carries
-- `controlled` and `ambient_c`, which say that a room is held somewhere and at
-- what, and nothing about which direction it is held in. **The number cannot
-- settle it.** This winery's one controlled room sits at 15.5C, which is cooling
-- in September and heating in January, and a threshold that called it cold would
-- be a guess wearing a decimal point. So the room says it, the same three ways a
-- vessel does, out of the enum that already exists.
--
-- Nothing is backfilled. Every existing room is `off` until somebody says
-- otherwise, and a room that is controlled with no direction draws its
-- temperature and no colour, which is the honest picture of what is known.

begin;

alter table location add column if not exists mode thermal_mode not null default 'off';

comment on column location.mode is
  'Which way a controlled room is held. Not derivable from ambient_c: the same '
  '15C is cooling in September and heating in January. See 0079.';

-- A room held in a direction is a room under control. The two were always one
-- fact and are now two columns, so the constraint is what keeps them one.
do $$ begin
  alter table location add constraint room_mode_needs_control
    check (mode = 'off' or controlled);
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- Saying it
-- ---------------------------------------------------------------------------

-- One function rather than an update from a client, because setting a direction
-- and setting `controlled` are the same act and a client doing both would be a
-- client holding the rule. A room told it is cooling is controlled by saying so.
create or replace function set_room_climate(
  p_location_id uuid,
  p_mode        text,
  p_ambient_c   numeric default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  l    location%rowtype;
  want thermal_mode;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here sets a room''s climate'
      using errcode = 'insufficient_privilege';
  end if;

  select * into l from location where id = p_location_id;
  if l.id is null then
    raise exception 'no room with id %', p_location_id;
  end if;

  begin
    want := lower(btrim(coalesce(p_mode, 'off')))::thermal_mode;
  exception when invalid_text_representation then
    raise exception
      'a room is held cooling, heating, or off. % is none of those', p_mode;
  end;

  update location
     set mode = want,
         -- Saying which way it is held says it is held. The alternative is a
         -- refusal that tells somebody to go and tick a box first, which is a
         -- refusal about bookkeeping rather than about the winery.
         controlled = (want <> 'off') or l.controlled,
         ambient_c = coalesce(p_ambient_c, l.ambient_c)
   where id = p_location_id;

  return jsonb_build_object('id', p_location_id, 'mode', want,
                            'ambient_c', coalesce(p_ambient_c, l.ambient_c));
end;
$$;

revoke all on function set_room_climate(uuid, text, numeric) from public;
grant execute on function set_room_climate(uuid, text, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- What the map reads
-- ---------------------------------------------------------------------------

-- The rooms, with what they are doing and how many vessels are standing in
-- them. A map needs the room before it needs anything in it.
create or replace view room_climate with (security_invoker = true) as
select
  l.id,
  l.name,
  k.label       as kind,
  l.controlled,
  l.mode::text  as mode,
  l.ambient_c,
  (select count(*) from vessel v where v.location_id = l.id and v.active) as vessels
from location l
left join term k on k.id = l.kind_id;

comment on view room_climate is
  'Rooms, with which way each is held and at what. The map draws the negative '
  'space behind the vessels from this. See 0079.';

grant select on room_climate to authenticated;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.rooms', 'cellar', 'Rooms',
   'Where vessels live, which way each room is held, and at what temperature.',
   'room_climate', 'id', 'name', 150)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('cellar.set_room_climate', 'cellar', 'Say how a room is held',
   'Cooling, heating, or neither, and at what temperature. Saying a direction '
   'says the room is controlled.',
   'set_room_climate', 'cellar.rooms',
   '[{"key":"room","param":"p_location_id","type":"uuid","required":true,
      "label":"Which room",
      "source":{"readable":"cellar.rooms"}},
     {"key":"mode","param":"p_mode","type":"text","required":true,
      "label":"How it is held",
      "note":"cooling, heating, or off."},
     {"key":"ambient","param":"p_ambient_c","type":"numeric","required":false,
      "label":"At what temperature, C"}]'::jsonb, 230)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

commit;
