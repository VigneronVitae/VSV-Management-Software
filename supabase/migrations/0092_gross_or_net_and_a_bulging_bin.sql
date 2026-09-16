-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A bin's weight says whether it is the fruit or the fruit and the
--           bin, because a scale shows one and the record wants the other, and
--           a bin can be filled past a nominal full one."
-- Depends on: [supabase/migrations/0087_a_bin_holds_pounds.sql,
--              supabase/migrations/0042_weighing_photo.sql,
--              supabase/migrations/0089_correcting_one_bin.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0093_a_guess_is_not_a_weight.sql]
-- Axioms enforced: A13 (a number whose unit is ambiguous is a number that is
--                  wrong about a tenth of the time and never says so), T0-2
--                  (whichever of the three was said is stored and the rest are
--                  derived)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker, stopping a build mid-flight: *"it should be very clear whether
-- the measurement is the net weight or fruit weight."* And before that, looking
-- at five bins reading 850: *"the picking bins have the wrong weights. It
-- shouldn't be capped at 850 if that's the problem."* And, pointing at a scale
-- display in his own photograph: *"that weight is 923."*
--
-- **This is the more serious of the two and it is mine.** `0087` put
-- `fruit_lbs` on a placement and asked a screen for "Fruit in each bin, lbs".
-- Somebody standing at a pallet scale reads 923 and types 923, and 923 is the
-- bin **and** the fruit. The bin weighs 92. So the record would say a bin held
-- 923 pounds of Chardonnay when it held 831, and nothing anywhere would notice,
-- because both numbers are plausible and only one of them is a weight anybody
-- measured.
--
-- **The app already had the right words and this column sat outside them.**
-- `weigh_bins` has taken a gross since `0042`, subtracted the bins' tare from
-- the vessel type, and recorded gross, tare and net. Net is the fruit. So the
-- column is renamed to `net_lbs`, a `gross_lbs` joins it, and exactly one of
-- gross, net and percent may be set: whichever somebody actually said.
--
-- Renaming costs nothing today, which is the only reason it is done now: every
-- bin in the cellar carries a percentage and not one carries pounds.
--
-- **And the cap.** `fill_pct` has been capped at a hundred since `0033`, which
-- is right for a tank and wrong for a picking bin: bins are routinely filled
-- past their nominal, which is what bulging means. Pounds were never capped and
-- were not what went wrong; what went wrong is that the entry box **pre-filled
-- 850**, so five bins recorded without anybody typing a weight came out reading
-- a weight. That is the prefilled box `0049` refused to build for vintages,
-- repeated in the field where the number is the entire point. Removed in the
-- same phase as this.

begin;

-- Guarded so the file can be run against a database that has already had it.
-- Every other statement here is already re-runnable and this one was not, which
-- is the difference between fixing a mistake in place and rebuilding from
-- empty to find out whether the fix worked.
do $$ begin
  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'placement'
       and column_name = 'fruit_lbs'
  ) then
    alter table placement rename column fruit_lbs to net_lbs;
  end if;
end $$;

alter table placement add column if not exists gross_lbs numeric(10,2);

comment on column placement.net_lbs is
  'Pounds of fruit in this bin, the bin itself not counted. Net, in the sense '
  'weigh_bins has used since 0042. Null when somebody gave a gross or a '
  'percentage instead. See 0092.';

comment on column placement.gross_lbs is
  'What the scale showed with the bin on it. The fruit is this minus the bin''s '
  'tare, which lives on the vessel type. Null when somebody gave the net or a '
  'percentage instead. See 0092.';

alter table placement drop constraint if exists placement_fruit_lbs_is_a_weight;
alter table placement drop constraint if exists placement_says_pounds_or_percent;

alter table placement drop constraint if exists placement_weights_are_weights;
alter table placement add constraint placement_weights_are_weights
  check ((net_lbs is null or net_lbs > 0) and (gross_lbs is null or gross_lbs > 0));

-- Exactly one, or none. Three ways to say how much is in a bin and no way to
-- say which of them somebody meant is the defect this migration exists for.
alter table placement drop constraint if exists placement_says_one_amount;
alter table placement add constraint placement_says_one_amount
  check (
    (case when net_lbs   is not null then 1 else 0 end)
  + (case when gross_lbs is not null then 1 else 0 end)
  + (case when fill_pct  is not null then 1 else 0 end) <= 1
  );

