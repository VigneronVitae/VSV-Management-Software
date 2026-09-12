# CC_G3: Offline behaviour, PWA, and a phone in a barrel room

**Commit reviewed:** `c3eae3c7c262544e4b2e29526b513c964c6852fe`, dated 2026-09-08, obtained by `git clone https://github.com/VigneronVitae/VSV-Management-Software` over HTTPS and read at that SHA.

## Provenance checks

| Check | Result |
|---|---|
| Commit | `git rev-parse HEAD` = `c3eae3c7c262544e4b2e29526b513c964c6852fe`. Exactly the review baseline, not an ancestor. |
| Branch | `main`. The stale `claude/sql-files-to-markdown-i31rob` was not checked out. |
| LICENSE canary | Tree contains 42 tracked files, not a bare LICENSE. |
| Content canary | `supabase/migrations/0005_account_and_walk.sql`, `tests/schema_assertions.sql`, `packages/cellar/src/walk.ts`, `docs/session-reports/2026-09-08-walk.md` all present. File count is 42, matching the baseline. |

Dependency versions were verified against `bun.lock` and the published tarballs, because several findings below turn on library defaults: `@supabase/supabase-js` 2.116.0, `@supabase/auth-js` 2.116.0, `@supabase/postgrest-js` 2.116.0, `@zxing/library` 0.21.3, `vite` 7.3.6.

---

## Findings

| ID | Severity | Triage | Issue |
|---|---|---|---|
| G-3-1 | BLOCKER | BEFORE HARVEST | Both vessel screens render a dead end with no Back button when their initial load fails |
| G-3-2 | MAJOR | BEFORE HARVEST | No request timeout anywhere; a dead-zone write hangs on "Working" indefinitely |
| G-3-3 | MAJOR | BEFORE HARVEST | A session that dies offline is indistinguishable from a sign-out, and the next write goes out as the anon key |
| G-3-4 | MAJOR | BEFORE HARVEST | The empty-vessel path is four calls that half-succeed, and a stranded code becomes unbindable |
| G-3-5 | MAJOR | BEFORE HARVEST | The photo upload runs before the vessel insert, unbounded and full-resolution |
| G-3-6 | MAJOR | BEFORE HARVEST | The scan screen fires a network lookup every 500 ms while a code is in frame |
| G-3-7 | MAJOR | BEFORE HARVEST | `allowedHosts` is empty, which blocks the only route to testing the camera on a real phone |
| G-3-8 | MAJOR | DURING | No service worker: a reload with no signal loses the application entirely |
| G-3-9 | MAJOR | DURING | Nothing queues, retries, or persists; a reload discards everything typed |
| G-3-10 | MINOR | DURING | No manifest and no icons, so it installs as a Safari bookmark rather than an app |
| G-3-11 | MINOR | DURING | `viewport-fit=cover` is set and no CSS reads the safe-area variables |
| G-3-12 | MINOR | DURING | `--ink-faint` is 3.5:1 in light and 4.2:1 in dark, and it carries the codes and volumes |
| G-3-13 | MINOR | DURING | Enter in the manual code field bypasses the pending-state wrapper |
| G-3-14 | MINOR | AFTER | No history integration, so the Android back gesture leaves the app mid-form |
| G-3-15 | MINOR | AFTER | Quiet buttons are 38 px and checkboxes 22 px against gloved hands |
| G-3-16 | MINOR | AFTER | The camera button never says Stop, and a denied permission leaves a stale reader |
| G-3-17 | UNVERIFIED | AFTER | iOS storage eviction and back-forward cache behaviour, both needing a real device |
| G-3-18 | NIT | AFTER | Six small things, grouped at the end |

Seven findings are BEFORE HARVEST and together they are about a day of work. The two largest items, the service worker and an offline outbox, are both DURING, because both are additive and both can ship against a system already in use.

---

## What is actually a PWA

Nothing. There is no manifest, no service worker, no registration call, no icon of any size, and no `public/` directory to hold one. `apps/web/` contains exactly `.env.example`, `index.html`, `package.json`, `vite.config.ts`, and `src/`. A search of the whole tree for `manifest`, `serviceWorker`, `workbox`, `apple-touch-icon`, `navigator.onLine`, `localStorage`, `indexedDB`, `AbortController`, `setTimeout`, `retry`, and `queue` across `apps/` and `packages/` returns one hit, and it is a comment: `packages/core/src/kernel.ts:32`.

