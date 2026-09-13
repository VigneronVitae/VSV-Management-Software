# W-4: harness, the null-permit class, and phase 5

**Repository:** github.com/VigneronVitae/VSV-Management-Software, branch `main`
**Mode:** write, unsupervised, multi-session. Same resumability and green rules as W-2 and W-3.
**Follows:** W-3 complete and green at `0025`. W-2 phases 5 through 8 are unblocked.
**Governing documents:** `docs/architecture-rulings.md`, `docs/findings-ledger.md`,
`docs/session-reports/modularization-progress.md`, and the three prior session reports.

---

## Where this starts

The gate is met on a set four times the size of the one that failed it, and it was not
lowered. Check constraints went 13% to 100%, unique constraints 12% to 100%, and the
RLS-off count went from 16 of 21 surviving to 0 of 22. Phase 5 is now defensible because the
nine composite foreign keys into `term(id, kind)` and the nine generated `kind` columns it has
to move are pinned by name and exact expression.

Three things come before phase 5 anyway, and the order is deliberate.

The harness is now the instrument every gate decision rests on, and it lied twice in one
session, in both directions. That gets fixed first because phase 5's own safety is measured
with it.

A24 is not a bug, it is a class with three known instances, and the catalog can find the
fourth. That gets a derived assertion before a migration adds instances nobody is looking for.

Then phase 5.

---

## Phase 1: repair the harness

`scripts/mutate.sh` silently truncated every multi-line mutation, so all ten function-body
mutations reported not-applicable and presented as ten resistant functions. Separately,
nineteen `weaken` mutations were degenerate and would have understated the suite by nineteen.

Both are the same defect in opposite directions: a harness that reports a number without
reporting that the number is unsound. This is the error W-3 was created to correct, arriving
from inside the instrument.

Fix multi-line mutation handling so function-body mutations actually apply. Then add a
degeneracy check: a mutation that does not change the object it targets, or that produces a
semantically identical object, is reported as degenerate and excluded from both numerator and
denominator, named in the output rather than silently dropped.

Then make the harness refuse to report a score it cannot stand behind. If any mutation is
not-applicable, degenerate, or failed to apply, the summary line says so and the score carries
that count beside it. A bare percentage from this tool is now a load-bearing number and it
should be impossible to produce one quietly.

Re-run the full set afterwards. The score will move, possibly down, and that is the correct
outcome. Report the before and after with the reason for each delta.

**Done when** the ten function-body mutations apply and are scored, degenerate mutations are
named and excluded, and a run with any unsound mutation cannot print a bare score.

---

## Phase 2: the null-permit class

A24 found that `operation_has_an_effect` reads `kind <> 'operation' or attributes ->> 'effect'
in (...)`. For an operation with no effect the inner test is `null in (...)` which is null, so
the whole predicate is `false or null` which is null, and a check constraint passes on null.
An effectless operation lands.

This is the third instance of one cause. `is_facility_user()` used `coalesce(..., true)`, so a
missing party row resolved to facility. `may_see_all_of` returns null on a path where nothing
matched. And now a check constraint permits on unknown. Three mechanisms, three authors'
worth of intent, nobody wrote any of them deliberately. That is `AR-B9`'s inflationary null in
the fixed layer, and it is the single most reliably recurring defect shape in this repository.

Do two things.

**File it as a class in the ledger,** not as a third instance of nothing. One entry naming the
shape, with the three known instances beneath it, and a statement of the invariant: in the
fixed layer, a predicate that cannot determine an answer must refuse, never permit. That is
`AR-B9` applied below the gate, at the level of individual constraints and functions.

**Write the derived assertion that finds the fourth.** The catalog can do this. Enumerate
every check constraint whose predicate can evaluate to null on a row satisfying no branch, and
every `security definer` function returning boolean that has a path returning null. Fail on
any that is not on an explicit allow-list with a stated reason. Derive the population rather
than hardcoding it, so it grows with the schema the way the other seven mutation classes do.

