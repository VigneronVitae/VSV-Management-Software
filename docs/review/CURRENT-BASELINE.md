---
Type: reference
Purpose: "States what this tree currently is, for a reviewer arriving with the archived prompts in hand. Every canary block in docs/review/prompts/ names a commit, a file count and a file set that are all now wrong, and this file supersedes them."
Depends on: [scripts/ratchet.sh]
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
| Head when this was written | the W-7 commit that added the two gates below |
| Branch holding it | `claude/sql-files-to-markdown-i31rob` |
| Tracked files | 205 tracked files |
| Migrations | 70 migrations, `0001_core_schema.sql` through `0032_vessel_maker_and_room_temperature.sql` |
| Assertions | 295 from an empty database, 297 against a copy of the cellar |

The file and migration counts above are derived rather than typed, and `scripts/verify.sh`
checks them against the tree on every run. If they are wrong here, `bun run verify` fails.
To confirm by hand: `git ls-files | wc -l` and `ls supabase/migrations/*.sql | wc -l`.

The sha is the one thing here that cannot check itself, because it names the commit that
writes it. A later commit is later work on the same tree, not a different tree. **The
canaries below are the durable check and the sha is a convenience.**

## The trap that was open until this file was written

**`main` carries this work and is pushed.** It was fast-forwarded from
`c3eae3c7c262544e4b2e29526b513c964c6852fe` to `0e3514c` during W-5, drifted behind again
through W-7 to W-10, and was pushed at the end of W-10: twenty six commits, `origin/main`
at `514b4bd`. **A clone of the default branch is now this tree.**

**It went behind twice and the second time was worse than the first.** W-7 through W-9 sat
on `claude/sql-files-to-markdown-i31rob` because moving the default branch is a decision
rather than a chore and the previous one had been made out loud. Then W-10 fast-forwarded
`main` at the start of the session and kept committing to the branch for the rest of it,
so `main` pointed into the middle of W-9 while reading as though it were current. **That
is the more dangerous shape**: behind and visibly behind is a state somebody notices, and
behind after being deliberately updated is one nobody re-checks. It was caught by
disbelieving an ahead-count of six after a session of six commits.

The rule this leaves: **fast-forwarding the default branch is the last thing a session
does, not the first.** Done first, it records an intention; done last, it records what
happened.

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

Eight files, none of which exists at `c3eae3c`. At the reviewed baseline the only file under
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
| `scripts/guards.sh` | The refusal surface is enumerated rather than sampled. If absent you are before W-7 |
| `scripts/ratchet.sh` | The two gates are enforced by a script rather than described in a document |

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

**The eighth class, `logic`, is the whole refusal surface of the kernel.** It used to be a
list of substitutions written by hand, and that list is the thing two review rounds broke.
X-1 chose nine substitutions independently and six were caught, against ten of ten on the
author's own list; W-6 chose sixteen more by reading guards out of `pg_proc` and five were
caught. The three figures are ordered by how far each chooser stood from the code and
ordered equally well by how hard each was looking for gaps, and nothing separates those two
explanations. W-6 proposed fixing it by requiring the chooser to be independent. **That
constrains the chooser and not the choice**, and a later session wanting a number above the
bar satisfies it and picks the way the original ten were picked.

So there is no sample any more. **`scripts/guards.sh` enumerates the population**: every
path in every function the kernel owns that declines to do what the caller asked. 176 of
them, committed at `docs/review/refusal-sites.tsv` so that the count is script output
rather than an estimate and so that a guard disappearing shows up as a diff. Seven shapes,
and the quiet ones matter more than the loud one:

| Shape | Count | What it looks like |
|---|---|---|
| `guard` | 79 | a conditional whose head finishes on its line |
| `raise` | 49 | `raise exception`, the only loud form |
| `silent` | 14 | a conjunct on an update or a delete, which refuses by matching nothing |
| `earlyreturn` | 13 | a return that reports success |
| `head` | 11 | a conditional whose head runs over several lines |
| `notfound` | 7 | `if not found` that does not raise |
| `permissive` | 3 | a `coalesce` supplying a default that permits |

The enumeration was wrong four times before it was right, and every one of the four was
silent. It could not see refusals expressed as a `where` conjunct, which is ledger A14 and
is how six kernel write paths did nothing for four days. It could not see anything on a
line ending in a carriage return, and 249 of the kernel's 1459 source lines end in one, so
the guard count was 61 when it was 79. It replaced whole lines, which turns
`if not found then return; end if;` into a function that will not compile, and reported
three sites as inapplicable in a way that reads like a fact about the schema. And it left
multi-line conditional heads out, because prefixing a condition with `false and` is wrong
wherever the condition is an `or`: `and` binds tighter, half the guard survives, and a
half-neutralised guard is worse than an omitted one because it still scores.

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

## The two gates, and why they are shaped differently

W-6 proposed these and deliberately did not adopt them. W-7 adopted them, amended, and
`scripts/ratchet.sh` enforces them. **The reason a gate is shaped the way it is decays
faster than the gate**, so the reasoning is here rather than only in the script.

**A phase that moves declarative objects requires that no class gain an uncovered
mutation.** Uncovered means scored minus behavioural: a mutation caught only by a pinned
snapshot is uncovered, because the snapshot noticed the catalog move and nothing refused
anything.

Not a percentage. A percentage rises when the denominator grows, so a phase that added
thirty uncovered policies to a class holding two would improve its score. The count of
uncovered mutations is the thing that must not grow, and "must not grow" is the same
sentence as "every new object has to be covered". W-4 already demonstrated the ratchet
working, when three new bare-name checks dropped the score and were closed in the same
session.

**A phase that rewrites a function body requires that every enumerated refusal site be
behaviourally covered or filed as unreachable with a reason.** Not a percentage, and not a
sample.

W-6 proposed a threshold of 80 percent on independently chosen substitutions. A percentage
invites the question of which substitutions, and that question is what produced two entire
sessions. There is no sample here to argue about, so a threshold would have nothing left to
do except permit a known gap without naming it. The filings live at
`docs/review/refusal-dispositions.tsv`, one line each, and `scripts/ratchet.sh` fails on a
filing for a site that no longer exists and on a filing for a site the suite now catches,
because a reason recorded against code that has changed is worse than no reason.

**Neither gate is a single number over all eight classes.** That is what produced W-6.

**`scripts/ratchet.sh` is not in `bun run green`.** It runs 385 mutations twice and takes
thirty three minutes, measured, and a gate that slow inside the loop is a gate people learn to
skip. Green carries the cheap half instead, as gate 6: that the committed enumeration still
describes the kernel, and that every filing resolves to a site that exists. If that gate
fails, every coverage figure on this page is about code that is no longer here.

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