`README.md:12` and `CLAUDE.md:18` both describe the client as "a static PWA client", and `apps/web/src/index.ts:1` opens "The PWA shell that mounts modules". The artefact is a single-page web site served over HTTP. The consequences are exact:

**Installing it to a home screen.** On iOS, with neither a manifest nor `apple-mobile-web-app-capable`, Add to Home Screen produces a bookmark that opens in Safari with full browser chrome, and the icon is a screenshot of whatever page was showing. On Android, Chrome offers no install prompt at all without a manifest, and Add to Home Screen produces a shortcut with a generated letter icon.

**Launching it without signal.** The launch fetches `index.html` over the network. With no signal it shows the browser's offline error page. There is no cached shell to fall back to.

**Surviving a reload in a dead zone.** It does not. A reload is a fresh document load, the document is not cached, and the application is gone until signal returns. This is the single most consequential fact in this review, and the fix is G-3-8.

For context rather than as a finding: the repository knows. `docs/status-ledger.md` grades "Local-first sync" as Specified under Stage 2, and `packages/cellar/docs/spec.md:63` carries T1-2, "Local-first for append-only writes". The gap between the axiom and the build is recorded, not hidden. What is not recorded is the word PWA in the README, which today is a claim rather than a description.

---

## BLOCKER

**G-3-1. Both vessel screens render a dead end with no Back button when their initial load fails.**
*Severity:* BLOCKER
*Triage:* BEFORE HARVEST
*Locator:* `packages/cellar/src/walk.ts:499-537` and `packages/cellar/src/walk.ts:562-669`
*What is wrong:* Both screens return `view` synchronously and populate it from a floating `void (async () => { ... })()`. Everything the screen needs, including the Back button, is appended only after `await parties()` and `await form.reload()` have both resolved. If either rejects, and offline they both will, the rejection is unhandled and `holder` stays empty. The user is left with an `h1`, a lede, and nothing else: no form, no error, no way back.
*Why it matters here:* Five to ten people are using this on phones in a barrel room with stretches of no connectivity. The only escape from that screen is a page reload, and per the PWA section a reload with no signal loses the application entirely. One weak-signal tap on "Add a vessel and put wine in it" takes a person out of the system for as long as they are standing where they are standing. `locationScreen` (`walk.ts:296-343`) shows the correct shape: its Back button is appended synchronously and only `kind.reload()` floats, so it degrades to a usable screen with an empty picker.
*Fix:* Append the Back button and the `message` div synchronously when the screen is constructed, alongside `holder`, and wrap the IIFE body in `try/catch` that writes `fail(error)` into `message`. About ten lines across the two screens. No dependency, no migration.
*Effort:* Under an hour.

---

## MAJOR

**G-3-2. No request timeout anywhere; a dead-zone write hangs on "Working" indefinitely.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/core/src/kernel.ts:27`
*What is wrong:* `createClient(url, anonKey)` is called with no options. In supabase-js 2.116.0 the default db options are `{ schema: "public" }` and nothing else, so `db.timeout` is undefined and postgrest-js never attaches an `AbortSignal`. Storage uploads carry no timeout either. A request into a dead zone therefore sits until the browser's own transport timeout, which on mobile is minutes. `ui.ts:57-71` disables the button and shows "Working" for the whole duration, which is correct behaviour attached to a promise that never settles in useful time.
*Why it matters here:* This is the difference between "the network is down, type it on paper" after fifteen seconds and a person standing in front of a barrel watching a greyed-out button for two minutes. It also compounds G-3-1, G-3-4 and G-3-5, each of which becomes diagnosable the moment failures arrive promptly.
*Fix:* One line, and the option already exists in the installed version:
```ts
client = createClient(url, anonKey, { db: { timeout: 15000 } });
```
postgrest-js 2.116.0 honours it by wrapping fetch in an `AbortController` (`dist/index.mjs:3691`). Do not also set `db.retry`: retrying a POST or an RPC is precisely the duplication hazard described in G-3-4. Storage uploads need their own guard, since `db.timeout` does not reach the storage client; `Promise.race` against a timer in `uploadVesselPhoto` covers it in five lines. No dependency, no migration.
*Effort:* Minutes for the db half, under an hour with storage.

**G-3-3. A session that dies offline is indistinguishable from a sign-out, and the next write goes out as the anon key.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/core/src/kernel.ts:54-61` and `packages/cellar/src/walk.ts:69-72`
*What is wrong:* Trace a session that has sat idle offline for six hours. The Supabase access token expires after an hour. `currentSession()` calls `auth.getSession()`, which in auth-js 2.116.0 sees the token as expired, calls `_callRefreshToken`, gets a network failure, and returns `{ data: { session: null }, error }`. `currentSession()` destructures `const { data }` and **discards `error`** at `kernel.ts:58`. It returns null. `route()` reads null at `walk.ts:72` and shows the sign-in screen. The person is now looking at a password prompt they cannot satisfy, with no indication that this is a signal problem rather than a logout.

