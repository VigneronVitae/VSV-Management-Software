---
Type: record
Purpose: "The file a fresh session with no memory reads first before continuing the W-2 modularization. Holds the phase list and its state, the last green commit, the current migration number, every decision made and why, and everything discovered that changes a later phase."
Depends on: [docs/architecture-rulings.md, docs/findings-ledger.md, docs/session-reports/2026-09-11-verification-surface.md, scripts/green.sh, scripts/mutate.sh, scripts/guards.sh, scripts/ratchet.sh, scripts/undefined-sites.sh, scripts/status.sh]
Depended on by: [docs/session-reports/index.md]
---

# W-2 modularization: progress

**This is not a session report.** It is the handover file. It is written to be
sufficient on its own for a session that has never seen this work, and it is updated
at the end of every phase and whenever a decision is made that a later session would
otherwise have to derive again.

## How to resume

1. Read this file.
2. Verify the tree matches what it claims: `git log --oneline -1` against the last
   green commit below, and `ls supabase/migrations/ | tail -1` against the current
   migration number.
3. Run `bun run green`. If it is not green, the tree does not match this file and
   that is the first thing to resolve.
4. Continue at the first phase marked not-started, which is phase 6. Before it, read
   **the gate**, below the phase table.

**Phase 5 is done**, as W-4 phase 3. The warning that stood here, that `term_kind` touches
nine generated columns and a composite foreign key and that its failure modes are the
classes the score is worst at, was right and the migration is `0027`. What survives of it is
general and applies to phase 6 as well: the classes this suite is weakest at are `weaken` at
6 of 39 and `policy` at 17 of 59, both of which are a policy that is still present and has
stopped refusing anything, and both of which are what a schema move produces.

Do not start a phase you cannot finish. Finishing means green and committed.

## Standing rules

**Commit before every break test, revert after.** A break test deliberately damages the
tree to watch a check fail, and it restores with `git checkout --`, which discards
uncommitted work as well. During W-2 phase 1 that reverted an entire uncommitted rename.
It was done correctly in the session before and wrongly in that one, which makes it a rule
rather than a mistake.

**Do not write shell scripts through a bash heredoc.** It collapses a doubled backslash, so
a Python `'\b'` becomes `''`, which Python reads as an escape and writes as a single
backspace byte. The script parses, `grep -n` prints the line as though the backslash were
there, and the check silently matches nothing. Build such strings with `chr(92)` or use an
editor tool. Detect it by counting `0x08` bytes, not by reading the line.

**Record predictions before measuring, then report them against the result.** W-2 predicted
the mutation score at 55 to 75 percent and got 24, and disclosing that is what made the rest
of that report worth reading. W-3 dropped the habit and said so, which is the next best
thing and not as good.

**An assertion written for a theory that turns out wrong gets deleted, not kept.** An
assertion that passes for a reason other than the one it states adds one to a count and
subtracts from what the count means. W-3 wrote one for a theory about reserved words,
discovered by probe that the theory was wrong, and deleted it rather than keeping a green
line.

**A check is not done until it has been seen to fail for the reason it states.** Break-test
every fix to a fail-open path. This is the fourth time a green check in this project was
proven hollow only by deliberate breakage: the `tgenabled` fingerprint, the `AR-` word
boundary, the A25 empty-row grid, and the assertion that caught its own alarm.

**No path may reach a success report without having done the work the report describes.**
Eleven fail-open paths were repaired in W-6 and every one violated that rule the same way,
by treating the absence of a signal as the presence of a good one. When writing anything
that decides something: what happens if the query errors, returns empty, returns a type
needing a cast, or the database is unreachable.

**A check nobody has watched fail is not a check.** The first two rules above were both
found by break tests and neither would have been found by reading.

**Never edit a script while it is running.** Bash reads a script incrementally rather than
loading it, so shifting the byte offsets under a running interpreter makes it misparse the
part it has not reached yet. W-7 edited a comment in `scripts/mutate.sh` during a run, and
the run completed all 385 mutations and then failed to parse its own scoring section.
Thirty minutes of measurement discarded, two hours after writing this rule down.

**No backtick inside a double-quoted shell string.** The SQL in `scripts/guards.sh` lives
inside `psql -c "..."`, and a backtick in a comment there is command substitution: bash ran
`return;` and an `if` fragment as commands, and the comment that reached the database was
not the comment in the file. It happened twice in one session. Use no quoting for code in a
SQL comment, or move the comment outside the string.

**Ask an assertion for the specific refusal, not for any error.** Most kernel functions
decline the same call at several guards for different reasons, and "it raised" cannot tell
them apart, so an assertion written that way covers the function and no individual guard in
it. W-7's `record_event` assertion passed with the guard it was written for deleted, because
`fork_lot` further down refuses in the same sentence.

**Compare with `is distinct from`, never with `<>`.** `if q <> 222 then raise` does nothing
at all when `q` is null. One assertion in the suite had been passing that way since it was
written, and the update it was written to protect could be deleted without it noticing. This
is A25, the null-permit class, arriving inside the instrument that was built to find A25.

## Predictions for W-10, recorded before measuring

Anchored on detection figures. The relevant prior is W-9's, where reading called the
existence of a defect right 76 percent of the time and running added about half as much
again. This session measures documents against a tree rather than a client against
policies, and I expect documents to be worse than code, because nothing has ever failed a
build over them.

1. **The three counts land at roughly eight to fourteen built and asserted, four to six
   claimed and unverified, and fifty or more ruled and unbuilt.** The middle column is the
   client and I can almost enumerate it now: the end-to-end walk, `viewer_scope`, the
   writable-columns derivation, and the B20 repair. The left column is small because most
   rulings are about a modular system that does not exist yet.

2. **Four to nine places where a session report and the tree disagree.** The mechanism is
   that a report is written at the end of a session and describes a state later sessions
   change, and nothing re-reads it. **The commonest kind will be a blocker that has been
   removed**, because a blocking relationship is the one fact in these documents that
   depends on work done somewhere else. `AR-E6` is already one before I have counted
   anything: its entry still says it is blocked by `task_board`, which `0024` fixed four
   sessions ago.

