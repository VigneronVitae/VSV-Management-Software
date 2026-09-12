Reviewed commit `c3eae3c7c262544e4b2e29526b513c964c6852fe`, committed 2026-09-08, on `main`; the tree was **not cloned locally** because this execution sandbox could not resolve GitHub hosts, so this best-effort review reconstructed the 42-file tree from GitHub and read every tracked file from `raw.githubusercontent.com` pinned to that exact SHA.

# R-3: declared against exercised

## Acquisition and current-tree proof

This report deliberately departs from the prompt's preferred acquisition route only because local acquisition was unavailable and the user explicitly asked for the strongest report possible with that limitation stated transparently.

| Check | Result |
|---|---|
| Local clone | **Failed.** Full and shallow HTTPS clone attempts failed with `Could not resolve host: github.com`. `gh` was unavailable, SSH was unavailable, and shell access to codeload/raw/API endpoints had the same DNS limitation. |
| Current `main` | **Confirmed remotely.** GitHub's `main` commit history currently has `c3eae3c` at the tip, dated 2026-09-08. The commit-detail URL resolves that short id to `c3eae3c7c262544e4b2e29526b513c964c6852fe`. |
| Baseline ancestry | **Satisfied at equality.** The reviewed SHA is the prompt's baseline SHA itself, so it is not an ancestor of the required baseline. |
| Branch | **Confirmed as `main` remotely.** No content was taken from `claude/sql-files-to-markdown-i31rob`. |
| LICENSE canary | **Passed.** The reconstructed tree has 42 tracked files, not a LICENSE-only tree. |
| Content canaries | **Passed.** `supabase/migrations/0005_account_and_walk.sql`, `tests/schema_assertions.sql`, `packages/cellar/src/walk.ts`, and `docs/session-reports/2026-09-08-walk.md` all exist at the pinned SHA. |
| Tracked-file count | **42**, matching the baseline count named by R-3. All 42 were successfully fetched through the pinned raw-content route. |
| Runtime execution | **Unavailable in this review.** There is no local checkout, so I did not run Bun, TypeScript, Biome, PostgreSQL, Supabase, Vite, a browser walk, a real JWT flow, or a camera. Prior session-report statements about passing commands remain historical evidence, not re-execution by this report. |

The rendered GitHub directory pages were used only to enumerate paths. Repository content used for findings came from raw URLs containing the full reviewed SHA. This preserves one-commit consistency even though it is not equivalent to a local clone.

## Finding index

| ID | Verdict | Finding |
|---|---|---|
| R-3-1 | EXPLOITABLE | `CLAUDE.md` requires `bun run test`, but the root package has no `test` script, so the definition-of-done block cannot succeed as committed. |
| R-3-2 | DIVERGENT | The scaffold report says the dependency graph was "checked by script", but no such verifier is committed in the 42-file tree. |
| R-3-3 | DIVERGENT | The compost contract says every killed approach has a revival condition, but C-4 and C-5 have none; `CLAUDE.md` also says there are five entries when there are six. |
| R-3-4 | DIVERGENT | The build-truth documents still say "Nothing is built" while the same status ledger grades three components Built and verified. |
| R-3-5 | BY DESIGN | `bun run doctor` is mandatory for done but is intentionally a stub that always exits 1; the repository names this as S-4 and as Specified, not implemented. |

## Claim / locator / supporting check / verdict

The maturity table below treats "passes today" as UNVERIFIED unless this review could execute the check. A committed runnable check is distinguished from a sentence recording that a prior session ran it.

