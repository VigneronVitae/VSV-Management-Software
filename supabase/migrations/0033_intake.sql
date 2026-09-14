-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Intake. A bin of fruit exists in the vineyard before anybody weighs
--           it, a weighing covers whatever was on the scale together, and the
--           bin that was never weighed is a thing the app can show you rather
--           than a thing you find out about in March."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0008_fill_vessel.sql,
--              supabase/migrations/0015_fork_and_history.sql,
--              supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0032_vessel_maker_and_room_temperature.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0034_press.sql, supabase/migrations/0035_bins_in_bulk.sql, supabase/migrations/0038_cancel_a_pick.sql, supabase/migrations/0042_weighing_photo.sql]
-- Axioms enforced: T0-1 (one node type: a bin of fruit is a node like any
--                  other), T0-2 (composition is derived, never stored),
--                  T0-5 (events are append only, a correction is a new event),
--                  T1-4 (intake must be fast before it is complete)
-- Open sorries: S-49 (pounds by constant rather than by setting),
--               S-50 (forking a pick is refused rather than estimated),
--               S-51 (only an admin may create a block)
-- ---------------------------------------------------------------------------
--
-- Build order 2 in spec.md §7, and the reason the order is what it is: a bug in
-- the task board costs an afternoon, and a bin that was never weighed cannot be
-- reconstructed from anything.
--
-- **A bin is a vessel.** This was the winemaker's own move and it collapses most
-- of the work: a bin already has a type with typed fields, an owner, a location,
-- photos and a sticker, and fruit sitting in a bin is a node with a placement,
-- which is the same sentence as wine sitting in a barrel. Nothing new is
-- invented for intake except the two things intake has that racking does not: a
-- weight that is not known yet, and a scale reading covering more than one
-- container.
--
-- **A pick is one node and a weighing is an event.** Three bins on the scale
-- produce one number. That number is a measurement of three bins together and it
-- does not contain three weights, so it is not stored as three weights. The pick
-- carries the total, every weighing records the bins it covered, and a per bin
-- figure is something a later session may derive and mark inferred, at the moment
-- somebody asks for it and not before. That is T0-2 applied to a scale.
--
-- **The unweighed bin is the point.** T1-4 says intake must be fast before it is
-- complete, which only works if incompleteness is visible. A bin with fruit and
-- no weight is a legitimate state, reachable in one tap in a vineyard with no
-- signal, and `unweighed_bin` is what stops it from being a silent one.

begin;

-- ---------------------------------------------------------------------------
-- A field that is a yes or a no
-- ---------------------------------------------------------------------------

-- "Borrowed, goes back" is a checkbox and the descriptor vocabulary had no way
-- to say so: `0009` allowed term, number and text, which covered every field any
-- vessel type had needed until a bin needed one. A text field holding the word
-- yes would be the wrong control and the wrong data.
--
-- Taken from the catalog and changed in one clause rather than retyped, per the
-- rule 0027 earned.
create or replace function validate_vessel_type_fields()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  f    jsonb;
  seen text[] := '{}';
  k    text;
begin
  if new.kind <> 'vessel_type' or not (new.attributes ? 'fields') then
    return new;
  end if;

  if jsonb_typeof(new.attributes -> 'fields') <> 'array' then
    raise exception 'fields must be a list';
  end if;

  for f in select value from jsonb_array_elements(new.attributes -> 'fields')
  loop
    k := f ->> 'key';
    if k is null or btrim(k) = '' then
      raise exception 'every field needs a key';
    end if;
    if k = any(seen) then
      raise exception 'two fields share the key %', k;
    end if;
    seen := seen || k;

    if (f ->> 'kind') not in ('term', 'number', 'text', 'boolean') then
      raise exception 'field % has kind %, which is not term, number, text or boolean',
        k, coalesce(f ->> 'kind', 'nothing');
    end if;

    if (f ->> 'kind') = 'term' then
      if f ->> 'term_kind' is null then
        raise exception 'field % is a picker and names no vocabulary', k;
      end if;
      -- Was: perform (f ->> 'term_kind')::term_kind, inside a begin/exception.
      if not exists (select 1 from term_kind tk where tk.kind = f ->> 'term_kind') then
        raise exception 'field % names vocabulary %, which does not exist',
          k, f ->> 'term_kind';
      end if;
    end if;

    if (f ->> 'min') is not null and (f ->> 'max') is not null
       and (f ->> 'min')::numeric > (f ->> 'max')::numeric then
      raise exception 'field % has a minimum above its maximum', k;
    end if;
  end loop;

  return new;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Picking bins, fermentation bins, and a manufacturer