The second half is worse. `SupabaseClient._getAccessToken()` falls back to `this.supabaseKey` when there is no session (`supabase-js/dist/index.mjs:836-840`). So a write attempted while the session is dead but the network has partially returned goes out as the **anon key**, RLS refuses it, and the error surfaced in the red banner is a row-level-security policy violation. The cellar reads "new row violates row-level security policy" and concludes their account lost permissions.
*Why it matters here:* Sessions run for hours between sign-ins, which the brief states directly. Five to ten users, three at once, and the failure presents as a permissions problem rather than a connectivity one. That is hours of the wrong diagnosis during the weeks that matter.

One thing here holds and is worth stating: auth-js does **not** clear the stored session on a network-failed refresh. `_callRefreshToken`'s catch checks `isAuthRetryableFetchError` and skips `_removeSession` for transport failures, so the refresh token survives in `localStorage` and the session recovers by itself when signal returns. The credential is intact. Only the client's reading of it is wrong.
*Fix:* Capture the error and distinguish the two cases:
```ts
export async function currentSession() {
  const { data, error } = await kernel().auth.getSession();
  if (error) throw new Error(`Cannot reach the server: ${error.message}`);
  ...
}
```
`route()` already catches and shows "Something went wrong" with a Try again button, which is the honest screen for this. Add a `navigator.onLine === false` check in front of the sign-in screen so an offline user is told to wait rather than asked to type a password. No dependency, no migration.
*Effort:* Under an hour.

**G-3-4. The empty-vessel path is four calls that half-succeed, and a stranded code becomes unbindable.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/cellar/src/walk.ts:506-526`
*What is wrong:* "Save vessel" runs `uploadVesselPhoto`, then `addVessel`, then a serial `for` loop of `bindCode` calls, as four to six separate REST round trips with no transaction around them. If the third code fails to bind, the vessel exists with two codes bound and the loop aborts into the error banner. The user presses Save again; `const id = newId()` at line 517 mints a **new** id, so the retry inserts a different vessel, which is caught only by `unique (type_id, name)` (`0004_terms_and_effects.sql:222`) and surfaces as a raw Postgres unique-violation string. There is no screen anywhere that binds a code to an existing vessel, so the stranded sticker can never be attached through the UI.

`supabase/migrations/0005_account_and_walk.sql:226-228` says this in its own words: "Split across four REST calls this half-succeeds and leaves a vessel with no wine or a lot with no home, and the person holding the phone has no way to tell which. One function is one transaction." `create_vessel_with_wine` was built for exactly this, and the empty-vessel screen does not use it.
*Why it matters here:* Fifty vessels, entered once, on a walk. A barrel with a physical sticker the database does not know about is a barrel that cannot be scanned for the rest of its life, and scanning is the reconciliation mechanism the whole design leans on (T1-3).
*Fix:* Call `create_vessel_with_wine` with `p_node` null-shaped, or add a sibling `create_vessel` function that does vessel plus codes in one transaction. That is a new migration and the cheaper version does not need one: hoist `const id = newId()` and `const values = form.read()` out of the click handler into the IIFE scope, so a retry reuses the same vessel id. `bind_vessel_code` is already idempotent per `(vessel_id, code)` (`0003_parties_and_products.sql:199-231`), and the vessel insert then collides on its primary key instead of creating a twin. The retry becomes safe and completes the binds. That is a two-line move.
*Effort:* Minutes for the id hoist; half a day for the transactional version with its migration.

**G-3-5. The photo upload runs before the vessel insert, unbounded and full-resolution.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/cellar/src/walk.ts:517` and `walk.ts:630`, with `packages/core/src/kernel.ts:278-286`
*What is wrong:* `if (file) attributes.photo_path = await uploadVesselPhoto(id, file);` runs before `addVessel` and before `createVesselWithWine`. The input is `capture: "environment"` (`walk.ts:421-426`), so the file is a full-resolution phone photo, typically two to five megabytes, uploaded with no downscale, no progress indicator and no timeout. On weak-but-present signal, which is the ordinary barrel-room case rather than the total-dead one, an optional decorative field blocks the record it decorates, and if it fails the vessel is not saved at all.
*Why it matters here:* The photo is described in its own hint as "Optional. Useful when the label falls off." The vessel row is not optional. Ordering them this way lets the optional one veto the mandatory one over a connection that is bad precisely where the barrels are.
*Fix:* Two changes, both small. Insert the vessel first, then upload the photo and patch `attributes.photo_path` in a second call; a failed photo then leaves a saved vessel and a banner rather than nothing. Separately, downscale on a canvas to about 1600 px on the long edge and re-encode at JPEG 0.8 before upload, which takes a five-megabyte capture to roughly two hundred kilobytes. That is about twenty lines of `createImageBitmap` and `canvas.toBlob`, with no dependency. The reorder is the BEFORE HARVEST half; the downscale can follow.
*Effort:* Under an hour for the reorder, a few hours with the downscale.

