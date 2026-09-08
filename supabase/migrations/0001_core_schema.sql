-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Defines the core object model: nodes, lineage, vessels, placements,
--           events, templates, tasks, and users."
-- Depends on: [packages/cellar/docs/spec.md]
-- Depended on by: [supabase/migrations/0002_derived_and_rls.sql,
--                 supabase/migrations/0003_parties_and_products.sql,
--                 docs/status-ledger.md]
-- Axioms enforced: T0-1 (one node type), T0-3 (provenance on every event),
--                  T0-5 (append-only history)
-- Open sorries: S-3 (partial parent consumption), S-4 (subject_id not a FK),
--               S-5 (vessel type granularity)
-- ---------------------------------------------------------------------------

-- Winery production app, core schema
-- Vitae Springs / Amica Luna
--
-- Conventions:
--   All ids are uuid, generated client-side so offline writes have identity
--   before the server sees them. Never use sequences for anything a phone creates.
--
--   Timestamps are timestamptz. The winery is one timezone but harvest runs
--   across DST and nobody should think about that.
--
--   Derived values (block composition, vessel occupancy) are functions and views,
--   never columns. Two sources of truth diverge the first time a volume is corrected.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type node_stage as enum (
  'bin', 'load', 'ferment', 'maturation', 'finished'
);

create type node_status as enum (
  'planned', 'open', 'closed'
);

create type provenance as enum (
  'observed',   -- someone recorded it when it happened
  'inferred',   -- generated from a template, not witnessed
  'confirmed'   -- inferred, then a human said yes
);

create type quantity_unit as enum ('lbs', 'kg', 'L', 'gal');

create type vessel_type as enum (
  'macrobin', 'fermenter', 'tank', 'barrel'
);

create type thermal_mode as enum ('cooling', 'heating', 'off');

create type subject_type as enum ('node', 'vessel', 'location', 'block');

create type task_status as enum ('open', 'claimed', 'done', 'skipped');

create type user_role as enum ('admin', 'cellar');

-- Operation vocabulary, grouped by effect on state.
-- Adding a value later: `alter type event_type add value '...'`
create type event_type as enum (
  -- measurements: observe, change nothing
  'sample', 'temp_reading',
  -- treatments: change the wine in place
  'addition', 'punchdown', 'pumpover', 'batonnage', 'topping',
  'cold_soak', 'cold_crash', 'cold_stabilize', 'filter',
  'halt_fermentation', 'malo_check',
  -- movements: change vessels, not the lot
  'rack', 'consolidate', 'distribute_lees', 'move_vessel',
  -- transformations: close nodes, open new ones, write lineage
  'press', 'destem', 'blend', 'bottle',
  -- environment
  'setpoint_change'
);

-- ---------------------------------------------------------------------------
-- People
-- ---------------------------------------------------------------------------

-- Mirrors auth.users. Supabase owns identity; this owns role.
create table app_user (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  role        user_role not null default 'cellar',
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create or replace function is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from app_user
    where id = auth.uid() and role = 'admin' and active
  );
$$;

-- ---------------------------------------------------------------------------
-- Places and vessels
-- ---------------------------------------------------------------------------

create table location (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  controlled  boolean not null default false,
  ambient_c   numeric(5,2),
  created_at  timestamptz not null default now()
);

create table block (
  id          uuid primary key default gen_random_uuid(),
  vineyard    text not null,
  name        text not null,
  variety     text not null,
  notes       text,
  created_at  timestamptz not null default now(),
  unique (vineyard, name)
);

create table vessel (
  id          uuid primary key default gen_random_uuid(),
  type        vessel_type not null,
  name        text not null,
  capacity_l  numeric(10,2),
  location_id uuid references location(id),

  -- vessels move between bays; location lives here, not on the placement
  has_glycol  boolean not null default false,
  setpoint_c  numeric(5,2),
  mode        thermal_mode not null default 'off',

  -- cooper, wood species, fill count, toast, format. Loose because barrels
  -- and tanks want different things and this is not worth normalising.
  attributes  jsonb not null default '{}'::jsonb,

  qr_code     text unique,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (type, name)
);

create index vessel_location_idx on vessel(location_id) where active;
create index vessel_qr_idx on vessel(qr_code) where qr_code is not null;

-- ---------------------------------------------------------------------------
-- Nodes: everything that is wine or becomes wine
-- ---------------------------------------------------------------------------

create table node (
  id          uuid primary key default gen_random_uuid(),
  stage       node_stage not null,
  status      node_status not null default 'open',

  variety     text,
  vintage     int,

  -- input only at stage='bin'. Composition downstream is derived from lineage.
  block_id    uuid references block(id),

  name        text not null,

  quantity    numeric(12,3),
  unit        quantity_unit,

  -- whole_cluster_pct, style_intent, pick_number, cap_rule, planned_bins
  attributes  jsonb not null default '{}'::jsonb,

  provenance  provenance not null default 'observed',

  closed_at   timestamptz,
  created_at  timestamptz not null default now(),
  created_by  uuid references app_user(id),

  -- block only means anything on a bin
  constraint block_only_on_bins
    check (block_id is null or stage = 'bin')
);

create index node_stage_idx on node(stage) where status <> 'closed';
create index node_variety_vintage_idx on node(variety, vintage);
create index node_block_idx on node(block_id) where block_id is not null;

