# R-6: intake, and the failures that cannot be walked back

**Target:** `github.com/VigneronVitae/VSV-Management-Software`, branch `main`
**Date of review:** 2026-09-12

---

## Header

### 1. Tier and route

**Tier A.** Full tree on disk at a pinned SHA. Route 1 succeeded on the first
attempt: `git clone https://github.com/VigneronVitae/VSV-Management-Software`,
run through the Bash tool. No fallback route was needed and none was used.
Citations are `path:line` throughout.

### 2. Commit

```
$ git rev-parse HEAD
c3eae3c7c262544e4b2e29526b513c964c6852fe
$ git rev-parse --abbrev-ref HEAD
main
$ git log -1 --format='%H %ad %s' --date=iso
c3eae3c7c262544e4b2e29526b513c964c6852fe 2026-09-08 23:31:36 +0000 File the walk session report, and correct the reverse dependency edges
$ git status --porcelain | wc -l
0
```

This is the baseline commit exactly, not a descendant and not an ancestor.
Working tree clean. Everything below was read at this SHA and nothing was
re-fetched.

### 3. Canaries

| Check | Result |
|---|---|
| Branch | `main`, not `claude/sql-files-to-markdown-i31rob` |
| Tree holds more than `LICENSE` | Yes, 42 entries |
| `supabase/migrations/0005_account_and_walk.sql` | Present |
| `tests/schema_assertions.sql` | Present |
| `packages/cellar/src/walk.ts` | Present |
| `docs/session-reports/2026-09-08-walk.md` | Present |
| Tracked file count | 42, matching |

### 4. Execution results

Postgres 16.13 on Ubuntu 24.04, local cluster, shim built to the R-6 spec:
`auth` schema with a `users` table; `auth.uid()` reading
`request.jwt.claim.sub` first and falling back to the `request.jwt.claims`
blob; roles `anon`, `authenticated`, `service_role` with default grants on
`public`; an empty `supabase_realtime` publication; **no `storage` schema**.

| Number | Result |
|---|---|
| Migrations applying clean from empty | **5 of 5.** Two notices only: `pgcrypto` already exists, and the storage skip |
| Assertions in `tests/schema_assertions.sql` | **28 ran, 28 passed**, 9 sections, exit 0 |
| Storage-guarded block in `0005` | **Skipped.** `NOTICE: storage schema absent, skipping the vessel-photos bucket` |

The assertion count is 28 with the storage block skipped. An earlier report in
this series reporting a different number was running a shim that stood storage
up; the two numbers are the same test file under two shims and the difference
is that block.

Every probe below ran under `set role authenticated` with
`request.jwt.claim.sub` set to a real `app_user` id, never as the migration
owner. Roles probed: an admin, a cellar user, a client login with a party row,
an authenticated principal with no `app_user` row, and an unset claim standing
in for `anon`. **80 probes were run.** Probes are identified in findings by
their label.

### 5. File table

Every file in the tree, whole, at `c3eae3c`. "Read" means read end to end in
this review; the rest are on disk and were grepped rather than read.

| Path | State | Lines | Read |
|---|---|---|---|
| `supabase/migrations/0001_core_schema.sql` | whole | 370 | yes |
| `supabase/migrations/0002_derived_and_rls.sql` | whole | 334 | yes |
| `supabase/migrations/0003_parties_and_products.sql` | whole | 284 | yes |
| `supabase/migrations/0004_terms_and_effects.sql` | whole | 519 | yes |
| `supabase/migrations/0005_account_and_walk.sql` | whole | 340 | yes |
| `tests/schema_assertions.sql` | whole | 412 | head + executed in full |
| `packages/core/src/kernel.ts` | whole | 297 | yes |
| `packages/core/src/types.ts` | whole | 125 | yes |
| `packages/core/src/env.ts` | whole | 27 | yes |
| `packages/core/src/index.ts` | whole | 6 | yes |
| `packages/cellar/src/walk.ts` | whole | 805 | yes |
| `packages/cellar/src/scan.ts` | whole | 125 | yes |
| `packages/cellar/src/sticky.ts` | whole | 35 | yes |
| `packages/cellar/src/pickers.ts` | whole | 201 | yes |
| `packages/cellar/src/index.ts` | whole | 3 | yes |
| `packages/cellar/src/ui.ts` | whole | 141 | grepped |
| `packages/cellar/docs/spec.md` | whole | 328 | sections 3-7 |
| `apps/web/src/index.ts` | whole | 27 | yes |
| `apps/web/src/app.css` | whole | 330 | no |
| `apps/web/index.html` | whole | 14 | no |
| `apps/web/vite.config.ts` | whole | 8 | no |
| `apps/web/package.json` | whole | 19 | no |
| `apps/web/.env.example` | whole | 4 | no |
| `CLAUDE.md` | whole | 130 | hard rules, done, removed |
| `README.md` | whole | 59 | yes |
| `package.json` | whole | 24 | yes |
| `docs/status-ledger.md` | whole | 112 | yes |
| `docs/sorry-ledger.md` | whole | 156 | yes |
| `docs/compost-ledger.md` | whole | 72 | no |
| `docs/methodology-lineage.md` | whole | 334 | grepped |
| `docs/session-reports/2026-09-08-walk.md` | whole | 202 | grepped |
| `docs/session-reports/2026-09-08-scaffold.md` | whole | 153 | grepped |
| `docs/session-reports/index.md` | whole | 33 | no |
| `supabase/config.toml` | whole | 56 | no |
| `packages/core/package.json` | whole | 10 | no |
| `packages/cellar/package.json` | whole | 11 | no |
| `tsconfig.json` | whole | 40 | no |
| `biome.json` | whole | 30 | no |
| `bun.lock` | whole | 218 | no |
| `.gitignore` | whole | 47 | no |
| `LICENSE` | whole | 201 | no |
| `supabase/seed/.gitkeep` | whole | 0 | n/a |

