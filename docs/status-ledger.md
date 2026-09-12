---
Type: record
Purpose: "Records the single source of build truth for the winery app, so every other document cites status here rather than re-asserting it."
Depends on: [packages/cellar/docs/spec.md, docs/sorry-ledger.md, docs/compost-ledger.md, docs/methodology-lineage.md, supabase/migrations/0001_core_schema.sql, supabase/migrations/0002_derived_and_rls.sql, supabase/migrations/0003_parties_and_products.sql, supabase/migrations/0004_terms_and_effects.sql, supabase/migrations/0005_account_and_walk.sql, supabase/migrations/0006_vessel_thermal.sql, supabase/migrations/0007_vessel_edit.sql, supabase/migrations/0008_fill_vessel.sql, supabase/migrations/0009_vessel_type_form.sql, supabase/migrations/0010_glycol_by_type.sql, supabase/migrations/0011_vessel_type_fields.sql, supabase/migrations/0012_vessel_type_notes.sql, supabase/migrations/0013_close_on_empty.sql, supabase/migrations/0014_rack.sql, supabase/migrations/0015_fork_and_history.sql, supabase/migrations/0016_lot_owner_name.sql, supabase/migrations/0017_vessel_state_rls.sql, supabase/migrations/0018_lot_privacy.sql, supabase/migrations/0019_procedures.sql, supabase/migrations/0020_pin_search_path.sql, supabase/migrations/0021_cellar_write_paths.sql, docs/architecture-rulings.md, docs/findings-ledger.md, tests/schema_assertions.sql, supabase/migrations/0022_admission_and_authorship.sql, scripts/verify.sh, scripts/green.sh, tests/shim.sql, supabase/migrations/0023_subject_resolver.sql, supabase/migrations/0024_task_board_via_registry.sql, supabase/migrations/0025_bind_an_unbound_code.sql]
Depended on by: [CLAUDE.md, README.md, scripts/verify.sh]
---

# Status Ledger

## In one read

Some of this is built and most of it is not, and the grades below are the only place that says which. This ledger began by saying nothing was built, which was true when it was written and stopped being true without the sentence changing, which is the failure this file exists to prevent and committed itself. The point stands: the
boundary between designed and built should be a checkable fact from the first commit
rather than something reconstructed later.

The design is complete enough to build against and is not complete enough to be
correct. The sorry ledger holds the count and the detail; this ledger does not
repeat it. Two entries there, the topping lineage threshold and the
conditional-interval model, will change the schema when they are answered.

**The deadline is harvest**, which is weeks out and does not move. Build order in
spec.md section 7 is ordered by irrecoverability of failure, not by architectural
foundation: a bug in the board costs an afternoon, a bug in intake costs a bin that
cannot be reconstructed.

## Grades

**Built and verified.** Coded, and its check passes.
**In progress.** The boundary exists and the remainder is named.
**Specified.** Designed and named, ready to build.
**Deferred.** Named on purpose, with its condition for reactivation in the compost ledger.

## Stage 0: schema and structure