3. **The ratchet does not hold on the first attempt at phase 6, and that is it working.**
   A structural move creates objects, an object starts uncovered, and the ratchet ratchets
   on the uncovered count. Predicting a red run is predicting the gate does its job; what
   would worry me is a green one, which would mean the move created nothing worth covering.

4. **Two to four of X-2's six EXPLOITABLE findings turn out not to need supervision.**
   "Supervised" was assigned to all six as a class rather than one at a time. A finding
   that needs a data migration or a domain judgment needs the winemaker; one that is a
   policy edit or a constraint does not, and W-9 has just done two of those unsupervised.

5. **At least one ruling I mark `built` will turn out to have no assertion citing it.** The
   citation convention does not exist yet, so I will be attaching `-- AR-` comments to
   existing assertions from my own reading of what each one does, and that reading is the
   same instrument that produced the drift this phase is measuring.

## Predictions for W-9, recorded before measuring

Anchored on detection figures, per W-9. W-8's running produced ten findings reading had not,
against five of seventeen section B entries reproduced. **That 2:1 is the number I distrust
most**, because it was measured on the third of the set I chose to spend the session on, and I
chose the leak. Selection deciding a ratio is the defect this project has spent three sessions
on, arriving in the one figure W-8 was commissioned to produce.

1. **Of the twelve unscored section B entries, seven to ten reproduce, one to three do not,
   and one to two are unreachable in this environment.** The unreachable ones are the two that
   need hardware or a network condition I cannot produce honestly: B8 needs a camera decoding
   frames, B17 needs a session to expire on a device that is offline. I will say which rather
   than simulating them and calling it a reproduction.

2. **Across all seventeen, twelve to fifteen reproduce, and the reading-against-running ratio
   falls to about one to one.** This is the prediction I care about. W-8's 2:1 should not
   survive completing the denominator, because the new findings came from the part of the
   surface I went looking at hardest, and the twelve remaining entries are mostly small and
   local, so they will add reproductions faster than they add discoveries. **If the ratio
   holds at 2:1 on the full set, my explanation was wrong and reading really is worth about
   half of running.**

3. **Of the twenty degenerate policies, five to nine are deliberately permissive and the rest
   are findings.** The deliberate ones are vocabulary: `term`, `term_kind`, `template`,
   `template_step` and probably `location`. Everything carrying wine, ownership, movement or
   people is a finding.

4. **No enumeration of sites would have caught B20, and I do not expect to find one.** A site
   enumeration finds sites and B20 is a density. What would catch it is enumerating render
   paths and asking of each whether it can compose a complete screen from an absent
   response, which is a different question with a different unit. **Two to five siblings.**

5. **Column privileges are not granted per column, so the phase 6 query returns every column
   as writable and the answer is useless.** The kernel enforces this with the
   `cellar_writable_columns` trigger, which is a `BEFORE UPDATE` check and not a grant, so
   `information_schema.column_privileges` cannot see it. I expect phase 6 to end in the
   finding it anticipates rather than in the query it hopes for.

## Predictions for W-8, recorded before measuring

W-8 is the client's first run. Nothing in this project has ever measured the client, so
there is no prior figure to anchor on and the anchoring correction that has now fired three
times has nothing to attach to. W-4 was optimistic by thirty points, W-6 by twenty four, and
W-7, having corrected for exactly that, was pessimistic by fourteen. **A blanket correction
applied to an unfamiliar quantity is a third error, not a fix.** So these are predicted from
the mechanism in each case and the reasoning is written down so that a wrong prediction says
which belief was wrong.

One honesty note before the count. **I am not a stranger to this tree** and phase 1 asks me
to be one. What I can do is follow `README.md` literally and treat every point where I know
something it does not say as the finding. What I cannot do is fail to notice a step, which
is the failure mode a real stranger has. **The count below is therefore a lower bound.**

1. **A stranger following `README.md` stops before the client renders a single row, and
   stops at configuration.** The mechanism is specific: the client has been typechecked and
   built and never run, so the path from `supabase start` to the client knowing a URL and an
   anon key is the one link in the chain that has never carried traffic. Everything before it
   has been exercised every session. **Between five and ten distinct points where the
   documented path does not work**, most of them clustered at that link.

2. **A refusal is indistinguishable from emptiness, and there is no code in the client that
   tries to tell them apart.** Predicted as zero occurrences, not as few. The reason to
   expect zero rather than a handful is that PostgREST returns 200 with `[]` for a denied
   read, so distinguishing them requires having had the thought, and nobody who wrote this
   client had run it against policies.

   **The corollary, and the sharper half: reads and updates are silent, inserts are loud.**
   An insert refused by RLS raises. A select refused by RLS returns no rows and an update
   refused by RLS reports success having matched nothing. So the client will look most
   correct exactly where it is least trustworthy.

3. **Section B, nineteen entries produced by reading: nine to thirteen reproduce, three to
   six do not, one to four are unreachable.** The mechanism for the ones that will not
   reproduce is that a reader of TypeScript cannot see which branches the running client
   takes, and a client written against an imagined API surface has dead paths in it.

   **The run finds twelve to twenty five defects that reading did not**, counting only ones
   actually reproduced rather than everything that looks wrong, per W-7's finding that a
   catch rate carries about a third padding over a detection rate.

4. **The undefined enumeration finds twenty to forty sites and fewer than a third of them
   are real.** Ordering comparisons eight to twenty, `||` where `??` was meant four to
   twelve, optional chaining feeding a comparison three to ten. The reason most will not be
   real is that TypeScript proves a great many of these values non-nullable already, which is
   the one respect in which this layer is better defended than the SQL was. **That is also
   the prediction I am least confident in**, because `strict` settings and `any` at the
   PostgREST boundary decide it and I have not looked.

5. **At least one step in the end-to-end walk appears to succeed and writes nothing.** W-8
   names this as the most important possible observation, and the base rate in this project
   for that specific shape is four for four.

## Predictions for W-7, recorded before measuring, and scored after

