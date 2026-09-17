-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A lot is of a year or is explicitly non-vintage, and the third
--           state, nobody said, stops existing."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0033_intake.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0071_a_wine_says_its_colour.sql,
--                  supabase/migrations/0099_a_vessel_says_which_vintage.sql,
--                  supabase/migrations/0103_racking_keeps_what_was_already_there.sql]
-- Axioms enforced: A25 (a null that permits is the class this closes: blank
--                  meant both "non-vintage" and "nobody got round to it")
-- Open sorries: S-69 (the constraint is not valid, so rows older than it are
--                grandfathered)
-- ---------------------------------------------------------------------------
--
-- An outside reading of the export found `2024 Eola Springs` carrying no
-- vintage, with the year only in its name, and said that vintage searches and
-- blending checks would silently miss it. True, and the silence is the part that
-- matters.
--
-- Put to the winemaker as a question rather than fixed, because whether a lot
-- may have no vintage is winery practice and not a schema preference. His
-- answer: **"They should always have a vintage, including NV."**
--
-- So there are two legitimate states and there were three. A lot is of a year,
-- or it is a non-vintage wine, and both of those are somebody saying something.
-- Blank was doing duty for both of them plus a third thing, which is nobody
-- having got round to it, and a field that means three things including "unknown"
-- cannot be reported on. That is A25's class exactly: a null that permits.
--
-- **NV is not a year, so it is not in the year column.** Widening `vintage` to
-- text to hold the string 'NV' would make every comparison and every sort a
-- special case, and would put a value that is not a number in a column every
-- report does arithmetic on. Two columns and a check that exactly one of them
-- speaks is the shape that keeps a year a year.
--
-- **Not valid, on purpose.** One lot in the cellar violates this today. The
-- constraint therefore applies to every insert and every update from now and
-- leaves that row alone, which means the rule is real for everything anybody
-- does next and the existing gap stays visible instead of being papered over.
-- The alternative was to read 2024 off the lot's own name and write it, which is
-- inventing a fact about somebody's wine from a string. `lot_without_vintage`
-- below is how it gets cleared, by the person who knows. S-69.

begin;

alter table node
  add column if not exists non_vintage boolean not null default false;

comment on column node.non_vintage is
  'This lot is a non-vintage wine, deliberately. Exactly one of this and '
  '`vintage` says something: a year means a vintage wine, this flag means NV, '
  'and neither is refused. See 0049.';

-- Exactly one of the two speaks. A year with the NV flag set is as wrong as
-- neither, and both directions are worth refusing: the first is a contradiction
-- and the second is the silence this migration exists to end.
alter table node drop constraint if exists node_says_its_vintage;
alter table node
  add constraint node_says_its_vintage
  check ((vintage is null) = non_vintage)
  not valid;

-- ---------------------------------------------------------------------------
-- The ones that predate the rule
-- ---------------------------------------------------------------------------

-- A derived worklist, which is how everything else in this system catches what
-- it cannot refuse. The list is the whole of the difference between a gap that
-- gets closed and a gap that is discovered in March: nothing here nags, and
-- nothing here is hidden either.
create or replace view lot_without_vintage with (security_invoker = true) as
select
  n.id,
  n.name,
  n.stage,
  n.status,
  n.created_at,
  -- Offered, never written. A lot called "2024 Eola Springs" is almost certainly
  -- a 2024, and almost certainly is not a thing a database may decide on
  -- somebody's behalf. The screen shows this beside an empty box; a person
  -- either agrees with it or does not.
  (regexp_match(n.name, '\y(19|20)\d{2}\y'))[1] is not null as year_in_the_name,
  substring(n.name from '\y((?:19|20)\d{2})\y') as suggested_year
from node n
where n.vintage is null
  and n.non_vintage = false;

comment on view lot_without_vintage is
  'Lots that predate the rule in 0049 and say neither a year nor NV. '
  '`suggested_year` is read off the lot name and is a suggestion for a person '
  'to accept or reject, never a value anything writes. See 0049 and S-69.';

-- ---------------------------------------------------------------------------
-- Saying which
-- ---------------------------------------------------------------------------