-- ---------------------------------------------------------------------------

-- `macrobin` was one vessel type doing three jobs. The winemaker took it apart:
-- a picking bin goes to the vineyard and comes back on a scale, a fermentation
-- bin sits in the winery and is somewhere fruit is tipped into, and **Macrobin
-- is probably the manufacturer's name**, which is why the type was confusing to
-- read. A brand in the type column is the same wrong-way knowledge `0032` took
-- out of the maker list, one table over.
--
-- Free to do today and not tomorrow: nothing is a macrobin yet.
do $$
declare n int;
begin
  select count(*) into n
    from vessel v join term t on t.id = v.type_id
   where t.kind = 'vessel_type' and t.value = 'macrobin';
  if n <> 0 then
    raise exception
      '% vessel(s) are still of type macrobin, so splitting the type would orphan them. Repoint them first', n;
  end if;
end $$;

-- The maker, where it belonged. Flagged for tanks rather than barrels, per the
-- `makes` set 0032 introduced, so entering it once is enough.
insert into term (kind, value, label, attributes)
values ('vessel_maker', 'macrobin', 'Macrobin',
        jsonb_build_object('makes', jsonb_build_array('manufacturer')))
on conflict (kind, value) do update
  set attributes = term.attributes || excluded.attributes;

-- The two types, carrying forward the shape macrobin had. A picking bin is
-- flagged for the scale; a fermentation bin is not, because in this winery's
-- process fruit is weighed in picking bins and tipped into fermentation bins,
-- so a ferm bin is a destination in the way a tank is.
--
-- **`intake_bin` rather than `bin`.** Both of these are bins in English and only
-- one of them is weighed, which is precisely the ambiguity that made `macrobin`
-- unreadable. The flag says what it decides.
insert into term (kind, value, label, attributes)
values
  ('vessel_type', 'picking_bin', 'Picking bin',
   jsonb_build_object(
     'intake_bin', true,
     'expand', jsonb_build_array(),
     'maker_label', 'Manufacturer',
     'maker_contract', 'manufacturer',
     'fields', jsonb_build_array(
       jsonb_build_object('key', 'maker', 'kind', 'term', 'open', false,
                          'label', 'Manufacturer', 'contract', 'manufacturer',
                          'term_kind', 'vessel_maker', 'sort_order', 10),
       -- Whose bin this one is, as distinct from who owns it. The winemaker's
       -- point: a client's bin and a bin borrowed from the grower are different
       -- situations, and only one of them has to go back with the fruit.
       jsonb_build_object('key', 'borrowed', 'kind', 'boolean', 'open', false,
                          'label', 'Borrowed, goes back',
                          'hint', 'On loan. It is owed to its owner once it is empty.',
                          'sort_order', 20))))
  ,
  ('vessel_type', 'fermentation_bin', 'Fermentation bin',
   jsonb_build_object(
     'expand', jsonb_build_array(),
     'maker_label', 'Manufacturer',
     'maker_contract', 'manufacturer',
     'fields', jsonb_build_array(
       jsonb_build_object('key', 'maker', 'kind', 'term', 'open', false,
                          'label', 'Manufacturer', 'contract', 'manufacturer',
                          'term_kind', 'vessel_maker', 'sort_order', 10))))
on conflict (kind, value) do update
  set label = excluded.label,
      attributes = term.attributes || excluded.attributes;

delete from term where kind = 'vessel_type' and value = 'macrobin';

