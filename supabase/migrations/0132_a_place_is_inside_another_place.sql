-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A place can be inside another place, so that a thing has an address
--           somebody can walk to rather than the name of a room, and so that the
--           empty location_kind vocabulary finally says what a place is."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0057_the_contract.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  docs/review/2026-09-20-one-kernel-many-peripheries.md,
--                  supabase/migrations/0133_a_place_can_be_for_more_than_one_thing.sql,
--                  docs/review/2026-09-20-showing-somebody-where-a-thing-is.md,
--                  packages/inventory/src/inventory.ts]
-- Axioms enforced: T0-2. Depth and the full address are computed by walking the
--                  parents, never stored, because a stored path is wrong the
--                  moment a room is renamed and nothing would say so.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- "I also want location to be location within a room within a building."
--
-- Said while describing where the hammers and nails live, which is the woodshed
-- or halfway down the sheds, and which nothing in this system can currently
-- write down. There are five places and they are flat: Outside, Steve South
-- Room, Steve's NW Room, Winery Large Room, Winery Small Room. The building is
-- in the name of the room, as a string, because there was nowhere else to put
-- it.
--
-- **`location` is already core's**, which is worth saying because it looks like
-- the cellar's: `cellar.rooms` reads it and `set_room_climate` writes to it. But
-- `subject_resolver` and `term_kind` both file it under core, correctly, since a
-- place is not winemaking. The same argument AR-E6 made for scheduling.
--
-- **It is also currently two things at once.** A location carries `controlled`,
-- `ambient_c` and a `thermal_mode`, because until now every location was a room
-- somebody might want to chill. A shelf is not, and this does not give a shelf a
-- meaningless temperature: `room_mode_needs_control` already says an uncontrolled
-- place must have its mode off, and off is the default, so a building and a
-- shelf are simply locations nobody is heating.

alter table location
  add column if not exists parent_id uuid references location(id);

comment on column location.parent_id is
  'The place this place is inside. Null means it is the outermost thing: a '
  'building, or the outdoors.';

-- The cheap half of the guard, which holds even if the trigger is ever dropped.
alter table location drop constraint if exists location_is_not_inside_itself;
alter table location add constraint location_is_not_inside_itself
  check (parent_id is null or parent_id <> id);

-- The half a check constraint cannot do. A cycle of length two or more is not
-- expressible without walking, and a cycle here would hang the recursive view
-- rather than return a wrong answer, which is a worse failure than usual.
create or replace function location_stays_a_tree()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  up   uuid;
  hops int := 0;
begin
  up := new.parent_id;
  while up is not null loop
    hops := hops + 1;
    if up = new.id then
      raise exception
        'that would put % inside something that is already inside it', new.name;
    end if;
    -- A depth no real building reaches, and the thing that stops this looping
    -- forever if a cycle somehow already exists in the table.
    if hops > 20 then
      raise exception 'places are nested more than twenty deep, which is a mistake';
    end if;
    select parent_id into up from location where id = up;
  end loop;
  return new;
end $$;

drop trigger if exists location_stays_a_tree on location;
create trigger location_stays_a_tree
  before insert or update of parent_id on location
  for each row execute function location_stays_a_tree();

-- ---------------------------------------------------------------------------
-- What a place is
-- ---------------------------------------------------------------------------

-- `location_kind` was registered by 0027 and has been empty ever since, so every
-- location in this database is of no kind at all. Three rows, and the test for
-- each is AR-J4's: would another winery installing this have it? A building,
-- yes. A room, yes. A spot inside a room where things sit, yes, whatever that
-- operation calls it. What this winery calls a particular one, Bay 3 or the
-- woodshed or halfway down the sheds, is the location's name and is its own
-- business.
insert into term (kind, value, label, sort_order) values
  ('location_kind', 'building', 'Building', 100),
  ('location_kind', 'room',     'Room',     200),
  ('location_kind', 'storage',  'Storage',  300)
on conflict (kind, value) do update set
  label = excluded.label, sort_order = excluded.sort_order, active = true;

-- ---------------------------------------------------------------------------
-- The address, walked rather than stored
-- ---------------------------------------------------------------------------

