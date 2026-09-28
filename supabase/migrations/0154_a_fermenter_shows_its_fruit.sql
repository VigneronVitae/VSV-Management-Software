-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A fermenter holding fruit says how many pounds and how full, the
--           way a picking bin always has, instead of drawing empty."
-- Depends on: [supabase/migrations/0100_a_jacket_is_on_a_machine.sql,
--              supabase/migrations/0148_reds_go_into_fermenters.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql, scripts/smoke.ts]
-- Axioms enforced: T0-2. A fermenter's pounds are the lot's pounds divided the
--                  way Sort and destem divided them when it filled the
--                  fermenters, computed on read; nothing new is stored.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- The Pommard of 2026-09-23 went through Sort and destem into MB01 with "80%"
-- and no pounds: three bins, 2374 lbs on the scale, 287 lbs sorted out, so the
-- lot is 2087 lbs and the destem event says all 2087 went into MB01. The
-- cellar drew MB01 as empty. `vessel_state` took pounds and fullness from
-- `bin_fruit`, which is picking bins only, and litres from the placement,
-- which fruit has none of. So the pounds were known and the winemaker could
-- not see them, and went looking for a way to type them in again.
--
-- **Divided the way the fermenters were filled.** One fermenter holds the whole
-- lot. Several hold it in the proportions Sort and destem recorded for each,
-- which came from the pounds or the fullness said at the time, scaled to what
-- the lot holds now. With neither, an equal share, which is a guess and the
-- only one there is. Fullness is what was said for that fermenter.

create or replace function fermenter_lbs(p_placement_id uuid)
returns numeric
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  with me as (
    select p.id, p.node_id, n.quantity, n.unit
      from placement p
      join node n on n.id = p.node_id
     where p.id = p_placement_id and p.to_at is null and n.stage <> 'bin'
  ),
  held as (
    select p.id,
           (select (f ->> 'lbs')::numeric
              from event e
              cross join lateral jsonb_array_elements(e.data -> 'fermenters') f
             where e.subject_type = 'node' and e.subject_id = p.node_id
               and e.operation_id = term_id('operation', 'destem')
               and (f ->> 'vessel_id')::uuid = p.vessel_id
             order by e.at desc
             limit 1) as filled
      from placement p
      join me on me.node_id = p.node_id
     where p.to_at is null
  )
  select case
           when me.unit is distinct from 'lbs' or me.quantity is null then null
           when (select count(*) from held) = 1 then me.quantity
           when (select bool_and(filled > 0) from held)
             then round(me.quantity * (select filled from held where id = me.id)
                        / (select sum(filled) from held), 1)
           else round(me.quantity / (select count(*) from held), 1)
         end
    from me;
$$;

comment on function fermenter_lbs is
  'The pounds of fruit in one fermenter: the lot''s pounds, divided across its '
  'fermenters the way Sort and destem filled them.';

grant execute on function fermenter_lbs(uuid) to authenticated;

insert into capability_exemption (fn, reason) values
  ('fermenter_lbs', 'Divides a lot''s pounds across the fermenters holding it, for vessel_state to show. It changes nothing.')
on conflict (fn) do update set reason = excluded.reason;

-- Replaced in place: three expressions change and the columns do not.
create or replace view vessel_state with (security_invoker = true) as
 SELECT v.id,
    v.type_id,
    vt.label AS type,
    v.name,
    v.capacity_l,
    v.owner_id,
    COALESCE(o.name, NULLIF(btrim((v.attributes ->> 'on_loan_from'::text)), ''::text)) AS owner_name,
    ((v.owner_id IS NULL) AND (NOT COALESCE(((v.attributes ->> 'borrowed'::text))::boolean, false))) AS facility_owned,
    v.has_glycol,
    v.setpoint_c,
    v.mode,
    v.attributes,
    l.name AS location_name,
    COALESCE(
        CASE
            WHEN (v.has_glycol AND (v.mode <> 'off'::thermal_mode)) THEN v.setpoint_c
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
    (p.node_id IS NULL) AS is_empty,
    ( SELECT array_agg(c.code ORDER BY c.added_at) AS array_agg
           FROM vessel_code c
          WHERE ((c.vessel_id = v.id) AND c.active)) AS codes,
    lo.name AS lot_owner_name,
    ((n.owner_id IS NOT NULL) AND (n.owner_id = facility_party_id())) AS lot_facility_owned,
    ((COALESCE(cardinality(n.hidden), 0) > 0) AND (NOT may_see_all_of(n.owner_id, n.hidden))) AS redacted,
    l.ambient_c AS location_ambient_c,
    l.controlled AS location_controlled,
    COALESCE(( SELECT bf.lbs
           FROM bin_fruit bf
          WHERE (bf.placement_id = p.id)), fermenter_lbs(p.id)) AS fruit_lbs,
    COALESCE(( SELECT bf.tons
           FROM bin_fruit bf
          WHERE (bf.placement_id = p.id)), round(fermenter_lbs(p.id) / 2000.0, 3)) AS fruit_tons,
    COALESCE(( SELECT bf.pct_full
           FROM bin_fruit bf
          WHERE (bf.placement_id = p.id)), round(p.fill_pct, 0)) AS fruit_pct,
    n.non_vintage,
        CASE
            WHEN (p.node_id IS NULL) THEN NULL::text
            WHEN n.non_vintage THEN 'NV'::text
            ELSE (n.vintage)::text
        END AS vintage_label,
    gh.machine_id AS glycol_machine_id,
    gm.name AS glycol_machine
   FROM ((((((((((vessel v
     JOIN term vt ON ((vt.id = v.type_id)))
     LEFT JOIN location l ON ((l.id = v.location_id)))
     LEFT JOIN party o ON ((o.id = v.owner_id)))
     LEFT JOIN placement p ON (((p.vessel_id = v.id) AND (p.to_at IS NULL))))
     LEFT JOIN LATERAL visible_node(p.node_id) n(id, stage, status, vintage, block_id, name, quantity, unit, attributes, provenance, closed_at, created_at, created_by, owner_id, variety_id, variety_kind, product_type_id, product_kind, hidden, non_vintage, colour_id, colour_kind) ON ((p.node_id IS NOT NULL)))
     LEFT JOIN term nv ON ((nv.id = n.variety_id)))
     LEFT JOIN term np ON ((np.id = n.product_type_id)))
     LEFT JOIN party lo ON ((lo.id = n.owner_id)))
     LEFT JOIN glycol_hookup gh ON (((gh.vessel_id = v.id) AND (gh.to_at IS NULL))))
     LEFT JOIN glycol_machine gm ON ((gm.id = gh.machine_id)))
  WHERE v.active;
