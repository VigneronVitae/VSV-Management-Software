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
--              supabase/migrations/0032_vessel_maker_and_room_temperature.sql, supabase/migrations/0033_intake.sql, supabase/migrations/0034_press.sql, supabase/migrations/0035_bins_in_bulk.sql, supabase/migrations/0036_bins_on_loan.sql, supabase/migrations/0037_export.sql, supabase/migrations/0038_cancel_a_pick.sql, supabase/migrations/0039_vineyard.sql, supabase/migrations/0040_block_variety_is_history.sql, supabase/migrations/0041_daily_log.sql, supabase/migrations/0042_weighing_photo.sql, supabase/migrations/0043_record_propagation.sql, supabase/migrations/0044_finishing_a_pick.sql, supabase/migrations/0045_press_detail.sql, supabase/migrations/0046_supply_inventory.sql, supabase/migrations/0047_attachments.sql, supabase/migrations/0048_pick_weighing.sql, supabase/migrations/0049_every_lot_says_its_vintage.sql, supabase/migrations/0050_additions.sql, supabase/migrations/0051_supplies_for_addition.sql, supabase/migrations/0052_press_as_a_process.sql, supabase/migrations/0053_a_press_is_a_vessel.sql, supabase/migrations/0054_a_spent_pick_is_spent.sql, supabase/migrations/0055_press_draws.sql, supabase/migrations/0056_draw_to_a_level.sql, supabase/migrations/0057_the_contract.sql, supabase/migrations/0058_an_open_pick_is_a_view.sql, supabase/migrations/0061_two_declarations_were_wrong.sql, supabase/migrations/0063_a_note_is_a_thing_too.sql, supabase/migrations/0065_confirming_without_owning.sql, supabase/migrations/0066_a_guard_that_can_be_weakened.sql, supabase/migrations/0067_sampling.sql, supabase/migrations/0068_an_invite_to_claim.sql,
--              supabase/migrations/0069_the_contract_hears_about_the_invite.sql,
--              supabase/migrations/0070_a_code_worth_guessing.sql, supabase/migrations/0064_typing_a_note.sql, supabase/migrations/0062_a_note_on_anything.sql, supabase/migrations/0060_the_contract_catches_up.sql, supabase/migrations/0059_a_weighing_says_its_pick.sql,
--              supabase/migrations/0071_a_wine_says_its_colour.sql,
--              supabase/migrations/0072_a_barrel_remembers.sql,
--              supabase/migrations/0073_the_contract_hears_about_colour.sql,
--              supabase/migrations/0074_an_unknown_colour_is_not_a_safe_one.sql,
--              supabase/migrations/0075_two_parents_that_disagree.sql,
--              supabase/migrations/0076_a_tie_goes_to_the_barrel.sql,
--              supabase/migrations/0077_a_barrel_can_arrive_red.sql,
--              supabase/migrations/0078_the_wine_in_a_vessel.sql,
--              supabase/migrations/0079_a_room_says_which_way_it_is_held.sql,
--              supabase/migrations/0080_whose_wine_it_is_can_be_corrected.sql,
--              supabase/migrations/0081_a_borrowed_bin_is_not_ours.sql,
--              supabase/migrations/0082_three_kinds_of_sampling.sql,
--              supabase/migrations/0083_what_you_can_sample.sql,
--              supabase/migrations/0084_a_bin_of_fruit_is_not_juice.sql,
--              supabase/migrations/0085_a_stack_of_bins_is_inventory.sql,
--              supabase/migrations/0086_a_variable_named_like_a_column.sql,
--              supabase/migrations/0087_a_bin_holds_pounds.sql,
--              supabase/migrations/0088_moving_more_than_one.sql,
--              supabase/migrations/0090_a_press_takes_bins.sql,
--              supabase/migrations/0091_a_bin_says_its_weight_everywhere.sql,
--              supabase/migrations/0089_correcting_one_bin.sql]
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
    insert into node (stage, name, vintage) values ('bin', 'ownerless', 2026);
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
    insert into node (stage, name, variety_id, vintage) values ('bin', 'x', term_id('vessel_maker','francois_freres'), 2026);
    raise exception 'FAIL: a cooper was accepted where a variety belongs';
  exception when foreign_key_violation or restrict_violation then
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
declare u app_user; was_empty boolean; boot text; an_admin uuid;
begin
  select count(*) = 0 into was_empty from app_user;

  -- 0068. Against a database that already has people in it, which is every run
  -- against a copy of the cellar, the suite's own fixture accounts have to be
  -- let in like anybody else. So borrow an administrator who is already there
  -- and have them issue the invite. Against an empty database `boot` stays null
  -- and the first claim needs none, which is the case this block is about.
  if not was_empty then
    select id into an_admin from app_user where role = 'admin' and active limit 1;
    if an_admin is null then
      raise exception
        'FAIL: app_user has rows and no active administrator, so nothing can let the fixtures in';
    end if;
    perform test_act_as(an_admin);
    boot := make_invite('cellar', 'the suite''s first fixture') ->> 'code';
  end if;

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  u := claim_account('First Account', boot);

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

  -- 0068. From the second person onwards, somebody already here has to let you
  -- in. The admin above issues the invite, which is the shape a real winery has:
  -- an intern is handed a phone and a code by whoever runs the cellar.
  declare
    inv text;
  begin
    inv := make_invite('cellar', 'the suite''s intern') ->> 'code';

    perform test_act_as('00000000-0000-0000-0000-00000000a002');
    -- Which refusal, not merely that one happened. `claim_account` declines
    -- this call at four separate guards and every one of them raises
    -- insufficient_privilege, so an assertion that catches the sqlstate covers
    -- the function and no site in it. The mutation harness proved that: with
    -- the missing-invite guard neutralised, the call fell through to the
    -- lookup, failed to find a row for a null code, and refused with a
    -- different message that this assertion accepted.
    begin
      perform claim_account('Harvest Intern');
      raise exception 'FAIL: a second account was claimed with no invite';
    exception when insufficient_privilege then
      if sqlerrm not like '%has to let you in%' then
        raise exception 'FAIL: claiming with no invite refused with "%", which is a different guard', sqlerrm;
      end if;
      perform test_ok('claiming without an invite is refused from the second person onwards, so reaching the sign-up page is not the same as working here');
    end;

    u := claim_account('Harvest Intern', inv);
    if u.role <> 'cellar' then raise exception 'FAIL: the second account is not cellar'; end if;
    perform test_ok('every account after the first is cellar, and needs somebody already here to have said so');

    -- One use. A code that admitted somebody is spent, or one leaked code
    -- admits everybody who hears it.
    perform test_act_as('00000000-0000-0000-0000-00000000a003');
    begin
      perform claim_account('Second Use', inv);
      raise exception 'FAIL: one invite admitted two people';
    exception when insufficient_privilege then
      if sqlerrm not like '%already been used%' then
        raise exception 'FAIL: a second use refused with "%", which is a different guard', sqlerrm;
      end if;
      perform test_ok('an invite works once, so a code somebody overhears does not admit a second person');
    end;

    -- A code nobody issued. Six characters is a billion, and a refusal that
    -- guesses in the caller's favour turns that into one attempt.
    begin
      perform claim_account('Made It Up', 'ZZZZZZ');
      raise exception 'FAIL: an invite nobody issued admitted somebody';
    exception when insufficient_privilege then
      if sqlerrm not like '%not one of ours%' then
        raise exception 'FAIL: an unissued code refused with "%", which is a different guard', sqlerrm;
      end if;
      perform test_ok('a code nobody issued admits nobody, so guessing is guessing against the whole alphabet rather than against a missing check');
    end;

    -- And an expired one. A code is good for a week because an invite left
    -- lying in a text message is a credential with no expiry otherwise. Backdated
    -- here rather than waited for, which is the only part of this that is not
    -- what a winery does.
    perform test_act_as('00000000-0000-0000-0000-00000000a001');
    inv := make_invite('cellar', 'the suite''s stale code') ->> 'code';
    update invite set expires_at = now() - interval '1 day' where code = inv;
    perform test_act_as('00000000-0000-0000-0000-00000000a003');
    begin
      perform claim_account('Too Late', inv);
      raise exception 'FAIL: an expired invite admitted somebody';
    exception when insufficient_privilege then
      if sqlerrm not like '%expired%' then
        raise exception 'FAIL: an expired code refused with "%", which is a different guard', sqlerrm;
      end if;
      perform test_ok('an expired invite admits nobody, so a code in a month-old text message is worth nothing');
    end;
  end;
end $$;

-- a cellar user belonging to the client party, for the scoping test below
do $$
declare u app_user; inv text;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  inv := make_invite('cellar', 'the suite''s client login') ->> 'code';
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  u := claim_account('Client Login', inv);
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
    insert into node (stage, name, provenance, vintage) values ('bin','born confirmed','confirmed', 2026);
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
  -- Scoped to the node this block is about, not the whole table.
  --
  -- This counted every row in `lineage` and passed for eleven sessions because
  -- the cellar had never had one. The winemaker started his first real press,
  -- which wrote the first lineage row this winery has ever had, and the suite
  -- went red on an assertion that has nothing to do with pressing. It is the
  -- same defect as the tare assertion that read whatever tare the facility
  -- happened to have set: **an assertion that reads production data is testing
  -- the cellar rather than the schema**, and the cellar is allowed to change.
  select count(*) into lineage_rows from lineage
   where parent_id = '00000000-0000-0000-0000-00000000b001'
      or child_id = '00000000-0000-0000-0000-00000000b001';
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

-- Named so it can collide with neither a real maker nor another fixture. It
-- avoids the `assert_` prefix on purpose: a later block asserts the exact set of
-- makers whose value begins with it, so a fixture wearing that prefix joins a
-- list it was never meant to be in. This fixture was called
-- `letina` and the winemaker then entered Letina as a real tank fabricator,
-- at which point the suite went red for a reason that had nothing to do with the
-- code. **A fixture that can collide with production data is the same defect as
-- an assertion that reads production data**, which this suite already learned
-- once today over a bin tare, and this is the second instance of the same class.
insert into term (kind, value, label, attributes)
  values ('vessel_maker', 'fixture_tank_brand', 'Fixture Tank Brand',
          '{"contract":"manufacturer"}');

do $$
declare barrel_has int; tank_has int;
begin
  select count(*) into barrel_has
    from makers_for_vessel_type(term_id('vessel_type','barrel')) where value = 'fixture_tank_brand';
  select count(*) into tank_has
    from makers_for_vessel_type(term_id('vessel_type','tank')) where value = 'fixture_tank_brand';
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

insert into node (id, stage, name, quantity, unit, vintage)
  values ('00000000-0000-0000-0000-00000000b0a1','ferment','Allow-list lot', 500, 'L', 2026);

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
  -- 74 before 0046, which added nine across supply, its sorts, supply_movement
  -- and shopping_item. None reads blanket true: the stores are the facility's
  -- business and a client has no reason to know what is on its shelves.
  -- 83 before 0047, which added four on attachment: read, insert, a caption-only
  -- update and an admin delete. None reads blanket true, and the read is in fact
  -- narrower than it should be, which is filed as S-65.
  -- 87 before 0057, which added six across the contract's three registries:
  -- a read and an admin write on each. The three reads are blanket true and
  -- are judged in the disposition list below as permissive, for the same
  -- reason `subject_resolver` and `term_kind` are: the contract says what
  -- kinds of thing exist and what may be done, and never whose wine.
  -- 93 before 0062, which added four on `note`: read, insert, a reword
  -- restricted to the author, and an admin delete. None reads blanket true,
  -- and the read is the same too-narrow one S-65 names for photographs.
  -- 97 before 0068, which added one on `invite`: a single all-verbs policy
  -- gated on is_admin(). It is the narrowest policy in the schema and that is
  -- deliberate. An invite is a credential, so a cellar hand who could read the
  -- list could admit their own second account, which is the thing the gate
  -- exists to stop.
  want := '98';
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
    ('readable.readable_read', 'permissive',
     'AR-Q8. What a periphery may read, by name. Saying that a list of presses exists discloses no press.'),
    ('capability.capability_read', 'permissive',
     'AR-Q8. What a periphery may write and what each write asks for. A client periphery cannot exist without reading this, and it is the same kind of thing as knowing the app has a Press screen.'),
    ('capability_exemption.capability_exemption_read', 'permissive',
     'AR-Q8. Which functions are deliberately outside the contract, with why. Readable so that the reason travels with the omission rather than only living in a migration.'),
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

  insert into node (id, stage, name, quantity, unit, vintage)
    values ('00000000-0000-0000-0000-0000000000d1', 'ferment', 'Cellar made this', 100, 'L', 2026);
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
    insert into node (id, stage, name, quantity, unit, vintage)
      values ('00000000-0000-0000-0000-0000000000d3', 'ferment', 'Client made this', 10, 'L', 2026);
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
  -- The four kinds this census is about, named rather than "whatever is in the
  -- catalog". It used to group over every `contype` present, which silently
  -- coupled the suite to the Postgres major version: **Postgres 18 records NOT
  -- NULL constraints in `pg_constraint` as contype 'n' and Postgres 17 does
  -- not**, so the same schema reports `n=181` on one and nothing on the other.
  --
  -- Found by applying this kernel to a Postgres compiled to WASM, which is
  -- Postgres 18, while investigating whether the kernel could run on a phone.
  -- The kernel was fine and this assertion was not, and it would have failed the
  -- same way the day this winery's server was upgraded.
  select string_agg(x.line, ' ' order by x.line) into have from (
    select c.contype::text || '=' || count(*)::text as line
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'public'
       and c.contype in ('c', 'f', 'p', 'u')
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
  -- c=25 f=53 p=29 u=18 before 0046, which added three tables. supply brings a
  -- unique name, a check that it has a unit, and the composite pinning its kind
  -- to the material vocabulary. supply_movement brings checks that a kind is
  -- known, that a quantity is an amount, and that only a count carries what was
  -- expected. shopping_item brings a check that a note says something, and both
  -- carry foreign keys to supply and to whoever recorded them.
  -- The sorts of a supply are a join table of their own, which is what lets a
  -- hose head be two things at once: its composite primary key and the
  -- composite foreign key pinning a sort to the material vocabulary.
  -- c=30 f=59 p=33 u=19 before 0047, which added one table. `attachment`
  -- brings its primary key, the check that a path is not blank, the unique
  -- that makes a double tap one photograph rather than two, and three
  -- foreign keys: the subject type into the resolver, whoever attached it,
  -- and the event it is evidence of. That last one is a real foreign key
  -- where `subject_id` cannot be, which is the whole reason it exists.
  -- c=31 f=62 p=34 u=20 before 0049, whose one new check is the rule that a
  -- lot says either a year or that it is non-vintage. It is added `not
  -- valid`, which this census does not distinguish and the assertion in the
  -- vintage block below does. S-69.
  -- c=32 f=62 p=34 u=20 before 0050, whose one new foreign key is a supply
  -- movement naming the addition that caused it. That link is the whole of
  -- S-64's answer: it is what makes the scoop off the shelf and the scoop
  -- into the wine provably one act.
  -- c=32 f=63 p=34 u=20 before 0057, which added the contract's three
  -- registries. Three primary keys, and four checks: a readable and a
  -- capability key must be qualified so `cellar.weigh_bins` cannot collide
  -- with another module's, a capability's fields must be a list, and an
  -- exemption must carry a reason. The one foreign key is a capability's
  -- subject into `readable`, restricted, because a capability pointing at a
  -- list that has gone is a periphery with nothing to offer.
  -- c=36 f=64 p=37 u=20 before 0062, which added `note`: its primary key,
  -- the check that it says something, and three foreign keys, being the
  -- subject type into the resolver, the event it is about, and who wrote it.
  -- c=37 f=67 p=38 u=20 before 0064, which types a note: the check that a
  -- value without a kind is refused, and the composite pinning the kind to
  -- the fact_kind vocabulary the way every other pointer into it is pinned.
  -- c=38 f=69 p=38 u=20 before 0068, which added `invite`: its primary key, the
  -- check that a code is at least six characters, and two foreign keys into
  -- app_user for who issued it and who used it. Both of those are nullable, and
  -- deliberately: an invite exists before anybody has used it, which is the
  -- whole of its working life.
  -- c=39 f=71 p=39 u=20 before 0071, whose one new foreign key is the composite
  -- pinning a lot''s colour to the wine_colour vocabulary, the same shape the
  -- variety and the product type already use. No new check: a lot with no
  -- colour is legal and is caught by a worklist rather than refused, which is
  -- what the winemaker asked for.
  -- c=39 f=72 p=39 u=20 before 0079, whose one new check is that a room held in
  -- a direction is a room under control. Those were always one fact and are now
  -- two columns, so the constraint is what keeps them one.
  -- c=40 f=72 p=39 u=20 before 0087, whose two new checks are on a bin's
  -- fruit: that a weight is a weight, and that a bin says pounds or says how
  -- full and never both. The second is the one that matters: two answers to
  -- one question with nothing to say which was typed and which was computed.
  want := 'c=42 f=72 p=39 u=20';
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
       -- 0071. A lot says its colour, pinned the way the variety and the
       -- product type already are. It is the fact a barrel's own colour is
       -- derived from, and no other column in this schema can answer it.
       || 'node.node_colour_is_a_wine_colour, '
       || 'node.node_product_type_is_a_product_type, '
       || 'node.node_variety_is_a_variety, '
       || 'note.note_kind_is_a_fact_kind, '
       -- 0043. A physical form says which kinds of measurement belong on it.
       || 'paper_record_operation.paper_record_operation_is_an_operation, '
       -- 0039. A block is planted to a variety, pinned the same way every other
       -- pointer into term has been since 0027.
       || 'planting.planting_variety_is_a_variety, '
       || 'procedure_step.step_material_is_a_material, '
       -- 0046. A supply is of material kinds, plural: the vocabulary 0027
       -- registered to the inventory module and nothing had used until now, on a
       -- join table so a hose head can be two things at once.
       || 'supply_material_kind.supply_kind_is_a_material, '
       || 'task.task_operation_is_an_operation, '
       || 'template.template_applies_to_a_registered_kind, '
       || 'template_step.template_step_operation_is_an_operation, '
       || 'vessel.vessel_type_is_a_vessel_type';

  if have is distinct from want then
    raise exception
      E'FAIL: the composite foreign keys into term(id, kind) changed.\nnow:  %\nwas:  %', have, want;
  end if;
  perform test_ok('every composite foreign key ties a typed id to its kind, which is what phase 5 moves');
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
       -- 0071, the kind half of the colour key.
       || 'node.colour_kind=''wine_colour''::text '
       || 'node.product_kind=''product_type''::text '
       || 'node.variety_kind=''variety''::text '
       || 'note.kind_kind=''fact_kind''::text '
       -- 0043, pinning a form's operation list to the operation vocabulary.
       || 'paper_record_operation.operation_kind=''operation''::text '
       -- 0039, pinning a planting's term to the variety vocabulary.
       || 'planting.variety_kind=''variety''::text '
       || 'procedure_step.material_kind=''material_kind''::text '
       -- 0046, pinning a supply's sorts to the material vocabulary.
       || 'supply_material_kind.kind_kind=''material_kind''::text '
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
    insert into node (stage, name, variety_id, vintage)
      values ('bin','wrong variety', term_id('vessel_maker','francois_freres'), 2026);
    raise exception 'FAIL: node.variety_id accepted a cooper';
  exception when foreign_key_violation or restrict_violation then refused := refused + 1;
  end;

  begin
    insert into node (stage, name, product_type_id, vintage)
      values ('bin','wrong product', term_id('variety','pinot_noir'), 2026);
    raise exception 'FAIL: node.product_type_id accepted a variety';
  exception when foreign_key_violation or restrict_violation then refused := refused + 1;
  end;

  begin
    insert into vessel (name, type_id) values ('wrong type', term_id('variety','pinot_noir'));
    raise exception 'FAIL: vessel.type_id accepted a variety';
  exception when foreign_key_violation or restrict_violation then refused := refused + 1;
  end;

  begin
    insert into event (operation_id, subject_type, subject_id, by_user)
      values (term_id('variety','pinot_noir'), 'node',
              '00000000-0000-0000-0000-00000000b001',
              '00000000-0000-0000-0000-00000000a001');
    raise exception 'FAIL: event.operation_id accepted a variety';
  exception when foreign_key_violation or restrict_violation then refused := refused + 1;
  end;

  begin
    insert into task (operation_id, subject_type, subject_id)
      values (term_id('variety','pinot_noir'), 'node', '00000000-0000-0000-0000-00000000b001');
    raise exception 'FAIL: task.operation_id accepted a variety';
  exception when foreign_key_violation or restrict_violation then refused := refused + 1;
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
  -- a=32 c=12 n=1 before 0046. The new cascade is supply_movement to supply: a
  -- movement has no meaning without the thing it moved. The new set-null is
  -- shopping_item to supply, because "buy more DAP" is still a useful line on a
  -- list after somebody retires the supply record it pointed at. The three new
  -- no-actions are who recorded each of the three, which outlive their accounts.
  -- The extra cascade is a supply's sorts to the supply: what something is, is
  -- meaningless without the something.
  -- a=35 c=14 n=2 r=8 before 0047. The two new restricts are an attachment's
  -- subject type into the resolver and the event it is evidence of: a
  -- photograph that has lost what it was a photograph of is worse than a
  -- refusal, because it is still in the record and no longer says anything.
  -- The new no-action is whoever attached it, which outlives their account
  -- for the same reason a note does.
  -- a=36 c=14 n=2 r=10 before 0050. The new restrict is that same link: a
  -- movement left pointing at an addition that is not there would be a use
  -- off the shelf with no reason attached, which is worse than no link.
  -- a=36 c=14 n=2 r=11 before 0057. The new restrict is a capability's
  -- subject into `readable`: a capability that acts on a list which has been
  -- deleted is a thing a periphery would offer and could not fill.
  -- a=36 c=14 n=2 r=12 before 0062. Two new restricts on `note`, the same
  -- pair `attachment` carries: the subject type into the resolver, and the
  -- event it is about. The new no-action is whoever wrote it, which outlives
  -- their account the way a day note does.
  -- a=37 c=14 n=2 r=14 before 0064. The two new no-actions are a note's fact
  -- kind and the composite pinning it to that vocabulary: a kind is deleted
  -- by deactivating it, not by removing the row, so nothing needs to cascade.
  -- a=39 c=14 n=2 r=14 before 0068. The two new no-actions are who issued an
  -- invite and who used it. Neither cascades and neither sets null, because a
  -- used invite is the only record there will ever be of who admitted whom, and
  -- it should survive either of them leaving.
  -- a=41 c=14 n=2 r=14 before 0071. The new no-action is a lot''s colour into
  -- the vocabulary: a colour is retired by deactivating the term, not by
  -- deleting the row, so nothing needs to cascade and nothing needs to restrict.
  want := 'a=42 c=14 n=2 r=14';
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

  -- 0047 added the two on `attachment`. The subject type is a registry pin like
  -- the other four. The event one is the interesting one: it is the only place
  -- in this schema where a restrict guards evidence rather than structure, and
  -- it says that a photograph may not be left pointing at a reading that no
  -- longer exists. Events are never deleted, so it should never fire; the point
  -- is what happens if somebody writes the code that would.
  -- 0050 added supply_movement.caused_by, the third restrict guarding
  -- evidence rather than structure.
  want := 'attachment.attachment_about_event_fkey, '
       || 'attachment.attachment_subject_type_fkey, '
       || 'capability.capability_subject_fkey, '
       || 'event.event_subject_type_is_registered, '
       || 'lineage.lineage_child_id_fkey, lineage.lineage_parent_id_fkey, '
       || 'note.note_about_event_fkey, note.note_subject_type_fkey, '
       || 'placement.placement_node_id_fkey, placement.placement_vessel_id_fkey, '
       || 'procedure.procedure_subject_type_is_registered, '
       || 'supply_movement.supply_movement_caused_by_fkey, '
       || 'task.task_subject_type_is_registered, term.term_kind_is_registered';

  if have <> want then
    raise exception E'FAIL: the restrict keys changed.\nnow:  %\nwas:  %', have, want;
  end if;
  perform test_ok('the fourteen ON DELETE RESTRICT keys are the lineage and placement ones ledger A20 names, the five registry ones, and the one holding a photograph to the reading it is evidence of');
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
    insert into node (stage, name, block_id, vintage)
      values ('ferment', 'ferment with a block', '00000000-0000-0000-0000-00000000a0b1', 2026);
    raise exception 'FAIL: a non-bin node carried a block';
  exception when check_violation then
    perform test_ok('only a bin may name a block, so a ferment cannot claim to have arrived from one');
  end;

  insert into node (stage, name, block_id, vintage)
    values ('bin', 'bin with a block', '00000000-0000-0000-0000-00000000a0b1', 2026);
  perform test_ok('a bin may name a block, so the constraint is about the stage and not about blocks');

  -- node_hidden_known and party_default_hidden_known, the two that keep the
  -- privacy vocabulary from drifting into free text.
  begin
    insert into node (stage, name, hidden, vintage) values ('bin', 'hidden nonsense', array['not_a_field'], 2026);
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
    -- 0047's two, and they are opposite cases worth keeping apart.
    --
    -- `attachment_event_matches_subject` opens with `if new.about_event is null
    -- then return new`, which is literally A25's shape: a null permits. Here the
    -- null is the meaning rather than a gap. A photograph of the fruit on the
    -- sorting table is about the pick and about no particular reading, and there
    -- is nothing for the check to compare. Everything it does compare is `not
    -- null` on both sides by column definition, so `<>` cannot go null and
    -- quietly permit. Exercised both ways in the attachment block below: a
    -- photograph naming no event is kept and does not clear a weighing, and one
    -- naming an event about another subject is refused.
    'attachment_event_matches_subject',
    -- 0062's pair are the same two shapes one table over, and they are listed
    -- separately rather than waved at, because "it is like the other one" is how
    -- a difference gets missed. `note_event_matches_subject` opens with the same
    -- deliberate null permit: a note about no particular event has nothing to
    -- compare, and everything it does compare is `not null` by column
    -- definition. `note_is_not_refiled` guards the two nullable columns with
    -- `is distinct from` so that attaching an event to a note that had none is a
    -- refusal rather than a comparison evaluating to null. Both exercised in the
    -- note block below, in both directions.
    'note_event_matches_subject',
    'note_is_not_refiled',
    -- 0064's two, and the first is A25's shape used deliberately a third time.
    -- `note_value_matches_its_kind` returns early when `kind_id` is null, which
    -- is the untyped floor: nothing is required of an untyped note and that is
    -- the point of it. Everything after that branch reads the kind's declared
    -- shape and refuses on a mismatch, so a null there cannot permit. Exercised
    -- in the typing block below in both directions: an untyped note is allowed
    -- to stay untyped, and a typed one with no value is refused.
    'note_value_matches_its_kind',
    -- `note_provenance_is_not_self_granted` guards a not-null enum, so there is
    -- no null to permit. `current_setting(..., true)` is coalesced rather than
    -- compared, because an unset setting returns null and a null comparison
    -- would let every update through, which is precisely the failure. Exercised
    -- below by a fact refused at birth, an update refused, and confirm_note
    -- succeeding.
    'note_provenance_is_not_self_granted',
    -- `attachment_is_not_rewritten` is the case where the null was designed
    -- against. `about_event` and `by_user` are the two nullable columns it
    -- guards, and both are compared with `is distinct from` rather than `<>`
    -- exactly so that attaching an event to a photograph that had none, or
    -- clearing one, is a refusal rather than a comparison that evaluates to null
    -- and falls through. The rest are `not null` columns. Exercised below by the
    -- refused refile and by the caption that is allowed through.
    'attachment_is_not_rewritten',
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
  exception when foreign_key_violation or restrict_violation then
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
  exception when foreign_key_violation or restrict_violation then
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
  -- Six until 0045 registered press_cut and press_program, both winemaking: how
  -- a press was divided and what it was run on are not things core could have an
  -- opinion about.
  -- Nine since 0071 registered wine_colour, which is winemaking by the same
  -- argument press_cut is: whether a wine is red is a fact about wine, and core
  -- has no opinion about what oak does.
  if (select count(*) from term_kind where module <> 'core') <> 9 then
    raise exception 'FAIL: % of the kinds are owned by a module other than core, and the claim is nine',
      (select count(*) from term_kind where module <> 'core');
  end if;
  perform test_ok('the registry says which module owns each kind, and nine of them are not core''s');
end $$;

-- A term cannot name a kind nobody registered, and adding a kind is a row.
do $$
begin
  begin
    insert into term (kind, value, label, sort_order)
      values ('not_a_kind', 'x', 'X', 1);
    raise exception 'FAIL: a term was created under an unregistered kind';
  exception when foreign_key_violation or restrict_violation then
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
insert into node (id, stage, status, name, owner_id, created_by, vintage)
values ('00000000-0000-0000-0000-00000000780e', 'bin', 'open', 'W7 bin',
        '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-00000000a001', 2026);

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
insert into node (id, stage, status, name, owner_id, created_by, hidden, vintage)
values ('00000000-0000-0000-0000-00000000780f', 'maturation', 'open', 'W7 client lot',
        '00000000-0000-0000-0000-00000000f002', '00000000-0000-0000-0000-00000000a001',
        array['composition','history'], 2026);
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

  insert into node (id, stage, status, name, owner_id, created_by, vintage)
  values ('00000000-0000-0000-0000-000000009101', 'bin', 'open', 'E10 bin',
          '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-00000000a001', 2026),
         ('00000000-0000-0000-0000-000000009102', 'maturation', 'open', 'E10 facility lot',
          '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-00000000a001', 2026),
         ('00000000-0000-0000-0000-000000009103', 'maturation', 'open', 'E10 client lot',
          '00000000-0000-0000-0000-00000000f002', '00000000-0000-0000-0000-00000000a001', 2026);

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
  -- Three until 0044, which added location_id. That is a policy change rather
  -- than a refactor and it is the reason this assertion is pinned: moving a
  -- vessel is what a cellar hand does all day, `move_vessel` has been an
  -- operation since 0004, and until 0044 nothing could perform it because the
  -- allow-list did not include where a vessel is.
  if not (got @> array['has_glycol','setpoint_c','mode','location_id']
          and array_length(got,1) = 4) then
    raise exception 'FAIL: a cellar hand may write %, and the trigger says four', got;
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
  exception when foreign_key_violation or restrict_violation then
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
  insert into node (id, stage, status, name, variety_id, owner_id, created_by, vintage)
  values ('00000000-0000-0000-0000-00000000b0e6', 'maturation', 'open', 'AR-E6 lot',
          term_id('variety', 'pinot_noir'),
          '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-00000000a001', 2026);

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
      -- One unnamed cut. 0045 replaced the destination list with cuts, and a
      -- press with nothing to say about fractions is exactly this.
      jsonb_build_array(jsonb_build_object('destinations',
        jsonb_build_array(jsonb_build_object('vessel_id', tank_id, 'volume_l', 500)))));
    raise exception 'FAIL: unweighed fruit went through the press and its weight is gone for good';
  exception when others then
    if position('never been weighed' in sqlerrm) = 0 then raise; end if;
    perform test_ok('pressing fruit nobody weighed is refused, because the press is the last moment anybody could');
  end;

  perform weigh_bins(pick_id, array[bin_a, bin_b]::uuid[], 2120);

  out_js := press(
    jsonb_build_array(jsonb_build_object('node_id', pick_id)),
    jsonb_build_array(jsonb_build_object('name', 'Assert pressed', 'destinations',
      jsonb_build_array(jsonb_build_object('vessel_id', tank_id, 'volume_l', 1200)))));

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
  exception when foreign_key_violation or restrict_violation then
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
                       'weighing_without_photo', 'measurement_to_propagate',
                       'processing_plan', 'supply_on_hand', 'supply_below_level')
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

  insert into node (id, stage, status, name, created_by, vintage)
  values ('00000000-0000-0000-0000-00000000da11', 'maturation', 'open', 'Assert day lot',
          '00000000-0000-0000-0000-00000000a001', 2026);

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

  -- 0047 gave the photograph a real foreign key onto the event it is evidence
  -- of, and refuses a delete that would leave it pointing at nothing. Nothing in
  -- the cellar ever deletes an event; this fixture does, so it tidies in order.
  delete from attachment where subject_type = 'node' and subject_id = pick_id;
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
  insert into node (id, stage, status, name, created_by, vintage)
  values (lot_id, 'maturation', 'open', 'Assert paper lot',
          '00000000-0000-0000-0000-00000000a001', 2026);

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
do $$ begin raise notice '--- picking stops, and the fruit goes somewhere'; end $$;

