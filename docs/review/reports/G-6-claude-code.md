# G-6: maintainability and handover to a stranger

## Report header

**Tier: A.** Full tree on disk. Route 1 (`git clone https://github.com/VigneronVitae/VSV-Management-Software`) worked on the first attempt through the Bash tool surface, in 0.9 seconds. No fallback route was needed. Citations are `path:line` against the pinned SHA below.

**Commit.** `git rev-parse HEAD` returns:

```
c3eae3c7c262544e4b2e29526b513c964c6852fe
```

This is the baseline exactly, not a descendant and not an ancestor. Branch `main`. Everything below was read at this SHA.

**Canaries.** All four present: `supabase/migrations/0005_account_and_walk.sql`, `tests/schema_assertions.sql`, `packages/cellar/src/walk.ts`, `docs/session-reports/2026-09-08-walk.md`. `git ls-files | wc -l` returns 42. Correct tree.

**Execution numbers.**

| Question | Answer |
|---|---|
| Did all five migrations apply clean? | Yes. Exit 0 on all five, from empty, on stock Postgres 16.13 |
| Assertions run / passed | 28 run, 28 passed. Zero `ERROR` or `FATAL` lines; the file reached its own `--- all assertions passed` notice and rolled back |
| Storage-guarded block | **Skipped.** No `storage` schema in the shim, and `0005` said so: `NOTICE: storage schema absent, skipping the vessel-photos bucket` |

My shim was built to the prompt's spec: Postgres 16, an `auth` schema with a `users` table, `auth.uid()` reading `request.jwt.claim.sub` with a fallback to the `request.jwt.claims` blob, roles `anon` / `authenticated` / `service_role` with Supabase's default grants on `public`, an empty `supabase_realtime` publication, and no `storage` schema. The 28-assertion count matches what `docs/status-ledger.md:40` claims, so on this commit the two shim variants the earlier reports disagreed about do not change the number.

**File table.** Every tracked file was read whole from disk. All 42:

| Path | State | Lines |
|---|---|---|
| `README.md` | whole | 59 |
| `CLAUDE.md` | whole | 130 |
| `LICENSE` | whole | 201 |
| `.gitignore` | whole | 47 |
| `package.json` | whole | 24 |
| `tsconfig.json` | whole | 40 |
| `biome.json` | whole | 30 |
| `bun.lock` | whole | (lockfile, scanned not read) |
| `packages/cellar/docs/spec.md` | whole | 328 |
| `docs/status-ledger.md` | whole | 112 |
| `docs/sorry-ledger.md` | whole | 156 |
| `docs/compost-ledger.md` | whole | 72 |
| `docs/methodology-lineage.md` | whole | 334 |
| `docs/session-reports/index.md` | whole | 33 |
| `docs/session-reports/2026-09-08-scaffold.md` | whole | 153 |
| `docs/session-reports/2026-09-08-walk.md` | whole | 202 |
| `apps/web/index.html` | whole | 14 |
| `apps/web/vite.config.ts` | whole | 8 |
| `apps/web/package.json` | whole | 19 |
| `apps/web/.env.example` | whole | 4 |
| `apps/web/src/index.ts` | whole | 27 |
| `apps/web/src/app.css` | whole | 330 |
| `packages/core/package.json` | whole | 9 |
| `packages/core/src/index.ts` | whole | 6 |
| `packages/core/src/env.ts` | whole | 27 |
| `packages/core/src/kernel.ts` | whole | 297 |
| `packages/core/src/types.ts` | whole | 125 |
| `packages/cellar/package.json` | whole | 11 |
| `packages/cellar/src/index.ts` | whole | 3 |
| `packages/cellar/src/ui.ts` | whole | 141 |
| `packages/cellar/src/sticky.ts` | whole | 35 |
| `packages/cellar/src/pickers.ts` | whole | 201 |
| `packages/cellar/src/scan.ts` | whole | 125 |
| `packages/cellar/src/walk.ts` | whole | 805 |
| `supabase/config.toml` | whole | 56 |
| `supabase/migrations/0001_core_schema.sql` | whole | 370 |
| `supabase/migrations/0002_derived_and_rls.sql` | whole | 334 |
| `supabase/migrations/0003_parties_and_products.sql` | whole | 284 |
| `supabase/migrations/0004_terms_and_effects.sql` | whole | 519 |
| `supabase/migrations/0005_account_and_walk.sql` | whole | 340 |
| `tests/schema_assertions.sql` | whole | 412 |
| `supabase/seed/.gitkeep` | whole | 0 |

No file was partial and none failed.

**What was probed and what was not.** Findings marked *(probed)* were executed: the migrations and assertions against a real Postgres 16, the setup path in a clean container, the client build, and the browser-rendered screens under headless Chromium 1194 with the accessibility tree read from the browser rather than inferred from source. One thing I could not execute: `supabase start` never reached the point of running containers, because this sandbox's egress policy returns 403 on Docker registry blob fetches (`production.cloudfront.docker.com`, confirmed in the proxy's own failure log). That is an environment limit, not a repository defect, and I have been careful to separate the two below.

**Two predictions of mine that the probes falsified.** I expected `supabase start` to fail because no Docker daemon was running. It does not get that far: it fails during config validation, before touching Docker, and it still fails after I started a daemon (finding G-6-1). Separately, my first accessibility script flagged all seven `<button>` elements as having no accessible name. That was my script's bug, not the repository's: buttons take their name from their own text content, and the browser's accessibility tree confirms every one of them is correctly named. The selects, which the same tree reports as `name=""`, are the real defect.

---

## Findings

