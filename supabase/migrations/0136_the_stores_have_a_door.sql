-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The inventory module gets a way to add a thing, its own count verb
--           back from the cellar, four screens and a path, so that everything
--           built for tools this afternoon has somewhere a person can open it."
-- Depends on: [supabase/migrations/0046_supply_inventory.sql,
--              supabase/migrations/0109_a_module_says_where_it_lives.sql,
--              supabase/migrations/0135_a_photograph_can_point_at_something.sql]
-- Depended on by: [docs/status-ledger.md, scripts/screens.sh,
--                  packages/inventory/src/places.ts,
--                  packages/inventory/src/inventory.ts]
-- Axioms enforced: none new.
-- Open sorries: closes the inventory half of S-94. Marketing is the last module
--               on the front door that cannot be opened.
-- ---------------------------------------------------------------------------

-- "Also is this going to be a new module/app? Would love for it to."
--
-- It was always going to be a module, and it has been one since `0109` in the
-- sense that matters least: a row saying `inventory`, labelled Stores, with no
-- path, no verbs of its own and its one real capability filed under the cellar.
-- `0134` gave it two verbs and three views. This gives it the rest.
--
-- **Nothing in the contract could add a thing**, which is the gap `0132` found in
-- the same shape for places: three migrations of machinery for tools, and no way
-- to write down a hammer. `supply` rows got into this database before the
-- contract existed and there has been one of them ever since.
--
-- `count_supply` moves from `cellar` to `inventory`. It was written in `0046`
-- when the cellar was the only periphery, the function is untouched, and this is
-- only the registry admitting whose verb it is. A periphery asking "what can I
-- do with stock" now gets an answer that includes counting it.

create or replace function add_supply(
  p_name          text,
  p_unit          text default null,
  p_reorder_level numeric default null,
  p_supplier      text default null,
  p_home_id       uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare made supply%rowtype;
begin
  if not is_facility_user() then
    raise exception 'stock is added by people who work here';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'a thing needs a name somebody would call it';
  end if;
  if p_reorder_level is not null and p_reorder_level < 0 then
    raise exception 'a reorder level below zero is not a level to reorder at';
  end if;
  if p_home_id is not null
     and not exists (select 1 from location where id = p_home_id) then
    raise exception 'there is no such place to keep it';
  end if;

  insert into supply (name, unit, reorder_level, supplier, home_id)
  values (btrim(p_name), nullif(btrim(coalesce(p_unit, '')), ''),
          p_reorder_level, nullif(btrim(coalesce(p_supplier, '')), ''), p_home_id)
  returning * into made;

  return jsonb_build_object('id', made.id, 'name', made.name);
end $$;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('inventory.add_supply', 'inventory', 'Add a thing',
   'Writes down something we have: a consumable, a tool, a box of screws. A unit and a reorder level are for things that run out; a thing that comes back needs neither.',
   'add_supply',
   '[{"key": "name", "type": "text", "label": "What it is called", "param": "p_name", "required": true},
     {"key": "unit", "type": "text", "label": "Counted in", "param": "p_unit", "required": false,
      "hint": "Rolls, kg, each. Leave blank for something you would not count."},
     {"key": "reorder_level", "type": "number", "label": "Reorder when it drops below", "param": "p_reorder_level", "required": false},
     {"key": "supplier", "type": "text", "label": "Who we buy it from", "param": "p_supplier", "required": false},
     {"key": "home", "type": "uuid", "label": "Lives at", "param": "p_home_id", "required": false,
      "source": {"readable": "core.places"}}]'::jsonb,
   39)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

-- The verb changes hands. Same function, same fields, a different word in front
-- of the dot, because the registry saying `cellar.count_supply` is the registry
-- saying something untrue about which module owns stock.
update capability
   set key = 'inventory.count_supply', module = 'inventory'
 where key = 'cellar.count_supply';

-- `cellar.supplies_for_addition` deliberately stays the cellar's. It was moved
-- in a first draft of this migration and the schema refused, because
-- `capability.fields` names a readable and there is a foreign key holding it:
-- `cellar.add_to_wine` reads that list to fill its picker. The refusal was right
-- for a better reason than the one it gave. Counting stock is a stores question
-- and belongs to inventory; "which of these may go into wine" is a winemaking
-- question about stock, and the cellar is exactly whose it is. A module owning a
-- view of another module's data is not the same as a module owning that data.
--
-- Worth recording that the contract is self-checking to this degree at all. A
-- readable cannot be renamed out from under a capability that reads it, which is
-- the drift 0060 found twenty-nine instances of, prevented by a key rather than
-- by a check.

-- ---------------------------------------------------------------------------
-- The door
-- ---------------------------------------------------------------------------

-- `stores` and `locations` are already taken by cellar screens, which is why
-- these are not called that. scripts/screens.sh reads places.ts, so these rows
-- and that place list go in together or the gate fails.
insert into screen (key, label) values
  ('stock',  'Everything we have'),
  ('thing',  'One thing'),
  ('places', 'The places'),
  ('place',  'One place')
on conflict (key) do nothing;

-- Same origin as the other four, so one sign-in still serves all of them.
update module set path = '/inventory/' where key = 'inventory';

do $$
begin
  if not exists (select 1 from module where key = 'inventory' and path is not null) then
    raise exception 'the stores still have no door, so the front page draws them shut';
  end if;
  if exists (select 1 from capability where key = 'cellar.count_supply') then
    raise exception 'counting stock is still filed under the cellar';
  end if;
  if (select count(*) from capability where module = 'inventory') < 4 then
    raise exception 'the inventory module has fewer verbs than it needs to be used';
  end if;
end $$;