-- The tare lives on the type because every picking bin of one type weighs the
-- same as every other one. Slotted and unslotted are different types, which is
-- the granularity the winemaker described and the reason this is a vocabulary
-- row rather than a column: a new bin type is a row, not a release.
--
-- **No tare is seeded.** Nobody has weighed an empty one into this database and
-- a number invented here would be indistinguishable from a measured one for the
-- rest of the vintage. `bin_tare_lbs` refuses until somebody puts a real one on
-- the type.
comment on table term is
  'Every vocabulary in one table, keyed by kind. A vessel_type flagged '
  '{"intake_bin": true} is weighed at intake and carries {"tare_lbs": n}, which '
  'a scale reading has subtracted from it. See 0033.';

create or replace function bin_tare_lbs(p_vessel_id uuid)
returns numeric
language plpgsql
stable
set search_path to 'public', 'pg_temp'
as $$
declare
  t          jsonb;
  type_label text;
  tare       numeric;
begin
  select vt.attributes, vt.label into t, type_label
    from vessel v
    join term vt on vt.id = v.type_id and vt.kind = 'vessel_type'
   where v.id = p_vessel_id;

  if t is null then
    raise exception 'no vessel with id %', p_vessel_id;
  end if;

  if coalesce((t ->> 'intake_bin')::boolean, false) is not true then
    raise exception
      '% is not a picking bin, so fruit is not weighed in it', type_label;
  end if;

  tare := (t ->> 'tare_lbs')::numeric;

  -- A25, the null permit class, in the place it would be most expensive: a
  -- missing tare treated as zero is a pick that reads heavy by the weight of its
  -- own containers, silently, for the whole vintage. A predicate that cannot
  -- determine an answer refuses.
  if tare is null then
    raise exception
      'the bin type % has no tare weight, so a gross weight cannot be turned into fruit. Set it on the vessel type', type_label;
  end if;
  if tare <= 0 then
    raise exception 'the bin type % has a tare of %, which is not a weight', type_label, tare;
  end if;

  return tare;
end;
$$;

-- ---------------------------------------------------------------------------
-- What the eye saw, before the scale
-- ---------------------------------------------------------------------------

-- How full the bin looked when it was filled. The winemaker asked for a
-- percentage "because then it can be tested against reality", which is the whole
-- justification: a bin that later goes on the scale by itself turns this into a
-- measured full bin weight, and the estimate stops being decoration.
--
-- Nullable on purpose. A tap that refuses to record a bin because nobody
-- estimated how full it was is the opposite of T1-4.
alter table placement add column if not exists fill_pct numeric(5,2);

alter table placement
  drop constraint if exists placement_fill_pct_is_a_percentage;
alter table placement
  add constraint placement_fill_pct_is_a_percentage
    check (fill_pct is null or (fill_pct > 0 and fill_pct <= 100));

comment on column placement.fill_pct is
  'How full this container looked, recorded by eye at the time, never computed. '
  'Null means nobody said. See 0033.';

-- The weighing itself. A measurement, so it neither moves wine nor transforms
-- it: operation_effect classifies it and the lineage machinery ignores it.
insert into term (kind, value, label, attributes)
values ('operation', 'weigh', 'Weigh', jsonb_build_object('effect', 'measurement'))
on conflict (kind, value) do update
  set label = excluded.label,
      attributes = term.attributes || excluded.attributes;

-- ---------------------------------------------------------------------------
-- The bin that has fruit and no number
-- ---------------------------------------------------------------------------

-- T1-4's safety net, and the reason the intermediate state is safe to allow at
-- all. A bin recorded in a vineyard and never carried to the scale is the one
-- loss this whole build order is arranged around, so it is a row somebody can
-- see rather than an absence nobody notices.
--
-- security_invoker, because a view without it runs as its owner and hands a
-- client somebody else's fruit. That is S-26, which 0017 fixed and 0032 briefly
-- re-opened by using CREATE OR REPLACE VIEW without repeating the option.
create or replace view unweighed_bin with (security_invoker = true) as
select
  p.node_id,
  n.name    as pick_name,
  p.vessel_id,
  v.name    as bin_name,
  vt.label  as bin_type,
  p.fill_pct,
  p.from_at as filled_at