**G-3-6. The scan screen fires a network lookup every 500 ms while a code is in frame.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/cellar/src/scan.ts:45-66` and `scan.ts:81-83`, reached from `packages/cellar/src/walk.ts:750-786`
*What is wrong:* `accept()` dedupes against `collected`, but `collected` is only appended to when `options.collect !== false` (`scan.ts:52`). `scanScreen` passes `collect: false`, so `collected` stays empty forever, the dedupe at line 48 never matches, and `options.onCode` fires on every decode. zxing's `decodeContinuously` invokes the callback once per successful decode and reschedules on `timeBetweenScansMillis`, which defaults to 500 (`@zxing/library/esm/browser/BrowserCodeReader.js:70,839`). Holding the camera on a barrel sticker therefore fires `resolveCode` twice a second, indefinitely, and the camera never stops after a hit.
*Why it matters here:* This is the screen a person uses most, standing in front of a barrel, and it turns a one-shot question into a sustained two-per-second RPC stream over the worst connection in the building, with the torch-less camera draining the battery behind it. On a slow link the in-flight responses also land out of order and the result panel flickers between renders of the same vessel.
*Fix:* Move the dedupe above the `collect` branch so the guard applies in both modes, keyed on the last code seen rather than on `collected`, and call `stop()` after a successful resolve in `scanScreen`'s `onCode` so the camera closes on a hit. About five lines. No dependency, no migration.
*Effort:* Under an hour.

**G-3-7. `allowedHosts` is empty, which blocks the only route to testing the camera on a real phone.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `apps/web/vite.config.ts:6`
*What is wrong:* `server: { host: true, port: 5173 }` with no `allowedHosts`. Vite 7.3.6 defaults `allowedHosts` to `[]` and installs `hostValidationMiddleware` on every dev request and on the HMR WebSocket. Reading `isHostAllowedInternal` (`vite/dist/node/chunks/config.js:20350-20361`), the rules are exact:

| Access path | Result |
|---|---|
| `http://localhost:5173` | Works, `hostname === "localhost"` |
| `http://127.0.0.1:5173` | Works, literal IPv4 |
| `http://192.168.1.42:5173` (LAN by IP) | Works, literal IPv4 |
| `http://[::1]:5173` | Works, literal IPv6 |
| `http://cellar.local:5173` (mDNS or Bonjour) | **403 Blocked request** |
| `http://winery.lan:5173` (local DNS) | **403 Blocked request** |
| `https://xyz.trycloudflare.com` or ngrok | **403 Blocked request** |

*Why it matters here:* On its own this is an inconvenience. It becomes BEFORE HARVEST because of what it interacts with: `getUserMedia` requires a secure context, and `http://192.168.1.42:5173` is not one. On a phone on the LAN, `navigator.mediaDevices` is undefined, zxing throws a `TypeError`, and `scan.ts:87-92` reports "Camera unavailable: Cannot read properties of undefined (reading 'getUserMedia')". `localhost` is a secure context, so the camera works on the laptop and nowhere else. The status ledger already grades "Code binding by camera" as In progress with the note "Never run against a camera". The only dependency-free route to changing that before harvest is an HTTPS tunnel, and the tunnel hostname is exactly what this config refuses.
*Fix:* One line:
```ts
server: { host: true, port: 5173, allowedHosts: [".local", ".trycloudflare.com", ".ngrok-free.app"] },
```
A leading dot matches both the bare host and any subdomain. `allowedHosts: true` also works and disables the check entirely; on a winery LAN the residual DNS-rebinding risk is small but real, and the dev server also serves the filesystem through `/@fs`, so prefer the list. Worth knowing for the camera specifically: vite skips the host check altogether when `server.https` is set (`config.js:25676`), so a local cert solves both problems at once, but generating one means mkcert, which is a new tool and should be flagged as such under the standing rule. The tunnel route needs nothing installed.
*Effort:* Minutes.

