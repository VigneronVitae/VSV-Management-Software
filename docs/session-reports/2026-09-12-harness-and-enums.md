---
Type: record
Purpose: "Records the W-4 session: the mutation harness taught to say what it excluded, the null-permit shape filed as a class and searched for a fourth instance that is not there, and both core enums turned into registry rows."
Depends on: []
Depended on by: [docs/session-reports/index.md]
---

# 2026-09-12: the instrument, the class, and both enums

W-4, phases 1 to 4, complete and green at `0027`. W-2 phase 6 is next.

## Predictions, recorded before measuring

W-4 made this a standing rule and this session is the first to follow it. All three were
written into the progress file and committed before phase 1 ran.

**1. Phase 1 will not move the percentage and will move the denominator.** Correct. The
two defects W-4 names were fixed in W-3, so what was left was honesty rather than
coverage: 188 of 188 before and after, with 20 exclusions that used to be invisible now
named.

**2. Phase 2 will find a fourth instance, and more than one.** *Wrong on the first half,
right on the second.* I expected two to five more check constraints of A24's shape and
expected no boolean function to answer null. There are none of either. The class has
exactly three instances and there is no fourth.

The reasoning behind the wrong half is worth keeping, because it was not unreasonable:
`X <> 'literal' or <expr>` is the natural way to write a conditional constraint in SQL and
this schema has eighteen check constraints. It turns out the shape needs the expression to
be able to answer null on non-null input, which in practice means a JSON lookup or a
function call, and only one constraint in this schema does that.

**3. Phase 3 will trip the pinned assertions deliberately, and will introduce at least one
new instance of the phase 2 class.** Correct on the first half, five times over. The second
half is *arguably correct and I am not going to claim it*: the conversion did not introduce
a null-permit instance, but it came within one substitution of turning a validator into a
no-op, which is the same family and was avoided rather than survived.

## Phase 1: the instrument said 100 percent and could not say what it excluded

The two specific defects W-4 names were repaired in W-3. What was left was the thing
underneath them: a harness that reports a number without reporting that the number is
unsound.

It now takes a catalog fingerprint before and after each mutation. A mutation that applies
and changes nothing is degenerate, named in the output, excluded from both columns. The
enumeration-time exclusion of nineteen already-open policies is gone, because dropping them
quietly was correct and invisible, and invisible was half of what was wrong with it. A run
with anything excluded cannot print a bare percentage, and a run that scores nothing exits
non-zero.

| | Before | After |
|---|---|---|
| Reported | 188 of 188, 100 percent | 188 of 188 scored, from 208 enumerated |
| Excluded | 19 dropped at enumeration, 1 refused to apply, neither mentioned | 20, listed with reasons |

**Writing the degeneracy check reproduced the defect it exists to prevent.** The
fingerprint query raised, because `tgenabled` is `"char"` and concatenating it without a
cast is ambiguous, so the function returned empty. The guard `[ -n "$before" ]` then
skipped degeneracy detection silently, for every mutation, and the run reported a clean
score. A check that fails open and says nothing, inside the fix for checks that fail open
and say nothing. It aborts now, and the abort is break-tested.

## Phase 2: a class with three instances and no fourth

A25 is filed as a class rather than as a third unrelated defect, because that is what it
is. `is_facility_user()` coalesced a missing party row to true. `may_see_all_of` returned
null where nothing matched. `operation_has_an_effect` is `false or null` for an operation
carrying `{}`. Three mechanisms, three sessions, three routes, and nobody wrote any of them
on purpose.

The invariant, which is `AR-B9` applied below the gate at the level of individual
constraints and functions: **a predicate that cannot determine an answer must refuse, never
permit.**

The derived assertion enumerates the population from the catalog and exercises each member
against every row the table could actually hold. At `0027` exactly one constraint answers
null, it is A24, and it is on the allow-list with its reason. **There is no fourth
instance, and that is the finding.**

**Two wrong tests came first and both are recorded in the assertion itself.** A row of all
nulls flagged twelve constraints, eleven of them wrongly, because forcing a NOT NULL column
to null asks about a row the table can never hold. A row of empty values flagged none,
including the real one, because A24's witness needs `kind = 'operation'` and the empty row
takes the first enum label. That second version passed, and would have passed forever, and
was caught only because the break test removed A24 from the allow-list and nothing failed.

