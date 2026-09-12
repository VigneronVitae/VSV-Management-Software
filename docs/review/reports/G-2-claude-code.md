# G-2: TypeScript and client code quality

**Repository:** github.com/VigneronVitae/VSV-Management-Software
**Commit reviewed:** `c3eae3c7c262544e4b2e29526b513c964c6852fe`
**Commit date:** 2026-09-08
**Tree obtained by:** full `git clone https://github.com/VigneronVitae/VSV-Management-Software` (route 1)
**Review date:** 2026-09-11

## Currency checks

All four, as required.

1. **Commit.** HEAD is exactly `c3eae3c7c262544e4b2e29526b513c964c6852fe`, not an ancestor. `git merge-base --is-ancestor` confirms.
2. **Branch.** `main`. The stale `claude/sql-files-to-markdown-i31rob` exists on the remote and was not read.
3. **LICENSE canary.** Negative: 42 tracked files, not one.
4. **Content canary.** Positive: `supabase/migrations/0005_account_and_walk.sql`, `tests/schema_assertions.sql`, `packages/cellar/src/walk.ts`, `docs/session-reports/2026-09-08-walk.md` all present. Tracked file count is 42, matching the baseline.

Everything below was read at that SHA.

---

## Findings

| Id | Severity | Triage | Issue |
|---|---|---|---|
| G-2-1 | MAJOR | BEFORE HARVEST | No field carries over between vessels. The sticky system never returns a value |
| G-2-2 | MAJOR | BEFORE HARVEST | "Create an account" destroys its own confirmation message and blanks the form |
| G-2-3 | MAJOR | BEFORE HARVEST | Both vessel screens build their form in an uncaught async IIFE. A failed load is a dead screen with no Back button |
| G-2-4 | MAJOR | BEFORE HARVEST | An error after the write commits is indistinguishable from an error before it |
| G-2-5 | MAJOR | BEFORE HARVEST | "Add an empty vessel" is four calls, not one. A partial write leaves a code bound to nothing and no screen can repair it |
| G-2-6 | MAJOR | BEFORE HARVEST | The scan screen fires `resolve_vessel_code` once per decode frame, unthrottled, with no ordering guard |
| G-2-7 | MAJOR | DURING | Home offers four actions a `cellar` user is refused by RLS, and shows the raw Postgres refusal |
| G-2-8 | MINOR | DURING | Sticky state survives sign-out. `clearAll` exists and is never called |
| G-2-9 | MINOR | DURING | `signOut` discards its error |
| G-2-10 | MINOR | AFTER | `run()` drops a rejected handler, restoring the button as if nothing happened |
| G-2-11 | MINOR | AFTER | `void kind.reload()` on the location screen is unhandled and silent |
| G-2-12 | MINOR | AFTER | A photo uploads before the row is written, so a failed create orphans it |
| G-2-13 | MINOR | AFTER | A volume of 0 renders as "unrecorded" |
| G-2-14 | MINOR | AFTER | `core` holds a surface only `cellar` uses, against its own stated rule |
| G-2-15 | MINOR | AFTER | The import boundary is enforced by prose; Biome can enforce it with no new dependency |
| G-2-16 | MINOR | AFTER | `suspicious/noUnnecessaryConditions` would have caught G-2-1 and is not enabled |
| G-2-17 | MINOR | AFTER | `bun run test` does not exist, and "what done means" requires it |
| G-2-18 | MINOR | AFTER | `termPicker` and `locationPicker` have already diverged |
| G-2-19 | MINOR | AFTER | `createVesselWithWine` casts its result unguarded where `claimAccount` guards |
| G-2-20 | UNVERIFIED | DURING | Photo upsert may need a storage UPDATE policy that no migration creates |
| G-2-21 | NOT A DEFECT | - | Camera lifecycle, DOM listener accumulation, tsconfig strictness, module direction, file size, query cost |

Nothing here is a BLOCKER. Every path that can lose a record is recoverable by an admin with SQL, and that is said per finding rather than inflating the scale.

---

## MAJOR

