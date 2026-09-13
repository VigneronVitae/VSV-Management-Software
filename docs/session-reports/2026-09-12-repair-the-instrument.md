---
Type: record
Purpose: "Records the W-6 session: the fail-open paths in the harness closed as a class, the mutation score split into a behavioural gate and a snapshot change-detector, and the independent measurement of the procedural surface that came back at five of sixteen."
Depends on: []
Depended on by: [docs/session-reports/index.md]
---

# 2026-09-12: repair the instrument

W-6, all five phases, green at `0027`. The three X reports are in the corpus and the six
work prompts are in the tree.

## Predictions, recorded before measuring

1. **More fail-open paths than the four X-1 named, nearer ten than three.** Correct.
   Eleven were repaired, and two more were introduced and caught during the repair.
2. **The behavioural score within a few points of X-1's 112 of 198.** Correct: 117 of 214,
   which is 54 percent against their 57. The denominator moved because the logic class grew
   from 10 substitutions to 26.
3. **The independent function-body substitutions catch between 55 and 70 percent.**
   **Wrong, and badly.** Five of sixteen, which is 31 percent. X-1 got 6 of 9 and I assumed
   a third sample would land near that. It landed at less than half of it.
4. **Extending the A25 population finds X-2-1 and nothing else.** Correct, in the sense
   that matters and not in the sense I meant. The extension does not evaluate trigger
   validators, because it cannot; it enumerates them and demands each be accounted for. Five
   exist, four are accounted for, and the fifth is X-2-1.

## The number, and what it was

| | Scored | Behavioural | Snapshot only | Neither |
|---|---|---|---|---|
| Total | 214 | **117 (54%)** | 86 (40%) | 11 |
| check | 21 | 21 | 0 | 0 |
| loosen | 21 | 21 | 0 | 0 |
| unique | 16 | 5 | 11 | 0 |
| trigger | 9 | 9 | 0 | 0 |
| policy | 59 | 17 | 42 | 0 |
| weaken | 39 | 6 | 33 | 0 |
| rls | 23 | 23 | 0 | 0 |
| logic | 26 | 15 | 0 | 11 |

Eleven of the 117 behavioural catches are the mutation breaking a fixture the suite needed
rather than an assertion refusing anything, so detection is 106 of 214. Twenty one
mutations excluded: twenty degenerate, one inapplicable.

**The snapshot figure reproduced X-1's exactly.** They measured 86 catches attributable to
three pinned catalog comparisons; this harness, splitting the passes a different way and
over a larger mutation set, also gets 86. Two independent measurements of the same quantity
agreeing to the unit is the strongest evidence in this report that the split is real.

The gate from here is the behavioural score. The snapshot score is a change detector and is
reported for that purpose only.

## Which assertions are snapshots, and why that classification is the judgment

Seven, each comparing a literal written into the file against the catalog: the policy
census, the wide-open policy list, the constraint inventory, the composite foreign key list,
the generated kind columns, the foreign-key delete behaviour, and the restrict key list.

The test applied was not "does it read the catalog" but **"can it pass without anything
having been refused"**. A pinned list notices that the catalog moved. It cannot notice that
a policy which is still present has stopped refusing anything, which is the failure a schema
move actually produces, and X-1 demonstrated both halves of that: weaken a policy, add the
one line the failure message asks for, and the suite passes at full count with every
authenticated role able to update every lot.

Assertions that read the catalog and were **not** classified as snapshot are the ones
stating an invariant rather than a photograph: every base table has row level security, no
table has it on with no policy, no check constraint permits on unknown. Those do not need
updating when the schema grows, so they cannot be defeated by updating them.

I want to be plain that this classification is mine, it is the most consequential judgment
in the instrument, and no independent round has seen it.

## The procedural surface, measured by somebody who did not write the list

| Who chose the substitutions | Caught |
|---|---|
| The harness author, the original ten | 10 of 10 |
| X-1, nine chosen independently | 6 of 9 |
| W-6, sixteen chosen by reading guards out of `pg_proc` | **5 of 16** |

Eleven survive both passes. Each is a guard that exists in the code and that nothing in 207
assertions notices being removed:

a claimed task can be taken from whoever holds it, twice over, since both halves of the
guard survive; wine goes into a deactivated vessel; finishing a run that does not exist
writes an event against a null vessel; forking zero vessels off a lot; a hidden composition
is disclosed anyway; an unknown operation name writes an event with a null operation;
topping into a vessel with nothing in it; editing a vessel that does not exist reports
success; required vessel-type fields stop being required; and a field of any kind at all is
accepted, which is X-2-1.