The third version enumerates candidate values per column, every label for an enum, and null
only where the column is actually nullable. It flags A24 and does not flag
`mode = 'off' or has_glycol`, which is the distinction the first two could not draw.

## Phase 3: both enums are rows

Split into two migrations so each is green on its own.

**`0026`, `subject_type`.** The registry already existed, so this deletes the enum rather
than building a second one beside it: registering a resolver is now what brings a subject
type into existence. Three foreign keys with `on delete restrict`, so uninstalling a module
while tasks still point at its subjects is refused rather than cascading.

**`0027`, `term_kind`,** much the larger: nine generated columns, nine composite foreign
keys, four views, a view-returning function, three constraints, an index and two typed
defaults. Enumerated from the catalog rather than listed by hand, following `0020`, because
hand-listing eighteen objects is where one gets missed.

Six of the eight kinds belong to winemaking or inventory. The registry records which module
owns each, and reading that list is the clearest statement of why the enum was wrong.

### Two traps, both of which would have been silent

**Dropping a generated column and adding it back moves it to the end of the table.**
`vessel_state` reads `visible_node(p.node_id)` through a **positional** column alias list.
Reordering `node` rebound `product_type_id` to `hidden`, and the view came back with
`uuid = text[]`. The columns are altered in place instead, which keeps their position.

It failed loudly only because this migration recreates the view. A migration that touched
the columns without recreating the view would have left the alias list quietly wrong, and
`vessel_state` would have started reporting one column's contents under another's name.

**A cast can be the check.** `validate_vessel_type_fields` proved that a picker names a real
vocabulary by casting the text to the enum and catching the failure. That is a good check
while `term_kind` is a closed type, and it is the check that produced the error `0020`
records. Rewrite `::term_kind` to `::text` and the cast always succeeds, the exception
handler never fires, and the validator silently stops validating. It is a registry lookup
now.

That is precisely the shape W-4 warned this conversion produces, and it was caught by
reading the body rather than substituting into it. The assertion for it is the one that
would have caught the silent version.

### The pins earned their keep, five times

The constraint inventory, the generated-column expressions, the policy count, the wide-open
policy list and the foreign-key delete behaviour all failed across the two migrations, and
every failure was deliberate and was updated with its reason in the same commit. That is
what W-3 phase B pinned them for, and it is the first session in which they were tested by
a migration rather than by a break test.

## The mutation score, with its set named every time

| When | Scored | Caught | Score | Excluded |
|---|---|---|---|---|
| `G-5`, September, its own 45 | 45 | 19 | 42% | not reported |
| This harness, September, at `0022` | 115 | 28 | 24% | not reported |
| W-3 end, at `0025` | 188 | 188 | 100% | 20, unreported |
| W-4 phase 1, at `0025` | 188 | 188 | 100% | 20, named |
| After `0027`, before closing the gap | 198 | 195 | 98% | 20, named |
| After closing it | 198 | 198 | 100% | 20, named |

**The fall to 98 percent was real and it was mine.** `0026` and `0027` added three bare-name
check constraints and nothing asserted them, which the `loosen` class found the moment they
existed. Three assertions closed it.

That is the whole point of the instrument working: new surface created in one session was
measured as uncovered in the same session, and the number went down before anybody claimed
otherwise.

## What is still true about what the score does not mean

Unchanged from W-3 and worth repeating because two more migrations have landed since. Seven
of the eight classes are enumerated from the catalog and grow with the schema. The eighth,
`logic`, is ten hand-chosen substitutions against function bodies. The declarative surface
is policed; the procedural surface is sampled.

W-2 phase 6 moves the scheduling block, and phases 7 and 8 rewrite function bodies. W-4 says
plainly not to start those on the strength of this score, and nothing this session found
changes that.

## What I got wrong

The prediction about a fourth instance, described above.

The first degeneracy check failed open and said nothing, which is the defect the session
was fixing.

The first null-permit test over-reported by eleven and the second under-reported by one,
and the second is the worse failure because it passed.

The first version of `0027` dropped and re-added generated columns, which silently
reordered `node`. Caught by the view refusing to come back.

And I wrote two function bodies from memory before reading them, one of which referenced a
table that does not exist and the other of which would have deleted a validation by
substituting a cast. Both were replaced with the real definitions. The general rule that
comes out of it: when a migration has to recreate something, take the definition from the
catalog and change it deliberately, never retype it.
