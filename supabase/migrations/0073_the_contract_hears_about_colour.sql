-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Declare the colour of a wine and the colour of a barrel in the
--           contract, so a second periphery can ask and answer both."
-- Depends on: [supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0071_a_wine_says_its_colour.sql,
--              supabase/migrations/0072_a_barrel_remembers.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: AR-Q8 (anything a person can do is declared once, where
--                  every interface can find it)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- 0069 was written because the contract's reverse check caught `make_invite` an
-- hour after it landed. This one is written before the check runs, which is the
-- first time that has happened and is the only evidence that the apparatus is
-- teaching rather than merely catching.

begin;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.lots_without_colour', 'cellar', 'Lots with no colour',
   'Wine nobody has said is red, orange, rose or white. A barrel cannot be '
   'called white while it has held one of these.',
   'lot_without_colour', 'id', 'name', 110),
  ('cellar.barrel_colours', 'cellar', 'Barrels, by colour',
   'Red, white or unknown, derived from what each barrel has held since it was '
   'last reconditioned.',
   'barrel_colour', 'id', 'name', 120),
  ('cellar.colour_conflicts', 'cellar', 'White wine in a red barrel',
   'Wine that does not stain, sitting in a barrel that has held wine that does.',
   'white_in_a_red_barrel', 'node_id', 'lot', 130)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('cellar.set_colour', 'cellar', 'Say what colour a wine is',
   'Red, orange, rose or white. Said once on a pick and inherited by everything '
   'that comes off it.',
   'set_colour', 'cellar.lots_without_colour',
   '[{"key":"lot","param":"p_node_id","type":"uuid","required":true,
      "label":"Which lot",
      "source":{"readable":"cellar.lots_without_colour"}},
     {"key":"colour","param":"p_colour","type":"text","required":true,
      "label":"Which colour",
      "source":{"terms":"wine_colour"}}]'::jsonb, 200),

  ('cellar.recondition_barrel', 'cellar', 'Recondition a barrel',
   'Shaved, retoasted or deep cleaned. A barrel that has held red counts as '
   'white again from this moment, and only because of this.',
   'recondition_barrel', 'cellar.barrel_colours',
   '[{"key":"barrel","param":"p_vessel_id","type":"uuid","required":true,
      "label":"Which barrel",
      "source":{"readable":"cellar.barrel_colours"}},
     {"key":"method","param":"p_method","type":"text","required":true,
      "label":"What was done to it",
      "note":"Shaved, retoasted, deep cleaned. Required, because it is the whole of the evidence."},
     {"key":"note","param":"p_note","type":"text","required":false,
      "label":"Note"}]'::jsonb, 210)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

-- Not capabilities. Each answers a question about something a periphery already
-- has, rather than being a thing a person does.
insert into capability_exemption (fn, reason) values
  ('lot_colour', 'Resolves a lot''s colour through its lineage. Arrives on every row that shows a colour.'),
  ('colour_stains', 'Asks the vocabulary whether a colour stains oak. A lookup on a term a periphery already has.'),
  ('barrel_warning', 'Answers whether a fill is worth a word first. A periphery asks it about a vessel and a lot it has already chosen, the way it asks viewer_scope what it is.')
on conflict (fn) do nothing;

commit;
