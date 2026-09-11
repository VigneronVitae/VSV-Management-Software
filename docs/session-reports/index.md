---
Type: record
Purpose: "Indexes the session reports, and states the convention they follow, so a report added later is findable rather than orphaned."
Depends on: [docs/session-reports/2026-09-08-scaffold.md, docs/session-reports/2026-09-08-walk.md, docs/session-reports/2026-09-10-wire.md, docs/methodology-lineage.md]
Depended on by: [README.md]
---

# Session reports

One report per working session. A report records what was decided and why, for
the decisions that happened in conversation and would otherwise exist nowhere in
the repository. The ledgers record gaps and kills; commit messages record
changes; neither records the reasoning that produced a shape nobody asked about
afterward.

## Convention

A report is history. It describes the repository as it stood on a date and does
not become stale when the repository moves on, so every report carries
`Depends on: []`. The edge runs the other way: this index depends on the
reports, because adding one makes this file wrong until it is updated. Adding a
report means adding a row below and naming this index in the report's
`Depended on by`.

Reports are append-only, per T0-5. A report that turns out to be wrong gets a
correction in a later report, not an edit.

## Reports

| Date | Session | What it covers |
|---|---|---|
| 2026-09-08 | [Repository scaffold](2026-09-08-scaffold.md) | Layout, migration 0003, ledger updates, spec correction and additions, tooling |
| 2026-09-08 | [Terms, effects, and the walk](2026-09-08-walk.md) | Migrations 0004 and 0005, schema assertions, the inventory walk screens |
| 2026-09-10 | [The wire, and what was behind it](2026-09-10-wire.md) | Real Supabase and a phone, migrations 0006 to 0020, four security defects, not destroying the data, and an assessment of five commercial patterns |