**G-2-1. No field carries over between vessels. The sticky system is wired end to end and never returns a value.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/cellar/src/pickers.ts:92-94`, `packages/cellar/src/pickers.ts:171-174`, `packages/cellar/src/sticky.ts:18-20`
*What is wrong:* Two independent breaks, in opposite directions. The pickers store correctly and read back through `const wanted = selectId ?? select.value ?? stickyValue(key)`. `HTMLSelectElement.value` is `string` and never nullish; it is `""` on a select with no options yet, and `"" ?? x` evaluates to `""`. The sticky branch is unreachable, so `wanted` is `""` and the guard on the next line refuses to restore. The four plain text fields (`capacity` at :372, `fill_count` at :412, `toast` at :417, `vintage` at :570) fail the other way: `remember()` writes only `if (pinned.has(key))`, and the "keep" toggle is rendered only by `shell()`, which only the pickers use. Those four keys can never be pinned, so `stickyValue` returns `""` for them too.
*Why it matters here:* The screen promises this in as many words: "The first one is the longest; the rest remember your answers" (`walk.ts:256`). For 50 vessels it is the difference between an hour and a morning, in the week where the deadline binds. Worse than slow, it lies: the pin checkbox reads as checked on the next vessel, because `pinned` is module-level and `isPinned` is true, while the value behind it was discarded. The operator believes cooper and wood carried over and they did not.
*Fix:* `selectId ?? (select.value || stickyValue(key))` at both picker sites, and give the four text fields a pin toggle, or drop their `stickyValue` reads and pin them unconditionally. No dependency, no migration.
*Effort:* Under an hour, most of it deciding whether the text fields get a toggle or are always sticky.

**G-2-2. "Create an account" destroys its own confirmation message and hands back a blank form.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/cellar/src/walk.ts:108-117`, called from `walk.ts:126-134`
*What is wrong:* `attempt()` writes the note into `message`, then calls `await route()`. On a Supabase project with email confirmation on, `signUp` returns no session, so `route()` falls to `show(signInScreen())`, which builds a fresh screen and `replaceChildren`s the old one away. The note, the email and the password all vanish in the same tick they were set.
*Why it matters here:* This file names a stranger's first run as its acceptance test (`walk.ts:43-45`), and hosted Supabase has confirmation on by default, which is exactly the configuration the next winemaker will have. They press Create, get a blank sign-in form and no message, conclude nothing happened, press it again, and get "User already registered" with no explanation. That is the first ninety seconds of the product.
*Fix:* Do not route when a note is set: `if (note) { message.replaceChildren(banner(note, "good")); return; }` before the `await route()`. Or check `currentSession()` and only route when one exists.
*Effort:* Minutes.

**G-2-3. Both vessel screens build their form inside an uncaught async IIFE, so a failed load is a dead screen with no way off it.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/cellar/src/walk.ts:499-537`, `packages/cellar/src/walk.ts:562-669`
*What is wrong:* `void (async () => { ... })()` with no catch anywhere inside. The first awaits are `parties()` and `form.reload()`, which fan out to `terms()` and `locations()`. Any of them rejecting aborts the IIFE as an unhandled promise rejection. The `holder` div stays empty and the screen renders as a title, a lede, and nothing. Critically, the Back button is appended inside the same block (`:527` and `:659`), so it is never created.
*Why it matters here:* A phone on the far side of a metal barn loses a request routinely. The only escape is reloading the page, which a cellar hand holding a phone in gloves may not think to do and which loses any sticky state along with it. It is the difference between a five second retry and finding someone who knows the app.
*Fix:* Wrap the body in try/catch, append `fail(error)` plus a Back button into `holder` on rejection. Same six lines in both places.
*Effort:* Minutes.

**G-2-4. An error raised after the write commits looks exactly like an error raised before it.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/cellar/src/walk.ts:632-657`, specifically `:648-657`
*What is wrong:* `createVesselWithWine` is one transaction and either commits or does not. But the success branch then does `show(await resultScreen(...))`, and `resultScreen` awaits `vessels()` (`:681`) and `nodeEvents()` (`:683`). Either can reject on a network blip, and that rejection lands in the same `catch` at `:655` that handles a failed write. The user sees an error banner on the form they just submitted, with every field still filled in.
*Why it matters here:* Pressing the button again calls `newId()` fresh, so the retry is a new vessel and a new lot. The database refuses it, because 0004 added `vessel_type_name_key unique (type_id, name)` (`supabase/migrations/0004_terms_and_effects.sql:222`), so the second attempt returns "duplicate key value violates unique constraint". To someone standing in a barrel room that reads as a system fault, and the obvious workaround is to rename the barrel to B23a. That commits a second vessel, a second lot and a second placement for one physical barrel. Volume totals and every ownership figure built on them are then wrong, and nothing in the app flags it.
*Fix:* Separate the two failures. `await createVesselWithWine(...)` in its own try/catch; on success, navigate unconditionally and let `resultScreen` render its own error state rather than propagating. Alternatively catch inside `resultScreen` and show the summary from the values already in hand.
*Effort:* Under an hour.