Expect this to find instances nobody has looked at. Those are findings, filed, not fixed,
consistent with the scope rule that has held since W-2.

**Also correct B2 in the ledger.** Two reports said adding an effectless operation raises. It
does not raise, it lands, silently inert, because the kernel reads no effect from it. A raise
is visible and gets fixed in the moment; silence is A13's class arriving through a constraint
rather than through RLS. The ledger should say the class is broader than it currently has it.

**Done when** the class entry exists, the derived assertion runs as part of `verify` or the
suite, and whatever it found is filed.

---

## Phase 3: W-2 phase 5

`term_kind` and `subject_type` to registry rows. `AR-E7`. The full text is in W-2 and is
unchanged; what follows is what the last two sessions added to it.

`term_kind` appears in nine generated columns, a composite foreign key, and most vocabulary
function signatures. Phase B pinned all of that by name and exact expression, which is the
protection this migration needs and the reason it was built.

Three things specific to this migration.

`0004` already performed exactly this conversion once, moving the winemaking enums into
`term`. Follow that precedent rather than inventing a second pattern, and if you deviate, say
why in the progress file.

`term.value` is ledger A16 and stays untouched: it is the join key the database resolves terms
by, its derivation lives in eight chained string operations in one TypeScript file, and that
is section A work for a supervised session. If this migration makes it worse or easier,
record which.

Watch for the phase 2 class while you are in here. Converting an enum to a lookup introduces
exactly the shape that produces it: a value that was previously unrepresentable becomes
representable as a missing row, and a predicate written against the old closed set now has a
third answer. Every predicate you touch should be checked for whether absence now permits.

**Done when** neither enum names a module concept, adding a subject type or term kind is a
row, all assertions pass against both a scratch database and a restored cellar copy, and the
mutation score has not fallen.

---

## Phase 4: the standing rules

Two habits were learned one session apart and both were learned by losing something. Put them
in `modularization-progress.md` where a fresh session reads them, not in a session report
where it will not.

Commit before every break test and revert after. A `git checkout --` reverted an uncommitted
rename in W-2 phase 1.

Record predictions before measuring, then report them against the result. W-2 predicted 55 to
75% and got 24%, and disclosing that is what made the rest of that report trustworthy. W-3
dropped the habit and said so, which is the next best thing.

Add a third while you are there, from W-3's own judgment: an assertion written for a theory
that turns out wrong gets deleted, not kept. An assertion that passes for a reason other than
the one it states adds one to a count and subtracts from what the count means. W-3 did this
correctly and the reasoning should outlive the session that produced it.

---

## Out of scope

Section B of the ledger, all client defects. Unchanged since W-2.

Fixing A24, A22's missing audit trail at S-43, A16, or any other section A entry. `0026` is a
supervised session. A24's assertion is already written so that fixing it fails the assertion,
which correctly puts fix and assertion in one commit, and that commit is not this one.

W-2 phases 6 through 8. Phase 6 moves the scheduling block and phases 7 and 8 rewrite function
bodies. Note for whoever writes that prompt: the mutation harness enumerates seven classes
from the catalog and samples the eighth at ten hand-chosen points, so the declarative surface
is policed and the procedural surface is not. That is the right shape of protection for phase
5, which moves declarative objects. It is the wrong shape for phases 7 and 8. Do not start
them on the strength of this session's score.

Adding CI. Adding any dependency without asking.

---

## The report

The usual shape, plus:

The mutation score before and after phase 1, with the delta attributed. A score that falls
because the harness stopped lying is a better number than the one it replaces, and the report
should say so in those terms.

Predictions recorded before measuring, per phase 4, starting with this session.

What the phase 2 derived assertion found, including the case where it found nothing, since a
class with exactly three instances and no fourth is itself a result.

And the thing every report in this series has earned its credibility on: what you expected and
got wrong.
