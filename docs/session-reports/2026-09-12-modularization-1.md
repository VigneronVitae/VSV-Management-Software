---
Type: record
Purpose: "Records the first W-2 modularization session: reaching green at all, separating three colliding id namespaces, reading the fifteen migrations no review had seen, measuring the mutation score that stops the schema split, and building the resolver registry that takes the last module name out of core."
Depends on: []
Depended on by: [docs/session-reports/index.md]
---

# 2026-09-12: modularization, the first session

Phases 0 to 4 of eight. Phases 7 and 8 are blocked by W-2's own stop condition.
Phases 5 and 6 are open. `docs/session-reports/modularization-progress.md` is the
handover file and is sufficient on its own.

## What green cost before any phase could start

W-2 defines green as six things: verify, typecheck, lint, every migration from empty
into a scratch database, the assertion suite there, and the assertion suite against a
copy of the cellar. Three of the six could not pass.

`bun run lint` could not pass on this checkout. Forty of ninety eight tracked files
arrive in the working tree with CRLF because `core.autocrlf` is true here, and Biome
refuses six of them on that alone. Every committed blob is already LF, so
`.gitattributes` pinning `eol=lf` changes no file's content and changes only what
checkout writes. One real lint error survived the formatting and is fixed.

The from-empty half needed the auth shim that three review runs each rebuilt and none
committed. `tests/shim.sql` is now in the tree, which discharges D1, and its header says
which migration needs which part of it rather than leaving the next person to assume the
file is optional.

`scripts/green.sh` and `bun run green` exist because eight phases each ending green means
running this many times, and a six-command gate run by hand is a gate that gets partly
run. It reads the cellar with `pg_dump` and writes to it never.

## The number that stops the schema split

W-2 makes phase 7 conditional on the mutation score improving on the 42 percent the
`G-5` review measured. It has not.

| Set | Mutations | Caught | Score |
|---|---|---|---|
| Everything, at migration `0022` | 115 | 28 | **24%** |
| Only objects that existed at the reviewed baseline | 71 | 15 | **21%** |
| Only objects added since `0006` | 44 | 13 | 30% |
| `G-5`, on its own 45 | 45 | 19 | 42% |

By class: check constraints 13 percent, unique constraints and indexes 12 percent,
triggers 89 percent, policies 20 percent, row level security disable 24 percent.

The denominators differ, because `G-5` chose 45 mutations and `scripts/mutate.sh`
enumerates 115 from the catalog, so the second row is the fair read: on the same objects,
with a larger and more systematic set, the suite catches 21 percent. Absolute catches
rose from 19 to 28 while the schema roughly doubled. The suite grew and its coverage of
the schema fell.

The single most quotable result is that row level security can be turned off outright on
16 of 21 tables and the suite still passes. The five that are caught are the ones an
assertion happens to read through a second principal.

So phase 7 is blocked and phase 8 with it. A schema move is exactly the operation that
silently changes which policies apply to which rows, and the policy class scores 13 to 20
percent. W-2's instruction is to say so plainly and stop.

The harness is committed, which `G-5`'s was not. That was the same defect as D1 applied
to a measurement rather than to a shim: a number nobody can reproduce cannot be improved
against.

## What the unreviewed range turned out to contain

Fifteen migrations, `0006` through `0022`, that the thirteen-report corpus never saw.
Read against the five patterns W-2 names. Two new findings, three infrastructure entries,
and the findings ledger is now 1.1.

**A22 confirms the prediction made before the read started.** There is a seventh write
path running as the caller against a policy that refuses it: `bind_vessel_code`, invoker,
inserting into `vessel_code`, whose only write policy is `is_admin()`. A cellar user
cannot put a sticker on a barrel. It differs from A14's class in failing loudly, because
a refused INSERT violates a `with check` and raises where a refused UPDATE matches zero
rows and says nothing.

It is filed rather than fixed, and that is a judgment worth stating: whether a cellar hand
may label a barrel is a fact about how the winery runs, not a defect an agent should
decide unsupervised. Creating a vessel is admin work and the suite asserts that on
purpose. Labelling one during harvest may not be.

The search was exhaustive rather than a spot check. Every function in `public` was matched
against every table it writes, and every such table's insert and update policies read.

**A23** is `vessel_type_note`, added by `0012` with `using (true)` on select, which is
A5's blanket default arriving on new surface seven migrations after A5 was filed. The
five tables `0019` added do not repeat it, so the habit changed mid-session.

**What the read checked and did not find** is written into the ledger as its own section,
because a review that reports only its finds cannot be told apart from one that stopped
early. No new instance of A10: `vessel_history` left-joins the nullable author, which is
the correct shape and the opposite of A10's mistake. No new instance of A18 or A19: two
columns were added in the whole range and both are stored choices, and
`procedure_run_state`, which carries `actual_seconds` and looked like the exception, is a
view.