**G-2-5. "Add an empty vessel" is four network calls where the wine path is one, and a partial write cannot be repaired from inside the app.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/cellar/src/walk.ts:506-526`, specifically `:519-521`
*What is wrong:* `await addVessel(...)` then `for (const row of capture.codes()) await bindOne(id, row)`. Separate REST calls, no transaction. If the second of three codes fails, the vessel row exists, code one is bound, codes two and three are not. Retrying the button hits `vessel_type_name_key` and fails forever with a duplicate-key message. There is no screen in the app that binds a code to an existing vessel: home offers add vessel, add vessel with wine, scan, add location.
*Why it matters here:* This is the case `create_vessel_with_wine` was written to prevent, and the comment above it says so (`0005_account_and_walk.sql:225-228`). The empty-vessel path simply does not use it. The outcome is a barrel wearing a physical sticker that `resolve_vessel_code` will answer "Nothing is bound to that yet" for, permanently, until someone runs SQL. At 50 vessels with two stickers each, one bad minute of signal during Stage 0 leaves a code that will never resolve.
*Why it is not a BLOCKER:* The vessel row itself is correct and the wine record is untouched. What is lost is a binding, recoverable by an admin calling `bind_vessel_code` directly.
*Fix:* Smallest version: call `createVesselWithWine` with no node, or add a `create_vessel_with_codes` function alongside it in a new migration so the bind loop is in the same transaction. Cheaper stopgap without a migration: on failure, keep the screen alive and retry only the unbound codes, tracking which succeeded. Needs a migration for the clean version.
*Effort:* Hours.

**G-2-6. The scan screen fires a database round trip per decode frame, unthrottled and unordered.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/cellar/src/scan.ts:45-66`, specifically `:48-52`; consumer at `packages/cellar/src/walk.ts:750-786`
*What is wrong:* `accept()` dedupes against `collected`, but `scanScreen` passes `collect: false`, so nothing is ever pushed to `collected` and the dedupe at `:48` never matches. zxing's `decodeContinuously` invokes the callback on a loop at `timeBetweenScansMillis`, so holding the camera on one barcode calls `resolveCode` several times a second for as long as it is in frame. There is no request token, so responses are rendered in arrival order.
*Why it matters here:* Two consequences. The mundane one is a phone on cellular burning battery and data on identical repeated queries. The one that matters in the cellar is walking down a barrel row: code A and code B both pass the lens within one round trip, A's response lands after B's, and the panel shows barrel A's lot under barrel B's sticker. Someone reads it and writes the wrong thing on a chalkboard.
*Fix:* Track the last accepted code in `accept()` regardless of `collect`, and hold a monotonically increasing request id in `scanScreen`'s `onCode`, discarding any response that is not the latest. Roughly eight lines, no dependency.
*Effort:* Under an hour.

**G-2-7. Home offers four actions that a `cellar` user is refused, and shows the raw Postgres refusal.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `packages/cellar/src/walk.ts:248-253`; policies at `supabase/migrations/0002_derived_and_rls.sql:274-284` and `supabase/migrations/0004_terms_and_effects.sql:517-519`
*What is wrong:* `vessel`, `location` and `term` are all `is_admin()`-only for writes, and `create_vessel_with_wine` is security invoker so it inherits those policies. `homeScreen` renders all four buttons for everyone. A `cellar` user fills the whole form, presses Save, and `fail()` puts the PostgREST message on screen verbatim: `new row violates row-level security policy for table "vessel"`. `facilityScreen` already gates on `user.role !== "admin"` at `:200`, so the pattern exists and is not applied here.
*Why it matters here:* With five to ten users on one instance, the second person to pick up a phone during the walk hits this, and the message tells them nothing they can act on. The 0004 comment (`:514-516`) accepts the policy deliberately; the defect is the client not reflecting it.
*Why DURING rather than BEFORE:* The inventory walk is a one-time admin job and the winemaker is the admin, so the common path is clear. The fix is purely additive.
*Fix:* Hide or disable the three admin-only buttons when `user.role !== "admin"` with a one-line explanation, and map `42501` or the RLS message in `fail()` to "Only an administrator can add this. Ask whoever set the cellar up."
*Effort:* Under an hour.