alter table placement drop constraint if exists placement_fill_pct_is_a_percentage;
alter table placement add constraint placement_fill_pct_is_a_percentage
  check (fill_pct is null or (fill_pct > 0 and fill_pct <= 200));

comment on constraint placement_fill_pct_is_a_percentage on placement is
  'How full, which for a picking bin can exceed a nominal full one because bins '
  'are filled bulging. The upper bound catches a weight typed into a percent '
  'box rather than describing a vessel. See 0033 and 0092.';

-- ---------------------------------------------------------------------------
-- Reading it, with the tare named
-- ---------------------------------------------------------------------------

-- `create or replace view` cannot rename a column, and `said_lbs` has to become
-- `said_net` because it no longer means "the pounds" but "the pounds somebody
-- gave as the fruit". Two views read this one, so all three go and come back in
-- order rather than one being replaced under the others.
drop view if exists bin_fruit cascade;

create view bin_fruit with (security_invoker = true) as
select
  p.id           as placement_id,
  p.vessel_id,
  v.name         as bin,
  p.node_id,
  n.name         as pick,
  p.from_at,
  p.net_lbs      as said_net,
  p.gross_lbs    as said_gross,
  p.fill_pct     as said_pct,
  nullif((vt.attributes ->> 'full_lbs')::numeric, 0) as full_lbs,
  -- The bin itself, from the vessel type, the same figure weigh_bins subtracts.
  nullif((vt.attributes ->> 'tare_lbs')::numeric, 0) as tare_lbs,
  -- The fruit, however it was arrived at. A gross has the bin taken off it; a
  -- percentage is multiplied by a nominal and is the only one of the three that
  -- nobody measured.
  coalesce(
    p.net_lbs,
    p.gross_lbs - nullif((vt.attributes ->> 'tare_lbs')::numeric, 0),
    round(p.fill_pct / 100.0 * nullif((vt.attributes ->> 'full_lbs')::numeric, 0), 0)
  )              as lbs,
  -- And what the scale would read with this bin on it, which is what somebody
  -- checks against a ticket.
  coalesce(
    p.gross_lbs,
    p.net_lbs + nullif((vt.attributes ->> 'tare_lbs')::numeric, 0),
    round(p.fill_pct / 100.0 * nullif((vt.attributes ->> 'full_lbs')::numeric, 0), 0)
      + nullif((vt.attributes ->> 'tare_lbs')::numeric, 0)
  )              as gross,
  coalesce(
    p.fill_pct,
    round(coalesce(p.net_lbs, p.gross_lbs - nullif((vt.attributes ->> 'tare_lbs')::numeric, 0))
          / nullif((vt.attributes ->> 'full_lbs')::numeric, 0) * 100, 0)
  )              as pct_full,
  round(
    coalesce(
      p.net_lbs,
      p.gross_lbs - nullif((vt.attributes ->> 'tare_lbs')::numeric, 0),
      p.fill_pct / 100.0 * nullif((vt.attributes ->> 'full_lbs')::numeric, 0)
    ) / 2000.0, 3)  as tons,
  -- Which of the three a person actually gave, so a screen shows the figure
  -- somebody typed and says what the others were worked out from.
  case
    when p.net_lbs   is not null then 'net'
    when p.gross_lbs is not null then 'gross'
    when p.fill_pct  is not null then 'pct'
  end            as said_as
from placement p
join vessel v on v.id = p.vessel_id
join term vt on vt.id = v.type_id
  and coalesce((vt.attributes ->> 'intake_bin')::boolean, false)
left join node n on n.id = p.node_id
where p.to_at is null;

-- The tare is read off the vessel type here rather than through
-- `bin_tare_lbs`, which refuses a bin type that has not set one. That refusal
-- is right at a scale and wrong in a view: a view that raises makes every read
-- of it fail, including the ones that do not care about the tare. The write
-- paths keep the refusal, which is where it belongs.
comment on view bin_fruit is
  'What is in each full picking bin. `lbs` is the fruit with the bin not '
  'counted and `gross` is what a scale would read with the bin on it, from '
  'whichever of net, gross or percent somebody said. An estimate until the '
  'scale: see S-84. See 0087 and 0092.';

