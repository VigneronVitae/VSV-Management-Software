---
Type: record
Purpose: "Records the W-7 session: the kernel's refusal surface enumerated rather than sampled, the mutation harness pointed at all 176 sites, 91 of them closed with assertions, 11 filed as equivalent, and the two gates adopted and enforced by a script."
Depends on: []
Depended on by: [docs/session-reports/index.md]
---

# 2026-09-12: the refusal surface

W-7, four phases, green at `0027`. No migration was written this session; the schema is
the one W-6 left and everything here is instrument and assertion.

## Predictions, recorded before measuring

Anchored on 31 percent, as W-7 phase 5 required, which is the least flattering figure
available rather than the most recent.

1. **The enumeration finds between 90 and 140 refusal sites.** **Wrong, low by 36.** It
   finds 176. The first pass found 134, which is inside the range, and every subsequent
   correction to the enumeration pushed the number up. A prediction that would have been
   scored correct against a broken instrument is worth noticing.
2. **The catch rate over the full population lands between 15 and 28 percent.** **Wrong,
   high by 14.** It was 74 of 176, which is 42 percent.

   The interesting part is why. 19 of those 74 are the mutation breaking a fixture the
   suite needed rather than an assertion refusing anything. Detection alone is 55 of 176,
   which is 31 percent, and 31 percent is the anchor W-7 told me to use, to the point. The
   anchor was right about detection and I applied it to a figure that also counts fixture
   breakage. Two sessions of over-optimism corrected into one session of pessimism, and the
   correction was the right size against the wrong quantity.
3. **The first pass of the enumeration will be wrong**, specifically by missing refusals
   expressed as a `where` clause that matches nothing. **Correct, and it is the only
   prediction in four sessions that named its own failure mode and hit it.** It was also
   incomplete: there were four such failures and this was one of them. See below.
4. **Between five and fifteen sites will be unreachable.** **Correct on the number and
   wrong on the reason.** Eleven. I said they would be defensive `if not found` guards
   behind a foreign key that already makes the case impossible. Four of the eleven are
   `if not found` and not one of them is behind a foreign key. The actual reason is a
   different thing entirely and more interesting: see the filings.

## The enumeration, and the four things the first pass could not see

`scripts/guards.sh` reads `pg_proc` and emits one row per refusal site, committed at
`docs/review/refusal-sites.tsv`. **176 sites in 50 functions.**

| Shape | Count |
|---|---|
| `guard`, a conditional whose head finishes on its line | 79 |
| `raise`, the only loud form | 49 |
| `silent`, a conjunct on an update or delete | 14 |
| `earlyreturn`, a return that reports success | 13 |
| `head`, a conditional whose head runs over several lines | 11 |
| `notfound`, an `if not found` that does not raise | 7 |
| `permissive`, a `coalesce` supplying a default that permits | 3 |

Every one of the four first-pass failures was silent, and each was found by looking for a
specific predicted shape rather than by reading the output.

**Refusals expressed as a conjunct.** Predicted, and the reason the `silent` kind exists.
`update task set status = 'claimed' where id = :id and status = 'open'` refuses by matching
nothing: no error, no row, and the caller told it worked. That is ledger A14 and it is how
six kernel write paths did nothing for four days. 14 sites.

**Carriage returns.** 249 of the kernel's 1459 source lines end in one, because some
migrations were written on Windows, and `btrim` with no argument does not remove it. Every
pattern anchored with a dollar therefore matched only lines that came from a LF file. The
guard count was 61 and it is 79. **The instrument was reading about half the kernel and
reporting a total for all of it**, which is the same defect as the snapshot score W-6
found, one layer down.

**Whole-line replacement.** `if not found then return; end if;` is one line, and swapping
the line for `if false then` takes the `end if;` with it and yields a function that will
not compile. Three sites were reported as *inapplicable*, which reads as a fact about the
schema and was a fact about the script. Guards are replaced up to their `then` now.

**Multi-line conditional heads.** No per-line substitution can neutralise a condition
spread over three lines, and the obvious repair is wrong: prefixing with `false and` binds
tighter than an `or`, so half the guard survives, and **a half-neutralised guard is worse
than an omitted one, because it still scores.** The substitution target spans lines instead
and the transport escapes the newline. 11 sites.

