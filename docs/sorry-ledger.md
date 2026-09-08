---
Type: record
Purpose: "Records every open deferred-verification obligation for the winery app, one entry per gap, as the honest unit of progress."
Depends on: [packages/cellar/docs/spec.md, docs/methodology-lineage.md]
Depended on by: [docs/status-ledger.md, CLAUDE.md, README.md]
---

# Sorry Ledger

A named gap is a build artifact. A gap without a record is one you cannot revisit.

## Open

**S-1. Topping lineage threshold undecided.**
Strictly, topping makes every barrel a two-parent node, which produces thousands of
edges and is unusable. Below some percentage the volume and source are recorded
without writing lineage. That percentage is not chosen. *Resolves when:* a threshold
is set explicitly, with the reason recorded. *Load-bearing:* affects whether block
composition on a topped barrel is honest.

**S-2. Conditional intervals do not fit `offset_rule`.**
Template steps carry an interval from the previous step. "Cold crash until clear" and
"malo until complete" are conditions, not durations. *Resolves when:* either a
condition-based step type is added, or conditional steps are excluded from templates
and created by hand. *Load-bearing:* four of six protocols contain at least one.

**S-3. Partial consumption of a parent is unhandled.**
The `lineage_closes_parent` trigger closes a parent entirely on first child. Pressing
half a bin and holding the rest would close the bin while material remains.
*Resolves when:* either a fraction-sum check replaces the trigger, or partial
consumption is declared out of scope with a reason. *Load-bearing:* silently wrong,
not loudly wrong, which is the worse kind.

**S-4. `event.subject_id` is not a foreign key.**
The cost of one events table across four subject types. A bad subject id fails
silently. *Resolves when:* `doctor` checks it and is run on a schedule. Until then,
every event count is unvalidated.

**S-5. Vessel `type` granularity unverified.**
`barrel` may need to distinguish puncheon from barrique from the acacia pieces.
*Resolves when:* the physical inventory walk in Stage 0 says whether it matters.

**S-6. Wine Meister export path unknown.**
Marketing says export; whether that is automatable or a manual download is unverified.
*Resolves when:* someone tries it. *Consequence if manual:* transcription stays
manual, which the spec already assumes, so this is a possible improvement rather than
a risk.

**S-7. RLS untested against a real cellar user.**
The policies in `0002` are written and have never been exercised by a second account.
*Resolves when:* an intern account exists and the admin-only writes actually refuse.

## Discharged

*None. Nothing has been built.*