---

## Findings at a glance

| id | Verdict | One line |
|---|---|---|
| R-6-1 | EXPLOITABLE | A cellar user is shown every walk button and refused by RLS only after filling the form |
| R-6-2 | EXPLOITABLE | Client ids are minted inside the submit handler, so a retry has a different identity |
| R-6-3 | EXPLOITABLE | Only an exactly-retyped vessel name or an exactly-retyped code stops a double submission |
| R-6-4 | EXPLOITABLE | A committed write is painted as a failure when the read after it fails |
| R-6-5 | EXPLOITABLE | A cellar user cannot close a placement, and the refusal is zero rows and no error |
| R-6-6 | EXPLOITABLE | The first lineage row closes the parent and a cellar user cannot undo it |
| R-6-7 | EXPLOITABLE | Orphan events are accepted and the one tool meant to find them is `exit 1` |
| R-6-8 | EXPLOITABLE | `by_sensor` lets one user sign an event with another user's name |
| R-6-9 | EXPLOITABLE | An admin rewrites a recorded weight, its time, its author and its provenance in place |
| R-6-10 | EXPLOITABLE | `generate_inferred_history` is not idempotent and any authenticated principal may call it |
| R-6-11 | LATENT | Lineage fractions into one child are unconstrained; `block_composition` returns 3.0 |
| R-6-12 | LATENT | A bin's weight, its unit and its block are three independently optional columns |
| R-6-13 | LATENT | A cellar user cannot add a block, so a pick from an unrecorded block records unattributed |
| R-6-14 | LATENT | Volume may exceed capacity, and a placement may open on a closed node |
| R-6-15 | LATENT | An event may be born back-dated, and nothing compares `at` against `created_at` |
| R-6-16 | DIVERGENT | Two of the six commands in CLAUDE.md's definition of done fail by construction |
| R-6-17 | DIVERGENT | `kernel.ts` and `CLAUDE.md` state an offline-identity property the call sites do not have |
| R-6-18 | BY DESIGN | The walk needs an admin, and `0004` says so |
| R-6-19 | NOT A DEFECT | `create_vessel_with_wine` is genuinely one transaction. **Prediction falsified** |
| R-6-20 | NOT A DEFECT | `bind_vessel_code` and `claim_account` are idempotent exactly as advertised |
| R-6-21 | NOT A DEFECT | Cellar users can neither update nor delete an event, and nobody can delete one |
| R-6-22 | UNVERIFIED | What the user sees on timeout, and on a write that lands after they gave up |
| R-6-23 | UNVERIFIED | Whether PostgREST reports an RLS-refused UPDATE to the client as success |
| R-6-24 | UNVERIFIED | The camera decode path, and its double-fire rate on one barcode |
| R-6-25 | UNVERIFIED | The storage bucket, and the photo uploaded under a vessel id that may never exist |

---

## EXPLOITABLE

