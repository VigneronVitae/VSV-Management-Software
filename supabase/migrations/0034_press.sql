-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Press. Fruit becomes juice, the bins empty, the lot acquires the
--           identity it keeps for the rest of its life, and a borrowed bin
--           starts being owed back rather than becoming invisible."
-- Depends on: [supabase/migrations/0013_close_on_empty.sql,
--              supabase/migrations/0014_rack.sql,
--              supabase/migrations/0033_intake.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0036_bins_on_loan.sql]
-- Axioms enforced: T0-1 (one node type), T0-2 (composition is derived by
--                  walking lineage, never copied), T0-5 (append only)
-- Open sorries: S-52 (a press records no cuts, so free run and hard press are
--               one lot until somebody presses them separately)
-- ---------------------------------------------------------------------------
--
-- Build order 3 in spec.md §7: where lots acquire their identity. A bin of fruit
-- is a thing that happened in a vineyard; the lot that comes off the press is
-- the thing that gets talked about, sampled, topped, blended and eventually
-- bottled, and every one of those depends on this row existing correctly.
--
-- **Press is structurally a blend, in different units.** Several parents
-- contribute, one child comes out, and the fraction each parent holds of the
-- child is its share of what went in. `rack` already does that arithmetic for
-- litres and this does it for pounds, which is the honest denominator here: what
-- the wine is made of is decided by fruit weight, not by how much juice happened
-- to run.
--
-- **Whites press before fermentation and reds press off skins after**, which is
-- the same verb at two positions in the sequence, so the stage the child lands
-- at is read off the stage the parents were at rather than chosen on a screen.
-- Fruit in bins presses to a ferment. A ferment presses to maturation.
--
-- **It refuses fruit that was never weighed.** Pressing is the last moment the
-- fruit exists as fruit: afterwards there is juice and a number nobody can go
-- back for. A pick whose quantity is null has no weight at all and pressing it
-- would destroy the only chance to record one, so that raises. A pick with
-- *some* bins still unweighed is allowed through and says so in its result,
-- because there the arithmetic is sound and the judgment is the winemaker's.

begin;

-- ---------------------------------------------------------------------------
-- The press
-- ---------------------------------------------------------------------------

