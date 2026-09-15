-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Every draw off a press, in the order it came off, because a press
--           recorded in four goes over three hours has a shape that its total
--           does not show."
-- Depends on: [supabase/migrations/0052_press_as_a_process.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (a cut's volume is the sum of its draws and is not
--                  stored twice), T0-5 (a draw is an event and a correction is
--                  another one)
-- ---------------------------------------------------------------------------
--
-- `0052` recorded every draw as its own event and then only ever showed the
-- total. That is enough to start a press and finish it, and it is not enough to
-- look at one: "400 L at 9:20, 150 more at 10:05, 90 of hard press at 11:40" is
-- the record of a morning, and "640 L" is a number.
--
-- Built for the log layout of the press screen, which is one of three the
-- winemaker asked for so he could tell which one works with wet hands. The view
-- is worth having whichever layout wins: it is the answer to "what came off
-- when", which is the question anybody asks when a press yields less than it
-- should have.
--
-- **Superseded draws are marked, not hidden.** A misread gauge corrected an hour
-- later is part of what happened, and a list that silently drops the first
-- number is a list somebody cannot reconcile against the paper.

begin;

create or replace view press_draw with (security_invoker = true) as
select
  e.id            as event_id,
  (e.data ->> 'load')::uuid as load_id,
  e.subject_id    as cut_id,
  c.name          as cut_name,
  c.attributes ->> 'cut_label' as cut_label,
  e.at,
  (e.data ->> 'volume_l')::numeric as volume_l,
  v.id            as vessel_id,
  v.name          as vessel_name,
  e.data ->> 'note' as note,
  u.name          as by_name,
  exists (
    select 1 from event s
     where s.subject_type = 'node' and s.subject_id = e.subject_id
       and (s.data ->> 'supersedes')::uuid = e.id
  ) as superseded
from event e
join node c on c.id = e.subject_id
left join vessel v on v.id = (e.data ->> 'vessel')::uuid
left join app_user u on u.id = e.by_user
where e.subject_type = 'node'
  and e.operation_id = term_id('operation', 'press')
  and e.data ->> 'action' = 'drawn';

comment on view press_draw is
  'Every draw off every press, newest last, with the vessel it went into and '
  'who recorded it. A superseded draw is marked rather than dropped, because a '
  'corrected number is part of what happened. See 0055.';

commit;