**R-6-1. A cellar user is shown every walk button and refused by RLS only after filling the form.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/cellar/src/walk.ts:234-253`, against `packages/cellar/src/walk.ts:200-210` and `supabase/migrations/0002_derived_and_rls.sql:274-285`.
*What is wrong:* `homeScreen` renders all four write buttons with no reference to `user.role`, and prints the role in its lede without acting on it. Only `facilityScreen` checks the role, and only for the facility party. Every structural write the walk performs is admin-only, so a cellar user reaches the end of a full form and is refused by the database. Probed W1, W2, W3, W5 as a cellar user: `create_vessel_with_wine` gives `42501 new row violates row-level security policy for table "vessel"`, and the inline term, inline location and code-bind paths give the same for `term`, `location` and `vessel_code`.
*How it surfaces:* the second person on the crew walks a row of barrels, types a barrel into the form, presses the button and gets a sentence about row-level security. Nothing on the screen says an administrator is needed, and the same wall is behind every other button.
*Resolves when:* the walk screens are gated on `user.role === 'admin'` the way `facilityScreen` already is, or the policies are widened to let a cellar user do the walk.
*Load-bearing:* yes. It is the difference between one person walking the cellar and one person walking the cellar while the other five discover one at a time that they cannot.

**R-6-2. Client ids are minted inside the submit handler, so a retry has a different identity.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/cellar/src/walk.ts:513`, `packages/cellar/src/walk.ts:626`, `packages/cellar/src/walk.ts:635`; `packages/core/src/kernel.ts:113`, `:162`, `:181`, `:214`. Against `packages/core/src/kernel.ts:32-33` and `CLAUDE.md:60-61`.
*What is wrong:* `newId()` is called inside the button callback and inside each kernel insert, so the uuid is created at the moment the request is built rather than when the form is opened. The stated purpose of a client-generated id is that an offline write has identity before the server sees it; an identity that is regenerated on every attempt is not that. Probed P6b (ids held across two submissions) is refused on `vessel_pkey`, which is the behaviour the design wants. Probed P6c, which is what the code actually sends on a retry, is refused on `vessel_type_name_key` instead, and that only holds while the name is character-identical.
*How it surfaces:* silently, and then loudly. The barn has intermittent signal, the request times out, the person presses the button again, and whether the second attempt is a duplicate or a refusal turns on whether they retyped the name the same way.
*Resolves when:* the id is minted when the form opens, held for the life of that form, and reused on every retry, with the server treating a repeat of a known id as the same write rather than as a collision.
*Load-bearing:* yes. Every idempotency claim in the repository rests on this and none of it holds.

**R-6-3. Only an exactly-retyped vessel name or an exactly-retyped code stops a double submission.**
*Verdict:* EXPLOITABLE.
*Locator:* `supabase/migrations/0001_core_schema.sql:159-187` (no unique constraint on `node` beyond its key), `supabase/migrations/0004_terms_and_effects.sql:222` (`vessel_type_name_key`), `supabase/migrations/0003_parties_and_products.sql:115-122` (`vessel_code.code` unique), `packages/cellar/src/scan.ts:46`.
*What is wrong:* `node` carries no uniqueness on anything but its primary key, so the lot half of a double submission has no guard of its own. The vessel name and the scan code are the whole defence, and both compare raw text. Probed P6e: a second `create_vessel_with_wine` with fresh uuids, the vessel name retyped as `B 40b`, and the code list not re-entered, succeeds completely and produces a second vessel, a second lot named `Chardonnay 2024` and a second placement. Probed X10: `B23` and `B23 ` are two vessels; nothing trims a vessel name anywhere. Probed X11 and X12: `" QR-9 "` and `"QR-9"` are two codes bound to two different vessels, which is precisely the sticker-moved-to-the-wrong-barrel failure `0003:124-126` says the unique index refuses. Probed C1: `B23` and `b23` are two codes on two vessels. `scan.ts:46` trims but does not case-fold, and it trims in the client only.
*How it surfaces:* two lots of the same wine in the books, each with part of the record, and no way afterwards to say which one the fruit went into.
*Resolves when:* codes are normalised (trim and case-fold) at the database boundary rather than in one client, vessel names are trimmed there too, and the lot carries an identity check of its own rather than riding on the vessel's.
*Load-bearing:* yes. This is the mechanism by which R-6-2 becomes a duplicate rather than a refusal.

**R-6-4. A committed write is painted as a failure when the read after it fails.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/cellar/src/walk.ts:625-657`, with `packages/cellar/src/walk.ts:676-683`.
*What is wrong:* the try block wraps the write and the render together. `createVesselWithWine` returns, `capture.stop()` runs, and then `show(await resultScreen(...))` makes two further network reads, `vessels()` and `nodeEvents()`. Either of those throwing lands in the same `catch` as a failed write and paints an error banner, on a form whose write already committed. The client has no way to distinguish the two cases and neither does the person holding it.
*How it surfaces:* signal drops in the second between the write landing and the read going out. The person sees an error, presses the button again, and gets a duplicate-key message about a vessel they now believe does not exist.
*Resolves when:* the write's try block ends at the write, and a failure to render the result is reported as a failure to render rather than as a failure to save.
*Load-bearing:* yes. It converts a transient network fault into a user who is actively trying to double-write.

**R-6-5. A cellar user cannot close a placement, and the refusal is zero rows and no error.**
*Verdict:* EXPLOITABLE.
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:299-312`, `supabase/migrations/0001_core_schema.sql:229-244`.
*What is wrong:* the loop grants `node`, `lineage` and `placement` an open insert policy and an admin-only update policy. Closing a placement is setting `to_at`, which is an update. A cellar user can therefore open a placement and never close one. Probed P4 and X3 as a cellar user: `update placement set to_at = now()` affects **0 rows and raises nothing**. Probed P2: a second open placement for the same lot in a second vessel is accepted, because a lot may legitimately span vessels. The two together mean a rack recorded by the person doing it leaves the lot in both vessels. `lot_state` then reports `vessel_count 2` and `total_volume_l 1980` for a lot of 1000 L.
*How it surfaces:* silently, and then as a volume figure that is roughly double. The `placement_one_lot_per_vessel` index catches the case where somebody else's wine is put into the vessel next, so the corruption surfaces days later as a refusal on an unrelated action.
*Resolves when:* the move is a kernel function owning both the close and the open in one transaction, or cellar users get an update policy scoped to `to_at`.
*Load-bearing:* yes. This is the most severe finding in the report. Every other defect here produces a wrong record; this one produces a wrong record while telling the writer it succeeded.

