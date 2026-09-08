---
Type: record
Purpose: "Records the single source of build truth for the winery app, so every other document cites status here rather than re-asserting it."
Depends on: [packages/cellar/docs/spec.md, docs/sorry-ledger.md, docs/compost-ledger.md, docs/methodology-lineage.md, supabase/migrations/0001_core_schema.sql, supabase/migrations/0002_derived_and_rls.sql, supabase/migrations/0003_parties_and_products.sql, supabase/migrations/0004_terms_and_effects.sql, supabase/migrations/0005_account_and_walk.sql, tests/schema_assertions.sql]
Depended on by: [CLAUDE.md, README.md]
---

# Status Ledger

## In one read

Nothing is built. This ledger exists before the code does, which is the point: the
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
| Schema assertions | Built and verified | `tests/schema_assertions.sql`, 28 assertions, all passing. The `psql` half of the definition of done in CLAUDE.md now exists |
| Account claim and walk kernel | Specified | `0005_account_and_walk.sql` written. Applies clean from empty after 0001 to 0004, against a scratch Postgres 16 |
| Terms and operation effects | Specified | `0004_terms_and_effects.sql` written. Applies clean from empty after 0001 to 0003, against a scratch Postgres 16 |
| Term configuration screens | Deferred | Deliberate. Seed data is the editor and add-inline covers the case that blocks a fresh install. See compost ledger C-6 |
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