| ID | Severity | Triage | Issue |
|---|---|---|---|
| G-6-1 | BLOCKER | BEFORE HARVEST | `config.toml` pins the one Postgres version the current Supabase CLI refuses |
| G-6-2 | MAJOR | BEFORE HARVEST | Every add-inline form is permanently open; CSS defeats the `hidden` attribute |
| G-6-3 | MAJOR | BEFORE HARVEST | "Running locally" never creates `.env.local` and never starts the client |
| G-6-4 | MAJOR | DURING | `0001_core_schema.sql` describes a schema that no longer exists, and nothing describes the one that does |
| G-6-5 | MAJOR | DURING | A failed load leaves a dead-end screen with no error and no way back |
| G-6-6 | MINOR | BEFORE HARVEST | The status ledger says nothing is built while grading four things built |
| G-6-7 | MINOR | BEFORE HARVEST | `bun run test` is in the definition of done and the script does not exist |
| G-6-8 | MINOR | DURING | Every `<select>` reaches the accessibility tree with no name |
| G-6-9 | MINOR | DURING | `--ink-faint` fails 4.5:1 in both themes |
| G-6-10 | MINOR | DURING | zxing is eagerly bundled: 636 kB where 247 kB would do |
| G-6-11 | MINOR | AFTER | Six Willamette varieties are seeded and the UI cannot remove them |
| G-6-12 | MINOR | AFTER | `block.variety` is free text while every other variety is a term |
| G-6-13 | MINOR | AFTER | This winery's name is compiled into the client |
| G-6-14 | MINOR | AFTER | "Static PWA client" is claimed four times and no PWA exists |
| G-6-15 | MINOR | AFTER | The README sends a human stranger to the agent contract first |
| G-6-16 | MINOR | AFTER | `DATABASE_URL` is required by `db:test` and documented nowhere |
| G-6-17 | NIT | AFTER | Grouped nits, seven of them |
| G-6-18 | NOT A DEFECT | n/a | Things I expected to be wrong and that hold |

Eleven of eighteen are MINOR or below, and only three are BEFORE HARVEST plus one blocker. That is the honest shape: this repository's problems are handover problems, not cellar-floor problems.

---

## The fresh clone, executed

I ran the documented path literally in a clean container and timed it. The README's prerequisites are Bun and the Supabase CLI (`README.md:30-31`), followed by three commands (`README.md:33-37`).

| Step | Result | Time |
|---|---|---|
| `git clone` | clean | 0.9s |
| `bun install` | clean, 62 packages | 1.6s |
| `supabase start` | **fails**, see G-6-1 | 0.8s to failure |
| `bun run db:reset` | fails, exit 127, `supabase: command not found` | immediate |
| `bun run typecheck` | clean, zero errors | 1.6s |
| `bun run lint` | clean, 20 files checked | 0.1s |
| `bun run build` | clean, builds with no `.env.local` at all | 2.8s |
| `bun run test` | no such script, see G-6-7 | immediate |
| `bun run doctor` | exits 1 by design, and the README says so | immediate |

Two separate things are true here and they should not be blurred together. Everything that does not need Supabase works from a cold clone in under seven seconds total, with no configuration, no warnings, and no missing steps. That half is genuinely good and I say so in G-6-18. Everything that needs Supabase is unreachable at this commit with a current CLI, and the first wall is not the one anybody expected.

Spec section 6 adopts tmulab/tacet's bar of "fresh clone to running in five minutes" and calls it the right bar (`packages/cellar/docs/spec.md:225-228`). Against that bar, the Bun half finishes in seven seconds and the Supabase half does not finish at all.

---

## BLOCKER

**G-6-1. `config.toml` pins the one Postgres major version the current Supabase CLI refuses, so the documented setup cannot start.**
*Severity:* BLOCKER
*Triage:* BEFORE HARVEST
*Locator:* `supabase/config.toml:22`
*What is wrong:* `major_version = 16`. Supabase CLI 2.117.0, installed fresh today, rejects it during config validation and exits 1:

```
{"_tag":"Error","error":{"code":"LegacyStartInvalidConfigError",
 "message":"Failed reading config: Invalid db.major_version: 16."}}
```

I confirmed this is not a Docker problem. It fails identically with no Docker daemon and with a daemon running and healthy, and it fails before any container work begins. I then tested the neighbouring values: `15` and `17` both pass validation and proceed to pull images; `16` alone is refused. So the single Postgres major version this project has actually verified its migrations against is the one its tooling will not run. The comment directly above the line (`config.toml:17-21`) explains at length that 16 was chosen because session 1 pinned 15 and verified on 16, "so the pin was a claim rather than a fact." The reasoning is right and the value has since been overtaken by the CLI.

There is a second, quieter part: no CLI version is pinned anywhere in the repository. `README.md:31` links to the Supabase CLI docs, which install whatever is current. A stranger following the README gets 2.117.0 and this wall.

*Why it matters here:* This is the first command in the only setup path the repository documents, and it is the command that creates the database. A second winemaker's developer gets 40 lines of successful `bun install` output and then a JSON error naming a config key, with nothing in the repository to tell them 16 was deliberate or what to change it to. They cannot reach the schema, the assertions, or the walk. For the stranger this prompt is written about, the repository does not run. It is not a cellar-floor blocker for this winery, whose instance presumably already exists, which is why I note the reading rather than leaving the grade to speak for itself.

*Fix:* Change `supabase/config.toml:22` to `major_version = 17` and re-run the assertions against 17 before trusting it, since the existing verification is against 16 and 17 is a different major. Then pin the CLI: add a `supabase` devDependency at a known-good version and change `README.md:30-31` to say `bun install` provides it, which also removes the global-install step. That is a new dependency and the standing rule in `CLAUDE.md:43` applies, so it needs consultation first. Without a new dependency: state the tested CLI version range in the README next to the link, and add a one-line comment at `config.toml:22` naming the CLI versions that accept the value. No migration needed either way.
*Effort:* Minutes for the value and the comment. An hour to re-verify the five migrations and 28 assertions against Postgres 17 and record the result.

---

## MAJOR

**G-6-2. Every add-inline form is permanently open, because CSS overrides the `hidden` attribute the TypeScript sets.** *(probed)*
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `apps/web/src/app.css:206-213`, against `packages/cellar/src/pickers.ts:64`, `:86`, `:125`, `:166`
*What is wrong:* `pickers.ts` creates each add-inline form with `hidden: "hidden"` and toggles it with `addForm.hidden = ...`. That is correct. But `.add-inline` sets `display: flex` (`app.css:208`), and an author rule beats the user-agent `[hidden] { display: none }`, so the attribute has no visual effect. Every picker's add form is open at all times and the "Add one" button does nothing visible.

I rendered the real `termPicker` and `locationPicker` modules in headless Chromium, replicating the picker set that `vesselWineScreen` builds (`walk.ts:562-614`). The browser reports:

