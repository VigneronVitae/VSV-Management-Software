---
Type: ledger
Version: 1.2
Purpose: "Deduplicates the thirteen review reports into one entry per defect, keyed by the database or code identifier rather than by line number, so entries survive the schema reorganization."
Depends on: [docs/architecture-rulings.md, docs/sorry-ledger.md, docs/review/README.md]
Depended on by: [docs/status-ledger.md, supabase/migrations/0021_cellar_write_paths.sql, supabase/migrations/0022_admission_and_authorship.sql, scripts/verify.sh, docs/session-reports/modularization-progress.md, supabase/migrations/0025_bind_an_unbound_code.sql]
---

# Findings Ledger

Thirteen reports, three engines, roughly 200 findings, 73 distinct defects, all against
`c3eae3c7c262544e4b2e29526b513c964c6852fe`. Five more were added by the phase 2 read of
migrations `0006` to `0022`, which no review had seen, bringing it to 78.

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

## What has been closed since the review

The reports describe `c3eae3c`, five migrations and 42 files. This section is the only
part of this document that changes as work lands, and it is kept here rather than by
editing the tables, so that a reader can still see what the reviews found.

| Id | Closed by | Note |
|---|---|---|
| A1 | `0022_admission_and_authorship.sql` | Probed before and after. Discharges S-25 in the same predicate |
| A2 | `0013_close_on_empty.sql` | The trigger the finding was about was dropped, for an unrelated reason, four days before the finding arrived |
| A3 | `0022_admission_and_authorship.sql` | The sensor branch is refused outright rather than made trustworthy. S-39 |
| A6 | `0022_admission_and_authorship.sql` | Staff only in both directions, and an update policy that 0005 never had. S-40 |
| A8 | `0022_admission_and_authorship.sql` | A definer function now decides who may call it, which is the check a definer function owes |
| A14 | `0021_cellar_write_paths.sql` | Predicted racking would be refused silently the day it was built. It was, for four days |
| A22 | `0025_bind_an_unbound_code.sql` | Ruled by the winemaker rather than decided here: a cellar hand may bind an unbound code, only an admin may rebind one, and the refusal names the barrel that already has the sticker. See S-43 |
| B1 | `app.css`, doubled `[hidden]` selector | Every add form had been permanently open |
| B14 | `vite.config.ts` | `allowedHosts` now names the tunnel, which is what unblocked camera testing on a phone |
| C1 | `package.json` | `bun run test` is a script. S-38 says what it is standing in for |
| C2 | `docs/status-ledger.md` | The opening sentence; no grade was touched |
| C3 | `CLAUDE.md`, `docs/compost-ledger.md` | Eight entries, all with a reactivation condition, in numeric order |
| C4 | `supabase/config.toml` | Postgres 17, with the tree as it stood at `0022` and 129 assertions run against it |
| D1 | partly | A throwaway shim proved the tree as it stood at `0022` apply from empty. A committed shim is still not in the tree |
| D4 | `scripts/verify.sh` | Found forty nine broken edges on its first run |
| D9 | `scripts/verify.sh` | Em dash rule enforced; the import rule holds vacuously and says so |
| E6 | `0014_rack.sql` | Racking writes `placement.to_at`, which nothing previously did |

Two entries were made worse by work done after the review and are worth naming as such.
A13, that every denial is a zero-row match rather than an error, went from a general
observation to a live defect in five new kernel functions, and `0021` improves it for one
principal on three tables rather than answering it. B9, that the home screen offers a
cellar user actions RLS refuses, now offers more of them, because the menu grew.

## Disposition

