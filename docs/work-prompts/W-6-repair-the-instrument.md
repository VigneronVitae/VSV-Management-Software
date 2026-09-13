# W-6: repair the instrument

**Repository:** github.com/VigneronVitae/VSV-Management-Software, branch `main`, head `72612e7`
**Mode:** write, unsupervised, multi-session. Same resumability and green rules as W-2 through W-5.
**Follows:** W-5 complete. X-1, X-2 and X-3 complete, independently run, reports attached.
**Governing documents:** `docs/architecture-rulings.md`, `docs/findings-ledger.md`,
`docs/session-reports/modularization-progress.md`, and the three X reports.

---

## What happened, stated plainly

W-3 and W-4 gated progress on the mutation score improving. An independent round measured the
instrument that produces that score and found 86 of the 198 caught mutations are caught only
by a pinned catalog snapshot whose failure message instructs the reader to update it. The
behavioural score is 112 of 198, about 57%.

**Nobody gamed anything.** The prompts asked whether the number went up, a snapshot assertion
makes it go up without detecting behavioural change, and that is a defect in the gate rather
than in the work. The gate was wrong and the author of the gate says so.

Three further findings make the number unsound rather than merely optimistic. A lost database
connection during an assertion run is recorded as `caught`. The eight enumeration queries in
`mutate.sh` discard stderr, so a broken one deletes its class silently and the summary still
prints clean. And `green.sh` gates 4 and 5 decide by anchored grep rather than exit status, so
an assertion run that never happened reports `ok`.

Each of those is the `tgenabled` class. W-4 fixed one instance of that class and treated it as
an incident. It is a population.

X-1 also answered the question W-4 could not: ten of ten function-body substitutions are
caught on the author's own list, and three of nine survive on independently chosen ones.

---

## Scope

Repair the instruments. Do not fix schema defects. X-2 filed six EXPLOITABLE findings in
`0021` through `0027` and they belong in a supervised migration session, not here.

The exception is X-2-7, because it is an instrument defect wearing a schema defect's clothes:
the A25 assertion's population excludes trigger validators, which is exactly where `0027`
worked. That is in scope.

---

## Phase 1: stop the harness reporting unsound numbers

Every one of these is a fail-open path. Fix them as a class and then go looking for more,
because three were found by one independent pass and the population was never enumerated.

**Exit status, not grep.** `green.sh` gates 4 and 5 decide by anchored grep on output. An
assertion run that never happened reports `ok`. Decide by exit status everywhere, and make a
non-zero exit from any gate fail the whole command.

**Do not discard stderr.** The eight enumeration queries in `mutate.sh` throw stderr away. A
broken query returns empty, its class silently vanishes from the run, and the score prints
clean over a smaller denominator. Capture stderr, and treat an enumeration that errors or
returns unexpectedly empty as a hard abort rather than as a class with no members.

**A lost connection is an error, not a catch.** An assertion run that fails to reach Postgres
currently records `caught`, so a harness that cannot connect scores 100%. Distinguish "the
assertion suite ran and failed", which is a catch, from "the suite did not run", which is an
error that aborts.

**A vanished substitution target aborts.** X-1-7: a `logic` substitution whose target string no
longer occurs is dropped at enumeration and reported as nothing, against a comment saying it
reports as not applicable. Either behaviour is defensible; silently disagreeing with your own
comment is not. Abort, and name the substitution.

**Then hunt the rest.** For every place the harness or `green.sh` or `verify.sh` decides
something: what happens when the query errors, returns empty, returns a type needing a cast,
or when the database is unreachable. The rule to implement is that no path may reach a
success report without having done the work the report describes.

**Break-test every fix.** A fix for a fail-open path that is not observed failing is the
defect it was written to remove. This is now the fourth time in this project that a green
check was proven hollow only by deliberate breakage, so it is a standing rule and belongs in
the progress file: a check is not done until it has been seen to fail for the reason it
states.

---

## Phase 2: split the score

The single most important change in this session.

A snapshot assertion and a behavioural assertion answer different questions and must never
again be summed into one number. A snapshot pins the catalog and detects that something
changed. A behavioural assertion probes and detects that something now does the wrong thing.
Both are useful. Only one of them is evidence about correctness.