```
addFormsInDom:           7
addFormsWithHiddenSet:   7     <- the TypeScript is doing its job
addFormsActuallyVisible: 7     <- the CSS is undoing it
pixelsOfOpenForms:    1656
totalPageHeight:      2737
```

So 61% of the primary capture screen is forms that are supposed to be closed, and the page is 3.2 phone screens tall where it should be 1.5. The forms are also in the tab order: tabbing from the Type select goes select, "Add one", "New type" input, "Save and select", and only then reaches the next real field. The rendered screen shows seven identical maroon "Save and select" primary buttons interleaved between the seven real fields, above the one button that actually saves the vessel.

*Why it matters here:* This is the screen from build order item 1, the one whose acceptance test is a stranger's first run, used on a phone by cold hands in a barrel room where the stated rule is one action per view. Instead of seven fields the user gets fourteen, half of them decoys, with seven primary-styled buttons that each save a vocabulary term rather than the vessel. At fifty vessels this is fifty walks through 1,200 extra pixels of scrolling, and the realistic failure is someone pressing a "Save and select" that creates a stray term instead of the barrel. The design intent in the comment at `pickers.ts:16-18` is exactly right and the stylesheet silently discards it.

*Fix:* Three lines in `app.css`:

```css
.add-inline[hidden] {
  display: none;
}
```

I applied this and re-measured: visible add forms drop from 7 to 0, page height from 2737px to 1226px, 3.2 phone screens to 1.5. The deliberate `toggle(true)` on an empty list (`pickers.ts:104`, `:187`) still works, so a fresh install still opens the form when a picker has nothing in it, which is the case that comment was written to protect. No dependency, no migration.
*Effort:* Minutes.

**G-6-3. "Running locally" never creates `.env.local` and never starts the client, so following it exactly cannot produce a running app.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `README.md:28-41`
*What is wrong:* The section gives `bun install`, `supabase start`, `bun run db:reset`, then describes `typecheck`, `lint` and `doctor`. Two things are missing and they are the two that matter. First, nothing tells the reader to copy `apps/web/.env.example` to `apps/web/.env.local` and fill in the anon key. `.env.example:1-2` explains how to do it and the README never points at the file. Second, the section never mentions `bun run dev`, never mentions `http://localhost:5173`, and never says the client exists as something you can open. `dev` and `build` are defined at `package.json:17-18` and appear nowhere in the README.

A reader who follows the README literally, and who gets past G-6-1, ends with a migrated database and no running client, with no instruction left unexecuted. The failure is silent: there is nothing to tell them they stopped early.

Worse, the app builds clean with no environment at all. I ran `bun run build` on a fresh clone with no `.env.local` and it succeeded in 2.8s. The missing-config check at `packages/core/src/env.ts:20-25` is a runtime check, so a misconfigured deploy builds, ships, and shows a banner to whoever opens it rather than failing at build time.

*Why it matters here:* The whole premise of the handover is that a developer at another winery gets this running alone. This section is the only instruction set in the repository and it stops one step short of the thing it promises. The `.env.local` step in particular is invisible: the reader has no reason to look in `apps/web/` for a file the README never names.

*Fix:* Four lines in `README.md:33-37`:

```sh
bun install
cp apps/web/.env.example apps/web/.env.local   # fill VITE_SUPABASE_ANON_KEY from `supabase status`
supabase start
bun run db:reset
bun run dev                                    # http://localhost:5173
```

Separately, the runtime-only config check is defensible for a client bundle and I would leave it, but the README should say that a build with no `.env.local` succeeds and fails at load, so nobody reads a green build as a working deploy. No dependency, no migration.
*Effort:* Minutes.

**G-6-4. `0001_core_schema.sql` describes a schema that no longer exists, and nothing in the repository describes the one that does.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `supabase/migrations/0001_core_schema.sql:250-268`, against `supabase/migrations/0004_terms_and_effects.sql:224-251`
*What is wrong:* A stranger wanting to know the shape of the database opens the file called `0001_core_schema.sql`. What it tells them is substantially false. Migration 0004 drops `node.variety`, `node.product_type`, `vessel.type`, `event.type`, `task.type` and `template_step.type`, and drops the `product_type`, `vessel_type` and `event_type` enum types outright (`0004:209-210`, `:221`, `:230`, `:239`, `:247`, `:249-251`). 0003 drops `vessel.qr_code` (`0003:132`) and 0005 drops `template.variety` (`0005:94`). I confirmed against the live database: `select count(*) from pg_type where typname='event_type'` returns 0.

So `0001:253` declares `type event_type not null` on a table whose current definition has no `type` column at all and where the replacement is `operation_id uuid not null` with a composite foreign key into `term`. Reading 0001 and believing it is the natural thing to do and produces a wrong mental model of the central table.

Views are worse. `vessel_state` is defined three times (`0002:100`, `0003:137`, `0004:270`) with two intervening drops, and `lot_state`, `task_board`, `next_cap_action`, `topping_check`, `variety_composition` and `resolve_vessel_code` are each defined twice. `vessel_state` is what the vessel list, the scan result and the result screen all read, and what `packages/core/src/types.ts:61-81` mirrors. To learn its current columns a stranger must find the last of three definitions across two files and know that later wins. There is no `docs/schema.md`, no generated reference, and no `\d`-style dump anywhere in the tree.

*Why it matters here:* Migrations are an append-only changelog and this repository correctly refuses to edit them (`CLAUDE.md:67-70`, and that rule is right). But a changelog is not a reference, and this tree has only the changelog. The second winemaker's developer, asked to add a field to an event, starts at the file named core schema and builds their change on a table shape that was dismantled two migrations later. At 2,259 lines of SQL across five files with 21% to 32% comment density, the reasoning is all preserved and the current state is not derivable without executing it.

*Fix:* Generate a schema reference and commit it, regenerated whenever a migration lands. `pg_dump --schema-only --no-owner --no-privileges` against a freshly reset local database gives it with no new dependency, since `psql` and `pg_dump` already ship with the Supabase CLI's toolchain. Add it as `docs/schema.sql` plus a `db:schema` script beside `db:test` at `package.json:16`, and point `README.md:45-53` at it. Add one line at the top of `0001_core_schema.sql` saying that later migrations alter it and naming the reference as the current truth. No migration needed; this is additive.
*Effort:* An hour, most of it deciding the regeneration convention and writing it down.

