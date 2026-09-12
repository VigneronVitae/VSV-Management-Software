# G-5: testing and continuous integration

**Target:** `github.com/VigneronVitae/VSV-Management-Software`
**Reviewed at:** `c3eae3c7c262544e4b2e29526b513c964c6852fe`
**Date:** 2026-09-11

---

## Report header

### 1. Tier and route

**Tier A.** Full tree on disk. Route 1 succeeded on the first attempt:
`git clone https://github.com/VigneronVitae/VSV-Management-Software` over the Bash tool
surface. No fallback route was needed. Citations are `path:line` against the working tree.

### 2. Commit

```
$ git rev-parse HEAD
c3eae3c7c262544e4b2e29526b513c964c6852fe

$ git log --oneline -1
c3eae3c File the walk session report, and correct the reverse dependency edges
```

This is the baseline commit exactly, neither ancestor nor descendant.

### 3. Canaries

| Canary | Result |
|---|---|
| Branch is `main`, not `claude/sql-files-to-markdown-i31rob` | Confirmed |
| Tree holds more than `LICENSE` | Confirmed, 42 files |
| `supabase/migrations/0005_account_and_walk.sql` | Present, 340 lines |
| `tests/schema_assertions.sql` | Present, 412 lines |
| `packages/cellar/src/walk.ts` | Present, 805 lines |
| `docs/session-reports/2026-09-08-walk.md` | Present, 202 lines |
| Tracked file count | 42, matching |

### 4. Execution results

**All five migrations applied clean from empty**, in order, with no errors.

**28 of 28 assertions in `tests/schema_assertions.sql` ran and passed.** The suite emits 28
`test_ok` lines and carries 28 `raise exception 'FAIL...'` guards, so the announced count and
the checked count agree. `psql` exited 0.

**The storage-guarded block did not execute.** The shim has no `storage` schema, so
`0005_account_and_walk.sql:307-340` printed `storage schema absent, skipping the
vessel-photos bucket` and skipped. This is the number the prompt says two earlier reports
disagreed on: my run is the skipped variant, and the 28 count is the count with that block
skipped. It does not change the assertion count either way, because the suite never touches
storage.

Shim, built to the prompt's spec: Postgres 16.13, an `auth` schema with `auth.users`,
`auth.uid()` reading `request.jwt.claim.sub` and falling back to the `request.jwt.claims`
blob, roles `anon` / `authenticated` / `service_role` with Supabase's default grants on
`public` applied through `alter default privileges`, an empty `supabase_realtime`
publication, no `storage` schema.

Probes ran under `set local role authenticated` and `set local role anon` with the JWT claim
set, never as the migration owner. Five principals were exercised: an admin, a facility
cellar user, a client login with a party row, an authenticated principal with no `app_user`
row, and `anon`.

### 5. File table

Every tracked file was read whole from disk. No truncation, no partial reads.

| Path | State | Lines |
|---|---|---|
| `CLAUDE.md` | whole | 130 |
| `README.md` | whole | 59 |
| `package.json` | whole | 24 |
| `apps/web/package.json` | whole | 19 |
| `packages/cellar/package.json` | whole | 11 |
| `packages/core/package.json` | whole | 10 |
| `biome.json` | whole | 30 |
| `tsconfig.json` | whole | 40 |
| `tests/schema_assertions.sql` | whole | 412 |
| `supabase/config.toml` | whole | 56 |
| `supabase/migrations/0001_core_schema.sql` | whole | 370 |
| `supabase/migrations/0002_derived_and_rls.sql` | whole | 334 |
| `supabase/migrations/0003_parties_and_products.sql` | whole | 284 |
| `supabase/migrations/0004_terms_and_effects.sql` | whole | 519 |
| `supabase/migrations/0005_account_and_walk.sql` | whole | 340 |
| `packages/core/src/kernel.ts` | whole | 297 |
| `packages/core/src/env.ts` | whole | 27 |
| `packages/core/src/types.ts` | whole | 125 |
| `packages/core/src/index.ts` | whole | 6 |
| `packages/cellar/src/walk.ts` | whole | 805 |
| `packages/cellar/src/pickers.ts` | whole | 201 |
| `packages/cellar/src/ui.ts` | whole | 141 |
| `packages/cellar/src/scan.ts` | whole | 125 |
| `packages/cellar/src/sticky.ts` | whole | 35 |
| `packages/cellar/src/index.ts` | whole | 3 |
| `apps/web/src/index.ts` | whole | 27 |
| `docs/status-ledger.md` | whole | 112 |
| `docs/sorry-ledger.md` | whole | 156 |
| `supabase/seed/.gitkeep` | whole | 0 (empty) |
| `.github/` | **absent** | n/a |

Remaining tracked files (`LICENSE`, `bun.lock`, `.gitignore`, `apps/web/index.html`,
`apps/web/src/app.css`, `apps/web/vite.config.ts`, `apps/web/.env.example`,
`packages/cellar/docs/spec.md`, `docs/compost-ledger.md`,
`docs/methodology-lineage.md`, `docs/session-reports/*`) were read whole and are not
load-bearing for this prompt's findings.

---

## Findings table

