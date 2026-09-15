-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A fill recorded at the same instant as a recondition counts as
--           after it, because the other way round calls a red barrel white."
-- Depends on: [supabase/migrations/0072_a_barrel_remembers.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0077_a_barrel_can_arrive_red.sql]
-- Axioms enforced: A25 (where a comparison can go either way, it goes the way
--                  that does not quietly permit the thing it guards against)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- `0072` asked for placements strictly after the last recondition. Two things
-- make that wrong at the boundary. `now()` is transaction start time, so a
-- recondition and a fill recorded in one transaction carry the identical
-- timestamp; and a backdated fill can legitimately land on the same second as
-- the treatment.
--
-- **A tie is not a coin toss here, because the two answers are not equally
-- wrong.** Counting the fill as before the recondition says a barrel with red
-- in it is white, which is the mistake this whole feature exists to prevent.
-- Counting it as after says a barrel that may be clean is red, which costs
-- somebody a recondition they did not strictly need. One of those ruins a wine
-- and the other wastes an afternoon.
--
-- Found by an assertion that reconditioned a barrel and refilled it in the same
-- transaction, which is not how a winery works and is exactly how a test works.

begin;

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
  -- At or after the last recondition, or all of it if there has never been one.
  -- The tie goes to the barrel. See the header.
  where p.from_at >= coalesce(r.at, '-infinity'::timestamptz)
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

commit;
