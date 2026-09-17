-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Racking into a vessel that already holds wine keeps that wine. The
--           blend absorbed it as a parent and then recorded only what arrived,
--           so the litres already in the vessel left the record while staying
--           in the vessel."
-- Depends on: [supabase/migrations/0014_rack.sql,
--              supabase/migrations/0049_every_lot_says_its_vintage.sql,
--              supabase/migrations/0102_a_tank_takes_more_than_one_pressing.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0104_a_pressed_bin_leaves_the_room.sql]
-- Axioms enforced: T0-2 (a lot's quantity and the placements holding it are one
--                  fact and cannot disagree)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker, an hour after the press fix: *"I added 50 L to a barrel from
-- the press, then 150 L from a tank I pressed into (via racking). Now it's just
-- showing the 150 L in that barrel."*
--
-- **He is right and the wine was in the barrel the whole time.** VS2610 held
-- 50 L of the Sep 15 Chardonnay cut. The rack at 05:13 closed that placement,
-- made that lot a parent of a new blend, and gave the blend a placement of
-- 150 L, which is what came down the hose.
--
-- **The plan knew.** `rack_plan` counted the resident lot's 50 L as a
-- contribution, and the lineage it produced says 0.75 and 0.25, which is 150 and
-- 50 out of 200. Every share was right. Only the two numbers that say how much
-- wine there is were wrong, and they were wrong by exactly the amount that was
-- already in the barrel.
--
-- So this is not a change of behaviour. `0014` has said since the beginning that
-- a destination holding another lot is absorbed into the blend; it absorbed it
-- everywhere except in the volume.
--
-- Two numbers move: the placement in each destination gains what that vessel
-- already held, and the blend's quantity gains the total, because a lot whose
-- quantity disagrees with the placements holding it is the thing T0-2 is for.
--
-- **This replaces `0049`'s rack, not `0014`'s.** `0049` redefined the whole
-- function in upper case as `CREATE OR REPLACE FUNCTION public.rack`, which is
-- why a search for the lower case form finds only `0014`. Rebuilding from
-- `0014` would have quietly reverted the vintage handling `0049` added, and did,
-- for about four minutes: the assertion suite refused the next blend it tried to
-- write because the node violated `node_says_its_vintage`. The lesson is that
-- the source for a function is the latest definition or the live catalog, never
-- the migration that first created it.
--
-- `in_l`, `out_l` and `loss_l` are untouched and still describe the transfer:
-- 150 L left the tank and 150 L arrived. The 50 L never moved, so counting it as
-- arriving would make the loss read as negative.
--
-- **This is not retroactive.** Any rack already recorded into an occupied vessel
-- is still short by what was there, and no migration can find them reliably,
-- because a placement that is simply low looks exactly like one somebody
-- measured. VS2610 was corrected by hand with an event recording what changed
-- and why.

begin;

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
      update placement set volume_l = held + vol
       where vessel_id = v_id and to_at is null and node_id = target;
    else
      insert into placement (node_id, vessel_id, volume_l)
      values (target, v_id, vol);
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


comment on function rack(jsonb, jsonb, jsonb, boolean, jsonb) is
  'Moves or blends wine. A destination that already holds another lot is a '
  'blend, and what that vessel held stays in it: the placement is what arrived '
  'plus what was absorbed. See 0014 and 0103.';

commit;
