-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A bin reports what the scale said about it, and how full somebody
--           guessed it was never becomes a weight."
-- Depends on: [supabase/migrations/0092_gross_or_net_and_a_bulging_bin.sql,
--              supabase/migrations/0042_weighing_photo.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-4 (a measurement outranks an estimate, and a guess never
--                  wears a measurement's clothes), A25 (no figure at all is
--                  reported as no figure rather than as a plausible number)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- Two things the winemaker said, an hour apart, and the second one is the rule.
--
-- *"Why is that correct but the current pick isn't?"*, with a screenshot of his
-- own weighings: every bin already weighed, one at a time, with a photograph of
-- each.
--
--     PB4  889 net, 981 gross      PB7  413 net, 505 gross
--     PB5  844 net, 936 gross      PB8  645 net, 737 gross
--     PB6  831 net, 923 gross
--
-- And `bin_fruit` was reporting 850, 850, 850, 425 and 680. Two records of one
-- thing, and the app was displaying the weaker one.
--
-- *"I think the problem is the % full. That is literally just a guess. It
-- shouldn't be used in a calculation except to see the difference between my
-- guesses and reality."*
--
-- **Both are true and the second is the deeper one.** `0087` multiplied a
-- percentage by a nominal and produced a number that looked exactly like a
-- weight: 850 lb, 0.43 ton, sitting in the same column as a figure off a scale.
-- Nothing downstream could tell them apart, so a guess went into a press load,
-- a yield and a tonnage.
--
-- So a percentage stops being a source of pounds entirely. A bin's weight comes
-- from a weighing of that bin, or from pounds somebody typed, and otherwise
-- there is no weight and the app says so. The percentage stays exactly where he
-- put it: beside the real number, so the guess can be compared with what turned
-- up.
--
-- **`0087` should not have existed in the shape it did.** `weigh_bins` has
-- recorded gross, tare and net against named bins since `0042`, and a weighing
-- naming one bin is a per-bin weight with a photograph and an author behind it.
-- What was missing was a screen that showed it. A second, weaker record of the
-- same fact got built instead.
--
-- **A weighing covering several bins is not a per-bin weight** and is not used
-- here: two bins on one pallet give one number, and splitting it evenly would
-- invent two measurements out of one.

begin;

create or replace view bin_fruit with (security_invoker = true) as
with weighed as (
  -- The latest live weighing that names this bin and nothing else. Superseded
  -- ones are excluded the way 0042 excludes them: by another event naming them.
  select distinct on (e.subject_id, (e.data -> 'bins' ->> 0))
    (e.data -> 'bins' ->> 0)::uuid    as vessel_id,
    e.subject_id                      as node_id,
    (e.data ->> 'net_lbs')::numeric   as net_lbs,
    (e.data ->> 'gross_lbs')::numeric as gross_lbs,
    (e.data ->> 'tare_lbs')::numeric  as tare_lbs,
    e.at
  from event e
  where e.operation_id = term_id('operation', 'weigh')
    and e.subject_type = 'node'
    and jsonb_array_length(e.data -> 'bins') = 1
    and not exists (
      select 1 from event s
       where s.operation_id = term_id('operation', 'weigh')
         and (s.data ->> 'supersedes')::uuid = e.id
    )
  order by e.subject_id, (e.data -> 'bins' ->> 0), e.at desc
)
select
  p.id           as placement_id,
  p.vessel_id,
  v.name         as bin,
  p.node_id,
  n.name         as pick,
  p.from_at,
  p.net_lbs      as said_net,
  p.gross_lbs    as said_gross,
  -- The guess, kept and never multiplied by anything. It is here to be compared
  -- with `pct_full` below, which is what actually turned up.
  p.fill_pct     as said_pct,
  nullif((vt.attributes ->> 'full_lbs')::numeric, 0) as full_lbs,
  coalesce(w.tare_lbs, nullif((vt.attributes ->> 'tare_lbs')::numeric, 0)) as tare_lbs,
  -- The scale first, then pounds somebody typed. **No percentage anywhere in
  -- this.** A bin nobody has weighed and nobody has given pounds for has no
  -- weight, and null is the honest answer.
  coalesce(
    w.net_lbs,
    p.net_lbs,
    p.gross_lbs - nullif((vt.attributes ->> 'tare_lbs')::numeric, 0)
  )              as lbs,
  coalesce(
    w.gross_lbs,
    p.gross_lbs,
    p.net_lbs + nullif((vt.attributes ->> 'tare_lbs')::numeric, 0)
  )              as gross,
  -- What it turned out to be, as a percentage of a nominal bin. Derived from
  -- the weight and never from the guess, so that sitting next to `said_pct` it
  -- answers the question he asked it to answer.
  round(
    coalesce(
      w.net_lbs,
      p.net_lbs,
      p.gross_lbs - nullif((vt.attributes ->> 'tare_lbs')::numeric, 0)
    ) / nullif((vt.attributes ->> 'full_lbs')::numeric, 0) * 100, 0
  )              as pct_full,
  round(
    coalesce(
      w.net_lbs,
      p.net_lbs,
      p.gross_lbs - nullif((vt.attributes ->> 'tare_lbs')::numeric, 0)
    ) / 2000.0, 3)  as tons,
  -- Which of the three this is, and `weighed` is the only one anybody measured.
  -- A bin with only a guess says `pct` and has no pounds at all.
  case
    when w.net_lbs   is not null then 'weighed'
    when p.net_lbs   is not null then 'net'
    when p.gross_lbs is not null then 'gross'
    when p.fill_pct  is not null then 'pct'
  end            as said_as,
  w.at           as weighed_at
from placement p
join vessel v on v.id = p.vessel_id
join term vt on vt.id = v.type_id
  and coalesce((vt.attributes ->> 'intake_bin')::boolean, false)
left join node n on n.id = p.node_id
left join weighed w on w.vessel_id = p.vessel_id and w.node_id = p.node_id
where p.to_at is null;

comment on view bin_fruit is
  'What is in each full picking bin, best evidence first: a weighing of that bin '
  'alone, then pounds somebody typed. A percentage is a guess and never becomes '
  'a weight: a bin with only a guess has no pounds here. `said_pct` is what was '
  'guessed and `pct_full` is what turned up, so the two can be compared. See '
  '0087, 0092 and 0093.';

commit;
