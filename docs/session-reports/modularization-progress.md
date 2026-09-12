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
4. Continue at the first phase marked not-started.

Do not start a phase you cannot finish. Finishing means green and committed.

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
| Last green commit | `c091fd1`, phase 2 |
| Current migration number | `0023`, so the next one is `0024` |
| Assertions | 137 from empty, 138 against the cellar copy |
| Module migration numbering | not yet designed, phase 6 designs it |

## Phases

| Phase | What | State |
|---|---|---|
| 0 | Reach green at all | done |
| 1 | Namespace collision, rulings ids to `AR-` | done |
| 2 | Read the unreviewed range, `0006` to `0022`, plus the mutation score | done |
| 3 | The resolver registry, `AR-E5` | done |
| 4 | `task_board` against the registry, `AR-E6` | not started |
| 5 | Enums to registry rows, `AR-E7` | not started |
| 6 | The scheduling block to core, plus per-module migration numbering | not started |
| 7 | The schema split and the `public` facade, plus the `AR-B8` gate check | **blocked** |
| 8 | The manifest and the register, plus the `AR-F5` falsifier | **blocked**, it depends on 7 |

**Phase 7 is blocked and phase 8 with it.** W-2 makes the schema split conditional on
phase 2's mutation score improving on the 42 percent `G-5` measured, and it has not. The
numbers are below. A schema move is precisely the operation that can silently change
which policies apply to which rows, and the policy class scores 13 to 20 percent, so the
suite would not tell you if the move broke something. W-2's own instruction is to say so
plainly and stop, and halting with a write-up is a good outcome.

Phases 3 through 6 are not gated on the score and are the next work.

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
| A22 filed rather than fixed | Whether a cellar hand may label a barrel is the winemaker's call, and phase 2 files rather than fixes |

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
