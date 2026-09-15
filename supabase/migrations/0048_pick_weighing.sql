-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The weighings of a pick, read back as a list, so somebody arriving
--           that evening with three photographs can tell which reading each of
--           them is of."
-- Depends on: [supabase/migrations/0042_weighing_photo.sql,
--              supabase/migrations/0047_attachments.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0059_a_weighing_says_its_pick.sql]
-- Axioms enforced: T0-2 (which reading is live is derived from the events and
--                  not stored anywhere)
-- ---------------------------------------------------------------------------
--
-- `weigh_bins` answers the person who made the reading. It says the gross, the
-- tare, the net and the running total, which is exactly what somebody standing
-- at the scale wants. It says nothing to the person who comes back that evening
-- with three photographs on a phone and no memory of which was which.
--
-- That person needs the readings listed, in order, with the bins that were on
-- the scale for each, because "747" means nothing and "747 lbs, PB1 and PB2, at
-- 9:12" is identifiable from a photograph of a display.
--
-- **Which reading is live is a rule and it belongs here.** A correction is a new
-- weighing naming the one it replaces, so the superseded one is still in the
-- events and must not be added twice. A screen working that out from a list of
-- events would be a client encoding a kernel rule, and the second client would
-- work it out differently. So the view answers it.

begin;

create or replace view pick_weighing with (security_invoker = true) as
select
  e.subject_id as node_id,
  e.id         as event_id,
  e.at,
  (e.data ->> 'gross_lbs')::numeric as gross_lbs,
  (e.data ->> 'tare_lbs')::numeric  as tare_lbs,
  (e.data ->> 'net_lbs')::numeric   as net_lbs,
  -- The bins by name rather than by id, because a name is what is painted on
  -- the side of one and an id is not.
  coalesce(
    (select array_agg(v.name order by v.name)
       from jsonb_array_elements_text(e.data -> 'bins') as b(vessel_id)
       join vessel v on v.id = b.vessel_id::uuid),
    array[]::text[]) as bins,
  e.data ->> 'note' as note,
  -- Kept rather than filtered out. A corrected reading is part of the record of
  -- the day, and hiding it would make the pick's total look like it came from
  -- nowhere. The flag is what lets a screen show it greyed rather than counted.
  exists (
    select 1 from event s
     where s.subject_type = 'node' and s.subject_id = e.subject_id
       and s.operation_id = term_id('operation', 'weigh')
       and (s.data ->> 'supersedes')::uuid = e.id
  ) as superseded,
  (select count(*) from attachment a where a.about_event = e.id) as photos
from event e
where e.subject_type = 'node'
  and e.operation_id = term_id('operation', 'weigh');

comment on view pick_weighing is
  'Every weighing of every pick, with the bins that were on the scale and how '
  'many photographs name it. `superseded` says a later reading corrected this '
  'one, which is derived from the events rather than stored. See 0048.';

commit;
