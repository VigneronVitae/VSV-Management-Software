-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Moves user-extensible vocabulary out of Postgres enums and into a
--           term table, and gives every operation one of four kernel effects so
--           the kernel branches on effect rather than on operation name."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0003_parties_and_products.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md,
--                 supabase/migrations/0005_account_and_walk.sql,
--                 tests/schema_assertions.sql,
--                 supabase/migrations/0007_vessel_edit.sql,
--                 supabase/migrations/0009_vessel_type_form.sql,
--                 supabase/migrations/0011_vessel_type_fields.sql,
--                 supabase/migrations/0014_rack.sql,
--                 supabase/migrations/0016_lot_owner_name.sql,
--                 supabase/migrations/0019_procedures.sql,
--                 supabase/migrations/0023_subject_resolver.sql,
--                 supabase/migrations/0024_task_board_via_registry.sql,
--                 supabase/migrations/0027_term_kind_registry.sql]
-- Axioms enforced: T1-1 (pickers, not text fields), T0-2 (derived over stored)
-- Open sorries: S-7 (RLS untested), S-15 (an unknown operation records and
--               drives nothing beyond its effect), S-16 (bottle is not really
--               a transformation)
-- ---------------------------------------------------------------------------

-- The problem this fixes: product_type, vessel_type and event_type were
-- Postgres enums, so adding a value took a migration. A brewery forking this
-- could not add a vessel type without editing SQL, and a winemaker could not
-- add a variety nobody anticipated. That is a semantic judgment sitting in the
-- fixed tier, which is the thing the spec's axioms say does not belong there.
--
-- The split this migration draws:
--   fixed tier  the kernel must understand it: term kinds, and the four effects
--   free tier   the facility decides it: which varieties, coopers, vessel types,
--               and operations exist
--
-- Nothing is preserved. The database is empty.

-- ---------------------------------------------------------------------------
-- term: one table for user-extensible vocabulary
-- ---------------------------------------------------------------------------

-- kind is an enum on purpose, and it is the one place this migration keeps a
-- fixed tier. Adding a kind means something in the kernel has to consume it, so
-- it is a code change either way and the enum says so out loud. Adding a value
-- within a kind is what has to be free, and now is.
create type term_kind as enum (
  'variety', 'cooper', 'wood', 'vessel_type', 'product_type',
  'material_kind', 'operation', 'location_kind'
);

create table term (
  id          uuid primary key default gen_random_uuid(),
  kind        term_kind not null,
  value       text not null,
  label       text not null,
  active      boolean not null default true,
  sort_order  int not null default 0,
  attributes  jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),

  unique (kind, value),

  -- Effect is fixed tier and there are exactly four answers, because the kernel
  -- has exactly four things it can do about volume and lineage. Operation names
  -- are free; what an operation does to the record is not.
  constraint operation_has_an_effect check (
    kind <> 'operation'
    or attributes ->> 'effect' in
       ('measurement', 'treatment', 'movement', 'transformation')
  )
);

-- Lets a referencing table demand a term of one specific kind, below.
alter table term add constraint term_id_kind_key unique (id, kind);

create index term_kind_idx on term(kind, sort_order, label) where active;

-- Stable lookup by machine key. Used for column defaults and for seeds, so that
-- nothing in this file has to hardcode a generated uuid.
create or replace function term_id(p_kind term_kind, p_value text)
returns uuid
language sql
stable
as $$
  select id from term where kind = p_kind and value = p_value;
$$;

-- What the kernel actually asks about an operation.
create or replace function operation_effect(p_operation_id uuid)
returns text
language sql
stable
as $$
  select attributes ->> 'effect' from term
   where id = p_operation_id and kind = 'operation';
$$;

-- ---------------------------------------------------------------------------
-- Seed: this winery's vocabulary, and nothing else
-- ---------------------------------------------------------------------------

-- Six varieties, four vessel types, four product types, and the operation
-- vocabulary from spec section 3. No coopers, no woods, no locations: those are
-- facility-specific, they must be addable at runtime, and seeding them would
-- hide the fact that a fresh install has none.

insert into term (kind, value, label, sort_order) values
  ('variety', 'riesling',          'Riesling',          10),
  ('variety', 'pinot_gris',        'Pinot Gris',        20),
  ('variety', 'chardonnay',        'Chardonnay',        30),
  ('variety', 'gruner_veltliner',  'Grüner Veltliner',  40),
  ('variety', 'muller_thurgau',    'Müller Thurgau',    50),
  ('variety', 'pinot_noir',        'Pinot Noir',        60);

