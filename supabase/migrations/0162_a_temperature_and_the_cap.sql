-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A temperature is read in whichever unit the thermometer reads, and
--           a punchdown or a pumpover on one fermenter never makes it a
--           different lot."
-- Depends on: [supabase/migrations/0158_a_ferment_is_variables.sql,
--              supabase/migrations/0015_fork_and_history.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-2. A reading keeps the unit it was read in; nothing is
--                  converted and stored.
-- Open sorries: S-150 is discharged.
-- ---------------------------------------------------------------------------

-- Two answers from the winemaker, 2026-09-28.
--
-- **Temperature**: "usually F but it should be an option." So there are two
-- kinds of reading, one a unit, and Fahrenheit is the one the log offers
-- first. Two kinds rather than one kind with a unit per reading, because
-- `note` has no unit column and a kind's unit is what `typed_fact` has always
-- reported (S-75): a reading in Fahrenheit is a different variable from a
-- reading in Celsius until somebody converts, and the log keeps what was read.
-- Both carry `measures: temperature`, so a form can offer them as one box with
-- a choice of unit. Their labels name the unit, because two entries in one
-- list with the same label are two entries nobody can tell apart.
--
-- **Cap work**: "Once it's in a macrobin it's one lot with a history (the
-- prior lots). Punchdown and pumpovers don't create new lots." `record_event`
-- forks a lot when an operation names only some of its vessels, which is right
-- for an addition and wrong for cap work. Operations marked `cap` (0158) now
-- keep the vessels they name in the data and never fork. S-150 asked exactly
-- this.

insert into term (kind, value, label, sort_order, attributes) values
  ('fact_kind', 'temperature_f', 'Temperature, °F', 30,
   '{"value_type": "number", "unit": "°F", "measures": "temperature"}'::jsonb),
  ('fact_kind', 'temperature_c', 'Temperature, °C', 31,
   '{"value_type": "number", "unit": "°C", "measures": "temperature"}'::jsonb)
on conflict (kind, value) do update set
  label = excluded.label, attributes = excluded.attributes, active = true;

-- This winery's thermometers read Fahrenheit. A winery that reads Celsius
-- moves this flag; nothing else changes.
update term set attributes = attributes || '{"preferred": true}'::jsonb
 where kind = 'fact_kind' and value = 'temperature_f';

CREATE OR REPLACE FUNCTION public.record_event(p_node_id uuid, p_operation text, p_data jsonb DEFAULT '{}'::jsonb, p_vessel_ids uuid[] DEFAULT NULL::uuid[], p_at timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  target  uuid := p_node_id;
  forked  boolean := false;
  n_total int;
  n_here  int;
  ev_id   uuid := gen_random_uuid();
  op_id   uuid;
begin
  op_id := term_id('operation', p_operation);
  if op_id is null then
    raise exception 'there is no operation called %', p_operation;
  end if;

  -- 0162. Cap work never makes a lot. "Once it's in a macrobin it's one lot
  -- with a history. Punchdowns and pumpovers don't create new lots." So the
  -- vessels it names are kept with it rather than used to fork, after the same
  -- check that they hold the lot at all.
  if coalesce((select (t.attributes ->> 'cap')::boolean from term t where t.id = op_id), false)
     and p_vessel_ids is not null and array_length(p_vessel_ids, 1) > 0 then
    if not exists (select 1 from placement
                    where node_id = p_node_id and to_at is null and vessel_id = any(p_vessel_ids)) then
      raise exception 'none of those vessels hold that lot';
    end if;
    p_data := coalesce(p_data, '{}'::jsonb) || jsonb_build_object('vessels', to_jsonb(p_vessel_ids));
    p_vessel_ids := null;
  end if;

  if p_vessel_ids is not null and array_length(p_vessel_ids, 1) > 0 then
    select count(*) into n_total
      from placement where node_id = p_node_id and to_at is null;
    select count(*) into n_here
      from placement
     where node_id = p_node_id and to_at is null and vessel_id = any(p_vessel_ids);

    if n_here = 0 then
      raise exception 'none of those vessels hold that lot';
    end if;

    -- A strict subset is the whole of the reason this function exists.
    if n_here < n_total then
      target := fork_lot(p_node_id, p_vessel_ids);
      forked := true;
    end if;
  end if;

  insert into event (id, operation_id, subject_type, subject_id, at, by_user,
                     data, provenance)
  values (ev_id, op_id, 'node', target, p_at, auth.uid(), p_data, 'observed');

  return jsonb_build_object('event_id', ev_id, 'node_id', target, 'forked', forked);
end;
$function$;
