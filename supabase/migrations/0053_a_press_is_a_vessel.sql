-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A press is a vessel, so that fruit in it is somewhere rather than
--           nowhere for the hours a press takes."
-- Depends on: [supabase/migrations/0052_press_as_a_process.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: AR-E6 (a vessel type is a registry row, so adding one is
--                  data rather than a schema change)
-- ---------------------------------------------------------------------------
--
-- `0052` made a press a process, which means there are hours during which the
-- fruit has left the bins and the juice has not yet come out. It has to be
-- somewhere, and the somewhere is the press.
--
-- **This is the same move `0033` made for bins.** A bin is a vessel, which
-- collapsed most of intake into machinery that already existed. A press is a
-- vessel for the same reason: it holds material, one lot at a time, and "what is
-- in the press right now" becomes a question the schema already knows how to
-- answer instead of a new kind of thing.
--
-- No capacity by default, because a press is rated by fruit and the capacity
-- column is litres, and a wrong number is worse than none. Nothing here refuses
-- one if somebody sets it.

begin;

insert into term (id, kind, value, label, sort_order, attributes)
values (
  gen_random_uuid(), 'vessel_type', 'press', 'Press', 45,
  jsonb_build_object(
    'expand', jsonb_build_array(),
    'fields', jsonb_build_array(
      jsonb_build_object(
        'key', 'maker', 'kind', 'term', 'open', false, 'label', 'Manufacturer',
        'contract', 'manufacturer', 'term_kind', 'vessel_maker', 'sort_order', 10),
      jsonb_build_object(
        'key', 'press_type', 'kind', 'text', 'open', true, 'label', 'Kind of press',
        'hint', 'Bladder, basket, continuous. Free text until somebody wants a list.',
        'sort_order', 20)),
    'maker_label', 'Manufacturer',
    'maker_contract', 'manufacturer'))
on conflict (kind, value) do nothing;

commit;
