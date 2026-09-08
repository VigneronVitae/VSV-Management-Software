-- ---------------------------------------------------------------------------
-- Type: test
-- Purpose: "Asserts that the schema refuses what it should refuse and computes
--           what it should compute, so that the definition of done in CLAUDE.md
--           is a command rather than a description."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0003_parties_and_products.sql,
--              supabase/migrations/0004_terms_and_effects.sql,
--              supabase/migrations/0005_account_and_walk.sql]
-- Depended on by: [docs/status-ledger.md]
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
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), true);
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else json_build_object('sub', p_user)::text end, true);
end $$;

create or replace function test_ok(p_msg text)
returns void language plpgsql as $$
begin
  raise notice 'ok   %', p_msg;
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

do $$
declare u app_user;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  u := claim_account('First Account');
  if u.role <> 'admin' then raise exception 'FAIL: the first account is not admin'; end if;
  perform test_ok('the first account becomes admin');

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
      'attributes', jsonb_build_object('cooper','francois_freres','wood','french_oak',
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

do $$ begin raise notice '--- all assertions passed'; end $$;

rollback;
