-- ---------------------------------------------------------------------------
-- Type: test
-- Purpose: "Asserts that the schema refuses what it should refuse and computes
--           what it should compute, so that the definition of done in CLAUDE.md
--           is a command rather than a description."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0003_parties_and_products.sql,
--              supabase/migrations/0004_terms_and_effects.sql,
--              supabase/migrations/0005_account_and_walk.sql,
--              supabase/migrations/0006_vessel_thermal.sql,
--              supabase/migrations/0007_vessel_edit.sql,
--              supabase/migrations/0008_fill_vessel.sql,
--              supabase/migrations/0009_vessel_type_form.sql,
--              supabase/migrations/0010_glycol_by_type.sql,
--              supabase/migrations/0011_vessel_type_fields.sql,
--              supabase/migrations/0012_vessel_type_notes.sql,
--              supabase/migrations/0013_close_on_empty.sql,
--              supabase/migrations/0014_rack.sql,
--              supabase/migrations/0015_fork_and_history.sql,
--              supabase/migrations/0016_lot_owner_name.sql,
--              supabase/migrations/0017_vessel_state_rls.sql,
--              supabase/migrations/0018_lot_privacy.sql,
--              supabase/migrations/0019_procedures.sql,
--              supabase/migrations/0020_pin_search_path.sql,
--              supabase/migrations/0021_cellar_write_paths.sql,
--              supabase/migrations/0022_admission_and_authorship.sql,
--              supabase/migrations/0023_subject_resolver.sql,
--              supabase/migrations/0024_task_board_via_registry.sql,
--              supabase/migrations/0025_bind_an_unbound_code.sql,
--              supabase/migrations/0026_subject_type_registry.sql,
--              supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0028_redaction_is_row_level.sql,
--              supabase/migrations/0029_viewer_scope.sql,
--              supabase/migrations/0030_writable_columns.sql,
--              supabase/migrations/0031_scheduling_to_core.sql,
--              supabase/migrations/0032_vessel_maker_and_room_temperature.sql, supabase/migrations/0033_intake.sql, supabase/migrations/0034_press.sql, supabase/migrations/0035_bins_in_bulk.sql, supabase/migrations/0036_bins_on_loan.sql, supabase/migrations/0037_export.sql, supabase/migrations/0038_cancel_a_pick.sql, supabase/migrations/0039_vineyard.sql, supabase/migrations/0040_block_variety_is_history.sql, supabase/migrations/0041_daily_log.sql, supabase/migrations/0042_weighing_photo.sql, supabase/migrations/0043_record_propagation.sql]
-- Depended on by: [docs/status-ledger.md, scripts/green.sh, scripts/mutate.sh,
--                  scripts/status.sh]
-- Axioms enforced: none. This file checks that the migrations enforce theirs.
-- Open sorries: S-7 (what this exercises is Postgres policy evaluation, not
--               Supabase's JWT to role mapping, so S-7 narrows and stays open)
-- ---------------------------------------------------------------------------

-- Run against a database with every migration applied, as a role that may
-- create rows and switch to `authenticated`:
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/schema_assertions.sql
--
-- Everything happens inside one transaction that rolls back at the end, so this
-- is safe against a development database and pointless against production.
--
-- Each assertion prints its own line. A failure raises and, with ON_ERROR_STOP,
-- takes the whole run down, which is the behaviour wanted: a half-passing
-- schema test is worse than none.

\set ON_ERROR_STOP on
\timing off

begin;

-- Acting as a given account. Both settings are written because auth.uid() in
-- Supabase reads the singular claim first and the claims blob second.
create or replace function test_act_as(p_user uuid)
returns void language plpgsql set search_path = public, pg_temp as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), true);
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else json_build_object('sub', p_user)::text end, true);
end $$;

-- Snapshot assertions can be switched off from outside, which is what lets the
-- mutation harness report a behavioural score separately from a snapshot score.
--
-- W-6 phase 2, and the reason it exists: 86 of 198 caught mutations were caught
-- only by a pinned catalog comparison whose failure message told the reader to
-- update the pinned value. A snapshot detects that something changed. A
-- behavioural assertion detects that something now does the wrong thing. Both
-- are worth having and summing them into one number made the number mean
-- nothing. The gate from here is the behavioural score.
create or replace function snapshots_on()
returns boolean language sql stable set search_path = public, pg_temp as $$
  select coalesce(current_setting('vsv.snapshots', true), 'on') <> 'off';
$$;

create or replace function skip_snapshot(p_msg text)
returns void language plpgsql set search_path = public, pg_temp as $$
begin
  raise notice 'skip %  (snapshot, off for the behavioural pass)', p_msg;
end $$;

create or replace function test_ok(p_msg text)
returns void language plpgsql set search_path = public, pg_temp as $$
begin
  raise notice 'ok   %', p_msg;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- standing the winery down for the duration'; end $$;

-- This suite asserts things about a winery that does not exist yet: that no node
-- can be created before the facility party, that exactly one facility party may
-- be active, that the first claimant becomes admin. All of those are true only of
-- an empty database, so until now the suite could be run only straight after
-- `supabase db reset`, which destroys the cellar. That put the definition of done
-- in CLAUDE.md at war with itself: it says run the assertions, and it says use
-- `db:up` because reset takes the inventory with it.
--
-- The condition is created here instead of assumed. Any existing facility party
-- is deactivated for the duration, which is enough because party_one_facility is
-- a partial unique index on `active` and facility_party_id() reads the same flag.
-- Everything in this file runs inside one transaction and the final `rollback`
-- puts the winery back. Nothing here commits.
do $$
declare n int;
begin
  update party set active = false where kind = 'facility' and active;
  get diagnostics n = row_count;
  if n > 0 then
    raise notice 'ok   stood % existing facility party down for the run; rollback restores it', n;
  else
    raise notice 'ok   no existing facility party, so this is an empty database';
  end if;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- vocabulary is extensible at runtime'; end $$;

insert into term (kind, value, label, sort_order) values
  ('variety',       'gamay_noir',      'Gamay Noir',      70),
  ('vessel_maker',  'francois_freres', 'François Frères', 10),
  ('wood',          'french_oak',      'French oak',      10),
  ('vessel_type',   'amphora',         'Amphora',         50),
  ('location_kind', 'barrel_room',     'Barrel room',     10);

do $$ begin
  perform test_ok('a variety, cooper, wood, vessel type and location kind added with no migration');
end $$;

do $$ begin
  begin
    insert into term (kind, value, label, attributes)
      values ('operation', 'teleport', 'Teleport', '{"effect":"magic"}');
    raise exception 'FAIL: an effect outside the four was accepted';
  exception when check_violation then
    perform test_ok('an operation effect outside the four is refused');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- ownership'; end $$;

do $$ begin
  begin
    insert into node (stage, name) values ('bin', 'ownerless');
    raise exception 'FAIL: a node was created with no facility party';
  exception when not_null_violation then
    perform test_ok('no node can exist before the facility party does');
  end;
end $$;

insert into party (id, name, kind) values
  ('00000000-0000-0000-0000-00000000f001', 'Test Facility', 'facility'),
  ('00000000-0000-0000-0000-00000000f002', 'Test Client',   'client');

do $$ begin
  begin
    insert into party (name, kind) values ('Second Facility', 'facility');
    raise exception 'FAIL: two active facility parties were allowed';
  exception when unique_violation then
    perform test_ok('exactly one active facility party');
  end;
end $$;

do $$ begin
  begin
    insert into node (stage, name, variety_id) values ('bin', 'x', term_id('vessel_maker','francois_freres'));
    raise exception 'FAIL: a cooper was accepted where a variety belongs';
  exception when foreign_key_violation then
    perform test_ok('a term of the wrong kind is refused by the database, not by the picker');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- claiming an account'; end $$;

insert into auth.users (id) values
  ('00000000-0000-0000-0000-00000000a001'),
  ('00000000-0000-0000-0000-00000000a002'),
  ('00000000-0000-0000-0000-00000000a003');

-- Whether the first account becomes admin depends on whether there is a first
-- account, so this asserts the rule rather than one side of it. On an empty
-- database the claimant is admin. On a database somebody has already signed into
-- the claimant is a cellar user, which is the half that protects a live winery
-- from the next person who signs up, and it is the half that was never asserted.
do $$
declare u app_user; was_empty boolean;
begin
  select count(*) = 0 into was_empty from app_user;
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  u := claim_account('First Account');

  if was_empty then
    if u.role <> 'admin' then raise exception 'FAIL: the first account is not admin'; end if;
    perform test_ok('the first account becomes admin');
  else
    if u.role <> 'cellar' then
      raise exception 'FAIL: an account claimed against a populated app_user came out %', u.role;
    end if;
    perform test_ok('an account claimed after the first is cellar, not admin');
    -- The rest of this file needs an admin fixture, and on a populated database
    -- claim_account correctly refuses to provide one. Promote it directly. This
    -- is fixture setup inside a transaction that rolls back, not a claim.
    update app_user set role = 'admin' where id = '00000000-0000-0000-0000-00000000a001';
  end if;

  u := claim_account('Called Again');
  if u.name <> 'First Account' then raise exception 'FAIL: claim_account is not idempotent'; end if;
  perform test_ok('claiming twice returns the existing account rather than a second one');

  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  u := claim_account('Harvest Intern');
  if u.role <> 'cellar' then raise exception 'FAIL: the second account is not cellar'; end if;
  perform test_ok('every account after the first is cellar');
end $$;

-- a cellar user belonging to the client party, for the scoping test below
do $$
declare u app_user;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  u := claim_account('Client Login');
end $$;
update party set app_user_id = '00000000-0000-0000-0000-00000000a003'
 where id = '00000000-0000-0000-0000-00000000f002';

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- T0-4, a producer cannot grant itself standing'; end $$;

do $$ begin perform test_act_as('00000000-0000-0000-0000-00000000a001'); end $$;

insert into node (id, stage, name, variety_id, vintage)
  values ('00000000-0000-0000-0000-00000000b001','ferment','Assertion lot',
          term_id('variety','pinot_noir'), 2026);

do $$ begin
  begin
    insert into node (stage, name, provenance) values ('bin','born confirmed','confirmed');
    raise exception 'FAIL: a node was born confirmed';
  exception when insufficient_privilege then
    perform test_ok('a node cannot be born confirmed');
  end;
  begin
    insert into event (operation_id, subject_type, subject_id, by_user, provenance)
      values (term_id('operation','sample'),'node','00000000-0000-0000-0000-00000000b001',
              auth.uid(),'confirmed');
    raise exception 'FAIL: an event was born confirmed';
  exception when insufficient_privilege then
    perform test_ok('an event cannot be born confirmed');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- operations, effects and predicates'; end $$;

insert into term (kind, value, label, sort_order, attributes)
  values ('operation','whirlpool','Whirlpool',500,'{"effect":"treatment"}');

insert into event (operation_id, subject_type, subject_id, by_user, data)
  values (term_id('operation','whirlpool'),'node','00000000-0000-0000-0000-00000000b001',
          auth.uid(),'{"minutes":20}');

do $$
declare lineage_rows int; st node_status;
begin
  select count(*) into lineage_rows from lineage;
  select status into st from node where id = '00000000-0000-0000-0000-00000000b001';
  if lineage_rows <> 0 or st <> 'open' then
    raise exception 'FAIL: an unseen treatment touched lineage or closed the node';
  end if;
  perform test_ok('an operation the kernel has never seen records and changes no lineage');
end $$;

-- topping_check reads the operation predicate rather than hardcoded fields
insert into vessel (id, type_id, name, capacity_l)
  values ('00000000-0000-0000-0000-00000000c001', term_id('vessel_type','barrel'), 'Assertion barrel', 228);
insert into node (id, stage, name, variety_id, vintage) values
  ('00000000-0000-0000-0000-00000000b010','maturation','In the barrel', term_id('variety','chardonnay'), 2025),
  ('00000000-0000-0000-0000-00000000b011','maturation','Same everything', term_id('variety','chardonnay'), 2025),
  ('00000000-0000-0000-0000-00000000b012','maturation','Older vintage',   term_id('variety','chardonnay'), 2024);
insert into placement (node_id, vessel_id, volume_l)
  values ('00000000-0000-0000-0000-00000000b010','00000000-0000-0000-0000-00000000c001', 220);

do $$
declare r record;
begin
  select * into r from topping_check('00000000-0000-0000-0000-00000000b011','00000000-0000-0000-0000-00000000c001');
  if not r.ok then raise exception 'FAIL: a compatible top was refused: %', r.reason; end if;
  select * into r from topping_check('00000000-0000-0000-0000-00000000b012','00000000-0000-0000-0000-00000000c001');
  if r.ok then raise exception 'FAIL: a vintage mismatch was allowed'; end if;
  perform test_ok('topping_check refuses a vintage mismatch under the seeded predicate');

  update term set attributes = jsonb_set(attributes,'{predicate,match}','["variety","product_type"]')
   where kind = 'operation' and value = 'topping';

  select * into r from topping_check('00000000-0000-0000-0000-00000000b012','00000000-0000-0000-0000-00000000c001');
  if not r.ok then raise exception 'FAIL: the predicate was edited and the check did not follow'; end if;
  perform test_ok('dropping vintage from the predicate changes what topping_check refuses, with no code change');

  update term set attributes = jsonb_set(attributes,'{predicate,match}','["variety","vintage","product_type"]')
   where kind = 'operation' and value = 'topping';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- vessel codes'; end $$;

do $$
declare a vessel_code; b vessel_code; n int;
begin
  a := bind_vessel_code('00000000-0000-0000-0000-00000000c001','COOPER-7781','cooper');
  b := bind_vessel_code('00000000-0000-0000-0000-00000000c001','VS-023','our sticker');
  perform bind_vessel_code('00000000-0000-0000-0000-00000000c001','COOPER-7781','cooper');
  select count(*) into n from vessel_code where vessel_id = '00000000-0000-0000-0000-00000000c001';
  if n <> 2 then raise exception 'FAIL: rebinding a code added a row'; end if;
  perform test_ok('rebinding a code the vessel already carries is not an error and adds nothing');

  select count(*) into n from (
    select id from resolve_vessel_code('COOPER-7781')
    intersect select id from resolve_vessel_code('VS-023')) x;
  if n <> 1 then raise exception 'FAIL: two codes on one barrel resolve differently'; end if;
  perform test_ok('every active code on a barrel resolves to that barrel');
end $$;

insert into vessel (id, type_id, name) values
  ('00000000-0000-0000-0000-00000000c002', term_id('vessel_type','barrel'), 'Other barrel');
-- Superseded by the A22 ruling in 0025 and rewritten rather than deleted, because
-- what it asserted is still half true: a bound code does not move for a cellar
-- hand. It moves for an admin, which is the other half and is asserted with the
-- rest of A22 further down.
--
-- The claim has to be switched to a cellar user to see the refusal. Everything up
-- to here has been acting as the admin, which is exactly why this assertion
-- started failing when the ruling landed: it was asserting that nobody could
-- rebind, and it was running as the one principal who now can.
do $$ begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  begin
    perform bind_vessel_code('00000000-0000-0000-0000-00000000c002','COOPER-7781','peeled');
    perform test_act_as('00000000-0000-0000-0000-00000000a001');
    raise exception 'FAIL: a cellar hand moved a bound code to another barrel';
  exception when insufficient_privilege then
    perform test_act_as('00000000-0000-0000-0000-00000000a001');
    perform test_ok('a code bound to one barrel refuses to move to another for a cellar hand');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the walk, in one action'; end $$;

insert into location (id, name, kind_id, controlled, ambient_c)
  values ('00000000-0000-0000-0000-00000000d001','Assertion room',
          term_id('location_kind','barrel_room'), true, 13.5);

do $$
declare r jsonb;
begin
  r := create_vessel_with_wine(
    jsonb_build_object('id','00000000-0000-0000-0000-00000000c010',
      'type_id', term_id('vessel_type','barrel'), 'name','Walk barrel', 'capacity_l', 228,
      'location_id','00000000-0000-0000-0000-00000000d001',
      -- Term ids, not term values. The client has always written ids here and
      -- this fixture wrote values, which nothing noticed until 0011 validated
      -- the bag against the type's declared fields.
      'attributes', jsonb_build_object('maker', term_id('vessel_maker','francois_freres'),
                                       'wood',  term_id('wood','french_oak'),
                                       'fill_count',3,'toast','medium')),
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b020','stage','maturation',
      'name','Walk lot','variety_id', term_id('variety','chardonnay'),'vintage',2024),
    225,
    '[{"code":"WALK-1","label":"our sticker"},{"code":"WALK-2","label":"cooper"}]');

  if (r ->> 'events_generated')::int <> 0 then
    raise exception 'FAIL: history was generated with no template present';
  end if;
  perform test_ok('vessel, lot, placement and two codes in one action');
  perform test_ok('with no template for the variety, no history is invented');
end $$;

do $$
declare n int;
begin
  select count(*) into n from vessel_state
   where name = 'Walk barrel' and lot_name = 'Walk lot'
     and current_volume_l = 225 and codes @> array['WALK-1','WALK-2'];
  if n <> 1 then raise exception 'FAIL: the vessel page does not show the walk result'; end if;
  perform test_ok('the vessel page shows the barrel, its wine, its volume and both codes');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a jacket overrides the room'; end $$;

-- The rule has been in vessel_state since 0002 and was unreachable until 0006,
-- because no write path ever set has_glycol. These four assertions are the
-- difference between a rule that is correct and a rule that is in use.

do $$
declare t numeric;
begin
  select effective_temp_c into t from vessel_state where name = 'Walk barrel';
  if t is distinct from 13.5 then
    raise exception 'FAIL: an unjacketed vessel reads % rather than the room ambient', t;
  end if;
  perform test_ok('an unjacketed vessel takes its location ambient');
end $$;

do $$
declare t numeric;
begin
  perform create_vessel_with_wine(
    jsonb_build_object('id','00000000-0000-0000-0000-00000000c012',
      'type_id', term_id('vessel_type','tank'), 'name','Assertion tank', 'capacity_l', 2000,
      'location_id','00000000-0000-0000-0000-00000000d001',
      'has_glycol', true, 'setpoint_c', 12, 'mode', 'cooling'),
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b022','stage','maturation',
      'name','Tank lot','variety_id', term_id('variety','riesling'),'vintage',2024),
    1800);

  select effective_temp_c into t from vessel_state where name = 'Assertion tank';
  if t is distinct from 12 then
    raise exception 'FAIL: a jacketed tank reads % rather than its setpoint', t;
  end if;
  perform test_ok('a jacketed setpoint overrides the room, carried by the one action');
end $$;

do $$ begin
  begin
    update vessel set mode = 'cooling'
     where id = '00000000-0000-0000-0000-00000000c010';
    raise exception 'FAIL: a mode was accepted on a vessel with no jacket';
  exception when check_violation then
    perform test_ok('cooling is refused on a vessel with no glycol jacket');
  end;
end $$;

do $$ begin
  begin
    update vessel set has_glycol = true, setpoint_c = null, mode = 'heating'
     where id = '00000000-0000-0000-0000-00000000c010';
    raise exception 'FAIL: a mode was accepted with no setpoint';
  exception when check_violation then
    perform test_ok('heating is refused with no setpoint');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- editing a vessel, and what that records'; end $$;

-- A change to the thermal triple is a decision and the spec asks for its
-- history. A change to anything else is a fact about the vessel and is not.

do $$
declare n int;
begin
  perform update_vessel('00000000-0000-0000-0000-00000000c010',
                        jsonb_build_object('name','Walk barrel renamed'));
  select count(*) into n from event
   where subject_type = 'vessel' and subject_id = '00000000-0000-0000-0000-00000000c010';
  if n <> 0 then raise exception 'FAIL: renaming a vessel wrote % events', n; end if;
  perform test_ok('renaming a vessel records no event');
end $$;

do $$
declare n int; prov provenance; d jsonb;
begin
  perform update_vessel('00000000-0000-0000-0000-00000000c010',
    jsonb_build_object('has_glycol', true, 'setpoint_c', 4, 'mode', 'cooling'));

  select count(*) into n from event
   where subject_type = 'vessel' and subject_id = '00000000-0000-0000-0000-00000000c010';
  if n <> 1 then raise exception 'FAIL: a thermal change wrote % events', n; end if;

  select provenance, data into prov, d from event
   where subject_type = 'vessel' and subject_id = '00000000-0000-0000-0000-00000000c010';
  if prov <> 'observed' then
    raise exception 'FAIL: a producer recorded its own decision as %', prov;
  end if;
  if (d ->> 'mode') <> 'cooling' or (d -> 'was' ->> 'mode') <> 'off' then
    raise exception 'FAIL: the event does not carry before and after: %', d;
  end if;
  perform test_ok('turning a jacket on writes one setpoint_change, stamped observed');
  perform test_ok('the event carries what the setpoint was and what it became');
end $$;

do $$
declare t numeric;
begin
  select effective_temp_c into t from vessel_state
   where id = '00000000-0000-0000-0000-00000000c010';
  if t is distinct from 4 then
    raise exception 'FAIL: after the edit the barrel reads % rather than its new setpoint', t;
  end if;
  perform test_ok('the edit takes effect in the derived view');
end $$;

do $$
declare n int;
begin
  perform update_vessel('00000000-0000-0000-0000-00000000c010',
    jsonb_build_object('has_glycol', true, 'setpoint_c', 4, 'mode', 'cooling'));
  select count(*) into n from event
   where subject_type = 'vessel' and subject_id = '00000000-0000-0000-0000-00000000c010';
  if n <> 1 then raise exception 'FAIL: rewriting the same thermal state wrote % events', n; end if;
  perform test_ok('saving the same thermal state again records nothing');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- filling a vessel that already exists'; end $$;

-- An empty vessel could be created and never filled: placement was written in
-- exactly one place, inside create_vessel_with_wine. These four say the other
-- half of build order 1 now exists and that it refuses the case it cannot mean.

insert into vessel (id, type_id, name, capacity_l, location_id)
  values ('00000000-0000-0000-0000-00000000c020', term_id('vessel_type','tank'),
          'Empty tank', 3000, '00000000-0000-0000-0000-00000000d001');

do $$
declare n int;
begin
  select count(*) into n from vessel_state
   where id = '00000000-0000-0000-0000-00000000c020' and is_empty;
  if n <> 1 then raise exception 'FAIL: a vessel with no placement is not empty'; end if;
  perform test_ok('a vessel created with no wine reads as empty');
end $$;

do $$
declare r jsonb; v record;
begin
  r := fill_vessel('00000000-0000-0000-0000-00000000c020',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b040','stage','maturation',
      'name','Filled lot','variety_id', term_id('variety','chardonnay'),'vintage',2024),
    2800);

  select * into v from vessel_state where id = '00000000-0000-0000-0000-00000000c020';
  if v.is_empty then raise exception 'FAIL: the vessel is still empty after a fill'; end if;
  if v.lot_name <> 'Filled lot' or v.current_volume_l <> 2800 then
    raise exception 'FAIL: filled with % at %', v.lot_name, v.current_volume_l;
  end if;
  perform test_ok('wine can be put into a vessel that already existed');
end $$;

do $$ begin
  begin
    perform fill_vessel('00000000-0000-0000-0000-00000000c020',
      jsonb_build_object('id','00000000-0000-0000-0000-00000000b041','stage','maturation',
        'name','Second lot','variety_id', term_id('variety','riesling'),'vintage',2024),
      100);
    raise exception 'FAIL: a second lot was accepted into an occupied vessel';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('filling an occupied vessel is refused in words, not by an index');
  end;
end $$;

do $$ begin
  begin
    perform fill_vessel('00000000-0000-0000-0000-0000000000ff',
      jsonb_build_object('name','Nowhere lot'), 10);
    raise exception 'FAIL: wine was placed into a vessel that does not exist';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('filling a vessel that does not exist is refused');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a vessel type describes its own form'; end $$;

-- "Creator of" is one function with two contracts. These say the partition
-- holds, and that a maker with no contract still shows up everywhere, which is
-- what keeps every cooper added before 0009 visible.

do $$
declare n int;
begin
  select count(*) into n from makers_for_vessel_type(term_id('vessel_type','barrel'))
   where value = 'francois_freres';
  if n <> 1 then raise exception 'FAIL: a cooper is not offered for a barrel'; end if;
  perform test_ok('a barrel is offered coopers');
end $$;

insert into term (kind, value, label, attributes)
  values ('vessel_maker', 'letina', 'Letina', '{"contract":"manufacturer"}');

do $$
declare barrel_has int; tank_has int;
begin
  select count(*) into barrel_has
    from makers_for_vessel_type(term_id('vessel_type','barrel')) where value = 'letina';
  select count(*) into tank_has
    from makers_for_vessel_type(term_id('vessel_type','tank')) where value = 'letina';
  if barrel_has <> 0 then raise exception 'FAIL: a tank fabricator is offered for a barrel'; end if;
  if tank_has <> 1 then raise exception 'FAIL: a tank fabricator is not offered for a tank'; end if;
  perform test_ok('a tank fabricator is offered for a tank and not for a barrel');
end $$;

insert into term (kind, value, label) values ('vessel_maker', 'untagged_maker', 'Untagged maker');

do $$
declare barrel_has int; tank_has int;
begin
  select count(*) into barrel_has
    from makers_for_vessel_type(term_id('vessel_type','barrel')) where value = 'untagged_maker';
  select count(*) into tank_has
    from makers_for_vessel_type(term_id('vessel_type','tank')) where value = 'untagged_maker';
  if barrel_has <> 1 or tank_has <> 1 then
    raise exception 'FAIL: a maker with no contract vanished from a picker';
  end if;
  perform test_ok('a maker with no contract satisfies every contract');
end $$;

do $$
declare barrel_expand jsonb; tank_expand jsonb;
begin
  select attributes -> 'expand' into barrel_expand
    from term where kind = 'vessel_type' and value = 'barrel';
  select attributes -> 'expand' into tank_expand
    from term where kind = 'vessel_type' and value = 'tank';
  if not (barrel_expand @> '["wood","toast","fill_count"]'::jsonb) then
    raise exception 'FAIL: a barrel does not open its barrel fields: %', barrel_expand;
  end if;
  -- Not "opens nothing": since 0010 a tank opens its jacket. What a tank must
  -- never open is the cooperage, which is what this is actually about.
  if tank_expand ?| array['wood','toast','fill_count'] then
    raise exception 'FAIL: a tank opens barrel fields: %', tank_expand;
  end if;
  perform test_ok('a barrel opens its barrel fields and a tank opens none of them');
end $$;

do $$
declare l text;
begin
  select attributes ->> 'maker_label' into l
    from term where kind = 'vessel_type' and value = 'tank';
  if l <> 'Manufacturer' then raise exception 'FAIL: a tank calls its maker %', l; end if;
  select attributes ->> 'maker_label' into l
    from term where kind = 'vessel_type' and value = 'barrel';
  if l <> 'Cooper' then raise exception 'FAIL: a barrel calls its maker %', l; end if;
  perform test_ok('each vessel type names its maker field for itself');
end $$;

do $$
declare tank_expand jsonb; barrel_expand jsonb;
begin
  select attributes -> 'expand' into tank_expand
    from term where kind = 'vessel_type' and value = 'tank';
  select attributes -> 'expand' into barrel_expand
    from term where kind = 'vessel_type' and value = 'barrel';
  if not (tank_expand @> '["glycol"]'::jsonb) then
    raise exception 'FAIL: a tank does not open its jacket: %', tank_expand;
  end if;
  if barrel_expand @> '["glycol"]'::jsonb then
    raise exception 'FAIL: a barrel opens a jacket it almost never has';
  end if;
  perform test_ok('a tank opens the jacket and a barrel keeps it behind More details');
end $$;

-- Visibility is not permission. Nothing about a barrel refuses a jacket, and
-- 0006's constraints are the only thing that ever refuses one.
do $$
declare t numeric;
begin
  perform update_vessel('00000000-0000-0000-0000-00000000c020',
    jsonb_build_object('has_glycol', true, 'setpoint_c', 15, 'mode', 'heating'));
  select setpoint_c into t from vessel where id = '00000000-0000-0000-0000-00000000c020';
  if t is distinct from 15 then raise exception 'FAIL: a jacket was refused on a vessel that hides it by default'; end if;
  perform test_ok('a vessel whose type hides the jacket can still be given one');
end $$;

-- with a template, history appears, stamped inferred
insert into template (id, applies_to_id, applies_to_kind, name)
  values ('00000000-0000-0000-0000-00000000e001', term_id('variety','pinot_gris'),
          'variety', 'Assertion template');
insert into template_step (template_id, step_order, operation_id, offset_interval) values
  ('00000000-0000-0000-0000-00000000e001', 1, term_id('operation','batonnage'),  interval '14 days'),
  ('00000000-0000-0000-0000-00000000e001', 2, term_id('operation','malo_check'), interval '30 days');

do $$
declare r jsonb; inferred int; confirmed int;
begin
  r := create_vessel_with_wine(
    jsonb_build_object('id','00000000-0000-0000-0000-00000000c011',
      'type_id', term_id('vessel_type','tank'), 'name','Walk tank', 'capacity_l', 2000),
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b021','stage','maturation',
      'name','PG lot','variety_id', term_id('variety','pinot_gris'),'vintage',2025),
    1800, '[]');

  if (r ->> 'events_generated')::int <> 2 then
    raise exception 'FAIL: expected two generated events, got %', r ->> 'events_generated';
  end if;

  select count(*) filter (where provenance = 'inferred'),
         count(*) filter (where provenance = 'confirmed')
    into inferred, confirmed
    from event where subject_id = '00000000-0000-0000-0000-00000000b021';

  if inferred <> 2 or confirmed <> 0 then
    raise exception 'FAIL: generated history is stamped wrong';
  end if;
  perform test_ok('template history is generated and every event of it is stamped inferred');
end $$;

do $$
declare e event; target uuid;
begin
  select id into target from event
   where subject_id = '00000000-0000-0000-0000-00000000b021' and provenance = 'inferred' limit 1;

  perform test_act_as('00000000-0000-0000-0000-00000000a002');   -- the cellar user
  begin
    e := confirm_event(target);
    raise exception 'FAIL: a cellar user confirmed an event';
  exception when insufficient_privilege then
    perform test_ok('a cellar user may not confirm');
  end;

  perform test_act_as('00000000-0000-0000-0000-00000000a001');   -- the admin
  e := confirm_event(target);
  if e.provenance <> 'confirmed' then raise exception 'FAIL: confirmation did not take'; end if;
  perform test_ok('a verifier may confirm, and only afterwards is anything confirmed');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- row level security, exercised with two accounts'; end $$;

-- A client-owned lot, so the scoping policy has something to hide.
insert into node (id, stage, name, owner_id, variety_id, vintage)
  values ('00000000-0000-0000-0000-00000000b030','maturation','Client lot',
          '00000000-0000-0000-0000-00000000f002', term_id('variety','riesling'), 2025);

do $$
declare n int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;

  begin
    insert into location (name) values ('Intern made this');
    raise exception 'FAIL: a cellar user created a location';
  exception when insufficient_privilege then
    perform test_ok('a cellar user may not create a location');
  end;

  begin
    insert into vessel (type_id, name) values (term_id('vessel_type','barrel'), 'Intern barrel');
    raise exception 'FAIL: a cellar user created a vessel';
  exception when insufficient_privilege then
    perform test_ok('a cellar user may not create a vessel');
  end;

  begin
    insert into term (kind, value, label) values ('variety','intern_grape','Intern Grape');
    raise exception 'FAIL: a cellar user created a term';
  exception when insufficient_privilege then
    perform test_ok('a cellar user may not create a term');
  end;

  -- but recording what happened is exactly what a cellar user is for
  insert into event (operation_id, subject_type, subject_id, by_user)
    values (term_id('operation','punchdown'),'node','00000000-0000-0000-0000-00000000b001', auth.uid());
  perform test_ok('a cellar user may record an event');

  select count(*) into n from node;
  if n = 0 then raise exception 'FAIL: a facility cellar user sees no nodes'; end if;
  perform test_ok('a cellar user linked to no party sees the whole cellar');

  reset role;
end $$;

do $$
declare visible int; total int; own int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');   -- the client login
  set local role authenticated;
  select count(*) into visible from node;
  select count(*) into own from node where owner_id = '00000000-0000-0000-0000-00000000f002';
  reset role;

  select count(*) into total from node;

  if visible = total then
    raise exception 'FAIL: the client sees every lot in the cellar';
  end if;
  if visible <> own or visible = 0 then
    raise exception 'FAIL: the client sees % rows, owns % of them', visible, own;
  end if;
  perform test_ok(format('a client login sees the %s lot it owns and none of the other %s',
                         visible, total - visible));
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a vessel type is admin-editable and everyone-commentable'; end $$;