**G-3-8. No service worker: a reload with no signal loses the application entirely.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `apps/web/index.html:1-14`, and the absence of `apps/web/public/`
*What is wrong:* Covered in full above. There is no cached shell, so every launch and every reload is a live network fetch of `index.html` and the module graph.
*Why it matters here:* Phones lock, tabs get evicted under memory pressure, and people pull-to-refresh when something looks stuck, which given G-3-2 they will. Any of those in a dead zone ends the session.
*Fix:* A hand-written `apps/web/public/sw.js` of about forty lines: cache the built shell on `install`, serve it cache-first for navigations, and pass everything else through to the network. Register it from `index.ts` behind a `'serviceWorker' in navigator` guard. This caches the shell only, not data, which is the honest scope: the app opens offline and tells you it cannot reach the server, rather than appearing to work. Vite emits hashed asset filenames, so the cache key needs to come from the build; the simplest version caches `/` and `/index.html` and lets the hashed assets fall through to the HTTP cache. No dependency. Reach for `vite-plugin-pwa` only if the hashed-asset precache turns out to matter, and flag it under the standing rule if so.
*Why DURING rather than BEFORE:* It is purely additive, it touches no existing code path, and it can be deployed against a system already in use with no migration and no risk to the record. The cost of not having it during week one is that people must not reload in a dead zone, which is a sentence you can say to five people.
*Effort:* Half a day including testing the update path.

**G-3-9. Nothing queues, retries, or persists; a reload discards everything typed.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `packages/cellar/src/sticky.ts:1-7`, and every write path in `packages/cellar/src/walk.ts`
*What is wrong:* Traced per screen, the answer is the same everywhere. Nothing queues. Nothing retries. Nothing persists. On failure the user sees a red banner produced by `fail(error)` carrying the raw error string.

| Screen | On a failed request |
|---|---|
| Sign in (`walk.ts:108-117`) | Banner. Email and password survive in the DOM. |
| Claim (`walk.ts:159-167`) | Banner. Name survives. |
| Facility (`walk.ts:218-226`) | Banner. Name survives. |
| Home (`walk.ts:234-235`) | Caught by `route()`, shows "Something went wrong" with Try again. Correct behaviour. |
| Location (`walk.ts:322-338`) | Banner. Fields survive. |
| Add empty vessel (`walk.ts:506-526`) | Banner, plus the half-commit in G-3-4. |
| Vessel and wine (`walk.ts:615-658`) | Banner. Everything typed survives. |
| Scan (`walk.ts:753-785`) | Banner in the result panel. |

One thing genuinely works: because a failure replaces only the `message` div and never the screen, everything typed stays on screen and the button re-enables. A person can stand still, wait for a bar of signal, and press again. That is a real and deliberate property.

What is missing is durability. `sticky.ts:3` is explicit: "In memory only: nothing is persisted, and a reload starts clean." Combined with G-3-8, a reload in a dead zone loses both the application and twelve fields of typed vessel data.
*Why it matters here:* Low thousands of events per vintage, fifty vessels entered on one walk. A real outbox is Stage 2 work the repository has already specified, and building it in the weeks before harvest would be the wrong trade.
*Fix:* The honest minimum given the deadline is not a queue. It is persistence of the in-flight form. On every `change` event in `vesselFields` and `vesselWineScreen`, write the form values to `localStorage` under one key; on mount, if the key is present, offer "You were adding B23. Restore?"; clear the key on a successful save. That is about thirty lines, no dependency, no migration, and it converts "the reload ate my barrel" into "press restore". Pair it with a visible banner when `navigator.onLine` is false so nobody types twelve fields into a screen that cannot save them. Say plainly to the cellar that writes require signal until Stage 2 lands.
*Effort:* A day for the draft persistence and the offline banner. Weeks for a real outbox, which is why it is not proposed.

---

## MINOR

**G-3-10. No manifest and no icons, so it installs as a Safari bookmark rather than an app.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `apps/web/index.html:1-14`
*What is wrong:* No `<link rel="manifest">`, no `apple-touch-icon`, no `apple-mobile-web-app-capable`, no icon files anywhere in the tree.
*Why it matters here:* Nothing breaks. People use it in Safari with a URL bar, which costs about 100 px of vertical space on a phone and means the app is one tab among many rather than a thing on the home screen. Worth doing, not worth delaying for.
*Fix:* A twelve-line `apps/web/public/manifest.webmanifest` with `name`, `short_name`, `display: "standalone"`, `background_color`, `theme_color`, and 192 px and 512 px icons; two PNG files; two `<link>` tags plus `<meta name="apple-mobile-web-app-capable" content="yes">`. Do G-3-11 in the same pass, because standalone display is what makes the safe-area gap visible.
*Effort:* An hour, mostly making the icons.

