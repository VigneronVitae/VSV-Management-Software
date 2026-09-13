# X-3: the documents against the tree

**Target:** `github.com/VigneronVitae/VSV-Management-Software`
**Tree reviewed:** `72612e7f9f8035b8fe238088ba86a77df6783bdd`, branch `main`, 112 tracked files,
migrations `0001` through `0027`. All six replacement canaries present, `scripts/mutate.sh`,
`tests/shim.sql`, `scripts/green.sh`, `scripts/verify.sh`, `docs/review/CURRENT-BASELINE.md`
and `docs/findings-ledger.md` all in the tree. Cloned over route 1, so locators are
`path:line`.
**Date:** 2026-09-12

## Acquisition and method note

`bash scripts/verify.sh` was refused twice by a permission classifier, not by git or the
filesystem, so the checker was never executed here. Every one of its seven checks was
reimplemented independently and run against the tree instead. That is a better instrument
for this prompt than the script's own exit code, because the question is what the checker
covers rather than whether it is currently green. Reimplemented, it is green: 52 headered
files, 408 edges, every one bidirectional and resolving, no orphan, no em dash outside the
corpus, every `S-`, `C-` and `AR-` id resolving, all three live count claims correct, every
command in the definition of done resolving.

Anything requiring a live Postgres, the mutation score and the per-table RLS figures, is
marked UNVERIFIED with the command that settles it. Nothing was guessed to a verdict.

---

## Every finding

### EXPLOITABLE

| | Finding |
|---|---|
| X-3-1 | The status ledger states two assertion counts, 129 and 190, and both are stale; no check looks at "N assertions" |
| X-3-2 | The Deferred check in `verify.sh` matches zero rows and has been inert since the only Deferred row acquired a qualifier |
| X-3-3 | The header check cannot see a missing header, and two tracked shell scripts have none |
| X-3-4 | The handover file's own resume procedure halts on the commit that contains it |

### DIVERGENT

| | Finding |
|---|---|
| X-3-5 | `architecture-rulings.md` says "Nothing here is built" twice while `AR-E5`, `AR-E6` and `AR-E7` are built and asserted |
| X-3-6 | `AR-E6` still carries the blocker that `0024` removed, in a document whose convention is to mark reversals in place |
| X-3-7 | W-2, W-3, W-4 and W-5 are cited as governing authority throughout and none of the four is in the tree |
| X-3-8 | Two documents name a head sha and a branch that no longer exist, which is the exact mistake `CURRENT-BASELINE.md` was written to correct |
| X-3-9 | The scratch and cellar-copy assertion counts differ by two; a recorded decision and the status ledger both say one |
| X-3-10 | The pair 204 / 206 is not what `green.sh` counts, and is quoted in three documents |
| X-3-11 | The findings ledger's disposition table sums to 78 against its own count of 80 |
| X-3-12 | `D1` is recorded as discharged by the status ledger and as "partly, a committed shim is still not in the tree" by the findings ledger |
| X-3-13 | The handover file's live "Discovered" section still reports the `E-4` dangle its own W-3 section records as repointed |
| X-3-14 | The status ledger defines four grades and uses seven |
| X-3-15 | "96 files and 22 migrations" in a session report holds at no commit in the history |
| X-3-16 | The rulings changelog says seventy ids were renamed; there are 69 |
| X-3-17 | `mutate.sh` announces "Five classes" and lists eight |
| X-3-18 | `mutate.sh` claims a vanished substitution target reports as not applicable; the enumeration drops it silently instead |
| X-3-19 | The corpus exemption in `verify.sh` says thirteen engines wrote the corpus; the corpus README says three |
| X-3-20 | Three migrations violate the migration header convention, which nothing enforces |
| X-3-21 | The definition of done cannot pass: two of its six commands are stubs that exit 1 |
| X-3-22 | The `term_kind` assertion says "six of the eight" and asserts five |
| X-3-23 | The findings ledger's changelog runs 1.4, 1.1, 1.0, 1.2, 1.3 |
| X-3-24 | The count-check history exemption covers two files in `docs/session-reports/` that are neither dated nor append-only |

### LATENT

| | Finding |
|---|---|
| X-3-25 | The count check bites on two literal phrases and nothing else |
| X-3-26 | Check 6 greps for a sentence that appears nowhere in the tree |
| X-3-27 | The `AR-` check is blind to section letters K through P |
| X-3-28 | The em dash check reads commit subjects only, and only the last 100 |
| X-3-29 | The module import check is vacuous and would miss a relative-path sibling import when it stops being vacuous |
| X-3-30 | The corpus exemption is defined by directory and grows with every prompt added to it |

### NOT A DEFECT

| | Finding |
|---|---|
| X-3-31 | The typed header graph is sound in both directions across 408 edges |
| X-3-32 | Every `S-`, `C-` and `AR-` id referenced anywhere in the tree resolves |
| X-3-33 | The em dash rule holds, and the corpus exemption is load-bearing for exactly two files |
| X-3-34 | `CURRENT-BASELINE.md`'s counts are derived and correct, and its six canaries identify this tree |
| X-3-35 | Seven historical numbers in the session reports recompute exactly |
| X-3-36 | The A25 allow-list has exactly one entry, as claimed |
| X-3-37 | The compost ledger is complete and the reactivation rule holds |

### UNVERIFIED

| | Finding |
|---|---|
| X-3-38 | Every mutation-score figure, and the per-table RLS counts |

---

## Claim, locator, supporting check, verdict