Anchored on 31 percent, per W-7 phase 5, which is the least flattering figure available
rather than the most recent. W-4's coverage prediction was optimistic by thirty points and
W-6's by twenty four, both because each anchored on the least adversarial sample then
available while predicting a more adversarial one. Anchoring low is a correction for a bias
that has fired twice in the same direction, not a hedge.

1. **The enumeration finds between 90 and 140 refusal sites.** **Wrong, low by 36: it is 176.**
   The first pass found 134, which is inside the range, and every correction to the
   instrument afterwards pushed the number up. A prediction that scores correct against a
   broken instrument is worth noticing. There are 50 functions and a
   crude count says 49 `raise exception` occurrences, so the loud form is about fifty. W-7's
   point is that the quiet forms are where this class hides, and I expect roughly as many
   again: early returns that report success, `if not found` that does not raise, `coalesce`
   supplying a permissive default.
2. **The catch rate over the full population lands between 15 and 28 percent.** **Wrong,
   high by 14: it was 74 of 176, which is 42 percent.** 19 of those 74 are fixture breakage
   rather than detection, and detection alone is 55 of 176, which is 31 percent, the anchor
   to the point. The anchor was right about the quantity it was measured on and I applied it
   to a different one. Below the 31
   percent anchor, because 31 was measured on sites I chose by reading guards, and every
   site I chose that way was a loud one. The quiet forms are less likely to be covered, not
   more, and adding them to the denominator should pull the figure down.
3. **The first pass of the enumeration will be wrong**, **correct, and the only prediction
   in four sessions that named its own failure mode and hit it.** Also incomplete: there
   were four such failures and the predicted one was the first of them. Because W-7 says to expect it and
   because it has been true every time. My specific guess is that it will miss refusals
   expressed as a `where` clause that matches nothing, since those have no keyword to grep
   for and are the shape that produced A14.
4. **Between five and fifteen sites will be unreachable.** **Correct on the number, eleven,
   and wrong on the reason.** Four of the eleven are `if not found` and not one is behind a
   foreign key. They are equivalent mutants: functions with more than one way to return the
   same answer, so the guard is reached, removed, and no caller can tell. Guessed as: mostly
   defensive `if not found` guards behind a foreign key that already makes the case
   impossible.

## Predictions for W-6, recorded before measuring

Written before phase 1 ran, after reading the three X reports.

1. **Phase 1 will find more fail-open paths than the four X-1 named, and the population is
   nearer ten than three.** X-1 itself filed five more as LATENT that are the same shape, and
   a pass that goes looking rather than stumbling should find a few beyond those.
2. **The behavioural score will land within a few points of X-1's 112 of 198.** It should not
   match exactly, because repairing the harness changes denominators: aborting on a vanished
   substitution target and counting fixture breakage separately both move the count.
3. **The independent function-body substitutions will catch between 55 and 70 percent.** X-1
   got 6 of 9 on its own choices against 10 of 10 on the author's, and there is no reason a
   third set should do better than the second.
4. **Extending the A25 population to trigger validators will find a fourth instance, and it
   will be X-2-1.** That is close to cheating, since X-2 already named it, so the honest form
   of the prediction is that it will find X-2-1 **and nothing else**.

## Predictions for W-4, recorded before measuring

Per the rule above, written down before phase 1 ran.

1. **Phase 1 will not move the percentage and will move the denominator.** The two specific
   defects W-4 names were both already fixed in W-3, so what is left is generalising
   degeneracy detection and making the output refuse to print a bare score. I expect the
   score to stay at 100 percent with roughly 20 mutations newly named as excluded, being the
   19 degenerate `weaken` ones that are currently dropped at enumeration time and the one
   inapplicable unique constraint.
2. **Phase 2 will find a fourth instance, and more than one.** I expect two to five check
   constraints of the shape `X <> 'literal' or <expr that can be null>`, because that is the
   shape `operation_has_an_effect` has and it is the natural way to write a conditional
   constraint in SQL. I do not expect any `security definer` boolean function to have a
   null-returning path, because `0022` rewrote the two that did.
3. **Phase 3 will trip the pinned assertions from W-3 deliberately, and that is the
   protection working rather than a problem.** I also expect the conversion to introduce at
   least one new instance of the phase 2 class, because turning a closed enum into a lookup
   is precisely the operation that makes a previously unrepresentable value representable as
   a missing row.

## The rules this work runs under

**Green means all of:** `bun run verify`, `bun run typecheck`, `bun run lint`, every
migration applying clean from empty into a scratch database, the assertion suite
passing against that scratch database, and the assertion suite passing against a copy
of the cellar. `bun run green` runs all six and exits non-zero if any fails.

**The cellar database has real harvest data in it.** Use `bun run db:up`, never
`db:reset`, and never run a destructive statement against it. `green.sh` touches it
only with `pg_dump`, which reads.

**Stop conditions**, from the W-2 prompt: a migration that cannot apply to both an
empty and a populated database; the assertion count falling; needing a change to the
hosted Supabase project's settings; a phase needing a decision the rulings do not
cover; or a defect found in the unreviewed range serious enough that continuing would
build on top of it. Halting with a clear write-up is a good outcome.

## State

| | |
|---|---|
| Last green commit | the W-7 commit adopting the two gates |
| Current migration number | `0027`, so the next one is `0028` |
| Assertions | 267 from empty, 269 against the cellar copy |
| Behavioural mutation score | 268 of 364, of which 34 are fixture breakage. Snapshot 85, reported separately and not a gate |
| The refusal surface | 176 sites, 165 behaviourally covered, 11 filed at `docs/review/refusal-dispositions.tsv` |
| Module migration numbering | not yet designed, phase 6 designs it |

## Phases

| Phase | What | State |
|---|---|---|
| 0 | Reach green at all | done |
| 1 | Namespace collision, rulings ids to `AR-` | done |
| 2 | Read the unreviewed range, `0006` to `0022`, plus the mutation score | done |
| 3 | The resolver registry, `AR-E5` | done |
| 4 | `task_board` against the registry, `AR-E6` | done |
| 5 | Enums to registry rows, `AR-E7` | done, as W-4 phase 3 |
| 6 | The scheduling block to core, plus per-module migration numbering | **unblocked**, next |
| 7 | The schema split and the `public` facade, plus the `AR-B8` gate check | **unblocked** |
| 8 | The manifest and the register, plus the `AR-F5` falsifier | **unblocked** |

