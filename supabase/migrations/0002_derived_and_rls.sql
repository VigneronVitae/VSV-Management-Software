-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Defines derived composition functions, read views, and row-level
--           security. Nothing here stores anything."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [supabase/migrations/0003_parties_and_products.sql,
--                 docs/status-ledger.md,
--                 supabase/migrations/0004_terms_and_effects.sql,
--                 supabase/migrations/0005_account_and_walk.sql,
--                 tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (derived over stored), T0-4 (a producer cannot grant
--                  itself standing), T1-1 (pickers, not text fields)
-- Open sorries: S-7 (RLS untested against a real cellar user)
-- ---------------------------------------------------------------------------

-- Derived views, composition functions, row-level security.
--
-- Nothing here stores anything. Block composition and vessel occupancy are
-- computed on read. If they were columns they would be wrong the first time
-- someone corrected a volume.

-- ---------------------------------------------------------------------------
-- Composition: walk lineage to the bins, multiply fractions along each path
-- ---------------------------------------------------------------------------

-- A barrel returns 60% Perlstaad / 40% Eola Springs.
-- Same traversal gives variety composition, which matters for TTB and labelling.
create or replace function node_bin_shares(p_node_id uuid)
returns table (bin_id uuid, share numeric)
language sql
stable
as $$
  with recursive up as (
    select p_node_id as id, 1.0::numeric as share
    union all
    select l.parent_id, up.share * l.fraction
      from up
      join lineage l on l.child_id = up.id
  )
  select up.id, sum(up.share)
    from up
    join node n on n.id = up.id
   where n.stage = 'bin'
   group by up.id;
$$;

create or replace function block_composition(p_node_id uuid)
returns table (block_id uuid, vineyard text, block_name text, share numeric)
language sql
stable
as $$
  select b.id, b.vineyard, b.name, sum(s.share)
    from node_bin_shares(p_node_id) s
    join node n on n.id = s.bin_id
    join block b on b.id = n.block_id
   group by b.id, b.vineyard, b.name
   order by 4 desc;
$$;

create or replace function variety_composition(p_node_id uuid)
returns table (variety text, share numeric)
language sql
stable
as $$
  select n.variety, sum(s.share)
    from node_bin_shares(p_node_id) s
    join node n on n.id = s.bin_id
   group by n.variety
   order by 2 desc;
$$;

-- How much of what a node rests on was never actually witnessed.
-- If a cost or yield number is computed from inferred history, say so.
create or replace function inferred_fraction(p_node_id uuid)
returns numeric
language sql
stable
as $$
  with recursive up as (
    select p_node_id as id
    union
    select l.parent_id from up join lineage l on l.child_id = up.id
  )
  select coalesce(
    count(*) filter (where e.provenance = 'inferred')::numeric
      / nullif(count(*), 0),
    0)
    from up
    join event e
      on e.subject_type = 'node' and e.subject_id = up.id;
$$;

-- ---------------------------------------------------------------------------
-- Views the app reads directly
-- ---------------------------------------------------------------------------

-- The vessel page. Occupancy is derived: a vessel is full if it has a
-- placement with no to_at.
create or replace view vessel_state as
  select
    v.id,
    v.type,
    v.name,
    v.capacity_l,
    v.qr_code,
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
    p.volume_l                   as current_volume_l,
    p.from_at                    as filled_at,
    (p.node_id is null)          as is_empty
  from vessel v
  left join location l on l.id = v.location_id
  left join placement p on p.vessel_id = v.id and p.to_at is null
  left join node n on n.id = p.node_id
  where v.active;

-- Every open lot with where it currently lives. A lot may appear many times:
-- Pinot Gris in a tank and eight barrels.
create or replace view lot_state as
  select
    n.id,
    n.name,
    n.stage,
    n.status,
    n.variety,
    n.vintage,
    n.quantity,
    n.unit,
    n.attributes,
    n.provenance,
    count(p.id)                          as vessel_count,
    sum(p.volume_l)                      as total_volume_l,
    array_agg(v.name order by v.name)
      filter (where v.name is not null)  as vessels
  from node n
  left join placement p on p.node_id = n.id and p.to_at is null
  left join vessel v on v.id = p.vessel_id
  where n.status <> 'closed'
  group by n.id;

-- What the board shows.
create or replace view task_board as
  select
    t.*,
    case t.subject_type
      when 'node'     then (select name from node where id = t.subject_id)
      when 'vessel'   then (select name from vessel where id = t.subject_id)
      when 'location' then (select name from location where id = t.subject_id)
      when 'block'    then (select vineyard || ' ' || name from block where id = t.subject_id)
    end as subject_name,
    u.name as claimed_by_name,
    a.name as assignee_name
  from task t
  left join app_user u on u.id = t.claimed_by
  left join app_user a on a.id = t.assignee
  where t.status in ('open', 'claimed');