-- ---------------------------------------------------------------------------
-- And the two that were cascaded away, back in dependency order
-- ---------------------------------------------------------------------------

create view pick_bin with (security_invoker = true) as
select
  n.id            as node_id,
  n.name          as pick,
  n.status::text  as status,
  v.id            as vessel_id,
  v.name          as bin,
  bf.lbs,
  bf.gross,
  bf.tare_lbs,
  bf.tons,
  bf.said_as,
  bf.pct_full,
  p.from_at
from node n
join placement p on p.node_id = n.id and p.to_at is null
join vessel v on v.id = p.vessel_id
join term vt on vt.id = v.type_id
  and coalesce((vt.attributes ->> 'intake_bin')::boolean, false)
left join bin_fruit bf on bf.placement_id = p.id
where n.stage = 'bin';


comment on view pick_bin is
  'The bins still holding fruit, by pick, with what is in each. What a press '
  'screen offers once somebody has chosen a pick. See 0090.';

grant select on pick_bin to authenticated;

create view vessel_state with (security_invoker = true) as
 SELECT v.id,
    v.type_id,
    vt.label AS type,
    v.name,
    v.capacity_l,
    v.owner_id,
    COALESCE(o.name, NULLIF(btrim(v.attributes ->> 'on_loan_from'), '')) AS owner_name,
    v.owner_id IS NULL
      AND NOT COALESCE((v.attributes ->> 'borrowed')::boolean, false) AS facility_owned,
    v.has_glycol,
    v.setpoint_c,
    v.mode,
    v.attributes,
    l.name AS location_name,
    COALESCE(
        CASE
            WHEN v.has_glycol AND v.mode <> 'off'::thermal_mode THEN v.setpoint_c
            ELSE NULL::numeric
        END, l.ambient_c) AS effective_temp_c,
    p.node_id,
    n.name AS lot_name,
    n.variety_id,
    nv.label AS variety,
    n.vintage,
    n.product_type_id,
    np.label AS product_type,
    n.owner_id AS lot_owner_id,
    p.volume_l AS current_volume_l,
    p.from_at AS filled_at,
    p.node_id IS NULL AS is_empty,
    ( SELECT array_agg(c.code ORDER BY c.added_at) AS array_agg
           FROM vessel_code c
          WHERE c.vessel_id = v.id AND c.active) AS codes,
    lo.name AS lot_owner_name,
    n.owner_id IS NOT NULL AND n.owner_id = facility_party_id() AS lot_facility_owned,
    COALESCE(cardinality(n.hidden), 0) > 0 AND NOT may_see_all_of(n.owner_id, n.hidden) AS redacted,
    l.ambient_c AS location_ambient_c,
    l.controlled AS location_controlled,
    -- 0091. Fruit is weighed, not measured in litres, so a picking bin's
    -- quantity lives here and null everywhere else. Resolved from whichever
    -- half somebody said, which is bin_fruit's job and not a second copy of
    -- its arithmetic.
    ( SELECT bf.lbs FROM bin_fruit bf WHERE bf.placement_id = p.id) AS fruit_lbs,
    ( SELECT bf.tons FROM bin_fruit bf WHERE bf.placement_id = p.id) AS fruit_tons,
    -- How full, so the map can draw a bin's fill height without the client
    -- knowing what a full bin holds. A screen dividing pounds by 850 would be a
    -- client holding a rule that lives on the vessel type, which is the one
    -- thing this repository is most explicit about.
    ( SELECT bf.pct_full FROM bin_fruit bf WHERE bf.placement_id = p.id) AS fruit_pct
   FROM vessel v
     JOIN term vt ON vt.id = v.type_id
     LEFT JOIN location l ON l.id = v.location_id
     LEFT JOIN party o ON o.id = v.owner_id
     LEFT JOIN placement p ON p.vessel_id = v.id AND p.to_at IS NULL
     LEFT JOIN LATERAL ( SELECT visible_node.id,
            visible_node.stage,
            visible_node.status,
            visible_node.vintage,
            visible_node.block_id,
            visible_node.name,
            visible_node.quantity,
            visible_node.unit,
            visible_node.attributes,
            visible_node.provenance,
            visible_node.closed_at,
            visible_node.created_at,
            visible_node.created_by,
            visible_node.owner_id,
            visible_node.variety_id,
            visible_node.variety_kind,
            visible_node.product_type_id,
            visible_node.product_kind,
            visible_node.hidden
           FROM visible_node(p.node_id) visible_node(id, stage, status, vintage, block_id, name, quantity, unit, attributes, provenance, closed_at, created_at, created_by, owner_id, variety_id, variety_kind, product_type_id, product_kind, hidden)) n ON p.node_id IS NOT NULL
     LEFT JOIN term nv ON nv.id = n.variety_id
     LEFT JOIN term np ON np.id = n.product_type_id
     LEFT JOIN party lo ON lo.id = n.owner_id
  WHERE v.active;