insert into term (kind, value, label, sort_order) values
  ('vessel_type', 'macrobin',  'Macrobin',  10),
  ('vessel_type', 'fermenter', 'Fermenter', 20),
  ('vessel_type', 'tank',      'Tank',      30),
  ('vessel_type', 'barrel',    'Barrel',    40);

insert into term (kind, value, label, sort_order) values
  ('product_type', 'wine',     'Wine',     10),
  ('product_type', 'cider',    'Cider',    20),
  ('product_type', 'vermouth', 'Vermouth', 30),
  ('product_type', 'other',    'Other',    40);

-- Measurements observe and change nothing.
insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'sample',       'Sample',              10, '{"effect": "measurement"}'),
  ('operation', 'temp_reading', 'Temperature reading', 20, '{"effect": "measurement"}');

-- A setpoint is a decision and a reading is an observation, which the spec is
-- careful about and this column is not: effect answers what happens to volume
-- and lineage, and for both the answer is nothing. The distinction the spec
-- cares about lives in the operation, which is where it belongs. See S-15.
insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'setpoint_change', 'Setpoint change', 30, '{"effect": "measurement"}');

-- Treatments change the wine in place. No structural change.
insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'addition',          'Addition',          110, '{"effect": "treatment"}'),
  ('operation', 'punchdown',         'Punchdown',         120, '{"effect": "treatment"}'),
  ('operation', 'pumpover',          'Pumpover',          130, '{"effect": "treatment"}'),
  ('operation', 'batonnage',         'Bâtonnage',         140, '{"effect": "treatment"}'),
  ('operation', 'cold_soak',         'Cold soak',         160, '{"effect": "treatment"}'),
  ('operation', 'cold_crash',        'Cold crash',        170, '{"effect": "treatment"}'),
  ('operation', 'cold_stabilize',    'Cold stabilise',    180, '{"effect": "treatment"}'),
  ('operation', 'filter',            'Filter',            190, '{"effect": "treatment"}'),
  ('operation', 'halt_fermentation', 'Halt fermentation', 200, '{"effect": "treatment"}'),
  ('operation', 'malo_check',        'Malo check',        210, '{"effect": "treatment"}');

-- Topping carries the compatibility rule that used to be hardcoded in
-- topping_check. Moving it here is what makes the check configurable without a
-- migration: a cidery that tops across vintages edits a row.
insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'topping', 'Topping', 150,
   '{"effect": "treatment",
     "predicate": {"match": ["variety", "vintage", "product_type"]}}');

-- Movements change vessels, not the lot.
insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'rack',             'Rack',             310, '{"effect": "movement"}'),
  ('operation', 'consolidate',      'Consolidate',      320, '{"effect": "movement"}'),
  ('operation', 'distribute_lees',  'Distribute lees',  330, '{"effect": "movement"}'),
  ('operation', 'move_vessel',      'Move vessel',      340, '{"effect": "movement"}');

-- Transformations close parents and write lineage.
-- press is both a movement and a transformation, which the spec notes; the
-- placement write covers the movement half and lineage covers this half.
insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'press',  'Press',  410, '{"effect": "transformation"}'),
  ('operation', 'destem', 'Destem', 420, '{"effect": "transformation"}'),
  ('operation', 'blend',  'Blend',  430, '{"effect": "transformation"}');

-- bottle is filed as a transformation because it closes a parent and it is the
-- closest of the four. It converts bulk to discrete units, which is arguably a
-- fifth effect, and S-12 already defers that whole seam. See S-16.
insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'bottle', 'Bottle', 440, '{"effect": "transformation"}');

-- ---------------------------------------------------------------------------
-- Everything that reads the columns about to change
-- ---------------------------------------------------------------------------

-- resolve_vessel_code returns setof vessel_state, so it holds a dependency on
-- the view's row type and has to go first. It comes back unchanged below.
drop function resolve_vessel_code(text);
drop view vessel_state;
drop view lot_state;
drop view task_board;
drop function variety_composition(uuid);
drop function topping_check(uuid, uuid);
drop function next_cap_action(uuid);

-- ---------------------------------------------------------------------------
-- Columns move from enums to terms
-- ---------------------------------------------------------------------------

-- The kind column on each side is a constant, and it exists so the foreign key
-- can name both id and kind. That turns "the picker only offers varieties" into
-- "the database refuses anything else", which is worth one stored column: this
-- is the opposite case from event.subject_id, where the check is impossible and
-- doctor has to carry it (S-4).

