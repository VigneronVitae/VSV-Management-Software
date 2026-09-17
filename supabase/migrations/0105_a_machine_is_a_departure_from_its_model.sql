-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A machine is a model plus everything done to it since, so what it is
--           today is read from its history rather than typed into a field that
--           goes stale the first time somebody changes it."
-- Depends on: [supabase/migrations/0026_subject_type_registry.sql,
--              supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0053_a_press_is_a_vessel.sql,
--              supabase/migrations/0104_a_pressed_bin_leaves_the_room.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0106_the_acts_a_shop_performs.sql]
-- Axioms enforced: T0-2 (what a machine is now follows from what was done to it
--                  and is never a second fact to maintain), T0-5 (work is
--                  append-only: a repair recorded wrongly is corrected by a new
--                  entry), AR-E5 (the kinds of work are registry rows)
-- Open sorries: S-91
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"I want to figure out where press as item lives. Like the thing
-- I would use when I'm working on it, or designing around it. Like it has an old
-- ass UI, plus we have done things like install VFDs to convert to 3 phase power.
-- There should be an app that isn't maintenance exactly, but lineage of equipment
-- including maintenance?"*
--
-- And, asked what counts: *"Less winemaking specific and more machinery, or
-- things that need fixed and diagnosed. Tractor and tractor equipment, press,
-- sorting line, etc. Stuff that is unique (and not - hence the bridge).
-- Departure from something."*
--
-- **Those last two phrases are the design and they are his.**
--
-- *Unique and not.* A press is one of a model and also this particular one with
-- its own serial and its own scars. Both facts are wanted: the model is where the
-- manual and the stock specification live, and the individual is where the hours
-- and the history live. So two tables, and the individual points at the model.
-- That is the same bridge `vessel` and `vessel_type` already are.
--
-- *Departure from something.* This is the better half. A machine is not described
-- by a list of current attributes that somebody remembers to update; it is its
-- model, plus every departure since. The VFDs are the example he gave: the press
-- as shipped is single phase and the press in his shed is not, and the honest way
-- to say so is that somebody installed VFDs on a date, not that a field reads
-- three phase because a person typed it.
--
-- So `machine_spec` reads the model's specification and then applies the
-- departures over the top, newest last. Nothing caches it. A machine whose
-- history is empty reads exactly as its model, which is the correct answer for
-- one nobody has touched.
--
-- **The other bridge: a machine can be a vessel.** The press is already a vessel,
-- because `0053` made it one so fruit could be placed in it. It must not become a
-- second object. `machine.vessel_id` says this machine and that vessel are the
-- same thing, and the tractor simply has none.
--
-- What is deliberately not here: schedules, due dates, reminders, hour meters
-- rolling over into service intervals. He asked for lineage including
-- maintenance, not a maintenance planner, and a due date nobody set is a screen
-- full of red that teaches people to ignore red. That is S-91.

begin;

-- ---------------------------------------------------------------------------
-- The kinds of work, as vocabulary rather than as an enum
-- ---------------------------------------------------------------------------

insert into term_kind (kind, module, label, sort_order) values
  ('machine_work_kind', 'shop', 'Kind of work', 70),
  ('machine_kind',      'shop', 'Kind of machine', 71)
on conflict (kind) do nothing;

-- `changes_spec` is the one attribute that matters here: it separates a
-- departure, which changes what the machine is, from work that returns it to
-- what it was. Installing VFDs is the first; changing the hydraulic oil is the
-- second, and neither is more important than the other.
insert into term (kind, value, label, sort_order, attributes) values
  ('machine_work_kind', 'modification', 'Modification', 10, '{"changes_spec": true}'::jsonb),
  ('machine_work_kind', 'repair',       'Repair',       20, '{"changes_spec": false}'::jsonb),
  ('machine_work_kind', 'service',      'Service',      30, '{"changes_spec": false}'::jsonb),
  ('machine_work_kind', 'diagnosis',    'Diagnosis',    40, '{"changes_spec": false}'::jsonb),
  ('machine_work_kind', 'inspection',   'Inspection',   50, '{"changes_spec": false}'::jsonb),
  -- The thing you only learn by standing in front of it at 6am. It is not
  -- maintenance and it is exactly what he meant by the old UI.
  ('machine_work_kind', 'quirk',        'Quirk',        60, '{"changes_spec": false}'::jsonb)
