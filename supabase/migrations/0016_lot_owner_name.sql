-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Puts the wine's owner's name on the vessel page. The view already
--           carried lot_owner_id and no name, so every screen showed the
--           vessel's owner under the word Owner, which read as Facility on a
--           barrel full of a client's wine."
-- Depends on: [supabase/migrations/0004_terms_and_effects.sql,
--              supabase/migrations/0006_vessel_thermal.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (derived over stored: a name resolved in the view, not
--                  copied onto the lot)
-- Open sorries: S-22 (a blend across owners keeps one owner_id, so this shows
--               the largest contributor and not the mixture)
-- ---------------------------------------------------------------------------

-- Two different owners meet on one row and they are genuinely different facts.
-- A vessel's owner answers whose barrel it is, which matters when a client
-- brought their own. A lot's owner answers whose wine is in it, which is what
-- drives TTB reporting, cost allocation, and what a client is allowed to see.
-- Naming only one of them Owner was fine while lots could not be owned by
-- anyone but the facility. They can now.
--
-- Appended rather than inserted, because create or replace view may add columns
-- at the end and may not reorder the ones already there.

create or replace view vessel_state as
  select
    v.id,
    v.type_id,
    vt.label                     as type,
    v.name,
    v.capacity_l,
    v.owner_id,
    o.name                       as owner_name,
    v.owner_id is null           as facility_owned,
    v.has_glycol,
    v.setpoint_c,
    v.mode,
    v.attributes,
    l.name                       as location_name,
    coalesce(
      case when v.has_glycol and v.mode <> 'off' then v.setpoint_c end,
      l.ambient_c
    )                            as effective_temp_c,
    p.node_id,
    n.name                       as lot_name,
    n.variety_id,
    nv.label                     as variety,
    n.vintage,
    n.product_type_id,
    np.label                     as product_type,
    n.owner_id                   as lot_owner_id,
    p.volume_l                   as current_volume_l,
    p.from_at                    as filled_at,
    (p.node_id is null)          as is_empty,
    (
      select array_agg(c.code order by c.added_at)
        from vessel_code c
       where c.vessel_id = v.id and c.active
    )                            as codes,
    lo.name                      as lot_owner_name,
    (n.owner_id is not null and n.owner_id = facility_party_id())
                                 as lot_facility_owned
  from vessel v
  join term vt on vt.id = v.type_id
  left join location l on l.id = v.location_id
  left join party o on o.id = v.owner_id
  left join placement p on p.vessel_id = v.id and p.to_at is null
  left join node n on n.id = p.node_id
  left join term nv on nv.id = n.variety_id
  left join term np on np.id = n.product_type_id
  left join party lo on lo.id = n.owner_id
 where v.active;
