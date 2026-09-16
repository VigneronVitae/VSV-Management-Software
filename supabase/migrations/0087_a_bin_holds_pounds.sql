-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A bin says how many pounds of fruit are in it, because that is what
--           anybody knows about a bin, and how full it is becomes the derived
--           half rather than the stored one."
-- Depends on: [supabase/migrations/0040_block_variety_is_history.sql,
--              supabase/migrations/0036_bins_on_loan.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0090_a_press_takes_bins.sql,
--                  supabase/migrations/0091_a_bin_says_its_weight_everywhere.sql,
--                  supabase/migrations/0089_correcting_one_bin.sql,
--                  supabase/migrations/0092_gross_or_net_and_a_bulging_bin.sql]
-- Axioms enforced: T0-2 (whichever of pounds and percent was said is stored and
--                  the other is derived, never both), A25 (a bin with no figure
--                  reads as no figure rather than as empty)
-- Open sorries: S-84 (an estimate and a weighing sit side by side and nothing
--                reconciles them)
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"Picking bins should hold fruit in lbs or % ton."* Asked what
-- a full bin holds, so percent could be turned into pounds, he answered the
-- better question instead: *"800-900 lbs of fruit if it's bulging. But the bins
-- should each have a fruit amount in lbs so we just use that right?"*
--
-- **Right, and it is a better model than the one he was offered.** `fill_pct`
-- says how full a bin is, which only means something against a capacity, and a
-- picking bin has no honest capacity: the same bin holds 800 pounds of loose
-- clusters and 900 bulging. Pounds are what a person can say about a bin and
-- what the scale will later confirm. So pounds become the told fact and percent
-- becomes the derived one, which is the reverse of what `0033` built.
--
-- **Neither is computed from the other and stored.** Whichever the person said
-- is what goes in the row; the other is null and is worked out at read. Storing
-- both would be storing a derivation, and the first time somebody edited one
-- they would disagree, which is C-3 in a column.
--
-- **Nothing is backfilled.** The bins in the cellar tonight carry percentages
-- somebody typed by eye, and turning those into pounds would be inventing
-- weights nobody measured and writing them where a weighing goes. They keep
-- their percentages and read as pounds through the nominal figure, marked as
-- the estimate it is.
--
-- `full_lbs` is 850, which is his 800 to 900 with the middle taken, and it is a
-- row so the middle can move. It is used for one thing: turning a percentage
-- into pounds and back. It is not a capacity anybody is held to.

begin;

alter table placement add column if not exists fruit_lbs numeric(10,2);

comment on column placement.fruit_lbs is
  'Pounds of fruit somebody said were in this bin. Null when they said a '
  'percentage instead, or said nothing. Never written from fill_pct: read '
  'bin_fruit, which derives whichever half is missing. See 0087.';

do $$ begin
  alter table placement add constraint placement_fruit_lbs_is_a_weight
    check (fruit_lbs is null or fruit_lbs > 0);
exception when duplicate_object then null;
end $$;

-- One of the two, or neither, and never both. Both would be two answers to one
-- question with nothing to say which was typed and which was computed.
do $$ begin
  alter table placement add constraint placement_says_pounds_or_percent
    check (fruit_lbs is null or fill_pct is null);
exception when duplicate_object then null;
end $$;

-- His number, on the type, because a stack of bins is a stack of one thing.
update term
   set attributes = attributes || jsonb_build_object('full_lbs', 850)
 where kind = 'vessel_type'
   and coalesce((attributes ->> 'intake_bin')::boolean, false)
   and attributes ->> 'full_lbs' is null;

-- ---------------------------------------------------------------------------
-- Saying it
-- ---------------------------------------------------------------------------