**G-3-11. `viewport-fit=cover` is set and no CSS reads the safe-area variables.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `apps/web/index.html:5` against `apps/web/src/app.css:53-57`
*What is wrong:* `viewport-fit=cover` is declared. `env(` appears zero times in `app.css`. `#app` uses a fixed `padding: 1.25rem 1rem 4rem`.
*Why it matters here:* Today this is inert, because in Safari with browser chrome there is nothing to clip against, and the 4 rem bottom padding already clears the home indicator comfortably. It becomes a real bug the moment G-3-10 lands: in standalone display on a notched iPhone, the status-bar area is about 47 px and the 20 px top padding puts the `h1` underneath it. Landscape on an iPad puts the left edge of the form under the rounded corner.
*Fix:* One declaration:
```css
#app {
  padding: max(1.25rem, env(safe-area-inset-top)) max(1rem, env(safe-area-inset-right))
           max(4rem, env(safe-area-inset-bottom)) max(1rem, env(safe-area-inset-left));
}
```
No dependency, no migration.
*Effort:* Minutes.

**G-3-12. `--ink-faint` is 3.5:1 in light and 4.2:1 in dark, and it carries the codes and volumes.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `apps/web/src/app.css:9` and `app.css:24`
*What is wrong:* Measured against the tokens as written:

| Pair | Ratio | 4.5:1 |
|---|---|---|
| `--ink` on `--ground`, light | 15.99:1 | pass |
| `--ink-soft` on `--ground`, light | 7.05:1 | pass |
| `--ink-faint` on `--ground`, light | **3.52:1** | **fail** |
| `--ink-faint` on `--surface`, light | **3.84:1** | **fail** |
| `--ink-faint` on `--ground`, dark | **4.24:1** | **fail** |
| `--ink-faint` on `--surface`, dark | **3.87:1** | **fail** |
| `--accent-ink` on `--accent`, light | 10.88:1 | pass |
| `--bad`, `--good`, `--warn` on `--surface` | 8.25, 6.99, 5.91 | pass |

Every other token in the palette clears 4.5:1 comfortably. The one that fails is the one applied to `.field-hint`, `.summary-label`, `.vessel-detail`, `.vessel-codes`, `.code-label`, `.event-at`, `.empty`, and the text of `.btn-quiet`. That list includes the codes bound to a vessel, its lot, its volume, and the Back button.
*Why it matters here:* Low light in a barrel room and direct sun on a crush pad are the two conditions this runs in, and both attack the bottom of the contrast range. The failing tier is not decoration; it is the answer to "what is in this barrel".
*Fix:* Two values.
```css
:root { --ink-faint: #6f6d66; }                      /* 4.75:1 on ground, 5.18:1 on surface */
@media (prefers-color-scheme: dark) {
  :root { --ink-faint: #8b8697; }                    /* 5.15:1 on ground, 4.69:1 on surface */
}
```
Both verified by calculation against the existing `--ground` and `--surface`. No dependency, no migration.
*Effort:* Minutes.

**G-3-13. Enter in the manual code field bypasses the pending-state wrapper.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `packages/cellar/src/scan.ts:105-110`
*What is wrong:* The keydown handler calls `accept()` directly rather than going through `button()`'s `run()` wrapper (`ui.ts:57-71`). In the scan screen `accept` reaches `resolveCode`, a network call, with no disabled control and no "Working" state. Repeated Enter presses fire repeated RPCs.
*Why it matters here:* Typing eleven characters and pressing Enter is the path the module comment at `scan.ts:9-11` correctly identifies as faster than fighting autofocus, which makes it the path that gets used most in the dark. It is also the one path with no feedback.
*Fix:* Have the keydown handler click `addManual` rather than call `accept` directly, so it inherits the disable-and-label behaviour. One line.
*Effort:* Minutes.

