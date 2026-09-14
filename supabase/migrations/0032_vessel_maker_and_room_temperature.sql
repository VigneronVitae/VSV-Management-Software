-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Renames the vessel-maker vocabulary off a barrel-maker's word, makes
--           what a maker builds a set of flags rather than one string, and puts
--           the room's own temperature on the vessels view beside the jacket's."
-- Depends on: [supabase/migrations/0009_vessel_type_form.sql,
--              supabase/migrations/0017_vessel_state_rls.sql,
--              supabase/migrations/0027_term_kind_registry.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: none new. AR-E7's registry is what makes the rename one row.
-- Open sorries: none.
-- ---------------------------------------------------------------------------
--
-- Asked for by the winemaker, who opened the vessel types screen and found that a
-- tank asks for a cooper.
--
-- It did. Not functionally: `terms_for_vessel_field` filtered by contract, so a
-- tank's picker only ever offered makers marked `manufacturer`. But all four
-- vessel types drew from one shared list whose registered name was `cooper`,
-- which is a barrel-maker's word, and the vessel types screen shows the
-- vocabulary name. The mechanism was right and the bucket had the wrong word on
-- it, which is a naming defect rather than a logic one and is worth exactly one
-- migration.
--
-- **What a maker builds becomes a set.** `contract` was one string per term, so a
-- cooper who also fabricates tanks had to be entered twice and the two copies
-- drifted. A maker is entered once now and carries `makes`, an array of the
-- things it builds, and a field asks for the one it needs. The old single-string
-- form is still honoured on read, because a term written before this migration is
-- not wrong, it is old.
--
-- A term that claims nothing still satisfies everything. That is `0009`'s rule and
-- it is deliberate: a maker added in the barn before anybody has classified it
-- should appear in every picker rather than vanish from all of them, which is the
-- deflationary reading AR-B7 asks for and the opposite of the silence this project
-- keeps finding.
--
-- The view change is the second half of the same request: the vessels screen
-- collapsed the room's temperature and the jacket's into one `effective_temp_c`,
-- so a barrel sitting in a cold room and a tank holding itself at 12 read the
-- same. Both are published now and the collapsed one stays, because it is what a
-- screen wants when it has room for one number.
--
-- `vessel_state` is replaced from `pg_get_functiondef`'s own output with two
-- columns appended, rather than retyped. It contains the positional alias list
-- over `visible_node` that `0027` nearly came apart on, eighteen columns bound by
-- order, and retyping it is how that trap gets sprung. Nothing here touches
-- `node`, so the binding is unchanged, and it is unchanged because it was copied
-- rather than rewritten.

begin;

-- 1. The new vocabulary has to exist before any field spec names it, because
--    validate_vessel_type_fields checks the registry on write.
insert into term_kind (kind, module, label)
values ('vessel_maker', 'winemaking', 'Vessel maker')
on conflict (kind) do nothing;

-- 2. Move the terms across. There are none in this cellar today and the statement
--    is written for a database that has them.
update term set kind = 'vessel_maker' where kind = 'cooper';

-- 3. One string becomes a set. A term that named a single contract now says it
--    makes that one thing, and can be given more without being duplicated.
update term
   set attributes = (attributes - 'contract')
       || jsonb_build_object('makes', jsonb_build_array(attributes ->> 'contract'))
 where kind = 'vessel_maker'
   and attributes ? 'contract'
   and not attributes ? 'makes';

-- 4. Point the vessel types at the renamed vocabulary. The label each type shows
--    is untouched: a barrel still says Cooper and a tank still says Manufacturer,
--    because that is what the person in front of it calls the thing.
update term
   set attributes = jsonb_set(
         attributes, '{fields}',
         (select jsonb_agg(
                   case when f ->> 'term_kind' = 'cooper'
                        then jsonb_set(f, '{term_kind}', to_jsonb('vessel_maker'::text))
                        else f end)
            from jsonb_array_elements(attributes -> 'fields') f))
 where kind = 'vessel_type'
   and attributes -> 'fields' @> '[{"term_kind": "cooper"}]'::jsonb;

-- 5. And the old name goes, so that nothing can quietly go on using it. The
--    foreign key is on delete restrict, so this fails loudly if step 2 missed a
--    term rather than orphaning one.
delete from term_kind where kind = 'cooper';

-- 6. The picker reads the set. `contract` on the field is what is being asked
--    for; `makes` on the term is what that maker builds.
create or replace function terms_for_vessel_field(p_vessel_type_id uuid, p_field_key text)
returns setof term
language sql
stable
set search_path to 'public', 'pg_temp'
as $function$
  with spec as (
    select f
      from term vt,
           lateral jsonb_array_elements(coalesce(vt.attributes -> 'fields', '[]'::jsonb)) f
     where vt.id = p_vessel_type_id
       and f ->> 'key' = p_field_key
     limit 1
  )
  select t.*
    from term t, spec
   where t.active
     and t.kind = (spec.f ->> 'term_kind')
     and (
       -- The field asks for nothing in particular.
       spec.f ->> 'contract' is null
       -- Or the term claims nothing, and a maker nobody has classified belongs in
       -- every picker rather than in none. 0009's rule, kept.
       or (not t.attributes ? 'makes' and not t.attributes ? 'contract')
       -- Or it is flagged for what was asked.
       or t.attributes -> 'makes' @> to_jsonb(array[spec.f ->> 'contract'])
       -- Or it is an older term carrying the single string this migration replaced.
       or t.attributes ->> 'contract' = spec.f ->> 'contract'
     )
   order by t.sort_order, t.label;
$function$;

-- 7. The room's own temperature, published beside the jacket's rather than
--    collapsed into it.
--
--    **With the security_invoker back on it, explicitly.** `create or replace
--    view` does not carry reloptions forward, so replacing this view drops
--    `security_invoker = true` and it silently reverts to running with its
--    owner's rights. That is S-26 exactly, the defect `0017` exists to fix and
--    the one `0028` is built on top of: without it, row level security under this
--    view does nothing and every custom crush client reads every lot by name.
--
--    The first version of this migration left it off and the assertion from
--    `0017` caught it. Third time a rewrite has silently dropped a property in
--    this tree, after `0027`'s two, and the first time an assertion got there
--    before a review did.
create or replace view vessel_state with (security_invoker = true) as
 SELECT v.id,
    v.type_id,
    vt.label AS type,
    v.name,
    v.capacity_l,
    v.owner_id,
    o.name AS owner_name,
    v.owner_id IS NULL AS facility_owned,
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

commit;
