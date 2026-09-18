-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The two capabilities 0119 registered declare their fields, so a
--           periphery built from the contract can actually call them."
-- Depends on: [supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0119_a_machine_keeps_its_papers.sql]
-- Depended on by: [tests/schema_assertions.sql, docs/status-ledger.md]
-- Axioms enforced: AR-Q8. A capability whose fields are empty is a promise the
--                  contract cannot keep: the periphery is written against the
--                  contract, and a contract that omits a required argument
--                  produces a client that cannot call the thing it names.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- 0119 registered `add_model_part` and `add_machine_document` with no `fields`,
-- and the assertion suite refused: "these capabilities omit a parameter their
-- function has no default for, so a periphery built from the contract cannot
-- call them". That check is the contract keeping itself honest, and it caught
-- this before any client was written against it rather than after.

update capability set fields = '[
  {"key": "model",    "type": "uuid",    "label": "Which model",        "param": "p_model_id",    "required": true,
   "source": {"readable": "shop.models"}},
  {"key": "name",     "type": "text",    "label": "What the part is",   "param": "p_name",        "required": true},
  {"key": "domain",   "type": "text",    "label": "Kind of part",       "param": "p_domain",      "required": false,
   "source": {"terms": "part_domain"}},
  {"key": "parent",   "type": "uuid",    "label": "Part of",            "param": "p_parent_id",   "required": false,
   "source": {"readable": "shop.model_part_detail"}},
  {"key": "maker",    "type": "text",    "label": "Who makes it",       "param": "p_maker",       "required": false},
  {"key": "number",   "type": "text",    "label": "Part number",        "param": "p_part_number", "required": false},
  {"key": "quantity", "type": "numeric", "label": "How many",           "param": "p_quantity",    "required": false},
  {"key": "wear",     "type": "boolean", "label": "It wears out",       "param": "p_wear",        "required": false},
  {"key": "life",     "type": "text",    "label": "How long it lasts",  "param": "p_wear_life",   "required": false},
  {"key": "url",      "type": "text",    "label": "Link to the datasheet", "param": "p_url",      "required": false},
  {"key": "note",     "type": "text",    "label": "Anything worth knowing", "param": "p_note",    "required": false},
  {"key": "document", "type": "uuid",    "label": "Which document says so", "param": "p_document_id", "required": false,
   "source": {"readable": "shop.machine_papers"}},
  {"key": "order",    "type": "numeric", "label": "Where it sits in the list", "param": "p_sort_order", "required": false}
]'::jsonb
where key = 'shop.add_model_part';

update capability set fields = '[
  {"key": "kind",    "type": "text", "label": "Kind of document", "param": "p_kind",  "required": true,
   "source": {"terms": "document_kind"}},
  {"key": "title",   "type": "text", "label": "Called",           "param": "p_title", "required": true},
  {"key": "model",   "type": "uuid", "label": "About which model", "param": "p_model_id", "required": false,
   "source": {"readable": "shop.models"}},
  {"key": "machine", "type": "uuid", "label": "Or about which machine", "param": "p_machine_id", "required": false,
   "source": {"readable": "shop.machines"}},
  {"key": "source",  "type": "text", "label": "Who wrote it",     "param": "p_source", "required": false},
  {"key": "url",     "type": "text", "label": "Where it lives",   "param": "p_url",    "required": false},
  {"key": "body",    "type": "text", "label": "The text of it",   "param": "p_body",   "required": false},
  {"key": "at",      "type": "date", "label": "Dated",            "param": "p_at",     "required": false}
]'::jsonb
where key = 'shop.add_machine_document';
