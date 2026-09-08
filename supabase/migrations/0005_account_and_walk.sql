-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Adds what the inventory walk needs from the kernel: account claim
--           with the first account as admin, location kind, enforcement of
--           T0-4 at the write path, inferred history generation, and the one
--           action that creates a vessel with wine in it."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0003_parties_and_products.sql,
--              supabase/migrations/0004_terms_and_effects.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md]
-- Axioms enforced: T0-3 (provenance on every event), T0-4 (a producer cannot
--                  grant itself standing), T0-5 (append-only history),
--                  T1-1 (pickers, not text fields)
-- Open sorries: S-7 (RLS untested), S-17 (no template is seeded, so inferred
--               history generates nothing yet)
-- ---------------------------------------------------------------------------

-- Everything here exists because a screen needed it and a hard rule said the
-- screen could not hold it. "The first account becomes admin" is a business
-- rule; "creating a vessel with wine in it is one action" is an atomicity
-- guarantee; "a producer may not write confirmed" is an axiom. None of the
-- three survives being implemented in a client.

-- ---------------------------------------------------------------------------
-- Claiming an account
-- ---------------------------------------------------------------------------

-- Without this the first user cannot exist. app_user is admin-write, is_admin()
-- reads app_user, and a brand new account has no row there, so the very first
-- sign-up is locked out of creating the row that would let it in. Security
-- definer breaks that circle, and the function is the only way through it.
--
-- Idempotent: calling it again returns the existing row. A user who reloads the
-- sign-up screen is not a new user.
create or replace function claim_account(p_name text)
returns app_user
language plpgsql
security definer
set search_path = public
as $$
declare
  u         app_user;
  is_first  boolean;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = 'insufficient_privilege';
  end if;

  select * into u from app_user where id = auth.uid();
  if found then
    return u;
  end if;

  -- Two people signing up in the same second would both read an empty table and
  -- both become admin. The window is small and the consequence is a second
  -- unintended admin, so it is cheaper to close it than to explain it.
  perform pg_advisory_xact_lock(hashtext('claim_account'));

  select count(*) = 0 into is_first from app_user;

  insert into app_user (id, name, role)
  values (auth.uid(), p_name,
          case when is_first then 'admin'::user_role else 'cellar'::user_role end)
  returning * into u;

  return u;
end;
$$;

-- ---------------------------------------------------------------------------
-- Location kind, and template variety, as terms
-- ---------------------------------------------------------------------------

-- Barrel room, crush pad, cold room. Nullable because a fresh install has no
-- location kinds at all and the walk adds them inline as it goes; requiring one
-- would make the first location impossible to create.
alter table location
  add column kind_id   uuid,
  add column kind_kind term_kind generated always as ('location_kind'::term_kind) stored,
  add constraint location_kind_is_a_location_kind
    foreign key (kind_id, kind_kind) references term(id, kind);

-- template.variety was left as text by 0004. Matching a template to a lot meant
-- comparing that text to a term's value, where a typo produces no template and
-- no error. The join belongs on an id.
alter table template
  add column variety_id   uuid,
  add column variety_kind term_kind generated always as ('variety'::term_kind) stored,
  add constraint template_variety_is_a_variety
    foreign key (variety_id, variety_kind) references term(id, kind);

alter table template drop column variety;
alter table template add constraint template_variety_name_key unique (variety_id, name);

-- ---------------------------------------------------------------------------
-- T0-4 at the write path
-- ---------------------------------------------------------------------------

-- The axiom says a producer cannot grant itself standing. Avoiding the field in
-- the client satisfies the axiom only for as long as every client remembers to,
-- which is a discipline rather than a boundary. This is the boundary: nothing
-- may be born confirmed, whoever is writing and whatever they send.
create or replace function refuse_self_granted_standing()
returns trigger
language plpgsql
as $$
begin
  if new.provenance = 'confirmed' then
    raise exception
      'provenance "confirmed" is written by a verifier, never at insert (T0-4)'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

create trigger node_no_self_confirm
  before insert on node
  for each row execute function refuse_self_granted_standing();

create trigger event_no_self_confirm
  before insert on event
  for each row execute function refuse_self_granted_standing();

-- The verifier side of the same axiom. Confirmation is a separate act by
-- somebody else, which is the whole content of T0-4, and it moves inferred to
-- confirmed and nothing else: an observed event was already witnessed and has
-- no confirmation to gain.
create or replace function confirm_event(p_event_id uuid)
returns event
language plpgsql
security definer
set search_path = public
as $$
declare
  e event;
begin
  if not is_admin() then
    raise exception 'only a verifier may confirm' using errcode = 'insufficient_privilege';
  end if;

  update event
     set provenance = 'confirmed'
   where id = p_event_id and provenance = 'inferred'
  returning * into e;

  if e.id is null then
    raise exception 'event % is not an inferred event awaiting confirmation', p_event_id;
  end if;

  return e;
end;
$$;

-- ---------------------------------------------------------------------------
-- Inferred history
-- ---------------------------------------------------------------------------