| Claim | Locator | Supporting check | Verdict |
|---|---|---|---|
| "129 assertions, all passing" | `docs/status-ledger.md`, row `Schema assertions` | none; check 4 reads only "tracked files" and "migrations" | EXPLOITABLE |
| "190 assertions" | `docs/status-ledger.md`, row `The suite polices the schema` | none | EXPLOITABLE |
| Every Deferred row names a compost entry | `scripts/verify.sh`, check 3, `grep '\| Deferred \|'` | the check itself, matching zero rows | EXPLOITABLE |
| "Every document carries a typed header" | `CLAUDE.md`, `## Conventions` | check 1, which skips any file without one | EXPLOITABLE |
| "Last green commit `f9c9f79`" | `docs/session-reports/modularization-progress.md`, `## State` | none | EXPLOITABLE |
| "Nothing here is built" | `docs/architecture-rulings.md`, `## Status` | check 6, scoped to two other files | DIVERGENT |
| "*Blocked by:* `task_board`" | `docs/architecture-rulings.md`, `**AR-E6.**` | none | DIVERGENT |
| "the W-2 prompt", "W-3's gate", "W-4 says plainly" | `modularization-progress.md`, three session reports | none; check 3 knows only `S-`, `C-`, `AR-` | DIVERGENT |
| "Branch holding it: `claude/sql-files-to-markdown-i31rob`" | `docs/review/CURRENT-BASELINE.md`, `## Where the tree actually is` | none | DIVERGENT |
| "the head is `45eaed5...` on branch `claude/sql-files-to-markdown-i31rob`" | `docs/findings-ledger.md`, preamble | none | DIVERGENT |
| "Scratch and copy counts may differ by exactly one" | `modularization-progress.md`, `## Decisions` | `green.sh` computes the gap instead, and the real gap is two | DIVERGENT |
| "204 from empty, 206 against the cellar copy" | `CURRENT-BASELINE.md`, `modularization-progress.md` twice | check 4 does not read "N assertions" | DIVERGENT |
| Disposition 23 + 19 + 12 + 12 + 12 | `docs/findings-ledger.md`, `## Disposition` | none | DIVERGENT |
| "A committed shim is still not in the tree" | `docs/findings-ledger.md`, closed table, row `D1` | none | DIVERGENT |
| "The findings ledger contains one dangling cross-reference" | `modularization-progress.md`, `## Discovered, and it changes a later phase` | none | DIVERGENT |
| Four grades | `docs/status-ledger.md`, `## Grades` | none | DIVERGENT |
| "96 files and 22 migrations" | `docs/session-reports/2026-09-11-verification-surface.md` | exempt from check 4 by the history glob | DIVERGENT |
| "and so on for all seventy" | `docs/architecture-rulings.md`, changelog 2.1 | none | DIVERGENT |
| "Five classes:" | `scripts/mutate.sh`, header comment | none | DIVERGENT |
| "reports as not applicable" | `scripts/mutate.sh`, above the logic values list | none; the `where position(...)` clause contradicts it | DIVERGENT |
| "Thirteen engines wrote it" | `scripts/verify.sh`, `corpus()` comment | `docs/review/README.md` says three engines, thirteen prompts | DIVERGENT |
| "Migrations additionally name the axioms they enforce and the sorries they leave open" | `CLAUDE.md`, `## Conventions` | none | DIVERGENT |
| "Done is: ... `bun run test` ... `bun run doctor`" | `CLAUDE.md`, `## What done means` | check 5, which verifies existence and explicitly not exit status | DIVERGENT |
| "six of the eight are not core's" | `tests/schema_assertions.sql`, `term_kind` registry block | the assertion beside it, which tests `< 5` | DIVERGENT |
| Changelog order | `docs/findings-ledger.md`, `## Changelog` | none | DIVERGENT |
| History exemption reason | `scripts/verify.sh`, `history()` | none; the glob is by directory | DIVERGENT |
| Counts stated in prose are derived and compared | `scripts/verify.sh`, check 4 | itself, over two phrases in two files | LATENT |
| The ledger cannot say nothing is built and grade rows Built | `scripts/verify.sh`, check 6 | itself, matching zero lines | LATENT |
| Every `AR-` id referenced exists | `scripts/verify.sh`, check 3 | itself, over `[A-JQ]` only | LATENT |
| "No em dashes anywhere, in ... commit messages" | `CLAUDE.md`, `## Conventions` | check 2, over `%s` of the last 100 commits | LATENT |
| "A module package may import from `core` and never from a sibling" | `CLAUDE.md`, `## Hard rules` | check 7, vacuous by its own admission | LATENT |
| The corpus is terminal | `scripts/verify.sh`, `corpus()`; `docs/review/README.md` | none | LATENT |
| Both directions of every dependency field are accurate | `CLAUDE.md`, `## Conventions` | check 1, reimplemented and green over 408 edges | NOT A DEFECT |
| Every `S-`, `C-`, `AR-` reference resolves | across the tree | check 3, reimplemented and green | NOT A DEFECT |
| "two of the sixteen contain any, thirty in total" | `2026-09-11-verification-surface.md` | recounted: 30 occurrences in 2 of 16 | NOT A DEFECT |
| "112 tracked files", "27 migrations" | `CURRENT-BASELINE.md` | check 4, and recounted by hand | NOT A DEFECT |
| "Its first run found forty nine one-directional header edges" | `docs/status-ledger.md`, `docs/findings-ledger.md` `D4` | recomputed against `595af42`: 49 | NOT A DEFECT |
| "Assertions went from 28 to 107" | `2026-09-10-wire.md` | recomputed: 28 at `c3eae3c`, 107 at `e111fdc` | NOT A DEFECT |
| "a 62-ruling architecture document" | `2026-09-11-verification-surface.md` | recounted: 69 ids less 7 open questions | NOT A DEFECT |
| "exactly one entry, `term.operation_has_an_effect`" | `CURRENT-BASELINE.md` | read at `tests/schema_assertions.sql`, `allowed text[]` | NOT A DEFECT |
| "Eight entries, each with a reactivation condition" | `CLAUDE.md` | check 3 and check 4, both reimplemented and green | NOT A DEFECT |
| "198 of 198 scored mutations caught", "21, named, from 219 enumerated" | `modularization-progress.md`, `## W-5` | none available here | UNVERIFIED |
| "cannot be disabled on any of 22 now" | `docs/status-ledger.md` | none available here | UNVERIFIED |

---

## Findings

### EXPLOITABLE

**X-3-1. The single source of build truth states two different assertion counts and both are stale.**
*Verdict:* EXPLOITABLE.
*Locator:* `docs/status-ledger.md`, row `Schema assertions` ("129 assertions, all passing")
and row `The suite polices the schema` ("190 assertions").
*What is wrong:* 129 was the count at `2f8cf5c` and 190 at `61cf709`. The suite now carries
206 `perform test_ok` calls. `CLAUDE.md` says the status ledger is the single source of build
truth and that a maturity claim anywhere else is wrong by construction, so these two numbers
outrank every other assertion count in the tree, and both are wrong by 77 and 16. Check 4
derives three counts and none of them is an assertion count.
*How it surfaces:* a reader who takes the ledger at its word believes the suite is a third
smaller than it is, and grades the coverage of `0023` through `0027` accordingly.
*Resolves when:* `verify.sh` derives the assertion count the same way `green.sh` does and
compares it against any `N assertions` phrase in a non-history file.