**Phase 7 was blocked and is now unblocked.** W-2 made the schema split conditional on
the mutation score improving on the 42 percent `G-5` measured. In September it came back
at 24 percent and the stop was correct. W-3 exists because of that, and after it the score
is 188 of 188. The gate is met, so W-2 phases 5 through 8 resume as written.

The gate was not lowered and the number is not a trend. It is a threshold, and the
threshold is cleared on a mutation set that is four times the size of the one that failed
it.

**That 188 of 188 was mostly a change detector, and the gate is a different one now.** W-6
split the score and W-7 replaced the threshold with two ratchets, written up in
`docs/review/CURRENT-BASELINE.md` and enforced by `scripts/ratchet.sh`. Before starting
phase 6, 7 or 8:

1. Run `bash scripts/ratchet.sh`. About thirty five minutes. It must say RATCHET HELD.
2. Do the phase.
3. Run it again. A declarative phase must not raise any class's uncovered count; a phase
   that rewrites a function body must leave every enumerated refusal site covered or filed.
4. If a phase adds a refusal site, it adds the assertion in the same phase. If it removes
   one, `docs/review/refusal-sites.tsv` is regenerated with `bash scripts/guards.sh` in the
   same commit, or `bun run green` gate 6 fails.

`bun run green` is still the per-phase gate and now carries the cheap half of this as gate
6: that the committed enumeration still describes the kernel, and that every filing resolves
to a site that exists.

## Phase 0: reach green at all

Not in the W-2 prompt. It exists because W-2 defines green as including `bun run lint`
and two database halves, and none of the three could pass when the session started.

**`bun run lint` could not pass on this checkout.** Forty of ninety eight tracked files
arrive in the working tree with CRLF, because `core.autocrlf` is true on this machine,
and Biome refuses six of them on that alone. Every committed blob is already LF, so
this was never a content problem. `.gitattributes` now pins `eol=lf`, which changes no
file's content and changes what checkout writes.

*Recorded because it was got wrong twice:* the previous session diagnosed this
correctly, and the check used to confirm it at the start of this session,
`grep -q $'\r'`, reported zero CRLF files on a tree where python counted forty. Count
bytes. Do not use grep for this.

**One real lint error**, at `walk.ts:1497`, a `forEach` callback returning the value of
`parts.push()`. Rewritten as a `for...of`. This is the only client change in W-2 and it
is not a section B defect; it is the linter being unable to pass.

**`tests/shim.sql` is committed**, which discharges D1. Not a W-2 phase either, but
green requires all migrations to apply from empty every phase, and that needs the shim
every time. It is built to the specification in W-1 and its header says which migration
needs which part of it, because the next person will otherwise assume it is optional:
`0002` cannot apply without the realtime publication and has no guard, while `0005` and
`0022` guard their storage blocks and skip with a notice.

**`scripts/green.sh` and `bun run green`** exist for the same reason: eight phases each
ending green means running this many times, and a gate that is six commands run by hand
is a gate that gets partially run.

**`verify.sh` now scans `.sh` files.** It did not, which meant its own typed header was
the one header in the tree that nothing checked. That header named `package.json`,
which carries no header and never could, so the edge could not have resolved. Fixed in
both directions.

### The two assertion counts differ by one, on purpose

128 from empty and 129 against the cellar copy. The scratch database has no storage
schema, so the two vessel-photos policy assertions report that they were not asserted
instead of asserting two things. `green.sh` checks that the difference is exactly one
and fails if it is anything else, so this cannot quietly become a real gap.

## Phase 2: the unreviewed range, and the number that stops phase 7

Fifteen migrations, `0006` through `0022`, which the thirteen-report corpus never saw
because it was run against a tree of five. Read against the five patterns W-2 names,
using `R-5`, `R-6`, `G-1` and `G-4` as lenses. Output is ledger entries, not fixes:
`docs/findings-ledger.md` is now 1.1.

### The mutation score

Measured with `scripts/mutate.sh`, which is committed, because `G-5` measured 42 percent
and did not commit its harness, so the number could not be reproduced or improved
against. That is D1's shape applied to a measurement. The method is `G-5`'s: build one
base database, clone it per mutation, apply one mutation, run the suite, caught means the
suite exits non-zero. The mutations are enumerated from the catalog rather than written
down, so the set grows with the schema.

| Set | Mutations | Caught | Score |
|---|---|---|---|
| Everything, 22 migrations | 115 | 28 | **24%** |
| Only objects that existed at the reviewed baseline | 71 | 15 | **21%** |
| Only objects added since `0006` | 44 | 13 | 30% |
| `G-5`, for comparison, on its own 45 | 45 | 19 | 42% |

By class, over everything: check constraints 13 percent, unique constraints and indexes
12 percent, triggers 89 percent, policies 20 percent, row level security disable 24
percent.

**The comparison is not exact and does not need to be.** `G-5` chose 45 mutations; this
harness enumerates 115 from the catalog, so the denominators differ and the second row of
that table is the fairest read: on the same objects, using a larger and more systematic
mutation set, the suite catches 21 percent. Absolute catches rose from 19 to 28 while the
schema roughly doubled. The suite grew and its coverage of the schema fell.

**The single most quotable result.** Row level security can be turned off outright on 16
of 21 tables and the suite still passes: `app_user`, `party`, `lineage`, `placement`,
`task`, `task_claim_log`, `template`, `template_step`, `vessel_code`, `block`,
`vessel_type_note` and all five procedure tables. The five that are caught are the ones
an assertion happens to read through a second principal. That is D11 and it is the
cheapest thing in the ledger to close.

### What the read found

Two new entries, A22 and A23, plus three infrastructure entries D10 to D12.

