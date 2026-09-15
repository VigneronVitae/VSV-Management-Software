-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "One read that says everything about a lot, so the wine in a vessel
--           is somewhere you can go rather than a name printed on a row."
-- Depends on: [supabase/migrations/0071_a_wine_says_its_colour.sql,
--              supabase/migrations/0062_a_note_on_anything.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (the colour here is resolved through the lineage at
--                  read time and is not a column), AR-Q8 (the periphery reads
--                  one declared thing rather than assembling four)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"I also need a way to edit (add/append only is fine) wine in
-- vessels, like to add the color."*
--
-- **There was nowhere to do that, and the code said so out loud.** Tapping a
-- full vessel went to the vessel edit screen under a comment reading "a full one
-- goes straight to the edit screen, because there is only one thing left to do
-- to it". That was true when every fact about a lot arrived at intake and
-- stopped. It stopped being true the moment a lot had a colour somebody says
-- afterwards, and it was already half untrue: a lot has a vintage, a name, and
-- notes, and none of them had a door.
--
-- So the wine gets a screen, and a screen needs one read. Four round trips
-- assembled in a client is how two clients end up disagreeing about what a lot
-- is, which is the rule about clients not encoding business rules wearing
-- different clothes.
--
-- **Nothing here is stored that is derived.** The colour comes through
-- `lot_colour`, so a lot that inherits red from its parents shows red and the
-- column stays null, and `colour_told` is what the screen uses to say whether
-- anybody has actually said it about this lot or whether it came down the
-- lineage. That distinction is the whole of why somebody would open the screen.

begin;

create or replace view lot_detail with (security_invoker = true) as
select
  n.id,
  n.name,
  n.stage::text   as stage,
  n.status::text  as status,
  n.vintage,
  n.non_vintage,
  v.label         as variety,
  pt.label        as product_type,
  c.value         as colour,
  c.label         as colour_label,
  -- Said about this lot, as against inherited from a parent. A screen that
  -- cannot tell those apart either nags about a lot that has an answer or
  -- hides that nobody ever gave one.
  (n.colour_id is not null) as colour_told,
  n.owner_id,
  o.name          as owner_name,
  n.provenance::text as provenance,
  n.created_at,
  -- Where it is now, which is the question that brought somebody here. A lot
  -- in more than one vessel gets more than one row, which is the truth.
  p.vessel_id,
  ve.name         as vessel,
  p.volume_l,
  p.from_at       as filled_at
from node n
left join term v  on v.id = n.variety_id
left join term pt on pt.id = n.product_type_id
left join term c  on c.id = lot_colour(n.id)
left join party o on o.id = n.owner_id
left join placement p on p.node_id = n.id and p.to_at is null
left join vessel ve on ve.id = p.vessel_id;

comment on view lot_detail is
  'Everything a screen needs to show one lot, in one read. The colour is '
  'resolved through the lineage rather than read off the column, and '
  'colour_told says which of those happened. See 0078.';

grant select on lot_detail to authenticated;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.lot_detail', 'cellar', 'One lot',
   'Everything about a lot, including where it is standing and what colour it is.',
   'lot_detail', 'id', 'name', 140)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

commit;
