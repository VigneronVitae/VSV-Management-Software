-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Lets a vessel type say what its own form looks like: which contract
--           fills the maker field, what that field is called, and which of the
--           optional fields start open. A barrel has a cooper, a wood, a toast
--           and a fill count; a tank has a manufacturer and none of the others,
--           and the form should not ask a tank about toast."
-- Depends on: [supabase/migrations/0004_terms_and_effects.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql, supabase/migrations/0010_glycol_by_type.sql, supabase/migrations/0011_vessel_type_fields.sql]
-- Axioms enforced: T1-1 (pickers, not text fields)
-- Open sorries: none new
-- ---------------------------------------------------------------------------

-- "Creator of" is one function with two contracts. A cooper satisfies it for a
-- barrel and a manufacturer satisfies it for a tank, and they are the same kind
-- of fact about a vessel rather than two unrelated fields. So this does not add
-- a term kind. It partitions the existing one: a maker term declares which
-- contract it satisfies, a vessel type declares which contract it wants, and
-- the picker shows the intersection.
--
-- The alternative was a second term kind, which would have meant editing the
-- term_kind enum. That enum is the fixed tier on purpose: adding a value there
-- says the kernel has to understand it. Nothing in the kernel needs to tell a
-- cooper from a tank fabricator. Only a form does, and a form is not the kernel.
--
-- A maker term with no contract satisfies every contract. That is what keeps
-- this backward compatible: nothing added before this migration disappears from
-- a picker, it just shows up under both.

-- ---------------------------------------------------------------------------
-- Which contract each existing maker satisfies
-- ---------------------------------------------------------------------------

update term
   set attributes = attributes || jsonb_build_object('contract', 'cooper')
 where kind = 'cooper'
   and not (attributes ? 'contract');

-- ---------------------------------------------------------------------------
-- What each vessel type's form looks like
-- ---------------------------------------------------------------------------

-- expand lists the optional fields a type opens by default. Anything not named
-- here is still reachable, one tap into "More details", because a form that
-- cannot record a true thing is worse than a form with an extra tap in it.

update term
   set attributes = attributes || jsonb_build_object(
         'maker_contract', 'cooper',
         'maker_label',    'Cooper',
         'expand',         jsonb_build_array('maker', 'wood', 'fill_count', 'toast'))
 where kind = 'vessel_type' and value = 'barrel';

update term
   set attributes = attributes || jsonb_build_object(
         'maker_contract', 'manufacturer',
         'maker_label',    'Manufacturer',
         'expand',         jsonb_build_array())
 where kind = 'vessel_type' and value in ('tank', 'fermenter', 'macrobin');

-- ---------------------------------------------------------------------------
-- The intersection, as a function rather than as a filter in a client
-- ---------------------------------------------------------------------------

-- Which makers a vessel type may pick from is a fact about this cellar's
-- vocabulary. A client that computed it would be a client that decides what a
-- cooper is, and the second client would decide differently.
create or replace function makers_for_vessel_type(p_vessel_type_id uuid)
returns setof term
language sql
stable
as $$
  select t.*
    from term t
   where t.kind = 'cooper'
     and t.active
     and (
       t.attributes ->> 'contract' is null
       or t.attributes ->> 'contract' = coalesce(
            (select vt.attributes ->> 'maker_contract'
               from term vt where vt.id = p_vessel_type_id),
            t.attributes ->> 'contract')
     )
   order by t.sort_order, t.label;
$$;