**X-3-2. The Deferred check matches no row and has been inert since the row it exists for acquired a qualifier.**
*Verdict:* EXPLOITABLE.
*Locator:* `scripts/verify.sh`, check 3, `done < <(grep '| Deferred |' docs/status-ledger.md)`.
*What is wrong:* the status ledger has exactly one deferred row and it reads
`| Deferred, partially reactivated |`. The grep requires `| Deferred |` with a closing pipe,
so it matches zero lines and the loop body never runs. The check reports as part of the pass
line for check 3 whether or not any Deferred row cites a compost entry.
*How it surfaces:* add a row graded `Deferred, pending the walk` naming no compost entry.
`bun run verify` is green. The rule in the ledger's own `## Grades` block is not enforced.
*Resolves when:* the grep anchors on the grade column rather than on an exact cell, for
instance `grep -E '\| *Deferred[^|]*\|'`.

**X-3-3. The header check cannot see a missing header, and two tracked shell scripts have none.**
*Verdict:* EXPLOITABLE.
*Locator:* `scripts/verify.sh`, check 1, `grep -q 'Depends on:' "$f" || continue`;
`scripts/db-backup.sh` and `scripts/db-restore.sh`.
*What is wrong:* the check enters a file into the graph only if it already carries a header,
so the convention in `CLAUDE.md` that every document carries one is enforced for files that
comply and invisible for files that do not. 52 of the 112 tracked files are headered. Two
`.sh` files inside the extension set the check does scan carry no header at all, and both are
cited by the status ledger row `Not losing your data` as tested apparatus.
*How it surfaces:* a new document added with no typed header joins no graph, is depended on
by nothing, and passes. This is the same shape as the orphan case the check does catch, with
the check looking the other way.
*Resolves when:* the loop inverts for the file classes the convention covers, failing on a
`.md`, `.sql` or `.sh` file in the enforced set that carries no `Depends on:` line, with the
two db scripts either given headers or exempted by name.

**X-3-4. The handover file's own resume procedure halts on the commit that contains it.**
*Verdict:* EXPLOITABLE.
*Locator:* `docs/session-reports/modularization-progress.md`, `## How to resume` steps 2 and
4, against `## State` and `## Phases`.
*What is wrong:* `## State` names `f9c9f79` as the last green commit. Head is `72612e7`, one
commit later. Step 2 instructs the reader to compare `git log --oneline -1` against that value
and says that if they differ, "the tree does not match this file and that is the first thing
to resolve." Step 4 says to continue at "the first phase marked not-started, which is phase
5", and the phase table two sections down marks phase 5 done and phase 6 next. The file's
purpose field says it is written to be sufficient on its own for a session that has never seen
this work.
*How it surfaces:* a fresh session follows the instructions literally, finds the sha mismatch
at step 2, and either stops to reconcile a difference that is only the commit that wrote the
file, or reaches step 4 and redoes a completed phase.
*Resolves when:* the last-green row is derived at check time rather than typed, or the resume
step compares against `git merge-base --is-ancestor` rather than equality, and step 4 reads
the phase table instead of naming a phase.

### DIVERGENT

**X-3-5. The rulings document says nothing in it is built, and three of its rulings are built and asserted.**
*Verdict:* DIVERGENT.
*Locator:* `docs/architecture-rulings.md:23` and `:30`, "Nothing here is built."
*What is wrong:* `0023` implements `AR-E5`, `0024` implements `AR-E6`, `0026` and `0027`
implement the two halves of `AR-E7`, all four migrations name the ruling in their headers, and
the status ledger grades all four Built and verified. The sentence appears twice, in the
preamble and again under `## Status`, and `## Status` adds "No ruling has been exercised by an
install", which is narrower and defensible. The first sentence is not. This is the same defect
`C2` closed in the status ledger, in the file check 6 does not read.
*How it surfaces:* silently, and it already has. Check 6 exists because this sentence was
found once. It greps `docs/status-ledger.md` and `docs/sorry-ledger.md` for the literal
`Nothing is built`, and the false instance now lives in a third file with one word changed.
*Resolves when:* check 6 scans every non-history document for a claim of the form "nothing
here is built" and compares it against any Built grade or any migration naming an id from that
document.

**X-3-6. `AR-E6` still carries the blocker that `0024` removed.**
*Verdict:* DIVERGENT.
*Locator:* `docs/architecture-rulings.md`, `**AR-E6.**`, the `*Blocked by:*` clause, against
`docs/status-ledger.md` row `` `task_board` through the registry ``.
*What is wrong:* the ruling reads "*Blocked by:* `task_board`, a core view whose `CASE` over
`subject_type` names `node`, `vessel` and `block` declaratively. That single view is why core
as drawn cannot install alone. Probed: `drop table block cascade` reports the cascade to
`task_board`." `0024` removed the `CASE`, and the status ledger records the opposite probe:
"`drop table block cascade` no longer reports a cascade to it, where it did an hour earlier",
with two assertions holding it. The document's own convention is that "Reversals are marked in
place rather than removed."
*How it surfaces:* a reader planning phase 6 reads `AR-E6` as blocked and re-derives the work
`0024` already did.
*Resolves when:* the clause is marked resolved in place with the migration that did it, and
`verify.sh` gains a check that a ruling named as implemented by a migration header carries no
unresolved blocker.

**X-3-7. Four work prompts govern every gate decision in the tree and none of them is in the tree.**
*Verdict:* DIVERGENT.
*Locator:* `W-2`, `W-3`, `W-4`, `W-5` across `docs/session-reports/modularization-progress.md`,
`2026-09-12-modularization-1.md`, `2026-09-12-assertion-suite.md`,
`2026-09-12-harness-and-enums.md`, `docs/findings-ledger.md`, `docs/sorry-ledger.md`,
`docs/status-ledger.md`. `docs/review/prompts/` contains `W-1-verification-surface.md` and
nothing else in the W series.
*What is wrong:* these are cited as authorities, not as history. "Stop conditions, from the W-2
prompt", "W-2 defines green as six things", "W-3's gate for the check and unique categories",
"W-4 says plainly not to start those on the strength of this score", "W-2 gates only phase 7 on
that number." Every one of those is a rule a future session is told to obey and cannot read.
This is the `E-4` dangle class at four times the size and with far more weight on it, and
check 3 cannot see it because it knows only `S-`, `C-` and `AR-`.
*How it surfaces:* phase 6 begins. The session is told the stop conditions come from W-2, looks
for W-2, and either reconstructs them from the fragments quoted in the progress file or
proceeds without them.
*Resolves when:* W-2 through W-5 are archived into `docs/review/prompts/` the way W-1 was, and
check 3 gains a `W-` arm resolving against that directory.

