-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Registers the gases a cellar puts over wine and the ways wine is
--           moved, so the four free text fields on the racking screen stop being
--           strings somebody spells four ways."
-- Depends on: [supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0014_rack.sql]
-- Depended on by: [docs/status-ledger.md, packages/cellar/src/index.ts]
-- Axioms enforced: AR-E5. Registry rows rather than an enum, so a cellar that
--                  blankets with something else adds a row instead of waiting
--                  for a migration.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- "Things like the gas and stuff should be a drop-down list instead of text."
--
-- The racking screen asks three gas questions, at the source, in the line and at
-- the destination, and all three have been free text since `0014` with a
-- placeholder reading "air, argon, nitrogen". `termOrText` in walk.ts is a
-- function whose name says what it was always meant to become and whose body is
-- one line returning a plain text field.
--
-- Free text here is worse than usually. These three fields exist to record
-- oxygen pickup, which is the difference between a clean rack and a lost one,
-- and the whole value of the record is being able to ask later which racks were
-- done under argon. "Ar", "argon", "Argon" and "argon?" do not group, and
-- nothing would ever tell you they had not.
--
-- **Air is on the list and is not a mistake.** A vessel left open is the fact
-- most worth recording of the four, and a vocabulary that only admits the inert
-- gases would push that case back into a blank field or, worse, into a lie.

insert into term_kind (kind, label, module, sort_order) values
  ('gas', 'Gas', 'winemaking', 130)
on conflict (kind) do update set
  label = excluded.label, module = excluded.module, sort_order = excluded.sort_order;

-- Four, and the AR-J4 test is whether another winery installing this would have
-- them. Air is what a vessel holds when nobody has done anything; argon,
-- nitrogen and carbon dioxide are what the industry blankets with. Which of the
-- three a given cellar keeps in a bottle is its own business, and adding a
-- fifth is a row rather than a migration.
insert into term (kind, value, label, sort_order) values
  ('gas', 'air',            'Air',            100),
  ('gas', 'argon',          'Argon',          200),
  ('gas', 'nitrogen',       'Nitrogen',       300),
  ('gas', 'carbon_dioxide', 'Carbon dioxide', 400)
on conflict (kind, value) do update set
  label = excluded.label, sort_order = excluded.sort_order, active = true;

do $$
begin
  if (select count(*) from term where kind = 'gas' and active) < 4 then
    raise exception 'the gas vocabulary is short, so a picker built on it would offer less than the cellar uses';
  end if;
  -- The one that would be tempting to leave out.
  if not exists (select 1 from term where kind = 'gas' and value = 'air' and active) then
    raise exception 'air is not on the list, so a vessel left open has nowhere honest to be recorded';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- And how it was moved
-- ---------------------------------------------------------------------------

-- The fourth free text field on the same screen, placeholder "gravity, pump".
-- Two members, because those are the two ways wine moves between vessels
-- anywhere and a third would be guessing at what this cellar distinguishes. A
-- push under gas is arguably a third and arguably a pump; nobody has been asked,
-- and AR-E5 means the answer is a row rather than a migration.
insert into term_kind (kind, label, module, sort_order) values
  ('rack_method', 'How it was moved', 'winemaking', 131)
on conflict (kind) do update set
  label = excluded.label, module = excluded.module, sort_order = excluded.sort_order;

insert into term (kind, value, label, sort_order) values
  ('rack_method', 'gravity', 'Gravity', 100),
  ('rack_method', 'pump',    'Pump',    200)
on conflict (kind, value) do update set
  label = excluded.label, sort_order = excluded.sort_order, active = true;

do $$
begin
  if (select count(*) from term where kind = 'rack_method' and active) < 2 then
    raise exception 'the racking method vocabulary is short';
  end if;
end $$;
