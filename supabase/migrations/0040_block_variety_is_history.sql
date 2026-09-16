-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "0039 left block.variety behind to preserve what somebody typed, and
--           left it NOT NULL, which meant no new block could be created at all."
-- Depends on: [supabase/migrations/0039_vineyard.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0041_daily_log.sql,
--                  supabase/migrations/0087_a_bin_holds_pounds.sql]
-- Axioms enforced: none. This is a defect fix.
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- `0039` moved a block's variety into the `planting` table, and kept the old
-- text column on the reasoning that a label matching no variety in the
-- vocabulary is still the only record of what was typed. That reasoning is
-- right. What it missed is that the column was declared `not null` when blocks
-- were created with a variety, and nothing writes it any more.
--
-- **So every attempt to add a block failed**, including the inline one on the
-- intake screen, which is on the path somebody uses at the scale. It was live
-- for the length of one migration and found by a fixture rather than by the
-- winemaker, which is the only good thing about it.
--
-- The column keeps its history and stops being required. A superseded column
-- that still refuses writes is worse than either dropping it or keeping it: it
-- is a rule nobody meant to still be enforcing.

begin;

alter table block alter column variety drop not null;

comment on column block.variety is
  'Superseded by the planting table in 0039 and kept because a label that '
  'matched no variety in the vocabulary is still the only record of what was '
  'typed. Nullable since 0040, because nothing writes it and requiring it made '
  'every new block impossible. Read planting_detail instead.';

-- ---------------------------------------------------------------------------
-- The pick name, which read a column that had moved
-- ---------------------------------------------------------------------------

-- Same migration, same cause. `add_bin_to_pick` builds a pick's name from its
-- block, and did it with `b.vineyard`, which `0039` turned into a table. Adding
-- a bin to a pick that already exists was unaffected, because the name is only
-- built when the pick is created, so this was invisible until somebody started
-- a new pick against a block. That is the worst shape a defect on the intake
-- path can have: it works all morning and fails on the next load of fruit.
--
-- Found by the assertion suite rather than in the vineyard. Taken from the
-- catalog and changed in one clause rather than retyped, per the rule 0027
-- earned.

create or replace function add_bin_to_pick(p_pick jsonb, p_vessel_id uuid, p_fill_pct numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  pick_id   uuid := coalesce((p_pick ->> 'id')::uuid, gen_random_uuid());
  existing  node%rowtype;
  holder    uuid;
  place_id  uuid := gen_random_uuid();
  auto_name text;
  blk_name  text;
  var_label text;
begin
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
    -- Vineyard and block, because a block called "Block 3" is not a place until
    -- you know whose Block 3 it is, and two growers both having one is normal.
    -- 0040. Was `concat_ws(' ', b.vineyard, b.name)`, reading a column 0039
    -- moved into its own table. Starting a new pick against a block would have
    -- raised "column b.vineyard does not exist" at the scale, which is the one
    -- place this schema promised not to fail.
    select concat_ws(' ', v.name, b.name) into blk_name
      from block b
      left join vineyard v on v.id = b.vineyard_id
     where b.id = (p_pick ->> 'block_id')::uuid;
    select t.label into var_label from term t
     where t.kind = 'variety' and t.id = (p_pick ->> 'variety_id')::uuid;

    -- "2026 Pinot Gris Royer 3, Sep 14". The winemaker picked the long form:
    -- nothing ever collides, and the name carries the one fact you would
    -- otherwise have to open the record to see.
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
       -- moment T1-4 exists to protect.
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

  insert into placement (id, node_id, vessel_id, fill_pct)
  values (place_id, pick_id, p_vessel_id, p_fill_pct);

  return jsonb_build_object(
    'node_id',      pick_id,
    'placement_id', place_id,
    'bins',         (select count(*) from placement
                      where node_id = pick_id and to_at is null),
    'unweighed',    (select count(*) from unweighed_bin where node_id = pick_id)
  );
end;
$function$;

commit;