comment on view vessel_state is
  'Every active vessel and what is in it. fruit_lbs is the fruit in a picking '
  'bin with the bin itself not counted. See 0081, 0091 and 0092.';

-- **A cascade takes more than views.** `resolve_vessel_code` returns `setof
-- vessel_state`, so it holds a dependency on the view's row type and went with
-- it. `0004` knew this and dropped it by hand before touching the view; this
-- migration used cascade and lost it silently, which the assertion suite caught
-- nineteen assertions in. It comes back unchanged.
create or replace function resolve_vessel_code(p_code text)
returns setof vessel_state
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
  select vs.*
    from vessel_state vs
    join vessel_code c on c.vessel_id = vs.id
   where c.code = p_code and c.active;
$$;

revoke all on function resolve_vessel_code(text) from public;
grant execute on function resolve_vessel_code(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Saying it
-- ---------------------------------------------------------------------------

create or replace function set_bin_fruit(
  p_vessel_id uuid,
  p_net_lbs   numeric default null,
  p_fill_pct  numeric default null,
  p_gross_lbs numeric default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  pl   placement%rowtype;
  nm   text;
  said int;
  tare numeric;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here says what is in a bin'
      using errcode = 'insufficient_privilege';
  end if;

  said := (case when p_net_lbs is not null then 1 else 0 end)
        + (case when p_gross_lbs is not null then 1 else 0 end)
        + (case when p_fill_pct is not null then 1 else 0 end);
  if said = 0 then
    raise exception 'say how much is in it';
  end if;
  if said > 1 then
    raise exception
      'say one of them: the fruit, the scale reading with the bin on it, or how full. The others are worked out';
  end if;

  if p_net_lbs is not null and p_net_lbs <= 0 then
    raise exception 'a bin with no fruit in it is empty, and emptying a bin is a different act';
  end if;
  if p_fill_pct is not null and (p_fill_pct <= 0 or p_fill_pct > 200) then
    raise exception
      '% is not how full a bin is. If that is a weight, say it in pounds', p_fill_pct;
  end if;

  select p.* into pl
    from placement p
    join vessel v on v.id = p.vessel_id
    join term vt on vt.id = v.type_id
     and coalesce((vt.attributes ->> 'intake_bin')::boolean, false)
   where p.vessel_id = p_vessel_id and p.to_at is null;

  if pl.id is null then
    raise exception
      'that bin has nothing in it, or it is not a picking bin, so there is no amount to correct';
  end if;

  -- A gross that does not clear the bin is a bin being weighed empty, or a
  -- tare that is wrong, and either way the fruit is not a negative number.
  if p_gross_lbs is not null then
    tare := bin_tare_lbs(p_vessel_id);
    if p_gross_lbs <= tare then
      raise exception
        'that bin weighs % empty, so a scale reading of % has no fruit in it',
        tare, p_gross_lbs;
    end if;
  end if;

  update placement
     set net_lbs   = p_net_lbs,
         gross_lbs = p_gross_lbs,
         fill_pct  = p_fill_pct
   where id = pl.id;

  select name into nm from vessel where id = p_vessel_id;

  return jsonb_build_object(
    'vessel', p_vessel_id, 'bin', nm,
    'lbs',   (select lbs   from bin_fruit where placement_id = pl.id),
    'gross', (select gross from bin_fruit where placement_id = pl.id),
    'tare',  (select tare_lbs from bin_fruit where placement_id = pl.id),
    'tons',  (select tons  from bin_fruit where placement_id = pl.id));
end;
$$;

drop function if exists set_bin_fruit(uuid, numeric, numeric);

revoke all on function set_bin_fruit(uuid, numeric, numeric, numeric) from public;
grant execute on function set_bin_fruit(uuid, numeric, numeric, numeric) to authenticated;

update capability
   set note = 'The fruit, or the scale reading with the bin on it, or how full. '
              'Say one and the rest are worked out from the bin''s tare.',
       fields = '[{"key":"bin","param":"p_vessel_id","type":"uuid","required":true,
                   "label":"Which bin",
                   "source":{"readable":"cellar.bin_fruit"}},
                  {"key":"net","param":"p_net_lbs","type":"numeric","required":false,
                   "label":"Fruit only, lbs"},
                  {"key":"gross","param":"p_gross_lbs","type":"numeric","required":false,
                   "label":"With the bin on the scale, lbs"},
                  {"key":"pct","param":"p_fill_pct","type":"numeric","required":false,
                   "label":"Or how full, percent"}]'::jsonb
 where key = 'cellar.set_bin_fruit';

