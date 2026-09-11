-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A lot stays one lot until something distinguishes its parts. The
--           moment an event is recorded against some of its vessels and not
--           all of them, those vessels become their own lot, because otherwise
--           the record claims the extra sulphur went into all four barrels.
--           And a lot that forked has to be able to tell you what happened to
--           it before it forked, which nothing could do until now."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0013_close_on_empty.sql,
--              supabase/migrations/0014_rack.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (history is inherited by walking, never copied),
--                  T0-3 (provenance on every event), T0-5 (append only)
-- Open sorries: S-21 (quantity stored and derivable), S-24 (an event recorded
--               before a fork cannot be re-attached to the shard afterwards)
-- ---------------------------------------------------------------------------

-- Four barrels of the same pressing are one lot for as long as nothing tells
-- them apart. Sulphur into one of them tells them apart. `event.subject_type`
-- has no way to say "barrel three's share of this lot", so without a fork the
-- addition lands on the lot and the record asserts all four got it. That is the
-- same shape of mistake as the closing rule removed in 0013: silently wrong.
--
-- Forking is not a mode anyone picks. It is what recording against a subset
-- means, so the kernel reads it off the shape exactly as racking reads move
-- versus blend. The operator says "sulphur, this barrel" and the consequences
-- are the kernel's problem.

-- ---------------------------------------------------------------------------
-- Splitting a lot's identity, without splitting its past
-- ---------------------------------------------------------------------------

create or replace function fork_lot(
  p_node_id    uuid,
  p_vessel_ids uuid[],
  p_name       text default null
)
returns uuid
language plpgsql
as $$
declare
  parent  node%rowtype;
  child   uuid := gen_random_uuid();
  moved   numeric;
  n_here  int;
  n_total int;
  label   text;
begin
  select * into parent from node where id = p_node_id;
  if not found then
    raise exception 'no lot with id %', p_node_id;
  end if;

  select count(*), sum(coalesce(volume_l, 0)) into n_here, moved
    from placement
   where node_id = p_node_id and to_at is null and vessel_id = any(p_vessel_ids);

  if n_here = 0 then
    raise exception 'none of those vessels hold that lot';
  end if;
  if n_here <> array_length(p_vessel_ids, 1) then
    raise exception 'some of those vessels do not hold that lot';
  end if;

  select count(*) into n_total
    from placement where node_id = p_node_id and to_at is null;

  if n_here = n_total then
    raise exception 'that is every vessel this lot is in, so there is nothing to fork it from';
  end if;

  select string_agg(v.name, ', ' order by v.name) into label
    from vessel v where v.id = any(p_vessel_ids);

  insert into node (id, stage, status, name, quantity, unit, variety_id, vintage,
                    product_type_id, block_id, owner_id, attributes, created_by)
  values (child, parent.stage, 'open',
          coalesce(p_name, parent.name || ' / ' || label),
          moved, parent.unit, parent.variety_id, parent.vintage,
          parent.product_type_id, parent.block_id, parent.owner_id,
          parent.attributes, auth.uid());

  -- Wholly out of the parent, so 1.0. node_bin_shares multiplies along the
  -- path, and multiplying by one is how the child inherits every bin the parent
  -- had without a single row being copied.
  insert into lineage (parent_id, child_id, fraction) values (p_node_id, child, 1.0);

  update placement set node_id = child
   where node_id = p_node_id and to_at is null and vessel_id = any(p_vessel_ids);

  -- The parent is smaller, not spent. 0013 closes it only if this emptied it,
  -- which forking cannot do because a whole-lot fork is refused above.
  update node set quantity = greatest(coalesce(quantity, 0) - coalesce(moved, 0), 0)
   where id = p_node_id and quantity is not null;

  return child;
end;
$$;

-- ---------------------------------------------------------------------------
-- Recording something, against a lot or against part of one
-- ---------------------------------------------------------------------------

create or replace function record_event(
  p_node_id    uuid,
  p_operation  text,
  p_data       jsonb   default '{}'::jsonb,
  p_vessel_ids uuid[]  default null,
  p_at         timestamptz default now()
)
returns jsonb
language plpgsql
as $$
declare
  target  uuid := p_node_id;
  forked  boolean := false;
  n_total int;
  n_here  int;
  ev_id   uuid := gen_random_uuid();
  op_id   uuid;
begin
  op_id := term_id('operation', p_operation);
  if op_id is null then
    raise exception 'there is no operation called %', p_operation;
  end if;

  if p_vessel_ids is not null and array_length(p_vessel_ids, 1) > 0 then
    select count(*) into n_total
      from placement where node_id = p_node_id and to_at is null;
    select count(*) into n_here
      from placement
     where node_id = p_node_id and to_at is null and vessel_id = any(p_vessel_ids);

    if n_here = 0 then
      raise exception 'none of those vessels hold that lot';
    end if;

    -- A strict subset is the whole of the reason this function exists.
    if n_here < n_total then
      target := fork_lot(p_node_id, p_vessel_ids);
      forked := true;
    end if;
  end if;

  insert into event (id, operation_id, subject_type, subject_id, at, by_user,
                     data, provenance)
  values (ev_id, op_id, 'node', target, p_at, auth.uid(), p_data, 'observed');

  return jsonb_build_object('event_id', ev_id, 'node_id', target, 'forked', forked);
end;
$$;

-- ---------------------------------------------------------------------------
-- What has happened to this wine, including before it was this lot
-- ---------------------------------------------------------------------------

-- The bound is the point. A parent goes on living after a fork: three barrels
-- are still the parent and they keep having things done to them. Inheriting the
-- parent's whole event list would put next month's sulphur into the funky
-- barrel's history, which is the exact mistake forking exists to prevent, moved
-- one level up. So each edge carries a cutoff, and an ancestor contributes only
-- what happened to it before this lot came off it.
--
-- Nothing is copied. lineage.created_at already records when the split
-- happened, so this is derivable, per T0-2.
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
language sql
stable
as $$
  with recursive chain as (
    select p_node_id as id, 'infinity'::timestamptz as cutoff, 0 as depth
    union all
    select l.parent_id,
           least(chain.cutoff, l.created_at),
           chain.depth + 1
      from chain
      join lineage l on l.child_id = chain.id
     -- lineage is a directed acyclic graph by construction, and this keeps a
     -- malformed one from hanging the page rather than reporting a cycle.
     where chain.depth < 50
  )
  select distinct
    e.id, e.subject_id, e.at, t.value, t.label, e.provenance, e.data,
    (chain.id <> p_node_id) as inherited
  from chain
  join event e
    on e.subject_type = 'node' and e.subject_id = chain.id and e.at <= chain.cutoff
  join term t on t.id = e.operation_id
  order by e.at;
$$;