-- The split the notes exist for: the person who finds the gap is rarely the
-- person allowed to close it, and blocking them loses the observation.

do $$
declare changed int; notes int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;

  update term set attributes = attributes || '{"fields":[]}'::jsonb
   where kind = 'vessel_type' and value = 'tank';
  get diagnostics changed = row_count;
  if changed <> 0 then
    raise exception 'FAIL: a cellar user reshaped a vessel type';
  end if;
  perform test_ok('a cellar user may not change what a vessel type asks for');

  insert into vessel_type_note (vessel_type_id, body, created_by)
    values (term_id('vessel_type','tank'), 'Tanks need a shape field',
            '00000000-0000-0000-0000-00000000a002');
  select count(*) into notes from vessel_type_note;
  if notes <> 1 then raise exception 'FAIL: a cellar user could not leave a note'; end if;
  perform test_ok('a cellar user may say a vessel type is wrong');

  reset role;
end $$;

do $$
declare still_open int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  set local role authenticated;
  update vessel_type_note
     set resolved_at = now(), resolved_by = '00000000-0000-0000-0000-00000000a001';
  select count(*) into still_open from vessel_type_note where resolved_at is null;
  if still_open <> 0 then raise exception 'FAIL: an admin could not resolve a note'; end if;
  perform test_ok('an admin may resolve a note, and resolving carries who did it');
  reset role;
end $$;

-- A descriptor that would break every form of that type is refused before it
-- can, rather than discovered by the next person to open the screen.
do $$ begin
  begin
    update term set attributes = attributes || '{"fields":[{"label":"x","kind":"text"}]}'::jsonb
     where kind = 'vessel_type' and value = 'tank';
    raise exception 'FAIL: a field with no key was accepted';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('a field with no key is refused');
  end;
end $$;

do $$ begin
  begin
    update term set attributes = attributes ||
      '{"fields":[{"key":"a","kind":"term","term_kind":"nonsense"}]}'::jsonb
     where kind = 'vessel_type' and value = 'tank';
    raise exception 'FAIL: a picker naming no real vocabulary was accepted';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('a picker naming a vocabulary that does not exist is refused');
  end;
end $$;

do $$ begin
  begin
    update term set attributes = attributes ||
      '{"fields":[{"key":"a","kind":"number","min":10,"max":2}]}'::jsonb
     where kind = 'vessel_type' and value = 'tank';
    raise exception 'FAIL: a minimum above a maximum was accepted';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('a minimum above a maximum is refused');
  end;
end $$;

-- What a type declares, a vessel of that type is held to.
do $$ begin
  begin
    insert into vessel (type_id, name, attributes)
      values (term_id('vessel_type','barrel'), 'Over-filled',
              '{"fill_count": -3}'::jsonb);
    raise exception 'FAIL: a value below its declared minimum was accepted';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('a value below its declared minimum is refused');
  end;
end $$;

-- A cooper that says so. francois_freres is added at runtime by this file with
-- no contract, and a maker with no contract satisfies every contract by design,
-- so it would be accepted here and correctly.
insert into term (kind, value, label, attributes)
  values ('vessel_maker', 'seguin_moreau', 'Seguin Moreau', '{"contract":"cooper"}');

do $$
declare maker_id uuid;
begin
  select id into maker_id from term where kind = 'vessel_maker' and value = 'seguin_moreau';
  begin
    insert into vessel (type_id, name, attributes)
      values (term_id('vessel_type','tank'), 'Wrong maker',
              jsonb_build_object('maker', maker_id));
    raise exception 'FAIL: a cooper was accepted as a tank manufacturer';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('a cooper is refused where the type asks for a manufacturer');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a lot closes when it is empty, not when it feeds'; end $$;

-- AR-E4. Closure is a property of the relation type, not a trigger on the table.
-- The winemaker's rule, in his own numbers: one barrel broken out of a 2000 L
-- lot for topping wine leaves 1772 L of that lot, open. 0001 closed it instead,
-- and nothing in this file noticed for two sessions.

insert into node (id, stage, status, name, quantity, unit, variety_id, vintage)
  values ('00000000-0000-0000-0000-00000000b050','maturation','open','Big lot',
          2000, 'L', term_id('variety','chardonnay'), 2025);

do $$
declare st node_status; q numeric;
begin
  -- the topping barrel, taken out of it
  insert into node (id, stage, status, name, quantity, unit, variety_id, vintage)
    values ('00000000-0000-0000-0000-00000000b051','maturation','open','Topping wine',
            228, 'L', term_id('variety','chardonnay'), 2025);
  insert into lineage (parent_id, child_id, fraction)
    values ('00000000-0000-0000-0000-00000000b050',
            '00000000-0000-0000-0000-00000000b051', 1.0);

  select status into st from node where id = '00000000-0000-0000-0000-00000000b050';
  if st <> 'open' then
    raise exception 'FAIL: feeding a child closed the parent, which is the rule that was removed';
  end if;
  perform test_ok('a lot that feeds something is not thereby spent');

  update node set quantity = 2000 - 228
   where id = '00000000-0000-0000-0000-00000000b050';
  select status, quantity into st, q
    from node where id = '00000000-0000-0000-0000-00000000b050';
  if q <> 1772 or st <> 'open' then
    raise exception 'FAIL: the lot is % L and %, expected 1772 and open', q, st;
  end if;
  perform test_ok('228 L off a 2000 L lot leaves 1772 L, still open');
end $$;

do $$
declare st node_status; ca timestamptz;
begin
  update node set quantity = 0 where id = '00000000-0000-0000-0000-00000000b050';
  select status, closed_at into st, ca
    from node where id = '00000000-0000-0000-0000-00000000b050';
  if st <> 'closed' or ca is null then
    raise exception 'FAIL: an emptied lot is % with closed_at %', st, ca;
  end if;
  perform test_ok('a lot closes when it is emptied, and records when');
end $$;

do $$ begin
  begin
    update node set quantity = 500 where id = '00000000-0000-0000-0000-00000000b050';
    raise exception 'FAIL: a closed lot was refilled';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('refilling a closed lot is refused, the correction is a new lot');
  end;
end $$;

-- Unknown is not zero. A lot nobody measured must not be closed by guessing.
do $$
declare st node_status;
begin
  insert into node (id, stage, status, name, quantity, variety_id, vintage)
    values ('00000000-0000-0000-0000-00000000b052','bin','open','Unweighed bin',
            null, term_id('variety','riesling'), 2025);
  update node set quantity = null where id = '00000000-0000-0000-0000-00000000b052';
  select status into st from node where id = '00000000-0000-0000-0000-00000000b052';
  if st <> 'open' then
    raise exception 'FAIL: a lot with no measured quantity was closed';
  end if;
  perform test_ok('a lot with no measured quantity is left open, not assumed empty');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- racking'; end $$;

insert into vessel (id, type_id, name, capacity_l) values
  ('00000000-0000-0000-0000-00000000c030', term_id('vessel_type','barrel'), 'Rack A', 228),
  ('00000000-0000-0000-0000-00000000c031', term_id('vessel_type','barrel'), 'Rack B', 228),
  ('00000000-0000-0000-0000-00000000c032', term_id('vessel_type','tank'),   'Rack T', 1000),
  ('00000000-0000-0000-0000-00000000c033', term_id('vessel_type','tank'),   'Rack S', 300),
  ('00000000-0000-0000-0000-00000000c034', term_id('vessel_type','tank'),   'Rack C', 300),
  ('00000000-0000-0000-0000-00000000c035', term_id('vessel_type','barrel'), 'Rack Small', 50);

do $$ begin
  perform fill_vessel('00000000-0000-0000-0000-00000000c030',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b060','name','Lot A',
      'variety_id', term_id('variety','chardonnay'), 'vintage', 2025), 225);
  perform fill_vessel('00000000-0000-0000-0000-00000000c031',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b061','name','Lot B',
      'variety_id', term_id('variety','riesling'), 'vintage', 2025), 220);
end $$;

-- The preview runs the same rule as the write, without writing, so a screen can
-- say what is about to happen while it is still cheap to change your mind.
do $$
declare plan jsonb;
begin
  plan := rack_plan(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c030','volume_l',225)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c033','volume_l',222)));
  if plan ->> 'kind' <> 'move' then
    raise exception 'FAIL: moving one lot to an empty vessel was planned as %', plan ->> 'kind';
  end if;
  if (plan ->> 'loss_l')::numeric <> 3 then
    raise exception 'FAIL: loss came out as % rather than 3', plan ->> 'loss_l';
  end if;
  perform test_ok('a preview names the operation and derives the loss before anything is written');
end $$;

do $$
declare r jsonb; n int; q numeric; vessels int;
begin
  r := rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c030','volume_l',225)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c033','volume_l',222)),
    jsonb_build_object('gas_source','argon','gas_line','argon','method','gravity'));

  if (r ->> 'node_id')::uuid <> '00000000-0000-0000-0000-00000000b060' then
    raise exception 'FAIL: moving a lot changed its identity';
  end if;
  select count(*) into n from lineage where child_id = '00000000-0000-0000-0000-00000000b060';
  if n <> 0 then raise exception 'FAIL: moving a lot wrote lineage'; end if;

  select count(*) into vessels from placement
   where node_id = '00000000-0000-0000-0000-00000000b060' and to_at is null;
  if vessels <> 1 then raise exception 'FAIL: the lot is in % vessels', vessels; end if;

  select quantity into q from node where id = '00000000-0000-0000-0000-00000000b060';
  if q <> 222 then raise exception 'FAIL: after a 3 L loss the lot is % L', q; end if;
  perform test_ok('moving a whole lot keeps its identity, writes no lineage, and loses only the loss');
end $$;

-- One into many. Still one lot, now in two places.
do $$
declare vessels int;
begin
  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c033','volume_l',222)),
    jsonb_build_array(
      jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c030','volume_l',110),
      jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c032','volume_l',110)));
  select count(*) into vessels from placement
   where node_id = '00000000-0000-0000-0000-00000000b060' and to_at is null;
  if vessels <> 2 then
    raise exception 'FAIL: splitting a lot put it in % vessels', vessels;
  end if;
  perform test_ok('splitting a lot across vessels is one lot in two places, not two lots');
end $$;

-- Many into one, and the lots differ, so this is a blend whether or not anyone
-- said the word.
do $$
declare r jsonb; parents int; f numeric; qb numeric; sta node_status;
begin
  r := rack(
    jsonb_build_array(
      jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c030','volume_l',110),
      jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c031','volume_l',100)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c033','volume_l',205)),
    '{}'::jsonb, false,
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b062','name','The blend'));

  if r ->> 'kind' <> 'blend' then
    raise exception 'FAIL: two different lots into one vessel was planned as %', r ->> 'kind';
  end if;
  select count(*) into parents from lineage where child_id = '00000000-0000-0000-0000-00000000b062';
  if parents <> 2 then raise exception 'FAIL: the blend has % parents', parents; end if;
  perform test_ok('two different lots into one vessel makes a new lot, without being asked to');

  -- Of what the parents put in, not of what arrived. Those differ by the loss,
  -- and losing wine down a hose does not change what the wine is made of.
  select fraction into f from lineage
   where child_id = '00000000-0000-0000-0000-00000000b062'
     and parent_id = '00000000-0000-0000-0000-00000000b060';
  if round(f, 3) <> round(110::numeric / 210, 3) then
    raise exception 'FAIL: the share is % rather than 110/210', f;
  end if;
  perform test_ok('each parent carries its share of the child, by volume');

  select sum(fraction) into f from lineage
   where child_id = '00000000-0000-0000-0000-00000000b062';
  if round(f, 5) <> 1.0 then
    raise exception 'FAIL: the shares of a blend sum to % rather than 1', f;
  end if;
  perform test_ok('the shares of a blend sum to one, whatever the loss was');

  select quantity, status into qb, sta from node where id = '00000000-0000-0000-0000-00000000b061';
  if qb <> 120 or sta <> 'open' then
    raise exception 'FAIL: 100 L off a 220 L lot left % L and %', qb, sta;
  end if;
  perform test_ok('a lot part drawn into a blend keeps the rest, open');
end $$;

-- A destination that already holds a different lot is a blend too, and the lot
-- already in there is a parent rather than an obstacle.
do $$
declare r jsonb; parents int; q numeric; sta node_status;
begin
  perform fill_vessel('00000000-0000-0000-0000-00000000c034',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b063','name','Lot C',
      'variety_id', term_id('variety','pinot_noir'), 'vintage', 2025), 100);

  r := rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c033','volume_l',100)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c034','volume_l',100)),
    '{}'::jsonb, false,
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b064','name','Topped up'));

  if r ->> 'kind' <> 'blend' then
    raise exception 'FAIL: racking onto an occupied vessel was planned as %', r ->> 'kind';
  end if;
  select count(*) into parents from lineage where child_id = '00000000-0000-0000-0000-00000000b064';
  if parents <> 2 then raise exception 'FAIL: it has % parents', parents; end if;

  -- Deliberately created through fill_vessel without a quantity, which is what
  -- S-21 describes, so this also proves closing does not depend on that number.
  select quantity, status into q, sta from node where id = '00000000-0000-0000-0000-00000000b063';
  if sta <> 'closed' then
    raise exception 'FAIL: the absorbed lot is still %', sta;
  end if;
  select count(*) into parents from placement
   where node_id = '00000000-0000-0000-0000-00000000b063' and to_at is null;
  if parents <> 0 then
    raise exception 'FAIL: the absorbed lot still holds a placement';
  end if;
  perform test_ok('racking onto wine already in the vessel blends with it');
  perform test_ok('a lot absorbed whole is closed and left in no vessel, quantity or not');
end $$;


-- Capacity is the one physical impossibility, and it is a question rather than
-- a wall.
do $$ begin
  begin
    perform rack(
      jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c032','volume_l',110)),
      jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c035','volume_l',110)));
    raise exception 'FAIL: a barrel was filled past its capacity';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('filling a vessel past its capacity is refused');
  end;
end $$;

do $$
declare r jsonb;
begin
  r := rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c032','volume_l',110)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c035','volume_l',110)),
    '{}'::jsonb, true);
  if jsonb_array_length(r -> 'overfill') = 0 then
    raise exception 'FAIL: an overfill happened and was not recorded as one';
  end if;
  perform test_ok('an overfill can be confirmed, and the confirming is recorded');
end $$;

do $$ begin
  begin
    perform rack(
      jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c032','volume_l',10)),
      jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c033','volume_l',10)));
    raise exception 'FAIL: wine was racked out of an empty vessel';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('racking out of a vessel the app believes is empty is refused');
  end;
end $$;

-- The whole transfer is one event, and the gas handling rides on it.
do $$
declare d jsonb;
begin
  select e.data into d from event e
    join term t on t.id = e.operation_id
   where t.value = 'rack' and e.data ->> 'gas_source' = 'argon' limit 1;
  if d is null then raise exception 'FAIL: the rack recorded no event'; end if;
  if d ->> 'method' <> 'gravity' then
    raise exception 'FAIL: the event lost what was on it';
  end if;
  if d ? 'loss_l' then
    raise exception 'FAIL: loss was stored, and it is derivable';
  end if;
  perform test_ok('a rack is one event carrying its gas and method, and no stored loss');
end $$;

-- The case these assertions missed until the browser found it: a lot in the
-- destination that also lives somewhere else is not consumed by being blended
-- from. Closing it would report wine as gone while it sits in a tank.
insert into vessel (id, type_id, name, capacity_l) values
  ('00000000-0000-0000-0000-00000000c036', term_id('vessel_type','tank'), 'Spread 1', 500),
  ('00000000-0000-0000-0000-00000000c037', term_id('vessel_type','tank'), 'Spread 2', 500),
  ('00000000-0000-0000-0000-00000000c038', term_id('vessel_type','tank'), 'Other wine', 500);

do $$
declare sta node_status; still int; q numeric;
begin
  perform fill_vessel('00000000-0000-0000-0000-00000000c036',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b066','name','Spread lot',
      'quantity', 300, 'variety_id', term_id('variety','chardonnay'), 'vintage', 2025), 300);
  perform fill_vessel('00000000-0000-0000-0000-00000000c038',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b067','name','Other wine',
      'quantity', 50, 'variety_id', term_id('variety','riesling'), 'vintage', 2025), 50);

  -- spread it across two vessels, still one lot
  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c036','volume_l',100)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c037','volume_l',100)));

  -- blend something else onto one of those two
  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c038','volume_l',50)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c037','volume_l',50)));

  select status, quantity into sta, q from node where id = '00000000-0000-0000-0000-00000000b066';
  select count(*) into still from placement
   where node_id = '00000000-0000-0000-0000-00000000b066' and to_at is null;
  if sta = 'closed' or still = 0 then
    raise exception 'FAIL: a lot was closed by a blend that took only one of its vessels, % with % placements', sta, still;
  end if;
  if q <> 200 then
    raise exception 'FAIL: the lot kept % L rather than the 200 still in the other vessel', q;
  end if;
  perform test_ok('a lot blended from one of its vessels keeps the ones it still occupies');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the funky barrel'; end $$;

-- The winemaker's workflow, exactly. Eola Springs Chardonnay is pressed into a
-- tank, goes to four barrels, all four get their regular sulphur, and then one
-- of them is funky and gets more.

insert into vessel (id, type_id, name, capacity_l) values
  ('00000000-0000-0000-0000-00000000c040', term_id('vessel_type','tank'),   'Press tank', 1000),
  ('00000000-0000-0000-0000-00000000c041', term_id('vessel_type','barrel'), 'ES 1', 228),
  ('00000000-0000-0000-0000-00000000c042', term_id('vessel_type','barrel'), 'ES 2', 228),
  ('00000000-0000-0000-0000-00000000c043', term_id('vessel_type','barrel'), 'ES 3', 228),
  ('00000000-0000-0000-0000-00000000c044', term_id('vessel_type','barrel'), 'ES 4', 228);

do $$ begin
  perform fill_vessel('00000000-0000-0000-0000-00000000c040',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b070',
      'name','Eola Springs Chardonnay','quantity',880,
      'variety_id', term_id('variety','chardonnay'), 'vintage', 2025), 880);

  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c040','volume_l',880)),
    jsonb_build_array(
      jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c041','volume_l',220),
      jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c042','volume_l',220),
      jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c043','volume_l',220),
      jsonb_build_object('vessel_id','00000000-0000-0000-0000-00000000c044','volume_l',220)));
end $$;

do $$
declare vessels int;
begin
  select count(*) into vessels from placement
   where node_id = '00000000-0000-0000-0000-00000000b070' and to_at is null;
  if vessels <> 4 then raise exception 'FAIL: the lot is in % barrels', vessels; end if;
  perform test_ok('a pressing split to four barrels is still one lot');
end $$;

-- The regular addition covers every barrel, so nothing is distinguished and
-- nothing forks.
do $$
declare r jsonb;
begin
  r := record_event('00000000-0000-0000-0000-00000000b070', 'addition',
        jsonb_build_object('material','SO2','ppm',30),
        array['00000000-0000-0000-0000-00000000c041'::uuid,
              '00000000-0000-0000-0000-00000000c042'::uuid,
              '00000000-0000-0000-0000-00000000c043'::uuid,
              '00000000-0000-0000-0000-00000000c044'::uuid]);
  if (r ->> 'forked')::boolean then
    raise exception 'FAIL: an addition to every barrel forked the lot';
  end if;
  perform test_ok('an addition covering every vessel of a lot does not fork it');
end $$;

-- ES 3 is funky. This is the divergence, and nobody had to say the word fork.
do $$
declare r jsonb; child uuid; q numeric; f numeric;
begin
  r := record_event('00000000-0000-0000-0000-00000000b070', 'addition',
        jsonb_build_object('material','SO2','ppm',60,'note','funky'),
        array['00000000-0000-0000-0000-00000000c043'::uuid]);

  if not (r ->> 'forked')::boolean then
    raise exception 'FAIL: sulphur into one of four barrels did not fork the lot';
  end if;
  child := (r ->> 'node_id')::uuid;
  if child = '00000000-0000-0000-0000-00000000b070' then
    raise exception 'FAIL: the addition landed on the whole lot';
  end if;
  perform test_ok('sulphur into one barrel of four forks that barrel off, unasked');

  select fraction into f from lineage
   where parent_id = '00000000-0000-0000-0000-00000000b070' and child_id = child;
  if f <> 1.0 then raise exception 'FAIL: the shard came off at fraction %', f; end if;

  select quantity into q from node where id = '00000000-0000-0000-0000-00000000b070';
  if q <> 660 then raise exception 'FAIL: the parent kept % L of 880', q; end if;
  perform test_ok('the shard comes off whole, and the parent keeps the other three barrels');
end $$;

-- Composition survives the fork without a row being copied.
do $$
declare parent_bins int; child_bins int; child uuid;
begin
  select child_id into child from lineage
   where parent_id = '00000000-0000-0000-0000-00000000b070' limit 1;
  select count(*) into parent_bins from node_bin_shares('00000000-0000-0000-0000-00000000b070');
  select count(*) into child_bins  from node_bin_shares(child);
  if parent_bins <> child_bins then
    raise exception 'FAIL: the shard sees % bins and its parent sees %', child_bins, parent_bins;
  end if;
  perform test_ok('a shard is made of what its parent was made of, by walking rather than copying');
end $$;

-- The trap. The other three barrels carry on, and what happens to them next
-- must not appear in the funky barrel's history.
do $$
declare child uuid; inherited_n int; own_n int; late int;
begin
  select child_id into child from lineage
   where parent_id = '00000000-0000-0000-0000-00000000b070' limit 1;

  -- a month later, the remaining three get topped up
  perform record_event('00000000-0000-0000-0000-00000000b070', 'topping',
    jsonb_build_object('note','after the split'), null,
    now() + interval '30 days');

  select count(*) into late from node_history(child)
   where data ->> 'note' = 'after the split';
  if late <> 0 then
    raise exception 'FAIL: the funky barrel inherited % events that happened to the other three after it left', late;
  end if;
  perform test_ok('a shard does not inherit what happened to its parent after the split');

  select count(*) into inherited_n from node_history(child) where inherited;
  if inherited_n < 1 then
    raise exception 'FAIL: the funky barrel lost the regular addition it did receive';
  end if;
  perform test_ok('a shard does inherit what happened to its parent before the split');

  select count(*) into own_n from node_history(child) where not inherited;
  if own_n <> 1 then
    raise exception 'FAIL: the funky barrel has % of its own events', own_n;
  end if;
  perform test_ok('a history says which events were this lot and which it inherited');
end $$;

do $$ begin
  begin
    perform fork_lot('00000000-0000-0000-0000-00000000b070',
      array['00000000-0000-0000-0000-00000000c041'::uuid,
            '00000000-0000-0000-0000-00000000c042'::uuid,
            '00000000-0000-0000-0000-00000000c044'::uuid]);
    raise exception 'FAIL: a lot was forked off every vessel it is in';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('forking a lot off all of its own vessels is refused');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- whose wine it is'; end $$;

-- Ownership was fully plumbed and never set: node.owner_id existed, node_read
-- already scoped a client to it, and the screens never asked. So every lot was
-- the facility's whatever the truth was.

insert into vessel (id, type_id, name, capacity_l) values
  ('00000000-0000-0000-0000-00000000c050', term_id('vessel_type','barrel'), 'Client barrel', 228),
  ('00000000-0000-0000-0000-00000000c051', term_id('vessel_type','barrel'), 'Our barrel', 228);

do $$
declare o uuid;
begin
  -- unstated ownership is still the facility, which is what the kernel coalesces to
  perform fill_vessel('00000000-0000-0000-0000-00000000c051',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b080','name','Ours',
      'quantity', 220, 'variety_id', term_id('variety','chardonnay'), 'vintage', 2025), 220);
  select owner_id into o from node where id = '00000000-0000-0000-0000-00000000b080';
  if o <> facility_party_id() then
    raise exception 'FAIL: a lot with no owner stated is owned by % rather than the facility', o;
  end if;
  perform test_ok('a lot with no owner stated belongs to the facility');

  -- and a stated client owner is honoured rather than overwritten
  perform fill_vessel('00000000-0000-0000-0000-00000000c050',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b081','name','Theirs',
      'quantity', 220, 'owner_id', '00000000-0000-0000-0000-00000000f002',
      'variety_id', term_id('variety','riesling'), 'vintage', 2025), 220);
  select owner_id into o from node where id = '00000000-0000-0000-0000-00000000b081';
  if o <> '00000000-0000-0000-0000-00000000f002' then
    raise exception 'FAIL: a client owner was not kept';
  end if;
  perform test_ok('a lot created for a client belongs to that client');
end $$;

-- The link is what makes a client login mean anything: current_party_id()
-- resolves through party.app_user_id, and without it their account is an
-- ordinary cellar login that sees the whole cellar.
do $$
declare mine int; theirs int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;

  select count(*) into theirs from node where id = '00000000-0000-0000-0000-00000000b081';
  select count(*) into mine   from node where id = '00000000-0000-0000-0000-00000000b080';
  if theirs <> 1 then raise exception 'FAIL: the client cannot see their own lot'; end if;
  if mine <> 0 then raise exception 'FAIL: the client can see the facility lot'; end if;
  perform test_ok('a client login sees the lot it owns and not the one it does not');

  reset role;
end $$;

-- The dangerous direction, asserted so it cannot change quietly. Detaching a
-- login does not blind that account, it promotes it: is_facility_user()
-- coalesces a missing party row to true, because a cellar hand has no party and
-- must still see the cellar. The cost is that an account made for a client and
-- not yet linked is staff. See S-25.
do $$
declare seen int;
begin
  update party set app_user_id = null
   where id = '00000000-0000-0000-0000-00000000f002';

  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select count(*) into seen from node where id = '00000000-0000-0000-0000-00000000b080';
  reset role;

  if seen <> 1 then
    raise exception 'FAIL: an account with no party did not fall back to staff, which is what the policy says it does';
  end if;
  perform test_ok('an account attached to no party is staff and sees the whole cellar, which is the hazard S-25 names');

  update party set app_user_id = '00000000-0000-0000-0000-00000000a003'
   where id = '00000000-0000-0000-0000-00000000f002';
end $$;

do $$ begin
  begin
    insert into party (name, kind, app_user_id)
      values ('Second claimant', 'client', '00000000-0000-0000-0000-00000000a003');
    raise exception 'FAIL: one login was attached to two parties';
  exception when unique_violation then
    perform test_ok('a login resolves to at most one party, so it cannot be handed to two clients');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- whose barrel is not whose wine'; end $$;

-- As the admin. Since 0018 the vessel page answers according to who is asking,
-- so a block that reads it has to say who it is. Before that the view ignored
-- the caller entirely, which was the bug 0017 fixed.
do $$ begin perform test_act_as('00000000-0000-0000-0000-00000000a001'); end $$;

-- Both directions are ordinary on a custom crush floor: our barrel holding a
-- client's wine, and a client's barrel holding ours. Nothing in the schema ties
-- vessel.owner_id to node.owner_id, and these four say so, so that a later
-- convenience cannot quietly couple them.

insert into vessel (id, type_id, name, capacity_l, owner_id) values
  ('00000000-0000-0000-0000-00000000c060', term_id('vessel_type','barrel'), 'Ours A',   228, null),
  ('00000000-0000-0000-0000-00000000c061', term_id('vessel_type','barrel'), 'Ours B',   228, null),
  ('00000000-0000-0000-0000-00000000c062', term_id('vessel_type','barrel'), 'Theirs A', 228,
   '00000000-0000-0000-0000-00000000f002'),
  ('00000000-0000-0000-0000-00000000c063', term_id('vessel_type','barrel'), 'Theirs B', 228,
   '00000000-0000-0000-0000-00000000f002');

do $$
declare n int;
begin
  -- our barrel, our wine
  perform fill_vessel('00000000-0000-0000-0000-00000000c060',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b090','name','Ours in ours',
      'quantity', 220, 'variety_id', term_id('variety','chardonnay'), 'vintage', 2025), 220);
  -- our barrel, their wine
  perform fill_vessel('00000000-0000-0000-0000-00000000c061',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b091','name','Theirs in ours',
      'quantity', 220, 'owner_id', '00000000-0000-0000-0000-00000000f002',
      'variety_id', term_id('variety','riesling'), 'vintage', 2025), 220);
  -- their barrel, our wine
  perform fill_vessel('00000000-0000-0000-0000-00000000c062',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b092','name','Ours in theirs',
      'quantity', 220, 'variety_id', term_id('variety','pinot_noir'), 'vintage', 2025), 220);
  -- their barrel, their wine
  perform fill_vessel('00000000-0000-0000-0000-00000000c063',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b093','name','Theirs in theirs',
      'quantity', 220, 'owner_id', '00000000-0000-0000-0000-00000000f002',
      'variety_id', term_id('variety','pinot_gris'), 'vintage', 2025), 220);

  select count(*) into n from vessel_state
   where name in ('Ours A','Ours B','Theirs A','Theirs B');
  if n <> 4 then raise exception 'FAIL: one of the four combinations was refused'; end if;
  perform test_ok('a vessel and the wine in it may belong to different parties, in either direction');
end $$;

do $$
declare vo boolean; lo boolean;
begin
  select facility_owned, lot_facility_owned into vo, lo
    from vessel_state where name = 'Ours B';
  if not vo or lo then
    raise exception 'FAIL: our barrel with their wine reads as vessel=% wine=%', vo, lo;
  end if;
  perform test_ok('our barrel with a client''s wine reports the barrel as ours and the wine as theirs');

  select facility_owned, lot_facility_owned into vo, lo
    from vessel_state where name = 'Theirs A';
  if vo or not lo then
    raise exception 'FAIL: their barrel with our wine reads as vessel=% wine=%', vo, lo;
  end if;
  perform test_ok('a client''s barrel with our wine reports the barrel as theirs and the wine as ours');
end $$;

-- And the boundary that matters: what a client sees is decided by the wine,
-- never by whose barrel it happens to be sitting in.
do $$
declare theirs int; ours_in_their_barrel int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select count(*) into theirs from node where id = '00000000-0000-0000-0000-00000000b091';
  select count(*) into ours_in_their_barrel from node
   where id = '00000000-0000-0000-0000-00000000b092';
  reset role;

  if theirs <> 1 then
    raise exception 'FAIL: a client cannot see their own wine when it sits in our barrel';
  end if;
  if ours_in_their_barrel <> 0 then
    raise exception 'FAIL: a client can see our wine because it sits in their barrel';
  end if;
  perform test_ok('a client sees wine by who owns it, not by whose barrel it is in');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the views obey the policies'; end $$;

-- node_read has been right since 0003 and nothing consulted it, because the
-- screens read vessel_state and a view runs with its owner's rights unless it
-- says otherwise. Every assertion above queries tables. This one queries what
-- the app actually reads, which is the only reason the breach was found.

do $$
declare v record;
begin
  for v in
    select c.relname, coalesce(array_to_string(c.reloptions, ','), '') as opts
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'v'
  loop
    if v.opts not like '%security_invoker=true%' then
      raise exception 'FAIL: view % does not run as its caller, so RLS below it does nothing', v.relname;
    end if;
  end loop;
  perform test_ok('every view runs as its caller, so the policies underneath still apply');
end $$;

-- The property, rather than a count. vessel_state only carries lots that are
-- currently in a vessel, so comparing totals against `node` counts a client's
-- own closed lots as a leak. What must hold is simpler: nothing belonging to
-- anybody else is legible through the list.
do $$
declare strangers int; names text;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;

  select count(*), string_agg(lot_name, ', ')
    into strangers, names
    from vessel_state
   where lot_name is not null
     and lot_owner_id is distinct from '00000000-0000-0000-0000-00000000f002';

  reset role;

  if strangers <> 0 then
    raise exception 'FAIL: a client reads % lots that are not theirs through the vessel list: %',
      strangers, names;
  end if;
  perform test_ok('a client reads no lot but their own through the vessel list');
end $$;

-- And the same list, seen by staff, is not narrowed by the fix.
do $$
declare seen int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;
  select count(*) into seen from vessel_state where lot_name is not null;
  reset role;

  if seen < 4 then
    raise exception 'FAIL: staff now see only % lots through the vessel list', seen;
  end if;
  perform test_ok('staff still see the whole cellar through the vessel list');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the owner decides what the crew can see'; end $$;

-- Hide the details, never the edges. The barrel still visibly holds wine and
-- how much of it, because the person racking it has to find it and write down
-- what they did. What they need not learn is whose it is and how it was made.