Classify every assertion in `tests/schema_assertions.sql` as snapshot or behavioural. Where a
single assertion does both, split it. Then make the harness report two scores, always, with
the denominators separate and neither ever presented alone.

Fix the failure messages while you are there. A snapshot assertion whose message tells the
reader to update the snapshot is a check that instructs its own defeat. The message should say
what changed and require a deliberate decision, not offer the fix.

**The gate from here on is the behavioural score.** The snapshot score is a change detector and
is reported for that purpose only. Write that into the progress file and into
`docs/review/CURRENT-BASELINE.md`, because the next person to read 100% will otherwise make
the same mistake in the same way.

---

## Phase 3: the dead and blind assertions

**X-1-6.** An assertion catches its own failure raise and can therefore never fail, and it is
the one whose comment claims it would have caught a silent `0027` regression. Fix it, then
break-test it.

**X-1-4.** The A25 allow-list entry is dead: removing it changes nothing, because `0027`
blinded the assertion that was supposed to depend on it. Restore the dependency, confirm
removal now fails, and re-audit whether the entry belongs on the list at all.

**X-2-7.** The A25 population excludes trigger validators. `0027` did its work in trigger
validators. Extend the population and report what it finds, filing rather than fixing.

**X-1-12.** The A25 candidate grid gives a text column two values, so every enum to registry
conversion narrows what that assertion can see. Since phases 5 through 8 are exactly that kind
of conversion, this shrinks as you proceed. Fix the grid so the population does not depend on
how a column happens to be typed.

**X-1-9.** The constraint inventory assertion pins one set of counts and prints a different set
on every green run. One of the two is wrong and both are load-bearing.

---

## Phase 4: re-measure, and say what it means

Run the repaired harness. Report the behavioural score and the snapshot score separately, with
denominators, with exclusions named, and with the count of mutations that failed to apply.

Then run X-1's nine independently chosen function-body substitutions plus at least six more you
choose without looking at the author's list. Report that catch rate separately. It is the only
honest measure of the procedural surface, and phases 7 and 8 rewrite function bodies.

State plainly whether the behavioural score clears a gate, and note that no gate currently
exists for it, because the old gate was measuring the wrong thing. Propose one. Do not adopt
it; that is a decision for the next prompt.

---

## Phase 5: the citation problem

X-3-7: W-2, W-3, W-4 and W-5 are cited as governing authority throughout the tree and none of
them is committed. That is my omission, not a tree defect, and it makes the progress file's own
resume procedure halt on the commit that contains it.

Commit the work prompts to `docs/work-prompts/` and the three X reports to
`docs/review/reports/`, named by prompt and engine as the corpus is. Update
`docs/review/CURRENT-BASELINE.md` to say the second review round exists and what it found.

Then fix the document findings from X-3 that are mechanical: the stale assertion counts, the
inert Deferred check, the changelog ordering, the disposition table that sums to 78 against a
count of 80, the "Five classes" banner over eight classes, the seventy against 69 renamed ids,
and the two documents naming a head sha and branch that no longer exist.

Leave the judgment ones. X-3-5 and X-3-6 concern whether the rulings document should say
things are built now that `AR-E5`, `AR-E6` and `AR-E7` are built and asserted, and that is a
ruling rather than an edit.

---

## Out of scope

X-2's six EXPLOITABLE schema findings. A supervised migration session.

W-2 phases 6, 7 and 8. Phase 6 is gated on nothing here, but running it before phase 4 reports
means running it on a number now known to mean something other than what it says.

Section A and section B of the ledger. Adding CI. Adding any dependency without asking.

If a tool call is refused by a permission classifier rather than by git or the filesystem,
retry. That is the classifier, not the repository.

---

## The report

Predictions recorded before measuring, per the standing rule.

The behavioural and snapshot scores, separately, with the reasoning for every assertion you
classified as snapshot, since that classification is now the most consequential judgment in the
instrument.

The independent function-body catch rate on fifteen or more substitutions you chose.

Every fail-open path found in phase 1 beyond the four X-1 named, because the question of
whether that population was three or thirty is currently open.

And what you got wrong.