-- Lineage. A DAG with both splits and merges: three Chardonnay vineyards feed
-- single-vineyard bottlings and two of them also feed reserve and distribution.
create table lineage (
  parent_id   uuid not null references node(id) on delete restrict,
  child_id    uuid not null references node(id) on delete restrict,
  fraction    numeric(6,5) not null check (fraction > 0 and fraction <= 1),
  created_at  timestamptz not null default now(),
  primary key (parent_id, child_id),
  constraint no_self_parent check (parent_id <> child_id)
);

create index lineage_child_idx on lineage(child_id);

-- Closing a parent is automatic: a node that has fed something is spent.
create or replace function close_parent_on_lineage()
returns trigger
language plpgsql
as $$
begin
  update node
     set status = 'closed',
         closed_at = coalesce(closed_at, now())
   where id = new.parent_id
     and status <> 'closed';
  return new;
end;
$$;

create trigger lineage_closes_parent
  after insert on lineage
  for each row execute function close_parent_on_lineage();

-- ---------------------------------------------------------------------------
-- Placements: which lot is in which vessel, when
-- ---------------------------------------------------------------------------

create table placement (
  id          uuid primary key default gen_random_uuid(),
  node_id     uuid not null references node(id) on delete restrict,
  vessel_id   uuid not null references vessel(id) on delete restrict,
  volume_l    numeric(10,2),
  from_at     timestamptz not null default now(),
  to_at       timestamptz,
  created_at  timestamptz not null default now()
);

-- One lot may hold many placements at once: Pinot Gris in a tank and eight barrels.
-- A vessel may hold only one lot at a time.
create unique index placement_one_lot_per_vessel
  on placement(vessel_id) where to_at is null;

create index placement_node_idx on placement(node_id) where to_at is null;

-- ---------------------------------------------------------------------------
-- Events: one table for everything that happens
-- ---------------------------------------------------------------------------

create table event (
  id            uuid primary key default gen_random_uuid(),
  type          event_type not null,
  subject_type  subject_type not null,
  subject_id    uuid not null,
  at            timestamptz not null default now(),
  by_user       uuid references app_user(id),
  by_sensor     text,   -- set instead of by_user for automated readings

  -- brix, ph, ta, temp_c, volume_l, material, dose, source_node_id
  data          jsonb not null default '{}'::jsonb,

  provenance    provenance not null default 'observed',
  task_id       uuid,
  created_at    timestamptz not null default now(),

  constraint has_an_author
    check (by_user is not null or by_sensor is not null)
);

-- Subject polymorphism is deliberate: a room thermometer, a vessel setpoint change,
-- a lot Brix reading and a pre-harvest block sample all share this table.
-- Not a foreign key, so validate on write in the client and periodically here.
create index event_subject_idx on event(subject_type, subject_id, at desc);
create index event_type_at_idx on event(type, at desc);
create index event_provenance_idx on event(provenance) where provenance = 'inferred';

-- ---------------------------------------------------------------------------
-- Templates: generators only
-- ---------------------------------------------------------------------------

create table template (
  id          uuid primary key default gen_random_uuid(),
  variety     text not null,
  name        text not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (variety, name)
);

create table template_step (
  id            uuid primary key default gen_random_uuid(),
  template_id   uuid not null references template(id) on delete cascade,
  step_order    int not null,
  type          event_type not null,

  -- interval from the previous step, or from stage entry
  offset_from   text not null default 'previous',
  offset_interval interval,

  default_data  jsonb not null default '{}'::jsonb,
  required      boolean not null default true,
  unique (template_id, step_order)
);

-- ---------------------------------------------------------------------------
-- Tasks
-- ---------------------------------------------------------------------------

create table task (
  id            uuid primary key default gen_random_uuid(),
  type          event_type not null,
  subject_type  subject_type not null,
  subject_id    uuid not null,

  due_from      timestamptz,
  due_to        timestamptz,

  assignee      uuid references app_user(id),
  claimed_at    timestamptz,
  claimed_by    uuid references app_user(id),

  status        task_status not null default 'open',
  instructions  text,
  recurrence    jsonb,
  created_from  uuid references template_step(id),
  created_at    timestamptz not null default now(),
  created_by    uuid references app_user(id)
);

create index task_board_idx on task(status, due_to)
  where status in ('open', 'claimed');
create index task_subject_idx on task(subject_type, subject_id);

-- Claiming must be atomic. Never read-then-write from the client.
create or replace function claim_task(p_task_id uuid)
returns task
language plpgsql
security definer
set search_path = public
as $$
declare
  claimed task;
begin
  update task
     set status = 'claimed',
         claimed_by = auth.uid(),
         claimed_at = now()
   where id = p_task_id
     and status = 'open'
     and claimed_by is null
  returning * into claimed;

  if claimed.id is null then
    raise exception 'task % is not available', p_task_id
      using errcode = 'lock_not_available';
  end if;

  return claimed;
end;
$$;

-- Releasing is recorded, not silent: a task claimed at 8am and released at 4pm
-- is different from one nobody touched.
create table task_claim_log (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid not null references task(id) on delete cascade,
  user_id     uuid not null references app_user(id),
  claimed_at  timestamptz not null,
  released_at timestamptz
);
