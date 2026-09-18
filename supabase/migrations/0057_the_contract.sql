-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "What a periphery may read, what it may write, and what each write
--           asks for, declared where a second periphery can read it rather than
--           discovered by reading the first one's source."
-- Depends on: [supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0052_press_as_a_process.sql,
--              supabase/migrations/0056_draw_to_a_level.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0058_an_open_pick_is_a_view.sql,
--                  supabase/migrations/0059_a_weighing_says_its_pick.sql,
--                  supabase/migrations/0060_the_contract_catches_up.sql,
--                  supabase/migrations/0069_the_contract_hears_about_the_invite.sql,
--                  supabase/migrations/0073_the_contract_hears_about_colour.sql,
--                  supabase/migrations/0079_a_room_says_which_way_it_is_held.sql,
--                  supabase/migrations/0080_whose_wine_it_is_can_be_corrected.sql,
--                  supabase/migrations/0088_moving_more_than_one.sql,
--                  supabase/migrations/0094_an_import_is_a_proposal.sql,
--                  supabase/migrations/0106_the_acts_a_shop_performs.sql,
--                  supabase/migrations/0109_a_module_says_where_it_lives.sql,
--                  supabase/migrations/0114_every_pick_stays_on_the_list.sql,
--                  supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql,
--                  supabase/migrations/0121_the_new_acts_say_what_they_take.sql]
-- Axioms enforced: AR-Q8 (an interface is a periphery over a read and write
--                  contract), AR-E6 (the declaration is registry rows, so
--                  another winery's contract is data), R-4 (a client that
--                  hardcodes what the kernel could answer is the failure this
--                  prevents)
-- Open sorries: S-72 (the contract declares shape and says nothing about
--                sequence, so a periphery can offer an action that cannot work)
-- ---------------------------------------------------------------------------
--
-- The winemaker, on being shown four ways to record a press: "should the UI/UX
-- thing just be different contracts? So that might be a thing, for like
-- everything." Then, sharpening it: "some people might like text based UI/UXs,
-- some people might want interactive/visual, some people audio, etc. But UI/UX
-- can just be a contract for writing and reading", citing his own EpiStack and
-- Knowledge Game.
--
-- **The shape is borrowed and it is specific.** Knowledge Game holds its client
-- unprivileged: reading and writing cross a strict periphery-to-kernel boundary,
-- and the falsifier is that a minimal independent client built from the public
-- api alone reproduces every capability. EpiStack separates the functions any
-- installation must fill from the contracts chosen by whoever holds the context.
-- Recording a press is a function every winery must fill. Asking for an
-- increment or asking for a tank level is a contract this winery chose. A text,
-- visual or audio interface is a periphery over both.
--
-- **Half of this was already built and had no name.** `viewer_scope` answers
-- what the caller is rather than letting a client infer it. `writable_columns`
-- answers which columns this caller may write, because hardcoding them was ruled
-- R-4. `terms_for_vessel_field` answers which vocabulary a field may offer.
-- `subject_resolver` answers what kinds of thing exist. That habit is the
-- contract. What was missing is that it could only be found by reading
-- `kernel.ts`, which is the one place a second periphery must not have to look.
--
-- **The declaration is worthless unless it cannot drift, so that is the part to
-- read carefully.** A registry saying `weigh_bins` takes a gross weight is a
-- comment unless something fails when the function stops taking one. The
-- assertions in the suite check both directions: every declared capability
-- resolves to exactly one function whose parameters are exactly what was
-- declared, and every function this database grants to `authenticated` is either
-- declared or named in an exemption with a reason. The second direction is the
-- one that matters, because a contract falls behind by omission rather than by
-- contradiction. It is the same ratchet as the refusal-site enumeration.

begin;

-- ---------------------------------------------------------------------------
-- What can be read
-- ---------------------------------------------------------------------------

create table if not exists readable (
  key          text primary key,
  module       text not null,
  label        text not null,
  note         text,
  -- The view or table behind it. Checked against the catalog by the suite: a
  -- readable naming a relation that does not exist fails the build.
  relation     text not null,
  -- Which column identifies a row, and which one a person would recognise it
  -- by. A periphery needs both and can guess neither.
  id_column    text,
  label_column text,
  sort_order   int not null default 100,
  constraint readable_key_is_qualified check (key like '%.%')
);

