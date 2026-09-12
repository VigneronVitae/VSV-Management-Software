# G-4: security and operational posture

**Target:** github.com/VigneronVitae/VSV-Management-Software
**Reviewed at:** `c3eae3c7c262544e4b2e29526b513c964c6852fe`
**Date:** 2026-09-11

---

## 1. Access and provenance

**Tier: A.** Full tree on disk at a pinned SHA. Route 1 worked: `git clone https://github.com/VigneronVitae/vsv-management-software` over the session's git proxy, into `/home/user/vigneronvitae/vsv-management-software`. Full history, not shallow. Citations are `path:line` against that tree.

**Commit.** `git rev-parse HEAD` returns verbatim:

```
c3eae3c7c262544e4b2e29526b513c964c6852fe
```

This is the baseline commit itself, not a descendant and not an ancestor. `git log --oneline -1` reads `c3eae3c File the walk session report, and correct the reverse dependency edges`.

**Canaries.** Branch `main` (`origin/HEAD -> origin/main`); the stale `claude/sql-files-to-markdown-i31rob` exists on the remote and was not checked out. `git ls-files | wc -l` returns **42**. All four named canaries present: `supabase/migrations/0005_account_and_walk.sql`, `tests/schema_assertions.sql`, `packages/cellar/src/walk.ts`, `docs/session-reports/2026-09-08-walk.md`.

