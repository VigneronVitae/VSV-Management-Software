---
Type: record
Purpose: "Records the single source of build truth for the winery app, so every other document cites status here rather than re-asserting it."
Depends on: [packages/cellar/docs/spec.md, docs/sorry-ledger.md, docs/compost-ledger.md, docs/methodology-lineage.md, supabase/migrations/0001_core_schema.sql, supabase/migrations/0002_derived_and_rls.sql, supabase/migrations/0003_parties_and_products.sql]
Depended on by: [CLAUDE.md, README.md]
---

# Status Ledger

## In one read

Nothing is built. This ledger exists before the code does, which is the point: the
boundary between designed and built should be a checkable fact from the first commit
rather than something reconstructed later.

The design is complete enough to build against and is not complete enough to be
correct. Six open questions in the sorry ledger are load-bearing, and two of them
(the topping lineage threshold and the conditional-interval model) will change the
schema when answered.

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
| Row-level security | Specified | Written; untested against a real second user |
| Variety templates (seed) | Specified | Six protocols transcribed, not encoded |
| Location and vessel inventory | Specified | Requires a physical walk of the winery |

## Stage 1: capture

| Component | Grade | Notes |
|---|---|---|
| Backfill path | Specified | Vessel + lot + placement in one action |
| Inferred history generation | Specified | Template run in reverse, stamped `inferred` |
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

## Deferred on purpose

Direct BLE to the EasyDens meter. See compost ledger C-1.
