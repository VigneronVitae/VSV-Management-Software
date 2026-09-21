-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A pressure washer is a kind of machine."
-- Depends on: [supabase/migrations/0105_a_machine_is_a_departure_from_its_model.sql,
--              supabase/migrations/0112_a_machine_decomposes_into_parts.sql,
--              supabase/migrations/0119_a_machine_keeps_its_papers.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: none new.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- **This migration used to hold one winery's machine and no longer does.**
--
-- It carried a hot water pressure washer bought second hand: its model, its
-- serials, its 72 parts, and two research reports about it running to 66 KB. All
-- of that is a record of one machine owned by one winery, and none of it belongs
-- in software that is meant to be handed to somebody else.
--
-- It lives in `data/machines/hot-water-pressure-washer/`, which is not
-- committed, and `scripts/import-machine.py` loads it.
--
-- The thing that was worth keeping from that work is not the machine. It is what
-- the machine taught: that two models answering the same prompt about the same
-- photographs disagreed about a part number, and that one of them put a number
-- behind the evidence marker meaning "I can see this" when the photograph said
-- otherwise. That is why `model_part.document_id` exists in 0119, and 0119 is
-- where the reasoning is recorded.
--
-- What stays is one row of vocabulary. Any winery may own a pressure washer.

insert into term (kind, value, label, sort_order) values
  ('machine_kind', 'pressure_washer', 'Pressure washer', 60)
on conflict (kind, value) do nothing;