| Component | Grade | Notes |
|---|---|---|
| Core schema migration | Specified | `0001_core_schema.sql` written, never run |
| Derived views and functions | Specified | `0002_derived_and_rls.sql` written, never run |
| Row-level security | In progress | Policies exercised with three accounts in `tests/schema_assertions.sql`. The Supabase auth wiring above them is still unverified. See S-7 |
| Schema assertions | Built and verified | `tests/schema_assertions.sql`, 129 assertions, all passing, against the cellar database and against an empty one. Until now the suite ran only from empty: three assertions asserted properties of a winery that does not exist yet, so the first facility party made the suite red and the definition of done contradicted itself, since it says run the assertions and says use `db:up` because reset takes the inventory. The suite now stands any existing facility party down for the run and rolls it back, and the first-claimant rule asserts both halves |
| Cellar write paths | Built and verified | `0021_cellar_write_paths.sql`. 0002 made every update on `node`, `placement` and `vessel` admin only, and every kernel function written since 0007 runs as the caller, so racking, forking and setting a jacket were zero-row no-ops for a cellar user with no error. `is_cellar_staff()` widens the rows and a column allow-list on three triggers keeps `owner_id` and `hidden` out of reach, refusing in words and naming the column. Predicted by A14 in the review corpus four days before the racking screen existed. See S-36 and S-37 |
| Admission and authorship | Built and verified | `0022_admission_and_authorship.sql`. The four cheapest exploitable findings in the review corpus, closed together. `is_facility_user()` coalesced a missing party row to true, so deactivating a client promoted that login to full cellar read: probed before and after, 0 nodes visible while active and the facility's lot visible once switched off. Asking "are you a client" instead of "is your party a facility" removes the default entirely and discharges S-25 as well, since a token with no `app_user` row is now nobody. `event_insert` accepted any row whose `by_sensor` was not null, so a string in that column let anyone write history in somebody else's name: probed, then refused. Both vessel-photos policies admitted every login eighteen lines under the comment explaining why the bucket is private. `claim_task` was security definer with no view on the caller, so a null identity wedged a task permanently and an assigned task could be taken by a passer-by. See S-39, S-40 |
| Subject resolvers | Built and verified, kernel only | `0023_subject_resolver.sql`. `AR-E5`. `task.subject_type` and `task.subject_id` are a polymorphic pointer with no foreign key, which is structurally forced: a core table cannot reference a module that may not be installed. A module now registers a resolver as a row, and `relation` is text rather than `regclass` on purpose, because a regclass column would put the dependency back into `pg_depend`. Resolution deflates at every step: no resolver, no relation, no row, or a row the caller cannot see all answer null and none raises. Probed by dropping `block` and watching resolution go quiet. No screen reads it yet; phase 4 is what makes `task_board` use it. See S-41, S-42 |
| `task_board` through the registry | Built and verified | `0024_task_board_via_registry.sql`. `AR-E6` named this view as the single declarative reason core cannot install alone: its `CASE` over `subject_type` named `node`, `vessel`, `location` and `block`, and Postgres recorded that in `pg_rewrite`. Proven twice. The board returns byte-identical rows before and after across all four subject types plus a task whose subject does not exist, and `drop table block cascade` no longer reports a cascade to it, where it did an hour earlier. Two assertions hold it: one drops a module and checks the view survives, one reads `pg_depend` so it fails on the change rather than on the consequence. See S-42 |
| A cellar hand may label a barrel | Built and verified | `0025_bind_an_unbound_code.sql`. Ledger A22, ruled by the winemaker: bind an unbound code as anyone who works here, rebind one only as an admin, and the refusal names the barrel that already has the sticker. Done the way `0021` did it, a narrow insert policy rather than a blanket definer, so update and delete stay admin and the table cannot be rebound directly either. Both halves asserted, including the wording of the refusal. See S-43, because the permitted path is silent |
| The suite polices the schema | Built and verified | 190 assertions. Eight mutation classes in `scripts/mutate.sh`, measured rather than estimated. Row level security could be disabled on 16 of 21 tables in September and cannot be disabled on any of 22 now. The classes are deliberately split between existence and behaviour: `policy` drops a policy and `weaken` leaves it in place with a predicate of true, `check` drops a constraint and `loosen` leaves it in place as `check (true)`, because a pinned inventory catches the first of each pair and only a probe catches the second |
| Verifying the repository against itself | Built and verified | `scripts/verify.sh`, `bun run verify`. Seven checks: the typed header graph in both directions, the em dash rule, ledger cross references, counts stated in prose, that every command in the definition of done resolves, that this ledger does not contradict its own grades, and the module import rule. Each one was broken on purpose and observed to fail before being trusted. Its first run found forty nine one-directional header edges, which is the second time that invariant has been found broken. The module rule holds vacuously with one module besides core and says so rather than printing a green tick. No CI yet, by instruction: the checks had to exist before a pipeline could run them |
| Green as one command | Built and verified | `scripts/green.sh`, `bun run green`. Six things: verify, typecheck, lint, every migration from empty into a scratch database, the assertion suite against that database, and the assertion suite against a copy of the cellar. It reads the cellar with `pg_dump` and writes to it never. The two assertion counts differ by exactly one, the storage skip, and the script fails if they differ by anything else |
| The auth shim | Built and verified | `tests/shim.sql`. Three review runs reconstructed one, none committed it, and four grades rested on it for eight sessions, which is D1. Built to the W-1 specification, and its header says which migration needs which part: `0002` cannot apply without the realtime publication and has no guard, while `0005` and `0022` guard their storage blocks and skip with a notice. Discharges D1 |
| Account claim and walk kernel | Specified | `0005_account_and_walk.sql` written. Applies clean from empty after 0001 to 0004, against a scratch Postgres 16 |
| Terms and operation effects | Specified | `0004_terms_and_effects.sql` written. Applies clean from empty after 0001 to 0003, against a scratch Postgres 16 |
| Vessel thermal state | Built and verified | `0006_vessel_thermal.sql`. The jacket columns have existed since 0001 and `vessel_state` has always read them; no write path set them, so every vessel was unjacketed and `effective_temp_c` always fell through to the room. Both vessel screens now offer a jacket, mode and setpoint, and two check constraints refuse a mode without either. See S-18 |
| Vessel editing | Built and verified | `0007_vessel_edit.sql`. `update_vessel` applies a patch and, when the thermal triple changes, writes a `setpoint_change` against the vessel stamped `observed`. Tapping a vessel in the list opens the create form with its current values in it. Renaming records nothing; turning a jacket on records once, and saving the same state again records nothing. See S-18 |
| Filling an existing vessel | Built and verified | `0008_fill_vessel.sql`. Placement was written in one place only, inside `create_vessel_with_wine`, so an empty vessel stayed empty for good. `fill_vessel` completes the other half of build order 1. Refuses an occupied vessel in words rather than as a unique index violation. Inventory only, no source: see S-19 |
| Vessel type form shape | Built and verified | `0009_vessel_type_form.sql`. "Creator of" is one function with two contracts: a barrel wants coopers and calls it Cooper, a tank wants manufacturers and calls it Manufacturer, and `makers_for_vessel_type` returns the intersection. Each type also declares which optional fields open by default; the rest sit one tap into "More details". A maker with no contract satisfies every contract, so nothing added before this disappears. A vessel type added at runtime gets the neutral default and cannot configure itself until the term screens exist. `0010_glycol_by_type.sql` puts the jacket under the same mechanism: a tank opens it, a barrel keeps it behind More details, and neither hides it, because visibility is not permission |
| Vessel type field editor | Built and verified | `0011_vessel_type_fields.sql` and `0012_vessel_type_notes.sql`. A vessel type carries an ordered list of field descriptors, so adding oxygen ingress to tanks is a row edit rather than a release. `validate_vessel_attributes` enforces required, min and max, and that a term value comes from that field's own contract; a second trigger refuses a descriptor that would break the form. Editing is admin only; anyone signed in may leave a note against a type, which an admin resolves. Units are display only, see S-20 |
| Racking | Built and verified | `0014_rack.sql`. One operation, because the cellar has one: the caller says which vessels wine came out of and which it went into, and the kernel reads the shape to decide whether a lot moved or a new one was made. `rack_plan` runs the same rule without writing, so a screen can say what is about to happen. Loss is derived and never stored. Capacity is the one refusal, overridable and recorded. The screen previews live as you add legs and repeats the kernel's answer rather than working it out. Two bugs were found by reading the database after a browser run and not by the assertions: a lot in the destination was closed even when it still lived in another vessel, and shares were divided by what arrived rather than by what the parents contributed, so loss changed composition. Both fixed, both now asserted |
| A lot closes when empty | Built and verified | `0013_close_on_empty.sql`. Replaces `lineage_closes_parent`, which closed a lot the first time it fed anything. Taking 228 L off a 2000 L lot now leaves 1772 L, open. Discharges S-3, and corrects spec.md, which carried the old rule |
| Forking a lot, and inherited history | Built and verified, kernel only | `0015_fork_and_history.sql`. Recording against some of a lot's vessels and not all of them forks those vessels into their own lot, because otherwise the record claims the extra sulphur reached all four barrels. Nobody picks a mode; the kernel reads it off the shape. `node_history` walks lineage with a cutoff at each edge, so a shard inherits what happened before it came off and nothing after. Nothing is copied. No screen yet beyond the result page |
| Skins | Built and verified | `packages/cellar/src/skins.ts` plus a scoped override layer in `app.css`. The word is the repo's own: apps/web/src/index.ts always said a later session would host several. A skin is a stylesheet selected by `data-skin` on the root, chosen from a picker on the home screen and remembered. Original is the foundation, untouched, so adding a skin cannot alter the one already in somebody's muscle memory. Cellar is the second: cards, 54px targets against Original's 48, and a fill gauge drawn from a `--fill` custom property the vessel list publishes whether or not a skin uses it. Neither overflows horizontally at 375px. A skin may change how a thing looks and never what is asked or in what order, because that order is the schema's |
| The menu you start from | Built and verified | Home is now a menu grouped into what the cellar does, what is set up, and what is not built yet. The unbuilt entries are listed rather than hidden, in spec.md section 7's order, because a named gap is worth more than a blank space and that order is by irrecoverability rather than by appetite. They are readable and not tappable. The vessel list moved to its own screen behind a Vessels entry that carries the count |
| Ownership of wine | Built and verified | `node.owner_id` and the `node_read` scoping existed from 0003 and nothing ever set them, so every lot was the facility's whatever the truth was. A Clients screen creates custom crush parties and attaches a login, and the wine form asks whose wine it is with add-inline for a client. `0016_lot_owner_name.sql` puts the owner's name on `vessel_state`, because the screens were showing the vessel's owner under the word Owner, which read as Facility on a barrel of somebody else's wine. Whose barrel and whose wine are independent in both directions, asserted across all four combinations, and what a client sees is decided by the wine and never by whose barrel it sits in. See S-25 |
| Views obey their policies | Built and verified | `0017_vessel_state_rls.sql`. `vessel_state` ran with its owner's rights, so RLS on the tables under it did nothing and both custom crush clients could read every lot in the cellar by name from the vessel list. One line to fix. The assertions all queried tables while the screens query views, which is why it survived eight sessions; there is now a check that every view in public is security_invoker. See S-26 |
| Lot privacy, per field | Built and verified, kernel only | `0018_lot_privacy.sql`. The owner of a lot names which of seven fields the crew may not see: name, owner, variety, vintage, attributes, history, composition. What is missing from that list is the floor: that a vessel holds wine and how much, because the work stops otherwise. Seeing and controlling are split, so an admin reads every lot and cannot change what a client hid. A party carries a default that new lots inherit. Redaction is done by `visible_node`, so it holds against the API and not only against a screen. No screen yet. See S-27 |
| Procedures with timed steps | Kernel only, no screen | `0019_procedures.sql`. Barrel steaming is the worked case: initial rinse, steam, bung suction, final rinse as timed steps with targets an admin sets, then a solution step drawing on the `material_kind` vocabulary. A session lays out one run per barrel in the order they are done. Duration is the difference between two timestamps and is never stored. Leaks, rings and off smells are events on the vessel, so they outlive the session that noticed them, and `vessel_history` reads them back. See S-28 |
| Not losing your data | Built and verified | `bun run db:up` applies pending migrations and leaves the cellar alone; `db:reset` destroys it and is for proving migrations from empty, not for a development loop. CLAUDE.md said the wrong one and now says so. `db:backup` and `db:restore` exist and were tested by wiping and restoring, and the restore is honestly imperfect: see S-29. `0020_pin_search_path.sql` fixes what that testing uncovered, which is that thirty four functions broke under the empty search_path every dump sets |
| Term configuration screens | Deferred, partially reactivated | Deliberate. Seed data is the editor and add-inline covers the case that blocks a fresh install. See compost ledger C-6 |
| Parties, ownership, and vessel codes | Specified | `0003_parties_and_products.sql` written. Applies clean from empty against a scratch Postgres 16; never run against this project's own instance |
| Variety templates (seed) | Specified | Six protocols transcribed, not encoded |
| Location and vessel inventory | Specified | Requires a physical walk of the winery |
| Party records | Specified | The facility party and both custom crush clients. First thing the walk creates: `node.owner_id` defaults to the facility party, so no node can be inserted before it exists |

