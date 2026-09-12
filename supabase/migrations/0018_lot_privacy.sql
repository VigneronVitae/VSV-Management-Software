-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Lets the owner of a lot decide, field by field, what the cellar
--           crew can see about it. Not whether the wine exists, which they have
--           to know to work on it, but what it is called, whose it is, how it
--           was made and where the fruit came from."
-- Depends on: [supabase/migrations/0003_parties_and_products.sql,
--              supabase/migrations/0015_fork_and_history.sql,
--              supabase/migrations/0017_vessel_state_rls.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql, supabase/migrations/0021_cellar_write_paths.sql]
-- Axioms enforced: T0-1 (the database refuses, rather than the screen omitting),
--                  T0-2 (the edge is computed, never a second copy of the lot)
-- Open sorries: S-27 (a client with no login cannot set privacy on their own
--               wine, because there is nobody to be them)
-- ---------------------------------------------------------------------------

-- Two custom crush clients are on the books, which spec.md's preamble already
-- says makes the second user real rather than hypothetical. At a facility where
-- some of the crew make wine for other people, "the winery can see everything"
-- is a confidentiality problem rather than a fact of life.
--
-- The shape is the winemaker's: hide the details, never the edges. A barrel
-- still visibly holds two hundred and twenty litres of something, because the
-- person racking it has to find it, move it and write down what they did. What
-- they need not learn is whose it is, what it is called, how it was handled and
-- which blocks it came from.
--
-- Two powers, deliberately split. Seeing is not controlling: an admin can read
-- every lot in the cellar, because they are responsible for it and TTB will ask
-- them about it, and an admin cannot change what a client has chosen to hide.
-- The switch belongs to the owner or it is not a choice.

-- ---------------------------------------------------------------------------
-- What may be hidden
-- ---------------------------------------------------------------------------

-- Fixed tier on purpose. The kernel does the redacting, so it has to understand
-- each name; a facility inventing a new one would be inventing a rule nothing
-- enforces. The floor is what is missing from this list: that a vessel holds
-- something, and how much. Neither can be hidden, because the work stops.
create or replace function hideable_fields()
returns text[]
language sql
immutable
as $$
  select array['name', 'owner', 'variety', 'vintage', 'attributes',
               'history', 'composition']::text[];
$$;

alter table node
  add column hidden text[] not null default '{}',
  add constraint node_hidden_known
    check (hidden <@ hideable_fields());

-- The owner's standing preference, copied onto each new lot of theirs so the
-- choice is made once rather than every harvest morning.
alter table party
  add column default_hidden text[] not null default '{}',
  add constraint party_default_hidden_known
    check (default_hidden <@ hideable_fields());

create or replace function apply_owner_privacy()
returns trigger
language plpgsql
as $$
begin
  -- Only when the caller said nothing. An explicit choice, including an
  -- explicit empty one, is the caller's and is left alone.
  if new.hidden = '{}' and new.owner_id is not null then
    select default_hidden into new.hidden from party where id = new.owner_id;
    new.hidden := coalesce(new.hidden, '{}');
  end if;
  return new;
end;
$$;

create trigger node_inherits_owner_privacy
  before insert on node
  for each row execute function apply_owner_privacy();

-- ---------------------------------------------------------------------------
-- Who may change it
-- ---------------------------------------------------------------------------

-- The owner, and nobody else. For the facility's own wine the owner is the
-- facility, and a facility user acts for it. For a client's wine it is the
-- client, and an admin is deliberately not included: an admin who could quietly
-- unhide a client's lot would make the setting advisory.
create or replace function may_set_privacy(p_node_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from node n
     where n.id = p_node_id
       and (
         n.owner_id = current_party_id()
         or (n.owner_id = facility_party_id() and is_facility_user())
       )
  );
$$;

create or replace function set_lot_hidden(p_node_id uuid, p_hidden text[])
returns text[]
language plpgsql
security definer
set search_path = public
as $$
begin
  if not may_set_privacy(p_node_id) then
    raise exception 'only the owner of that wine decides what is hidden about it'
      using errcode = 'insufficient_privilege';
  end if;
  if not (coalesce(p_hidden, '{}') <@ hideable_fields()) then
    raise exception 'that is not something the kernel knows how to hide';
  end if;

  update node set hidden = coalesce(p_hidden, '{}') where id = p_node_id;
  return coalesce(p_hidden, '{}');