And one risk `0022` introduced last session without noticing. Tightening `event_insert`
to `by_user = auth.uid() and by_sensor is null` would break any function writing an event
in another name. All six that insert into `event` were checked and every one writes
`auth.uid()`. No path breaks. That could have gone the other way.

## Three documents had claimed one id shape

`docs/compost-ledger.md` has used `C-1` onward since before either of the others existed.
`docs/findings-ledger.md` numbers its findings `A1` to `E12` without hyphens, which does
not collide. `docs/architecture-rulings.md` numbered its sections `A-1` to `J-2`, which
collides with the compost ledger on `C-1` through `C-4` directly, and `verify.sh` carried
an exemption naming the rulings file to work around it.

All seventy ruling ids are now `AR-` prefixed, 107 references updated, nothing else about
the document changed. Two `A-1` references are deliberately not renamed because they name
the review prompt rather than a ruling, and after the rename a bare `A-1` means the prompt
with no overlap.

The exemption is gone and `verify.sh` gained an `AR-` cross-reference check, because
separating namespaces stops two documents meaning different things by one string and only
checking them stops a reference pointing at nothing. That earns itself immediately: the
findings ledger cites "E-4's premise" and `E-4` resolves to nothing in this repository
under any reading. Left as it stands rather than guessed at.

## The last module name is out of core

`0023` builds the resolver registry, `AR-E5`. `0024` rewrites `task_board` against it,
`AR-E6`.

The property that matters in `0023` is an absence: `subject_resolver.relation` is `text`
and not `regclass`, because a `regclass` column would record the dependency in `pg_depend`
and put back exactly the edge the registry removes. An assertion checks the column's type,
so the next person who helpfully tightens it will be told what they broke. Resolution
deflates at every step, per `AR-B7` and `AR-G2`, and `resolve_subject_name` is invoker
twice over so the stored expression cannot escalate and row level security still evaluates
as the caller.

`0024` is proven two ways. The board returns byte-identical rows before and after across
all four subject types plus a task whose subject does not exist. And `drop table block
cascade` reported a cascade to `task_board` before and reports only `node_block_id_fkey`
after, which is `node.block_id`, `AR-F5`, phase 7's business.

An assertion written in phase 3 to report which of two states it was in now asserts the
first one, and its text did not change. It was written to start saying the other thing
when phase 4 landed.

## Deviations from the prompt

**A lateral join is not possible here.** W-2 and `AR-E5` both say `task_board`'s `CASE`
becomes a lateral join. A lateral join needs the relation known when the statement is
planned, and the registry's whole point is that it is not known until a row is read, so a
view cannot have one. A scalar call is the achievable form of the same idea and buys the
same property. The cost is S-42, one dynamic query per row, filed in `0023` as a trade and
taken in `0024`.

**Phase 0 is not in the prompt.** It exists because W-2's definition of green could not be
met when the session started.

## Predictions, scored

Recorded before phase 2 ran, so they could not be quietly revised.

1. *A seventh write path running as the caller against an admin-only policy exists.*
   **Correct.** A22.
2. *The mutation score will have improved but not enough, landing between 55 and 75
   percent.* **Wrong, in the optimistic direction.** It is 24 percent, and 21 on the
   comparable subset, which is a decline rather than a small improvement. The reasoning
   behind it was right and incomplete: writing good assertions about the defects you just
   fixed still loses ground when the schema grows faster than the suite.
3. *Phase 8's `AR-F5` falsifier will pass.* Not yet testable. Phase 8 is blocked.

## Two tooling traps that cost real time

**A heredoc collapses a doubled backslash.** Writing a shell script through one turns a
Python `'\\b'` into `'\b'`, which Python reads as an escape and writes as a single
backspace byte. The script parses, `grep -n` prints the line as though the backslash were
there, and the check silently matches nothing. It hit the `S-` and `C-` boundaries in the
previous session and the `AR-` boundary in this one, which was committed broken in phase 1
and caught by its own break test. Count `0x08` bytes; do not read the line.

**`git checkout --` on a file with uncommitted work discards it.** A break test that
restores files that way reverted the whole phase 1 rename. Commit first, then break-test.
That was done correctly in the previous session and wrongly here.

Both belong in a report rather than only in a commit message, because the general lesson
is the one the checker exists to enforce arriving from the inside: a check nobody has
watched fail is not a check.

## What is open

Phase 5, the two core enums becoming registry rows, and phase 6, the scheduling block
moving to core with per-module migration numbering. Neither is gated on the mutation
score by W-2's text.

Phase 5 deserves a note before somebody starts it. `term_kind` appears in nine generated
columns, in a composite foreign key, and in the signature of most functions that touch
vocabulary. Converting it is a large migration whose failure modes are exactly the classes
the mutation score is worst at: check constraints at 13 percent and unique constraints at
12. W-2 gates only phase 7 on that number, and this is not a refusal to do phase 5, but
the same argument that blocks the split applies to it in weaker form and somebody should
decide that deliberately rather than by not noticing.
