-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "One vocabulary of domains tags both a place and a thing, a supply
--           gets a home, and an inventory for a domain is everything tagged for
--           it together with everything sitting in a place tagged for it, each
--           row saying which of the two it is."
-- Depends on: [supabase/migrations/0046_supply_inventory.sql,
--              supabase/migrations/0133_a_place_can_be_for_more_than_one_thing.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  docs/review/2026-09-20-showing-somebody-where-a-thing-is.md,
--                  supabase/migrations/0135_a_photograph_can_point_at_something.sql,
--                  packages/inventory/src/inventory.ts]
-- Axioms enforced: T0-2. An inventory for a domain is computed from tags and
--                  homes and never written down, because the same tin of screws
--                  belongs to two inventories at once and a stored answer would
--                  have to pick one.
--                  A13. A row that is in a list because somebody assigned it and
--                  a row that is in it because it happens to be in the room are
--                  different facts, and a list that cannot tell them apart would
--                  put hammers on the winery's reorder report.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- "Cellar/winery inventory should be a subset of total inventory." Then, asked
-- whether places and things should share one vocabulary: "I'm not quite sure.
-- Maybe winery carries winery tagged tools plus tools in winery tagged
-- locations?"
--
-- **That second sentence settles the first question by implication.** A union of
-- "tagged winery" and "in a place tagged winery" only type-checks if both sides
-- draw the word from the same list. So the vocabulary is shared, and `0133`
-- named it `location_tag` an hour too early. Renamed here rather than later,
-- because the table has no rows in it yet and the cost never goes down.
--
-- `domain` rather than `area` or `purpose`, because `part_domain` has meant
-- exactly this since `0112`: which discipline a thing belongs to. A part is
-- mechanical or hydraulic; a place or a supply is winery or tools or vineyard.
--
-- **The union is the useful answer and the reason each row says why it is
-- there.** Looking for a hammer in the winery, you want to know there is one in
-- the room even though it is not winery stock. Reordering winery supplies, you
-- very much do not want that hammer on the list. One relation answers both, and
-- `because` is the column that keeps them apart, the same way `inherited` does
-- on `location_domain_effective`.

-- ---------------------------------------------------------------------------
-- The vocabulary, renamed
-- ---------------------------------------------------------------------------

insert into term_kind (kind, label, module, sort_order) values
  ('domain', 'Domain', 'core', 120)
on conflict (kind) do update set
  label = excluded.label, module = excluded.module, sort_order = excluded.sort_order;

-- The composite pin means the generated column has to go before the terms can
-- move, and come back after. Safe only because the table is empty, which it is.
alter table location_tag drop constraint if exists location_tag_is_a_location_tag;
alter table location_tag drop column if exists tag_kind;

update term set kind = 'domain' where kind = 'location_tag';
delete from term_kind where kind = 'location_tag';

alter table location_tag rename column tag_id to domain_id;
alter table location_tag rename to location_domain;

alter table location_domain
  add column domain_kind text generated always as ('domain'::text) stored;

alter table location_domain
  add constraint location_domain_is_a_domain
  foreign key (domain_id, domain_kind) references term(id, kind);

comment on table location_domain is
  'Which domains a place belongs to. Several per place, and inherited downward '
  'by everything inside it.';

-- Everything downstream of the rename, carried through. These are the same
-- definitions 0133 wrote with the word changed, except that the views are
-- dropped and recreated rather than replaced because their column names move
-- too, and `create or replace view` cannot rename a column.
drop view if exists location_tree;
drop view if exists location_tag_effective;

create view location_domain_effective with (security_invoker = true) as
with recursive up as (
  -- Every place is its own ancestor, which is what makes a place's own domains
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
  t.value as domain,
  t.label as domain_label,
  u.location_id <> ld.location_id as inherited
from up u
join location_domain ld on ld.location_id = u.ancestor_id
join term t on t.id = ld.domain_id
where t.active;

comment on view location_domain_effective is
  'Every domain that reaches a place: its own, and every domain on anything it '
  'is inside. `inherited` says which.';

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
    (select array_agg(e.domain order by e.domain)
       from location_domain_effective e where e.location_id = w.id),
    '{}'::text[]) as domains
from walk w
left join term t on t.id = w.kind_id;

comment on view location_tree is
  'Every place with its full address and every domain that reaches it, both '
  'walked and neither stored, so renaming or moving a place fixes everything '
  'under it.';

-- Dropped by signature first. `create or replace function` will not rename an
-- input parameter even when the signature is otherwise identical, and `p_tag`
-- becomes `p_domain` here. Same family of lesson as 0131's: replace does less
-- than it sounds like it does.
drop function if exists tag_place(uuid, text);
drop function if exists untag_place(uuid, text);

create or replace function tag_place(p_location_id uuid, p_domain text)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare d uuid;
begin
  if not is_facility_user() then
    raise exception 'places are tagged by people who work here';
  end if;
  if not exists (select 1 from location where id = p_location_id) then
    raise exception 'there is no such place to tag';
  end if;
  select t.id into d from term t
   where t.kind = 'domain' and t.value = p_domain and t.active;
  if d is null then
    raise exception 'there is no domain called %', p_domain;
  end if;

  insert into location_domain (location_id, domain_id, by_user)
  values (p_location_id, d, auth.uid())
  on conflict (location_id, domain_id) do nothing;

  return jsonb_build_object('location', p_location_id, 'domain', p_domain);
