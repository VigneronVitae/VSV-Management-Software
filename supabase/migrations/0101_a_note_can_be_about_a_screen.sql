-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A note can be about anything, including the app itself: screens
--           become rows so that a note about wording points at the screen whose
--           wording it is, rather than being a sentence in a list."
-- Depends on: [supabase/migrations/0026_subject_type_registry.sql,
--              supabase/migrations/0063_a_note_is_a_thing_too.sql,
--              supabase/migrations/0100_a_jacket_is_on_a_machine.sql]
-- Depended on by: [tests/schema_assertions.sql, scripts/screens.sh,
--                  supabase/migrations/0102_a_tank_takes_more_than_one_pressing.sql,
--                  supabase/migrations/0107_the_shop_has_screens_too.sql,
--                  supabase/migrations/0113_a_vineyard_is_a_place_you_can_open.sql,
--                  supabase/migrations/0114_every_pick_stays_on_the_list.sql,
--                  supabase/migrations/0118_the_vineyard_has_a_door.sql]
-- Axioms enforced: AR-E5 (a registry row rather than a new kind of note),
--                  A13 (a note about "the vessels screen" filed against nothing
--                  is a note nobody will ever find again)
-- Open sorries: S-89
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"I think we need to upgrade notes. I want to be able to add a
-- note to anything. Maybe a permanent top right block to select something on any
-- screen to take a note of? One of my first uses will be to make notes of
-- verbage changes, so notes point to actual objects."*
--
-- **Most of this was already built.** `add_note(subject_type, subject_id, ...)`
-- has taken any registered subject since `0063`, and it refuses a type nothing
-- is, which is why this is a registry change rather than a notes change. What
-- was missing was a place to put the control and three things worth pointing at.
--
-- **The hard half is the first use he named.** A note about wording is about a
-- screen or a label, and a screen is not an object in this schema: it is a
-- string in a TypeScript file. A note filed against nothing is the A13 shape in
-- the place it hurts most, because the whole value of "notes point to actual
-- objects" is being able to come back to the object and find the note.
--
-- So screens become rows. Forty one of them, which is the list the client
-- already routes on, and `scripts/screens.sh` compares the two so a screen added
-- without a row is caught by the gate rather than by somebody trying to file a
-- note on it. That check is the whole reason this is safe to do: a registry that
-- can silently fall behind the thing it describes is worse than no registry.
--
-- **Two other subjects, for the same reason.** `term` is where the words this
-- winery chose actually live: variety names, vessel types, fact kinds. A note
-- saying "call this Grüner rather than Gruner" points at the row that says it.
-- `glycol_machine` arrived yesterday in `0100` with no way to note anything
-- about it.
--
-- What is deliberately not here: the wording inside a screen. A note can say
-- "the button on this screen should read Save rather than Record", and it points
-- at the screen, not at the button, because the button is not a row either and
-- making every label a row is a content management system nobody asked for. That
-- is S-89.

begin;

-- ---------------------------------------------------------------------------
-- The screens
-- ---------------------------------------------------------------------------

create table if not exists screen (
  id         uuid primary key default gen_random_uuid(),
  -- What the client routes on. The join between a note and a place somebody was
  -- standing when they wrote it.
  key        text not null unique,
  label      text not null,
  note       text,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table screen is
  'Every screen the client can be at, so a note can be about one. Kept in step '
  'with the client by scripts/screens.sh. See 0101.';

alter table screen enable row level security;

drop policy if exists screen_read on screen;
create policy screen_read on screen for select to authenticated
  using (is_facility_user());
drop policy if exists screen_write on screen;
create policy screen_write on screen for all to authenticated
  using (is_admin()) with check (is_admin());

-- The list the client routes on, as of 0101. A screen added to `places.ts`
-- without a row here is caught by scripts/screens.sh in the gate.
insert into screen (key, label) values
  ('home',           'Home'),
  ('vessels',        'Vessels'),
  ('vessel',         'A vessel'),
  ('vessel-new',     'Add an empty vessel'),
  ('vessel-edit',    'Edit a vessel'),
  ('vessel-wine',    'Put wine in a vessel'),
  ('vessel-fill',    'Fill a vessel'),
  ('vessel-type',    'A vessel type'),
  ('vessel-types',   'Vessel types'),
  ('vessel-photos',  'Photographs of a vessel'),
  ('rack',           'Rack'),
  ('scan',           'Scan a code'),
  ('locations',      'Rooms'),
  ('clients',        'Clients'),
  ('intake',         'Intake'),
  ('pick-new',       'A new pick'),
  ('pick-bins',      'Bins on a pick'),
  ('pick-photos',    'Photographs of a pick'),
  ('scale',          'The scale'),
  ('press',          'Press'),
  ('bins-to-return', 'Bins to return'),
  ('export',         'Take a copy'),
  ('vineyards',      'Vineyards'),
  ('block',          'A block'),
  ('day',            'The day log'),
  ('paper',          'Paperwork'),
  ('makers',         'Coopers and manufacturers'),
  ('stores',         'Stores'),
  ('vintages',       'Vintages'),
  ('additions',      'Additions'),
  ('practice',       'Practice mode'),
  ('fact-kinds',     'Fact kinds'),
  ('invites',        'Invites'),
  ('sampling',       'Sampling'),
  ('sample',         'A sample'),
  ('go',             'Go to'),
  ('colours',        'Colours'),
  ('bins',           'Picking bins'),
  ('running',        'Running'),
  ('glycol',         'Glycol'),
  ('wine',           'A wine')
on conflict (key) do update set label = excluded.label;

-- ---------------------------------------------------------------------------
-- Three more things a note can be about
-- ---------------------------------------------------------------------------

insert into subject_resolver (subject_type, relation, name_expression, module) values
  -- A screen is named by what it is called on screen, which is what somebody
  -- writing "this wording is wrong" would recognise in a list afterwards.
  ('screen', 'screen', 'label', 'core'),
  -- Where the words this winery chose actually live. A note about calling
  -- something by a different name points at the row that says the name.
  ('term', 'term', 'label', 'core'),
  -- 0100 arrived with no way to say anything about a machine.
  ('glycol_machine', 'glycol_machine', 'name', 'cellar')
on conflict (subject_type) do update
  set relation = excluded.relation,
      name_expression = excluded.name_expression,
      module = excluded.module;

-- ---------------------------------------------------------------------------
-- What a screen is written against
-- ---------------------------------------------------------------------------

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.screens', 'cellar', 'Screens',
   'Every screen in the app, so a note can be about one.',
   'screen', 'id', 'label', 400)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

commit;