**G-3-14. No history integration, so the Android back gesture leaves the app mid-form.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `packages/cellar/src/walk.ts:58-61`
*What is wrong:* `show()` calls `root.replaceChildren(node)`. There is no `pushState`, no `popstate` listener, and no `beforeunload` guard anywhere in the tree. Every screen is the same history entry, so the Android back button and the iOS edge-swipe navigate away from the document entirely rather than up one screen.
*Why it matters here:* Android's back gesture is reflexive. Doing it halfway through a twelve-field vessel form leaves the page, and with no service worker and no draft persistence there is nothing to come back to.
*Fix:* `history.pushState` in `show()` and a `popstate` handler that calls `route()` is the proper version and is a small refactor. The version that fits before harvest is a `beforeunload` handler registered while a form screen has unsaved input, which gives the browser's "Leave site?" prompt. Five lines. Largely moot once G-3-9's draft persistence exists, which is why this is AFTER.
*Effort:* Minutes for the guard, a few hours for real history.

**G-3-15. Quiet buttons are 38 px and checkboxes 22 px against gloved hands.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `apps/web/src/app.css:187-195` and `app.css:147-151`
*What is wrong:* `--tap: 3rem` is 48 px and is applied to `.input` and `.btn`, which is right. `.btn-quiet` overrides it to `min-height: 2.4rem`, or 38.4 px, with `background: none` and `border: none`, so it is underlined text with no visible boundary. That is the class on every Back button and on Sign out. `.checkbox` is `1.4rem`, or 22.4 px, which is the temperature-controlled toggle and the "keep" pin on every sticky picker.
*Why it matters here:* Cold wet hands in gloves. 38 px of unbounded underlined text is a small target, and 22.4 px is below the 24 px WCAG 2.2 floor before the platform guidance of 44 to 48 px is even considered.

Two mitigations are real and worth crediting. Both checkboxes are wrapped in `<label>` elements, so the adjacent text is part of the hit area. And `load()` calls `toggle(true)` when a picker comes back empty (`pickers.ts:104`, `pickers.ts:187`), so on a fresh install the add-inline form opens itself and nobody has to hit "Add one" to escape a dead end.
*Fix:* Delete the `min-height` override on `.btn-quiet` so it inherits `--tap`, and raise `.checkbox` to `1.75rem`. Two lines.
*Effort:* Minutes.

**G-3-16. The camera button never says Stop, and a denied permission leaves a stale reader.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `packages/cellar/src/scan.ts:70-96`
*What is wrong:* The button label is "Scan with camera" whether the camera is off or running, so the toggle-off path at line 74 is invisible. Separately, `reader` is assigned at line 78 before the `await` that can throw; the catch at line 84 sets `running = false` and hides the video but never calls `stop()`, so the reference survives and the next press constructs a second reader over the first.
*Why it matters here:* Cosmetic on both counts. The orphaned reader holds no media stream, because the failure was `getUserMedia` itself.
*Fix:* Set `camera.textContent` in `stop()` and after a successful start, and call `stop()` in the catch rather than unwinding by hand. Four lines.
*Effort:* Minutes.

**G-3-17. iOS storage eviction and back-forward cache, both needing a real device.**
*Severity:* UNVERIFIED
*Triage:* AFTER
*Locator:* `packages/core/src/kernel.ts:27`
*What is wrong:* Two iPadOS Safari behaviours that cannot be checked from a clone. First, the session lives in `localStorage` under auth-js's default `persistSession: true`, and Safari's tracking prevention evicts script-writable storage after seven days without interaction for sites not installed to the home screen. Second, there is no `pagehide` or `pageshow` handling, so a return from the back-forward cache after an app switch restores a page whose `running` flag is true but whose camera track is dead. The decode loop keeps running against a frozen frame and finds nothing; pressing "Scan with camera" once stops it and a second press recovers, which nobody will guess.
*Why it matters here:* The eviction window is seven days and harvest is daily use, so it will not bite during the season. It will bite the first person who opens the app in November. The bfcache case is a real daily annoyance and a real one to fix, but the fix cannot be validated without an iPad in hand.
*Fix:* For eviction, nothing beyond G-3-10, since home-screen installation changes the eviction policy. For bfcache, a `pageshow` listener that calls `capture.stop()` when `event.persisted` is true. Both need a device to confirm.
*Effort:* Minutes to write, unknown to verify.

---

## Checked, and it holds

Worth saying, because a reviewer would expect several of these to be wrong.

**Buttons already have a pending state.** `ui.ts:43-71` wraps every `button()` in `run()`, which disables the control and swaps the label to "Working" for the duration of the action, restoring both in a `finally`. The comment above it names the exact failure it prevents. Double-tap during flight is not possible. The gap is the absence of a timeout (G-3-2), not the absence of feedback.