**X-3-8. The two documents that exist to say where the tree is name a branch that no longer exists.**
*Verdict:* DIVERGENT.
*Locator:* `docs/review/CURRENT-BASELINE.md`, the `Branch holding it` row; `docs/findings-ledger.md`,
"the head is `45eaed57a43f77b327674475b2b4c1c990d8bb1b` on branch
`claude/sql-files-to-markdown-i31rob`".
*What is wrong:* `git ls-remote --heads origin` returns one ref, `refs/heads/main` at `72612e7`.
The branch both files name is gone. The two files also name two different heads, `3698997` and
`45eaed5`, neither of which is head. `CURRENT-BASELINE.md` states the general lesson three
paragraphs below its own row: "identify a tree by things that only exist in it, not by where it
is parked or how large it is." Its summary table then parks the tree on a deleted branch. The
sha is excused in the file's own text; the branch is not.
*How it surfaces:* a reviewer arriving with the archived prompts reads the table first, tries
to check out the named branch, and fails. The negative check and the six canaries below still
work, so this costs a detour rather than a wrong review.
*Resolves when:* the row is dropped in favour of the canaries the same file already argues are
the durable check, or `verify.sh` gains a check that any branch name written in a non-history
document resolves through `git rev-parse --verify`.

**X-3-9. The two assertion runs differ by two, and a recorded decision says one.**
*Verdict:* DIVERGENT.
*Locator:* `docs/session-reports/modularization-progress.md`, `## Decisions`, row "Scratch and
copy counts may differ by exactly one"; `docs/status-ledger.md`, row `Green as one command`,
"The two assertion counts differ by exactly one, the storage skip, and the script fails if they
differ by anything else."
*What is wrong:* there are two storage-guarded blocks, at `tests/schema_assertions.sql:2073`
and `:2453`. Each carries two `perform test_ok` calls when the storage schema exists and one
skip notice when it does not, so each contributes a gap of one and the total gap is two.
`CURRENT-BASELINE.md` states 204 and 206, which differ by two and agree with the code. The
decision row and the status ledger both say one. `green.sh` is right and does not hardcode
either number: it counts `no storage schema here` lines and compares.
*How it surfaces:* silently, never, as long as nobody acts on the written decision. It surfaces
the moment someone edits `green.sh` to match the decision, at which point the comparison
becomes a hardcoded 1 and fails on the current tree.
*Resolves when:* both sentences say two, or better, say "one per storage-guarded block" so the
figure stops being a number at all, which is how `green.sh` already computes it.

**X-3-10. The pair 204 / 206 is not the number `green.sh` prints.**
*Verdict:* DIVERGENT.
*Locator:* `docs/review/CURRENT-BASELINE.md`, the Assertions row; `modularization-progress.md`
`## State` and `## W-5`; against `scripts/green.sh`, `grep -c '^NOTICE:  ok'`.
*What is wrong:* the suite emits `NOTICE:  ok` from three places. 206 `perform test_ok` calls,
of which four sit inside the two storage guards. Two skip notices, which fire only without a
storage schema. And one stand-down notice at `tests/schema_assertions.sql:94` or `:96`, which
fires in both environments and reports whether an existing facility party was deactivated.
`green.sh` counts all three kinds. That gives 202 + 2 + 1 = 205 from empty and 206 + 1 = 207
against the cellar copy. The documented 204 and 206 are exactly those figures less the
stand-down notice, which is an environment report rather than an assertion, so the prose is
counting the honest thing and the script's headline is one higher than the prose that quotes
it. The gap of two between the runs is correct either way, which is why `green.sh`'s internal
consistency check passes and nothing surfaces this.
*How it surfaces:* the next person to reconcile `bun run green`'s final line against the State
table finds a one-off in both columns and has to re-derive which is right.
*Resolves when:* `green.sh` excludes the stand-down notice from its count, or the three
documents quote the script's output verbatim. One live `bun run green` settles which figure the
script actually prints; the arithmetic above is static and is the one number in this report I
could not execute.

**X-3-11. The findings ledger's disposition table sums to 78 and the ledger counts 80.**
*Verdict:* DIVERGENT.
*Locator:* `docs/findings-ledger.md`, `## Disposition`, rows 23 / 19 / 12 / 12 / 12, against
the preamble "That is 80."
*What is wrong:* the id sets are `A1` to `A25`, `B1` to `B19`, `C1` to `C12`, `D1` to `D12`,
`E1` to `E12`, which is 25 + 19 + 12 + 12 + 12 = 80. The disposition table still says 23 for
section A. `A24` and `A25` were added by the W-3 and W-4 reads, the preamble was updated to say
so, and the table below it was not.
*How it surfaces:* silently, never, until someone counts the sections against the table.
*Resolves when:* the disposition counts are derived from the section tables at check time,
which is a five-line addition to check 4 given the ids are already greppable at line start.

**X-3-12. `D1` is discharged in one ledger and open in another.**
*Verdict:* DIVERGENT.
*Locator:* `docs/findings-ledger.md`, closed table, row `D1`: "partly | A throwaway shim proved
the tree as it stood at `0022` apply from empty. A committed shim is still not in the tree."
Against `docs/status-ledger.md`, row `The auth shim`: "Built to the W-1 specification ...
Discharges D1", and `tests/shim.sql`, tracked since `df3ac3d`.
*What is wrong:* the shim is committed. The findings ledger's row is the state before
`df3ac3d` and was not updated when the shim landed, while `CURRENT-BASELINE.md` lists `D1`
among the closed entries with no qualifier. Three documents, three different states for one id.
*How it surfaces:* a reader planning infrastructure work reads the findings ledger, the
governing document by its own declaration, and rebuilds a shim that exists.
*Resolves when:* the `D1` row is updated, and check 3 gains a rule that an id the status ledger
says is discharged is not carried as open elsewhere.

