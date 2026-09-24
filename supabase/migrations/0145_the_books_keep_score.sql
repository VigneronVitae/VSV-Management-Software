-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The two things the books app's redesign needs to know that only the
--           kernel can say: how far through the transactions this person is,
--           and what a store on a receipt was filed as last time."
-- Depends on: [supabase/migrations/0126_only_a_person_confirms.sql,
--              supabase/migrations/0144_a_paper_says_what_money_was.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/books/src/books.ts]
-- Axioms enforced: T0-2. Both are views. A streak stored anywhere would be a
--                  second answer to a question the attestations already answer.
-- Open sorries: none new. The winery's zone is S-57's constant again.
-- ---------------------------------------------------------------------------

-- "I want you to really improve the UI/UX of the receipts and stuff. Maybe even
-- gamify one."
--
-- **The game is scored by the kernel.** Eight hundred transactions filed one
-- tap at a time is the work, and a counter, a streak and a bar that fills are
-- what make an evening of it go by. Every one of those numbers is a count over
-- `line_attestation`, which already records who confirmed what and when. If the
-- phone kept the score, the tablet would disagree with it, and a streak that
-- resets because you switched devices is the one way to make a game feel like
-- a lie.
--
-- Only a person's yes counts. A guess the importer wrote is not somebody's work,
-- and T0-4 already draws that line. In the books that yes is written as
-- `observed`, which is what `money_queue` reads as verified since 0122 and what
-- `attest_line` writes for `p_confirm => true` since 0126.
--
-- ---------------------------------------------------------------------------
-- And the yes that never saved
-- ---------------------------------------------------------------------------
--
-- Found by the assertion for this view, which was the first thing in the
-- repository to call `attest_line` with a confirmation. Every call failed:
-- `case when ... then 'observed' else 'inferred' end` is a CASE of two untyped
-- literals, which Postgres resolves to text, and there is no assignment cast
-- from text to the `provenance` enum. So the one-tap confirm, the centre of the
-- books app, has refused every tap since 0126 with a type error, and nobody
-- tapped it: S-143 says the confirm queue was built and never used. The 205
-- attestations in the cellar all came through the import script, which inserts
-- directly. The body below is the live one with the two literals cast and
-- nothing else changed.
--
-- The suite had tests of the refusals around it and none of the success, which
-- is the shape S-79 describes: a function whose refusals are covered and whose
-- purpose is not.

CREATE OR REPLACE FUNCTION public.attest_line(p_line_id uuid, p_class text, p_note text DEFAULT NULL::text, p_confirm boolean DEFAULT NULL::boolean)
 RETURNS line_attestation
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  made line_attestation;
  cls  uuid;
begin
  if not is_admin() then
    raise exception 'only an administrator may say what a transaction was for';
  end if;

  select t.id into cls from term t
   where t.kind = 'money_class' and t.value = p_class and t.active;
  if cls is null then
    raise exception 'there is no class of transaction called %', p_class;
  end if;

  if not exists (select 1 from bank_line where id = p_line_id) then
    raise exception 'that transaction is not there to say anything about';
  end if;

  insert into line_attestation (line_id, class_id, note, by_user, provenance)
  values (
    p_line_id, cls, p_note, auth.uid(),
    -- T0-4. Only an outright yes is a confirmation. Silence is a guess.
    case when p_confirm is true then 'observed'::provenance else 'inferred'::provenance end)
  returning * into made;

  return made;
end $function$;


create or replace view books_progress with (security_invoker = true) as
with here as (
  select (now() at time zone 'America/Los_Angeles')::date as today
),
mine as (
  select (a.at at time zone 'America/Los_Angeles')::date as d, a.line_id
    from line_attestation a
   where a.by_user = auth.uid()
     and a.provenance = 'observed'
),
days as (
  select distinct d from mine
),
-- Gaps and islands: consecutive days share `d - row_number`. The streak is the
-- island holding the most recent day, and only if that day is today or
-- yesterday; a streak you broke last week is not a streak.
islands as (
  select d, d - (row_number() over (order by d))::int as island from days
),
latest as (
  select island, max(d) as last_day, count(*) as length
    from islands
   group by island
   order by max(d) desc
   limit 1
)
select
  (select count(distinct line_id) from mine, here where d = here.today)           as filed_today,
  (select count(distinct line_id) from mine, here where d > here.today - 7)       as filed_week,
  (select count(distinct line_id) from mine)                                       as filed_ever,
  -- Zero, not null, for somebody who has never confirmed anything. No streak is
  -- a length, and a null here would render as a blank where a 0 belongs.
  coalesce((select case when l.last_day >= here.today - 1 then l.length else 0 end
              from latest l, here), 0)                                             as streak_days,
  (select count(*) filter (where q.queue in ('unexplained', 'unconfirmed')) from money_queue q) as left_to_file,
  (select count(*) filter (where q.queue = 'settled') from money_queue q)          as settled,
  (select count(*) from money_queue q)                                             as total,
  (select count(*) from money_paper p, here
    where p.by_user = auth.uid()
      and (p.created_at at time zone 'America/Los_Angeles')::date = here.today)    as papers_today,
  (select count(*) from money_paper_now n where not n.matched)                     as papers_loose;

comment on view books_progress is
  'How far through the books the person asking is: what they confirmed today, '
  'this week and ever, their streak of days, and what is left. All counted from '
  'line_attestation and the papers, nothing kept.';

-- What a name on a paper was filed as last time. Memory, like
-- `merchant_suggestion`: it can only suggest what somebody already said, and
-- what it suggests is exactly that.
create or replace view paper_who_memory with (security_invoker = true) as
select distinct on (lower(btrim(n.who)))
  n.who,
  lower(btrim(n.who))                                    as key,
  n.kind,
  n.class,
  n.class_label,
  n.direction,
  count(*) over (partition by lower(btrim(n.who)))      as times
from money_paper_now n
where n.who is not null and btrim(n.who) <> ''
order by lower(btrim(n.who)), n.read_at desc;

comment on view paper_who_memory is
  'Each name that has appeared on a paper, with what the latest paper from it was '
  'filed as. The source of "last time" on a new paper.';

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('books.progress', 'books', 'How far through the books you are',
   'What you confirmed today, this week and ever, your streak of days, and what is left to file. Counted from the attestations, never stored.',
   'books_progress', 'filed_today', 'filed_today', 364),
  ('books.paper_names', 'books', 'Names seen on papers before',
   'Each store, vendor or payee that has appeared on a paper, with what it was filed as last time.',
   'paper_who_memory', 'key', 'who', 365)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into screen (key, label) values
  ('deck', 'Clear the deck')
on conflict (key) do nothing;