**Phases 7 and 8 rewrite function bodies.** That is the surface this measures.

## Every fail-open path found, which was the open question

X-1 named four. Eleven were repaired.

**The four from X-1.** `green.sh` gates 4 and 5 deciding by anchored grep, so a run that
never happened reported ok. The eight enumeration queries discarding stderr, so a broken one
deleted its class and the score printed clean over a smaller denominator. A lost database
connection recorded as a caught mutation. A vanished `logic` substitution target dropped at
enumeration against a comment saying it reported as not applicable.

**Seven more.** `green.sh` exiting before `verify`, `typecheck` and `lint` when the
container is down, so three gates that need no database could not run in a clean clone. A
total `pg_dump` failure reported as `cellar copied, 0 tables`, because `pipefail` does not
reach a child `sh -c` and psql exits zero on empty input. Every database create and drop
discarding its status. The scratch-against-copy reconciliation guarded so that it was
skipped in exactly the case where a run had not happened. `verify.sh` section 1 having no
blindness guard, so a tree where the header field was renamed would print `ok 0 headered
files, 0 edges, every one bidirectional`. The same section examining only files that already
had a header, so omitting one was a complete exemption from the graph, which two tracked
shell scripts had been enjoying. And the `Deferred` check in `verify.sh`, which matched
`| Deferred |` exactly and has matched zero rows since the only Deferred row acquired a
qualifier.

**And two the repair introduced**, both caught the same day. The new `q()` dropped its
trailing newline, so the first row of each mutation class landed on the last row of the
previous one and seven mutations vanished from the enumeration. And `assert_run` echoed its
count into a command substitution that swallowed its own `ok` line, so both assertion gates
printed nothing at all.

The general rule now in the progress file: **no path may reach a success report without
having done the work the report describes.** Every one of the eleven violated it in the same
way, by treating the absence of a signal as the presence of a good one.

## The assertions that could not fail

`raise exception 'FAIL: ...'` is SQLSTATE P0001, which is `raise_exception`, which is what
thirteen handlers in the suite catch. One of them swallowed the suite's own alarm and could
never fail, and it was the one whose comment claimed it would have caught a silent `0027`.
The other twelve were fatal only because their guarded statement raises before the alarm is
reached. All thirteen re-raise now.

The A25 allow-list entry was dead. An enum column is exercised against every label and a
text column was exercised against `''`, `'x'` and null, so `0027` converting `term.kind`
from enum to text silently narrowed the assertion until it could no longer see A24. Removing
the entry changed nothing, which is how X-1 found it. The literals in each constraint's own
expression are candidates now, and removing the entry fails again.

Both were break-tested, which is now a standing rule: **a check is not done until it has
been seen to fail for the reason it states.** This is the fourth time in this project that a
green check was proven hollow only by deliberate breakage.

## A gate, proposed and not adopted

There is currently no gate on the behavioural score, because the old gate was measuring the
wrong thing and W-6 says explicitly not to adopt one.

What I would propose, for the next prompt to accept or reject:

**A phase that moves declarative objects requires the behavioural score not to fall, and
requires every new object it creates to be behaviourally covered.** The declarative classes
are at 100 percent behaviourally today, so this is a ratchet rather than a threshold, and
W-4 already demonstrated it working when three new bare-name checks dropped the score and
were closed in the same session.

**A phase that rewrites function bodies requires the independent `logic` figure above 80
percent, measured on substitutions chosen by somebody who did not write the phase.** It is
at 31 percent. That is not a near miss and W-2 phases 7 and 8 should not proceed against it.

I would not propose a single number over all eight classes. That is what produced this
session.

## What I got wrong

Prediction 3, by more than twenty points, in the optimistic direction. That is twice now
that a prediction about this suite's coverage has been optimistic and wrong, W-4's by
thirty points and this one by twenty four, and the pattern is worth more than either number:
I keep estimating coverage by how carefully the assertions were written rather than by how
much surface there is.

Two fail-open paths introduced while removing eleven, described above.

A `logic` substitution added without reading the function body, which the new
vanished-target abort caught on its first run. That is the rule from W-4 that I wrote down
and then broke within one session.

And an assertion classification I got wrong twice before getting it right in W-4, repeated
here in a smaller way: the first version of the A25 validator extension tried to evaluate
trigger bodies, which cannot be done from a catalog query, and was replaced with an
accounting requirement that says who covers what.
