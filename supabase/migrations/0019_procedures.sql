-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Procedures with timed steps, run against a vessel. Barrel steaming
--           is the worked case: an initial rinse, the steam, bung suction, a
--           final rinse, then solution, with an admin setting how long each
--           should take and a cellar hand recording how long each did take."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0004_terms_and_effects.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (a duration is the difference between two timestamps
--                  and is never stored), T0-3 (provenance on every event),
--                  T1-1 (pickers, not text fields)
-- Open sorries: S-28 (a procedure is written here and the winery's SOPs live
--               in a folder of documents; nothing reconciles the two)
-- ---------------------------------------------------------------------------

-- Why this is not a template.
--
-- `template` is keyed by variety and its steps carry `offset_interval`, which
-- answers "when is the next step due" over days. That is a schedule for a lot.
-- Steaming a barrel is a stopwatch: four steps in one sitting, each with a
-- target measured in minutes, against a vessel that has no wine in it at all.
-- Squeezing one into the other would make offset_interval mean two things.
--
-- The subject is a vessel here and the column says so rather than assuming,
-- because the six variety protocols are procedures too and will want this
-- shape once S-17 is answered. That is one column reusing an enum that already
-- exists, not an abstraction layer.

create table procedure (
  id            uuid primary key default gen_random_uuid(),
  name          text not null unique,
  subject_type  subject_type not null default 'vessel',
  -- The written SOP, kept beside the steps so the person doing it at 6am can
  -- read what they are supposed to be doing. See S-28: this is a copy, and
  -- nothing reconciles it with the document it was copied from.
  sop_text      text,
  sop_source    text,
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);

-- Fixed tier, because each kind drives a different control on the screen and
-- the kernel has to understand which. A facility inventing a fifth would be
-- inventing a widget nothing knows how to draw.
create table procedure_step (
  id             uuid primary key default gen_random_uuid(),
  procedure_id   uuid not null references procedure(id) on delete cascade,
  step_order     int not null,
  label          text not null,
  kind           text not null check (kind in ('timer', 'solution', 'check', 'note')),

  -- What it should take, set by an admin. What it did take is the difference
  -- between two timestamps on the run, and is never written down.
  target_seconds int check (target_seconds is null or target_seconds > 0),

  -- For a solution step: what goes in, by default. material_kind already
  -- exists as a vocabulary, so citric, caustic and peracetic are rows rather
  -- than a new enum.
  material_id    uuid references term(id),
  material_kind  term_kind generated always as ('material_kind'::term_kind) stored,

  instructions   text,
  required       boolean not null default true,

  unique (procedure_id, step_order),
  constraint step_material_is_a_material
    foreign key (material_id, material_kind) references term(id, kind),
  constraint timer_needs_a_target
    check (kind <> 'timer' or target_seconds is not null)
);

-- One sitting. The barrels done together, in the order they were done, so a
-- run can be compared with the one before it on the same barrel.
create table procedure_session (
  id            uuid primary key default gen_random_uuid(),
  procedure_id  uuid not null references procedure(id),
  started_at    timestamptz not null default now(),
  finished_at   timestamptz,
  started_by    uuid references app_user(id),
  note          text
);

create table procedure_run (
  id           uuid primary key default gen_random_uuid(),
  session_id   uuid not null references procedure_session(id) on delete cascade,
  vessel_id    uuid not null references vessel(id),
  position     int not null,
  started_at   timestamptz,
  finished_at  timestamptz,
  unique (session_id, vessel_id),
  unique (session_id, position)
);

create table procedure_run_step (
  id          uuid primary key default gen_random_uuid(),
  run_id      uuid not null references procedure_run(id) on delete cascade,
  step_id     uuid not null references procedure_step(id),
  started_at  timestamptz,
  ended_at    timestamptz,
  -- For a solution step: what actually went in, and how much.
  data        jsonb not null default '{}'::jsonb,
  note        text,
  unique (run_id, step_id),
  constraint ends_after_it_starts
    check (ended_at is null or started_at is null or ended_at >= started_at)
);

create index procedure_run_session_idx on procedure_run(session_id);
create index procedure_run_step_run_idx on procedure_run_step(run_id);

-- ---------------------------------------------------------------------------
-- How long it took, which is not a column
-- ---------------------------------------------------------------------------

