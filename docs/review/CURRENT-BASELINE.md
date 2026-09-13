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
| Head when this was written | the W-6 commit that added the second review round below |
| Branch holding it | `claude/sql-files-to-markdown-i31rob` |
| Tracked files | 124 tracked files |
| Migrations | 27 migrations, `0001_core_schema.sql` through `0027_term_kind_registry.sql` |
| Assertions | 204 from an empty database, 206 against a copy of the cellar |

The file and migration counts above are derived rather than typed, and `scripts/verify.sh`
checks them against the tree on every run. If they are wrong here, `bun run verify` fails.
To confirm by hand: `git ls-files | wc -l` and `ls supabase/migrations/*.sql | wc -l`.

The sha is the one thing here that cannot check itself, because it names the commit that
writes it. A later commit is later work on the same tree, not a different tree. **The
canaries below are the durable check and the sha is a convenience.**

## The trap that was open until this file was written

**`main` now carries this work.** It was fast-forwarded from
`c3eae3c7c262544e4b2e29526b513c964c6852fe` to the head named above during the session that
wrote this file, and that is worth recording rather than quietly fixing.

Until then, `main` was still at `c3eae3c`: forty two files, five migrations, the exact
commit the thirteen-report corpus reviewed. Twenty six migrations of work sat on
`claude/sql-files-to-markdown-i31rob` and nothing on the default branch said so.

The consequence is the reason this file exists. A reviewer who cloned the repository,
stayed on the default branch, and ran the canary check printed in every archived prompt
would have found that the branch is `main` and not the working branch, that the tracked
file count is the one the prompt names, and that all four content canaries are present.
**Every check would have passed, and the tree would have been the one already reviewed.**
The canary block was written to catch exactly that mistake and had come to point the wrong
way, because it identifies the right tree by a branch name and a file count that both
moved.

That is the general lesson for whoever writes the next set of prompts: **identify a tree by
things that only exist in it, not by where it is parked or how large it is.** The
replacement canaries below are chosen on that principle.

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

**The eighth class, `logic`, is substitutions against function bodies, chosen by hand.**
It does not grow with the schema and it does not systematically cover branches.

**And the second review round measured what that is worth.** X-1 chose nine substitutions
independently and six were caught, against ten of ten on the author's own list. W-6 chose
sixteen more the same way, by reading guards out of `pg_proc`, and **five were caught.**
The list is now reported split by who chose it, and the two figures are printed separately
for that reason. Whoever chose the sample decides the number.

## The score is two numbers now, and only one of them is a gate

**This is the single most important thing on this page.** Until W-6 the harness reported
one figure and it was read for two sessions as a statement about the kernel.

X-1 measured that **86 of the 198 catches came from three pinned catalog comparisons**
whose failure message told the reader to update the pinned value. Disabling those three
took the score from 198 of 198 to 112 of 198. Demonstrated twice: weaken `node_admin_update`
to `using (true)`, add the one line the failure message asks for, and the suite passes at
full count with every authenticated role able to update every lot. Or drop
`vessel_code_code_key`, change one number in the pinned inventory, and the suite passes
while two vessels accept the same QR code.

Nobody gamed anything. The gate asked whether a number went up, and a snapshot assertion
makes it go up without detecting behavioural change. The gate was wrong.

So `scripts/mutate.sh` now runs every mutation twice and reports:

**The behavioural score.** Snapshot assertions switched off, so only an assertion that
exercises the schema can catch anything. **This is the gate.**

**The snapshot score.** What the pinned comparisons caught on top. A change detector, worth
having, and not evidence that anything was refused.

Seven assertions are classified as snapshot: the policy census, the wide-open policy list,
the constraint inventory, the composite foreign key list, the generated kind columns, the
foreign-key delete behaviour, and the restrict key list. Each compares a literal written
into the file against the catalog. They are switched off through the `vsv.snapshots`
setting, which is how the two passes are separated.

**A snapshot assertion's failure message must not offer the fix.** The three X-1 broke all
said, in effect, update this list. A message that tells you how to make it pass is a check
that instructs its own defeat.

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

## The second review round

`docs/review/prompts/X-1`, `X-2` and `X-3`, with reports beside them in
`docs/review/reports/`. Where the first round reviewed the schema, this one reviewed the
instruments that had been grading the schema for four sessions, the seven migrations the
first round never saw, and the documents.

**X-1, the instrument.** The behavioural score above. Also: a broken enumeration query
deleted its whole mutation class and the harness printed a clean number; `green.sh` decided
whether the assertion suite had passed by grepping its log, so a run that never happened
reported ok; a lost database connection was recorded as a caught mutation; and one
assertion caught its own failure raise and could never fail. All repaired by W-6, all
break-tested.

**X-2, migrations `0021` to `0027`.** Six EXPLOITABLE findings in the range that had never
been independently read. They are **not fixed** and belong to a supervised migration
session. The one exception W-6 took was X-2-7, because it is an instrument defect: the A25
assertion's population excluded trigger validators, which is exactly the layer `0027`
worked in.

**X-3, the documents.** Twenty five findings, most of them numbers that had rotted. The
mechanical ones are fixed. Two are left because they are rulings rather than edits: whether
`architecture-rulings.md` should stop saying "Nothing here is built" now that `AR-E5`,
`AR-E6` and `AR-E7` are, and whether `AR-E6` should record that `0024` removed the blocker
it still names.

**The work prompts are in the tree now**, at `docs/work-prompts/`. W-1 through W-6 were
cited as governing authority throughout and none of them was committed, which is X-3-7 and
made this file's own resume procedure halt on the commit containing it. They are history:
the reason a commit looks the way it does, never a live requirement.

## What has never been reviewed by anything independent

Nothing, now, in the sense that was true when this file was written: `0021` through `0027`
have been read by X-2 and the instruments by X-1.

What remains unreviewed is W-6's own work, which is every repair described on this page. The
harness that reports the behavioural score was written by the same agent whose previous
harness reported the number X-1 found to be misleading, and the seven assertions classified
as snapshot were classified by that agent. That classification is the most consequential
judgment in the instrument and one round of independent review has not seen it.
