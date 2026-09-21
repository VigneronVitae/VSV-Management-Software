-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A volume in a vessel can say whether somebody read it or guessed it,
--           because most of them are guesses and nothing has ever recorded which."
-- Depends on: [supabase/migrations/0014_rack.sql,
--              supabase/migrations/0008_fill_vessel.sql,
--              supabase/migrations/0137_harvest_so_far.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts]
-- Axioms enforced: T0-4, applied to a number rather than to a record. The
--                  person entering the volume says how well it is known and
--                  nothing works it out for them, because a kernel that decided
--                  a full-looking vessel had been measured would be writing a
--                  trust field on behalf of the producer.
--                  A13. Null is a third answer and not a default. "Nobody said"
--                  is different from "measured" and different from "guessed".
-- Open sorries: none new. See S-141 on the five other functions.
-- ---------------------------------------------------------------------------

-- "Liters are often guesses, mostly when they're not guesses it's because a
-- vessel is full. Like when I racked into barrels I guessed 200-210 liters
-- because I put them at fermentation height. When I filled the 1100l with 950
-- liters I guessed at that number. Sometimes they have a liter read sometimes
-- they don't. So one thing is when I type an amount there should be a flag for
-- measure vs estimate."
--
-- **The system already has the word for this and it is `provenance`.** A volume
-- read off a sight gauge is `observed`; a volume worked out from how high the
-- wine sits in a barrel is `inferred`. `note` and `event` have carried that enum
-- since the beginning and `placement`, which holds the number everything else
-- sums, never has.
--
-- **The column is nullable and has no default, which is the important decision.**
-- Defaulting to `observed` would assert that all eighteen existing placements
-- were measured, and he has just said most volumes are guesses. Defaulting to
-- `inferred` would assert the opposite about the ones that were read. Null means
-- nobody said, which is true of every row written before today and is a
-- different fact from either answer. A13 is usually about refusals; here it is
-- about a column.
--
-- **What this deliberately does not do is work it out.** "Mostly when they're
-- not guesses it's because a vessel is full" is a real correlation and it is
-- exactly the kind of thing a kernel must not act on: a full vessel is evidence,
-- not a measurement, and marking one `observed` because the arithmetic looked
-- tidy is T0-4's specific prohibition. A periphery may *offer* measured as the
-- default when the amount equals the capacity. The person still says.

alter table placement
  add column if not exists volume_provenance provenance;

comment on column placement.volume_provenance is
  'Whether the volume was read or guessed. observed is a gauge or a full vessel '
  'somebody checked; inferred is an estimate from how high the wine sits. Null '
  'means nobody said, which every row written before 0141 is.';

-- ---------------------------------------------------------------------------
-- The two verbs where he types a number
-- ---------------------------------------------------------------------------

-- A leg may now carry `measured`, a boolean, alongside `vessel_id` and
-- `volume_l`. Absent stays null, so every existing caller means exactly what it
-- meant yesterday. A boolean rather than the enum because a boolean is what a
-- toggle is, and `confirmed` has no meaning for a number nobody re-measured.
create or replace function placement_provenance(p_leg jsonb)
returns provenance
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
           when p_leg ? 'measured' and (p_leg ->> 'measured')::boolean then 'observed'::provenance
           when p_leg ? 'measured' then 'inferred'::provenance
         end;
$$;

comment on function placement_provenance is
  'Translates a leg''s measured flag into the provenance a placement stores. '
  'Absent means null, which is nobody having said.';

-- Not a verb, so not a capability. It reads one json object and returns an enum,
-- touches nothing and decides nothing a person would recognise as an action. The
-- contract check is right to demand an answer either way, and this is the answer:
-- a periphery never calls it, `rack` does.
insert into capability_exemption (fn, reason) values
  ('placement_provenance',
   'A pure translation from a leg''s measured flag to the provenance stored on the placement. It reads no table and writes none, and a periphery has no reason to call it: it sends `measured` on the leg and rack does the rest.')
on conflict (fn) do update set reason = excluded.reason;