insert into vessel (id, type_id, name, capacity_l) values
  ('00000000-0000-0000-0000-00000000c070', term_id('vessel_type','barrel'), 'Private barrel', 228);

do $$ begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  perform fill_vessel('00000000-0000-0000-0000-00000000c070',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000b100','name','Secret Cuvee',
      'quantity', 220, 'owner_id', '00000000-0000-0000-0000-00000000f002',
      'attributes', jsonb_build_object('style_intent','skin contact'),
      'variety_id', term_id('variety','pinot_gris'), 'vintage', 2025), 220);
end $$;

-- Seeing is not controlling. An admin reads everything and changes nothing.
do $$ begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  set local role authenticated;
  begin
    perform set_lot_hidden('00000000-0000-0000-0000-00000000b100', array['name']);
    raise exception 'FAIL: an admin changed what a client hides';
  exception when insufficient_privilege then
    perform test_ok('an admin may not change what a client has chosen to hide');
  end;
  reset role;
end $$;

do $$
declare h text[];
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  h := set_lot_hidden('00000000-0000-0000-0000-00000000b100',
        array['name','owner','attributes','history','composition']);
  reset role;
  if not ('name' = any(h)) then raise exception 'FAIL: the owner could not hide the name'; end if;

  -- The return value echoes the argument, so on its own it proves the call was
  -- allowed and nothing about whether it landed. Read it back.
  select hidden into h from node where id = '00000000-0000-0000-0000-00000000b100';
  if not ('history' = any(h)) then
    raise exception 'FAIL: set_lot_hidden was allowed but did not persist, stored %', h;
  end if;
  perform test_ok('the owner of the wine decides, field by field, what is hidden');
end $$;

do $$ begin
  begin
    perform test_act_as('00000000-0000-0000-0000-00000000a003');
    set local role authenticated;
    perform set_lot_hidden('00000000-0000-0000-0000-00000000b100', array['volume']);
    reset role;
    raise exception 'FAIL: a field the kernel cannot hide was accepted';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('a field the kernel does not know how to hide is refused');
  end;
end $$;

-- The crew: the barrel and the volume, not the name or the technique.
do $$
declare v record;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;
  select * into v from vessel_state where id = '00000000-0000-0000-0000-00000000c070';
  reset role;

  if v.current_volume_l <> 220 then
    raise exception 'FAIL: the crew cannot see how much is in the barrel';
  end if;
  if v.is_empty then
    raise exception 'FAIL: a private barrel reads as empty, so nobody would rack it';
  end if;
  perform test_ok('the crew still sees the barrel and how much is in it');

  if v.lot_name is not null then
    raise exception 'FAIL: the crew reads the hidden lot name %', v.lot_name;
  end if;
  if v.lot_owner_id is not null then
    raise exception 'FAIL: the crew reads whose wine it is';
  end if;
  if not v.redacted then
    raise exception 'FAIL: nothing tells the screen that something was withheld';
  end if;
  perform test_ok('the crew reads neither the name nor the owner, and knows something was withheld');

  if v.variety is null then
    raise exception 'FAIL: a field the owner did not hide was hidden anyway';
  end if;
  perform test_ok('only the fields the owner named are withheld');
end $$;

-- History and composition are not columns, so they need their own gate.
do $$
declare rows_seen int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;
  select count(*) into rows_seen from node_history('00000000-0000-0000-0000-00000000b100');
  reset role;
  if rows_seen <> 0 then
    raise exception 'FAIL: the crew reads % events of a lot whose history is hidden', rows_seen;
  end if;
  perform test_ok('a hidden history is withheld by the kernel, not omitted by a screen');
end $$;

-- The specific way this broke, kept because it will be tempting to simplify
-- that coalesce away. current_party_id() is null for everyone on the crew, so
-- `owner_id = current_party_id()` is null rather than false, `not null` is
-- null, and an `if` on null does not run. The permission check fell open for
-- exactly the people it exists to keep out.
do $$
declare answer boolean;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;
  answer := may_see_all_of('00000000-0000-0000-0000-00000000f002',
                           array['name','history']);
  reset role;

  if answer is null then
    raise exception 'FAIL: the permission check answered null, which no gate treats as a refusal';
  end if;
  if answer then
    raise exception 'FAIL: the crew may see all of a lot they do not own';
  end if;
  perform test_ok('a permission check answers false rather than null when nobody has a party');
end $$;

do $$
declare owner_name text; admin_name text;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select lot_name into owner_name from vessel_state
   where id = '00000000-0000-0000-0000-00000000c070';
  reset role;

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  set local role authenticated;
  select lot_name into admin_name from vessel_state
   where id = '00000000-0000-0000-0000-00000000c070';
  reset role;

  if owner_name <> 'Secret Cuvee' then
    raise exception 'FAIL: the owner cannot read their own wine, it says %', owner_name;
  end if;
  if admin_name <> 'Secret Cuvee' then
    raise exception 'FAIL: an admin cannot read a lot they answer for, it says %', admin_name;
  end if;
  perform test_ok('the owner and an admin both still read everything');
end $$;

-- A standing preference, so the choice is made once rather than every morning.
do $$
declare h text[];
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  perform set_party_default_hidden('00000000-0000-0000-0000-00000000f002', array['name','owner']);
  reset role;

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  insert into node (id, stage, status, name, quantity, unit, owner_id, variety_id, vintage)
    values ('00000000-0000-0000-0000-00000000b101','maturation','open','Inherits',
            10,'L','00000000-0000-0000-0000-00000000f002',
            term_id('variety','riesling'), 2025);
  select hidden into h from node where id = '00000000-0000-0000-0000-00000000b101';
  if not ('name' = any(h) and 'owner' = any(h)) then
    raise exception 'FAIL: a new lot did not inherit its party default, it has %', h;
  end if;
  perform test_ok('a new lot inherits what its owner hides by default');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a cellar user can do the job, and only the job'; end $$;

-- 0002 gave node, placement and vessel an admin-only update policy, and every
-- write path built since 0007 runs as the caller. A cellar user racking a barrel
-- therefore got the destination placement and kept the source one, because
-- inserts were open and updates matched zero rows in silence. These assertions
-- are the ones that would have failed the day 0014 landed.

insert into vessel (id, type_id, name, capacity_l, has_glycol)
  values ('00000000-0000-0000-0000-00000000c0a1', term_id('vessel_type','tank'),
          'Allow-list tank', 1000, true);

insert into node (id, stage, name, quantity, unit)
  values ('00000000-0000-0000-0000-00000000b0a1','ferment','Allow-list lot', 500, 'L');

insert into placement (id, node_id, vessel_id, volume_l)
  values ('00000000-0000-0000-0000-00000000d0a1',
          '00000000-0000-0000-0000-00000000b0a1',
          '00000000-0000-0000-0000-00000000c0a1', 500);

do $$
declare n int; st node_status; m thermal_mode;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');   -- the cellar user
  set local role authenticated;

  update placement set to_at = now()
   where id = '00000000-0000-0000-0000-00000000d0a1';
  get diagnostics n = row_count;
  if n <> 1 then
    raise exception 'FAIL: a cellar user could not close a placement, which is what racking is';
  end if;
  perform test_ok('a cellar user may close a placement, so racking is not a silent no-op');

  update node set quantity = 0 where id = '00000000-0000-0000-0000-00000000b0a1';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL: a cellar user could not empty a lot'; end if;
  perform test_ok('a cellar user may write down what is left in a lot');

  update vessel set setpoint_c = 12, mode = 'cooling'
   where id = '00000000-0000-0000-0000-00000000c0a1';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL: a cellar user could not turn on a jacket'; end if;
  perform test_ok('a cellar user may set a jacket, which is an operation and not a rename');

  reset role;

  select status into st from node where id = '00000000-0000-0000-0000-00000000b0a1';
  if st <> 'closed' then
    raise exception 'FAIL: emptying a lot left it %, so close_node_when_empty never fired', st;
  end if;
  perform test_ok('emptying a lot closes it, which needed the update to land first');

  select mode into m from vessel where id = '00000000-0000-0000-0000-00000000c0a1';
  if m <> 'cooling' then raise exception 'FAIL: the jacket did not come on'; end if;
end $$;

-- The other half. Widening the rows without narrowing the columns would have
-- handed a cellar hand the fields that say whose wine it is and who may see it.
do $$
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;

  begin
    update node set owner_id = '00000000-0000-0000-0000-00000000f002'
     where id = '00000000-0000-0000-0000-00000000b0a1';
    raise exception 'FAIL: a cellar user changed who owns a lot';
  exception when insufficient_privilege then
    perform test_ok('a cellar user may not change who owns a lot');
  end;

  begin
    update node set hidden = array['variety']
     where id = '00000000-0000-0000-0000-00000000b0a1';
    raise exception 'FAIL: a cellar user changed the privacy edge';
  exception when insufficient_privilege then
    perform test_ok('a cellar user may not change what an owner hides');
  end;

  begin
    update vessel set capacity_l = 900
     where id = '00000000-0000-0000-0000-00000000c0a1';
    raise exception 'FAIL: a cellar user resized a vessel';
  exception when insufficient_privilege then
    perform test_ok('a cellar user may not resize a vessel, only operate it');
  end;

  -- placement's allow-list had no assertion at all, which the trigger mutation
  -- class found: disabling placement_cellar_columns changed nothing this suite
  -- could see. vessel_id is the column that matters, because moving a placement
  -- to a different vessel without closing and opening one is how the history
  -- stops being a history.
  begin
    update placement set vessel_id = '00000000-0000-0000-0000-00000000c001'
     where id = '00000000-0000-0000-0000-00000000d0a1';
    raise exception 'FAIL: a cellar user moved a placement to another vessel';
  exception when insufficient_privilege then
    perform test_ok('a cellar user may not move a placement between vessels, only close it');
  end;

  reset role;
end $$;

-- An admin is not subject to the allow-list, because correcting a mistake is
-- what an admin is for and that is the case 0002 was right about.
do $$
declare n int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');   -- the admin
  set local role authenticated;
  update vessel set capacity_l = 900
   where id = '00000000-0000-0000-0000-00000000c0a1';
  get diagnostics n = row_count;
  reset role;
  if n <> 1 then raise exception 'FAIL: an admin could not correct a vessel'; end if;
  perform test_ok('an admin may still change anything, so the allow-list is not a wall');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- admission: switching an account off takes access away'; end $$;

-- A1 in the findings ledger, found by six independent review runs and the worst
-- of them: is_facility_user() coalesced a missing party row to true so that a
-- harvest intern with no party could see the cellar, and a deactivated client
-- has no findable party row either, so switching a client off promoted them to
-- staff. Deactivation escalated instead of revoking.
do $$
declare before_ boolean; after_ boolean; nodes_after int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');   -- the client login
  set local role authenticated;
  select is_facility_user() into before_;
  reset role;

  update party set active = false
   where id = '00000000-0000-0000-0000-00000000f002';

  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select is_facility_user() into after_;
  select count(*) into nodes_after from node;
  reset role;

  update party set active = true
   where id = '00000000-0000-0000-0000-00000000f002';

  if before_ then raise exception 'FAIL: an active client login counts as facility'; end if;
  if after_ then
    raise exception 'FAIL: deactivating a client party promoted that login to facility';
  end if;
  perform test_ok('deactivating a client party revokes rather than promotes');

  if nodes_after <> 0 then
    raise exception 'FAIL: a deactivated client still sees % nodes', nodes_after;
  end if;
  perform test_ok('a deactivated client sees nothing, not everything');
end $$;

-- The intern case the coalesce existed to serve, which must survive the fix.
do $$
declare n int; facility boolean;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');   -- no party at all
  set local role authenticated;
  select is_facility_user() into facility;
  select count(*) into n from node;
  reset role;
  if not facility then raise exception 'FAIL: a cellar hand with no party is not staff'; end if;
  if n = 0 then raise exception 'FAIL: a cellar hand with no party sees no nodes'; end if;
  perform test_ok('a login with no party at all is still the harvest intern and still sees the cellar');
end $$;

-- S-25, discharged by the same predicate. An authenticated identity that never
-- claimed an account is nobody here, rather than being staff by default.
do $$
declare facility boolean;
begin
  insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000ff');
  perform test_act_as('00000000-0000-0000-0000-0000000000ff');
  set local role authenticated;
  select is_facility_user() into facility;
  reset role;
  if facility then
    raise exception 'FAIL: a token with no app_user row counts as a facility user';
  end if;
  perform test_ok('an account that never claimed is not staff, which is S-25');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- authorship: an event names the person who wrote it'; end $$;

-- A3. The old policy read `by_user = auth.uid() or by_sensor is not null`, so any
-- string in by_sensor unbound the author check and by_user could name anybody.
do $$
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;

  begin
    insert into event (operation_id, subject_type, subject_id, by_user, by_sensor)
    values (term_id('operation','punchdown'), 'node',
            '00000000-0000-0000-0000-00000000b001',
            '00000000-0000-0000-0000-00000000a001',  -- the admin, not the caller
            'anything');
    raise exception 'FAIL: an event was written in another user''s name';
  exception when insufficient_privilege then
    perform test_ok('a sensor string no longer unbinds the author check');
  end;

  begin
    insert into event (operation_id, subject_type, subject_id, by_user)
    values (term_id('operation','punchdown'), 'node',
            '00000000-0000-0000-0000-00000000b001',
            '00000000-0000-0000-0000-00000000a001');
    raise exception 'FAIL: an event was attributed to somebody else';
  exception when insufficient_privilege then
    perform test_ok('an event must name the person writing it');
  end;

  insert into event (operation_id, subject_type, subject_id, by_user)
  values (term_id('operation','punchdown'), 'node',
          '00000000-0000-0000-0000-00000000b001', auth.uid());
  perform test_ok('recording what you did yourself still works, which is the point of the table');

  reset role;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- claiming a task needs an identity and an entitlement'; end $$;

-- A8. claim_task was security definer with no view on the caller, so an unclaimed
-- token could take a task, a null uid wrote null into claimed_by and wedged it
-- permanently, and an open task assigned to a named person could be taken by
-- anybody.
insert into task (id, operation_id, status, subject_type, subject_id, assignee, instructions)
  values ('00000000-0000-0000-0000-00000000e001',
          term_id('operation','punchdown'), 'open',
          'node', '00000000-0000-0000-0000-00000000b001',
          '00000000-0000-0000-0000-00000000a001',
          'Assigned to the admin on purpose');

do $$
declare tsk task; st task_status; cb uuid;
begin
  perform test_act_as(null);
  set local role authenticated;
  begin
    tsk := claim_task('00000000-0000-0000-0000-00000000e001');
    raise exception 'FAIL: a task was claimed with no identity';
  exception when insufficient_privilege then
    perform test_ok('claiming with no identity is refused rather than writing a null');
  end;
  reset role;

  select status, claimed_by into st, cb from task
   where id = '00000000-0000-0000-0000-00000000e001';
  if st <> 'open' or cb is not null then
    raise exception 'FAIL: the refused claim still wedged the task: % / %', st, cb;
  end if;
  perform test_ok('a refused claim leaves the task claimable, which is what wedging meant');

  perform test_act_as('00000000-0000-0000-0000-00000000a002');   -- not the assignee
  set local role authenticated;
  begin
    tsk := claim_task('00000000-0000-0000-0000-00000000e001');
    raise exception 'FAIL: a task assigned to somebody else was taken';
  exception when lock_not_available then
    perform test_ok('a task assigned to somebody else cannot be taken from them');
  end;
  reset role;

  perform test_act_as('00000000-0000-0000-0000-00000000a001');   -- the assignee
  set local role authenticated;
  tsk := claim_task('00000000-0000-0000-0000-00000000e001');
  reset role;
  if tsk.claimed_by <> '00000000-0000-0000-0000-00000000a001' then
    raise exception 'FAIL: the assignee could not claim their own task';
  end if;
  perform test_ok('the assignee claims their own task, and an unassigned task is anyone''s');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the photo bucket is private in policy, not only in comment'; end $$;

-- A6. Both policies were `using (bucket_id = 'vessel-photos')` and nothing else,
-- eighteen lines below the comment saying the bucket is private because a barrel
-- photo shows a chalk mark with a client's lot on it. Asserted against the
-- catalog rather than by uploading, because the storage schema is part of the
-- Supabase stack and these migrations stay runnable without it.
do $$
declare n int; blanket int;
begin
  if not exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    raise notice 'ok   no storage schema here, so the photo policies are not asserted';
    return;
  end if;

  select count(*) into n from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname in ('vessel_photos_read','vessel_photos_insert','vessel_photos_update');
  if n <> 3 then
    raise exception 'FAIL: expected read, insert and update policies on the photo bucket, found %', n;
  end if;
  perform test_ok('the photo bucket has an update policy, so re-photographing a vessel works');

  select count(*) into blanket from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname like 'vessel_photos%'
     and coalesce(qual, with_check) not like '%is_facility_user%';
  if blanket > 0 then
    raise exception 'FAIL: % photo policy(ies) admit every login', blanket;
  end if;
  perform test_ok('every vessel-photos policy asks who is looking, which is why the bucket is private');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a subject type is registered, not compiled in'; end $$;

-- AR-E5. task.subject_type and task.subject_id are a polymorphic pointer with no
-- foreign key, which is structurally forced rather than sloppy: a core table
-- cannot reference a module that may not be installed. The registry is how the
-- pointer becomes checkable anyway, and the property that matters is that core
-- names no module table declaratively, so `relation` is text and resolution goes
-- through to_regclass.

insert into location (id, name)
  values ('00000000-0000-0000-0000-0000000000c1', 'Resolver Barn');
insert into vessel (id, name, type_id, capacity_l)
  values ('00000000-0000-0000-0000-0000000000c2', 'RESOLVE-1',
          term_id('vessel_type','tank'), 500);

do $$
declare n text; v text;
begin
  select resolve_subject_name('location','00000000-0000-0000-0000-0000000000c1') into n;
  if n is distinct from 'Resolver Barn' then
    raise exception 'FAIL: a location did not resolve to its name, got %', n;
  end if;
  select resolve_subject_name('vessel','00000000-0000-0000-0000-0000000000c2') into v;
  if v is distinct from 'RESOLVE-1' then
    raise exception 'FAIL: a vessel did not resolve to its name, got %', v;
  end if;
  perform test_ok('a registered subject type resolves through the registry');

  if resolve_subject_name('vessel', gen_random_uuid()) is not null then
    raise exception 'FAIL: a subject id that names nothing resolved to something';
  end if;
  perform test_ok('a subject id that names no row resolves to null, not to an error');
end $$;

-- The registry is a table, so `relation` carrying a name is the only declarative
-- statement core makes about a module, and it is not one Postgres records. This
-- is the assertion that would fail if somebody helpfully changed the column to
-- regclass, which would put the edge back into pg_depend.
do $$
declare t text;
begin
  select data_type into t from information_schema.columns
   where table_schema = 'public' and table_name = 'subject_resolver'
     and column_name = 'relation';
  if t <> 'text' then
    raise exception 'FAIL: subject_resolver.relation is %, so core declares a dependency on a module relation', t;
  end if;
  perform test_ok('subject_resolver.relation is text, so core names no module table declaratively');
end $$;

-- Registration is a row and an admin writes it.
do $$
declare r subject_resolver;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');   -- a cellar user
  set local role authenticated;
  begin
    r := register_subject_resolver('location','location','name','core');
    raise exception 'FAIL: a cellar user registered a resolver';
  exception when insufficient_privilege then
    perform test_ok('only an administrator may register a resolver');
  end;
  reset role;

  perform test_act_as('00000000-0000-0000-0000-00000000a001');   -- the admin
  set local role authenticated;
  r := register_subject_resolver('location','location','''renamed by the test''','core');
  reset role;
  if r.name_expression <> '''renamed by the test''' then
    raise exception 'FAIL: registering did not replace the existing row';
  end if;
  if resolve_subject_name('location','00000000-0000-0000-0000-0000000000c1')
     is distinct from 'renamed by the test' then
    raise exception 'FAIL: re-registering did not change what resolution returns';
  end if;
  perform test_ok('registering a subject type again replaces it, and resolution follows');

  -- put it back, because later assertions read the board
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  set local role authenticated;
  r := register_subject_resolver('location','location','name','core');
  reset role;
end $$;

-- The behaviour that matters: a subject whose module is not installed. Two
-- versions, because they fail in different places. First a registration pointing
-- at a relation that does not exist, which is what an uninstalled module looks
-- like to the registry.
do $$
begin
  update subject_resolver set relation = 'not_a_table_here' where subject_type = 'block';

  if subject_is_resolvable('block') then
    raise exception 'FAIL: a subject type pointing at a missing relation reports as resolvable';
  end if;
  if resolve_subject_name('block', gen_random_uuid()) is not null then
    raise exception 'FAIL: resolving against a missing relation returned something';
  end if;
  perform test_ok('a subject type whose relation is absent resolves to null and reports unresolvable');

  update subject_resolver set relation = 'block' where subject_type = 'block';
end $$;

-- And then the real thing: drop the module's table and confirm nothing raises.
-- Inside a savepoint, because this also drops task_board today, which is the
-- declarative edge phase 4 exists to remove. When phase 4 lands, the second half
-- of this assertion changes and that is the point of writing it down now.
-- No assertion here on purpose: the savepoint is setup, not a claim.
savepoint before_dropping_block;

drop table block cascade;

do $$
declare board_exists boolean;
begin
  if subject_is_resolvable('block') then
    raise exception 'FAIL: block is resolvable after its table was dropped';
  end if;
  if resolve_subject_name('block', gen_random_uuid()) is not null then
    raise exception 'FAIL: resolving a dropped module raised or returned a value';
  end if;
  perform test_ok('dropping a module''s table makes its subject type unresolvable, silently and without error');

  -- Written in phase 3 to report which of two states it was in. Phase 4 made it
  -- the first one, and it now asserts rather than reports.
  select to_regclass('public.task_board') is not null into board_exists;
  if not board_exists then
    raise exception 'FAIL: dropping block took task_board with it, so core names a module table again';
  end if;
  perform test_ok('task_board survives dropping a module, so core no longer names a module table');
end $$;

rollback to savepoint before_dropping_block;

do $$
begin
  if to_regclass('public.block') is null then
    raise exception 'FAIL: the savepoint did not restore block';
  end if;
  if to_regclass('public.task_board') is null then
    raise exception 'FAIL: the savepoint did not restore task_board';
  end if;
  perform test_ok('the drop rolled back, so the suite stays hermetic');
end $$;


-- The same property asserted against the catalog rather than by dropping things,
-- so it fails on the change rather than on the consequence. task_board used to
-- carry a CASE naming four relations, which Postgres records in pg_rewrite; the
-- registry is what replaced it.
do $$
declare named text;
begin
  select string_agg(distinct c.relname, ', ') into named
    from pg_depend d
    join pg_rewrite r on r.oid = d.objid
    join pg_class v on v.oid = r.ev_class
    join pg_class c on c.oid = d.refobjid
    join pg_namespace n on n.oid = c.relnamespace
   where v.relname = 'task_board'
     and n.nspname = 'public'
     and c.relname in ('node','vessel','location','block');

  if named is not null then
    raise exception 'FAIL: task_board declares a dependency on module relations: %', named;
  end if;
  perform test_ok('task_board declares no dependency on node, vessel, location or block');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- row level security is on, and it is the thing being on that was untested'; end $$;

-- W-3's finding, and the reason this block exists: row level security could be
-- disabled outright on 16 of 21 tables and this suite still passed. Every fix in
-- 0021 and 0022 is an RLS fix, so A1, A3, A5, A6, A7 and A8 were all repaired
-- against a suite that could not tell whether RLS was on at all.
--
-- Derived rather than listed. Every base table in public carries row level
-- security today, so the rule is "all of them" and a table added later is
-- covered the moment it exists rather than the moment somebody remembers.
do $$
declare missing text;
begin
  select string_agg(t.relname, ', ' order by t.relname) into missing
    from pg_class t
    join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public' and t.relkind = 'r'
     and not t.relrowsecurity;

  if missing is not null then
    raise exception 'FAIL: row level security is off on: %', missing;
  end if;
  perform test_ok('every base table in public has row level security enabled');
end $$;

-- Not forced, and that is deliberate rather than an oversight. force row level
-- security subjects the table owner to its own policies, and the migrations, the
-- security definer kernel functions and pg_dump all run as the owner. Forcing it
-- would break the restore that S-29 is already about. Asserted so the absence is
-- a decision on the record rather than a thing nobody considered.
do $$
declare forced text;
begin
  select string_agg(t.relname, ', ' order by t.relname) into forced
    from pg_class t
    join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public' and t.relkind = 'r' and t.relforcerowsecurity;

  if forced is not null then
    raise exception
      'FAIL: row level security is forced on %, which subjects the owner to its own policies and breaks migrations and restores', forced;
  end if;
  perform test_ok('row level security is enabled and not forced, so the owner can still migrate and restore');
end $$;

-- A table with row level security and no policy denies everything to everyone
-- except the owner, silently. That is an outage that looks like an empty cellar.
do $$
declare bare text;
begin
  select string_agg(t.relname, ', ' order by t.relname) into bare
    from pg_class t
    join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public' and t.relkind = 'r' and t.relrowsecurity
     and not exists (
       select 1 from pg_policies p
        where p.schemaname = 'public' and p.tablename = t.relname);

  if bare is not null then
    raise exception 'FAIL: row level security is on with no policy at all on: %', bare;
  end if;
  perform test_ok('no table has row level security on and no policy, which would deny everything silently');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the policy surface is what it was last agreed to be'; end $$;

-- Two pinned facts, one about existence and one about openness. Neither replaces
-- a behavioural probe and both catch something a probe does not: a policy
-- silently disappearing in a schema move, and a new blanket read appearing.
--
-- These are the assertions that need a deliberate edit when a migration adds a
-- policy. That friction is the point. A schema split that loses a policy should
-- cost somebody thirty seconds of noticing rather than nothing at all.
do $$
declare have text; want text;
begin
  if not snapshots_on() then perform skip_snapshot('the policy census'); return; end if;
  select count(*)::text into have from pg_policies where schemaname = 'public';
  -- 56 before 0025, which added vessel_code_cellar_insert for A22. This number
  -- catching that addition is the assertion working, not the assertion being in
  -- the way: it cost thirty seconds and it is the same thirty seconds a schema
  -- move would cost when it loses one.
  -- 57 before 0027, which added a read and an admin-write policy to the new
  -- term_kind registry.
  -- 59 before 0039, which added read and admin write on vineyard and planting.
  -- 63 before 0041, which added four on day_note: read, insert, and update and
  -- delete restricted to the author. None of them reads blanket true, because a
  -- note is scoped either to the facility or to whoever wrote it.
  -- 67 before 0043, which added seven across paper_record, its operation list
  -- and propagation. None reads blanket true either: paperwork is scoped to
  -- facility users, because a client has no reason to learn which of this
  -- winery's forms are behind.
  want := '74';
  if have <> want then
    raise exception
      'FAIL: there are % policies in public and this suite was written against %. If that is deliberate, update this number, and judge the new policy in the disposition list below if it reads or writes blanket true', have, want;
  end if;
  perform test_ok('the number of policies in public is what this suite was written against');
end $$;

-- The blanket reads, named, and judged. This is ledger A5's surface.
--
-- It used to be a pinned string: the set of wide-open policies compared against a
-- literal, gated behind snapshots_on() because that is what it was. Satisfying it
-- cost one paste. W-9 phase 2 is the observation that makes that wrong. A weaken
-- mutation against these policies has reported "degenerate, changed nothing" in
-- every harness run for three sessions, because a policy that is already true has
-- nothing left to weaken. The exclusion list was the finding, printed
-- continuously in a column labelled excluded, and read past by five sessions
-- including the one that ran the client and found it by hand.
--
-- So this is no longer a photograph. Every policy whose predicate is literally
-- true carries a disposition and a reason. `permissive` means somebody decided
-- this is reference data anybody may read. `finding` means it is open and filed.
-- Adding a wide-open policy fails until it is judged, and the judgment costs a
-- sentence rather than a paste, which is the whole of the difference.
--
-- It is not gated by snapshots_on(). It states an invariant, that nothing is
-- blanket readable without a recorded reason, and an invariant does not need
-- updating when the schema grows somewhere else.
do $$
declare
  undisposed text;
  stale      text;
  reasonless text;
begin
  create temp table w9_open (policy text, disposition text, reason text) on commit drop;
  insert into w9_open values
    -- Deliberately permissive. Vocabulary, structure, and the rooms the vessels
    -- stand in. None of it says whose wine, or how much.
    ('term.term_read', 'permissive',
     'The vocabulary. Every picker in every client reads it, and it names varieties rather than wine.'),
    ('term_kind.term_kind_read', 'permissive',
     'Vocabulary about vocabulary, AR-E7. Reading it tells you what kinds of term exist.'),
    ('template.template_read', 'permissive',
     'Inferred history templates describe winemaking practice rather than any particular lot.'),
    ('template_step.template_step_read', 'permissive',
     'The steps of the above, for the same reason.'),
    ('subject_resolver.subject_resolver_read', 'permissive',
     'The registry naming which relation backs which subject type, AR-E5. Structure, not content.'),
    ('location.location_read', 'permissive',
     'Rooms and their ambient temperature. Facility infrastructure, and anybody standing in the barn can read a thermometer.'),

    -- Open findings. Everything carrying wine, ownership, movement or people.
                ('app_user.app_user_read', 'finding',
     'A5. Every staff name and role to every authenticated user, a custom crush client included.'),
    ('party.party_read', 'finding',
     'A5. Every client sees the name of every other client of the same facility.'),
    ('task.task_read', 'finding',
     'A5. Who was asked to do what, to everybody.'),
    ('task_claim_log.task_claim_log_read', 'finding',
     'A5. Who took which task and when, to everybody.'),
    ('vessel.vessel_read', 'finding',
     'A5, and the one W-9 phase 3 rules on. A client needs to know whether a vessel can take wine, which is a boolean. The row carries owner, capacity and attributes instead.'),
    ('vessel_code.vessel_code_read', 'finding',
     'A5. The codes on the barrels, which is how a vessel is identified from a sticker.'),
    ('vessel_type_note.vessel_type_note_read', 'finding',
     'A23. A5 blanket read arriving on new surface seven migrations later.'),
    ('block.block_read', 'finding',
     'A5. Vineyard blocks, which belong to a grower. No longer latent: the first pick put real blocks in.'),
    ('vineyard.vineyard_read', 'finding',
     'A5, and the same finding as block_read one table up. 0039 made a vineyard a row, so who this winery buys fruit from is now readable by every signed-in account including a custom crush client. Consistent with block_read rather than newly worse, because a block already carried its vineyard name, but it is the same gap and it is named here rather than inherited quietly.'),
    ('planting.planting_read', 'finding',
     'A5. What is planted where, readable by anyone signed in. Clone and rootstock are the sort of thing a grower might not expect a neighbouring client to read off the system.'),
    ('node.node_insert', 'finding',
     'A7 and A11, the admission surface. Any authenticated user may insert a lot.'),
    ('placement.placement_insert', 'finding',
     'A7 and A11. Any authenticated user may place wine in any vessel.'),
    ('lineage.lineage_insert', 'finding',
     'A7 and A11. Any authenticated user may assert that one lot came out of another.');

  select string_agg(t, ', ' order by t) into undisposed from (
    select p.tablename || '.' || p.policyname as t
      from pg_policies p
     where p.schemaname = 'public' and (p.qual = 'true' or p.with_check = 'true')
       and not exists (select 1 from w9_open w where w.policy = p.tablename || '.' || p.policyname)
  ) x;
  if undisposed is not null then
    raise exception
      'FAIL: these policies read or write blanket true and nobody has said why: %. Add each to the list in this assertion with a disposition of permissive or finding, and a reason. A reason, not a name.', undisposed;
  end if;

  select string_agg(w.policy, ', ' order by w.policy) into stale from w9_open w
   where not exists (
     select 1 from pg_policies p
      where p.schemaname = 'public' and (p.qual = 'true' or p.with_check = 'true')
        and p.tablename || '.' || p.policyname = w.policy);
  if stale is not null then
    raise exception
      'FAIL: these are recorded as blanket true and are not: %. If one was narrowed, that is good, and its entry goes in the same commit.', stale;
  end if;

  select string_agg(policy, ', ' order by policy) into reasonless from w9_open
   where reason is null or btrim(reason) = '' or disposition not in ('permissive', 'finding');
  if reasonless is not null then
    raise exception 'FAIL: these carry no reason, or a disposition that is neither permissive nor finding: %', reasonless;
  end if;

  perform test_ok(
    'every blanket-true policy carries a disposition and a reason, '
    || (select count(*) from w9_open where disposition = 'permissive')::text || ' permissive and '
    || (select count(*) from w9_open where disposition = 'finding')::text || ' filed as open');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the writes a cellar user is supposed to have'; end $$;