**No site is unsubstitutable.** The first pass omitted 24 because a bare `replace()` would
hit every copy of a repeated line; an occurrence index fixed that, computed from the line's
reconstructed offset into the definition rather than by counting substrings, because a bare
`return;` is a substring of a conditional that ends in one. Every one of the 176 was
checked to compile and to differ from the original before any of them was scored, and
`guards.sh` reports any site it cannot reach rather than dropping it, because a site missing
from the denominator and a site that does not exist produce the same percentage.

## The catch rate over the full population

| | Sites |
|---|---|
| Covered when the session began | 74 |
| Uncovered, closed here | 91 |
| Unreachable, filed with a reason | 11 |
| **Enumerated** | **176** |

**165 of 176 behaviourally covered.** 62 new assertions, 267 in the suite from an empty
database against 205 at the start.

Over all eight classes the behavioural score is **268 of 364, up from 166 of 343**. The
snapshot score is 85, essentially unchanged, which is the right shape: this session added
no pinned lists.

| Class | Scored | Behavioural | of which fixture | Snapshot only |
|---|---|---|---|---|
| check | 21 | 21 | 1 | 0 |
| loosen | 21 | 21 | 0 | 0 |
| unique | 16 | 6 | 1 | 10 |
| trigger | 9 | 9 | 0 | 0 |
| policy | 59 | 17 | 9 | 42 |
| weaken | 39 | 6 | 0 | 33 |
| rls | 23 | 23 | 0 | 0 |
| logic | 176 | 165 | 23 | 0 |
| **Total** | **364** | **268** | **34** | **85** |

## The eleven, named, and what unreachable turned out to mean

Not dead code, and not a path I could not find. **Every one is a function with more than
one way to say the same thing**, so the guard is reached, it is removed, and no caller can
tell. Each was checked rather than argued: apply that one mutation to a clone, call the
function on an input that reaches the guard, compare the answer.

**`resolve_subject_name`, five of them.** Every branch of this function returns null. An
unregistered subject type returns null; with the guard gone the resolver row is all nulls,
`quote_ident(null)` is null, `to_regclass(null)` is null, and the next guard returns the
same null. Remove that one and the dynamic `execute` runs against a relation that does not
exist, raises, and the function's own exception handler returns the same null. Remove the
handler's return and it falls through to a final return of a variable never assigned, which
is null. Five refusal sites, one answer.

**`node_bin_shares` and `node_history`, two each.** The `if not found` in each: a lot that
does not exist has no lineage and no events, so the query returns the empty set either way.
The `coalesce(may_see_all_of(...), false)` in each: `may_see_all_of` coalesces to false
inside itself and can never return null, so the outer default is never the value used.

**`generate_inferred_history`, two.** Removing the null-variety guard looks up a template by
a null variety, which matches nothing; removing the null-template guard loops over the steps
of a null template, which is no rows. Both return the same zero.

This is worth stating plainly because a reader of the source would count eleven refusals
that are not there.

## Two rules the new assertions follow and the old ones did not

**Ask for the specific refusal, not for any error.** Most of these functions decline the
same call at several guards for different reasons, and "it raised" cannot tell them apart,
so an assertion written that way covers the function and no individual site in it.
`record_event` is the case that proves it. Aimed at a lot that is in one vessel, removing
the vessel guard falls through to `fork_lot`, which refuses in the same sentence, and the
assertion passed with the guard gone. Aimed at a lot in no vessel at all, the guard is the
only thing that can refuse.

**Compare with `is distinct from`.** The racking assertion reading "after a 3 L loss the lot
is 222 L" was written as `if q <> 222 then raise` against a lot whose quantity was null,
because the fixture passed 225 as the placement volume and never set one. Null is not
unequal to 222. **It had been passing without checking anything**, and the update it was
written to protect could be deleted without it noticing. That is the fifth hollow green
check in this project and the first found by mutating the code the check points at rather
than by deliberately breaking the check.

## The null-permit class, in the write paths

`where id = :node and quantity is not null` guards two updates, one where a fork shrinks its
parent and one where a blend absorbs the lot already in the destination. **A lot whose
quantity was never recorded is ordinary here**, because volume lives on the placement and
the lot-level number is optional. Subtracting from a number nobody wrote gives a confident
zero, and zero closes lots.

