---
Type: record
Purpose: "The file a fresh session with no memory reads first before continuing the W-2 modularization. Holds the phase list and its state, the last green commit, the current migration number, every decision made and why, and everything discovered that changes a later phase."
Depends on: [docs/architecture-rulings.md, docs/findings-ledger.md, docs/session-reports/2026-09-11-verification-surface.md, scripts/green.sh]
Depended on by: [docs/session-reports/index.md]
---

# W-2 modularization: progress

**This is not a session report.** It is the handover file. It is written to be
sufficient on its own for a session that has never seen this work, and it is updated
at the end of every phase and whenever a decision is made that a later session would
otherwise have to derive again.

## How to resume

1. Read this file.
2. Verify the tree matches what it claims: `git log --oneline -1` against the last
   green commit below, and `ls supabase/migrations/ | tail -1` against the current
   migration number.
3. Run `bun run green`. If it is not green, the tree does not match this file and
   that is the first thing to resolve.
4. Continue at the first phase marked not-started.

Do not start a phase you cannot finish. Finishing means green and committed.

## The rules this work runs under

**Green means all of:** `bun run verify`, `bun run typecheck`, `bun run lint`, every
migration applying clean from empty into a scratch database, the assertion suite
passing against that scratch database, and the assertion suite passing against a copy
of the cellar. `bun run green` runs all six and exits non-zero if any fails.

**The cellar database has real harvest data in it.** Use `bun run db:up`, never
`db:reset`, and never run a destructive statement against it. `green.sh` touches it
only with `pg_dump`, which reads.

**Stop conditions**, from the W-2 prompt: a migration that cannot apply to both an
empty and a populated database; the assertion count falling; needing a change to the
hosted Supabase project's settings; a phase needing a decision the rulings do not
cover; or a defect found in the unreviewed range serious enough that continuing would
build on top of it. Halting with a clear write-up is a good outcome.

## State

| | |
|---|---|
| Last green commit | `1b1ad2f` |
| Current migration number | `0022`, so the next one is `0023` |
| Assertions | 128 from empty, 129 against the cellar copy |
| Module migration numbering | not yet designed, phase 6 designs it |

## Phases

| Phase | What | State |
|---|---|---|
| 0 | Reach green at all | done |
| 1 | Namespace collision, rulings ids to `AR-` | not started |
| 2 | Read the unreviewed range, `0006` to `0022`, plus the mutation score | not started |
| 3 | The resolver registry, `AR-E5` | not started |
| 4 | `task_board` against the registry, `AR-E6` | not started |
| 5 | Enums to registry rows, `AR-E7` | not started |
| 6 | The scheduling block to core, plus per-module migration numbering | not started |
| 7 | The schema split and the `public` facade, plus the `AR-B8` gate check | not started |
| 8 | The manifest and the register, plus the `AR-F5` falsifier | not started |

Phase 7 is conditional on phase 2's mutation score. If it has not improved on the 42
percent the `G-5` run measured against 28 assertions, that is a stop condition for
phase 7 specifically, because a schema move policed by a suite that misses more than
half of injected defects is not policed.

## Phase 0: reach green at all

Not in the W-2 prompt. It exists because W-2 defines green as including `bun run lint`
and two database halves, and none of the three could pass when the session started.

**`bun run lint` could not pass on this checkout.** Forty of ninety eight tracked files
arrive in the working tree with CRLF, because `core.autocrlf` is true on this machine,
and Biome refuses six of them on that alone. Every committed blob is already LF, so
this was never a content problem. `.gitattributes` now pins `eol=lf`, which changes no
file's content and changes what checkout writes.

*Recorded because it was got wrong twice:* the previous session diagnosed this
correctly, and the check used to confirm it at the start of this session,
`grep -q $'\r'`, reported zero CRLF files on a tree where python counted forty. Count
bytes. Do not use grep for this.

**One real lint error**, at `walk.ts:1497`, a `forEach` callback returning the value of
`parts.push()`. Rewritten as a `for...of`. This is the only client change in W-2 and it
is not a section B defect; it is the linter being unable to pass.

**`tests/shim.sql` is committed**, which discharges D1. Not a W-2 phase either, but
green requires all migrations to apply from empty every phase, and that needs the shim
every time. It is built to the specification in W-1 and its header says which migration
needs which part of it, because the next person will otherwise assume it is optional:
`0002` cannot apply without the realtime publication and has no guard, while `0005` and
`0022` guard their storage blocks and skip with a notice.

**`scripts/green.sh` and `bun run green`** exist for the same reason: eight phases each
ending green means running this many times, and a gate that is six commands run by hand
is a gate that gets partially run.

**`verify.sh` now scans `.sh` files.** It did not, which meant its own typed header was
the one header in the tree that nothing checked. That header named `package.json`,
which carries no header and never could, so the edge could not have resolved. Fixed in
both directions.

### The two assertion counts differ by one, on purpose

128 from empty and 129 against the cellar copy. The scratch database has no storage
schema, so the two vessel-photos policy assertions report that they were not asserted
instead of asserting two things. `green.sh` checks that the difference is exactly one
and fails if it is anything else, so this cannot quietly become a real gap.

## Decisions

| Decision | Why |
|---|---|
| `.gitattributes` pins `eol=lf` tree-wide | Green includes lint, lint could not pass, and no blob content changes |
| The shim lands now rather than in a W-1 follow-up | Green includes a from-empty build every phase |
| `green.sh` exists | Six commands run by hand is a gate that gets partially run |
| `verify.sh` scans `.sh` | Otherwise the checker's own header is unchecked |
| Scratch and copy counts may differ by exactly one | The storage skip, and only that |

## Discovered, and it changes a later phase

**`0020` breaks on any install where pgcrypto lands in `public`.** It pins
`search_path` on every function in `public` with no `proconfig`, which on such an
install includes `digest`, and it fails with "must be owner of function digest".
`tests/shim.sql` puts pgcrypto in `extensions` where Supabase puts it, so the shim
matches the real thing and the defect stays visible rather than being papered over.
This matters for phase 7: moving tables into module schemas does not move functions
unless somebody says so, and `0020`'s "every function in public" becomes "every
function in which schema" the moment there is more than one.

**`verify.sh` currently exempts `docs/architecture-rulings.md` from the compost
cross-reference check by name.** Phase 1 removes that exemption, and phase 1 is not
done until it is gone.

## Predictions made, for later scoring

Recorded now so they cannot be quietly revised. The previous session's corpus earned
its credibility from the runs that disclosed their own misses.

1. Phase 2 will find at least one more write path that runs as the caller against an
   admin-only policy, beyond the six `0021` fixed.
2. The mutation score will have improved but not enough, landing between 55 and 75
   percent, because the new assertions were written against known defects rather than
   against the schema generally.
3. Phase 8's `AR-F5` falsifier will pass, meaning winemaking installs with no vineyard
   module once `block_id` is gone, because `block_id` really does look like the only
   coupling.