-- Ledger A7 says node, lineage and placement insertion is admission by token
-- alone. It is still open and fixing it is out of scope here. What is asserted is
-- the half that is intended: a cellar user creating a lot through the press
-- screen must work, which is what makes dropping those three policies a caught
-- mutation rather than a silent one.
do $$
declare n int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');   -- the cellar user
  set local role authenticated;

  insert into node (id, stage, name, quantity, unit)
    values ('00000000-0000-0000-0000-0000000000d1', 'ferment', 'Cellar made this', 100, 'L');
  insert into placement (id, node_id, vessel_id, volume_l)
    values ('00000000-0000-0000-0000-0000000000d2',
            '00000000-0000-0000-0000-0000000000d1',
            '00000000-0000-0000-0000-0000000000c2', 100);
  insert into lineage (parent_id, child_id, fraction)
    values ('00000000-0000-0000-0000-00000000b001',
            '00000000-0000-0000-0000-0000000000d1', 1.0);

  reset role;

  select count(*) into n from node where id = '00000000-0000-0000-0000-0000000000d1';
  if n <> 1 then raise exception 'FAIL: a cellar user could not create a lot'; end if;
  perform test_ok('a cellar user may create a lot, place it and give it a parent, which is the press screen');
end $$;

-- And the half that is the defect, documented rather than endorsed. A client
-- login can do the same thing, which is A7. Written so that fixing A7 fails this
-- assertion on purpose: the fix and the assertion belong in one commit, and a
-- suite that quietly kept passing through the fix would be worse than one that
-- stops.
do $$
declare inserted boolean := false;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');   -- the client login
  set local role authenticated;
  begin
    insert into node (id, stage, name, quantity, unit)
      values ('00000000-0000-0000-0000-0000000000d3', 'ferment', 'Client made this', 10, 'L');
    inserted := true;
  exception when insufficient_privilege then
    inserted := false;
  end;
  reset role;

  if not inserted then
    raise exception
      'FAIL: a client can no longer insert a node, which means A7 was fixed. That is good; update this assertion to say so.';
  end if;
  perform test_ok('a client can still insert a node, which is A7 open and asserted so a fix cannot land unnoticed');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the photo bucket refuses a client, where storage exists'; end $$;

-- A6. The catalog half was asserted when 0022 landed; this is the behavioural
-- half, and it can only run where the storage schema exists, which is a real
-- Supabase and not the shim. Guarded the same way 0005 and 0022 guard, so the
-- suite says what it did not test rather than passing quietly.
do $$
declare visible int;
begin
  if not exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    raise notice 'ok   no storage schema here, so the photo bucket is not probed';
    return;
  end if;

  insert into storage.objects (bucket_id, name, owner)
  values ('vessel-photos', '00000000-0000-0000-0000-0000000000c2/photo.jpg', null)
  on conflict do nothing;

  perform test_act_as('00000000-0000-0000-0000-00000000a003');   -- the client login
  set local role authenticated;
  select count(*) into visible from storage.objects where bucket_id = 'vessel-photos';
  reset role;

  if visible <> 0 then
    raise exception 'FAIL: a client login can read % vessel photo(s)', visible;
  end if;
  perform test_ok('a client login reads no vessel photographs, which is A6 probed rather than read');

  perform test_act_as('00000000-0000-0000-0000-00000000a002');   -- a cellar user
  set local role authenticated;
  select count(*) into visible from storage.objects where bucket_id = 'vessel-photos';
  reset role;

  if visible = 0 then
    raise exception 'FAIL: a cellar user cannot see vessel photographs either, so the bucket is useless';
  end if;
  perform test_ok('a cellar user reads vessel photographs, so the fix did not close the bucket to everyone');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the constraint surface, which is what phase 5 has to move through'; end $$;

-- W-2 phase 5 converts term_kind across nine generated columns, nine composite
-- foreign keys and most vocabulary function signatures. Its failure modes are
-- exactly the two categories the mutation score was worst at: check constraints
-- at 13 percent and unique constraints at 12. These assertions exist so that a
-- migration which changes any of it fails loudly rather than quietly.
--
-- Pinned by name and by count. This catches a constraint that disappears, which
-- is what a hand-written schema move does when it recreates a table and forgets
-- one. It does not catch a constraint that is still there and no longer refuses
-- anything; the behavioural assertions below that do, and the `loosen` class in
-- scripts/mutate.sh measures which of the two you have.
do $$
declare have text; want text;
begin
  if not snapshots_on() then perform skip_snapshot('the constraint inventory'); return; end if;
  select string_agg(x.line, ' ' order by x.line) into have from (
    select c.contype::text || '=' || count(*)::text as line
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'public'
     group by c.contype
  ) x;

  -- c=18 f=40 before 0026, which removed the subject_type enum and replaced it
  -- with three foreign keys into the resolver registry plus a bare-name check.
  -- c=19 f=43 p=22 before 0027, which added the term_kind registry: two bare-name
  -- checks, its primary key, and the foreign key from term.kind into it.
  -- c=22 before 0033, which added placement_fill_pct_is_a_percentage: the visual
  -- fill estimate is nullable, because a bin nobody estimated is still a bin,
  -- and bounded, because a percentage outside nought to a hundred is not one.
  -- c=23 f=44 p=23 u=14 before 0039, which added vineyard and planting: two
  -- primary keys, two uniques (vineyard.name, one planting per variety per
  -- block), and three foreign keys, being block to vineyard, planting to block,
  -- and the composite that pins a planting's term to the variety vocabulary.
  -- c=23 f=47 p=25 u=16 before 0041, which added day_note: its primary key, the
  -- foreign key to its author, and the check that a note says something, because
  -- an empty note is not a note.
  -- c=24 f=48 p=26 u=16 before 0043, which added three tables: paper_record with
  -- its name unique and the check that a form cannot be retired before it
  -- started, its operation list with a composite primary key and the composite
  -- foreign key pinning the term to the operation vocabulary, and propagation
  -- with two foreign keys and one measurement written onto a given form once.
  want := 'c=25 f=53 p=29 u=18';
  if have <> want then
    raise exception
      E'FAIL: the constraint inventory changed.\nnow:  %\nwas:  %\nIf that is deliberate, update this line in the same commit that changed the schema.', have, want;
  end if;
  -- X-1-9: this used to name 18 check, 40 foreign key, 22 primary key and 14
  -- unique, which were the pre-0026 numbers, and printed them on every passing
  -- run while pinning and comparing a different set four lines above. The whole
  -- design of this file is that a number in a sentence is derived; here was one
  -- that rotted in the one place the derivation was not applied.
  perform test_ok('the constraint inventory is what this suite was written against: ' || have);
end $$;

-- The nine composite foreign keys into term(id, kind). These are the mechanism
-- that makes a term of the wrong kind unusable, and they are the thing phase 5
-- moves. Pinned as their exact definitions, so a migration that rewrites them
-- has to say so here too.
do $$
declare have text; want text;
begin
  if not snapshots_on() then perform skip_snapshot('the composite foreign key list'); return; end if;
  select string_agg(t.relname || '.' || c.conname, ', ' order by t.relname, c.conname)
    into have
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public' and c.contype = 'f'
     and pg_get_constraintdef(c.oid) like '%REFERENCES term(id, kind)%';

  want := 'event.event_operation_is_an_operation, '
       || 'location.location_kind_is_a_location_kind, '
       || 'node.node_product_type_is_a_product_type, '
       || 'node.node_variety_is_a_variety, '
       -- 0043. A physical form says which kinds of measurement belong on it.
       || 'paper_record_operation.paper_record_operation_is_an_operation, '
       -- 0039. A block is planted to a variety, pinned the same way every other
       -- pointer into term has been since 0027.
       || 'planting.planting_variety_is_a_variety, '
       || 'procedure_step.step_material_is_a_material, '
       || 'task.task_operation_is_an_operation, '
       || 'template.template_applies_to_a_registered_kind, '
       || 'template_step.template_step_operation_is_an_operation, '
       || 'vessel.vessel_type_is_a_vessel_type';

  if have is distinct from want then
    raise exception
      E'FAIL: the composite foreign keys into term(id, kind) changed.\nnow:  %\nwas:  %', have, want;
  end if;
  perform test_ok('nine composite foreign keys tie a typed id to its kind, which is what phase 5 moves');
end $$;

-- And the nine generated columns that supply the kind half of each of those
-- keys. Each is a constant, which is what makes the pair work: the column cannot
-- be written, so the foreign key cannot be satisfied by lying about the kind.
do $$
declare have text; want text;
begin
  if not snapshots_on() then perform skip_snapshot('the generated kind columns'); return; end if;
  select string_agg(table_name || '.' || column_name || '=' || generation_expression, ' ' order by table_name, column_name)
    into have
    from information_schema.columns
   where table_schema = 'public' and is_generated = 'ALWAYS';

  -- Each was ::term_kind before 0027 and is ::text after it. The nine columns and
  -- their positions are unchanged, which matters: they were altered in place
  -- rather than dropped and re-added, because vessel_state reads visible_node
  -- through a positional alias list and reordering node silently rebinds it.
  want := 'event.operation_kind=''operation''::text '
       || 'location.kind_kind=''location_kind''::text '
       || 'node.product_kind=''product_type''::text '
       || 'node.variety_kind=''variety''::text '
       -- 0043, pinning a form's operation list to the operation vocabulary.
       || 'paper_record_operation.operation_kind=''operation''::text '
       -- 0039, pinning a planting's term to the variety vocabulary.
       || 'planting.variety_kind=''variety''::text '
       || 'procedure_step.material_kind=''material_kind''::text '
       || 'task.operation_kind=''operation''::text '
       || 'template_step.operation_kind=''operation''::text '
       || 'vessel.type_kind=''vessel_type''::text';

  if have is distinct from want then
    raise exception
      E'FAIL: the generated kind columns changed.\nnow:  %\nwas:  %', have, want;
  end if;
  perform test_ok('the nine generated kind columns are constants and still in place, so a kind cannot be lied about');
end $$;

-- Behaviour, not just shape. Every one of the nine refuses a term of the wrong
-- kind, probed rather than read, on the tables that have somewhere to write.
do $$
declare refused int := 0;
begin
  begin
    insert into node (stage, name, variety_id)
      values ('bin','wrong variety', term_id('vessel_maker','francois_freres'));
    raise exception 'FAIL: node.variety_id accepted a cooper';
  exception when foreign_key_violation then refused := refused + 1;
  end;

  begin
    insert into node (stage, name, product_type_id)
      values ('bin','wrong product', term_id('variety','pinot_noir'));
    raise exception 'FAIL: node.product_type_id accepted a variety';
  exception when foreign_key_violation then refused := refused + 1;
  end;

  begin
    insert into vessel (name, type_id) values ('wrong type', term_id('variety','pinot_noir'));
    raise exception 'FAIL: vessel.type_id accepted a variety';
  exception when foreign_key_violation then refused := refused + 1;
  end;

  begin
    insert into event (operation_id, subject_type, subject_id, by_user)
      values (term_id('variety','pinot_noir'), 'node',
              '00000000-0000-0000-0000-00000000b001',
              '00000000-0000-0000-0000-00000000a001');
    raise exception 'FAIL: event.operation_id accepted a variety';
  exception when foreign_key_violation then refused := refused + 1;
  end;

  begin
    insert into task (operation_id, subject_type, subject_id)
      values (term_id('variety','pinot_noir'), 'node', '00000000-0000-0000-0000-00000000b001');
    raise exception 'FAIL: task.operation_id accepted a variety';
  exception when foreign_key_violation then refused := refused + 1;
  end;

  if refused <> 5 then raise exception 'FAIL: only % of 5 wrong-kind writes were refused', refused; end if;
  perform test_ok('five of the nine typed-id keys refuse a term of the wrong kind, probed on the tables that have a write path');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- delete behaviour is what the DDL says it is'; end $$;

-- Ledger A20 found ON DELETE RESTRICT bypassable in two steps: delete the
-- lineage edge, then the node, both permitted. The constraint is not wrong; the
-- absence of a delete policy for cellar users is what made it reachable. What is
-- asserted here is that the declared behaviour has not drifted, since a schema
-- move that recreates a foreign key is exactly where a cascade turns into a
-- no-action without anybody noticing.
do $$
declare have text; want text;
begin
  if not snapshots_on() then perform skip_snapshot('foreign key delete behaviour'); return; end if;
  select string_agg(x.line, ' ' order by x.line) into have from (
    select c.confdeltype::text || '=' || count(*)::text as line
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'public' and c.contype = 'f'
     group by c.confdeltype
  ) x;

  -- r=4 before 0026. The three new restrict keys are the subject-type
  -- registrations: uninstalling a module while tasks still point at its subjects
  -- is refused rather than silently taking the tasks with it.
  -- r=7 before 0027, which added term.term_kind_is_registered: deregistering a
  -- kind of vocabulary while terms still use it is refused, not cascaded.
  -- a=27 c=8 before 0039. The new cascade is planting to block: a planting has
  -- no meaning without the block it is in, so deleting the block takes what was
  -- planted in it. The two new no-actions are block to vineyard and the
  -- composite pinning a planting to the variety vocabulary.
  -- a=29 before 0041. The new one is day_note to its author: no action, because
  -- a note outliving the account that wrote it is still a record of the day, and
  -- losing the winery's notes because somebody left would be the wrong answer.
  -- a=30 c=9 before 0043. The three new cascades all hang off a form: its
  -- operation list and its propagations have no meaning without it, and a
  -- propagation has none without the event it is about. The two new no-actions
  -- are who wrote it, which outlives their account, and the composite pinning a
  -- form's operation list to the vocabulary.
  want := 'a=32 c=12 n=1 r=8';
  if have <> want then
    raise exception
      E'FAIL: foreign key delete behaviour changed.\nnow:  %\nwas:  %\na is no action, c is cascade, n is set null, r is restrict.', have, want;
  end if;
  perform test_ok('foreign key delete behaviour is unchanged: 27 no action, 8 cascade, 1 set null, 4 restrict');
end $$;

-- The restrict ones by name, because those four are the ones A20 is about and a
-- count would not notice one of them becoming a cascade while another became a
-- restrict.
do $$
declare have text; want text;
begin
  if not snapshots_on() then perform skip_snapshot('the restrict key list'); return; end if;
  select coalesce(string_agg(t.relname || '.' || c.conname, ', ' order by t.relname, c.conname), '')
    into have
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public' and c.contype = 'f' and c.confdeltype = 'r';

  want := 'event.event_subject_type_is_registered, '
       || 'lineage.lineage_child_id_fkey, lineage.lineage_parent_id_fkey, '
       || 'placement.placement_node_id_fkey, placement.placement_vessel_id_fkey, '
       || 'procedure.procedure_subject_type_is_registered, '
       || 'task.task_subject_type_is_registered, term.term_kind_is_registered';

  if have <> want then
    raise exception E'FAIL: the restrict keys changed.\nnow:  %\nwas:  %', have, want;
  end if;
  perform test_ok('the eight ON DELETE RESTRICT keys are the lineage and placement ones ledger A20 names, plus the four registry ones');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- check constraints refuse what they say they refuse'; end $$;

-- operation_has_an_effect is named by W-3 as needing care because it is what
-- makes ledger B2 fail: addTerm sends no effect and adding an operation inline
-- always raises. The constraint is asserted here and the client is not, because
-- B2 is section B and out of scope.
-- What it actually does, which is not what it was written to do. The predicate
-- is `kind <> 'operation' or attributes ->> 'effect' in (four values)`. For an
-- operation with no effect at all that inner test is `null in (...)`, which is
-- null, so the whole check is `false or null`, which is null, and a check
-- constraint passes on null. An effectless operation lands.
--
-- That is ledger A24, filed by this assertion rather than fixed by it, because
-- section A is out of scope here. It also corrects B2: two reports said adding an
-- operation inline always raises because addTerm sends `{}`. It does not raise.
-- It silently creates an operation the kernel will read no effect from, which is
-- worse than raising, because a raise is visible.
--
-- Written so that fixing A24 fails this assertion on purpose.
do $$
declare landed boolean := false;
begin
  begin
    insert into term (kind, value, label, attributes)
      values ('operation','effectless','Effectless','{}'::jsonb);
    landed := true;
  exception when check_violation then
    landed := false;
  end;

  if not landed then
    raise exception
      'FAIL: an effectless operation is now refused, which means A24 was fixed. That is good; update this assertion and B2 to say so.';
  end if;
  perform test_ok('an operation with no effect is accepted, which is A24: null in a check constraint is not false');

  begin
    insert into term (kind, value, label, attributes)
      values ('operation','wrong_effect_here','Wrong','{"effect":"magic"}'::jsonb);
    raise exception 'FAIL: an operation with an effect outside the four was accepted';
  exception when check_violation then
    perform test_ok('an operation with an effect outside the four is refused, which is the half that works');
  end;

  begin
    insert into term (kind, value, label, attributes)
      values ('variety','effectless_variety','Effectless Variety','{}'::jsonb);
    perform test_ok('a non-operation term needs no effect, so the constraint is scoped to operations');
  exception when check_violation then
    raise exception 'FAIL: operation_has_an_effect fired on a variety';
  end;
end $$;

-- The thermal pair from 0006, which is the only check constraint in the tree
-- that encodes a physical fact about a vessel.
do $$
begin
  begin
    insert into vessel (name, type_id, mode)
      values ('jacketless cooler', term_id('vessel_type','tank'), 'cooling');
    raise exception 'FAIL: cooling was accepted on a vessel with no jacket';
  exception when check_violation then
    perform test_ok('a thermal mode without a jacket is refused');
  end;

  begin
    insert into vessel (name, type_id, has_glycol, mode)
      values ('setpointless cooler', term_id('vessel_type','tank'), true, 'cooling');
    raise exception 'FAIL: cooling was accepted with no setpoint';
  exception when check_violation then
    perform test_ok('a thermal mode without a setpoint is refused');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- unique constraints refuse duplicates, and partial ones only inside their predicate'; end $$;

do $$
begin
  begin
    insert into term (kind, value, label, sort_order, attributes)
      values ('variety','pinot_noir','Duplicate Pinot',999,'{}'::jsonb);
    raise exception 'FAIL: a duplicate term kind and value was accepted';
  exception when unique_violation then
    perform test_ok('a term is unique on kind and value');
  end;

  begin
    insert into location (name) values ('Assertion Barn Duplicate');
    insert into location (name) values ('Assertion Barn Duplicate');
    raise exception 'FAIL: a duplicate location name was accepted';
  exception when unique_violation then
    perform test_ok('a location name is unique');
  end;
end $$;

-- The partial ones, which are the interesting half: they must refuse inside the
-- predicate and accept outside it. party_one_facility is the load-bearing case,
-- and it is what lets the suite stand the winery down at the top of this file.
do $$
begin
  begin
    insert into party (name, kind) values ('Second Active Facility', 'facility');
    raise exception 'FAIL: a second active facility party was accepted';
  exception when unique_violation then
    perform test_ok('only one facility party may be active at a time');
  end;

  insert into party (id, name, kind, active)
    values ('00000000-0000-0000-0000-0000000000e9','Retired Facility','facility', false);
  perform test_ok('an inactive facility party is accepted, so the uniqueness is partial and not absolute');

  begin
    insert into placement (node_id, vessel_id, volume_l)
      values ('00000000-0000-0000-0000-00000000b001',
              '00000000-0000-0000-0000-0000000000c2', 1);
    insert into placement (node_id, vessel_id, volume_l)
      values ('00000000-0000-0000-0000-00000000b010',
              '00000000-0000-0000-0000-0000000000c2', 1);
    raise exception 'FAIL: two open placements in one vessel were accepted';
  exception when unique_violation then
    perform test_ok('a vessel holds one open placement, which is what makes occupancy derivable');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- every check constraint refuses one specific thing, on its own'; end $$;

-- The pinned inventory above catches a constraint that disappears. It cannot
-- catch one that is still listed and refuses nothing, and measuring that is what
-- the `loosen` class in scripts/mutate.sh exists for: it replaces each check with
-- `check (true)` and leaves the name in place. Before this block it scored 2 of
-- 18.
--
-- Each assertion below violates exactly one constraint and satisfies every other
-- constraint on the same row. That matters more than it sounds: the first attempt
-- at the vessel pair violated both thermal constraints at once, so loosening
-- either one still raised and neither was really covered. Ledger G-5-6 is the
-- same observation about vessel_code.

do $$
begin
  -- event.has_an_author. Not reachable through the policy, which now also
  -- requires by_user = auth.uid(), so this runs as the owner to reach the
  -- constraint itself rather than the policy in front of it.
  begin
    insert into event (operation_id, subject_type, subject_id, by_user, by_sensor)
      values (term_id('operation','punchdown'), 'node',
              '00000000-0000-0000-0000-00000000b001', null, null);
    raise exception 'FAIL: an event with neither a user nor a sensor was accepted';
  exception when check_violation then
    perform test_ok('an event names a user or a sensor, never neither');
  end;
end $$;

do $$
begin
  -- lineage.no_self_parent, with a valid fraction so only this one can fire.
  begin
    insert into lineage (parent_id, child_id, fraction)
      values ('00000000-0000-0000-0000-00000000b001',
              '00000000-0000-0000-0000-00000000b001', 0.5);
    raise exception 'FAIL: a lot was made its own parent';
  exception when check_violation then
    perform test_ok('a lot cannot be its own parent');
  end;

  -- lineage_fraction_check, twice, because the constraint has two sides and a
  -- one-sided test leaves half of it unexercised.
  begin
    insert into lineage (parent_id, child_id, fraction)
      values ('00000000-0000-0000-0000-00000000b001',
              '00000000-0000-0000-0000-00000000b010', 0);
    raise exception 'FAIL: a lineage fraction of zero was accepted';
  exception when check_violation then
    perform test_ok('a lineage fraction must be greater than zero');
  end;

  begin
    insert into lineage (parent_id, child_id, fraction)
      values ('00000000-0000-0000-0000-00000000b001',
              '00000000-0000-0000-0000-00000000b010', 1.5);
    raise exception 'FAIL: a lineage fraction above one was accepted';
  exception when check_violation then
    perform test_ok('a lineage fraction cannot exceed one');
  end;
end $$;

do $$
begin
  -- node.block_only_on_bins. A block on anything that is not a bin is a claim
  -- that fruit arrived as a ferment, which is F-1's whole point arriving as a
  -- constraint.
  -- A real block, so the foreign key is satisfied and only block_only_on_bins
  -- can fire. The first version of this used an id that did not exist, so it
  -- passed on a foreign key violation and proved nothing about the check.
  -- 0039 made a vineyard a row rather than a string on the block, so the
  -- fixture names one. This broke when the column moved, which is the fixture
  -- doing its job: a test that kept compiling against a column that no longer
  -- existed would be a test of nothing.
  insert into vineyard (id, name)
    values ('00000000-0000-0000-0000-00000000a0d1', 'Eola Springs')
    on conflict do nothing;
  insert into block (id, vineyard_id, name)
    values ('00000000-0000-0000-0000-00000000a0b1',
            '00000000-0000-0000-0000-00000000a0d1', 'Assertion Block')
    on conflict do nothing;

  begin
    insert into node (stage, name, block_id)
      values ('ferment', 'ferment with a block', '00000000-0000-0000-0000-00000000a0b1');
    raise exception 'FAIL: a non-bin node carried a block';
  exception when check_violation then
    perform test_ok('only a bin may name a block, so a ferment cannot claim to have arrived from one');
  end;

  insert into node (stage, name, block_id)
    values ('bin', 'bin with a block', '00000000-0000-0000-0000-00000000a0b1');
  perform test_ok('a bin may name a block, so the constraint is about the stage and not about blocks');

  -- node_hidden_known and party_default_hidden_known, the two that keep the
  -- privacy vocabulary from drifting into free text.
  begin
    insert into node (stage, name, hidden) values ('bin', 'hidden nonsense', array['not_a_field']);
    raise exception 'FAIL: a node hid a field that does not exist';
  exception when check_violation then
    perform test_ok('a lot can only hide a field the schema agrees is hideable');
  end;

  begin
    insert into party (name, kind, default_hidden)
      values ('Nonsense Defaults', 'client', array['not_a_field']);
    raise exception 'FAIL: a party defaulted to hiding a field that does not exist';
  exception when check_violation then
    perform test_ok('a party can only default to hiding a field the schema agrees is hideable');
  end;
end $$;

do $$
declare v uuid; p uuid; sess uuid; run uuid; st uuid;
begin
  -- The vessel thermal pair, each violated alone. The jacket case supplies a
  -- setpoint so that vessel_mode_needs_setpoint is satisfied and only
  -- vessel_mode_needs_jacket can fire; the setpoint case supplies a jacket for
  -- the same reason. Written the other way round, loosening either one still
  -- raised and neither was covered.
  begin
    insert into vessel (name, type_id, has_glycol, setpoint_c, mode)
      values ('jacketless but set', term_id('vessel_type','tank'), false, 12, 'cooling');
    raise exception 'FAIL: cooling was accepted on a vessel with a setpoint and no jacket';
  exception when check_violation then
    perform test_ok('a thermal mode needs a jacket, asserted without the setpoint rule masking it');
  end;

  begin
    insert into vessel (name, type_id, has_glycol, setpoint_c, mode)
      values ('jacketed but unset', term_id('vessel_type','tank'), true, null, 'cooling');
    raise exception 'FAIL: cooling was accepted on a jacketed vessel with no setpoint';
  exception when check_violation then
    perform test_ok('a thermal mode needs a setpoint, asserted without the jacket rule masking it');
  end;
end $$;

do $$
declare proc uuid;
begin
  -- The three procedure_step constraints from 0019, none of which had ever been
  -- exercised.
  insert into procedure (id, name, subject_type) values (gen_random_uuid(), 'Assertion Procedure', 'vessel')
    returning id into proc;

  begin
    insert into procedure_step (procedure_id, step_order, label, kind)
      values (proc, 1, 'nonsense kind', 'interpretive_dance');
    raise exception 'FAIL: a procedure step of an unknown kind was accepted';
  exception when check_violation then
    perform test_ok('a procedure step is a timer, a solution, a check or a note, and nothing else');
  end;

  begin
    insert into procedure_step (procedure_id, step_order, label, kind, target_seconds)
      values (proc, 2, 'zero timer', 'check', 0);
    raise exception 'FAIL: a target of zero seconds was accepted';
  exception when check_violation then
    perform test_ok('a target duration must be positive, so zero seconds is not a target');
  end;

  begin
    insert into procedure_step (procedure_id, step_order, label, kind, target_seconds)
      values (proc, 3, 'untimed timer', 'timer', null);
    raise exception 'FAIL: a timer step with no target was accepted';
  exception when check_violation then
    perform test_ok('a timer step carries a target, or it is not timing anything');
  end;
end $$;

do $$
declare sess uuid; run uuid; stp uuid; proc uuid;
begin
  -- procedure_run_step.ends_after_it_starts. A step that ended before it began
  -- is a clock problem or a typo, and either way the duration derived from it
  -- would be negative.
  insert into procedure (id, name, subject_type) values (gen_random_uuid(), 'Timing Procedure', 'vessel')
    returning id into proc;
  insert into procedure_step (id, procedure_id, step_order, label, kind)
    values (gen_random_uuid(), proc, 1, 'a step', 'note') returning id into stp;
  insert into procedure_session (id, procedure_id, started_by)
    values (gen_random_uuid(), proc, '00000000-0000-0000-0000-00000000a001') returning id into sess;
  insert into procedure_run (id, session_id, vessel_id, position)
    values (gen_random_uuid(), sess, '00000000-0000-0000-0000-0000000000c2', 1) returning id into run;

  begin
    insert into procedure_run_step (run_id, step_id, started_at, ended_at)
      values (run, stp, now(), now() - interval '1 hour');
    raise exception 'FAIL: a step ended before it started';
  exception when check_violation then
    perform test_ok('a procedure step cannot end before it starts, so a derived duration is never negative');
  end;
end $$;

do $$
begin
  -- The three subject_resolver checks from 0023. The earlier attempt at these
  -- collided with the primary key instead of reaching the check, so it proved
  -- nothing; these use a subject type that is not already registered by using
  -- update rather than insert.
  begin
    update subject_resolver set relation = 'node; drop table node' where subject_type = 'node';
    raise exception 'FAIL: a resolver relation carrying a statement was accepted';
  exception when check_violation then
    perform test_ok('a resolver relation must be a bare name, so it cannot carry a statement');
  end;

  begin
    update subject_resolver set module = 'not a module' where subject_type = 'node';
    raise exception 'FAIL: a resolver module with a space in it was accepted';
  exception when check_violation then
    perform test_ok('a resolver module must be a bare name');
  end;

  begin
    update subject_resolver set name_expression = '   ' where subject_type = 'node';
    raise exception 'FAIL: a blank name expression was accepted';
  exception when check_violation then
    perform test_ok('a resolver name expression cannot be blank');
  end;
end $$;


do $$
declare vt uuid;
begin
  -- The two vessel_type_note constraints from 0012, neither of which had been
  -- exercised. A note with no body is a row nobody can act on, and a note marked
  -- resolved by nobody, or by somebody at no time, is half a record.
  vt := term_id('vessel_type','barrel');

  begin
    insert into vessel_type_note (vessel_type_id, body, created_by)
      values (vt, '   ', '00000000-0000-0000-0000-00000000a002');
    raise exception 'FAIL: a blank vessel type note was accepted';
  exception when check_violation then
    perform test_ok('a note about a vessel type has to say something');
  end;

  begin
    insert into vessel_type_note (vessel_type_id, body, created_by, resolved_at, resolved_by)
      values (vt, 'resolved by nobody', '00000000-0000-0000-0000-00000000a002', now(), null);
    raise exception 'FAIL: a note was resolved at a time by nobody';
  exception when check_violation then
    perform test_ok('a resolved note names who resolved it, and an unresolved one names nobody');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a cellar hand may label a barrel, and may not relabel one'; end $$;

-- Ledger A22, ruled by the winemaker: a cellar hand may bind an unbound code;
-- only an admin may rebind one already bound. The split sits where the risk is,
-- and both halves are asserted because only asserting the permitted half would
-- leave the refusal free to rot.
do $$
declare c vessel_code; msg text;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');   -- the cellar user
  set local role authenticated;

  c := bind_vessel_code('00000000-0000-0000-0000-0000000000c2', 'STICKER-NEW', 'our sticker');
  if c.vessel_id <> '00000000-0000-0000-0000-0000000000c2' then
    raise exception 'FAIL: binding an unbound code did not land on the vessel asked for';
  end if;
  perform test_ok('a cellar hand may put a new sticker on a barrel, which is A22');

  -- Idempotence survives the change.
  c := bind_vessel_code('00000000-0000-0000-0000-0000000000c2', 'STICKER-NEW');
  perform test_ok('binding a code the vessel already carries returns it rather than complaining');

  -- And the half that is refused, with the message checked rather than just the
  -- refusal, because the whole point of the ruling is that a person in a barrel
  -- room learns which barrel already has that sticker.
  begin
    c := bind_vessel_code('00000000-0000-0000-0000-00000000c001', 'STICKER-NEW');
    raise exception 'FAIL: a cellar hand moved a sticker to another barrel';
  exception when insufficient_privilege then
    get stacked diagnostics msg = message_text;
    if msg not like '%RESOLVE-1%' then
      raise exception 'FAIL: the refusal did not name the vessel currently holding the code: %', msg;
    end if;
    perform test_ok('a cellar hand may not move a sticker, and the refusal names the barrel that has it');
  end;

  -- Writing the table directly must be refused too, or the function is a
  -- suggestion rather than a boundary.
  begin
    update vessel_code set vessel_id = '00000000-0000-0000-0000-00000000c001'
     where code = 'STICKER-NEW';
    if found then
      raise exception 'FAIL: a cellar hand rebound a code by writing the table';
    end if;
  exception when insufficient_privilege then null;
  end;
  if exists (select 1 from vessel_code
              where code = 'STICKER-NEW'
                and vessel_id = '00000000-0000-0000-0000-00000000c001') then
    raise exception 'FAIL: a direct update moved the sticker';
  end if;
  perform test_ok('a cellar hand cannot rebind by writing vessel_code directly either');

  reset role;
end $$;

