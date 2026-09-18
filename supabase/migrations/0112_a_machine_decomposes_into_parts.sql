-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A model decomposes into parts, by domain and in a tree, and a
--           machine's parts are that decomposition with its own departures
--           applied, the same way its specification already works."
-- Depends on: [supabase/migrations/0105_a_machine_is_a_departure_from_its_model.sql,
--              supabase/migrations/0106_the_acts_a_shop_performs.sql,
--              supabase/migrations/0111_a_count_that_reads_zero_is_a_lie.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0119_a_machine_keeps_its_papers.sql,
--                  supabase/migrations/0120_the_hot_water_pressure_washer.sql]
-- Axioms enforced: T0-2 (what parts a machine has follows from its model and
--                  what was done to it), AR-E5 (the domains are registry rows),
--                  T0-5 (a part change is a dated entry, never an edit)
-- Open sorries: S-95
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"I'm wanting this to literally have as in depth as possible
-- understanding of each machine. Diagrams, flow charts, engineering schematics,
-- etc. So like for the press we will probably do some research reports and stuff
-- finding this model to get a great baseline that we then depart from. But like
-- it needs decomposed into parts: mechanical parts, electrical parts, software
-- parts, etc."*
--
-- **The decomposition belongs to the model, and that is his own sentence
-- doing the work again.** The research is done once, about a Bucher XPlus rather
-- than about this particular press, and it establishes the baseline. What this
-- press is, including the VFDs somebody fitted, is that baseline plus its
-- departures. So `model_part` hangs off the model and `machine_part_change`
-- hangs off a dated piece of work, and `machine_part` is the two composed.
--
-- **A tree, because that is what a machine is.** The industry calls the bottom
-- of its asset hierarchy the component level, and every CMMS builds it as parent
-- and child: a press has a hydraulic system, which has a pump, which has a seal
-- kit. `parent_id` is that, and the depth is not limited because nobody can say
-- in advance how far down a person will want to go.
--
-- **The domains are a vocabulary, not columns.** Mechanical, electrical,
-- hydraulic, pneumatic, control and software, consumable. He named three and the
-- others are the ones a press and a tractor actually have; being a registry, the
-- list is his to change without a migration.
--
-- **Documents attach to any of it already.** `0101` made the subject registry
-- general, so a schematic can hang on a model, a machine, or a single part, and
-- this registers `model_part` so the third of those works. Nothing new is needed
-- for the diagrams and the reports: what was missing was something specific
-- enough to attach them to.

begin;

-- ---------------------------------------------------------------------------
-- What kind of part it is
-- ---------------------------------------------------------------------------

insert into term_kind (kind, module, label, sort_order) values
  ('part_domain', 'shop', 'Kind of part', 72)
on conflict (kind) do nothing;

insert into term (kind, value, label, sort_order) values
  ('part_domain', 'mechanical',  'Mechanical',        10),
  ('part_domain', 'electrical',  'Electrical',        20),
  ('part_domain', 'hydraulic',   'Hydraulic',         30),
  ('part_domain', 'pneumatic',   'Pneumatic',         40),
  ('part_domain', 'control',     'Control and software', 50),
  ('part_domain', 'consumable',  'Consumable',        60),
  ('part_domain', 'structural',  'Structural',        70)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- The baseline decomposition
-- ---------------------------------------------------------------------------

create table if not exists model_part (
  id          uuid primary key default gen_random_uuid(),
  model_id    uuid not null references machine_model (id) on delete cascade,
  -- A subassembly. Null is a part directly on the machine.
  parent_id   uuid references model_part (id) on delete cascade,
  name        text not null,
  domain_id   uuid references term (id),
  domain_kind text generated always as ('part_domain') stored,
  part_number text,
  -- How many of it, where that is a fact worth having. Six identical membrane
  -- clamps is one row and a number, not six rows.
  quantity    numeric,
  -- Anything the research turned up that is worth knowing about this part
  -- specifically: pressures, tolerances, the fact that it is discontinued.
  spec        jsonb not null default '{}'::jsonb,
  note        text,
  sort_order  int not null default 100,
  created_at  timestamptz not null default now(),
  created_by  uuid references app_user (id),
  constraint model_part_says_what_it_is check (btrim(name) <> ''),
  constraint model_part_quantity_is_a_quantity check (quantity is null or quantity > 0),
  constraint model_part_is_not_its_own_parent check (parent_id is distinct from id),
  constraint model_part_domain_is_a_part_domain
    foreign key (domain_id, domain_kind) references term (id, kind)
);