**A22 confirms the prediction this file made before phase 2 started.** There is a seventh
write path running as the caller against a policy that refuses it: `bind_vessel_code`,
invoker, inserting into `vessel_code`, whose only write policy is `is_admin()`. A cellar
user cannot put a sticker on a barrel. It differs from A14's class in failing loudly,
because a refused INSERT violates a `with check` and raises where a refused UPDATE
matches zero rows and says nothing. Whether it should be refused at all is a question for
the winemaker rather than a defect to fix unsupervised: creating a vessel is admin work
and the suite asserts that on purpose, and labelling one during harvest may not be.

The search was exhaustive rather than a spot check. Every function in `public` was matched
against every table it writes, and every such table's insert and update policies were
read.

**A23** is `vessel_type_note`, added by `0012` with `using (true)` on select, which is
A5's blanket default arriving on new surface. The five tables `0019` added do not repeat
it, so the habit changed mid-session and `0012` predates the change.

### What the read checked and did not find

Written into the ledger as its own section, because a review that reports only its finds
cannot be told apart from one that stopped early. No new instance of A10, the derived
function that inner-joins something optional: `vessel_history` left-joins the nullable
author, which is the correct shape. No new instance of A18 or A19, the stored derivation:
two columns were added in the whole range and both are stored choices, and
`procedure_run_state`, which carries `actual_seconds` and `over_by_seconds`, is a view.

And one risk that `0022` introduced without noticing: tightening `event_insert` to
`by_user = auth.uid() and by_sensor is null` would break any function writing an event in
another name. All six that insert into `event` were checked and every one writes
`auth.uid()`. No path breaks. That could have gone the other way.

### Scoring the predictions this file made

1. **Correct.** A seventh write path exists: A22.
2. **Wrong, and wrong in the optimistic direction.** The prediction was 55 to 75 percent.
   It is 24 percent, and 21 on the comparable subset, which is not a smaller improvement
   than expected but a decline. The reasoning behind the prediction, that the new
   assertions were written against known defects rather than against the schema generally,
   was right; what it missed is that the schema grew faster than the suite, so writing
   good assertions about the defects you fixed still loses ground.
3. Not yet testable. It belongs to phase 8, which is blocked.

## What should happen about the score

Not a decision to take unsupervised, so it is written down rather than acted on.

The cheapest single improvement is D11: an assertion per table that row level security is
enabled, derived from the catalog rather than listed, in the shape of the existing checks
that every view is `security_invoker` and every function pins `search_path`. That is one
loop and it converts 16 surviving mutations into caught ones, which on its own would take
the overall score from 24 to roughly 38 percent.

The second is the policy class, which is the one that actually gates the schema split.
Thirty eight of 54 policies survive being dropped. Closing that means a probe per policy
per principal, which is real work and is the thing W-2 declined to authorise by making
the score a stop condition rather than a task.

## Phase 3: the resolver registry

`0023_subject_resolver.sql`. `AR-E5`, and the prerequisite the A-1 survey measured as
making phase 4 cost under a day instead of half again as much.

The property that matters is an absence. `subject_resolver.relation` is `text` and not
`regclass`, because a `regclass` column would record the dependency in `pg_depend` and put
back exactly the wrong-way edge the registry exists to remove. Resolution goes through
`to_regclass`, which answers null for a relation that is not there. An assertion checks
the column's type for that reason, so the next person who helpfully tightens it will be
told what they broke.

Resolution deflates at every step, per `AR-B7` and `AR-G2`: no resolver registered, the
module absent, the row gone, or the row invisible to this caller all answer null, and none
of them raises. `resolve_subject_name` is `security invoker` twice over on purpose, so the
stored expression runs with the caller's own rights and row level security still evaluates
as the caller, which means a client asking the name of a lot they cannot see gets null
rather than the name.

Probed by dropping `block` inside a savepoint: resolution went quiet, `subject_is_resolvable`
went false, nothing raised, and the savepoint restored it.

The four subject types that exist are registered as rows, saying exactly what `task_board`'s
`CASE` says today. Phase 4 deletes the `CASE` rather than teaching it a fifth branch.

**An assertion written to change its own answer.** The drop also confirms that
`task_board` still cascades from `block`, which is the declarative edge phase 4 removes.
The assertion reports which of the two states it is in rather than asserting one, so when
phase 4 lands it will start saying the other thing without anybody editing it.

New sorries: S-41, the registry stores an expression it later executes, which is not an
escalation today because the function is invoker and only admins may write the row; and
S-42, resolution is one query per row, which is `AR-I3`'s trade taken deliberately.

## Phase 4: `task_board` stops naming module tables

`0024_task_board_via_registry.sql`. `AR-E6` named this one view as the single declarative
reason core cannot install alone, and the A-1 survey probed it: `drop table block cascade`
reported the cascade to `task_board`.

Proven twice, both ways round.

**Identical output.** A scratch database with tasks of all four subject types, plus one
whose subject does not exist, captured before and after. Five rows, byte-identical,
including the null name for the task pointing at nothing.

**The cascade is gone.** `drop table block cascade` on that same database reported the
cascade to `task_board` before and reports only `node_block_id_fkey` after. That remaining
edge is `node.block_id`, which is `AR-F5` and belongs to phase 7.

Two assertions hold it. The one written in phase 3 to report which of two states it was in
now asserts the first, without anybody editing its text. A second reads `pg_depend`
directly, so it fails on the change rather than on the consequence.

**Deviation from the prompt, recorded in the migration as well as here.** W-2 says rewrite
it as a lateral join and `AR-E5` uses the same phrase. A lateral join needs the relation
known at plan time, and the whole point is that it is not known until a row is read, so a
view cannot have one. A scalar call to `resolve_subject_name` is the achievable form of
the same idea and buys the same property. The cost is S-42, one dynamic query per row,
which 0023 filed as a trade and this takes. If the board is ever slow enough to measure,
the answer is a per-type contract view and a real lateral join over the union, which is
`AR-B4`'s shape and belongs with phase 8.

`create or replace view` rather than drop and create, so the column list is unchanged, no
grant is lost, and the client keeps working untouched.

## W-3: making the suite police the schema

W-2 phases 5 through 8 are on hold until this finishes. W-3's phases are A, B, C, D and
they are tracked here alongside W-2's.