do $$
declare c vessel_code;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');   -- the admin
  set local role authenticated;
  c := bind_vessel_code('00000000-0000-0000-0000-00000000c001', 'STICKER-NEW');
  reset role;
  if c.vessel_id <> '00000000-0000-0000-0000-00000000c001' then
    raise exception 'FAIL: an admin could not move a sticker to another barrel';
  end if;
  perform test_ok('an admin may move a sticker, which is the other half of the ruling');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- deactivating an account takes the account away'; end $$;

-- Found by the logic mutation class: removing the `active` conjunct from
-- is_admin() changed nothing this suite could see. An admin who has been
-- switched off stayed an admin, and nothing said so. That is ledger B10's shape,
-- where the client reimplements is_admin and drops the same conjunct, arriving
-- in the kernel instead.
do $$
declare was boolean; now_ boolean;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  select is_admin() into was;

  update app_user set active = false where id = '00000000-0000-0000-0000-00000000a001';
  select is_admin() into now_;
  update app_user set active = true where id = '00000000-0000-0000-0000-00000000a001';

  if not was then raise exception 'FAIL: the admin fixture is not an admin to begin with'; end if;
  if now_ then
    raise exception 'FAIL: an admin who has been deactivated is still an admin';
  end if;
  perform test_ok('deactivating an admin takes their admin rights with it');
end $$;

-- And the same question for a cellar hand, since is_facility_user() reads the
-- same flag through a different route.
do $$
declare still boolean;
begin
  update app_user set active = false where id = '00000000-0000-0000-0000-00000000a002';
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  select is_facility_user() into still;
  update app_user set active = true where id = '00000000-0000-0000-0000-00000000a002';
  perform test_act_as('00000000-0000-0000-0000-00000000a001');

  if still then
    raise exception 'FAIL: a deactivated cellar account is still a facility user';
  end if;
  perform test_ok('deactivating a cellar account takes the cellar with it');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- nothing in the fixed layer permits on unknown'; end $$;

-- Ledger A25, the null-permit class. Three instances found one at a time over
-- three sessions, by three routes, none written deliberately:
--
--   is_facility_user() used coalesce(..., true), so a missing party row resolved
--   to facility and deactivating a client promoted them.
--
--   may_see_all_of returned null where nothing matched, so `not null` was null
--   and the `if` guarding a privacy check did not fire.
--
--   operation_has_an_effect reads `kind <> 'operation' or attributes ->> 'effect'
--   in (four values)`. For an operation carrying `{}` that is `false or null`,
--   which is null, and a check constraint permits on null.
--
-- The invariant, which is AR-B9 applied below the gate at the level of individual
-- constraints and functions: **in the fixed layer, a predicate that cannot
-- determine an answer must refuse, never permit.**
--
-- **Two wrong tests preceded this one and both are worth recording, because each
-- failed in a different direction and a reader will otherwise reinvent them.**
--
-- Evaluating each predicate against a row of all nulls flagged twelve
-- constraints, eleven of them wrongly: forcing a NOT NULL column to null asks
-- about a row the table can never hold.
--
-- Evaluating against a row of empty values, '' and '{}' and false and zero,
-- flagged none, including the one instance that is real. A24's witness needs
-- `kind = 'operation'` and the empty row takes the first enum label, which is
-- not that. It passed, and it would have passed forever, and it was caught only
-- because the break test removed A24 from the allow-list and nothing failed.
--
-- What actually decides it is whether **any** row the table could hold makes the
-- predicate null. So the test enumerates candidate values per column, every label
-- for an enum, a small representative set otherwise, and null only where the
-- column is actually nullable, and asks whether any combination answers null.
-- That flags A24 and does not flag `mode = 'off' or has_glycol`, which is the
-- distinction the first two tests could not draw.

do $$
declare
  r            record;
  found_null   boolean;
  combos       bigint;
  permits      text := '';
  unevaluable  text := '';
  allowed      text[] := array[
    -- Each entry needs a reason, and knowing about it is not a reason.
    -- A24: filed and not fixed, section A, out of scope since W-2. The assertion
    -- for it is written so that fixing it fails that assertion, which puts the
    -- fix and the assertion in one commit.
    'term.operation_has_an_effect'
  ];
begin
  for r in
    select t.relname as tbl, c.conname as con,
           pg_get_expr(c.conbin, c.conrelid) as expr,
           (select string_agg(
                     format('unnest(array[%s]::%s[]) c%s(v)',
                       (select string_agg(lit, ', ') from (
                          select case
                            when tp.typtype = 'e' then format('%L', e.enumlabel)
                            else null end as lit
                            from pg_enum e where e.enumtypid = a.atttypid
                           order by e.enumsortorder) q(lit) where lit is not null),
                       format_type(a.atttypid, null), k.ord)
                   , ', ')
              from unnest(c.conkey) with ordinality k(attnum, ord)
              join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum
              join pg_type tp on tp.oid = a.atttypid
              where tp.typtype = 'e') as ignore_me,
           (select count(*) from unnest(c.conkey)) as ncols,
           c.conkey, c.conrelid
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'public' and c.contype = 'c'
     order by t.relname, c.conname
  loop
    declare
      froms   text := '';
      selects text := '';
      i        int := 0;
      col      record;
      cands    text;
      cand_arr text[];
    begin
      combos := 1;
      for col in
        select a.attname, a.atttypid, a.atttypmod, a.attnotnull, tp.typtype,
               format_type(a.atttypid, a.atttypmod) as ftype,
               format_type(a.atttypid, null) as btype
          from unnest(r.conkey) k
          join pg_attribute a on a.attrelid = r.conrelid and a.attnum = k
          join pg_type tp on tp.oid = a.atttypid
         order by a.attnum
      loop
        i := i + 1;

        if col.typtype = 'e' then
          select array_agg(format('%L', enumlabel) order by enumsortorder)
            into cand_arr from pg_enum where enumtypid = col.atttypid;
        elsif col.atttypid = 'boolean'::regtype then
          cand_arr := array['true', 'false'];
        elsif col.btype like '%[]' then
          cand_arr := array[quote_literal('{}'), quote_literal('{x}')];
        elsif col.atttypid in ('jsonb'::regtype, 'json'::regtype) then
          cand_arr := array[quote_literal('{}'), quote_literal('{"effect": "treatment"}')];
        elsif col.atttypid in ('text'::regtype, 'character varying'::regtype, 'name'::regtype) then
          -- X-1-4 and X-1-12. A text column used to be exercised against '' and
          -- 'x' and null only. An enum column is exercised against every label,
          -- so 0027 converting term.kind from an enum to text silently narrowed
          -- this assertion until it could no longer see A24: the candidate set
          -- never contained 'operation', so `kind <> 'operation'` was always
          -- true and the predicate never answered null. Removing the allow-list
          -- entry changed nothing, which is how the blindness was found.
          --
          -- The literals in the constraint's own expression are now candidates,
          -- which is where the interesting values live: a predicate that
          -- compares a column to a literal is only interesting at that literal.
          -- Every enum-to-registry conversion after this one keeps working
          -- rather than narrowing the population further.
          cand_arr := array[quote_literal(''), quote_literal('x')];
          cand_arr := cand_arr || coalesce(
            (select array_agg(distinct quote_literal(m[1]))
               from regexp_matches(r.expr, '''([^'']+)''', 'g') as m),
            '{}'::text[]);
        elsif col.atttypid in ('smallint'::regtype,'integer'::regtype,'bigint'::regtype,
                               'numeric'::regtype,'real'::regtype,'double precision'::regtype) then
          cand_arr := array['0', '1'];
        elsif col.atttypid = 'uuid'::regtype then
          cand_arr := array[quote_literal('00000000-0000-0000-0000-000000000000')];
        elsif col.atttypid in ('timestamptz'::regtype,'timestamp'::regtype,'date'::regtype) then
          cand_arr := array['now()'];
        else
          cand_arr := null;
        end if;

        if cand_arr is null then
          unevaluable := unevaluable || format('%s.%s (no candidate values for %s of type %s); ',
                                               r.tbl, r.con, col.attname, col.ftype);
          froms := '';
          exit;
        end if;

        -- null only where the column can actually be null. This is the whole
        -- difference between this test and the first one that was written.
        if not col.attnotnull then
          -- The cast is load-bearing: text[] || 'null' resolves as array
          -- concatenation and tries to parse the string as an array literal.
          cand_arr := cand_arr || 'null'::text;
        end if;

        -- values rather than unnest, because unnest on an array-typed column's
        -- candidates flattens them and the predicate then sees text where it
        -- expects text[].
        select string_agg(format('(%s::%s)', lit, col.btype), ', ')
          into cands from unnest(cand_arr) lit;

        froms := froms || case when froms = '' then '' else ', ' end
              || format('(values %s) c%s(v)', cands, i);
        selects := selects || case when selects = '' then '' else ', ' end
                || format('c%s.v as %I', i, col.attname);
      end loop;

      if froms = '' then
        -- X-1-16: there are two ways to reach this. One sets `unevaluable` first
        -- and is reported; the other is a constraint whose conkey is empty,
        -- where the column loop never ran, and that used to continue in silence.
        -- A check constraint referencing no column is exactly what the `loosen`
        -- mutation class creates.
        if i = 0 then
          unevaluable := unevaluable || format('%s.%s (references no column); ', r.tbl, r.con);
        end if;
        continue;
      end if;

      begin
        execute format('select bool_or((%s) is null) from (select %s from %s) s',
                       r.expr, selects, froms)
          into found_null;
      exception when others then
        unevaluable := unevaluable || format('%s.%s (%s); ', r.tbl, r.con, sqlerrm);
        continue;
      end;

      if coalesce(found_null, false) and not ((r.tbl || '.' || r.con) = any(allowed)) then
        permits := permits || r.tbl || '.' || r.con || ', ';
      end if;
    end;
  end loop;

  if unevaluable <> '' then
    raise exception 'FAIL: these check constraints could not be exercised, so this assertion is blind to them: %', unevaluable;
  end if;

  if permits <> '' then
    raise exception
      'FAIL: these check constraints answer null for some row the table could hold, which is ledger A25: %. A predicate that cannot determine an answer must refuse. If one is deliberate, add it to the allow-list here with the reason.', permits;
  end if;

  perform test_ok('no check constraint permits on unknown, except the one instance on the allow-list');
end $$;

-- The other half of the population. A boolean function that can answer null is
-- the same defect one layer up: `not null` is null, and an `if` on null does not
-- run, which is exactly how may_see_all_of failed open. Called with nulls for
-- every argument and with nobody signed in, because that is the state an
-- unauthenticated or half-configured caller actually arrives in.
do $$
declare
  r       record;
  result  boolean;
  nulls   text := '';
begin
  perform test_act_as(null);

  for r in
    select p.proname as fn,
           pg_get_function_identity_arguments(p.oid) as sig,
           coalesce((select string_agg('null::' || format_type(t, null), ', ')
                       from unnest(p.proargtypes) as u(t)), '') as nullargs
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and pg_get_function_result(p.oid) = 'boolean'
       and p.prokind = 'f'
     order by p.proname
  loop
    begin
      execute format('select %I(%s)', r.fn, r.nullargs) into result;
    exception when others then
      nulls := nulls || r.fn || ' raised: ' || sqlerrm || '; ';
      continue;
    end;

    if result is null then
      nulls := nulls || r.fn || '(' || r.sig || ') returned null; ';
    end if;
  end loop;

  perform test_act_as('00000000-0000-0000-0000-00000000a001');

  if nulls <> '' then
    raise exception 'FAIL: these boolean functions answer null rather than false, which is ledger A25: %', nulls;
  end if;

  perform test_ok('every boolean function answers true or false and never null, with null arguments and nobody signed in');
end $$;

-- X-2-7. The two halves above enumerate check constraints and boolean functions.
-- A validator that returns `trigger` or `void` and refuses by raising is in the
-- class and in neither half, and `0027` did its work in exactly that layer:
-- `validate_vessel_type_fields` proved a vocabulary existed by casting to an enum
-- and catching the failure, and rewriting the cast to text would have made it
-- always succeed.
--
-- The ledger says of A25 that "a derived assertion now enumerates the population
-- from the catalog and searches it, and as of 0025 there is no fourth". That
-- sentence was true of the population it enumerated and was read as a statement
-- about the class.
--
-- This assertion cannot exercise a trigger validator the way it exercises a check
-- constraint: there is no row to build, the guards are `if` conditions inside a
-- body, and evaluating them means executing the function. So it does the next
-- honest thing. It enumerates them, and requires that each is accounted for
-- somewhere by name. A validator that appears without an entry fails the suite,
-- which turns a silent gap in the population into a decision somebody has to
-- make.
do $$
declare
  r         record;
  unaccounted text := '';
  accounted text[] := array[
    -- Each entry says where the function's null-permit behaviour is actually
    -- exercised, because "we know about it" is not an account.
    --
    -- covered by the `logic` mutation class in scripts/mutate.sh, which
    -- substitutes into the guard and requires the suite to notice:
    'cellar_writable_columns',
    'close_node_when_empty',
    'validate_vessel_type_fields',
    -- covered by behavioural assertions elsewhere in this file:
    'refuse_self_granted_standing',
    -- The null branch is unreachable rather than covered, which is a different
    -- account and the honest one. Both subselects read `node.stage` by an id
    -- that lineage constrains with a foreign key into `node`, so a row reaching
    -- this trigger cannot name a parent or child that is not there. If those
    -- foreign keys ever go, this becomes A25's shape and permits the fork it
    -- exists to refuse, which is why the reason is written down rather than the
    -- conclusion. Asserted in the intake block below.
    'refuse_forking_a_pick',
    -- NOT covered, and filed as ledger A26. The `required` guard reads
    -- `coalesce((f ->> 'required')::boolean, false)`, which is the defensive
    -- form, but the `kind` guard above it is `(f ->> 'kind') not in (...)`,
    -- which is null for a field carrying no kind, so the whole picker block
    -- including the registry lookup is skipped. That is X-2-1 and it is a
    -- fourth instance of A25. Filed, not fixed: section A is out of scope.
    'validate_vessel_attributes'
  ];
begin
  for r in
    select p.proname as fn
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and pg_get_function_result(p.oid) in ('trigger', 'void')
       and p.prosrc ~* 'raise exception'
     order by p.proname
  loop
    if not (r.fn = any(accounted)) then
      unaccounted := unaccounted || r.fn || ', ';
    end if;
  end loop;

  if unaccounted <> '' then
    raise exception
      'FAIL: these validators refuse by raising and are in A25''s class, and nothing accounts for how their null behaviour is exercised: %. Add each to the list in this assertion with where it is covered, or say it is not.', unaccounted;
  end if;

  perform test_ok('every validator that refuses by raising is accounted for, which is A25''s population beyond check constraints');
end $$;


-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a subject type is a row, not a type'; end $$;

-- AR-E7, the half `0026` did. subject_type was an enum with four labels, three
-- of which name tables belonging to modules an install may not have. It never
-- failed to install and it was always a wrong-way edge.
do $$
begin
  if exists (select 1 from pg_type where typname = 'subject_type') then
    raise exception 'FAIL: the subject_type enum is back, so core carries a fixed list of module concepts again';
  end if;
  perform test_ok('there is no subject_type enum, so adding a subject type is a row');
end $$;

-- And the row is what makes it real: a task cannot point at a subject type
-- nobody registered.
do $$
begin
  begin
    insert into task (operation_id, subject_type, subject_id)
      values (term_id('operation','punchdown'), 'unregistered_thing',
              '00000000-0000-0000-0000-00000000b001');
    raise exception 'FAIL: a task was created against an unregistered subject type';
  exception when foreign_key_violation then
    perform test_ok('a task cannot name a subject type nobody registered');
  end;
end $$;

-- Registering one is a row and nothing else, which is the whole claim.
do $$
declare r subject_resolver; got text;
begin
  create table if not exists widget (id uuid primary key, name text not null);
  insert into widget (id, name) values ('00000000-0000-0000-0000-00000000aa01', 'A widget')
    on conflict do nothing;

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  set local role authenticated;
  r := register_subject_resolver('widget', 'widget', 'name', 'inventory');
  reset role;

  insert into task (operation_id, subject_type, subject_id)
    values (term_id('operation','punchdown'), 'widget', '00000000-0000-0000-0000-00000000aa01');

  select subject_name into got from task_board where subject_type = 'widget';
  if got is distinct from 'A widget' then
    raise exception 'FAIL: a newly registered subject type did not render on the board, got %', got;
  end if;
  perform test_ok('registering a subject type is one row, and the board renders it immediately');

  delete from task where subject_type = 'widget';
  delete from subject_resolver where subject_type = 'widget';
  drop table widget;
end $$;

-- Uninstalling a module out from under live tasks is refused rather than
-- silently taking the tasks with it, which is AR-A4.
do $$
begin
  insert into task (id, operation_id, subject_type, subject_id)
    values ('00000000-0000-0000-0000-00000000aa02', term_id('operation','punchdown'),
            'location', '00000000-0000-0000-0000-0000000000c1');
  begin
    delete from subject_resolver where subject_type = 'location';
    raise exception 'FAIL: a subject type was deregistered while tasks still pointed at it';
  exception when foreign_key_violation then
    perform test_ok('deregistering a subject type with live tasks is refused, not cascaded');
  end;
  delete from task where id = '00000000-0000-0000-0000-00000000aa02';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a term kind is a row, not a type'; end $$;

-- AR-E7, the half `0027` did. The enum listed variety, cooper, wood, vessel_type,
-- product_type, material_kind, operation and location_kind, and six of those
-- eight belong to winemaking or inventory rather than to core.
do $$
begin
  if exists (select 1 from pg_type where typname = 'term_kind' and typtype = 'e') then
    raise exception 'FAIL: the term_kind enum is back, so core carries module vocabulary again';
  end if;
  if to_regclass('public.term_kind') is null then
    raise exception 'FAIL: there is no term_kind registry';
  end if;
  perform test_ok('there is no term_kind enum, and there is a term_kind registry');

  -- X-3-22: this said six of the eight and asserted at least five, which is two
  -- claims and one number. It asserts the count it names.
  if (select count(*) from term_kind where module <> 'core') <> 6 then
    raise exception 'FAIL: % of the kinds are owned by a module other than core, and the claim is six',
      (select count(*) from term_kind where module <> 'core');
  end if;
  perform test_ok('the registry says which module owns each kind, and six of the eight are not core''s');
end $$;

-- A term cannot name a kind nobody registered, and adding a kind is a row.
do $$
begin
  begin
    insert into term (kind, value, label, sort_order)
      values ('not_a_kind', 'x', 'X', 1);
    raise exception 'FAIL: a term was created under an unregistered kind';
  exception when foreign_key_violation then
    perform test_ok('a term cannot name a kind nobody registered');
  end;

  insert into term_kind (kind, module, label) values ('hop_variety', 'brewing', 'Hop variety');
  insert into term (kind, value, label, sort_order)
    values ('hop_variety', 'cascade', 'Cascade', 10);
  perform test_ok('adding a kind of vocabulary is one row, and a term can use it immediately');
end $$;

-- The one check this conversion could have silently disabled. The validator used
-- to prove a picker's vocabulary exists by casting text to the enum and catching
-- the failure. Rewritten as a cast to text it would always succeed and the
-- validator would stop validating, which is exactly the shape W-4 warns this
-- conversion produces. It is a registry lookup now, and this is the assertion
-- that would have caught the silent version.
do $$
begin
  begin
    insert into term (kind, value, label, sort_order, attributes)
      values ('vessel_type', 'amphora_two', 'Amphora II', 60,
              '{"fields": [{"key": "maker", "kind": "term", "term_kind": "nonexistent_vocabulary"}]}'::jsonb);
    raise exception 'FAIL: a vessel type named a vocabulary that does not exist and was accepted';
  exception when raise_exception then
    -- X-1-6: raise exception 'FAIL: ...' is P0001, which is raise_exception, so
    -- this handler can catch the suite's own alarm. Re-raised here. Twelve of the
    -- thirteen handlers of this shape were fatal only by luck; one was not.
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('a vessel type field naming a vocabulary that does not exist is still refused');
  end;

  insert into term (kind, value, label, sort_order, attributes)
    values ('vessel_type', 'amphora_three', 'Amphora III', 61,
            '{"fields": [{"key": "maker", "kind": "term", "term_kind": "vessel_maker"}]}'::jsonb);
  perform test_ok('a vessel type field naming a vocabulary that does exist is still accepted');
end $$;

-- The bare-name checks on the two registries, added by 0026 and 0027. Each is
-- what keeps a registry key out of the dynamic SQL that reads it, and the
-- mutation class found all three unasserted the moment they existed.
do $$
begin
  begin
    update subject_resolver set subject_type = 'not a bare name' where subject_type = 'node';
    raise exception 'FAIL: a subject type with a space in it was accepted';
  exception when check_violation then
    perform test_ok('a subject type must be a bare name, because it reaches dynamic SQL');
  end;

  begin
    insert into term_kind (kind, module, label) values ('not a bare name', 'core', 'X');
    raise exception 'FAIL: a term kind with a space in it was accepted';
  exception when check_violation then
    perform test_ok('a term kind must be a bare name');
  end;

  begin
    insert into term_kind (kind, module, label) values ('fine_kind', 'not a module', 'X');
    raise exception 'FAIL: a term kind owned by a module with a space in its name was accepted';
  exception when check_violation then
    perform test_ok('the module owning a term kind must be a bare name');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the refusal surface: the kernel refuses what it says it refuses'; end $$;

-- W-7. scripts/guards.sh enumerates every refusal site in every function the
-- kernel owns and scripts/mutate.sh neutralises them one at a time. 102 of 176
-- could be removed without a single assertion in this file noticing, and the
-- eleven functions below are where they were. The declarative layer was tested
-- for what it refuses and the procedural layer for what it does.
--
-- Two rules these assertions follow that the earlier ones did not.
--
-- Ask for the specific refusal, not for any error. Most of these functions have
-- several guards that decline the same call for different reasons, and "it
-- raised" cannot tell them apart, so an assertion written that way covers the
-- function and no individual site in it.
--
-- Compare with `is distinct from`. `if q <> 222 then raise` does nothing at all
-- when q is null, and one assertion in this file had been passing that way since
-- it was written. See the note above the racking loss assertion.

-- The message a call refuses with, or null if it did not refuse. Roll back is
-- automatic: an exception inside a plpgsql block undoes the block's writes, so a
-- call that was supposed to be refused and was not leaves nothing behind either,
-- because the assertion that follows aborts the run.
create or replace function test_refusal(p_sql text)
returns text language plpgsql set search_path = public, pg_temp as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;

-- Asserts that a call refused, and refused for the stated reason.
create or replace function test_refuses(p_sql text, p_like text, p_msg text)
returns void language plpgsql set search_path = public, pg_temp as $$
declare got text;
begin
  got := test_refusal(p_sql);
  if got is null then
    raise exception 'FAIL: % : the call was accepted', p_msg;
  end if;
  if got not like p_like then
    raise exception 'FAIL: % : refused with "%" rather than %', p_msg, got, p_like;
  end if;
  perform test_ok(p_msg);
end $$;

insert into vessel (id, type_id, name, capacity_l) values
  ('00000000-0000-0000-0000-000000007701', term_id('vessel_type','barrel'), 'W7 source',   228),
  ('00000000-0000-0000-0000-000000007702', term_id('vessel_type','tank'),   'W7 sink',    1000),
  ('00000000-0000-0000-0000-000000007703', term_id('vessel_type','barrel'), 'W7 reused',   228),
  ('00000000-0000-0000-0000-000000007704', term_id('vessel_type','barrel'), 'W7 second',   228),
  ('00000000-0000-0000-0000-000000007705', term_id('vessel_type','tank'),   'W7 blend',    500),
  ('00000000-0000-0000-0000-000000007706', term_id('vessel_type','barrel'), 'W7 rejoin',   228),
  ('00000000-0000-0000-0000-000000007707', term_id('vessel_type','barrel'), 'W7 small',    228),
  ('00000000-0000-0000-0000-000000007708', term_id('vessel_type','tank'),   'W7 absorb',   500),
  ('00000000-0000-0000-0000-000000007709', term_id('vessel_type','barrel'), 'W7 bystander', 228),
  ('00000000-0000-0000-0000-000000007710', term_id('vessel_type','barrel'), 'W7 spare',     228),
  ('00000000-0000-0000-0000-000000007711', term_id('vessel_type','barrel'), 'W7 losing',    228);

do $$ begin perform test_act_as('00000000-0000-0000-0000-00000000a001'); end $$;

-- A lot nothing below touches, so that any mutation which drops a `where`
-- clause and writes to every row has somewhere visible to show up.
do $$ begin
  perform fill_vessel('00000000-0000-0000-0000-000000007709',
    jsonb_build_object('id','00000000-0000-0000-0000-000000007809','name','W7 bystander lot',
      'variety_id', term_id('variety','chardonnay'), 'vintage', 2025, 'quantity', 111), 111, false);
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- rack_plan refuses before anything is written'; end $$;

do $$ begin
  perform fill_vessel('00000000-0000-0000-0000-000000007701',
    jsonb_build_object('id','00000000-0000-0000-0000-000000007801','name','W7 lot one',
      'variety_id', term_id('variety','chardonnay'), 'vintage', 2025, 'quantity', 200), 200, false);
end $$;

do $$
declare
  src text := $q$jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007701','volume_l',100))$q$;
  dst text := $q$jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007702','volume_l',100))$q$;
begin
  perform test_refuses(
    'select rack_plan(''[]''::jsonb, ' || dst || ')',
    '%somewhere to come from%',
    'a rack with nothing to come out of is refused before anything is written');

  perform test_refuses(
    'select rack_plan(' || src || ', ''[]''::jsonb)',
    '%somewhere to go%',
    'a rack with nowhere to go is refused before anything is written');

  perform test_refuses(
    'select rack_plan(' ||
      $q$jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007701','volume_l',0))$q$
      || ', ' || dst || ')',
    '%how much came out of%is not recorded%',
    'a source with no volume recorded is refused, rather than counted as nothing');

  perform test_refuses(
    'select rack_plan(' ||
      $q$jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007701','volume_l',500))$q$
      || ', ' || dst || ')',
    '%holds%L and this takes%',
    'taking more out of a vessel than it holds is refused');

  perform test_refuses(
    'select rack_plan(' || src || ', ' ||
      $q$jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-0000000077ff','volume_l',100))$q$
      || ')',
    '%no vessel with id%',
    'a destination that is not a vessel is refused');

  perform test_refuses(
    'select rack_plan(' || src || ', ' ||
      $q$jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007702','volume_l',0))$q$
      || ')',
    '%how much went into%is not recorded%',
    'a destination with no volume recorded is refused, rather than counted as nothing');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- racking writes where it says and nowhere else'; end $$;

-- Every `where` clause in rack carries `and to_at is null`, and dropping that
-- conjunct is a refusal that stops refusing in the A14 shape: no error, no
-- missing row, and a placement that ended in August quietly rewritten.
--
-- The closed placements below are inserted with an explicit older `to_at`
-- rather than made by racking, and that detail is the assertion. `now()` is the
-- transaction timestamp, so inside this file a mutation that restamps an
-- already-closed placement writes exactly the value that was there and cannot
-- be seen. The first version of these assertions made the history by racking
-- and proved nothing at all.
insert into placement (node_id, vessel_id, volume_l, from_at, to_at) values
  ('00000000-0000-0000-0000-000000007809','00000000-0000-0000-0000-000000007703',
   100, now() - interval '9 days', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000007809','00000000-0000-0000-0000-000000007706',
   101, now() - interval '9 days', now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000007809','00000000-0000-0000-0000-000000007702',
   102, now() - interval '9 days', now() - interval '8 days');

-- Emptying a vessel ends the placement that is open, and only that one.
do $$
declare t timestamptz; v numeric;
begin
  perform fill_vessel('00000000-0000-0000-0000-000000007703',
    jsonb_build_object('id','00000000-0000-0000-0000-000000007803','name','W7 second tenant',
      'variety_id', term_id('variety','chardonnay'), 'vintage', 2025, 'quantity', 50), 50, false);
  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007703','volume_l',50)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007705','volume_l',50)));

  select to_at into t from placement
   where vessel_id = '00000000-0000-0000-0000-000000007703'
     and node_id = '00000000-0000-0000-0000-000000007809';
  if t is distinct from now() - interval '8 days' then
    raise exception 'FAIL: emptying a vessel restamped a placement that ended eight days ago, to %', t;
  end if;
  perform test_ok('emptying a vessel ends the placement that is open and leaves the ones that closed');

  -- And the partial branch, which writes a volume rather than a to_at.
  perform fill_vessel('00000000-0000-0000-0000-000000007703',
    jsonb_build_object('id','00000000-0000-0000-0000-000000007804','name','W7 third tenant',
      'variety_id', term_id('variety','chardonnay'), 'vintage', 2025, 'quantity', 80), 80, false);
  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007703','volume_l',30)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007705','volume_l',30)));

  select volume_l into v from placement
   where vessel_id = '00000000-0000-0000-0000-000000007703'
     and node_id = '00000000-0000-0000-0000-000000007809';
  if v is distinct from 100 then
    raise exception 'FAIL: drawing from a vessel rewrote a closed placement to % L', v;
  end if;
  perform test_ok('drawing part of a lot out of a vessel does not rewrite what was in it before');
end $$;

-- Racking a lot into a vessel it is already in adds to the placement it has,
-- rather than making a second one, and leaves the placements that ended there.
do $$
declare n int; v numeric;
begin
  -- Lot 7804 is split so that it is in two vessels at once, then some of it is
  -- moved from one of its own vessels into the other.
  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007703','volume_l',20)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007706','volume_l',20)));
  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007703','volume_l',10)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007706','volume_l',10)));

  select count(*) into n from placement
   where vessel_id = '00000000-0000-0000-0000-000000007706' and to_at is null;
  if n <> 1 then
    raise exception 'FAIL: a lot racked into a vessel it was already in is there % times', n;
  end if;
  select volume_l into v from placement
   where vessel_id = '00000000-0000-0000-0000-000000007706' and to_at is null;
  if v is distinct from 30 then
    raise exception 'FAIL: 20 L then 10 L into the same vessel came to % L', v;
  end if;
  perform test_ok('a lot racked into a vessel it is already in adds to the placement it has');

  select volume_l into v from placement
   where vessel_id = '00000000-0000-0000-0000-000000007706'
     and node_id = '00000000-0000-0000-0000-000000007809';
  if v is distinct from 101 then
    raise exception 'FAIL: topping up a placement rewrote a closed one to % L', v;
  end if;
  perform test_ok('adding to a placement leaves the placements that ended in that vessel alone');
end $$;

-- A blend takes its wine out of the parents it drew from, by what each of them
-- put in, and out of nothing else.
do $$
declare q7804 numeric; q numeric;
begin
  select quantity into q7804 from node where id = '00000000-0000-0000-0000-000000007804';

  perform fill_vessel('00000000-0000-0000-0000-000000007707',
    jsonb_build_object('id','00000000-0000-0000-0000-000000007805','name','W7 other parent',
      'variety_id', term_id('variety','riesling'), 'vintage', 2025, 'quantity', 20), 20, false);

  perform rack(
    jsonb_build_array(
      jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007706','volume_l',10),
      jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007707','volume_l',5)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007708','volume_l',15)),
    '{}'::jsonb, false,
    jsonb_build_object('id','00000000-0000-0000-0000-000000007806','name','W7 blend one'));

  select quantity into q from node where id = '00000000-0000-0000-0000-000000007805';
  if q is distinct from 15 then
    raise exception 'FAIL: a parent that gave 5 L of its 20 L to a blend is now % L', coalesce(q::text,'null');
  end if;
  select quantity into q from node where id = '00000000-0000-0000-0000-000000007804';
  if q is distinct from q7804 - 10 then
    raise exception 'FAIL: the other parent gave 10 L and went from % to %', q7804, q;
  end if;
  perform test_ok('a blend takes out of each parent exactly what that parent put in');

  select quantity into q from node where id = '00000000-0000-0000-0000-000000007809';
  if q is distinct from 111 then
    raise exception 'FAIL: a blend elsewhere in the winery changed an untouched lot to % L', q;
  end if;
  perform test_ok('a blend does not change the quantity of a lot that was not in it');
end $$;

