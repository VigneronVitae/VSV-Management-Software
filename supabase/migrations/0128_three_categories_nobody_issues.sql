-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Retires three money classes that exist in this database and in no
--           file, so the picker stops offering the same category twice under
--           two different ids."
-- Depends on: [supabase/migrations/0125_the_categories_are_schedule_f.sql]
-- Depended on by: [tests/schema_assertions.sql, docs/status-ledger.md,
--                  supabase/migrations/0129_not_yet_decided_is_an_answer.sql]
-- Axioms enforced: AR-E5, in the direction it is usually read backwards. A
--                  registry row is the thing that exists, so two rows carrying
--                  one meaning are two things, and the kernel has no way to
--                  know they were meant to be one.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- Found by reading the vocabulary out of the live database while scoping the
-- ledger import, which is the only place it was visible.
--
-- `0125` was written twice on 2026-09-19. The first version seeded this winery's
-- own additions alongside Schedule F; AR-J4 was ruled the same afternoon and the
-- local ones moved to `data/books/money-classes.tsv`, loaded by
-- `scripts/seed-terms.py`. The rewrite used different values for three of them,
-- and because `term` is keyed on `(kind, value)`, the second load inserted rather
-- than updated. This database therefore carries six rows meaning three things:
--
--     Product             product            product_expense
--     Supplies Purchased  supplies_purchased supplies
--     the till Revenue   counter_revenue  till_income
--
-- The left column is issued by nothing in the tree. A clone built from empty has
-- never had it, which is the whole shape of the divergence CLAUDE.md warns about
-- for Studio edits, arriving instead through a migration that was edited after it
-- had already applied. Worth saying plainly because the lesson is not "do not
-- edit Studio", it is "a migration that has run is history, and changing it
-- changes only the clones that have not run it yet".
--
-- This would have shipped as a live defect in the books app. The category picker
-- draws one chip per active term, so three categories would have appeared twice,
-- identically labelled, and which twin a person tapped would have been a coin
-- flip. Two people filing the same merchant would have split the merchant memory
-- in half and the suggestion would then have been right about half the time,
-- which is the failure mode where nobody can tell anything is wrong.
--
-- Deactivated rather than deleted: `active` is how this schema retires
-- vocabulary, a deletion would be refused the moment anything pointed at one,
-- and nothing does today only because nothing has been attested yet.

update term
   set active = false
 where kind = 'money_class'
   and value in ('product', 'supplies_purchased', 'counter_revenue');

-- From empty this whole migration is a no-op, and that is the point: the rows it
-- retires were never issued from empty. It runs for the sake of the one database
-- that has real data in it.
do $$
declare
  dup text;
begin
  select string_agg(label, ', ')
    into dup
    from (
      select label
        from term
       where kind = 'money_class' and active
       group by label
      having count(*) > 1
    ) s;

  if dup is not null then
    raise exception
      'two active money classes share a label, so the picker would offer it twice: %', dup;
  end if;
end $$;