-- 0044. Finishing is not closing, a plan is not an event, and where fruit goes
-- when it leaves depends on whether it is coming back.
do $$
declare
  pick_id uuid := '00000000-0000-0000-0000-00000000fc01';
  cold    uuid := '00000000-0000-0000-0000-00000000fc02';
  bins    uuid[];
  rest    uuid[];
  out_js  jsonb;
  n       int;
begin
  update term set attributes = attributes || '{"tare_lbs": 60}'::jsonb
   where kind = 'vessel_type' and value = 'picking_bin';
  insert into location (id, name) values (cold, 'Assert cold store');

  perform add_bins_to_pick(
    jsonb_build_object('id', pick_id, 'variety_id', term_id('variety', 'riesling'),
                       'vintage', 2026),
    null, 3, term_id('vessel_type', 'picking_bin'), 'ASRTFIN', 100);

  -- Two of the three weighed, so finishing has something to be loud about.
  select array_agg(vessel_id) into bins from (
    select vessel_id from unweighed_bin where node_id = pick_id order by bin_name limit 2
  ) x;
  perform weigh_bins(pick_id, bins, 4120);

  out_js := finish_pick(pick_id);

  if (out_js ->> 'net_lbs')::numeric <> 4000 then
    raise exception 'FAIL: a finished pick reports % lbs and 4000 were weighed', out_js ->> 'net_lbs';
  end if;
  if (out_js ->> 'tons')::numeric <> 2.000 then
    raise exception 'FAIL: 4000 lbs came to % tons', out_js ->> 'tons';
  end if;
  perform test_ok('finishing a pick reports what it weighed, in the unit somebody says out loud');

  -- Reported, never refused. A pick finished with bins nobody weighed is a real
  -- end to a long day, and refusing would push somebody into not finishing it,
  -- which loses the signal entirely.
  if (out_js ->> 'unweighed')::int <> 1 then
    raise exception
      'FAIL: a pick finished with one unweighed bin reports %, and saying so is the whole point',
      out_js ->> 'unweighed';
  end if;
  select count(*) into n from node where id = pick_id and status = 'closed';
  if n <> 0 then
    raise exception 'FAIL: finishing a pick closed it, and its fruit has not gone anywhere yet';
  end if;
  perform test_ok('finishing says what is still unweighed rather than refusing, and does not close the pick');

  -- Asked for directly: "make sure that the pick total, if not all of the bins
  -- are weighed, is updated once the bins are weighed." It holds because
  -- `weigh_bins` recomputes the total from the live weighing events rather than
  -- adding to a running figure, so a bin weighed after the pick was finished
  -- lands in the total and finishing is not a freeze.
  -- A separate variable. Reusing `bins` here reassigned it to the one remaining
  -- bin and the move test below then moved one bin and expected two, which is a
  -- test failing for its own reasons rather than the code's.
  select array_agg(vessel_id) into rest from unweighed_bin where node_id = pick_id;
  perform weigh_bins(pick_id, rest, 2060);

  select quantity into n from node where id = pick_id;
  if n <> 6000 then
    raise exception
      'FAIL: weighing the last bin after the pick was finished left the total at % rather than 6000', n;
  end if;
  select count(*) into n from unweighed_bin where node_id = pick_id;
  if n <> 0 then
    raise exception 'FAIL: a bin weighed after finishing is still listed as unweighed';
  end if;
  select count(*) into n from node
   where id = pick_id and attributes ? 'picking_finished_at';
  if n <> 1 then
    raise exception 'FAIL: weighing a bin after finishing unfinished the pick';
  end if;
  perform test_ok('a bin weighed after the pick was finished raises the total, and finishing is not a freeze');

  -- Cold storage is a location, so going cold is a move, and the event is what
  -- answers how long fruit sat rather than only where it is now.
  perform move_vessels(bins, cold);
  select count(*) into n from vessel where id = any(bins) and location_id = cold;
  if n <> 2 then
    raise exception 'FAIL: % of 2 bins reached the cold store', n;
  end if;
  select count(*) into n from event
   where subject_type = 'vessel' and subject_id = any(bins)
     and operation_id = term_id('operation', 'move_vessel');
  if n <> 2 then
    raise exception 'FAIL: % move events were written for 2 bins, and when it moved is the useful half', n;
  end if;
  perform test_ok('moving bins records where they went and when, which is what answers how long fruit sat');

  begin
    perform move_vessels(bins, '00000000-0000-0000-0000-0000000000ff');
    raise exception 'FAIL: bins were moved to a location that does not exist';
  exception when others then
    if position('no such location' in sqlerrm) = 0 then raise; end if;
    perform test_ok('moving bins somewhere that does not exist is refused');
  end;

  -- A plan is tasks, because a plan is changeable and an observation is not.
  perform plan_processing(bins, term_id('operation', 'press'), date '2026-09-17', 'whole cluster');
  select count(*) into n from task
   where subject_type = 'vessel' and subject_id = any(bins)
     and operation_id = term_id('operation', 'press');
  if n <> 2 then
    raise exception 'FAIL: planning two bins made % tasks', n;
  end if;
  -- Qualified, because `bins` is also a column on the view and a plpgsql
  -- variable of the same name is ambiguous rather than shadowing.
  select pp.bins into n from processing_plan pp where pp.planned_for = date '2026-09-17';
  if n <> 2 then
    raise exception 'FAIL: the plan for that day covers % bins', n;
  end if;
  perform test_ok('a plan is a set of tasks sharing a day and an operation, grouped by asking rather than stored');

  -- Changing it is allowed, which is the difference between a plan and a record.
  update task set due_from = date '2026-09-18', due_to = date '2026-09-19'
   where subject_id = any(bins) and operation_id = term_id('operation', 'press');
  select count(*) into n from processing_plan pp where pp.planned_for = date '2026-09-17';
  if n <> 0 then
    raise exception 'FAIL: a plan moved to another day is still showing on the old one';
  end if;
  perform test_ok('a plan can be moved, because an intention is not an observation');

  delete from task where subject_id = any(bins);
end $$;

-- Where fruit goes when it leaves depends on whether it is coming back, which is
-- the winemaker's answer: sold fruit stops being this winery's problem and fruit
-- sent out to be made is still its wine.
do $$
declare
  sold_id uuid := '00000000-0000-0000-0000-00000000fc11';
  out_id  uuid := '00000000-0000-0000-0000-00000000fc12';
  n       int;
begin
  insert into node (id, stage, status, name, quantity, unit, created_by, vintage) values
    (sold_id, 'bin', 'open', 'Assert sold pick', 1200, 'lbs',
     '00000000-0000-0000-0000-00000000a001', 2026),
    (out_id,  'bin', 'open', 'Assert away pick', 900, 'lbs',
     '00000000-0000-0000-0000-00000000a001', 2026);

  perform send_fruit_away(sold_id, 'Another Winery', false);
  select count(*) into n from node where id = sold_id and status = 'closed';
  if n <> 1 then
    raise exception 'FAIL: fruit that was sold left and the pick is still open';
  end if;
  -- The weight stays on the row. It is the thing anybody would later be asked
  -- about, and zeroing it to make the row look empty would throw it away.
  select count(*) into n from node where id = sold_id and quantity = 1200;
  if n <> 1 then
    raise exception 'FAIL: the weight that left is no longer recorded anywhere';
  end if;
  perform test_ok('sold fruit closes the pick and the weight that left stays on it');

  perform send_fruit_away(out_id, 'Another Winery', true);
  select count(*) into n from node where id = out_id and status = 'open';
  if n <> 1 then
    raise exception 'FAIL: fruit sent out to be made and coming back closed the pick, and it is still this winery''s wine';
  end if;
  perform test_ok('fruit sent out to be made and returning leaves the pick open, which is true rather than tidy');

  begin
    perform send_fruit_away(out_id, '   ', true);
    raise exception 'FAIL: fruit left to nowhere';
  exception when others then
    if position('does not leave to nowhere' in sqlerrm) = 0 then raise; end if;
    perform test_ok('fruit does not leave to nowhere, so a destination is required');
  end;

  delete from event where subject_type = 'node' and subject_id in (sold_id, out_id);
  delete from node where id in (sold_id, out_id);
end $$;

-- The allow-list change, asserted because it is a policy decision rather than a
-- refactor: a cellar hand may move a vessel, which `move_vessel` has implied
-- since 0004 and nothing could perform.
do $$
declare allowed text;
begin
  select pg_get_triggerdef(oid) into allowed
    from pg_trigger where tgname = 'vessel_cellar_columns';
  if position('location_id' in allowed) = 0 then
    raise exception
      'FAIL: a cellar user still may not move a vessel, so putting bins in the cold room is an administrator''s job';
  end if;
  if position('setpoint_c' in allowed) = 0 then
    raise exception 'FAIL: the jacket columns were dropped from the cellar allow-list';
  end if;
  perform test_ok('a cellar hand may move a vessel and still may not change what it is');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the cuts a press was divided into'; end $$;

-- 0045, and the discharge of S-52. The resolution was not to change the
-- arithmetic: proportional by fruit weight is correct, because a hard press is
-- made of the same fruit as the free run and in the same ratios. What was
-- missing is that the cut is a fact about the lot.
do $$
declare
  pick_id uuid := '00000000-0000-0000-0000-00000000cd01';
  tank_a  uuid := '00000000-0000-0000-0000-00000000cd02';
  tank_b  uuid := '00000000-0000-0000-0000-00000000cd03';
  out_js  jsonb;
  n       int;
  shares  int;
begin
  update term set attributes = attributes || '{"tare_lbs": 60}'::jsonb
   where kind = 'vessel_type' and value = 'picking_bin';
  insert into vessel (id, type_id, name, capacity_l) values
    (tank_a, term_id('vessel_type', 'tank'), 'Assert cut tank A', 900),
    (tank_b, term_id('vessel_type', 'tank'), 'Assert cut tank B', 400);

  -- No program is seeded by the migration, on purpose: they belong to a
  -- particular press. So the fixture brings its own.
  insert into term (kind, value, label)
  values ('press_program', 'assert_program', 'Assert program');

  perform add_bins_to_pick(
    jsonb_build_object('id', pick_id, 'variety_id', term_id('variety', 'pinot_gris'),
                       'vintage', 2026),
    null, 2, term_id('vessel_type', 'picking_bin'), 'ASRTCUT', 100);
  perform weigh_bins(pick_id,
    array(select vessel_id from unweighed_bin where node_id = pick_id), 2120);

  out_js := press(
    jsonb_build_array(jsonb_build_object('node_id', pick_id)),
    jsonb_build_array(
      jsonb_build_object('cut_id', term_id('press_cut', 'free_run'),
        'destinations', jsonb_build_array(
          jsonb_build_object('vessel_id', tank_a, 'volume_l', 800))),
      jsonb_build_object('cut_id', term_id('press_cut', 'hard_press'),
        'destinations', jsonb_build_array(
          jsonb_build_object('vessel_id', tank_b, 'volume_l', 300)))),
    '{}'::jsonb,
    jsonb_build_object(
      'program_id', (select id from term
                      where kind = 'press_program' and value = 'assert_program'),
      'whole_cluster_pct', 100,
      'skin_contact_start', (timestamptz '2026-09-14 06:00+00')::text,
      'skin_contact_end',   (timestamptz '2026-09-14 10:00+00')::text,
      'pressed_from',       (timestamptz '2026-09-14 10:00+00')::text,
      'pressed_to',         (timestamptz '2026-09-14 10:45+00')::text));

  if jsonb_array_length(out_js -> 'cuts') <> 2 then
    raise exception 'FAIL: a press into two cuts made % lots', jsonb_array_length(out_js -> 'cuts');
  end if;
  perform test_ok('a press into two cuts makes two lots, one for each');

  select count(*) into n from node
   where id::text = any(array(select jsonb_array_elements_text(out_js -> 'cuts')))
     and attributes ->> 'cut_label' in ('Free run', 'Hard press');
  if n <> 2 then
    raise exception 'FAIL: % of 2 cuts say which cut they are', n;
  end if;
  perform test_ok('each cut carries its own name, which is the fact S-52 had nowhere to put');

  -- The arithmetic S-52 said was sound and stays sound. Every cut of one press
  -- draws the same share from the same parent.
  select count(distinct fraction) into shares from lineage
   where child_id::text = any(array(select jsonb_array_elements_text(out_js -> 'cuts')));
  if shares <> 1 then
    raise exception
      'FAIL: the cuts of one press claim % different shares of the same fruit, and they are made of the same fruit', shares;
  end if;
  perform test_ok('every cut of one press draws the same share of the same fruit, which is what makes the cut a name rather than a composition');

  -- Named in spec.md since the scaffold and written by nothing until 0045.
  select count(*) into n from node
   where id::text = any(array(select jsonb_array_elements_text(out_js -> 'cuts')))
     and (attributes ->> 'whole_cluster_pct')::numeric = 100;
  if n <> 2 then
    raise exception 'FAIL: % of 2 cuts record how much went in whole', n;
  end if;
  perform test_ok('whole cluster is recorded on the lot, which spec.md named and nothing wrote until now');

  -- Two timestamps, not three. The total is a subtraction and storing it would
  -- invite it to disagree with its own inputs.
  select (data ->> 'skin_contact_minutes')::int into n from event
   where id = (out_js ->> 'event_id')::uuid;
  if n <> 240 then
    raise exception 'FAIL: four hours of skin contact came to % minutes', n;
  end if;
  perform test_ok('skin contact is two timestamps and the total is derived from them');

  -- The other duration, and a different fact. A press that ran forty minutes
  -- against skins that were on for four hours is ordinary, and a record that
  -- conflated them would answer neither question.
  select (data ->> 'press_minutes')::int into n from event
   where id = (out_js ->> 'event_id')::uuid;
  if n <> 45 then
    raise exception 'FAIL: a forty five minute press run came to % minutes', n;
  end if;
  select count(*) into n from event
   where id = (out_js ->> 'event_id')::uuid
     and data ->> 'program_label' = 'Assert program';
  if n <> 1 then
    raise exception 'FAIL: the press does not record which program it was run on';
  end if;
  perform test_ok('how long the press ran is recorded apart from how long the skins were on, and the program is named');

  delete from lineage where child_id::text = any(array(select jsonb_array_elements_text(out_js -> 'cuts')));
  delete from event where id = (out_js ->> 'event_id')::uuid;
  delete from placement where node_id::text = any(array(select jsonb_array_elements_text(out_js -> 'cuts')));
  delete from node where id::text = any(array(select jsonb_array_elements_text(out_js -> 'cuts')));
  delete from placement where node_id = pick_id;
  delete from event where subject_type = 'node' and subject_id = pick_id;
  delete from node where id = pick_id;
  delete from vessel where id in (tank_a, tank_b) or name like 'ASRTCUT%';
  delete from term where kind = 'press_program' and value = 'assert_program';
  update term set attributes = attributes - 'tare_lbs'
   where kind = 'vessel_type' and value = 'picking_bin';