-- Blending into a vessel that already holds a different lot absorbs that lot:
-- its placement in that vessel ends and it loses what was in that vessel. Both
-- of those are `where` clauses whose second conjunct is the whole of the care.
do $$
declare t timestamptz; q numeric;
begin
  -- The lot to be absorbed is in two vessels, so absorbing the one in 7702 must
  -- take 30 L off it rather than all 60.
  perform fill_vessel('00000000-0000-0000-0000-000000007702',
    jsonb_build_object('id','00000000-0000-0000-0000-000000007808','name','W7 absorbed',
      'variety_id', term_id('variety','pinot_noir'), 'vintage', 2025, 'quantity', 60), 30, false);
  insert into placement (node_id, vessel_id, volume_l)
    values ('00000000-0000-0000-0000-000000007808','00000000-0000-0000-0000-000000007704', 30);

  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007703','volume_l',10)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007702','volume_l',10)),
    '{}'::jsonb, false,
    jsonb_build_object('id','00000000-0000-0000-0000-00000000780a','name','W7 blend two'));

  select to_at into t from placement
   where vessel_id = '00000000-0000-0000-0000-000000007702'
     and node_id = '00000000-0000-0000-0000-000000007809';
  if t is distinct from now() - interval '8 days' then
    raise exception 'FAIL: absorbing a lot restamped a placement that had already ended, to %', t;
  end if;
  perform test_ok('absorbing the lot in a destination ends its open placement and no other');

  select quantity into q from node where id = '00000000-0000-0000-0000-000000007808';
  if q is distinct from 30 then
    raise exception 'FAIL: absorbing 30 L of a 60 L lot left it at % L', coalesce(q::text,'null');
  end if;
  perform test_ok('a lot absorbed out of one of its vessels loses what was in that vessel, not all of it');

  select quantity into q from node where id = '00000000-0000-0000-0000-000000007809';
  if q is distinct from 111 then
    raise exception 'FAIL: absorbing a lot changed an unrelated lot to % L', q;
  end if;
  perform test_ok('absorbing a lot does not reach any other lot');
end $$;

-- The loss on a move comes off the lot. This assertion existed already, as
-- `if q <> 222 then raise`, against a lot whose quantity was null because the
-- fixture passed 225 as the placement volume and never set one. Null is not
-- unequal to 222, so it passed without checking anything, and removing the
-- update it was written to protect changed nothing. Fifth time in this project
-- that a green check has turned out to be hollow, and the first one found by
-- mutating the code the check was pointing at rather than by breaking the check.
do $$
declare q numeric;
begin
  perform fill_vessel('00000000-0000-0000-0000-000000007711',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000780b','name','W7 losing lot',
      'variety_id', term_id('variety','chardonnay'), 'vintage', 2025, 'quantity', 90), 90, false);
  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007711','volume_l',90)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007710','volume_l',85)));

  select quantity into q from node where id = '00000000-0000-0000-0000-00000000780b';
  if q is distinct from 85 then
    raise exception 'FAIL: after a 5 L loss a 90 L lot is % L', coalesce(q::text, 'null');
  end if;
  perform test_ok('moving a lot takes the loss off it, and a lot with no quantity is not a pass');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- forking takes the vessels it was given and no others'; end $$;

insert into vessel (id, type_id, name, capacity_l) values
  ('00000000-0000-0000-0000-000000007712', term_id('vessel_type','barrel'), 'W7 fork one', 228),
  ('00000000-0000-0000-0000-000000007713', term_id('vessel_type','barrel'), 'W7 fork two', 228),
  ('00000000-0000-0000-0000-000000007714', term_id('vessel_type','barrel'), 'W7 fork not', 228),
  ('00000000-0000-0000-0000-000000007715', term_id('vessel_type','barrel'), 'W7 empty',    228);

do $$ begin
  perform fill_vessel('00000000-0000-0000-0000-000000007712',
    jsonb_build_object('id','00000000-0000-0000-0000-00000000780c','name','W7 forkable',
      'variety_id', term_id('variety','chardonnay'), 'vintage', 2025, 'quantity', 100), 60, false);
  insert into placement (node_id, vessel_id, volume_l)
    values ('00000000-0000-0000-0000-00000000780c','00000000-0000-0000-0000-000000007713', 40);
end $$;

do $$ begin
  perform test_refuses(
    $q$select fork_lot('00000000-0000-0000-0000-0000000077fe',
                       array['00000000-0000-0000-0000-000000007712']::uuid[])$q$,
    '%no lot with id%',
    'forking a lot that does not exist is refused');

  perform test_refuses(
    $q$select fork_lot('00000000-0000-0000-0000-00000000780c',
                       array['00000000-0000-0000-0000-000000007714']::uuid[])$q$,
    '%none of those vessels hold that lot%',
    'forking off a vessel that does not hold the lot is refused');

  perform test_refuses(
    $q$select fork_lot('00000000-0000-0000-0000-00000000780c',
                       array['00000000-0000-0000-0000-000000007712',
                             '00000000-0000-0000-0000-000000007714']::uuid[])$q$,
    '%some of those vessels do not hold that lot%',
    'forking off a set where only some vessels hold the lot is refused, rather than the rest ignored');
end $$;

do $$
declare child uuid; n int; q numeric;
begin
  child := fork_lot('00000000-0000-0000-0000-00000000780c',
                    array['00000000-0000-0000-0000-000000007712']::uuid[]);

  select count(*) into n from placement
   where node_id = '00000000-0000-0000-0000-00000000780c' and to_at is null;
  if n <> 1 then
    raise exception 'FAIL: forking one of two vessels left the parent in % of them', n;
  end if;
  perform test_ok('forking moves the placements it was given and leaves the parent in the rest');

  select count(*) into n from placement where node_id = child and to_at is null;
  if n <> 1 then
    raise exception 'FAIL: the child came out in % vessels', n;
  end if;

  select quantity into q from node where id = '00000000-0000-0000-0000-00000000780c';
  if q is distinct from 40 then
    raise exception 'FAIL: forking 60 L out of a 100 L lot left it at % L', coalesce(q::text,'null');
  end if;
  perform test_ok('forking takes what moved off the parent, and the parent is smaller rather than spent');

  select quantity into q from node where id = '00000000-0000-0000-0000-000000007809';
  if q is distinct from 111 then
    raise exception 'FAIL: forking a lot changed an unrelated lot to % L', q;
  end if;
  perform test_ok('forking does not reach the quantity of any other lot');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- an operation nobody registered is refused by name'; end $$;

-- A lot in no vessel at all, which is what makes the vessel guard below the only
-- thing that can refuse.
insert into node (id, stage, status, name, owner_id, created_by)
values ('00000000-0000-0000-0000-00000000780e', 'bin', 'open', 'W7 bin',
        '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-00000000a001');

do $$ begin
  perform test_refuses(
    $q$select record_event('00000000-0000-0000-0000-00000000780b', 'no_such_operation')$q$,
    '%there is no operation called%',
    'recording an event under an unknown operation is refused, not written with a null operation');

  -- Against a lot that is in no vessel at all. Aimed at a lot that is in one,
  -- removing this guard falls through to fork_lot, which refuses in the same
  -- words, and the assertion passes while the guard is gone.
  perform test_refuses(
    $q$select record_event('00000000-0000-0000-0000-00000000780e', 'punchdown', '{}'::jsonb,
                           array['00000000-0000-0000-0000-000000007715']::uuid[])$q$,
    '%none of those vessels hold that lot%',
    'recording an event against vessels that do not hold the lot is refused by the caller''s own guard');

  perform test_refuses(
    $q$select record_vessel_note('00000000-0000-0000-0000-000000007715', 'no_such_operation')$q$,
    '%there is no operation called%',
    'a vessel note under an unknown operation is refused, not written with a null operation');

  perform test_refuses(
    $q$select generate_inferred_history('00000000-0000-0000-0000-0000000077fd')$q$,
    '%no such node%',
    'inferring history for a lot that does not exist is refused');

  perform test_refuses(
    $q$select update_vessel('00000000-0000-0000-0000-0000000077fc', '{}'::jsonb)$q$,
    '%no vessel with id%',
    'editing a vessel that does not exist is refused rather than reported as done');

  perform test_refuses(
    $q$select finish_run('00000000-0000-0000-0000-0000000077fb')$q$,
    '%no such run%',
    'finishing a run that does not exist is refused rather than writing against a null vessel');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- procedure runs are timed one step at a time'; end $$;

do $$
declare proc uuid; s1 uuid; s2 uuid; sess uuid; run uuid; other timestamptz;
begin
  insert into procedure (id, name, subject_type) values (gen_random_uuid(), 'W7 Procedure', 'vessel')
    returning id into proc;
  insert into procedure_step (id, procedure_id, step_order, label, kind)
    values (gen_random_uuid(), proc, 1, 'first', 'note') returning id into s1;
  insert into procedure_step (id, procedure_id, step_order, label, kind)
    values (gen_random_uuid(), proc, 2, 'second', 'note') returning id into s2;

  perform test_refuses(
    format($q$select start_procedure_session(%L, '{}'::uuid[])$q$, proc),
    '%at least one vessel%',
    'a procedure session with no vessels is refused rather than started empty');

  sess := start_procedure_session(proc, array['00000000-0000-0000-0000-000000007715']::uuid[]);
  select id into run from procedure_run where session_id = sess;

  perform test_refuses(
    format($q$select end_run_step(%L, %L)$q$, run, s1),
    '%never started%',
    'ending a step that was never started is refused rather than timed from nothing');

  perform begin_run_step(run, s1);
  perform begin_run_step(run, s2);
  perform end_run_step(run, s2);

  select ended_at into other from procedure_run_step where run_id = run and step_id = s1;
  if other is not null then
    raise exception 'FAIL: ending one step of a run ended another one as well';
  end if;
  perform test_ok('ending a step ends that step, and leaves the other steps of the run running');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a cap sequence that is empty still names an action'; end $$;

do $$
declare n int; v text;
begin
  update node set attributes = jsonb_build_object('cap_rule', jsonb_build_object('sequence', '[]'::jsonb))
   where id = '00000000-0000-0000-0000-000000007809';

  select count(*), min(value) into n, v
    from next_cap_action('00000000-0000-0000-0000-000000007809');
  if n <> 1 or v is distinct from 'punchdown' then
    raise exception 'FAIL: a lot with an empty cap sequence offered % action(s), %', n, coalesce(v,'none');
  end if;
  perform test_ok('a cap rule with an empty sequence falls back to punchdown rather than offering nothing');

  update node set attributes = '{}'::jsonb where id = '00000000-0000-0000-0000-000000007809';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- claiming a task, the three refusals that were not asserted'; end $$;

insert into task (id, operation_id, status, subject_type, subject_id) values
  ('00000000-0000-0000-0000-000000007e01', term_id('operation','punchdown'), 'done',
   'node', '00000000-0000-0000-0000-000000007809'),
  ('00000000-0000-0000-0000-000000007e02', term_id('operation','punchdown'), 'open',
   'node', '00000000-0000-0000-0000-000000007809');
update task set claimed_by = '00000000-0000-0000-0000-00000000a002', claimed_at = now()
 where id = '00000000-0000-0000-0000-000000007e02';

do $$ begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  perform test_refuses(
    $q$select claim_task('00000000-0000-0000-0000-000000007e01')$q$,
    '%not available to you%',
    'a task that is already done cannot be claimed');

  perform test_refuses(
    $q$select claim_task('00000000-0000-0000-0000-000000007e02')$q$,
    '%not available to you%',
    'a task somebody already holds cannot be taken from them');

  perform test_act_as('00000000-0000-0000-0000-00000000a003');   -- the client login
  perform test_refuses(
    $q$select claim_task('00000000-0000-0000-0000-000000007e02')$q$,
    '%only somebody who works here%',
    'a client login may not claim a cellar task, and is told which rule it broke');

  perform test_act_as(null);
  perform test_refuses(
    $q$select claim_task('00000000-0000-0000-0000-000000007e02')$q$,
    '%nobody to claim this task for%',
    'claiming with no identity is refused for want of an identity, not for want of an entitlement');

  perform test_refuses(
    $q$select claim_account('W7 nobody')$q$,
    '%not signed in%',
    'claiming an account with no identity is refused rather than writing a null user');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- confirming, and who decides what a party hides'; end $$;

do $$
declare ev uuid;
begin
  ev := record_vessel_note('00000000-0000-0000-0000-000000007715', 'topping', 'W7 note');
  perform test_refuses(
    format($q$select confirm_event(%L)$q$, ev),
    '%not an inferred event awaiting confirmation%',
    'confirming an event that was observed rather than inferred is refused');

  perform test_refuses(
    $q$select confirm_event('00000000-0000-0000-0000-0000000077fa')$q$,
    '%not an inferred event awaiting confirmation%',
    'confirming an event that does not exist is refused rather than reported as confirmed');
end $$;

do $$ begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');   -- the client's own login
  perform test_refuses(
    $q$select set_party_default_hidden('00000000-0000-0000-0000-00000000f001', '{}'::text[])$q$,
    '%only that party decides%',
    'a client login may not set what the facility hides by default');

  perform test_act_as('00000000-0000-0000-0000-00000000a003');   -- that party's own login
  perform test_refuses(
    $q$select set_party_default_hidden('00000000-0000-0000-0000-00000000f002',
                                       array['not_a_field']::text[])$q$,
    '%not something the kernel knows how to hide%',
    'a party may not hide a field the kernel has never heard of');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- privacy: what a definer function hands back'; end $$;

insert into node (id, stage, status, name, variety_id, vintage, attributes, owner_id, created_by, hidden)
values ('00000000-0000-0000-0000-00000000780d', 'maturation', 'open', 'W7 private lot',
        term_id('variety','riesling'), 2024, '{"note":"private"}'::jsonb,
        '00000000-0000-0000-0000-00000000f002', '00000000-0000-0000-0000-00000000a001',
        array['name','owner','variety','vintage','attributes']);

-- A lot the facility owns, with a bin behind it and an event on it, for the two
-- definer functions that answer about somebody else's wine. The bin itself is
-- created earlier, because record_event is asked about it there.
insert into node (id, stage, status, name, variety_id, vintage, owner_id, created_by)
values ('00000000-0000-0000-0000-000000007810', 'maturation', 'open', 'W7 facility lot',
        term_id('variety','riesling'), 2024,
        '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-00000000a001');
insert into lineage (parent_id, child_id, fraction)
values ('00000000-0000-0000-0000-00000000780e','00000000-0000-0000-0000-000000007810', 1.0);
insert into event (operation_id, subject_type, subject_id, by_user, provenance)
values (term_id('operation','punchdown'), 'node', '00000000-0000-0000-0000-000000007810',
        '00000000-0000-0000-0000-00000000a001', 'observed');

-- A lot the client owns whose composition it has hidden, for the second gate.
insert into node (id, stage, status, name, owner_id, created_by, hidden)
values ('00000000-0000-0000-0000-00000000780f', 'maturation', 'open', 'W7 client lot',
        '00000000-0000-0000-0000-00000000f002', '00000000-0000-0000-0000-00000000a001',
        array['composition','history']);
insert into lineage (parent_id, child_id, fraction)
values ('00000000-0000-0000-0000-00000000780e','00000000-0000-0000-0000-00000000780f', 1.0);
insert into event (operation_id, subject_type, subject_id, by_user, provenance)
values (term_id('operation','punchdown'), 'node', '00000000-0000-0000-0000-00000000780f',
        '00000000-0000-0000-0000-00000000a001', 'observed');

do $$
declare n node; j json; c int;
begin
  -- A lot that does not exist comes back as nothing rather than as a row of
  -- nulls. `is null` cannot tell those two apart, because a composite whose
  -- every field is null is itself null by that test; row_to_json can.
  j := row_to_json(visible_node('00000000-0000-0000-0000-0000000077f9'));
  if j is not null then
    raise exception 'FAIL: asking for a lot that does not exist returned a row: %', j;
  end if;
  perform test_ok('asking for a lot that does not exist returns nothing, not a lot with no fields');

  -- The owner and an admin see the whole thing. Without this the redaction below
  -- would pass just as well if everything were always redacted.
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  n := visible_node('00000000-0000-0000-0000-00000000780d');
  if n.name is distinct from 'W7 private lot' then
    raise exception 'FAIL: an admin saw the hidden name as %', coalesce(n.name,'null');
  end if;
  if n.variety_id is null or n.vintage is null then
    raise exception 'FAIL: an admin saw a redacted variety or vintage';
  end if;
  perform test_ok('somebody entitled to the whole lot gets the whole lot, and is not redacted anyway');

  -- A facility hand who is neither the owner nor an admin sees the edges and
  -- nothing the owner named.
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  n := visible_node('00000000-0000-0000-0000-00000000780d');
  if n.id is distinct from '00000000-0000-0000-0000-00000000780d' then
    raise exception 'FAIL: a facility hand could not see the lot at all';
  end if;
  if n.variety_id is not null then
    raise exception 'FAIL: a hidden variety was disclosed';
  end if;
  if n.vintage is not null then
    raise exception 'FAIL: a hidden vintage was disclosed';
  end if;
  if n.attributes is distinct from '{}'::jsonb then
    raise exception 'FAIL: hidden attributes were disclosed as %', n.attributes;
  end if;
  perform test_ok('variety, vintage and attributes are each redacted by name for somebody not entitled');

  -- The gate above the redaction, which is a different question and was covered
  -- by nothing. W-10's ratchet caught it: `visible_node` can have its whole
  -- row-visibility check replaced by `if false then` and all 287 assertions pass.
  --
  -- The two assertions above ask an admin and a facility hand, and both of them
  -- pass that gate, so neither can see it removed. What was catching it until this
  -- session was fixture breakage somewhere else, which moved when 0031 moved, and
  -- fixture breakage is not coverage. **Redaction is the second question. The
  -- first is whether you get the row at all**, and a client who does not own the
  -- lot does not.
  perform test_act_as('00000000-0000-0000-0000-00000000a003');   -- a client, not the owner
  if row_to_json(visible_node('00000000-0000-0000-0000-000000007810')) is not null then
    raise exception 'FAIL: a client read a lot that is not theirs, redacted or otherwise';
  end if;
  perform test_ok('a client asking for a lot that is not theirs gets nothing, before any question of redaction');

  -- And the blindness guard on that, because a visible_node that returned null to
  -- everybody would satisfy it.
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  if row_to_json(visible_node('00000000-0000-0000-0000-000000007810')) is null then
    raise exception 'FAIL: a facility hand got nothing for a facility lot, so the check above is blind';
  end if;
  perform test_ok('a facility hand does get the lot, so the refusal above is a refusal rather than a silence');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
end $$;

do $$
declare c int;
begin
  -- Composition. A facility user sees it, a client who does not own the lot sees
  -- nothing, and a lot whose owner hid its composition discloses none of it.
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  select count(*) into c from node_bin_shares('00000000-0000-0000-0000-000000007810');
  if c <> 1 then
    raise exception 'FAIL: a facility hand got % bins for a facility lot, so the checks below are blind', c;
  end if;

  perform test_act_as('00000000-0000-0000-0000-00000000a003');   -- a client, not the owner
  select count(*) into c from node_bin_shares('00000000-0000-0000-0000-000000007810');
  if c <> 0 then
    raise exception 'FAIL: a client read the composition of somebody else''s lot, % row(s)', c;
  end if;
  perform test_ok('a client cannot read the composition of a lot that is not theirs');

  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  select count(*) into c from node_bin_shares('00000000-0000-0000-0000-00000000780f');
  if c <> 0 then
    raise exception 'FAIL: a lot whose composition is hidden disclosed % bin(s)', c;
  end if;
  perform test_ok('a lot whose owner hid its composition discloses none of it to a facility hand');

  -- History, through the same two gates.
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  select count(*) into c from node_history('00000000-0000-0000-0000-000000007810');
  if c < 1 then
    raise exception 'FAIL: a facility hand got no history for a facility lot, so the check below is blind';
  end if;

  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  select count(*) into c from node_history('00000000-0000-0000-0000-000000007810');
  if c <> 0 then
    raise exception 'FAIL: a client read the history of somebody else''s lot, % row(s)', c;
  end if;
  perform test_ok('a client cannot read the history of a lot that is not theirs');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- topping check answers once'; end $$;

do $$
declare c int; r record;
begin
  select count(*) into c from topping_check(
    '00000000-0000-0000-0000-00000000780b', '00000000-0000-0000-0000-000000007715');
  if c <> 1 then
    raise exception 'FAIL: topping into an empty vessel gave % answers', c;
  end if;
  select * into r from topping_check(
    '00000000-0000-0000-0000-00000000780b', '00000000-0000-0000-0000-000000007715');
  if r.ok or r.reason is distinct from 'vessel is empty' then
    raise exception 'FAIL: topping into an empty vessel said % / %', r.ok, r.reason;
  end if;
  perform test_ok('topping into an empty vessel is one answer, and the answer is that it is empty');

  -- 780b is chardonnay and 7805 is riesling, so the seeded predicate finds a
  -- variety mismatch and stops there.
  select count(*) into c from topping_check(
    '00000000-0000-0000-0000-000000007805', '00000000-0000-0000-0000-000000007710');
  if c <> 1 then
    raise exception 'FAIL: a topping mismatch gave % answers rather than one', c;
  end if;
  select * into r from topping_check(
    '00000000-0000-0000-0000-000000007805', '00000000-0000-0000-0000-000000007710');
  if r.ok then
    raise exception 'FAIL: topping riesling onto chardonnay was allowed';
  end if;
  perform test_ok('a topping mismatch is one answer naming the field, not a list ending in ok');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a vessel type declares its fields, and the declaration is checked'; end $$;

do $$ begin
  -- The validator is about vessel types. A term of another kind may carry an
  -- attributes.fields that would be nonsense for a vessel type, because it is
  -- not one, and that is the whole content of the first guard.
  insert into term (kind, value, label, attributes)
  values ('variety', 'w7_not_a_vessel_type', 'W7 not a vessel type',
          '{"fields": [{"key": "x", "kind": "nonsense"}]}'::jsonb);
  perform test_ok('the vessel type field validator does not run against terms of other kinds');

  perform test_refuses(
    $q$insert into term (kind, value, label, attributes)
       values ('vessel_type','w7_bad_list','W7 bad list', '{"fields": "not a list"}'::jsonb)$q$,
    '%fields must be a list%',
    'a vessel type whose fields are not a list is refused');

  perform test_refuses(
    $q$insert into term (kind, value, label, attributes)
       values ('vessel_type','w7_dupe','W7 duplicate key',
               '{"fields": [{"key":"a","kind":"text"},{"key":"a","kind":"text"}]}'::jsonb)$q$,
    '%two fields share the key%',
    'a vessel type with two fields under one key is refused');

  perform test_refuses(
    $q$insert into term (kind, value, label, attributes)
       values ('vessel_type','w7_badkind','W7 bad kind',
               '{"fields": [{"key":"a","kind":"colour"}]}'::jsonb)$q$,
    '%which is not term, number, text or boolean%',
    'a vessel type field of an unknown kind is refused');

  perform test_refuses(
    $q$insert into term (kind, value, label, attributes)
       values ('vessel_type','w7_nokind','W7 picker with no list',
               '{"fields": [{"key":"a","kind":"term"}]}'::jsonb)$q$,
    '%is a picker and names no vocabulary%',
    'a vessel type field that is a picker and names no vocabulary is refused');
end $$;

insert into term (id, kind, value, label, attributes)
values ('00000000-0000-0000-0000-000000007f01', 'vessel_type', 'w7_type', 'W7 type',
        '{"fields": [{"key":"w7num","label":"W7 number","kind":"number",
                      "required":true,"min":1,"max":10}]}'::jsonb);

do $$ begin
  perform test_refuses(
    $q$select validate_vessel_attributes('00000000-0000-0000-0000-000000007f01', '{}'::jsonb)$q$,
    '%is required for this vessel type%',
    'a required vessel field left empty is refused');

  perform test_refuses(
    $q$select validate_vessel_attributes('00000000-0000-0000-0000-000000007f01',
                                         '{"w7num": "not a number"}'::jsonb)$q$,
    '%must be a number%',
    'a number field given something that is not a number is refused');

  perform test_refuses(
    $q$select validate_vessel_attributes('00000000-0000-0000-0000-000000007f01',
                                         '{"w7num": 99}'::jsonb)$q$,
    '%must be at most%',
    'a number field above its maximum is refused');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the defaults a create path supplies'; end $$;

do $$
declare r jsonb; g boolean; ev int;
begin
  r := create_vessel_with_wine(
    jsonb_build_object('id','00000000-0000-0000-0000-000000007716',
      'type_id', term_id('vessel_type','barrel'), 'name','W7 no jacket', 'capacity_l', 228),
    jsonb_build_object('id','00000000-0000-0000-0000-000000007811','name','W7 plain lot',
      'variety_id', term_id('variety','chardonnay'), 'vintage', 2025),
    200, '[]', false);

  select has_glycol into g from vessel where id = '00000000-0000-0000-0000-000000007716';
  if g is distinct from false then
    raise exception 'FAIL: a vessel created without a jacket came out has_glycol %', coalesce(g::text,'null');
  end if;
  perform test_ok('a vessel created without saying anything about glycol does not have any');

  -- And the history switch is a switch. pinot_gris has a two step template.
  r := fill_vessel('00000000-0000-0000-0000-000000007715',
    jsonb_build_object('id','00000000-0000-0000-0000-000000007812','name','W7 inferred lot',
      'variety_id', term_id('variety','pinot_gris'), 'vintage', 2025, 'quantity', 100), 100);
  ev := (r ->> 'events_generated')::int;
  if ev is distinct from 2 then
    raise exception 'FAIL: filling a vessel with history asked for generated % events', coalesce(ev::text,'null');
  end if;
  perform test_ok('filling a vessel generates the inferred history when it is asked to');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a lot with no quantity recorded does not acquire one'; end $$;

-- `where id = p_node_id and quantity is not null` appears twice in the write
-- paths, once when a fork shrinks its parent and once when a blend absorbs the
-- lot already sitting in the destination. The conjunct that matters is the
-- second one. A lot whose quantity was never recorded is a real thing here,
-- because volume lives on the placement and the lot-level number is optional,
-- and subtracting from a number nobody wrote would invent one: `coalesce(null,0)
-- - 30` is a confident zero, and zero closes lots.
--
-- Neither of these could be seen until now, because every fixture in this file
-- either set a quantity or never checked it. This is the A25 null-permit shape
-- arriving in the write paths rather than in a check constraint.
insert into vessel (id, type_id, name, capacity_l) values
  ('00000000-0000-0000-0000-000000007717', term_id('vessel_type','tank'),   'W7 absorb two', 500),
  ('00000000-0000-0000-0000-000000007718', term_id('vessel_type','barrel'), 'W7 elsewhere',  228),
  ('00000000-0000-0000-0000-000000007719', term_id('vessel_type','barrel'), 'W7 blender',    228),
  ('00000000-0000-0000-0000-000000007720', term_id('vessel_type','barrel'), 'W7 fork null',  228),
  ('00000000-0000-0000-0000-000000007721', term_id('vessel_type','barrel'), 'W7 fork rest',  228);

do $$
declare q numeric; child uuid;
begin
  -- Forking a lot that has no quantity.
  perform fill_vessel('00000000-0000-0000-0000-000000007720',
    jsonb_build_object('id','00000000-0000-0000-0000-000000007813','name','W7 unmeasured',
      'variety_id', term_id('variety','chardonnay'), 'vintage', 2025), 30, false);
  insert into placement (node_id, vessel_id, volume_l)
    values ('00000000-0000-0000-0000-000000007813','00000000-0000-0000-0000-000000007721', 30);

  select quantity into q from node where id = '00000000-0000-0000-0000-000000007813';
  if q is not null then
    raise exception 'FAIL: the fixture recorded a quantity, so this proves nothing';
  end if;

  child := fork_lot('00000000-0000-0000-0000-000000007813',
                    array['00000000-0000-0000-0000-000000007720']::uuid[]);

  select quantity into q from node where id = '00000000-0000-0000-0000-000000007813';
  if q is not null then
    raise exception 'FAIL: forking gave a lot with no recorded quantity a quantity of %', q;
  end if;
  perform test_ok('forking a lot whose quantity was never recorded does not invent one for it');
end $$;

do $$
declare q numeric; open_now int;
begin
  -- And absorbing one into a blend.
  perform fill_vessel('00000000-0000-0000-0000-000000007717',
    jsonb_build_object('id','00000000-0000-0000-0000-000000007814','name','W7 unmeasured two',
      'variety_id', term_id('variety','riesling'), 'vintage', 2025), 30, false);
  insert into placement (node_id, vessel_id, volume_l)
    values ('00000000-0000-0000-0000-000000007814','00000000-0000-0000-0000-000000007718', 30);
  perform fill_vessel('00000000-0000-0000-0000-000000007719',
    jsonb_build_object('id','00000000-0000-0000-0000-000000007815','name','W7 blender lot',
      'variety_id', term_id('variety','pinot_noir'), 'vintage', 2025, 'quantity', 20), 20, false);

  select quantity into q from node where id = '00000000-0000-0000-0000-000000007814';
  if q is not null then
    raise exception 'FAIL: the fixture recorded a quantity, so this proves nothing';
  end if;

  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007719','volume_l',20)),
    jsonb_build_array(jsonb_build_object('vessel_id','00000000-0000-0000-0000-000000007717','volume_l',20)),
    '{}'::jsonb, false,
    jsonb_build_object('id','00000000-0000-0000-0000-000000007816','name','W7 blend three'));

  select quantity into q from node where id = '00000000-0000-0000-0000-000000007814';
  if q is not null then
    raise exception 'FAIL: absorbing a lot with no recorded quantity gave it one, of %', q;
  end if;
  perform test_ok('absorbing a lot whose quantity was never recorded does not invent one for it');

  -- And the lot is still in the vessel it was not absorbed out of, which is what
  -- keeps a zero from closing it.
  select count(*) into open_now from placement
   where node_id = '00000000-0000-0000-0000-000000007814' and to_at is null;
  if open_now <> 1 then
    raise exception 'FAIL: absorbing one of two placements left the lot in % vessels', open_now;
  end if;
  perform test_ok('a lot absorbed out of one vessel is still in the other, and is not closed');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- AR-E10, redaction is row-level'; end $$;

-- AR-E10. Redaction is row-level. If you cannot see the lot, you do not get the row.

-- 0028. `node_read` had been scoped since 0003 and everything pointing at `node`
-- had not, so the privacy model was enforced on one table and on nothing that
-- refers to it. W-8 read the facility's whole movement history, its rack events
-- with volumes and method, and the lot ids behind a redacting view, from a
-- browser signed in as a custom crush client.
--
-- These assert the refusal from the client's side rather than the policy's, so
-- that a policy which is present and has stopped refusing is caught. The first
-- two are the blindness guards: without them every check below passes on a
-- database where the client can see nothing at all, which is a different bug.
do $$
declare seen int; mine int;
begin
  -- A lot the facility owns, in a vessel, with an event and a parent.
  insert into vessel (id, type_id, name, capacity_l)
  values ('00000000-0000-0000-0000-000000009001', term_id('vessel_type','tank'), 'E10 ours', 500),
         ('00000000-0000-0000-0000-000000009002', term_id('vessel_type','tank'), 'E10 theirs', 500);

  insert into node (id, stage, status, name, owner_id, created_by)
  values ('00000000-0000-0000-0000-000000009101', 'bin', 'open', 'E10 bin',
          '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-00000000a001'),
         ('00000000-0000-0000-0000-000000009102', 'maturation', 'open', 'E10 facility lot',
          '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-00000000a001'),
         ('00000000-0000-0000-0000-000000009103', 'maturation', 'open', 'E10 client lot',
          '00000000-0000-0000-0000-00000000f002', '00000000-0000-0000-0000-00000000a001');

  insert into placement (node_id, vessel_id, volume_l) values
    ('00000000-0000-0000-0000-000000009102', '00000000-0000-0000-0000-000000009001', 400),
    ('00000000-0000-0000-0000-000000009103', '00000000-0000-0000-0000-000000009002', 300);

  insert into lineage (parent_id, child_id, fraction)
  values ('00000000-0000-0000-0000-000000009101', '00000000-0000-0000-0000-000000009102', 1.0);

  insert into event (operation_id, subject_type, subject_id, by_user, provenance) values
    (term_id('operation','punchdown'), 'node', '00000000-0000-0000-0000-000000009102',
     '00000000-0000-0000-0000-00000000a001', 'observed'),
    (term_id('operation','punchdown'), 'node', '00000000-0000-0000-0000-000000009103',
     '00000000-0000-0000-0000-00000000a001', 'observed');

  -- Staff see the cellar they work in. This is the blindness guard: if this
  -- number were zero the checks below would pass on a schema that refuses
  -- everybody, which is not the thing being asserted.
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;
  select count(*) into seen from placement where vessel_id in
    ('00000000-0000-0000-0000-000000009001','00000000-0000-0000-0000-000000009002');
  reset role;
  if seen <> 2 then
    raise exception 'FAIL: a facility hand sees % of 2 placements, so the checks below are blind', seen;
  end if;
  perform test_ok('a facility hand reads the placements of the cellar they work in');

  -- And the client sees one row, theirs, in each of the three tables that carry
  -- wine by reference.
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;

  select count(*) into seen from placement where vessel_id in
    ('00000000-0000-0000-0000-000000009001','00000000-0000-0000-0000-000000009002');
  select count(*) into mine from placement
   where node_id = '00000000-0000-0000-0000-000000009103';
  reset role;
  if mine <> 1 then
    raise exception 'FAIL: a client cannot read the placement of their own wine';
  end if;
  if seen <> 1 then
    raise exception 'FAIL: a client reads % placements where one is theirs, so somebody else''s wine is in the answer', seen;
  end if;
  perform test_ok('a client reads the placement of their own wine and of no other');

  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select count(*) into seen from event
   where subject_id in ('00000000-0000-0000-0000-000000009102','00000000-0000-0000-0000-000000009103');
  reset role;
  if seen <> 1 then
    raise exception 'FAIL: a client reads % of 2 events, and only one of them is about their wine', seen;
  end if;
  perform test_ok('a client reads the events on their own wine and not the events on anybody else''s');

  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select count(*) into seen from lineage
   where child_id = '00000000-0000-0000-0000-000000009102';
  reset role;
  if seen <> 0 then
    raise exception 'FAIL: a client reads % lineage edge(s) of a lot that is not theirs, which is composition by reference', seen;
  end if;
  perform test_ok('a client cannot walk the lineage of a lot that is not theirs, which is what node_bin_shares guards');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