**Beyond reading: the migrations were executed.** Postgres 16.13 was available in the review environment, so the five migrations were applied to a live cluster against a minimal Supabase-shaped stub (roles `anon`, `authenticated`, `service_role`; an `auth` schema with `auth.uid()` reading `request.jwt.claim.sub`; Supabase's default `grant all on tables to anon, authenticated`). Every claim below marked **verified** was produced by running the query, not by reading it. The stub is a stub: it reproduces PostgREST's role mapping and nothing else, so it proves policy evaluation and says nothing about GoTrue. That is exactly the line sorry S-7 already draws, and this review does not close it.

### File table

Every file read, all whole.

| Path | State | Lines |
|---|---|---|
| `supabase/migrations/0001_core_schema.sql` | whole | 370 |
| `supabase/migrations/0002_derived_and_rls.sql` | whole | 334 |
| `supabase/migrations/0003_parties_and_products.sql` | whole | 284 |
| `supabase/migrations/0004_terms_and_effects.sql` | whole | 519 |
| `supabase/migrations/0005_account_and_walk.sql` | whole | 340 |
| `supabase/config.toml` | whole | 56 |
| `packages/core/src/env.ts` | whole | 27 |
| `packages/core/src/kernel.ts` | whole | 297 |
| `packages/core/src/types.ts` | whole | 125 |
| `packages/cellar/src/walk.ts` | whole | 805 |
| `packages/cellar/src/scan.ts` | whole | 125 |
| `packages/cellar/src/sticky.ts` | whole | 35 |
| `packages/cellar/src/pickers.ts` | whole | 201 |
| `tests/schema_assertions.sql` | whole | 412 |
| `.gitignore` | whole | 47 |
| `apps/web/.env.example` | whole | 4 |
| `apps/web/vite.config.ts` | whole | 8 |
| `apps/web/src/index.ts` | whole | 27 |
| `apps/web/index.html` | whole | 14 |
| `bun.lock` | whole | 218 |
| `package.json`, `apps/web/package.json`, `packages/*/package.json` | whole | 24 / 19 / 10 / 11 |
| `CLAUDE.md` | whole | 130 |
| `README.md` | whole | 59 |
| `LICENSE` | whole | 201 |
| `docs/sorry-ledger.md`, `docs/status-ledger.md`, `docs/compost-ledger.md` | whole | 156 / 112 / 72 |

The remaining files (`packages/cellar/docs/spec.md`, `docs/methodology-lineage.md`, the session reports, `apps/web/src/app.css`, `biome.json`, `tsconfig.json`, `packages/cellar/src/ui.ts`) are on disk whole and were read selectively or not at all, because nothing in them bears on this prompt. Coverage of the minimum corpus is complete.

---

## 2. Findings

| ID | Severity | Triage | Issue |
|---|---|---|---|
| G-4-1 | BLOCKER | BEFORE HARVEST | The hosted project's auth settings live nowhere in the repository, and the client ships a self-service signup button |
| G-4-2 | MAJOR | BEFORE HARVEST | A signed-in account with no `app_user` row reads the whole cellar and writes lots, lineage, placements and events |
| G-4-3 | MAJOR | BEFORE HARVEST | Admin goes to the first account that reaches the claim screen, not to the person who was invited |
| G-4-4 | MAJOR | BEFORE HARVEST | Deactivating a custom crush client promotes that login to full cellar read |
| G-4-5 | MAJOR | BEFORE HARVEST | No backup exists, and no restore has been rehearsed |
| G-4-6 | MAJOR | BEFORE HARVEST | No deployment path and no rollback |
| G-4-7 | MAJOR | BEFORE HARVEST | Nothing is written down for the hours Supabase is unreachable |
| G-4-8 | MAJOR | DURING | `claim_task` is a definer function with no entitlement check, and a stranded task cannot be recovered by a cellar user |
| G-4-9 | MAJOR | DURING | Any signed-in user can write an event attributed to anybody |
| G-4-10 | MAJOR | DURING | Client scoping stops at `node`; `event`, `placement`, `lineage` and `party` are readable in full |
| G-4-11 | MAJOR | DURING | Every signed-in user can read every vessel photo, which is the exact thing the bucket was made private to prevent |
| G-4-12 | MINOR | DURING | Re-photographing a vessel fails: the client upserts, and no UPDATE policy on `storage.objects` exists |
| G-4-13 | MINOR | DURING | The photo is uploaded before the row it belongs to, and orphans on any later failure |
| G-4-14 | MINOR | DURING | An admin can rewrite event history in place, leaving no trace |
| G-4-15 | MINOR | DURING | A cellar user can rewrite the operation and subject of a task they hold |
| G-4-16 | MINOR | DURING | Topping compares variety, vintage and product type, and not owner |
| G-4-17 | MINOR | AFTER | Only an admin can close a placement, so racking will be refused the day it is built |
| G-4-18 | MINOR | AFTER | Migration 0002 cannot be applied to a bare Postgres, which 0005 takes trouble to allow |
| G-4-19 | NIT | AFTER | Five small things, grouped at the end |
| G-4-20 | NOT A DEFECT | n/a | Eleven checks that hold, listed so the flags above mean something |

Seven BEFORE HARVEST, of which four are configuration and procedure rather than code. That is the shape the deadline argues for.

---

## BLOCKER

**G-4-1. The hosted project's auth configuration lives nowhere in the repository, and the client offers self-service account creation.**
*Severity:* BLOCKER
*Triage:* BEFORE HARVEST
*Locator:* `supabase/config.toml:1-3,40-53`; `packages/cellar/src/walk.ts:126-134`; `packages/core/src/kernel.ts:40-43`
*What is wrong:* `config.toml` sets `enable_signup = false` and says in a comment that "an open one would let anyone insert events." The file's own first three lines say it governs local development only and that nothing in it describes a hosted project. So the single most load-bearing security setting in the system is asserted in a file that does not reach the deployment, and there is no other file in the tree where it is recorded, checked, or tested. Meanwhile `signInScreen` renders a "Create an account" button that calls `auth.signUp` unconditionally, and the walk's stated acceptance test is a stranger's first run from an empty database, which only works if signup is on.
*Why it matters here:* the anon key ships in the client bundle by design, so row-level security is the whole access story, and every policy in the tree is written `to authenticated`. The distance between "no attacker" and "any visitor with full cellar read and event write" is one dashboard toggle that nothing in this repository controls or observes. If someone enables signup during setup to get the first-run walk working (which is what the walk's own design pushes them toward) and never turns it back off, findings G-4-2 and G-4-3 become live for anyone who finds the URL. `enable_confirmations = false` at line 53 means there is not even an email round trip in the way.
*Fix:* two parts, both small. First, procedure: confirm in the hosted dashboard that email signup is disabled, and record the confirmed state and the date in `docs/status-ledger.md` so it is a fact with an owner rather than an assumption. Second, code: gate the "Create an account" button behind a build flag that defaults to off, so the production bundle does not advertise a door that should be shut, and so a `Signups not allowed for this instance` error is never what a cellar hand sees at 6am. The first-run walk keeps working locally where the flag is on.
*Effort:* minutes for the dashboard check, under an hour for the flag.

---

## MAJOR

**G-4-2. A signed-in account with no `app_user` row reads the whole cellar and writes lots, lineage, placements and events.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `supabase/migrations/0003_parties_and_products.sql:265-283`; `supabase/migrations/0002_derived_and_rls.sql:299-312,289-291`
*What is wrong:* `is_facility_user()` reads `select kind = 'facility' from party where app_user_id = auth.uid() and active` and wraps it in `coalesce(..., true)`. The comment names the intended case, the harvest intern who owns nothing and needs to see everything. The effect is broader: no party row of any kind means `true`, and an account that has authenticated but never called `claim_account` has no `app_user` row and no party row either. `node_read` therefore admits it. Insert policies on `node`, `lineage` and `placement` are `with check (true)` to `authenticated`, and `event_insert` needs only `by_user = auth.uid()`.
*Verified:* acting as a JWT `sub` that exists in `auth.users` and nowhere else, `select count(*) from node` returned every row, and an `insert into node` succeeded. The placement insert was refused only by `placement_one_lot_per_vessel`, which is a uniqueness constraint doing its job and not an access control.
*Why it matters here:* the coupling to G-4-1 is what makes this urgent rather than theoretical. It also means the security model does not degrade: there is no "signed in but not yet set up" state with reduced rights, so any hole that yields a JWT yields the cellar. At five to ten users the fix costs nothing and removes a whole class of surprise.
*Fix:* make the intern case explicit instead of a default. Require the `app_user` row: `select is_admin() or exists (select 1 from app_user where id = auth.uid() and active) and coalesce((select kind = 'facility' from party where app_user_id = auth.uid() and active), true)`. One migration, one function body, no schema change.
*Effort:* under an hour including a new assertion in `tests/schema_assertions.sql`.

**G-4-3. Admin goes to the first account that reaches the claim screen, not to the person who was invited.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `supabase/migrations/0005_account_and_walk.sql:37-70`, particularly `:61`
*What is wrong:* `claim_account` decides admin by `select count(*) = 0 into is_first from app_user`. It counts rows in `app_user`, which are created by this function, not accounts in `auth.users`, which are created in the dashboard. With signup disabled (the intended posture, per G-4-1), the winemaker creates five accounts in the dashboard and hands out passwords. Whoever opens the app first becomes the administrator, and everyone after is `cellar`. The advisory lock at `:59` closes the two-at-once race correctly and does nothing about this, because this is not a race.
*Why it matters here:* admin is the role that creates vessels, locations, terms and tasks, edits nodes, and confirms inferred history. Handing it to a harvest intern who happened to charge their phone first is not a security breach so much as a support problem that lands during the week nobody has time for it, and the recovery path requires the dashboard SQL editor.
*Why it is not a BLOCKER:* it is recoverable. An admin row can be repaired with one `update app_user set role = 'admin'` from the dashboard.
*Fix:* cheapest for harvest is procedural and costs nothing: the winemaker signs in and completes the claim screen before any other account exists or any URL is shared. The durable fix is a `bootstrap_admin_email` row in a one-row settings table that `claim_account` compares against `auth.jwt() ->> 'email'`, falling back to first-wins only when unset. Ship the procedure now, write the code after.
*Effort:* minutes for the procedure, two hours for the settings table and its assertion.

**G-4-4. Deactivating a custom crush client promotes that login to full cellar read.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `supabase/migrations/0003_parties_and_products.sql:272-275`
*What is wrong:* the same `coalesce(..., true)` as G-4-2, reached by a different and much more likely route. The subquery filters on `and active`. Set `party.active = false` on a client and the subquery returns no rows, `coalesce` yields `true`, and `is_facility_user()` reports that the client is facility staff. Deactivation, the ordinary end-of-season housekeeping action, grants strictly more access than it revokes.
*Verified:* a client login saw 1 of 2 nodes while its party was active, and 2 of 2 with `is_facility_user() = true` the moment the party was deactivated. Flipping `active` back restored the scoping.
*Why it matters here:* two custom crush clients are already real, and both are other businesses. The action that triggers this is the one a tidy person performs in December: mark last year's client inactive. The account is not deleted, because Supabase auth accounts and party rows are separate, so the login keeps working and silently widens.
*Fix:* the same one-line change as G-4-2 closes both, because requiring an active `app_user` row and treating an existing-but-inactive party as a client rather than as staff are the same correction. If only one thing is changed, change this: split the party lookup so that "has a party row that is inactive" is distinguished from "has no party row." Add both cases to `tests/schema_assertions.sql`, which currently tests the active client and not the deactivated one (`tests/schema_assertions.sql:389-408`).
*Effort:* under an hour, shared with G-4-2.

**G-4-5. No backup exists, and no restore has been rehearsed.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `docs/status-ledger.md:79` grades "Nightly git export" as Specified; `docs/compost-ledger.md:31-32` records it as the surviving fragment of C-2 and "Adopted"; nothing in the tree implements it. `supabase/seed/` holds only `.gitkeep`.
*What is wrong:* the only backup in the system is whatever Supabase's plan includes, which is not named anywhere in this repository, is not verified, and on the free and Pro tiers is a daily snapshot with a retention window rather than point-in-time recovery. The specified nightly export does not exist. No restore has been performed, so the restore time is unknown.
*Why it matters here:* the prompt's own scenario is the real one. A bad migration applied mid-harvest against a single Postgres instance with no replica has exactly one recovery path, and at the moment nobody knows whether that path is hours, a day, or a support ticket. The data at risk is not reconstructible: a bin record that was never written down anywhere else is gone, and the cellar cannot re-weigh fruit that is already fermenting.
*Fix:* three things, in this order and none of them large. (1) Write down, in `docs/status-ledger.md`, which Supabase plan the project is on and what its actual backup frequency and retention are. That is a ten-minute dashboard check and it converts an assumption into a number. (2) Rehearse one restore into a scratch project before harvest and record how long it took. An unrehearsed restore is not a backup. (3) Build the specified nightly export as the smallest possible thing: a cron job on any machine that runs `pg_dump` against the connection string and commits the output to a separate private repository. No new dependency in this tree, no code in this repository, and it gives a diffable daily record that also answers "what changed yesterday" during harvest.
*Effort:* an hour for (1) and (2) together. Half a day for (3), and (3) can slip to DURING if (1) and (2) are done.

**G-4-6. No deployment path and no rollback.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* no `.github/` directory exists; `package.json:18` is the whole build story (`vite build`); `supabase/config.toml:42-43` names only `http://localhost:5173` as site URL and redirect target.
*What is wrong:* there is no CI, no hosting configuration, no production URL anywhere in the tree, and no record of how the client reaches a phone. `site_url` and `additional_redirect_urls` still point at a dev server, which means that if any auth flow that uses a redirect is ever enabled (password reset, magic link, email confirmation), it will send people to `localhost`. Migrations are applied by hand with the Supabase CLI, with nothing recording which migrations a given deployment has.
*Why it matters here:* a broken deploy at 2pm during press week has no defined recovery other than "rebuild whatever was there before and hope." The client is static files, so the correct answer is small and worth having written down rather than improvised.
*Fix:* the smallest thing that works. Deploy `apps/web/dist` to any static host with immutable per-deploy URLs and an atomic alias switch (Netlify, Cloudflare Pages, GitHub Pages with a tag). Rollback is then re-pointing the alias at the previous deploy, which takes seconds and needs no rebuild. Add the production origin to `site_url` and `additional_redirect_urls` in the hosted project's auth settings, and mirror it into `config.toml` so the file stops describing only a laptop. Write the four commands into `README.md` under a "Deploying" heading. No new dependency in this tree.
*Effort:* half a day, most of it the first deploy.

**G-4-7. Nothing is written down for the hours Supabase is unreachable.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `packages/core/src/kernel.ts` throughout (every function is an immediate awaited call with no retry); `packages/cellar/src/walk.ts:63-65,81-89`; `packages/cellar/src/sticky.ts:1-5`; `apps/web/index.html` has no manifest link and no service worker registration
*What is wrong:* this is the design question the prompt asks the review to answer, so here is the honest answer. Every write is a live round trip. When the API is unreachable, `fail()` renders the raw network error into a banner and the screen stays put, which means the form the person filled in is still on screen and pressing the button again will work once the network returns. That is better than it sounds and it is the right behaviour at this scale. What is lost is everything not yet submitted the moment someone reloads, backgrounds the tab long enough for iOS to evict it, or navigates back: `sticky.ts:1-5` is explicit that its memory does not survive a reload, and there is no service worker, so a reload with no network is a blank page rather than a cached shell. The README calls the client a PWA; today it is a single-page app served over the network, which is not the same promise.
*Why it matters here:* fifty vessels and three concurrent users do not need an offline sync engine, and building one now would be the wrong call under every rule in `CLAUDE.md`. But intake is the one path where a lost record is unrecoverable, and barn wifi is not reliable.
*Fix:* two cheap things and one procedure. (1) Register a minimal service worker that caches the built shell, so a reload with no network gives the app back rather than a browser error page. Vite can emit one with no plugin; twenty lines of `caches.match` fallback. (2) On a failed submit, say "not saved, still on this screen, press again when you have signal" instead of surfacing a raw `TypeError: Failed to fetch`. (3) The paper fallback, which should exist on the wall and not only in a repository: a pre-printed intake sheet with bin, block, weight, time and initials, and a rule that the sheet is authoritative until someone has typed it in and initialled the sheet again. Paper does not need a network and the cellar already knows how to use it.
*Effort:* a day for (1) and (2). An hour for (3), and (3) is the one that actually saves the harvest.

**G-4-8. `claim_task` is a definer function with no entitlement check, and a stranded task cannot be recovered by a cellar user.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `supabase/migrations/0001_core_schema.sql:335-360`; interacts with `supabase/migrations/0002_derived_and_rls.sql:319-322`
*What is wrong:* `claim_task` is `security definer`, so it runs as the migration owner and bypasses RLS entirely, and it validates nothing about its caller. It sets `claimed_by = auth.uid()` without asserting that `auth.uid()` is non-null or that the caller has an `app_user` row. A caller with a null `uid` produces a task in status `claimed` with `claimed_by = NULL`. That row is then unreachable: `claim_task` itself requires `status = 'open'`, and `task_own_update` requires `claimed_by = auth.uid()`, which no value of `auth.uid()` satisfies against NULL. Only an admin can free it.
*Verified:* acting as `anon` with no JWT claim at all, `claim_task` returned `status = claimed, claimed_by = NULL`. A cellar user then could neither re-claim it (`task ... is not available`) nor update it (0 rows).
*Why it is not a BLOCKER:* reaching it as a true anonymous caller requires knowing a task's UUID, and `anon` cannot read `task` to learn one (verified: 0 rows). So the practical exposure is a signed-in account without an `app_user` row, which is G-4-2's population, plus anyone who ever sees a task id in a URL or a log.
*Why it matters here:* a task the board shows as claimed by nobody, that nobody can take, is exactly the kind of small wrongness that costs an afternoon during harvest and gets worked around rather than reported.
*Fix:* three lines at the top of the function, matching what `claim_account:47-49` already does correctly: raise `insufficient_privilege` when `auth.uid() is null`, and require an active `app_user` row for the caller. Optionally add `check (status <> 'claimed' or claimed_by is not null)` to `task` so the bad state cannot exist at all. One migration.
*Effort:* under an hour.

**G-4-9. Any signed-in user can write an event attributed to anybody.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:289-291`; constraint at `supabase/migrations/0001_core_schema.sql:266-267`
*What is wrong:* the policy is `with check (by_user = auth.uid() or by_sensor is not null)`. The disjunction is the hole. Setting `by_sensor` to any non-empty string satisfies the right branch and leaves `by_user` entirely unconstrained, so a cellar user can write an event stamped with the winemaker's user id. The same disjunction accepts an event with no `by_user` at all and an arbitrary sensor name, since `has_an_author` only requires one of the two to be present and nothing validates that a named sensor exists.
*Verified:* acting as the cellar account, an insert with `by_user` set to the admin's uuid and `by_sensor = 'meter-1'` was accepted. A second insert with only `by_sensor = 'anything'` was also accepted.
*Why it matters here:* the event table is the record. `by_user` is what the board shows, what an audit of who did what reads, and what any future activity costing would attribute hours against. At five to ten users the realistic failure is not malice but a client integration or a future script that sets both fields and quietly reassigns authorship; the policy should not be the thing that permits it.
*Fix:* make the branches exclusive and pin the human branch: `with check ((by_sensor is null and by_user = auth.uid()) or (by_user is null and by_sensor is not null))`. If sensors are ever real, add a `sensor` term kind and a foreign key so `by_sensor` is a picker rather than free text, which is what T1-1 asks for anyway. One migration, one policy replacement.
*Effort:* under an hour.

**G-4-10. Client scoping stops at `node`; `event`, `placement`, `lineage` and `party` are readable in full.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `supabase/migrations/0003_parties_and_products.sql:278-283` replaces only `node_read`; the blanket reads remain at `supabase/migrations/0002_derived_and_rls.sql:262-272` and `supabase/migrations/0003_parties_and_products.sql:236-237`
*What is wrong:* 0003 says in its own comment that "a client sees their own lots and is not told how many others exist," and rewrites `node_read` to deliver that. It leaves every neighbouring table at `using (true)`. `event.subject_id` carries node ids, `placement.node_id` carries node ids, `lineage` carries the whole parentage graph, and `party` carries every custom crush client's legal name.
*Verified:* the client login saw 2 of 2 events (including the one on the facility's lot, which `node_read` hides from it), 1 of 1 placements, and 2 of 2 parties. `vessel_state` behaved correctly and is not part of this finding: the client saw the facility's tank listed but with a null lot name, because the view carries `security_invoker = true` and `node_read` applied underneath.
*Why it matters here:* two custom crush clients are already real and they are other businesses. A client with a login can enumerate how many lots exist, when work happened on each, the shape of the blend graph, and the name of the other client in the building. That is commercially sensitive in a way the winemaker would not expect, and `tests/schema_assertions.sql:389-408` tests only `node`, so nothing catches it.
*Fix:* scope the three tables that carry node ids with a predicate shaped like `node_read`'s, via a helper so the rule exists once: `create function node_visible(uuid) returns boolean` wrapping `is_facility_user() or owner_id = current_party_id()`, then `using (subject_type <> 'node' or node_visible(subject_id))` on `event` and the equivalent on `placement` and `lineage`. Narrow `party_read` to `is_facility_user() or id = current_party_id()`. Add one assertion per table.
*Effort:* half a day including assertions. Additive and reversible, which is why it is DURING rather than BEFORE.

**G-4-11. Every signed-in user can read every vessel photo, which is the exact thing the bucket was made private to prevent.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `supabase/migrations/0005_account_and_walk.sql:314-328`
*What is wrong:* line 314 gives the reason the bucket is private: "A photo of a barrel shows a chalk mark with a client's lot on it." Line 326 then writes `for select to authenticated using (bucket_id = 'vessel-photos')`, which grants every signed-in account every photo in the bucket, custom crush client logins included. The rationale and the policy contradict each other in the same `do` block. The insert policy at `:336-338` is equally wide: any authenticated user may write any path in the bucket.
*Status:* UNVERIFIED against a running instance, because the storage schema does not exist on a bare Postgres and the block correctly skips itself there. The policy text is unambiguous and the conclusion follows from it; what is unverified is only whether the block executed at all on the hosted project.
*Why it matters here:* it is the same commercial boundary as G-4-10, through a channel the code explicitly identified and then left open. The bucket being private stops the public internet and does not stop the other client in the building.
*Fix:* scope the path and check it in the policy. The client already writes `${vesselId}/photo.${suffix}` (`packages/core/src/kernel.ts:280`), so the vessel id is the first path segment and the policy can use it: `using (bucket_id = 'vessel-photos' and exists (select 1 from vessel v where v.id = (storage.foldername(name))[1]::uuid and (v.owner_id is null or is_facility_user() or v.owner_id = current_party_id())))`. Same predicate on insert. One migration.
*Effort:* two hours, including confirming in the dashboard that the bucket and both policies actually exist on the hosted project.

---

## MINOR

**G-4-12. Re-photographing a vessel fails.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `packages/core/src/kernel.ts:278-286`; `supabase/migrations/0005_account_and_walk.sql:319-339`
*What is wrong:* the upload passes `upsert: true` against the deterministic path `${vesselId}/photo.${suffix}`. Upsert against an existing object is an update in storage, and the migration creates only SELECT and INSERT policies on `storage.objects`. The first photo of a barrel works; the better photo taken ten minutes later is refused. A second wrinkle: the extension comes from `file.name.split(".").pop()`, so an iPhone HEIC capture and a JPEG of the same barrel land on different paths and both persist, with `attributes.photo_path` pointing at whichever was written last.
*Why it matters here:* the walk is a one-pass inventory of fifty vessels and a bad photo is noticed immediately, on the spot, which is precisely when the retry is refused.
*Fix:* add an UPDATE policy matching the INSERT one (with the ownership predicate from G-4-11), and normalise the stored path to a single extension so a re-shoot replaces rather than accumulates.
*Effort:* an hour.

**G-4-13. The photo is uploaded before the row it belongs to.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `packages/cellar/src/walk.ts:517` and `:630`
*What is wrong:* `uploadVesselPhoto` runs, and only then does `addVessel` or `createVesselWithWine` run. If the insert fails for any reason, the object is already in the bucket with nothing referencing it and, since no DELETE policy exists on `storage.objects`, nothing can remove it. The most likely failure is mundane: a cellar user pressing "Add an empty vessel", because `vessel` is admin-write (`supabase/migrations/0002_derived_and_rls.sql:274-285`). They get a raw `new row violates row-level security policy for table "vessel"` after their photo has already uploaded.
*Why it matters here:* it is not data loss, it is an accumulating mess plus a confusing error at the exact moment someone is standing in front of a barrel. `create_vessel_with_wine` exists precisely because "four calls half-succeed" (`supabase/migrations/0005_account_and_walk.sql:225-228`), and the photo sits outside the transaction that reasoning produced.
*Fix:* write the row first, then upload, then patch `attributes.photo_path`. If the upload fails the vessel still exists and the photo can be retaken. Separately, hide or disable the vessel buttons for non-admins on the home screen (`packages/cellar/src/walk.ts:249-252`) rather than letting the database deliver the refusal.
*Effort:* two hours.

**G-4-14. An admin can rewrite event history in place, leaving no trace.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:287-295`
*What is wrong:* the comment reads "anyone may record, nobody may rewrite history. Corrections are new events, not edits." The next statement creates `event_admin_update`, which lets an admin change any column of any event, including `at`, `data` and `by_user`, with no audit row and no indication in the record that it happened. `CLAUDE.md:52-53` states the rule as absolute, and axiom T0-5 is named in 0001's header as enforced.
*Verified:* acting as the admin, `update event set data = ..., at = now() - interval '3 days'` changed every row. Deletes are correctly refused: the same admin's `delete from event` removed 0 rows, because no DELETE policy exists. Append-only holds against deletion and not against mutation.
*Why it matters here:* the winemaker is the admin, and the one thing he will want to do at 11pm is fix a Brix number he typed wrong. The system should let him, and it should record that he did, because the value of provenance tracking is exactly that it survives someone's good intentions.
*Fix:* one of two, both cheap. Either drop `event_admin_update` and require corrections to be new events, which is what the comment says and what the client already does, or keep it and add an `event_revision` table written by a trigger capturing the old row, the new row, the actor and the time. The second is more honest about how a small winery actually operates.
*Effort:* two hours either way.

**G-4-15. A cellar user can rewrite the operation and subject of a task they hold.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:319-322`
*What is wrong:* `task_own_update` gates on the row, not on the columns. Its `using` and `with check` both test `claimed_by = auth.uid() or assignee = auth.uid()`, which is what lets someone mark their own task done. It also lets them change `operation_id`, `subject_id`, `instructions`, `due_from` and `due_to` on that row, so a task to top B23 can become a task to bottle the client's lot, and the board will show the new version as though it were assigned.
*Verified:* acting as the cellar account on a task it held, a single update changed the operation, the subject and the instructions, and set status to done. One row affected.
*Why it matters here:* it is not an attack, it is drift. The task board is the thing three people coordinate through, and a task that quietly changes meaning after being claimed is a coordination failure rather than a security one. The insert path is correctly closed (verified: a cellar user's `insert into task` was refused), so this is only about rows an admin already created.
*Fix:* restrict the columns. A `before update` trigger that raises if any column other than `status`, `claimed_at` and `claimed_by` changed when `not is_admin()` is the smallest version and needs no policy rewrite.
*Effort:* an hour.

**G-4-16. Topping compares variety, vintage and product type, and not owner.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `supabase/migrations/0004_terms_and_effects.sql:149-152` (the seeded predicate) against `:451-455` (the comparable surface, which builds an `owner` key)
*What is wrong:* `topping_check` assembles a jsonb object carrying `variety`, `vintage`, `product_type` and `owner`, then compares only the fields the operation's predicate names. The seeded predicate is `{"match": ["variety", "vintage", "product_type"]}`. `owner` is built and never consulted, which reads as an oversight rather than a decision: the plumbing for it is right there.
*Verified:* `topping_check` returned `ok = true` for pouring a facility-owned lot into a vessel holding a client-owned lot.
*Why it matters here:* two custom crush clients are real. Topping a client's barrel with the facility's wine is not a data problem, it is someone else's wine and a TTB one. The check exists to be asked before pouring, which is the right moment to catch it.
*Fix:* one row. `update term set attributes = jsonb_set(attributes, '{predicate,match}', '["variety","vintage","product_type","owner"]') where kind = 'operation' and value = 'topping';` Ship it as a migration so a fresh install gets it too. Confirm with the winemaker first: topping a client's barrel from the client's own other barrel is fine and this change permits that correctly, but there may be a practice where the facility tops a client's wine by arrangement, in which case the answer is a warning rather than a refusal.
*Effort:* minutes, plus the question.

**G-4-17. Only an admin can close a placement, so racking will be refused the day it is built.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:299-312`
*What is wrong:* the loop gives `node`, `lineage` and `placement` an open insert and an admin-only update. Moving wine out of a vessel means setting `placement.to_at`, which is an update. So a cellar user can put wine into a vessel and can never take it out. Racking, consolidating and distributing lees are all in this shape.
*Why it is AFTER:* movements are Stage 2 and graded Specified in `docs/status-ledger.md`, so nothing is broken today. It is filed here so that whoever builds the rack screen finds it written down rather than discovering it against a live policy.
*Fix:* when the movement screens are built, do it as a `security invoker` function that closes the old placement and opens the new one in one transaction, the way `create_vessel_with_wine` composes ordinary writes, plus a narrow `placement_close` policy permitting an update that sets `to_at` and changes nothing else.
*Effort:* part of the movement work, not separate.

**G-4-18. Migration 0002 cannot be applied to a bare Postgres, which 0005 takes trouble to allow.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:332-334` against `supabase/migrations/0005_account_and_walk.sql:302-312`
*What is wrong:* 0005 guards its storage block with an `information_schema.schemata` check and explains why at length: "these migrations have to stay applicable to a bare database for anyone verifying them without Docker." 0002 ends with three unguarded `alter publication supabase_realtime add table` statements, and `supabase_realtime` is created by the Supabase stack, not by Postgres.
*Verified:* applying the migrations in order to a stock Postgres 16 failed at `0002:332` with `publication "supabase_realtime" does not exist`. Creating the publication by hand let all five apply cleanly, which is how this review's verification was done.
*Why it matters here:* the stated goal is that a winemaker forking this can verify the schema without Docker. Today they get a failure two migrations in, at a line about realtime that has nothing to do with why they were reading.
*Fix:* wrap the three statements in the same `do $$ ... if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then raise notice ...; return; end if; ... end $$;` shape that 0005 already uses. Six lines, same idiom, same file family.
*Effort:* minutes.

---

## NIT

**G-4-19.** Grouped, no argument attached to any of them.

- `supabase/config.toml:10` exposes `graphql_public` alongside `public`. Nothing in the client uses GraphQL (`packages/core/src/kernel.ts` is PostgREST and storage only). pg_graphql respects RLS so this is not a hole, but it is an unused surface on a system whose whole boundary is RLS. Remove it from `schemas`.
- Every `security definer` function pins `set search_path = public` (`0001:100`, `0001:339`, `0003:257`, `0003:270`, `0005:41`, `0005:135`). `set search_path = ''` with schema-qualified references is the stronger form and costs only the qualification. Belt and braces at this scale, worth doing when one of these functions is next edited.
- `.gitignore:24-33` covers dumps, backups, photos and every `.env` variant, and does not cover `*.csv` or `*.xlsx`. S-6 is specifically about a Wine Meister export, and a spreadsheet of real lot data dropped into the repo to look at would be committed. Two lines.
- `@zxing/library@0.21.3` (`packages/cellar/package.json:9`) brings one runtime dependency (`ts-custom-error`) and one optional, so the tree cost is nil, but `BrowserMultiFormatReader` (`packages/cellar/src/scan.ts:78`) pulls every barcode format the library supports when the cellar reads two. Importing the specific readers cuts the bundle, which matters on barn wifi. Not a correctness issue and not urgent. The exact byte saving is UNVERIFIED; it was not measured.
- No CI exists. `bun run typecheck`, `bun run lint` and `psql -f tests/schema_assertions.sql` are the definition of done in `CLAUDE.md:81-93` and nothing runs them except a person remembering to. A single workflow file running those three on push would make the definition of done enforceable rather than aspirational. It needs no new dependency in this tree.

---

## NOT A DEFECT

**G-4-20.** Checked, and each of these holds. Listed because a reviewer would expect several of them to be wrong, and because the flags above are only worth reading if the passes are honest.

- **RLS coverage is complete.** All 15 tables in `public` have `relrowsecurity = true` and at least two policies each. No table with RLS and no policy, and none with a policy and no RLS. Verified by querying `pg_class` joined to `pg_policy`.
- **The anon key gets nothing through PostgREST.** Every policy is written `to authenticated`, so the `anon` role falls through to the RLS default deny. Verified: as `anon`, `select count(*)` returned 0 from `node`, `vessel_state` and `task`, against a database holding rows in all three. The one exception is `claim_task`, which is G-4-8.
- **The three views carry `security_invoker = true`.** `supabase/migrations/0003_parties_and_products.sql:137-138,181-182` and `0004:271,329,358`. This is the single most commonly missed thing in a Supabase schema: a view defaults to running as its owner, which would have handed every client the whole cellar through `lot_state` while `node_read` refused it. The comment at `0003:178-180` shows it was reasoned about rather than stumbled into. Verified: the client login saw the facility's tank in `vessel_state` with a null lot name, which is the policy applying underneath the view.
- **Events cannot be deleted by anyone.** No DELETE policy exists on `event`. Verified: an admin's `delete from event` removed 0 rows and raised nothing. Append-only holds against deletion, which is the half that matters most. The mutation half is G-4-14.
- **`refuse_self_granted_standing` closes T0-4 at the write path.** `0005:105-125`. Nothing can be inserted with `provenance = 'confirmed'` on either `node` or `event`, whoever is writing, and `confirm_event` is the only route to `confirmed` and requires `is_admin()`. Verified: `confirm_event` called as `anon` raised `only a verifier may confirm`.
- **`create_vessel_with_wine` is invoker on purpose and grants nothing.** `0005:229-231`. It composes ordinary writes and every table's own policy still decides. This is the right call and the comment says why. `generate_inferred_history` is likewise invoker and writes `by_user = auth.uid()`, so it cannot manufacture authorship it does not have.
- **`claim_account` handles its own race correctly.** The advisory lock at `0005:59` closes the two-simultaneous-signups window, and the function is idempotent for a reload. The defect in it is who becomes admin (G-4-3), not how it concurrently decides.
- **No secret has ever been committed.** Checked the full history, not just the tip: `git log --all -p` grepped for service role keys, JWT prefixes, passwords and secrets returns only the empty `VITE_SUPABASE_ANON_KEY=` line in `.env.example` and the two references to that variable name in source. `.gitignore:13-22` covers `.env`, `.env.*` with a negation for the example, and `supabase/.env` and `supabase/.temp/`. The only files ever deleted in history are three `.gitkeep` placeholders.
- **Policy cost is a non-issue at this scale, and the pattern is the slower one.** Every policy calls `auth.uid()`, `is_admin()`, `is_facility_user()` and `current_party_id()` bare rather than wrapped in `(select ...)`, so Postgres evaluates them per row rather than once as an InitPlan. Verified by `explain analyze`: `node_read` shows `Filter: (is_facility_user() OR (owner_id = current_party_id()))` on a sequential scan, and the admin write path shows `Filter: is_admin()`. At 50 vessels and low thousands of events this is a few hundred index lookups on a table with fewer than ten rows, which is not measurable. It is worth knowing that the fix is one character per call site if a query is ever slow, and worth not doing until one is.
- **The dependency tree is genuinely thin and the versions are current.** Four direct dependencies: `@supabase/supabase-js` 2.116.0, `@zxing/library` 0.21.3, `vite` 7.3.6, `@biomejs/biome` 2.5.12, plus `typescript` 5.9.3. 93 entries in `bun.lock`, of which roughly 50 are platform-specific esbuild, rollup and biome binaries that resolve to one each at install. The real transitive runtime surface is `tslib`, `ts-custom-error`, `@supabase/phoenix` and `iceberg-js`. Carets in the manifests are pinned by the committed lockfile. No unmaintained package, nothing large pulled for a small use, and nothing to replace.
- **The licence is complete and correct.** `LICENSE` is the full Apache 2.0 text with the copyright line filled in at `:189` rather than left as the `[yyyy] [name of copyright owner]` placeholder, and `package.json:5` matches. `README.md:55-59` gives the reasoning.

---

## 3. Answers to the ten questions, where a finding does not already carry them

**1. What each role can do, per table.** `anon` can do nothing through PostgREST anywhere: every policy is `to authenticated` and the default deny holds (verified). Its one reach into the database is `claim_task` (G-4-8). For `authenticated`, read is `using (true)` on every table except `node`, which is scoped by `node_read`. Write splits three ways. Admin-only, verified refused for a cellar user: `app_user`, `location`, `block`, `vessel`, `template`, `template_step`, `party`, `vessel_code`, `term`, and `task` inserts. Open to any authenticated user: inserts on `node`, `lineage` and `placement` (`with check (true)`), inserts on `event` (subject to the disjunction in G-4-9), and inserts on `task_claim_log` where `user_id = auth.uid()`. Updates and deletes on `node`, `lineage` and `placement` are admin-only, updates on `event` are admin-only, deletes on `event` are nobody's. `task` updates are admin, or the holder, with the column problem in G-4-15.

**2. Policy correctness and cost.** Correctness failures are G-4-2, G-4-4, G-4-9, G-4-10 and G-4-15. Cost is covered in G-4-20: bare per-row calls, confirmed by `explain analyze`, irrelevant at 50 vessels and tens of thousands of rows.

**3. Definer functions.** Six exist. `is_admin` (`0001:95`), `claim_task` (`0001:335`), `current_party_id` (`0003:252`), `is_facility_user` (`0003:265`), `claim_account` (`0005:37`), `confirm_event` (`0005:131`). All six pin `search_path = public`, which is adequate and not the strongest form (G-4-19). Four of the six are the right size and validate correctly: `is_admin` and `current_party_id` read only the caller's own row, `claim_account` refuses a null `uid`, `confirm_event` requires `is_admin()` and moves only `inferred` to `confirmed`. `is_facility_user` is the wrong size in the direction that grants (G-4-2, G-4-4). `claim_task` validates nothing about its caller (G-4-8).

**4. Auth configuration against the client.** The disagreements: `config.toml` disables signup while `walk.ts:126-134` offers it (G-4-1); `site_url` and `additional_redirect_urls` name only `localhost:5173` while the app is meant to be served to phones (G-4-6). What a user sees when signup is off and they press the button: a red banner containing Supabase's raw `Signups not allowed for this instance`, with no explanation of how to get an account. `jwt_expiry = 3600` with `enable_refresh_token_rotation = true` and `refresh_token_reuse_interval = 10` are Supabase's defaults and are reasonable; the one thing worth knowing is that a phone that loses signal in the ten-second window between the server rotating a refresh token and the client storing it will be signed out, which on barn wifi will happen occasionally. Raising the interval to 30 is a dashboard change if it proves annoying, and is not worth doing pre-emptively.

**5. Storage.** One bucket, `vessel-photos`, created private (`0005:315-317`), which is the right default and the comment gives the right reason. Upload path is `${vesselId}/photo.${extension}` from the client. Reads go through `createSignedUrl(path, 600)` (`kernel.ts:294`), so a ten-minute expiry, which is sensible and bounded. No public bucket is created anywhere and no unbounded URL is generated. The problems are who may read (G-4-11), the missing update policy (G-4-12), the ordering against the row write (G-4-13), and the bucket carrying no `file_size_limit` or `allowed_mime_types` of its own, so it inherits the global 50MiB and accepts any content type the client declares. A 50MB accidental video from a phone on barn wifi is a real annoyance, and an uploaded `text/html` file would be served with that content type from the storage origin, which is a small stored-XSS surface on a domain that is not the app's. Both are closed by adding `file_size_limit` and `allowed_mime_types` to the bucket insert: one line, and it belongs with the G-4-11 migration. Nothing can delete an object, including an admin, so a wrong photo is permanent.

**6. Secrets and the repository.** Clean, in the tree and in the history. Detail in G-4-20. The one gap is the missing spreadsheet pattern in `.gitignore` (G-4-19).

**7. Dependencies.** Covered in G-4-20. Nothing to change, nothing to replace, and no finding here proposes adding one.

**8. Availability during harvest.** G-4-7.

**9. Backup and restore.** G-4-5.

**10. Deployment.** G-4-6.

---

## 4. Closing

The parts of this system that are usually wrong are right. RLS is enabled everywhere with a policy on every table, the anon key genuinely gets nothing, the views carry `security_invoker` (which is the mistake almost everyone makes), the append-only rule holds against deletion, nothing writes `confirmed` at insert, no secret has ever been committed, and the dependency set is four packages that are all current. The verification in this review was done by running the migrations, and they applied in order and produced the schema they describe.

The failures cluster in one place and share one shape: the boundary is drawn correctly for the users the design imagined and defaults open for the users it did not. `coalesce(..., true)` on a missing party row, `with check (true)` on the insert paths, `using (true)` on the tables next to the one that was scoped, no caller check on the definer function that bypasses RLS. Each is small and each defaults toward access. G-4-2 and G-4-4 are the same line and fixing it costs an hour.

The largest real risk is not in the SQL. It is that the one setting the entire model depends on, whether a stranger can create an account, lives in a dashboard that this repository does not describe, check, or test, while the client ships a button that invites them to try. That is G-4-1, and it is the one to close first.

Second to it, and not a code problem at all: there is no backup you have restored from and no way to deploy or roll back. Harvest is weeks away. An hour spent confirming the backup plan and rehearsing one restore is worth more than any finding below G-4-1 in this document.
