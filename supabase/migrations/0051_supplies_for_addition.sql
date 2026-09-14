-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Which of the things on the shelf are things that go into wine, by
--           the flag somebody set rather than by a label a screen recognises."
-- Depends on: [supabase/migrations/0046_supply_inventory.sql,
--              supabase/migrations/0050_additions.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: AR-E6 (a registry row is identified by its value, and a
--                  label is what a person reads)
-- ---------------------------------------------------------------------------
--
-- The additions screen has to offer the right half of the shelf. Hose heads and
-- filter pads are not additions and DAP is, which is exactly the distinction the
-- winemaker asked `0046` to carry: "for stores we need type. Like additions to
-- wine flag, consumable flag, etc."
--
-- `supply_on_hand` exposes those sorts as labels, because a label is what a
-- person reads. A client filtering on the string "Goes into wine" would be
-- matching on the one part of a registry row that is meant to be editable, so
-- renaming the sort would empty the picker with no error anywhere. That is AR-E6
-- and it is the reason this is a view rather than three words in a screen.

begin;

create or replace view supply_for_addition with (security_invoker = true) as
select
  h.supply_id,
  h.name,
  h.unit,
  h.on_hand,
  h.counted_at,
  h.supplier
from supply_on_hand h
where h.retired_at is null
  and exists (
    select 1
      from supply_material_kind k
      join term t on t.id = k.kind_id and t.kind = 'material_kind'
     where k.supply_id = h.supply_id
       and t.value = 'addition'
  );

comment on view supply_for_addition is
  'The supplies flagged as going into wine, for the additions picker. Matched '
  'on the registry value rather than the label, so renaming the sort does not '
  'silently empty the list. See 0051.';

commit;