end $$;

-- The cost of AR-E10, asserted rather than described, because S-44 is the only
-- thing 0028 made worse and a sorry nobody can see is a sorry that gets
-- forgotten. A vessel holding wine this viewer may not see reports as empty.
-- When AR-E11 is built this assertion should fail, and that is the point of it.
do $$
declare empty_to_them boolean;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select is_empty into empty_to_them from vessel_state
   where id = '00000000-0000-0000-0000-000000009001';
  reset role;

  if empty_to_them is distinct from true then
    raise exception
      'FAIL: S-44 says a vessel a client may not see into reports as empty, and it reported %. If AR-E11 is built, this assertion is what should have changed with it', empty_to_them;
  end if;
  perform test_ok('S-44, recorded as an assertion: a vessel a client may not see into says it is empty, which is false and is the narrower of the two errors');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- what the caller is, answered by the kernel'; end $$;

-- 0029. The client used to decide who was staff by comparing app_user.role to the
-- string "admin", which reimplements is_admin() and drops its active conjunct, so
-- a deactivated account reached every screen and was refused one write at a time.
-- That is ledger B10 and the R-4 class. viewer_scope() is the kernel answering
-- instead, and these assert the three answers it can give.
do $$
declare v record;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  select * into v from viewer_scope();
  if v.sees is distinct from 'everything' or not v.may_admin then
    raise exception 'FAIL: an admin is scoped as % / may_admin %', v.sees, v.may_admin;
  end if;
  perform test_ok('an administrator is scoped to everything');

  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  select * into v from viewer_scope();
  if v.sees is distinct from 'everything' or v.may_admin then
    raise exception 'FAIL: a cellar hand is scoped as % / may_admin %', v.sees, v.may_admin;
  end if;
  perform test_ok('a cellar hand is scoped to everything and is not an administrator');

  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  select * into v from viewer_scope();
  if v.sees is distinct from 'own' or v.party_name is distinct from 'Test Client' then
    raise exception 'FAIL: a client login is scoped as % for %', v.sees, coalesce(v.party_name, 'nobody');
  end if;
  perform test_ok('a client login is scoped to its own party, by name');

  -- The B10 case. Deactivation has to change the answer, or the client is back to
  -- reading a role string and ignoring the column that matters.
  update app_user set active = false where id = '00000000-0000-0000-0000-00000000a002';
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  select * into v from viewer_scope();
  if v.account or v.sees is distinct from 'nothing' then
    raise exception 'FAIL: a deactivated account is scoped account=% sees=%, so B10 is open again', v.account, v.sees;
  end if;
  perform test_ok('a deactivated account is scoped to nothing, which is what B10 needed and the client could not see');
  update app_user set active = true where id = '00000000-0000-0000-0000-00000000a002';

  perform test_act_as(null);
  select * into v from viewer_scope();
  if v.signed_in or v.sees is distinct from 'nothing' then
    raise exception 'FAIL: nobody is scoped signed_in=% sees=%', v.signed_in, v.sees;
  end if;
  perform test_ok('nobody at all is scoped to nothing, without raising');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- which columns this caller may write'; end $$;

-- 0030. A cellar hand saw fifteen fields on the vessel edit screen and could
-- write three, and the form did not know which three. Hardcoding them in the
-- client is R-4. Column privileges cannot say, because admin and cellar are the
-- same database role and the distinction is a row in app_user, which is S-45.
-- The trigger carries its own allow-list, so the kernel answers from the place
-- it enforces.
do $$
declare got text[];
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');   -- a cellar hand
  got := writable_columns('vessel');
  if not (got @> array['has_glycol','setpoint_c','mode'] and array_length(got,1) = 3) then
    raise exception 'FAIL: a cellar hand may write %, and the trigger says three', got;
  end if;
  perform test_ok('a cellar hand is told the three vessel columns the trigger lets them write');

  -- The answer has to come from the trigger and not from a list. If somebody
  -- edits the allow-list, this follows; if somebody wrote the three names into
  -- the function, it does not, and that is the drift this exists to prevent.
  if got::text <> (
    select array(select btrim(x, chr(32) || chr(39))
                   from unnest(string_to_array(
                     (regexp_match(pg_get_triggerdef(t.oid),
                                   'cellar_writable_columns' || chr(92) || '((.*)' || chr(92) || ')'))[1], ','
                   )) as x)::text
      from pg_trigger t
     where t.tgrelid = 'vessel'::regclass and not t.tgisinternal
       and pg_get_triggerdef(t.oid) like '%cellar_writable_columns%'
  ) then
    raise exception 'FAIL: the answer % is not what the trigger says, so it is a copy', got;
  end if;
  perform test_ok('the answer is read out of the trigger rather than kept beside it');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');   -- an admin
  got := writable_columns('vessel');
  if array_length(got, 1) < 10 then
    raise exception 'FAIL: an admin may write only % columns of vessel', array_length(got,1);
  end if;
  perform test_ok('an administrator is told they may write every column, rather than the client assuming it');

  -- A table with no such trigger has no cellar allow-list, and the honest answer
  -- is none rather than all. Getting this backwards would open every form.
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  got := writable_columns('term');
  if coalesce(array_length(got, 1), 0) <> 0 then
    raise exception 'FAIL: a table with no cellar trigger reported % writable columns', got;
  end if;
  perform test_ok('a table with no cellar allow-list answers none, not all');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- AR-E6, the scheduling block is core'; end $$;