## Stage 1: capture

| Component | Grade | Notes |
|---|---|---|
| Backfill path, kernel | Built and verified | `create_vessel_with_wine`: vessel, lot, placement and codes in one transaction. Asserted |
| Backfill path, screens | In progress | Written, typechecked, built, and never run against a Supabase instance. The stranger's first run is the check and it has not happened |
| Sign up and account claim | In progress | `claim_account` asserted; the screens above it are unrun |
| First run, facility party | In progress | Screen written. It explains the wall rather than only showing a form |
| Code binding by camera | In progress | zxing for 1D and QR, with manual entry beside it rather than behind it. Never run against a camera |
| Inferred history generation | Built and verified | `generate_inferred_history` asserted. Generates nothing until a template exists, see S-17 |
| Intake screen | Specified | The one that must be solid before harvest |
| Press and destem | Specified | |
| Event entry | Specified | Manual transcription from Wine Meister |

## Stage 2: coordination

| Component | Grade | Notes |
|---|---|---|
| Tasks and board | Specified | Atomic claim function written in `0002` |
| Local-first sync | Specified | Append-only local, mutable server-side |
| QR codes on vessels | Specified | Barrels first; tanks are recognisable by name |
| Topping mode | Specified | Depends on QR |
| Cap management mode | Specified | Depends on QR and `cap_rule` |

