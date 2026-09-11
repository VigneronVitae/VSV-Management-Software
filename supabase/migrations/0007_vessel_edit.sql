-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Makes a vessel editable after it exists, and makes a change to its
--           thermal state record itself. Until now a vessel was whatever it was
--           at the moment it was created, which meant a barrel could never be
--           moved and a tank's jacket could never be turned on."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0004_terms_and_effects.sql,
--              supabase/migrations/0006_vessel_thermal.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-3 (provenance on every event), T0-5 (append-only
--                  history: the correction is a new event, never an edit)
-- Discharges: S-18, in the half that said a thermal state could be set and
--             never changed and recorded nothing when it was
-- ---------------------------------------------------------------------------

-- The spec is careful that a setpoint is a decision and a reading is an
-- observation, and asks for both histories. A vessel's three thermal columns
-- are the current value of a decision, so changing them has to leave a trace or
-- the history is only ever the present tense.
--
-- This lives in a function rather than in a client for the ordinary reason: if
-- a screen decides when a setpoint change is worth recording, the second screen
-- will decide differently and the two histories will disagree. The kernel
-- compares before to after and writes the event, so every caller records the
-- same thing whether or not it remembered to.
--
-- Security invoker on purpose. RLS then applies as it would to a direct write,
-- so vessel_admin_write still means only an admin may edit a vessel, and
-- event_insert still means the event is written as the caller rather than on
-- their behalf.

create or replace function update_vessel(p_vessel_id uuid, p_patch jsonb)
returns jsonb
language plpgsql
as $$
declare
  was vessel%rowtype;
  now_ vessel%rowtype;
begin
  select * into was from vessel where id = p_vessel_id;
  if not found then
    raise exception 'no vessel with id %', p_vessel_id;
  end if;

  -- Key present means "set this, including to null". Key absent means "leave
  -- it". A patch that says nothing changes nothing, which is what lets the
  -- thermal comparison below be trusted.
  update vessel set
    type_id     = case when p_patch ? 'type_id'
                       then (p_patch ->> 'type_id')::uuid else type_id end,
    name        = case when p_patch ? 'name'
                       then p_patch ->> 'name' else name end,
    capacity_l  = case when p_patch ? 'capacity_l'
                       then (p_patch ->> 'capacity_l')::numeric else capacity_l end,
    location_id = case when p_patch ? 'location_id'
                       then (p_patch ->> 'location_id')::uuid else location_id end,
    owner_id    = case when p_patch ? 'owner_id'
                       then (p_patch ->> 'owner_id')::uuid else owner_id end,
    attributes  = case when p_patch ? 'attributes'
                       then p_patch -> 'attributes' else attributes end,
    has_glycol  = case when p_patch ? 'has_glycol'
                       then (p_patch ->> 'has_glycol')::boolean else has_glycol end,
    setpoint_c  = case when p_patch ? 'setpoint_c'
                       then (p_patch ->> 'setpoint_c')::numeric else setpoint_c end,
    mode        = case when p_patch ? 'mode'
                       then (p_patch ->> 'mode')::thermal_mode else mode end
  where id = p_vessel_id
  returning * into now_;

  -- Only a thermal change is a decision. Renaming a barrel or correcting its
  -- capacity is a fact about the vessel, not about the wine, and the spec does
  -- not ask for a history of it.
  if (was.has_glycol, was.setpoint_c, was.mode)
     is distinct from
     (now_.has_glycol, now_.setpoint_c, now_.mode)
  then
    insert into event
      (operation_id, subject_type, subject_id, by_user, data, provenance)
    values
      (term_id('operation', 'setpoint_change'),
       'vessel',
       p_vessel_id,
       auth.uid(),
       jsonb_build_object(
         'has_glycol', now_.has_glycol,
         'setpoint_c', now_.setpoint_c,
         'mode',       now_.mode,
         'was', jsonb_build_object(
           'has_glycol', was.has_glycol,
           'setpoint_c', was.setpoint_c,
           'mode',       was.mode)),
       -- Never confirmed. A producer recording its own decision is observing
       -- it, and T0-4 says standing is granted by a verifier and not taken.
       'observed');
  end if;

  return jsonb_build_object(
    'vessel_id',      p_vessel_id,
    'thermal_change', (was.has_glycol, was.setpoint_c, was.mode)
                      is distinct from
                      (now_.has_glycol, now_.setpoint_c, now_.mode)
  );
end;
$$;
