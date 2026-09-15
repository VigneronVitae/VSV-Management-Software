-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A sample says whether it is vineyard, juice or wine, derived from
--           what was sampled, so the three can be told apart without anybody
--           choosing a category when they take one."
-- Depends on: [supabase/migrations/0067_sampling.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0083_what_you_can_sample.sql]
-- Axioms enforced: T0-2 (the kind is a function of the subject and the lot, and
--                  is never stored), T1-4 (taking a sample stays one tap: the
--                  separation costs the person nothing at the moment of doing it)
-- Open sorries: S-83 (the kind follows the lot's stage now, not its stage on
--                the day of the sample)
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"vineyard sampling and juice sampling and wine sampling should
-- all be easily separated. Vineyard sampling is watching the fruit over time to
-- see when to pick. Juice sampling and wine sampling are similar, but I want to
-- have filters to separate them so you don't have to navigate through previous
-- vintages wine to find the only things we're really taking samples of often."*
--
-- **Three activities, one act.** Somebody walks a block with a refractometer,
-- somebody pulls a sample off a fermenter, somebody thieves a barrel. The thing
-- recorded is identical and the reason for recording is not: the first is
-- watching fruit ripen toward a pick date, the second is watching a ferment, and
-- the third is watching wine that will sit for a year.
--
-- **Nobody should have to say which.** `0067` already records what was sampled,
-- and what was sampled answers the question. A vineyard, a block or a planting
-- is fruit on the vine. A vessel is juice or wine, and which one depends on what
-- is in it. Asking for a category as well would be asking somebody to type an
-- answer the database already has, which is R-4.
--
-- **The filter is the whole point.** Two custom crush clients' wine sits in
-- barrel across two vintages, and during harvest none of it is being sampled
-- weekly while every ferment is. A list that mixes them buries the work in the
-- archive.

begin;

create or replace view sample with (security_invoker = true) as
with lot_at as (
  -- What was in the vessel when the sample was taken, not what is in it now. A
  -- barrel sampled in March and refilled in October has two different answers
  -- and only one of them is about the sample.
  select
    e.id as event_id,
    p.node_id
  from event e
  join placement p
    on p.vessel_id = e.subject_id
   and p.from_at <= e.at
   and (p.to_at is null or p.to_at > e.at)
  where e.subject_type = 'vessel'
    and e.operation_id = term_id('operation', 'sample')
)
select
  e.id            as event_id,
  e.subject_type,
  e.subject_id,
  resolve_subject_name(e.subject_type, e.subject_id) as of_what,
  e.at,
  e.data ->> 'note' as note,
  u.name          as by_name,
  (select count(*) from note n
    where n.about_event = e.id and n.kind_id is not null) as readings,
  -- The separation, derived. See S-83 for the one way this is approximate.
  case
    when e.subject_type in ('vineyard', 'block', 'planting') then 'vineyard'
    when n.stage in ('bin', 'load', 'ferment') then 'juice'
    when n.stage in ('maturation', 'finished') then 'wine'
    -- A vessel that held nothing when it was sampled. Rare, real, and not
    -- silently filed under one of the three: an empty vessel somebody sampled
    -- is a question rather than a category.
    else 'unknown'
  end             as kind,
  n.id            as node_id,
  n.name          as lot_name,
  n.vintage,
  n.non_vintage,
  vr.label        as variety,
  n.owner_id      as lot_owner_id,
  ow.name         as lot_owner_name
from event e
left join app_user u on u.id = e.by_user
left join lot_at la on la.event_id = e.id
left join node n on n.id = la.node_id
left join term vr on vr.id = n.variety_id
left join party ow on ow.id = n.owner_id
where e.operation_id = term_id('operation', 'sample');

comment on view sample is
  'Every sample, what it was of, and how many readings have been typed against '
  'it. `kind` is vineyard, juice or wine, derived from the subject and from the '
  'lot that was in the vessel at the time. A sample stores no readings of its '
  'own: they are typed notes whose about_event is the sample. See 0067 and 0082.';

commit;