end $$;

-- The refusals that keep the detail honest.
do $$
declare
  lot_id uuid := '00000000-0000-0000-0000-00000000cd11';
  tank   uuid := '00000000-0000-0000-0000-00000000cd12';
begin
  insert into vessel (id, type_id, name, capacity_l)
  values (tank, term_id('vessel_type', 'tank'), 'Assert detail tank', 900);
  insert into node (id, stage, status, name, quantity, unit, created_by, vintage)
  values (lot_id, 'bin', 'open', 'Assert detail pick', 1000, 'lbs',
          '00000000-0000-0000-0000-00000000a001', 2026);

  begin
    perform press(
      jsonb_build_array(jsonb_build_object('node_id', lot_id)),
      jsonb_build_array(jsonb_build_object('destinations', jsonb_build_array(
        jsonb_build_object('vessel_id', tank, 'volume_l', 500)))),
      '{}'::jsonb,
      jsonb_build_object(
        'skin_contact_start', (timestamptz '2026-09-14 10:00+00')::text,
        'skin_contact_end',   (timestamptz '2026-09-14 06:00+00')::text));
    raise exception 'FAIL: skins came off before they went on';
  exception when others then
    if position('ended before it started' in sqlerrm) = 0 then raise; end if;
    perform test_ok('skin contact that ended before it started is refused, rather than stored as a negative');
  end;

  begin
    perform press(
      jsonb_build_array(jsonb_build_object('node_id', lot_id)),
      jsonb_build_array(jsonb_build_object('destinations', jsonb_build_array(
        jsonb_build_object('vessel_id', tank, 'volume_l', 500)))),
      '{}'::jsonb,
      jsonb_build_object('whole_cluster_pct', 140));
    raise exception 'FAIL: 140 percent of the fruit went in whole';
  exception when others then
    if position('is not a proportion' in sqlerrm) = 0 then raise; end if;
    perform test_ok('whole cluster outside nought to a hundred is refused');
  end;

  begin
    perform press(
      jsonb_build_array(jsonb_build_object('node_id', lot_id)),
      jsonb_build_array(jsonb_build_object('cut_id', term_id('variety', 'riesling'),
        'destinations', jsonb_build_array(
          jsonb_build_object('vessel_id', tank, 'volume_l', 500)))),
      '{}'::jsonb, '{}'::jsonb);
    raise exception 'FAIL: a press cut was a grape variety';
  exception when others then
    if position('not a press cut' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a cut names the press cut vocabulary and nothing else');
  end;

  begin
    perform press(
      jsonb_build_array(jsonb_build_object('node_id', lot_id)),
      jsonb_build_array(jsonb_build_object('destinations', jsonb_build_array(
        jsonb_build_object('vessel_id', tank, 'volume_l', 500)))),
      '{}'::jsonb,
      jsonb_build_object('program_id', term_id('variety', 'riesling')));
    raise exception 'FAIL: a press program was a grape variety';
  exception when others then
    if position('not a press program' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a press program names the press program vocabulary and nothing else');
  end;

  begin
    perform press(
      jsonb_build_array(jsonb_build_object('node_id', lot_id)),
      jsonb_build_array(jsonb_build_object('destinations', jsonb_build_array(
        jsonb_build_object('vessel_id', tank, 'volume_l', 500)))),
      '{}'::jsonb,
      jsonb_build_object(
        'pressed_from', (timestamptz '2026-09-14 12:00+00')::text,
        'pressed_to',   (timestamptz '2026-09-14 11:00+00')::text));
    raise exception 'FAIL: the press finished before it started';
  exception when others then
    if position('finished before it started' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a press that finished before it started is refused, rather than stored as a negative');
  end;

  -- A press with nothing to say about cuts is one cut with no name, which is
  -- what this function did before 0045. One shape, not two.
  perform press(
    jsonb_build_array(jsonb_build_object('node_id', lot_id)),
    jsonb_build_array(jsonb_build_object('destinations', jsonb_build_array(
      jsonb_build_object('vessel_id', tank, 'volume_l', 500)))),
    '{}'::jsonb, '{}'::jsonb);
  perform test_ok('a press that says nothing about cuts is one unnamed cut, which is what it always was');

  delete from lineage where parent_id = lot_id;
  -- Unqualified, which it has always been: this block clears every node event
  -- so that what follows starts from a known floor. Since 0047 a photograph
  -- holds a restrict onto the reading it is evidence of, so the photographs go
  -- first. Found by the winemaker attaching three real ones from his phone
  -- while this was being written, which is the best way to find it.
  delete from attachment a using event e
   where a.about_event = e.id and e.subject_type = 'node';
  delete from event where subject_type = 'node';
  delete from placement where vessel_id = tank;
  delete from node where id = lot_id or name like 'Assert detail%';
  delete from vessel where id = tank;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- what is on the shelf, and what to buy'; end $$;

-- 0046. On hand is derived from what came in and went out since the last count,
-- which is the winemaker's shape: "derived from what came in and went out with
-- reconciliation".
do $$
declare
  dap  uuid := '00000000-0000-0000-0000-00000000ba01';
  kmbs uuid := '00000000-0000-0000-0000-00000000ba02';
  out_js jsonb;
  n    numeric;
begin
  insert into supply (id, name, unit, reorder_level) values
    (dap,  'Assert DAP',  'g', 500),
    (kmbs, 'Assert KMBS', 'g', 1000);

  insert into supply_movement (supply_id, kind, quantity, by_user) values
    (dap, 'received', 2000, '00000000-0000-0000-0000-00000000a001'),
    (dap, 'used',      300, '00000000-0000-0000-0000-00000000a001'),
    (dap, 'used',      300, '00000000-0000-0000-0000-00000000a001');

  select on_hand into n from supply_on_hand where supply_id = dap;
  if n <> 1400 then
    raise exception 'FAIL: two kilos in and six hundred out leaves % grams', n;
  end if;
  perform test_ok('what is on the shelf is what came in less what went out, asked rather than stored');

  -- The gap is the point. A count that quietly wrote a correcting movement
  -- would destroy the one number that says whether any of this is believable.
  out_js := count_supply(dap, 1200, 'assertion count');
  if (out_js ->> 'expected')::numeric <> 1400 then
    raise exception 'FAIL: the count expected % where the movements said 1400', out_js ->> 'expected';
  end if;
  if (out_js ->> 'difference')::numeric <> -200 then
    raise exception 'FAIL: counting 1200 against 1400 gave a difference of %', out_js ->> 'difference';
  end if;
  perform test_ok('a count records what was found beside what was expected, so the gap is a measurement rather than a correction');

  select on_hand into n from supply_on_hand where supply_id = dap;
  if n <> 1200 then
    raise exception 'FAIL: after counting 1200 the shelf reads %', n;
  end if;
  perform test_ok('a count is the floor the running total starts again from');

  -- The reason `seq` exists. A transaction sees one `now()` for its whole
  -- length, so a use recorded in the same instant as a count would have been
  -- silently dropped from the total if this ordered by time. Counting a shelf
  -- and then recording the scoop you just took is the ordinary case.
  insert into supply_movement (supply_id, kind, quantity, by_user)
  values (dap, 'used', 300, '00000000-0000-0000-0000-00000000a001');
  select on_hand into n from supply_on_hand where supply_id = dap;
  if n <> 900 then
    raise exception
      'FAIL: a use recorded in the same instant as the count left the shelf at % rather than 900', n;
  end if;
  perform test_ok('a movement in the same instant as a count still lands after it, because the order is a sequence and not a clock');

  -- Broken is a quantity and a date, not a label on the thing. Two of six hose
  -- heads are broken, which a flag could not say, and it happened on a day,
  -- which a flag could not say either.
  insert into supply_movement (supply_id, kind, quantity, by_user)
  values (dap, 'broken', 200, '00000000-0000-0000-0000-00000000a001');
  select on_hand into n from supply_on_hand where supply_id = dap;
  if n <> 700 then
    raise exception 'FAIL: two hundred grams broken left % usable rather than 700', n;
  end if;
  select broken into n from supply_on_hand where supply_id = dap;
  if n <> 200 then
    raise exception 'FAIL: % is reported broken where 200 was', n;
  end if;
  perform test_ok('broken stock comes off what is usable and is still counted, because four good and two broken is not four');

  insert into supply_movement (supply_id, kind, quantity, by_user)
  values (dap, 'repaired', 200, '00000000-0000-0000-0000-00000000a001');
  select broken into n from supply_on_hand where supply_id = dap;
  if n <> 0 then
    raise exception 'FAIL: repairing left % broken', n;
  end if;
  select on_hand into n from supply_on_hand where supply_id = dap;
  if n <> 900 then
    raise exception 'FAIL: repairing left % usable rather than 900', n;
  end if;
  perform test_ok('repairing puts it back, so breaking something is not a one way door');

  -- Flags rather than a category, which is the hose head argument: the thing
  -- nobody anticipated is exactly the thing a single category gets wrong.
  insert into supply_material_kind (supply_id, kind_id)
  select dap, id from term
   where kind = 'material_kind' and value in ('addition', 'consumable');
  select array_length(kinds, 1) into n from supply_on_hand where supply_id = dap;
  if n <> 2 then
    raise exception 'FAIL: a supply flagged as two sorts of thing reports %', n;
  end if;
  perform test_ok('a supply carries several sorts at once, so the thing that is neither one nor the other can say so');

  begin
    insert into supply_material_kind (supply_id, kind_id)
    values (dap, term_id('variety', 'riesling'));
    raise exception 'FAIL: a supply was flagged as a grape variety';
  exception when foreign_key_violation or restrict_violation then
    perform test_ok('a sort of supply names the material vocabulary and nothing else');
  end;

  delete from supply_material_kind where supply_id = dap;

  -- A suggestion, not the list.
  select count(*) into n from supply_below_level where supply_id = kmbs;
  if n <> 1 then
    raise exception 'FAIL: a supply at zero against a level of 1000 is not being suggested';
  end if;
  select count(*) into n from supply_below_level where supply_id = dap;
  if n <> 0 then
    raise exception 'FAIL: a supply above its level is being suggested';
  end if;
  perform test_ok('a supply under the level somebody set is suggested, and one above it is not');

  -- A prompt that keeps prompting what somebody has acted on is noise.
  insert into shopping_item (supply_id, what, added_by)
  values (kmbs, 'Assert KMBS', '00000000-0000-0000-0000-00000000a001');
  select count(*) into n from supply_below_level where supply_id = kmbs;
  if n <> 0 then
    raise exception 'FAIL: something already on the shopping list is still being suggested';
  end if;
  perform test_ok('a supply already on the list stops being suggested, so a prompt does not become noise');

  -- A level nobody set is not a reason to buy anything, and is not zero.
  update supply set reorder_level = null where id = kmbs;
  delete from shopping_item where supply_id = kmbs;
  select count(*) into n from supply_below_level where supply_id = kmbs;
  if n <> 0 then
    raise exception 'FAIL: a supply with no level set is being suggested, and nobody said what low means for it';
  end if;
  perform test_ok('a supply nobody set a level for is never suggested, because no level is not a level of zero');

  delete from shopping_item where supply_id in (dap, kmbs);
  delete from supply_movement where supply_id in (dap, kmbs);
  delete from supply where id in (dap, kmbs);
end $$;

-- The refusals, and who may do what.
do $$
declare dap uuid := '00000000-0000-0000-0000-00000000ba11'; seen int;
begin
  insert into supply (id, name, unit) values (dap, 'Assert refusal supply', 'g');

  begin
    perform count_supply(dap, -5);
    raise exception 'FAIL: a shelf was counted at minus five';
  exception when others then
    if position('is not an amount on a shelf' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a negative count is refused, because a shelf does not hold less than nothing');
  end;

  begin
    insert into supply_movement (supply_id, kind, quantity, by_user)
    values (dap, 'borrowed', 10, '00000000-0000-0000-0000-00000000a001');
    raise exception 'FAIL: a movement of an unknown kind was accepted';
  exception when check_violation then
    perform test_ok('a movement is received, used, discarded or counted, and nothing else');
  end;

  -- Only a count has something to have expected, so the column cannot be used
  -- to smuggle an expectation onto a delivery.
  begin
    insert into supply_movement (supply_id, kind, quantity, expected, by_user)
    values (dap, 'received', 10, 5, '00000000-0000-0000-0000-00000000a001');
    raise exception 'FAIL: a delivery carried an expectation';
  exception when check_violation then
    perform test_ok('only a count records what was expected, so the reconciliation cannot be faked onto a delivery');
  end;

  -- The stores are the facility's business and none of a client's.
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select count(*) into seen from supply;
  reset role;
  if seen <> 0 then
    raise exception 'FAIL: a client can read % of this winery''s supplies', seen;
  end if;
  perform test_ok('a client reads none of the winery''s stores');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  delete from supply where id = dap;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a photograph of anything, attached whenever somebody gets to it'; end $$;

-- 0047. The winemaker weighed three loads, photographed the scale three times,
-- and had nowhere to put the photographs. Attaching one later has to count for
-- exactly as much as attaching one at the scale, or the list of unphotographed
-- weighings never empties and stops being read.
do $$
declare
  pick_id uuid := '00000000-0000-0000-0000-00000000ca01';
  ev_at   uuid;
  ev_late uuid;
  out_js  jsonb;
  n       int;
  who     uuid;
begin
  update term set attributes = attributes || '{"tare_lbs": 50}'::jsonb
   where kind = 'vessel_type' and value = 'picking_bin';

  perform add_bins_to_pick(
    jsonb_build_object('id', pick_id, 'variety_id', term_id('variety', 'riesling'),
                       'vintage', 2026),
    null, 2, term_id('vessel_type', 'picking_bin'), 'ASRTATTACH', 100);

  -- One weighing photographed at the scale, one not. The first is the path that
  -- already worked; the second is the one he actually had.
  out_js := weigh_bins(pick_id,
    array(select vessel_id from unweighed_bin where node_id = pick_id limit 1),
    400, null, null, 'weighing/at-the-scale.jpg');
  ev_at := (out_js ->> 'event_id')::uuid;

  out_js := weigh_bins(pick_id,
    array(select vessel_id from unweighed_bin where node_id = pick_id),
    300);
  ev_late := (out_js ->> 'event_id')::uuid;

  -- A path handed to `weigh_bins` has to become an attachment, or the answer to
  -- "is there a photograph of this" lives in two places and they disagree.
  select count(*) into n from attachment where about_event = ev_at;
  if n <> 1 then
    raise exception 'FAIL: a weighing photographed at the scale produced % attachments', n;
  end if;
  perform test_ok('a photograph taken at the scale is filed the same way as one attached afterwards, so one question has one answer');

  select count(*) into n from weighing_without_photo where event_id = ev_late;
  if n <> 1 then
    raise exception 'FAIL: the unphotographed weighing is not listed as one';
  end if;

  -- The whole point. Before this, a photograph attached in the evening left the
  -- weighing on the list of weighings nobody photographed.
  perform attach_photo('node', pick_id, 'weighing/from-my-camera-roll.jpg',
                       'the second load', ev_late, now() - interval '9 hours');
  select count(*) into n from weighing_without_photo where event_id = ev_late;
  if n <> 0 then
    raise exception 'FAIL: a weighing photographed after the fact is still listed as unphotographed';
  end if;
  perform test_ok('a photograph attached hours later clears the weighing it names, because later is when photographs actually get attached');

  -- Taken this morning, attached tonight. Throwing the stated time away would
  -- lose the only fact the file itself carried.
  select count(*) into n from attachment
   where path = 'weighing/from-my-camera-roll.jpg' and at < created_at;
  if n <> 1 then
    raise exception 'FAIL: a photograph taken this morning and attached tonight records one time, not two';
  end if;
  perform test_ok('when a photograph was taken and when it arrived are kept apart, because during harvest they are hours apart');

  -- A picture of the fruit is about the pick and about no reading. Letting it
  -- clear one would be a claim nobody made.
  perform attach_photo('node', pick_id, 'fruit/sorting-table.jpg');
  select count(*) into n from weighing_without_photo where node_id = pick_id;
  if n <> 0 then
    raise exception 'FAIL: % weighing(s) unaccounted for, and both were photographed', n;
  end if;
  perform attach_photo('node', pick_id, 'fruit/second-load.jpg');
  perform test_ok('a photograph of the pick that names no reading is kept without pretending to be evidence of one');

  -- The person holding the phone, not whoever is named. T0-3.
  select by_user into who from attachment where path = 'fruit/sorting-table.jpg';
  if who <> '00000000-0000-0000-0000-00000000a001' then
    raise exception 'FAIL: a photograph was filed under % rather than whoever attached it', who;
  end if;
  perform test_ok('a photograph carries whoever attached it, taken from the login rather than from an argument');

  -- A double tap with gloves on is not a second photograph, and must not read
  -- like a failure either. A13.
  out_js := attach_photo('node', pick_id, 'fruit/sorting-table.jpg');
  if (out_js ->> 'already')::boolean is not true then
    raise exception 'FAIL: attaching the same photograph twice did not say it was already there';
  end if;
  select count(*) into n from attachment
   where subject_type = 'node' and subject_id = pick_id and path = 'fruit/sorting-table.jpg';
  if n <> 1 then
    raise exception 'FAIL: the same photograph is attached % times', n;
  end if;
  perform test_ok('attaching the same photograph twice says so and changes nothing, rather than failing or duplicating');

  -- The morning's other request: a vessel holds more than one photograph, where
  -- before it held one path that the next one overwrote.
  perform attach_photo('vessel', '00000000-0000-0000-0000-0000000000c2', 'vessel/gauge.jpg');
  perform attach_photo('vessel', '00000000-0000-0000-0000-0000000000c2', 'vessel/valve.jpg');
  select count(*) into n from attachment
   where subject_type = 'vessel' and subject_id = '00000000-0000-0000-0000-0000000000c2';
  if n <> 2 then
    raise exception 'FAIL: a vessel holds % photographs and two were attached', n;
  end if;
  perform test_ok('a vessel holds as many photographs as somebody takes of it, where it used to hold the last one only');

  -- The refusals.
  begin
    perform attach_photo('barrel_rack', pick_id, 'anything.jpg');
    raise exception 'FAIL: a photograph was attached to a kind of thing that does not exist';
  exception when others then
    if position('nothing in this system is a' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a photograph of a kind of thing nothing in this system knows about is refused, rather than filed where nothing will find it');
  end;

  -- Evidence has to be evidence of the thing it is filed under. Otherwise a
  -- photograph can claim one pick's weighing while sitting in another's record,
  -- and both screens show it correctly.
  begin
    insert into attachment (subject_type, subject_id, path, about_event, by_user)
    values ('vessel', '00000000-0000-0000-0000-0000000000c2', 'mismatch.jpg', ev_at,
            '00000000-0000-0000-0000-00000000a001');
    raise exception 'FAIL: a photograph of a vessel claims to be evidence of a weighing of a pick';
  exception when others then
    if position('so one of the two is wrong' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a photograph that names an event must be filed under what that event was about');
  end;

  -- Append-only in the sense that matters: the label can be fixed, the evidence
  -- cannot be moved. T0-5.
  update attachment set caption = 'the sorting table, second load'
   where path = 'fruit/sorting-table.jpg';
  perform test_ok('a caption can be corrected by whoever wrote it, because a label is not evidence');

  begin
    update attachment set subject_id = '00000000-0000-0000-0000-00000000ca02'
     where path = 'fruit/sorting-table.jpg';
    raise exception 'FAIL: a photograph was refiled under a different subject';
  exception when others then
    if position('captioned but not moved' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a photograph cannot be moved to another subject or another event, because that is rewriting evidence rather than labelling it');
  end;

  -- 0048. The list somebody reads that evening, holding three photographs and
  -- no memory of which was which. `weigh_bins` answers the person who made the
  -- reading; this answers the person who comes back.
  select count(*) into n from pick_weighing where node_id = pick_id;
  if n <> 2 then
    raise exception 'FAIL: two weighings were made and the list shows %', n;
  end if;
  select count(*) into n from pick_weighing
   where node_id = pick_id and event_id = ev_at
     and gross_lbs = 400 and net_lbs = 350 and array_length(bins, 1) = 1;
  if n <> 1 then
    raise exception 'FAIL: a weighing reads back without the figures and bins that made it';
  end if;
  perform test_ok('a weighing reads back with the bins that were on the scale, because 747 identifies nothing and 747 on PB1 and PB2 identifies a photograph');

  select photos into n from pick_weighing where event_id = ev_late;
  if n <> 1 then
    raise exception 'FAIL: the reading photographed after the fact says it has % photographs', n;
  end if;
  perform test_ok('a reading says how many photographs name it, so the one already done is visible before another is taken');

  -- Which reading is live is the kernel's answer. A screen working it out from
  -- the events would be a client encoding a kernel rule, and the second client
  -- would encode it differently.
  perform weigh_bins(pick_id,
    array(select vessel_id::uuid from jsonb_array_elements_text(
            (select data -> 'bins' from event where id = ev_late)) as x(vessel_id)),
    320, 'misread the display', ev_late);
  select count(*) into n from pick_weighing where node_id = pick_id and superseded;
  if n <> 1 then
    raise exception 'FAIL: % of three readings are marked corrected, and exactly one was', n;
  end if;
  select count(*) into n from pick_weighing where node_id = pick_id;
  if n <> 3 then
    raise exception 'FAIL: a corrected reading was dropped from the list rather than marked';
  end if;
  perform test_ok('a corrected reading stays in the list and is marked rather than hidden, because it is part of the record of the day and its total is not');

  -- The weighing kept its own path too, and nothing reads it to decide whether
  -- a photograph exists. Both sources agreeing is the thing being checked.
  select count(*) into n from event e
   where e.id = ev_at and e.data ->> 'photo_path' = 'weighing/at-the-scale.jpg';
  if n <> 1 then
    raise exception 'FAIL: the weighing no longer carries the path it was given';
  end if;
  perform test_ok('the path the weighing was given stays in the weighing, because removing it would rewrite history for no gain');

  -- Removing evidence is a decision, not a stray tap.
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;
  delete from attachment where path = 'fruit/second-load.jpg';
  reset role;
  select count(*) into n from attachment where path = 'fruit/second-load.jpg';
  if n <> 1 then
    raise exception 'FAIL: a cellar user deleted a photograph';
  end if;
  perform test_ok('a cellar user cannot delete a photograph, because a photograph is evidence and deleting one should be somebody deciding to');

  -- The cellar's photographs are the cellar's business. S-65 says this is too
  -- narrow and that a client should see photographs of their own fruit; what it
  -- must never be is too wide.
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select count(*) into n from attachment;
  reset role;
  if n <> 0 then
    raise exception 'FAIL: a client can read % of this winery''s photographs', n;
  end if;
  perform test_ok('a client reads no photographs at all, which is too little and is filed as S-65, and is not too many');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  delete from attachment where subject_type = 'node' and subject_id = pick_id;
  delete from attachment where subject_type = 'vessel'
     and subject_id = '00000000-0000-0000-0000-0000000000c2';
  delete from event where subject_type = 'node' and subject_id = pick_id;
  delete from placement where node_id = pick_id;
  delete from node where id = pick_id;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- every lot says its vintage, including NV'; end $$;

-- 0049. The winemaker's rule: "They should always have a vintage, including NV."
-- So blank stops meaning three things at once, and the one it used to hide,
-- nobody got round to it, stops being writable at all.
do $$
declare
  v_a  uuid := '00000000-0000-0000-0000-00000000cb01';
  v_b  uuid := '00000000-0000-0000-0000-00000000cb02';
  v_c  uuid := '00000000-0000-0000-0000-00000000cb03';
  tank uuid;
  vrty uuid;
  n_a  uuid;
  n_b  uuid;
  child uuid;
  forked uuid;
  kept uuid;
  plan jsonb;
  out_js jsonb;
  n    int;
  frac numeric;
begin
  select id into tank from term where kind = 'vessel_type' and value = 'tank';
  select id into vrty from term where kind = 'variety' and value = 'riesling';

  -- The refusals first, on a bare insert, because the constraint is the
  -- guarantee and everything else is a convenience over it.
  begin
    insert into node (id, stage, name, vintage, non_vintage)
    values (gen_random_uuid(), 'maturation', 'Assert silent lot', null, false);
    raise exception 'FAIL: a lot was created saying neither a year nor NV';
  exception when check_violation then
    perform test_ok('a lot that says neither a year nor non-vintage is refused, which is the state that used to be indistinguishable from both');
  end;

  begin
    insert into node (id, stage, name, vintage, non_vintage)
    values (gen_random_uuid(), 'maturation', 'Assert both lot', 2024, true);
    raise exception 'FAIL: a lot was created claiming to be 2024 and non-vintage';
  exception when check_violation then
    perform test_ok('a lot cannot be both of a year and non-vintage, because that is a contradiction rather than a choice');
  end;

  -- Two lots of different years, so the blend has something to derive from.
  n_a := (create_vessel_with_wine(
    jsonb_build_object('id', v_a, 'name', 'ASRTNV A', 'type_id', tank, 'capacity_l', 1000),
    jsonb_build_object('name', 'ASRTNV 2024', 'vintage', 2024, 'variety_id', vrty,
                       'quantity', 600, 'unit', 'L'),
    600, '[]'::jsonb, false) ->> 'node_id')::uuid;
  n_b := (create_vessel_with_wine(
    jsonb_build_object('id', v_b, 'name', 'ASRTNV B', 'type_id', tank, 'capacity_l', 1000),
    jsonb_build_object('name', 'ASRTNV 2025', 'vintage', 2025, 'variety_id', vrty,
                       'quantity', 400, 'unit', 'L'),
    400, '[]'::jsonb, false) ->> 'node_id')::uuid;
  insert into vessel (id, name, type_id, capacity_l) values (v_c, 'ASRTNV C', tank, 2000);

  -- **The winemaker's second sentence: NV is derived when two vintages are
  -- blended, and the lineage and composition survive it.** Both halves are the
  -- assertion, because deriving the answer by throwing away what it was derived
  -- from would be worse than not deriving it.
  plan := rack(
    jsonb_build_array(
      jsonb_build_object('vessel_id', v_a, 'volume_l', 600),
      jsonb_build_object('vessel_id', v_b, 'volume_l', 400)),
    jsonb_build_array(jsonb_build_object('vessel_id', v_c, 'volume_l', 1000)),
    '{}'::jsonb, false,
    jsonb_build_object('name', 'ASRTNV blend'));
  child := (plan ->> 'node_id')::uuid;

  select count(*) into n from node
   where id = child and vintage is null and non_vintage;
  if n <> 1 then
    raise exception 'FAIL: blending 2024 with 2025 gave a lot of vintage %, not NV',
      coalesce((select vintage::text from node where id = child), 'null');
  end if;
  perform test_ok('blending two vintages derives a non-vintage lot, because a wine made of two years is what NV means');

  select count(*) into n from lineage where child_id = child;
  if n <> 2 then
    raise exception 'FAIL: the blend kept % lineage rows and was made of two lots', n;
  end if;
  select fraction into frac from lineage where child_id = child and parent_id = n_a;
  if frac is null or round(frac, 4) <> 0.6 then
    raise exception 'FAIL: 600 of 1000 litres came through as a fraction of %', frac;
  end if;
  select variety_id into kept from node where id = child;
  if kept is null then
    raise exception 'FAIL: the blend lost its variety along with its vintage';
  end if;
  perform test_ok('the blend keeps every parent and the fraction each contributed, so deriving NV costs none of what it was derived from');

  -- The control. Deriving NV has to be a fact about the parents disagreeing
  -- rather than something that happens to every blend, so a parent that was
  -- 2024 going in is still 2024.
  select count(*) into n from node
   where id = n_a and vintage = 2024 and not non_vintage;
  if n <> 1 then
    raise exception 'FAIL: a lot of one year stopped being of that year when something was blended out of it';
  end if;
  perform test_ok('a lot of one year is still of that year afterwards, so NV is derived from disagreement and not from blending as such');

  -- A child of an NV parent is NV. Without this, the first press or fork of a
  -- blend would be refused by the constraint, which is the sort of thing that
  -- only shows up on the day it matters.
  -- The blend is all in one vessel and a whole-lot fork is refused, so it is
  -- split across two first. Still one lot: a split keeps identity, which is
  -- what makes the fork below the thing being tested rather than the split.
  perform rack(
    jsonb_build_array(jsonb_build_object('vessel_id', v_c, 'volume_l', 1000)),
    jsonb_build_array(
      jsonb_build_object('vessel_id', v_a, 'volume_l', 500),
      jsonb_build_object('vessel_id', v_b, 'volume_l', 500)));
  forked := fork_lot(child, array[v_a]::uuid[], 'ASRTNV forked');
  select count(*) into n from node
   where id = forked and vintage is null and non_vintage;
  if n <> 1 then
    raise exception 'FAIL: a lot forked off a non-vintage blend is not non-vintage';
  end if;
  perform test_ok('a lot taken out of a non-vintage lot is non-vintage, so nothing downstream of a blend is refused for saying nothing');

  -- The voice, as opposed to the guarantee. A constraint name arriving in front
  -- of somebody at a press is not a refusal anybody can act on.
  begin
    perform set_vintage(n_a, null, false);
    raise exception 'FAIL: set_vintage accepted neither';
  exception when others then
    if position('or say it is non-vintage' in sqlerrm) = 0 then raise; end if;
    perform test_ok('being asked for a vintage and given neither answers in a sentence rather than a constraint name');
  end;

  begin
    perform set_vintage(n_a, 20244, false);
    raise exception 'FAIL: a lot was given the vintage 20244';
  exception when others then
    if position('is not a vintage year' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a mistyped year is refused, because 20244 is a slip rather than a vintage');
  end;

  out_js := set_vintage(n_a, null, true);
  if (out_js ->> 'non_vintage')::boolean is not true then
    raise exception 'FAIL: a lot set to non-vintage does not read as one';
  end if;
  perform test_ok('a lot can be declared non-vintage deliberately, which is the state the old blank was standing in for');

  -- Tidy, in dependency order. 0047 holds a photograph to the reading it is
  -- evidence of with a restrict, so anything attached goes before the events.
  delete from attachment
   where subject_type = 'node' and subject_id in (n_a, n_b, child, forked);
  delete from attachment a using event e
   where a.about_event = e.id and e.subject_type = 'node'
     and e.subject_id in (n_a, n_b, child, forked);
  delete from placement where vessel_id in (v_a, v_b, v_c);
  delete from event where subject_type = 'node'
     and subject_id in (n_a, n_b, child, forked);
  delete from lineage
   where parent_id in (n_a, n_b, child, forked)
      or child_id in (n_a, n_b, child, forked);
  delete from node where id in (n_a, n_b, child, forked) or name like 'ASRTNV%';
  delete from vessel where id in (v_a, v_b, v_c);
end $$;

-- The grandfathering, stated rather than left implicit. S-69 says this rule is
-- real for everything anybody does next and not yet true of everything already
-- written, and an assertion is how that stays a known limit rather than a
-- forgotten one.
do $$
declare
  is_valid boolean;
  probe uuid := '00000000-0000-0000-0000-00000000cb11';
  n int;
  suggested text;
begin
  select convalidated into is_valid from pg_constraint
   where conrelid = 'node'::regclass and conname = 'node_says_its_vintage';
  if is_valid is null then
    raise exception 'FAIL: the rule that a lot says its vintage is not in the schema at all';
  end if;
  if is_valid then
    raise exception
      'FAIL: node_says_its_vintage is now valid, which is good news and means S-69 is discharged. Update this assertion and the ledger together.';
  end if;
  perform test_ok('the vintage rule is enforced for everything written from now and not retrospectively, which is S-69 and is deliberate');

  -- The suggestion is read off the name and is never written. A lot called
  -- "2024 Eola Springs" is almost certainly a 2024 and that is almost certainly
  -- not a thing a database may decide on somebody's behalf.
  --
  -- The only way to build a row like the one this is about is to put the
  -- constraint aside for a moment, because it refuses updates as firmly as
  -- inserts, which is why nothing new can join that list. Dropped and re-added
  -- with the same definition, inside a transaction the suite rolls back.
  alter table node drop constraint node_says_its_vintage;
  insert into node (id, stage, name, vintage, non_vintage)
  values (probe, 'maturation', '2019 Assert Grandfathered', null, false);
  alter table node add constraint node_says_its_vintage
    check ((vintage is null) = non_vintage) not valid;

  select count(*) into n from lot_without_vintage where id = probe;
  if n <> 1 then
    raise exception 'FAIL: a lot saying nothing is not on the list of lots saying nothing';
  end if;
  select suggested_year into suggested from lot_without_vintage where id = probe;
  if suggested <> '2019' then
    raise exception 'FAIL: the year in the name came out as %', coalesce(suggested, 'nothing');
  end if;
  select vintage::text into suggested from node where id = probe;
  if suggested is not null then
    raise exception 'FAIL: the suggestion was written to the lot rather than offered';
  end if;
  perform test_ok('a year visible in a lot name is offered as a suggestion and never written, because reading a fact off a string is not the same as knowing it');

  delete from node where id = probe;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- something goes into the wine, and off the shelf'; end $$;

-- 0050. The winemaker: "we definitely need an additions section. Where you
-- select a vessel with wine and add additions." And S-64, which 0046 predicted
-- would be the thing that made its inventory untrustworthy: nobody records a
-- scoop twice during harvest.
do $$
declare
  v_a   uuid := '00000000-0000-0000-0000-00000000cc01';
  v_b   uuid := '00000000-0000-0000-0000-00000000cc02';
  dap   uuid := '00000000-0000-0000-0000-00000000cc03';
  wrap  uuid := '00000000-0000-0000-0000-00000000cc04';
  tank  uuid;
  vrty  uuid;
  n_a   uuid;
  n_b   uuid;
  out_js jsonb;
  n     int;
  q     numeric;
begin
  select id into tank from term where kind = 'vessel_type' and value = 'tank';
  select id into vrty from term where kind = 'variety' and value = 'riesling';

  insert into supply (id, name, unit) values
    (dap,  'Assert DAP for wine', 'g'),
    (wrap, 'Assert not an addition', 'Rolls');
  insert into supply_material_kind (supply_id, kind_id)
  values (dap, term_id('material_kind', 'addition'));
  insert into supply_movement (supply_id, kind, quantity, by_user)
  values (dap, 'received', 1000, '00000000-0000-0000-0000-00000000a001');

  -- The picker offers what somebody flagged as going into wine, matched on the
  -- registry value rather than on the label, so renaming the sort cannot empty
  -- it silently. 0051 and AR-E6.
  select count(*) into n from supply_for_addition where supply_id = dap;
  if n <> 1 then
    raise exception 'FAIL: a supply flagged as going into wine is not offered as an addition';
  end if;
  select count(*) into n from supply_for_addition where supply_id = wrap;
  if n <> 0 then
    raise exception 'FAIL: plastic wrap is offered as something to put in wine';
  end if;
  perform test_ok('the additions picker offers what somebody flagged as going into wine and nothing else, matched on the registry value rather than its label');

  n_a := (create_vessel_with_wine(
    jsonb_build_object('id', v_a, 'name', 'ASRTADD A', 'type_id', tank, 'capacity_l', 1000),
    jsonb_build_object('name', 'ASRTADD lot', 'vintage', 2026, 'variety_id', vrty,
                       'quantity', 500, 'unit', 'L'),
    500, '[]'::jsonb, false) ->> 'node_id')::uuid;
  n_b := (create_vessel_with_wine(
    jsonb_build_object('id', v_b, 'name', 'ASRTADD B', 'type_id', tank, 'capacity_l', 1000),
    jsonb_build_object('name', 'ASRTADD other lot', 'vintage', 2026, 'variety_id', vrty,
                       'quantity', 300, 'unit', 'L'),
    300, '[]'::jsonb, false) ->> 'node_id')::uuid;

  -- **S-64, answered.** One action, two records.
  out_js := add_to_wine(array[v_a]::uuid[], 100, 'g', dap);
  if (out_js ->> 'shelf_moved')::boolean is not true then
    raise exception 'FAIL: an addition off the shelf did not take anything off the shelf: %',
      out_js ->> 'shelf_note';
  end if;
  select on_hand into q from supply_on_hand where supply_id = dap;
  if q <> 900 then
    raise exception 'FAIL: 100 g out of 1000 leaves % on the shelf', q;
  end if;
  perform test_ok('an addition that names the supply it came from takes it off the shelf as a consequence, which is S-64 and is why the stores exist');

  select count(*) into n from supply_movement
   where supply_id = dap and caused_by = (out_js ->> 'event_id')::uuid;
  if n <> 1 then
    raise exception 'FAIL: the movement does not name the addition that caused it';
  end if;
  perform test_ok('the scoop off the shelf names the addition it was part of, so the two are provably one act rather than two entries somebody hoped matched');

  -- The rate is arithmetic over two facts that are both in the record, so it is
  -- computed rather than stored. T0-2.
  if (out_js ->> 'volume_l')::numeric <> 500 then
    raise exception 'FAIL: the addition went into % litres rather than 500', out_js ->> 'volume_l';
  end if;
  if (out_js ->> 'per_litre')::numeric <> 0.2 then
    raise exception 'FAIL: 100 g into 500 L came out as % per litre', out_js ->> 'per_litre';
  end if;
  select count(*) into n from event
   where id = (out_js ->> 'event_id')::uuid
     and (data ? 'per_litre' or data ? 'volume_l');
  if n <> 0 then
    raise exception 'FAIL: the rate or the volume was stored, and both are derivations';
  end if;
  perform test_ok('the volume at the time and the rate are computed from the placements and never written down, which is the whole of C-3 lesson');

  -- **Unit mismatch is said, not guessed.** A factor invented here is an
  -- inventory that is confidently wrong. S-63.
  out_js := add_to_wine(array[v_a]::uuid[], 2, 'kg', dap);
  if (out_js ->> 'shelf_moved')::boolean is not false then
    raise exception 'FAIL: 2 kg was taken off a shelf measured in grams';
  end if;
  if position('nothing here converts' in (out_js ->> 'shelf_note')) = 0 then
    raise exception 'FAIL: the shelf was left alone and the reason given was: %',
      out_js ->> 'shelf_note';
  end if;
  select on_hand into q from supply_on_hand where supply_id = dap;
  if q <> 900 then
    raise exception 'FAIL: the shelf moved anyway, to %', q;
  end if;
  select count(*) into n from lot_addition where node_id = n_a;
  if n <> 2 then
    raise exception 'FAIL: the addition in a unit the shelf does not use was not recorded at all';
  end if;
  perform test_ok('an addition measured in a unit the shelf does not keep is recorded in full and moves nothing, and says which, because a guessed conversion is worse than an unrecorded one');

  -- Vessels first, and one lot at a time. A lot in three barrels dosed in one of
  -- them is not an addition to the other two: the wine is not mixed, and one
  -- record of both would put a rate on the day that neither experienced.
  begin
    perform add_to_wine(array[v_a, v_b]::uuid[], 50, 'g', dap);
    raise exception 'FAIL: one addition was recorded across two different lots';
  exception when others then
    if position('different lots' in sqlerrm) = 0 then raise; end if;
    perform test_ok('an addition cannot span two lots in one record, because the rate it implies is true of neither');
  end;

  -- The refusals that stop a record meaning nothing.
  begin
    perform add_to_wine(array[v_a]::uuid[], 100, 'g');
    raise exception 'FAIL: something unnamed was added to the wine';
  exception when others then
    if position('say what went in' in sqlerrm) = 0 then raise; end if;
    perform test_ok('an addition that does not say what went in is refused, because the amount alone records nothing');
  end;

  begin
    perform add_to_wine(array[v_b]::uuid[], 0, 'g', null, 'nothing at all');
    raise exception 'FAIL: an addition of zero was recorded';
  exception when others then
    if position('is not an amount' in sqlerrm) = 0 then raise; end if;
    perform test_ok('an addition of nothing is refused, because zero is a measurement and this is the absence of one');
  end;

  -- Something not on the shelf is still a record. Refusing it would mean it goes
  -- unrecorded rather than that somebody sets up a supply first.
  out_js := add_to_wine(array[v_b]::uuid[], 5, 'mL', null, 'Assert enzyme');
  if out_js ->> 'what' <> 'Assert enzyme' then
    raise exception 'FAIL: an addition by name came back as %', out_js ->> 'what';
  end if;
  if (out_js ->> 'shelf_moved')::boolean is not false then
    raise exception 'FAIL: something not off the shelf moved the shelf';
  end if;
  perform test_ok('something the winery does not keep an inventory of is still recorded, because the alternative is that it is not recorded at all');

  -- Tidy, photographs and movements before the events they hang off.
  delete from supply_movement where supply_id in (dap, wrap);
  delete from event where subject_type = 'node' and subject_id in (n_a, n_b);
  delete from supply_material_kind where supply_id in (dap, wrap);
  delete from supply where id in (dap, wrap);
  delete from placement where vessel_id in (v_a, v_b);
  delete from node where id in (n_a, n_b) or name like 'ASRTADD%';
  delete from vessel where id in (v_a, v_b);
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a press is a process, not an entry at the end'; end $$;

-- 0052. The winemaker, from the crush pad: "pressing needs to be a process
-- instead of an entry at the end. Like I wanted to start a press but I can't
-- know how many liters until after I've pressed." And: "you might update the
-- liters multiple times, or after different pressures."
do $$
declare
  pick   uuid := '00000000-0000-0000-0000-00000000cd01';
  press  uuid := '00000000-0000-0000-0000-00000000cd02';
  tank   uuid := '00000000-0000-0000-0000-00000000cd03';
  tank2  uuid := '00000000-0000-0000-0000-00000000cd04';
  load_id uuid;
  out_js jsonb;
  n      int;
  q      numeric;
  st     node_stage;
  st_text text;
begin
  update term set attributes = attributes || '{"tare_lbs": 60}'::jsonb
   where kind = 'vessel_type' and value = 'picking_bin';

  insert into vessel (id, name, type_id, capacity_l) values
    (press, 'Assert press', term_id('vessel_type', 'press'), null),
    (tank,  'Assert press tank', term_id('vessel_type', 'tank'), 1000),
    (tank2, 'Assert press tank 2', term_id('vessel_type', 'tank'), 1000);

  perform add_bins_to_pick(
    jsonb_build_object('id', pick, 'variety_id', term_id('variety', 'riesling'),
                       'vintage', 2026),
    null, 2, term_id('vessel_type', 'picking_bin'), 'ASRTPRESS', 100);
  perform weigh_bins(pick,
    array(select vessel_id from unweighed_bin where node_id = pick), 2120);

  -- **Starting.** The fruit leaves the bins and is in the press, and how much it
  -- will give is not known yet. That is T1-4's shape a second time: the thing
  -- exists before its quantity does, exactly as a bin does before a scale.
  out_js := start_press(array(select vessel_id from placement
                          where node_id = pick and to_at is null), press);
  load_id := (out_js ->> 'node_id')::uuid;

  select stage, quantity into st, q from node where id = load_id;
  if st <> 'load' then
    raise exception 'FAIL: fruit in a press is at stage % rather than load', st;
  end if;
  if q is not null then
    raise exception
      'FAIL: a press that has given nothing yet says it has given %, and nobody has measured anything', q;
  end if;
  perform test_ok('fruit in a press is a lot at the load stage with no volume yet, because nobody knows the litres before they have pressed');

  select count(*) into n from placement where node_id = pick and to_at is null;
  if n <> 0 then
    raise exception 'FAIL: % bins still hold fruit that is in the press', n;
  end if;
  perform test_ok('the bins empty when the press starts rather than when it finishes, so they are free for the next pick while it runs');

  select count(*) into n from press_in_progress where node_id = load_id;
  if n <> 1 then
    raise exception 'FAIL: a press that was started is not listed as running';
  end if;
  perform test_ok('a press that was started and not finished is findable without remembering where it was, which is what popping back in needs');

  -- **Drawing, more than once.** Free run, then more free run into the same
  -- tank an hour later, is one cut that got bigger.
  out_js := draw_cut(load_id, tank, 400, term_id('press_cut', 'free_run'));
  if (out_js ->> 'cut_total')::numeric <> 400 then
    raise exception 'FAIL: the first 400 L came out as %', out_js ->> 'cut_total';
  end if;

  out_js := draw_cut(load_id, tank, 150, term_id('press_cut', 'free_run'));
  if (out_js ->> 'cut_total')::numeric <> 550 then
    raise exception 'FAIL: 400 then 150 into the same cut came to %', out_js ->> 'cut_total';
  end if;
  select count(*) into n from lineage where parent_id = load_id;
  if n <> 1 then
    raise exception 'FAIL: drawing the same cut twice made % lots', n;
  end if;
  perform test_ok('the same cut drawn again is that cut getting bigger rather than a second lot, which is what updating the litres multiple times means');

  select volume_l into q from placement
   where node_id = (out_js ->> 'cut_id')::uuid and vessel_id = tank and to_at is null;
  if q <> 550 then
    raise exception 'FAIL: the tank holds % L after two draws totalling 550', q;
  end if;
  perform test_ok('the vessel holds what has actually been put in it, updated on each draw rather than at the end');

  -- A different pressure into a different vessel is a different cut.
  out_js := draw_cut(load_id, tank2, 90, term_id('press_cut', 'hard_press'));
  select count(*) into n from lineage where parent_id = load_id;
  if n <> 2 then
    raise exception 'FAIL: a second cut gave % children', n;
  end if;
  select count(*) into n from lineage where parent_id = load_id and fraction <> 1;
  if n <> 0 then
    raise exception 'FAIL: a cut is not entirely made of the load it came out of';
  end if;
  perform test_ok('every cut is wholly made of the load, which is what lets its share be written the moment it is drawn instead of at the end');

  -- The picks' proportions live one generation up, where they were known before
  -- a drop ran. That is the reason the load exists at all.
  select count(*) into n from lineage where child_id = load_id;
  if n <> 1 then
    raise exception 'FAIL: the load does not record what it was made of';
  end if;
  perform test_ok('what the load was made of was recorded when it went in, so nothing has to be recomputed as the juice comes off');

  -- 0056, the second way of working. `draw_cut` asks what came off since last
  -- time, which is subtraction in somebody's head against a number they last saw
  -- an hour ago. This asks what the tank reads now. The subtraction is a rule and
  -- lives in the kernel, because two clients doing it differently would disagree
  -- about how much wine exists.
  out_js := draw_to_level(load_id, tank, 700);
  if (out_js ->> 'was_at')::numeric <> 550 then
    raise exception 'FAIL: the tank was at 550 and the kernel thought %', out_js ->> 'was_at';
  end if;
  if (out_js ->> 'volume_l')::numeric <> 150 then
    raise exception 'FAIL: 550 up to 700 came out as a draw of %', out_js ->> 'volume_l';
  end if;
  select quantity into q from node
   where id = (out_js ->> 'cut_id')::uuid;
  if q <> 700 then
    raise exception 'FAIL: after reading the tank at 700 the cut holds %', q;
  end if;
  perform test_ok('reading the tank works out what came off, so nobody does subtraction against a number they last saw an hour ago');

  -- The cut is not asked for a vessel already taking juice from this press: a
  -- tank holding free run receiving more juice is receiving more free run.
  if out_js ->> 'cut' <> 'Free run' then
    raise exception 'FAIL: topping up a tank of free run was recorded as %', out_js ->> 'cut';
  end if;
  perform test_ok('a tank already taking a cut of this press keeps taking that cut, so the one question with one right answer is not asked again');

  -- **The interesting refusal.** A reading below what is in the vessel means a
  -- misread gauge or wine having left, and neither is a draw.
  begin
    perform draw_to_level(load_id, tank, 400);
    raise exception 'FAIL: a tank holding 700 L was read at 400 and that was recorded as a draw';
  exception when others then
    if position('is not more wine arriving' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a reading below what the vessel already holds is refused, because it is a misread gauge rather than a negative draw');
  end;

  -- And a reading that has not moved is not a draw either. A13: a success that
  -- did nothing must not look like a success that did something.
  begin
    perform draw_to_level(load_id, tank, 700);
    raise exception 'FAIL: recording the same level twice counted as a second draw';
  exception when others then
    if position('nothing has come off' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a level that has not changed is refused rather than recorded as a draw of nothing, so a double tap does not read as progress');
  end;

  select litres_so_far into q from press_in_progress where node_id = load_id;
  if q <> 790 then
    raise exception 'FAIL: 700 and 90 off shows as % so far', q;
  end if;
  perform test_ok('the litres so far is the number that changes every time somebody goes back to the press, and it is what the list shows');

  -- **Finishing.** The yield exists now and did not before.
  out_js := finish_press(load_id, jsonb_build_object('program', 'Assert program', 'minutes', 95));
  if (out_js ->> 'litres_out')::numeric <> 790 then
    raise exception 'FAIL: the press finished at % L', out_js ->> 'litres_out';
  end if;
  if (out_js ->> 'yield_l_per_ton')::numeric <> 790 then
    raise exception 'FAIL: 790 L off a ton came out as % L per ton', out_js ->> 'yield_l_per_ton';
  end if;
  perform test_ok('the yield exists when the press finishes and not before, because it is litres over a weight and one of those arrives hours after the other');

  select count(*) into n from press_in_progress where node_id = load_id;
  if n <> 0 then
    raise exception 'FAIL: a finished press is still listed as running';
  end if;
  select count(*) into n from placement where vessel_id = press and to_at is null;
  if n <> 0 then
    raise exception 'FAIL: the press still holds something after it was finished';
  end if;
  perform test_ok('a finished press is empty and off the list, so the next load can go in');

  -- The refusals that keep the process honest.
  begin
    perform draw_cut(load_id, tank, 10, term_id('press_cut', 'free_run'));
    raise exception 'FAIL: juice was drawn off a press that had been finished';
  exception when others then
    if position('that press is finished' in sqlerrm) = 0 then raise; end if;
    perform test_ok('nothing can be drawn off a press that was finished, because a correction is a different act from a draw');
  end;

  -- 0054, and the assertion that found it. Before that fix the pick stayed open
  -- with its bins emptied, so once the press was free the same fruit could be
  -- pressed again and a second load made out of juice.
  select status::text into st_text from node where id = pick;
  if st_text <> 'closed' then
    raise exception 'FAIL: a pick whose fruit is in the press is still %', st_text;
  end if;
  -- 0090 changes what this looks like without changing what it proves. The
  -- sources are vessels now, so a spent pick has no vessels to name: the second
  -- press is refused because there is nothing to press rather than because the
  -- lot is closed. Both are the same refusal wearing the shape of the argument
  -- it was given, and the one that matters is that the fruit cannot go twice.
  begin
    perform start_press(array(select vessel_id from placement
                          where node_id = pick and to_at is null), press);
    raise exception 'FAIL: a spent pick was pressed a second time';
  exception when others then
    if position('is closed' in sqlerrm) = 0
       and position('nothing of it left to press' in sqlerrm) = 0
       and position('nothing was named to press' in sqlerrm) = 0 then raise; end if;
    perform test_ok('fruit that has already gone into a press cannot go into another one, which nothing refused until an assertion asked');
  end;

  -- And by the other route, which 0090 makes the reachable one: naming the bin
  -- itself after it has been emptied.
  begin
    perform start_press(
      array(select vessel_id from placement
             where node_id = pick order by from_at limit 1), press);
    raise exception 'FAIL: an emptied bin was pressed again';
  exception when others then
    if position('nothing in it' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a bin that has been emptied into a press cannot be pressed again by name, which is the route that exists now that the source is a vessel');
  end;

  -- Lineage holds a restrict at both ends, so it goes before the lots it links.
  create temp table asrt_press_cuts on commit drop as
    select child_id as id from lineage where parent_id = load_id;
  delete from event where subject_type = 'node'
     and subject_id in (select id from asrt_press_cuts);
  delete from event where subject_type = 'node' and subject_id in (load_id, pick);
  delete from placement where node_id in (select id from asrt_press_cuts);
  delete from lineage where parent_id = load_id or child_id = load_id;
  delete from node where id in (select id from asrt_press_cuts);
  delete from placement where node_id in (load_id, pick);
  delete from node where id in (load_id, pick);
  delete from vessel where id in (press, tank, tank2) or name like 'ASRTPRESS%';
  update term set attributes = attributes - 'tare_lbs'
   where kind = 'vessel_type' and value = 'picking_bin';
end $$;

-- An empty press is a press that has not started, and finishing one that gave
-- nothing would record a press that produced nothing, which is a claim rather
-- than a measurement.
do $$
declare
  pick  uuid := '00000000-0000-0000-0000-00000000cd11';
  press uuid := '00000000-0000-0000-0000-00000000cd12';
  load_id uuid;
begin
  insert into vessel (id, name, type_id) values
    (press, 'Assert empty press', term_id('vessel_type', 'press'));
  perform add_bins_to_pick(
    jsonb_build_object('id', pick, 'variety_id', term_id('variety', 'riesling'),
                       'vintage', 2026),
    null, 1, term_id('vessel_type', 'picking_bin'), 'ASRTEMPTYPRESS', 100);

  load_id := (start_press(array(select vessel_id from placement
                          where node_id = pick and to_at is null), press) ->> 'node_id')::uuid;
  begin
    perform finish_press(load_id);
    raise exception 'FAIL: a press that gave nothing was finished';
  exception when others then
    if position('nothing has been drawn' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a press nothing was drawn off cannot be finished, because a press that produced nothing is a claim rather than a measurement');
  end;

  delete from event where subject_type = 'node' and subject_id in (load_id, pick);
  delete from lineage where child_id = load_id;
  delete from placement where node_id in (load_id, pick);
  delete from node where id in (load_id, pick);
  delete from vessel where id = press or name like 'ASRTEMPTYPRESS%';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the contract, and whether it can drift'; end $$;

-- AR-Q8. An interface is a periphery over a read and write contract, and 0057
-- is that contract. A declaration of what a periphery may read and write is a
-- comment unless something fails when it stops being true, so the assertions
-- below are what make it a contract rather than documentation. They are the
-- whole of the difference, and they are what the ruling's `built` claim rests
-- on.

-- Forwards: everything declared exists and is shaped as declared.
do $$
declare bad text; n int;
begin
  -- A readable naming a relation that is not there is the first way this rots,
  -- and it happened within a minute of 0057 applying: `cellar.open_picks` named
  -- `pick_open`, which did not exist, because what counts as an open pick was
  -- three filters typed into a client. 0058 is that fix.
  select string_agg(r.key || ' names ' || r.relation, ', ' order by r.key) into bad
    from readable r
   where to_regclass('public.' || r.relation) is null;
  if bad is not null then
    raise exception 'FAIL: these readables name relations that do not exist: %', bad;
  end if;
  perform test_ok('every readable in the contract names a relation that exists, so a periphery reading the contract can read the cellar');

  -- And the columns it promises a periphery can find a row by.
  select string_agg(r.key, ', ' order by r.key) into bad
    from readable r
   where r.id_column is not null
     and not exists (
       select 1 from information_schema.columns c
        where c.table_schema = 'public' and c.table_name = r.relation
          and c.column_name = r.id_column);
  if bad is not null then
    raise exception 'FAIL: these readables name an id column their relation does not have: %', bad;
  end if;
  select string_agg(r.key, ', ' order by r.key) into bad
    from readable r
   where r.label_column is not null
     and not exists (
       select 1 from information_schema.columns c
        where c.table_schema = 'public' and c.table_name = r.relation
          and c.column_name = r.label_column);
  if bad is not null then
    raise exception 'FAIL: these readables name a label column their relation does not have: %', bad;
  end if;
  perform test_ok('every readable names an id and a label column that exist, because a periphery needs both and can guess neither');

  -- A capability naming a function that is not there, or is there twice.
  select string_agg(c.key || ' calls ' || c.fn, ', ' order by c.key) into bad
    from capability c
   where (select count(*) from pg_proc p
            join pg_namespace ns on ns.oid = p.pronamespace
           where ns.nspname = 'public' and p.proname = c.fn) <> 1;
  if bad is not null then
    raise exception
      'FAIL: these capabilities call a function that does not exist or exists more than once: %', bad;
  end if;
  perform test_ok('every capability calls exactly one function that exists, so nothing in the contract is a name somebody hoped was still right');

  -- **The parameter check, which is the one that catches a rename.** Every
  -- declared field must fill a real parameter of that function.
  select string_agg(c.key || '.' || (f ->> 'key') || ' -> ' || (f ->> 'param'), ', ') into bad
    from capability c, jsonb_array_elements(c.fields) f
   where not exists (
     select 1 from pg_proc p
       join pg_namespace ns on ns.oid = p.pronamespace,
       unnest(p.proargnames) as arg
      where ns.nspname = 'public' and p.proname = c.fn and arg = (f ->> 'param'));
  if bad is not null then
    raise exception 'FAIL: these declared fields name parameters their function does not take: %', bad;
  end if;
  perform test_ok('every field in the contract fills a parameter its function actually takes, so renaming an argument breaks the build rather than a periphery');

  -- And the reverse within one function: a parameter with no default is one the
  -- kernel cannot do without, so a contract that omits it hands a periphery a
  -- call that always fails.
  select string_agg(c.key || ' omits ' || arg, ', ') into bad
    from capability c
    join pg_proc p on p.proname = c.fn
    join pg_namespace ns on ns.oid = p.pronamespace and ns.nspname = 'public',
    lateral unnest(p.proargnames) with ordinality as a(arg, ord)
   where a.ord <= p.pronargs - p.pronargdefaults
     and not exists (
       select 1 from jsonb_array_elements(c.fields) f where f ->> 'param' = a.arg);
  if bad is not null then
    raise exception
      'FAIL: these capabilities omit a parameter their function has no default for, so a periphery built from the contract cannot call them: %', bad;
  end if;
  perform test_ok('every parameter the kernel has no default for is declared, so a periphery built from the contract alone can make the call');

  -- A required field for a parameter that has a default is a contract being
  -- stricter than the kernel, which is allowed, and the opposite is not.
  select string_agg(x.key || '.' || x.fkey, ', ') into bad
    from (
      select c.key, c.fn,
             f ->> 'key'   as fkey,
             f ->> 'param' as param,
             coalesce((f ->> 'required')::boolean, false) as required
        from capability c
        cross join lateral jsonb_array_elements(c.fields) f
    ) x
    join pg_proc p on p.proname = x.fn
    join pg_namespace ns on ns.oid = p.pronamespace and ns.nspname = 'public'
   where not x.required
     and exists (
       select 1
         from unnest(p.proargnames) with ordinality as a(arg, ord)
        where a.ord <= p.pronargs - p.pronargdefaults
          and a.arg = x.param);
  if bad is not null then
    raise exception
      'FAIL: these fields are optional in the contract and required by the kernel: %', bad;
  end if;
  perform test_ok('nothing the kernel requires is optional in the contract, so a periphery is never told a thing is skippable when it is not');

  -- A source pointing at a readable or a vocabulary that is not there.
  select string_agg(c.key || '.' || (f ->> 'key'), ', ') into bad
    from capability c, jsonb_array_elements(c.fields) f
   where f -> 'source' ? 'readable'
     and not exists (select 1 from readable r where r.key = f -> 'source' ->> 'readable');
  if bad is not null then
    raise exception 'FAIL: these fields draw from a readable that is not in the contract: %', bad;
  end if;
  select string_agg(c.key || '.' || (f ->> 'key'), ', ') into bad
    from capability c, jsonb_array_elements(c.fields) f
   where f -> 'source' ? 'terms'
     and not exists (select 1 from term_kind k where k.kind = f -> 'source' ->> 'terms');
  if bad is not null then
    raise exception 'FAIL: these fields draw from a vocabulary that is not registered: %', bad;
  end if;
  select count(*) into n from capability c
   where c.subject is not null
     and not exists (select 1 from readable r where r.key = c.subject);
  if n <> 0 then
    raise exception 'FAIL: % capabilities act on a subject that is not a readable', n;
  end if;
  perform test_ok('every picker in the contract points at a readable or a vocabulary that exists, so nothing offers a periphery a list it cannot fetch');
end $$;

-- **Backwards, which is the direction that matters.** A contract does not fall
-- behind by contradicting itself. It falls behind by omission: somebody adds a
-- function, grants it, writes a screen for it, and the declaration says nothing.
-- This is the same ratchet as the refusal-site enumeration, and it is why
-- `capability_exemption` carries a reason rather than a list of names.
do $$
declare undeclared text;
begin
  select string_agg(p.proname, ', ' order by p.proname) into undeclared
    from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
     and p.prokind = 'f'
     and has_function_privilege('authenticated', p.oid, 'EXECUTE')
     -- Triggers are reached by writing a row, never called by a periphery.
     and pg_get_function_result(p.oid) <> 'trigger'
     -- This suite's own harness, created inside this transaction and gone when
     -- it rolls back. Excluded here rather than exempted in a migration,
     -- because a migration recording them would be recording things that do not
     -- exist in the database it describes.
     and p.proname not in ('test_ok', 'test_act_as', 'test_refusal', 'test_refuses',
                           'snapshots_on', 'skip_snapshot')
     and not exists (select 1 from capability c where c.fn = p.proname)
     and not exists (select 1 from capability_exemption e where e.fn = p.proname);

  if undeclared is not null then
    raise exception
      E'FAIL: these functions are callable by a signed-in account and the contract says nothing about them: %.\nEither declare a capability for it, or add it to capability_exemption with the reason it is not one. A contract falls behind by omission rather than by contradiction, which is why this direction is checked.',
      undeclared;
  end if;
  perform test_ok('every function a signed-in account can call is either a declared capability or an exemption with a written reason, so the contract cannot fall behind in silence');
end $$;

-- What a periphery actually receives. If this is wrong the rest is theory.
do $$
declare c jsonb; n int;
begin
  c := contract();
  if c -> 'viewer' is null then
    raise exception 'FAIL: the contract does not say who is asking';
  end if;
  select jsonb_array_length(c -> 'capabilities') into n;
  if n < 5 then
    raise exception 'FAIL: the contract offers % capabilities', n;
  end if;
  select jsonb_array_length(c -> 'readables') into n;
  if n < 5 then
    raise exception 'FAIL: the contract offers % readables', n;
  end if;
  -- Every capability arrives with its fields, or a periphery has to ask again.
  select count(*) into n
    from jsonb_array_elements(c -> 'capabilities') cap
   where jsonb_array_length(cap -> 'fields') = 0;
  if n <> 0 then
    raise exception 'FAIL: % capabilities arrive with no fields at all', n;
  end if;
  perform test_ok('one call returns who is asking, what may be read, what may be written and what each write needs, which is what a second periphery starts from');
end $$;

-- The contract is structure, and structure is readable by anyone signed in. It
-- must never carry content: what may be done is not whose wine.
do $$
declare seen int; leaked text;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a003');   -- the client login
  set local role authenticated;
  select count(*) into seen from capability;
  reset role;
  if seen = 0 then
    raise exception 'FAIL: a client cannot read the contract, so a client periphery cannot exist';
  end if;

  select string_agg(c.key, ', ') into leaked from capability c
   where c.note ~* '(pinot|riesling|chardonnay|amica|pearlstaad|vitae)';
  if leaked is not null then
    raise exception 'FAIL: the contract names this winery''s wine in %, which is content rather than structure', leaked;
  end if;
  perform test_ok('the contract is readable by anybody signed in and names no lot, party or wine, because it says what may be done and never whose');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
end $$;

-- 0058. The R-4 the contract found on its first day.
do $$
declare n int; probe uuid := '00000000-0000-0000-0000-00000000ce01';
begin
  insert into node (id, stage, status, name, vintage, created_by)
  values (probe, 'bin', 'open', 'Assert open pick', 2026,
          '00000000-0000-0000-0000-00000000a001');
  select count(*) into n from open_pick where id = probe;
  if n <> 1 then
    raise exception 'FAIL: a pick in bins and not closed is not an open pick';
  end if;

  update node set status = 'closed', closed_at = now() where id = probe;
  select count(*) into n from open_pick where id = probe;
  if n <> 0 then
    raise exception 'FAIL: a closed pick is still open';
  end if;
  perform test_ok('what counts as an open pick is a view rather than three filters typed into a client, which is the R-4 that declaring the contract found');

  delete from node where id = probe;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a note on anything, and what a note may never do'; end $$;

-- 0062. The winemaker: "everything needs to be an item that I can add more
-- detail to. Like the fruit condition was mostly good in the PG. How do I add
-- that to the bins now?"
--
-- The rule is his reference's, from Knowledge Game: comments "carry no grade and
-- can never be cited as support", so that "talking never masquerades as
-- evidence", enforced mechanically rather than by policy. **The assertions below
-- are that mechanism.** Without them the rule is a sentence in a migration.
do $$
declare
  pick   uuid := '00000000-0000-0000-0000-00000000cf01';
  bin    uuid;
  ev     uuid;
  out_js jsonb;
  n      int;
  before int;
  q      numeric;
begin
  update term set attributes = attributes || '{"tare_lbs": 60}'::jsonb
   where kind = 'vessel_type' and value = 'picking_bin';
  perform add_bins_to_pick(
    jsonb_build_object('id', pick, 'variety_id', term_id('variety', 'riesling'),
                       'vintage', 2026),
    null, 2, term_id('vessel_type', 'picking_bin'), 'ASRTNOTE', 100);
  select vessel_id into bin from unweighed_bin where node_id = pick limit 1;

  -- A note goes on a bin, which is a vessel, and on the pick, which is a lot,
  -- and on anything else the resolver knows. That is the whole point of it not
  -- being a fourth note table.
  out_js := add_note('vessel', bin, 'fruit was mostly good, a bit of shrivel');
  if (out_js ->> 'id') is null then
    raise exception 'FAIL: a note on a bin was not written';
  end if;
  perform add_note('node', pick, 'picked in two passes');
  select count(*) into n from subject_note where subject_id in (pick, bin);
  if n <> 2 then
    raise exception 'FAIL: % notes came back and two were written', n;
  end if;
  perform test_ok('a note goes on a bin or a lot or anything else the resolver knows, so nobody has to invent a note table per kind of thing');

  -- **The rule.** A note changes nothing that computes.
  select quantity into q from node where id = pick;
  if q is not null then
    raise exception 'FAIL: a pick with two notes and no weighing has a quantity of %', q;
  end if;
  select count(*) into n from unweighed_bin where node_id = pick;
  if n <> 2 then
    raise exception 'FAIL: writing a note changed the bins waiting for a scale to %', n;
  end if;
  perform test_ok('a note changes no quantity and clears no worklist, because talking is not evidence and the difference is mechanical rather than a convention');

  -- Nor can it discharge paperwork. A propagation is cleared by filling the
  -- form, and saying you filled it is not filling it.
  perform weigh_bins(pick,
    array(select vessel_id from unweighed_bin where node_id = pick), 2120);
  select e.id into ev from event e
   where e.subject_type = 'node' and e.subject_id = pick
     and e.operation_id = term_id('operation', 'weigh')
   limit 1;
  select count(*) into before from measurement_to_propagate where event_id = ev;
  perform add_note('node', pick, 'wrote this one on the paper sheet', ev);
  select count(*) into n from measurement_to_propagate where event_id = ev;
  if n <> before then
    raise exception
      'FAIL: a note changed the propagation list from % to %, so saying a thing was written down counted as writing it down',
      before, n;
  end if;
  perform test_ok('a note cannot discharge a paper form: saying a measurement was written down is not writing it down');

  -- A note about one weighing rather than about the pick, which is the same
  -- distinction 0047 gave photographs and for the same reason.
  select count(*) into n from subject_note where about_event = ev;
  if n <> 1 then
    raise exception 'FAIL: a note about a weighing is not attached to it';
  end if;
  begin
    insert into note (subject_type, subject_id, body, about_event, by_user)
    values ('vessel', bin, 'wrong subject', ev,
            '00000000-0000-0000-0000-00000000a001');
    raise exception 'FAIL: a note on a bin claimed to be about a weighing of a pick';
  exception when others then
    if position('so one of the two is wrong' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a note that names an event must be filed under what that event was about');
  end;

  -- Reworded, not refiled.
  update note set body = 'fruit was mostly good, some shrivel on the north end'
   where subject_id = bin;
  select count(*) into n from note where subject_id = bin and edited_at is not null;
  if n <> 1 then
    raise exception 'FAIL: a reworded note does not say it was reworded';
  end if;
  perform test_ok('a note can be reworded and says that it was, because a note that changed silently is one nobody can rely on having read');

  begin
    update note set subject_id = pick where subject_id = bin;
    raise exception 'FAIL: a note was refiled onto a different subject';
  exception when others then
    if position('reworded but not refiled' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a note cannot be moved to another thing, because where it is filed is what it is about');
  end;

  begin
    perform add_note('node', pick, '   ');
    raise exception 'FAIL: an empty note was written';
  exception when others then
    if position('nothing here to say' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a note that says nothing is refused rather than stored as a blank line somebody has to read past');
  end;

  -- The cellar's notes are the cellar's business, the same as its photographs.
  perform test_act_as('00000000-0000-0000-0000-00000000a003');
  set local role authenticated;
  select count(*) into n from note;
  reset role;
  if n <> 0 then
    raise exception 'FAIL: a client can read notes that are not theirs';
  end if;
  perform test_ok('a client reads none of the winery notes, which is the same limit S-65 names for photographs');

  -- Back to the admin before anything else is written, which the block below
  -- needs and the first version of it did not do.
  perform test_act_as('00000000-0000-0000-0000-00000000a001');

  -- 0063, and the winemaker's own follow-up: "notes themselves could be tied to
  -- objects, if desired?" They are objects, so a note about a note is a reply
  -- and nothing had to be built for it.
  declare
    first_note uuid;
    reply      uuid;
  begin
    select id into first_note from note where subject_id = bin limit 1;
    reply := (add_note('note', first_note, 'agreed, the north end was worse') ->> 'id')::uuid;
    select count(*) into n from subject_note where subject_type = 'note' and subject_id = first_note;
    if n <> 1 then
      raise exception 'FAIL: a reply to a note is not attached to it';
    end if;
    -- And a photograph of what the note is talking about.
    perform attach_photo('note', first_note, 'notes/the-north-end.jpg');
    select count(*) into n from attachment where subject_type = 'note' and subject_id = first_note;
    if n <> 1 then
      raise exception 'FAIL: a photograph cannot hang off a note';
    end if;
    perform test_ok('a note is itself a thing, so a reply is a note about a note and a photograph can hang off one, and neither needed building');

    -- The resolver names it by what it says, because a subject name is for
    -- somebody picking it out of a list.
    if resolve_subject_name('note', first_note) is null then
      raise exception 'FAIL: a note has no name, so nothing can list it as a subject';
    end if;
    perform test_ok('a note and a photograph can be named by the resolver, which is what lets every screen that lists subjects list them');

    delete from attachment where subject_type = 'note';
    delete from note where id = reply;
  end;

  delete from note where subject_id in (pick, bin);
  delete from attachment where subject_type = 'node' and subject_id = pick;
  delete from event where subject_type = 'node' and subject_id = pick;
  delete from placement where node_id = pick;
  delete from node where id = pick;
  delete from vessel where name like 'ASRTNOTE%';
  update term set attributes = attributes - 'tare_lbs'
   where kind = 'vessel_type' and value = 'picking_bin';
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- the untyped floor, and typing something on it'; end $$;

-- 0064. The winemaker: "we might think of the untyped type here a la epistack."
--
-- This system already had that idea one level down. spec.md's untyped floor says
-- an unknown thing should "land, be addressable, and drive nothing until
-- somebody here types it", and the suite has proved it for operations since
-- early on. 0062 built the same floor for facts without noticing, and 0064 is
-- the other half: typing one.
--
-- **Everything below runs as a signed-in user rather than as the owner**, which
-- is not decoration. `confirm_note` shipped in 0064 using `alter table disable
-- trigger`, worked perfectly as `postgres`, and failed for every real caller
-- with "must be owner of table note". An assertion that runs as the owner would
-- have passed.
do $$
declare
  v      uuid;
  plain  uuid;
  typed  uuid;
  out_js jsonb;
  n      int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a002');   -- a cellar user
  select id into v from vessel limit 1;

  -- The floor. A note lands and drives nothing, which 0062 already asserts; what
  -- matters here is that it is also allowed to stay that way forever.
  plain := (add_note('vessel', v, 'gasket looked tired') ->> 'id')::uuid;
  select count(*) into n from untyped_note where id = plain;
  if n <> 1 then
    raise exception 'FAIL: an untyped note is not on the untyped floor';
  end if;
  select count(*) into n from typed_fact where note_id = plain;
  if n <> 0 then
    raise exception 'FAIL: an untyped note is being reported as a fact';
  end if;
  perform test_ok('a note with no kind is addressable and is not a fact, which is the untyped floor spec.md already describes for an arriving lot');

  -- Typing it keeps the words. That is the whole reason this is not a column.
  typed := (add_note('vessel', v, 'fruit was mostly good, a bit of shrivel on the north end') ->> 'id')::uuid;
  out_js := type_note(typed, 'fruit_condition', null, 'mostly good');
  if out_js ->> 'value' <> 'mostly good' then
    raise exception 'FAIL: typing gave back %', out_js ->> 'value';
  end if;
  select count(*) into n from typed_fact
   where note_id = typed and kind = 'fruit_condition'
     and value = 'mostly good'
     and body like '%north end%';
  if n <> 1 then
    raise exception 'FAIL: a typed fact lost either its value or the sentence it came from';
  end if;
  perform test_ok('typing a note gives it a kind and a value and keeps the prose, so what can be reported on and what somebody said are one object');

  select count(*) into n from untyped_note where id = typed;
  if n <> 0 then
    raise exception 'FAIL: a typed note is still on the untyped floor';
  end if;
  perform test_ok('a note leaves the untyped floor when somebody types it, which is the only way off it');

  -- The gate. A kind declares a shape and a typed note must carry it.
  begin
    perform type_note(plain, 'fruit_condition', 22.4, null);
    raise exception 'FAIL: a text kind accepted a number';
  exception when others then
    if position('is written out' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a kind that is written out refuses a number, so typing means something rather than pointing at a vocabulary row');
  end;

  begin
    perform type_note(plain, 'fruit_condition', null, null);
    raise exception 'FAIL: a note was typed with no value at all';
  exception when others then
    if position('has no value' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a note typed with no value is refused, because a kind without a value says less than the sentence did');
  end;

  begin
    perform type_note(plain, 'nothing_of_the_sort', null, 'x');
    raise exception 'FAIL: a note was typed with a kind that does not exist';
  exception when others then
    if position('nothing here is a kind of fact' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a kind nobody registered is refused, and adding one is a row rather than a change to this system');
  end;

  -- A value with no kind is a number nobody can interpret.
  begin
    insert into note (subject_type, subject_id, body, value_num, by_user)
    values ('vessel', v, 'twenty two point four', 22.4,
            '00000000-0000-0000-0000-00000000a002');
    raise exception 'FAIL: a value was stored with no kind to interpret it';
  exception when check_violation then
    perform test_ok('a value without a kind is refused, because a number nobody can interpret is worse than the sentence it came from');
  end;

  -- T0-4, which is the axiom this whole layer rests on.
  begin
    insert into note (subject_type, subject_id, body, provenance, by_user)
    values ('vessel', v, 'born confirmed', 'confirmed',
            '00000000-0000-0000-0000-00000000a002');
    raise exception 'FAIL: a fact was born confirmed';
  exception when others then
    if position('cannot be born confirmed' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a fact cannot be born confirmed, which is T0-4 in the place it now matters most');
  end;

  begin
    update note set provenance = 'confirmed' where id = typed;
    raise exception 'FAIL: confirmed was written by an ordinary update';
  exception when others then
    if position('confirming is its own act' in sqlerrm) = 0 then raise; end if;
    perform test_ok('confirmed cannot be written by an update, so who checked a fact is always recorded');
  end;

  -- **And the one that 0064 shipped broken.** As the owner this passed; as a
  -- signed-in user it failed with "must be owner of table note", because
  -- confirm_note got past its own guard by disabling the trigger.
  out_js := confirm_note(typed);
  if out_js ->> 'provenance' <> 'confirmed' then
    raise exception 'FAIL: confirming did not confirm';
  end if;
  select count(*) into n from typed_fact where note_id = typed and provenance = 'confirmed';
  if n <> 1 then
    raise exception 'FAIL: a confirmed fact does not read as confirmed';
  end if;
  perform test_ok('a signed-in user can confirm a fact, which the first version could not because it disabled a trigger it did not own');

  -- The confirming is itself a note on the fact, which 0063 is what allows.
  select count(*) into n from note where subject_type = 'note' and subject_id = typed;
  if n <> 1 then
    raise exception 'FAIL: confirming left no record of who did it';
  end if;
  perform test_ok('confirming writes a note on the fact, so who checked it is in the record rather than in a column nobody displays');

  -- Confirming twice is not a failure and must not read like one.
  out_js := confirm_note(typed);
  if (out_js ->> 'already')::boolean is not true then
    raise exception 'FAIL: confirming an already confirmed fact did not say so';
  end if;
  perform test_ok('confirming something already confirmed says so and changes nothing, rather than failing or recording it twice');

  begin
    perform confirm_note(plain);
    raise exception 'FAIL: an untyped note was confirmed';
  exception when others then
    if position('no fact in it to confirm' in sqlerrm) = 0 then raise; end if;
    perform test_ok('an untyped note cannot be confirmed, because there is no claim in it to check');
  end;

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  delete from note where subject_type = 'note';
  delete from note where id in (plain, typed);
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- sampling a place, and the readings that come off it'; end $$;

-- 0067. "Samples should be able to be assigned to vineyards and blocks and
-- varieties, both as a sampling button and in the vineyard button."
--
-- Two of the three were subjects already. The third is the interesting one: a
-- variety is a word, and what somebody actually samples is a variety in a block,
-- which is a planting and has been a row since 0039.
do $$
declare
  vy    uuid := '00000000-0000-0000-0000-00000000d001';
  bk    uuid := '00000000-0000-0000-0000-00000000d002';
  pl    uuid;
  ev    uuid;
  note1 uuid;
  out_js jsonb;
  n     int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');

  insert into vineyard (id, name) values (vy, 'Assert Vineyard');
  insert into block (id, vineyard_id, name) values (bk, vy, 'Assert Block');
  insert into planting (block_id, variety_id)
    values (bk, term_id('variety', 'riesling'))
  returning id into pl;

  -- A planting resolves to something a person can pick out of a list, which is
  -- the whole reason it is registered rather than just being a row.
  if resolve_subject_name('planting', pl) not like '%Assert Block%' then
    raise exception 'FAIL: a planting does not name the block it is in, so nobody could pick the right one';
  end if;
  if resolve_subject_name('planting', pl) not like '%Riesling%' then
    raise exception 'FAIL: a planting does not name its variety';
  end if;
  perform test_ok('a variety in a block is a subject you can sample, and it names the block, because which Riesling is the whole question');

  -- All three, and a refusal for the fourth.
  perform take_sample('vineyard', vy);
  perform take_sample('block', bk);
  out_js := take_sample('planting', pl, null, '50 berries off the north end');
  ev := (out_js ->> 'event_id')::uuid;
  select count(*) into n from sample where subject_id in (vy, bk, pl);
  if n <> 3 then
    raise exception 'FAIL: three things were sampled and % samples exist', n;
  end if;
  perform test_ok('a vineyard, a block and a variety in a block can each be sampled, which is the three the winemaker asked for');

  begin
    perform take_sample('variety', term_id('variety', 'riesling'));
    raise exception 'FAIL: a word was sampled';
  exception when others then
    if position('nothing in this system is a variety' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a variety on its own cannot be sampled, because a variety is a word and sampling a word is not a thing somebody does. S-76');
  end;

  begin
    perform take_sample('block', '00000000-0000-0000-0000-0000000000ff');
    raise exception 'FAIL: a block that does not exist was sampled';
  exception when others then
    if position('to sample' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a sample of something that is not there is refused, which is the only check available because event.subject_id cannot be a foreign key');
  end;

  -- **The one that matters.** A sample carries no readings of its own.
  select count(*) into n from event
   where id = ev and (data ? 'brix' or data ? 'ph' or data ? 'value' or data ? 'readings');
  if n <> 0 then
    raise exception 'FAIL: a sample stored a reading of its own, which is nine columns for four forms all over again';
  end if;
  select readings into n from sample where event_id = ev;
  if n <> 0 then
    raise exception 'FAIL: a fresh sample claims % readings', n;
  end if;
  perform test_ok('a sample stores no readings, because the readings are typed notes about it and a column per parameter is the thing 0064 exists to avoid');

  -- The readings, as notes typed against the sample.
  note1 := (add_note('planting', pl, 'off the north end', ev) ->> 'id')::uuid;
  perform type_note(note1, 'fruit_condition', null, 'mostly good');
  select readings into n from sample where event_id = ev;
  if n <> 1 then
    raise exception 'FAIL: a reading typed against a sample shows as % readings', n;
  end if;
  perform test_ok('a reading is a note typed against the sample, so one sample carries a condition and a Brix and a remark without a column for any of them');

  -- And an untyped note about the sample is not a reading, which is the floor
  -- doing its job in the place it will matter most.
  perform add_note('planting', pl, 'wind picked up while we were out there', ev);
  select readings into n from sample where event_id = ev;
  if n <> 1 then
    raise exception 'FAIL: talking about the weather counted as a reading';
  end if;
  perform test_ok('an untyped note about a sample is not a reading, so a remark about the weather never becomes a measurement');

  delete from note where about_event = ev;
  delete from event where subject_id in (vy, bk, pl);
  delete from planting where id = pl;
  delete from block where id = bk;
  delete from vineyard where id = vy;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- reaching the sign-up page is not the same as working here'; end $$;

-- 0068. "How could I do this so my interns don't need to download an app besides
-- the vitae springs app?" They do not have to: it is a web page they add to
-- their home screen. What stood in the way is that the only route to it is
-- Tailscale, and getting off Tailscale means being reachable by strangers.
--
-- S-78 is what made that unsafe: `claim_account` handed a `cellar` role to any
-- identity that asked, which `is_facility_user()` reads as somebody who works
-- here. On a private tailnet that is right. Reachable from the internet it is
-- open registration over two custom crush clients' wine.
do $$
declare
  out_js jsonb;
  inv    text;
  n      int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');   -- the admin

  -- Only an administrator lets somebody in. A cellar hand who could issue an
  -- invite could admit their own second account, which is the whole point.
  perform test_act_as('00000000-0000-0000-0000-00000000a002');   -- a cellar user
  begin
    perform make_invite('cellar', 'should not work');
    raise exception 'FAIL: a cellar user issued an invite';
  exception when others then
    if position('only an administrator' in sqlerrm) = 0 then raise; end if;
    perform test_ok('only an administrator hands out an invite, because anybody who can issue one can admit themselves twice');
  end;

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  out_js := make_invite('cellar', 'Assert intern');
  inv := out_js ->> 'code';
  if length(inv) <> 6 then
    raise exception 'FAIL: an invite code is % characters', length(inv);
  end if;
  -- No I, O, 0 or 1, because somebody reads this out across a crush pad.
  if inv ~ '[IO01]' then
    raise exception 'FAIL: the code % contains a character that is read wrong out loud', inv;
  end if;
  perform test_ok('an invite is six characters an administrator can read out, with no letter anybody mishears as a digit');

  -- **The gate itself.** There is exactly one signature, so there is no
  -- unguarded call left to make.
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'claim_account';
  if n <> 1 then
    raise exception
      'FAIL: there are % versions of claim_account, and one of them is a way past the invite', n;
  end if;
  perform test_ok('claim_account has one signature, so the version that needed no invite is gone rather than merely unused');

  -- An invite may be used once, which is checked here rather than by anything
  -- in the client, because the client is the half a stranger does not run.
  update invite set used_by = '00000000-0000-0000-0000-00000000a002',
                    used_at = now()
   where invite.code = inv;
  select count(*) into n from invite where invite.code = inv and used_at is not null;
  if n <> 1 then
    raise exception 'FAIL: an invite cannot be marked used';
  end if;
  perform test_ok('an invite records who used it and when, so who let somebody in survives the person forgetting');

  -- A used one is kept rather than deleted. It is the only record there will
  -- ever be of who admitted whom.
  select count(*) into n from invite where invite.code = inv;
  if n <> 1 then
    raise exception 'FAIL: using an invite destroyed the record of it';
  end if;
  perform test_ok('a used invite is kept, because who let somebody in is worth more than the row it costs');

  -- A cellar hand cannot read the invite list either: a readable code is an
  -- issuable code.
  perform test_act_as('00000000-0000-0000-0000-00000000a002');
  set local role authenticated;
  select count(*) into n from invite;
  reset role;
  if n <> 0 then
    raise exception 'FAIL: a cellar user can read % invite codes', n;
  end if;
  perform test_ok('a cellar user reads no invite codes, because a code they can read is a code they can use');

  -- 0070. A source assertion, which this suite has few of and which earns its
  -- place here: the difference between a guessable code and an unguessable one
  -- is invisible in the output. Every code `random()` produces looks exactly
  -- like every code `gen_random_bytes` produces, which is A13 in its purest
  -- form, so the only place the difference is visible is the definition.
  if pg_get_functiondef('make_invite(user_role, text)'::regprocedure) ~ 'random\(\)' then
    raise exception
      'FAIL: make_invite builds a credential out of random(), which is a sequence somebody holding one code can continue';
  end if;
  if pg_get_functiondef('make_invite(user_role, text)'::regprocedure) !~ 'gen_random_bytes' then
    raise exception
      'FAIL: make_invite no longer draws from a cryptographic source';
  end if;
  perform test_ok('an invite code comes from a cryptographic source, because one code should not be a step toward the next');

  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  delete from invite where note = 'Assert intern';
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

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a wine says its colour, and a barrel remembers'; end $$;

-- 0071 through 0076. The winemaker asked for red and white barrels and then
-- said the better version: the colour belongs to the wine, and the barrel's own
-- colour is derived from what has been in it.
--
-- These assertions are about the derivation, because the derivation is the
-- whole feature. Nothing here refuses a fill and that is deliberate: "warn and
-- let through because somebody could put the wine in the barrel before using
-- the app". A refusal assertion would be asserting a decision that was made the
-- other way.
--
-- **Every placement carries an explicit time.** Everything inside one
-- transaction shares a single now(), so a sequence built on the default would
-- put the recondition and every fill on the same instant, and this would be
-- measuring the tie-break in 0076 rather than the rule. Days are counted
-- backwards from now, and the one deliberate tie is marked where it happens.
do $$
declare
  b_white uuid := '00000000-0000-0000-0000-0000000c0001';
  b_red   uuid := '00000000-0000-0000-0000-0000000c0002';
  l_red   uuid := '00000000-0000-0000-0000-0000000c0101';
  l_white uuid := '00000000-0000-0000-0000-0000000c0102';
  l_rose  uuid := '00000000-0000-0000-0000-0000000c0103';
  l_child uuid := '00000000-0000-0000-0000-0000000c0104';
  l_mixed uuid := '00000000-0000-0000-0000-0000000c0105';
  l_bare  uuid := '00000000-0000-0000-0000-0000000c0106';
  a_tank  uuid;
  got     text;
  js      jsonb;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  select id into a_tank from vessel where type_id = term_id('vessel_type','tank') limit 1;

  insert into vessel (id, type_id, name, capacity_l) values
    (b_white, term_id('vessel_type','barrel'), 'C7 clean',   228),
    (b_red,   term_id('vessel_type','barrel'), 'C7 stained', 228);

  insert into node (id, stage, name, vintage) values
    (l_red,   'maturation', 'C7 a red',    2025),
    (l_white, 'maturation', 'C7 a white',  2025),
    (l_rose,  'maturation', 'C7 a rose',   2025),
    (l_child, 'maturation', 'C7 a child',  2025),
    (l_mixed, 'maturation', 'C7 a blend',  2025),
    (l_bare,  'maturation', 'C7 untyped',  2025);

  -- **The vocabulary carries the rule.** Which colours stain is a column on a
  -- row rather than a list inside a function, so a fifth colour is an insert
  -- and a change of mind about orange is an update.
  if not colour_stains(term_id('wine_colour','red')) then
    raise exception 'FAIL: red does not stain';
  end if;
  if colour_stains(term_id('wine_colour','rose')) then
    raise exception 'FAIL: rose stains, and the winemaker said it does not';
  end if;
  if colour_stains(term_id('wine_colour','white'))
     or colour_stains(term_id('wine_colour','orange')) then
    raise exception 'FAIL: a colour that should not stain does';
  end if;
  perform test_ok('which colours stain is a property of the vocabulary, so a fifth colour is an insert rather than an edit to a function');

  -- 0074, and the reason it exists. A predicate that answers null where the
  -- caller expects false permits whatever it guards, which is ledger A25.
  if colour_stains(null) is not false then
    raise exception 'FAIL: colour_stains(null) is %, and a caller writing "not colour_stains(x)" would get nothing', colour_stains(null);
  end if;
  perform test_ok('an unknown colour answers false rather than null, so a caller asking whether it does not stain gets an answer instead of silence');

  perform set_colour(l_red, 'red');
  perform set_colour(l_white, 'white');
  perform set_colour(l_rose, 'rose');

  -- **A colour told once is inherited.** A press cut of a red lot is red and so
  -- is everything racked out of it. Copying the value down at each step would be
  -- storing what is derived, which is C-3, so only the told value is stored.
  insert into lineage (parent_id, child_id, fraction) values (l_red, l_child, 1.0);
  if lot_colour(l_child) <> term_id('wine_colour','red') then
    raise exception 'FAIL: a child of a red lot did not inherit red';
  end if;
  if (select colour_id from node where id = l_child) is not null then
    raise exception 'FAIL: inheriting a colour wrote it onto the child, which is C-3';
  end if;
  perform test_ok('a lot inherits its colour from its parents and nothing is copied down the lineage, so saying it once on a pick is enough');

  -- 0075. Two parents that disagree are a question rather than an answer.
  -- Deciding that red wins would be inventing a winemaking rule nobody stated,
  -- and the first version of this picked whichever colour sorted first by uuid.
  insert into lineage (parent_id, child_id, fraction) values
    (l_red,   l_mixed, 0.5),
    (l_white, l_mixed, 0.5);
  if lot_colour(l_mixed) is not null then
    raise exception 'FAIL: a blend of a red and a white parent was given a colour';
  end if;
  perform test_ok('a lot blended from parents of different colours has no colour until somebody says, because red winning would be a rule nobody stated');

  -- The derivation follows the lineage rather than the column.
  insert into placement (node_id, vessel_id, volume_l, from_at)
    values (l_child, b_white, 200, now() - interval '9 days');
  select colour into got from barrel_colour where id = b_white;
  if got <> 'red' then
    raise exception 'FAIL: a barrel holding an inherited red reads %', got;
  end if;
  perform test_ok('a barrel goes red from a lot that inherited red, so the derivation follows the lineage rather than the column');

  update placement set to_at = now() - interval '8 days'
   where vessel_id = b_white and to_at is null;
  delete from lineage where child_id = l_child;

  -- Rose does not turn a white barrel red. This is the one rule in this feature
  -- that is pure winery practice and could not be guessed from anything else in
  -- the schema.
  insert into placement (node_id, vessel_id, volume_l, from_at)
    values (l_rose, b_red, 200, now() - interval '7 days');
  select colour into got from barrel_colour where id = b_red;
  if got <> 'white' then
    raise exception 'FAIL: rose turned a barrel %, and it should turn it nothing', got;
  end if;
  perform test_ok('rose leaves a barrel white, because it goes in either and turns neither');

  update placement set to_at = now() - interval '6 days'
   where vessel_id = b_red and to_at is null;
  insert into placement (node_id, vessel_id, volume_l, from_at)
    values (l_red, b_red, 200, now() - interval '5 days');
  select colour into got from barrel_colour where id = b_red;
  if got <> 'red' then
    raise exception 'FAIL: red in a barrel left it %', got;
  end if;
  perform test_ok('red in a barrel makes it a red barrel, which is the whole of what was asked for');

  -- **A barrel that has held an untyped lot is unknown, not white.** Calling it
  -- white would be a default permitting the exact mistake this exists to
  -- prevent, which is the A25 class: an absent answer read as a favourable one.
  insert into placement (node_id, vessel_id, volume_l, from_at)
    values (l_bare, b_white, 100, now() - interval '4 days');
  select colour into got from barrel_colour where id = b_white;
  if got <> 'unknown' then
    raise exception 'FAIL: a barrel holding a lot nobody typed reads %, and white would be a guess in the caller''s favour', got;
  end if;
  perform test_ok('a barrel that has held a lot nobody typed is unknown rather than white, because an absent colour is not evidence of a harmless one');

  -- The worklist is the catching mechanism, so it has to actually contain it.
  if not exists (select 1 from lot_without_colour where id = l_bare) then
    raise exception 'FAIL: an untyped lot is not on the list of untyped lots';
  end if;
  if exists (select 1 from lot_without_colour where id = l_red) then
    raise exception 'FAIL: a lot that said its colour is still on the list';
  end if;
  perform test_ok('the list of lots with no colour holds exactly the lots with no colour, because nothing refuses one and the list is the only thing that catches it');

  -- **Reconditioning.** Told, not derived, and the one refusal in this feature:
  -- a barrel that has held red is white again because somebody did something to
  -- it, and which thing is the whole of the evidence.
  update placement set to_at = now() - interval '3 days'
   where vessel_id = b_red and to_at is null;

  begin
    perform recondition_barrel(b_red, '');
    raise exception 'FAIL: a barrel was reconditioned with no method';
  exception when others then
    if position('say what was done to it' in sqlerrm) = 0 then raise; end if;
    perform test_ok('reconditioning with no method is refused, because an event saying a barrel was treated and not saying how is paperwork for a thing that may not have happened');
  end;

  begin
    perform recondition_barrel(a_tank, 'deep clean');
    raise exception 'FAIL: a tank was reconditioned';
  exception when others then
    if position('reconditioning is a thing done to a barrel' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a tank cannot be reconditioned, because stainless does not hold colour and the word would mean nothing');
  end;

  -- The event lands at now(), which is after every placement above.
  perform recondition_barrel(b_red, 'retoasted');
  select colour into got from barrel_colour where id = b_red;
  if got <> 'white' then
    raise exception 'FAIL: a reconditioned barrel still reads %', got;
  end if;
  perform test_ok('a reconditioned barrel is white again, and only a recorded process does that');

  -- 0076, deliberately at the recondition's own instant: a fill recorded at the
  -- same moment as the treatment counts as after it, because the other reading
  -- calls a barrel with red in it white. This is the one placement in this block
  -- that uses the default time, and it is the tie.
  insert into placement (node_id, vessel_id, volume_l) values (l_red, b_red, 200);
  select colour into got from barrel_colour where id = b_red;
  if got <> 'red' then
    raise exception 'FAIL: red recorded at the same instant as the recondition left the barrel %, and a tie has to go to the barrel', got;
  end if;
  perform test_ok('a fill recorded at the same instant as a recondition counts as after it, because calling a barrel with red in it white is the one wrong answer that costs a wine');

  -- **The catch.** White sitting in a red barrel, which nothing refused.
  update placement set to_at = now() where vessel_id = b_red and to_at is null;
  insert into placement (node_id, vessel_id, volume_l) values (l_white, b_red, 200);
  if not exists (select 1 from white_in_a_red_barrel where vessel_id = b_red) then
    raise exception 'FAIL: a white lot in a red barrel is not on the list of white lots in red barrels';
  end if;
  perform test_ok('a white lot in a red barrel appears on the worklist, which is the catch, since the winemaker asked for a warning rather than a refusal');

  -- An untyped lot is not on that list. It is a different question with a
  -- different answer, and running the two together would turn a list somebody
  -- clears into a list somebody ignores.
  if exists (select 1 from white_in_a_red_barrel where node_id = l_bare) then
    raise exception 'FAIL: a lot with no colour is being reported as a white in a red barrel';
  end if;
  perform test_ok('a lot with no colour is not reported as a white in a red barrel, because not knowing is a different question from knowing it is wrong');

  -- The same question, asked the way a screen asks it.
  js := barrel_warning(b_red, l_white);
  if not (js ->> 'warn')::boolean then
    raise exception 'FAIL: the kernel says a white going into a red barrel is not worth a word';
  end if;
  js := barrel_warning(b_red, l_red);
  if (js ->> 'warn')::boolean then
    raise exception 'FAIL: the kernel warns about red going into a red barrel';
  end if;
  js := barrel_warning(b_red, l_bare);
  if not (js ->> 'warn')::boolean then
    raise exception 'FAIL: the kernel says nothing about an untyped lot going into a red barrel';
  end if;
  js := barrel_warning(a_tank, l_white);
  if (js ->> 'warn')::boolean then
    raise exception 'FAIL: the kernel warns about a tank, which cannot hold colour';
  end if;
  perform test_ok('the kernel answers whether a fill is worth a word, so a second periphery asking gets the same answer as the first and neither works it out for itself');

  -- 0077. **A barrel can arrive red.** The winemaker buys used barrels, red and
  -- white neutral, and a barrel that has held three vintages of somebody else's
  -- Pinot has no placements here at all. Deriving from an empty history gave the
  -- one answer that could ruin a wine.
  declare
    bought uuid := '00000000-0000-0000-0000-0000000c0003';
  begin
    insert into vessel (id, type_id, name, capacity_l)
      values (bought, term_id('vessel_type','barrel'), 'C7 bought used', 228);

    select colour into got from barrel_colour where id = bought;
    if got <> 'white' then
      raise exception 'FAIL: a barrel with no history and nothing said reads %', got;
    end if;

    perform declare_barrel_colour(bought, 'red', 'bought from a red house');
    select colour into got from barrel_colour where id = bought;
    if got <> 'red' then
      raise exception 'FAIL: a barrel declared red reads %', got;
    end if;
    perform test_ok('a barrel bought used can be told it arrived red, because nothing in its placements here could ever say so');

    -- Red outranks unknown. A declared red barrel holding a lot nobody typed is
    -- still red: unknown means nothing says red, and something does.
    insert into placement (node_id, vessel_id, volume_l) values (l_bare, bought, 100);
    select colour into got from barrel_colour where id = bought;
    if got <> 'red' then
      raise exception 'FAIL: an untyped lot in a declared red barrel made it %', got;
    end if;
    perform test_ok('a barrel declared red stays red while holding a lot nobody typed, because unknown means nothing says red and something does');

    -- **A declaration is not a process.** Saying a barrel is white after it has
    -- held red here would be the way around the one rule the winemaker stated
    -- twice: red barrels do not turn white unless somebody does something to
    -- them.
    begin
      perform declare_barrel_colour(bought, 'white');
      raise exception 'FAIL: a red barrel was declared white';
    exception when check_violation then
      perform test_ok('a barrel that has held red cannot be declared white, because a declaration is not a shave, a retoast or a deep clean');
    end;

    -- And the vocabularies stay apart. A wine is red, orange, rose or white; a
    -- barrel has either held something that stains or it has not.
    begin
      perform declare_barrel_colour(bought, 'rose');
      raise exception 'FAIL: a barrel was declared rose';
    exception when others then
      if position('a barrel is red or white' in sqlerrm) = 0 then raise; end if;
      perform test_ok('a barrel cannot be declared rose, because what a wine is and what it does to oak are two different vocabularies');
    end;

    -- A declared white barrel still turns red the moment red goes in it. This is
    -- the half that must not be given up in exchange for the told floor.
    update placement set to_at = now() where vessel_id = bought and to_at is null;
    perform recondition_barrel(bought, 'shaved');
    insert into placement (node_id, vessel_id, volume_l) values (l_red, bought, 100);
    select colour into got from barrel_colour where id = bought;
    if got <> 'red' then
      raise exception 'FAIL: red in a reconditioned barrel left it %', got;
    end if;
    perform test_ok('what somebody said is where the derivation starts and never where it stops, so a barrel told it is white still goes red the next time red goes in it');
  end;

  -- 0078. The wine in a vessel is somewhere you can go. The screen behind this
  -- is the answer to "I also need a way to edit (add/append only is fine) wine
  -- in vessels, like to add the color", and it needs one read rather than four,
  -- because a lot assembled out of pieces in a client is how two clients end up
  -- disagreeing about what a lot is.
  declare
    d record;
    n_rows int;
  begin
    select * into d from lot_detail where id = l_child limit 1;
    if d.id is null then
      raise exception 'FAIL: a lot is not in lot_detail';
    end if;

    -- The colour comes through the lineage, and the screen has to be able to
    -- tell an inherited answer from one somebody gave about this lot: one is an
    -- answer and the other is an answer nobody gave.
    insert into lineage (parent_id, child_id, fraction) values (l_red, l_child, 1.0);
    select * into d from lot_detail where id = l_child limit 1;
    if d.colour <> 'red' then
      raise exception 'FAIL: lot_detail says a child of a red lot is %', coalesce(d.colour, 'nothing');
    end if;
    if d.colour_told then
      raise exception 'FAIL: lot_detail claims an inherited colour was told about this lot';
    end if;

    perform set_colour(l_child, 'red');
    select * into d from lot_detail where id = l_child limit 1;
    if not d.colour_told then
      raise exception 'FAIL: lot_detail does not notice a colour told about the lot itself';
    end if;
    perform test_ok('one read says what colour a lot is and whether anybody said it about this lot or it came down the lineage, which is the difference a screen has to show');

    -- A lot in two vessels is two rows. Flattening it would be inventing a
    -- single answer to a question that has two.
    -- Both barrels are holding something from the assertions above, and a
    -- vessel holds one lot at a time.
    update placement set to_at = now()
     where to_at is null and (node_id = l_child or vessel_id in (b_white, b_red));
    insert into placement (node_id, vessel_id, volume_l) values (l_child, b_white, 100);
    insert into placement (node_id, vessel_id, volume_l) values (l_child, b_red, 100);
    select count(*) into n_rows from lot_detail where id = l_child and vessel_id is not null;
    if n_rows <> 2 then
      raise exception 'FAIL: a lot standing in two vessels came back as % row(s)', n_rows;
    end if;
    perform test_ok('a lot standing in two vessels is two rows, because one row would be a single answer to a question that has two');

    delete from lineage where child_id = l_child;
  end;

  -- T0-2, stated as a check rather than as a comment. A column caching this is
  -- exactly what C-3 is about.
  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'vessel'
       and column_name in ('colour', 'colour_id', 'is_red', 'barrel_colour')
  ) then
    raise exception 'FAIL: vessel carries a colour column, and a barrel colour is derived';
  end if;
  perform test_ok('no column on vessel caches a barrel colour, so the derivation cannot drift from what the barrel has actually held');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a room says which way it is held'; end $$;

-- 0079. The winemaker wants the map to draw rooms under cold control as light
-- negative space and heated rooms as the inverse. `location` said a room was
-- controlled and at what, and never which direction, and **no temperature can
-- settle it**: this winery's one controlled room sits at 15.5C, which is
-- cooling in September and heating in January. So a room says it.
do $$
declare
  r      uuid := '00000000-0000-0000-0000-0000000d0001';
  got    record;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');

  insert into location (id, name) values (r, 'C8 a room');

  select * into got from room_climate where id = r;
  if got.mode <> 'off' or got.controlled then
    raise exception 'FAIL: a new room is % and controlled is %', got.mode, got.controlled;
  end if;
  perform test_ok('a room nobody has said anything about is held no way at all, rather than defaulting to one');

  -- Saying which way it is held says it is held. The alternative is a refusal
  -- telling somebody to go and tick a box first, which is a refusal about
  -- bookkeeping rather than about the winery.
  perform set_room_climate(r, 'cooling', 4);
  select * into got from room_climate where id = r;
  if got.mode <> 'cooling' or not got.controlled or got.ambient_c <> 4 then
    raise exception 'FAIL: a room told it is cooling reads % / % / %',
      got.mode, got.controlled, got.ambient_c;
  end if;
  perform test_ok('saying which way a room is held also says it is held, because those were always one fact');

  -- The temperature survives a later change of direction. A room that swings
  -- from cooling to heating across a season keeps the number somebody typed.
  perform set_room_climate(r, 'heating', null);
  select * into got from room_climate where id = r;
  if got.mode <> 'heating' or got.ambient_c <> 4 then
    raise exception 'FAIL: changing direction lost the temperature: % at %',
      got.mode, got.ambient_c;
  end if;
  perform test_ok('changing which way a room is held keeps the temperature somebody typed, because the season changes and the setting does not');

  begin
    perform set_room_climate(r, 'chilly');
    raise exception 'FAIL: a room was held chilly';
  exception when others then
    if position('a room is held cooling, heating, or off' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a room cannot be held in a direction that is not one of the three, because the vocabulary is the vessel''s and there is no reason for a second one');
  end;

  -- The constraint, not the function. A direction written straight into the
  -- table without control is the shape the function exists to prevent, and a
  -- rule that only the function enforces is a rule anything else can walk past.
  begin
    update location set mode = 'cooling', controlled = false where id = r;
    raise exception 'FAIL: a room is held cooling and is not controlled';
  exception when check_violation then
    perform test_ok('a room held in a direction is controlled, enforced by the table rather than by the one function that writes it');
  end;
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a borrowed bin is not ours'; end $$;

-- 0081. The winemaker registered five bins on loan from Pearlstaad, and every
-- screen said they were his. What he typed was recorded correctly: the bins
-- carried `borrowed` and `on_loan_from`. `facility_owned` was `owner_id is
-- null`, a grower is not a party and never gets an owner_id, so the unticked
-- box and the ticked box produced the same visible answer. **That is A13 in its
-- purest form**: a control that says not ours, a database that agrees, and every
-- surface saying ours anyway.
do $$
declare
  ours     uuid := '00000000-0000-0000-0000-0000000e0001';
  lent     uuid := '00000000-0000-0000-0000-0000000e0002';
  clients  uuid := '00000000-0000-0000-0000-0000000e0003';
  a_client uuid;
  got      record;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  select id into a_client from party where kind = 'client' and active limit 1;

  insert into vessel (id, type_id, name, capacity_l, attributes) values
    (ours, term_id('vessel_type','picking_bin'), 'C9 ours', 400, '{}'::jsonb),
    (lent, term_id('vessel_type','picking_bin'), 'C9 lent', 400,
     '{"borrowed": true, "on_loan_from": "Pearlstaad"}'::jsonb);
  insert into vessel (id, type_id, name, capacity_l, owner_id) values
    (clients, term_id('vessel_type','picking_bin'), 'C9 theirs', 400, a_client);

  select * into got from vessel_state where id = ours;
  if not got.facility_owned or got.owner_name is not null then
    raise exception 'FAIL: a bin nobody else owns reads owner % / facility %',
      got.owner_name, got.facility_owned;
  end if;
  perform test_ok('a bin nobody lent and nobody owns is this winery''s, which is the case the other two are measured against');

  -- The one he hit.
  select * into got from vessel_state where id = lent;
  if got.facility_owned then
    raise exception 'FAIL: a bin on loan from a grower reads as facility owned, which is what the unticked box was meant to prevent';
  end if;
  if got.owner_name is distinct from 'Pearlstaad' then
    raise exception 'FAIL: a borrowed bin says it belongs to %', coalesce(got.owner_name, 'nobody');
  end if;
  perform test_ok('a bin on loan from a grower is not this winery''s and says whose it is, because a grower is not a party and the name is the only place it lives');

  -- And the other representation, which always worked and must keep working: a
  -- client is a party, so their equipment has an owner_id.
  select * into got from vessel_state where id = clients;
  if got.facility_owned or got.owner_name is null then
    raise exception 'FAIL: a client''s own bin reads owner % / facility %',
      got.owner_name, got.facility_owned;
  end if;
  perform test_ok('a client''s own equipment still reads as theirs through the party, so the two ways of not being ours both answer the same question');

  -- Empty and borrowed is owed back. The point of the whole flag: empty is not
  -- the same as available.
  if not exists (select 1 from bin_to_return where vessel_id = lent and owed_to = 'Pearlstaad') then
    raise exception 'FAIL: an empty borrowed bin is not owed back to the grower who lent it';
  end if;
  if exists (select 1 from bin_to_return where vessel_id = ours) then
    raise exception 'FAIL: a bin of ours is owed back to somebody';
  end if;
  perform test_ok('an empty borrowed bin is owed back by name and one of ours is not, because empty is not the same as available');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- vineyard, juice and wine are three kinds of sampling'; end $$;

-- 0082 and 0083. The winemaker: "vineyard sampling and juice sampling and wine
-- sampling should all be easily separated. Vineyard sampling is watching the
-- fruit over time to see when to pick... I want to have filters to separate
-- them so you don't have to navigate through previous vintages wine to find the
-- only things we're really taking samples of often."
--
-- **Nobody says which kind.** The subject answers it: a vineyard, block or
-- planting is fruit on the vine, and a vessel is juice or wine depending on
-- what was in it. Asking for a category as well would be asking somebody to
-- type an answer the database already has.
do $$
declare
  a_block   uuid;
  ferment   uuid := '00000000-0000-0000-0000-0000000f0001';
  barrel    uuid := '00000000-0000-0000-0000-0000000f0002';
  young     uuid := '00000000-0000-0000-0000-0000000f0101';
  old       uuid := '00000000-0000-0000-0000-0000000f0102';
  s_vine    uuid;
  s_juice   uuid;
  s_wine    uuid;
  got       text;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  select id into a_block from block limit 1;

  insert into vessel (id, type_id, name, capacity_l) values
    (ferment, term_id('vessel_type','tank'),   'CA ferment', 1000),
    (barrel,  term_id('vessel_type','barrel'), 'CA barrel',   228);

  insert into node (id, stage, name, vintage) values
    (young, 'ferment',    'CA this year', 2026),
    (old,   'maturation', 'CA last year', 2024);

  insert into placement (node_id, vessel_id, volume_l, from_at) values
    (young, ferment, 900, now() - interval '2 days'),
    (old,   barrel,  228, now() - interval '400 days');

  s_vine  := (take_sample('block', a_block) ->> 'event')::uuid;
  s_juice := (take_sample('vessel', ferment) ->> 'event')::uuid;
  s_wine  := (take_sample('vessel', barrel) ->> 'event')::uuid;

  select kind into got from sample where event_id = s_vine;
  if got <> 'vineyard' then
    raise exception 'FAIL: a sample of a block is %', got;
  end if;
  perform test_ok('a sample of a block is vineyard sampling, because what was sampled answers which kind it is and nobody has to say');

  select kind into got from sample where event_id = s_juice;
  if got <> 'juice' then
    raise exception 'FAIL: a sample of a ferment is %', got;
  end if;
  select kind into got from sample where event_id = s_wine;
  if got <> 'wine' then
    raise exception 'FAIL: a sample of a barrel of last year''s wine is %', got;
  end if;
  perform test_ok('a ferment gives juice and a barrel of an older vintage gives wine, which is the separation the filter is built on');

  -- **The lot as it was, not as it is.** A barrel sampled in March and refilled
  -- in October has two answers and only one of them is about the sample.
  if (select lot_name from sample where event_id = s_wine) <> 'CA last year' then
    raise exception 'FAIL: a sample does not name the lot that was in the vessel';
  end if;
  if (select vintage from sample where event_id = s_wine) <> 2024 then
    raise exception 'FAIL: a sample does not carry the vintage of what was sampled, which is the thing being filtered past';
  end if;

  update placement set to_at = now() where vessel_id = barrel and to_at is null;
  insert into placement (node_id, vessel_id, volume_l) values (young, barrel, 200);
  if (select lot_name from sample where event_id = s_wine) <> 'CA last year' then
    raise exception 'FAIL: refilling a barrel rewrote what an old sample was of';
  end if;
  perform test_ok('a sample names the lot that was in the vessel when it was taken, so refilling a barrel does not rewrite what last spring''s sample was of');

  -- The picker and the filter read one rule. Two derivations of the same rule
  -- is how a list that hides last vintage's barrels keeps offering them.
  if (select kind from sample_target where subject_id = ferment) <> 'juice' then
    raise exception 'FAIL: the picker calls a ferment something other than juice';
  end if;
  if (select kind from sample_target where subject_id = a_block) <> 'vineyard' then
    raise exception 'FAIL: the picker calls a block something other than vineyard';
  end if;
  perform test_ok('what can be sampled carries the same kind as what was sampled, so the picker and the filter cannot disagree about whether a thing is juice or wine');

  -- An empty vessel is not in the picker at all, and a sample of one is not
  -- quietly filed under a kind.
  if exists (select 1 from sample_target t
              join vessel v on v.id = t.subject_id
             where t.subject_type = 'vessel'
               and not exists (select 1 from placement pl
                                where pl.vessel_id = v.id and pl.to_at is null)) then
    raise exception 'FAIL: an empty vessel is offered as something to sample';
  end if;
  perform test_ok('an empty vessel is not offered as something to sample, because there is nothing in it to put in a jar');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a stack of bins is inventory'; end $$;

-- 0085. "Also batch add for picking bins. I'd rather just inventory and add as
-- they don't really differ." The batch existed and only ever created bins onto
-- a pick, so the fleet got registered in dribs during harvest, which is the
-- worst possible time.
do $$
declare
  out_js jsonb;
  bin_t  uuid;
  n      int;
  before int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  select id into bin_t from term
   where kind = 'vessel_type'
     and coalesce((attributes ->> 'intake_bin')::boolean, false)
   limit 1;

  select count(*) into before from vessel where name ~ '^CB\s*\d+$';

  out_js := register_bins(4, bin_t, 'CB');
  if (out_js ->> 'count')::int <> 4 then
    raise exception 'FAIL: registering four bins made %', out_js ->> 'count';
  end if;
  select count(*) into n from vessel where name ~ '^CB\s*\d+$';
  if n <> before + 4 then
    raise exception 'FAIL: four bins were asked for and % exist', n - before;
  end if;
  -- And attached to nothing. That is the whole point: inventory, not a pick.
  if exists (
    select 1 from placement pl join vessel v on v.id = pl.vessel_id
     where v.name ~ '^CB\s*\d+$'
  ) then
    raise exception 'FAIL: registering bins put fruit in them';
  end if;
  perform test_ok('a stack of bins can be registered without a pick to attach them to, which is what makes registering the fleet a thing you do before harvest rather than during it');

  -- Numbering carries on rather than counting rows, so a retired bin leaves a
  -- gap and nothing reuses its name.
  out_js := register_bins(2, bin_t, 'CB');
  if (out_js ->> 'from') <> 'CB' || (before + 5)::text then
    raise exception 'FAIL: the second stack started at % rather than carrying on', out_js ->> 'from';
  end if;
  perform test_ok('a second stack carries on from the highest number already worn, because reusing a retired bin''s name puts two objects under one name');

  -- Borrowed, which is the case that was wrong everywhere until 0081.
  out_js := register_bins(3, bin_t, 'CL', null, 'Pearlstaad');
  if not exists (
    select 1 from vessel_state
     where name ~ '^CL\s*\d+$' and owner_name = 'Pearlstaad' and not facility_owned
  ) then
    raise exception 'FAIL: a stack registered as on loan reads as ours';
  end if;
  perform test_ok('a stack registered as on loan from a grower reads as theirs, so the batch path and the pick path agree about whose a bin is');

  -- The two ways of not being ours are still exclusive.
  begin
    perform register_bins(1, bin_t, 'CX',
      (select id from party where kind = 'client' limit 1), 'Pearlstaad');
    raise exception 'FAIL: a bin was registered as both on loan and party owned';
  exception when others then
    if position('says both' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a bin cannot be registered as both on loan from a grower and owned by a party here, which is the rule 0036 set and this path repeats rather than reinvents');
  end;

  begin
    perform register_bins(0, bin_t, 'CZ');
    raise exception 'FAIL: zero bins were registered';
  exception when others then
    if position('how many bins' in sqlerrm) = 0 then raise; end if;
    perform test_ok('registering no bins is refused rather than quietly doing nothing, because a form that reports success and writes nothing is the worst answer available');
  end;

  begin
    perform register_bins(41, bin_t, 'CZ');
    raise exception 'FAIL: forty one bins were registered at once';
  exception when others then
    if position('is not a number of bins' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a count past forty is refused, because it is a mistyped number rather than a delivery');
  end;

  -- The inventory: counted, not listed.
  select bins into n from bin_inventory
   where whose = 'Pearlstaad' and borrowed
   limit 1;
  if coalesce(n, 0) < 3 then
    raise exception 'FAIL: the inventory does not count the borrowed stack';
  end if;
  perform test_ok('the bin inventory counts bins by whose they are, which is the question sixty interchangeable objects can actually answer');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a bin holds pounds'; end $$;

-- 0087. "Picking bins should hold fruit in lbs or % ton", and then the better
-- version when asked what a full bin holds: "800-900 lbs of fruit if it's
-- bulging. But the bins should each have a fruit amount in lbs so we just use
-- that right?" Right: pounds are the told fact and how full is the derived one,
-- which is the reverse of what 0033 built.
do $$
declare
  bin_t  uuid;
  b1     uuid := '00000000-0000-0000-0000-0000000e1001';
  b2     uuid := '00000000-0000-0000-0000-0000000e1002';
  pick   jsonb;
  pick_id uuid;
  got    record;
  full_l numeric;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  select id into bin_t from term
   where kind = 'vessel_type'
     and coalesce((attributes ->> 'intake_bin')::boolean, false)
   limit 1;
  select (attributes ->> 'full_lbs')::numeric into full_l from term where id = bin_t;

  if coalesce(full_l, 0) <= 0 then
    raise exception 'FAIL: no figure for what a full bin holds, so no percentage can become a weight';
  end if;
  perform test_ok('a picking bin type says what a full bin holds, which is the only thing a percentage can be turned into pounds against');

  insert into vessel (id, type_id, name) values
    (b1, bin_t, 'CD1'), (b2, bin_t, 'CD2');

  pick := jsonb_build_object('id', gen_random_uuid(), 'vintage', 2026);

  -- Pounds, which is what he asked for.
  pick_id := (add_bin_to_pick(pick, b1, null, 700) ->> 'node_id')::uuid;
  select * into got from bin_fruit where vessel_id = b1;
  if got.said_as <> 'lbs' or got.lbs <> 700 then
    raise exception 'FAIL: a bin told 700 pounds reads % as %', got.lbs, got.said_as;
  end if;
  if got.said_pct is not null then
    raise exception 'FAIL: a percentage was written next to pounds somebody gave';
  end if;
  perform test_ok('a bin says how many pounds of fruit are in it, and nothing writes a percentage beside the figure somebody actually gave');

  -- And the derived half, which is never stored.
  if got.pct_full <> round(700 / full_l * 100, 0) then
    raise exception 'FAIL: how full a 700 pound bin is reads %', got.pct_full;
  end if;
  if got.tons <> round(700 / 2000.0, 3) then
    raise exception 'FAIL: 700 pounds is % tons', got.tons;
  end if;
  perform test_ok('how full a bin is and what it is in tons are worked out from the pounds at read time, so neither can drift from the figure they came from');

  -- The other way round, for somebody who eyeballs it.
  perform add_bin_to_pick(pick || jsonb_build_object('id', pick_id), b2, 50, null);
  select * into got from bin_fruit where vessel_id = b2;
  if got.said_as <> 'pct' then
    raise exception 'FAIL: a bin told half full reads as %', got.said_as;
  end if;
  if got.lbs <> round(full_l / 2, 0) then
    raise exception 'FAIL: half a bin is % pounds and a full one is %', got.lbs, full_l;
  end if;
  perform test_ok('a bin can still be given as a percentage and reads back in pounds, because somebody standing at a bin is looking at it rather than weighing it');

  -- Never both. Two answers to one question, with nothing to say which was
  -- typed and which was computed.
  begin
    perform add_bin_to_pick(pick || jsonb_build_object('id', pick_id),
      (select id from vessel where type_id = bin_t and id not in (b1, b2)
        and not exists (select 1 from placement pl where pl.vessel_id = vessel.id and pl.to_at is null)
        limit 1), 50, 700);
    raise exception 'FAIL: a bin said both pounds and how full';
  exception when others then
    if position('not both' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a bin cannot say pounds and say how full at once, because one of the two would be a guess sitting beside a figure somebody gave');
  end;

  -- The constraint, not the function. A rule only the function enforces is a
  -- rule anything else can walk past.
  begin
    update placement set fill_pct = 90 where vessel_id = b1 and to_at is null;
    raise exception 'FAIL: both halves were written straight into the table';
  exception when check_violation then
    perform test_ok('the table refuses a bin carrying both a weight and a percentage, so the rule does not depend on everything going through one function');
  end;

  -- And the lot's own quantity is still the scale's, not a total of estimates.
  if (select n.quantity from node n where n.id = pick_id) is not null then
    raise exception 'FAIL: estimates in the bins gave the pick a weight before anybody weighed it';
  end if;
  perform test_ok('estimates in the bins do not give the pick a weight, because a pick reading a number nobody weighed is the A13 shape at the moment T1-4 exists to protect');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- moving more than one'; end $$;

-- 0088. "There should also be a batch option for things like moving barrels.
-- Like I'd love to be able to select 6 barrels to move to a new room, or put
-- the 5 picking bins in the south bay, etc, without doing it individually."
--
-- The kernel has done this since 0044 and nothing ever called it: `move_bins`
-- took an array, never checked that a vessel was a bin, and sat with no screen
-- above it and an exemption reading "not yet declared". So what 0088 adds is a
-- name that does not lie and a declaration, and what these assert is the batch
-- behaviour nothing had ever exercised.
do $$
declare
  room_a uuid := '00000000-0000-0000-0000-0000000f1001';
  room_b uuid := '00000000-0000-0000-0000-0000000f1002';
  v1     uuid := '00000000-0000-0000-0000-0000000f1101';
  v2     uuid := '00000000-0000-0000-0000-0000000f1102';
  v3     uuid := '00000000-0000-0000-0000-0000000f1103';
  ghost  uuid := '00000000-0000-0000-0000-0000000f1199';
  out_js jsonb;
  n      int;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');

  insert into location (id, name) values
    (room_a, 'CE the shed'), (room_b, 'CE the south bay');
  insert into vessel (id, type_id, name, location_id) values
    (v1, term_id('vessel_type','barrel'), 'CE1', room_a),
    (v2, term_id('vessel_type','barrel'), 'CE2', room_a),
    (v3, term_id('vessel_type','barrel'), 'CE3', room_a);

  out_js := move_vessels(array[v1, v2, v3], room_b);
  if (out_js ->> 'moved')::int <> 3 then
    raise exception 'FAIL: moving three vessels moved %', out_js ->> 'moved';
  end if;
  select count(*) into n from vessel
   where id in (v1, v2, v3) and location_id = room_b;
  if n <> 3 then
    raise exception 'FAIL: % of three vessels are in the new room', n;
  end if;
  perform test_ok('any number of vessels move to a room in one act, which is six barrels to a new room rather than six trips through a form');

  -- The column says where it is and the event says when it got there, which is
  -- the half that answers how long fruit sat in the cold.
  select count(*) into n from event
   where subject_type = 'vessel' and subject_id in (v1, v2, v3)
     and operation_id = term_id('operation', 'move_vessel');
  if n <> 3 then
    raise exception 'FAIL: three vessels moved and % events were written', n;
  end if;
  perform test_ok('a move writes an event for each vessel, so where a vessel is and when it got there are two different questions with two answers');

  -- **All or none.** Six selected and five moved is a state nobody asked for
  -- and nobody would notice: the screen would say it worked and one barrel
  -- would be in the wrong room.
  begin
    perform move_vessels(array[v1, ghost], room_a);
    raise exception 'FAIL: a batch with an unknown vessel in it moved anyway';
  exception when others then
    if position('no active vessel' in sqlerrm) = 0 then raise; end if;
  end;
  if (select location_id from vessel where id = v1) <> room_b then
    raise exception 'FAIL: a batch that failed still moved one of its vessels';
  end if;
  perform test_ok('a batch naming a vessel that is not there moves none of them, because half a move is a state nobody asked for and nobody would notice');

  begin
    perform move_vessels(array[]::uuid[], room_a);
    raise exception 'FAIL: an empty batch was accepted';
  exception when others then
    if position('nothing to move' in sqlerrm) = 0 then raise; end if;
    perform test_ok('moving nothing is refused rather than reported as success, because a screen saying it moved zero vessels is a screen that did nothing and said it worked');
  end;

  begin
    perform move_vessels(array[v1], '00000000-0000-0000-0000-0000000f1198');
    raise exception 'FAIL: vessels were moved to a room that does not exist';
  exception when others then
    if position('no such location' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a move to a room that is not there is refused, so a vessel is never filed somewhere nobody can walk to');
  end;

  -- The old name is gone rather than kept beside the new one.
  if exists (
    select 1 from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
     where ns.nspname = 'public' and p.proname = 'move_bins'
  ) then
    raise exception 'FAIL: move_bins is still callable, so there are two names for one act';
  end if;
  perform test_ok('there is one name for moving vessels, because a second name for one act is a call nobody can choose between');
end $$;

-- ---------------------------------------------------------------------------
do $$ begin raise notice '--- a press takes bins, not whole picks'; end $$;

-- 0090. "For the press log it should be bins grouped by pick, not just
-- selecting a whole pick. Like I can't fit all 5 bins into one press."
--
-- 0052 took whole lots and 0054 closed them, which was right while a pick was
-- assumed to fit in a press. Five half tonne bins against a 1.2 tonne press is
-- two loads and a bit, and closing the pick after the first would be the app
-- saying the fruit is gone while it is standing on the pad.
do $$
declare
  bin_t   uuid;
  press_v uuid := '00000000-0000-0000-0000-0000000f2001';
  b1      uuid := '00000000-0000-0000-0000-0000000f2101';
  b2      uuid := '00000000-0000-0000-0000-0000000f2102';
  b3      uuid := '00000000-0000-0000-0000-0000000f2103';
  pick    jsonb;
  pick_id uuid;
  out_js  jsonb;
  load_a  uuid;
  n       int;
  frac    numeric;
begin
  perform test_act_as('00000000-0000-0000-0000-00000000a001');
  select id into bin_t from term
   where kind = 'vessel_type'
     and coalesce((attributes ->> 'intake_bin')::boolean, false)
   limit 1;

  insert into vessel (id, type_id, name) values
    (press_v, term_id('vessel_type','press'), 'CF press'),
    (b1, bin_t, 'CF1'), (b2, bin_t, 'CF2'), (b3, bin_t, 'CF3');

  pick := jsonb_build_object('id', gen_random_uuid(), 'vintage', 2026,
                             'name', 'CF a pick');
  pick_id := (add_bin_to_pick(pick, b1, null, 800) ->> 'node_id')::uuid;
  perform add_bin_to_pick(jsonb_build_object('id', pick_id), b2, null, 800);
  perform add_bin_to_pick(jsonb_build_object('id', pick_id), b3, null, 400);

  -- The screen he described: open the pick, see its bins.
  select count(*) into n from pick_bin where node_id = pick_id;
  if n <> 3 then
    raise exception 'FAIL: a pick with three bins offers % of them to a press', n;
  end if;
  if (select sum(lbs) from pick_bin where node_id = pick_id) <> 2000 then
    raise exception 'FAIL: the bins on a pick do not add up to what went in them';
  end if;
  perform test_ok('a pick offers its bins with what is in each, which is what a press screen shows once somebody has chosen a pick');

  -- **Two of the three.** The press takes what fits.
  out_js := start_press(array[b1, b2], press_v);
  load_a := (out_js ->> 'node_id')::uuid;
  if (out_js ->> 'lbs_in')::numeric <> 1600 then
    raise exception 'FAIL: pressing two 800 pound bins loaded % pounds', out_js ->> 'lbs_in';
  end if;
  if (out_js ->> 'bins_emptied')::int <> 2 then
    raise exception 'FAIL: pressing two bins emptied %', out_js ->> 'bins_emptied';
  end if;
  perform test_ok('a press takes the bins it is given and weighs what those bins held, rather than the whole pick');

  -- **The pick is still open, with fruit in it.** This is the one that matters:
  -- 0054 closed the source outright, and doing that here would be the app
  -- saying the fruit is gone while a bin of it is on the pad.
  if (select status from node where id = pick_id) <> 'open' then
    raise exception 'FAIL: a pick with a full bin left was closed by pressing the other two';
  end if;
  if (out_js ->> 'picks_spent')::int <> 0 then
    raise exception 'FAIL: the press reported spending a pick that still has fruit';
  end if;
  select count(*) into n from pick_bin where node_id = pick_id;
  if n <> 1 then
    raise exception 'FAIL: % bins are left on the pick and one should be', n;
  end if;
  perform test_ok('a pick with bins still full stays open and still offers them, because the fruit that is left is still fruit that is left');

  -- Shares by what went in, not by lot and not equally.
  select fraction into frac from lineage
   where parent_id = pick_id and child_id = load_a;
  if frac <> 1.0 then
    raise exception 'FAIL: a load from one pick is % of it rather than all of it', frac;
  end if;
  perform test_ok('a load from one pick is entirely that pick, whichever of its bins went in');

  -- The rest of it, into the same press once it is free.
  update placement set to_at = now() where vessel_id = press_v and to_at is null;
  out_js := start_press(array[b3], press_v);
  if (out_js ->> 'lbs_in')::numeric <> 400 then
    raise exception 'FAIL: the second load is % pounds rather than the 400 left', out_js ->> 'lbs_in';
  end if;
  if (out_js ->> 'picks_spent')::int <> 1 then
    raise exception 'FAIL: the last bin left the pick and it was not spent';
  end if;
  if (select status from node where id = pick_id) <> 'closed' then
    raise exception 'FAIL: a pick with nothing in any vessel is still open';
  end if;
  perform test_ok('a pick is spent when its last bin empties and not before, which is the rule 0054 was reaching for in its true form');

  -- And the hole 0054 found stays shut: nothing can press a spent pick again.
  update placement set to_at = now() where vessel_id = press_v and to_at is null;
  begin
    perform start_press(array[b1], press_v);
    raise exception 'FAIL: an empty bin was pressed';
  exception when others then
    if position('nothing in it' in sqlerrm) = 0 then raise; end if;
    perform test_ok('an empty bin cannot be pressed, which is the hole 0054 found arriving by the new route and still shut');
  end;

  -- A press cannot be loaded from itself, which the old signature could not
  -- express because its sources were lots rather than vessels. The press has to
  -- be empty to reach this: a full one is refused one check earlier, and that
  -- ordering is itself the answer to which mistake is more likely.
  begin
    perform start_press(array[press_v], press_v);
    raise exception 'FAIL: a press was loaded from itself';
  exception when others then
    if position('from itself' in sqlerrm) = 0 then raise; end if;
    perform test_ok('a press cannot be loaded from itself, which only became sayable once the sources were vessels');
  end;
end $$;

do $$ begin raise notice '--- all assertions passed'; end $$;

rollback;
