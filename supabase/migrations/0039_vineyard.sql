-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A vineyard is a place, a block is part of it, and what is planted in
--           a block is a list of varieties that each have their own clone, age
--           and rootstock, or take the block's."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0026_subject_type_registry.sql,
--              supabase/migrations/0038_cancel_a_pick.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0040_block_variety_is_history.sql, supabase/migrations/0067_sampling.sql,
--                  supabase/migrations/0113_a_vineyard_is_a_place_you_can_open.sql,
--                  supabase/migrations/0114_every_pick_stays_on_the_list.sql,
--                  supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql]
-- Axioms enforced: T0-2 (never store what is derived: a planting inherits the
--                  block's answer by being asked, not by being copied)
-- Open sorries: S-55 (acres and years are typed, and no unit is recorded
--               beside them)
-- ---------------------------------------------------------------------------
--
-- Asked for after the first export made it obvious that a block was four fields
-- and a vineyard was a string typed onto each of them.
--
-- **Three levels, because the winemaker described three.** A vineyard is a
-- place. A block is part of that place. What is planted in a block is a list:
-- "a block can carry several, and those varieties could also have different
-- rootstocks and planting age". So a planting is a variety in a block, and it is
-- the thing that carries the detail.
--
-- **Inheritance is a question, not a copy.** Every field a planting can carry,
-- a block can carry too, and a planting that says nothing takes the block's
-- answer. That is done in a view rather than by writing the block's value onto
-- each planting, because a copied value is a value that can disagree with its
-- source, which is T0-2 in the one place it is easiest to get lazy about.
--
-- **`subject_resolver` had to move in the same breath.** It carried
-- `vineyard || ' ' || name` for a block, and `resolve_subject_name` runs that
-- expression inside `exception when others then return null`. Replacing the
-- text column without touching it would not have failed: every block would
-- quietly have stopped having a name. The export is what showed this, which is
-- the export earning itself on its first use.
--
-- This is deliberately input only. The winemaker's words: "it will also be able
-- to be plugged into the vineyard module later". Nothing here computes anything
-- about farming; it is a place to put what somebody knows, shaped so that a real
-- vineyard module can fill the same rows in without the shape changing.

begin;

-- ---------------------------------------------------------------------------
-- The place
-- ---------------------------------------------------------------------------

create table if not exists vineyard (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  -- Free text on purpose. Where a vineyard is might be an address, a road, a
  -- pin somebody would recognise, or nothing yet, and picking one of those now
  -- would be guessing at what the vineyard module will bring.
  location   text,
  notes      text,
  created_at timestamptz not null default now()
);

alter table vineyard enable row level security;

drop policy if exists vineyard_read on vineyard;
create policy vineyard_read on vineyard for select to authenticated using (true);

drop policy if exists vineyard_admin_write on vineyard;
create policy vineyard_admin_write on vineyard to authenticated
  using (is_admin()) with check (is_admin());

comment on table vineyard is
  'Where fruit comes from. Named once and pointed at, rather than typed onto '
  'every block, which is half of sorry S-53. See 0039.';

-- ---------------------------------------------------------------------------
-- The block, pointing at its vineyard
-- ---------------------------------------------------------------------------

alter table block add column if not exists vineyard_id uuid references vineyard (id);

-- One vineyard row per distinct name already typed. Case and spacing are
-- folded, because "Pearlstaad " and "Pearlstaad" are one place and this is the
-- only moment where that can be fixed without somebody choosing.
insert into vineyard (name)
select distinct btrim(b.vineyard)
  from block b
 where btrim(coalesce(b.vineyard, '')) <> ''
   and not exists (
     select 1 from vineyard v where lower(v.name) = lower(btrim(b.vineyard)))
on conflict (name) do nothing;

update block b
   set vineyard_id = v.id
  from vineyard v
 where lower(v.name) = lower(btrim(b.vineyard))
   and b.vineyard_id is null;

-- The old unique was (vineyard, name). The same block name under two vineyards
-- is two blocks, which is still true with an id in place of a string.
alter table block drop constraint if exists block_vineyard_name_key;
alter table block drop column if exists vineyard;
alter table block
  add constraint block_vineyard_name_key unique (vineyard_id, name);

-- What is true of the whole block unless a planting says otherwise. Every one of
-- these is nullable: a block nobody has measured is a real block, and refusing
-- to record one because its acreage is unknown would be the opposite of useful.
alter table block
  add column if not exists acres        numeric(10,2),
  add column if not exists planted_year int,
  add column if not exists clone        text,
  add column if not exists rootstock    text,
  add column if not exists spacing      text,
  add column if not exists trellis      text,
  add column if not exists aspect       text,
  add column if not exists elevation    text,
  add column if not exists soil         text;

-- ---------------------------------------------------------------------------
-- What is planted in it
-- ---------------------------------------------------------------------------

create table if not exists planting (
  id           uuid primary key default gen_random_uuid(),
  block_id     uuid not null references block (id) on delete cascade,
  variety_id   uuid not null,
  -- Pins the term to the variety vocabulary, the same way every other pointer
  -- into `term` does since 0027. A block planted to a vessel type is not a
  -- thing, and the composite key is what says so.
  variety_kind text generated always as ('variety') stored,
  acres        numeric(10,2),
  planted_year int,
  clone        text,
  rootstock    text,
  spacing      text,
  trellis      text,
  aspect       text,
  elevation    text,
  soil         text,
  notes        text,
  created_at   timestamptz not null default now(),
  constraint planting_variety_is_a_variety
    foreign key (variety_id, variety_kind) references term (id, kind),
  constraint planting_one_row_per_variety unique (block_id, variety_id)
);

alter table planting enable row level security;

drop policy if exists planting_read on planting;
create policy planting_read on planting for select to authenticated using (true);

drop policy if exists planting_admin_write on planting;
create policy planting_admin_write on planting to authenticated
  using (is_admin()) with check (is_admin());

comment on table planting is
  'A variety in a block. Carries its own clone, age and rootstock, or leaves '
  'them null and takes the block''s. See planting_detail and 0039.';

-- The variety a block already named as text becomes its first planting, matched
-- against the vocabulary by label. A name that matches nothing is left alone
-- rather than guessed at, and the block simply has no planting yet.
insert into planting (block_id, variety_id)
select b.id, t.id
  from block b
  join term t on t.kind = 'variety' and lower(t.label) = lower(btrim(b.variety))
 where btrim(coalesce(b.variety, '')) <> ''
on conflict (block_id, variety_id) do nothing;

-- Kept rather than dropped. A label that matched no variety is still the only
-- record of what somebody typed, and throwing it away to tidy up would lose it.
comment on column block.variety is
  'Superseded by the planting table in 0039 and kept because a label that '
  'matched no variety in the vocabulary is still the only record of what was '
  'typed. Read planting_detail instead.';

-- ---------------------------------------------------------------------------
-- Asking the block when the planting does not say
-- ---------------------------------------------------------------------------

-- The inheritance the winemaker asked for: fill it in per variety, or let the
-- whole block answer. Derived on read, never written down, so a block corrected
-- next spring corrects every planting that was relying on it.
--
-- `inherited` names the fields that came from the block, so a screen can show
-- the difference between "this planting says 2014" and "the block says 2014 and
-- this planting has not been asked". Those are not the same fact.
create or replace view planting_detail with (security_invoker = true) as
select
  p.id            as planting_id,
  b.id            as block_id,
  b.name          as block_name,
  v.id            as vineyard_id,
  v.name          as vineyard_name,
  t.id            as variety_id,
  t.label         as variety,
  coalesce(p.acres,        b.acres)        as acres,
  coalesce(p.planted_year, b.planted_year) as planted_year,
  coalesce(p.clone,        b.clone)        as clone,
  coalesce(p.rootstock,    b.rootstock)    as rootstock,
  coalesce(p.spacing,      b.spacing)      as spacing,
  coalesce(p.trellis,      b.trellis)      as trellis,
  coalesce(p.aspect,       b.aspect)       as aspect,
  coalesce(p.elevation,    b.elevation)    as elevation,
  coalesce(p.soil,         b.soil)         as soil,
  p.notes,
  array_remove(array[
    case when p.acres        is null and b.acres        is not null then 'acres' end,
    case when p.planted_year is null and b.planted_year is not null then 'planted_year' end,
    case when p.clone        is null and b.clone        is not null then 'clone' end,
    case when p.rootstock    is null and b.rootstock    is not null then 'rootstock' end,
    case when p.spacing      is null and b.spacing      is not null then 'spacing' end,
    case when p.trellis      is null and b.trellis      is not null then 'trellis' end,
    case when p.aspect       is null and b.aspect       is not null then 'aspect' end,
    case when p.elevation    is null and b.elevation    is not null then 'elevation' end,
    case when p.soil         is null and b.soil         is not null then 'soil' end
  ], null) as inherited
from planting p
join block b on b.id = p.block_id
join term  t on t.id = p.variety_id and t.kind = 'variety'
left join vineyard v on v.id = b.vineyard_id;

comment on view planting_detail is
  'A planting with the block''s answers filled in where it has none of its own. '
  'The inherited column names which ones were borrowed. See 0039.';

-- ---------------------------------------------------------------------------
-- Names, which would otherwise have gone quiet
-- ---------------------------------------------------------------------------

-- `resolve_subject_name` runs this expression against the block row inside an
-- exception handler that returns null. So the old `vineyard || ' ' || name`
-- would not have errored after the column moved: every block would simply have
-- stopped having a name, which is the shape of failure this project is built to
-- refuse. A block with no vineyard still names itself.
update subject_resolver
   set name_expression =
     'coalesce((select v.name || '' '' from vineyard v where v.id = vineyard_id), '''') || name'
 where subject_type = 'block';

insert into subject_resolver (subject_type, relation, name_expression, module)
values ('vineyard', 'vineyard', 'name', 'vineyard')
on conflict (subject_type) do update
  set relation = excluded.relation,
      name_expression = excluded.name_expression,
      module = excluded.module;

commit;