**R-6-6. The first lineage row closes the parent and a cellar user cannot undo it.**
*Verdict:* EXPLOITABLE.
*Locator:* `supabase/migrations/0001_core_schema.sql:206-223`, `supabase/migrations/0002_derived_and_rls.sql:299-312`.
*What is wrong:* `lineage_closes_parent` fires after each row, so a press assembled as three separate lineage inserts closes the first bin the moment the first row lands. Probed L1: Bin 1 goes to `closed` with `closed_at` set while Bins 2 and 3 are still open. Probed L2 and L3 as the cellar user who just did it: reopening the node is 0 rows and deleting the lineage row is 0 rows, both silent. There is no press function in the schema, so press assembly is necessarily several client calls, which is exactly the shape question 4 asks about and the one that cannot roll back. The path is reachable today through the REST surface, since `lineage` carries an open insert policy to `authenticated`, rather than through a screen.
*How it surfaces:* a bin scanned into the wrong press at 6am is closed against the wrong child, permanently, and the person who did it can neither reverse it nor see that they need to.
*Resolves when:* a press is one kernel function that takes its whole parent list and writes the lineage rows together, and the trigger fires on that set rather than per row. Sorry S-3 names the adjacent half of this (partial consumption) and does not name this half.
*Load-bearing:* yes. Press is build order 3 and inherits this as written.

**R-6-7. Orphan events are accepted and the one tool meant to find them is `exit 1`.**
*Verdict:* EXPLOITABLE.
*Locator:* `supabase/migrations/0001_core_schema.sql:250-275`, `package.json:15`, against `CLAUDE.md:92-97`.
*What is wrong:* `event.subject_id` is `uuid not null` with no foreign key, deliberately, per S-4. Probed E1: an event carrying `{"brix": 24.1, "weight_lbs": 880}` against a node id that names no row is accepted. Probed E2: an event whose `subject_type` says `node` while its `subject_id` is in fact a party is accepted. The ledger's stated remedy is `doctor`; `package.json:15` defines `doctor` as `echo 'doctor: not implemented...' && exit 1`, and `README.md:38-40` says that is on purpose. So nothing checks, by design, and `CLAUDE.md:95-97` calls `doctor` "the only thing standing between the schema and orphaned records".
*How it surfaces:* silently, never. A bin weight written against an id whose node insert failed is stored, is invisible to every view, and has no second source.
*Resolves when:* `doctor` exists and runs on a schedule, or the intake write path is a kernel function that writes the node and its first events in one transaction so the orphan cannot be created.
*Load-bearing:* yes. It is the specific mechanism by which a weight recorded at the scale disappears.

**R-6-8. `by_sensor` lets one user sign an event with another user's name.**
*Verdict:* EXPLOITABLE.
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:289-291`.
*What is wrong:* the policy reads `with check (by_user = auth.uid() or by_sensor is not null)`. The `or` means the authorship check is skipped entirely whenever `by_sensor` is set, rather than the two columns being alternatives for one row. Probed E3: cellar user `a2` inserts an event with `by_user` set to admin `a1` and `by_sensor` set to `'scale-1'`, accepted. Probed E4: the same insert without `by_sensor` is refused. The `has_an_author` check at `0001:266-267` is likewise satisfied by either column, so the row is internally consistent and wrong.
*How it surfaces:* a weight in the record attributed to someone who was not at the scale. Visible only if that person is asked about it.
*Resolves when:* the check becomes `(by_user = auth.uid() and by_sensor is null) or (by_user is null and by_sensor is not null)`, so a row is signed by exactly one of the two.
*Load-bearing:* yes for T0-3. Provenance that can name the wrong person is not provenance.

**R-6-9. An admin rewrites a recorded weight, its time, its author and its provenance in place.**
*Verdict:* EXPLOITABLE.
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:293-295`, against `supabase/migrations/0002_derived_and_rls.sql:287-288`, `packages/cellar/docs/spec.md:56-57`, `CLAUDE.md:52-53`, `supabase/migrations/0005_account_and_walk.sql:127-155`.
*What is wrong:* the comment three lines above the policy says "anyone may record, nobody may rewrite history. Corrections are new events, not edits." `event_admin_update` then grants admins a full update on `event`. Probed as an admin: A1 rewrites `weight_lbs` from 880 to 440, one row, no trace. A2 moves an `observed` event straight to `confirmed`, routing around the inferred-only rule that `confirm_event` (`0005:144-151`) exists to enforce and that `0005:127-130` calls the whole content of T0-4. A3 moves `at` back a year. A4 reassigns `by_user`. The `refuse_self_granted_standing` trigger (`0005:105-125`) is `before insert` only, so none of this touches it.
*How it surfaces:* silently, never. The bin weight is the number with no second source, and an admin can change it with nothing recording that it changed.
*Resolves when:* the update policy is narrowed to the columns a correction actually needs (none, if corrections are new events), or every update writes a prior-value row.
*Load-bearing:* yes. T0-5 is stated in three places and enforced against cellar users only.

