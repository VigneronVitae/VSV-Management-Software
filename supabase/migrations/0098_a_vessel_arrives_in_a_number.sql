-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Adding a vessel takes a count, which is 1 unless you say otherwise,
--           and a borrowed one is named after whoever lent it rather than taking
--           the next number in this winery's own series."
-- Depends on: [supabase/migrations/0085_a_stack_of_bins_is_inventory.sql,
--              supabase/migrations/0086_a_variable_named_like_a_column.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0104_a_pressed_bin_leaves_the_room.sql]
-- Axioms enforced: T0-2 (the number a new vessel wears follows from the ones
--                  already worn and is never typed in beside them), R-4 (a
--                  count of one is the answer to a question nobody should be
--                  asked), AR-E7 (one act, one function: bins were the batch
--                  path and barrels had none)
-- Open sorries: S-87
-- ---------------------------------------------------------------------------
--
-- The winemaker, asked whether batch vessel addition existed: *"Seems like all
-- it needs to be is a number of vessel in the type. Then it defaults to 1 but
-- you can change it to whatever you need for an action."*
--
-- **That is smaller than what was here and it is right.** `register_bins` from
-- `0085` takes a count, and it is the only thing in the app that does; a row of
-- twelve barrels arriving from a cooper is twelve trips through a form that asks
-- about each one separately, and the questions have the same answer every time.
-- Adding a vessel is one act whether it happens once or thirty times, so it is
-- one function with a number on it.
--
-- **The numbering rule lives here and nowhere else.** Carrying on from the
-- highest number already worn, rather than counting rows, is `0036`'s rule and
-- `0085`'s: a retired bin leaves a gap, and reusing its number puts two objects
-- under one name in a schema where a name is how somebody in a barn tells them
-- apart. `register_bins` now calls this rather than repeating it, because the
-- second copy of a rule is the one that stays wrong.
--
-- ---------------------------------------------------------------------------
--
-- The other half. *"Picking bins on loan should have a different naming
-- convention - eventually I'm gonna have like 30 picking bins of ours in
-- there."*
--
-- Today PB4 through PB8 are Pearlstaad's and PB1 through PB3 are his, and
-- nothing about those names says so. When his thirty arrive they take PB9
-- onward, and the series reads as one fleet with five strangers hidden in the
-- middle of it. The day that matters is the day the bins go back, and it is
-- answered by reading a number off the side rather than by opening the app.
--
-- **So a borrowed vessel is named after whoever lent it.** Pearlstaad's bins are
-- PEAR1 to PEAR5, the first word of the lender cut to four letters, and his own
-- keep PB. The prefix is still whatever anybody types; this is only what happens
-- when nobody says, which is the case that produced PB4.
--
-- Nothing is renamed. The five that exist keep their names until somebody
-- decides otherwise, because a bin sitting in a press log under one name and on
-- the pad under another is worse than a bin with an unhelpful name. That is
-- S-87.

begin;

-- ---------------------------------------------------------------------------
-- What a borrowed thing is called
-- ---------------------------------------------------------------------------

create or replace function lender_prefix(p_lender text)
returns text
language sql
immutable
set search_path to 'public', 'pg_temp'
as $$
  -- First word, letters and digits only, four characters. Long enough to read as
  -- a name and short enough to fit on the side of a bin and on a vessel chip.
  select coalesce(
    nullif(
      upper(substr(regexp_replace(split_part(btrim(coalesce(p_lender, '')), ' ', 1),
                                  '[^a-zA-Z0-9]', '', 'g'), 1, 4)),
      ''),
    -- A lender whose name is all punctuation still must not land in this
    -- winery's own series, which is the whole point of the function.
    'LOAN');
$$;

comment on function lender_prefix(text) is
  'What a vessel on loan is called when nobody says: the lender, first word, '
  'four characters. Keeps a borrowed bin out of this winery''s own number '
  'series. See 0098.';

-- ---------------------------------------------------------------------------
-- Adding one, or thirty
-- ---------------------------------------------------------------------------