| Phase | What | State |
|---|---|---|
| A | RLS assertions | done |
| B | Constraint assertions | done |
| C | Remeasure and decide whether phase 7's gate is met | done, **gate met** |
| D | A22, the `E-4` repoint, the standing rule | done |

### Phase A: row level security is now asserted to be on

The set-independent fact W-3 is built around: row level security could be disabled on 16
of 21 tables and the suite still passed. It is now 0 of 22.

Derived rather than listed, because every base table in `public` carries row level
security, so the rule is "all of them" and a table added later is covered the moment it
exists rather than the moment somebody remembers. Three class assertions: every base table
has RLS, none has it forced, and no table has it on with no policy at all, which would
deny everything silently and look like an empty cellar.

Two pinned facts about the policy surface: the count, and the exact list of policies whose
predicate is literally `true`, which is ledger A5's surface written down. Both need a
deliberate edit when a migration changes them, and that friction is the point.

The behavioural half of A6 now exists. The catalog half was asserted when `0022` landed;
this probes `storage.objects` as a client and as a cellar user, guarded on the storage
schema the same way `0005` and `0022` guard, so it runs against the cellar and reports
itself skipped against the shim.

A7 is asserted in both directions and one of them is deliberately the defect. A cellar
user creating a lot, placing it and giving it a parent must work, which is what makes
dropping those three policies a caught mutation. A client can still do the same thing,
which is A7 open, and that assertion is written to fail when A7 is fixed so the fix and
the assertion land in one commit.

**Measured, not reasoned:** `bash scripts/mutate.sh rls` reports 22 of 22 caught, 100
percent.

### The harness gained a class, and it changes what the numbers mean

Dropping a policy and weakening one are different tests and only the second is the failure
mode a schema move produces. A pinned list of policy names catches every drop and nothing
else; a policy that is still there and has stopped refusing anything is invisible to it.

`weaken` recreates each policy with the same name, command and roles and a predicate of
`true`. Nineteen of the fifty six are excluded because they are already `true`, so
weakening them injects no defect at all; counting those as survivors would have
understated the suite by nineteen and that would have been the same mistake this whole
session exists to correct.

**`bash scripts/mutate.sh weaken` reports 37 of 37 caught, 100 percent.** Behavioural
policy coverage is strong, which the 20 percent drop score did not show and could not.

### Phase B: the constraint surface

The category phase 5 depends on, which phase A does not touch at all.

Pinned first: the constraint inventory by type, the nine composite foreign keys into
`term(id, kind)` by name, and the nine generated kind columns by their exact expressions.
Those nine pairs are precisely what W-2 phase 5 has to move, and a migration that changes
any of them now fails loudly. Delete behaviour is pinned too, by count and by naming the
four `ON DELETE RESTRICT` keys, because a schema move that recreates a foreign key is
exactly where a cascade becomes a no-action unnoticed.

Then behaviour, one constraint at a time, each violating exactly one thing. That last part
turned out to matter more than it sounds: the first attempt at the vessel thermal pair
violated both constraints at once, so loosening either one still raised and neither was
covered. `G-5-6` is the same observation about `vessel_code`.

**Measured, with both numbers W-3 asked for:** the check-constraint class went from 13
percent to 100, and the unique-constraint class from 12 percent to 100.

### What writing the assertions found

**A24, and it is the third of its kind.** `operation_has_an_effect` reads
`kind <> 'operation' or attributes ->> 'effect' in (four values)`. For an operation with no
effect at all the inner test is `null in (...)`, which is null, so the check is
`false or null`, which is null, and **a check constraint passes on null**. An effectless
operation lands. The four-effects invariant refuses a wrong answer and not a missing one.

That is the same three-valued-logic shape as A1's `coalesce(..., true)` and
`may_see_all_of` returning null. Three times now, in three different mechanisms, by three
different routes.

**It also corrects B2.** Two reports said adding an operation inline always raises because
`addTerm` sends `{}`. It does not raise. It lands, and the operation is silently inert
because the kernel reads no effect from it. A raise would have been visible. Filed, not
fixed: section A beyond A22 is out of scope here.

### Phase C: the numbers, each with its set named

| Set | Mutations | Caught | Score |
|---|---|---|---|
| `G-5`, September, its own 45 | 45 | 19 | 42% |
| This harness, September, at `0022` | 115 | 28 | 24% |
| Same objects as the review saw, September | 71 | 15 | 21% |
| **This harness, now, at `0025`** | **188** | **188** | **100%** |

By class, now: check 18 of 18, loosen 18 of 18, unique 16 of 16, trigger 9 of 9, policy
57 of 57, weaken 38 of 38, rls 22 of 22, logic 10 of 10.

**The RLS-off count, which is the set-independent fact to watch across sessions:** 16 of 21
tables in September, 0 of 22 now.

**`G-5`'s original 45 could not be reconstructed, and that is a real limitation rather than
a rounding note.** Its report names its caught and survived objects, but roughly nine of
its forty five were function-body mutations of a kind this harness did not implement.
Rather than quietly skip that, a `logic` class was added: ten substitutions against
`pg_get_functiondef`, so each mutation carries the function's real signature and
`search_path` rather than a copy that drifts, and a substitution whose target has gone
reports as not applicable, which is also how the list tells you a function changed shape.

### Three things the harness got wrong first, all corrected

**Multi-line mutations were silently truncated.** The mutation file is line based and
`read` stops at the first newline, so all ten function-body mutations reported as
inapplicable. They now travel base64 encoded.

**Nineteen `weaken` mutations were degenerate.** Recreating a policy with a predicate of
`true` where the predicate is already `true` injects no defect, so counting them as
survivors understated the suite by nineteen. Excluded, the way an undroppable constraint
already was.

**One mutation was equivalent and it took two attempts to establish that rather than assume
it.** Removing `quote_ident` from `resolve_subject_name` survived. The first theory was an
equivalent mutant, the second was that a reserved word like `order` would break it, and the
probe settled it: `from public.order` parses unquoted, because schema qualification lets the
parser accept a reserved word. The mutation really is equivalent for every name
`relation_is_a_bare_name` permits. The assertion written for the wrong theory was deleted
rather than kept, because an assertion that cannot fail for the reason it gives is the
inflation this repository is against, and the mutation was replaced with one that
discriminates.