| Id | Severity | Triage | One line |
|---|---|---|---|
| G-5-1 | MAJOR | BEFORE HARVEST | `bun run test` is not a script; it silently executes `/usr/bin/test` |
| G-5-2 | MAJOR | BEFORE HARVEST | The suite passes with `security_invoker` stripped from both read views |
| G-5-3 | MAJOR | BEFORE HARVEST | `enable_signup = false` blocks the stranger's-first-run the walk is built around |
| G-5-4 | MAJOR | DURING | Migrations are neither transactional nor re-runnable |
| G-5-5 | MINOR | AFTER | 26 of 45 mutations survive; the mutation score is 42% |
| G-5-6 | MINOR | AFTER | `vessel_code` uniqueness is double-covered, so neither cover is tested |
| G-5-7 | MINOR | AFTER | The task subsystem and every composition function are untouched |
| G-5-8 | MINOR | AFTER | `event_admin_update` is uncovered, so append-only is asserted nowhere |
| G-5-9 | MINOR | DURING | An unclaimed authenticated principal sees every client lot, and the suite locks that in |
| G-5-10 | MINOR | AFTER | `README.md` and `CLAUDE.md` disagree on the definition of done |
| G-5-11 | NOT A DEFECT | n/a | The suite is hermetic and rolls back cleanly, including on abort |
| G-5-12 | NOT A DEFECT | n/a | Both documented `psql` invocations exit non-zero on failure |
| G-5-13 | NOT A DEFECT | n/a | Biome's `"preset": "recommended"` is valid and the linter does run |
| G-5-14 | NOT A DEFECT | n/a | Every untested composition function is correct, diamond lineage included |
| G-5-15 | NOT A DEFECT | n/a | The header graph, the em-dash rule and the import rule all currently hold |
| N-1 to N-4 | NIT | AFTER | Collapsed at the end |

Four BEFORE HARVEST findings, three of which are under an hour of work each. Everything else
waits, and most of it should.

---

## MAJOR

**G-5-1. `bun run test` is not a script; it silently executes `/usr/bin/test`.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `CLAUDE.md:88`, against `package.json:10-19`
*What is wrong:* `CLAUDE.md` names `bun run test` as one of five commands that constitute
done. There is no `test` script in any of the three `package.json` files, and no test runner
in any dependency list. Bun does not stop at a missing script: it falls through to the
`test` binary on `PATH`, which is GNU coreutils' `test`. Run with no arguments that binary
exits 1, so the command appears to fail a test suite rather than report that none exists.

```
$ bun run test
error: "/usr/bin/test" exited with code 1
note: a package.json script "test" was not found
$ echo $?
1
```

*Why it matters here:* This is the worst shape a missing check can take. A green exit would
be an obvious lie; a red exit from a program nobody wrote is a lie that looks like diligence.
With one developer and no CI, the definition of done is the entire quality process, and one
of its five items currently runs coreutils.
*Fix:* Either delete the line from `CLAUDE.md:88`, or add
`"test": "echo 'no test runner yet, see G-5 and the sorry ledger' && exit 1"` to
`package.json` so the failure states its own reason. The second is better: it keeps the slot
open and makes the gap visible. No dependency either way. `README.md:39-41` already lists
only `typecheck`, `lint` and `doctor`, so the README is the document that is currently right.
*Effort:* Two minutes.

---

**G-5-2. The suite passes with `security_invoker` stripped from `lot_state` and `vessel_state`, the one setting that keeps a client from reading every lot in the cellar.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `supabase/migrations/0003_parties_and_products.sql:178-182` and `:138`, against
`tests/schema_assertions.sql:389-408`
*What is wrong:* The migration is explicit that this setting is load-bearing: "A view runs as
its owner unless told otherwise, which would hand a client every lot in the cellar through
`lot_state` while node's own policy refused it." The RLS assertions test the policy by
counting rows on `node` directly. The application never reads `node` directly; `kernel.ts:191`
reads `vessel_state` and every screen reads through views. Removing `security_invoker` from
both views is invisible to the suite. Probed, on a build with the setting flipped:

```
--- AS SHIPPED (security_invoker=true) ---
vessel_state: name=B1 lot_name=<hidden> vol=220.00
--- MUTANT (security_invoker=false) ---
vessel_state: name=B1 lot_name=SECRET facility lot vol=220.00
lot_state rows visible to client: 1
node rows visible to client: 0
```

The base table correctly returns zero rows to the client while the view hands over the lot
name. The suite reports 28 of 28 passing in both cases.
*Why it matters here:* Two custom crush clients are real, per `CLAUDE.md:24-26`. The entire
justification for `owner_id` existing this early is that a client must not see another
client's wine. That guarantee currently rests on one view option that no check defends, in a
file that will be edited again when `lot_state` gains a column.
*Fix:* Add to `tests/schema_assertions.sql`, inside the existing client-login block at
`:389-408`, a count against `lot_state` and `vessel_state` alongside the count against `node`,
and assert that all three agree. Six lines, no migration, no dependency. A second cheap line
asserts the setting itself:
`select count(*) from pg_class where relname in ('lot_state','vessel_state') and 'security_invoker=true' = any(reloptions)` must be 2.
*Effort:* Twenty minutes.

---

**G-5-3. `enable_signup = false` blocks the stranger's-first-run acceptance test the walk is built around.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `supabase/config.toml:49` and `:52`, against `packages/cellar/src/walk.ts:43-45`
and `:126-134`
*What is wrong:* `walk.ts:43-45` states the acceptance test in the file's own header: "empty
database, fresh account, and you get from sign up to a labelled barrel with wine in it
without touching SQL." `walk.ts:126-134` renders a "Create an account" button calling
`signUp()`. The committed local config disables signup twice, at `[auth]` and at
`[auth.email]`. Against the tree as committed, the first screen of the first run fails, and
it fails at the one step the whole walk was ordered around.
*Why it matters here:* This is not a subtle defect and it would be caught in the first ten
seconds of the first manual run. That is exactly the point: nothing has run this yet. The
status ledger grades the screens "In progress, written, typechecked, built, and never run
against a Supabase instance" (`docs/status-ledger.md:54`), which is honest, and this is what
that honesty is covering.
*Why the config is not simply wrong:* The comment at `config.toml:47-48` gives a real reason,
that an open signup lets anyone insert events. Both readings are defensible, and the choice
belongs to the winemaker. What is not defensible is the tree holding both.
*Fix:* Pick one. Either set `enable_signup = true` locally and rely on
`claim_account` plus the facility-party gate to contain a stray account, or remove the
"Create an account" button and document that an admin creates accounts in Studio, which
weakens the stranger-can-fork claim in `README.md:18-19`. This is a question for the
winemaker under `CLAUDE.md:123-127`. Either way it is a one-line change.
*Effort:* Five minutes once the question is answered.