on conflict do nothing;

insert into term (kind, value, label, sort_order) values
  ('machine_kind', 'press',      'Press',            10),
  ('machine_kind', 'tractor',    'Tractor',          20),
  ('machine_kind', 'implement',  'Tractor implement',30),
  ('machine_kind', 'sorting',    'Sorting line',     40),
  ('machine_kind', 'pump',       'Pump',             50),
  ('machine_kind', 'chiller',    'Chiller',          60),
  ('machine_kind', 'other',      'Other',            70)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- The not-unique half
-- ---------------------------------------------------------------------------

create table if not exists machine_model (
  id          uuid primary key default gen_random_uuid(),
  make        text not null,
  model       text not null,
  kind_id     uuid references term (id),
  kind_kind   text generated always as ('machine_kind') stored,
  -- The stock specification: what one of these is before anybody touches it.
  -- Free-form because a press and a forklift have nothing in common to put in
  -- columns, and inventing a schema for both is how this becomes a project.
  spec        jsonb not null default '{}'::jsonb,
  note        text,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  created_by  uuid references app_user (id),
  constraint machine_model_says_what_it_is check (btrim(make) <> '' and btrim(model) <> ''),
  constraint machine_model_kind_is_a_machine_kind
    foreign key (kind_id, kind_kind) references term (id, kind)
);

comment on table machine_model is
  'A kind of machine as the manufacturer made it: make, model, and the stock '
  'specification. The unique half is `machine`. See 0105.';

alter table machine_model enable row level security;
drop policy if exists machine_model_read on machine_model;
create policy machine_model_read on machine_model for select to authenticated
  using (is_facility_user());
drop policy if exists machine_model_write on machine_model;
create policy machine_model_write on machine_model for all to authenticated
  using (is_facility_user()) with check (is_facility_user());

-- ---------------------------------------------------------------------------
-- The unique half
-- ---------------------------------------------------------------------------

create table if not exists machine (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  model_id    uuid references machine_model (id) on delete set null,
  serial      text,
  -- **The bridge.** The press is already a vessel and must not become a second
  -- object with a second history. The tractor has none of this and that is the
  -- point: a machine is not a kind of vessel, it sometimes is one.
  vessel_id   uuid unique references vessel (id) on delete set null,
  location_id uuid references location (id) on delete set null,
  acquired_at date,
  active      boolean not null default true,
  attributes  jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  created_by  uuid references app_user (id),
  constraint machine_says_what_it_is check (btrim(name) <> '')
);

comment on table machine is
  'One actual machine. vessel_id is set when this machine is also a vessel, '
  'which the press is. What it is now is machine_spec, not a column here. '
  'See 0105.';

create index if not exists machine_by_model on machine (model_id);

alter table machine enable row level security;
drop policy if exists machine_read on machine;
create policy machine_read on machine for select to authenticated
  using (is_facility_user());
drop policy if exists machine_write on machine;
create policy machine_write on machine for all to authenticated
  using (is_facility_user()) with check (is_facility_user());

-- ---------------------------------------------------------------------------
-- What was done to it
-- ---------------------------------------------------------------------------

create table if not exists machine_work (
  id          uuid primary key default gen_random_uuid(),
  machine_id  uuid not null references machine (id) on delete cascade,
  kind_id     uuid not null references term (id),
  kind_kind   text generated always as ('machine_work_kind') stored,
  -- **When it happened, which is not when it was typed.** The VFDs went in
  -- months before this table existed. A history that can only record today is a
  -- history nobody can enter.
  at          date not null default current_date,
  body        text not null,
  -- What this departure changes about the specification. Only read for a kind
  -- that says it changes the spec, and null for the ordinary repair.
  spec_change jsonb,
  by_user     uuid references app_user (id),
  created_at  timestamptz not null default now(),
  constraint machine_work_says_something check (btrim(body) <> ''),
  constraint machine_work_kind_is_a_work_kind
    foreign key (kind_id, kind_kind) references term (id, kind)
);

comment on table machine_work is
  'Everything done to a machine, with the date it happened rather than the date '
  'it was typed. Append only: a wrong entry is corrected by another. See 0105.';

create index if not exists machine_work_by_machine on machine_work (machine_id, at desc);

alter table machine_work enable row level security;
drop policy if exists machine_work_read on machine_work;
create policy machine_work_read on machine_work for select to authenticated
  using (is_facility_user());