### Phase D

**A22 is built,** `0025`. Ruled by the winemaker: bind an unbound code as anyone who works
here, rebind one only as an admin, and the refusal names the barrel that already holds the
sticker. Done the way `0021` did it, a narrow insert policy rather than a blanket definer,
so update and delete stay admin and the table cannot be rebound directly either. Both halves
asserted, including the wording of the refusal. S-43 records that the permitted path is
silent, which is A17's class.

**The `E-4` reference is repointed.** It was never a ruling reference, so the `AR-` rename
exposed it rather than caused it. A12 now cites `CLAUDE.md`'s append-only statement and the
`R-5` report.

**The standing rules are at the top of this file**, where a fresh session reads them before
starting anything.

### A note on what 100 percent does not mean

It means no constraint, index, trigger, policy or row level security setting can be removed
or neutered without the suite noticing, and that ten specific pieces of kernel logic cannot
be altered without it noticing either. It does not mean the kernel is correct. The `logic`
class is ten hand-chosen substitutions, not a systematic mutation of every branch in every
function, and a written list is the kind of thing that goes stale. The honest reading is
that the declarative surface is now policed and the procedural surface is sampled.

## W-4: the harness, the null-permit class, and phase 5

| Phase | What | State |
|---|---|---|
| 1 | Repair the harness | done |
| 2 | The null-permit class | done |
| 3 | W-2 phase 5, both enums | done |
| 4 | The standing rules | done, first |

### Phase 1: the instrument

The two defects W-4 names were both already fixed in W-3, so the work was the part
underneath them: a harness that reports a number without reporting that the number is
unsound. It now fingerprints the catalog before and after every mutation. A mutation that
applies and changes nothing is degenerate, named, and excluded from both columns. The
enumeration-time exclusion of the nineteen already-open policies is gone, because dropping
them quietly was correct and invisible and invisible was half the problem.

The score cannot appear bare. Every run ends with what it excluded and why, and a run that
scores nothing exits non-zero.

**Writing that check reproduced the defect it was written to prevent.** The fingerprint
query raised, because `tgenabled` is `"char"` and concatenating it needs a cast, so the
function returned empty and the guard `[ -n "$before" ]` skipped degeneracy detection
silently for every mutation. A check that fails open and says nothing, inside the fix for
checks that fail open and say nothing. It aborts now, and that abort is break-tested.

| | Before | After |
|---|---|---|
| Reported | 188 of 188, 100 percent | 188 of 188 scored, from 208 enumerated |
| Excluded | 19 dropped at enumeration, 1 refused to apply, neither mentioned | 20, named in the output |

The percentage did not move and was never the point.

### Phase 2: the null-permit class, and the fourth instance that is not there

A25 is filed as a class. The invariant: **in the fixed layer, a predicate that cannot
determine an answer must refuse, never permit.** That is `AR-B9` applied below the gate.

The derived assertion enumerates every check constraint and every boolean function from
the catalog and exercises each against every row the table could actually hold. **At `0027`
the allow-list has exactly one entry, A24, and there is no fourth instance.** A class with
three instances and no fourth is the result, not the absence of one.

**Two wrong tests preceded the right one and both are recorded in the assertion**, because
a reader will otherwise reinvent them. A row of all nulls flagged twelve constraints,
eleven wrongly: forcing a NOT NULL column to null asks about a row the table can never
hold. A row of empty values flagged none, including the real one, because A24 needs
`kind = 'operation'` and the empty row takes the first enum label. The second version
passed and would have passed forever; it was caught only because the break test took A24
off the allow-list and nothing failed.

B2 is broadened: an effectless operation does not raise, it lands silently inert, which is
A13's shape arriving through a check constraint rather than through row level security.
A13 is therefore not only about RLS.

### Phase 3: both enums are rows now

Split into two migrations so each is green on its own.

`0026`, `subject_type`. The registry already existed, so the enum is deleted rather than
duplicated: registering a resolver is what brings a subject type into existence. Three
foreign keys with `on delete restrict`, so uninstalling a module while tasks still point at
its subjects is refused.

`0027`, `term_kind`, much the larger: nine generated columns, nine composite foreign keys,
four views, a view-returning function, three constraints, an index and two typed defaults.
Enumerated from the catalog rather than listed by hand, following `0020`.

**Two traps, both of which would have been silent.**

Dropping a generated column and adding it back moves it to the end of the table.
`vessel_state` reads `visible_node` through a **positional** column alias list, so
reordering `node` rebound `product_type_id` to `hidden` and the view came back with
`uuid = text[]`. The columns are altered in place instead. It failed loudly only because
this migration recreates the view; one that did not would have left the alias list quietly
wrong.

`validate_vessel_type_fields` proved that a picker names a real vocabulary **by casting the
text to the enum and catching the failure**. Rewrite `::term_kind` to `::text` and the cast
always succeeds, the handler never fires, and the validator silently stops validating. It
is a registry lookup now. This is exactly the shape W-4 warned the conversion produces, and
it was caught by reading the body rather than substituting into it.

### The pins earned their keep

Five separate pinned assertions failed across the two migrations and every one was
deliberate: the constraint inventory, the generated-column expressions, the policy count,
the wide-open policy list, and the foreign-key delete behaviour. That is what W-3 phase B
pinned them for.

### The mutation score, with its set named

| When | Scored | Caught | Score | Excluded |
|---|---|---|---|---|
| W-3 end, at `0025` | 188 | 188 | 100% | 20, unreported |
| W-4 phase 1, at `0025` | 188 | 188 | 100% | 20, named |
| After `0027`, before closing the gap | 198 | 195 | 98% | 20, named |
| After closing it | 198 | 198 | 100% | 21, named |

**The fall to 98 percent was real and was mine.** `0026` and `0027` added three bare-name
check constraints and nothing asserted them, which the `loosen` class found the moment they
existed. Three assertions closed it. That is the harness doing its job on new surface
within the same session that created the surface.

## W-5: the handoff, and one number corrected