**R-6-10. `generate_inferred_history` is not idempotent and any authenticated principal may call it.**
*Verdict:* EXPLOITABLE.
*Locator:* `supabase/migrations/0005_account_and_walk.sql:169-219`, with `supabase/migrations/0002_derived_and_rls.sql:75-92`.
*What is wrong:* the function has no guard against having run before on the same node, and the events it writes take server-generated ids, so there is no client identity to collide on. Probed H1 then H2 with a two-step template: two calls, four events, the second set indistinguishable from the first. Probed W6: a cellar user calls it directly and it writes, because the events pass `event_insert` on `by_user = auth.uid()`. `inferred_fraction` is the number that says how much of a lot was never witnessed, and it moves with every extra call.
*How it surfaces:* a lot with twice the history it should have, all of it correctly stamped `inferred` and none of it distinguishable. Today `template` is empty (S-17) so every call returns zero, which is why this has not bitten.
*Resolves when:* the function refuses to run against a node that already carries inferred events from the same template, or the generated events carry deterministic ids derived from node and step.
*Load-bearing:* yes once the six protocols are encoded, which is the condition S-17 already names.

---

## LATENT

**R-6-11. Lineage fractions into one child are unconstrained, and `block_composition` returns 3.0.**
*Verdict:* LATENT.
*Locator:* `supabase/migrations/0001_core_schema.sql:195-204`, `supabase/migrations/0002_derived_and_rls.sql:29-59`.
*What is wrong:* `fraction` is checked per row, `> 0 and <= 1`, and nothing checks the sum into a child or out of a parent. Probed: three bins at fraction 1.0 into one press load is accepted; `node_bin_shares` returns 1.0 for each and `block_composition` returns `share 3.0` for a single block. The natural client encoding for "these three bins went into this press" is fraction 1.0 per bin, because from each bin's side all of it went in, so this is the likely first implementation rather than a typo.
*How it surfaces:* a composition figure above 1.0 on a TTB report or a label, which is the kind of number that is wrong in a way nobody catches because it looks like a percentage and nothing renders it as one.
*Resolves when:* the press function normalises fractions across the parent set, or a deferred constraint checks that the fractions into a child sum to 1.
*Load-bearing:* yes for composition. Reached by the press screen, build order 3. Nothing in the committed client writes lineage, which is the only reason this is LATENT. Three bins is the real scale, not a thousand.

**R-6-12. A bin's weight, its unit and its block are three independently optional columns.**
*Verdict:* LATENT.
*Locator:* `supabase/migrations/0001_core_schema.sql:164-187`, against `packages/cellar/docs/spec.md:67-69`.
*What is wrong:* `quantity`, `unit` and `block_id` are each nullable and nothing relates them. Probed X4: a bin with `quantity -880` is accepted. X5: `quantity 880` with `unit` null. X6: `unit 'lbs'` with no quantity. X7: a bin with no block at all. X8: fruit measured in litres. X9: `vintage 99999`. T1-4 says "a bin that was never weighed cannot be recovered"; the schema accepts one, and accepts 880 with no unit, which is 880 lbs or 1940 lbs depending on what the person meant and nothing records which.
*How it surfaces:* at the end of the vintage, when per-bin yield is computed and a handful of bins carry a number with no unit.
*Resolves when:* the intake write path is a kernel function that requires weight, unit and block together, or `node` carries a check that a `bin` has all three.
*Load-bearing:* yes. Reached by the intake screen, build order 2, which is the one the spec says must be solid before harvest.

