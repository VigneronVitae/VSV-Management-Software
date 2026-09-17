-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A jacketed vessel says which glycol machine it is hooked to and a
--           machine says what is hanging off it, so the two questions are one
--           fact read from either end, with the history of what was on what."
-- Depends on: [supabase/migrations/0006_vessel_thermal.sql,
--              supabase/migrations/0099_a_vessel_says_which_vintage.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0101_a_note_can_be_about_a_screen.sql]
-- Axioms enforced: T0-2 (which way a machine is running is derived from the
--                  jackets on it and is never a second thing to set), T0-5
--                  (a hookup is a period with a start and an end, like a
--                  placement, so what was on what in October survives)
-- Open sorries: S-88
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"The glycol jackets should be linked to a glycol pump and
-- chiller/cooler"*, and then the winery: *"We have two glycol machines, both
-- have pumps and coolers, one can also heat (the bigger one, but can only cool
-- or heat at once)."*
--
-- **So a machine is one thing, not a pump and a cooler to be linked separately.**
-- The pump is part of the machine here, and modelling it as its own object would
-- be a join nobody at this winery can point at.
--
-- Seven vessels carry a jacket today and three of them are cooling at 1C, and
-- there is nothing anywhere saying which machine is doing that work. The
-- question that cannot be answered is the one that matters at 2am: this machine
-- is struggling, what is on it.
--
-- **Which way a machine is running is derived, not told.** A machine cooling is
-- a machine with a jacket calling for cold on it. Storing a direction on the
-- machine as well would be two facts that disagree by November, and the second
-- one is always the stale one. This is the same move `0097` made for a room.
--
-- **One direction at a time, and it is a real refusal.** The small machine has
-- no heater, so a vessel held warm cannot be on it: that is not a mistake to
-- warn about, it is a sentence about a machine that physically cannot do it, and
-- it is refused at the hookup and again at the moment somebody sets the mode,
-- because the mode can change long after the hose was connected.
--
-- **Two directions on the machine that can do both is surfaced, not refused.**
-- The big machine cools or heats, never both at once, so a tank cooling and a
-- tank heating on it is a contradiction. It is still let through, for the reason
-- the winemaker gave about barrels: somebody can do the thing before telling the
-- app, and an app that refuses to record what already happened is an app people
-- stop telling. It lands in `glycol_conflict` instead, which is a worklist and
-- not a flag anybody has to clear.
--
-- **A hookup is a period.** Hoses move during harvest and he wants the history,
-- so this has the shape `placement` has: a start, an open end, and a close when
-- it comes off. One open hookup per vessel, by index rather than by trust.

begin;

-- ---------------------------------------------------------------------------
-- The machines
-- ---------------------------------------------------------------------------

create table if not exists glycol_machine (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  -- The one fact that separates his two machines, and the one the refusal below
  -- turns on. Cooling is assumed: a glycol machine that cannot cool is not one.
  can_heat    boolean not null default false,
  -- Where it stands, so it can be drawn on the map later. Nullable because
  -- nobody should have to answer it to register a machine mid harvest.
  location_id uuid references location (id) on delete set null,
  active      boolean not null default true,
  attributes  jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  created_by  uuid references app_user (id)
);

comment on table glycol_machine is
  'A glycol machine: pump and cooler in one unit, which is how this winery has '
  'them. can_heat is the difference between the two. Which way it is running is '
  'derived from the jackets on it, never stored. See 0100.';

alter table glycol_machine enable row level security;

drop policy if exists glycol_machine_read on glycol_machine;
create policy glycol_machine_read on glycol_machine for select to authenticated
  using (is_facility_user());
drop policy if exists glycol_machine_write on glycol_machine;
create policy glycol_machine_write on glycol_machine for all to authenticated
  using (is_facility_user()) with check (is_facility_user());

-- ---------------------------------------------------------------------------
-- What is hooked to what, and what was
-- ---------------------------------------------------------------------------

create table if not exists glycol_hookup (
  id         uuid primary key default gen_random_uuid(),
  vessel_id  uuid not null references vessel (id) on delete cascade,
  machine_id uuid not null references glycol_machine (id) on delete cascade,
  from_at    timestamptz not null default now(),
  -- Null while the hose is on. The same shape placement uses, for the same
  -- reason: "what is on it now" and "what was on it in October" are one table.
  to_at      timestamptz,
  created_by uuid references app_user (id),
  constraint glycol_hookup_ends_after_it_starts check (to_at is null or to_at >= from_at)
);

