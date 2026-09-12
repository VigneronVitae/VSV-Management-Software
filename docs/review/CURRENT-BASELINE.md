---
Type: reference
Purpose: "States what this tree currently is, for a reviewer arriving with the archived prompts in hand. Every canary block in docs/review/prompts/ names a commit, a file count and a file set that are all now wrong, and this file supersedes them."
Depends on: []
Depended on by: [docs/review/README.md]
---

# The current baseline

**Read this before any prompt in `docs/review/prompts/`.** Every one of them carries a
canary block identifying the tree by commit, by tracked file count, and by four named
files. All three checks now pass on the wrong tree or fail on the right one. The prompts
are corpus and are not edited; this file is the correction.

## Where the tree actually is

| | |
|---|---|
| Head when this was written | `3698997`, the commit that added this file |
| Branch holding it | `claude/sql-files-to-markdown-i31rob` |
| Tracked files | 112 tracked files |
| Migrations | 27 migrations, `0001_core_schema.sql` through `0027_term_kind_registry.sql` |
| Assertions | 204 from an empty database, 206 against a copy of the cellar |

The file and migration counts above are derived rather than typed, and `scripts/verify.sh`
checks them against the tree on every run. If they are wrong here, `bun run verify` fails.
To confirm by hand: `git ls-files | wc -l` and `ls supabase/migrations/*.sql | wc -l`.

The sha is the one thing here that cannot check itself, because it names the commit that
writes it. A later commit is later work on the same tree, not a different tree. **The
canaries below are the durable check and the sha is a convenience.**

## The trap, which is the most important paragraph here

**`main` is still at `c3eae3c7c262544e4b2e29526b513c964c6852fe`, which is the exact commit
the thirteen-report corpus already reviewed.** Forty two files, five migrations.

So a reviewer who clones this repository, stays on the default branch, and runs the canary
check printed in every archived prompt will find: the branch is `main` and not
`claude/sql-files-to-markdown-i31rob`, the tracked file count is the forty two the prompt
names, and all four named content canaries are present. **Every check passes, and the tree is the one that was
already reviewed a month ago.** The canary block was written to catch exactly this mistake
and it now points the wrong way.

Twenty six migrations of work, three review-response sessions and two enum conversions live
on the branch. If `main` has moved by the time you read this, good: check the canaries
below rather than the branch name, since the point of them is that they do not depend on
which branch you are standing on.

## Replacement canaries

Six files, none of which exists at `c3eae3c`. At the reviewed baseline the only file under
`scripts/` or `tests/` was `tests/schema_assertions.sql`, so the instruments are the
clearest signal that you have the current tree.

| File | What its presence tells you |
|---|---|
| `supabase/migrations/0027_term_kind_registry.sql` | The newest migration. If absent you are before W-4 |
| `supabase/migrations/0021_cellar_write_paths.sql` | The first response to the review corpus. If absent you are at or near the reviewed baseline |
| `tests/shim.sql` | The auth shim exists in the tree. Three review runs each rebuilt one and none committed it |
| `scripts/mutate.sh` | The mutation harness is committed and its number is reproducible |
| `scripts/green.sh` | The six-gate definition of green exists as one command |
| `docs/findings-ledger.md` | The deduplicated result of the last review is present and has been acted on |

And one negative check, which is the fastest of all: **if `git ls-files | wc -l` returns
the number the archived prompts name, which is forty two, you are on the reviewed baseline
and not on this tree.** That phrasing is deliberate; `scripts/verify.sh` checks any count
written here against the tree, and writing the old number as a figure would fail it, which
is the check doing its job.

## The instruments, and what they do not tell you

A reviewer who does not know how these work will read their output as stronger than it is.

**`tests/shim.sql`** stands up the parts of Supabase the migrations reference so a bare
Postgres can apply all 27 from empty: an `auth` schema with `users` and `uid()`, the three
PostgREST roles with Supabase's default grants, an empty `supabase_realtime` publication,
and `pgcrypto` in its own schema. It deliberately creates **no `storage` schema**, so the
vessel-photos blocks in `0005` and `0022` skip with a notice and two assertions report
themselves unrun. That is the whole of the difference between the two assertion counts.
What it does not reproduce is GoTrue minting a JWT and PostgREST mapping it to a role,
which is sorry S-7 and is still open: everything measured against the shim is a claim about
Postgres policy evaluation and assumes the plumbing.

**`scripts/mutate.sh`** injects one schema defect at a time and reports whether the
assertion suite notices. Eight classes. **Seven are enumerated from the catalog and grow
with the schema**: `check` and `unique` drop a constraint, `loosen` leaves a check
constraint in place as `check (true)`, `policy` drops a policy, `weaken` leaves a policy in
place with a predicate of `true`, `trigger` disables a trigger, `rls` turns row level
security off per table. The pairs are deliberate: the first of each catches an object that
disappears and only the second catches one that is still there and has stopped refusing
anything.

**The eighth class, `logic`, is ten substitutions against function bodies, chosen by hand.**
It does not grow with the schema and it does not systematically cover branches. **So the
score says the declarative surface is policed and the procedural surface is sampled. A
reader who takes 198 of 198 as "the kernel is correct" has read it wrong**, and that
sentence is the reason this section exists.

The harness refuses to print a bare percentage: every run names what it excluded as
degenerate or inapplicable. It has also been wrong in both directions inside one session,
which is recorded in the 2026-09-12 session reports.

**`bun run green`** is the gate every phase has to pass: `verify`, `typecheck`, `lint`,
every migration applied from empty into a scratch database, the assertion suite there, and
the assertion suite against a `pg_dump` copy of the live cellar. It never writes to the
cellar.

**`scripts/verify.sh`** checks what the repository claims about itself: the typed header
graph in both directions, the em dash rule, that every `S-`, `C-` and `AR-` id referenced
exists, counts stated in prose, that every command in the definition of done resolves, that
the status ledger agrees with its own grades, and the module import rule.

**The A25 allow-list** lives inside `tests/schema_assertions.sql`, in the block headed
`nothing in the fixed layer permits on unknown`. A25 is the null-permit class: a predicate
that cannot determine an answer permitting instead of refusing. The assertion enumerates
every check constraint and every boolean function from the catalog and exercises each
against every row the table could hold. The allow-list has **exactly one entry**,
`term.operation_has_an_effect`, which is ledger A24, filed and deliberately not fixed.
Anything else answering null fails the suite.

## What has been done to the corpus's findings

`docs/findings-ledger.md` is the governing document and carries its own progress section
naming what has been closed. In short: A1, A2, A3, A6, A8, A14, A22, B1, B14, C1, C2, C3,
C4, D1, D4, D9 and E6 are closed; A24 and A25 were added by later reads; section B, the
nineteen client defects, is untouched by design.

## What has never been reviewed by anything independent

Migrations `0021` through `0027`, which is every response to the corpus plus both enum
conversions. The assertion suite and the mutation harness are both agent-authored, and
every gate decision since W-2 was made with them.