comment on table model_part is
  'What one of these is made of, as the manufacturer built it. A tree: a part '
  'may be a subassembly of another. The machine''s own parts are this with its '
  'departures applied. See 0112.';

create index if not exists model_part_by_model on model_part (model_id);
create index if not exists model_part_by_parent on model_part (parent_id);

alter table model_part enable row level security;
drop policy if exists model_part_read on model_part;
create policy model_part_read on model_part for select to authenticated
  using (is_facility_user());
drop policy if exists model_part_write on model_part;
create policy model_part_write on model_part for all to authenticated
  using (is_facility_user()) with check (is_facility_user());

-- ---------------------------------------------------------------------------
-- How this one differs
-- ---------------------------------------------------------------------------

create table if not exists machine_part_change (
  id           uuid primary key default gen_random_uuid(),
  -- **Always through a piece of work.** A part did not change on its own: on a
  -- date, somebody fitted, swapped or removed it. This is what keeps one history
  -- rather than two.
  work_id      uuid not null references machine_work (id) on delete cascade,
  -- The stock part this is about, when it is about one. Null means a part the
  -- model never had, which is the VFD case.
  model_part_id uuid references model_part (id) on delete set null,
  -- A change about an earlier change, which is how a part that was added can
  -- later be removed or replaced.
  about_change uuid references machine_part_change (id) on delete set null,
  action       text not null,
  -- What it is now. Null for a removal.
  name         text,
  domain_id    uuid references term (id),
  domain_kind  text generated always as ('part_domain') stored,
  part_number  text,
  quantity     numeric,
  spec         jsonb not null default '{}'::jsonb,
  note         text,
  created_at   timestamptz not null default now(),
  constraint machine_part_change_is_an_action
    check (action in ('added', 'replaced', 'removed')),
  -- Something has to be being changed, and a change about nothing is a typo.
  constraint machine_part_change_is_about_something
    check (model_part_id is not null or about_change is not null or action = 'added'),
  -- A removal names no replacement; anything else must say what it now is.
  constraint machine_part_change_says_what_it_is
    check ((action = 'removed' and name is null) or (action <> 'removed' and btrim(coalesce(name, '')) <> '')),
  constraint machine_part_change_quantity_is_a_quantity
    check (quantity is null or quantity > 0),
  constraint machine_part_change_domain_is_a_part_domain
    foreign key (domain_id, domain_kind) references term (id, kind)
);

comment on table machine_part_change is
  'How one machine''s parts differ from its model''s, each tied to the dated '
  'work that did it. See 0112.';

create index if not exists machine_part_change_by_work on machine_part_change (work_id);

alter table machine_part_change enable row level security;
drop policy if exists machine_part_change_read on machine_part_change;
create policy machine_part_change_read on machine_part_change for select to authenticated
  using (is_facility_user());
drop policy if exists machine_part_change_write on machine_part_change;
create policy machine_part_change_write on machine_part_change for all to authenticated
  using (is_facility_user()) with check (is_facility_user());

-- ---------------------------------------------------------------------------
-- The baseline, readable as a tree
-- ---------------------------------------------------------------------------