-- Templates run backward: a barrel of 2024 Chardonnay entering at maturation
-- gets the history it would have had, stamped inferred so that nothing
-- downstream mistakes it for a record. It writes 'inferred' and it could not
-- write 'confirmed' if it tried, per the trigger above.
--
-- Returns the number of events written. Zero is a normal answer and means no
-- active template matches the variety, which is currently every variety. See
-- sorry S-17.
create or replace function generate_inferred_history(
  p_node_id uuid,
  p_from    timestamptz default now()
)
returns integer
language plpgsql
as $$
declare
  n        node;
  tmpl     uuid;
  step     record;
  at_time  timestamptz;
  written  int := 0;
begin
  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no such node %', p_node_id;
  end if;
  if n.variety_id is null then
    return 0;
  end if;

  select t.id into tmpl
    from template t
   where t.active and t.variety_id = n.variety_id
   order by t.created_at
   limit 1;

  if tmpl is null then
    return 0;
  end if;

  at_time := p_from;

  for step in
    select * from template_step where template_id = tmpl order by step_order
  loop
    at_time := at_time + coalesce(step.offset_interval, interval '0');

    insert into event
      (operation_id, subject_type, subject_id, at, by_user, data, provenance)
    values
      (step.operation_id, 'node', p_node_id, at_time, auth.uid(),
       step.default_data, 'inferred');

    written := written + 1;
  end loop;

  return written;
end;
$$;

-- ---------------------------------------------------------------------------
-- Vessel plus wine, one action
-- ---------------------------------------------------------------------------

-- Three inserts and a code binding, from a phone, in a barrel room. Split
-- across four REST calls this half-succeeds and leaves a vessel with no wine or
-- a lot with no home, and the person holding the phone has no way to tell which.
-- One function is one transaction.
--
-- Security invoker on purpose: this composes ordinary writes and every table's
-- own policy still decides. It grants nothing.
create or replace function create_vessel_with_wine(
  p_vessel           jsonb,
  p_node             jsonb,
  p_volume_l         numeric default null,
  p_codes            jsonb default '[]'::jsonb,
  p_generate_history boolean default true
)
returns jsonb
language plpgsql
as $$
declare
  v_id        uuid := coalesce((p_vessel ->> 'id')::uuid, gen_random_uuid());
  n_id        uuid := coalesce((p_node   ->> 'id')::uuid, gen_random_uuid());
  p_id        uuid := gen_random_uuid();
  code        jsonb;
  generated   int := 0;
begin
  insert into vessel
    (id, type_id, name, capacity_l, location_id, owner_id, attributes)
  values
    (v_id,
     (p_vessel ->> 'type_id')::uuid,
      p_vessel ->> 'name',
     (p_vessel ->> 'capacity_l')::numeric,
     (p_vessel ->> 'location_id')::uuid,
     (p_vessel ->> 'owner_id')::uuid,
      coalesce(p_vessel -> 'attributes', '{}'::jsonb));

  insert into node
    (id, stage, status, name, variety_id, vintage, product_type_id,
     quantity, unit, attributes, owner_id, created_by)
  values
    (n_id,
     coalesce((p_node ->> 'stage')::node_stage, 'maturation'),
     'open',
      p_node ->> 'name',
     (p_node ->> 'variety_id')::uuid,
     (p_node ->> 'vintage')::int,
      coalesce((p_node ->> 'product_type_id')::uuid, term_id('product_type', 'wine')),
     (p_node ->> 'quantity')::numeric,
      coalesce((p_node ->> 'unit')::quantity_unit, 'L'),
      coalesce(p_node -> 'attributes', '{}'::jsonb),
      coalesce((p_node ->> 'owner_id')::uuid, facility_party_id()),
      auth.uid());

  insert into placement (id, node_id, vessel_id, volume_l)
  values (p_id, n_id, v_id, p_volume_l);

  for code in select * from jsonb_array_elements(p_codes)
  loop
    perform bind_vessel_code(v_id, code ->> 'code', code ->> 'label');
  end loop;

  if p_generate_history then
    generated := generate_inferred_history(n_id);
  end if;

  return jsonb_build_object(
    'vessel_id',        v_id,
    'node_id',          n_id,
    'placement_id',     p_id,
    'events_generated', generated
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Storage for vessel photos
-- ---------------------------------------------------------------------------

-- Guarded because the storage schema is part of the Supabase stack rather than
-- of Postgres, and these migrations have to stay applicable to a bare database
-- for anyone verifying them without Docker. The guard is the honest form of
-- that dependency: outside Supabase this block does nothing and says so by
-- doing nothing, rather than failing halfway through the migration.
do $$
begin
  if not exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    raise notice 'storage schema absent, skipping the vessel-photos bucket';
    return;
  end if;

  -- Private. A photo of a barrel shows a chalk mark with a client's lot on it.
  insert into storage.buckets (id, name, public)
  values ('vessel-photos', 'vessel-photos', false)
  on conflict (id) do nothing;

  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'vessel_photos_read'
  ) then
    execute $p$
      create policy vessel_photos_read on storage.objects
        for select to authenticated using (bucket_id = 'vessel-photos')
    $p$;
  end if;

  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'vessel_photos_insert'
  ) then
    execute $p$
      create policy vessel_photos_insert on storage.objects
        for insert to authenticated with check (bucket_id = 'vessel-photos')
    $p$;
  end if;
end $$;
