-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A barrel bought red is red before it has held anything here, so the
--           derivation starts from what somebody said about it rather than from
--           an empty history."
-- Depends on: [supabase/migrations/0072_a_barrel_remembers.sql,
--              supabase/migrations/0076_a_tie_goes_to_the_barrel.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-3 (the told value is an event with an author and a time,
--                  not a column somebody overwrites), A25 (a barrel nobody has
--                  said anything about is not thereby white)
-- Open sorries: S-80 (still barrels only)
-- ---------------------------------------------------------------------------
--
-- The winemaker, on the derivation in `0072`: *"But it also belongs on the
-- barrel (like for the red and white neutral barrels we purchase)."*
--
-- **`0072` had this exactly half right.** Deriving from placements is correct
-- for every barrel this winery has filled, and it is silent about the barrel
-- that arrives on a pallet having already held three vintages of somebody
-- else's Pinot. That barrel has no placements here, so it read `white`, which is
-- the one answer that could ruin a wine.
--
-- So: a declaration. Somebody says what a barrel is when it arrives, and the
-- derivation starts there instead of at the beginning of time. Everything after
-- it still derives, which is the half that must not be given up: a declared
-- white barrel turns red the moment red goes in it, exactly as before.
--
-- **A declaration is not a process, and cannot be used as one.** Declaring a
-- barrel white after it has held red here would be a way around the rule that a
-- red barrel only turns white if somebody shaved, retoasted or deep cleaned it,
-- so that specific declaration is refused and says to record the recondition
-- instead. Declaring red is always allowed: there is no rule against admitting
-- a barrel is more stained than the record shows.
--
-- **Red outranks unknown.** A barrel declared red that later holds a lot nobody
-- typed stays red. Unknown means "nothing here says this is red and something
-- in it is unaccounted for", which stops being true the moment something says
-- it is red.

begin;

insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'barrel_declared', 'Barrel colour recorded', 71,
   '{"effect": "measurement"}'::jsonb)
on conflict (kind, value) do nothing;

-- Measurement rather than treatment, and the distinction is the point: a
-- recondition changes the barrel, and this records something that was already
-- true of it before it got here.
create or replace function declare_barrel_colour(
  p_vessel_id uuid,
  p_colour    text,
  p_note      text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  v    vessel%rowtype;
  vt   text;
  want text := lower(btrim(coalesce(p_colour, '')));
  now_ text;
  eid  uuid;
begin
  select * into v from vessel where id = p_vessel_id;
  if v.id is null then
    raise exception 'no vessel with id %', p_vessel_id;
  end if;

  select value into vt from term where id = v.type_id;
  if vt <> 'barrel' then
    raise exception '% is a %, and only a barrel holds colour', v.name, vt;
  end if;

  -- Two states, not four. A wine is red, orange, rose or white; a barrel has
  -- either held something that stains or it has not, and the vocabulary of the
  -- one is not the vocabulary of the other.
  if want not in ('red', 'white') then
    raise exception
      'a barrel is red or white. % is a colour a wine is, and what it does to oak is either staining or not', p_colour;
  end if;

  if want = 'white' then
    select colour into now_ from barrel_colour where id = p_vessel_id;
    if now_ = 'red' then
      raise exception
        'this barrel has held red here, and saying it is white does not make it white. Record what was done to it instead: shaved, retoasted or deep cleaned'
        using errcode = 'check_violation';
    end if;
  end if;

  insert into event (subject_type, subject_id, operation_id, by_user, data)
  values ('vessel', p_vessel_id, term_id('operation', 'barrel_declared'), auth.uid(),
          jsonb_build_object('colour', want,
                             'note', nullif(btrim(coalesce(p_note, '')), '')))
  returning id into eid;

  return jsonb_build_object('event', eid, 'vessel', p_vessel_id, 'colour', want);
end;
$$;

revoke all on function declare_barrel_colour(uuid, text, text) from public;
grant execute on function declare_barrel_colour(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- The derivation, starting from whatever was last said
-- ---------------------------------------------------------------------------

create or replace view barrel_colour with (security_invoker = true) as
with said as (
  -- Both kinds of statement about a barrel, in one stream. A recondition says
  -- white by doing something; a declaration says whichever by asserting it. The
  -- latest one is where the derivation starts.
  select
    e.subject_id as vessel_id,
    e.at,
    case when e.operation_id = term_id('operation', 'recondition')
         then 'white' else e.data ->> 'colour' end as colour,
    row_number() over (partition by e.subject_id order by e.at desc, e.created_at desc) as rn
  from event e
  where e.subject_type = 'vessel'
    and e.operation_id in (term_id('operation', 'recondition'),
                           term_id('operation', 'barrel_declared'))
),
base as (
  select vessel_id, at, colour from said where rn = 1
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
  left join base b on b.vessel_id = p.vessel_id
  -- At or after the last thing anybody said about it. The tie goes to the
  -- barrel, which is 0076.
  where p.from_at >= coalesce(b.at, '-infinity'::timestamptz)
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
    -- Something that stains has been in it since. Nothing outranks this.
    when s.vessel_id is not null then 'red'
    -- Or somebody said it arrived red, which a lot nobody has typed does not
    -- cast doubt on: unknown means nothing says red, and something does.
    when b.colour = 'red' then 'red'
    when u.vessel_id is not null then 'unknown'
    else 'white'
  end as colour,
  case
    when s.vessel_id is not null then n.name
    when b.colour = 'red' then 'it arrived that way'
  end as went_red_with,
  coalesce(s.from_at, case when b.colour = 'red' then b.at end) as went_red_at,
  case when b.colour = 'white' then b.at end as reconditioned_at,
  v.location_id,
  v.active
from vessel v
join term vt on vt.id = v.type_id and vt.value = 'barrel'
left join stained s on s.vessel_id = v.id
left join untold  u on u.vessel_id = v.id
left join node n on n.id = s.node_id
left join base b on b.vessel_id = v.id;

comment on view barrel_colour is
  'Red, white or unknown. Derived from everything the barrel has held since the '
  'last thing anybody said about it, which is either a recondition or a '
  'declaration that it arrived a given colour. Never stored. Unknown means it '
  'has held a lot nobody has typed and nothing says it is red. See 0072 and 0077.';

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('cellar.declare_barrel_colour', 'cellar', 'Say what a barrel arrived as',
   'For a barrel bought used. Red if it has held red somewhere else, white for a '
   'neutral one. Everything after this still derives from what goes in it.',
   'declare_barrel_colour', 'cellar.barrel_colours',
   '[{"key":"barrel","param":"p_vessel_id","type":"uuid","required":true,
      "label":"Which barrel",
      "source":{"readable":"cellar.barrel_colours"}},
     {"key":"colour","param":"p_colour","type":"text","required":true,
      "label":"Red or white",
      "note":"A barrel is one or the other. Saying white is refused if it has held red here."},
     {"key":"note","param":"p_note","type":"text","required":false,
      "label":"Note",
      "note":"Where it came from, and what was in it."}]'::jsonb, 220)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

commit;