**iOS does not zoom the inputs on focus.** `body` is `17px` (`app.css:44`) and `.input` is `font: inherit` (`app.css:136`), so every field including the `<select>` elements renders at 17 px. iOS zooms only below 16 px. `-webkit-text-size-adjust: 100%` at line 50 covers the other half.

**The camera asks for the rear one.** `decodeFromVideoDevice(null, video, cb)` at `scan.ts:81` resolves a null deviceId to `{ facingMode: 'environment' }` in zxing 0.21.3 (`BrowserCodeReader.js:373`). There is no device-enumeration step to get wrong, and no permission prompt for the device list.

**The video is unhidden before play.** `video.hidden = false` at `scan.ts:79` runs before `decodeFromVideoDevice`, which matters because iOS will not play a stream into a hidden element. `playsinline` is set at line 31. Adding `muted` would be belt and braces; with a video-only constraint there is no audio track to block on.

**Manual entry is genuinely reachable everywhere.** The `manual` field and "Add this code" button are siblings of the camera button in every construction of `codeCapture` (`scan.ts:112-122`), present before the camera is ever touched and unaffected by any camera failure. The camera is never a gate. `scan.ts:9-11` states this as a deliberate choice and the code matches the claim.

**The schema catches the duplicates the client does not.** Every add path regenerates its id on retry, so client-side idempotency is not what protects the record. The database is: `vessel` carries `unique (type_id, name)`, `location.name`, `party.name` and `vessel_code.code` are all unique, `term` is unique on `(kind, value)`, and `placement_one_lot_per_vessel` is a partial unique index. A double-submit after a lost response collides rather than duplicating. The cost is that the collision surfaces as a raw Postgres error string, and that the protection is a schema property a future edit could relax without anyone noticing what it was load-bearing for.

**`bind_vessel_code` is genuinely idempotent.** `0003_parties_and_products.sql:199-231` returns the existing row when the code is already on that vessel and raises only on a cross-vessel mix-up. Retrying the bind loop with the same vessel id is safe, which is what makes the two-line fix in G-3-4 work.

**auth-js keeps the session through a failed refresh.** Covered in G-3-3. `_callRefreshToken` skips `_removeSession` for retryable fetch errors, and `__loadSession` hands back a still-valid access token when a proactive refresh fails. The credential survives the dead zone; only `currentSession()`'s reading of it does not.

**`locationScreen` and `homeScreen` degrade correctly.** Both are the counter-example to G-3-1. `locationScreen` appends its Back button synchronously and floats only `kind.reload()`, so a failed picker load leaves a working screen. `homeScreen` is awaited inside `route()`, whose catch produces a titled error screen with a Try again button.

**`create_vessel_with_wine` is one transaction and accepts client ids.** `0005_account_and_walk.sql:232-295`, security invoker so every table's own RLS still decides. The wine path does the right thing; only the empty-vessel path does not.

---

## NITs

**G-3-18.** Grouped, none worth a paragraph.

- `kernel.ts:279`: `file.name.split(".").pop() ?? "jpg"`: `pop()` on a non-empty array never returns undefined, so the fallback is dead. A file named `image` with no extension yields `photo.image`.
- `scan.ts:53-63`: `manual.input.value` is cleared after a code is added but `labelField` is not, so the second code silently inherits the first one's label.
- `walk.ts:312`: `void kind.reload()` is a floating promise whose rejection is unhandled. Harmless here because the screen stays usable, but it is the same shape as G-3-1.
- `walk.ts:370` and `walk.ts:577`: capacity and volume are `type="number"`, which on iOS gives a keypad but no `inputmode="decimal"`. Values like `13.5` and `228` work; `inputmode` would be tidier.
- `walk.ts:421-426`: `capture="environment"` on the file input means iOS and Android go straight to the camera with no photo-library option. Right for the use case, worth knowing it is not a choice the user gets.
- `ui.ts:57`: the `if (b.disabled) return` guard is unreachable, since a disabled button does not dispatch click.

---

## One line on the rest

The kernel layer is a clean pass-through with no rules computed client-side, matching its own stated constraint, and the two-query approach in `nodeEvents` (`kernel.ts:256-272`) with its comment about PostgREST composite-key relation detection is exactly the right kind of caution. The `run()` wrapper, the always-visible manual entry, the auto-opening add-inline picker on an empty install, and the 48 px `--tap` token are all evidence of someone who has thought about the barrel room. The gap between that and this review's findings is almost entirely the difference between designing for a bad connection and designing for no connection, which is a Stage 2 item the repository has already named.
