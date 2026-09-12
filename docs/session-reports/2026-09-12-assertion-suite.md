---
Type: record
Purpose: "Records the W-3 session, which set out to make the assertion suite police the schema and ended with the mutation score at 188 of 188, the gate for the schema split met, and two defects found by writing assertions rather than by reading."
Depends on: []
Depended on by: [docs/session-reports/index.md]
---

# 2026-09-12: making the suite police the schema

W-3, phases A to D, all complete and green. W-2 phases 5 through 8 are unblocked.

## The number, and the set it belongs to

Every figure here names its mutation set, because the entire reason this session
existed is that one number was reported without its set and turned out not to mean what
it appeared to mean.

| Set | Mutations | Caught | Score |
|---|---|---|---|
| `G-5`, September, its own 45 | 45 | 19 | 42% |
| `scripts/mutate.sh`, September, at `0022` | 115 | 28 | 24% |
| Same objects the review saw, September | 71 | 15 | 21% |
| **`scripts/mutate.sh`, now, at `0025`** | **188** | **188** | **100%** |

By class: check 18 of 18, loosen 18 of 18, unique 16 of 16, trigger 9 of 9, policy 57 of
57, weaken 38 of 38, rls 22 of 22, logic 10 of 10.

W-3's gate for the check and unique categories specifically: 13 percent to 100, and 12
percent to 100.

**The gate for the schema split is met.** It was not lowered, and this is a threshold
rather than a trend: it is cleared on a mutation set four times the size of the one that
failed it.

## Row level security, table by table, which is the fact to watch

The set-independent finding W-3 was built around: row level security could be disabled
outright and the suite still passed.

| | September, 21 tables | Now, 22 tables |
|---|---|---|
| Caught | `event`, `location`, `node`, `term`, `vessel` | all of them |
| Survived | `app_user`, `block`, `lineage`, `party`, `placement`, `procedure`, `procedure_run`, `procedure_run_step`, `procedure_session`, `procedure_step`, `task`, `task_claim_log`, `template`, `template_step`, `vessel_code`, `vessel_type_note` | none |

Sixteen to zero. The five that were caught in September were caught incidentally, because
some other assertion happened to read that table through a second principal; none of them
was an assertion about row level security. The assertion that closes all of them is three
lines and derived rather than listed, so a table added later is covered the moment it
exists rather than the moment somebody remembers.

Every fix in `0021` and `0022` is a row level security fix. A1, A3, A5, A6, A7 and A8 were
all repaired against a suite that could not tell whether the mechanism was switched on.
They are protected now.

## Two defects found by writing assertions rather than by reading

**A24, and it is the third of its kind.** `operation_has_an_effect` reads
`kind <> 'operation' or attributes ->> 'effect' in (four values)`. For an operation with no
effect at all the inner test is `null in (...)`, which is null, so the whole check is
`false or null`, which is null, and a check constraint passes on null. An effectless
operation lands. The four-effects invariant refuses a wrong answer and does not refuse a
missing one.

That is the same shape as A1's `coalesce(..., true)`, where a missing party row resolved to
facility, and as `may_see_all_of` returning null so that `not null` was null and an `if`
did not fire. Three times, three mechanisms, three routes, one cause: SQL's third truth
value arriving where the author was thinking in two.

**It corrects B2, and the correction is worse than the finding.** Two review reports said
that adding an operation inline always raises, because `addTerm` defaults `attributes` to
`{}`. It does not raise. It lands, and the operation is silently inert, because the kernel
reads `attributes ->> 'effect'` to decide what an event does to volume and lineage and
gets nothing. A raise is visible. This is not.

Both filed rather than fixed: section A beyond A22 is out of W-3's scope, and the
assertion for A24 is written so that fixing it fails the assertion on purpose, which puts
the fix and the assertion in the same commit.

## What phase B pinned, and why those things

The nine composite foreign keys into `term(id, kind)` and the nine generated kind columns
that supply their second half. Those pairs are exactly what W-2 phase 5 has to move, and
they are pinned by name and by exact expression so that a phase 5 migration which changes
any of them fails loudly rather than quietly. Delete behaviour is pinned the same way, by
count and by naming the four `ON DELETE RESTRICT` keys, because a schema move that
recreates a foreign key is precisely where a cascade turns into a no-action with nothing
to notice it.

Then behaviour, one constraint at a time, each violating exactly one thing and satisfying
every other constraint on the same row. That turned out to matter: the first version of
the vessel thermal assertions violated both constraints at once, so loosening either one
still raised and neither was actually covered. `G-5-6` made the same observation about
`vessel_code` and it went unaddressed for a month.

## The harness now measures existence and behaviour separately

