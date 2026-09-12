---
Type: ledger
Version: 1.0
Purpose: "Deduplicates the thirteen review reports into one entry per defect, keyed by the database or code identifier rather than by line number, so entries survive the schema reorganization."
Depends on: [docs/architecture-rulings.md, docs/sorry-ledger.md, docs/review/README.md]
Depended on by: [docs/status-ledger.md]
---

# Findings Ledger

Thirteen reports, three engines, roughly 200 findings, 73 distinct defects. All against
`c3eae3c7c262544e4b2e29526b513c964c6852fe`.

## Why this is keyed by identifier

Line numbers do not survive the schema reorganization, and one engine's locators already
drift by up to twenty lines. A policy name, a function name, a constraint name, or a file
plus symbol survives both. Every entry below is greppable at any commit.

## How to read the Found column

The count is independent confirmations across separate runs, not a severity score. Six
engines finding one defect means the finding is solid. One engine finding it means it is
probably real and unconfirmed, and several of the single-source entries are the most
interesting items in the set, because they took execution rather than reading.

**(p)** marks an entry at least one report probed rather than reasoned.

## Disposition

| Lands in | Count |
|---|---|
| `0006`, the admission and integrity migration | 21 |
| Client, independent of the migration | 19 |
| Documents and ledgers | 12 |
| Infrastructure: verify, doctor, CI, backup, deploy | 9 |
| Deferred with a condition | 12 |

---

## A. Lands in 0006

Written once, after the schema split, against the new layout.

| Id | Identifier | Defect | Found | Verdict |
|---|---|---|---|---|
| A1 | `is_facility_user()` | `coalesce(..., true)`: no party row resolves to facility. Deactivating a client party promotes that login to full cellar read. Deactivation escalates rather than revokes | 6 (p) | EXPLOITABLE |
| A2 | `close_parent_on_lineage()` | No `security definer`, so the `update node` runs as invoker and is filtered by the admin-only node update policy. Zero rows, no error, parent stays open. Fires for an admin and not for a cellar user | 3 (p) | EXPLOITABLE |
| A3 | `event_insert` | `by_user = auth.uid() or by_sensor is not null`. Any string in `by_sensor` unbinds the author check, including planting another user's uuid in `by_user` | 5 (p) | EXPLOITABLE |
| A4 | `event_admin_update` | An admin rewrites any field of any event in place, `at`, `by_user` and `provenance` included, with no trace. Reaches `confirmed` on an observed event, which `confirm_event()` exists to refuse | 7 (p) | EXPLOITABLE |
| A5 | `node_read` and the `0002` policy loop | Only `node_read` was narrowed by `0003`. `event`, `placement`, `lineage`, `vessel`, `party`, `term`, `task` and the rest still read blanket `using (true)` | 4 (p) | EXPLOITABLE |
| A6 | `vessel-photos` storage policies | Both policies are `to authenticated using (bucket_id = 'vessel-photos')`. Every login reads every photo, eighteen lines below the comment explaining why the bucket is private | 5 | EXPLOITABLE |
| A7 | `node_insert`, `lineage_insert`, `placement_insert` | `with check (true)`. A custom crush client can insert a lineage edge naming one of your lots as parent. Reachable today by design, unlike the unclaimed-stranger case | 3 (p) | EXPLOITABLE |
| A8 | `claim_task` | `security definer` with no entitlement check and no signed-in check. Takes a task assigned to someone else; a null uid permanently wedges it and no cellar user can recover it | 3 (p) | EXPLOITABLE |
| A9 | `lineage` constraints | Only `no_self_parent`. No acyclicity, and `node_bin_shares` has no visited set, so a two-edge cycle never terminates. Its sibling traversal does have a guard | 3 | EXPLOITABLE |
| A10 | `block_composition` | Inner-joins `block`, dropping every bin with no block, and normalizes over the parents it found. Returns a short total and reports nothing. Structural for vermouth, where no origin has a block | 5 (p) | EXPLOITABLE |
| A11 | `template`, `template_step` | No owner column exists and read is blanket true. A custom crush client's botanical formula is readable by every login. This is a migration, not a policy edit, and it blocks handing the system to a client | 1 | EXPLOITABLE |
| A12 | `event.data` | No schema object reads it. The correction path does not exist: a correcting event changes no number anywhere. E-4's premise has no implementation | 1 (p) | EXPLOITABLE |
| A13 | RLS denial surface | Every denial is a zero-row match, not an error. A refused correction is indistinguishable from an applied one. This is the class the whole sweep converges on | 4 (p) | EXPLOITABLE |
| A14 | `placement` update policy | Admin-only close, so racking is refused the day it is built, silently | 2 (p) | EXPLOITABLE |
| A15 | `name` columns declared `not null` | The database accepts `''` for every one. Non-empty and trim are client-only rules | 1 (p) | EXPLOITABLE |
| A16 | `term.value` | The join key the database resolves terms by, derived by eight chained string operations in one TypeScript file. `term_id()`, `next_cap_action` and `topping_check` all depend on it. B-2 violated inside the tree | 2 | EXPLOITABLE |
| A17 | `vessel.owner_id` against `node.owner_id` | The walk's Owner select writes the vessel and the node payload omits `owner_id`, so the lot coalesces to the facility. TTB-relevant, and invisible from inside the walk | 1 | EXPLOITABLE |
| A18 | `node.quantity` against `placement.volume_l` | Two stored volumes for the same wine, written from one input, with nothing linking or reconciling them | 2 | EXPLOITABLE |
| A19 | `node.status`, `node.closed_at` | Stored derivations of lineage with no recompute and no staleness detection | 1 | EXPLOITABLE |
| A20 | `task_claim_log`, `ON DELETE RESTRICT` on lineage | Cascade-deletable from `task` although no delete policy exists. Restrict is a speed bump: delete the edge, then the node, both permitted | 1 (p) | EXPLOITABLE |
| A21 | `subject_type`, `term_kind` | Core enums naming higher-module tables and carrying module vocabulary. Wrong-way edges that never fail to install. `0004` already performed this migration once | 1 (p) | E-7 |

