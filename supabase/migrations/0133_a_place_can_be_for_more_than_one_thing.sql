-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A place can be tagged with what it is used for, several at once, and
--           a place inside a tagged place inherits the tag, so that a tools
--           periphery and a cellar periphery can each ask for the rooms that
--           concern them without either of them holding the list."
-- Depends on: [supabase/migrations/0046_supply_inventory.sql,
--              supabase/migrations/0132_a_place_is_inside_another_place.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  supabase/migrations/0134_a_domain_tags_a_place_and_a_thing.sql]
-- Axioms enforced: T0-2. An effective tag is own tags union every ancestor's,
--                  computed by walking, never written down, for the same reason
--                  the address is walked: moving a room under a different
--                  building would silently falsify a stored copy.
--                  AR-E5. The tags are rows in a vocabulary rather than an enum
--                  or a set of boolean columns.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- "Locations should be tagged if we have shared locations. Like the big winery
-- room might have winery tag and tools tag, but Steve's rooms and the small
-- winery room will mostly just have the winery tag, whereas the woodshed and
-- some other rooms would only have the tools tag."
--
-- **A tag is a different axis from a kind and both are needed.** `0132` gave a
-- place a kind: what it *is*, a building or a room or a spot inside one, exactly
-- one of them. This is what it is *for*, and a place can be for several things
-- at once, which is the whole point of the sentence above: the big winery room
-- is both.
--
-- The shape is `supply_material_kind`'s, from `0046`, which exists for the same
-- reason in a different place: "a join table so a hose head can be two things at
-- once". Same composite pin into `term(id, kind)` so a tag cannot be borrowed
-- from some other vocabulary, same cascade from the owner.
--
-- **Inheritance is downward and additive.** Tagging the woodshed as tools means
-- every bay and shelf inside it is a tools place without anybody saying so
-- again, which is the difference between tagging five things and tagging fifty.
-- Additive rather than overriding, because a tools bench inside a winery
-- building is both and neither answer should erase the other.

create table if not exists location_tag (
  location_id uuid not null references location(id) on delete cascade,
  tag_id      uuid not null,
  -- Generated so nobody can hand-set it, which is how the composite pin below
  -- stays a pin rather than a suggestion. AR-E5, and the same shape every other
  -- pointer into term has had since 0027.
  tag_kind    text generated always as ('location_tag'::text) stored,
  at          timestamptz not null default now(),
  by_user     uuid references app_user(id),
  primary key (location_id, tag_id),
  constraint location_tag_is_a_location_tag
    foreign key (tag_id, tag_kind) references term(id, kind)
);

comment on table location_tag is
  'What a place is used for. Several per place, and inherited downward by '
  'everything inside it.';

alter table location_tag enable row level security;

drop policy if exists location_tag_read on location_tag;
create policy location_tag_read on location_tag
  for select using (is_facility_user());

drop policy if exists location_tag_write on location_tag;
create policy location_tag_write on location_tag
  for all using (is_facility_user()) with check (is_facility_user());

-- ---------------------------------------------------------------------------
-- The vocabulary
-- ---------------------------------------------------------------------------

insert into term_kind (kind, label, module, sort_order) values
  ('location_tag', 'Place tag', 'core', 120)
on conflict (kind) do update set
  label = excluded.label, module = excluded.module, sort_order = excluded.sort_order;

-- Three, and the AR-J4 test for each is whether another winery installing this
-- system would have it. Somewhere wine is made, somewhere tools live, and the
-- ground the fruit comes off: yes to all three, and they are the tags that make
-- the vocabulary usable on a fresh install rather than empty the way
-- `location_kind` sat empty from 0027 until 0132.
--
-- What does not ship is which of this winery's rooms carries which, because that
-- is the shape of this operation and not of the system. Those are rows in
-- `location_tag`, written through the capability below.
insert into term (kind, value, label, sort_order) values
  ('location_tag', 'winery',   'Winery',   100),
  ('location_tag', 'tools',    'Tools',    200),
  ('location_tag', 'vineyard', 'Vineyard', 300)
on conflict (kind, value) do update set
  label = excluded.label, sort_order = excluded.sort_order, active = true;

-- ---------------------------------------------------------------------------
-- Every tag that reaches a place, its own and its ancestors'
-- ---------------------------------------------------------------------------

-- T0-2. Walked rather than stored, on the same argument the address is: moving a
-- room under a different building would falsify a written-down copy and nothing
-- in the system would know it had.
create or replace view location_tag_effective with (security_invoker = true) as
with recursive up as (
  -- Every place is its own ancestor, which is what makes a place's own tags
  -- count without a second branch.
  select l.id as location_id, l.id as ancestor_id
    from location l
  union all
  select u.location_id, p.parent_id
    from up u
    join location p on p.id = u.ancestor_id
   where p.parent_id is not null
)
select distinct
  u.location_id,
  t.value as tag,
  t.label as tag_label,
  u.location_id <> lt.location_id as inherited