---

**G-5-4. Migrations are neither transactional nor re-runnable, so a failure partway leaves a schema that cannot be recovered by re-running.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* all five files in `supabase/migrations/`; none opens with `begin;`. Compare
`tests/schema_assertions.sql:32` and `:412`, which does wrap itself.
*What is wrong:* Probed. I injected a failing statement into `0004_terms_and_effects.sql`
immediately after `alter table vessel drop column type;` (`:221`) and applied it with psql:

```
ERROR:  division by zero
term rows: 36
vessel has type column: false
vessel has type_id column: true
event_type enum still exists: true

--- rerunning 0004 from the top ---
ERROR:  type "term_kind" already exists
```

The half-applied state persists and the file cannot be re-run over it. `0004` is the riskiest
of the five: it drops and recreates three views, two functions and four columns, and it drops
three enum types at `:249-251`.
*Bound on this claim:* I verified plain `psql`, which is what `package.json:16` uses for
`db:test` and what anyone applying a migration by hand uses. I did not verify what
`supabase db push` does against a hosted project; recent CLI versions may wrap. The fix is
harmless either way, and the guarantee should not depend on which CLI version is installed.
*Why it matters here:* `supabase db reset` drops and recreates, so locally this is always
recoverable and costs a minute. The exposure is the hosted instance during harvest, where
half-applied is the state from which there is no clean path forward and the winemaker is
unavailable for hours (`CLAUDE.md:129`).
*Fix:* Add `begin;` as the first statement and `commit;` as the last to each of the five
files. Postgres runs DDL transactionally, so all of this rolls back cleanly. Ten lines total,
no dependency. Verify by re-running the injected-failure probe above and confirming the
schema is untouched.
*Effort:* Fifteen minutes including verification.

---

## MINOR

**G-5-5. 26 of 45 mutations survive. The suite's mutation score is 42%.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `tests/schema_assertions.sql`, whole file
*What is wrong:* The prompt asks for this measurement rather than a description, so here it
is. I built a fresh database from the five migrations for each mutation, applied one
mutation, and re-ran the suite. Caught means the suite exited non-zero.

| Class | Mutations | Caught | Score |
|---|---|---|---|
| Constraints and indexes | 16 | 4 | 25% |
| Triggers and functions | 9 | 7 | 78% |
| RLS policies | 20 | 8 | 40% |
| **Total** | **45** | **19** | **42%** |

Caught: `operation_has_an_effect`; `party_one_facility`; `node.owner_id NOT NULL`;
`node_variety_is_a_variety`; both `no_self_confirm` triggers; the `confirm_event` admin gate;
`claim_account`'s first-is-admin rule and its idempotence; the `inferred` stamp in
`generate_inferred_history`; `create_vessel_with_wine`'s event count; `node_read`;
`location_admin_write`; `vessel_admin_write`; `term_admin_write`; `event_insert`; RLS
disabled on `node`; `is_facility_user`; `is_admin`.

Survived: `block_only_on_bins`; `has_an_author`; `no_self_parent`; the `lineage.fraction`
range check; `vessel_code.code UNIQUE`; `placement_one_lot_per_vessel`; `party_app_user_idx`;
`term unique(kind,value)`; three more term-kind foreign keys; `template_variety_name_key`;
`vessel_type_name_key`; the `lineage_closes_parent` trigger; `bind_vessel_code`'s cross-vessel
guard; `event_admin_update`; `node_insert`; `placement_insert`; `lineage_insert`;
`task_admin_write`; `task_own_update`; `claim_log_insert`; `vessel_code_admin_write`;
`party_admin_write`; RLS disabled on `event`; `security_invoker` on both views.

The shape of the result is legible and mostly reflects a deliberate scope. The suite was
written to cover the walk, and it covers the walk well: the trigger-and-function column scores
78%. The constraint column scores 25% because the suite exercises constraints through the
functions that sit on top of them, which catches the function and not the constraint.

The single structural cause of the policy survivors is that the suite runs as the table owner
except in two blocks (`:350-387` and `:389-408`). RLS does not apply to an owner, so nine
of the twelve policy survivors are simply never evaluated. Both `set local role` blocks are
well built; there are only two of them.

The two survivors worth acting on are `placement_one_lot_per_vessel`
(`0001_core_schema.sql:241-242`, the invariant that one vessel holds one lot; I probed it and
it holds today) and `lineage_closes_parent` (`0001_core_schema.sql:221-223`, which closes a
parent when it feeds a child, and which sorry S-3 already names as silently wrong under
partial consumption).
*Why it matters here:* Two lots recorded in one barrel is a cellar record that cannot be
reconstructed, which is the failure class `CLAUDE.md:28-30` orders the whole build around.
The invariant is correct as shipped. The gap is regression protection on the next edit, not a
live bug, which is why this is MINOR and AFTER rather than anything louder.
*Fix:* Four assertions, roughly twenty lines: insert a second open placement into an occupied
vessel and expect `unique_violation`; insert a lineage edge and assert the parent closes;
insert an event with neither `by_user` nor `by_sensor` and expect `check_violation`; insert a
lineage row with `fraction = 0` and expect `check_violation`. No dependency, no migration.
*Effort:* One hour for the four, plus a further hour if the two `set local role` blocks are
extended to cover the remaining write policies.