**X-3-13. The handover file's live section still reports a dangle its own W-3 section records as repointed.**
*Verdict:* DIVERGENT.
*Locator:* `docs/session-reports/modularization-progress.md`, `## Discovered, and it changes a
later phase`, "The findings ledger contains one dangling cross-reference", against the same
file's `## W-3` section, "The `E-4` reference is repointed", and `docs/findings-ledger.md`
entry `A12`.
*What is wrong:* `A12` now cites `CLAUDE.md`'s append-only statement and
`docs/review/reports/R-5-claude-code.md`. The file that says so is the same file that still
carries the unresolved report, in a section that is not a dated phase log. The file's own
header says "This is not a session report. It is the handover file", so the append-only excuse
that covers the session reports does not cover this section.
*How it surfaces:* the file is the first thing a fresh session reads by instruction. It is told
a dangle exists, goes looking, and finds it fixed.
*Resolves when:* the `## Discovered` entry is struck or marked resolved. The distinction that
makes this actionable is that `## Discovered` is present tense and the phase sections are past
tense, which is a distinction the file could state and does not.

**X-3-14. The status ledger defines four grades and uses seven.**
*Verdict:* DIVERGENT.
*Locator:* `docs/status-ledger.md`, `## Grades`, against the grade column across all five
stage tables.
*What is wrong:* the block defines Built and verified, In progress, Specified and Deferred. The
tables use those four plus `Built and verified, kernel only` three times,
`Deferred, partially reactivated` once, and `Kernel only, no screen` once. The last of these is
a grade the block does not define at all and which is not a qualified form of one that it does.
*How it surfaces:* `Kernel only, no screen` on the `Procedures with timed steps` row is
ambiguous between In progress and Built and verified, kernel only, which are different claims
about whether a check passes. It also carries the qualifier that makes X-3-2 inert, so the
grade vocabulary is not cosmetic.
*Resolves when:* the grade block enumerates the qualified forms, and check 6 verifies that
every grade cell matches one of them.

**X-3-15. "96 files and 22 migrations" holds at no commit in the history.**
*Verdict:* DIVERGENT.
*Locator:* `docs/session-reports/2026-09-11-verification-surface.md`, "The tree they were handed
to has 96 files and 22 migrations".
*What is wrong:* recomputed across that session: `0e42021`, the commit that archived the
corpus, is 94 files and 20 migrations. `deacebf` is 96 and 21. `2f8cf5c` is 97 and 22. The pair
is a splice of one commit's file count and the next commit's migration count. The tree the
corpus was actually handed to is 94 and 20.
*How it surfaces:* silently, never. It is history and reads as history.
*Resolves when:* nothing, by the append-only convention; a correction belongs in a later report
or in the handover file, which is where the W-4 exclusion count correction already lives. It is
listed here because it is the second forward-carried number found in the reports and the prompt
asked whether there were others. There is one, and this is it.

**X-3-16. The rulings changelog says seventy ids were renamed and there are 69.**
*Verdict:* DIVERGENT.
*Locator:* `docs/architecture-rulings.md`, changelog 2.1, "`A-1` became `AR-A1`, `J-2` became
`AR-J2`, and so on for all seventy."
*What is wrong:* the document carries 69 bolded `AR-` ids: A1 to A5, B1 to B11, C1 to C4, D1 to
D8, E1 to E9, F1 to F9, G1 to G3, H1 to H4, I1 to I7, J1 to J2, Q1 to Q7. 62 rulings and 7 open
questions. The neighbouring claim in the same session's report, "a 62-ruling architecture
document", is exactly right, so the two figures were derived differently and one of them was
not derived.
*How it surfaces:* silently, never.
*Resolves when:* check 4 derives the ruling count the way it derives the compost count, which
is the same three lines against a different regex.

**X-3-17. `mutate.sh` announces five classes and lists eight.**
*Verdict:* DIVERGENT.
*Locator:* `scripts/mutate.sh`, header comment, "The mutations are enumerated from the catalog
rather than listed by hand ... Five classes:", followed by eight named classes, against
`for class in check loosen unique trigger policy weaken rls logic`.
*What is wrong:* eight classes run and the sentence above them says five. Every other document
in the tree says eight. The sentence is also the one that says the set is enumerated from the
catalog, which is true of seven of the eight and not of `logic`, a distinction
`CURRENT-BASELINE.md` is careful about and this comment is not.
*How it surfaces:* silently. It is a comment in the instrument everybody trusts, and the number
beside it is the number `CURRENT-BASELINE.md` warns readers not to over-read.
*Resolves when:* the comment says eight and marks `logic` as the hand-chosen one, matching the
distinction `CURRENT-BASELINE.md` already draws.

**X-3-18. A vanished substitution target is dropped from the enumeration, not reported.**
*Verdict:* DIVERGENT.
*Locator:* `scripts/mutate.sh`, the comment "A substitution whose target string is gone reports
as not applicable, which is also how this list tells you a function has changed shape", against
the query below it: `where position(m.find in pg_get_functiondef(p.oid)) > 0` and
`join pg_proc p on p.proname = m.fn`.
*What is wrong:* the not-applicable path in this script is for a mutation that enumerates and
then fails to apply. A logic substitution whose target text is absent, or whose function has
been renamed or dropped, is filtered out by the `where` and the `join` before it becomes a
mutation. It never enters `$muts`, never runs, and appears in no column, including the excluded
one. The denominator shrinks and the score stays at 100 percent.
*What makes this the sharpest item in the instrument:* `logic` is the only class that samples
the procedural surface, and phases 7 and 8 rewrite function bodies. Every one of the ten
substitutions is a literal string from a body those phases will change. The class that measures
the surface about to move is the class that silently shrinks when it moves.
*How it surfaces:* phase 7 rewrites `rack`. `nullif(contributed, 0)` no longer appears. The
next mutation run enumerates nine logic mutations instead of ten, scores 197 of 197, and
reports 100 percent with no line saying anything is missing.
*Resolves when:* the query stops filtering and emits an explicit not-applicable row for a
substitution whose target or function is absent, so a shrinking class shows up in the excluded
list the harness already refuses to print a bare percentage without.

**X-3-19. The corpus exemption's stated reason miscounts the corpus.**
*Verdict:* DIVERGENT.
*Locator:* `scripts/verify.sh`, the `corpus()` comment, "Thirteen engines wrote it", against
`docs/review/README.md`, "Thirteen review prompts run across three engines in September 2026,
sixteen runs".
*What is wrong:* three engines, thirteen prompts, sixteen runs. The exemption's justification
turns the prompt count into an engine count. The exemption itself is correct and load-bearing;
its reason is not accurately stated.
*How it surfaces:* silently. It matters only because the prompt asks whether each exemption's
reason still holds, and a reason that misstates the thing it is about cannot be checked against
it.
*Resolves when:* the comment says three engines and thirteen prompts.