from up u
join location_tag lt on lt.location_id = u.ancestor_id
join term t on t.id = lt.tag_id
where t.active;

comment on view location_tag_effective is
  'Every tag that reaches a place: its own, and every tag on anything it is '
  'inside. `inherited` says which.';

-- `location_tree` gains the tags, so one read answers where a place is and what
-- it is for. Replaced rather than altered because the column list grows.
drop view if exists location_tree;

create view location_tree with (security_invoker = true) as
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
  t.label as kind_label,
  coalesce(
    (select array_agg(e.tag order by e.tag)
       from location_tag_effective e where e.location_id = w.id),
    '{}'::text[]) as tags
from walk w
left join term t on t.id = w.kind_id;

comment on view location_tree is
  'Every place with its full address and every tag that reaches it, both walked '
  'and neither stored, so renaming or moving a place fixes everything under it.';

-- ---------------------------------------------------------------------------
-- The contract
-- ---------------------------------------------------------------------------

create or replace function tag_place(p_location_id uuid, p_tag text)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare tg uuid;
begin
  if not is_facility_user() then
    raise exception 'places are tagged by people who work here';
  end if;
  if not exists (select 1 from location where id = p_location_id) then
    raise exception 'there is no such place to tag';
  end if;
  select t.id into tg from term t
   where t.kind = 'location_tag' and t.value = p_tag and t.active;
  if tg is null then
    raise exception 'there is no place tag called %', p_tag;
  end if;

  insert into location_tag (location_id, tag_id, by_user)
  values (p_location_id, tg, auth.uid())
  on conflict (location_id, tag_id) do nothing;

  return jsonb_build_object('location', p_location_id, 'tag', p_tag);
end $$;

create or replace function untag_place(p_location_id uuid, p_tag text)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare tg uuid; gone int;
begin
  if not is_facility_user() then
    raise exception 'places are tagged by people who work here';
  end if;
  select t.id into tg from term t
   where t.kind = 'location_tag' and t.value = p_tag;
  if tg is null then
    raise exception 'there is no place tag called %', p_tag;
  end if;

  delete from location_tag
   where location_id = p_location_id and tag_id = tg;
  get diagnostics gone = row_count;

  -- A13. Removing a tag a place never carried, and removing one it did, must not
  -- look the same to the person who asked. An inherited tag is the case this
  -- catches: it cannot be removed here and saying nothing would read as success.
  if gone = 0 then
    if exists (select 1 from location_tag_effective
                where location_id = p_location_id and tag = p_tag and inherited) then
      raise exception
        'that place gets % from something it is inside, so it has to come off there', p_tag;
    end if;
    raise exception 'that place was not tagged %', p_tag;
  end if;

  return jsonb_build_object('location', p_location_id, 'tag', p_tag);
end $$;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('core.tag_place', 'core', 'Say what a place is used for',
   'Tags a place. A place may carry several tags, and everything inside it inherits them.',
   'tag_place',
   '[{"key": "location", "type": "uuid", "label": "Which place", "param": "p_location_id", "required": true,
      "source": {"readable": "core.places"}},
     {"key": "tag", "type": "text", "label": "Used for", "param": "p_tag", "required": true,
      "source": {"terms": "location_tag"}}]'::jsonb,
   33),
  ('core.untag_place', 'core', 'Take a tag off a place',
   'Removes a tag a place carries in its own right. A tag it inherits from something it is inside has to come off there.',
   'untag_place',
   '[{"key": "location", "type": "uuid", "label": "Which place", "param": "p_location_id", "required": true,
      "source": {"readable": "core.places"}},
     {"key": "tag", "type": "text", "label": "Stop using it for", "param": "p_tag", "required": true,
      "source": {"terms": "location_tag"}}]'::jsonb,
   34)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('core.place_tags', 'core', 'What places are used for',
   'Every tag that reaches every place, its own and the ones it inherits from whatever it is inside.',
   'location_tag_effective', 'location_id', 'tag_label', 35)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

do $$
declare
  shed uuid;
  bay  uuid;
begin
  if not exists (select 1 from term where kind = 'location_tag' and active) then
    raise exception 'the place tag vocabulary is empty, so no place can say what it is for';
  end if;

  -- Inheritance, asserted rather than trusted, because it is the property that
  -- makes tagging five places do the work of tagging fifty.
  insert into location (name, controlled) values ('TAG TEST SHED 0133', false) returning id into shed;
  insert into location (name, controlled, parent_id) values ('TAG TEST BAY 0133', false, shed) returning id into bay;
  insert into location_tag (location_id, tag_id)
    select shed, id from term where kind = 'location_tag' and value = 'tools';

  if not exists (select 1 from location_tag_effective
                  where location_id = bay and tag = 'tools' and inherited) then
    raise exception 'a place inside a tagged place did not inherit the tag';
  end if;
  if exists (select 1 from location_tag_effective
              where location_id = shed and tag = 'tools' and inherited) then
    raise exception 'a place reported its own tag as inherited';
  end if;

  delete from location where id in (bay, shed);
end $$;