---

**G-5-6. `vessel_code` uniqueness is covered twice, and the two covers hide each other, so neither is tested.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `tests/schema_assertions.sql:243-250`, against
`supabase/migrations/0003_parties_and_products.sql:118` and `:217-218`
*What is wrong:* The assertion binds a code already on another vessel and expects
`unique_violation`. Two independent mechanisms produce that error: the `UNIQUE` constraint on
`vessel_code.code`, and `bind_vessel_code`'s own `raise ... using errcode = 'unique_violation'`.
I dropped each separately. Both mutants survived: with the constraint gone the function still
raises, and with the function's guard gone the constraint still raises. The assertion cannot
tell which one is doing the work, and so it defends neither.
*Why it matters here:* The comment at `0003:124-126` says what this is for: a sticker peeled
off barrel 23 and stuck on barrel 40. The application reaches the table both ways.
`kernel.ts:210` goes through the function; `vessel_code_admin_write` permits an admin to
insert directly, and the suite never takes that path.
*Fix:* One extra assertion that inserts into `vessel_code` directly rather than through
`bind_vessel_code`, expecting `unique_violation`. Five lines.
*Effort:* Ten minutes.

---

**G-5-7. The task subsystem and every composition function are untouched by the suite.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `tests/schema_assertions.sql`, by absence
*What is wrong:* Named explicitly, as the prompt asks. The suite never mentions: `task`,
`task_claim_log`, `claim_task` (`0001:335-360`), `task_board`, `block`, `node_bin_shares`,
`block_composition`, `variety_composition` (`0002:29-71`, rewritten at `0004:257-268`),
`inferred_fraction` (`0002:75-92`), `next_cap_action` (rewritten at `0004:380-417`), and
`lot_state`. It mentions `lineage` three times and never inserts an edge, so the recursive
traversal that produces TTB composition numbers has never executed anywhere in this
repository.
*Why it matters here:* Composition drives labelling and TTB reporting. It is the one
computation in the schema whose wrong answer is a compliance problem rather than an
inconvenience. It is also not on the critical path before harvest: the board is Stage 2 and
composition matters at bottling, not at intake.
*Fix:* Not before harvest. The single assertion worth adding when it is worth adding is a
three-bin blend asserting shares sum to 1.0, which is about fifteen lines.
*Effort:* One hour for the composition set. The task set can wait for the board to exist.

---