**R-6-13. A cellar user cannot add a block, so a pick from an unrecorded block records unattributed.**
*Verdict:* LATENT.
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:274-285`, against `supabase/migrations/0004_terms_and_effects.sql:513-516`.
*What is wrong:* `block` is in the admin-write loop. Probed W4: a cellar user **can** insert a node, including a bin. Probed X7: a bin with `block_id` null is accepted. So the person doing intake can record the bin and cannot record which block it came from, and the record that results is accepted without complaint. `0004:513-516` names this shape for terms, calls it a policy line away, and says it is not that session's problem; `block` has the same shape and higher stakes, because block attribution has no second source once the fruit is in the press.
*How it surfaces:* a block that was not in the system before the pick, at 6am, with a truck waiting.
*Resolves when:* `block` gets an insert policy for cellar users, or the intake path refuses a bin with no block.
*Load-bearing:* yes. Together with R-6-12 this is the "bin that cannot be reconstructed" the build order is named after.

**R-6-14. Volume may exceed capacity, and a placement may open on a closed node.**
*Verdict:* LATENT.
*Locator:* `supabase/migrations/0001_core_schema.sql:229-244`, `supabase/migrations/0001_core_schema.sql:130-150`.
*What is wrong:* nothing relates `placement.volume_l` to `vessel.capacity_l`. Probed X2: 999999 L into a tank, accepted. Probed X1b: a placement into a node whose `status` is `closed`, accepted, once the target vessel is free. A closed node is one that has already fed a child, so wine placed into it after the fact is outside the lineage the composition functions walk.
*How it surfaces:* a fat-fingered volume that no screen questions, and a closed lot that quietly reacquires a vessel.
*Resolves when:* a check relates the two volumes, and a placement refuses a node whose status is `closed`.
*Load-bearing:* no for the volume check, which is a typo guard. Yes for the closed-node case, which corrupts lineage.

**R-6-15. An event may be born back-dated, and nothing compares `at` against `created_at`.**
*Verdict:* LATENT.
*Locator:* `supabase/migrations/0001_core_schema.sql:255`, `:264`.
*What is wrong:* probed E5: a cellar user inserts a new event with `at = now() - interval '3 years'`, accepted, no marker. `created_at` does record the insertion time, so there is a second source and the discrepancy is reconstructable, which is the only reason this is not worse. Nothing reads it: no view, no function and no assertion compares the two.
*How it surfaces:* a record entered late looks contemporaneous. Legitimate for transcription from Wine Meister (build order 4) and indistinguishable from the other case.
*Resolves when:* a view or `doctor` surfaces events whose `at` and `created_at` differ by more than a threshold.
*Load-bearing:* no. The second source exists; only the reading of it is missing.

---

## DIVERGENT

**R-6-16. Two of the six commands in CLAUDE.md's definition of done fail by construction.**
*Verdict:* DIVERGENT.
*Locator:* `CLAUDE.md:89` and `CLAUDE.md:92`, against `package.json:10-19` and `README.md:38-40`.
*What is wrong:* `CLAUDE.md:89` lists `bun run test`; `package.json` has no `test` script. `CLAUDE.md:92` lists `bun run doctor  # reports nothing, against replay fixtures`; `package.json:15` is `echo '...' && exit 1`, and `README.md:38-40` states that the non-zero exit is deliberate. Which of the two is wrong is a real question: the README's framing is honest about the state of the tree, and CLAUDE.md's is the standard the tree is supposed to be held to.
*How it surfaces:* the first person who runs the definition of done end to end.
*Resolves when:* either the commands exist, or CLAUDE.md marks both as pending with the same honesty the README uses.
*Load-bearing:* yes indirectly. `doctor` is the stated remedy for S-4 and therefore for R-6-7.

**R-6-17. `kernel.ts` and `CLAUDE.md` state an offline-identity property the call sites do not have.**
*Verdict:* DIVERGENT.
*Locator:* `packages/core/src/kernel.ts:32-33` and `CLAUDE.md:60-61`, against the call sites in R-6-2.
*What is wrong:* both say the id exists so an offline write has identity before the server sees it. The ids are uuids and not sequences, so the letter holds; the property does not, because the uuid is created inside the request rather than held with the work. Neither document is wrong about what should be true, and the code is not wrong about the uuid. What is missing is the part that makes the uuid mean anything.
*How it surfaces:* only when somebody tries to retry a write and finds it is a new write.
*Resolves when:* R-6-2 resolves, at which point both statements become true.
*Load-bearing:* yes. This divergence is why R-6-2 was not caught.

---

## BY DESIGN

**R-6-18. The walk needs an admin, and `0004` says so.**
*Verdict:* BY DESIGN.
*Locator:* `supabase/migrations/0004_terms_and_effects.sql:513-516`, `supabase/migrations/0003_parties_and_products.sql:246-250`.
*What is wrong:* nothing. The comments state that structural writes match `vessel` and `location` rather than the event tables, that add-inline during the walk therefore needs an admin, and that the walk is admin work. The defect is R-6-1, which is that the client does not say the same thing.
*How it surfaces:* n/a.
*Resolves when:* n/a.
*Load-bearing:* no.

---

## NOT A DEFECT

