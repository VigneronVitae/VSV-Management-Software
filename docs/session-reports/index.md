---
Type: record
Purpose: "Indexes the session reports, and states the convention they follow, so a report added later is findable rather than orphaned."
Depends on: [docs/session-reports/2026-09-08-scaffold.md, docs/session-reports/2026-09-08-walk.md, docs/session-reports/2026-09-10-wire.md, docs/session-reports/2026-09-11-verification-surface.md, docs/methodology-lineage.md, docs/session-reports/modularization-progress.md, docs/session-reports/2026-09-12-modularization-1.md, docs/session-reports/2026-09-12-assertion-suite.md, docs/session-reports/2026-09-12-harness-and-enums.md, docs/session-reports/2026-09-12-repair-the-instrument.md]
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
| 2026-09-11 | [The verification surface](2026-09-11-verification-surface.md) | The red team corpus archived, `scripts/verify.sh`, migrations 0021 and 0022, the write paths that silently did nothing, and the four cheapest exploitable findings |
| 2026-09-12 | [Modularization, the first session](2026-09-12-modularization-1.md) | W-2 phases 0 to 4: reaching green, the `AR-` namespace, the fifteen unreviewed migrations, the mutation score that blocks the schema split, and the resolver registry that takes the last module name out of core |
| 2026-09-12 | [Making the suite police the schema](2026-09-12-assertion-suite.md) | W-3: row level security asserted to be on at all, the constraint surface pinned and probed, the mutation score from 24 percent to 188 of 188, A24 found by writing an assertion, and A22 built to the winemaker's ruling |
| 2026-09-12 | [The instrument, the class, and both enums](2026-09-12-harness-and-enums.md) | W-4: the harness taught to report what it excluded, the null-permit shape filed as class A25 with no fourth instance found, and `subject_type` and `term_kind` turned into registry rows |
| 2026-09-12 | [Repair the instrument](2026-09-12-repair-the-instrument.md) | W-6, after the second review round: eleven fail-open paths closed, the mutation score split into a behavioural gate of 117 of 214 and a snapshot change detector of 86, and the procedural surface measured at five of sixteen by somebody who did not write the list |
