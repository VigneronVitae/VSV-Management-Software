-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The vineyard module starts. A block is rows, a row is plant spaces,
--           and what stands in a space is a history rather than a column."
-- Depends on: [supabase/migrations/0026_subject_type_registry.sql,
--              supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0039_vineyard.sql,
--              supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0109_a_module_says_where_it_lives.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  supabase/migrations/0116_the_vineyard_is_not_everybodys_business.sql]
-- Axioms enforced: T0-2, acreage and plant counts become derivations and stop
--                  being figures anybody types. T0-5, a vine that died and was
--                  replanted is two records and not an edit. AR-E5, plant state
--                  is a vocabulary rather than an enum.
-- Open sorries: S-97, block.acres still exists beside the derived figure.
--               S-98, the map is not loaded yet.
-- ---------------------------------------------------------------------------

-- "Now is the time for the start of the vineyard module, that will feed the
-- vineyard section of the winery module."
--
-- The module has been a registered row with one readable and no kernel since
-- 0109. This gives it one.
--
-- **The master document is `Maps/Vitae Springs Vine Map.xlsx` and it is a map of
-- plant spaces, not of plantings.** Five sheets, one per block, each a grid of
-- vineyard rows by plant space, and every space painted a colour that says what
-- stands in it: a variety, a young scion, rootstock only, or nothing. About
-- thirteen and a half thousand spaces. The shape below is that document's shape,
-- because the document is right: a vineyard is not a list of varieties with
-- acreages, it is a set of positions, most of which have a vine in them.
--
-- **Acreage is already a derivation and has been all along.** 220 Müller Thurgau
-- reads as 0.20202020202020202 acres, which is 220/1089 to the last digit, and
-- 1366 Riesling reads as 1.2543617998163452, which is 1366/1089. Tudor and
-- Southeast are planted at 1089 vines to the acre and Overlook's Pommard and 777
-- block at 1245. Nobody measured those acreages, they were counted and divided,
-- which is exactly what T0-2 says must not be stored. So `vines_per_acre` goes
-- on the block and the acreage comes out of a view.
--
-- **What stands in a space is a history, not a column.** The same argument as
-- `machine_work` in 0105: a vine that died in 2023 and was replanted in 2024 is
-- two facts with dates on them, and a column would remember only the second. It
-- also makes the map importable honestly, as one observation dated when the map
-- was drawn, rather than as a claim about today.

-- ---------------------------------------------------------------------------
-- What can stand in a plant space
-- ---------------------------------------------------------------------------

insert into term_kind (kind, module, label, sort_order) values
  ('plant_state', 'vineyard', 'What is in a plant space', 80)
on conflict (kind) do nothing;

-- Four, and they are the map's own four. "Young scion" is a state and not a
-- variety: it is a vine of a known variety that is not yet bearing, which is
-- why the map paints it differently and why it must not be counted as a
-- producing vine.
insert into term (kind, value, label, sort_order) values
  ('plant_state', 'vine',           'A vine',          10),
  ('plant_state', 'young_scion',    'Young scion',     20),
  ('plant_state', 'rootstock_only', 'Rootstock only',  30),
  ('plant_state', 'empty',          'No vine',         40)
on conflict (kind, value) do nothing;

-- ---------------------------------------------------------------------------
-- The row
-- ---------------------------------------------------------------------------

create table if not exists vine_row (
  id          uuid primary key default gen_random_uuid(),
  block_id    uuid not null references block (id) on delete cascade,
  -- The number painted on the end post. Not a position in a list: rows get
  -- pulled out and rows get added, and the number is what somebody says on the
  -- radio.
  number      int not null,
  -- "N to S orientation" is written at the top of each sheet and it decides
  -- which end plant space 1 is, which is the difference between finding the
  -- vine and walking the wrong way down a row in the rain.
  orientation text,
  length_ft   numeric(8,2),
  notes       text,
  created_at  timestamptz not null default now(),
  created_by  uuid references auth.users (id),

  constraint vine_row_number_is_positive check (number > 0),
  constraint vine_row_length_is_positive check (length_ft is null or length_ft > 0),
  unique (block_id, number)
);