create or replace function add_vessels(
  p_vessel jsonb,
  p_count  int default 1
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  want    int    := coalesce(p_count, 1);
  lender  text   := nullif(btrim(coalesce(p_vessel -> 'attributes' ->> 'on_loan_from', '')), '');
  owner   uuid   := (p_vessel ->> 'owner_id')::uuid;
  given   text   := btrim(coalesce(p_vessel ->> 'name', ''));
  bag     jsonb  := coalesce(p_vessel -> 'attributes', '{}'::jsonb);
  prefix  text;
  next_n  int;
  made    text[] := '{}';
  ids     uuid[] := '{}';
  one     uuid;
  nm      text;
  i       int;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here adds a vessel'
      using errcode = 'insufficient_privilege';
  end if;

  if want <= 0 then
    raise exception 'how many vessels?';
  end if;
  -- 0085's ceiling, for 0085's reason: more than anybody wheels in at once, and
  -- a mistyped count is what it is here to catch.
  if want > 40 then
    raise exception '% is not a number of vessels to add at once', want;
  end if;

  if (p_vessel ->> 'type_id') is null then
    raise exception 'a vessel is of some type, and this one says none';
  end if;

  -- 0036's rule, unchanged and now applying to a borrowed tank as well as a
  -- borrowed bin: a vessel is a named grower's or a party's, never both.
  if lender is not null and owner is not null then
    raise exception
      'a vessel is either on loan from % or owned by a party here, and this says both', lender;
  end if;

  if lender is not null then
    bag := bag || jsonb_build_object('borrowed', true, 'on_loan_from', lender);
  elsif owner is not null and owner is distinct from facility_party_id() then
    bag := bag || jsonb_build_object('borrowed', true);
  end if;

  -- The name is a prefix once there is more than one of them. Trailing digits
  -- come off, so typing PB1 with a count of five continues the PB series rather
  -- than starting a PB1 series next to it.
  if given = '' then
    if lender is null then
      raise exception 'a new vessel needs something to be called';
    end if;
    prefix := lender_prefix(lender);
  else
    prefix := btrim(regexp_replace(given, '\s*\d+$', ''));
    if prefix = '' then
      -- Somebody typed a bare number. That is a name, not a series.
      prefix := given;
    end if;
  end if;

  -- One vessel keeps the name it was given. Only a batch gets numbered, because
  -- a single tank called "Fermenter" should not come back as "Fermenter 1".
  if want = 1 and given <> '' then
    one := coalesce((p_vessel ->> 'id')::uuid, gen_random_uuid());
    insert into vessel
      (id, type_id, name, capacity_l, location_id, owner_id, attributes,
       has_glycol, setpoint_c, mode)
    values
      (one, (p_vessel ->> 'type_id')::uuid, given,
       (p_vessel ->> 'capacity_l')::numeric,
       (p_vessel ->> 'location_id')::uuid,
       owner, bag,
       coalesce((p_vessel ->> 'has_glycol')::boolean, false),
       (p_vessel ->> 'setpoint_c')::numeric,
       coalesce((p_vessel ->> 'mode')::thermal_mode, 'off'));
    return jsonb_build_object(
      'made', to_jsonb(array[given]), 'ids', to_jsonb(array[one]),
      'count', 1, 'from', given, 'to', given, 'prefix', prefix);
  end if;

  -- Carry on from the highest number already worn rather than counting rows: a
  -- retired vessel leaves a gap and reusing its number puts two objects under
  -- one name.
  select coalesce(max((regexp_match(v.name, '^' || prefix || '\s*(\d+)$'))[1]::int), 0) + 1
    into next_n
    from vessel v
   where v.name ~ ('^' || prefix || '\s*\d+$');

  for i in 0 .. want - 1
  loop
    nm  := prefix || (next_n + i)::text;
    one := gen_random_uuid();
    insert into vessel
      (id, type_id, name, capacity_l, location_id, owner_id, attributes,
       has_glycol, setpoint_c, mode)
    values
      (one, (p_vessel ->> 'type_id')::uuid, nm,
       (p_vessel ->> 'capacity_l')::numeric,
       (p_vessel ->> 'location_id')::uuid,
       owner, bag,
       coalesce((p_vessel ->> 'has_glycol')::boolean, false),
       (p_vessel ->> 'setpoint_c')::numeric,
       coalesce((p_vessel ->> 'mode')::thermal_mode, 'off'));
    made := made || nm;
    ids  := ids || one;
  end loop;

  return jsonb_build_object(
    'made',   to_jsonb(made),
    'ids',    to_jsonb(ids),
    'count',  want,
    'from',   made[1],
    'to',     made[array_length(made, 1)],
    'prefix', prefix);
end;
$$;

comment on function add_vessels(jsonb, int) is
  'Add a vessel, or several of the same kind. The count is 1 unless somebody '
  'says otherwise; a batch is numbered on from the highest already worn, and a '
  'borrowed one with no name given is called after the lender. See 0098.';

revoke all on function add_vessels(jsonb, int) from public;
grant execute on function add_vessels(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------------
-- Bins go through the same door
-- ---------------------------------------------------------------------------

-- Everything bin-shaped stays: working out the one picking bin type, refusing a
-- type fruit is not weighed in, and taking the capacity off the stack that is
-- already there. Everything vessel-shaped is now add_vessels, so the numbering
-- rule and the loan rule exist once.
create or replace function register_bins(
  p_count        int,
  p_type_id      uuid    default null,
  p_name_prefix  text    default null,
  p_owner_id     uuid    default null,
  p_on_loan_from text    default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  lender    text := nullif(btrim(coalesce(p_on_loan_from, '')), '');
  prefix    text := nullif(btrim(coalesce(p_name_prefix, '')), '');
  want_type uuid := p_type_id;
  cap       numeric;
  bag       jsonb := '{}'::jsonb;
  out       jsonb;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here registers bins'
      using errcode = 'insufficient_privilege';
  end if;

  if coalesce(p_count, 0) <= 0 then
    raise exception 'how many bins?';
  end if;
  -- add_vessels refuses this too, at the same number. Said here as well because
  -- add_bins_to_pick says it in these words, and the three bin paths refusing
  -- the same mistyped count in two different sentences is worse than the line.
  if p_count > 40 then
    raise exception '% is not a number of bins to register at once', p_count;
  end if;

  -- The one picking bin type, if this winery has only one. Naming it every time
  -- is a question with one possible answer, which is R-4 in a form.
  if want_type is null then
    select t.id into want_type
      from term t
     where t.kind = 'vessel_type' and t.active
       and coalesce((t.attributes ->> 'intake_bin')::boolean, false)
     limit 2;
    if want_type is null then
      raise exception 'no picking bin type is registered, so there is nothing to make these as';
    end if;
    if (select count(*) from term t
         where t.kind = 'vessel_type' and t.active
           and coalesce((t.attributes ->> 'intake_bin')::boolean, false)) > 1 then
      raise exception 'this winery has more than one kind of picking bin, so say which';
    end if;
  end if;

  if not exists (
    select 1 from term
     where id = want_type and kind = 'vessel_type'
       and coalesce((attributes ->> 'intake_bin')::boolean, false)
  ) then
    raise exception 'that is not a picking bin type, so fruit is not weighed in it';
  end if;

  select v.capacity_l into cap
    from vessel v
   where v.type_id = want_type
   order by v.created_at desc
   limit 1;

  -- Borrowed bins are called after the lender, ours are PB. Both are defaults
  -- for the case where nobody says, and either can be typed over.
  if prefix is null then
    prefix := case when lender is null then 'PB' else lender_prefix(lender) end;
  end if;

  if lender is not null then
    bag := jsonb_build_object('on_loan_from', lender);
  end if;

  out := add_vessels(
    jsonb_build_object(
      'type_id',    want_type,
      -- A trailing 1 so add_vessels reads this as a series even when one bin is
      -- registered, which is the difference between a bin and a tank: a bin is
      -- always one of a stack.
      'name',       prefix || '1',
      'capacity_l', cap,
      'owner_id',   p_owner_id,
      'attributes', bag),
    p_count);

  return jsonb_build_object(
    'registered', out -> 'made',
    'count',      out -> 'count',
    'from',       out -> 'from',
    'to',         out -> 'to');
end;
$$;

revoke all on function register_bins(int, uuid, text, uuid, text) from public;
grant execute on function register_bins(int, uuid, text, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- What a screen is written against
-- ---------------------------------------------------------------------------

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('cellar.add_vessels', 'cellar', 'Add a vessel',
   'One vessel, or a number of the same kind. A batch is numbered on from the '
   'highest already used.',
   'add_vessels', 'cellar.vessels',
   '[{"key":"vessel","param":"p_vessel","type":"jsonb","required":true,
      "label":"The vessel",
      "note":"type_id and name at least. A name ending in a number is read as the series it belongs to."},
     {"key":"count","param":"p_count","type":"integer","required":false,
      "label":"How many",
      "note":"1 unless you say otherwise."}]'::jsonb, 240)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

update capability
   set fields = '[{"key":"count","param":"p_count","type":"integer","required":true,
      "label":"How many"},
     {"key":"prefix","param":"p_name_prefix","type":"text","required":false,
      "label":"Called",
      "note":"PB for ours, the lender''s name for borrowed ones. Numbering carries on from the highest already used."},
     {"key":"lender","param":"p_on_loan_from","type":"text","required":false,
      "label":"On loan from",
      "note":"A grower who lent them. Leave blank if they are this winery''s."}]'::jsonb
 where key = 'cellar.register_bins';

-- Not a capability. It answers what a borrowed thing is called, which is a
-- default inside two capabilities rather than an act anybody performs.
insert into capability_exemption (fn, reason) values
  ('lender_prefix', 'Works out what a borrowed vessel is called when nobody says. A default inside add_vessels and register_bins, not an act.')
on conflict (fn) do nothing;

commit;