-- `rack` and `fill_vessel` restated with the flag threaded through. Both bodies
-- are the live definitions with two lines changed, taken from
-- `pg_get_functiondef` rather than retyped, because `rack` is four hundred lines
-- and a hand copy of it would be wrong in a way nothing would catch. `fill_vessel`
-- gains a parameter; `rack` gains nothing, because a leg is already a json object
-- and `measured` is a field on it.

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
  -- 0103. What each destination already held, by vessel. It is part of the
  -- blend and it is still in the vessel afterwards, which is the fact this
  -- function used to lose.
  absorbed   jsonb := '{}'::jsonb;
  absorbed_l numeric := 0;
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

        -- 0103. Remembered per vessel, because it goes back into that same
        -- vessel below. rack_plan already counts it as a parent's contribution,
        -- which is why the shares were right while the volume was not.
        absorbed := absorbed || jsonb_build_object(
          dst ->> 'vessel_id', coalesce(held, 0));
        absorbed_l := absorbed_l + coalesce(held, 0);

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
    -- What arrived, plus what was already standing there and has just been
    -- absorbed into this blend. 0014 wrote only the first of those, so a barrel
    -- holding 50 L that took 150 L read as 150 L afterwards and fifty litres of
    -- wine left the record while staying in the barrel.
    vol  := (dst ->> 'volume_l')::numeric
            + coalesce((absorbed ->> (dst ->> 'vessel_id'))::numeric, 0);

    select p.volume_l into held
      from placement p where p.vessel_id = v_id and p.to_at is null
       and p.node_id = target;

    if held is not null then
      -- 0141. The flag belongs to the amount somebody typed, so it follows the
      -- leg rather than the vessel. Absent stays null, which is nobody having
      -- said, and is what every leg written before today means.
      update placement set volume_l = held + vol,
             volume_provenance = placement_provenance(dst)
       where vessel_id = v_id and to_at is null and node_id = target;
    else
      insert into placement (node_id, vessel_id, volume_l, volume_provenance)
      values (target, v_id, vol, placement_provenance(dst));
    end if;
  end loop;

  -- The blend was minted with what arrived, before anything was known about
  -- what the destinations already held. A lot whose quantity disagrees with the
  -- placements holding it is the shape T0-2 exists to prevent, and here it was
  -- low by exactly the wine that was already in the vessel.
  if plan ->> 'kind' = 'blend' and absorbed_l > 0 then
    update node set quantity = coalesce(total_in, 0) + absorbed_l
     where id = target;
  end if;

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

  return plan || jsonb_build_object('node_id', target, 'event_id', ev_id,
                                   -- So a screen can say what is in the vessel
                                   -- rather than only what went down the hose.
                                   'absorbed_l', absorbed_l);
end;
$function$;

-- Dropped by its old signature first. `create or replace function` with a new
-- parameter overloads rather than replaces, so both arities would live in the
-- catalog and `fill_vessel(uuid, jsonb, numeric)` would be ambiguous. This is
-- the third time today: 0131 on `add_note`, 0134 on `tag_place`, and now here.
-- Replace does less than it sounds like it does.
drop function if exists fill_vessel(uuid, jsonb, numeric, boolean);

CREATE OR REPLACE FUNCTION public.fill_vessel(p_vessel_id uuid, p_node jsonb, p_volume_l numeric DEFAULT NULL::numeric, p_generate_history boolean DEFAULT true, p_measured boolean DEFAULT NULL::boolean)
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

  -- 0141. `fill_vessel` takes one volume rather than a list of legs, so the
  -- flag is a parameter rather than a field on a leg. Null by default, which is
  -- nobody having said.
  insert into placement (id, node_id, vessel_id, volume_l, volume_provenance)
  values (p_id, n_id, p_vessel_id, p_volume_l,
          case when p_measured is null then null
               when p_measured then 'observed'::provenance
               else 'inferred'::provenance end);

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

-- ---------------------------------------------------------------------------
-- What it is for
-- ---------------------------------------------------------------------------

-- The payoff, and the reason to record it at all: a total that says how much of
-- itself is a guess. Without this the flag is a column nobody reads.
--
-- It has to be split one level down, on `harvest_lot_now`, because a lot sitting
-- in three barrels can have three different answers and a single provenance per
-- lot would have to pick one. So the split is over placements and the share is
-- applied to each part, which keeps a blend's arithmetic the same as it was.
--
-- Both dropped and rebuilt rather than replaced, and in dependency order,
-- because the new columns land in the middle of `harvest_lot_now` and
-- `create or replace view` refuses to move a column. Appending them to the end
-- to avoid that would be arranging the view around a limitation of one
-- statement, which is the note 0130 left about `money_queue`.
drop view if exists harvest_so_far;
drop view if exists harvest_lot_now;