comment on table readable is
  'What a periphery may read, by name, with the relation behind it. See 0057.';

-- ---------------------------------------------------------------------------
-- What can be written
-- ---------------------------------------------------------------------------

create table if not exists capability (
  key        text primary key,
  module     text not null,
  label      text not null,
  -- One sentence saying what it is for, in the voice a person reads. A text or
  -- audio periphery has nothing else to say when it offers this.
  note       text,
  -- The kernel function. Checked against `pg_proc` by the suite.
  fn         text not null,
  -- Which readable supplies the thing this acts on, when it acts on one. A
  -- periphery offering "record a tank level" needs to know to list presses in
  -- progress first, and it cannot work that out.
  subject    text references readable (key) on delete restrict,
  -- The arguments, in the order a person should be asked for them. Each entry:
  --   key       what to call it to a person
  --   param     the function parameter it fills, checked against the catalog
  --   type      uuid | uuid[] | numeric | text | boolean | timestamptz | jsonb
  --   required  whether the kernel refuses without it
  --   label     what to ask
  --   hint      why, or what a good answer looks like
  --   source    where the answer comes from, if it is not typed:
  --               {"terms": "press_cut"}    a vocabulary
  --               {"readable": "cellar.vessels"}  a row somebody picks
  fields     jsonb not null default '[]'::jsonb,
  sort_order int not null default 100,
  constraint capability_key_is_qualified check (key like '%.%'),
  constraint capability_fields_is_a_list check (jsonb_typeof(fields) = 'array')
);

comment on table capability is
  'What a periphery may write: the kernel function, what it acts on, and what '
  'to ask for in the order to ask. Checked against the catalog, in both '
  'directions, by tests/schema_assertions.sql. See 0057 and AR-Q8.';

-- Functions deliberately outside the contract, each with the reason. This is
-- the list that stops the reverse check becoming a thing somebody silences.
create table if not exists capability_exemption (
  fn     text primary key,
  reason text not null,
  constraint exemption_has_a_reason check (btrim(reason) <> '')
);

comment on table capability_exemption is
  'Functions granted to authenticated that are deliberately not capabilities, '
  'each with why. An exemption is a decision somebody wrote down, which is the '
  'difference between this and the check not existing. See 0057.';

alter table readable enable row level security;
alter table capability enable row level security;
alter table capability_exemption enable row level security;

-- The contract is structure rather than content: it says what kinds of thing
-- exist and what may be done, and never whose wine or how much. The same
-- judgement `subject_resolver` and `term_kind` already carry.
drop policy if exists readable_read on readable;
create policy readable_read on readable for select to authenticated using (true);
drop policy if exists capability_read on capability;
create policy capability_read on capability for select to authenticated using (true);
drop policy if exists capability_exemption_read on capability_exemption;
create policy capability_exemption_read on capability_exemption
  for select to authenticated using (true);

drop policy if exists readable_admin_write on readable;
create policy readable_admin_write on readable for all to authenticated
  using (is_admin()) with check (is_admin());
drop policy if exists capability_admin_write on capability;
create policy capability_admin_write on capability for all to authenticated
  using (is_admin()) with check (is_admin());
drop policy if exists capability_exemption_admin_write on capability_exemption;
create policy capability_exemption_admin_write on capability_exemption
  for all to authenticated using (is_admin()) with check (is_admin());

-- ---------------------------------------------------------------------------
-- One call, because a periphery should not need to know there are three tables
-- ---------------------------------------------------------------------------

create or replace function contract()
returns jsonb
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
  select jsonb_build_object(
    -- What the caller is. Already answered by `viewer_scope`, included here so
    -- that one call is enough to build a first screen.
    'viewer', (select to_jsonb(v) from viewer_scope() v),
    'readables', coalesce((
      select jsonb_agg(jsonb_build_object(
               'key', r.key, 'module', r.module, 'label', r.label,
               'note', r.note, 'relation', r.relation,
               'id_column', r.id_column, 'label_column', r.label_column)
               order by r.sort_order, r.key)
        from readable r), '[]'::jsonb),
    'capabilities', coalesce((
      select jsonb_agg(jsonb_build_object(
               'key', c.key, 'module', c.module, 'label', c.label,
               'note', c.note, 'fn', c.fn, 'subject', c.subject,
               'fields', c.fields)
               order by c.sort_order, c.key)
        from capability c), '[]'::jsonb));