**Ordering inside 0006.** A1 first, since it is one line and it currently inverts
deactivation. Then A7, A5 and A11 together, since they are the admission surface and A11
gates the client handoff. Then A2, A4, A12 and A13, which are the integrity set. A21 last,
because it is the module-boundary work and belongs with the schema split rather than with
admission.

---

## B. Client, independent of the migration

| Id | Identifier | Defect | Found | Verdict |
|---|---|---|---|---|
| B1 | `.add-inline` in `app.css` | `display: flex` with no `[hidden]` guard, so an author rule beats the UA `[hidden] { display: none }`. Every add form is permanently open. Probed: seven of seven visible, 1656px of 2737 | 1 (p) | MAJOR |
| B2 | `addTerm` against `operation_has_an_effect` | Defaults `attributes` to `{}` and the picker sends none, so adding an operation inline always raises | 2 (p) | MAJOR |
| B3 | `sticky.ts` with `pickers.ts` restore | Dead twice over: no text-field key is ever pinned, and `selectId ?? select.value ?? sticky` never falls through because `select.value` is always a string. The walk's own copy promises carry-over | 3 | MAJOR |
| B4 | `vesselScreen` empty-vessel path | Insert then loop `bindOne` with no transaction. One rejected code leaves a vessel that can be neither completed nor retried, and the camera keeps running | 4 (p) | MAJOR |
| B5 | `newId()` inside submit handlers | Client ids are minted in the handler, so a retry has a different identity. This is the one property `CLAUDE.md` claims for offline writes | 2 | MAJOR |
| B6 | both vessel screens' async IIFE | A failed initial load renders a dead end with no error and no Back | 3 | BLOCKER |
| B7 | write-then-read error handling | A committed write is painted as a failure when the read after it fails | 2 | MAJOR |
| B8 | `scan.ts` decode loop | Fires `resolve_vessel_code` per decode frame, unthrottled, with no ordering guard | 2 | MAJOR |
| B9 | `walk.ts` home routing | Shows a cellar user four actions RLS refuses, and surfaces the raw Postgres message | 3 | MAJOR |
| B10 | `walk.ts:200` role check | Reimplements `is_admin()` and drops the `active` conjunct. `route()` admits inactive users to every screen | 1 | EXPLOITABLE |
| B11 | `current_volume_l` render | `0` is falsy, so an emptied vessel displays as "unrecorded". The write side is correct | 3 | MAJOR |
| B12 | `Number(x.value())` guards | A `type="number"` field holding text the browser rejects writes null, silently | 1 | EXPLOITABLE |
| B13 | `uploadVesselPhoto` ordering | Photo uploads before the row it belongs to, unbounded and full-resolution, orphaning on any later failure | 3 | MINOR |
| B14 | `vite.config.ts` | `server.host` set, `allowedHosts` empty, on a vite that enforces the Host check. LAN by IP works, a tunnel does not, which blocks camera testing on a real phone | 2 | MAJOR |
| B15 | no service worker, no manifest, no icons | The PWA is claimed four times in the tree and does not exist. A reload with no signal loses the application | 2 | MAJOR |
| B16 | no request timeout anywhere | A dead-zone write hangs on "Working" indefinitely | 1 | MAJOR |
| B17 | session expiry offline | Indistinguishable from sign-out, and the next write goes out as the anon key | 1 | MAJOR |
| B18 | `--ink-faint` | Below 4.5:1 in both themes, and it carries the codes and volumes | 2 | MINOR |
| B19 | `addTerm` sort_order | Inline terms sort above every seeded term; the client owns picker ordering and never sets it | 1 | MINOR |

