-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "What is on the shelf, worked out from what came in and what went
--           out, corrected by somebody actually counting it, and a list of what
--           to buy that a person keeps rather than a machine."
-- Depends on: [supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0045_press_detail.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0050_additions.sql, supabase/migrations/0051_supplies_for_addition.sql,
--                  docs/review/2026-09-17-shop-and-inventory-elsewhere.md]
-- Axioms enforced: T0-2 (on hand is derived and never stored), T0-3 (a count is
--                  an observation and the gap it reveals is kept, not smoothed
--                  away), T0-5 (movements are appended; the shopping list is an
--                  intention and may be changed)
-- Open sorries: S-63 (a supply has a unit and nothing converts between units),
--               S-64 (nothing consumes a supply automatically yet)
-- ---------------------------------------------------------------------------
--
-- `term_kind` has registered `material_kind` to a module called `inventory`
-- since `0027`, and nothing was ever built on it. This is that module's first
-- migration, living in the same schema for now because a second package is a
-- later pass and `AR-A3` is about which direction knowledge flows rather than
-- how many folders there are.
--
-- **On hand is derived, and a count is what corrects the derivation.** The
-- winemaker's shape exactly: "derived from what came in and went out with
-- reconciliation". Received minus used is exact when every use is recorded and
-- silently wrong the first time somebody takes a scoop without saying so, which
-- during harvest is every day. So a count is an observation that resets the sum,
-- and everything after it accumulates again.
--
-- **The gap a count reveals is kept.** When somebody counts 3.8 kg where the
-- movements said 4.2, that 0.4 is the most interesting number in the table: it
-- is a measurement of how much use goes unrecorded. Smoothing it into a
-- correcting movement would destroy the one signal that says whether this
-- inventory can be trusted at all. So the count records what was expected beside
-- what was found.
--
-- **The shopping list is kept by a person and prompted by the derivation.** Also
-- his: "maybe only what you put there but it prompts based on derivation". A
-- list that fills itself is a list nobody reads, and a level nobody set is not a
-- reason to buy anything. So `supply_below_level` is a suggestion and
-- `shopping_item` is a list, and the two are not the same table.
--
-- **Broken is a movement, not a flag.** He suggested flagging things broken or
-- partially broken. A flag could not say that two of six hose heads are broken,
-- and could not say when, and both of those are the useful part. So breaking is
-- a movement with a quantity and a date, it comes off what is usable, and
-- `repaired` reverses it. Partially broken is a note on the movement rather than
-- a third tally: something still usable should not be subtracted from what is
-- usable, and calling it broken would do exactly that.
--
-- **What sort of thing it is, is flags rather than a category.** His case for it
-- was a delivery of hose heads: "not exactly infrastructure not exactly
-- consumable". A single category forces a wrong answer for precisely the things
-- nobody anticipated, and the vocabulary is editable for the same reason.
--
-- Dry goods are out of scope for now, by his instruction. Nothing here precludes
-- them: a bottle is a supply with a unit of `each`, so admitting them later is
-- rows rather than schema.

begin;

-- ---------------------------------------------------------------------------
-- The things
-- ---------------------------------------------------------------------------

create table if not exists supply (
  id            uuid primary key default gen_random_uuid(),
  name          text not null unique,
  -- What one of it is: g, kg, L, mL, each. Free text and nothing converts, which
  -- is S-63. A supply bought in kilograms and used in grams is the ordinary case
  -- and this migration does not solve it; it records the unit so that the day
  -- somebody does solve it, the numbers mean something.
  unit          text not null,
  -- The level below which it goes on the suggestions. Null means nobody has said
  -- what low is, which is not the same as zero and must not prompt.
  reorder_level numeric(12,3),
  supplier      text,
  notes         text,
  retired_at    timestamptz,
  created_at    timestamptz not null default now(),
  constraint supply_has_a_unit check (btrim(unit) <> '')
);

-- What sort of thing it is, as flags rather than one category. The winemaker's
-- case for it: "we just got new hose heads too, not exactly infrastructure not
-- exactly consumable." A single category forces a wrong answer for exactly the
-- things nobody thought about when the categories were written, and those are
-- the things that arrive during harvest.
--
-- The vocabulary is `material_kind`, which `0027` registered to the inventory
-- module and nothing had used. No second vocabulary is invented for this: what
-- sort of material a thing is, is what that list is for.
create table if not exists supply_material_kind (
  supply_id uuid not null references supply (id) on delete cascade,
  kind_id   uuid not null,
  kind_kind text generated always as ('material_kind') stored,
  primary key (supply_id, kind_id),
  constraint supply_kind_is_a_material
    foreign key (kind_id, kind_kind) references term (id, kind)
);

-- A starting vocabulary rather than a fixed one. Three that everybody has, and
-- the list is open and editable, because the hose head is the argument: the
-- category somebody needs is the one nobody wrote down in advance.
insert into term (kind, value, label, sort_order) values
  ('material_kind', 'addition',   'Goes into wine', 10),
  ('material_kind', 'consumable', 'Consumable',     20),
  ('material_kind', 'equipment',  'Equipment',      30)