end;
$$;

create or replace function set_party_default_hidden(p_party_id uuid, p_hidden text[])
returns text[]
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (p_party_id = current_party_id()
          or (p_party_id = facility_party_id() and is_facility_user())) then
    raise exception 'only that party decides what it hides by default'
      using errcode = 'insufficient_privilege';
  end if;
  if not (coalesce(p_hidden, '{}') <@ hideable_fields()) then
    raise exception 'that is not something the kernel knows how to hide';
  end if;

  update party set default_hidden = coalesce(p_hidden, '{}') where id = p_party_id;
  return coalesce(p_hidden, '{}');
end;
$$;

-- ---------------------------------------------------------------------------
-- What a given reader may see of a given lot
-- ---------------------------------------------------------------------------

-- Security definer, so it can read the row and then decide. This is the only
-- thing that redacts, which is what keeps the answer the same whether it is
-- asked by a screen, a second client, or somebody with the API key and an
-- afternoon. The alternative, redacting in a view and leaving the table
-- readable, is exactly the mistake 0017 had to fix.
-- Wrapped in coalesce, and that is the whole point of this comment.
--
-- current_party_id() is null for anyone with no party, which is every member of
-- the crew. `p_owner_id = null` is not false, it is null, so the unwrapped
-- version returned null rather than false for exactly the people it exists to
-- keep out. `not null` is null, an `if` on null does not run, and the gate in
-- node_history fell open: the crew read a hidden history in full. visible_node
-- survived it only by accident, because there null failed closed.
--
-- Three-valued logic in a permission check is a bug waiting for a null, and
-- this one had a null in the commonest case there is.
create or replace function may_see_all_of(p_owner_id uuid, p_hidden text[])
returns boolean
language sql
stable
as $$
  select coalesce(
    coalesce(cardinality(p_hidden), 0) = 0
    or is_admin()
    or p_owner_id = current_party_id(),
  false);
$$;

create or replace function visible_node(p_node_id uuid)
returns node
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  n node;
  full_view boolean;
begin
  select * into n from node where id = p_node_id;
  if not found then return null; end if;

  -- Row visibility first, then field redaction. Security definer means this
  -- function reads the row whatever node_read says, so it has to re-answer the
  -- question node_read would have answered. Redacting without checking this is
  -- how a definer function hands a stranger the edges of every lot in the
  -- cellar, which is what the first draft of this migration did.
  if not coalesce(is_admin()
                  or n.owner_id = current_party_id()
                  or is_facility_user(), false) then
    return null;
  end if;

  full_view := may_see_all_of(n.owner_id, n.hidden);
  if full_view then return n; end if;

  -- Redact, field by field, exactly what the owner named. Quantity, unit and
  -- stage stay: they are the edge, and the cellar cannot work without them.
  if 'name'       = any(n.hidden) then n.name := null; end if;
  if 'owner'      = any(n.hidden) then n.owner_id := null; end if;
  if 'variety'    = any(n.hidden) then n.variety_id := null; end if;
  if 'vintage'    = any(n.hidden) then n.vintage := null; end if;
  if 'attributes' = any(n.hidden) then n.attributes := '{}'::jsonb; end if;
  return n;
end;
$$;

-- node_read now hides a lot that has anything hidden from anyone who is not its
-- owner or an admin. Staff reach it through visible_node instead, which is what
-- makes the redaction real rather than a screen being polite.
drop policy if exists node_read on node;
create policy node_read on node
  for select to authenticated
  using (
    is_admin()
    or owner_id = current_party_id()
    or (is_facility_user() and cardinality(hidden) = 0)
  );

-- ---------------------------------------------------------------------------
-- The vessel page, rebuilt on the redacting read
-- ---------------------------------------------------------------------------

