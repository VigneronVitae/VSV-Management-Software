-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Twenty nine functions a signed-in account can call that the
--           contract said nothing about, each now either declared or exempt
--           with the reason."
-- Depends on: [supabase/migrations/0057_the_contract.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0061_two_declarations_were_wrong.sql]
-- Axioms enforced: AR-Q8 (a contract falls behind by omission, so the omission
--                  is what gets checked)
-- ---------------------------------------------------------------------------
--
-- `0057` declared eleven capabilities and thirty five exemptions, which felt
-- thorough. The reverse assertion then listed twenty nine more functions that a
-- signed-in account can call and the contract had never heard of.
--
-- **That is the check earning its place on the first run.** A contract does not
-- rot by contradicting itself; somebody would notice. It rots by omission, and
-- twenty nine is what omission looks like after eleven sessions of adding
-- functions with no declaration to keep in step. The list below is the honest
-- state of it: four are real capabilities and are declared, and the rest carry a
-- reason that is specific enough to argue with.
--
-- The reasons matter more than the count. "Internal" is not a reason. Each entry
-- says what the function is for and why a periphery would not call it, so that
-- somebody disagreeing has something to disagree with.

begin;

-- Four that a periphery would genuinely call, so they are capabilities rather
-- than exemptions.
insert into capability (key, module, label, note, fn, subject, fields, sort_order) values

  ('cellar.record_event', 'cellar', 'Record something that happened',
   'The untyped floor. Any operation in the vocabulary, against any subject, with whatever data it carries. What a periphery uses for an operation nothing has written a screen for.',
   'record_event', null,
   '[{"key":"operation","param":"p_operation","type":"text","required":true,
      "label":"Which operation","source":{"terms":"operation"}},
     {"key":"subject_type","param":"p_subject_type","type":"text","required":true,
      "label":"On what kind of thing"},
     {"key":"subject_id","param":"p_subject_id","type":"uuid","required":true,"label":"On which one"},
     {"key":"data","param":"p_data","type":"jsonb","required":false,"label":"What it carries"}]'::jsonb, 200),

  ('cellar.record_vessel_note', 'cellar', 'Leave a note on a vessel',
   'Something worth saying about a vessel that is not a measurement and not a treatment.',
   'record_vessel_note', 'cellar.vessels',
   '[{"key":"vessel","param":"p_vessel_id","type":"uuid","required":true,"label":"Which vessel",
      "source":{"readable":"cellar.vessels"}},
     {"key":"body","param":"p_body","type":"text","required":true,"label":"What to say"}]'::jsonb, 210),

  ('cellar.claim_task', 'cellar', 'Take a task',
   'Put your name on something on the board so two people do not do it.',
   'claim_task', null,
   '[{"key":"task","param":"p_task_id","type":"uuid","required":true,"label":"Which task"}]'::jsonb, 220),

  ('cellar.confirm_event', 'cellar', 'Confirm an inferred event',
   'A generated event that somebody has checked against the world. T0-4: only a verifier writes confirmed.',
   'confirm_event', null,
   '[{"key":"event","param":"p_event_id","type":"uuid","required":true,"label":"Which event"}]'::jsonb, 230)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

insert into capability_exemption (fn, reason) values
  -- Predicates. A periphery asks `viewer_scope` what it is; these are how the
  -- policies decide, and calling them directly would be a client reimplementing
  -- row level security.
  ('may_see_all_of', 'A policy predicate. A periphery asks viewer_scope what it is and lets the rows answer the rest.'),
  ('may_set_privacy', 'A policy predicate, as above.'),
  ('current_party_id', 'A policy predicate. Returned inside viewer_scope as party_id.'),
  ('visible_node', 'The row level security test for one lot, used by policies. A periphery gets the row or it does not.'),
  ('subject_is_resolvable', 'A constraint predicate, used by the registry pins.'),
  ('validate_vessel_attributes', 'A validator invoked by a trigger. Nothing calls it directly.'),

  -- Lookups whose answers already arrive inside something else.
  ('operation_effect', 'Looks up an operation''s effect. Arrives on the term row a periphery already has.'),
  ('inferred_fraction', 'Arithmetic used by the history generator.'),
  ('resolve_subject_name', 'Names one subject. A readable already carries a label column, which is the contract''s answer to the same question.'),
  ('register_subject_resolver', 'Registers a subject kind. A migration does this, not a periphery.'),

  -- Reports and traversals. They read and their shape is a report''s, not a
  -- capability''s: a periphery renders them rather than composing them.
  ('block_composition', 'A report: what a lot is made of by block. Read, and shaped as a report.'),
  ('variety_composition', 'A report: the same by variety.'),
  ('vessel_history', 'A report: what has happened in one vessel.'),
  ('next_cap_action', 'A suggestion for what to do next to a cap. Reads and suggests.'),
  ('topping_check', 'Answers whether two lots may top each other. A preview, like rack_plan.'),
  ('generate_inferred_history', 'Writes a template''s worth of inferred events. Invoked when a lot is created, not chosen from a menu.'),

  -- Procedure runs. A real surface, deliberately not declared yet: it has three
  -- functions that must be called in order and the contract cannot say so.
  -- S-72 is exactly that gap, and declaring these before it is answered would
  -- hand a periphery three actions and no way to know which comes first.
  ('start_procedure_session', 'Procedure runs are a sequence, and S-72 says the contract cannot yet express one. Declaring the three steps without the order would be worse than not declaring them.'),
  ('begin_run_step', 'The same sequence, step two.'),
  ('end_run_step', 'The same sequence, step three.'),
  ('finish_run', 'The same sequence, the end.'),

  -- Screens that predate the contract and are the next ones to bring in.
  ('update_vessel', 'Not yet declared. The vessel edit screen predates the contract, and its writable columns are answered by writable_columns rather than by a field list.'),
  ('bind_vessel_code', 'Not yet declared. Reached by scanning a sticker.'),
  ('resolve_vessel_code', 'A lookup from a sticker to a vessel. Reads.'),
  ('set_lot_hidden', 'Not yet declared. Privacy is admin work with its own screen.'),
  ('set_party_default_hidden', 'The same.')
on conflict (fn) do update set reason = excluded.reason;

commit;