**G-6-5. A failed load inside either vessel screen leaves a dead-end: no fields, no error, and no way back.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `packages/cellar/src/walk.ts:499-537` and `packages/cellar/src/walk.ts:562-669`
*What is wrong:* Both vessel screens return a shell synchronously and populate it from a floating async IIFE:

```ts
const view = screen("Add an empty vessel", lede(...), holder);
void (async () => {
  const partyRows = await parties();     // walk.ts:500
  ...
  holder.append(...form.nodes, capture.root, button("Save vessel", ...),
                button("Back", ...), message);
})();
return view;
```

There is no `try`/`catch`. If `parties()` rejects, or any of the four `reload()` calls inside `form.reload()` rejects (`walk.ts:476-483`), the IIFE's promise rejects unhandled and nothing is ever appended. The user is left looking at a heading and a lede over an empty div. Critically, the "Back" button and the `message` element that would show the error are both appended inside the same block, so the error surface and the escape hatch are lost by the same failure that needs them. The only recovery is a browser reload.

This is reasoned from the source rather than probed: reproducing it needs a Supabase instance that accepts the connection and then fails the query, which I could not stand up here. The mechanism is unambiguous in the code, and the probe I would run is to point `VITE_SUPABASE_URL` at a host that accepts TCP and returns 500, then open the vessel screen.

*Why it matters here:* This is a phone on winery wifi in a barn. A dropped request during the two seconds the form is loading is ordinary, not an edge case, and every other error path in this file is handled carefully: `route()` wraps everything in a try/catch with a "Try again" button (`walk.ts:81-89`), and every save handler catches and shows a banner. These two screens are the exception, and they are the two that matter most, since they are the capture path. The cellar cost is small in absolute terms, a reload and a re-entry of nothing, but the confidence cost is not: a screen that shows no error is read as a broken app.

*Fix:* Wrap both IIFE bodies and reuse the pattern already in this file:

```ts
void (async () => {
  try {
    // existing body
  } catch (error) {
    holder.replaceChildren(fail(error), button("Back", () => route(), "quiet"));
  }
})();
```

`fail()` at `walk.ts:63-65` and `route()` already exist. No dependency, no migration.
*Effort:* Minutes.

---

## MINOR

**G-6-6. The status ledger's opening line says nothing is built while the tables below grade four components built and verified.**
*Severity:* MINOR
*Triage:* BEFORE HARVEST
*Locator:* `docs/status-ledger.md:12`, against `docs/status-ledger.md:40`, `:53`, `:58`, and `docs/sorry-ledger.md:155`
*What is wrong:* `status-ledger.md:12` opens with "Nothing is built. This ledger exists before the code does, which is the point." Twenty-eight lines later the same file grades schema assertions, the backfill path kernel and inferred history generation as **Built and verified**. The sorry ledger's Discharged section (`sorry-ledger.md:155`) repeats the stale claim: "*None. Nothing has been built.*" The prose in both files is one or two sessions behind the tables in one of them.

*Why it matters here:* `README.md:23-26` and `CLAUDE.md:11-12` both declare this file the single source of build truth and say that a maturity claim anywhere else is wrong by construction. The construction only holds if this file is internally consistent, and right now its first sentence contradicts its own tables. A stranger reads the first paragraph, concludes the repository is a design document with no code, and does not look for the 1,792 lines of TypeScript that exist. This is the cheapest high-value fix in the report.

*Fix:* Rewrite `status-ledger.md:12-14` to say what is true: the schema is written and verified against a scratch Postgres, the walk screens are written and unrun against Supabase, and nothing has run against this winery's own instance. Replace `sorry-ledger.md:155` with the same. No dependency, no migration.
*Effort:* Minutes.

**G-6-7. `bun run test` is in the definition of done and no `test` script exists.**
*Severity:* MINOR
*Triage:* BEFORE HARVEST
*Locator:* `CLAUDE.md:89`, against `package.json:10-19`
*What is wrong:* The "What done means" block lists `bun run test` between `bun run lint` and `bun run doctor`. Running it produces:

```
error: "/usr/bin/test" exited with code 1
note: a package.json script "test" was not found
```

Bun falls through to the `/usr/bin/test` binary, so the failure is confusing as well as wrong: the message mentions a path nobody referenced. Meanwhile `db:test` exists at `package.json:16` and is not in the definition of done, even though `tests/schema_assertions.sql` is the thing that actually tests anything and it is named separately two lines above.

*Why it matters here:* `CLAUDE.md` is the contract every agent and every new developer reads first, and its definition of done contains a command that cannot succeed. Anyone checking their work against it either silently skips the line or spends ten minutes working out whether they broke something. There is no test runner in the tree and no dependency for one, so the honest version of this list has four commands, not five.

*Fix:* Either delete the `bun run test` line from `CLAUDE.md:89` and replace it with `bun run db:test`, which is the check that exists, or add a `"test"` script that aliases `db:test`. The first is better: it puts the assertion file in the definition of done under its real name. Note that adding a real TypeScript test runner would be a new dependency under `CLAUDE.md:43` and is not what this finding asks for. No migration.
*Effort:* Minutes.

**G-6-8. Every `<select>` in the app reaches the accessibility tree with an empty name.** *(probed)*
*Severity:* MINOR
*Triage:* DURING
*Locator:* `packages/cellar/src/pickers.ts:46-59` (and `:62`, `:123`), `packages/cellar/src/walk.ts:388-397`
*What is wrong:* `field()` in `ui.ts:97-103` wraps its input in a `<label>`, which works. The pickers do not use it. `shell()` puts the label text in a `<span class="field-label">` inside a `<div class="field-head">` and makes the `<select>` a sibling, so nothing associates them: no `for`, no `id`, no `aria-label`. The owner select at `walk.ts:388-397` and the photo input at `walk.ts:427-436` are built the same way.

Chromium's accessibility tree, read directly rather than inferred:

```
role=textbox   name="Name What is written on it."
role=combobox  name=""            <- Type
role=combobox  name=""            <- Location
...
selectsWithNoName: 7   selectsTotal: 7
```

Seven of seven. A screen reader announces "combo box, blank" on the field that chooses whether this is a barrel or a tank.