create or replace function press(
  p_sources      jsonb,
  p_destinations jsonb,
  p_node         jsonb default '{}'::jsonb,
  p_data         jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  src        jsonb;
  dst        jsonb;
  n          node%rowtype;
  child      uuid := coalesce((p_node ->> 'id')::uuid, gen_random_uuid());
  want       numeric;
  total_in   numeric := 0;
  total_out  numeric := 0;
  parent_ids uuid[] := '{}';
  weights    numeric[] := '{}';
  i          int;
  child_stage node_stage;
  parent_stage node_stage;
  waiting    int := 0;
  v_id       uuid;
  vol        numeric;
  held       numeric;
  emptied    int := 0;
  ev_id      uuid := gen_random_uuid();
begin
  if p_sources is null or jsonb_array_length(p_sources) = 0 then
    raise exception 'nothing was named to press';
  end if;
  if p_destinations is null or jsonb_array_length(p_destinations) = 0 then
    raise exception 'the juice has to go somewhere; name at least one vessel';
  end if;

  -- Pass one: read the parents and decide what may be pressed. Nothing is
  -- written until every source has been checked, so a press that is going to be
  -- refused does not half happen.
  for src in select value from jsonb_array_elements(p_sources)
  loop
    select * into n from node where id = (src ->> 'node_id')::uuid;
    if n.id is null then
      raise exception 'no lot with id %', src ->> 'node_id';
    end if;
    if n.status = 'closed' then
      raise exception '% is closed; there is nothing left in it to press', n.name;
    end if;

    -- The guard this migration exists for. Weight is recoverable right up to
    -- the moment the fruit goes through the press and never afterwards.
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

  -- Same verb, different position in the sequence. Whites press before
  -- fermentation and reds press off skins after, so the answer is read off the
  -- parents rather than asked for on a screen.
  child_stage := coalesce(
    (p_node ->> 'stage')::node_stage,
    case when parent_stage = 'bin' then 'ferment'::node_stage
         else 'maturation'::node_stage end);

  for dst in select value from jsonb_array_elements(p_destinations)
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

  -- The child. Variety, vintage and owner survive only where every parent
  -- agrees, per the rule `rack` established: where they disagree the answer is
  -- genuinely nothing and composition is derived from lineage rather than
  -- copied onto the child.
  -- No block_id. `block_only_on_bins` refuses it above bin stage and the
  -- constraint is right: T0-2 says composition downstream is derived by walking
  -- lineage, never copied, so a child carrying its parent's block would be a
  -- stored answer that could disagree with `block_composition`. Caught here by
  -- the constraint on the first run, which is what it is for.
  insert into node (id, stage, status, name, quantity, unit,
                    variety_id, vintage, product_type_id,
                    owner_id, created_by, attributes)
  select
    child, child_stage, 'open',
    coalesce(nullif(p_node ->> 'name', ''),
             (select p.name from node p where p.id = parent_ids[1]) || ' pressed'),
    total_out, 'L',
    (select case when count(distinct p.variety_id) = 1
                 then (array_agg(distinct p.variety_id))[1] end
       from node p where p.id = any(parent_ids)),
    (select case when count(distinct p.vintage) = 1
                 then min(p.vintage) end
       from node p where p.id = any(parent_ids)),
    coalesce((select case when count(distinct p.product_type_id) = 1
                          then (array_agg(distinct p.product_type_id))[1] end
                from node p where p.id = any(parent_ids)),
             term_id('product_type', 'wine')),
    -- One owner_id, because RLS scopes a client's view by it and a null here
    -- hides the wine from everyone who part owns it. See S-22.
    (select p.owner_id from node p where p.id = any(parent_ids)
      order by p.quantity desc nulls last limit 1),
    auth.uid(),
    coalesce(p_node -> 'attributes', '{}'::jsonb);

  -- Lineage by fruit weight. The denominator is what the parents put in rather
  -- than what came out of the press, so the shares sum to one and the press
  -- yield does not change what the wine is made of.
  for i in 1 .. array_length(parent_ids, 1)
  loop
    insert into lineage (parent_id, child_id, fraction)
    values (parent_ids[i], child,
            greatest(least(weights[i] / nullif(total_in, 0), 1), 0.00001));
  end loop;

  -- Take the fruit out of the parents. The node closing when it reaches nothing
  -- is 0013's rule and not this function's business.
  for i in 1 .. array_length(parent_ids, 1)
  loop
    select quantity into held from node where id = parent_ids[i];
    update node set quantity = greatest(held - weights[i], 0)
     where id = parent_ids[i];

    -- A bin is empty when the fruit it held is gone, which is what frees it for
    -- the next pick and, if it is borrowed, starts it being owed back.
    if held - weights[i] <= 0.0001 then
      update placement set to_at = now()
       where node_id = parent_ids[i] and to_at is null;
      get diagnostics emptied = row_count;
    end if;
  end loop;

  for dst in select value from jsonb_array_elements(p_destinations)
  loop
    insert into placement (node_id, vessel_id, volume_l)
    values (child, (dst ->> 'vessel_id')::uuid, (dst ->> 'volume_l')::numeric);
  end loop;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'press'), 'node', child, auth.uid(), 'observed',
     coalesce(p_data, '{}'::jsonb) || jsonb_build_object(
       'lbs_in', total_in,
       'litres_out', total_out,
       'yield_l_per_ton', round(total_out / nullif(total_in, 0) * 2000, 2),
       'parents', to_jsonb(parent_ids::text[])));

  return jsonb_build_object(
    'node_id',         child,
    'stage',           child_stage,
    'lbs_in',          total_in,
    'litres_out',      total_out,
    'yield_l_per_ton', round(total_out / nullif(total_in, 0) * 2000, 2),
    'bins_emptied',    emptied,
    -- Not fatal and not silent. The arithmetic is sound without these bins'
    -- weights, and somebody should know the pick went through the press with
    -- containers on it that never reached a scale.
    'unweighed_left',  waiting,
    'event_id',        ev_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- The bin that is empty and not yours
-- ---------------------------------------------------------------------------

-- The winemaker's point, and the reason "empty" is not the same as "available":
-- a bin borrowed from the grower of the fruit has to go back, and the moment it
-- becomes returnable is the moment it stops holding anything. A client's bin and
-- a borrowed bin are different situations, so the flag is per bin rather than
-- read off who owns it.
create or replace view bin_to_return with (security_invoker = true) as
select
  v.id          as vessel_id,
  v.name        as bin_name,
  vt.label      as bin_type,
  v.owner_id,
  p.name        as owed_to,
  v.location_id
from vessel v
join term vt on vt.id = v.type_id and vt.kind = 'vessel_type'
left join party p on p.id = v.owner_id
where v.active
  and coalesce((v.attributes ->> 'borrowed')::boolean, false)
  and not exists (
    select 1 from placement pl where pl.vessel_id = v.id and pl.to_at is null
  );

comment on view bin_to_return is
  'Borrowed bins with nothing in them. Empty is not the same as available: these '
  'are owed back to whoever lent them. See 0034.';

commit;