comment on table glycol_hookup is
  'A period during which a vessel was hooked to a glycol machine. Open ended '
  'while the hose is on. See 0100.';

-- One hose per jacket. By index rather than by every writer remembering to
-- close the old one first.
create unique index if not exists glycol_hookup_one_open_per_vessel
  on glycol_hookup (vessel_id) where to_at is null;

create index if not exists glycol_hookup_by_machine
  on glycol_hookup (machine_id) where to_at is null;

alter table glycol_hookup enable row level security;

drop policy if exists glycol_hookup_read on glycol_hookup;
create policy glycol_hookup_read on glycol_hookup for select to authenticated
  using (is_facility_user());
drop policy if exists glycol_hookup_write on glycol_hookup;
create policy glycol_hookup_write on glycol_hookup for all to authenticated
  using (is_facility_user()) with check (is_facility_user());

-- ---------------------------------------------------------------------------
-- Registering one
-- ---------------------------------------------------------------------------

create or replace function register_glycol_machine(
  p_name        text,
  p_can_heat    boolean default false,
  p_location_id uuid    default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  nm  text := nullif(btrim(coalesce(p_name, '')), '');
  one uuid;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here registers a glycol machine'
      using errcode = 'insufficient_privilege';
  end if;

  if nm is null then
    raise exception 'a glycol machine needs something to be called';
  end if;

  if exists (select 1 from glycol_machine where active and lower(name) = lower(nm)) then
    raise exception 'there is already a glycol machine called %', nm;
  end if;

  insert into glycol_machine (name, can_heat, location_id, created_by)
  values (nm, coalesce(p_can_heat, false), p_location_id, auth.uid())
  returning id into one;

  return jsonb_build_object('id', one, 'name', nm, 'can_heat', coalesce(p_can_heat, false));
end;
$$;

revoke all on function register_glycol_machine(text, boolean, uuid) from public;
grant execute on function register_glycol_machine(text, boolean, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Hooking up and taking off
-- ---------------------------------------------------------------------------

create or replace function hook_up_glycol(
  p_vessel_id  uuid,
  p_machine_id uuid,
  p_at         timestamptz default now()
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  v    vessel%rowtype;
  m    glycol_machine%rowtype;
  open_id uuid;
  open_machine uuid;
  open_from timestamptz;
  when_ timestamptz := coalesce(p_at, now());
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here moves a glycol hose'
      using errcode = 'insufficient_privilege';
  end if;

  select * into v from vessel where id = p_vessel_id;
  if v.id is null then
    raise exception 'no vessel with id %', p_vessel_id;
  end if;
  -- A jacket is what glycol connects to. Without one there is nothing at the
  -- other end of the hose, and recording it would make the machine's load a
  -- number that includes vessels it cannot affect.
  if not v.has_glycol then
    raise exception '% has no jacket, so there is nothing to hook glycol to', v.name;
  end if;

  select * into m from glycol_machine where id = p_machine_id;
  if m.id is null then
    raise exception 'no glycol machine with id %', p_machine_id;
  end if;
  if not m.active then
    raise exception '% is not in service', m.name;
  end if;

  -- The hardware refusal. The small machine has no heater, so a vessel being
  -- held warm cannot be on it, and this is a fact about the machine rather than
  -- an opinion about good practice.
  if v.mode = 'heating' and not m.can_heat then
    raise exception '% is being held warm and % cannot heat', v.name, m.name;
  end if;

  select id, machine_id, from_at into open_id, open_machine, open_from
    from glycol_hookup
   where vessel_id = p_vessel_id and to_at is null;

  -- Already there. Said out loud rather than written twice, because a second
  -- period starting the instant the first one ends is a history that reads as
  -- somebody having moved a hose they did not touch.
  if open_machine = p_machine_id then
    return jsonb_build_object('vessel', v.name, 'machine', m.name,
                              'hooked', false, 'already', true);
  end if;

  if open_id is not null then
    if when_ < open_from then
      raise exception
        '% went onto % at % and cannot be moved before it',
        v.name, (select gm.name from glycol_machine gm where gm.id = open_machine),
        to_char(open_from, 'Mon DD HH24:MI');
    end if;
    update glycol_hookup set to_at = when_ where id = open_id;
  end if;

  insert into glycol_hookup (vessel_id, machine_id, from_at, created_by)
  values (p_vessel_id, p_machine_id, when_, auth.uid());

  return jsonb_build_object('vessel', v.name, 'machine', m.name,
                            'hooked', true, 'already', false,
                            'moved_from', open_machine);
end;
$$;

revoke all on function hook_up_glycol(uuid, uuid, timestamptz) from public;
grant execute on function hook_up_glycol(uuid, uuid, timestamptz) to authenticated;

create or replace function unhook_glycol(
  p_vessel_id uuid,
  p_at        timestamptz default now()
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  v       vessel%rowtype;
  open_id uuid;
  started timestamptz;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here moves a glycol hose'
      using errcode = 'insufficient_privilege';
  end if;

  select * into v from vessel where id = p_vessel_id;
  if v.id is null then
    raise exception 'no vessel with id %', p_vessel_id;
  end if;

  select id, from_at into open_id, started
    from glycol_hookup
   where vessel_id = p_vessel_id and to_at is null;

  -- Otherwise the check constraint speaks, and what it says is
  -- "glycol_hookup_ends_after_it_starts", to somebody standing in a barrel room
  -- holding a hose. A refusal names the winery thing it is about.
  if open_id is not null and coalesce(p_at, now()) < started then
    raise exception
      'that hose went on at % and cannot come off before it', to_char(started, 'Mon DD HH24:MI');
  end if;

  if open_id is null then
    -- Not an error and not a success. A13: the caller has to be able to tell
    -- that nothing came off, because "unhooked" with nothing hooked would read
    -- as the hose having been moved.
    return jsonb_build_object('vessel', v.name, 'unhooked', false,
                              'was_on_nothing', true);
  end if;

  update glycol_hookup set to_at = coalesce(p_at, now()) where id = open_id;
  return jsonb_build_object('vessel', v.name, 'unhooked', true,
                            'was_on_nothing', false);
end;
$$;

revoke all on function unhook_glycol(uuid, timestamptz) from public;
grant execute on function unhook_glycol(uuid, timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- The mode cannot outrun the machine
-- ---------------------------------------------------------------------------

-- The hookup refusal covers the hose moving. This covers the other order, which
-- is the common one: the hose has been on the small machine for a month and
-- somebody sets the tank to heating today. Without this the refusal is one a
-- person can walk around by doing the two things in the other sequence, which
-- is a rule that only holds when nobody is in a hurry.
create or replace function glycol_mode_fits_machine()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  m glycol_machine%rowtype;
begin
  if new.mode <> 'heating' then
    return new;
  end if;
  if old.mode = 'heating' then
    return new;
  end if;

  select gm.* into m
    from glycol_hookup h
    join glycol_machine gm on gm.id = h.machine_id
   where h.vessel_id = new.id and h.to_at is null;

  if m.id is not null and not m.can_heat then
    raise exception '% is hooked to %, which cannot heat. Move the hose first, or take it off.',
      new.name, m.name;
  end if;

  return new;
end;
$$;

drop trigger if exists vessel_glycol_mode_fits_machine on vessel;
create trigger vessel_glycol_mode_fits_machine
  before update of mode on vessel
  for each row execute function glycol_mode_fits_machine();

-- ---------------------------------------------------------------------------
-- Read from either end
-- ---------------------------------------------------------------------------

-- The vessel's end. Every jacketed vessel, including the ones on nothing, which
-- is the worklist half: a jacket connected to no machine is either fine or
-- somebody forgot, and the only way to tell is to see it listed.
create or replace view vessel_glycol with (security_invoker = true) as
select
  v.id            as vessel_id,
  v.name          as vessel,
  vt.label        as type,
  v.mode::text    as mode,
  v.setpoint_c,
  l.name          as location_name,
  h.machine_id,
  gm.name         as machine,
  gm.can_heat,
  h.from_at       as hooked_at,
  (h.machine_id is null) as on_nothing
from vessel v
join term vt on vt.id = v.type_id
left join location l on l.id = v.location_id
left join glycol_hookup h on h.vessel_id = v.id and h.to_at is null
left join glycol_machine gm on gm.id = h.machine_id
where v.active and v.has_glycol;

comment on view vessel_glycol is
  'Every jacketed vessel and the machine it is on, including the ones on '
  'nothing. See 0100.';

grant select on vessel_glycol to authenticated;

-- The machine's end. Which way it is running is derived from what is hanging
-- off it: a machine is cooling because something on it is calling for cold.
create or replace view glycol_machine_load with (security_invoker = true) as
select
  gm.id,
  gm.name,
  gm.can_heat,
  gm.active,
  l.name as location_name,
  count(h.vessel_id)                                     as vessels,
  count(*) filter (where v.mode = 'cooling')             as cooling,
  count(*) filter (where v.mode = 'heating')             as heating,
  count(*) filter (where v.mode = 'off')                 as idle,
  -- What it is doing, out of the same vocabulary a vessel and a room use.
  case
    when count(*) filter (where v.mode = 'cooling') > 0
     and count(*) filter (where v.mode = 'heating') > 0 then 'both'
    when count(*) filter (where v.mode = 'cooling') > 0 then 'cooling'
    when count(*) filter (where v.mode = 'heating') > 0 then 'heating'
    else 'off'
  end                                                    as running,
  -- The coldest thing asked of it, which is the number somebody wants when the
  -- machine is struggling.
  min(v.setpoint_c) filter (where v.mode = 'cooling')    as coldest_c,
  max(v.setpoint_c) filter (where v.mode = 'heating')    as warmest_c
from glycol_machine gm
left join location l on l.id = gm.location_id
left join glycol_hookup h on h.machine_id = gm.id and h.to_at is null
left join vessel v on v.id = h.vessel_id and v.active
group by gm.id, gm.name, gm.can_heat, gm.active, l.name;

comment on view glycol_machine_load is
  'Each glycol machine and what is hanging off it. running is derived from the '
  'jackets on it, because a machine with a tank calling for cold on it is '
  'cooling whatever anybody wrote down. See 0100.';

grant select on glycol_machine_load to authenticated;

-- A machine being asked for both at once. Surfaced rather than refused: the
-- winemaker's rule about barrels applies here too, that somebody can do the
-- thing before telling the app, and an app that will not record what already
-- happened is an app people stop telling.
create or replace view glycol_conflict with (security_invoker = true) as
select
  ml.id      as machine_id,
  ml.name    as machine,
  ml.cooling,
  ml.heating,
  (select string_agg(vg.vessel, ', ' order by vg.vessel)
     from vessel_glycol vg
    where vg.machine_id = ml.id and vg.mode = 'cooling') as cold_side,
  (select string_agg(vg.vessel, ', ' order by vg.vessel)
     from vessel_glycol vg
    where vg.machine_id = ml.id and vg.mode = 'heating') as warm_side
from glycol_machine_load ml
where ml.running = 'both';

comment on view glycol_conflict is
  'Machines asked to cool and heat at once, which none of them can do. A '
  'worklist, not a flag: it empties itself when somebody moves a hose or '
  'changes a mode. See 0100.';

grant select on glycol_conflict to authenticated;

-- ---------------------------------------------------------------------------
-- The vessel's own row says it, because that is where somebody is standing
-- ---------------------------------------------------------------------------

-- Appended, as always. 0099 is the previous definition and the only change here
-- is the last two columns.
create or replace view vessel_state with (security_invoker = true) as
 SELECT v.id,
    v.type_id,
    vt.label AS type,
    v.name,
    v.capacity_l,
    v.owner_id,
    COALESCE(o.name, NULLIF(btrim(v.attributes ->> 'on_loan_from'), '')) AS owner_name,
    v.owner_id IS NULL
      AND NOT COALESCE((v.attributes ->> 'borrowed')::boolean, false) AS facility_owned,
    v.has_glycol,
    v.setpoint_c,
    v.mode,
    v.attributes,
    l.name AS location_name,
    COALESCE(
        CASE
            WHEN v.has_glycol AND v.mode <> 'off'::thermal_mode THEN v.setpoint_c
            ELSE NULL::numeric
        END, l.ambient_c) AS effective_temp_c,
    p.node_id,
    n.name AS lot_name,
    n.variety_id,
    nv.label AS variety,
    n.vintage,
    n.product_type_id,
    np.label AS product_type,
    n.owner_id AS lot_owner_id,
    p.volume_l AS current_volume_l,
    p.from_at AS filled_at,
    p.node_id IS NULL AS is_empty,
    ( SELECT array_agg(c.code ORDER BY c.added_at) AS array_agg
           FROM vessel_code c
          WHERE c.vessel_id = v.id AND c.active) AS codes,
    lo.name AS lot_owner_name,
    n.owner_id IS NOT NULL AND n.owner_id = facility_party_id() AS lot_facility_owned,
    COALESCE(cardinality(n.hidden), 0) > 0 AND NOT may_see_all_of(n.owner_id, n.hidden) AS redacted,
    l.ambient_c AS location_ambient_c,
    l.controlled AS location_controlled,
    ( SELECT bf.lbs FROM bin_fruit bf WHERE bf.placement_id = p.id) AS fruit_lbs,
    ( SELECT bf.tons FROM bin_fruit bf WHERE bf.placement_id = p.id) AS fruit_tons,
    ( SELECT bf.pct_full FROM bin_fruit bf WHERE bf.placement_id = p.id) AS fruit_pct,
    n.non_vintage,
    CASE
        WHEN p.node_id IS NULL THEN NULL
        WHEN n.non_vintage THEN 'NV'
        ELSE n.vintage::text
    END AS vintage_label,
    -- 0100, appended. Which machine is doing the work, so the answer is on the
    -- row somebody is already looking at rather than one screen away.
    gh.machine_id AS glycol_machine_id,
    gm.name       AS glycol_machine
   FROM vessel v
     JOIN term vt ON vt.id = v.type_id
     LEFT JOIN location l ON l.id = v.location_id
     LEFT JOIN party o ON o.id = v.owner_id
     LEFT JOIN placement p ON p.vessel_id = v.id AND p.to_at IS NULL
     LEFT JOIN LATERAL visible_node(p.node_id) n ON p.node_id IS NOT NULL
     LEFT JOIN term nv ON nv.id = n.variety_id
     LEFT JOIN term np ON np.id = n.product_type_id
     LEFT JOIN party lo ON lo.id = n.owner_id
     LEFT JOIN glycol_hookup gh ON gh.vessel_id = v.id AND gh.to_at IS NULL
     LEFT JOIN glycol_machine gm ON gm.id = gh.machine_id
  WHERE v.active;

comment on view vessel_state is
  'Every active vessel and what is in it. owner_name is the party that owns it '
  'or the grower it is on loan from, and facility_owned means neither. '
  'vintage_label is the year or NV. glycol_machine is what its jacket is hooked '
  'to, null when nothing. See 0081, 0091, 0099 and 0100.';

-- ---------------------------------------------------------------------------
-- What a screen is written against
-- ---------------------------------------------------------------------------

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.glycol', 'cellar', 'Glycol machines',
   'Each machine, what is hooked to it, and which way it is being asked to run.',
   'glycol_machine_load', 'id', 'name', 170),
  ('cellar.vessel_glycol', 'cellar', 'Jackets',
   'Every jacketed vessel and the machine it is on, including the ones on nothing.',
   'vessel_glycol', 'vessel_id', 'vessel', 175)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('cellar.register_glycol_machine', 'cellar', 'Register a glycol machine',
   'A name, and whether it can heat as well as cool.',
   'register_glycol_machine', 'cellar.glycol',
   '[{"key":"name","param":"p_name","type":"text","required":true,
      "label":"Called"},
     {"key":"can_heat","param":"p_can_heat","type":"boolean","required":false,
      "label":"Can heat as well as cool",
      "note":"A machine that cannot heat refuses a vessel being held warm."},
     {"key":"where","param":"p_location_id","type":"uuid","required":false,
      "label":"Where it stands",
      "source":{"readable":"cellar.rooms"}}]'::jsonb, 280),

  ('cellar.hook_up_glycol', 'cellar', 'Hook a jacket to a machine',
   'Moves the hose. The machine it was on is closed off with today''s time, so '
   'what was on what last month survives.',
   'hook_up_glycol', 'cellar.vessel_glycol',
   '[{"key":"vessel","param":"p_vessel_id","type":"uuid","required":true,
      "label":"Which vessel",
      "source":{"readable":"cellar.vessel_glycol"}},
     {"key":"machine","param":"p_machine_id","type":"uuid","required":true,
      "label":"Which machine",
      "source":{"readable":"cellar.glycol"}},
     {"key":"when","param":"p_at","type":"timestamptz","required":false,
      "label":"When",
      "note":"Now unless you say otherwise."}]'::jsonb, 281),

  ('cellar.unhook_glycol', 'cellar', 'Take a jacket off',
   'Closes the period. The vessel keeps its jacket and its mode; it is simply '
   'on no machine.',
   'unhook_glycol', 'cellar.vessel_glycol',
   '[{"key":"vessel","param":"p_vessel_id","type":"uuid","required":true,
      "label":"Which vessel",
      "source":{"readable":"cellar.vessel_glycol"}},
     {"key":"when","param":"p_at","type":"timestamptz","required":false,
      "label":"When"}]'::jsonb, 282)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

-- Not a capability. It is a trigger, and a periphery calling it directly would
-- be a periphery running a constraint by hand.
insert into capability_exemption (fn, reason) values
  ('glycol_mode_fits_machine', 'Trigger. Refuses a vessel being set to heating while it is hooked to a machine that cannot heat.')
on conflict (fn) do nothing;

commit;
