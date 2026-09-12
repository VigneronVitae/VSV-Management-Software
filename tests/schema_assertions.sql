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
--              supabase/migrations/0024_task_board_via_registry.sql]
-- Depended on by: [docs/status-ledger.md, scripts/green.sh, scripts/mutate.sh]
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
  ('cooper',        'francois_freres', 'François Frères', 10),
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
    insert into node (stage, name, variety_id) values ('bin', 'x', term_id('cooper','francois_freres'));
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
do $$ begin
  begin
    perform bind_vessel_code('00000000-0000-0000-0000-00000000c002','COOPER-7781','peeled');
    raise exception 'FAIL: a bound code moved to another vessel';
  exception when unique_violation then
    perform test_ok('a code bound to one barrel refuses to move to another');
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
      'attributes', jsonb_build_object('maker', term_id('cooper','francois_freres'),
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
  values ('cooper', 'letina', 'Letina', '{"contract":"manufacturer"}');

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

insert into term (kind, value, label) values ('cooper', 'untagged_maker', 'Untagged maker');

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
insert into template (id, variety_id, name)
  values ('00000000-0000-0000-0000-00000000e001', term_id('variety','pinot_gris'), 'Assertion template');
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
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('a value below its declared minimum is refused');
  end;
end $$;

-- A cooper that says so. francois_freres is added at runtime by this file with
-- no contract, and a maker with no contract satisfies every contract by design,
-- so it would be accepted here and correctly.
insert into term (kind, value, label, attributes)
  values ('cooper', 'seguin_moreau', 'Seguin Moreau', '{"contract":"cooper"}');

do $$
declare maker_id uuid;
begin
  select id into maker_id from term where kind = 'cooper' and value = 'seguin_moreau';
  begin
    insert into vessel (type_id, name, attributes)
      values (term_id('vessel_type','tank'), 'Wrong maker',
              jsonb_build_object('maker', maker_id));
    raise exception 'FAIL: a cooper was accepted as a tank manufacturer';
  exception when raise_exception then
    if sqlerrm like 'FAIL:%' then raise; end if;
    perform test_ok('a cooper is refused where the type asks for a manufacturer');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a lot closes when it is empty, not when it feeds'; end $$;

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