**X-3-20. Three migrations do not name their axioms or their sorries, and nothing checks that they do.**
*Verdict:* DIVERGENT.
*Locator:* `CLAUDE.md`, `## Conventions`, "Migrations additionally name the axioms they enforce
and the sorries they leave open." `0006_vessel_thermal.sql` and `0010_glycol_by_type.sql` carry
no `Axioms enforced` field. `0007_vessel_edit.sql` carries no `Open sorries` field.
*What is wrong:* the convention is stated as unconditional and 24 of 27 migrations follow it.
Check 1 reads the `Depends on` and `Depended on by` fields of these files and never looks at the
other two.
*How it surfaces:* silently. `0006` and `0010` are both thermal-state migrations whose axiom
coverage is exactly the thing a later reader would want stated.
*Resolves when:* check 1 requires both fields on any file under `supabase/migrations/`, which
is one `case` arm inside the loop it already runs over those files.

**X-3-21. The definition of done cannot pass, and green is a different definition that nothing reconciles with it.**
*Verdict:* DIVERGENT.
*Locator:* `CLAUDE.md`, `## What done means`; `package.json`, the `test` and `doctor` scripts;
`scripts/green.sh`.
*What is wrong:* `doctor` is `echo 'doctor: not implemented ...' && exit 1` and `test` is
`echo "test: no client tests exist ..." && exit 1`. Both are in the definition of done. Check 5
verifies that each command resolves to a script and its comment says so explicitly, naming
`doctor` as a stub by design under `S-4` and not naming `test`, which is `S-38`. Meanwhile
`green.sh` runs verify, typecheck, lint, migrations and the assertions twice, and runs neither
`test` nor `doctor`. So the tree has two definitions of finished: one that cannot pass and one
that can, and no document says which governs a grade of Built and verified.
*How it surfaces:* every Built and verified row in the status ledger claims "its check passes".
For 28 rows that check is green, not done, and the two are not the same set of commands.
*Resolves when:* `CLAUDE.md` states that green is the gate and done is green plus the two
stubs, or the two stubs exit 0 with a skip notice the way the storage blocks do, which is the
pattern the assertion suite already uses for a check that cannot run.

**X-3-22. The `term_kind` assertion says six and tests five.**
*Verdict:* DIVERGENT.
*Locator:* `tests/schema_assertions.sql`, the `term kind is a row` block:
`if (select count(*) from term_kind where module <> 'core') < 5 then raise exception`, followed
by `perform test_ok('the registry says which module owns each kind, and six of the eight are
not core''s')`.
*What is wrong:* `0027` seeds eight kinds, six of them non-core. The assertion permits five.
Moving one kind to core leaves the suite green and the message saying six.
*How it surfaces:* phase 6 moves the scheduling block into core. If any vocabulary kind moves
with it the assertion passes and its own message becomes false, which is a small instance of
exactly what this prompt is about.
*Resolves when:* the comparison is `<> 6`, or the message is derived from the count.

**X-3-23. The findings ledger's changelog is out of version order.**
*Verdict:* DIVERGENT.
*Locator:* `docs/findings-ledger.md`, `## Changelog`, sections in the order 1.4, 1.1, 1.0, 1.2,
1.3.
*What is wrong:* three of the five entries carry the same date and the ordering carries no
information. The rulings document's changelog is strictly descending and reads correctly, so
this is a divergence between two documents that follow the same convention.
*How it surfaces:* silently. A reader looking for the most recent change finds 1.4 first by
luck rather than by rule.
*Resolves when:* the sections are reordered, and check 4 verifies descending version order in
any document carrying a `Version:` header field, which is currently two files.

**X-3-24. The count-check history exemption covers two files that are neither dated nor append-only.**
*Verdict:* DIVERGENT.
*Locator:* `scripts/verify.sh`, `history()`, the glob `docs/session-reports/*`, against
`docs/session-reports/modularization-progress.md` and `docs/session-reports/index.md`.
*What is wrong:* the exemption's stated reason is "the session reports, which describe the tree
as it stood on a date and are append-only by their own convention. A count check that cannot
tell the difference would force history to be rewritten to stay green." Two files in that
directory are not that. `modularization-progress.md` opens with "**This is not a session
report.** It is the handover file ... updated at the end of every phase", and its `## State`
table is a live count claim about now. `index.md` is a live index. Both are exempted purely by
location. This is the exemption being broader than its reason requires, and it is the one that
matters, because the numbers X-3-4, X-3-9 and X-3-10 all live inside it.
*How it surfaces:* the last green commit goes stale, the assertion pair goes stale, and the
count check that exists to catch stale numbers is looking away by directory.
*Resolves when:* the exemption tests the file rather than the path, for instance by exempting
files whose name begins with a date, which is the actual distinguishing property and is already
the naming convention in that directory.

### LATENT

**X-3-25. The count check bites on two literal phrases and nothing else.**
*Verdict:* LATENT.
*Locator:* `scripts/verify.sh`, check 4, `grep -o '[0-9][0-9]* tracked files'` and
`grep -o '[0-9][0-9]* migrations'`.
*What is wrong:* after the history exemption, exactly three sentences in two files are checked:
`112 tracked files` and `27 migrations` in `CURRENT-BASELINE.md`, and `27 migrations` twice in
`findings-ledger.md`. Every other count in the live document layer is unguarded, including
every assertion count, the mutation score, the ruling count, the disposition counts, the
findings count, the RLS table counts, and any count written as a word. `CURRENT-BASELINE.md`
writes `forty two` as words on purpose to evade the check and explains why, which is the check
working as designed and also a demonstration of how narrow its aperture is.
*Resolves when:* the check derives a named set of quantities and scans for each as digits and
as words, the way `word_for()` already does for the compost count. The apparatus for this is
present and used once.

