# W-3: making the suite police the schema

**Repository:** github.com/VigneronVitae/VSV-Management-Software, branch `main`
**Mode:** write, unsupervised, multi-session. Same resumability and green rules as W-2.
**Follows:** W-2 phases 0 through 4, complete and green. W-2 phases 5 through 8 are on hold
until this finishes.
**Governing documents:** `docs/architecture-rulings.md`, `docs/findings-ledger.md`,
`docs/session-reports/modularization-progress.md`, and the two W-2 session reports.

---

## Why this exists

W-2 blocked phase 7 on the mutation score and the score came back at 24%, against 42% for
G-5's smaller set and 21% on the same objects the review saw. The stop was correct.

The number is the symptom. The finding is this: **row level security can be disabled outright
on 16 of 21 tables and the suite still passes.** That property is set-independent, does not
depend on how mutations are counted, and it is the one that matters, because every fix in
`0021` and `0022` is an RLS fix. A1, A3, A5, A6 and A7 were all repaired against a suite that
cannot tell whether RLS is on at all. Those repairs are currently unprotected.

So this is not a detour before the real work. It is the critical path. W-2 phase 5 converts
`term_kind` across nine generated columns, a composite foreign key and most vocabulary
function signatures, and its failure modes are exactly the two categories the suite is worst
at: check constraints at 13% and unique constraints at 12%. Running phase 5 first would be
building on the measurement that already failed.

`scripts/mutate.sh` is committed, which is what makes any of this possible. A number nobody
can reproduce cannot be improved against.

---

## Order, and why it is this order

**Phase A protects work already done.** RLS assertions. They cover the fixes in `0021` and
`0022` and they lift the global score toward phase 7's gate.

**Phase B makes phase 5 survivable.** Constraint-level assertions. RLS assertions do not
touch check or unique constraints, so phase A does nothing for phase 5's risk. Do not let the
two run together in your head: they protect different things and only B derisks the migration
after it.

**Phase C remeasures**, and phases 5 and 7 unblock together or neither does.

**Phase D** is the small backlog this session inherits.

---

## Phase A: RLS assertions

One hour of the highest-value work available in this tree.

For every table with RLS enabled, assert that it is enabled and forced where it should be,
that the expected policy set exists by name, and that the policy actually refuses what it
claims to refuse. The last part is the one that counts. An assertion that reads
`pg_policy` proves a policy exists; an assertion that probes under `set local role
authenticated` with a real `request.jwt.claim.sub` proves it works. `tests/shim.sql` gives
you the roles; the existing suite already sets claims for the five assertions that currently
catch anything, so follow that pattern rather than inventing a second one.

Cover at minimum, because each corresponds to a fix that is currently unprotected:

`is_facility_user()` returns false for a principal with no `app_user` row, false for an
inactive party, and does not invert when a client party is deactivated. That is A1, found by
six independent runs, and it is the single most important assertion in this phase.

`event_insert` refuses an event whose `by_user` is not the caller, with and without
`by_sensor` populated. That is A3.

The vessel-photos policies refuse a client principal in both directions. That is A6.

`node`, `lineage` and `placement` inserts are refused for a principal who should not have
them. That is A7.

The `0021` column allow-lists refuse a cellar user who touches a protected column, and
`owner_id` and `hidden` are refused specifically, since they were deliberately left out of
every list.

`claim_task` refuses a null uid and refuses taking a task assigned to someone else. That is
A8.

Then make the RLS-off case detectable as a class rather than one table at a time. An assertion
that enumerates tables expected to have RLS and fails if any lacks it is three lines and
closes all 16 at once. Derive the expected set rather than hardcoding a list, or it rots the
first time a table is added.

**Done when** `scripts/mutate.sh` run with only the RLS mutations shows every one caught, and
you have confirmed that by actually running it rather than by reasoning about coverage.

---

## Phase B: constraint assertions

The category phase 5 depends on and phase A does not touch.

