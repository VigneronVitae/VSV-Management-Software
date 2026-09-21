-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Renames the money classes that carry a vendor's name to what the
--           vendor is, so the shipped vocabulary says a sale came through a till
--           rather than naming which company's till this winery happens to use."
-- Depends on: [supabase/migrations/0125_the_categories_are_schedule_f.sql,
--              supabase/migrations/0129_not_yet_decided_is_an_answer.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: AR-J4. The repository says what can exist, not what does. A
--                  till is universal; which company sells the till is this
--                  winery's procurement and nobody else's.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- Asked what should be scrubbed before the first push to a public remote, he
-- said "oh yeah no financial info at all", which is broader than the ledger
-- prose the question was about. It reaches the vocabulary, and the instruction
-- was already on record from 2026-09-19, when he named the credit union and the
-- till and said each should go to GitHub as what it is rather than as who it is.
--
-- `0125` shipped `orderport_income`, `orderport_fee`, `square_income`,
-- `stripe_income`, `square` and `fintech`. Every one of those names a company.
-- The AR-J4 test asks whether another winery installing this would have the row,
-- and the answer is that another winery has a till and a card processor and very
-- possibly not these ones.
--
-- **Why this is a rename and not a deletion.** The classes themselves are
-- universal: a winery takes money at a counter, a processor takes a cut, a
-- payment lands from a gateway. What was local was the proper noun. So the
-- meaning stays and the name generalises, and nothing anybody has already filed
-- moves category.
--
-- `fintech` is dropped rather than renamed. It named a company and stood for
-- nothing general; it was already inactive from the draft 0128 cleaned up after,
-- and nothing has ever been attested to it.

update term set value = 'till_income', label = 'Counter sales'
 where kind = 'money_class' and value = 'orderport_income';

update term set value = 'till_fee', label = 'Counter sales fee'
 where kind = 'money_class' and value = 'orderport_fee';

update term set value = 'gateway_income', label = 'Online sales'
 where kind = 'money_class' and value = 'stripe_income';

update term set value = 'card_income', label = 'Card sales'
 where kind = 'money_class' and value = 'square_income';

-- These two are leftovers of the stripped draft, inactive since 0128's family of
-- fixes, and named after companies. Retired rather than renamed, because neither
-- carries a meaning the four above do not already cover.
update term set active = false
 where kind = 'money_class' and value in ('orderport_revenue', 'square', 'fintech');

do $$
declare named text;
begin
  select string_agg(value, ', ') into named
    from term
   where kind = 'money_class' and active
     and (value ~* 'orderport|square|stripe|quickbooks|intuit|ufcu|plaid');
  if named is not null then
    raise exception
      'the shipped vocabulary still names a vendor: %. AR-J4 says the repository carries what can exist, not which company this winery buys from', named;
  end if;
end $$;
