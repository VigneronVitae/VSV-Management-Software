-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A picking bin carries its pounds of fruit on vessel_state, so the
--           screen that lists every vessel can say what is in a bin instead of
--           leaving it blank."
-- Depends on: [supabase/migrations/0087_a_bin_holds_pounds.sql,
--              supabase/migrations/0081_a_borrowed_bin_is_not_ours.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (the pounds are resolved at read from whichever half
--                  was said, and nothing is cached on the vessel)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"I want weights of each bin to be presented in the vessel
-- view."*
--
-- **The vessel list measures everything in litres.** `current_volume_l` comes
-- off the placement, a bin's placement has no volume because fruit is not
-- measured in litres, and so every picking bin in the cellar reads as holding
-- nothing. The map draws them unfilled and the list shows a lot name with no
-- quantity beside it, which is the same wrong answer `0087` fixed one screen
-- deeper.
--
-- So `vessel_state` gains the pounds. Derived, at read, from whichever half
-- somebody said, exactly as `bin_fruit` does it: this adds a column to a view
-- and nothing to a table.
--
-- **Appended, never inserted.** This view binds `visible_node` through a
-- positional alias list, which `0081` already had to say out loud. New columns
-- go on the end.

begin;

create or replace view vessel_state with (security_invoker = true) as
 SELECT v.id,
    v.type_id,
    vt.label AS type,
    v.name,
    v.capacity_l,
    v.owner_id,
    COALESCE(o.name, NULLIF(btrim(v.attributes ->> 'on_loan_from'), '')) AS owner_name,
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
    l.controlled AS location_controlled,
    -- 0091. Fruit is weighed, not measured in litres, so a picking bin's
    -- quantity lives here and null everywhere else. Resolved from whichever
    -- half somebody said, which is bin_fruit's job and not a second copy of
    -- its arithmetic.
    ( SELECT bf.lbs FROM bin_fruit bf WHERE bf.placement_id = p.id) AS fruit_lbs,
    ( SELECT bf.tons FROM bin_fruit bf WHERE bf.placement_id = p.id) AS fruit_tons,
    -- How full, so the map can draw a bin's fill height without the client
    -- knowing what a full bin holds. A screen dividing pounds by 850 would be a
    -- client holding a rule that lives on the vessel type, which is the one
    -- thing this repository is most explicit about.
    ( SELECT bf.pct_full FROM bin_fruit bf WHERE bf.placement_id = p.id) AS fruit_pct
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
  'or the grower it is on loan from, and facility_owned means neither. '
  'fruit_lbs is what is in a picking bin, because fruit is weighed and not '
  'measured in litres. See 0081 and 0091.';

commit;
