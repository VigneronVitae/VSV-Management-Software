-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Whether a barrel is red or white is derived from what has been in
--           it since it was last reconditioned, so nobody has to remember and
--           nobody has to maintain a second field that drifts."
-- Depends on: [supabase/migrations/0071_a_wine_says_its_colour.sql,
--              supabase/migrations/0014_rack.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0073_the_contract_hears_about_colour.sql,
--                  supabase/migrations/0076_a_tie_goes_to_the_barrel.sql,
--                  supabase/migrations/0077_a_barrel_can_arrive_red.sql]
-- Axioms enforced: T0-2 (a barrel's colour is a function of its placements and
--                  is never stored), A25 (an untold colour is its own answer and
--                  never a permissive default), A13 (the conflict is surfaced as
--                  a worklist rather than as a refusal nobody sees)
-- Open sorries: S-80 (only barrels; concrete and amphora are left out)
-- ---------------------------------------------------------------------------
--
-- The winemaker asked for red and white barrels: reds leave colour, so a white
-- should not go into a barrel that has held red. A white barrel turns red the
-- moment red goes in it. A red barrel turns white only if somebody does a
-- process to it, retoasting or deep cleaning. Rose goes in either and turns
-- nothing red. And, on whether it should be a vessel type: "it should actually
-- be derived (or told)".
--
-- **It is derived, and there is nothing to tell.** `placement` has held the
-- whole history of what has been in every vessel since `0001`: node, vessel,
-- from and to. A barrel is red if something that stains has been in it since the
-- last time somebody reconditioned it. That is one query, it cannot drift, and
-- it is right about barrels that were filled before this migration existed.
--
-- **Sixteen call sites put wine in a vessel.** Refusing at each of them would be
-- sixteen edits and sixteen chances to miss one, and the winemaker settled the
-- question anyway when asked whether to refuse or warn: "warn and let through
-- because somebody could put the wine in the barrel before using the app.
-- Wouldn't be smart but definitely possible." The app records what happened; it
-- does not get to say it did not happen. So nothing here refuses a fill. The
-- conflict is a derived worklist, which is the same mechanism as every other
-- catch in this schema, and it catches the barrel somebody filled on Tuesday and
-- recorded on Thursday.
--
-- **Three states, not two.** A barrel that has held a lot nobody has said a
-- colour for is `unknown`, not `white`. Calling it white would be a default
-- permitting the exact mistake this is for, which is the A25 class: an absent
-- answer read as a favourable one. It is also what makes `lot_without_colour`
-- load-bearing rather than tidy.

begin;

insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'recondition', 'Barrel reconditioned', 70,
   '{"effect": "treatment"}'::jsonb)
on conflict (kind, value) do nothing;

-- ---------------------------------------------------------------------------
-- Told: the process that makes a red barrel white again
-- ---------------------------------------------------------------------------