$$;

revoke all on function contract() from public;
grant execute on function contract() to authenticated;

comment on function contract() is
  'The whole contract in one call: who is asking, what they may read, what they '
  'may write and what each write needs. A second periphery should need nothing '
  'else to start. See AR-Q8.';

-- ---------------------------------------------------------------------------
-- The cellar's contract, as it stands today
-- ---------------------------------------------------------------------------

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.vessels', 'cellar', 'Vessels',
   'Every vessel and what is in it.', 'vessel_state', 'id', 'name', 10),
  ('cellar.open_picks', 'cellar', 'Open picks',
   'Fruit in bins that has not been pressed or sent away.', 'pick_open', 'id', 'name', 20),
  ('cellar.unweighed_bins', 'cellar', 'Bins waiting for the scale',
   'Bins holding known fruit whose weight nobody has taken yet.',
   'unweighed_bin', 'vessel_id', 'bin_name', 30),
  ('cellar.presses_running', 'cellar', 'Presses running',
   'Presses that were started and not finished.', 'press_in_progress', 'node_id', 'name', 40),
  ('cellar.press_draws', 'cellar', 'What came off a press',
   'Every draw, in the order it came off.', 'press_draw', 'event_id', 'cut_name', 50),
  ('cellar.pick_weighings', 'cellar', 'Weighings of a pick',
   'Every reading, with the bins that were on the scale.', 'pick_weighing', 'event_id', 'pick_name', 60),
  ('cellar.additions', 'cellar', 'Additions',
   'What went into the wine, with the volume it went into and the rate.',
   'lot_addition', 'event_id', 'what', 70),
  ('cellar.supplies_for_addition', 'cellar', 'Things that go into wine',
   'The shelf, filtered to what somebody flagged as an addition.',
   'supply_for_addition', 'supply_id', 'name', 80),
  ('cellar.bins_to_return', 'cellar', 'Bins owed back',
   'Borrowed bins that are empty.', 'bin_to_return', 'vessel_id', 'bin_name', 90),
  ('cellar.lots_without_vintage', 'cellar', 'Lots that never said a vintage',
   'Recorded before the app asked. Can only shrink.',
   'lot_without_vintage', 'id', 'name', 100)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values

  ('cellar.weigh_bins', 'cellar', 'Weigh bins',
   'One scale reading, however many bins were on it. Their tares come off automatically.',
   'weigh_bins', 'cellar.open_picks',
   '[{"key":"pick","param":"p_node_id","type":"uuid","required":true,"label":"Which pick",
      "source":{"readable":"cellar.open_picks"}},
     {"key":"bins","param":"p_vessel_ids","type":"uuid[]","required":true,
      "label":"Which bins were on the scale","source":{"readable":"cellar.unweighed_bins"}},
     {"key":"gross_lbs","param":"p_gross_lbs","type":"numeric","required":true,
      "label":"Gross, lbs","hint":"What the scale says, bins and fruit together."},
     {"key":"note","param":"p_note","type":"text","required":false,"label":"Note",
      "hint":"What a number alone would not say."},
     {"key":"supersedes","param":"p_supersedes","type":"uuid","required":false,
      "label":"Correcting which reading","hint":"Only when fixing an earlier one."},
     {"key":"photo_path","param":"p_photo_path","type":"text","required":false,
      "label":"Photograph of the scale","hint":"Wanted, not required."}]'::jsonb, 10),

  ('cellar.start_press', 'cellar', 'Start a press',
   'The fruit goes in and the bins empty. How much it will give is not known yet.',
   'start_press', 'cellar.open_picks',
   '[{"key":"picks","param":"p_source_ids","type":"uuid[]","required":true,
      "label":"What is going in","source":{"readable":"cellar.open_picks"}},
     {"key":"press","param":"p_press_vessel_id","type":"uuid","required":true,
      "label":"Into which press","source":{"readable":"cellar.vessels"}},
     {"key":"node","param":"p_node","type":"jsonb","required":false,"label":"Name it something else"},
     {"key":"detail","param":"p_detail","type":"jsonb","required":false,"label":"Anything known already"}]'::jsonb, 20),

  ('cellar.draw_cut', 'cellar', 'Say what came off',
   'How much has come off since the last time this was recorded. It adds up.',
   'draw_cut', 'cellar.presses_running',
   '[{"key":"press","param":"p_load_id","type":"uuid","required":true,"label":"Which press",
      "source":{"readable":"cellar.presses_running"}},
     {"key":"vessel","param":"p_vessel_id","type":"uuid","required":true,"label":"Into which vessel",
      "source":{"readable":"cellar.vessels"}},
     {"key":"litres","param":"p_volume_l","type":"numeric","required":true,"label":"Litres off"},
     {"key":"cut","param":"p_cut_id","type":"uuid","required":false,"label":"Which cut",
      "source":{"terms":"press_cut"}},
     {"key":"name","param":"p_name","type":"text","required":false,"label":"Call the cut something else"},
     {"key":"note","param":"p_note","type":"text","required":false,"label":"Note"}]'::jsonb, 30),

  ('cellar.draw_to_level', 'cellar', 'Read the tank',
   'What the receiving tank''s gauge says now. The difference is worked out for you.',
   'draw_to_level', 'cellar.presses_running',
   '[{"key":"press","param":"p_load_id","type":"uuid","required":true,"label":"Which press",
      "source":{"readable":"cellar.presses_running"}},
     {"key":"vessel","param":"p_vessel_id","type":"uuid","required":true,"label":"Which tank",
      "source":{"readable":"cellar.vessels"}},
     {"key":"level_l","param":"p_level_l","type":"numeric","required":true,
      "label":"What it reads now, litres"},
     {"key":"cut","param":"p_cut_id","type":"uuid","required":false,"label":"Which cut",
      "hint":"Only if it is a new one. A tank already taking a cut keeps taking it.",
      "source":{"terms":"press_cut"}},
     {"key":"note","param":"p_note","type":"text","required":false,"label":"Note"}]'::jsonb, 40),

  ('cellar.finish_press', 'cellar', 'Finish a press',
   'Sets the yield and closes the load. Record the last of the litres first.',
   'finish_press', 'cellar.presses_running',
   '[{"key":"press","param":"p_load_id","type":"uuid","required":true,"label":"Which press",
      "source":{"readable":"cellar.presses_running"}},
     {"key":"detail","param":"p_detail","type":"jsonb","required":false,
      "label":"Program, minutes, anything else"}]'::jsonb, 50),

  ('cellar.add_to_wine', 'cellar', 'Make an addition',
   'Something goes into the wine in a vessel, and off the shelf at the same time.',
   'add_to_wine', 'cellar.vessels',
   '[{"key":"vessels","param":"p_vessel_ids","type":"uuid[]","required":true,
      "label":"Into which vessels","hint":"They must all hold the same lot.",
      "source":{"readable":"cellar.vessels"}},
     {"key":"amount","param":"p_amount","type":"numeric","required":true,"label":"How much"},
     {"key":"unit","param":"p_unit","type":"text","required":true,"label":"Unit",
      "hint":"Nothing converts, so use the unit the shelf keeps."},
     {"key":"supply","param":"p_supply_id","type":"uuid","required":false,
      "label":"Off the shelf","hint":"Picking one takes it off the shelf as well.",
      "source":{"readable":"cellar.supplies_for_addition"}},
     {"key":"what","param":"p_what","type":"text","required":false,"label":"What went in",
      "hint":"Needed only if it did not come off the shelf."},
     {"key":"at","param":"p_at","type":"timestamptz","required":false,"label":"When"},
     {"key":"note","param":"p_note","type":"text","required":false,"label":"Note"}]'::jsonb, 60),

  ('cellar.attach_photo', 'cellar', 'Attach a photograph',
   'A picture of anything, attached whenever somebody gets to it.',
   'attach_photo', null,
   '[{"key":"subject_type","param":"p_subject_type","type":"text","required":true,
      "label":"Of what kind of thing"},
     {"key":"subject_id","param":"p_subject_id","type":"uuid","required":true,"label":"Of which one"},
     {"key":"path","param":"p_path","type":"text","required":true,"label":"Where the file was uploaded"},
     {"key":"caption","param":"p_caption","type":"text","required":false,"label":"Caption"},
     {"key":"about_event","param":"p_about_event","type":"uuid","required":false,
      "label":"Evidence for which event"},
     {"key":"taken_at","param":"p_taken_at","type":"timestamptz","required":false,
      "label":"When it was taken"}]'::jsonb, 70),

  ('cellar.set_vintage', 'cellar', 'Say a lot''s vintage',
   'A year, or that it is deliberately non-vintage. Saying neither is refused.',
   'set_vintage', 'cellar.lots_without_vintage',
   '[{"key":"lot","param":"p_node_id","type":"uuid","required":true,"label":"Which lot",
      "source":{"readable":"cellar.lots_without_vintage"}},
     {"key":"vintage","param":"p_vintage","type":"numeric","required":false,"label":"Which year"},
     {"key":"non_vintage","param":"p_non_vintage","type":"boolean","required":false,
      "label":"It is non-vintage"}]'::jsonb, 80),

  ('cellar.cancel_pick', 'cellar', 'Cancel a pick',
   'A pick that was recorded and did not happen. The bins empty.',
   'cancel_pick', 'cellar.open_picks',
   '[{"key":"pick","param":"p_node_id","type":"uuid","required":true,"label":"Which pick",
      "source":{"readable":"cellar.open_picks"}},
     {"key":"reason","param":"p_reason","type":"text","required":false,"label":"Why"}]'::jsonb, 90),

  ('cellar.count_supply', 'cellar', 'Count something on the shelf',
   'What was found, beside what was expected. The gap is the measurement.',
   'count_supply', 'cellar.supplies_for_addition',
   '[{"key":"supply","param":"p_supply_id","type":"uuid","required":true,"label":"Which supply",
      "source":{"readable":"cellar.supplies_for_addition"}},
     {"key":"counted","param":"p_counted","type":"numeric","required":true,"label":"How much is there"},
     {"key":"note","param":"p_note","type":"text","required":false,"label":"Note"}]'::jsonb, 100)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