---

## C. Documents and ledgers

Cheap, and every remaining report would have found them again.

| Id | Identifier | Defect | Found |
|---|---|---|---|
| C1 | `package.json` scripts | `bun run test` is in the definition of done and is not a script. It silently executes `/usr/bin/test` | 7 |
| C2 | `docs/status-ledger.md` | "Nothing is built" above rows graded Built and verified. The sorry ledger repeats it | 4 |
| C3 | `CLAUDE.md:54` | Says five compost entries; there are six, and two carry no reactivation condition. C-5 is filed after C-6 | 3 |
| C4 | `supabase/config.toml:22` | `major_version = 16` is refused by current Supabase CLI during config validation. 15 and 17 pass. The one version verified is the one the tooling will not run | 1 (p) |
| C5 | hosted project auth settings | Exist nowhere in the repository. The state governing the live instance is unversioned and invisible to every review | 1 |
| C6 | `0001_core_schema.sql` header | Describes a schema that no longer exists, and nothing describes the one that does | 1 |
| C7 | `README.md` setup path | Never creates `.env.local`, never starts the client, and `DATABASE_URL` is required by `db:test` and documented nowhere. README and CLAUDE.md disagree on the definition of done | 2 |
| C8 | walk session report commit count | Miscounts the repository's own commits by five | 1 |
| C9 | `.gitignore` | The most common database dump filename is not ignored, against a report claiming dumps are | 1 |
| C10 | S-1 topping threshold | The ledger says unchosen; the code chose 100%, silently | 1 |
| C11 | `spec.md` topping fields | Different set from the seeded predicate's fields | 1 |
| C12 | `kernel.ts:288` photo comment | Claims the bucket is confidential against A6 | 2 |

---

## D. Infrastructure

The survey's conclusion. Thirty-seven of 123 dependency edges are enforceable by nothing else.