*Why it matters here:* Five to ten users and no stated screen reader requirement, so the direct cost today is low and I will not inflate it. Two things make it worth fixing anyway. Voice control ("tap Type") does not work on an unnamed control, which is the input method most likely to matter to someone whose hands are cold and wet. And it is systematic rather than incidental: every picker in the app is affected because they all route through one six-line function, which also means one fix covers all of them. On handover, if any adopting winery has a screen reader user, this becomes a MAJOR for them on day one.

*Fix:* In `shell()` at `pickers.ts:46-59`, give the select a generated id and make the label element a real `<label for>`:

```ts
const id = `f${Math.random().toString(36).slice(2, 9)}`;
select.id = id;
// then in head:
el("label", { class: "field-label", for: id, text: options.label })
```

Apply the same to `walk.ts:391` and `walk.ts:430`. No dependency, no migration.
*Effort:* Under an hour including the two one-off fields.

**G-6-9. `--ink-faint` fails the 4.5:1 contrast minimum in both themes.** *(probed)*
*Severity:* MINOR
*Triage:* DURING
*Locator:* `apps/web/src/app.css:9` and `apps/web/src/app.css:25`
*What is wrong:* I computed WCAG relative luminance for every token in the palette against both surfaces. Everything passes comfortably except one:

| Token | On surface | On ground |
|---|---|---|
| `--ink` | 17.42 / 13.77 | 15.99 / 15.12 |
| `--ink-soft` | 7.68 / 6.88 | 7.05 / 7.55 |
| **`--ink-faint`** | **3.84 / 3.87** | **3.52 / 4.24** |
| `--good` | 6.99 / 7.45 | 6.41 / 8.17 |
| `--warn` | 5.91 / 7.84 | 5.43 / 8.60 |
| `--bad` | 8.25 / 6.38 | 7.57 / 7.00 |
| primary button text on `--accent` | 10.88 / 7.40 | n/a |

(light / dark, against `--surface` and `--ground` respectively.)

`--ink-faint` misses 4.5:1 everywhere, worst at 3.52:1 for light-theme text on the page background. It carries `.field-hint`, `.summary-label`, `.empty`, `.section-head`, `.vessel-detail`, `.vessel-codes`, `.code-label`, `.event-at`, `.pin` and, notably, `.btn-quiet`, which is the "Back" and "Sign out" control on several screens.

*Why it matters here:* A phone screen in a barrel room, often in daylight through an open door, at 0.8rem. The specific casualties are the vessel list's detail line, which is how someone confirms what is in a barrel at a glance, and the "Back" link, which at 3.84:1 and no button styling is the least visible thing on a screen while being the primary navigation. Everything else in this palette is well chosen, which is why the one outlier is worth naming rather than a general complaint about contrast.

*Fix:* Darken the light value and lighten the dark one. `#6f6c64` reaches 4.6:1 on `--ground`; `#948fa0` reaches 4.6:1 on `--surface` in dark. Two token values at `app.css:9` and `app.css:25`, no markup changes. Separately consider giving `.btn-quiet` `--ink-soft` instead, since it is a control rather than secondary text. No dependency, no migration.
*Effort:* Minutes.

**G-6-10. zxing is bundled eagerly, so every load pays 416 kB for a feature used on one screen.** *(probed)*
*Severity:* MINOR
*Triage:* DURING
*Locator:* `packages/cellar/src/scan.ts:1`
*What is wrong:* `import { BrowserMultiFormatReader } from "@zxing/library"` is a static top-level import, so the decoder ships in the entry chunk. Measured on a fresh clone:

```
before:  dist/assets/index-MJBe4-LU.js   635.97 kB  gzip: 168.82 kB
```

I changed the one import to a type-only import plus a dynamic `await import()` at the point the camera button actually constructs a reader (`scan.ts:78`), and rebuilt:

```
after:   dist/assets/index-CztMpSNI.js   247.40 kB  gzip:  66.35 kB
         dist/assets/index-DSN73KLr.js   416.47 kB  gzip: 110.24 kB   (loaded on camera press)
```

First load drops 61%, from 169 kB gzipped to 66 kB. The deferred chunk loads when someone presses "Scan with camera" and not before.

*Why it matters here:* This is the one place where the scale bound argues for the change rather than against it. Five to ten users is small, but they are on phones on rural cell service in an outbuilding, opening the app dozens of times a day, and the camera is used on the scan screen and the two vessel screens rather than on sign-in, the claim screen, the facility screen, the home screen or the result screen. This is not a performance optimisation against imagined growth; it is 100 kB of decoder that most page loads never use. I would not raise it if the fix were structural. It is one line.

*Fix:* At `scan.ts:1`, `import type { BrowserMultiFormatReader } from "@zxing/library";` and inside the camera handler at `scan.ts:78`, `const { BrowserMultiFormatReader: R } = await import("@zxing/library"); reader = new R();`. Vite splits it automatically with no config change. Uses the installed dependency, adds none. No migration.
*Effort:* Minutes.

**G-6-11. Six Willamette Valley varieties are seeded into the schema and the app has no way to remove them.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `supabase/migrations/0004_terms_and_effects.sql:101-107`
*What is wrong:* The seed block inserts riesling, pinot_gris, chardonnay, gruner_veltliner, muller_thurgau and pinot_noir. I confirmed against the live database that these are the only six variety terms present. The comment above it is self-aware and draws the line deliberately (`0004:96-99`): "No coopers, no woods, no locations: those are facility-specific, they must be addable at runtime, and seeding them would hide the fact that a fresh install has none." That reasoning is correct and it applies with equal force to varieties, which are at least as facility-specific as coopers. The header on the block even says so: "Seed: this winery's vocabulary, and nothing else" (`0004:93`).

The compounding problem is that there is no removal path. `term` carries an `active` column, but `kernel.ts` only inserts (`addTerm`, `kernel.ts:105-118`); there is no update, no deactivate, no reorder. Configuration screens were killed in compost entry C-6, correctly, on the grounds that add-inline covers the case that blocks a fresh install. So a winery in Napa adopting this gets six Oregon varieties permanently at the top of their variety picker, above the Cabernet they add, and the only way to remove them is SQL against production or Supabase Studio, which `CLAUDE.md:67-70` forbids.

