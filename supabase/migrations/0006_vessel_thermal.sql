-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Lets a vessel's thermal state be written. The columns have existed
--           since 0001 and the derived view has always read them, but no write
--           path ever set them, so every vessel was unjacketed forever and
--           effective_temp_c always fell through to the location's ambient."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0005_account_and_walk.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Open sorries: S-18 (thermal state is set at creation, records no
--               setpoint_change event, and cannot be changed afterwards)
-- ---------------------------------------------------------------------------

-- The spec says a jacketed vessel's setpoint overrides its location's ambient,
-- and that cold soak and cold crash are therefore derivable states rather than
-- only logged events. vessel_state has computed exactly that since 0002:
--
--   coalesce(case when has_glycol and mode <> 'off' then setpoint_c end,
--            l.ambient_c)
--
-- What was missing was any way to make has_glycol true. create_vessel_with_wine
-- named its insert columns explicitly and left all three out, so a client that
-- sent them got silent discard rather than an error, which is the worse of the
-- two failures. The screens never offered them at all. The result was a rule
-- that was correct, tested, and unreachable.

-- ---------------------------------------------------------------------------
-- Refuse the combinations that mean nothing
-- ---------------------------------------------------------------------------

-- Without these a tank can claim to be cooling to no particular temperature, or
-- cooling with no jacket to cool with, and vessel_state answers by quietly
-- falling back to ambient. That is a wrong number rather than a refusal, and it
-- is the kind that reads as correct. The checks live here rather than in the
-- screen because a second skin would otherwise have to reimplement both, and
-- would get one of them wrong.

alter table vessel
  add constraint vessel_mode_needs_jacket
  check (mode = 'off' or has_glycol);

alter table vessel
  add constraint vessel_mode_needs_setpoint
  check (mode = 'off' or setpoint_c is not null);

-- ---------------------------------------------------------------------------
-- Carry the thermal columns through the one-action create
-- ---------------------------------------------------------------------------

-- Identical to the 0005 body apart from the three columns on the vessel insert.
-- Their defaults repeat the table's own, so a payload that omits them behaves
-- exactly as it did before this migration.

create or replace function create_vessel_with_wine(
  p_vessel           jsonb,
  p_node             jsonb,
  p_volume_l         numeric default null,
  p_codes            jsonb default '[]'::jsonb,
  p_generate_history boolean default true
)
returns jsonb
language plpgsql
as $$
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
$$;