on conflict (kind, value) do nothing;

-- Everything that changed the amount. Appended, never edited: a delivery that
-- arrived is a fact about the past, and so is a count.
create table if not exists supply_movement (
  id         uuid primary key default gen_random_uuid(),
  supply_id  uuid not null references supply (id) on delete cascade,
  -- A total order that does not depend on the clock. `at` is when it happened
  -- and is what a person reads; it is not sufficient to decide what came after a
  -- count, because a transaction sees one `now()` for its whole length and two
  -- movements a second apart carry the same timestamp anyway. Counting a shelf
  -- and then immediately recording the scoop you just took is the ordinary case
  -- that breaks, and it breaks silently: the scoop is simply not subtracted.
  seq        bigserial not null,
  at         timestamptz not null default now(),
  -- received adds; used, discarded and broken subtract; repaired adds back.
  -- counted does none of those: it says what was on the shelf, and the running
  -- total starts again from there.
  --
  -- **Broken is a quantity, not a label on the thing.** Two of six hose heads
  -- are broken, which a flag on the supply could not say, and it happened on a
  -- day, which a flag could not say either. So it subtracts from what is usable
  -- and stays countable on its own, and `repaired` brings one back.
  kind       text not null,
  quantity   numeric(12,3) not null,
  -- What the derivation said at the moment of a count. Kept rather than used to
  -- write a correcting movement, because the difference between this and
  -- `quantity` is a measurement of how much use goes unrecorded, and that is the
  -- number that says whether any of this can be trusted.
  expected   numeric(12,3),
  note       text,
  by_user    uuid references app_user (id),
  created_at timestamptz not null default now(),
  constraint supply_movement_kind_is_known
    check (kind in ('received', 'used', 'discarded', 'broken', 'repaired', 'counted')),
  constraint supply_movement_quantity_is_an_amount
    check (quantity >= 0),
  -- Only a count has something to have expected.
  constraint supply_movement_expected_only_on_counts
    check (expected is null or kind = 'counted')
);

create index if not exists supply_movement_supply_seq_idx
  on supply_movement (supply_id, seq desc);

-- A list somebody keeps. Not derived, because the winemaker asked for it not to
-- be: a list that fills itself is a list nobody reads.
create table if not exists shopping_item (
  id         uuid primary key default gen_random_uuid(),
  -- Null for something that is not a supply yet, which is most of what ends up
  -- on a shopping list the first time somebody needs it.
  supply_id  uuid references supply (id) on delete set null,
  what       text not null,
  quantity   text,
  note       text,
  added_by   uuid references app_user (id),
  bought_at  timestamptz,
  created_at timestamptz not null default now(),
  constraint shopping_item_says_something check (btrim(what) <> '')
);

alter table supply enable row level security;
alter table supply_material_kind enable row level security;
alter table supply_movement enable row level security;
alter table shopping_item enable row level security;

drop policy if exists supply_material_kind_read on supply_material_kind;
create policy supply_material_kind_read on supply_material_kind for select
  to authenticated using (is_facility_user());

drop policy if exists supply_material_kind_admin_write on supply_material_kind;
create policy supply_material_kind_admin_write on supply_material_kind
  to authenticated using (is_admin()) with check (is_admin());

-- The stores are the facility's business and none of a client's.
drop policy if exists supply_read on supply;
create policy supply_read on supply for select to authenticated
  using (is_facility_user());

drop policy if exists supply_admin_write on supply;
create policy supply_admin_write on supply to authenticated
  using (is_admin()) with check (is_admin());

drop policy if exists supply_movement_read on supply_movement;
create policy supply_movement_read on supply_movement for select to authenticated
  using (is_facility_user());

-- Anybody who works here records what they used and what arrived, as
-- themselves. This is the whole point: a cellar hand who cannot say they took a
-- scoop is a cellar hand whose scoop never happened.
drop policy if exists supply_movement_insert on supply_movement;
create policy supply_movement_insert on supply_movement for insert to authenticated
  with check (is_facility_user() and by_user = auth.uid());

drop policy if exists supply_movement_admin_delete on supply_movement;
create policy supply_movement_admin_delete on supply_movement for delete
  to authenticated using (is_admin());

drop policy if exists shopping_item_read on shopping_item;
create policy shopping_item_read on shopping_item for select to authenticated
  using (is_facility_user());

-- A list is an intention, so anybody who works here may add to it, tick it off
-- and change their mind. That is not append only and should not be.
drop policy if exists shopping_item_write on shopping_item;
create policy shopping_item_write on shopping_item to authenticated
  using (is_facility_user()) with check (is_facility_user());

comment on table supply is
  'Something kept on a shelf. Dry goods are out of scope for now and nothing '
  'here precludes them: a bottle is a supply with a unit of each. See 0046.';