create or replace view model_part_tree with (security_invoker = true) as
with recursive walk as (
  select
    p.id, p.model_id, p.parent_id, p.name, p.domain_id, p.part_number,
    p.quantity, p.spec, p.note, p.sort_order,
    0 as depth,
    array[p.sort_order, 0]::int[] as ordering,
    p.name as path
  from model_part p
  where p.parent_id is null
  union all
  select
    c.id, c.model_id, c.parent_id, c.name, c.domain_id, c.part_number,
    c.quantity, c.spec, c.note, c.sort_order,
    w.depth + 1,
    w.ordering || array[c.sort_order, 0],
    w.path || ' > ' || c.name
  from model_part c
  join walk w on w.id = c.parent_id
)
select
  w.id, w.model_id, w.parent_id, w.name, w.part_number, w.quantity, w.spec,
  w.note, w.depth, w.path, w.ordering,
  d.value as domain,
  d.label as domain_label,
  (select count(*) from model_part k where k.parent_id = w.id) as children,
  (select count(*) from attachment a
    where a.subject_type = 'model_part' and a.subject_id = w.id) as documents
from walk w
left join term d on d.id = w.domain_id;

comment on view model_part_tree is
  'A model''s parts, flattened with a depth and a path so a screen can draw the '
  'tree without walking it itself. See 0112.';

grant select on model_part_tree to authenticated;

-- ---------------------------------------------------------------------------
-- What this machine is actually made of
-- ---------------------------------------------------------------------------

-- The same composition `machine_spec` does, one level down. Start with the
-- model's parts, apply the latest change about each, and add the ones the model
-- never had.
create or replace view machine_part with (security_invoker = true) as

-- Stock parts, with the most recent thing said about each.
select
  m.id                      as machine_id,
  p.id                      as model_part_id,
  null::uuid                as change_id,
  coalesce(latest.name, p.name)               as name,
  coalesce(latest.part_number, p.part_number) as part_number,
  coalesce(latest.quantity, p.quantity)       as quantity,
  coalesce(latest.domain_id, p.domain_id)     as domain_id,
  p.parent_id,
  p.sort_order,
  (latest.id is not null)   as departed,
  latest.action             as last_action,
  work.at                   as changed_at
from machine m
join model_part p on p.model_id = m.model_id
left join lateral (
  select c.*, w.at
    from machine_part_change c
    join machine_work w on w.id = c.work_id
   where c.model_part_id = p.id and w.machine_id = m.id
   order by w.at desc, c.created_at desc
   limit 1
) latest on true
left join machine_work work on work.id = latest.work_id
where latest.action is distinct from 'removed'

union all

-- Parts the model never had. The VFD is this row.
select
  w.machine_id,
  null::uuid,
  c.id,
  c.name,
  c.part_number,
  c.quantity,
  c.domain_id,
  null::uuid,
  1000,
  true,
  c.action,
  w.at
from machine_part_change c
join machine_work w on w.id = c.work_id
where c.model_part_id is null
  and c.action = 'added'
  -- Unless something later said it was removed or replaced.
  and not exists (
    select 1 from machine_part_change later
     join machine_work lw on lw.id = later.work_id
    where later.about_change = c.id
      and later.action = 'removed'
  );

comment on view machine_part is
  'What a machine is made of now: its model''s parts with its own departures '
  'applied, plus the parts the model never had. Derived, never stored, the same '
  'as machine_spec. See 0112.';

grant select on machine_part to authenticated;

-- ---------------------------------------------------------------------------
-- A part is something a document can be about
-- ---------------------------------------------------------------------------

insert into subject_resolver (subject_type, relation, name_expression, module) values
  ('model_part', 'model_part', 'name', 'shop')
on conflict (subject_type) do update
  set relation = excluded.relation,
      name_expression = excluded.name_expression,
      module = excluded.module;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('shop.model_parts', 'shop', 'What a model is made of',
   'The parts of each model, as a tree, by kind. Schematics and diagrams attach to any of them.',
   'model_part_tree', 'id', 'name', 306),
  ('shop.machine_parts', 'shop', 'What a machine is made of',
   'A machine''s parts: its model''s decomposition with everything done to this one applied over it.',
   'machine_part', 'machine_id', 'name', 307)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

commit;