*Why it matters here:* Zero cost to this winery, which is why it is AFTER rather than sooner. It is a direct handover cost, and C-6 has already written its own answer: its reactivation condition (`compost-ledger.md:62-64`) is "a fork's vocabulary diverges far enough that seeding this winery's list is the wrong starting point." The handover premise satisfies that condition by definition. This finding is not arguing against C-6; it is pointing out that the condition C-6 set for itself is met the moment a second winery exists.

*Fix:* Smallest version, and the one that fits before harvest if it has to: move the six varieties out of `0004` into `supabase/seed/`, which exists and is empty but for `.gitkeep`, so `supabase db reset` still loads them locally and a fork can delete one file. Migrations are append-only, so this is a new migration that deletes the six variety rows plus a seed file that reinserts them, not an edit to `0004`. Fuller version, later: add a deactivate toggle to the picker, which is a single boolean update and is far short of the configuration surface C-6 killed. No dependency; the first version needs a migration.
*Effort:* An hour for the seed move. Half a day for the deactivate path.

**G-6-12. `block.variety` is free text while every other variety in the schema is a controlled term.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `supabase/migrations/0001_core_schema.sql:120-128`
*What is wrong:* Migration 0004 converted variety to a term reference everywhere it appeared: `node.variety` became `node.variety_id` with a composite foreign key into `term` (`0004:199-210`), and `template.variety` followed in 0005 (`0005:88-95`). `block.variety` was left as `text not null` and still is; I confirmed against the live database. Nothing joins it to `term` and nothing constrains it.

*Why it matters here:* T1-1 says cellar users select from existing objects because "free-text vessel names from three people is how the data becomes unusable" (`spec.md:61-63`), and this is the one surviving free-text instance of the vocabulary's most important word. The concrete failure is downstream: spec section 8.3 specifies a reverse block view answering "given this block, which vessels currently hold its fruit," and any query that wants to group blocks by variety alongside nodes has to reconcile a `text` column against `term.label`, where "Pinot Noir", "pinot noir" and "PN" do not match. Today the cost is zero, because no screen writes a block and `block_composition()` (`0002:48-59`) returns vineyard and block name without touching variety. That is exactly why it is AFTER: it is cheap now and expensive once blocks carry data.

*Fix:* A migration mirroring `0004:199-210`: add `variety_id` with the composite foreign key, backfill from the text column through `term_id('variety', ...)`, drop `block.variety`. Do it before any intake screen writes a block, since after that it needs a data migration with unmatched spellings to resolve by hand. No dependency; needs a migration.
*Effort:* An hour or two while the table is empty. Days once it is not.

**G-6-13. This winery's name is compiled into the client in two places.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `apps/web/index.html:7`, `packages/cellar/src/walk.ts:120`
*What is wrong:* `<title>Vitae Springs</title>` and `screen("Vitae Springs", ...)` as the sign-in screen's heading. A second winery's crew sees another winery's name on the browser tab and on the first screen they ever look at, before they have signed in and before anything could have loaded a configured name.

The repository already has the right mechanism and uses it correctly one screen later: `homeScreen` titles itself `facility.name` from the database (`walk.ts:239`), and `facilityScreen` uses "Vitae Springs" only as an input placeholder (`walk.ts:178`), which is fine and I am not flagging it. The gap is only the two places that render before a facility party can be read.

*Why it matters here:* Not a correctness problem and not urgent; nobody's wine is at risk. It is the most visible single artifact of this being one winery's software, and it is the first thing an evaluating winemaker sees, which makes it disproportionate to its size. I checked the rest of the tree: the only other occurrences are in SQL comments (`0001:19`, `0003:20`), which are history and should stay.

*Fix:* For the sign-in heading, either a generic string ("Sign in") or read a `VITE_APP_TITLE` from the environment with a neutral default, adding one line to `.env.example`. For the document title, set it from the same value in `apps/web/src/index.ts` after config loads, or make the static title generic. No dependency, no migration.
*Effort:* Minutes.

**G-6-14. The client is described as a PWA in four documents and no PWA exists.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `README.md:12`, `CLAUDE.md:18`, `apps/web/src/index.ts:1`, `packages/cellar/docs/spec.md:65-67`
*What is wrong:* "static PWA client" in the README and CLAUDE.md, "The PWA shell" as the first line of the web entry point. I searched the tree for a web app manifest, a service worker, any registration call, and any use of IndexedDB or localStorage. There are none, and `apps/web/public/` does not exist. The only trace is a comment at `kernel.ts:32` explaining that ids are client-generated "so an offline write has identity before the server sees it," which is groundwork for offline rather than offline.

T1-2 in the spec promises local-first append-only writes with opportunistic sync (`spec.md:65-67`). Nothing in the client persists anything: `sticky.ts:7-8` is explicit that its state is in memory and a reload starts clean, which is correct and honestly commented for what it is.

To be fair to the ledger, it does not overclaim: `status-ledger.md:68` grades "Local-first sync" as **Specified**. So the build truth is right and the prose around it is ahead of the build. Given `CLAUDE.md:11-12` says a maturity claim outside the ledger is wrong by construction, this is four instances of the thing that rule exists to catch.

*Why it matters here:* The phones are in a barn, and the person deciding whether to adopt this will read "PWA" as "works when the wifi drops." It does not: `route()` calls `currentSession()` first thing (`walk.ts:71`) and a network failure sends the user to the "Something went wrong" screen. The gap between the word and the behaviour is exactly the kind of thing that gets discovered during harvest.

*Fix:* Change the four descriptions to "static web client" until a manifest and a service worker exist, and add a line to the README saying the app currently requires connectivity. Adding an actual PWA is a real piece of work and belongs in the build order, not in this review. No dependency, no migration.
*Effort:* Minutes for the wording.

**G-6-15. The README sends a human stranger to the agent contract first, and the documents a stranger actually needs do not exist.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `README.md:43-53`
*What is wrong:* The "Where to read next" table has seven rows and the first is `CLAUDE.md`, described as "The agent contract. Read order, hard rules, what done means." `CLAUDE.md:2-3` says of itself that it is "The working contract for any agent operating in this repository." It is a good document and it is not an orientation for a person. A developer at another winery opens it and gets standing instructions about not installing dependencies and not writing trust fields, before they know what a node is.

