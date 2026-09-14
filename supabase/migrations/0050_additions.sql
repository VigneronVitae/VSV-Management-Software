-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Something goes into the wine in a vessel, and the shelf it came off
--           goes down by the same amount as a consequence rather than as a
--           second chore."
-- Depends on: [supabase/migrations/0046_supply_inventory.sql,
--              supabase/migrations/0014_rack.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0051_supplies_for_addition.sql]
-- Axioms enforced: T0-2 (the volume of wine at the moment of an addition, and
--                  therefore the rate, are derived from placements and not
--                  stored), T0-5 (an addition is an event and a correction is
--                  another one)
-- Open sorries: S-63 (nothing converts between units, so an addition measured
--                in a unit the shelf does not use records the addition and not
--                the movement)
-- ---------------------------------------------------------------------------
--
-- The winemaker: "we definitely need an additions section. Where you select a
-- vessel with wine and add additions."
--
-- **Vessel first, which is not a detail.** An addition is made to what is in
-- front of somebody, and what is in front of them is a tank. A lot can be spread
-- across three barrels, and topping one of them with something is not an
-- addition to the other two: the wine is not mixed and pretending otherwise
-- would put a rate on the record that nothing ever experienced. So this takes
-- the vessels the addition actually went into, requires that they all hold the
-- same lot the way `weigh_bins` requires bins of one pick, and derives the
-- volume from exactly those.
--
-- **The rate is not stored.** Alexis's forms want addition, date, wine volume
-- and rate in four columns, and three of those four are one fact plus arithmetic.
-- The volume at the moment of the addition is a function of the placements as
-- they stood then, which the schema already keeps, and the rate is the amount
-- over that volume. Storing either is C-3's mistake with a different name. They
-- are in `lot_addition` below, computed.
--
-- **This is S-64, and it is the whole reason the stores exist.** `0046` built an
-- inventory whose accuracy is bounded by somebody remembering to record every
-- scoop, and said so: "nobody does a thing twice during harvest, so the honest
-- prediction is that uses will go unrecorded." An addition that names the supply
-- it was drawn from writes the movement itself. One action, two records, and the
-- count that reconciles them stops having to absorb the difference.
--
-- What it will not do is convert. If somebody records 5 g of a supply the shelf
-- keeps in kilos, the addition is recorded in full and the movement is not
-- written, and the caller is told which. Guessing at the factor is how an
-- inventory becomes confidently wrong, and the unit question is S-63 and belongs
-- to weight, volume, area and count together rather than being answered here for
-- one of them.

begin;

-- What caused a movement, when something did. Nullable, because a delivery and a
-- count are nobody's consequence, and a restrict because a movement pointing at
-- an addition that is not there is worse than no link at all.
alter table supply_movement
  add column if not exists caused_by uuid references event (id) on delete restrict;

comment on column supply_movement.caused_by is
  'The event this movement was a consequence of, when it was a consequence of '
  'one. An addition to a lot writes the use off the shelf, and this is what '
  'makes them provably the same act rather than two entries somebody hoped '
  'matched. Null for deliveries and counts. See 0050 and S-64.';

create index if not exists supply_movement_caused_by_idx
  on supply_movement (caused_by) where caused_by is not null;

-- ---------------------------------------------------------------------------
-- The volume that was there at the time
-- ---------------------------------------------------------------------------

-- Placements are append-only with a from and a to, so what was in a vessel at
-- any past moment is a question the schema can already answer. Nothing caches
-- it. T0-2.
create or replace function vessel_volume_at(p_vessel_ids uuid[], p_at timestamptz)
returns numeric
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
  select coalesce(sum(p.volume_l), 0)
    from placement p
   where p.vessel_id = any(p_vessel_ids)
     and p.from_at <= p_at
     and (p.to_at is null or p.to_at > p_at);
$$;

-- ---------------------------------------------------------------------------
-- Making one
-- ---------------------------------------------------------------------------

