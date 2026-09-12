---
Type: record
Purpose: "The file a fresh session with no memory reads first before continuing the W-2 modularization. Holds the phase list and its state, the last green commit, the current migration number, every decision made and why, and everything discovered that changes a later phase."
Depends on: [docs/architecture-rulings.md, docs/findings-ledger.md, docs/session-reports/2026-09-11-verification-surface.md, scripts/green.sh, scripts/mutate.sh]
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
4. Continue at the first phase marked not-started, which is phase 5.

**Before starting phase 5, read this.** `term_kind` appears in nine generated columns, in
a composite foreign key, and in the signature of most functions that touch vocabulary.
Converting it to rows is a large migration whose failure modes are exactly the classes the
mutation score is worst at: check constraints at 13 percent, unique constraints at 12. W-2
gates only phase 7 on that number and phase 5 is not blocked, but the same argument applies
to it in weaker form, and somebody should decide that deliberately rather than by not
noticing. The session report for 2026-09-12 says the same thing at more length.

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

**A check nobody has watched fail is not a check.** The first two rules above were both
found by break tests and neither would have been found by reading.

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
| Last green commit | `f9c9f79`, W-5 handoff, pushed to `main` and to the branch |
| Current migration number | `0027`, so the next one is `0028` |
| Assertions | 204 from empty, 206 against the cellar copy, reproduced from a clean clone |
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

**The findings ledger contains one dangling cross-reference.** Entry A12 cites "E-4's
premise", and `E-4` resolves to nothing in this repository under any reading: not a
ruling, not a compost entry, not a finding, not a spec section, and it appears nowhere
in the review corpus. Left as it stands rather than guessed at. Phase 1's new `AR-` check
would have caught it had it been written as a ruling reference, and cannot catch it as
written.

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