| Lands in | Count |
|---|---|
| `0006`, the admission and integrity migration | 23 |
| Client, independent of the migration | 19 |
| Documents and ledgers | 12 |
| Infrastructure: verify, doctor, CI, backup, deploy | 12 |
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
| A12 | `event.data` | No schema object reads it. The correction path does not exist: a correcting event changes no number anywhere, so the commitment in `CLAUDE.md` that "events are append-only, corrections are new events" has no implementation behind its second clause. Confirmed by the `R-5` report, which is the one that reviewed append-only and derived. This entry used to cite `E-4`, which was never a ruling reference and dangled after the `AR-` rename; the target is the `CLAUDE.md` statement and `docs/review/reports/R-5-claude-code.md` | 1 (p) | EXPLOITABLE |
| A13 | RLS denial surface | Every denial is a zero-row match, not an error. A refused correction is indistinguishable from an applied one. This is the class the whole sweep converges on | 4 (p) | EXPLOITABLE |
| A14 | `placement` update policy | Admin-only close, so racking is refused the day it is built, silently | 2 (p) | EXPLOITABLE |
| A15 | `name` columns declared `not null` | The database accepts `''` for every one. Non-empty and trim are client-only rules | 1 (p) | EXPLOITABLE |
| A16 | `term.value` | The join key the database resolves terms by, derived by eight chained string operations in one TypeScript file. `term_id()`, `next_cap_action` and `topping_check` all depend on it. AR-B2 violated inside the tree | 2 | EXPLOITABLE |
| A17 | `vessel.owner_id` against `node.owner_id` | The walk's Owner select writes the vessel and the node payload omits `owner_id`, so the lot coalesces to the facility. TTB-relevant, and invisible from inside the walk | 1 | EXPLOITABLE |
| A18 | `node.quantity` against `placement.volume_l` | Two stored volumes for the same wine, written from one input, with nothing linking or reconciling them | 2 | EXPLOITABLE |
| A19 | `node.status`, `node.closed_at` | Stored derivations of lineage with no recompute and no staleness detection | 1 | EXPLOITABLE |
| A20 | `task_claim_log`, `ON DELETE RESTRICT` on lineage | Cascade-deletable from `task` although no delete policy exists. Restrict is a speed bump: delete the edge, then the node, both permitted | 1 (p) | EXPLOITABLE |
| A21 | `subject_type`, `term_kind` | Core enums naming higher-module tables and carrying module vocabulary. Wrong-way edges that never fail to install. `0004` already performed this migration once | 1 (p) | AR-E7 |

| A22 | `bind_vessel_code` | Invoker, and it inserts into `vessel_code`, whose only write policy is `vessel_code_admin_write` at `is_admin()`. A cellar user cannot put a sticker on a barrel. Unlike A14 this fails loudly, because a refused INSERT violates a `with check` and raises, where a refused UPDATE matches zero rows. Whether it should be refused at all is a question for the winemaker: creating a vessel is admin work and asserted so on purpose, and labelling one during harvest may not be | 1 (p) | EXPLOITABLE |
| A23 | `vessel_type_note` | Added by `0012` with `using (true)` on select, which is A5's default arriving on new surface seven migrations after A5 was filed. The five tables `0019` added do not repeat it, so the habit changed mid-session and `0012` is the one that predates the change. Low consequence, since a note says a vessel type asks for the wrong field, but it is the pattern recurring rather than a one-off | 1 | LATENT |

| A24 | `operation_has_an_effect` | The predicate is `kind <> 'operation' or attributes ->> 'effect' in (four values)`. For an operation carrying no effect at all the inner test is `null in (...)`, which is null, so the whole check is `false or null`, which is null, and **a check constraint passes on null**. An effectless operation lands. The four-effects invariant refuses a wrong answer and not a missing one. Same three-valued-logic shape as A1's `coalesce(..., true)` and `may_see_all_of` returning null, which makes it the third time in this schema. Found by writing the assertion for it, probed, and it also corrects B2 | 1 (p) | EXPLOITABLE |

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
| B2 | `addTerm` against `operation_has_an_effect` | Two reports said defaulting `attributes` to `{}` makes adding an operation inline always raise. **The premise is wrong and the truth is worse.** The constraint passes on a missing effect, see A24, so an inline operation lands and is silently inert: the kernel reads no effect from it and does nothing about volume or lineage. A raise would have been visible. Confirmed by probe on 2026-09-12 | 2 (p) | MAJOR |
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
| D10 | the assertion suite's mutation score | 28 of 115 injected schema defects caught, 24 percent, measured by `scripts/mutate.sh` at migration `0022`. On the subset of objects that existed at the reviewed baseline it is 15 of 71, 21 percent, against the 42 percent `G-5` measured on its own 45. Absolute catches rose from 19 to 28 while the schema roughly doubled, so the suite grew and its coverage of the schema fell. **This is the stop condition W-2 sets for the schema split** | 1 (p) |
| D11 | row level security itself | Disabling RLS outright on 16 of 21 tables is not noticed by any assertion. `app_user`, `party`, `lineage`, `placement`, `task`, `task_claim_log`, `template`, `template_step`, `vessel_code`, `block`, `vessel_type_note` and all five procedure tables can have RLS turned off and the suite still passes. The five that are caught are the ones an assertion reads through a second principal. This is the most actionable half of D10 and the cheapest to close | 1 (p) |
| D12 | the mutation harness | `G-5` measured 42 percent and did not commit the harness, so the number could not be reproduced or improved against. That is D1's shape applied to a measurement rather than to a shim. `scripts/mutate.sh` now exists and enumerates its mutations from the catalog rather than from a written list, so the set grows with the schema | 1 |

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
| E9 | `block.variety` | Free text while every other variety is a term. AR-F2 violated in the existing tree | With the origin work |
| E10 | this winery's facts in the client | The winery name is compiled in, six Willamette varieties are seeded with no UI to remove them | Second install. AR-J1 in miniature |
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