| Claim | Locator | Supporting check | Verdict |
|---|---|---|---|
| Row-level security is **In progress**: Postgres-side policies exercised; Supabase auth wiring remains open | `docs/status-ledger.md:32`; `docs/sorry-ledger.md:47-57`; `tests/schema_assertions.sql:311-373` | **Committed runnable check:** `tests/schema_assertions.sql` switches to `authenticated` and exercises multiple accounts. The real GoTrue/JWT/PostgREST path is explicitly outside that check. | **UNVERIFIED** for current runtime and real JWT wiring. The repository accurately names the unverified boundary. |
| Schema assertions are **Built and verified**, 28 passing | `docs/status-ledger.md:33`; `tests/schema_assertions.sql:1-26`; `docs/session-reports/2026-09-08-walk.md:80-109` | **Committed runnable check:** `tests/schema_assertions.sql`; root alias `bun run db:test` is `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/schema_assertions.sql` (`package.json:16`). The walk report records a prior 28-assertion pass. | **UNVERIFIED** today because this review could not execute PostgreSQL. The check itself is committed, not merely prose. |
| Backfill path, kernel is **Built and verified** | `docs/status-ledger.md:44`; `tests/schema_assertions.sql:230-289` | **Committed runnable check:** assertions call `create_vessel_with_wine`, check vessel/lot/placement/codes, and check inferred-history behavior. | **UNVERIFIED** today because the SQL suite was not re-run. |
| Backfill path, screens is **In progress** | `docs/status-ledger.md:45`; `packages/cellar/src/walk.ts:42-48,515-633`; `docs/session-reports/2026-09-08-walk.md:111-135` | Artifact is committed. Typecheck/build commands are committed; the report says they passed previously. The repository itself says the screen has never run against Supabase. | **UNVERIFIED**, correctly so: its named acceptance test is a stranger's first live run. |
| Sign up and account claim is **In progress** | `docs/status-ledger.md:46`; `packages/cellar/src/walk.ts:88-161`; `packages/core/src/kernel.ts:37-68`; `docs/session-reports/2026-09-08-walk.md:126-133` | `claim_account` has SQL coverage; sign-up/claim UI exists. No committed end-to-end GoTrue/PostgREST check exercises the wire path. | **UNVERIFIED** for the live auth/wire path. |
| First run, facility party is **In progress** and explains the wall | `docs/status-ledger.md:47`; `packages/cellar/src/walk.ts:163-216` | Static artifact exists and the explanatory copy is visible in code. Its acceptance criterion is usability on an actual first run, which the walk report says did not occur. | **UNVERIFIED** as an exercised function; the static wording claim is supported. |
| Code binding by camera is **In progress**: zxing plus manual entry | `docs/status-ledger.md:48`; `packages/cellar/src/scan.ts:1-9,63-115`; `packages/cellar/package.json:1-11` | Camera path uses `BrowserMultiFormatReader`; manual entry is adjacent and remains available on camera failure. No committed camera/hardware check exists, and the session report says no camera was exercised. | **UNVERIFIED** on a real camera. |
| Inferred history generation is **Built and verified** | `docs/status-ledger.md:49`; `tests/schema_assertions.sql:263-307`; `packages/cellar/src/walk.ts:638-703` | **Committed runnable check:** SQL creates a template, expects two generated events, and checks `inferred` provenance. | **UNVERIFIED** today because the SQL suite was not re-run. |
| Definition of done: `supabase db reset` | `CLAUDE.md:69-84`; `package.json:14` | Root alias `db:reset` maps directly to `supabase db reset`. Both session reports say the actual Supabase reset was not run in their isolated environments. | **UNVERIFIED** today. The command is real; no current successful run was available. |
| Definition of done: `psql < tests/schema_assertions.sql` | `CLAUDE.md:74-76`; `tests/schema_assertions.sql:16-26`; `package.json:16` | File exists; it sets `ON_ERROR_STOP` internally. The stronger committed alias supplies `$DATABASE_URL` and `-v ON_ERROR_STOP=1`. | **UNVERIFIED** today; historical session report says the suite passed on scratch PostgreSQL 16. |
| Definition of done: `bun run typecheck` | `CLAUDE.md:78-81`; `package.json:10-11`; `tsconfig.json:4-37` | Script exists and runs `tsc --noEmit -p tsconfig.json`; tsconfig includes package and app TypeScript sources. | **UNVERIFIED** today; prior session report says it passed. |
| Definition of done: `bun run lint` | `CLAUDE.md:78-81`; `package.json:11-12`; `biome.json:7-21` | Script exists and runs `biome check .`; Biome linter is enabled with recommended rules. | **UNVERIFIED** today; prior session report says it passed. |
| Definition of done: `bun run test` | `CLAUDE.md:78-81`; `package.json:10-18` | **No supporting script.** Root scripts include typecheck, lint, format, db:reset, doctor, db:test, dev, build, but no `test`. | **EXPLOITABLE**. Running the required command cannot satisfy the block as committed. See R-3-1. |
| Definition of done: `bun run doctor` | `CLAUDE.md:82-88`; `package.json:14-16`; `docs/sorry-ledger.md:34-37`; `README.md:35-37` | Script exists but only prints that doctor is not implemented and exits 1. S-4 and README explicitly name that state. | **BY DESIGN**, but it means the complete done block cannot pass today. See R-3-5. |
| Scaffold report: dependency graph was verified "by script" | `docs/session-reports/2026-09-08-scaffold.md:76-94` | No graph-verifier script exists in the 42 tracked paths. The current graph can be reconstructed and is sound, but that is not the same as committing the claimed verifier. | **DIVERGENT**. See R-3-2. |
| Walk report: schema assertions verified by a script | `docs/session-reports/2026-09-08-walk.md:60-63,80-109` | `tests/schema_assertions.sql` is committed and root `db:test` invokes it. | **NOT A DEFECT** as a script-presence claim; pass result remains historical for this review. |
| Walk/scaffold reports: typecheck and lint were run | `docs/session-reports/2026-09-08-scaffold.md:88-89`; `docs/session-reports/2026-09-08-walk.md:111-112` | Root `typecheck` and `lint` scripts are committed. | **NOT A DEFECT** as a script-presence claim; current pass result is UNVERIFIED here. |
| Typed-header graph has reciprocal edges | Header blocks in `CLAUDE.md:1-5`, `README.md:1-5`, `packages/cellar/docs/spec.md:1-5`, five ledger/report documents at `:1-5`, both session reports at `:1-5`, migrations `0001`-`0005` at `:1-16`, and `tests/schema_assertions.sql:1-15` | Static reconstruction yields 16 headered files and 49 forward `Depends on` edges, each mirrored by the target's `Depended on by`. No edge points to a nonexistent path. | **NOT A DEFECT** at the reviewed SHA. |
| Every headered file is pointed at by another headered file | `README.md:1-5` plus the same header inventory above | `README.md` is the sole graph root: no file depends on it, and its own header explicitly says `Depended on by: []`. It is also the repository entry document. | **NOT A DEFECT**. Reported because R-3 asks for every headered file with no inbound dependency. |
| Deferred status rows name compost entries | `docs/status-ledger.md:23-26,36,94-96`; `docs/compost-ledger.md:46-58` | The only table row graded Deferred, term configuration screens, points to C-6; C-6 exists and has a reactivation condition. The separate "Deferred on purpose" BLE note points to C-1, which also exists and has a condition. | **NOT A DEFECT**. |
| Compost entries all carry reactivation conditions | `CLAUDE.md:47-49`; `docs/compost-ledger.md:8-9,38-65`; `docs/methodology-lineage.md:97-109` | C-1, C-2, C-3, and C-6 have `Reactivate if`; C-4 and C-5 end without one. The ledger contains six entries, while CLAUDE says five. | **DIVERGENT**. See R-3-3. |
| Status ledger is internally consistent about whether anything is built | `docs/status-ledger.md:10-16,23-25,33,44,49`; `docs/sorry-ledger.md:136-138` | The status introduction says "Nothing is built" but later rows grade three components Built and verified. Sorry ledger's Discharged section repeats "Nothing has been built." | **DIVERGENT**. See R-3-4. |
| Sorry/compost references resolve globally | Definitions: `docs/sorry-ledger.md:15-138`; `docs/compost-ledger.md:10-65`; representative references throughout CLAUDE, status, methodology, migrations, tests, and walk code | Every reference examined in the maturity, migration-header, session-report, code-comment, and ledger passes resolves to S-1 through S-17 or C-1 through C-6. A true repository-wide ID extraction with `rg` was not possible without a checkout, so I do not claim an equivalent machine-generated reverse-orphan set. | **UNVERIFIED exhaustively**. No missing ID was found in the reviewed references. |
| No em dashes in tracked files | `CLAUDE.md:108-109` declares the rule; scope is all 42 tracked paths at the pinned SHA | All 42 pinned raw files were individually searched for the U+2014 em-dash character; zero matches. | **NOT A DEFECT**. |
| No em dashes in commit messages | `CLAUDE.md:108-109`; current `main` history from `1a5c71d` through `c3eae3c` | All 16 commit-detail pages reachable from the current all-time `main` history were individually searched for U+2014; zero matches in the exposed subject/body text. | **NOT A DEFECT**. |