This is the methodological half of the session and it is why the number is trustworthy.

A pinned list of policy names catches every policy that disappears and nothing else. A
policy that is still present and has stopped refusing anything is invisible to it, and
that is the failure mode a schema move actually produces. So the harness gained `weaken`,
which recreates each policy with the same name, command and roles and a predicate of
`true`. The same argument applies to constraints, so it gained `loosen`, which leaves a
check constraint in place as `check (true)`.

The pairs are the point. `policy` at 100 percent and `weaken` at 100 percent say different
things, and a single combined number would say neither.

It also gained `logic`: ten substitutions against `pg_get_functiondef`, because roughly
nine of `G-5`'s forty five were function-body mutations this harness did not do, and
skipping that quietly would have let a declarative-only score be read as a statement about
the kernel. Each mutation carries the function's real signature and `search_path` rather
than a copy that drifts, and a substitution whose target string has gone reports as not
applicable, which is also how the list tells you a function changed shape.

**`G-5`'s original 45 could not be reconstructed.** Its report names its caught and
survived objects, but the function-body half cannot be recovered from prose, and inventing
a plausible version of somebody else's mutation would produce a comparable-looking number
that compared nothing. Said plainly rather than estimated.

## What this session got wrong

No predictions were recorded at the start of this one, which is a miss: the previous
session's habit of writing them down before measuring is what made its report worth
reading, and it was not repeated. What follows is what was got wrong along the way, which
is the next best thing and is the honest content.

**The harness silently truncated every multi-line mutation.** The mutation file is line
based and `read` stops at the first newline, so all ten function-body mutations reported
as "not applicable". That looked like ten functions being resistant to mutation. They now
travel base64 encoded.

**Nineteen `weaken` mutations were degenerate.** Recreating a policy with a predicate of
`true` where the predicate is already `true` injects no defect at all. Counting them as
survivors understated the suite by nineteen, which is the same error this session exists
to correct, arriving from the opposite direction.

**One mutation was equivalent, and it took two wrong theories to establish that.** Removing
`quote_ident` from `resolve_subject_name` survived. The first theory was that it was an
equivalent mutant because `relation_is_a_bare_name` already constrains the input. The
second was that a reserved word like `order` matches that pattern and would break unquoted.
An assertion was written for the second theory, and it failed against the unmutated
function, which meant the assertion was wrong rather than the code. A probe settled it:
`from public.order` parses perfectly well unquoted, because schema qualification lets the
parser accept a reserved word there. The mutation is equivalent after all. The assertion
was deleted rather than kept, because one that cannot fail for the reason it states is
exactly the inflation this repository is against, and the mutation was replaced with one
that discriminates.

**An annotation was written confidently and was wrong.** A superseded assertion about
rebinding a code was first annotated as running with `is_admin()` false. It runs after
`test_act_as` has set the admin's claim, so `is_admin()` is true, which is why the
assertion started failing when A22 landed: it asserted that nobody could rebind while
running as the one principal who now can.

**The pinned policy count caught the session's own new policy** and had to be updated by
hand. That is the assertion working rather than being in the way. It cost thirty seconds,
which is the same thirty seconds a schema move will cost when it loses one.

## Phase D

A22 is built as `0025`, to the winemaker's ruling: a cellar hand may bind an unbound code,
only an admin may rebind one already bound, and the refusal names the barrel that already
holds the sticker rather than its uuid, because the person reading it is standing in a
barrel room. Done the way `0021` did it, a narrow insert policy rather than a blanket
`security definer`, so update and delete stay with the admin policy and the table cannot be
rebound by writing it directly either. Both halves are asserted, including the wording of
the refusal. S-43 records that the permitted path leaves no trace, which is A17's class.

The `E-4` reference is repointed at `CLAUDE.md`'s append-only statement and the `R-5`
report. It was never a ruling reference, so the `AR-` rename exposed it rather than caused
it.

The standing rules are at the top of the progress file, where a fresh session reads them
before starting anything: commit before every break test and revert after, do not write
shell scripts through a bash heredoc, and a check nobody has watched fail is not a check.

## What 100 percent does not mean

It means that no constraint, index, trigger, policy or row level security setting can be
removed or neutered without the suite noticing, and that ten specific pieces of kernel
logic cannot be altered without it noticing either.

It does not mean the kernel is correct. The `logic` class is ten hand-chosen substitutions
rather than a systematic mutation of every branch in every function, and a written list is
the kind of thing that goes stale, which is why the other seven classes are enumerated from
the catalog instead. The honest summary is that the declarative surface is now policed and
the procedural surface is sampled.

The next session should know which of those it is relying on.
