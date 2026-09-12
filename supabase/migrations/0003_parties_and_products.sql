-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Adds the party that owns wine, ownership on nodes and vessels,
--           product type, several scan codes per vessel, and the client-scoped
--           read policy that ownership makes possible."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0002_derived_and_rls.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md,
--                 supabase/migrations/0004_terms_and_effects.sql,
--                 supabase/migrations/0005_account_and_walk.sql,
--                 tests/schema_assertions.sql,
--                 supabase/migrations/0018_lot_privacy.sql,
--                 supabase/migrations/0022_admission_and_authorship.sql,
--                 supabase/migrations/0025_bind_an_unbound_code.sql]
-- Axioms enforced: T1-1 (pickers, not text fields), T1-3 (every scan is a
--                  reconciliation opportunity)
-- Open sorries: S-7 (RLS untested, now including the client-party policy
--               written here), S-8 (volume losses), S-9 (unit conversion),
--               S-10 (tax class), S-11 (bond status), S-12 (bottling seam)
-- ---------------------------------------------------------------------------

-- Custom crush is the reason for this migration. Amica Luna and a
-- cider/vermouth producer own wine in this cellar without owning the cellar,
-- which the schema had no way to say. Ownership drives TTB reporting, cost
-- allocation, and what a client is permitted to see.
--
-- What this migration deliberately does not add: tax class, bond status,
-- volume losses, unit conversion, and case goods. Those are sorries S-8
-- through S-12 and every one of them needs the compliance advisor before a
-- column is chosen. Guessing at them would produce a schema that reports
-- confidently wrong numbers to the TTB, which is worse than reporting none.

-- ---------------------------------------------------------------------------
-- party: legal entities that own wine
-- ---------------------------------------------------------------------------

create type party_kind as enum ('facility', 'client');

-- A party is not an app_user. A custom crush client may own six lots and never
-- log in, and a harvest intern logs in and owns nothing. The optional link
-- exists so that a client who does log in sees their own wine and no more.
create table party (
  id           uuid primary key default gen_random_uuid(),
  name         text not null unique,
  kind         party_kind not null,
  app_user_id  uuid references app_user(id) on delete set null,
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);

-- One login resolves to at most one party, because the RLS lookup below has to
-- be single-valued to mean anything.
create unique index party_app_user_idx
  on party(app_user_id) where app_user_id is not null;

-- Exactly one facility, which is what makes node.owner_id's default
-- unambiguous. A second facility is a different problem (a facility-level
-- org_id) and is deferred until one exists. See the spec preamble.
create unique index party_one_facility
  on party(kind) where kind = 'facility' and active;

create or replace function facility_party_id()
returns uuid
language sql
stable
as $$
  select id from party where kind = 'facility' and active;
$$;

-- ---------------------------------------------------------------------------
-- Ownership on nodes and vessels
-- ---------------------------------------------------------------------------

-- Not null, because a lot nobody owns cannot be reported on and the ambiguity
-- would surface at the worst possible moment. The default means the facility
-- case costs nothing at the call site.
--
-- Consequence worth knowing: no node can be inserted until a facility party
-- exists, since the default resolves to null and the column refuses it. The
-- Stage 0 walk creates the parties first. Nothing is seeded here because the
-- winery's own legal names are not this file's to invent.
alter table node
  add column owner_id uuid not null default facility_party_id() references party(id);

create index node_owner_idx on node(owner_id);

-- Nullable, and null means facility-owned. Both cases are real: a client may
-- bring their own barrels and press into our tanks in the same week.
alter table vessel
  add column owner_id uuid references party(id);

create index vessel_owner_idx on vessel(owner_id) where owner_id is not null;

-- ---------------------------------------------------------------------------
-- Product type
-- ---------------------------------------------------------------------------

-- The schema assumes variety and vintage on every node. Neither applies
-- cleanly to cider, and vermouth is a wine that stops being one somewhere in
-- the process. This field is the gate that decides which downstream rules
-- apply. The rules themselves are not written yet and must not be guessed at.
create type product_type as enum ('wine', 'cider', 'vermouth', 'other');

alter table node
  add column product_type product_type not null default 'wine';

create index node_product_type_idx on node(product_type) where product_type <> 'wine';

-- ---------------------------------------------------------------------------
-- vessel_code: several codes per vessel, replacing vessel.qr_code
-- ---------------------------------------------------------------------------

-- A barrel arrives with a cooper's barcode on the head, gets our own sticker
-- on the belly, and whichever one is facing you at 6am is the one you scan.
-- One code per vessel made scanning the wrong sticker on the right barrel an
-- error, which is exactly backwards: it is the right barrel.
create table vessel_code (
  id         uuid primary key default gen_random_uuid(),
  vessel_id  uuid not null references vessel(id) on delete cascade,
  code       text not null unique,
  label      text,
  added_at   timestamptz not null default now(),
  active     boolean not null default true
);