create or replace function add_to_wine(
  p_vessel_ids uuid[],
  p_amount     numeric,
  p_unit       text,
  p_supply_id  uuid default null,
  p_what       text default null,
  p_at         timestamptz default null,
  p_note       text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  n_vessels int := coalesce(array_length(p_vessel_ids, 1), 0);
  node_ids  uuid[];
  lot       node%rowtype;
  s         supply%rowtype;
  label     text;
  at_time   timestamptz := coalesce(p_at, now());
  vol       numeric;
  ev_id     uuid := gen_random_uuid();
  moved     boolean := false;
  why       text;
begin
  if n_vessels = 0 then
    raise exception 'no vessel was named, so there is nothing for this to go into';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'an addition of % is not an amount',
      coalesce(p_amount::text, 'nothing');
  end if;
  if p_unit is null or btrim(p_unit) = '' then
    raise exception 'say what % is: grams, millilitres, something',
      p_amount;
  end if;
  if p_supply_id is null and btrim(coalesce(p_what, '')) = '' then
    raise exception 'say what went in, either off the shelf or by name';
  end if;

  -- Every named vessel must hold the same lot. Adding to two vessels holding
  -- different wine in one action is two additions, and recording it as one puts
  -- a rate on the record that neither of them experienced.
  select array_agg(distinct pl.node_id) into node_ids
    from placement pl
   where pl.vessel_id = any(p_vessel_ids) and pl.to_at is null;

  if node_ids is null or array_length(node_ids, 1) = 0 then
    raise exception 'there is no wine in %',
      coalesce((select string_agg(v.name, ', ' order by v.name)
                  from vessel v where v.id = any(p_vessel_ids)),
               'that vessel');
  end if;
  if array_length(node_ids, 1) > 1 then
    raise exception
      'those vessels hold different lots, so one addition cannot be a record of both';
  end if;

  select * into lot from node where id = node_ids[1];
  if lot.status = 'closed' then
    raise exception 'that lot is closed, so nothing more goes into it';
  end if;

  if p_supply_id is not null then
    select * into s from supply where id = p_supply_id;
    if s.id is null then
      raise exception 'no supply with id %', p_supply_id;
    end if;
    label := coalesce(nullif(btrim(coalesce(p_what, '')), ''), s.name);
  else
    label := btrim(p_what);
  end if;

  vol := vessel_volume_at(p_vessel_ids, at_time);

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, at, provenance, data)
  values
    (ev_id, term_id('operation', 'addition'), 'node', lot.id, auth.uid(), at_time,
     'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'what',      label,
       'supply_id', p_supply_id,
       'amount',    p_amount,
       'unit',      btrim(p_unit),
       'vessels',   to_jsonb(p_vessel_ids::text[]),
       'note',      nullif(btrim(coalesce(p_note, '')), ''))));

  -- S-64, answered. The scoop leaves the shelf because it went into the wine,
  -- rather than because somebody remembered to say so afterwards.
  if p_supply_id is not null then
    if lower(btrim(s.unit)) = lower(btrim(p_unit)) then
      insert into supply_movement (supply_id, kind, quantity, by_user, at, caused_by, note)
      values (p_supply_id, 'used', p_amount, auth.uid(), at_time, ev_id,
              'added to ' || lot.name);
      moved := true;
    else
      -- Recorded in full, and the shelf left alone, because a factor guessed
      -- here is an inventory that is confidently wrong. S-63.
      why := format(
        'the addition is in %s and the shelf keeps %s in %s, and nothing here converts between them, so the shelf was left alone',
        btrim(p_unit), s.name, s.unit);
    end if;
  end if;

  return jsonb_build_object(
    'event_id',  ev_id,
    'node_id',   lot.id,
    'lot_name',  lot.name,
    'what',      label,
    'amount',    p_amount,
    'unit',      btrim(p_unit),
    -- Said back rather than stored. A rate nobody can recompute is a number
    -- somebody has to trust, and this one is arithmetic over two facts that are
    -- both in the record.
    'volume_l',  vol,
    'per_litre', case when vol > 0 then round(p_amount / vol, 6) end,
    'shelf_moved', moved,
    'shelf_note',  why
  );
end;
$$;

revoke all on function add_to_wine(uuid[], numeric, text, uuid, text, timestamptz, text) from public;
grant execute on function add_to_wine(uuid[], numeric, text, uuid, text, timestamptz, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Reading them back
-- ---------------------------------------------------------------------------

-- Alexis's form wants addition, date, wine volume and rate. Three of those four
-- are one recorded fact and two derivations, which is why the table has one
-- column for them and this has four.
create or replace view lot_addition with (security_invoker = true) as
select
  e.id          as event_id,
  e.subject_id  as node_id,
  n.name        as lot_name,
  e.at,
  e.data ->> 'what'                  as what,
  (e.data ->> 'supply_id')::uuid     as supply_id,
  (e.data ->> 'amount')::numeric     as amount,
  e.data ->> 'unit'                  as unit,
  e.data ->> 'note'                  as note,
  coalesce(
    (select array_agg(v.name order by v.name)
       from jsonb_array_elements_text(e.data -> 'vessels') as x(vessel_id)
       join vessel v on v.id = x.vessel_id::uuid),
    array[]::text[])                 as vessels,
  -- As it stood when the addition was made, not as it stands now. A lot racked
  -- twice since is still a lot that had this much in it that day.
  vessel_volume_at(
    array(select x.vessel_id::uuid
            from jsonb_array_elements_text(e.data -> 'vessels') as x(vessel_id)),
    e.at)                            as volume_l,
  case when vessel_volume_at(
         array(select x.vessel_id::uuid
                 from jsonb_array_elements_text(e.data -> 'vessels') as x(vessel_id)),
         e.at) > 0
       then round((e.data ->> 'amount')::numeric / vessel_volume_at(
              array(select x.vessel_id::uuid
                      from jsonb_array_elements_text(e.data -> 'vessels') as x(vessel_id)),
              e.at), 6)
  end                                as per_litre,
  exists (select 1 from supply_movement m where m.caused_by = e.id) as took_from_the_shelf
from event e
join node n on n.id = e.subject_id
where e.subject_type = 'node'
  and e.operation_id = term_id('operation', 'addition');

comment on view lot_addition is
  'Every addition, with the volume of wine it went into and the resulting rate '
  'computed from the placements as they stood at the time rather than stored. '
  '`took_from_the_shelf` says whether the inventory moved with it. See 0050.';

commit;