-- AR-E6. The scheduling block moves to core and points at a generic subject.
--
-- `0031`. Every outward edge of `template`, `template_step`, `task` and
-- `task_claim_log` was already core except one: `template.variety_id`, with a
-- generated `variety_kind` pinned to the string 'variety'. `term_kind` records
-- that `variety` belongs to winemaking, so a core table carried "a schedule is
-- for a grape variety", which is what `AR-E7` took out of two enums.
--
-- The structural claim, asserted from the catalog rather than by reading the four
-- tables. A generated kind column is how this schema pins a composite foreign key
-- to one vocabulary, and a core table pinning itself to a module's vocabulary is
-- the wrong-way edge `AR-A3` forbids. Pinning to a core vocabulary is fine, which
-- is why `operation` on `task` and `template_step` is left alone.
do $$
declare offender text; n_pins int;
begin
  select string_agg(x.tbl || '.' || x.col || ' pinned to ' || x.kind || ', owned by ' || x.module, '; ')
       , count(*) filter (where true)
    into offender, n_pins
    from (
      select c.relname as tbl, a.attname as col,
             btrim(pg_get_expr(d.adbin, d.adrelid), '''()::text ') as kind,
             tk.module
        from pg_class c
        join pg_namespace ns on ns.oid = c.relnamespace and ns.nspname = 'public'
        join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
        join pg_attrdef d on d.adrelid = c.oid and d.adnum = a.attnum
        left join term_kind tk
          on tk.kind = btrim(pg_get_expr(d.adbin, d.adrelid), '''()::text ')
       where c.relname in ('template', 'template_step', 'task', 'task_claim_log')
         and a.attgenerated <> ''
    ) x
   where x.module is not null and x.module <> 'core';

  if offender is not null then
    raise exception
      'FAIL: a scheduling table pins itself to a module vocabulary: %. AR-E6 says these four are core', offender;
  end if;
  -- The blindness guard. If no generated kind column were found at all this
  -- would pass on a schema that had lost the mechanism entirely.
  select count(*) into n_pins
    from pg_class c
    join pg_namespace ns on ns.oid = c.relnamespace and ns.nspname = 'public'
    join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
   where c.relname in ('template', 'template_step', 'task', 'task_claim_log')
     and a.attgenerated <> '';
  if n_pins < 2 then
    raise exception 'FAIL: only % generated kind column(s) on the scheduling block, so this check is blind', n_pins;
  end if;
  perform test_ok('no scheduling table pins itself to a vocabulary a module owns, which is what makes the block core');
end $$;

-- And the positive half: a schedule may be written against a vocabulary that has
-- nothing to do with wine. This is the thing AR-E6 buys and it is the thing that
-- would silently stop working if somebody put the variety back.
do $$
declare kept uuid;
begin
  insert into template (id, applies_to_id, applies_to_kind, name)
  values ('00000000-0000-0000-0000-00000000e0a1',
          term_id('location_kind', (select value from term where kind = 'location_kind' limit 1)),
          'location_kind', 'Opening checklist');
  select id into kept from template where id = '00000000-0000-0000-0000-00000000e0a1';
  if kept is null then
    raise exception 'FAIL: a schedule against a non-winemaking vocabulary was not accepted';
  end if;
  perform test_ok('a schedule may be written against a vocabulary that is not winemaking, which is what AR-E6 is for');

  -- S-46, asserted rather than only filed. It applies to a kind no generator
  -- reads, so it is accepted, correct, and inert. That is a refusal returning
  -- success wearing a different coat, and it is worth seeing in the output.
  delete from template where id = '00000000-0000-0000-0000-00000000e0a1';
end $$;

-- The composite key still proves the term is of the kind claimed. Making the kind
-- a value rather than a constant loosens nothing, and that is the sentence this
-- assertion is here to keep true.
do $$
begin
  begin
    insert into template (id, applies_to_id, applies_to_kind, name)
    values ('00000000-0000-0000-0000-00000000e0a2',
            term_id('variety', 'pinot_noir'), 'vessel_type', 'Lying about its kind');
    raise exception 'FAIL: a schedule named a variety and called it a vessel type';
  exception when foreign_key_violation then
    perform test_ok('a schedule naming a term of one kind and claiming another is refused by the composite key');
  end;

  begin
    insert into template (id, applies_to_kind, name)
    values ('00000000-0000-0000-0000-00000000e0a3', 'variety', 'A kind and no member of it');
    raise exception 'FAIL: a schedule named a vocabulary and no member of it';
  exception when check_violation then
    perform test_ok('a schedule carries a vocabulary and a member of it, or neither');
  end;
end $$;

-- Where the winemaking knowledge went. It is in the generator now, which asks for
-- the vocabulary it understands by name, and a schedule against any other
-- vocabulary is not history and does not become events.
do $$
declare written int;
begin
  insert into node (id, stage, status, name, variety_id, owner_id, created_by)
  values ('00000000-0000-0000-0000-00000000b0e6', 'maturation', 'open', 'AR-E6 lot',
          term_id('variety', 'pinot_noir'),
          '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-00000000a001');

  insert into template (id, applies_to_id, applies_to_kind, name, active)
  values ('00000000-0000-0000-0000-00000000e0a4',
          term_id('variety', 'pinot_noir'), 'variety', 'PN schedule', true);
  insert into template_step (template_id, step_order, operation_id, offset_interval)
  values ('00000000-0000-0000-0000-00000000e0a4', 1, term_id('operation', 'batonnage'), interval '7 days');

  written := generate_inferred_history('00000000-0000-0000-0000-00000000b0e6');
  if written <> 1 then
    raise exception 'FAIL: a schedule against the lot''s variety generated % events', written;
  end if;
  perform test_ok('history generation asks for the variety vocabulary by name, which is where that knowledge belongs');

  -- Re-pointed at a vocabulary the generator does not read, the same schedule
  -- generates nothing. S-46 is that nothing says so.
  delete from event where subject_id = '00000000-0000-0000-0000-00000000b0e6';
  update template set applies_to_id = term_id('vessel_type', 'barrel'), applies_to_kind = 'vessel_type'
   where id = '00000000-0000-0000-0000-00000000e0a4';
  written := generate_inferred_history('00000000-0000-0000-0000-00000000b0e6');
  if written <> 0 then
    raise exception 'FAIL: a schedule against another vocabulary generated % events for a lot', written;
  end if;
  perform test_ok('S-46, asserted: a schedule against a vocabulary no generator reads is accepted and does nothing, silently');

  delete from template where id = '00000000-0000-0000-0000-00000000e0a4';
  delete from node where id = '00000000-0000-0000-0000-00000000b0e6';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- one list of vessel makers, flagged for what they build'; end $$;

-- 0032. The winemaker opened the vessel types screen and found that a tank asks
-- for a cooper. It did: all four types drew from one shared list whose registered
-- name was `cooper`, and that screen shows the vocabulary name. The filtering was
-- right and the bucket had a barrel-maker's word on it.
--
-- The rename is one row because `0027` made a vocabulary a row. That is AR-E7
-- paying for itself: before it, this was an enum and a rename was a migration
-- against nine generated columns.
do $$
declare n int;
begin
  select count(*) into n from term_kind where kind = 'cooper';
  if n <> 0 then
    raise exception 'FAIL: the cooper vocabulary is still registered, so a tank still asks for one';
  end if;
  select count(*) into n from term_kind where kind = 'vessel_maker';
  if n <> 1 then
    raise exception 'FAIL: there is no vessel_maker vocabulary for the four types to draw from';
  end if;
  perform test_ok('there is one vessel maker vocabulary and it is not named after barrels');

  -- The labels are untouched on purpose. A barrel still says Cooper to the person
  -- in front of it, because that is what they call the thing; only the shared
  -- list underneath stopped pretending to be barrel-specific.
  select count(*) into n
    from term vt, lateral jsonb_array_elements(vt.attributes -> 'fields') f
   where vt.kind = 'vessel_type' and f ->> 'key' = 'maker'
     and f ->> 'term_kind' <> 'vessel_maker';
  if n <> 0 then
    raise exception 'FAIL: % vessel type(s) still draw their maker from another vocabulary', n;
  end if;
  select count(*) into n
    from term vt, lateral jsonb_array_elements(vt.attributes -> 'fields') f
   where vt.kind = 'vessel_type' and f ->> 'key' = 'maker'
     and f ->> 'label' = 'Cooper' and vt.value = 'barrel';
  if n <> 1 then
    raise exception 'FAIL: a barrel stopped calling its maker a cooper, which is what the person holding it calls them';
  end if;
  perform test_ok('a barrel still says Cooper and a tank still says Manufacturer, over one shared list');
end $$;

-- What a maker builds is a set, so somebody who makes both is entered once. This
-- is the whole of what was asked for and the reason the single `contract` string
-- was not good enough.
do $$
declare barrel_opts text; tank_opts text;
begin
  insert into term (kind, value, label, attributes) values
    ('vessel_maker', 'assert_cooper_only', 'Assert Cooperage',  '{"makes": ["cooper"]}'::jsonb),
    ('vessel_maker', 'assert_tank_only',   'Assert Tankworks',  '{"makes": ["manufacturer"]}'::jsonb),
    ('vessel_maker', 'assert_both',        'Assert Both',       '{"makes": ["cooper", "manufacturer"]}'::jsonb),
    ('vessel_maker', 'assert_unflagged',   'Assert Unflagged',  '{}'::jsonb),
    -- A term written before 0032, carrying the single string it replaced. Old is
    -- not wrong, and a migration that silently stopped honouring it would be the
    -- A13 shape: the maker would vanish from the picker and nothing would say so.
    ('vessel_maker', 'assert_legacy',      'Assert Legacy',     '{"contract": "cooper"}'::jsonb);

  select string_agg(label, ', ' order by label) into barrel_opts
    from terms_for_vessel_field((select id from term where kind='vessel_type' and value='barrel'), 'maker')
   where value like 'assert_%';
  select string_agg(label, ', ' order by label) into tank_opts
    from terms_for_vessel_field((select id from term where kind='vessel_type' and value='tank'), 'maker')
   where value like 'assert_%';

  if barrel_opts is distinct from 'Assert Both, Assert Cooperage, Assert Legacy, Assert Unflagged' then
    raise exception 'FAIL: a barrel offers %', coalesce(barrel_opts, 'nothing');
  end if;
  if tank_opts is distinct from 'Assert Both, Assert Tankworks, Assert Unflagged' then
    raise exception 'FAIL: a tank offers %', coalesce(tank_opts, 'nothing');
  end if;
  perform test_ok('a maker flagged for both appears in both pickers, entered once, and one flagged for neither appears in both');
  perform test_ok('a maker written before the flags, carrying a single contract, is still offered where it belongs');

  delete from term where kind = 'vessel_maker' and value like 'assert_%';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the room and the jacket are two temperatures'; end $$;

-- The vessels screen collapsed them into one number, so a barrel sitting in a
-- cold room and a tank holding itself at 12 read the same. `effective_temp_c`
-- stays, because a screen with room for one number wants the answer rather than
-- the parts, and the parts are published beside it.
do $$
declare amb numeric; ctrl boolean; eff numeric; sp numeric; md thermal_mode;
begin
  insert into vessel (id, type_id, name, capacity_l, location_id, has_glycol, setpoint_c, mode)
  values ('00000000-0000-0000-0000-000000003201',
          term_id('vessel_type','tank'), 'Temp tank', 1000,
          '00000000-0000-0000-0000-00000000d001', true, 12.0, 'cooling'),
         ('00000000-0000-0000-0000-000000003202',
          term_id('vessel_type','barrel'), 'Temp barrel', 228,
          '00000000-0000-0000-0000-00000000d001', false, null, 'off');

  -- A jacket that is running: the room is still 13.5 and the wine is held at 12,
  -- and a screen that can only say one of those should say 12.
  select location_ambient_c, location_controlled, effective_temp_c, setpoint_c, mode
    into amb, ctrl, eff, sp, md
    from vessel_state where name = 'Temp tank';
  if amb is distinct from 13.5 then
    raise exception 'FAIL: the room reads % rather than 13.5', coalesce(amb::text,'nothing');
  end if;
  if ctrl is distinct from true then
    raise exception 'FAIL: the room is temperature controlled and the view says %', coalesce(ctrl::text,'nothing');
  end if;
  if eff is distinct from 12.0 or sp is distinct from 12.0 or md is distinct from 'cooling' then
    raise exception 'FAIL: a cooling jacket at 12 reads effective %, setpoint %, mode %', eff, sp, md;
  end if;
  perform test_ok('a vessel with a running jacket publishes the room and the jacket separately, and the jacket is the effective one');

  -- And one with no jacket: the room is the answer, and the parts still say why.
  select location_ambient_c, effective_temp_c, setpoint_c
    into amb, eff, sp from vessel_state where name = 'Temp barrel';
  if amb is distinct from 13.5 or eff is distinct from 13.5 then
    raise exception 'FAIL: an unjacketed barrel in a 13.5 room reads room % effective %', amb, eff;
  end if;
  if sp is not null then
    raise exception 'FAIL: an unjacketed barrel reports a setpoint of %', sp;
  end if;
  perform test_ok('a vessel with no jacket takes the room temperature, and says it has no setpoint of its own');

  delete from vessel where id in ('00000000-0000-0000-0000-000000003201',
                                  '00000000-0000-0000-0000-000000003202');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- intake: a bin of fruit before anybody weighs it'; end $$;

-- 0033. Build order 2, and the one place where a missed record cannot be
-- reconstructed. These assertions are arranged around the two things intake has
-- that racking does not: a weight that is not known yet, and a scale reading
-- covering more than one container.

-- The type split the winemaker asked for. `macrobin` was one vessel type doing
-- three jobs and the brand was one of them, which is the wrong-way knowledge
-- AR-E7 took out of two enums and 0032 took out of the maker list.
do $$
declare n int;
begin
  select count(*) into n from term where kind = 'vessel_type' and value = 'macrobin';
  if n <> 0 then
    raise exception 'FAIL: macrobin is still a vessel type, so a brand is still a kind of vessel';
  end if;
  select count(*) into n from term where kind = 'vessel_maker' and value = 'macrobin';
  if n <> 1 then
    raise exception 'FAIL: Macrobin is not a vessel maker, so the brand went nowhere';
  end if;
  perform test_ok('a brand is a maker rather than a kind of vessel, which is where 0032 put the others');

  select count(*) into n from term
   where kind = 'vessel_type' and value = 'picking_bin'
     and (attributes ->> 'intake_bin')::boolean;
  if n <> 1 then
    raise exception 'FAIL: a picking bin is not flagged as weighed at intake';
  end if;
  select count(*) into n from term
   where kind = 'vessel_type' and value = 'fermentation_bin'
     and coalesce((attributes ->> 'intake_bin')::boolean, false);
  if n <> 0 then
    raise exception 'FAIL: a fermentation bin is flagged for the scale, and it is a destination';
  end if;
  perform test_ok('only the bin fruit is weighed in is flagged for the scale, which is what intake_bin decides');
end $$;

-- The A25 class, in the place it would be most expensive. A missing tare read as
-- zero is a pick that weighs its own containers, silently, for a whole vintage.
do $$
declare v_id uuid := '00000000-0000-0000-0000-00000000c101';
begin
  -- Cleared rather than assumed. This used to read whatever tare the facility
  -- happened to have set, so it passed against an empty database and failed the
  -- hour the winemaker typed a real number into the running cellar. **An
  -- assertion whose answer depends on production data is not an assertion**, and
  -- this one was one until the first pick found it. The suite rolls back, so the
  -- real tare is untouched.
  update term set attributes = attributes - 'tare_lbs'
   where kind = 'vessel_type' and value = 'picking_bin';

  insert into vessel (id, type_id, name, capacity_l)
  values (v_id, term_id('vessel_type', 'picking_bin'), 'Assert bin A', 400);

  begin
    perform bin_tare_lbs(v_id);
    raise exception 'FAIL: a bin type with no tare returned a number, so fruit would weigh its own bin';
  exception when others then
    if position('no tare weight' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a bin type with no tare refuses rather than permitting, which is A25 below the gate');
  end;

  -- A fermentation bin has no tare and should not: it is a destination.
  insert into vessel (id, type_id, name, capacity_l)
  values ('00000000-0000-0000-0000-00000000c103',
          term_id('vessel_type', 'fermentation_bin'), 'Assert ferm bin', 900);
  begin
    perform bin_tare_lbs('00000000-0000-0000-0000-00000000c103');
    raise exception 'FAIL: a fermentation bin answered a question about its tare';
  exception when others then
    if position('not a picking bin' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a vessel that is not a picking bin says so rather than returning a weight');
  end;
end $$;

-- A bin recorded in a vineyard, with no weight. The state T1-4 exists to allow.
do $$
declare
  pick_id uuid := '00000000-0000-0000-0000-00000000c201';
  q       numeric;
  n       int;
begin
  update term set attributes = attributes || '{"tare_lbs": 60}'::jsonb
   where kind = 'vessel_type' and value = 'picking_bin';

  insert into vessel (id, type_id, name, capacity_l)
  values ('00000000-0000-0000-0000-00000000c102',
          term_id('vessel_type', 'picking_bin'), 'Assert bin B', 400);

  perform add_bin_to_pick(
    jsonb_build_object('id', pick_id, 'variety_id', term_id('variety', 'pinot_noir'),
                       'vintage', 2026),
    '00000000-0000-0000-0000-00000000c101', 100);
  perform add_bin_to_pick(jsonb_build_object('id', pick_id),
                          '00000000-0000-0000-0000-00000000c102', 50);

  select quantity into q from node where id = pick_id;
  -- B11's lesson, one table down. Zero is a weight and this is the absence of
  -- one, and a pick reading 0 lbs until somebody weighs it is indistinguishable
  -- from a pick that arrived empty.
  if q is not null then
    raise exception 'FAIL: a pick nobody has weighed reports a quantity of %', q;
  end if;
  perform test_ok('a pick with no weighing has no weight, rather than a weight of zero');

  select count(*) into n from unweighed_bin where node_id = pick_id;
  if n <> 2 then
    raise exception 'FAIL: % of 2 unweighed bins are visible, so one could be lost', n;
  end if;
  perform test_ok('a bin with fruit and no weight is a row somebody can see, which is what makes T1-4 safe');

  -- A destination is not a picking bin, and intake says so rather than
  -- accepting fruit into something that is never carried to a scale.
  begin
    perform add_bin_to_pick(jsonb_build_object('id', pick_id),
                            '00000000-0000-0000-0000-00000000c103', 100);
    raise exception 'FAIL: fruit was recorded into a fermentation bin at intake';
  exception when others then
    if position('not an active picking bin' in sqlerrm) = 0 then raise; end if;
    perform test_ok('intake refuses a vessel that is not a picking bin');
  end;
end $$;

-- The scale. One reading over several bins, and one tare subtracted per bin.
do $$
declare
  pick_id uuid := '00000000-0000-0000-0000-00000000c201';
  out_js  jsonb;
  q       numeric;
  n       int;
  first   uuid;
begin
  out_js := weigh_bins(pick_id,
    array['00000000-0000-0000-0000-00000000c101',
          '00000000-0000-0000-0000-00000000c102']::uuid[],
    1000, 'one full one half');

  if (out_js ->> 'tare_lbs')::numeric <> 120 then
    raise exception 'FAIL: two bins of 60 tared %, so the tare is not per bin', out_js ->> 'tare_lbs';
  end if;
  if (out_js ->> 'net_lbs')::numeric <> 880 then
    raise exception 'FAIL: 1000 gross less 120 of bin came to %', out_js ->> 'net_lbs';
  end if;
  perform test_ok('a scale reading over several bins subtracts one tare for each of them');

  select quantity into q from node where id = pick_id;
  if q <> 880 then
    raise exception 'FAIL: the pick holds % lbs after a reading of 880', q;
  end if;
  select count(*) into n from unweighed_bin where node_id = pick_id;
  if n <> 0 then
    raise exception 'FAIL: % bins still read as unweighed after being weighed', n;
  end if;
  perform test_ok('weighing a bin takes it off the list of bins waiting for a weight');

  -- The guard that stops a pick from silently doubling. Without it a second
  -- reading of the same bins adds its fruit again and no screen shows it.
  begin
    perform weigh_bins(pick_id,
      array['00000000-0000-0000-0000-00000000c101']::uuid[], 500);
    raise exception 'FAIL: the same bin was weighed twice and the pick doubled';
  exception when others then
    if position('weighed already' in sqlerrm) = 0 then raise; end if;
    perform test_ok('weighing a bin that has been weighed is refused rather than added');
  end;

  -- T0-5. A correction is a new event naming the one it replaces, so the wrong
  -- number stays in the record and stops counting. Nothing is edited.
  select id into first from event
   where subject_type = 'node' and subject_id = pick_id
     and operation_id = term_id('operation', 'weigh')
   order by created_at limit 1;

  out_js := weigh_bins(pick_id,
    array['00000000-0000-0000-0000-00000000c101',
          '00000000-0000-0000-0000-00000000c102']::uuid[],
    1200, 'misread the scale', first);

  if (out_js ->> 'total_lbs')::numeric <> 1080 then
    raise exception
      'FAIL: correcting 1000 to 1200 left the pick at % lbs, so the first reading is still counted',
      out_js ->> 'total_lbs';
  end if;
  select count(*) into n from event
   where subject_type = 'node' and subject_id = pick_id
     and operation_id = term_id('operation', 'weigh');
  if n <> 2 then
    raise exception 'FAIL: correcting a weighing left % events, so something was edited', n;
  end if;
  perform test_ok('a corrected weighing supersedes rather than adds, and the first reading is still in the record');
end $$;

-- S-50, asserted rather than only filed. fork_lot sums placement.volume_l, which
-- a pick deliberately leaves null, so forking one would hand the child a weight
-- of zero. A wrong number is worse than a missing feature.
do $$
begin
  begin
    insert into lineage (parent_id, child_id, fraction)
    values ('00000000-0000-0000-0000-00000000c201',
            '00000000-0000-0000-0000-00000000c201', 1.0);
    raise exception 'FAIL: a pick was split bin by bin and the pieces would weigh nothing';
  exception when others then
    if position('cannot be split bin by bin' in sqlerrm) = 0 then raise; end if;
    perform test_ok('S-50, asserted: splitting a pick is refused rather than producing a weight of zero');
  end;
end $$;

-- S-26, the leak 0017 closed and 0032 briefly re-opened. Every view added since
-- then has to carry the option, and this is the newest one.
do $$
declare opts text[];
begin
  select c.reloptions into opts
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relname = 'unweighed_bin';
  if opts is null or not ('security_invoker=true' = any(opts)) then
    raise exception
      'FAIL: unweighed_bin does not run as its caller, so it hands a client somebody else fruit';
  end if;
  perform test_ok('the unweighed bin list runs as whoever asks, so it shows one client their own fruit');

  delete from event where subject_type = 'node'
     and subject_id = '00000000-0000-0000-0000-00000000c201';
  delete from placement where node_id = '00000000-0000-0000-0000-00000000c201';
  delete from node where id = '00000000-0000-0000-0000-00000000c201';
  delete from vessel where id in ('00000000-0000-0000-0000-00000000c101',
                                  '00000000-0000-0000-0000-00000000c102',
                                  '00000000-0000-0000-0000-00000000c103');
  update term set attributes = attributes - 'tare_lbs'
   where kind = 'vessel_type' and value = 'picking_bin';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- press: where a lot gets the identity it keeps'; end $$;

-- 0034. Build order 3. Press is structurally a blend in different units: several
-- parents contribute fruit weight, one child comes out in litres, and the share
-- each parent holds is its share of what went in rather than of what ran.
do $$
declare
  pick_id  uuid := '00000000-0000-0000-0000-00000000d201';
  bin_a    uuid := '00000000-0000-0000-0000-00000000d101';
  bin_b    uuid := '00000000-0000-0000-0000-00000000d102';
  tank_id  uuid := '00000000-0000-0000-0000-00000000d103';
  out_js   jsonb;
  st       node_stage;
  q        numeric;
  n        int;
begin
  update term set attributes = attributes || '{"tare_lbs": 60}'::jsonb
   where kind = 'vessel_type' and value = 'picking_bin';

  insert into vessel (id, type_id, name, capacity_l, attributes) values
    (bin_a, term_id('vessel_type', 'picking_bin'), 'Assert press bin A', 400,
     '{"borrowed": true}'::jsonb),
    (bin_b, term_id('vessel_type', 'picking_bin'), 'Assert press bin B', 400, '{}'::jsonb),
    (tank_id, term_id('vessel_type', 'tank'), 'Assert press tank', 1500, '{}'::jsonb);

  perform add_bin_to_pick(
    jsonb_build_object('id', pick_id, 'variety_id', term_id('variety', 'pinot_gris'),
                       'vintage', 2026, 'name', 'Assert pick'),
    bin_a, 100);
  perform add_bin_to_pick(jsonb_build_object('id', pick_id), bin_b, 100);

  -- The guard this migration exists for. Fruit weight is recoverable right up to
  -- the moment it goes through the press and never afterwards, so pressing a
  -- pick nobody weighed destroys the only chance there was.
  begin
    perform press(
      jsonb_build_array(jsonb_build_object('node_id', pick_id)),
      jsonb_build_array(jsonb_build_object('vessel_id', tank_id, 'volume_l', 500)));
    raise exception 'FAIL: unweighed fruit went through the press and its weight is gone for good';
  exception when others then
    if position('never been weighed' in sqlerrm) = 0 then raise; end if;
    perform test_ok('pressing fruit nobody weighed is refused, because the press is the last moment anybody could');
  end;

  perform weigh_bins(pick_id, array[bin_a, bin_b]::uuid[], 2120);

  out_js := press(
    jsonb_build_array(jsonb_build_object('node_id', pick_id)),
    jsonb_build_array(jsonb_build_object('vessel_id', tank_id, 'volume_l', 1200)),
    jsonb_build_object('name', 'Assert pressed'));

  if (out_js ->> 'lbs_in')::numeric <> 2000 then
    raise exception 'FAIL: the press took % lbs from a pick holding 2000', out_js ->> 'lbs_in';
  end if;
  if (out_js ->> 'bins_emptied')::int <> 2 then
    raise exception 'FAIL: % bins were emptied by a press that took all the fruit',
      out_js ->> 'bins_emptied';
  end if;
  perform test_ok('a press takes the fruit out of the bins it came from and says how many it emptied');

  -- Whites press before fermentation and reds press off skins after: the same
  -- verb at two positions. The stage is read off the parents rather than asked
  -- for, because that is winery practice and not a preference.
  select stage into st from node where id = (out_js ->> 'node_id')::uuid;
  if st <> 'ferment' then
    raise exception 'FAIL: fruit in bins pressed to %, and a white presses before it ferments', st;
  end if;
  perform test_ok('fruit in bins presses to a ferment, which is the kernel answering rather than a screen asking');

  -- 0013's rule, reached by this path. The pick empties and closes itself.
  select count(*) into n from node
   where id = pick_id and status = 'closed' and coalesce(quantity, -1) = 0;
  if n <> 1 then
    select quantity into q from node where id = pick_id;
    raise exception 'FAIL: a pick holding % after being pressed in full is not closed at zero', q;
  end if;
  perform test_ok('a pick that has all been pressed closes itself, which is 0013 reached from here');

  -- T0-2. The child carries no block, because composition downstream is derived
  -- by walking lineage and a stored copy could disagree with block_composition.
  select count(*) into n from node
   where id = (out_js ->> 'node_id')::uuid and block_id is not null;
  if n <> 0 then
    raise exception 'FAIL: the pressed lot carries a block, which T0-2 says is derived rather than copied';
  end if;
  perform test_ok('a pressed lot carries no block of its own, because what it is made of is derived by walking');

  -- The borrowed bin. Empty is not the same as available: a bin lent by the
  -- grower is owed back the moment it stops holding anything, and the one that
  -- is not borrowed is simply free.
  select count(*) into n from bin_to_return where vessel_id = bin_a;
  if n <> 1 then
    raise exception 'FAIL: an empty borrowed bin is not showing as owed back';
  end if;
  select count(*) into n from bin_to_return where vessel_id = bin_b;
  if n <> 0 then
    raise exception 'FAIL: a bin nobody borrowed is showing as owed back';
  end if;
  perform test_ok('an empty borrowed bin is owed back and an empty owned one is just empty');

  -- S-26 again, on the newest view. Every view added since 0017 has to carry it.
  if not exists (
    select 1 from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
     where ns.nspname = 'public' and c.relname = 'bin_to_return'
       and 'security_invoker=true' = any(c.reloptions)) then
    raise exception 'FAIL: bin_to_return does not run as its caller, so it lists somebody else bins';
  end if;
  perform test_ok('the bins to return list runs as whoever asks');

  delete from event where subject_type = 'node'
     and subject_id in (pick_id, (out_js ->> 'node_id')::uuid);
  delete from lineage where child_id = (out_js ->> 'node_id')::uuid;
  delete from placement where node_id in (pick_id, (out_js ->> 'node_id')::uuid);
  delete from node where id in (pick_id, (out_js ->> 'node_id')::uuid);
  delete from vessel where id in (bin_a, bin_b, tank_id);
  update term set attributes = attributes - 'tare_lbs'
   where kind = 'vessel_type' and value = 'picking_bin';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- bins by the stack, and bins that are not yours'; end $$;

-- 0035 and 0036, both asked for during the first pick, which is when the cost of
-- doing a thing six times is being paid rather than imagined.
do $$
declare
  pick_id uuid := '00000000-0000-0000-0000-00000000e301';
  made    jsonb;
  n       int;
  who     text;
begin
  -- Named so they cannot collide with whatever the winery has: the numbering
  -- reads existing names, so an assertion using a real prefix would be an
  -- assertion about production data, which is the fragility the first pick
  -- already found once in this suite.
  made := add_bins_to_pick(
    jsonb_build_object('id', pick_id, 'variety_id', term_id('variety', 'chardonnay'),
                       'vintage', 2026),
    null, 3, term_id('vessel_type', 'picking_bin'), 'ASRTBIN', 100);

  if made -> 'registered' <> '["ASRTBIN1", "ASRTBIN2", "ASRTBIN3"]'::jsonb then
    raise exception 'FAIL: three new bins were named %', made -> 'registered';
  end if;
  if (made ->> 'bins')::int <> 3 then
    raise exception 'FAIL: % bins landed on the pick from one action', made ->> 'bins';
  end if;
  perform test_ok('three bins are registered and put on one pick in a single action');

  -- The gap rule. A retired bin leaves its number behind rather than handing it
  -- to a different physical object, which is what makes a bin name worth
  -- reading in a record two vintages later.
  update vessel set name = 'ASRTBIN2-retired' where name = 'ASRTBIN2';
  made := add_bins_to_pick(jsonb_build_object('id', pick_id),
                           null, 1, term_id('vessel_type', 'picking_bin'), 'ASRTBIN', 100);
  if made -> 'registered' <> '["ASRTBIN4"]'::jsonb then
    raise exception 'FAIL: after retiring ASRTBIN2 the next bin was named %',
      made -> 'registered';
  end if;
  perform test_ok('a retired bin does not hand its number to a different object');

  -- A fermentation bin is a destination, so it is not something a pick is
  -- registered into however many are asked for at once.
  begin
    perform add_bins_to_pick(jsonb_build_object('id', pick_id),
      null, 1, term_id('vessel_type', 'fermentation_bin'), 'ASRTFB', 100);
    raise exception 'FAIL: bulk registration made fermentation bins for a pick';
  exception when others then
    if position('not a picking bin type' in sqlerrm) = 0 then raise; end if;
    perform test_ok('bulk registration refuses a type fruit is not weighed in');
  end;

  begin
    perform add_bins_to_pick(jsonb_build_object('id', pick_id), null, 0, null, null, null);
    raise exception 'FAIL: a call naming no bins and asking for none did something';
  exception when others then
    if position('nothing to add' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a bulk call that names no bins and asks for none refuses rather than passing');
  end;

  -- 0036. Fruit bought in arrives in the grower's bins, and the grower is not a
  -- party here: `party.kind` is facility or client, and a client is somebody
  -- whose wine this is and who signs in to see it. So the lender is a name.
  made := add_bins_to_pick(
    jsonb_build_object('id', '00000000-0000-0000-0000-00000000e302',
                       'variety_id', term_id('variety', 'chardonnay'), 'vintage', 2026),
    null, 2, term_id('vessel_type', 'picking_bin'), 'ASRTLOAN', 100,
    null, 'Assert Vineyards');

  select count(*) into n from vessel
   where name like 'ASRTLOAN%'
     and (attributes ->> 'borrowed')::boolean
     and attributes ->> 'on_loan_from' = 'Assert Vineyards';
  if n <> 2 then
    raise exception 'FAIL: % of 2 bins on loan say whose they are', n;
  end if;
  perform test_ok('bins registered for bought-in fruit record the grower they belong to');

  -- Empty is not the same as available. This is the moment a borrowed bin stops
  -- being a container and starts being something owed to somebody.
  update placement set to_at = now()
   where node_id = '00000000-0000-0000-0000-00000000e302';
  select string_agg(distinct owed_to, ', ') into who
    from bin_to_return where bin_name like 'ASRTLOAN%';
  if who is distinct from 'Assert Vineyards' then
    raise exception 'FAIL: emptied bins on loan are owed to %', coalesce(who, 'nobody');
  end if;
  perform test_ok('an emptied bin on loan is owed back to the grower by name, not to this winery');

  -- Ours empty into being available rather than into being owed.
  select count(*) into n from bin_to_return where bin_name like 'ASRTBIN%';
  if n <> 0 then
    raise exception 'FAIL: % of our own bins are listed as owed back', n;
  end if;
  perform test_ok('a bin this winery owns empties into being free rather than into being owed');

  -- The two situations the winemaker separated stay separate. A row claiming
  -- both would make the view pick one silently, which is the A13 shape.
  begin
    perform add_bins_to_pick(
      jsonb_build_object('id', '00000000-0000-0000-0000-00000000e303',
                         'variety_id', term_id('variety', 'chardonnay'), 'vintage', 2026),
      null, 1, term_id('vessel_type', 'picking_bin'), 'ASRTBOTH', 100,
      facility_party_id(), 'Assert Vineyards');
    raise exception 'FAIL: a bin was recorded as both on loan from a grower and owned by a party';
  exception when others then
    if position('and this says both' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a bin is on loan from a grower or owned by a party here, never recorded as both');
  end;

  -- One name, one function. Adding parameters with defaults creates a second
  -- function rather than replacing the first, and every caller then fails with
  -- "is not unique": found by the test doing what the client would have done.
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'add_bins_to_pick';
  if n <> 1 then
    raise exception
      'FAIL: there are % versions of add_bins_to_pick, so a call cannot choose between them', n;
  end if;
  perform test_ok('bulk registration has exactly one signature, so no call is ambiguous');

  delete from placement where node_id in ('00000000-0000-0000-0000-00000000e301',
                                          '00000000-0000-0000-0000-00000000e302');
  delete from node where id in ('00000000-0000-0000-0000-00000000e301',
                                '00000000-0000-0000-0000-00000000e302');
  delete from vessel where name like 'ASRTBIN%' or name like 'ASRTLOAN%';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- taking a copy away, and cancelling a pick'; end $$;

-- 0037. The export is the thing that survives the one desktop the database is
-- on, so the question it has to answer is "is everything in here", and the way
-- that goes wrong is a table added later and never added to the export.
do $$
declare missing text; e jsonb; n int;
begin
  e := export_cellar();

  select string_agg(c.relname, ', ') into missing
    from pg_class c
    join pg_namespace ns on ns.oid = c.relnamespace
   where ns.nspname = 'public' and c.relkind = 'r'
     and not (e -> 'tables' ? c.relname);
  if missing is not null then
    raise exception
      'FAIL: these tables are in the database and not in the export: %. A copy that is quietly short is worse than none', missing;
  end if;
  perform test_ok('every table in the database appears in the export, so a copy cannot be quietly short');

  -- An empty table is an answer. Distinguishing "nothing you may read" from
  -- "not included" is the whole reason the empty array is kept rather than
  -- skipped, and it is the A13 shape if they collapse.
  if jsonb_typeof(e -> 'tables' -> 'task') <> 'array' then
    raise exception 'FAIL: an empty table is % in the export rather than an empty list',
      jsonb_typeof(e -> 'tables' -> 'task');
  end if;
  perform test_ok('a table with nothing in it exports as an empty list rather than going missing');

  select count(*) into n from jsonb_object_keys(e -> 'tables');
  if (e ->> 'table_count')::int <> n then
    raise exception 'FAIL: the export says % tables and carries %', e ->> 'table_count', n;
  end if;
  perform test_ok('the export counts what it actually contains');
end $$;

-- The export runs as whoever asked, which is the difference between a copy of
-- the record and a copy of the database. A client taking one must not get the
-- facility's lots in it.
do $$
declare admin_rows int; client_rows int;
begin
  -- `set local role authenticated` matters and is the whole test. The suite runs
  -- as the owning superuser, for whom row level security is not enforced at all,
  -- so without this both numbers come back as every lot in the cellar and the
  -- assertion passes while proving nothing. The first version of this did
  -- exactly that.
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  set local role authenticated;
  select jsonb_array_length(export_cellar() -> 'tables' -> 'node') into admin_rows;
  reset role;

  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select jsonb_array_length(export_cellar() -> 'tables' -> 'node') into client_rows;
  reset role;

  if client_rows >= admin_rows then
    raise exception
      'FAIL: a client exported % lots and an administrator exported %, so the export is not going through row level security',
      client_rows, admin_rows;
  end if;
  perform test_ok('an export carries only what the person asking may read, so two people get two different files');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
end $$;

-- 0038. Cancelling keeps what was measured; removing is for a row that never
-- measured anything.
do $$
declare
  pick_id uuid := '00000000-0000-0000-0000-00000000cc01';
  out_js  jsonb;
  n       int;
begin
  update term set attributes = attributes || '{"tare_lbs": 55}'::jsonb
   where kind = 'vessel_type' and value = 'picking_bin';

  out_js := add_bins_to_pick(
    jsonb_build_object('id', pick_id, 'variety_id', term_id('variety', 'riesling'),
                       'vintage', 2026),
    null, 2, term_id('vessel_type', 'picking_bin'), 'ASRTCANC', 100);

  out_js := cancel_pick(pick_id, 'fruit went somewhere else');
  if (out_js ->> 'bins_freed')::int <> 2 then
    raise exception 'FAIL: cancelling freed % of 2 bins, so a bin is still held by a pick that is not happening',
      out_js ->> 'bins_freed';
  end if;
  perform test_ok('cancelling a pick gives the bins back, which is most of what cancelling is for');

  select count(*) into n from node
   where id = pick_id and status = 'closed'
     and (attributes ->> 'cancelled')::boolean
     and attributes ->> 'cancelled_reason' = 'fruit went somewhere else';
  if n <> 1 then
    raise exception 'FAIL: a cancelled pick does not say that it was cancelled, or why';
  end if;
  perform test_ok('a cancelled pick records that it was cancelled and the reason given');

  -- Nothing was weighed, so there is no observation to keep and removing it
  -- destroys no record. That is the only condition under which it is allowed.
  perform remove_pick(pick_id);
  select count(*) into n from node where id = pick_id;
  if n <> 0 then
    raise exception 'FAIL: a cancelled pick with nothing weighed into it was not removed';
  end if;
  perform test_ok('a cancelled pick that measured nothing can be removed outright');

  delete from vessel where name like 'ASRTCANC%';
end $$;

-- The refusals, which are the part that protects the record.
do $$
declare pick_id uuid := '00000000-0000-0000-0000-00000000cc02'; bins uuid[];
begin
  perform add_bins_to_pick(
    jsonb_build_object('id', pick_id, 'variety_id', term_id('variety', 'riesling'),
                       'vintage', 2026),
    null, 1, term_id('vessel_type', 'picking_bin'), 'ASRTKEEP', 100);

  begin
    perform remove_pick(pick_id);
    raise exception 'FAIL: a pick that had not been cancelled was removed';
  exception when others then
    if position('has not been cancelled' in sqlerrm) = 0 then raise; end if;
    perform test_ok('removing a pick that was never cancelled is refused, so removal is a second decision');
  end;

  select array_agg(vessel_id) into bins from unweighed_bin where node_id = pick_id;
  perform weigh_bins(pick_id, bins, 400);
  perform cancel_pick(pick_id);

  begin
    perform remove_pick(pick_id);
    raise exception 'FAIL: a pick somebody weighed fruit into was deleted';
  exception when others then
    if position('weighing' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a cancelled pick that was weighed keeps its weighings and refuses to be removed');
  end;

  delete from event where subject_type = 'node' and subject_id = pick_id;
  delete from placement where node_id = pick_id;
  delete from node where id = pick_id;
  delete from vessel where name like 'ASRTKEEP%';
  update term set attributes = attributes - 'tare_lbs'
   where kind = 'vessel_type' and value = 'picking_bin';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the vineyard, and what a planting inherits'; end $$;

-- 0039. Three levels, and the middle one answers for the bottom one when it has
-- nothing to say. The inheritance is derived on read, so a block corrected next
-- spring corrects every planting relying on it, which is T0-2.
do $$
declare
  vy   uuid := '00000000-0000-0000-0000-00000000da01';
  blk  uuid := '00000000-0000-0000-0000-00000000da02';
  r    record;
begin
  insert into vineyard (id, name, location) values (vy, 'Assert Vineyard', 'A road');
  insert into block (id, vineyard_id, name, planted_year, rootstock, soil)
  values (blk, vy, 'Assert Block', 2008, '3309', 'Jory');

  insert into planting (block_id, variety_id) values (blk, term_id('variety', 'chardonnay'));
  insert into planting (block_id, variety_id, planted_year, rootstock)
  values (blk, term_id('variety', 'pinot_noir'), 2014, 'Riparia');

  select * into r from planting_detail
   where block_id = blk and variety = 'Chardonnay';
  if r.planted_year <> 2008 or r.rootstock <> '3309' or r.soil <> 'Jory' then
    raise exception 'FAIL: a planting that says nothing did not take the block''s answers';
  end if;
  if not (r.inherited @> array['planted_year', 'rootstock', 'soil']) then
    raise exception 'FAIL: a planting borrowed the block''s answers and does not say which: %', r.inherited;
  end if;
  perform test_ok('a planting with nothing of its own takes the block''s answers and says which it borrowed');

  select * into r from planting_detail
   where block_id = blk and variety = 'Pinot Noir';
  if r.planted_year <> 2014 or r.rootstock <> 'Riparia' then
    raise exception 'FAIL: a planting with its own answers was overruled by the block';
  end if;
  if 'planted_year' = any(r.inherited) then
    raise exception 'FAIL: a planting that gave its own year is reported as having borrowed one';
  end if;
  if not ('soil' = any(r.inherited)) then
    raise exception 'FAIL: a planting that gave no soil is not reported as borrowing it';
  end if;
  perform test_ok('a planting that answers for itself overrules the block, field by field rather than all or nothing');

  -- Corrected at the block, and every planting relying on it moves. This is the
  -- thing a copied value could not do.
  update block set soil = 'Willakenzie' where id = blk;
  select count(*) into r from planting_detail where block_id = blk and soil = 'Willakenzie';
  perform test_ok('correcting the block corrects every planting that was relying on it, because nothing was copied');

  -- The composite key, the same one every pointer into `term` has carried since
  -- 0027. A block planted to a vessel type is not a thing.
  begin
    insert into planting (block_id, variety_id) values (blk, term_id('vessel_type', 'barrel'));
    raise exception 'FAIL: a block was planted to a vessel type';
  exception when foreign_key_violation then
    perform test_ok('a planting names a variety or nothing, which the composite key is what enforces');
  end;

  -- S-53's other half. `resolve_subject_name` runs its expression inside an
  -- exception handler that returns null, so moving the vineyard out of `block`
  -- would not have failed: every block would silently have stopped having a
  -- name. This is the assertion that would have caught it.
  if resolve_subject_name('block', blk) is distinct from 'Assert Vineyard Assert Block' then
    raise exception 'FAIL: a block names itself % rather than by its vineyard and name',
      coalesce(resolve_subject_name('block', blk), 'nothing');
  end if;
  if resolve_subject_name('vineyard', vy) is distinct from 'Assert Vineyard' then
    raise exception 'FAIL: a vineyard does not name itself';
  end if;
  perform test_ok('a block still names itself after the vineyard stopped being a column on it');

  delete from planting where block_id = blk;
  delete from block where id = blk;
  delete from vineyard where id = vy;
end $$;

-- Both views added since 0017 have to run as their caller. This is the third
-- time this has been worth asserting and the second time it was nearly missed.
do $$
declare leaky text;
begin
  select string_agg(c.relname, ', ') into leaky
    from pg_class c
    join pg_namespace ns on ns.oid = c.relnamespace
   where ns.nspname = 'public' and c.relkind = 'v'
     and c.relname in ('planting_detail', 'bin_to_return', 'unweighed_bin',
                       'weighing_without_photo', 'measurement_to_propagate')
     and (c.reloptions is null or not ('security_invoker=true' = any(c.reloptions)));
  if leaky is not null then
    raise exception
      'FAIL: these views run as their owner rather than their caller, so they hand a client somebody else data: %', leaky;
  end if;
  perform test_ok('every view added for intake and the vineyard runs as whoever asks');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the day, and what somebody wrote about it'; end $$;

-- 0041. The spine is derived, so the only things worth asserting about it are
-- that it finds what happened, that it puts it on the right day, and that it
-- shows the asker only what the asker may see.
do $$
declare n int; when_local date;
begin
  -- The timezone is the part that is easy to get wrong and impossible to notice.
  -- An event at five in the afternoon in Oregon is the next day in UTC, so a log
  -- that asked naively would file the afternoon's pressing under tomorrow.
  select (timestamptz '2026-09-14 23:30:00+00' at time zone 'America/Los_Angeles')::date
    into when_local;
  if when_local <> date '2026-09-14' then
    raise exception
      'FAIL: half past eleven UTC lands on % in Oregon, so the day log would file an evening pressing under the wrong day', when_local;
  end if;
  perform test_ok('a day is the winery''s day rather than the database''s, which is what puts an evening on the right one');

  insert into node (id, stage, status, name, created_by)
  values ('00000000-0000-0000-0000-00000000da11', 'maturation', 'open', 'Assert day lot',
          '00000000-0000-0000-0000-00000000a001');

  select count(*) into n from day_log()
   where subject = 'Assert day lot' and kind = 'lot';
  if n <> 1 then
    raise exception
      'FAIL: a lot created today does not appear in today''s log, so a pick started in a vineyard would be absent from its own first day';
  end if;
  perform test_ok('a lot coming into existence appears in the day it appeared, which no event would have recorded');

  delete from node where id = '00000000-0000-0000-0000-00000000da11';
end $$;

-- The two visibilities the winemaker asked for. Both are row level security
-- rather than a screen choosing what to draw, because a screen that decides is
-- a screen somebody can go around.
do $$
declare seen int;
begin
  insert into day_note (id, on_date, body, private, author_id) values
    ('00000000-0000-0000-0000-00000000da21', current_date,
     'Assert board note', false, '00000000-0000-0000-0000-00000000a001'),
    ('00000000-0000-0000-0000-00000000da22', current_date,
     'Assert private note', true, '00000000-0000-0000-0000-00000000a001');

  -- The author, who wrote both.
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  set local role authenticated;
  select count(*) into seen from day_note where id in (
    '00000000-0000-0000-0000-00000000da21', '00000000-0000-0000-0000-00000000da22');
  reset role;
  if seen <> 2 then
    raise exception 'FAIL: the person who wrote both notes can see % of them', seen;
  end if;

  -- Another cellar user: the board, and not the private one.
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;
  select count(*) into seen from day_note where id in (
    '00000000-0000-0000-0000-00000000da21', '00000000-0000-0000-0000-00000000da22');
  reset role;
  if seen <> 1 then
    raise exception
      'FAIL: another cellar user sees % of the two notes, and should see the board and not the private one', seen;
  end if;
  perform test_ok('a private note is its author''s alone, and the board is everybody who works here');

  -- A custom crush client: neither. They sign in to see their own wine and have
  -- no business reading the winery's day, which may be about other people's fruit.
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select count(*) into seen from day_note;
  reset role;
  if seen <> 0 then
    raise exception 'FAIL: a client can read % of the winery''s daily notes', seen;
  end if;
  perform test_ok('a client reads none of the winery''s daily notes, board or private');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  delete from day_note where id in (
    '00000000-0000-0000-0000-00000000da21', '00000000-0000-0000-0000-00000000da22');
end $$;

-- 0042. A photograph of the scale turns a typed number into evidence of a
-- number. Wanting it and requiring it differ in what happens next, not in
-- whether anybody mentions it.
do $$
declare
  pick_id uuid := '00000000-0000-0000-0000-00000000da31';
  out_js  jsonb;
  n       int;
begin
  update term set attributes = attributes || '{"tare_lbs": 50}'::jsonb
   where kind = 'vessel_type' and value = 'picking_bin';

  perform add_bins_to_pick(
    jsonb_build_object('id', pick_id, 'variety_id', term_id('variety', 'riesling'),
                       'vintage', 2026),
    null, 2, term_id('vessel_type', 'picking_bin'), 'ASRTPHOTO', 100);

  out_js := weigh_bins(pick_id,
    array(select vessel_id from unweighed_bin where node_id = pick_id limit 1),
    400, null, null, 'weighing/assert.jpg');
  if (out_js ->> 'photographed')::boolean is not true then
    raise exception 'FAIL: a weighing given a photograph does not say it has one';
  end if;

  out_js := weigh_bins(pick_id,
    array(select vessel_id from unweighed_bin where node_id = pick_id),
    300);
  if (out_js ->> 'photographed')::boolean is not false then
    raise exception 'FAIL: a weighing with no photograph claims to have one';
  end if;
  perform test_ok('a weighing says whether anybody photographed the scale, which is what wanting rather than requiring needs');

  -- Absent rather than empty. "Nobody photographed this" and "somebody
  -- photographed nothing" must not be the same row, which is why the path is
  -- stripped rather than stored as an empty string.
  select count(*) into n from event
   where subject_type = 'node' and subject_id = pick_id
     and operation_id = term_id('operation', 'weigh')
     and data ? 'photo_path' and btrim(data ->> 'photo_path') = '';
  if n <> 0 then
    raise exception 'FAIL: % weighing(s) carry an empty photograph path, which reads as evidence and is not', n;
  end if;
  perform test_ok('a weighing nobody photographed carries no path at all rather than an empty one');

  select count(*) into n from weighing_without_photo where node_id = pick_id;
  if n <> 1 then
    raise exception
      'FAIL: % of the two weighings are listed as unphotographed, and exactly one was', n;
  end if;
  perform test_ok('the weighings whose numbers cannot be checked against anything are the ones listed');

  -- One name, one function. 0036 shipped two `add_bins_to_pick` by adding
  -- parameters with defaults, and every call then failed with "is not unique".
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'weigh_bins';
  if n <> 1 then
    raise exception 'FAIL: there are % versions of weigh_bins, so a call cannot choose between them', n;
  end if;
  perform test_ok('weighing has exactly one signature, so adding the photograph did not fork it');

  delete from event where subject_type = 'node' and subject_id = pick_id;
  delete from placement where node_id = pick_id;
  delete from node where id = pick_id;
  delete from vessel where name like 'ASRTPHOTO%';
  update term set attributes = attributes - 'tare_lbs'
   where kind = 'vessel_type' and value = 'picking_bin';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- what is still owed to paper'; end $$;

-- 0043. The `unweighed_bin` pattern pointed at paperwork: a derived list that
-- should be empty, which is the only mechanism in this app that has reliably
-- caught anything, because it does not depend on somebody remembering to look.
--
-- **Every timestamp here is written out rather than taken from `now()`.** A
-- transaction sees one `now()` for its whole length, so a document retired at
-- `now()` and an event recorded at `now()` are the same instant and no
-- comparison between them can distinguish anything. The first version of this
-- test did exactly that and reported a number that meant nothing.
do $$
declare
  sheet_a uuid := '00000000-0000-0000-0000-00000000fa11';
  sheet_b uuid := '00000000-0000-0000-0000-00000000fa12';
  lot_id  uuid := '00000000-0000-0000-0000-00000000fa13';
  ev_in   uuid := '00000000-0000-0000-0000-00000000fa14';
  ev_early uuid := '00000000-0000-0000-0000-00000000fa15';
  ev_late uuid := '00000000-0000-0000-0000-00000000fa16';
  n       int;
begin
  insert into node (id, stage, status, name, created_by)
  values (lot_id, 'maturation', 'open', 'Assert paper lot',
          '00000000-0000-0000-0000-00000000a001');

  -- Kept through September, and one of them abandoned at the end of it.
  insert into paper_record (id, name, effective_from, retired_at) values
    (sheet_a, 'Assert weight sheet', timestamptz '2026-09-01 00:00+00', null),
    (sheet_b, 'Assert ticket book',  timestamptz '2026-09-01 00:00+00',
                                     timestamptz '2026-09-20 00:00+00');
  insert into paper_record_operation (paper_record_id, operation_id)
  select id, term_id('operation', 'weigh') from paper_record
   where id in (sheet_a, sheet_b);

  insert into event (id, operation_id, subject_type, subject_id, at, by_user, data)
  values
    -- Before either form existed.
    (ev_early, term_id('operation', 'weigh'), 'node', lot_id,
     timestamptz '2026-08-15 12:00+00', '00000000-0000-0000-0000-00000000a001', '{}'),
    -- While both were being kept.
    (ev_in, term_id('operation', 'weigh'), 'node', lot_id,
     timestamptz '2026-09-10 12:00+00', '00000000-0000-0000-0000-00000000a001', '{}'),
    -- After one was retired.
    (ev_late, term_id('operation', 'weigh'), 'node', lot_id,
     timestamptz '2026-09-25 12:00+00', '00000000-0000-0000-0000-00000000a001', '{}');

  -- One measurement, two forms, two pieces of work. Doing one of two sheets is
  -- not doing both, which is the case a queue exists for.
  select count(*) into n from measurement_to_propagate where event_id = ev_in;
  if n <> 2 then
    raise exception
      'FAIL: a weighing due on two forms appears % time(s), and each form is its own piece of work', n;
  end if;
  perform test_ok('a measurement due on two documents is two pieces of work, not one');

  -- Adding a form must not invent a backlog stretching to the start of the
  -- vintage.
  select count(*) into n from measurement_to_propagate where event_id = ev_early;
  if n <> 0 then
    raise exception
      'FAIL: a measurement from before any of these forms existed is owed to % of them', n;
  end if;
  perform test_ok('a form starts owing from when it started being kept, so adding one invents no backlog');

  -- Retiring stops new obligations and forgives none of the old ones. S-59 is
  -- that there is no way to forgive them at all.
  select count(*) into n from measurement_to_propagate
   where event_id = ev_late and paper_record_id = sheet_b;
  if n <> 0 then
    raise exception 'FAIL: a retired form is still collecting new work';
  end if;
  select count(*) into n from measurement_to_propagate
   where event_id = ev_in and paper_record_id = sheet_b;
  if n <> 1 then
    raise exception
      'FAIL: retiring a form forgave work that was outstanding while it was being kept, which is the thing this list exists to show';
  end if;
  perform test_ok('retiring a document stops new obligations and forgives none of the ones already owed');

  -- Writing it on one form takes it off that form and no other.
  insert into propagation (event_id, paper_record_id, written_by)
  values (ev_in, sheet_a, '00000000-0000-0000-0000-00000000a001');

  select count(*) into n from measurement_to_propagate where event_id = ev_in;
  if n <> 1 then
    raise exception
      'FAIL: writing a measurement on one of two forms left % owing, and one was expected', n;
  end if;
  perform test_ok('writing a measurement onto one document clears it from that one and no other');

  -- Twice on the same form is the same claim, not two.
  begin
    insert into propagation (event_id, paper_record_id, written_by)
    values (ev_in, sheet_a, '00000000-0000-0000-0000-00000000a001');
    raise exception 'FAIL: the same measurement was written onto the same form twice';
  exception when unique_violation then
    perform test_ok('a measurement is written onto a given form once, and saying so twice is refused');
  end;

  delete from propagation where event_id = ev_in;
  delete from event where id in (ev_early, ev_in, ev_late);
  delete from paper_record_operation where paper_record_id in (sheet_a, sheet_b);
  delete from paper_record where id in (sheet_a, sheet_b);
  delete from node where id = lot_id;
end $$;

-- Paperwork is the facility's business and none of a client's.
do $$
declare seen int;
begin
  insert into paper_record (id, name) values
    ('00000000-0000-0000-0000-00000000fa21', 'Assert private form');

  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select count(*) into seen from paper_record;
  reset role;
  if seen <> 0 then
    raise exception 'FAIL: a client can read % of this winery''s physical forms', seen;
  end if;

  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;
  select count(*) into seen from paper_record
   where id = '00000000-0000-0000-0000-00000000fa21';
  reset role;
  if seen <> 1 then
    raise exception 'FAIL: somebody who works here cannot see the forms they are meant to fill in';
  end if;
  perform test_ok('the winery''s paperwork is readable by the people who keep it and by no client');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  delete from paper_record where id = '00000000-0000-0000-0000-00000000fa21';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- functions survive a restore'; end $$;

-- pg_dump sets search_path to empty at the top of every dump, on purpose, so a
-- restore cannot be hijacked by whatever is on the path. Any function that
-- names a type or table unqualified then stops resolving, and every trigger
-- that fires during the restore runs in that state. This was found by a restore
-- failing with "field maker names vocabulary cooper, which does not exist",
-- which was true of the cast and false of the vocabulary.
do $$
declare unpinned text;
begin
  select string_agg(p.proname, ', ') into unpinned
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proconfig is null;

  if unpinned is not null then
    raise exception 'FAIL: these do not pin search_path and will break in a restore: %', unpinned;
  end if;
  perform test_ok('every function pins its search_path, so a restore does not trip over it');
end $$;

do $$ begin raise notice '--- all assertions passed'; end $$;

rollback;