from placement p
join node   n  on n.id = p.node_id and n.stage = 'bin' and n.status <> 'closed'
join vessel v  on v.id = p.vessel_id
join term   vt on vt.id = v.type_id and vt.kind = 'vessel_type'
where p.to_at is null
  and not exists (
    select 1
      from event e
     where e.subject_type = 'node'
       and e.subject_id   = p.node_id
       and e.operation_id = term_id('operation', 'weigh')
       and e.data -> 'bins' ? p.vessel_id::text
       -- A weighing that has been corrected does not count as having weighed
       -- anything. The correction is a new event naming the one it replaces,
       -- which is T0-5: the wrong number stays in the record and stops counting.
       and not exists (
         select 1 from event s
          where s.subject_type = 'node'
            and s.subject_id   = e.subject_id
            and s.operation_id = term_id('operation', 'weigh')
            and (s.data ->> 'supersedes')::uuid = e.id
       )
  );

comment on view unweighed_bin is
  'Bins holding fruit that no live weighing covers. The list that must be empty '
  'before a pick is finished. See 0033 and axiom T1-4.';

-- ---------------------------------------------------------------------------
-- A bin of fruit, before anybody has weighed it
-- ---------------------------------------------------------------------------

-- One tap in a vineyard. The pick is created by the first bin that joins it and
-- every later bin finds it already there, so the person filling bins never has
-- to decide whether they are starting something: they are recording a bin, and
-- the pick is what those bins have in common.
--
-- The id comes from the client, per the repo's rule that an offline write has
-- identity before the server sees it, which is what makes this call safe to
-- repeat when a phone in a vineyard is not sure whether it got through.
create or replace function add_bin_to_pick(
  p_pick      jsonb,
  p_vessel_id uuid,
  p_fill_pct  numeric default null
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
    select concat_ws(' ', b.vineyard, b.name) into blk_name
      from block b where b.id = (p_pick ->> 'block_id')::uuid;
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
$$;

-- ---------------------------------------------------------------------------
-- The scale
-- ---------------------------------------------------------------------------

-- One reading, however many bins were on it. The gross is what the scale said,
-- the tare is the sum of what those particular bins weigh empty, and the
-- difference is fruit. All three are kept, because a stored difference whose
-- inputs were thrown away cannot be checked against anything.
--
-- **The reading is not divided.** Three bins on a scale produce one number and
-- that number does not contain three weights. Per bin figures are derivable
-- later from fill_pct and must be marked inferred at the moment they are
-- derived, which is the winemaker's own answer and T0-2 applied to a scale.
create or replace function weigh_bins(
  p_node_id    uuid,
  p_vessel_ids uuid[],
  p_gross_lbs  numeric,
  p_note       text default null,
  p_supersedes uuid default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  n       node%rowtype;
  n_bins  int := coalesce(array_length(p_vessel_ids, 1), 0);
  n_here  int;
  tare    numeric := 0;
  net     numeric;
  v_id    uuid;
  already text;
  ev_id   uuid := gen_random_uuid();
  total   numeric;
begin
  if n_bins = 0 then
    raise exception 'no bins were named, so there is nothing this weight is of';
  end if;
  if p_gross_lbs is null or p_gross_lbs <= 0 then
    raise exception 'a gross weight of % is not a scale reading',
      coalesce(p_gross_lbs::text, 'nothing');
  end if;

  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no pick with id %', p_node_id;
  end if;
  if n.stage <> 'bin' then
    raise exception 'that lot is not a pick, so it is not weighed in bins';
  end if;
  if n.status = 'closed' then
    raise exception 'that pick is closed; its fruit has already gone somewhere';
  end if;

  select count(*) into n_here
    from placement
   where node_id = p_node_id and to_at is null and vessel_id = any(p_vessel_ids);
  if n_here <> n_bins then
    raise exception
      'some of those bins do not hold this pick, so this reading is not of it';
  end if;

  -- Already weighed, unless this is the correction of the reading that did it.
  -- Without the guard a second reading of the same bins adds its fruit a second
  -- time and the pick quietly doubles, which is invisible from every screen.
  select string_agg(u.bin_name, ', ' order by u.bin_name) into already
    from (
      select v.name as bin_name
        from unnest(p_vessel_ids) as x(vessel_id)
        join vessel v on v.id = x.vessel_id
       where not exists (
         select 1 from unweighed_bin ub
          where ub.node_id = p_node_id and ub.vessel_id = x.vessel_id)
    ) u;
  if already is not null and p_supersedes is null then
    raise exception
      'these bins have been weighed already: %. Correct that weighing rather than adding a second one',
      already;
  end if;

  if p_supersedes is not null and not exists (
    select 1 from event
     where id = p_supersedes
       and subject_type = 'node' and subject_id = p_node_id
       and operation_id = term_id('operation', 'weigh')
  ) then
    raise exception 'there is no weighing of this pick with id % to correct', p_supersedes;
  end if;

  foreach v_id in array p_vessel_ids loop
    tare := tare + bin_tare_lbs(v_id);
  end loop;

  net := p_gross_lbs - tare;
  if net <= 0 then
    raise exception
      'a gross of % lbs over bins weighing % lbs empty leaves % lbs of fruit, so one of those numbers is wrong',
      p_gross_lbs, tare, net;
  end if;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'weigh'), 'node', p_node_id, auth.uid(), 'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'gross_lbs',  p_gross_lbs,
       'tare_lbs',   tare,
       'net_lbs',    net,
       'bins',       to_jsonb(p_vessel_ids::text[]),
       'note',       nullif(p_note, ''),
       'supersedes', p_supersedes)));

  -- Recomputed from the events rather than added to, so a correction lands
  -- without anybody working out what the old reading contributed. The events are
  -- the record; quantity is the schema's place to keep the answer.
  select coalesce(sum((e.data ->> 'net_lbs')::numeric), 0) into total
    from event e
   where e.subject_type = 'node' and e.subject_id = p_node_id
     and e.operation_id = term_id('operation', 'weigh')
     and not exists (
       select 1 from event s
        where s.subject_type = 'node' and s.subject_id = p_node_id
          and s.operation_id = term_id('operation', 'weigh')
          and (s.data ->> 'supersedes')::uuid = e.id);

  update node set quantity = total, unit = 'lbs' where id = p_node_id;

  return jsonb_build_object(
    'event_id',  ev_id,
    'gross_lbs', p_gross_lbs,
    'tare_lbs',  tare,
    'net_lbs',   net,
    'total_lbs', total,
    'unweighed', (select count(*) from unweighed_bin where node_id = p_node_id)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- What forking a pick would do, and why it does not
-- ---------------------------------------------------------------------------

-- S-50. fork_lot computes the child's quantity by summing placement.volume_l
-- across the vessels being split off, and a pick deliberately stores nothing
-- there. Left alone it would hand the child a quantity of zero, which is a wrong
-- number rather than a missing one, and zero closes nothing and reads as an
-- empty bin.
--
-- Splitting a pick is a real thing somebody will want, and the honest version
-- divides the parent's weight by fill_pct and writes the pieces as inferred at
-- that moment. That is not built. Refusing is the part of it that is.
create or replace function refuse_forking_a_pick()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
begin
  if (select stage from node where id = new.parent_id) = 'bin'
     and (select stage from node where id = new.child_id) = 'bin' then
    raise exception
      'a pick cannot be split bin by bin yet: one weight was measured over several bins and dividing it would invent numbers. See sorry S-50';
  end if;
  return new;
end;
$$;

drop trigger if exists lineage_refuses_forking_a_pick on lineage;
create trigger lineage_refuses_forking_a_pick
  before insert on lineage
  for each row execute function refuse_forking_a_pick();

commit;