-- T0-2. The duration is the difference between two timestamps. Storing it as
-- well would be a second source of truth that disagrees the first time anybody
-- corrects a start time.
create or replace view procedure_run_state as
  select
    rs.id,
    rs.run_id,
    r.session_id,
    r.vessel_id,
    v.name                          as vessel_name,
    r.position,
    s.id                            as step_id,
    s.step_order,
    s.label,
    s.kind,
    s.target_seconds,
    s.instructions,
    s.required,
    rs.started_at,
    rs.ended_at,
    case when rs.started_at is not null and rs.ended_at is not null
         then extract(epoch from (rs.ended_at - rs.started_at))::int
    end                             as actual_seconds,
    case when rs.started_at is not null and rs.ended_at is not null
              and s.target_seconds is not null
         then extract(epoch from (rs.ended_at - rs.started_at))::int - s.target_seconds
    end                             as over_by_seconds,
    rs.data,
    rs.note,
    m.label                         as material_label
  from procedure_run_step rs
  join procedure_run r on r.id = rs.run_id
  join procedure_step s on s.id = rs.step_id
  join vessel v on v.id = r.vessel_id
  left join term m on m.id = s.material_id;

alter view procedure_run_state set (security_invoker = true);

-- ---------------------------------------------------------------------------
-- Running one
-- ---------------------------------------------------------------------------

-- Starting a session lays out one run per barrel in the order given, so the
-- order is recorded rather than remembered.
create or replace function start_procedure_session(
  p_procedure_id uuid,
  p_vessel_ids   uuid[]
)
returns uuid
language plpgsql
as $$
declare
  sess uuid := gen_random_uuid();
  i    int;
begin
  if coalesce(array_length(p_vessel_ids, 1), 0) = 0 then
    raise exception 'a session needs at least one vessel';
  end if;

  insert into procedure_session (id, procedure_id, started_by)
  values (sess, p_procedure_id, auth.uid());

  for i in 1 .. array_length(p_vessel_ids, 1)
  loop
    insert into procedure_run (session_id, vessel_id, position)
    values (sess, p_vessel_ids[i], i);
  end loop;

  return sess;
end;
$$;

-- Start and finish are separate calls because the gap between them is the
-- measurement. A single call taking a duration would be somebody typing in
-- what they think four minutes felt like.
create or replace function begin_run_step(p_run_id uuid, p_step_id uuid)
returns uuid
language plpgsql
as $$
declare rs uuid;
begin
  insert into procedure_run_step (run_id, step_id, started_at)
  values (p_run_id, p_step_id, now())
  on conflict (run_id, step_id)
    do update set started_at = coalesce(procedure_run_step.started_at, now())
  returning id into rs;

  update procedure_run set started_at = coalesce(started_at, now())
   where id = p_run_id;

  return rs;
end;
$$;

create or replace function end_run_step(
  p_run_id  uuid,
  p_step_id uuid,
  p_data    jsonb default '{}'::jsonb,
  p_note    text  default null
)
returns int
language plpgsql
as $$
declare secs int;
begin
  update procedure_run_step
     set ended_at = now(),
         data     = coalesce(p_data, '{}'::jsonb),
         note     = p_note
   where run_id = p_run_id and step_id = p_step_id
   returning extract(epoch from (ended_at - started_at))::int into secs;

  if not found then
    raise exception 'that step was never started, so there is nothing to time';
  end if;
  return secs;
end;
$$;

-- Finishing a barrel writes one event against the vessel, so the steaming
-- shows up in that barrel's own history rather than only inside this session.
create or replace function finish_run(p_run_id uuid)
returns uuid
language plpgsql
as $$
declare
  ev   uuid := gen_random_uuid();
  v_id uuid;
  p_id uuid;
  nm   text;
begin
  update procedure_run set finished_at = now() where id = p_run_id
  returning vessel_id into v_id;
  if v_id is null then raise exception 'no such run'; end if;

  select p.id, p.name into p_id, nm
    from procedure_run r
    join procedure_session s on s.id = r.session_id
    join procedure p on p.id = s.procedure_id
   where r.id = p_run_id;

  insert into event (id, operation_id, subject_type, subject_id, by_user,
                     data, provenance)
  values (ev, term_id('operation', 'procedure_run'), 'vessel', v_id, auth.uid(),
          jsonb_build_object('procedure', nm, 'run_id', p_run_id),
          'observed');
  return ev;
end;
$$;

-- ---------------------------------------------------------------------------
-- What people write down about a barrel
-- ---------------------------------------------------------------------------