alter table vine_row enable row level security;

drop policy if exists vine_row_read on vine_row;
create policy vine_row_read on vine_row for select to authenticated using (true);

drop policy if exists vine_row_admin_write on vine_row;
create policy vine_row_admin_write on vine_row to authenticated
  using (is_admin()) with check (is_admin());

comment on table vine_row is
  'A row of vines in a block, by the number on its end post.';

-- ---------------------------------------------------------------------------
-- The plant space, which is the thing that persists
-- ---------------------------------------------------------------------------

-- **A space, not a vine.** The map says "no vine or root stock" for a position
-- that is empty, which means the position is the durable object and the vine is
-- what is currently standing in it. A vine that dies does not delete the
-- address, and the next vine planted there is at the same address. This is the
-- same reason `vessel` and the wine in it are two things.
create table if not exists plant_space (
  id         uuid primary key default gen_random_uuid(),
  row_id     uuid not null references vine_row (id) on delete cascade,
  number     int not null,
  created_at timestamptz not null default now(),

  constraint plant_space_number_is_positive check (number > 0),
  unique (row_id, number)
);

alter table plant_space enable row level security;

drop policy if exists plant_space_read on plant_space;
create policy plant_space_read on plant_space for select to authenticated using (true);

drop policy if exists plant_space_admin_write on plant_space;
create policy plant_space_admin_write on plant_space to authenticated
  using (is_admin()) with check (is_admin());

comment on table plant_space is
  'One position in a row. It persists whether or not anything is growing in it.';

-- ---------------------------------------------------------------------------
-- What was found there, and when
-- ---------------------------------------------------------------------------

create table if not exists plant_change (
  id         uuid primary key default gen_random_uuid(),
  space_id   uuid not null references plant_space (id) on delete cascade,
  -- A date rather than a timestamp. Nobody knows what time a vine was planted
  -- and pretending otherwise makes the record look more precise than it is.
  at         date not null default current_date,
  state_id   uuid not null,
  state_kind text generated always as ('plant_state') stored,
  -- Null when nothing is growing. A variety on an empty space would be a claim
  -- about a vine that is not there.
  variety_id uuid,
  variety_kind text generated always as ('variety') stored,
  clone      text,
  note       text,
  -- T0-4. The map is an observation made on the day it was drawn; a survey walked
  -- this summer is another. An agent writes `inferred` here and never `confirmed`.
  provenance provenance not null default 'observed',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  constraint plant_change_state_is_a_plant_state
    foreign key (state_id, state_kind) references term (id, kind),
  constraint plant_change_variety_is_a_variety
    foreign key (variety_id, variety_kind) references term (id, kind),

  -- Nothing growing means no variety and no clone. The map has a colour for an
  -- empty space and it is not a kind of grape.
  constraint plant_change_empty_names_nothing check (
    variety_id is not null
    or clone is null
  )
);

create index if not exists plant_change_space_idx
  on plant_change (space_id, at desc);

alter table plant_change enable row level security;

drop policy if exists plant_change_read on plant_change;
create policy plant_change_read on plant_change for select to authenticated using (true);

drop policy if exists plant_change_write on plant_change;
create policy plant_change_write on plant_change to authenticated
  using (is_admin()) with check (is_admin());

comment on table plant_change is
  'What was found or planted in a space, on a date. Append only: a vine that '
  'died and was replaced is two rows, and the older one stays true of its date.';

-- ---------------------------------------------------------------------------
-- What is there now, which is a function of the history
-- ---------------------------------------------------------------------------