create or replace view vessel_state as
  select
    v.id,
    v.type_id,
    vt.label                     as type,
    v.name,
    v.capacity_l,
    v.owner_id,
    o.name                       as owner_name,
    v.owner_id is null           as facility_owned,
    v.has_glycol,
    v.setpoint_c,
    v.mode,
    v.attributes,
    l.name                       as location_name,
    coalesce(
      case when v.has_glycol and v.mode <> 'off' then v.setpoint_c end,
      l.ambient_c
    )                            as effective_temp_c,
    p.node_id,
    n.name                       as lot_name,
    n.variety_id,
    nv.label                     as variety,
    n.vintage,
    n.product_type_id,
    np.label                     as product_type,
    n.owner_id                   as lot_owner_id,
    p.volume_l                   as current_volume_l,
    p.from_at                    as filled_at,
    (p.node_id is null)          as is_empty,
    (
      select array_agg(c.code order by c.added_at)
        from vessel_code c
       where c.vessel_id = v.id and c.active
    )                            as codes,
    lo.name                      as lot_owner_name,
    (n.owner_id is not null and n.owner_id = facility_party_id())
                                 as lot_facility_owned,
    -- So a screen can say "the owner has hidden some of this" rather than
    -- showing blanks that read like missing data.
    coalesce(cardinality(n.hidden), 0) > 0
      and not may_see_all_of(n.owner_id, n.hidden)
                                 as redacted
  from vessel v
  join term vt on vt.id = v.type_id
  left join location l on l.id = v.location_id
  left join party o on o.id = v.owner_id
  left join placement p on p.vessel_id = v.id and p.to_at is null
  -- The redacting read, rather than a plain join, so the view cannot show what
  -- the table would refuse.
  left join lateral (
    select * from visible_node(p.node_id)
  ) n on p.node_id is not null
  left join term nv on nv.id = n.variety_id
  left join term np on np.id = n.product_type_id
  left join party lo on lo.id = n.owner_id
 where v.active;

alter view vessel_state set (security_invoker = true);

-- ---------------------------------------------------------------------------
-- History and composition, which are not columns
-- ---------------------------------------------------------------------------

-- Hiding how a wine was made means hiding what was done to it, and hiding where
-- the fruit came from means hiding the walk to the bins. Neither lives on the
-- node, so neither is covered by redacting columns.

create or replace function node_history(p_node_id uuid)
returns table (
  event_id     uuid,
  node_id      uuid,
  at           timestamptz,
  operation    text,
  label        text,
  provenance   provenance,
  data         jsonb,
  inherited    boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  n node;
begin
  select * into n from node where id = p_node_id;
  if not found then return; end if;

  -- Same gate as visible_node, for the same reason.
  if not coalesce(is_admin() or n.owner_id = current_party_id()
                  or is_facility_user(), false) then
    return;
  end if;
  if 'history' = any(n.hidden)
     and not coalesce(may_see_all_of(n.owner_id, n.hidden), false) then
    return;
  end if;

  return query
  with recursive chain as (
    select p_node_id as id, 'infinity'::timestamptz as cutoff, 0 as depth
    union all
    select l.parent_id, least(chain.cutoff, l.created_at), chain.depth + 1
      from chain
      join lineage l on l.child_id = chain.id
     where chain.depth < 50
  )
  select distinct
    e.id, e.subject_id, e.at, t.value, t.label, e.provenance, e.data,
    (chain.id <> p_node_id)
  from chain
  join event e
    on e.subject_type = 'node' and e.subject_id = chain.id and e.at <= chain.cutoff
  join term t on t.id = e.operation_id
  order by e.at;
end;
$$;

create or replace function node_bin_shares(p_node_id uuid)
returns table (bin_id uuid, share numeric)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  n node;
begin
  select * into n from node where id = p_node_id;
  if not found then return; end if;

  if not coalesce(is_admin() or n.owner_id = current_party_id()
                  or is_facility_user(), false) then
    return;
  end if;
  if 'composition' = any(n.hidden)
     and not coalesce(may_see_all_of(n.owner_id, n.hidden), false) then
    return;
  end if;

  return query
  with recursive up as (
    select p_node_id as id, 1.0::numeric as share
    union all
    select l.parent_id, up.share * l.fraction
      from up
      join lineage l on l.child_id = up.id
  )
  select up.id, sum(up.share)
    from up
    join node nn on nn.id = up.id
   where nn.stage = 'bin'
   group by up.id;
end;
$$;
