-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Puts everything the bank actually sent about a transaction where a
--           periphery can read it, including the memo block, which carries the
--           merchant address, the card and the authorisation reference and which
--           nothing has ever been able to show."
-- Depends on: [supabase/migrations/0122_money_that_has_already_moved.sql,
--              supabase/migrations/0123_the_bank_can_name_its_own_transactions.sql]
-- Depended on by: [docs/status-ledger.md, packages/books/src/books.ts]
-- Axioms enforced: T0-2, read the way it is usually not. Nothing here is stored
--                  twice: `raw` was already captured at import and this only
--                  stops hiding it. The alternative on offer was parsing the
--                  memo into columns, which would store a derivation of a thing
--                  the row already holds, and would do it in a client.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- "I want each transaction to list all identifying information from the credit union."
--
-- All of it has been there since the first import and none of it has been
-- visible. `bank_line.raw` holds what OFX called the memo, and for a card
-- purchase that is four lines carrying the merchant with its street address, the
-- kind of withdrawal, the authorisation reference and the last four of the card
-- that paid. The screen was showing a one word merchant name against it.
--
-- **What this deliberately does not do is parse that memo.** It is tempting,
-- because three of the four lines look regular. They are not: OFX wraps the
-- merchant line at a width the bank chose, so, in an invented memo of the shape
-- a real one has (invented because AR-J4 says this repository carries what can
-- exist and not what does, and a real one carries a merchant, a street, an
-- authorisation reference and the last four of a card),
--
--     GROCER #0000 1234 EXAMPLE ST TOWNSVILLE
--     Withdrawal POS #000000000000
--     OR
--     Card 0000
--
-- has the tail of the address on the third line, after the transaction line,
-- and the same merchant on a shorter street has three lines with nothing in that
-- position. A rule that reads line three as a state abbreviation here and as a
-- card line elsewhere is a business rule, it would be wrong about some fraction
-- of 799 rows, and CLAUDE.md says a client may not encode one. So the memo
-- travels whole and the screen prints it as the bank wrote it. A person reading
-- a wrapped address loses nothing; a parser that guesses wrong invents a fact.
--
-- The other four columns were simply never selected: the row number within its
-- import, the bank's own FITID, the transaction group and the currency.
-- `external_id` in particular is the thing that makes a re-import land once, so
-- being unable to see it made the one guarantee this module offers unverifiable
-- from the outside.

create or replace view bank_line_now with (security_invoker = true) as
select
  b.id,
  b.batch_id,
  b.row_no,
  b.account_id,
  a.name  as account,
  b.at,
  b.amount,
  b.direction,
  -- The derivation his spreadsheet does by hand, done once here.
  case when b.direction = 'Debit' then -b.amount else b.amount end as signed_amount,
  b.description,
  b.txn_type,
  b.check_number,
  b.bank_category,
  -- The latest word. A person's word beats a suggestion whatever the order they
  -- arrived in, because a machine writing after a human must not overwrite them.
  latest.class,
  latest.class_label,
  latest.provenance,
  latest.by_user,
  latest.at as said_at,
  -- Confirmed by a person, which is the state a hand-kept ledger records in a
  -- column somebody ticks.
  coalesce(latest.provenance, 'inferred') = 'observed' as verified,
  (select count(*) from line_attestation la where la.line_id = b.id) as attestations,
  -- Two people who disagree. Not an error: a thing to look at.
  (select count(distinct la.class_id) from line_attestation la
    where la.line_id = b.id) > 1 as disputed,
  -- Everything the bank said, added here and stored nowhere new.
  b.txn_group,
  b.currency,
  b.external_id,
  b.raw
from bank_line b
left join ledger_account a on a.id = b.account_id
left join lateral (
  select t.value as class, t.label as class_label, la.provenance, la.by_user, la.at
    from line_attestation la
    join term t on t.id = la.class_id
   where la.line_id = b.id
   order by (la.provenance = 'observed') desc, la.at desc
   limit 1
) latest on true;

comment on view bank_line_now is
  'Every bank line with the signed amount, what it is currently taken to be, '
  'who said so, whether a person confirmed it, whether anybody disagrees, and '
  'everything the bank itself sent including the memo block.';

-- `money_queue` selects `n.*`, so the four new columns land in the middle of its
-- own column list and `create or replace` refuses that. Dropped and rebuilt
-- rather than reordered, because putting them at the end of bank_line_now to
-- avoid this would be arranging the kernel around a limitation of one statement.
drop view if exists money_queue;

create view money_queue with (security_invoker = true) as
select
  n.*,
  case
    when n.attestations = 0 then 'unexplained'
    when n.disputed      then 'disputed'
    when not n.verified  then 'unconfirmed'
    else 'settled'
  end as queue,
  -- What the memory would say, for a line nobody has typed yet.
  s.class       as suggested,
  s.class_label as suggested_label,
  s.times       as suggested_on
from bank_line_now n
left join merchant_suggestion s on s.description = n.description;

comment on view money_queue is
  'Bank lines with the signed amount, what they are taken to be, which pile they '
  'are in, and everything the bank sent.';

do $$
declare
  missing text;
begin
  select string_agg(c, ', ') into missing from unnest(
    array['raw', 'external_id', 'txn_group', 'currency', 'row_no']) c
   where not exists (
     select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'money_queue'
        and column_name = c);
  if missing is not null then
    raise exception
      'money_queue was rebuilt without %, so the screen still cannot show what the bank sent', missing;
  end if;
end $$;