create or replace view plant_space_now with (security_invoker = true) as
select
  ps.id            as space_id,
  ps.number        as space_number,
  vr.id            as row_id,
  vr.number        as row_number,
  vr.orientation,
  b.id             as block_id,
  b.name           as block,
  v.id             as vineyard_id,
  v.name           as vineyard,
  c.at             as as_of,
  st.value         as state,
  st.label         as state_label,
  c.variety_id,
  t.label          as variety,
  c.clone,
  c.note,
  c.provenance
from plant_space ps
join vine_row vr on vr.id = ps.row_id
join block b on b.id = vr.block_id
left join vineyard v on v.id = b.vineyard_id
-- The latest change wins, and a space with no change yet is still a space.
left join lateral (
  select * from plant_change pc
   where pc.space_id = ps.id
   order by pc.at desc, pc.created_at desc
   limit 1
) c on true
left join term st on st.id = c.state_id
left join term t on t.id = c.variety_id;

comment on view plant_space_now is
  'Every plant space with what currently stands in it, derived from the latest '
  'dated change rather than stored.';

-- ---------------------------------------------------------------------------
-- The planting, which is now counted rather than typed
-- ---------------------------------------------------------------------------

-- `vines_per_acre` rather than a spacing string, because the arithmetic is what
-- the acreage needs and "8x5" would have to be parsed to get it. His own sheet
-- divides by 1089 for Tudor and Southeast and by 1245 for Overlook's Pommard and
-- 777 block, so it differs by block and belongs on the block.
alter table block add column if not exists vines_per_acre numeric(8,2);

comment on column block.vines_per_acre is
  'Planting density, used to derive acreage from plant spaces. 1089 is 40 square '
  'feet a vine, 1245 is 35.';

create or replace view block_planting with (security_invoker = true) as
select
  n.block_id,
  n.block,
  n.vineyard_id,
  n.vineyard,
  n.variety_id,
  n.variety,
  n.clone,
  n.state,
  count(*) as plants,
  -- Null rather than a wrong number when nobody has said how densely the block
  -- is planted. A13: an acreage computed from a missing divisor would be a
  -- confident answer to a question nobody has answered.
  round(count(*) / nullif(b.vines_per_acre, 0), 4) as acres
from plant_space_now n
join block b on b.id = n.block_id
where n.variety_id is not null
group by n.block_id, n.block, n.vineyard_id, n.vineyard,
         n.variety_id, n.variety, n.clone, n.state, b.vines_per_acre;

comment on view block_planting is
  'What is planted in each block, counted from the plant spaces. This is the '
  'derived form of what block.acres and planting.acres hold by hand. See S-97.';

-- ---------------------------------------------------------------------------
-- A note can be about one vine
-- ---------------------------------------------------------------------------

-- The map already carries per-vine observations: "R2, P68 sucker only",
-- "R4,P86 orange flag", grow tubes. Those are notes about a position, and the
-- note system has been able to point at any registered subject since 0101.
-- Inserted rather than registered through the function, which checks is_admin()
-- and so refuses inside a migration, where there is no signed-in anybody. 0101
-- did the same for the same reason.
insert into subject_resolver (subject_type, relation, name_expression, module) values
  ('plant_space', 'plant_space',
   'coalesce((select b.name || '' row '' || vr.number || '' plant ''
                from vine_row vr join block b on b.id = vr.block_id
               where vr.id = row_id), ''plant '') || number',
   'vineyard')
on conflict (subject_type) do update
  set relation = excluded.relation,
      name_expression = excluded.name_expression,
      module = excluded.module;

-- ---------------------------------------------------------------------------
-- The contract
-- ---------------------------------------------------------------------------

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('vineyard.plant_spaces', 'vineyard', 'Every plant space',
   'Every position in every row, with what currently stands in it and when that was last seen.',
   'plant_space_now', 'space_id', 'variety', 410),
  ('vineyard.block_plantings', 'vineyard', 'What is planted where',
   'Counted from the plant spaces rather than typed: plants and derived acreage per block, variety and clone.',
   'block_planting', 'block_id', 'variety', 411)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;