**G-5-8. `event_admin_update` is uncovered, so "nobody may rewrite history" is asserted nowhere.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:287-295`
*What is wrong:* The comment reads "Events: anyone may record, nobody may rewrite history.
Corrections are new events, not edits," and `CLAUDE.md:50-52` states append-only as a hard
rule. I replaced `event_admin_update` with a policy allowing any authenticated user to update
any event. The suite passed 28 of 28. Disabling RLS on `event` entirely also survived.
*Why it matters here:* Append-only is the property that makes the record trustworthy in a
dispute with a custom crush client about what was done to their wine. It is currently correct
and unasserted.
*Fix:* Inside the existing cellar-user block at `:350-387`, attempt an `update event set data
= ...` and expect zero rows affected. Four lines. Note that the policy as written does let an
admin update an event, which is a deliberate escape hatch rather than a defect, so the
assertion should be scoped to the cellar user.
*Effort:* Fifteen minutes.

---

**G-5-9. An authenticated principal with no `app_user` row sees every lot including client-owned ones, and the suite asserts that behaviour as correct.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `supabase/migrations/0003_parties_and_products.sql:265-276`, asserted at
`tests/schema_assertions.sql:382-384`
*What is wrong:* `is_facility_user()` coalesces a missing party lookup to `true`. Probed: a
principal in `auth.users` with no `app_user` row and no party sees all node rows, including a
client's. The comment explains the intent, which is the harvest intern who owns nothing and
needs to see everything, and the assertion at `:384` locks it in as
"a cellar user linked to no party sees the whole cellar."
*Why it matters here:* The blast radius is bounded by `config.toml:49`: signup is off, so
every principal is one an admin deliberately created. Under the current configuration this is
a design choice, not a hole. It becomes a hole the moment G-5-3 is resolved in favour of open
signup, and the suite will report 28 of 28 while it does.
*Fix:* If signup opens, narrow the coalesce default to `false` and give the intern case an
explicit facility party link. If signup stays shut, leave it and add a one-line comment at
`:384` recording that the assertion depends on `enable_signup = false`. The coupling between
the two files is the thing worth writing down.
*Effort:* Ten minutes for the comment. Half an hour if the default changes, because the
assertion at `:382-384` changes with it.

---

**G-5-10. `README.md` and `CLAUDE.md` disagree on the definition of done.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `CLAUDE.md:79-93` against `README.md:39-41`
*What is wrong:* `CLAUDE.md` names five commands. `README.md` names three, omitting
`supabase db reset` and `bun run test`. The README's list is the one that matches the tree.
Under `CLAUDE.md:10-12`, a claim outside the designated source is wrong by construction, and
the definition of done is a maturity claim living in two places.
*Why it matters here:* Small, and it is the mechanism by which G-5-1 stayed invisible: the
document a person reads says three commands, the document an agent reads says five, and the
two disagreeing is why nobody ran the fourth.
*Fix:* Make `README.md:39-41` a pointer to `CLAUDE.md`'s list rather than a second copy of a
subset, the same move `README.md:23-26` already makes for build status.
*Effort:* Five minutes.

---

## NOT A DEFECT

**G-5-11. The suite is hermetic and rolls back cleanly, including on abort.** Everything runs
inside the transaction opened at `:32` and closed at `:412`. I aborted a run mid-way by
breaking a constraint the suite covers, then queried the database: zero `app_user` rows, no
residue. The two helper functions at `:36-48` are created inside the transaction and go with
it. The one qualification is that the suite depends on terms seeded by
`0004_terms_and_effects.sql:101-173`, notably `pinot_noir`, `chardonnay` and `barrel`. That is
correct rather than a leak: those seeds are part of the schema under test.

**G-5-12. Both documented invocations report failure through the exit code.** `CLAUDE.md:84`
uses `psql < tests/schema_assertions.sql` with no `ON_ERROR_STOP` flag, which normally would
not stop. The file sets it itself at `:29`. I verified both forms against a deliberately
broken schema:

```
psql < tests/schema_assertions.sql          exit=3
psql -v ON_ERROR_STOP=1 -f ...              exit=3
```

Failure messages are legible and name the specific breach with a file and line, for example
`schema_assertions.sql:97: ERROR: FAIL: two active facility parties were allowed`. This is the
right design: the message says what the schema wrongly permitted, not which assertion number
failed.

**G-5-13. Biome's `"preset": "recommended"` is valid and the linter does run.** I predicted
this was a config error silently disabling the linter, since the documented key is
`recommended: true`. Wrong on both counts. Biome accepts `preset` and rejects a genuinely
unknown sibling key, so the config is validated. I compared `preset: "recommended"` against
`recommended: true` and `recommended: false` on the same file: the first two produce identical
diagnostics, the third produces none. A planted `==` and a formatting violation both fail
`bun run lint` with exit 1. `bun run typecheck` passes with zero errors and no suppressions;
`bun run lint` checks 20 files clean; `bun run build` produces a bundle.

**G-5-14. Every untested composition function is correct, diamond lineage included.** Two
falsified predictions, reported per the prompt's instruction. I expected the never-executed
recursive traversal in `node_bin_shares` (`0002:29-46`) to double-count on a DAG where two
paths reach the same bin, which is the blend case the scale bound calls out. It does not:
`union all` with fraction multiplication and a final `sum()` is the right shape. On a bin
feeding a free-run lot and a press cut at 0.7 / 0.3, both feeding one blend, the bin share
comes back as exactly 1.0. `block_composition` returns 60% Perlstaad / 40% Eola Springs on
the two-bin case, matching the comment at `0002:27`. `variety_composition`,
`inferred_fraction`, `next_cap_action` (which correctly advances punchdown to pumpover after
one punchdown today) and `claim_task` (which correctly refuses a second claim with
`lock_not_available`) all behave as specified. `lineage_closes_parent` closes both parents on
a two-parent blend. The gap here is regression protection, not correctness, and saying so is
what keeps G-5-5 honest.

**G-5-15. The three prose conventions all currently hold.** Checked mechanically rather than
by reading. Zero U+2014 and zero U+2013 across all 42 tracked files. No module imports a
sibling: `cellar` imports only `core`, `./`-relative files and `@zxing/library`; `core`
imports only `@supabase/supabase-js`; `apps/web` imports both modules, which is its job. The
document header graph is fully bidirectional: 16 files carry typed headers and all 16 have
zero one-directional links, which means the correction made in commit `c3eae3c` landed.

---

## The seven questions

### 1. What exists, on its merits

`tests/schema_assertions.sql` is good work and the best-built artifact in the repository. It
is hermetic, it rolls back, its failures name the breach rather than an index, and it tests
behaviour rather than restating DDL almost everywhere: it does not check that a column is
`not null`, it checks that a node cannot be created before the facility party exists. The
predicate test at `:210-218`, which edits a term's `predicate.match` and re-asserts that
`topping_check` follows, is the strongest assertion in the file, because it proves the
configurability claim rather than asserting the configuration.

Its coverage is scoped to the inventory walk, which matches what has been built. Within that
scope it is genuinely thorough: account claim, the T0-4 write path, code binding, the
one-action walk, inferred history and its provenance stamp, and RLS with three accounts.

Its measured weakness is the one the mutation table shows. Constraints are reached through
the functions layered on them, so the function is tested and the constraint underneath is
not, and RLS is evaluated in only two of roughly twenty places because the rest of the run is
as owner.

Not touched, named: `task`, `task_claim_log`, `claim_task`, `task_board`, `block`,
`node_bin_shares`, `block_composition`, `variety_composition`, `inferred_fraction`,
`next_cap_action`, `lot_state`, the `lineage_closes_parent` trigger, `placement_one_lot_per_vessel`,
`has_an_author`, `block_only_on_bins`, `no_self_parent`, the `lineage.fraction` range check,
`event_admin_update`, `node_insert`, `placement_insert`, `lineage_insert`,
`task_admin_write`, `task_own_update`, `claim_log_insert`, `vessel_code_admin_write`,
`party_admin_write`, `security_invoker` on both views, and the storage bucket policies.

### 2. What the definition of done claims

`CLAUDE.md:81-93` names five commands. Checked against the tree:

| Command | Exists | Exit | Verdict |
|---|---|---|---|
| `supabase db reset` | `package.json:14` wraps it as `db:reset` | not run | Needs the Supabase CLI, which is a prerequisite in `README.md:30-31` and is in no dependency list. Reasonable, since it is a platform tool |
| `psql < tests/schema_assertions.sql` | yes | 0 clean, 3 on failure | Passes. `package.json:16` also offers `db:test`, which needs `DATABASE_URL` and exits 2 without it |
| `bun run typecheck` | `package.json:11` | 0 | Passes, zero errors, no suppressions |
| `bun run lint` | `package.json:12` | 0 | Passes, 20 files |
| `bun run test` | **no** | 1, from coreutils | **G-5-1** |
| `bun run doctor` | `package.json:15` | 1 | Exits 1 by design, with a message naming sorry S-4. Correct and honest: the slot exists and says why it is empty |

One command of six does not exist. One is a deliberate red. The other four pass against the
tree as committed.

### 3. Testability of the client as written

Honestly: roughly 15% of the TypeScript is unit-testable without restructuring, and the
untestable 85% is untestable for a reason that is mostly correct.

Testable now, with no changes: `slug()` (`kernel.ts:122-130`, a pure string function and the
single highest-value pure function in the tree, since it generates the machine key for every
term a user adds inline); the whole of `sticky.ts` (35 lines, a pure in-memory map with five
exported functions and no DOM); and `readConfig()` (`env.ts:16-27`), which needs only
`import.meta.env` stubbed.

Testable with a DOM: `ui.ts` is 141 lines of pure `document.createElement` with no network and
no module state. `el`, `field`, `checkbox`, `banner` and `summaryRow` are all directly
assertable under happy-dom or jsdom. The `run()` wrapper at `ui.ts:57-71`, which disables a
button while a write is in flight, is worth a test: `ui.ts:55-56` names the failure it
prevents, which is a duplicate barrel from a double tap.

Not testable without restructuring, and the seams named:

- **The module-level client** (`kernel.ts:22-30`). `kernel()` memoises a singleton built from
  `readConfig()`. Every one of the roughly 20 exported functions calls it directly. There is
  no injection point, so testing any of them means intercepting the network or monkey-patching
  the module. The seam is one parameter: `kernel()` taking an optional client, or a
  `setKernel()` exported for tests. It is a six-line change and it would make the whole of
  `kernel.ts` testable against a stub.
- **`walk.ts`'s module-level `root`** (`walk.ts:51-56`). Every screen function closes over a
  module-global element set by `mountWalk`. `route()` (`:69-90`) reads four network calls in
  sequence and calls `show()` on a global. The seam is threading `root` through as a
  parameter, which touches about a dozen call sites.
- **Screens returning elements with async work fired inside** (`walk.ts:499-537`,
  `:562-669`). `vesselScreen()` returns a view synchronously and starts an IIFE that populates
  it later. A test has no handle on the promise. The seam is returning it.

**Do not restructure any of this before harvest.** The trade, stated so it is visible: three
seams, perhaps a day of work each including re-verification, and every one of them touches
`walk.ts`, which is 805 lines and is the file that has to work when the winemaker is standing
in the barrel room. The correct call is to test `slug`, `sticky` and `ui` where they sit,
leave the rest to the manual first run, and take the `kernel()` injection seam later when a
second module exists and forces the question anyway.

### 4. The minimum viable test set before harvest

Ranked by defect caught per hour. Total: about five hours.

| Rank | Test | Hours | Catches |
|---|---|---|---|
| 1 | **One manual end-to-end first run** against a local `supabase start`: sign up, claim, name the facility, add a vessel with wine, bind two codes, scan one back. | 1 | G-5-3 immediately, plus every unrun screen, every PostgREST call shape in `kernel.ts`, and the `claim_account` composite-versus-array guess at `kernel.ts:65-74`. Nothing else on this list comes close |
| 2 | **`security_invoker` and view-scoping assertions** (G-5-2) | 0.3 | A client reading another client's wine |
| 3 | **Fix `bun run test`** (G-5-1) | 0.05 | A lying checklist |
| 4 | **Wrap the five migrations in transactions** (G-5-4) | 0.25 | A half-migrated hosted database mid-harvest |
| 5 | **Four write-integrity assertions**: second placement into an occupied vessel; lineage closing its parent; `has_an_author`; `fraction` range (G-5-5) | 1 | A duplicated or lost volume record |
| 6 | **Append-only assertion for the cellar user** (G-5-8) | 0.25 | A rewritten history |
| 7 | **A `slug()` unit test table**, about a dozen cases including the accented labels the seed already contains: `Grüner Veltliner`, `Bâtonnage`, `François Frères` | 0.5 | A term key collision from two labels sluggifying the same. Needs a test runner: `bun test` is built in and adds no dependency |
| 8 | **A second manual run on an actual phone**, in the actual barrel room, with the actual camera | 1.5 | The zxing path, which has never met a camera, and every touch-target assumption in `app.css` |

Items 1 and 8 are manual and are the two highest-value items on the list. That is the honest
answer for a two-week horizon: the cheapest defect-finding instrument available here is a
person running the app once, and it has not happened yet.

Ranks 2 through 6 all extend `tests/schema_assertions.sql`, which already exists, already
runs in 65 milliseconds, and already has the helper functions. That is the whole reason they
are cheap.

### 5. What not to test

- **The screens, as automated tests.** A DOM-testing harness for `walk.ts` costs a day of
  restructuring plus a dependency, and it would assert that buttons exist. Rank 1 above finds
  more in an hour.
- **The camera path.** zxing decoding cannot be meaningfully faked, and a passing test against
  a synthetic image tells you nothing about autofocus on a cracked lens in a dark barrel room.
  `scan.ts:9-11` already puts manual entry beside the camera rather than behind it, which is
  the mitigation that matters. Test it on a phone or not at all.
- **The composition functions, before harvest.** Untested and, as G-5-14 confirms, correct.
  They matter at bottling, which is not in the next eight weeks.
- **The task subsystem.** Nothing is built. A test against an unbuilt board is a test of a
  guess.
- **`uploadVesselPhoto` and signed URLs.** They need a live Supabase storage instance, which
  means the test is an integration test against a service, and `0005:307-340` already guards
  for storage being absent.
- **Anything asserting that a column is `not null`.** The suite already avoids this. Restating
  the DDL in a second language catches nothing except somebody deliberately deleting a
  constraint, which G-5-5 shows is caught only when it changes behaviour anyway.
- **Performance, at any scale.** Fifty vessels, five users, low thousands of events. The
  assertion suite runs in 65 milliseconds against the full schema. There is no query here worth
  measuring.

### 6. CI

There is no `.github/` in the tree. What the smallest useful pipeline would be, stated
concretely:

- **Trigger:** push to `main` and pull requests.
- **Checks:** `bun install`, `bun run typecheck`, `bun run lint`, then a Postgres 16 service
  container, apply the five migrations, run `tests/schema_assertions.sql` with
  `ON_ERROR_STOP=1`.
- **Cost:** measured on this machine, the work itself is about two seconds.

```
bun install          12 ms   (warm cache)
bun run typecheck  1578 ms
bun run lint         98 ms
shim + 5 migrations 583 ms
28 assertions        65 ms
```

Add 30 to 60 seconds of runner startup, checkout and a cold `bun install`. Call it a minute
per push, free on a public repository, and the YAML is about 35 lines.

**The choice: a single local `verify` script, not CI.** Pick the script.

The reasoning, against this situation rather than in general. There is one developer, so CI's
primary function, which is stopping one person's push from breaking another person's morning,
has no one to serve. The feedback CI gives arrives 60 seconds after a push; the same script
gives it in two seconds before the commit, and two seconds is fast enough to run on every
save. The real gap here is not that checks fail unnoticed, it is that four of the five checks
in the definition of done have never been run in one sequence, and a script fixes that for
ten lines where CI fixes it for 35 plus a service container definition plus a runner secret
for `DATABASE_URL`.

Against this, CI's one genuine advantage is that it runs the migrations against a truly empty
database every time, which a developer's local instance drifts away from. That is real, and
it is cheaper to buy with `supabase db reset` inside the same script.

```sh
# package.json
"verify": "bun run typecheck && bun run lint && bun run test && bun run db:reset && bun run db:test && bun run doctor"
```

That is the definition of done as an executable rather than a description, which is the same
move `tests/schema_assertions.sql:3-5` says it exists to make for the schema. Add CI when a
second person commits, and at that point the pipeline is one line calling `verify`.

One caveat to state plainly: `verify` as written above exits 1 today, because `doctor` exits 1
by design and `test` does not exist. That is correct behaviour for a definition of done that
is not yet met, and it is why G-5-1's fix should keep the slot rather than delete it.

### 7. Fixtures

`supabase/seed/` holds only `.gitkeep`. `config.toml` names no seed path. The replay fixture is
graded Specified at `docs/status-ledger.md:80`.

**What it would have to contain** to boot the app into a plausible mid-harvest state. In the
order the schema forces, which is the order `walk.ts:47-49` already describes:

1. Three `auth.users` rows and three `app_user` rows: one admin, one cellar, one client login.
   The first must be inserted before the others for `claim_account`'s first-is-admin rule to
   produce the right shape, or inserted directly with explicit roles.
2. Three parties: the facility, and two clients matching the two real custom crush clients in
   structure though not in name.
3. Terms beyond the migration seed: two or three coopers, two woods, three location kinds.
   `0004:96-99` deliberately seeds none of these, so a fixture without them lands on the same
   empty-picker dead end the add-inline path exists to rescue.
4. Four locations, and about 20 vessels: two macrobins, four fermenters, four tanks, ten
   barrels. Not 50. Twenty is enough to make the vessel list scroll and the search matter, and
   a fixture nobody can read by eye is one nobody checks.
5. Two to four vessel codes on the barrels, some with a cooper label and some with ours, so
   the two-codes-one-barrel case at `tests/schema_assertions.sql:234-238` is visible in the UI
   rather than only in a test.
6. Six to eight bin nodes with `block_id` set, three blocks, then press lineage into ferment
   nodes and one blend, so that `block_composition` has something to return. This is the part
   that takes the time and the part that makes the fixture worth having.
7. Placements putting most lots in vessels, leaving three or four vessels empty.
8. Perhaps 150 events across the lots, spread over six weeks, mostly `observed`, a handful
   `inferred` from a template, and one or two `confirmed` so all three provenance tags render.
9. One variety template with three or four steps, which also closes sorry S-17 for
   development purposes without claiming the winemaker's real protocol.
10. A handful of open and claimed tasks, once the board exists. Not before.

**What it buys.** Two distinct things, and they are worth separating. First, development
without touching real harvest data, which matters most in the weeks when the real database is
the only record of what is in the cellar and a developer with a REPL is a hazard. Second, a
fresh clone that a stranger can explore, which is the thing `README.md:18-19` promises other
winemakers and currently cannot deliver: today a stranger clones, runs `supabase start`, and
lands on an empty first-run screen with no way to see what the app is for.

There is a third, quieter benefit: a fixture is the only practical way to hand the winemaker
something to react to during the weeks he is unavailable for design questions
(`CLAUDE.md:129-130`). A screenshot of a populated barrel room is a better question than a
paragraph.

**Effort.** Four to six hours for a hand-written `seed.sql`, most of it in step 6. Half that
if lineage and events are generated by a short `generate_series` loop rather than written out,
which is what I would do: the fixture is for exploring, not for asserting, so plausible
generated data beats hand-curated data at a quarter of the cost. Point `config.toml` at it
with a `[db.seed]` block so `supabase db reset` picks it up, which is one stanza.

This is an AFTER item. It is genuinely valuable and nothing in the cellar breaks for want of
it.

### 8. Regression protection for the ledgers' own claims

Four rules stated in prose and enforced by nothing. All four currently hold, verified in
G-5-15. The cheapest mechanical check for each:

**The module import rule** (`CLAUDE.md:71-75`). Biome enforces this natively; no script
needed. Add to `biome.json` under `linter.rules`:

```json
"correctness": {
  "noRestrictedImports": {
    "level": "error",
    "options": { "paths": { "cellar": "A module may import core, never a sibling module." } }
  }
}
```

scoped to `packages/*/src` via an `overrides` block excluding `apps/`. That last part is the
only fiddly bit, because `apps/web` legitimately imports `cellar`. If the override proves
awkward, the two-line grep below is honest and takes ten minutes:

```sh
grep -rE 'from "(cellar|core/[a-z]+/)"' packages/*/src --include=*.ts \
  | grep -v '^packages/cellar/' && { echo "module import rule violated"; exit 1; }