For every check constraint, assert that a violating value is refused. For every unique and
partial-unique constraint, assert that a duplicate is refused, and for partial ones, that a
value outside the predicate is accepted. For every foreign key, assert the violation is
refused, and separately assert the delete behaviour is what the DDL says, since ledger A20
found `ON DELETE RESTRICT` bypassable in two steps.

Two that need care because they are already known to be strange:

`operation_has_an_effect` is what makes ledger B2 fail, where `addTerm` sends no `effect` and
adding an operation inline always raises. Assert the constraint's behaviour, not the client's;
B2 is section B and out of scope here.

The composite foreign key `term_id_kind_key` and the nine generated columns that reference
`term_kind` are what phase 5 has to move. Assert their current behaviour precisely enough that
a phase 5 migration which changes it fails loudly. This is the specific reason phase B exists,
so if any assertion in this session is worth over-writing, it is this one.

**Done when** the mutation score for the check-constraint and unique-constraint categories is
materially above 13% and 12%, measured rather than estimated, and you state both numbers.

---

## Phase C: remeasure and decide

Run `scripts/mutate.sh` over the full set at the current head. Then run it over **G-5's
original 45-mutation set as well**, if that set can be reconstructed from the report. Two
numbers on the same objects across time is the only way to distinguish real improvement from
a change in how you count, and this session exists because that distinction was unavailable
the first time.

Report: the full-set score, the same-objects score, the per-category breakdown, and the G-5
set score if reconstructible. State plainly whether phase 7's gate is met.

If it is met, W-2 phases 5 through 8 resume as written, and say so in the progress file.

If it is not met, stop and write up which categories remain weak and what assertions would
close them. Do not lower the gate. Do not proceed on the argument that the score improved a
lot. The gate is a threshold, not a trend.

---

## Phase D: the inherited backlog

**A22, the barrel sticker.** Ruled: a cellar hand may bind an unbound code; only an admin may
rebind one already bound. The split sits where the risk is. An unbindable code means a cellar
hand cannot onboard the vessel they are about to record against, which is obstructive during
harvest. A silent rebind reattributes every future scan to the wrong barrel, which is ledger
A17's class, where one button press put a lot under the wrong owner and the screen reported
success.

Implement it the way `0021` did, with a narrow permission rather than a blanket definer. The
refusal on rebind must name the vessel currently bound to that code, because a person in a
barrel room needs to know which barrel already has that sticker.

Assert both halves.

**The dangling `E-4` reference is my error, not a tree defect.** Ledger A12 says the correction
path has no implementation and cites `E-4`. The append-only-with-corrections commitment lives
in `CLAUDE.md` and in R-5's finding, not in the rulings document, so after the `AR-` rename it
dangles because it was never a ruling reference in the first place. Repoint A12 at
`CLAUDE.md`'s append-only statement and at the R-5 report. The new `AR-` existence check then
passes without anyone guessing.

**Add a standing rule to the progress file:** commit before every break test, revert after. A
`git checkout --` during phase 1 reverted an uncommitted rename. That was done correctly in
the previous session and wrongly in this one, which makes it a rule rather than a mistake,
and a fresh session will otherwise learn it the same way.

---

## Out of scope

Section B of the ledger, all client defects, unchanged from W-2.

W-2 phases 5 through 8, until phase C says otherwise. Do not start phase 5 because phase B
went well.

Section A beyond A22. Fixing a defect is not the same as asserting one, and this session is
about assertions. If writing an assertion reveals that a fix is wrong, file it and say so
rather than fixing it here.

Adding CI. Adding any dependency without asking.

---

## The report

The same shape as the last two, plus three things this session specifically owes.

Every number with its mutation set named, since the whole reason this session exists is that
one number was reported without its set and turned out not to mean what it appeared to mean.

The RLS-off count before and after, table by table, because it is the set-independent fact and
it is the one to watch across sessions.

And the predictions you made that turned out false. Last session predicted 55 to 75% and got
24%, and disclosing that is what made the rest of the report trustworthy.
