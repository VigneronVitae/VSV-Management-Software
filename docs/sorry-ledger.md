---
Type: record
Purpose: "Records every open deferred-verification obligation for the winery app, one entry per gap, as the honest unit of progress."
Depends on: [packages/cellar/docs/spec.md, docs/methodology-lineage.md]
Depended on by: [docs/status-ledger.md, CLAUDE.md, README.md]
---

# Sorry Ledger

A named gap is a build artifact. A gap without a record is one you cannot revisit.

S-8 through S-12 are compliance gaps. Every one of them must be confirmed with
the winery's compliance advisor before any schema is built for it. A guessed
tax boundary produces confident wrong numbers on a federal return, which is a
worse outcome than producing none.

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
`0003` adds a narrower one on top: a cellar user linked to a client party sees only
that party's nodes. Same status, written and never exercised.
*Resolves when:* an intern account exists and the admin-only writes actually refuse,
and a client account exists and sees exactly its own lots. *Until then:* client
scoping is a policy, not a boundary that is known to hold.

**S-8. Volume losses are not modeled.**
TTB requires volume to be accounted for, and racking, evaporation, and lees are
where it goes. A lot can currently lose fifty liters between two placements with
nothing in the record saying so. *Resolves when:* the compliance advisor confirms
what has to be recorded and at what granularity. *Load-bearing:* every volume
figure the app can produce is currently unreconciled.

**S-9. Unit conversion has no single home.**
TTB reports in wine gallons; the schema permits litres and gallons per node.
Conversion has to happen in exactly one place, and it currently happens nowhere.
*Resolves when:* one conversion point is chosen and every reporting path is made
to go through it. *Note:* the danger here is not the arithmetic, it is two call
sites rounding differently.

**S-10. Tax class is not represented.**
Class derives from ABV and product type, and a transition across a boundary is
reportable. The class itself should be a function rather than a column, per T0-2,
but the ABV measurement and the transition event both have to be stored and
neither is. *Resolves when:* the compliance advisor confirms which boundaries
apply to this facility, cider and vermouth included.

**S-11. Bond status is not represented.**
Wine sits in bond until removal, and taxpaid removal is the taxable event the
excise return is built from. Nothing in the schema knows which side of that line
a lot is on. *Resolves when:* the compliance advisor confirms which removal
events have to be recorded and what each one carries.

**S-12. The bottling seam is underspecified.**
Bottling converts bulk to case goods and is the point where the object changes
kind. The case goods module does not exist, but the bottling event has to record
enough for one to attach to it later: source lot, volume, case count, SKU, ABV at
bottling, and whether it went taxpaid or stayed in bond. *Resolves when:* those
fields are confirmed and the `bottle` event carries them. *Load-bearing:* bottling
this vintage against an incomplete event means the case goods module has nothing
to hang on, and the bottling already happened by the time anyone notices.

## Discharged

*None. Nothing has been built.*