```

`CLAUDE.md:74-75` already says "Lint will enforce this once there is code to enforce it
against." There is now.

**The no-em-dash rule** (`CLAUDE.md:121`). One line, and it belongs in `verify`:

```sh
git ls-files -z | xargs -0 grep -nP '\x{2014}' && { echo "em dash found"; exit 1; }
```

Add `\x{2013}` if en dashes are also unwanted; the tree currently has none of either.

**The document header graph** (`CLAUDE.md:112-116`). The one that needs an actual script,
because bidirectionality is a graph property. About 30 lines of Python with no dependency:
parse `Depends on:` and `Depended on by:` out of the first 2000 bytes of every tracked file,
build both edge sets, and report any edge present in one direction and absent in the other. I
wrote and ran exactly this to produce G-5-15; it reports 16 headed files and zero
one-directional links at this commit. It runs in well under a second and is the single most
useful of these four, because the failure it catches is invisible to a reader and was in fact
introduced and then fixed in the two commits before this one.

**The rule against business logic in a client** (`CLAUDE.md:62-66`). This one has no
mechanical check, and saying so is more useful than proposing a bad one. It is a semantic
property: `next_cap_action` reimplemented in TypeScript looks exactly like any other function.
Three weak proxies exist and each is worth less than its false-positive rate: grep for
arithmetic in `packages/*/src` outside `ui.ts`; assert that `kernel.ts` contains only
pass-throughs by checking no exported function body exceeds some line count; assert that no
file outside `core` imports `@supabase/supabase-js`. The third is the only one worth having,
it is one grep, and it enforces something real though narrower than the rule:

```sh
grep -rl '@supabase/supabase-js' packages/cellar apps --include=*.ts \
  && { echo "only core may talk to the kernel directly"; exit 1; }
```

The rule itself stays enforced by review, which `CLAUDE.md:64-66` already predicts is where it
decays. The honest mitigation is not a lint rule, it is that `kernel.ts:18-20` states the
invariant at the top of the file most likely to break it.

---

## NITs

**N-1.** `package.json:16` defines `db:test` using `$DATABASE_URL` while `CLAUDE.md:84`
documents a bare `psql <` with no connection string. Both work; the tree should name one.
Prefer `db:test`, since it is the one that can go in `verify`.

**N-2.** `biome.json:2` pins the schema to `2.5.12` while `package.json:21` allows `^2.3.14`.
The resolved version happens to be 2.5.12, so nothing is wrong today, but a lockfile refresh
could resolve higher and silently desynchronise the schema from the binary. Pin the
dependency to the schema version or drop the patch specificity from the schema URL.

**N-3.** `tests/schema_assertions.sql:276-277` emits two `test_ok` lines from one function
call, and `:319` covers three distinct properties in one assertion. The 28 announced and the
28 guarded happen to reconcile, which makes the count trustworthy by coincidence rather than
by construction. One `test_ok` per `FAIL` guard keeps them in step.

**N-4.** `supabase/seed/` exists with only `.gitkeep` and no `[db.seed]` stanza in
`config.toml`, so the directory is currently decorative. Either point the config at it or
delete it until the fixture exists; an empty directory reads as a fixture that failed to load.

---

## What is fine, in one line each

The assertion suite's design (hermetic, self-rolling-back, legible failures, behaviour over
DDL) is better than most production test suites and should be the model for everything added
to it. `topping_check`'s predicate-driven rewrite at `0004:422-502` is the best piece of
design in the schema, and the assertion that proves it at `:210-218` is the best assertion in
the suite. `doctor` exiting 1 with a message naming its own sorry is the correct way to ship
an unimplemented check. The `run()` wrapper at `ui.ts:57-71` prevents a real duplicate-write
failure for fourteen lines. `tsconfig.json` is strict from the first file including
`noUncheckedIndexedAccess` and `exactOptionalPropertyTypes`, and it passes clean. The storage
guard at `0005:307-340` is the honest form of a platform dependency and is the reason these
migrations can be verified at all without Docker.

---

## Method, so the numbers are reproducible

Postgres 16.13 on Ubuntu 24.04, local cluster, trust auth. Shim as specified above. For each
mutation: drop and recreate the database, apply the shim, apply the five migrations in order,
apply exactly one mutation, run `tests/schema_assertions.sql` with `ON_ERROR_STOP=1`, record
the exit code and the count of `ok` lines. 45 mutations, one database build each. Role probes
used `set local role authenticated` / `set local role anon` with `request.jwt.claim.sub` and
the `request.jwt.claims` blob both set, inside a transaction rolled back afterwards. Every
finding above marked with a probe result was executed, not reasoned. Two predictions were
falsified and both corrections are kept: G-5-13 and G-5-14.