end $$;

create or replace function untag_place(p_location_id uuid, p_domain text)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare d uuid; gone int;
begin
  if not is_facility_user() then
    raise exception 'places are tagged by people who work here';
  end if;
  select t.id into d from term t where t.kind = 'domain' and t.value = p_domain;
  if d is null then
    raise exception 'there is no domain called %', p_domain;
  end if;

  delete from location_domain
   where location_id = p_location_id and domain_id = d;
  get diagnostics gone = row_count;

  -- A13. Removing a domain a place never carried, and removing one it did, must
  -- not look the same. An inherited one is the case this catches: it cannot be
  -- removed here and saying nothing would read as success.
  if gone = 0 then
    if exists (select 1 from location_domain_effective
                where location_id = p_location_id and domain = p_domain and inherited) then
      raise exception
        'that place gets % from something it is inside, so it has to come off there', p_domain;
    end if;
    raise exception 'that place was not tagged %', p_domain;
  end if;

  return jsonb_build_object('location', p_location_id, 'domain', p_domain);
end $$;

-- The two place capabilities and the readable, restated because their parameter
-- names and their relation moved.
update capability
   set fields = '[{"key": "location", "type": "uuid", "label": "Which place", "param": "p_location_id", "required": true,
                   "source": {"readable": "core.places"}},
                  {"key": "domain", "type": "text", "label": "Belongs to", "param": "p_domain", "required": true,
                   "source": {"terms": "domain"}}]'::jsonb
 where key = 'core.tag_place';

update capability
   set fields = '[{"key": "location", "type": "uuid", "label": "Which place", "param": "p_location_id", "required": true,
                   "source": {"readable": "core.places"}},
                  {"key": "domain", "type": "text", "label": "Stop belonging to", "param": "p_domain", "required": true,
                   "source": {"terms": "domain"}}]'::jsonb
 where key = 'core.untag_place';

update readable
   set key = 'core.place_domains',
       label = 'What domains places belong to',
       note = 'Every domain that reaches every place, its own and the ones it inherits from whatever it is inside.',
       relation = 'location_domain_effective',
       label_column = 'domain_label'
 where key = 'core.place_tags';

-- ---------------------------------------------------------------------------
-- A thing belongs to domains too, and has somewhere it lives
-- ---------------------------------------------------------------------------

create table if not exists supply_domain (
  supply_id   uuid not null references supply(id) on delete cascade,
  domain_id   uuid not null,
  domain_kind text generated always as ('domain'::text) stored,
  at          timestamptz not null default now(),
  by_user     uuid references app_user(id),
  primary key (supply_id, domain_id),
  constraint supply_domain_is_a_domain
    foreign key (domain_id, domain_kind) references term(id, kind)
);

comment on table supply_domain is
  'Which domains a thing belongs to. Several, because a box of gloves is the '
  'winery''s and the woodshed''s at the same time and there is one box.';

alter table supply_domain enable row level security;

drop policy if exists supply_domain_read on supply_domain;
create policy supply_domain_read on supply_domain
  for select using (is_facility_user());

drop policy if exists supply_domain_write on supply_domain;
create policy supply_domain_write on supply_domain
  for all using (is_facility_user()) with check (is_facility_user());

-- Where a thing lives, which is not where it is.
--
-- A column rather than a history on purpose, and the distinction is the one that
-- makes the tool question answerable at all: a home is a stable fact about a
-- thing, "the shears belong on the hook in the woodshed", and it is what you
-- tell somebody who is looking. Where it is *right now*, because Matthew took it
-- to the vineyard, is a different fact with a different shape, and it is a
-- history for the reason `0115` gave about vine plantings and `placement` gives
-- about wine: a column would remember only the last one. That history is not
-- built here.
alter table supply
  add column if not exists home_id uuid references location(id);

comment on column supply.home_id is
  'Where this belongs when nobody has it. Not where it currently is: that is a '
  'history and does not exist yet.';

-- ---------------------------------------------------------------------------
-- An inventory for a domain
-- ---------------------------------------------------------------------------

create or replace view inventory_for_domain with (security_invoker = true) as
-- Assigned to the domain outright.
select
  d.value        as domain,
  d.label        as domain_label,
  h.supply_id,
  h.name,
  h.unit,
  h.on_hand,
  h.supplier,
  s.home_id,
  'tagged'::text as because
from supply_on_hand h
join supply s        on s.id = h.supply_id
join supply_domain sd on sd.supply_id = h.supply_id
join term d          on d.id = sd.domain_id and d.active
where s.retired_at is null
union
-- Or simply sitting in a place that belongs to the domain, inherited tags
-- included, which is how a hammer left in the winery room becomes findable by
-- somebody standing in the winery without becoming winery stock.
select
  e.domain,
  e.domain_label,
  h.supply_id,
  h.name,
  h.unit,
  h.on_hand,
  h.supplier,
  s.home_id,
  'present'::text as because