-- Red barrels do not turn white unless somebody does a process to them, so the
-- method is required. An event that says a barrel was reconditioned and does not
-- say how is the paperwork for a thing that may not have happened, and this is
-- the one write in this migration, so it is the one place a refusal belongs.
create or replace function recondition_barrel(
  p_vessel_id uuid,
  p_method    text,
  p_note      text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  v   vessel%rowtype;
  vt  text;
  eid uuid;
begin
  select * into v from vessel where id = p_vessel_id;
  if v.id is null then
    raise exception 'no vessel with id %', p_vessel_id;
  end if;

  select value into vt from term where id = v.type_id;
  if vt <> 'barrel' then
    raise exception '% is a %, and reconditioning is a thing done to a barrel', v.name, vt;
  end if;

  if p_method is null or btrim(p_method) = '' then
    raise exception
      'say what was done to it. A barrel that has held red is white again because somebody shaved it, retoasted it or deep cleaned it, and which one is the whole of the evidence';
  end if;

  insert into event (subject_type, subject_id, operation_id, by_user, data)
  values ('vessel', p_vessel_id, term_id('operation', 'recondition'), auth.uid(),
          jsonb_build_object('method', btrim(p_method),
                             'note', nullif(btrim(coalesce(p_note, '')), '')))
  returning id into eid;

  return jsonb_build_object('event', eid, 'vessel', p_vessel_id,
                            'method', btrim(p_method));
end;
$$;

revoke all on function recondition_barrel(uuid, text, text) from public;
grant execute on function recondition_barrel(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Derived: what a barrel is now
-- ---------------------------------------------------------------------------

create or replace view barrel_colour with (security_invoker = true) as
with reset as (
  select e.subject_id as vessel_id, max(e.at) as at
    from event e
   where e.subject_type = 'vessel'
     and e.operation_id = term_id('operation', 'recondition')
   group by e.subject_id
),
held as (
  select
    p.vessel_id,
    p.node_id,
    p.from_at,
    lot_colour(p.node_id) as colour_id
  from placement p
  join vessel v on v.id = p.vessel_id
  join term vt on vt.id = v.type_id and vt.value = 'barrel'
  left join reset r on r.vessel_id = p.vessel_id
  -- Since the last recondition, or all of it if there has never been one.
  where p.from_at > coalesce(r.at, '-infinity'::timestamptz)
),
stained as (
  select distinct on (h.vessel_id)
         h.vessel_id, h.node_id, h.from_at
    from held h
   where colour_stains(h.colour_id)
   order by h.vessel_id, h.from_at
),
untold as (
  select distinct vessel_id from held where colour_id is null
)
select
  v.id,
  v.name,
  case
    when s.vessel_id is not null then 'red'
    when u.vessel_id is not null then 'unknown'
    else 'white'
  end as colour,
  -- What made it red, and when. A barrel nobody can account for is worth less
  -- than a barrel whose red says which lot and which day it came from.
  n.name      as went_red_with,
  s.from_at   as went_red_at,
  r.at        as reconditioned_at,
  v.location_id,
  v.active
from vessel v
join term vt on vt.id = v.type_id and vt.value = 'barrel'
left join stained s on s.vessel_id = v.id
left join untold  u on u.vessel_id = v.id
left join node n on n.id = s.node_id
left join reset r on r.vessel_id = v.id;

comment on view barrel_colour is
  'Red, white or unknown, derived from everything the barrel has held since it '
  'was last reconditioned. Never stored. Unknown means it has held a lot nobody '
  'has said a colour for, which is not the same as white. See 0072.';

grant select on barrel_colour to authenticated;

-- ---------------------------------------------------------------------------
-- The catch
-- ---------------------------------------------------------------------------

-- Nothing refused this and nothing is going to. This is the list somebody looks
-- at, and it is right about wine that went into a barrel before anybody opened
-- the app, which is the case the winemaker named.
create or replace view white_in_a_red_barrel with (security_invoker = true) as
select
  b.id   as vessel_id,
  b.name as vessel,
  n.id   as node_id,
  n.name as lot,
  c.label as lot_colour,
  b.went_red_with,
  b.went_red_at,
  p.from_at as filled_at
from barrel_colour b
join placement p on p.vessel_id = b.id and p.to_at is null
join node n on n.id = p.node_id
join term c on c.id = lot_colour(n.id)
where b.colour = 'red'
  and not colour_stains(lot_colour(n.id))
order by p.from_at desc;

comment on view white_in_a_red_barrel is
  'Wine that does not stain, sitting in a barrel that has held wine that does. '
  'Not an error and not refused: the winemaker asked for a warning rather than a '
  'refusal, because a barrel can be filled before anybody records it. See 0072.';

grant select on white_in_a_red_barrel to authenticated;

-- What a screen asks before it offers a vessel, so that the rule lives here
-- rather than in a client. A second periphery asking the same question gets the
-- same answer, which is the whole of AR-Q8.
create or replace function barrel_warning(p_vessel_id uuid, p_node_id uuid)
returns jsonb
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
  select case
    when b.id is null then jsonb_build_object('warn', false)
    when b.colour = 'red' and lot_colour(p_node_id) is null then
      jsonb_build_object(
        'warn', true, 'colour', b.colour,
        'why', b.name || ' has held red since ' || coalesce(b.went_red_with, 'an earlier lot')
               || ', and nobody has said what colour this wine is')
    when b.colour = 'red' and not colour_stains(lot_colour(p_node_id)) then
      jsonb_build_object(
        'warn', true, 'colour', b.colour,
        'why', b.name || ' went red with ' || coalesce(b.went_red_with, 'an earlier lot')
               || ', so it will leave colour in this wine')
    else jsonb_build_object('warn', false, 'colour', coalesce(b.colour, 'not a barrel'))
  end
  from (select 1 as one) o
  left join barrel_colour b on b.id = p_vessel_id;
$$;

comment on function barrel_warning(uuid, uuid) is
  'Whether putting this lot in this vessel is worth a word first, and what to '
  'say. A vessel that is not a barrel warns about nothing. See 0072.';

revoke all on function barrel_warning(uuid, uuid) from public;
grant execute on function barrel_warning(uuid, uuid) to authenticated;

commit;