create or replace function add_bin_to_pick(
  p_pick       jsonb,
  p_vessel_id  uuid,
  p_fill_pct   numeric default null,
  p_fruit_lbs  numeric default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  pick_id   uuid := coalesce((p_pick ->> 'id')::uuid, gen_random_uuid());
  existing  node%rowtype;
  holder    uuid;
  place_id  uuid := gen_random_uuid();
  auto_name text;
  blk_name  text;
  var_label text;
begin
  if p_fill_pct is not null and p_fruit_lbs is not null then
    raise exception
      'say pounds or say how full, not both: one of them would be a guess written next to a figure somebody actually gave';
  end if;
  if p_fruit_lbs is not null and p_fruit_lbs <= 0 then
    raise exception 'a bin with no fruit in it is not part of a pick';
  end if;

  -- The tare is not needed until the scale, and asking for it here would make a
  -- vineyard refuse a bin because an office field is blank. But the bin has to
  -- be a picking bin: fruit tipped into a barrel is a different mistake and it
  -- should not be recorded as a pick.
  if not exists (
    select 1 from vessel v
      join term vt on vt.id = v.type_id and vt.kind = 'vessel_type'
     where v.id = p_vessel_id
       and v.active
       and coalesce((vt.attributes ->> 'intake_bin')::boolean, false)
  ) then
    raise exception
      'that is not an active picking bin, so fruit cannot be recorded into it';
  end if;

  select node_id into holder
    from placement where vessel_id = p_vessel_id and to_at is null;
  if holder = pick_id then
    raise exception 'that bin is already part of this pick';
  end if;
  if holder is not null then
    raise exception 'that bin already holds other fruit; empty it before filling it again';
  end if;

  select * into existing from node where id = pick_id;

  if existing.id is null then
    select concat_ws(' ', v.name, b.name) into blk_name
      from block b
      left join vineyard v on v.id = b.vineyard_id
     where b.id = (p_pick ->> 'block_id')::uuid;
    select t.label into var_label from term t
     where t.kind = 'variety' and t.id = (p_pick ->> 'variety_id')::uuid;

    auto_name := nullif(
      trim(both ' ,' from concat_ws(' ', (p_pick ->> 'vintage'), var_label, blk_name)),
      '');
    auto_name := case when auto_name is null then null
                      else auto_name || ', ' || to_char(now(), 'Mon DD') end;

    insert into node
      (id, stage, status, name, variety_id, vintage, block_id,
       quantity, unit, attributes, owner_id, created_by)
    values
      (pick_id, 'bin', 'open',
       coalesce(nullif(p_pick ->> 'name', ''), auto_name,
                'Pick ' || to_char(now(), 'YYYY-MM-DD')),
       (p_pick ->> 'variety_id')::uuid,
       (p_pick ->> 'vintage')::int,
       (p_pick ->> 'block_id')::uuid,
       -- Not zero. Zero is a weight and this is the absence of one, and a pick
       -- reading 0 lbs until somebody weighs it is the A13 shape at the exact
       -- moment T1-4 exists to protect. An estimate in the bins does not change
       -- that: the lot's quantity is what the scale said.
       null,
       'lbs',
       coalesce(p_pick -> 'attributes', '{}'::jsonb),
       coalesce((p_pick ->> 'owner_id')::uuid, facility_party_id()),
       auth.uid());
  elsif existing.stage <> 'bin' then
    raise exception 'that lot is not a pick, so bins cannot be added to it';
  elsif existing.status = 'closed' then
    raise exception 'that pick is closed; its fruit has already gone somewhere';
  end if;

  insert into placement (id, node_id, vessel_id, fill_pct, fruit_lbs)
  values (place_id, pick_id, p_vessel_id, p_fill_pct, p_fruit_lbs);

  return jsonb_build_object(
    'node_id',      pick_id,
    'placement_id', place_id,
    'bins',         (select count(*) from placement
                      where node_id = pick_id and to_at is null),
    'unweighed',    (select count(*) from unweighed_bin where node_id = pick_id)
  );
end;
$$;

-- The old three-argument signature would keep every existing caller working and
-- would be a second way to add a bin that cannot say pounds. 0036 and 0068 both
-- taught this: a second signature is a call nobody can choose between.
drop function if exists add_bin_to_pick(jsonb, uuid, numeric);

create or replace function add_bins_to_pick(
  p_pick         jsonb,
  p_vessel_ids   uuid[]  default null,
  p_new_count    int     default 0,
  p_new_type_id  uuid    default null,
  p_name_prefix  text    default null,
  p_fill_pct     numeric default null,
  p_owner_id     uuid    default null,
  p_on_loan_from text    default null,
  p_fruit_lbs    numeric default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  pick_id  uuid := coalesce((p_pick ->> 'id')::uuid, gen_random_uuid());
  prefix   text := btrim(coalesce(p_name_prefix, 'Bin'));
  lender   text := nullif(btrim(coalesce(p_on_loan_from, '')), '');
  bag      jsonb;
  next_n   int;
  cap      numeric;
  new_id   uuid;
  made     text[] := '{}';
  v_id     uuid;
  i        int;
  result   jsonb;
begin
  if coalesce(p_new_count, 0) = 0
     and coalesce(array_length(p_vessel_ids, 1), 0) = 0 then
    raise exception 'no bins were named and none were asked for, so there is nothing to add';
  end if;
  if coalesce(p_new_count, 0) < 0 or coalesce(p_new_count, 0) > 40 then
    raise exception '% is not a number of bins to register at once', p_new_count;
  end if;

  if lender is not null and p_owner_id is not null then
    raise exception
      'a bin is either on loan from % or owned by a party here, and this says both', lender;
  end if;

  if coalesce(p_new_count, 0) > 0 then
    if prefix = '' then
      raise exception 'new bins need something to be called';
    end if;
    if p_new_type_id is null then
      raise exception 'new bins need a type, so the scale knows what they weigh empty';
    end if;
    if not exists (
      select 1 from term
       where id = p_new_type_id and kind = 'vessel_type'
         and coalesce((attributes ->> 'intake_bin')::boolean, false)
    ) then
      raise exception 'that is not a picking bin type, so fruit is not weighed in it';
    end if;

    bag := '{}'::jsonb;
    if lender is not null then
      bag := jsonb_build_object('borrowed', true, 'on_loan_from', lender);
    elsif p_owner_id is not null and p_owner_id is distinct from facility_party_id() then
      bag := jsonb_build_object('borrowed', true);
    end if;

    select coalesce(max((regexp_match(v.name, '^' || prefix || '\s*(\d+)$'))[1]::int), 0) + 1
      into next_n
      from vessel v
     where v.name ~ ('^' || prefix || '\s*\d+$');

    select v.capacity_l into cap
      from vessel v
     where v.type_id = p_new_type_id
     order by v.created_at desc
     limit 1;

    for i in 0 .. p_new_count - 1
    loop
      new_id := gen_random_uuid();
      insert into vessel (id, type_id, name, capacity_l, owner_id, attributes)
      values (new_id, p_new_type_id, prefix || (next_n + i)::text, cap,
              p_owner_id, bag);
      made := made || (prefix || (next_n + i)::text);
      p_vessel_ids := coalesce(p_vessel_ids, '{}'::uuid[]) || new_id;
    end loop;
  end if;

  -- The same figure into each bin, because they went out together and nobody
  -- fills one to 900 and the next to 400 on purpose. A bin that differs gets
  -- corrected on its own afterwards.
  foreach v_id in array p_vessel_ids
  loop
    result := add_bin_to_pick(p_pick || jsonb_build_object('id', pick_id), v_id,
                              p_fill_pct, p_fruit_lbs);
    pick_id := (result ->> 'node_id')::uuid;
  end loop;

  return jsonb_build_object(
    'node_id',    pick_id,
    'registered', to_jsonb(made),
    'bins',       (select count(*) from placement
                    where node_id = pick_id and to_at is null),
    'unweighed',  (select count(*) from unweighed_bin where node_id = pick_id)
  );
end;
$$;

drop function if exists add_bins_to_pick(jsonb, uuid[], int, uuid, text, numeric, uuid, text);

revoke all on function add_bin_to_pick(jsonb, uuid, numeric, numeric) from public;
grant execute on function add_bin_to_pick(jsonb, uuid, numeric, numeric) to authenticated;
revoke all on function add_bins_to_pick(jsonb, uuid[], int, uuid, text, numeric, uuid, text, numeric) from public;
grant execute on function add_bins_to_pick(jsonb, uuid[], int, uuid, text, numeric, uuid, text, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Reading it, in whichever unit somebody wants
-- ---------------------------------------------------------------------------

-- Pounds, percent and tons, from whichever one was said. A short ton, 2000
-- pounds, because that is what a Willamette Valley tonnage contract is written
-- in and there is no reason for this app to have an opinion of its own.
create or replace view bin_fruit with (security_invoker = true) as
select
  p.id           as placement_id,
  p.vessel_id,
  v.name         as bin,
  p.node_id,
  n.name         as pick,
  p.from_at,
  p.fruit_lbs    as said_lbs,
  p.fill_pct     as said_pct,
  nullif((vt.attributes ->> 'full_lbs')::numeric, 0) as full_lbs,
  -- The pounds, however they were arrived at. Null when somebody gave a
  -- percentage and nobody has said what a full bin holds, which is a real
  -- state: the honest answer is then that nobody knows.
  coalesce(
    p.fruit_lbs,
    round(p.fill_pct / 100.0 * nullif((vt.attributes ->> 'full_lbs')::numeric, 0), 0)
  )              as lbs,
  coalesce(
    p.fill_pct,
    round(p.fruit_lbs / nullif((vt.attributes ->> 'full_lbs')::numeric, 0) * 100, 0)
  )              as pct_full,
  round(
    coalesce(
      p.fruit_lbs,
      p.fill_pct / 100.0 * nullif((vt.attributes ->> 'full_lbs')::numeric, 0)
    ) / 2000.0, 3)  as tons,
  -- Which half a person actually gave, so a screen can show the figure somebody
  -- typed rather than the one it worked out.
  case
    when p.fruit_lbs is not null then 'lbs'
    when p.fill_pct is not null then 'pct'
  end            as said_as
from placement p
join vessel v on v.id = p.vessel_id
join term vt on vt.id = v.type_id
  and coalesce((vt.attributes ->> 'intake_bin')::boolean, false)
left join node n on n.id = p.node_id
where p.to_at is null;

comment on view bin_fruit is
  'What is in each full picking bin, in pounds, percent and tons, from whichever '
  'one somebody said. An estimate until the scale: see S-84. Tons are short '
  'tons of 2000 pounds. See 0087.';

grant select on bin_fruit to authenticated;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.bin_fruit', 'cellar', 'Fruit in bins',
   'How much is in each bin that has fruit in it, in pounds, percent and tons.',
   'bin_fruit', 'placement_id', 'bin', 165)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

commit;