**X-3-26. Check 6 greps for a sentence that appears nowhere in the tree.**
*Verdict:* LATENT.
*Locator:* `scripts/verify.sh`, check 6, `grep -q 'Nothing is built'`.
*What is wrong:* neither ledger contains the literal string. The status ledger now says "This
ledger began by saying nothing was built", lowercase and past tense, which is the correct
history and does not match. So check 6 evaluates two false conditions and prints a pass. It has
been decorative since the sentence it was written for was rewritten, which happened in the same
session that wrote the check.
*Name the change that reaches it:* any future ledger opening that says nothing is built in any
other wording. X-3-5 is that change, already landed, in a third file.
*Resolves when:* the check tests the property rather than the string, comparing any
`Nothing is`, `None of this is` or `nothing here is` claim near the top of a graded document
against the presence of Built rows.

**X-3-27. The `AR-` check is blind to section letters K through P.**
*Verdict:* LATENT.
*Locator:* `scripts/verify.sh`, check 3, `grep -o '^\*\*AR-[A-JQ][0-9]*'` and
`grep -o '\bAR-[A-JQ][0-9][0-9]*\b'`.
*What is wrong:* both the list builder and the reference scanner use `[A-JQ]`. Sections A
through J exist and Q holds the open questions, so the range is correct today. A new section K
would be invisible on both sides at once: its ids would not enter the resolvable set, and
references to them would not be scanned, so a reference to `AR-K3` would neither resolve nor
fail.
*Name the change that reaches it:* phase 6, 7 or 8 adding a section. `AR-I3` through `AR-I6`
and section J were both added by version 2.0, so the document grows sections.
*Resolves when:* the range becomes `[A-Z]`, which requires no other change because the compost
and sorry namespaces are separated by the `AR-` prefix.

**X-3-28. The em dash check reads commit subjects only, and only the last 100.**
*Verdict:* LATENT.
*Locator:* `scripts/verify.sh`, check 2, `git log --format='%h %s' -n 100`.
*What is wrong:* `CLAUDE.md` says "No em dashes anywhere, in code comments, docs, or commit
messages." The check reads `%s` and not `%b`, so a commit body is unguarded, and the window is
the last 100 commits. There are 51 commits and both subjects and bodies are clean today, so
neither hole is live.
*Name the change that reaches it:* the 101st commit, at which point the earliest commit leaves
the window permanently and the rule stops being retroactive. Or the first commit body
containing one, which is available now.
*Resolves when:* the format is `%h %s%n%b` and the window is the whole history, which at 51
commits and growing slowly costs nothing.

**X-3-29. The module import check is vacuous and would miss a relative-path sibling import when it stops being vacuous.**
*Verdict:* LATENT.
*Locator:* `scripts/verify.sh`, check 7, and its pass line "the module import rule holds
vacuously".
*What is wrong:* the check says out loud that it proves nothing with one module besides core,
which is the right behaviour and is the only place in the script that refuses to print a green
tick it has not earned. The second issue is that when a second module lands, the grep matches
bare specifiers only: `from "sib"`, `from 'sib'`, `require("sib")`. The workspace does use bare
specifiers today, `from "core"` and `from "cellar"`, so the pattern fits the house style. A
relative import reaching across, `from "../../cellar/src/ui.ts"`, would pass.
*Name the change that reaches it:* a second module package, plus one relative import written by
an editor's auto-import rather than by hand.
*Resolves when:* the pattern also matches any relative path escaping the module's own directory,
or the rule moves into Biome once the CRLF problem the comment describes is fixed.

**X-3-30. The corpus exemption is defined by directory and grows with every prompt added to it.**
*Verdict:* LATENT.
*Locator:* `scripts/verify.sh`, `corpus()`; `docs/review/README.md`, "The prompts and reports
are terminal."
*What is wrong:* the exemption's reason is that the corpus is terminal, written by engines that
never read this repository's style rule, and depended on by nothing. All three hold today: no
typed header anywhere names a corpus file, and exactly two of the sixteen reports carry em
dashes. But the directory is not terminal in practice. `W-1-verification-surface.md` is a work
prompt written in this repository and sitting in `prompts/`, and this prompt series continues.
Anything dropped into either directory is exempt from the header check, the em dash check and
the whole of check 3 on arrival.
*Name the change that reaches it:* the next in-house prompt filed in `prompts/`, which inherits
an exemption written for external output.
*Resolves when:* the exemption enumerates the archived files, or scopes to files whose header
says they are corpus, which reverses the direction so a new file has to claim the exemption
rather than inherit it.

### NOT A DEFECT

**X-3-31. The typed header graph is sound.**
Reimplemented and run: 52 headered files, 408 edges, every edge resolving to a real path, every
edge reciprocated in the named direction, no orphan. The one weakness is that a file with no
header is invisible to it, which is X-3-3, and it is a hole in the scope rather than in the
graph. Within its scope this is the strongest check in the tree.

**X-3-32. Every `S-`, `C-` and `AR-` reference in the tree resolves.**
Reimplemented over all 112 tracked files less the corpus: 43 sorry ids, 8 compost ids, 69
ruling ids, zero unresolved references in either direction. The word boundary that stops
`VS-023` reading as a sorry works. The findings-ledger ids, `A1` through `E12`, also all
resolve, though nothing checks them; the only near miss is a barrel-code placeholder `"B23"` at
`packages/cellar/src/walk.ts:595`, which is data.

**X-3-33. The em dash rule holds, and its exemption is smaller than the corpus.**
Zero em dashes in any tracked file outside `docs/review/prompts/` and `docs/review/reports/`,
zero in all 51 commit subjects, zero in all 51 commit bodies. Inside the corpus, 30 occurrences
in 2 of 16 reports, both ChatGPT runs. The verification-surface report's claim of "thirty in
total" is exact.

**X-3-34. `CURRENT-BASELINE.md`'s counts are derived and correct, and its canaries work.**
112 and 27 both verified by hand. All six replacement canaries are present, none exists at
`c3eae3c`, and the earliest commit satisfying all six is `3a94d94`, so the set identifies this
tree and the five commits before it rather than this commit exactly. The file says so itself:
"A later commit is later work on the same tree, not a different tree." The negative check works:
`c3eae3c` is 42 files. Nothing else in the tree states the superseded figures as current; every
occurrence of 42, five migrations or `c3eae3c` outside the corpus is framed as history and
reads that way. The one thing that has gone stale in this file is the branch row, which is
X-3-8.