-- One blessed way to answer, so that the refusal is a sentence rather than a
-- constraint name arriving in front of somebody standing at a press. The check
-- constraint is the guarantee; this is the voice.
create or replace function set_vintage(
  p_node_id     uuid,
  p_vintage     int default null,
  p_non_vintage boolean default false
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare n node%rowtype;
begin
  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no lot with id %', p_node_id;
  end if;

  if p_non_vintage and p_vintage is not null then
    raise exception
      'a lot is either of % or non-vintage, and this says both', p_vintage;
  end if;
  if not p_non_vintage and p_vintage is null then
    raise exception
      'say which year this is, or say it is non-vintage; leaving it blank is what this is replacing';
  end if;
  -- A year outside living memory of this winery is a typo rather than a lot.
  -- 1800 catches a mistyped 18 and 2200 catches a mistyped century, and neither
  -- refuses anything a person could legitimately mean.
  if p_vintage is not null and (p_vintage < 1800 or p_vintage > 2200) then
    raise exception '% is not a vintage year', p_vintage;
  end if;

  update node
     set vintage = p_vintage,
         non_vintage = p_non_vintage
   where id = p_node_id;

  return jsonb_build_object(
    'id', p_node_id,
    'vintage', p_vintage,
    'non_vintage', p_non_vintage,
    'left', (select count(*) from lot_without_vintage)
  );
end;
$$;

revoke all on function set_vintage(uuid, int, boolean) from public;
grant execute on function set_vintage(uuid, int, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Carrying it, everywhere a lot is made from another lot
-- ---------------------------------------------------------------------------
--
-- Six functions insert a node and every one of them had to be told. Adding the
-- constraint without this would have refused the first press of a non-vintage
-- lot, which is the worst possible day to find out.
--
-- **Two of them turn out to answer a question this schema could not previously
-- ask.** `press` and `rack` already said "one vintage if the parents agree, and
-- null if they do not", and that null was exactly the silence being closed here.
-- A wine made of two vintages is a non-vintage wine. So the shape that used to
-- be a gap is now the shape that says what it is, and a blend across vintages
-- stops being a lot with a blank field.
--
-- `count(distinct)` skips nulls, which is the trap: an NV parent and a 2024
-- parent would otherwise count as one distinct vintage and produce a 2024 child.
-- The `bool_and(not non_vintage)` is what stops that.
--
-- Taken from the catalog and changed in one clause each rather than retyped.
-- That rule was earned by 0027 and paid for again by 0040, and the script that
-- did it refuses unless every pattern matches exactly once, so a body that has
-- moved fails loudly instead of producing a function nobody meant.

CREATE OR REPLACE FUNCTION public.add_bin_to_pick(p_pick jsonb, p_vessel_id uuid, p_fill_pct numeric DEFAULT NULL::numeric)
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
      (id, stage, status, name, variety_id, vintage, non_vintage, block_id,
       quantity, unit, attributes, owner_id, created_by)
    values
      (pick_id, 'bin', 'open',
       coalesce(nullif(p_pick ->> 'name', ''), auto_name,
                'Pick ' || to_char(now(), 'YYYY-MM-DD')),
       (p_pick ->> 'variety_id')::uuid,
       (p_pick ->> 'vintage')::int,
       -- 0049.
       coalesce((p_pick ->> 'non_vintage')::boolean, false),
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

CREATE OR REPLACE FUNCTION public.create_vessel_with_wine(p_vessel jsonb, p_node jsonb, p_volume_l numeric DEFAULT NULL::numeric, p_codes jsonb DEFAULT '[]'::jsonb, p_generate_history boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_id        uuid := coalesce((p_vessel ->> 'id')::uuid, gen_random_uuid());
  n_id        uuid := coalesce((p_node   ->> 'id')::uuid, gen_random_uuid());
  p_id        uuid := gen_random_uuid();
  code        jsonb;
  generated   int := 0;
begin
  insert into vessel
    (id, type_id, name, capacity_l, location_id, owner_id, attributes,
     has_glycol, setpoint_c, mode)
  values
    (v_id,
     (p_vessel ->> 'type_id')::uuid,
      p_vessel ->> 'name',
     (p_vessel ->> 'capacity_l')::numeric,
     (p_vessel ->> 'location_id')::uuid,
     (p_vessel ->> 'owner_id')::uuid,
      coalesce(p_vessel -> 'attributes', '{}'::jsonb),
      coalesce((p_vessel ->> 'has_glycol')::boolean, false),
     (p_vessel ->> 'setpoint_c')::numeric,
      coalesce((p_vessel ->> 'mode')::thermal_mode, 'off'));

  insert into node
    (id, stage, status, name, variety_id, vintage, non_vintage, product_type_id,
     quantity, unit, attributes, owner_id, created_by)
  values
    (n_id,
     coalesce((p_node ->> 'stage')::node_stage, 'maturation'),
     'open',
      p_node ->> 'name',
     (p_node ->> 'variety_id')::uuid,
     (p_node ->> 'vintage')::int,
     -- 0049. False unless the caller says otherwise, and the check
     -- constraint then refuses a lot that says neither.
     coalesce((p_node ->> 'non_vintage')::boolean, false),
      coalesce((p_node ->> 'product_type_id')::uuid, term_id('product_type', 'wine')),
     (p_node ->> 'quantity')::numeric,
      coalesce((p_node ->> 'unit')::quantity_unit, 'L'),
      coalesce(p_node -> 'attributes', '{}'::jsonb),
      coalesce((p_node ->> 'owner_id')::uuid, facility_party_id()),
      auth.uid());

  insert into placement (id, node_id, vessel_id, volume_l)
  values (p_id, n_id, v_id, p_volume_l);

  for code in select * from jsonb_array_elements(p_codes)
  loop
    perform bind_vessel_code(v_id, code ->> 'code', code ->> 'label');
  end loop;

  if p_generate_history then
    generated := generate_inferred_history(n_id);
  end if;

  return jsonb_build_object(
    'vessel_id',        v_id,
    'node_id',          n_id,
    'placement_id',     p_id,
    'events_generated', generated
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.fill_vessel(p_vessel_id uuid, p_node jsonb, p_volume_l numeric DEFAULT NULL::numeric, p_generate_history boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  n_id      uuid := coalesce((p_node ->> 'id')::uuid, gen_random_uuid());
  p_id      uuid := gen_random_uuid();
  occupied  uuid;
  generated int := 0;
begin
  if not exists (select 1 from vessel where id = p_vessel_id and active) then
    raise exception 'no active vessel with id %', p_vessel_id;
  end if;

  -- placement_one_lot_per_vessel would refuse this anyway, as a unique index
  -- violation naming an index. Saying it in words costs three lines and is the
  -- difference between a screen that explains and a screen that apologises.
  select node_id into occupied
    from placement
   where vessel_id = p_vessel_id and to_at is null;
  if occupied is not null then
    raise exception 'that vessel already holds a lot; rack it out before filling it';
  end if;

  insert into node
    (id, stage, status, name, variety_id, vintage, non_vintage, product_type_id,
     quantity, unit, attributes, owner_id, created_by)
  values
    (n_id,
     coalesce((p_node ->> 'stage')::node_stage, 'maturation'),
     'open',
      p_node ->> 'name',
     (p_node ->> 'variety_id')::uuid,
     (p_node ->> 'vintage')::int,
     -- 0049. False unless the caller says otherwise, and the check
     -- constraint then refuses a lot that says neither.
     coalesce((p_node ->> 'non_vintage')::boolean, false),
      coalesce((p_node ->> 'product_type_id')::uuid, term_id('product_type', 'wine')),
     (p_node ->> 'quantity')::numeric,
      coalesce((p_node ->> 'unit')::quantity_unit, 'L'),
      coalesce(p_node -> 'attributes', '{}'::jsonb),
      coalesce((p_node ->> 'owner_id')::uuid, facility_party_id()),
      auth.uid());

  insert into placement (id, node_id, vessel_id, volume_l)
  values (p_id, n_id, p_vessel_id, p_volume_l);

  if p_generate_history then
    generated := generate_inferred_history(n_id);
  end if;

  return jsonb_build_object(
    'vessel_id',        p_vessel_id,
    'node_id',          n_id,
    'placement_id',     p_id,
    'events_generated', generated
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.fork_lot(p_node_id uuid, p_vessel_ids uuid[], p_name text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  parent  node%rowtype;
  child   uuid := gen_random_uuid();
  moved   numeric;
  n_here  int;
  n_total int;
  label   text;
begin
  select * into parent from node where id = p_node_id;
  if not found then
    raise exception 'no lot with id %', p_node_id;
  end if;

  select count(*), sum(coalesce(volume_l, 0)) into n_here, moved
    from placement
   where node_id = p_node_id and to_at is null and vessel_id = any(p_vessel_ids);

  if n_here = 0 then
    raise exception 'none of those vessels hold that lot';
  end if;
  if n_here <> array_length(p_vessel_ids, 1) then
    raise exception 'some of those vessels do not hold that lot';
  end if;

  select count(*) into n_total
    from placement where node_id = p_node_id and to_at is null;

  if n_here = n_total then
    raise exception 'that is every vessel this lot is in, so there is nothing to fork it from';
  end if;

  select string_agg(v.name, ', ' order by v.name) into label
    from vessel v where v.id = any(p_vessel_ids);

  insert into node (id, stage, status, name, quantity, unit, variety_id, vintage,
                    non_vintage,
                    product_type_id, block_id, owner_id, attributes, created_by)
  values (child, parent.stage, 'open',
          coalesce(p_name, parent.name || ' / ' || label),
          moved, parent.unit, parent.variety_id, parent.vintage,
          -- 0049. Carried rather than defaulted: a child of a non-vintage
          -- parent is non-vintage, and defaulting it to false would make
          -- every fork of an NV lot fail the constraint instead.
          parent.non_vintage,
          parent.product_type_id, parent.block_id, parent.owner_id,
          parent.attributes, auth.uid());

  -- Wholly out of the parent, so 1.0. node_bin_shares multiplies along the
  -- path, and multiplying by one is how the child inherits every bin the parent
  -- had without a single row being copied.
  insert into lineage (parent_id, child_id, fraction) values (p_node_id, child, 1.0);

  update placement set node_id = child
   where node_id = p_node_id and to_at is null and vessel_id = any(p_vessel_ids);

  -- The parent is smaller, not spent. 0013 closes it only if this emptied it,
  -- which forking cannot do because a whole-lot fork is refused above.
  update node set quantity = greatest(coalesce(quantity, 0) - coalesce(moved, 0), 0)
   where id = p_node_id and quantity is not null;

  return child;
end;
$function$;

CREATE OR REPLACE FUNCTION public.press(p_sources jsonb, p_cuts jsonb, p_node jsonb DEFAULT '{}'::jsonb, p_detail jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  src          jsonb;
  cut          jsonb;
  dst          jsonb;
  n            node%rowtype;
  want         numeric;
  total_in     numeric := 0;
  total_out    numeric := 0;
  cut_out      numeric;
  parent_ids   uuid[] := '{}';
  weights      numeric[] := '{}';
  child_ids    uuid[] := '{}';
  child        uuid;
  i            int;
  child_stage  node_stage;
  parent_stage node_stage;
  waiting      int := 0;
  v_id         uuid;
  vol          numeric;
  held         numeric;
  emptied      int := 0;
  ev_id        uuid := gen_random_uuid();
  wc           numeric := (p_detail ->> 'whole_cluster_pct')::numeric;
  started      timestamptz := (p_detail ->> 'skin_contact_start')::timestamptz;
  ended        timestamptz := (p_detail ->> 'skin_contact_end')::timestamptz;
  ran_from     timestamptz := (p_detail ->> 'pressed_from')::timestamptz;
  ran_to       timestamptz := (p_detail ->> 'pressed_to')::timestamptz;
begin
  if p_sources is null or jsonb_array_length(p_sources) = 0 then
    raise exception 'nothing was named to press';
  end if;
  if p_cuts is null or jsonb_array_length(p_cuts) = 0 then
    raise exception 'the juice has to go somewhere; name at least one vessel';
  end if;

  if wc is not null and (wc < 0 or wc > 100) then
    raise exception 'whole cluster of % percent is not a proportion', wc;
  end if;
  -- Skins do not come off before they go on. A pair this way round is a typo
  -- somebody would otherwise find in March as a negative contact time.
  if started is not null and ended is not null and ended < started then
    raise exception 'skin contact ended before it started';
  end if;
  if ran_from is not null and ran_to is not null and ran_to < ran_from then
    raise exception 'the press finished before it started';
  end if;
  if (p_detail ->> 'program_id') is not null and not exists (
    select 1 from term
     where id = (p_detail ->> 'program_id')::uuid and kind = 'press_program'
  ) then
    raise exception 'that is not a press program';
  end if;

  -- Pass one: read the parents and decide what may be pressed. Nothing is
  -- written until every source has been checked.
  for src in select value from jsonb_array_elements(p_sources)
  loop
    select * into n from node where id = (src ->> 'node_id')::uuid;
    if n.id is null then
      raise exception 'no lot with id %', src ->> 'node_id';
    end if;
    if n.status = 'closed' then
      raise exception '% is closed; there is nothing left in it to press', n.name;
    end if;
    if n.quantity is null then
      raise exception
        '% has never been weighed, and pressing it is the last moment anybody could. Weigh its bins first', n.name;
    end if;

    if parent_stage is null then
      parent_stage := n.stage;
    elsif parent_stage <> n.stage then
      raise exception
        'those lots are at different stages, so one press cannot be the right record for both';
    end if;

    want := coalesce((src ->> 'weight_lbs')::numeric, n.quantity);
    if want <= 0 then
      raise exception 'a press of % from % is not an amount', want, n.name;
    end if;
    if want > n.quantity then
      raise exception
        '% holds % and the press says %, so that is more fruit than there is',
        n.name, n.quantity, want;
    end if;

    parent_ids := parent_ids || n.id;
    weights    := weights || want;
    total_in   := total_in + want;

    select count(*) into i from unweighed_bin where node_id = n.id;
    waiting := waiting + i;
  end loop;

  child_stage := coalesce(
    (p_node ->> 'stage')::node_stage,
    case when parent_stage = 'bin' then 'ferment'::node_stage
         else 'maturation'::node_stage end);

  -- Pass two: check every destination before writing anything, so a press that
  -- is going to be refused does not half happen.
  for cut in select value from jsonb_array_elements(p_cuts)
  loop
    if (cut ->> 'cut_id') is not null and not exists (
      select 1 from term where id = (cut ->> 'cut_id')::uuid and kind = 'press_cut'
    ) then
      raise exception 'that is not a press cut';
    end if;
    if cut -> 'destinations' is null
       or jsonb_array_length(cut -> 'destinations') = 0 then
      raise exception 'a cut with no vessel to go into is not a cut';
    end if;
    for dst in select value from jsonb_array_elements(cut -> 'destinations')
    loop
      vol := (dst ->> 'volume_l')::numeric;
      if vol is null or vol <= 0 then
        raise exception 'a volume of % into a vessel is not a filling',
          coalesce(vol::text, 'nothing');
      end if;
      v_id := (dst ->> 'vessel_id')::uuid;
      if not exists (select 1 from vessel where id = v_id and active) then
        raise exception 'no active vessel with id %', v_id;
      end if;
      if exists (select 1 from placement where vessel_id = v_id and to_at is null) then
        raise exception
          'a vessel the juice is going into already holds a lot; rack it out first';
      end if;
      total_out := total_out + vol;
    end loop;
  end loop;

  -- One child per cut. Every child of one press draws the same share from every
  -- parent, because a hard press is made of the same fruit as the free run and
  -- in the same ratios. The cut is a fact about the lot rather than a second
  -- composition, which is what S-52 was waiting for.
  for cut in select value from jsonb_array_elements(p_cuts)
  loop
    child := gen_random_uuid();
    select coalesce(sum((d ->> 'volume_l')::numeric), 0) into cut_out
      from jsonb_array_elements(cut -> 'destinations') d;

    insert into node (id, stage, status, name, quantity, unit,
                      variety_id, vintage, non_vintage, product_type_id,
                      owner_id, created_by, attributes)
    select
      child, child_stage, 'open',
      coalesce(
        nullif(cut ->> 'name', ''),
        (select p.name from node p where p.id = parent_ids[1])
          || ' pressed'
          || coalesce(', ' || (select t.label from term t
                                where t.id = (cut ->> 'cut_id')::uuid), '')),
      cut_out, 'L',
      (select case when count(distinct p.variety_id) = 1
                   then (array_agg(distinct p.variety_id))[1] end
         from node p where p.id = any(parent_ids)),
      -- 0049. One vintage if every parent is of it, and non-vintage if
      -- they disagree or if any parent is itself NV. `count(distinct)`
      -- skips nulls, so the bool_and is what stops an NV parent and a
      -- 2024 parent producing a 2024 child.
      (select case when count(distinct p.vintage) = 1 and bool_and(not p.non_vintage)
                   then min(p.vintage) end
         from node p where p.id = any(parent_ids)),
      (select case when count(distinct p.vintage) = 1 and bool_and(not p.non_vintage)
                   then false else true end
         from node p where p.id = any(parent_ids)),
      coalesce((select case when count(distinct p.product_type_id) = 1
                            then (array_agg(distinct p.product_type_id))[1] end
                  from node p where p.id = any(parent_ids)),
               term_id('product_type', 'wine')),
      (select p.owner_id from node p where p.id = any(parent_ids)
        order by p.quantity desc nulls last limit 1),
      auth.uid(),
      coalesce(p_node -> 'attributes', '{}'::jsonb)
        || jsonb_strip_nulls(jsonb_build_object(
             'cut',              (cut ->> 'cut_id')::uuid,
             'cut_label',        (select t.label from term t
                                   where t.id = (cut ->> 'cut_id')::uuid),
             -- Named in spec.md Â§2 as an attribute of a node since the scaffold,
             -- and nothing wrote it until now.
             'whole_cluster_pct', wc));

    child_ids := child_ids || child;

    for dst in select value from jsonb_array_elements(cut -> 'destinations')
    loop
      insert into placement (node_id, vessel_id, volume_l)
      values (child, (dst ->> 'vessel_id')::uuid, (dst ->> 'volume_l')::numeric);
    end loop;

    -- Lineage by fruit weight, the same for every cut. The denominator is what
    -- the parents put in rather than what came out, so the shares sum to one and
    -- the press yield does not change what the wine is made of.
    for i in 1 .. array_length(parent_ids, 1)
    loop
      insert into lineage (parent_id, child_id, fraction)
      values (parent_ids[i], child,
              greatest(least(weights[i] / nullif(total_in, 0), 1), 0.00001));
    end loop;
  end loop;

  -- Take the fruit out of the parents.
  for i in 1 .. array_length(parent_ids, 1)
  loop
    select quantity into held from node where id = parent_ids[i];
    update node set quantity = greatest(held - weights[i], 0)
     where id = parent_ids[i];

    if held - weights[i] <= 0.0001 then
      update placement set to_at = now()
       where node_id = parent_ids[i] and to_at is null;
      get diagnostics emptied = row_count;
    end if;
  end loop;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'press'), 'node', child_ids[1], auth.uid(), 'observed',
     jsonb_strip_nulls(coalesce(p_detail, '{}'::jsonb) || jsonb_build_object(
       'lbs_in',          total_in,
       'litres_out',      total_out,
       'yield_l_per_ton', round(total_out / nullif(total_in, 0) * 2000, 2),
       'parents',         to_jsonb(parent_ids::text[]),
       'cuts',            to_jsonb(child_ids::text[]),
       -- Two timestamps, not three. The total is a subtraction, and storing it
       -- would be storing what is derived and inviting it to disagree.
       'skin_contact_minutes',
         case when started is not null and ended is not null
              then round(extract(epoch from (ended - started)) / 60.0)
         end,
       -- The other duration, and a different fact: how long the skins were on
       -- and how long the press ran are two things the form asks for separately
       -- and one of them is often a fraction of the other.
       'press_minutes',
         case when ran_from is not null and ran_to is not null
              then round(extract(epoch from (ran_to - ran_from)) / 60.0)
         end,
       'program_label',
         (select t.label from term t
           where t.id = (p_detail ->> 'program_id')::uuid))));

  return jsonb_build_object(
    'node_id',         child_ids[1],
    'cuts',            to_jsonb(child_ids::text[]),
    'stage',           child_stage,
    'lbs_in',          total_in,
    'litres_out',      total_out,
    'yield_l_per_ton', round(total_out / nullif(total_in, 0) * 2000, 2),
    'bins_emptied',    emptied,
    'unweighed_left',  waiting,
    'event_id',        ev_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.rack(p_sources jsonb, p_destinations jsonb, p_data jsonb DEFAULT '{}'::jsonb, p_allow_overfill boolean DEFAULT false, p_node jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  plan      jsonb;
  src       jsonb;
  dst       jsonb;
  par       jsonb;
  new_id    uuid;
  target    uuid;
  v_id      uuid;
  vol       numeric;
  held      numeric;
  p_node_id uuid;
  total_in  numeric;
  contributed numeric;
  remaining int;
  ev_id     uuid := gen_random_uuid();
begin
  plan := rack_plan(p_sources, p_destinations);

  if jsonb_array_length(plan -> 'overfill') > 0 and not p_allow_overfill then
    raise exception 'that puts more in % than it holds; confirm the overfill to record it anyway',
      (plan -> 'overfill' -> 0 ->> 'name');
  end if;

  total_in := (plan ->> 'in_l')::numeric;

  if plan ->> 'kind' = 'move' then
    target := (plan ->> 'node_id')::uuid;
  else
    -- A new lot. Variety, vintage and product type survive only where every
    -- parent agrees; where they disagree the answer is genuinely nothing, and
    -- composition is derived from lineage rather than copied onto the child.
    new_id := coalesce((p_node ->> 'id')::uuid, gen_random_uuid());
    insert into node (id, stage, status, name, quantity, unit,
                      variety_id, vintage, non_vintage, product_type_id, owner_id, created_by,
                      attributes)
    select
      new_id,
      coalesce((p_node ->> 'stage')::node_stage, 'maturation'),
      'open',
      coalesce(p_node ->> 'name', 'Blend ' || to_char(now(), 'YYYY-MM-DD')),
      total_in,
      'L',
      (select case when count(distinct n.variety_id) = 1
                   then (array_agg(distinct n.variety_id))[1] end
         from node n where n.id = any(
           select (e ->> 'node_id')::uuid from jsonb_array_elements(plan -> 'parents') e)),
      -- 0049. A blend of two vintages is a non-vintage wine, which is a
      -- thing this schema could not say before and recorded as a blank.
      (select case when count(distinct n.vintage) = 1 and bool_and(not n.non_vintage)
                   then min(n.vintage) end
         from node n where n.id = any(
           select (e ->> 'node_id')::uuid from jsonb_array_elements(plan -> 'parents') e)),
      (select case when count(distinct n.vintage) = 1 and bool_and(not n.non_vintage)
                   then false else true end
         from node n where n.id = any(
           select (e ->> 'node_id')::uuid from jsonb_array_elements(plan -> 'parents') e)),
      (select case when count(distinct n.product_type_id) = 1
                   then (array_agg(distinct n.product_type_id))[1] end
         from node n where n.id = any(
           select (e ->> 'node_id')::uuid from jsonb_array_elements(plan -> 'parents') e)),
      -- One owner_id, because RLS scopes a client's view by it and a null here
      -- would hide the wine from everyone who part owns it. The largest
      -- contributor holds it and the mixing is recorded. See S-22.
      (select (e ->> 'owner_id')::uuid from jsonb_array_elements(plan -> 'parents') e
        where e ->> 'owner_id' is not null
        order by (e ->> 'volume_l')::numeric desc limit 1),
      auth.uid(),
      case when (plan ->> 'mixed_owners')::boolean
           then jsonb_build_object('mixed_ownership', true,
                                   'owners', (select jsonb_agg(distinct e -> 'owner_id')
                                                from jsonb_array_elements(plan -> 'parents') e))
           else '{}'::jsonb end;

    target := new_id;

    -- Lineage: each parent's share of the child, which is what
    -- block_composition multiplies along the path.
    --
    -- The denominator is what the parents put in, not what arrived in the
    -- vessel. Those differ by the loss, and dividing by the arrival would make
    -- the shares sum to something other than one, so losing five litres down a
    -- hose would change what the wine is made of. It does not.
    select sum((e ->> 'volume_l')::numeric) into contributed
      from jsonb_array_elements(plan -> 'parents') e;

    for par in select value from jsonb_array_elements(plan -> 'parents')
    loop
      insert into lineage (parent_id, child_id, fraction)
      values ((par ->> 'node_id')::uuid, new_id,
              greatest(least((par ->> 'volume_l')::numeric
                             / nullif(contributed, 0), 1), 0.00001));
    end loop;
  end if;

  -- Take the wine out of the sources.
  for src in select value from jsonb_array_elements(p_sources)
  loop
    v_id := (src ->> 'vessel_id')::uuid;
    vol  := (src ->> 'volume_l')::numeric;

    select p.node_id, p.volume_l into p_node_id, held
      from placement p where p.vessel_id = v_id and p.to_at is null;

    if held is null or held - vol <= 0.0001 then
      update placement set to_at = now()
       where vessel_id = v_id and to_at is null;
    else
      update placement set volume_l = held - vol
       where vessel_id = v_id and to_at is null;
    end if;

    -- The parent shrinks by what left it. It closes only if that empties it,
    -- which is 0013's rule and not this function's business.
    if plan ->> 'kind' = 'blend' then
      update node set quantity = greatest(coalesce(quantity, 0) - vol, 0)
       where id = p_node_id and quantity is not null;
    end if;
  end loop;

  -- A destination holding another lot has just become a parent, so its
  -- placement ends here too. It is absorbed whole rather than drawn from, so
  -- its quantity goes to nothing and 0013 closes it. Without this it would
  -- keep a volume while being in no vessel at all.
  if plan ->> 'kind' = 'blend' then
    for dst in select value from jsonb_array_elements(p_destinations)
    loop
      select p.node_id into p_node_id
        from placement p
       where p.vessel_id = (dst ->> 'vessel_id')::uuid and p.to_at is null;

      if p_node_id is not null and p_node_id <> target then
        select p.volume_l into held
          from placement p
         where p.vessel_id = (dst ->> 'vessel_id')::uuid and p.to_at is null;

        update placement set to_at = now()
         where vessel_id = (dst ->> 'vessel_id')::uuid and to_at is null;

        -- Only what was in this vessel went into the blend. A lot already in
        -- the destination is not thereby consumed: the same lot may be sitting
        -- in a tank and eight other barrels, and closing it here would report
        -- four hundred litres as gone while they are still in the tank.
        update node set quantity = greatest(coalesce(quantity, 0) - coalesce(held, 0), 0)
         where id = p_node_id and quantity is not null;

        -- Whether it is finished is answered by where it is, not by a number
        -- somebody may never have recorded. If it is in no vessel at all then
        -- it is empty, and that is knowledge rather than a guess.
        select count(*) into remaining
          from placement where node_id = p_node_id and to_at is null;
        if remaining = 0 then
          update node
             set status    = 'closed',
                 closed_at = coalesce(closed_at, now())
           where id = p_node_id;
        end if;
      end if;
    end loop;
  end if;

  -- Put it in.
  for dst in select value from jsonb_array_elements(p_destinations)
  loop
    v_id := (dst ->> 'vessel_id')::uuid;
    vol  := (dst ->> 'volume_l')::numeric;

    select p.volume_l into held
      from placement p where p.vessel_id = v_id and p.to_at is null
       and p.node_id = target;

    if held is not null then
      update placement set volume_l = held + vol
       where vessel_id = v_id and to_at is null and node_id = target;
    else
      insert into placement (node_id, vessel_id, volume_l)
      values (target, v_id, vol);
    end if;
  end loop;

  -- A move keeps its identity and loses only what the hose kept.
  if plan ->> 'kind' = 'move' then
    update node set quantity = greatest(coalesce(quantity, 0)
                                        - ((plan ->> 'loss_l')::numeric), 0)
     where id = target and quantity is not null;
  end if;

  -- One event for the whole transfer. Loss is not in it: it is the difference
  -- between the volumes, and storing it would be a second source of truth for
  -- a number anyone can subtract.
  insert into event (id, operation_id, subject_type, subject_id, by_user, data, provenance)
  values (ev_id, term_id('operation', 'rack'), 'node', target, auth.uid(),
          p_data || jsonb_build_object(
            'sources', p_sources,
            'destinations', p_destinations,
            'kind', plan ->> 'kind',
            'overfilled', jsonb_array_length(plan -> 'overfill') > 0),
          'observed');

  return plan || jsonb_build_object('node_id', target, 'event_id', ev_id);
end;
$function$;

commit;
