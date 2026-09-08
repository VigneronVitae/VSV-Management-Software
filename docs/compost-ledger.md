---
Type: record
Purpose: "Records approaches killed for the winery app, with the condition under which each would be reconsidered."
Depends on: [packages/cellar/docs/spec.md, docs/methodology-lineage.md]
Depended on by: [docs/status-ledger.md, CLAUDE.md, README.md]
---

# Compost Ledger

An approach that was killed without a record is one that gets rebuilt. Each entry
carries what was tried, why it died, and what would bring it back.

**C-1. Direct BLE to the Anton Paar EasyDens.**
*Tried:* reading the meter directly and skipping Wine Meister entirely.
*Killed by:* no published SDK or API, no public reverse-engineering to build on, and
the raw characteristic may return oscillation frequency rather than density, which
would mean reimplementing Anton Paar's temperature correction and calibration.
Compounding: Web Bluetooth does not work in Safari on iPadOS, so a PWA on the harvest
device cannot talk to the meter at all, which forces a native app and a platform
decision.
*Reactivate if:* manual transcription volume becomes the actual constraint, or the
device platform changes off iPad.

**C-2. Git as the datastore.**
*Tried:* using a repository as the live data store, on the model of the Knowledge Game
snapshot pattern.
*Killed by:* every write becomes a commit; concurrent barrel scans produce merge
conflicts on JSON; textual merge is meaningless for structured records; task claiming
is exactly the case it handles worst; and it would require pushing write credentials to
interns' phones. Latency also defeats the shared-state purpose.
*Surviving fragment:* nightly export to a repo for version history and offsite backup,
out of band, with no role in the live path. Adopted.
*Reactivate if:* the app becomes single-user and read-mostly.

**C-3. Storing block composition on the node.**
*Tried:* a `blocks` column carrying the proportional composition of each lot.
*Killed by:* it is derivable from lineage fractions, and two sources of truth diverge
the first time a volume is corrected. Violates T0-2.
*Surviving fragment:* a refreshed index over the derived function, for filtering.
*Reactivate if:* traversal performance becomes a real problem at real data volumes,
in which case it returns as a cache with an explicit staleness marker, not as truth.

**C-4. Template versioning on the lot.**
*Tried:* copying a versioned template onto each lot at instantiation so lots in flight
are insulated from template edits.
*Killed by:* the template is only an autopopulator. Steps diverge by grape and vintage
as a matter of course, so divergence is the norm and versioning would answer a question
nobody asks.
*Surviving fragment:* `created_from` on the task, recording that a step was seeded
rather than added by hand.

**C-6. Configuration screens for the term vocabulary.**
*Tried:* admin screens for creating, editing, reordering and deactivating terms:
varieties, coopers, woods, vessel types, operations.
*Killed by:* seed data plus an add-inline path on every picker already covers the
only case that actually blocks anyone, which is a picker with no rows in it on a
fresh install. A separate configuration surface would be a second way to do the
same thing, and it would be built before anyone had discovered which fields they
actually want to edit.
*Surviving fragment:* add-inline on every picker, which writes a term and selects
it without leaving the form. Adopted.
*Reactivate if:* someone needs to deactivate, reorder or relabel terms in bulk, or
a fork's vocabulary diverges far enough that seeding this winery's list is the
wrong starting point.

**C-5. Pick as the atomic intake unit.**
*Tried:* modelling each pick as a lot, with three Pinot Gris picks as one lot carrying
a pick attribute.
*Killed by:* bins carry blocks, and press loads are assembled from bins across blocks,
so the bin is atomic and the pick is not. Also, a lot is created by the operation that
combines material, not by arrival: two days of Riesling pressed together is one lot,
and modelling it otherwise would force a split that never happened.
