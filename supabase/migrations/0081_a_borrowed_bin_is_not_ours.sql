-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A bin on loan from a grower stops reading as facility owned, because
--           it is owed back and saying it is ours is the one thing that loses
--           it."
-- Depends on: [supabase/migrations/0032_vessel_maker_and_room_temperature.sql,
--              supabase/migrations/0036_bins_on_loan.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: A13 (a negation indistinguishable from an affirmation: the
--                  form said not ours and every screen said ours)
-- Open sorries: S-82 (a client's own bins still cannot be recorded from the
--                bin screen)
-- ---------------------------------------------------------------------------
--
-- The winemaker, having registered five bins on loan from Pearlstaad: *"it also
-- looks like the bins, when created, default to facility owned even when I
-- unclicked owned by us and put Pearlstaad."*
--
-- **He is right, and what he typed was recorded correctly.** The bins carry
-- `borrowed: true` and `on_loan_from: Pearlstaad`, which is what `0036` built
-- and it works. What is wrong is everything downstream: `facility_owned` is
-- `owner_id is null`, a grower is not a party and never gets an `owner_id`, so
-- a bin that is emphatically not ours reads as ours on the vessel list, in the
-- map, and on its own screen.
--
-- **This is the A13 shape in its purest form.** The control said "not ours", the
-- database agreed, and every surface that displays it said "ours" anyway. The
-- unticked box and the ticked box produced the same visible result, which is a
-- control that does nothing as far as anybody can tell.
--
-- **Ownership here has two representations and only one was being read.** A
-- client's equipment is a party, because a client is a party. A grower's bins
-- are free text, because `0036` decided that a vineyard you buy fruit from is
-- not a party at this winery and it was right: making one would put a grower in
-- the client picker and in the privacy model. So "whose vessel" is the party or
-- the lender, and "is it ours" is neither of them being set.
--
-- Nothing here is a policy change. `facility_owned` is a display derivation and
-- no policy reads it: the policies read `owner_id`. The column order is
-- unchanged, deliberately, because this view reads `visible_node` through a
-- positional alias list and reordering silently rebinds it.

begin;

create or replace view vessel_state with (security_invoker = true) as
 SELECT v.id,
    v.type_id,
    vt.label AS type,
    v.name,
    v.capacity_l,
    v.owner_id,
    -- The party, or the grower it is on loan from. One question with two
    -- places to look, and a screen should not have to know which.
    COALESCE(o.name, NULLIF(btrim(v.attributes ->> 'on_loan_from'), '')) AS owner_name,
    -- Ours only if nobody else's: no party owns it and nobody lent it.
    v.owner_id IS NULL
      AND NOT COALESCE((v.attributes ->> 'borrowed')::boolean, false) AS facility_owned,
    v.has_glycol,
    v.setpoint_c,
    v.mode,
    v.attributes,
    l.name AS location_name,
    COALESCE(
        CASE
            WHEN v.has_glycol AND v.mode <> 'off'::thermal_mode THEN v.setpoint_c
            ELSE NULL::numeric
        END, l.ambient_c) AS effective_temp_c,
    p.node_id,
    n.name AS lot_name,
    n.variety_id,
    nv.label AS variety,
    n.vintage,
    n.product_type_id,
    np.label AS product_type,
    n.owner_id AS lot_owner_id,
    p.volume_l AS current_volume_l,
    p.from_at AS filled_at,
    p.node_id IS NULL AS is_empty,
    ( SELECT array_agg(c.code ORDER BY c.added_at) AS array_agg
           FROM vessel_code c
          WHERE c.vessel_id = v.id AND c.active) AS codes,
    lo.name AS lot_owner_name,
    n.owner_id IS NOT NULL AND n.owner_id = facility_party_id() AS lot_facility_owned,
    COALESCE(cardinality(n.hidden), 0) > 0 AND NOT may_see_all_of(n.owner_id, n.hidden) AS redacted,
    l.ambient_c AS location_ambient_c,
    l.controlled AS location_controlled
   FROM vessel v
     JOIN term vt ON vt.id = v.type_id
     LEFT JOIN location l ON l.id = v.location_id
     LEFT JOIN party o ON o.id = v.owner_id
     LEFT JOIN placement p ON p.vessel_id = v.id AND p.to_at IS NULL
     LEFT JOIN LATERAL ( SELECT visible_node.id,
            visible_node.stage,
            visible_node.status,
            visible_node.vintage,
            visible_node.block_id,
            visible_node.name,
            visible_node.quantity,
            visible_node.unit,
            visible_node.attributes,
            visible_node.provenance,
            visible_node.closed_at,
            visible_node.created_at,
            visible_node.created_by,
            visible_node.owner_id,
            visible_node.variety_id,
            visible_node.variety_kind,
            visible_node.product_type_id,
            visible_node.product_kind,
            visible_node.hidden
           FROM visible_node(p.node_id) visible_node(id, stage, status, vintage, block_id, name, quantity, unit, attributes, provenance, closed_at, created_at, created_by, owner_id, variety_id, variety_kind, product_type_id, product_kind, hidden)) n ON p.node_id IS NOT NULL
     LEFT JOIN term nv ON nv.id = n.variety_id
     LEFT JOIN term np ON np.id = n.product_type_id
     LEFT JOIN party lo ON lo.id = n.owner_id
  WHERE v.active;

comment on view vessel_state is
  'Every active vessel and what is in it. owner_name is the party that owns it '
  'or the grower it is on loan from, and facility_owned means neither: a '
  'borrowed bin is not ours. See 0081.';

commit;
