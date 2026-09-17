-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The three things anybody does to the machine registry, as
--           capabilities, so a screen is written against the contract rather
--           than against three tables."
-- Depends on: [supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0105_a_machine_is_a_departure_from_its_model.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: AR-Q8 (the interface is periphery over a read and write
--                  contract), T0-5 (work is appended, never edited)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- `0105` made the objects. This makes the acts, because a screen writing rows
-- into three tables is a screen holding rules about which combinations are
-- allowed, and the next screen would hold them differently.
--
-- Three acts, which is all a shop does: say what a model is, say you have one,
-- and say what you did to it. Everything else is reading.
--
-- **A machine that is also a vessel is claimed, not created.** The press exists.
-- `register_machine` takes the vessel it already is, and refuses to take one
-- another machine has already claimed, because a press with two histories is
-- worse than a press with none.

begin;

-- ---------------------------------------------------------------------------
-- What a model is
-- ---------------------------------------------------------------------------

create or replace function register_machine_model(
  p_make  text,
  p_model text,
  p_kind  text default null,
  p_spec  jsonb default '{}'::jsonb,
  p_note  text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  mk   text := nullif(btrim(coalesce(p_make, '')), '');
  md   text := nullif(btrim(coalesce(p_model, '')), '');
  -- Not `kind`. `term.kind` is a column in the query below and plpgsql resolves
  -- the variable first, so `where kind = 'machine_kind'` compares the variable
  -- with itself and raises. 0086 is the same bug with `type_id`, which means
  -- this repository has now written it twice.
  want_kind uuid;
  one  uuid;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here registers a machine model'
      using errcode = 'insufficient_privilege';
  end if;

  if mk is null or md is null then
    raise exception 'a model is a make and a model, and this gives %',
      coalesce(nullif(concat_ws(' and ', mk, md), ''), 'neither');
  end if;

  if p_kind is not null then
    select t.id into want_kind from term t
     where t.kind = 'machine_kind' and t.value = lower(btrim(p_kind)) and t.active;
    if want_kind is null then
      raise exception '% is not a kind of machine this winery knows about', p_kind;
    end if;
  end if;

  if exists (select 1 from machine_model
              where active and lower(make) = lower(mk) and lower(model) = lower(md)) then
    raise exception 'there is already a % % registered', mk, md;
  end if;

  insert into machine_model (make, model, kind_id, spec, note, created_by)
  values (mk, md, want_kind, coalesce(p_spec, '{}'::jsonb),
          nullif(btrim(coalesce(p_note, '')), ''), auth.uid())
  returning id into one;

  return jsonb_build_object('id', one, 'make', mk, 'model', md);
end;
$$;

revoke all on function register_machine_model(text, text, text, jsonb, text) from public;
grant execute on function register_machine_model(text, text, text, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------------
-- That you have one
-- ---------------------------------------------------------------------------

create or replace function register_machine(
  p_name        text,
  p_model_id    uuid default null,
  p_serial      text default null,
  p_vessel_id   uuid default null,
  p_location_id uuid default null,
  p_acquired_at date default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  nm    text := nullif(btrim(coalesce(p_name, '')), '');
  taken text;
  one   uuid;
  place uuid := p_location_id;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here registers a machine'
      using errcode = 'insufficient_privilege';
  end if;

  if nm is null then
    raise exception 'a machine needs something to be called';
  end if;

  if p_model_id is not null
     and not exists (select 1 from machine_model where id = p_model_id) then
    raise exception 'no machine model with id %', p_model_id;
  end if;

  if p_vessel_id is not null then
    if not exists (select 1 from vessel where id = p_vessel_id and active) then
      raise exception 'that vessel is not one a machine can be';
    end if;
    -- A press with two histories is worse than a press with none.
    select m.name into taken from machine m where m.vessel_id = p_vessel_id;
    if taken is not null then
      raise exception 'that vessel is already registered as the machine %', taken;
    end if;
    -- Where the vessel stands, unless somebody says otherwise. It is the same
    -- object, so two answers about where it is would be one of them wrong.
    if place is null then
      select location_id into place from vessel where id = p_vessel_id;
    end if;
  end if;

  insert into machine (name, model_id, serial, vessel_id, location_id, acquired_at, created_by)
  values (nm, p_model_id, nullif(btrim(coalesce(p_serial, '')), ''),
          p_vessel_id, place, p_acquired_at, auth.uid())
  returning id into one;

  return jsonb_build_object('id', one, 'name', nm, 'is_a_vessel', p_vessel_id is not null);
end;
$$;

revoke all on function register_machine(text, uuid, text, uuid, uuid, date) from public;
grant execute on function register_machine(text, uuid, text, uuid, uuid, date) to authenticated;

-- ---------------------------------------------------------------------------
-- What you did to it
-- ---------------------------------------------------------------------------

create or replace function record_machine_work(
  p_machine_id  uuid,
  p_kind        text,
  p_body        text,
  p_at          date  default null,
  p_spec_change jsonb default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  k       uuid;
  changes boolean;
  said    text := nullif(btrim(coalesce(p_body, '')), '');
  when_   date := coalesce(p_at, current_date);
  one     uuid;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here records work on a machine'
      using errcode = 'insufficient_privilege';
  end if;

  if not exists (select 1 from machine where id = p_machine_id) then
    raise exception 'no machine with id %', p_machine_id;
  end if;

  if said is null then
    raise exception 'there is nothing here to say';
  end if;

  select t.id, coalesce((t.attributes ->> 'changes_spec')::boolean, false)
    into k, changes
    from term t
   where t.kind = 'machine_work_kind' and t.value = lower(btrim(coalesce(p_kind, '')))
     and t.active;
  if k is null then
    raise exception '% is not a kind of work this winery records', p_kind;
  end if;

  -- **A departure has to be the kind that departs.** A service that claims to
  -- change what the machine is would be silently ignored by machine_spec, which
  -- is a write that reads as success and changes nothing. A13.
  if p_spec_change is not null and p_spec_change <> '{}'::jsonb and not changes then
    raise exception
      'a % does not change what the machine is, so it cannot carry a change to its specification. Record it as a modification if it does.',
      lower(btrim(p_kind));
  end if;

  -- Work in the future is a plan, and this records what happened. S-91 says why
  -- there is nowhere to put a plan yet.
  if when_ > current_date then
    raise exception 'that date has not happened yet, so it is not work that was done';
  end if;

  insert into machine_work (machine_id, kind_id, at, body, spec_change, by_user)
  values (p_machine_id, k, when_, said,
          nullif(coalesce(p_spec_change, '{}'::jsonb), '{}'::jsonb), auth.uid())
  returning id into one;

  return jsonb_build_object(
    'id', one, 'at', when_, 'kind', lower(btrim(p_kind)),
    'changed_it', changes and p_spec_change is not null,
    'spec_now', machine_spec(p_machine_id));
end;
$$;

revoke all on function record_machine_work(uuid, text, text, date, jsonb) from public;
grant execute on function record_machine_work(uuid, text, text, date, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- What a screen is written against
-- ---------------------------------------------------------------------------

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('shop.machines', 'shop', 'Machines',
   'Every machine, what it is now, and what it is also. The press is here and so is the tractor.',
   'machine_detail', 'id', 'name', 300),
  ('shop.machine_history', 'shop', 'What was done',
   'Every modification, repair, service, diagnosis and quirk, newest first.',
   'machine_history', 'machine_id', 'machine', 310)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('shop.register_machine_model', 'shop', 'Register a machine model',
   'What one of these is as the manufacturer ships it. The specification here is '
   'what every departure is measured against.',
   'register_machine_model', 'shop.machines',
   '[{"key":"make","param":"p_make","type":"text","required":true,"label":"Make"},
     {"key":"model","param":"p_model","type":"text","required":true,"label":"Model"},
     {"key":"kind","param":"p_kind","type":"text","required":false,
      "label":"Kind of machine","note":"press, tractor, implement, sorting, pump, chiller, other."},
     {"key":"spec","param":"p_spec","type":"jsonb","required":false,
      "label":"Stock specification",
      "note":"Power, capacity, fittings. Whatever you would want when designing around it."},
     {"key":"note","param":"p_note","type":"text","required":false,"label":"Note"}]'::jsonb, 300),

  ('shop.register_machine', 'shop', 'Register a machine',
   'One actual machine. If it is already a vessel in this app, say which, and it '
   'stays one object.',
   'register_machine', 'shop.machines',
   '[{"key":"name","param":"p_name","type":"text","required":true,"label":"Called"},
     {"key":"model","param":"p_model_id","type":"uuid","required":false,
      "label":"Which model","source":{"readable":"shop.machines"}},
     {"key":"serial","param":"p_serial","type":"text","required":false,"label":"Serial number"},
     {"key":"vessel","param":"p_vessel_id","type":"uuid","required":false,
      "label":"It is also this vessel","source":{"readable":"cellar.vessels"}},
     {"key":"where","param":"p_location_id","type":"uuid","required":false,
      "label":"Where it lives","source":{"readable":"cellar.rooms"}},
     {"key":"acquired","param":"p_acquired_at","type":"date","required":false,
      "label":"When you got it"}]'::jsonb, 301),

  ('shop.record_machine_work', 'shop', 'Record work on a machine',
   'What was done and when it was done, which is not the same as when you typed '
   'it. A modification may also say what it changed.',
   'record_machine_work', 'shop.machines',
   '[{"key":"machine","param":"p_machine_id","type":"uuid","required":true,
      "label":"Which machine","source":{"readable":"shop.machines"}},
     {"key":"kind","param":"p_kind","type":"text","required":true,
      "label":"Kind of work",
      "note":"modification, repair, service, diagnosis, inspection, quirk."},
     {"key":"body","param":"p_body","type":"text","required":true,"label":"What was done"},
     {"key":"when","param":"p_at","type":"date","required":false,
      "label":"When","note":"Today unless you say otherwise. Past dates are the point."},
     {"key":"change","param":"p_spec_change","type":"jsonb","required":false,
      "label":"What it changed",
      "note":"Only for a modification. {\"power\": \"three phase via VFD\"} and the like."}]'::jsonb, 302)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

-- Not a capability. It answers what a machine is now, which arrives on every
-- machine_detail row; a periphery calling it directly would be a screen doing
-- the view's job.
insert into capability_exemption (fn, reason) values
  ('machine_spec', 'Answers what a machine is now, from its model and its modifications. Arrives on every machine_detail row.')
on conflict (fn) do nothing;

commit;