comment on column supply_movement.expected is
  'What the derivation said at the moment of a count. The difference between '
  'this and the counted quantity measures how much use goes unrecorded, which '
  'is why it is kept rather than smoothed into a correcting movement.';

-- ---------------------------------------------------------------------------
-- What is on the shelf
-- ---------------------------------------------------------------------------

-- Derived on every read, never stored. The last count is the floor and
-- everything after it accumulates: that is what makes a count a correction
-- rather than one more opinion.
-- Dropped rather than replaced: `create or replace view` refuses a change to
-- the column list, and this one gained `kinds` in the middle. Cascading takes
-- the suggestion view with it, which is recreated below.
drop view if exists supply_below_level;
drop view if exists supply_on_hand;

create view supply_on_hand with (security_invoker = true) as
with last_count as (
  -- By sequence rather than by time, so a movement recorded in the same instant
  -- as the count still lands after it.
  select distinct on (supply_id) supply_id, seq, at, quantity
    from supply_movement
   where kind = 'counted'
   order by supply_id, seq desc
)
select
  s.id        as supply_id,
  s.name,
  -- Carried here so a screen can group or filter without a second query, and
  -- because "what sort of thing is this" is part of reading a shelf.
  coalesce((
    select array_agg(t.label order by t.sort_order, t.label)
      from supply_material_kind k
      join term t on t.id = k.kind_id and t.kind = 'material_kind'
     where k.supply_id = s.id
  ), '{}'::text[]) as kinds,
  s.unit,
  s.reorder_level,
  s.supplier,
  s.retired_at,
  c.at        as counted_at,
  -- What is usable. Broken stock is subtracted here and counted separately,
  -- because six hose heads of which two are broken is four hose heads to
  -- anybody reaching for one.
  coalesce(c.quantity, 0) + coalesce((
    select sum(case when m.kind in ('received', 'repaired') then m.quantity
                    else -m.quantity end)
      from supply_movement m
     where m.supply_id = s.id
       and m.kind <> 'counted'
       and (c.seq is null or m.seq > c.seq)
  ), 0) as on_hand,
  -- Broken and not yet repaired or thrown out. Worth seeing beside the usable
  -- figure: a shelf with four good and two broken is a different situation from
  -- a shelf with four.
  coalesce((
    select sum(case m.kind when 'broken' then m.quantity else -m.quantity end)
      from supply_movement m
     where m.supply_id = s.id
       and m.kind in ('broken', 'repaired')
       and (c.seq is null or m.seq > c.seq)
  ), 0) as broken
from supply s
left join last_count c on c.supply_id = s.id;

comment on view supply_on_hand is
  'What came in less what went out, starting from the last time somebody '
  'counted. Derived on every read, because a stored figure is one that can '
  'disagree with its own movements. See 0046.';

-- A suggestion, not a list. Only supplies somebody has said a level for: a
-- level nobody set is not a reason to buy anything, and prompting on every
-- supply that happens to be low would be prompting on all of them.
create view supply_below_level with (security_invoker = true) as
select h.*
  from supply_on_hand h
 where h.retired_at is null
   and h.reorder_level is not null
   and h.on_hand < h.reorder_level
   -- Already on the list is already known about. A suggestion that keeps
   -- suggesting what somebody has acted on is how a prompt becomes noise.
   and not exists (
     select 1 from shopping_item i
      where i.supply_id = h.supply_id and i.bought_at is null
   );

comment on view supply_below_level is
  'Supplies under the level somebody set for them and not already on the '
  'shopping list. A suggestion rather than the list itself, because a list that '
  'fills itself is a list nobody reads. See 0046.';

-- ---------------------------------------------------------------------------
-- Counting
-- ---------------------------------------------------------------------------

-- A count is the one movement that has to read before it writes, because what
-- it records is both what was found and what the system believed.
create or replace function count_supply(
  p_supply_id uuid,
  p_counted   numeric,
  p_note      text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  before numeric;
  s      supply%rowtype;
begin
  select * into s from supply where id = p_supply_id;
  if s.id is null then
    raise exception 'no supply with id %', p_supply_id;
  end if;
  if p_counted is null or p_counted < 0 then
    raise exception 'a count of % is not an amount on a shelf',
      coalesce(p_counted::text, 'nothing');
  end if;

  select on_hand into before from supply_on_hand where supply_id = p_supply_id;

  insert into supply_movement (supply_id, kind, quantity, expected, note, by_user)
  values (p_supply_id, 'counted', p_counted, before, p_note, auth.uid());

  return jsonb_build_object(
    'supply_id', p_supply_id,
    'name',      s.name,
    'counted',   p_counted,
    'expected',  before,
    -- Positive means more was found than the movements accounted for, negative
    -- means less. Either way it is a measurement of what is not being recorded,
    -- and it is worth putting in front of somebody rather than filing.
    'difference', p_counted - before,
    'unit',      s.unit
  );
end;
$$;

commit;