## EXPLOITABLE

**R-3-1. The definition of done requires a package script that does not exist.**  
*Verdict:* EXPLOITABLE  
*Locator:* `CLAUDE.md:69-84`; `package.json:10-18`  
*What is wrong:* `CLAUDE.md` makes `bun run test` part of the exact command block that defines done. The root `package.json` has no `test` script, so the declared gate and the executable project interface disagree.  
*How it surfaces:* Run `bun run test` from the repository root. Bun cannot run a script that is not defined, so the done block stops there regardless of code correctness.  
*Resolves when:* The committed definition-of-done block and the committed package scripts describe the same runnable test command.  
*Load-bearing:* yes, because the repository explicitly uses executable done criteria to prevent compilation-only completion.

## DIVERGENT

**R-3-2. The dependency graph's claimed script verifier is not a repository artifact.**  
*Verdict:* DIVERGENT  
*Locator:* `docs/session-reports/2026-09-08-scaffold.md:76-94`; current tracked-path inventory; typed headers listed in the claim table above  
*What is wrong:* The scaffold report says the typed-header graph was "checked by script rather than by reading." No graph-checking script is present in the 42-file reviewed tree. The graph is currently sound by independent static reconstruction, but the check that supposedly established the property is session machinery rather than a committed repository property.  
*How it surfaces:* Silently, never, until a future edit changes only one side of a dependency edge. There is no committed checker to fail.  
*Resolves when:* A repository-committed runnable check enforces header reciprocity and missing targets, or the session report no longer presents the uncommitted script as repository-level evidence.  
*Load-bearing:* yes, because `CLAUDE.md:100-103` and `docs/methodology-lineage.md:35-48` call bidirectional edges the load-bearing part of the header system.

