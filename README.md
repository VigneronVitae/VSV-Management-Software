---
Type: reference
Purpose: "Orients a new reader: what this repository is, where its build truth lives, how to run it locally, and what to read next."
Depends on: [CLAUDE.md, packages/cellar/docs/spec.md, docs/status-ledger.md, docs/sorry-ledger.md, docs/compost-ledger.md, docs/session-reports/index.md]
Depended on by: [docs/first-run.md, scripts/undefined-sites.sh]
---

# VSV Management Software

Production tracking for a small Willamette Valley winery. Bins of fruit become
lots, lots move between vessels, people record what they did. Postgres on
Supabase, a static PWA client, phones in a barn.

The cellar module comes first, because production is where a missed record is
unrecoverable. Custom crush clients own wine here, so ownership is in the schema
from the start rather than retrofitted.

Built against the 2026 harvest at one winery, and built to be given to other
winemakers once that vintage proves it.

## State

`docs/status-ledger.md`. It is the single source of build truth and every
component in it is graded. A maturity claim anywhere else in this repository,
this file included, is wrong by construction, which is why this section is a
pointer rather than a description.

## Running locally

Prerequisites: [Bun](https://bun.sh) and the
[Supabase CLI](https://supabase.com/docs/guides/cli).

```sh
bun install
supabase start
bun run db:up                     # applies the migrations, keeps any data
cp apps/web/.env.example apps/web/.env.local
# fill VITE_SUPABASE_ANON_KEY from the `supabase start` output, and set
# VITE_SUPABASE_URL to the API URL it printed
bun run dev                       # the client, at http://localhost:5173
```

Then open it and follow the screens: create an account, name yourself, name the
facility. The first account becomes the administrator. `docs/first-run.md` walks
the rest.

**`bun run db:reset` destroys every row in the database and is not part of
setting up.** It is how you prove the migrations apply from empty. `project_id`
in `supabase/config.toml` is fixed, so a second clone on the same machine talks
to the same containers as the first, and running it there resets the first
clone's database too. Use `bun run db:up` unless you mean it.

`bun run typecheck` and `bun run lint` check the client. `bun run doctor` is the
data-integrity check and currently exits non-zero on purpose, because it is not
implemented; see sorry S-4.

The Supabase CLI is a prerequisite and is not a dependency of this repository. If
`supabase` is not on your path, `npx supabase@2.34.3 <command>` works for all of
the above.

## Where to read next

| File | What it is |
|---|---|
| `CLAUDE.md` | The agent contract. Read order, hard rules, what done means |
| `packages/cellar/docs/spec.md` | The design. Object model, modes, build order |
| `docs/status-ledger.md` | What is built |
| `docs/sorry-ledger.md` | What is open, and which gaps are load-bearing |
| `docs/compost-ledger.md` | What was killed, and what would bring it back |
| `docs/methodology-lineage.md` | Why the repository carries the apparatus it does |
| `docs/session-reports/` | What each working session decided, and what it left open |

## Licence

Apache 2.0. See `LICENSE`. Apache rather than MIT for the explicit patent grant,
and rather than AGPL so that another winemaker can adopt this without licence
friction.
