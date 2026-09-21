-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Issues a money class meaning the transaction was looked at and
--           deliberately not categorised, which is a different fact from not
--           having been looked at."
-- Depends on: [supabase/migrations/0125_the_categories_are_schedule_f.sql,
--              supabase/migrations/0128_three_categories_nobody_issues.sql]
-- Depended on by: [docs/status-ledger.md,
--                  supabase/migrations/0138_the_repository_names_no_vendor.sql]
-- Axioms enforced: A13, in the shape it takes on a queue rather than on a
--                  refusal. A transaction nobody has opened and a transaction
--                  somebody opened and could not name are different states, and
--                  a books module that cannot tell them apart shows the second
--                  one to the same person every evening.
-- Open sorries: none new. Answers the code 41 half of S-102.
-- ---------------------------------------------------------------------------

-- Asked about twelve rows of ATM withdrawals and shared branch withdrawals, he
-- chose "not yet decided" over Transfer and over Draw. That is the right answer
-- and it needs somewhere to live: cash left the account, what it bought is
-- written down somewhere that is not the bank, and naming a category would be
-- inventing one.
--
-- Without this, such a row stays in the `unexplained` pile forever, and it is
-- indistinguishable from the eight hundred nobody has reached yet. The pile is
-- the work; a row that cannot leave it makes the count stop meaning anything.
--
-- Universal under AR-J4 rather than local, and the test is the usual one: would
-- another winery installing this have it? Every farm has money it cannot name
-- from the bank line alone. The category is about the state of the knowing, not
-- about how this operation is run, which is what separates it from the ones that
-- had to move out to data/.
--
-- A row already exists in this database, inactive, left behind by the draft of
-- 0125 that was stripped when AR-J4 was ruled. Insert-or-update rather than a
-- plain insert, for the same reason 0128 exists: the clone that has never seen
-- the draft needs the row created, and the one machine that has it needs it
-- turned back on.

insert into term (kind, value, label, sort_order, attributes)
values ('money_class', 'uncategorised', 'Not yet decided', 900, '{"side":"neither"}'::jsonb)
on conflict (kind, value) do update set
  label = excluded.label,
  sort_order = excluded.sort_order,
  attributes = excluded.attributes,
  active = true;

do $$
begin
  if not exists (
    select 1 from term
     where kind = 'money_class' and value = 'uncategorised' and active
  ) then
    raise exception 'uncategorised is not an active money class, so a person who cannot name a transaction has nothing to say';
  end if;
end $$;
