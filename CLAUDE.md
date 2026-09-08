---
Type: contract
Purpose: "The working contract for any agent operating in this repository: what to read, what is forbidden, and what done means."
Depends on: [packages/cellar/docs/spec.md, docs/status-ledger.md, docs/sorry-ledger.md, docs/compost-ledger.md, docs/methodology-lineage.md]
Depended on by: [README.md]
---

# CLAUDE.md: agent contract

Read `packages/cellar/docs/spec.md` before any non-trivial change. It is the single source of design
truth. `docs/status-ledger.md` is the single source of build truth: if a maturity
claim appears anywhere else in this repo, it is wrong by construction.

## What this is

A production-tracking app for a two-label Willamette Valley winery. Bins of fruit
become lots, lots move between vessels, people record what they did. Postgres on
Supabase, static PWA client, phones in a barn.

**Disposable by declaration.** This is a working tool for one harvest, not a product.
Do not build for scale, do not add abstraction layers for hypothetical second users,
do not generalise a thing used in one place. If it survives to a second harvest, that
is a decision made afterward.

**The deadline is harvest and it does not move.** Build order in spec.md §7 is ordered
by irrecoverability of failure, not by architectural elegance. A bug in the task board
costs an afternoon. A bug in intake costs a bin that cannot be reconstructed.

## Read order

1. `packages/cellar/docs/spec.md`: object model, modes, build order
2. `docs/status-ledger.md`: what is built, graded
3. `docs/sorry-ledger.md`: open gaps, seven of them, three load-bearing
4. `docs/compost-ledger.md`: what was killed and what would revive it
5. `docs/methodology-lineage.md`: what each piece of apparatus is for, and the
   condition under which dropping it is correct

## Hard rules

- **Consult before adding ANY dependency or external service.** Standing instruction.
  Use what is installed. If you believe something is genuinely required, say so and
  wait; do not install and explain afterward.
- **Never write a trust field on behalf of a producer.** `provenance` is set by the
  verifier. An agent generating inferred history writes `inferred` and may never
  write `confirmed`. This is axiom T0-4 and it is not negotiable for convenience.
- **Never store what is derived.** Block composition, variety composition, and vessel
  occupancy are functions. If you find yourself adding a column that caches one of
  these, stop and read compost entry C-3 first.
- **Events are append-only.** Corrections are new events. Do not add an update path
  for cellar users, however much simpler it looks.
- **Check the compost ledger before proposing an approach.** Five entries, each with
  a reactivation condition. If your idea is in there, either meet the condition
  explicitly or pick something else. Rebuilding a killed approach without addressing
  why it died is the specific failure this file exists to prevent.
- **A new gap goes in the sorry ledger before the code that creates it.** Not after,
  not in a comment, not in a commit message.
- **Ids are client-generated uuids.** Never sequences. An offline write must have
  identity before the server sees it.
- **A module package may import from `core` and never from a sibling module.**
  `cellar` may use `core`; a future `cases` or `sales` module may use `core` and
  may not reach into `cellar`. Shared code moves down into `core` or gets
  duplicated, whichever is smaller. Lint will enforce this once there is code to
  enforce it against; until then it is enforced here.

## What done means

Not "it runs." Done is:

```sh
# schema
supabase db reset                 # migrations apply clean from empty
psql < tests/schema_assertions.sql # constraints actually refuse what they should

# client
bun run typecheck                 # zero errors, no suppressions added
bun run lint
bun run test

# the winery-specific one
bun run doctor                    # reports nothing, against replay fixtures
```

`doctor` is not optional. `event.subject_id` cannot be a foreign key (sorry S-4), so
`doctor` is the only thing standing between the schema and orphaned records. Run it
before considering any data-path change finished.

## Removed on purpose

Recorded here so nothing rebuilds them. Full reasoning in the compost ledger.

- Direct Bluetooth to the Anton Paar meter. Killed 2026-09. Web Bluetooth does not
  work in Safari on iPadOS and there is no published SDK. (C-1)
- Git as the live datastore. Killed 2026-09. Nightly export survives; the live path
  does not. (C-2)
- Template versioning on the lot. Killed 2026-09. `created_from` on the task is the
  surviving fragment. (C-4)

## Conventions

Every document carries a typed header: `Type`, `Purpose`, `Depends on`,
`Depended on by`. Migrations additionally name the axioms they enforce and the
sorries they leave open. Keep both directions of the dependency fields accurate; a
one-directional link is a broken link.

Comments explain why, not what. A comment restating the code is noise. A comment
naming which axiom a constraint enforces, or why an obvious simpler approach was
rejected, is the thing that makes this repo navigable in six months.

No em dashes anywhere, in code comments, docs, or commit messages.

## Working with the winemaker

He is the domain expert and he is also the one who wrote the schema. When something
in the model looks wrong, it is roughly as likely to be a real modelling error as a
piece of winery practice you do not know about. Ask which before changing it.

During harvest he is unavailable for hours at a stretch. Prefer leaving a named gap
in the sorry ledger over guessing at domain semantics.