alter table node
  add column variety_id      uuid,
  add column variety_kind    term_kind generated always as ('variety'::term_kind) stored,
  add column product_type_id uuid not null default term_id('product_type', 'wine'),
  add column product_kind    term_kind generated always as ('product_type'::term_kind) stored,
  add constraint node_variety_is_a_variety
    foreign key (variety_id, variety_kind) references term(id, kind),
  add constraint node_product_type_is_a_product_type
    foreign key (product_type_id, product_kind) references term(id, kind);

alter table node drop column variety;
alter table node drop column product_type;

create index node_variety_vintage_idx on node(variety_id, vintage);
create index node_product_type_idx on node(product_type_id);

alter table vessel
  add column type_id   uuid not null,
  add column type_kind term_kind generated always as ('vessel_type'::term_kind) stored,
  add constraint vessel_type_is_a_vessel_type
    foreign key (type_id, type_kind) references term(id, kind);

alter table vessel drop column type;
alter table vessel add constraint vessel_type_name_key unique (type_id, name);

alter table event
  add column operation_id   uuid not null,
  add column operation_kind term_kind generated always as ('operation'::term_kind) stored,
  add constraint event_operation_is_an_operation
    foreign key (operation_id, operation_kind) references term(id, kind);

alter table event drop column type;
create index event_operation_at_idx on event(operation_id, at desc);

alter table task
  add column operation_id   uuid not null,
  add column operation_kind term_kind generated always as ('operation'::term_kind) stored,
  add constraint task_operation_is_an_operation
    foreign key (operation_id, operation_kind) references term(id, kind);

alter table task drop column type;

alter table template_step
  add column operation_id   uuid not null,
  add column operation_kind term_kind generated always as ('operation'::term_kind) stored,
  add constraint template_step_operation_is_an_operation
    foreign key (operation_id, operation_kind) references term(id, kind);

alter table template_step drop column type;

drop type product_type;
drop type vessel_type;
drop type event_type;

-- ---------------------------------------------------------------------------
-- The views and functions come back, reading labels through term
-- ---------------------------------------------------------------------------

create or replace function variety_composition(p_node_id uuid)
returns table (variety_id uuid, variety text, share numeric)
language sql
stable
as $$
  select t.id, t.label, sum(s.share)
    from node_bin_shares(p_node_id) s
    join node n on n.id = s.bin_id
    left join term t on t.id = n.variety_id
   group by t.id, t.label
   order by 3 desc;
$$;

create view vessel_state
with (security_invoker = true) as
  select
    v.id,
    v.type_id,
    vt.label                     as type,
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
    )                            as codes
  from vessel v
  join term vt on vt.id = v.type_id
  left join location l on l.id = v.location_id
  left join party o on o.id = v.owner_id
  left join placement p on p.vessel_id = v.id and p.to_at is null
  left join node n on n.id = p.node_id
  left join term nv on nv.id = n.variety_id
  left join term np on np.id = n.product_type_id
  where v.active;

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

create view lot_state
with (security_invoker = true) as
  select
    n.id,
    n.name,
    n.stage,
    n.status,
    n.variety_id,
    nv.label                             as variety,
    n.vintage,
    n.product_type_id,
    np.label                             as product_type,
    n.owner_id,
    n.quantity,
    n.unit,
    n.attributes,
    n.provenance,
    count(p.id)                          as vessel_count,
    sum(p.volume_l)                      as total_volume_l,
    array_agg(v.name order by v.name)
      filter (where v.name is not null)  as vessels
  from node n
  left join term nv on nv.id = n.variety_id
  left join term np on np.id = n.product_type_id
  left join placement p on p.node_id = n.id and p.to_at is null
  left join vessel v on v.id = p.vessel_id
  where n.status <> 'closed'
  group by n.id, nv.label, np.label;

create view task_board
with (security_invoker = true) as
  select
    t.*,
    op.value as operation,
    op.label as operation_label,
    case t.subject_type
      when 'node'     then (select name from node where id = t.subject_id)
      when 'vessel'   then (select name from vessel where id = t.subject_id)
      when 'location' then (select name from location where id = t.subject_id)
      when 'block'    then (select vineyard || ' ' || name from block where id = t.subject_id)
    end as subject_name,
    u.name as claimed_by_name,
    a.name as assignee_name
  from task t
  join term op on op.id = t.operation_id
  left join app_user u on u.id = t.claimed_by
  left join app_user a on a.id = t.assignee
  where t.status in ('open', 'claimed');