---

## MINOR

**G-2-8. Sticky state survives sign-out; `clearAll` exists for exactly this and is never called.** `packages/cellar/src/sticky.ts:32`, sign-out at `packages/cellar/src/walk.ts:259-266`. `values` and `pinned` are module-level and only a page reload clears them. On a shared barn phone, the next person to sign in inherits the previous person's pinned cooper and capacity. One line in the sign-out handler. Minutes.

**G-2-9. `signOut` discards its error.** `packages/core/src/kernel.ts:50-52`. Every other kernel function checks `error` and throws; this one does not. If the call fails the UI still routes, and whether the session actually ended depends on supabase-js internals rather than on anything this code asserts. Match the other five: check and throw. Minutes.

**G-2-10. `run()` drops a rejected handler and restores the button as if nothing happened.** `packages/cellar/src/ui.ts:57-71`. `try { await action() } finally { ... }` with no catch, invoked as `void run(...)` at `:49`. Every current call site guards internally, so this is correct today, which is the MINOR definition exactly. The first async `onClick` written without its own try/catch produces a silent unhandled rejection and a button that looks like it worked. Add a catch that surfaces the error, or document the contract at the call site. Minutes.

**G-2-11. `void kind.reload()` on the location screen is unhandled and silent.** `packages/cellar/src/walk.ts:312`. If `terms("location_kind")` fails, the Kind select stays empty with no message and the add-inline form does not open, because `toggle(true)` at `pickers.ts:104` is downstream of the failed await. The user sees an empty dropdown and no explanation. Minutes.

**G-2-12. The photo uploads before the row is written, so a failed create orphans it.** `packages/cellar/src/walk.ts:517` and `:630`. `uploadVesselPhoto(id, file)` runs first; if the insert or RPC then fails, `vessel-photos/<uuid>/photo.jpg` is a file for a vessel that does not exist. Retrying generates a new uuid and a second orphan. At these volumes it is litter, not a cost. Move the upload after the write and patch `attributes` in a second call, or accept it and write a cleanup into `doctor` when S-4 is closed. Hours.

**G-2-13. A volume of 0 renders as "unrecorded".** `packages/cellar/src/walk.ts:713` and `:774` use `vessel?.current_volume_l ? ... : "unrecorded"`, while `:283` gets it right with `?? "?"`. An emptied-but-not-closed placement reads as missing data rather than as zero. Change the two truthiness tests to null checks. Minutes.

**G-2-14. `core` holds a surface only `cellar` uses, against the rule written at the top of the file.** `packages/core/src/index.ts:1-3` states that anything only one module needs does not belong there, and then `kernel.ts:188-297` and `types.ts:60-125` carry `VesselState`, `VesselPayload`, `NodePayload`, `WalkResult`, `createVesselWithWine`, `resolveCode`, `bindCode`, `nodeEvents` and the photo pair. A future `sales` or `cases` module needs none of it. The honest counter is that the split cannot be judged against one module and moving it later is a rename. The import direction itself is clean: `cellar` imports only `core` and its own files, `web` imports both, `core` imports nothing internal. Leave it until a second module exists, then move rather than generalise. Hours, later.

**G-2-15. The import boundary is enforced by prose; Biome can enforce it with no new dependency.** `CLAUDE.md:71-75` says lint will do this "once there is code to enforce it against". There is now. `biome.json:17-22` enables only the recommended preset; `style/noRestrictedImports` ships in Biome 2.5.12 and takes a per-path pattern. Add a rule forbidding `cellar` inside `packages/*/src` other than `cellar` itself. Minutes.