from supply_on_hand h
join supply s on s.id = h.supply_id
join location_domain_effective e on e.location_id = s.home_id
where s.retired_at is null
  and not exists (
    -- A thing both tagged for the domain and living in it is reported once, as
    -- tagged, because that is the stronger claim of the two.
    select 1 from supply_domain sd
      join term d on d.id = sd.domain_id
     where sd.supply_id = h.supply_id and d.value = e.domain);

comment on view inventory_for_domain is
  'Everything in a domain''s inventory: what is assigned to it, and what happens '
  'to live in one of its places. `because` says which, so a reorder report can '
  'take the first and a search can take both.';

-- ---------------------------------------------------------------------------
-- The contract
-- ---------------------------------------------------------------------------

create or replace function tag_supply(p_supply_id uuid, p_domain text)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare d uuid;
begin
  if not is_facility_user() then
    raise exception 'stock is tagged by people who work here';
  end if;
  if not exists (select 1 from supply where id = p_supply_id) then
    raise exception 'there is no such thing to tag';
  end if;
  select t.id into d from term t
   where t.kind = 'domain' and t.value = p_domain and t.active;
  if d is null then
    raise exception 'there is no domain called %', p_domain;
  end if;

  insert into supply_domain (supply_id, domain_id, by_user)
  values (p_supply_id, d, auth.uid())
  on conflict (supply_id, domain_id) do nothing;

  return jsonb_build_object('supply', p_supply_id, 'domain', p_domain);
end $$;

-- The default is what makes the contract's `required: false` honest, and it is
-- also the only way to say "this has no home any more". Nullable is not the same
-- as optional and the contract assertion is right to tell them apart.
create or replace function set_supply_home(p_supply_id uuid, p_location_id uuid default null)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare s supply%rowtype;
begin
  if not is_facility_user() then
    raise exception 'stock is put away by people who work here';
  end if;
  if p_location_id is not null
     and not exists (select 1 from location where id = p_location_id) then
    raise exception 'there is no such place to keep it';
  end if;

  update supply set home_id = p_location_id where id = p_supply_id
  returning * into s;
  if s.id is null then
    raise exception 'there is no such thing to put away';
  end if;

  return jsonb_build_object('supply', s.id, 'home', s.home_id);
end $$;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('inventory.tag_supply', 'inventory', 'Say which domain something belongs to',
   'Assigns a thing to a domain. Several are allowed, because one box of gloves can be the winery''s and the woodshed''s at once.',
   'tag_supply',
   '[{"key": "supply", "type": "uuid", "label": "Which thing", "param": "p_supply_id", "required": true,
      "source": {"readable": "inventory.stock"}},
     {"key": "domain", "type": "text", "label": "Belongs to", "param": "p_domain", "required": true,
      "source": {"terms": "domain"}}]'::jsonb,
   40),
  ('inventory.set_supply_home', 'inventory', 'Say where something lives',
   'Records where a thing belongs when nobody has it, which is what you tell somebody who is looking for it. Not where it currently is.',
   'set_supply_home',
   '[{"key": "supply", "type": "uuid", "label": "Which thing", "param": "p_supply_id", "required": true,
      "source": {"readable": "inventory.stock"}},
     {"key": "location", "type": "uuid", "label": "Lives at", "param": "p_location_id", "required": false,
      "source": {"readable": "core.places"}}]'::jsonb,
   41)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

-- The inventory module had a name, a label and one vocabulary, and its actual
-- surface was filed under the cellar. These are its own.
insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('inventory.stock', 'inventory', 'Everything we have',
   'Total inventory: every thing, what is on hand, and where it lives. Every domain''s inventory is a subset of this.',
   'supply_on_hand', 'supply_id', 'name', 42),
  ('inventory.by_domain', 'inventory', 'Inventory by domain',
   'What belongs to each domain, and what merely sits in one of its places. `because` says which.',
   'inventory_for_domain', 'supply_id', 'name', 43)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

-- A thing can now carry a note or a photograph, which it could not before: the
-- drill whose battery is dying, and the shelf photographed so somebody can find
-- it.
insert into subject_resolver (subject_type, relation, name_expression, module)
values ('supply', 'supply', 'name', 'inventory')
on conflict (subject_type) do update set
  relation = excluded.relation,
  name_expression = excluded.name_expression,
  module = excluded.module;

do $$
begin
  if exists (select 1 from term_kind where kind = 'location_tag') then
    raise exception 'the old vocabulary name is still registered';
  end if;
  if (select count(*) from term where kind = 'domain' and active) < 3 then
    raise exception 'the domain vocabulary lost members in the rename';
  end if;
  if not exists (select 1 from capability where module = 'inventory') then
    raise exception 'the inventory module still has no verbs of its own';
  end if;
  if not exists (select 1 from subject_resolver where subject_type = 'supply') then
    raise exception 'a thing still cannot carry a note or a photograph';
  end if;
end $$;