| Id | Identifier | Defect | Found |
|---|---|---|---|
| D1 | the auth shim | Every "applies clean" and "all passing" grade rests on a shim not in the tree. Three runs now agree on 28 of 28 with storage skipped | 1 |
| D2 | `bun run doctor` | `echo` and `exit 1`. It is in the definition of done and cannot pass. Orphan events are accepted and this is the one tool meant to find them | 3 |
| D3 | no `.github/` | Every check runs only when someone remembers | 4 |
| D4 | the header-graph checker | Exists as a sentence in a session report. The invariant it guards broke silently for five commits | 3 |
| D5 | mutation score | 26 of 45 mutations survive, 42%. The suite passes with `security_invoker` stripped from both read views | 1 (p) |
| D6 | coverage gaps | `event_admin_update` uncovered, so append-only is asserted nowhere. The task subsystem and every composition function untested | 1 |
| D7 | backup, restore, deploy | No backup, no rehearsed restore, no deployment path, no rollback, nothing written for the hours Supabase is unreachable. With C4 there is no local stack to restore into either | 1 |
| D8 | migrations | Neither transactional nor re-runnable, and applicable only to an empty database, against `0005`'s stated intent. `0002` needs the shim and does not guard; `0005` guards | 4 |
| D9 | the em-dash and import rules | Both stated absolutely, both enforced by nothing. Biome can enforce the import rule with no new dependency | 3 |

---

## E. Deferred, with a condition

| Id | Identifier | Defect | Revives when |
|---|---|---|---|
| E1 | `max_rows = 1000` | Truncates the vessel list silently and home reports the truncation as a count | Vessel count approaches 1000. LATENT at 50, not EXPLOITABLE |
| E2 | `next_cap_action` | Counts events that have not happened yet, and instructs punchdown for a node that does not exist | Cap management is used |
| E3 | `generate_inferred_history` | Dates history in the future, is not idempotent, and any authenticated principal may call it | Templates are seeded |
| E4 | timezone handling | The cellar's day starts at 5pm the previous afternoon; the client's boundary is the phone's and the kernel's is the server's | Any date-bucketed report exists |
| E5 | lineage fraction sum | Unconstrained into one child; `block_composition` returns 3.0 | With A10, since both are the fraction semantics |
| E6 | `placement.to_at` | Nothing writes it, so the first placement holds the vessel forever | Racking is built |
| E7 | realtime publication | Broadcasts every event and placement to every login; whether RLS applies to the hosted replication stream is unverified | Before any second client subscribes |
| E8 | `topping_check` | Approves everything when the operation carries no predicate, and raises if the `topping` term is renamed | Topping is recorded |
| E9 | `block.variety` | Free text while every other variety is a term. F-2 violated in the existing tree | With the origin work |
| E10 | this winery's facts in the client | The winery name is compiled in, six Willamette varieties are seeded with no UI to remove them | Second install. J-1 in miniature |
| E11 | `event.task_id`, `event.subject_id` | Two unconstrained ids; S-4 names only one | D2 exists to check them |
| E12 | account deletion | Fails for any user who ever created a node | Anyone leaves |

---

## Unverified across the set

Needing a real device, a real camera, or the hosted instance. Not defects and not cleared.

The camera decode path has never met a camera, and its double-fire rate on one barcode is
unmeasured. The vessel-photos bucket and its policies have never executed anywhere. How
PostgREST surfaces a zero-row RLS denial to the phone, which is the reporting half of A13.
Whether an RLS-refused UPDATE is reported to the client as success. Supabase's JWT-to-role
mapping, which is the half of S-7 the assertions assume. iOS storage eviction and
back-forward cache. What the user sees on timeout and on a write that lands after they gave
up.

---

## Falsified predictions

Reports that expected a defect, probed, and found otherwise. Recorded because they are the
evidence the probes were real.

`create_vessel_with_wine` is genuinely one transaction and rolls back whole, which is why B4
is about the empty-vessel path only. `bind_vessel_code` and `claim_account` are idempotent
exactly as advertised. Cellar users can neither update nor delete an event, and no role can
delete one by any direct path. Composition is genuinely functions over lineage with no
cached column anywhere, so C-3 stayed dead at the level C-3 was about. Every untested
composition function is correct, diamond lineage included. The assertion suite is hermetic
and rolls back cleanly, including on abort. The header graph, the em-dash rule and the
import rule all currently hold, they are simply enforced by nothing.
