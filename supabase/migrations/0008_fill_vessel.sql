-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Lets wine be recorded into a vessel that already exists. Until now
--           placement was written in exactly one place, inside
--           create_vessel_with_wine, so wine could only enter a vessel at the
--           instant the vessel was created and an empty vessel stayed empty
--           for good."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0005_account_and_walk.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-3 (provenance on every event), T0-4 (a producer cannot
--                  grant itself standing)
-- Open sorries: S-19 (this records wine arriving with no source, which is
--               right for inventory and wrong for a rack)
-- ---------------------------------------------------------------------------

-- Build order 1 in the spec is "creating a barrel of Chardonnay registers
-- vessel, lot, and placement in one action". create_vessel_with_wine does that
-- for a vessel that does not exist yet. This is the same action for a vessel
-- that does, which is what the walk hits the moment somebody adds an empty tank
-- and then finds wine in it.
--
-- This is the inventory case and only the inventory case: it declares that wine
-- is in a vessel, with no claim about where it came from. Moving wine that the
-- app already knows about is a rack, it closes a placement as well as opening
-- one, and it is not this function. S-19 names the difference so that this one
-- does not get quietly used for both.

create or replace function fill_vessel(
  p_vessel_id        uuid,
  p_node             jsonb,
  p_volume_l         numeric default null,
  p_generate_history boolean default true
)
returns jsonb
language plpgsql
as $$
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
    (id, stage, status, name, variety_id, vintage, product_type_id,
     quantity, unit, attributes, owner_id, created_by)
  values
    (n_id,
     coalesce((p_node ->> 'stage')::node_stage, 'maturation'),
     'open',
      p_node ->> 'name',
     (p_node ->> 'variety_id')::uuid,
     (p_node ->> 'vintage')::int,
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
$$;