drop policy if exists machine_work_write on machine_work;
create policy machine_work_write on machine_work for all to authenticated
  using (is_facility_user()) with check (is_facility_user());

-- ---------------------------------------------------------------------------
-- What it is now: the model, plus the departures
-- ---------------------------------------------------------------------------

-- The whole idea, in one function. The model says what one of these is. Every
-- modification since says how this one differs. Applied oldest first so the most
-- recent change wins, which is what somebody means when they say a machine was
-- converted and then converted again.
--
-- Nothing is stored. A machine with no history reads exactly as its model, which
-- is the right answer for one nobody has touched, and the VFD install is a row
-- rather than a checkbox somebody has to remember to tick.
create or replace function machine_spec(p_machine_id uuid)
returns jsonb
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
  select coalesce(
    (select coalesce(mm.spec, '{}'::jsonb) from machine m
       left join machine_model mm on mm.id = m.model_id
      where m.id = p_machine_id)
    ||
    coalesce((
      select jsonb_object_agg(key, value)
        from (
          select distinct on (d.key) d.key, d.value
            from machine_work w
            join term t on t.id = w.kind_id
            cross join lateral jsonb_each(coalesce(w.spec_change, '{}'::jsonb)) d
           where w.machine_id = p_machine_id
             and coalesce((t.attributes ->> 'changes_spec')::boolean, false)
           order by d.key, w.at desc, w.created_at desc
        ) latest
    ), '{}'::jsonb),
    '{}'::jsonb);
$$;

comment on function machine_spec(uuid) is
  'What a machine is now: its model''s specification with every modification '
  'applied over the top, newest winning. Derived, never stored. See 0105.';

-- ---------------------------------------------------------------------------
-- What a screen reads
-- ---------------------------------------------------------------------------

create or replace view machine_detail with (security_invoker = true) as
select
  m.id,
  m.name,
  m.serial,
  m.acquired_at,
  m.active,
  mm.id            as model_id,
  mm.make,
  mm.model,
  nullif(concat_ws(' ', mm.make, mm.model), '') as model_name,
  k.label          as kind,
  l.name           as location_name,
  m.vessel_id,
  v.name           as vessel_name,
  mm.spec          as stock_spec,
  machine_spec(m.id) as spec,
  -- So a screen can say "three phase, since the VFDs" rather than just "three
  -- phase". The departure is the interesting part.
  (select count(*) from machine_work w
     join term t on t.id = w.kind_id
    where w.machine_id = m.id
      and coalesce((t.attributes ->> 'changes_spec')::boolean, false)) as modifications,
  (select count(*) from machine_work w where w.machine_id = m.id) as entries,
  (select max(w.at) from machine_work w where w.machine_id = m.id) as last_worked_on
from machine m
left join machine_model mm on mm.id = m.model_id
left join term k on k.id = mm.kind_id
left join location l on l.id = m.location_id
left join vessel v on v.id = m.vessel_id;

comment on view machine_detail is
  'A machine as a machine: what it is, where it is, what it is also (a vessel, '
  'sometimes), and how much has been done to it. See 0105.';

grant select on machine_detail to authenticated;

create or replace view machine_history with (security_invoker = true) as
select
  w.id,
  w.machine_id,
  m.name        as machine,
  w.at,
  t.value       as kind,
  t.label       as kind_label,
  coalesce((t.attributes ->> 'changes_spec')::boolean, false) as changed_it,
  w.body,
  w.spec_change,
  u.name        as by_whom,
  w.created_at
from machine_work w
join machine m on m.id = w.machine_id
join term t on t.id = w.kind_id
left join app_user u on u.id = w.by_user
order by w.at desc, w.created_at desc;

comment on view machine_history is
  'Everything done to every machine, newest first. See 0105.';

grant select on machine_history to authenticated;

-- ---------------------------------------------------------------------------
-- A machine is something a note can be about
-- ---------------------------------------------------------------------------

insert into subject_resolver (subject_type, relation, name_expression, module) values
  ('machine', 'machine', 'name', 'shop'),
  ('machine_model', 'machine_model', 'make || '' '' || model', 'shop')
on conflict (subject_type) do update
  set relation = excluded.relation,
      name_expression = excluded.name_expression,
      module = excluded.module;

commit;
