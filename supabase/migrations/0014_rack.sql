-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Racking, as one operation. The cellar does not distinguish moving
--           wine from combining wine: somebody puts a hose between vessels. So
--           the caller says which vessels wine came out of and which it went
--           into, and the kernel works out whether that preserved a lot or made
--           a new one."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0004_terms_and_effects.sql,
--              supabase/migrations/0013_close_on_empty.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql, supabase/migrations/0015_fork_and_history.sql, supabase/migrations/0021_cellar_write_paths.sql]
-- Axioms enforced: T0-2 (loss is derived, never stored), T0-3 (provenance on
--                  every event), T0-5 (append only)
-- Open sorries: S-21 (quantity stored and derivable), S-22 (a blend across
--               owners keeps one owner_id), S-23 (lees are recorded as a
--               quantity and are not yet material)
-- ---------------------------------------------------------------------------

-- Why one function rather than two.
--
-- Moving a lot and blending lots have different consequences: one adds
-- placements, the other mints a node and writes lineage. But they are the same
-- act in the cellar, and a client that decided which one was happening would be
-- a client deciding a business rule, which is the thing CLAUDE.md forbids. So
-- the caller describes the physical transfer and the kernel reads the shape:
--
--   every source holds the same lot, destinations empty  ->  the lot moves
--   sources hold different lots                          ->  a new lot
--   a destination already holds a different lot          ->  a new lot
--
-- The operator never picks a mode, and never has to know they crossed from one
-- to the other. Which is precisely why rack_plan exists: the same rule, run
-- without writing anything, so a screen can say what is about to happen while
-- it is still cheap to change your mind.

-- ---------------------------------------------------------------------------
-- What this transfer would do
-- ---------------------------------------------------------------------------

create or replace function rack_plan(
  p_sources      jsonb,
  p_destinations jsonb
)
returns jsonb
language plpgsql
stable
as $$
declare
  src        jsonb;
  dst        jsonb;
  parents    jsonb := '[]'::jsonb;
  overfill   jsonb := '[]'::jsonb;
  out_total  numeric := 0;
  in_total   numeric := 0;
  node_ids   uuid[] := '{}';
  owners     uuid[] := '{}';
  v_id       uuid;
  n_id       uuid;
  vol        numeric;
  held       numeric;
  cap        numeric;
  v_name     text;
  n_name     text;
  n_owner    uuid;
begin
  if jsonb_array_length(coalesce(p_sources, '[]'::jsonb)) = 0 then
    raise exception 'a rack needs somewhere to come from';
  end if;
  if jsonb_array_length(coalesce(p_destinations, '[]'::jsonb)) = 0 then
    raise exception 'a rack needs somewhere to go';
  end if;

  -- Sources. Each must currently hold something, because wine cannot come out
  -- of a vessel the app believes is empty.
  for src in select value from jsonb_array_elements(p_sources)
  loop
    v_id := (src ->> 'vessel_id')::uuid;
    vol  := (src ->> 'volume_l')::numeric;

    select p.node_id, p.volume_l, v.name, n.name, n.owner_id
      into n_id, held, v_name, n_name, n_owner
      from placement p
      join vessel v on v.id = p.vessel_id
      join node n on n.id = p.node_id
     where p.vessel_id = v_id and p.to_at is null;

    if n_id is null then
      select name into v_name from vessel where id = v_id;
      raise exception '% is empty, so nothing can be racked out of it',
        coalesce(v_name, v_id::text);
    end if;

    if vol is null or vol <= 0 then
      raise exception 'how much came out of % is not recorded', v_name;
    end if;
    if held is not null and vol > held then
      raise exception '% holds % L and this takes % L out of it', v_name, held, vol;
    end if;

    out_total := out_total + vol;
    if not (n_id = any(node_ids)) then
      node_ids := node_ids || n_id;
      owners   := owners || n_owner;
      parents  := parents || jsonb_build_object(
        'node_id', n_id, 'name', n_name, 'owner_id', n_owner, 'volume_l', vol);
    else
      -- the same lot drawn from more than one of its vessels
      parents := (
        select jsonb_agg(
          case when (e ->> 'node_id')::uuid = n_id
               then jsonb_set(e, '{volume_l}',
                    to_jsonb((e ->> 'volume_l')::numeric + vol))
               else e end)
        from jsonb_array_elements(parents) e);
    end if;
  end loop;

  -- Destinations. A destination that already holds a different lot is not an
  -- error, it is a blend, and the lot already in there is another parent.
  for dst in select value from jsonb_array_elements(p_destinations)
  loop
    v_id := (dst ->> 'vessel_id')::uuid;
    vol  := (dst ->> 'volume_l')::numeric;

    select v.name, v.capacity_l into v_name, cap from vessel v where v.id = v_id;
    if v_name is null then
      raise exception 'no vessel with id %', v_id;
    end if;
    if vol is null or vol <= 0 then
      raise exception 'how much went into % is not recorded', v_name;
    end if;

    select p.node_id, p.volume_l, n.name, n.owner_id
      into n_id, held, n_name, n_owner
      from placement p join node n on n.id = p.node_id
     where p.vessel_id = v_id and p.to_at is null;

    if n_id is not null and not (n_id = any(node_ids)) then
      node_ids := node_ids || n_id;
      owners   := owners || n_owner;
      parents  := parents || jsonb_build_object(
        'node_id', n_id, 'name', n_name, 'owner_id', n_owner,
        'volume_l', coalesce(held, 0));
    end if;

    in_total := in_total + vol;

    -- Capacity is the one physical impossibility worth refusing. Nominal and
    -- actual differ, so this is a question rather than a wall: the caller can
    -- say it meant it, and that saying so is recorded.
    if cap is not null and (coalesce(held, 0) + vol) > cap then
      overfill := overfill || jsonb_build_object(
        'vessel_id', v_id, 'name', v_name, 'capacity_l', cap,
        'would_hold', coalesce(held, 0) + vol);
    end if;
  end loop;

  return jsonb_build_object(
    'kind',        case when array_length(node_ids, 1) = 1 then 'move' else 'blend' end,
    'node_id',     case when array_length(node_ids, 1) = 1 then node_ids[1] end,
    'parents',     parents,
    'out_l',       out_total,
    'in_l',        in_total,
    -- Derived, never stored. T0-2.
    'loss_l',      out_total - in_total,
    'overfill',    overfill,
    'mixed_owners',(select count(distinct o) > 1 from unnest(owners) o where o is not null)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Do it
-- ---------------------------------------------------------------------------

create or replace function rack(
  p_sources        jsonb,
  p_destinations   jsonb,
  p_data           jsonb   default '{}'::jsonb,
  p_allow_overfill boolean default false,
  p_node           jsonb   default '{}'::jsonb
)
returns jsonb
language plpgsql
as $$
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
                      variety_id, vintage, product_type_id, owner_id, created_by,
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
      (select case when count(distinct n.vintage) = 1
                   then min(n.vintage) end
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
$$;
