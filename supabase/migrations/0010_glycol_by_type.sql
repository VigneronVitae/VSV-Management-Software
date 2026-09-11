-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Puts the glycol jacket under the same per-type visibility as the
--           barrel fields. A tank opens it, a barrel keeps it behind More
--           details. Neither hides it, because somebody does occasionally
--           jacket a barrel and the form should not call them wrong."
-- Depends on: [supabase/migrations/0009_vessel_type_form.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Open sorries: none new
-- ---------------------------------------------------------------------------

-- 0006 offered the jacket on every vessel type, on the reasoning that which
-- types can be jacketed is equipment rather than vessels and the person filling
-- the form knows it. That reasoning still holds and this does not reverse it.
-- What changes is only default visibility, which 0009 made a property of the
-- type. Unusual is not the same as impossible, and the difference between them
-- is one tap rather than a missing field.

update term
   set attributes = jsonb_set(attributes, '{expand}',
         (attributes -> 'expand') || '["glycol"]'::jsonb)
 where kind = 'vessel_type'
   and value in ('tank', 'fermenter')
   and not ((attributes -> 'expand') @> '["glycol"]'::jsonb);

-- Barrel and macrobin say nothing here on purpose. Their expand lists already
-- omit glycol, so it lands in More details, which is where it belongs for a
-- vessel that is jacketed once in a hundred.