**G-2-16. The rule that would have caught G-2-1 is available and not enabled.** `biome.json:20`. `suspicious/noUnnecessaryConditions` exists in 2.5.12 and is type-aware, so it flags a `??` whose left operand is never nullish, which is precisely the `select.value ?? stickyValue(key)` bug. It is not on under the recommended preset. This is the honest answer to what the preset does not cover that this codebase needs: not a style rule, a rule that reads types. `noFloatingPromises` is also present in nursery but would not have caught G-2-3, because those rejections are already `void`-prefixed. Enabling `noUnnecessaryConditions` needs no dependency; the config as written is otherwise valid, `preset` is a real key in 2.5.12 and the lockfile resolves to exactly that version. Minutes to enable, unknown to fix whatever else it finds.

**G-2-17. `bun run test` does not exist, and "what done means" requires it.** `CLAUDE.md:86` lists `bun run test` in the gate; `package.json:10-19` has no `test` script, so it exits with "Script not found". `doctor` exits 1 on purpose and says why, which is honest; this one just fails. Either add a script, even one that says there are no tests yet and exits 0, or strike the line from the contract. Minutes.

**G-2-18. `termPicker` and `locationPicker` have already diverged.** `packages/cellar/src/pickers.ts:61-118` against `:122-201`. Sixty near-identical lines each, and the empty-list branches no longer match: the term version at `:95-100` shows "Nothing here yet" only when `allowEmpty` is false, the location version at `:176-183` shows it whenever there are no rows. Nothing in the code says which is intended. Both carry the same `??` bug, which is what duplication does. Extract the shared shell after G-2-1 is fixed, not before. Hours.

**G-2-19. `createVesselWithWine` casts its result unguarded where `claimAccount` guards.** `packages/core/src/kernel.ts:240` is a bare `data as WalkResult`; `kernel.ts:69-75` goes to the trouble of accepting either an array or a bare object and explains why in a comment. The contract is currently right, because `create_vessel_with_wine` returns `jsonb` and PostgREST hands back the scalar, so this is a consistency note rather than a live bug. If it ever were wrong, the consequence is a success screen naming nothing: `vessels().find(v => v.id === undefined)` returns undefined and every summary row falls through to "unknown". Three lines to make it fail loudly instead, checking `vessel_id` is a string before returning. Minutes.

---

## UNVERIFIED

**G-2-20. Photo upsert may need a storage UPDATE policy that no migration creates.** `packages/core/src/kernel.ts:283` passes `{ upsert: true }`; `supabase/migrations/0005_account_and_walk.sql:319-339` creates only `vessel_photos_read` (select) and `vessel_photos_insert` (insert). Supabase's storage API is documented as requiring both INSERT and UPDATE policies for an upsert. Whether it demands the update permission unconditionally or only when the object already exists decides whether this is live. In the walk it cannot collide, because the path is keyed on a uuid generated moments earlier, so if the check is existence-gated it never fires. Cannot be settled without a running Supabase instance. The test: sign in as a non-admin, upload to `vessel-photos/<fresh uuid>/photo.jpg` with `x-upsert: true`, see whether it returns 403. If it does, add an update policy in a new migration, or drop `upsert: true`, which the walk does not need.

Related, and already named: S-7 covers the Supabase auth wiring under every RLS claim above. G-2-7's failure mode depends on that wiring behaving as the assertions assume.

---

## NOT A DEFECT

Six things a reviewer would expect to be wrong here, checked and holding.

**Camera lifecycle.** `reader.reset()` at `scan.ts:99` reaches `stopStreams()`, which calls `track.stop()` on every video track and breaks the decode loop, and `_destroyVideoElement()`, which removes zxing's own listeners and nulls `srcObject` without detaching the element, so the same `<video>` restarts cleanly on the next tap. `capture.stop()` is called on every path that leaves a screen with the camera possibly running: `walk.ts:521`, `:531`, `:647`, `:663`, `:800`. `decodeFromVideoDevice(null, ...)` is `if (!deviceId)` internally, so null takes the `facingMode: 'environment'` branch and gets the rear camera, not the front. `prepareVideoElement` sets `autoplay`, `muted` and `playsinline` itself, which is what iOS 11+ needs. `decodeContinuously` is synchronous, so the awaited promise at `scan.ts:81` does resolve and the tap-to-stop toggle at `:74-77` is reachable rather than stuck behind a permanently disabled button. All five verified against @zxing/library 0.21.3, the version the lockfile pins.