On volume: the repository carries 12,943 words of prose across 1,579 markdown lines, against 1,792 lines of TypeScript and 2,259 of SQL. That ratio is not itself a problem, and I want to be clear that I am not arguing these documents should not exist. `docs/methodology-lineage.md` in particular is unusually good: every one of its fifteen entries names the failure it prevents, what it costs, and the condition under which dropping it is correct, and it says outright that an element failing all three "is ritual and should be removed." That is a better standard than most repositories hold themselves to.

The problem is ordering and absence, which is what the prompt asks about. Three things a stranger needs are missing entirely: a glossary (I searched; there is none), a current schema reference (G-6-4), and a "how to change something" page. The domain vocabulary is the sharpest gap. "Block" appears thirteen times across the spec and CLAUDE.md and is never defined; a reader has to infer vineyard block from the table's columns at `0001:120-128`. "Macrobin" appears as a seeded vessel type and nowhere in prose. Most consequentially, the schema's central object is `node` and the UI calls it a lot: there is a `lot_state` view, a `lot_name` column, and "Lot name" on screen, and the sentence "a lot is a node" is never written anywhere in the repository. I searched for every phrasing of it. The spec explains bin-to-lot lifecycle (`spec.md:176-180`) and separately defines node (`spec.md:86-88`) without connecting the two words.

*Why it matters here:* The stranger's first hour is spent working out vocabulary that one page would have given them, and the page that greets them is addressed to an agent. Everything needed to write the glossary already exists in the spec; it needs collecting, not authoring.

*Fix:* Reorder `README.md:45-53` to put `packages/cellar/docs/spec.md` first with a one-line note that CLAUDE.md is for agents and contributors rather than for orientation. Add `docs/glossary.md` defining node, lot, bin, load, block, vessel, placement, lineage, topping, racking, macrobin and cooper, with the node-equals-lot mapping stated plainly, and link it first. Both are collection jobs from existing text. No dependency, no migration.
*Effort:* Two or three hours for the glossary, minutes for the reordering.

**G-6-16. `DATABASE_URL` is required by `db:test` and documented nowhere.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `package.json:16`, against `apps/web/.env.example:1-4`
*What is wrong:* `"db:test": "psql \"$DATABASE_URL\" -v ON_ERROR_STOP=1 -f tests/schema_assertions.sql"`. `DATABASE_URL` appears in no `.env.example`, no README line and no CLAUDE.md line. `.env.example` documents only the two `VITE_` variables the client needs. With the variable unset, `psql ""` attempts a default local connection and produces a connection error rather than anything naming the missing variable.

This is the full configuration inventory, which the prompt asks for: `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`, both documented in `.env.example` and both failing loudly and clearly at runtime through `MissingConfig` (`env.ts:20-25`), with a message that names both variables and the example file. That part is done properly. `DATABASE_URL` is the only undocumented one, and the only one with no clear failure message.

*Why it matters here:* `db:test` runs the 28 assertions, which are the strongest verification this repository has. A stranger who wants to check the schema before trusting it hits an unexplained psql error. Small, but it sits directly on the path from "I cloned this" to "I believe it works."

*Fix:* Add `DATABASE_URL` to `apps/web/.env.example` with the local Supabase default as its commented value (`postgresql://postgres:postgres@127.0.0.1:54322/postgres`), or better, add a root `.env.example` since it is not a client variable and does not belong in `apps/web/`. Mention `bun run db:test` in the README beside `typecheck` and `lint` at `README.md:39-41`. No dependency, no migration.
*Effort:* Minutes.

---

## NITs

**G-6-17. Grouped.**
*Severity:* NIT
*Triage:* AFTER

1. `CLAUDE.md:54` says the compost ledger has "Five entries, each with a reactivation condition." It has six (C-1 through C-6), and two of them, C-4 and C-5, carry no `*Reactivate if:*` line. The compost ledger's own preamble (`compost-ledger.md:10-11`) makes the same claim about itself: "Each entry carries what was tried, why it died, and what would bring it back." Both statements are wrong in the same two places.
2. `docs/compost-ledger.md` lists C-6 at line 52 before C-5 at line 66. C-5 is the last entry in a file ordered C-1, C-2, C-3, C-4, C-6, C-5.
3. `packages/core/src/types.ts:60` says `VesselState` "Mirrors the vessel_state view." It mirrors 19 of the view's 26 columns; `has_glycol`, `setpoint_c`, `mode`, `variety_id`, `product_type_id`, `lot_owner_id` and `filled_at` are absent. Since `vessels()` does `select("*")` (`kernel.ts:191`) and casts the result, the extra columns arrive at runtime and are invisible to the type. Harmless today; the comment should say "the columns the screens use" rather than "mirrors."
4. `packages/cellar/src/scan.ts:70-96`: the camera button's label stays "Scan with camera" while the camera is running, because `run()` in `ui.ts:57-71` restores the original text when the handler resolves. Pressing it again stops the scanner (`scan.ts:73-76`), so the behaviour is right and only the label is silent about it. Set it to "Stop scanning" while `running` is true.
5. `packages/cellar/src/walk.ts:749` and `:756`: the scan screen's result region is replaced with no live-region announcement, so a scan that resolves changes the page silently for a screen reader. `banner()` already carries `role="status"` (`ui.ts:123`), so the pattern exists; the summary block does not use it.
6. `packages/cellar/src/ui.ts:97-103`: `field()` puts the hint inside the `<label>`, so the hint becomes part of the accessible name. Chromium reports `name="Name What is written on it."` and `name="Label Optional. Which sticker this is, so the next person knows."`. The whole hint is re-read every time the field takes focus. Move the hint outside the label and tie it with `aria-describedby`. *(probed)*
7. `packages/cellar/src/walk.ts:630` and `:517`: the photo is uploaded before the row it belongs to is created, so a failure in `createVesselWithWine` or `addVessel` leaves an orphaned object at `{vesselId}/photo.{ext}` in the bucket for a vessel that never existed. Nothing in the cellar record is wrong and nothing is lost; it is storage litter with no cleanup path, and `doctor` (S-4, unimplemented) would be the natural place to catch it.

---

## NOT A DEFECT

**G-6-18. Things a reviewer would expect to be wrong, that hold.**
*Severity:* NOT A DEFECT
*Triage:* n/a

The migrations apply clean from empty on stock Postgres 16 with a shim built in under fifty lines, and all 28 assertions pass. Nothing about the schema needs Supabase to verify, which is a real portability property and not an accident.