## Stage 3: reconciliation

| Component | Grade | Notes |
|---|---|---|
| `doctor` | Specified | The only check on orphaned `subject_id` |
| Provenance audit view | Specified | What fraction of a number was never witnessed |
| Nightly git export | Specified | Backup and diffable daily record |
| Replay fixtures | Specified | Mid-harvest seed state for dev and forks |

## Stage 4: compliance and case goods

Nothing here is graded, because a grade would imply a design exists. Volume
losses (S-8), unit conversion (S-9), tax class (S-10), bond status (S-11), and
the bottling seam (S-12) are named in the sorry ledger and are blocked on the
winery's compliance advisor. They are listed as a stage so that their absence is
visible here rather than only in the sorry ledger.

The one with a date on it is S-12. Bottling happens whether or not the event that
records it is complete.

Activity costing (S-14) sits on top of all five and is not reachable until they are
answered. A cost per case computed from unreconciled volumes looks authoritative and
is not, which is the failure mode this whole stage is arranged to avoid.

## Specified, not scheduled

Section 8 of the spec, scouted from commercial platforms. Designed and named, and
absent from the section 7 build order on purpose: that order is by irrecoverability
of failure and none of these are irrecoverable.

| Component | Grade | Notes |
|---|---|---|
| Dry goods with live depletion | Specified | `material` and `material_use`. Not a purchase order system |
| Work orders | Specified | Grouping table plus a print view. Tasks stay standalone |
| Reverse block view | Specified | Derived, per T0-2. Same traversal as `block_composition` |
| Clone and rootstock on `block` | Specified | Structured fields, not `notes` |

## Deferred on purpose

Direct BLE to the EasyDens meter. See compost ledger C-1.