-- Unique across the whole table rather than per vessel, retired codes
-- included. A sticker peeled off barrel 23 and stuck on barrel 40 is the
-- failure this refuses.
create index vessel_code_vessel_idx on vessel_code(vessel_id) where active;

-- vessel_state selects qr_code, so the view goes first and comes back below.
drop view vessel_state;
drop index vessel_qr_idx;
alter table vessel drop column qr_code;

-- Scanning resolves to the vessel and everything currently in it. Rescanning
-- something already bound is not an error: mid-walk people scan things twice
-- and the useful answer is "this is barrel 23, here is what is in it."
create or replace view vessel_state
with (security_invoker = true) as
  select
    v.id,
    v.type,
    v.name,
    v.capacity_l,
    v.owner_id,
    o.name                       as owner_name,
    (v.owner_id is null)         as facility_owned,
    v.has_glycol,
    v.setpoint_c,
    v.mode,
    v.attributes,
    l.name                       as location_name,
    -- effective temperature: a jacketed vessel overrides ambient
    coalesce(
      case when v.has_glycol and v.mode <> 'off' then v.setpoint_c end,
      l.ambient_c
    )                            as effective_temp_c,
    p.node_id,
    n.name                       as lot_name,
    n.variety,
    n.vintage,
    n.product_type,
    n.owner_id                   as lot_owner_id,
    p.volume_l                   as current_volume_l,
    p.from_at                    as filled_at,
    (p.node_id is null)          as is_empty,
    (
      select array_agg(c.code order by c.added_at)
        from vessel_code c
       where c.vessel_id = v.id and c.active
    )                            as codes
  from vessel v
  left join location l on l.id = v.location_id
  left join party o on o.id = v.owner_id
  left join placement p on p.vessel_id = v.id and p.to_at is null
  left join node n on n.id = p.node_id
  where v.active;

-- A view runs as its owner unless told otherwise, which would hand a client
-- every lot in the cellar through lot_state while node's own policy refused it.
-- The policy below is only worth writing if the views respect it.
alter view lot_state set (security_invoker = true);
alter view task_board set (security_invoker = true);

create or replace function resolve_vessel_code(p_code text)
returns setof vessel_state
language sql
stable
as $$
  select vs.*
    from vessel_state vs
    join vessel_code c on c.vessel_id = vs.id
   where c.code = p_code and c.active;
$$;

-- Idempotent by design. Binding a code the vessel already carries returns the
-- existing row; binding a code that belongs to a different vessel raises,
-- because that one is a real mix-up and silence would attach a barrel's
-- history to the wrong wine.
create or replace function bind_vessel_code(
  p_vessel_id uuid,
  p_code      text,
  p_label     text default null,
  p_id        uuid default gen_random_uuid()
)
returns vessel_code
language plpgsql
as $$
declare
  existing vessel_code;
begin
  select * into existing from vessel_code where code = p_code;

  if found then
    if existing.vessel_id = p_vessel_id then
      return existing;
    end if;
    raise exception 'code % is already bound to vessel %', p_code, existing.vessel_id
      using errcode = 'unique_violation';
  end if;

  insert into vessel_code (id, vessel_id, code, label)
  values (p_id, p_vessel_id, p_code, p_label)
  returning * into existing;

  return existing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table party       enable row level security;
alter table vessel_code enable row level security;

create policy party_read on party
  for select to authenticated using (true);

create policy party_admin_write on party
  for all to authenticated
  using (is_admin()) with check (is_admin());

create policy vessel_code_read on vessel_code
  for select to authenticated using (true);

-- Codes are bound during the Stage 0 inventory walk, which is structural work,
-- so this matches vessel itself rather than the event tables.
create policy vessel_code_admin_write on vessel_code
  for all to authenticated
  using (is_admin()) with check (is_admin());

create or replace function current_party_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from party where app_user_id = auth.uid() and active;
$$;

-- Facility user means admin, or a cellar user linked to the facility party, or
-- a cellar user linked to no party at all. The last case is the harvest intern,
-- who owns nothing and needs to see everything.
create or replace function is_facility_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select is_admin() or coalesce(
    (select kind = 'facility' from party where app_user_id = auth.uid() and active),
    true
  );
$$;

-- Replaces the blanket read from 0002. A client sees their own lots and is not
-- told how many others exist.
drop policy node_read on node;

create policy node_read on node
  for select to authenticated
  using (is_facility_user() or owner_id = current_party_id());