`bun run typecheck` and `bun run lint` are both clean from a cold clone, in 1.6s and 0.1s, under a `tsconfig.json` that turns on `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes` and `verbatimModuleSyntax` from the first file. Strict from the start with zero suppressions and zero lint findings across 20 files is uncommon and it is worth saying.

The comment convention holds. I grepped for comments that restate their code across 2,259 lines of SQL and 1,792 of TypeScript and found one candidate (`0005:166`), which immediately continues into why zero is a meaningful answer. SQL comment density runs 18% to 32% and the comments consistently name the axiom a constraint enforces or the simpler approach that was rejected, which is exactly what `CLAUDE.md:117-119` asks for. The TypeScript is sparser and the comments it has are load-bearing: `kernel.ts:64-68` explaining why `claimAccount` accepts both an array and a bare object from PostgREST, and `kernel.ts:257-259` explaining why two queries beat an embed across a composite key, are both the kind of note that saves someone an afternoon.

The add-inline design is the right answer to a real problem and the comment at `pickers.ts:16-18` states it well: a picker with nothing in it on a fresh install is a dead end on the first screen anyone sees. G-6-2 is a CSS bug defeating this design, not a criticism of it.

`LICENSE` is the complete Apache 2.0 text with the copyright line filled in as "Copyright 2026 VSV Management Software Contributors" rather than left as the `[yyyy] [name of copyright owner]` placeholder, which is the usual failure. `package.json:5` declares `Apache-2.0` consistently. There is no vendored or copied third-party code in the tree, so there are no attribution obligations beyond the license file itself. The sole runtime dependencies are `@supabase/supabase-js` (MIT) and `@zxing/library` (Apache-2.0), both consumed as packages, neither requiring a NOTICE entry that is missing. The README's stated reasoning for Apache over MIT and AGPL (`README.md:57-59`) is sound and worth keeping.

`app.css` gets the phone details right: `:focus-visible` outlines on both inputs and buttons, a 3rem minimum tap target as a token, `font-variant-numeric: tabular-nums` on summary values, a full dark palette, and `text-size-adjust` pinned. Aside from the single `--ink-faint` token in G-6-9, every colour pair clears 4.5:1 comfortably.

`ui.ts:55-71` disables a button while its write is in flight, with the comment "A button that is pressed twice because nothing visibly happened is how a duplicate barrel gets created." That is the correct concern, correctly handled, and it is the sort of thing usually discovered after the duplicate barrel.

Finally, the `doctor` script. It exits 1 with a message naming sorry S-4 and the file to read (`package.json:15`), and the README says it does this on purpose (`README.md:39-41`). A stub that fails loudly and explains itself is better than a stub that returns 0, and I would leave it exactly as it is.

---

## Navigability: three change requests, traced

The prompt asks for three plausible changes a second winery would make, traced through the files in order. I traced them against the tree and, where I could, against the running database.

**1. Add a vessel type, say "puncheon".** Zero files. `vessel.type_id` is a foreign key into `term` with kind `vessel_type` (`0004:215-222`), the picker loads terms at runtime (`pickers.ts:89-105`), and the add-inline path writes one and selects it without leaving the form (`kernel.ts:105-118`). I confirmed the four seeded types are ordinary rows. This is the change request the architecture was built for and it needs no developer at all, which is a genuinely good outcome and the strongest argument for the term table. Discoverability from a cold start is poor in one respect only: nothing tells a new developer that this is runtime-configurable, and sorry S-5 (`sorry-ledger.md:44-46`) asks whether barrel needs to distinguish puncheon from barrique as though it were a schema question. It is not one any more, and S-5's own phrasing predates 0004. Worth a line in the glossary from G-6-15.

**2. Change what the vessel-and-wine screen records, say adding a "received from" field.** Four files in a forced order, and the order is discoverable only by reading all of them. `supabase/migrations/0006_*.sql` for the column or the attributes key, then `packages/core/src/types.ts` for `NodePayload` or `VesselPayload` (`types.ts:85-106`), then `packages/core/src/kernel.ts` if the RPC signature changes (`kernel.ts:226-241`), then `packages/cellar/src/walk.ts:562-669` for the field itself and `walk.ts:455-469` for the read. The hard part is not the sequence; it is knowing that `create_vessel_with_wine` takes jsonb and therefore does not validate the shape, which `types.ts:83-84` says in a comment ("The function reads jsonb, so the shape is enforced here on the way in rather than by the signature") that you only find if you open the right file. A mistyped key in `NodePayload` is accepted by Postgres and silently ignored. That comment is doing a lot of load-bearing work in a place nobody would look first, and it belongs in the schema reference from G-6-4.

**3. Add a field to an event, say a lab reference number.** This is the one that goes wrong. The natural first stop is `0001_core_schema.sql:250-268`, which shows `type event_type not null` and a `data jsonb` column with a comment listing the keys it expects (`0001:260`). Both are stale: `event.type` was dropped and the `event_type` enum no longer exists (`0004:230`, `:251`). The current table has `operation_id` with a composite foreign key into `term`. A developer who builds on what 0001 shows them writes a migration referencing a type that is not there. Once past that, the change itself is small: a key in `data`, no migration at all, plus `EventRow` at `types.ts:117-125` and the read at `kernel.ts:243-272`. So the change is easy and finding out how to make it is not, which is exactly G-6-4.

The pattern across all three is consistent. Where the repository made something runtime-configurable it is excellent. Where it requires a code change, the reasoning is well preserved in comments and the current state is not written down anywhere.

---

## Closing

One blocker, and it is a version pin the world moved past rather than a design error. One UI bug that is three lines of CSS and is disproportionately worth fixing because it lands on the screen build order calls item 1. A README that stops two steps short of a running app. Everything else is handover debt: a schema you cannot read without executing it, a glossary that does not exist, and one winery's vocabulary in places a second winery cannot reach.

What is underneath all of it is in good shape. The migrations apply clean and prove themselves with 28 assertions on a stock Postgres, the TypeScript is strict with no suppressions, the comments explain why rather than what, and the decisions that were killed are written down with the conditions that would revive them. The gap between this repository and one a stranger can pick up is a few hours of writing and about twenty lines of code, which is a much better position than the reverse.

The one thing I would do before anything else is G-6-1, because until it is fixed nobody outside this winery can check any of the rest.