**R-6-19. `create_vessel_with_wine` is genuinely one transaction. Prediction falsified.**
*Verdict:* NOT A DEFECT.
*Locator:* `supabase/migrations/0005_account_and_walk.sql:232-296`.
*What is wrong:* nothing, and I expected otherwise. I predicted that a four-step plpgsql body calling out to `bind_vessel_code` and `generate_inferred_history` would leak a vessel when a later step failed, on the reasoning that the loop at `:280-283` calls a separate function per code. It does not. Three forced failures at three different depths: ATOM-1b, a cooper term as `variety_id`, which fails at the node insert after the vessel insert has succeeded; ATOM-2, an owner party that does not exist, same depth; ATOM-3, two codes where the second collides, so the failure lands after all three inserts **and** after one code has already been bound. In all three, nothing survived: no vessel, no node, no placement, no code. The function call is one statement and the whole body is one transaction, exactly as `0005:225-228` claims and as the status ledger grades it. Recording the falsification here because it is the only evidence in this report that the probes were real.
*How it surfaces:* n/a.
*Resolves when:* n/a.
*Load-bearing:* yes, and it holds. This is the one place in the tree where the multi-row atomicity question is answered correctly.

**R-6-20. `bind_vessel_code` and `claim_account` are idempotent exactly as advertised.**
*Verdict:* NOT A DEFECT.
*Locator:* `supabase/migrations/0003_parties_and_products.sql:195-227`, `supabase/migrations/0005_account_and_walk.sql:36-70`.
*What is wrong:* nothing. Probed P5 #2: the same code on the same vessel with a fresh `p_id` returns the existing row and adds nothing, so the unused `p_id` is harmless. P5 #3: the same code on a different vessel raises `23505` with a message naming the other vessel, which is a good refusal and better than the raw constraint text everywhere else in this report. `claim_account` probed twice for the same uid with a different name: returns the existing row and does not rename, so a reloaded sign-up screen is not a new user and not a renamed one. These are the only two write paths in the tree that are idempotent, and both are idempotent on a natural key rather than on the client uuid, which is why they survive R-6-2 and nothing else does.
*How it surfaces:* n/a.
*Resolves when:* n/a.
*Load-bearing:* yes, and they hold.

**R-6-21. Cellar users can neither update nor delete an event, and nobody can delete one.**
*Verdict:* NOT A DEFECT.
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:287-295`.
*What is wrong:* nothing. Probed E6 and E7 as a cellar user: both 0 rows. Probed A5 as an admin: `delete from event` is 0 rows, because no delete policy on `event` exists at all. So the append-only half of T0-5 that concerns cellar users holds completely, and deletion is closed to everybody. Probed E8: `provenance = 'confirmed'` at insert is refused by the T0-4 trigger with its own message rather than a constraint name. The gap is R-6-9, which is the admin update path, and it is the only gap.
*How it surfaces:* n/a.
*Resolves when:* n/a.
*Load-bearing:* yes, and mostly holds.

---

## UNVERIFIED

**R-6-22. What the user sees on timeout, and on a write that lands after they gave up.**
*Verdict:* UNVERIFIED.
*Locator:* `packages/cellar/src/sticky.ts:1-10`, `packages/cellar/src/walk.ts:625-657`, `packages/cellar/src/walk.ts:499-537`.
*What is wrong:* question 3 asks what the client actually holds rather than what it is assumed to hold, so I read it. It holds nothing durable. `sticky.ts:2` states in memory only, a reload starts clean, and that is accurate: `values` and `pinned` are a `Map` and a `Set` in module scope. There is no `localStorage`, no `sessionStorage`, no IndexedDB, no service worker, no retry and no queue anywhere in `packages` or `apps` (grepped across every `.ts`, `.html` and `.json`). So a page reload mid-form loses every field, the collected code list and the selected photo, and there is no second source for any of it. Within one screen the form survives a failed submit, because the error path calls `message.replaceChildren(fail(error))` and never `show()`, so a retry is possible as long as nobody navigates or reloads.
*What could not be checked:* whether `supabase-js` surfaces a network timeout as a thrown error the catch blocks see, how long it waits before doing so, and whether a request that succeeds server-side after the client has given up produces the banner described in R-6-4. Those are the three facts that decide how bad R-6-2 and R-6-4 actually are.
*The probe I would have run:* the walk against a real Supabase instance with the connection cut mid-request, and again with a proxy that delays the response past the client timeout and then lets the write through.

**R-6-23. Whether PostgREST reports an RLS-refused UPDATE to the client as success.**
*Verdict:* UNVERIFIED.
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:299-312`.
*What is wrong:* R-6-5's silence is probed at the SQL level: the update affects 0 rows and raises nothing. Whether `supabase-js`'s `.update()` without a trailing `.select()` returns `{ error: null }` in that case decides whether a cellar user's failed rack is invisible or merely unhelpful, and it cannot be settled from the SQL. The committed kernel has no placement update path, so this becomes live with the intake and press screens.
*The probe I would have run:* a real Supabase instance, a cellar account, and a `PATCH /rest/v1/placement` that the policy refuses, inspecting both the HTTP status and what `supabase-js` hands back.