create view harvest_lot_now with (security_invoker = true) as
select
  b.id            as pick_id,
  b.name          as pick,
  n.id            as lot_id,
  n.name          as lot,
  n.stage,
  n.status,
  s.share,
  (select sum(p.volume_l)
     from placement p
    where p.node_id = n.id and p.to_at is null) as lot_l,
  round(
    coalesce((select sum(p.volume_l)
                from placement p
               where p.node_id = n.id and p.to_at is null), 0) * s.share, 1) as share_l,
  round(coalesce((select sum(p.volume_l) from placement p
                   where p.node_id = n.id and p.to_at is null
                     and p.volume_provenance = 'observed'), 0) * s.share, 1) as share_l_measured,
  round(coalesce((select sum(p.volume_l) from placement p
                   where p.node_id = n.id and p.to_at is null
                     and p.volume_provenance = 'inferred'), 0) * s.share, 1) as share_l_estimated,
  round(coalesce((select sum(p.volume_l) from placement p
                   where p.node_id = n.id and p.to_at is null
                     and p.volume_provenance is null), 0) * s.share, 1) as share_l_unsaid,
  (select string_agg(distinct v.name, ', ' order by v.name)
     from placement p
     join vessel v on v.id = p.vessel_id
    where p.node_id = n.id and p.to_at is null) as vessels
from node n
cross join lateral node_bin_shares(n.id) s
join node b on b.id = s.bin_id
where n.status = 'open';

comment on view harvest_lot_now is
  'Every pick paired with every open lot that still holds some of its fruit, '
  'with the share, the litres attributable, and how much of that was read '
  'rather than guessed.';

create view harvest_so_far with (security_invoker = true) as
select
  f.id,
  f.name,
  f.picked,
  f.vintage,
  f.variety,
  f.vineyard,
  f.block,
  f.bins,
  f.bins_weighed,
  f.lbs,
  f.tons,
  f.status                         as pick_status,
  count(h.lot_id)                  as lots_now,
  max(h.stage)                     as furthest_stage,
  round(sum(h.share_l), 1)         as litres_now,
  round(sum(h.share_l) filter (where h.stage = 'load'), 1)       as litres_at_load,
  round(sum(h.share_l) filter (where h.stage = 'ferment'), 1)    as litres_fermenting,
  round(sum(h.share_l) filter (where h.stage = 'maturation'), 1) as litres_maturing,
  round(sum(h.share_l) filter (where h.stage = 'finished'), 1)   as litres_finished,
  -- How much of that number was read and how much was somebody's eye. Three
  -- columns rather than two, because a litre nobody said anything about is not
  -- the same as a litre somebody guessed.
  round(sum(h.share_l_measured), 1)  as litres_measured,
  round(sum(h.share_l_estimated), 1) as litres_estimated,
  round(sum(h.share_l_unsaid), 1)    as litres_unsaid,
  (select string_agg(distinct x.vessels, ', ')
     from harvest_lot_now x where x.pick_id = f.id and x.vessels is not null) as vessels,
  case
    when f.tons > 0 and sum(h.share_l) > 0
      then round(sum(h.share_l) / f.tons, 1)
  end                              as litres_per_ton
from fruit_log f
left join harvest_lot_now h on h.pick_id = f.id
group by f.id, f.name, f.picked, f.vintage, f.variety, f.vineyard, f.block,
         f.bins, f.bins_weighed, f.lbs, f.tons, f.status;

comment on view harvest_so_far is
  'Every pick of the vintage with where its fruit is now, and how much of the '
  'volume was read rather than guessed.';

do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_name = 'placement' and column_name = 'volume_provenance') then
    raise exception 'a volume still cannot say whether it was measured';
  end if;
  -- The decision worth asserting: null is a real third answer, so nothing may
  -- have been given one by a default.
  if exists (select 1 from placement where volume_provenance is not null) then
    raise exception
      'a placement written before this migration was given a provenance, which claims something nobody said';
  end if;
end $$;