**Listener and node accumulation.** Every listener is attached to a node inside the subtree that `show()` replaces at `walk.ts:59`. Nothing binds to `window` or `document`, there is no `setInterval` anywhere, and there is no subscription: `alter publication supabase_realtime` exists in 0002 but no client code subscribes. A long session on one phone accumulates nothing. The only cross-screen resource is the MediaStream, covered above.

**Double-click on submit.** `ui.ts:57-71` disables the button and changes its label for the duration of the await, with the reasoning in a comment. It does what it says. Its gap is the window after an error, which is G-2-4 and G-2-5, not this.

**Handling of `unknown` from jsonb.** `walk.ts:685-690` reads `vessel?.attributes?.photo_path`, which is `unknown` under the declared type, and narrows with `typeof photoPath === "string"` before use. That is the correct shape for the jsonb boundary and the only place in the client that gets an unknown right by construction rather than by cast.

**tsconfig and suppressions.** `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `verbatimModuleSyntax`, `noFallthroughCasesInSwitch`, `noImplicitOverride`, all on, none loosened. Zero `@ts-ignore`, `@ts-expect-error`, `biome-ignore` or `any` in the 1,800 lines. `"jsx": "react-jsx"` is dead with no `.tsx` file in the tree, and `apps/web/vite.config.ts` falls outside the `include` globs so it is never typechecked; both are NITs below.

**`walk.ts` at 805 lines, and query cost.** It is a long file, not a problem file. The screen functions share no state beyond the module-level `root`, they appear in the order a stranger meets them, and there is no cross-cutting logic to trace. If it splits, the seams are `vesselFields` plus the two create screens into a file owning the vessel form, and `signInScreen` / `claimScreen` / `facilityScreen` into one owning the gates, leaving `walk.ts` with `route()` and `show()`. The cost of that split is that `root` and `show` become a navigator that has to be passed in, which is more structure than 800 lines currently justify. Do it when a second module needs the shell, not now. Separately, against the stated bound: `resultScreen` at `:681` fetches all of `vessel_state` to `.find()` one row, and `vessel_state` carries a correlated subquery for `codes`. At 50 vessels that is one round trip and nothing measurable. No query in this client is slow at these numbers.

---

## NITs

`bindOne` at `walk.ts:542` is a one-line wrapper around `bindCode`, used once, inline it. `(ev as KeyboardEvent)` at `scan.ts:106` is redundant, `on()` already types the handler from `HTMLElementEventMap`. `if (b.disabled) return` at `ui.ts:61` is unreachable, disabled buttons do not fire click. `checkbox()`'s `value: () => String(input.checked)` at `ui.ts:116` is never called, every caller reads `.input.checked`. `Effect` in `types.ts:17` and `KernelConfig` in `env.ts:9` are exported and unused outside their own files, as is `slug` at `kernel.ts:122`. `fail()` at `walk.ts:63` renders `[object Object]` for a thrown non-Error, which no current path produces. `"jsx": "react-jsx"` at `tsconfig.json:10` has no `.tsx` in the tree. `apps/web/vite.config.ts` is outside the `include` globs at `tsconfig.json:33-38` and is never typechecked. `env.ts:3-7` augments `ImportMeta` globally from `core`, which will conflict the day anyone adds `vite/client` types. `walk.ts:639` sends `Number(vintage)` unbounded and `node.vintage` is a bare `int` with no check constraint (`0001_core_schema.sql:165`), so a fat-fingered 20244 stores; per the hard rule the bound belongs in a migration, not in the client.

---

## Closing

The kernel layer is the strongest thing here: every function checks `error`, the two-query approach in `nodeEvents` has its reasoning written down, and the composite-versus-set ambiguity in `claimAccount` is handled rather than assumed. The client above it is where the gaps are, and they cluster in one place: what happens after a write, when the network is worse than the code assumes. G-2-3, G-2-4 and G-2-5 are the same missing idea seen three times.