-- The ones deliberately outside, each with why. A reverse check with no
-- exemption list is a check somebody eventually deletes.
insert into capability_exemption (fn, reason) values
  ('contract', 'The contract itself. A periphery calls it to find everything else.'),
  ('viewer_scope', 'Answers what the caller is. Returned inside the contract already.'),
  ('writable_columns', 'Answers which columns this caller may write. A contract about the contract.'),
  ('terms_for_vessel_field', 'Answers which vocabulary a field may offer. Resolves a source, rather than being a capability.'),
  ('makers_for_vessel_type', 'The same, for makers.'),
  ('claim_account', 'Identity, before there is a caller to have capabilities.'),
  ('export_cellar', 'A whole-database read for backup. Not a thing a periphery composes.'),
  ('day_log', 'A report. Reads rather than writes, and its shape is a report''s.'),
  ('rack_plan', 'A preview of a rack. The write is `rack`, which is not yet declared.'),
  ('press', 'The one-shot press superseded by `start_press`. S-71: it is still here and has no screen.'),
  ('rack', 'Not yet declared. The rack screen predates the contract and is the next one to bring in.'),
  ('fork_lot', 'The same. Reached from the vessel screen.'),
  ('fill_vessel', 'The same.'),
  ('create_vessel_with_wine', 'The same.'),
  ('add_bin_to_pick', 'Superseded by `add_bins_to_pick`, which is not yet declared either.'),
  ('add_bins_to_pick', 'Not yet declared. Its argument list is the most complicated in the kernel and wants thought.'),
  ('remove_pick', 'Administrative. Deletes rather than records.'),
  ('finish_pick', 'Not yet declared, and its screen is unbuilt.'),
  ('move_bins', 'The same.'),
  ('plan_processing', 'The same.'),
  ('send_fruit_away', 'The same.'),
  ('move_supply', 'Not yet declared. The stores screen predates the contract.'),
  ('mark_propagated', 'The same.'),
  ('bind_code', 'The same.'),
  ('resolve_code', 'A lookup rather than a write.'),
  ('table_count', 'A number for the export stamp.'),
  ('term_id', 'A lookup used inside other functions.'),
  ('bin_tare_lbs', 'A lookup used inside other functions.'),
  ('vessel_volume_at', 'A lookup used inside other functions.'),
  ('facility_party_id', 'A lookup used inside other functions.'),
  ('is_admin', 'A predicate used by policies.'),
  ('is_facility_user', 'A predicate used by policies.'),
  ('hideable_fields', 'A lookup used by a constraint.'),
  ('node_bin_shares', 'A traversal used by reports.'),
  ('node_history', 'A traversal used by reports.')
on conflict (fn) do update set reason = excluded.reason;

commit;