## Read but not found: what phase 2 checked in 0006 to 0022 and came back clean

Recorded because a review that reports only what it found cannot be distinguished from a
review that stopped early. Fifteen migrations and every function, policy, table and column
they added were read against the five patterns known to recur.

**A10, a derived function inner-joining something optional and returning a short total.**
No new instance. `vessel_history` left-joins `app_user` on the nullable `by_user`, which is
the correct shape and the opposite of A10's mistake. `node_history` and `rack_plan` inner-join
only on columns that are `not null` with a foreign key, where an inner join cannot drop a row.
A10 itself is unchanged: `block_composition` still inner-joins `block`.

**A18 and A19, a stored value that is a derivation nothing recomputes.** No new instance.
Two columns were added in the whole range, `node.hidden` and `party.default_hidden`, and both
are stored choices rather than derivations. `procedure_run_state` looked like the exception,
carrying `actual_seconds` and `over_by_seconds`, and it is a view. The nine generated columns
are recomputed by definition.

**A13, a refused write returning zero rows rather than an error.** Recurs, mildly. The five
tables `0019` added all carry `for all ... using (is_facility_user())`, so a client's refused
UPDATE is a silent no-op there as everywhere else. The consequence is small, since a client
has no reason to write a procedure run, but the pattern was inherited rather than fixed.

**A14's generalization, a write path running as the caller against a policy that refuses it.**
One more found, A22, and the search was exhaustive rather than a spot check: every function in
`public` was matched against every table it writes, and every such table's insert and update
policies were read. Six were fixed by `0021`; `bind_vessel_code` is the seventh and it predates
the range, having been written in `0003`.

**A risk `0022` introduced and did not realise.** Tightening `event_insert` to
`by_user = auth.uid() and by_sensor is null` would break any function that writes an event in
another name. All six that insert into `event` were checked: `generate_inferred_history`,
`record_event`, `record_vessel_note`, `finish_run`, `update_vessel` and `rack`. Every one
writes `auth.uid()` and none sets `by_sensor`. No path breaks.

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

---

## Changelog

### 1.1 (2026-09-12)

*Cause: W-2 phase 2, a read of migrations `0006` through `0022`, which no review had
ever seen. The thirteen-report corpus was run against five migrations and 42 files.*

**Added.** A22, `bind_vessel_code` refused to cellar users. A23, `vessel_type_note`
repeating A5's blanket read on new surface. D10, the mutation score. D11, row level
security disable surviving on 16 of 21 tables. D12, the harness itself now existing.

**Added a section**, "Read but not found", recording the four patterns checked across
the unreviewed range that came back clean, because a review that reports only its
finds cannot be told apart from one that stopped early.

**Amended.** Four references that named rulings rather than compost entries now use the
`AR-` prefix introduced by `docs/architecture-rulings.md` v2.1: AR-B2, AR-E7, AR-F2 and
AR-J1. A progress section records what has been closed since the review.

**Known dangling reference, not resolved.** Entry A12 cites "E-4's premise". `E-4`
resolves to nothing in this repository under any reading: not a ruling, not a compost
entry, not a finding, not a spec section, and it appears nowhere in the review corpus.
Left as it stands rather than guessed at.

### 1.0 (2026-09-11)

Thirteen reports, three engines, roughly 200 findings deduplicated into 73 distinct
defects against `c3eae3c`, keyed by identifier rather than by line number.

### 1.2 (2026-09-12)

*Cause: W-3, which set out to make the assertion suite police the schema and found two
things by writing assertions rather than by reading.*

**Added.** A24, `operation_has_an_effect` passing on a missing effect because a check
constraint passes on null. It is the third appearance of the same three-valued-logic shape
in this schema, after A1's `coalesce(..., true)` and `may_see_all_of` returning null.

**Corrected.** B2's premise. Two reports said adding an operation inline always raises. It
does not raise; it lands, and the operation is silently inert because the kernel reads no
effect from it. A raise would have been visible, so the real defect is worse than the one
that was filed.

**Repointed.** A12 cited `E-4`, which was never a ruling reference and dangled after the
`AR-` rename in `docs/architecture-rulings.md` v2.1. The commitment it meant lives in
`CLAUDE.md` and in the `R-5` report, and it now says so. That was W-3's own correction of
its author's error rather than a defect in the tree.

**Closed.** A22, by `0025`.