`main` was still at `c3eae3c`, the commit the thirteen-report corpus reviewed, while twenty
six migrations of work sat on the branch. A reviewer cloning the default branch would have
passed every canary in every archived prompt and reviewed the already-reviewed tree.
`main` is now fast-forwarded to the current head and pushed, and
`docs/review/CURRENT-BASELINE.md` records what the trap was and why the canaries were
chosen the way they were: identify a tree by things that only exist in it, not by where it
is parked or how large it is.

**Reproduced from a clean clone of the pushed remote rather than from the working tree:**
27 of 27 migrations from empty, 204 assertions there, 206 against a copy of the cellar, and
198 of 198 scored mutations caught.

**One correction to W-4's numbers.** The exclusion count in the last row of the table above
was 20 and is 21: 20 degenerate plus 1 inapplicable, from 219 enumerated. W-4 ran only the
`loosen` class after adding the three bare-name assertions and carried the exclusion count
forward from the full run before `0027`, which had one policy fewer. The score itself, 198
of 198, is unchanged and was verified. The 2026-09-12 session report still says 20; reports
are append-only by their own convention, so the correction lives here and in this session's
commit rather than as an edit to it.

## Decisions

| Decision | Why |
|---|---|
| `.gitattributes` pins `eol=lf` tree-wide | Green includes lint, lint could not pass, and no blob content changes |
| The shim lands now rather than in a W-1 follow-up | Green includes a from-empty build every phase |
| `green.sh` exists | Six commands run by hand is a gate that gets partially run |
| `verify.sh` scans `.sh` | Otherwise the checker's own header is unchecked |
| Scratch and copy counts may differ by exactly one | The storage skip, and only that |
| Two `A-1` references in the rulings are not renamed | They name the review prompt, not ruling `AR-A1` |
| `verify.sh` gained an `AR-` cross-reference check | Separating namespaces stops ambiguity; checking them stops a reference pointing at nothing |
| Ruling ids bumped the document to 2.1, not 2.0.1 | Ids are how other documents refer to it, so a consumer re-reads |
| `scripts/mutate.sh` is committed | `G-5` measured and did not commit, so its number could not be reproduced |
| Mutations enumerated from the catalog, not listed | A written list goes stale; this set grows with the schema |
| `task_board` uses a scalar call, not a lateral join | A lateral join needs the relation at plan time and a view cannot have it |
| The harness gained a `weaken` class | Dropping a policy and weakening one are different tests; only the second is what a schema move does |
| Degenerate `weaken` mutations excluded | A policy already `true` cannot be weakened, and counting it as survived understates the suite |
| `green.sh` derives the expected assertion gap | Adding another storage-guarded block should not require editing a number |
| A22 filed rather than fixed | Whether a cellar hand may label a barrel is the winemaker's call, and phase 2 files rather than fixes |
| A22 then built in `0025` | The winemaker ruled it in W-3 |
| Multi-line mutations travel base64 | A line-based file truncates them at the first newline, silently |
| Degenerate and equivalent mutants excluded | A mutation that injects no defect is not a coverage gap |
| A24 filed rather than fixed | Section A beyond A22 is out of W-3 scope |
| Degeneracy detected by fingerprint, not at enumeration | Excluding quietly is half the defect |
| The harness aborts when its fingerprint is empty | A check that fails open and says nothing is the thing being fixed |
| Phase 3 split into `0026` and `0027` | Each is green on its own, and W-2 required only that both enums move |
| Generated columns altered in place, not dropped | `vessel_state` reads `visible_node` through a positional alias list |
| `validate_vessel_type_fields` rewritten, not substituted | Its cast to the enum *was* the check, and `::text` always succeeds |

## A tooling trap that has now cost time twice

Writing a shell script through a bash heredoc collapses a doubled backslash. A Python
source line reading `'\bAR-...'` arrives as `'AR-...'`, which Python then reads as
an escape and writes a single backspace byte, 0x08. The script still parses, `grep -n`
prints it as if the backslash were there, and the check silently matches nothing.

It happened in the previous session to the `S-` and `C-` word boundaries, and again in
this one to the `AR-` check, which was committed broken in phase 1 and caught by its own
break test. `verify.sh` scans for stray control characters in no way at all, which is
why it does not catch this itself.

*How to avoid it:* build such strings with `chr(92)`, or write the file with an editor
tool rather than through a heredoc. *How to detect it:* count `0x08` bytes, do not read
the line. A break test catches it; assuming a check works does not.

## Discovered, and it changes a later phase

**`0020` breaks on any install where pgcrypto lands in `public`.** It pins
`search_path` on every function in `public` with no `proconfig`, which on such an
install includes `digest`, and it fails with "must be owner of function digest".
`tests/shim.sql` puts pgcrypto in `extensions` where Supabase puts it, so the shim
matches the real thing and the defect stays visible rather than being papered over.
This matters for phase 7: moving tables into module schemas does not move functions
unless somebody says so, and `0020`'s "every function in public" becomes "every
function in which schema" the moment there is more than one.

**Resolved, and kept for the reasoning.** The findings ledger contained one dangling
cross-reference: entry A12 cited `E-4`, which resolved to nothing in this repository under
any reading. W-3 repointed it at `CLAUDE.md`'s append-only statement and the `R-5` report,
because it was never a ruling reference and the `AR-` rename exposed it rather than caused
it. This section went on reporting it as open for two sessions after it was closed, which
is X-3-13 and is the reason a live handover file should not accumulate a history section:
the W-3 entry below already recorded the fix.

## Predictions made, for later scoring

Recorded now so they cannot be quietly revised. The previous session's corpus earned
its credibility from the runs that disclosed their own misses.

1. Phase 2 will find at least one more write path that runs as the caller against an
   admin-only policy, beyond the six `0021` fixed.
2. The mutation score will have improved but not enough, landing between 55 and 75
   percent, because the new assertions were written against known defects rather than
   against the schema generally.
3. Phase 8's `AR-F5` falsifier will pass, meaning winemaking installs with no vineyard
   module once `block_id` is gone, because `block_id` really does look like the only
   coupling.