**R-3-3. The compost ledger violates its own revival-condition contract, and CLAUDE misstates its size.**  
*Verdict:* DIVERGENT  
*Locator:* `CLAUDE.md:47-49`; `docs/compost-ledger.md:8-9,38-65`; `docs/methodology-lineage.md:97-109`  
*What is wrong:* `CLAUDE.md` says there are five compost entries and that each has a reactivation condition. The ledger actually contains C-1 through C-6, and C-4 and C-5 have no `Reactivate if` condition. The methodology says the revival condition is what distinguishes a recorded kill from prejudice.  
*How it surfaces:* Silently when someone revisits template versioning or pick-as-intake-unit. Those two kills have no repository-defined condition that would make reconsideration legitimate.  
*Resolves when:* The count in the contract matches the ledger and every compost entry either carries a concrete revival condition or is explicitly exempted by a changed compost rule.  
*Load-bearing:* yes, because the repository names the reactivation condition as the mechanism preventing dead ideas from becoming permanent unsupported prohibitions.

**R-3-4. The authoritative build ledger contradicts itself about whether anything is built.**  
*Verdict:* DIVERGENT  
*Locator:* `docs/status-ledger.md:10-16,23-25,33,44,49`; `docs/sorry-ledger.md:136-138`  
*What is wrong:* The status ledger opens with "Nothing is built" but later, under its own grade definition, marks Schema assertions, Backfill path kernel, and Inferred history generation as Built and verified. The sorry ledger also ends with "None. Nothing has been built." These are current-record statements, not the intentionally historical session reports.  
*How it surfaces:* Immediately to a new reader following the mandated read order: the same authoritative apparatus gives incompatible maturity summaries.  
*Resolves when:* Current build-state prose agrees with the grades in the status ledger, and cross-ledger prose no longer asserts the obsolete all-unbuilt state.  
*Load-bearing:* yes, because `CLAUDE.md:8-10` and `docs/methodology-lineage.md:63-81` make the status ledger the single source of build truth.