-- cap_rule keeps its text values, per the spec: it was designed as data and the
-- sequence a person writes should stay readable. Resolution to a term happens
-- here, once, rather than in whatever screen asks the question.
create or replace function next_cap_action(p_node_id uuid)
returns table (operation_id uuid, value text, label text)
language plpgsql
stable
as $$
declare
  rule       jsonb;
  seq        text[];
  done_today int;
  pick       text;
begin
  select attributes -> 'cap_rule' into rule from node where id = p_node_id;

  seq := case
           when rule is null then array['punchdown']
           else array(select jsonb_array_elements_text(rule -> 'sequence'))
         end;

  if array_length(seq, 1) is null then
    seq := array['punchdown'];
  end if;

  select count(*) into done_today
    from event e
    join term o on o.id = e.operation_id
   where e.subject_type = 'node'
     and e.subject_id = p_node_id
     and o.value in ('punchdown', 'pumpover')
     and e.at >= date_trunc('day', now());

  pick := seq[(done_today % array_length(seq, 1)) + 1];

  return query
    select t.id, t.value, t.label
      from term t
     where t.kind = 'operation' and t.value = pick;
end;
$$;

-- Reads the fields to compare from the operation's predicate rather than
-- hardcoding variety and vintage. A cidery that tops across vintages edits one
-- row; the previous version needed a migration and a redeploy.
create or replace function topping_check(
  p_source_node uuid,
  p_vessel_id   uuid,
  p_operation   uuid default null
)
returns table (ok boolean, reason text)
language plpgsql
stable
as $$
declare
  op          uuid;
  fields      text[];
  src         jsonb;
  src_display jsonb;
  tgt         jsonb;
  tgt_display jsonb;
  f           text;
begin
  op := coalesce(p_operation, term_id('operation', 'topping'));

  select coalesce(
           array(select jsonb_array_elements_text(t.attributes -> 'predicate' -> 'match')),
           '{}'::text[])
    into fields
    from term t where t.id = op;

  -- The comparable surface of a node, keyed the way a predicate names it. A
  -- predicate naming a field that is absent here compares null to null and
  -- passes, which is the untyped floor behaving as designed.
  select jsonb_build_object(
           'variety',      n.variety_id,
           'vintage',      n.vintage,
           'product_type', n.product_type_id,
           'owner',        n.owner_id),
         jsonb_build_object(
           'variety',      coalesce(vt.label, 'none'),
           'vintage',      coalesce(n.vintage::text, 'none'),
           'product_type', coalesce(pt.label, 'none'),
           'owner',        coalesce(po.name, 'none'))
    into src, src_display
    from node n
    left join term vt on vt.id = n.variety_id
    left join term pt on pt.id = n.product_type_id
    left join party po on po.id = n.owner_id
   where n.id = p_source_node;

  select jsonb_build_object(
           'variety',      n.variety_id,
           'vintage',      n.vintage,
           'product_type', n.product_type_id,
           'owner',        n.owner_id),
         jsonb_build_object(
           'variety',      coalesce(vt.label, 'none'),
           'vintage',      coalesce(n.vintage::text, 'none'),
           'product_type', coalesce(pt.label, 'none'),
           'owner',        coalesce(po.name, 'none'))
    into tgt, tgt_display
    from placement p
    join node n on n.id = p.node_id
    left join term vt on vt.id = n.variety_id
    left join term pt on pt.id = n.product_type_id
    left join party po on po.id = n.owner_id
   where p.vessel_id = p_vessel_id and p.to_at is null;

  if tgt is null then
    return query select false, 'vessel is empty';
    return;
  end if;

  foreach f in array fields loop
    if (src -> f) is distinct from (tgt -> f) then
      return query select
        false,
        f || ' mismatch: ' || (tgt_display ->> f) || ' vs ' || (src_display ->> f);
      return;
    end if;
  end loop;

  return query select true, 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table term enable row level security;

create policy term_read on term
  for select to authenticated using (true);

-- Structural, so it matches vessel and location rather than the event tables.
-- The consequence is that add-inline during the inventory walk needs an admin,
-- which the walk is. A cellar user who needs to add a cooper mid-intake is a
-- policy line away and is not this session's problem.
create policy term_admin_write on term
  for all to authenticated
  using (is_admin()) with check (is_admin());