-- T0-2, and compost entry C-3 is the one to read if this ever looks like it
-- should be a column. A stored path is wrong the moment somebody renames a room
-- and nothing in the system would know.
create or replace view location_tree with (security_invoker = true) as
with recursive walk as (
  select l.id, l.name, l.parent_id, l.kind_id, l.controlled,
         1 as depth,
         l.name::text as address
    from location l
   where l.parent_id is null
  union all
  select c.id, c.name, c.parent_id, c.kind_id, c.controlled,
         w.depth + 1,
         (w.address || ' > ' || c.name)::text
    from location c
    join walk w on w.id = c.parent_id
)
select
  w.id,
  w.name,
  w.parent_id,
  w.depth,
  -- "Winery Large Room > Bay 3 > top shelf", which is what you tell somebody
  -- who is looking for the shears.
  w.address,
  w.controlled,
  t.value as kind,
  t.label as kind_label
from walk w
left join term t on t.id = w.kind_id;

comment on view location_tree is
  'Every place with its full address, walked up through its parents. The address '
  'is computed and never stored, so renaming a room fixes every address under it.';

-- ---------------------------------------------------------------------------
-- The contract
-- ---------------------------------------------------------------------------

-- Nothing in the contract could create a place. Rooms got into this database
-- before the contract existed and no periphery has been able to add one since,
-- which is why a person with a new shed has had nowhere to put it.
create or replace function add_place(
  p_name      text,
  p_kind      text default null,
  p_parent_id uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  made location%rowtype;
  k    uuid;
begin
  if not is_facility_user() then
    raise exception 'places are added by people who work here';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'a place needs a name somebody could say out loud';
  end if;

  if p_kind is not null then
    select t.id into k from term t
     where t.kind = 'location_kind' and t.value = p_kind and t.active;
    if k is null then
      raise exception 'there is no kind of place called %', p_kind;
    end if;
  end if;

  if p_parent_id is not null
     and not exists (select 1 from location where id = p_parent_id) then
    raise exception 'there is no place to put that inside';
  end if;

  insert into location (name, kind_id, parent_id)
  values (btrim(p_name), k, p_parent_id)
  returning * into made;

  return jsonb_build_object('id', made.id, 'name', made.name);
end $$;

create or replace function move_place(
  p_location_id uuid,
  p_parent_id   uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare moved location%rowtype;
begin
  if not is_facility_user() then
    raise exception 'places are moved by people who work here';
  end if;
  if not exists (select 1 from location where id = p_location_id) then
    raise exception 'there is no such place to move';
  end if;
  if p_parent_id is not null
     and not exists (select 1 from location where id = p_parent_id) then
    raise exception 'there is no place to put that inside';
  end if;

  -- The cycle guard is the trigger's, not this function's, so that it holds for
  -- a migration and a console session too.
  update location set parent_id = p_parent_id
   where id = p_location_id
  returning * into moved;

  return jsonb_build_object('id', moved.id, 'name', moved.name);
end $$;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('core.add_place', 'core', 'Add a place',
   'Adds a building, a room, or a spot inside one. A place with no parent is the outermost thing.',
   'add_place',
   '[{"key": "name", "type": "text", "label": "What it is called", "param": "p_name", "required": true},
     {"key": "kind", "type": "text", "label": "What kind of place", "param": "p_kind", "required": false,
      "source": {"terms": "location_kind"}},
     {"key": "parent", "type": "uuid", "label": "Inside which place", "param": "p_parent_id", "required": false,
      "source": {"readable": "core.places"}}]'::jsonb,
   30),
  ('core.move_place', 'core', 'Put a place inside another',
   'Moves a place, and everything inside it, under a different one. Leaving the parent blank makes it outermost.',
   'move_place',
   '[{"key": "location", "type": "uuid", "label": "Which place", "param": "p_location_id", "required": true,
      "source": {"readable": "core.places"}},
     {"key": "parent", "type": "uuid", "label": "Inside which place", "param": "p_parent_id", "required": false,
      "source": {"readable": "core.places"}}]'::jsonb,
   31)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('core.places', 'core', 'Places',
   'Every place with its full address, so a thing can be somewhere a person could walk to.',
   'location_tree', 'id', 'address', 32)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

do $$
declare
  a uuid;
  b uuid;
begin
  if not exists (select 1 from term where kind = 'location_kind' and active) then
    raise exception 'the location_kind vocabulary is still empty, so no place can say what it is';
  end if;

  -- The guard that matters, asserted rather than trusted. A cycle here would
  -- hang location_tree rather than return a wrong row.
  insert into location (name, controlled) values ('CYCLE TEST OUTER 0132', false) returning id into a;
  insert into location (name, controlled, parent_id) values ('CYCLE TEST INNER 0132', false, a) returning id into b;
  begin
    update location set parent_id = b where id = a;
    raise exception 'a place was put inside something that is already inside it';
  exception when others then
    if sqlerrm not like '%already inside it%' then raise; end if;
  end;
  delete from location where id in (a, b);
end $$;