## BY DESIGN

**R-3-5. `doctor` makes the definition of done impossible today, deliberately.**  
*Verdict:* BY DESIGN  
*Locator:* `CLAUDE.md:82-88`; `package.json:14-16`; `docs/status-ledger.md:64-68`; `docs/sorry-ledger.md:34-37`; `README.md:35-37`  
*What is wrong:* In isolation, a mandatory done command that always exits 1 would be a broken gate. Here the tree explicitly records that `doctor` is not implemented, that S-4 remains open, and that the nonzero exit is intentional.  
*How it surfaces:* Every `bun run doctor` invocation prints the S-4 explanation and exits nonzero, so no data-path change can satisfy the full done block yet.  
*Resolves when:* `doctor` actually checks orphaned polymorphic `event.subject_id` records and the mandatory command can report a clean result against the intended fixtures/data.  
*Load-bearing:* yes, because the schema cannot express the polymorphic subject foreign key and the repository names `doctor` as the compensating integrity check.

## Static checks that held

The current typed-header graph is internally reciprocal: 16 headered files, 49 `Depends on` edges, 49 matching reverse declarations, no dangling paths. `README.md` is the only headered root with no incoming dependency, and its `Depended on by: []` declaration matches that role.

The style rule also holds at the pinned state. Every one of the 42 tracked raw files was searched for U+2014 and produced zero matches. The 16 commit-detail pages in current `main` history were also searched and produced zero matches in the subject/body text exposed by GitHub.

The Deferred grade rule holds for the status table: term configuration screens point to C-6, and C-6 has a reactivation condition. The separate direct-BLE deferred note points to C-1, which also has one.

## What this report could not earn

This review did not execute the database or client. Therefore it does **not** independently certify that the 28 schema assertions pass today, that the TypeScript or Biome commands pass today, that Vite builds today, or that a Supabase reset succeeds. The repository contains committed commands/checks for those items, and the September 8 walk report records prior successful runs for the SQL assertions, typecheck, lint, and Vite build, but those are session claims rather than executions performed here.

The repository itself also correctly leaves several physical/network boundaries unverified: real GoTrue JWT issuance and PostgREST role mapping, the sign-up/account-claim flow over the wire, the stranger's first-run facility walk, photo storage, `create_vessel_with_wine` over PostgREST, and camera scanning. Those should remain UNVERIFIED until exercised on the actual path; I did not promote static code presence into a runtime verdict.

The only audit item I could not make as mechanically exhaustive as the em-dash/header passes is the repository-wide reverse-orphan scan for every S-/C- identifier. All maturity, ledger, session, migration-header, test, and relevant code references examined resolve to existing S-1..S-17 or C-1..C-6 entries, and every Deferred status reference resolves. Without a local checkout I cannot honestly claim that this was equivalent to a single `rg`-based extraction over the entire tree, so that sub-check remains exhaustively UNVERIFIED rather than guessed.

## Bottom line

The reviewed `main` tree is the required baseline, not the stale LICENSE-only state. Its dependency graph and em-dash convention currently hold, and its three Built-and-verified maturity claims each have a committed SQL check rather than only session prose. The most concrete executable defect is simpler: the definition of done names `bun run test`, which the repository cannot run because no such script exists.

The more structural drift is documentary enforcement. The graph was once "checked by script" but the checker was not committed; the compost system no longer satisfies its own revival-condition rule; and the authoritative build records still carry obsolete "nothing is built" statements alongside Built-and-verified grades. `doctor` is also a mandatory failing gate, but that one is explicitly named and therefore BY DESIGN rather than hidden drift.

Because the repository could not be cloned in this sandbox, runtime pass/fail claims remain UNVERIFIED unless they follow directly from committed script definitions. No finding in this report treats a prior session report as a substitute for re-execution.