**R-6-24. The camera decode path, and its double-fire rate on one barcode.**
*Verdict:* UNVERIFIED.
*Locator:* `packages/cellar/src/scan.ts:70-96`, `packages/cellar/src/scan.ts:45-66`, `packages/cellar/src/walk.ts:750-786`.
*What is wrong:* `decodeFromVideoDevice` fires a callback per decode and ZXing will generally decode the same barcode repeatedly while it stays in frame. In the collecting case that is handled: `accept` dedupes against `collected` at `scan.ts:48` and shows a note. In `scanScreen`, `collect` is `false`, so nothing is ever pushed to `collected`, the dedupe never has anything to compare against, and `options.onCode` fires on every decode. Today that only re-runs `resolveCode`, a read, so it is harmless; it stops being harmless the first time a scan screen writes, which is topping mode and cap management, build order 6.
*What could not be checked:* the actual fire rate, and whether ZXing's own internal state suppresses repeats. The status ledger already grades this "never run against a camera".
*The probe I would have run:* the scan screen on a phone, against a real barcode, counting `onCode` calls per second.

**R-6-25. The storage bucket, and the photo uploaded under a vessel id that may never exist.**
*Verdict:* UNVERIFIED.
*Locator:* `supabase/migrations/0005_account_and_walk.sql:307-340`, `packages/core/src/kernel.ts:276-297`, `packages/cellar/src/walk.ts:517` and `:630`.
*What is wrong:* the storage block was skipped under this shim, so none of the bucket or its two policies were executed. What reading shows, and what would be worth probing with storage up: `uploadVesselPhoto` runs **before** the write in both vessel screens, keyed on the vessel id the handler just minted. If the write then fails, the photo is in the bucket under an id no row will ever carry. On retry R-6-2 mints a new id, so the retry uploads a second copy under a second orphan path. Nothing cleans up and `vesselPhotoUrl` returns null silently on error (`kernel.ts:291-296`), so a lost photo path is indistinguishable from no photo.
*The probe I would have run:* the same shim with a `storage` schema stood up, then a `create_vessel_with_wine` forced to fail after the upload, counting objects in the bucket.

---

## The three things most likely to lose a bin

Ranked by consequence, not by likelihood, as asked.

**1. A move recorded by the person who made it is half-recorded and reports success.** R-6-5. A cellar user can open a placement and cannot close one, and the refusal is zero rows with no error. The lot is then in two vessels, volumes double, and the person who did it has no signal that anything went wrong. This is worse than every other finding here because it is the only one that writes a wrong record while telling the writer it worked. *The change that closes it:* moves become a kernel function that owns the close and the open in one transaction, the way `create_vessel_with_wine` already owns its four inserts. The pattern is in the tree and works (R-6-19); it just has not been applied to the move.

**2. Nothing refuses a bin with no weight, no unit or no block, and nothing looks for one afterwards.** R-6-12, R-6-13 and R-6-7 together. The three columns that carry the information with no second source are independently nullable, a cellar user cannot add the block they are standing in, and the tool named as the backstop for orphaned and incomplete records is `exit 1`. T1-4 says a bin that was never weighed cannot be recovered, and nothing in the schema or the client enforces that sentence. *The change that closes it:* the intake write is a kernel function taking weight, unit and block as one required triple, plus `doctor` implemented and scheduled so that whatever slips through is found within a day rather than at the end of the vintage.

**3. A retried submission has a new identity, so the only thing between a timeout and a duplicate lot is a name typed the same way twice.** R-6-2, R-6-3 and R-6-4. The id is minted inside the submit handler, `node` has no uniqueness of its own, vessel names and codes are compared as raw text with no trim or case-fold at the database, and a read failure after a successful write is painted as a write failure so the person retries on purpose. In a barn with intermittent signal this composes into two lots of the same wine with the record split between them. *The change that closes it:* mint the id when the form opens and hold it across retries, have the server treat a repeat of a known id as the same write rather than as a collision, and end the write's try block at the write.

---

## What is sound

`create_vessel_with_wine` is genuinely atomic under three forced mid-function failures (R-6-19). `bind_vessel_code` and `claim_account` are idempotent as documented (R-6-20). Cellar users cannot rewrite or delete an event and nobody can delete one (R-6-21). The T0-4 insert trigger refuses self-granted standing with its own message. The composite `(id, kind)` foreign keys genuinely refuse a term of the wrong kind, including through the RPC. All five migrations apply clean from empty and all 28 assertions pass. The gap between that and this report is that the assertions check what the schema refuses and almost nothing checks what it silently accepts.