-- ---------------------------------------------------------------------------
-- Cap management: the app answers punchdown or pumpover
-- ---------------------------------------------------------------------------

-- The rule plus today's history determines the answer, which is what makes
-- recording self-enforcing rather than a chore layered on top.
--
-- cap_rule shape, on node.attributes:
--   {"cap_rule": {"sequence": ["punchdown", "pumpover"], "per_day": 2}}
create or replace function next_cap_action(p_node_id uuid)
returns event_type
language plpgsql
stable
as $$
declare
  rule       jsonb;
  seq        text[];
  done_today int;
begin
  select attributes -> 'cap_rule' into rule from node where id = p_node_id;
  if rule is null then
    return 'punchdown';
  end if;

  seq := array(select jsonb_array_elements_text(rule -> 'sequence'));
  if array_length(seq, 1) is null then
    return 'punchdown';
  end if;

  select count(*) into done_today
    from event
   where subject_type = 'node'
     and subject_id = p_node_id
     and type in ('punchdown', 'pumpover')
     and at >= date_trunc('day', now());

  return seq[(done_today % array_length(seq, 1)) + 1]::event_type;
end;
$$;

-- Topping compatibility, checked before pouring rather than after.
create or replace function topping_check(p_source_node uuid, p_vessel_id uuid)
returns table (ok boolean, reason text)
language sql
stable
as $$
  with src as (select variety, vintage from node where id = p_source_node),
       tgt as (
         select n.variety, n.vintage
           from placement p join node n on n.id = p.node_id
          where p.vessel_id = p_vessel_id and p.to_at is null
       )
  select
    case
      when (select count(*) from tgt) = 0 then false
      when (select variety from tgt) is distinct from (select variety from src) then false
      when (select vintage from tgt) is distinct from (select vintage from src) then false
      else true
    end,
    case
      when (select count(*) from tgt) = 0 then 'vessel is empty'
      when (select variety from tgt) is distinct from (select variety from src)
        then 'variety mismatch: ' || coalesce((select variety from tgt), '?')
             || ' vs ' || coalesce((select variety from src), '?')
      when (select vintage from tgt) is distinct from (select vintage from src)
        then 'vintage mismatch'
      else 'ok'
    end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
-- Cellar users record what happened. Admins create the things it happens to.
-- The point is not secrecy, it is that free-text vessel names from three
-- people is how the data becomes unusable.

alter table app_user      enable row level security;
alter table location      enable row level security;
alter table block         enable row level security;
alter table vessel        enable row level security;
alter table node          enable row level security;
alter table lineage       enable row level security;
alter table placement     enable row level security;
alter table event         enable row level security;
alter table template      enable row level security;
alter table template_step enable row level security;
alter table task          enable row level security;
alter table task_claim_log enable row level security;

-- Everyone signed in reads everything.
do $$
declare t text;
begin
  foreach t in array array[
    'app_user','location','block','vessel','node','lineage','placement',
    'event','template','template_step','task','task_claim_log'
  ] loop
    execute format(
      'create policy %I_read on %I for select to authenticated using (true)', t, t);
  end loop;
end $$;

-- Admin-only writes: the structural objects.
do $$
declare t text;
begin
  foreach t in array array[
    'app_user','location','block','vessel','template','template_step'
  ] loop
    execute format(
      'create policy %I_admin_write on %I for all to authenticated
         using (is_admin()) with check (is_admin())', t, t);
  end loop;
end $$;

-- Events: anyone may record, nobody may rewrite history.
-- Corrections are new events, not edits.
create policy event_insert on event
  for insert to authenticated
  with check (by_user = auth.uid() or by_sensor is not null);

create policy event_admin_update on event
  for update to authenticated
  using (is_admin()) with check (is_admin());

-- Nodes, lineage, placements: cellar users create these through the press and
-- rack screens, so inserts are open. Edits and deletes are admin.
do $$
declare t text;
begin
  foreach t in array array['node','lineage','placement'] loop
    execute format(
      'create policy %I_insert on %I for insert to authenticated with check (true)', t, t);
    execute format(
      'create policy %I_admin_update on %I for update to authenticated
         using (is_admin()) with check (is_admin())', t, t);
    execute format(
      'create policy %I_admin_delete on %I for delete to authenticated
         using (is_admin())', t, t);
  end loop;
end $$;

-- Tasks: admins create and assign. Cellar users may only move a task they hold.
create policy task_admin_write on task
  for all to authenticated
  using (is_admin()) with check (is_admin());

create policy task_own_update on task
  for update to authenticated
  using (claimed_by = auth.uid() or assignee = auth.uid())
  with check (claimed_by = auth.uid() or assignee = auth.uid());

create policy claim_log_insert on task_claim_log
  for insert to authenticated with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
-- The board needs to show a claimed task as claimed on someone else's phone.

alter publication supabase_realtime add table task;
alter publication supabase_realtime add table event;
alter publication supabase_realtime add table placement;
