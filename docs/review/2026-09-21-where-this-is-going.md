---
Type: review
Purpose: "An architectural read of the whole system at the end of a long build day, written to be argued with: what is widening faster than it is being used, which structural gaps bite in what order, and where an agent is and is not useful here."
Depends on: [docs/status-ledger.md, docs/sorry-ledger.md, docs/architecture-rulings.md]
Depended on by: [docs/status-ledger.md]
---

# Where this is going

Written overnight 2026-09-21 at the winemaker's request: "overnight think about
ways you might be able to help with things, like big picture architecture and
stuff." It is a read rather than a plan, and every section is meant to be
disagreed with.

## The thing I would say first

**The system is five apps wide and one harvest deep, and the width grew today
while the depth did not.**

Today added four migrations of tool and place infrastructure, a fifth periphery,
and zero rows of tool data. The stores app is real and opens onto five flat
untagged rooms and one supply called Plastic Wrap. Meanwhile the cellar has six
picks and thirteen open lots in it, entered by hand, during the fortnight that
cannot be repeated.

That gap is the architectural risk, more than any individual missing feature. A
system with five doors and one furnished room has five ways to look wrong to
somebody new, and each new door costs something every time the kernel changes
underneath it: today the `location_tag` to `domain` rename touched two views,
two functions, two capabilities, a readable and six assertions, an hour after the
thing being renamed had shipped.

The honest counter-argument, and it may be right: the peripheries are cheap
because the contract makes them cheap, that is exactly what AR-Q8 predicted, and
proving it on five apps is worth more than furnishing one. I do not think the
evidence settles this yet. What would settle it is somebody other than him
opening the stores app and getting somewhere.

## What bites, and when

Ranked by when rather than by size. There are 106 sorries and 13 marked
load-bearing; these are the ones whose timing is structural rather than
incidental.

### Now, because harvest is now

**S-30, the offline story, is the one I would fix first.** Thirteen open lots,
fruit still coming, and the app is request-response over Tailscale to a laptop in
a barn. Every write today assumed a connection. The sorry has been open since the
wire session and its question is still unanswered: what does the client do when
somebody racks a barrel in a shed with no signal?

The reason it is urgent is not that the barn has no signal. It is that **nobody
finds out it had no signal until the write is already lost**, because a failed
write and an unattempted write look the same to a person walking away from a
tank. That is A13 in the one place A13 has no screen to put a sentence on.

The reason it is tractable is that the sorry's own analysis narrows it: `rack`
and `record_event` cannot queue because performing them offline means a client
reproducing a kernel decision. But `add_note`, `record_work`, `attest_line`,
`take_sample` and `attach_photo` derive nothing. Five verbs that queue safely and
two that must not is a much smaller problem than "build offline", and the
distinction is already written down.

### Soon, because three features are waiting on it

**Relationships are not typed; only annotations are.** A note can point at
anything through `subject_resolver`. A lot points at a block through a hardcoded
`node.block_id`. Three separate requests in three conversations hit this:

- this bank line paid for that machine repair
- this work order needs those shears
- this tool is with that person

Three independent uses is the corpus CLAUDE.md asks for before generalising, and
it arrived honestly rather than by anticipation. But I would still not build one
generic edge table. Custody has an interval and a direction that a bank-line link
does not, and `placement` already proves that exact shape for wine in a vessel.
Build custody specifically, watch whether the second case wants the same table,
and generalise on the third. The corpus justifies *considering* it, not
collapsing all three into one row type.

### Quietly, and the one I would watch

**The contract is 31 capabilities of cellar and 8 of everything else.** That is
not wrong, it is the build order, and spec.md section 7 is ordered by
irrecoverability for good reasons. What is worth watching is that every
non-cellar module was added by writing its verbs *after* its tables, which is
how `count_supply` ended up filed under `cellar` for four months and how the
vineyard shipped an app with no verbs at all.

The check that would catch this does not exist: nothing asserts that a module
with tables has capabilities, or that a capability lives in the module whose
tables it writes. Both are mechanical. Neither is written.

### The one with an irreversible failure mode

**S-139**, filed today. The data surface check reads rows; every leak tonight was
prose. A card's last four digits reached a tracked file and was found by reading
the diff before a first push, not by any check. The mechanical half is easy and
should exist before the next push: currency amounts, runs of twelve or more
digits, four-digit card fragments. Company names are not mechanically decidable
and that part should be a human reading a diff, which is what happened.

## What harvest itself needs in the next fortnight

Separately from architecture, because the deadline does not move:

**Nothing in the cellar is blocked.** Picks, presses, racking and sampling all
work and are being used. That is the important sentence in this document.

**Harvest so far has no screen.** The readables exist and nothing opens them.
Given six picks and thirteen lots, this is the highest ratio of usefulness to
work on the list, and it is an afternoon.

**S-51 refuses a cellar hand adding a block, during harvest**, and the workaround
is to ask him. Marked load-bearing specifically for these weeks.

**S-96**, the previous years' weight sheets, is load-bearing because the table
exists to hold his history and holds one vintage. Not urgent this fortnight and
worth doing before the memory of the sheets' three different schemas fades.

## Where an agent is useful here, and where it is not

The most useful thing I can write, because it is the part nobody else has
evidence about.

**Useful:** the mechanical checks. Every one of the gate's steps has caught
something real, several of them catching me. Today the contract check found two
`add_note` functions within a minute of my creating them; the two-run
reconciliation found an assertion that tested more against a full database than
an empty one; the header graph found four broken links. This is the repository's
best idea and it compounds.

**Useful:** reading a corpus and reporting what is in it rather than what should
be. The vine map decode, the QFX shape, the ledger match rate of 348 in 381, the
memo wrapping. Each of those replaced a guess with a measurement, and in three of
the four the measurement contradicted the plan.

**Not useful, and today proved it four times:** anything that depends on my
having remembered a list. `scripts/screens.sh` reads a hardcoded list of three
place files and the books app went a day unchecked. `scripts/verify.sh` has had
the same bug four times over four languages. `data-surface.py` checks a
hardcoded set of structural tables. Each was written by me, each was correct when
written, and each went silently wrong the moment the thing it enumerated grew.
**A check whose coverage is a literal list will be wrong, and it will be wrong in
the direction of passing.** Where a check can derive its own scope, it must.

**Not useful:** my judgement about what is real in his world. I nearly deleted
four vessel makers today believing they were my test pollution; they were real
coopers on four real barrels. The tell was available and I nearly did not look
for it. The rule that saved it was checking references before deleting, and that
rule should be treated as absolute rather than as good practice.

**Worth knowing about the failure shape:** three of today's defects were the same
defect. `.sheet` collided with an existing class, then `.photo` collided the next
day. `0117` applied cleanly and loaded nothing; `0135`'s assertion passed against
a full database and fired against an empty one. `create or replace` did less than
it sounded like it did, twice, in two different ways. In each pair the second
instance came after the first was written down. Writing it down is not sufficient
and I do not have a proposal for what is, beyond the checks.

## What I would do next, in order

1. **The harvest screen.** An afternoon, and it makes today's most useful view
   reachable during the fortnight it is about.
2. **The prose half of S-139**, mechanically, before any further push.
3. **Offline for the five verbs that derive nothing.** Say out loud which two
   are online-only and make the app say so before somebody starts.
4. **Custody**, specifically, not generically.
5. **The two module checks**: a module with tables has verbs, and a capability
   belongs to the module whose tables it writes.

And one thing I would not do: build the sixth periphery. Marketing is the last
greyed-out door and it should stay grey until something behind it exists.
