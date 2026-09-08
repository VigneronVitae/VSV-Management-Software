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

**S-7. RLS is exercised in Postgres and not through Supabase auth.**
`tests/schema_assertions.sql` now runs the policies with three accounts under the
`authenticated` role: a cellar user is refused locations, vessels and terms and
allowed events, a cellar user linked to no party sees the whole cellar, and a
client login sees its own lots and none of the others. That is the part Postgres
decides, and it holds.
What is still untested is the part Supabase decides: GoTrue issuing a JWT,
PostgREST mapping it to the `authenticated` role and setting the `sub` claim that
`auth.uid()` reads. The assertions set that claim directly, so they prove the
policies and assume the plumbing. *Resolves when:* the walk is run against a real
Supabase instance with two real accounts and the refusals happen there too.
*Until then:* treat the policies as correct and the wiring as unverified.

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

**S-13. Blending trials are not modeled.**
The Chardonnay protocol includes them. A trial is a proposed blend: components and
percentages, not executed, evaluated against tasting notes, and promoted to a real
blend when one is chosen. Orion treats a trial blend as a first-class object.
*Resolves when:* a trial is either modeled as a node that never acquires lineage, or
declared out of scope with a reason. *Load-bearing:* without it the reasoning behind
a blend lives in a notebook. Lineage records the blend that was made and loses every
alternative that was considered and rejected, which is the half that explains it.

**S-14. Activity costing has no input.**
Commercial platforms attach labour and equipment time to operations, which is what
makes cost per case computable at the end. Nothing in the schema records either.
*Resolves when:* volumes reconcile and case goods exist, which is to say S-8 through
S-12 first. Costing built on unreconciled volumes would produce a cost per case that
looks authoritative and is not.

**S-15. An operation whose effect the kernel understands, and whose meaning it does
not, still records.**
This is the intended behaviour and it is the spec's untyped floor applied to
vocabulary. A brewery defines `whirlpool` with effect `treatment`; the kernel
records the event, does the one thing the effect names, and knows nothing else
about it. The same floor covers `setpoint_change`, which the spec is careful to
call a decision rather than an observation and which carries effect
`measurement` here, because the only question effect answers is what happens to
volume and lineage, and for a setpoint the answer is nothing. Named so that it
reads as a choice rather than an oversight. *Resolves when:* some operation needs
behaviour beyond its effect, at which point either the kernel learns that
operation by name or the operation carries more configuration. *Not
load-bearing:* the failure mode is an operation that records and drives nothing,
which is visible rather than silent.

**S-16. `bottle` is filed as a transformation and is not really one.**
It closes a parent and writes lineage, which is why `transformation` is the
closest of the four effects. It also converts bulk to discrete units, which is a
change of kind the other three transformations do not make, and whether that is a
fifth effect is exactly the question S-12 defers. This entry exists so the filing
reads as a placeholder rather than a judgment. *Resolves when:* S-12 is answered
and the case goods seam is specified. *Watch for:* the first thing that branches
on effect and gets bottling wrong, which is the point this stops being harmless.

**S-17. No variety template is seeded, so inferred history generates nothing.**
`generate_inferred_history` returns zero for every variety, because `template` and
`template_step` are empty: the six protocols are transcribed and not encoded. A
lot created by the walk therefore has no history, which is the correct answer for
a variety with no protocol and is, from inside the app, indistinguishable from a
template that exists and failed to match. *Resolves when:* the six protocols are
encoded, at which point the backfill path in build order 1 starts returning
history and this function starts doing its job. *Not load-bearing:* zero is
truthful. The risk is that it gets read as a bug in the generator and someone
goes looking in the wrong place.

## Discharged

*None. Nothing has been built.*
