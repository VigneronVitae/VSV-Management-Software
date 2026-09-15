-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A weighing carries the name of the pick it is of, so a periphery
--           listing weighings can say what each one is a weighing of."
-- Depends on: [supabase/migrations/0048_pick_weighing.sql,
--              supabase/migrations/0057_the_contract.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: none. A view gains a column the contract asked for.
-- ---------------------------------------------------------------------------
--
-- The second thing `0057` found, and found the same way: the contract declares
-- that `cellar.pick_weighings` can be labelled by `pick_name`, the assertion
-- asked the catalog whether that column exists, and it does not. `0048` built
-- the view for one screen that already knew which pick it was looking at, so the
-- name was never needed and never added.
--
-- A periphery does not have that context. Given a list of weighings it has no
-- way to say what any of them is a weighing of, and "the row with id
-- 7d2e9a35" is not a thing to say to somebody. `weighing_without_photo` already
-- carries the name for exactly this reason.
--
-- **Two for two on the first day.** The contract is not finding bugs. It is
-- finding places where a screen knew something the kernel had not been asked to
-- say, which is the whole of what AR-Q8 predicted would be in there.

begin;

drop view if exists pick_weighing;
create view pick_weighing with (security_invoker = true) as
select
  e.subject_id as node_id,
  n.name       as pick_name,
  e.id         as event_id,
  e.at,
  (e.data ->> 'gross_lbs')::numeric as gross_lbs,
  (e.data ->> 'tare_lbs')::numeric  as tare_lbs,
  (e.data ->> 'net_lbs')::numeric   as net_lbs,
  coalesce(
    (select array_agg(v.name order by v.name)
       from jsonb_array_elements_text(e.data -> 'bins') as b(vessel_id)
       join vessel v on v.id = b.vessel_id::uuid),
    array[]::text[]) as bins,
  e.data ->> 'note' as note,
  exists (
    select 1 from event s
     where s.subject_type = 'node' and s.subject_id = e.subject_id
       and s.operation_id = term_id('operation', 'weigh')
       and (s.data ->> 'supersedes')::uuid = e.id
  ) as superseded,
  (select count(*) from attachment a where a.about_event = e.id) as photos
from event e
join node n on n.id = e.subject_id
where e.subject_type = 'node'
  and e.operation_id = term_id('operation', 'weigh');

comment on view pick_weighing is
  'Every weighing of every pick, with the pick it is of, the bins that were on '
  'the scale and how many photographs name it. `superseded` says a later '
  'reading corrected this one. See 0048 and 0059.';

commit;
