-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A vessel says which vintage is standing in it, including when the
--           answer is NV, so the vessels screen can be sorted and filtered by
--           the thing a cellar is actually organised around."
-- Depends on: [supabase/migrations/0049_every_lot_says_its_vintage.sql,
--              supabase/migrations/0091_a_bin_says_its_weight_everywhere.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0100_a_jacket_is_on_a_machine.sql]
-- Axioms enforced: T0-2 (a vessel has no vintage of its own: it is the vintage
--                  of the wine standing in it, and it changes when the wine
--                  does), A13 (NV, no wine and nobody said are three answers
--                  and null was all three)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"Another thing to add for sorting vessels, by vintage. Maybe
-- just 2024/2025/2026/NV?"*
--
-- **Most of this was already here.** `vessel_state.vintage` has carried the year
-- of the lot in the vessel since the view existed, and the cellar is holding
-- 2024, 2025 and 2026 right now. What it could not say is NV.
--
-- `0049` made a lot say its vintage or say it is deliberately non-vintage, and
-- the constraint is `(vintage is null) = non_vintage`, so blank stopped meaning
-- both "no year" and "nobody got round to it". That distinction never reached
-- this view: `non_vintage` is not projected, so a screen reading `vintage is
-- null` sees NV, an empty vessel and an old lot nobody has answered for as one
-- thing. Three answers arriving as one is A13, and here it would put a barrel of
-- NV sparkling base in the same bucket as an empty tank.
--
-- So two columns, appended because `create or replace view` cannot put one in
-- the middle:
--
--   * `non_vintage`, the fact, null when there is no wine.
--   * `vintage_label`, what to write on the chip: the year, or NV, and null when
--     there is nothing to say. A client choosing between those would be a client
--     holding a rule, and the next client would choose differently.
--
-- Note the constraint is `not valid`, so a lot predating `0049` can still have
-- neither. That reads as a null label on a vessel that is not empty, which is
-- "nobody said" and is the honest answer rather than being folded into NV.
--
-- **And the column alias list on the lateral goes.** `visible_node` returns a
-- whole `node` row, so naming its columns positionally in the join was never
-- needed, and it is the kind of list that silently goes stale: `0071` added
-- three columns to `node` and the list in `0091` still stops at `hidden`. Named
-- resolution cannot drift that way.

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
    ( SELECT bf.pct_full FROM bin_fruit bf WHERE bf.placement_id = p.id) AS fruit_pct,
    -- 0099, appended. The fact, and then what to write on a chip.
    n.non_vintage,
    CASE
        WHEN p.node_id IS NULL THEN NULL
        WHEN n.non_vintage THEN 'NV'
        -- A lot predating 0049's not-valid constraint can have neither, and
        -- that is "nobody said", which is not NV and must not read as it.
        ELSE n.vintage::text
    END AS vintage_label
   FROM vessel v
     JOIN term vt ON vt.id = v.type_id
     LEFT JOIN location l ON l.id = v.location_id
     LEFT JOIN party o ON o.id = v.owner_id
     LEFT JOIN placement p ON p.vessel_id = v.id AND p.to_at IS NULL
     -- No column alias list. visible_node returns a node row, so its columns
     -- resolve by name and cannot go stale the way a positional list does.
     LEFT JOIN LATERAL visible_node(p.node_id) n ON p.node_id IS NOT NULL
     LEFT JOIN term nv ON nv.id = n.variety_id
     LEFT JOIN term np ON np.id = n.product_type_id
     LEFT JOIN party lo ON lo.id = n.owner_id
  WHERE v.active;

comment on view vessel_state is
  'Every active vessel and what is in it. owner_name is the party that owns it '
  'or the grower it is on loan from, and facility_owned means neither. '
  'fruit_lbs is what is in a picking bin, because fruit is weighed and not '
  'measured in litres. vintage_label is the year or NV, and null when there is '
  'nothing standing in the vessel or nobody has said. See 0081, 0091 and 0099.';

commit;