-- ---------------------------------------------------------------------------
-- The two that write it
-- ---------------------------------------------------------------------------

-- Taken from 0087 and changed where the rename touches them, rather than
-- retyped. That rule was earned by 0027 and paid for again by 0040.
create or replace function add_bin_to_pick(
  p_pick       jsonb,
  p_vessel_id  uuid,
  p_fill_pct   numeric default null,
  p_net_lbs    numeric default null,
  p_gross_lbs  numeric default null
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
  -- 0092. Three ways to say how much, and exactly one of them. A number whose
  -- unit is ambiguous is wrong about a tenth of the time and never says so:
  -- somebody at a pallet scale reads 923 and that is the bin as well as the
  -- fruit.
  if (case when p_net_lbs is not null then 1 else 0 end)
   + (case when p_gross_lbs is not null then 1 else 0 end)
   + (case when p_fill_pct is not null then 1 else 0 end) > 1 then
    raise exception
      'say one of them: the fruit, the scale reading with the bin on it, or how full. The others are worked out';
  end if;
  if p_net_lbs is not null and p_net_lbs <= 0 then
    raise exception 'a bin with no fruit in it is not part of a pick';
  end if;
  if p_gross_lbs is not null and p_gross_lbs <= bin_tare_lbs(p_vessel_id) then
    raise exception
      'that bin weighs % empty, so a scale reading of % has no fruit in it',
      bin_tare_lbs(p_vessel_id), p_gross_lbs;
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

  insert into placement (id, node_id, vessel_id, fill_pct, net_lbs, gross_lbs)
  values (place_id, pick_id, p_vessel_id, p_fill_pct, p_net_lbs, p_gross_lbs);

  return jsonb_build_object(
    'node_id',      pick_id,
    'placement_id', place_id,
    'bins',         (select count(*) from placement
                      where node_id = pick_id and to_at is null),
    'unweighed',    (select count(*) from unweighed_bin where node_id = pick_id)
  );
end;
$$;


create or replace function add_bins_to_pick(
  p_pick         jsonb,
  p_vessel_ids   uuid[]  default null,
  p_new_count    int     default 0,
  p_new_type_id  uuid    default null,
  p_name_prefix  text    default null,
  p_fill_pct     numeric default null,
  p_owner_id     uuid    default null,
  p_on_loan_from text    default null,
  p_net_lbs      numeric default null,
  p_gross_lbs    numeric default null
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
                              p_fill_pct, p_net_lbs, p_gross_lbs);
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


drop function if exists add_bin_to_pick(jsonb, uuid, numeric, numeric);
drop function if exists add_bins_to_pick(jsonb, uuid[], int, uuid, text, numeric, uuid, text, numeric);

revoke all on function add_bin_to_pick(jsonb, uuid, numeric, numeric, numeric) from public;
grant execute on function add_bin_to_pick(jsonb, uuid, numeric, numeric, numeric) to authenticated;
revoke all on function add_bins_to_pick(jsonb, uuid[], int, uuid, text, numeric, uuid, text, numeric, numeric) from public;
grant execute on function add_bins_to_pick(jsonb, uuid[], int, uuid, text, numeric, uuid, text, numeric, numeric) to authenticated;

commit;