-- Leaking, fixed a leak, tightened the rings, off smell. These are facts about
-- the barrel and not about this morning, so they are events on the vessel and
-- they outlive the session that noticed them.
--
-- Operations already carry an effect. These carry a subject as well, the same
-- partition trick 0009 used for makers, so a wine screen does not offer to
-- tighten the rings on a lot.
insert into term (kind, value, label, sort_order, attributes) values
  ('operation','procedure_run','Procedure run', 500,
   '{"effect":"measurement","subject":"vessel"}'),
  ('operation','leak_found',  'Leaking',        510,
   '{"effect":"measurement","subject":"vessel"}'),
  ('operation','leak_fixed',  'Leak fixed',     520,
   '{"effect":"measurement","subject":"vessel"}'),
  ('operation','rings_tightened','Rings tightened', 530,
   '{"effect":"measurement","subject":"vessel"}'),
  ('operation','off_smell',   'Off smell',      540,
   '{"effect":"measurement","subject":"vessel"}'),
  ('operation','vessel_note', 'Note',           550,
   '{"effect":"measurement","subject":"vessel"}');

create or replace function record_vessel_note(
  p_vessel_id uuid,
  p_operation text,
  p_note      text default null,
  p_data      jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
as $$
declare
  ev uuid := gen_random_uuid();
  op uuid := term_id('operation', p_operation);
begin
  if op is null then
    raise exception 'there is no operation called %', p_operation;
  end if;

  insert into event (id, operation_id, subject_type, subject_id, by_user,
                     data, provenance)
  values (ev, op, 'vessel', p_vessel_id, auth.uid(),
          coalesce(p_data, '{}'::jsonb) || jsonb_build_object('note', p_note),
          'observed');
  return ev;
end;
$$;

-- A barrel's own history. node_history walks lineage; a vessel has none, so
-- this is the flat list, and it is the thing that tells you this barrel has
-- leaked three times.
create or replace function vessel_history(p_vessel_id uuid)
returns table (
  event_id   uuid,
  at         timestamptz,
  operation  text,
  label      text,
  provenance provenance,
  data       jsonb,
  by_name    text
)
language sql
stable
as $$
  select e.id, e.at, t.value, t.label, e.provenance, e.data, u.name
    from event e
    join term t on t.id = e.operation_id
    left join app_user u on u.id = e.by_user
   where e.subject_type = 'vessel' and e.subject_id = p_vessel_id
   order by e.at desc;
$$;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table procedure enable row level security;
alter table procedure_step enable row level security;
alter table procedure_session enable row level security;
alter table procedure_run enable row level security;
alter table procedure_run_step enable row level security;

-- An admin writes the procedure and sets the targets. A cellar hand runs it.
create policy procedure_read on procedure
  for select to authenticated using (is_facility_user());
create policy procedure_admin_write on procedure
  for all to authenticated using (is_admin()) with check (is_admin());

create policy procedure_step_read on procedure_step
  for select to authenticated using (is_facility_user());
create policy procedure_step_admin_write on procedure_step
  for all to authenticated using (is_admin()) with check (is_admin());

create policy procedure_session_read on procedure_session
  for select to authenticated using (is_facility_user());
create policy procedure_session_write on procedure_session
  for all to authenticated using (is_facility_user()) with check (is_facility_user());

create policy procedure_run_read on procedure_run
  for select to authenticated using (is_facility_user());
create policy procedure_run_write on procedure_run
  for all to authenticated using (is_facility_user()) with check (is_facility_user());

create policy procedure_run_step_read on procedure_run_step
  for select to authenticated using (is_facility_user());
create policy procedure_run_step_write on procedure_run_step
  for all to authenticated using (is_facility_user()) with check (is_facility_user());

-- ---------------------------------------------------------------------------
-- The barrel steaming procedure itself
-- ---------------------------------------------------------------------------

-- Targets are a starting point, not a claim. An admin changes them from the
-- screen the first time the cellar disagrees with them.
insert into procedure (id, name, subject_type, sop_text)
values ('00000000-0000-0000-0000-0000000000b1', 'Barrel steaming', 'vessel',
        'Rinse, steam, draw the bung, rinse again, then solution. Targets are '
        'the winery''s starting numbers and an admin can change them.');

insert into procedure_step
  (procedure_id, step_order, label, kind, target_seconds, instructions)
values
  ('00000000-0000-0000-0000-0000000000b1', 10, 'Initial rinse', 'timer', 120,
   'Cold water until it runs clear.'),
  ('00000000-0000-0000-0000-0000000000b1', 20, 'Steam',         'timer', 300,
   'Steam in through the bung.'),
  ('00000000-0000-0000-0000-0000000000b1', 30, 'Bung suction',  'timer',  60,
   'Leave the bung in and let it draw as it cools.'),
  ('00000000-0000-0000-0000-0000000000b1', 40, 'Final rinse',   'timer', 120,
   'Until the water runs clear and smells of nothing.');

insert into procedure_step
  (procedure_id, step_order, label, kind, instructions)
values
  ('00000000-0000-0000-0000-0000000000b1', 50, 'Solution', 'solution',
   'What went in and how much.');