Neither guard could be seen by anything in the suite, because every fixture in the file
either set a quantity or never looked at it. This is A25, the null-permit class, arriving in
the procedural layer after four sessions of being a story about check constraints.

## The two gates, adopted

W-6 proposed these and deliberately did not adopt them. They are adopted, amended, and
**enforced by `scripts/ratchet.sh` rather than described in a document**, with the reasoning
written into `docs/review/CURRENT-BASELINE.md` because the reason a gate is shaped the way
it is decays faster than the gate.

**Declarative phases ratchet on the uncovered count per class.** Not a percentage: a
percentage rises when the denominator grows, so a phase adding thirty uncovered policies to
a class holding two would improve its score. "The uncovered count must not grow" is the same
sentence as "every new object must be covered".

**Function-body phases require every enumerated refusal site to be behaviourally covered or
filed with a reason.** Not a percentage and not a sample. W-6 proposed 80 percent on
independently chosen substitutions; W-7 is right that this constrains the chooser and not
the choice, and with no sample left there is nothing for a threshold to do except permit a
known gap without naming it.

Runtime is thirty three minutes, measured, for 385 mutations run twice, which is why it is not in
`bun run green`. Green carries the cheap half as gate 6: the committed enumeration still
describes the kernel, and every filing resolves to a site that exists.

**All four ways the gate can fail were break-tested**: a site neither covered nor filed, a
filing for a site that no longer exists, a filing for a site the suite now catches, and a
declarative class losing coverage. Each was seen to fail naming the right thing. Those four
were run against the gate's logic with the measurement already in hand rather than through
a fresh thirty five minute run each; **the script itself was then run once end to end, from
its own harness run, and held.** Saying which of the two a check got is the point of saying
it was checked.

## What I got wrong

**Two of four predictions**, as above, and this time in opposite directions.

**I edited `mutate.sh` while it was running.** Bash reads a script incrementally, so shifting
the byte offsets under a running interpreter made it misparse its own scoring section after
completing all 385 mutations. Thirty minutes of measurement discarded, and I had written the
rule about not doing this two hours earlier in this same session.

**Backticks inside a double-quoted SQL string, twice.** The comments I wrote to explain the
query used backticks around code, bash performed command substitution on them, and it
executed `return;` and an `if` fragment as shell commands. Harmless both times and it means
the comment reaching the database was not the comment in the file.

**The heredoc backslash collapse, again.** Writing `\\1` in a Python heredoc produced a
literal 0x08 in earlier sessions and a literal 0x01 in this one, silently turning a regex
backreference into a control character. This is the fourth session it has cost time in. The
rule that works is `chr(92)`, and the rule I keep forgetting is to check the bytes rather
than read the line.

**The first equivalence check passed on two runs agreeing on having failed.** Both the
mutated and the unmutated call to `generate_inferred_history` returned "no such node",
because the fixture it needed had never been created, and the checker reported them
equivalent. That is precisely the fail-open shape this whole line of work is about, inside
the thing built to confirm the last eleven gaps.

**The first version of the conjunct assertions proved nothing.** They made a closed
placement by racking, and `now()` is the transaction timestamp, so a mutation that restamps
an already-closed placement writes exactly the value that was already there. The fixtures
insert history with an explicit older timestamp now.

**The `permissive` replacement was dropped from the case expression** when I rewrote
`guards.sh`, which turned three substitutable sites into three reported holes. Caught by the
run immediately after, because the script reports holes rather than dropping them.

## Does anything here change the judgment about the client

**No, and it sharpens it.** W-7 notes that the SQL layer is the most heavily verified part
of the system and the client the least, and that the next prompt should be the client's
first live run.

The ratio got worse this session, by a lot. The kernel went from 166 of 364 behaviourally
covered to 268, with a gate that ratchets and a script that enforces it. Section B's
nineteen client defects are where they were, and the client has still never run against a
live Supabase instance.

Two things found here bear on it directly. The first is that a green check can be hollow for
five sessions and only exercise reveals it, and the client is a body of code that has never
been exercised at all: typechecked, built, and never run. The second is that the null-permit
class is not a story about check constraints. It has now been found in check constraints, in
trigger validators and in the write paths, and the client is written in a language whose
`undefined` behaves the same way in comparisons. There is no reason to expect it to be the
one layer where that class does not appear, and there is currently nothing that would say.