**X-3-35. Seven historical numbers in the session reports recompute exactly.**
`c3eae3c` is 42 files, 5 migrations, 28 `test_ok`. `e111fdc` is 107, so the wire report's "28 to
107" is right. `42e5a90` is 61 files, 20 migrations, 107 assertions, so the archive README's
"twenty migrations, 61 files and 107 assertions" is right. Re-running the header check against
`595af42`, the commit before `verify.sh` landed, gives exactly 49 one-directional edges and no
dangles, so "forty nine" in the status ledger and in `D4` is right. "a 62-ruling architecture
document" is right, 69 ids less 7 open questions. "thirty in total" is right. The only
forward-carried number found besides the one already disclosed is X-3-15.

**X-3-36. The A25 allow-list has exactly one entry.**
`tests/schema_assertions.sql`, `allowed text[] := array['term.operation_has_an_effect']`, with
the reason written beside it and a note that fixing A24 will fail the assertion, which puts the
fix and the assertion in one commit. Both halves of the claim in `CURRENT-BASELINE.md` check
out: the block enumerates check constraints from `pg_constraint` and boolean functions from
`pg_proc`, neither by hand.

**X-3-37. The compost ledger is complete and the reactivation rule holds.**
Eight entries, `C-1` through `C-8`, every one carrying a `Reactivate if:` line, and
`CLAUDE.md`'s "Eight entries" derived and compared by check 4 through `word_for()`. This is the
one rule in the tree where the claim, the artifact and the check are all present and all agree,
and it is worth naming as the pattern the rest should follow.

### UNVERIFIED

**X-3-38. Every mutation-score figure and every per-table RLS count.**
*Verdict:* UNVERIFIED.
*Locator:* `modularization-progress.md` `## W-5`, "198 of 198 scored mutations caught" and "21:
20 degenerate plus 1 inapplicable, from 219 enumerated"; `docs/status-ledger.md`, "Row level
security could be disabled on 16 of 21 tables in September and cannot be disabled on any of 22
now"; the per-class breakdown in `2026-09-12-assertion-suite.md`.
*What would check it:* `bash scripts/mutate.sh` and `bash scripts/green.sh` against a running
`supabase_db_vsv-management-software` container. Neither is available here and neither can be
approximated from the SQL: the mutation set is enumerated from `pg_constraint`, `pg_index`,
`pg_trigger`, `pg_policies` and `pg_class` at run time, and counting `create table` and
`enable row level security` statements across the migrations gives 23 and 12, which says
nothing about the catalog state after 27 migrations have applied in order.
*What can be said statically:* the W-3 by-class breakdown is internally consistent,
18 + 18 + 16 + 9 + 57 + 38 + 22 + 10 = 188. The `logic` class does contain exactly ten effective
substitutions, twelve rows less two no-op probes filtered by `m.find <> m.repl`, so
`CURRENT-BASELINE.md`'s "ten substitutions" is right. The exclusion-count correction in the
handover file, 20 to 21, is consistent with 219 enumerated less 198 scored.

---

## Predictions that turned out false

Four, recorded because the prompt asks and because in this series the disclosure has been the
signal.

**I expected the ledgers to contradict each other on the discharge state of many entries, and
they mostly do not.** Point 5 of the prompt anticipates entries listed as open that the tree has
fixed. The sorry ledger's Open section is 40 entries and I found no discharge language hiding in
any of them; the three in Discharged are correctly there. The one real instance is `D1` in the
findings ledger, X-3-12, and it is a findings id rather than a sorry. The prompt's framing of
"nine ledger entries discharged themselves when the wire session landed" also does not match the
tree: the nine are corpus findings discharged on arrival, per `docs/review/README.md`, not sorry
entries, and no document enumerates which nine. The README says "the session report for the
archive says which" and the report says only "nine entries were already discharged on arrival",
so that pointer resolves to a statement without the list. Small, and it is a cross-reference
that goes nowhere, which is what point 4 asked for.

**I expected four session reports and there are seven.** The prompt says four exist. `index.md`
lists seven, all seven files are present, and the index's own rows are accurate. Whatever the
prompt was written against, it was not this tree.

**I counted the corpus em dashes by line and got 26, then recounted by occurrence and got 30.**
The report's figure was right and my first pass was wrong. Recorded because the same
line-versus-occurrence distinction is what makes the assertion-count arithmetic in X-3-10 worth
treating as static rather than settled.

**I expected the findings-ledger id references to have dangled after the `AR-` rename and they
have not.** Every `A1` through `E12` reference across the tree resolves, including in the
migrations and the assertion suite. The rename was clean. The dangles that exist are in a
namespace nobody thought to check, which is the W series, X-3-7.

---

## One line on what is sound

The header graph, the em dash rule, the three id namespaces, the compost ledger and the
`CURRENT-BASELINE.md` counts are all genuinely enforced and all genuinely hold, and the
mutation harness refusing to print a bare percentage is the best single decision in the
apparatus.

## The shape of the answer

The prompt asks whether the checker makes the documents true or merely consistent. It makes them
consistent, over a surface substantially smaller than the document layer implies.

Seven checks exist. Two of them, the Deferred rule and the "nothing is built" rule, currently
match zero lines and pass on nothing. One, the module import rule, says out loud that it proves
nothing. One, the count check, guards three sentences in two files after its exemptions. That
leaves the header graph, the em dash rule and the id cross-references as the three that carry
real load, and all three carry it well.

The unenforced remainder, ranked by how silently each would break:

1. `mutate.sh`'s `logic` class shrinking when phases 7 and 8 rewrite the function bodies it
   samples. Silent, and it makes the number go up.
2. Assertion counts anywhere in prose. Already broken in two places in the file `CLAUDE.md`
   names as the single source of build truth.
3. The `W-` namespace. Four governing prompts, zero of them readable, growing by one per work
   session.
4. Any maturity claim in `architecture-rulings.md`, a graded document that check 6 does not
   read and that currently opens by saying nothing in it is built.
5. Grade vocabulary in the status ledger, which is what made the Deferred check inert.
6. The `## State` block of the handover file, exempt from the count check by directory, and the
   first thing a fresh session is told to trust.
7. Migration header fields beyond the two the graph check reads.
8. Everything about the client. `CLAUDE.md` says a client may not encode a business rule and
   adds that it "is the thing that decays first". Nothing checks it, and section B of the
   findings ledger, nineteen entries, is untouched by design.

The single change with the best ratio is to make check 4 derive a named set of quantities rather
than grep two phrases, and to scope the history exemption by filename date rather than by
directory. That one pair reaches X-3-1, X-3-4, X-3-10, X-3-11, X-3-16 and X-3-24.
