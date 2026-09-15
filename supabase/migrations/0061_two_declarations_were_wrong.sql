-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Two capabilities declared from memory rather than from the catalog,
--           corrected by the check that exists to catch exactly that."
-- Depends on: [supabase/migrations/0060_the_contract_catches_up.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: AR-Q8 (a declaration is worth having only because something
--                  fails when it stops being true)
-- ---------------------------------------------------------------------------
--
-- `0060` declared `record_event` as taking a subject type and a subject id, and
-- `record_vessel_note` as taking a body. Neither is true. `record_event` is
-- scoped to a node and takes an operation, data, vessels and a time;
-- `record_vessel_note` takes an operation and a note.
--
-- **The parameter check caught both within a minute**, which is the entire
-- argument for `0057` existing, and it caught the person who wrote the check.
-- A declaration written from memory is a declaration that is wrong, and there
-- is no amount of care that fixes that: the fix is that something reads the
-- catalog and refuses.
--
-- Recorded as its own migration rather than folded into `0060` because a
-- correction is a new event. The original is still there and still wrong, and
-- this is what replaced it.

begin;

update capability set
  label = 'Record something that happened to a lot',
  note = 'Any operation in the vocabulary, against a lot, with whatever data it carries. The untyped floor: what a periphery uses for an operation nothing has written a screen for.',
  fields = '[{"key":"lot","param":"p_node_id","type":"uuid","required":true,
              "label":"Which lot"},
             {"key":"operation","param":"p_operation","type":"text","required":true,
              "label":"Which operation","source":{"terms":"operation"}},
             {"key":"data","param":"p_data","type":"jsonb","required":false,
              "label":"What it carries"},
             {"key":"vessels","param":"p_vessel_ids","type":"uuid[]","required":false,
              "label":"Which vessels it concerns","source":{"readable":"cellar.vessels"}},
             {"key":"at","param":"p_at","type":"timestamptz","required":false,
              "label":"When"}]'::jsonb
 where key = 'cellar.record_event';

update capability set
  fields = '[{"key":"vessel","param":"p_vessel_id","type":"uuid","required":true,
              "label":"Which vessel","source":{"readable":"cellar.vessels"}},
             {"key":"operation","param":"p_operation","type":"text","required":true,
              "label":"What kind of note","source":{"terms":"operation"}},
             {"key":"note","param":"p_note","type":"text","required":false,
              "label":"What to say"},
             {"key":"data","param":"p_data","type":"jsonb","required":false,
              "label":"Anything it carries"}]'::jsonb
 where key = 'cellar.record_vessel_note';

commit;
