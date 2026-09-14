---
Type: review
Purpose: "An outside reading of the cellar export, checked against the live database, with every claim confirmed or corrected and every recommendation either taken or argued with."
Depends on: [docs/sorry-ledger.md, packages/cellar/docs/spec.md]
Depended on by: [docs/status-ledger.md]
---

# A red team of the export, and what it is owed

On 2026-09-14 the winemaker took an export of the cellar and had it read by
somebody outside this project. The reading is good. It is the first assessment
of this system made by someone with no stake in the decisions, working from the
data rather than from the documents, and it found six things. **Every factual
claim in it is true.** I checked each against the live database rather than
against my memory of what I built, which matters, because two of the six are
things I would have said were already handled.

What follows keeps the reviewer's numbering, states what I verified, and then
says what I am doing about it. Three are being acted on, two are being filed
with the reason they are not being acted on yet, and one is being argued with.

## Confirmed, all of it

Before the disagreements, the parts worth not burying.

The reviewer reconstructed the object model correctly from the data alone: a
node is a lot of material, a vessel is a physical container, a placement is the
bridge saying which material is in which container, an event is the logbook, and
lineage is how material descends from material. That is the model, and nothing
in the documents was available to them. A model that reads correctly from its own
data is the thing this project is actually trying to be.

They also checked the arithmetic and it holds: 747 + 799 + 786 = 2,332 lbs, which
is the Pinot Gris lot's recorded quantity, and each of the three nets is its gross
less the 92 lb tare. That is the intake path working end to end on real fruit,
verified by somebody who was not standing in the barn. **That is a better test
than any assertion in this repository, because it was made without knowing what
the answer was supposed to be.**

And they found no dangling references, no duplicate ids, no broken node-to-vessel
links. I did not expect any, but "I did not expect any" is not a measurement.

## 1. Quantity on placement: the problem is real and the fix is wrong

**Verified.** `placement` carries `id, node_id, vessel_id, volume_l, from_at,
to_at, created_at, fill_pct` and no general quantity or unit. All three Pinot Gris
placements say `fill_pct: 100` and nothing else. The pound figures are in the
weighing events.

**The recommendation is to add `quantity` + `unit` to `placement`. I am not doing
that, and the reason is a fact about scales rather than a preference about
schemas.**

A weighing is of whatever went on the scale. The winemaker weighed this pick one
bin at a time, which is why the per-bin figures appear to exist. Put two bins on
the scale together, which is the ordinary case with a forklift and macrobins, and
there is one gross, one tare for two bins, and one net. **There is no per-bin
number.** Writing `quantity` onto each placement would mean the app inventing two
numbers that were never measured, splitting the net somehow, and then presenting
them with the same authority as a reading. That is precisely the shape axiom T0-2
exists to refuse, and the reason it is worth refusing is that a fabricated number
is indistinguishable from a measured one six months later.

So the problem stands and the answer is a different one: **the question should be
answered at the resolution it was measured at.** "PB1 and PB2 weighed 1,546 lbs
together at 9:14" is a true sentence that the database can produce. "PB2 contains
773 lbs" is not, and no column will make it one.

That is now sorry **S-66**, with the view it wants described. I am not building
the view today because nothing is asking the question yet, and building it
speculatively would mean guessing at how somebody wants to read it.

One thing the reviewer could not see and should know: `pick_weighing`, added as
migration `0048` this evening, is the first step of exactly this. It lists every
reading with the bins that were on the scale for it, because somebody holding a
photograph of a display needs to find the reading it shows.

## 2. The Eola Springs vintage: correct, and it is data rather than schema

**Verified.** `2024 Eola Springs` has `vintage` null. The other three lots all
carry theirs. The year is in the name and nowhere a query can reach it.

The reviewer is right that vintage searches and blending checks will silently
miss it, and silent is the operative word.

**This is a data-entry correction and it is the winemaker's to make, not mine.**
The standing rule in this repository is that I do not fix data by hand; I report
what is wrong. Setting it is one edit on the lot screen.

The question underneath it is worth more than the fix: **should a lot be allowed
to have no vintage at all?** There is a real case for null, which is a
non-vintage blend, and that case is rare enough that requiring an explicit "NV"
would be better than permitting a blank. I am not changing the constraint without
asking, because "is a vintageless lot a thing at this winery" is a domain question
and guessing at domain semantics is the one thing CLAUDE.md forbids outright.

## 3. Block variety versus planting variety: half right, and the half that is
right is about the export

**Verified, and then corrected.** `block` does carry a `variety` text column
alongside the `planting` table's `variety_id`, exactly as described.

But nothing writes `block.variety` any more. Migration `0039` moved a block's
variety into `planting`, kept the text column deliberately because a label
matching no variety in the vocabulary is the only surviving record of what
somebody typed, and `0040` made it nullable after the `not null` it had been left
with made every new block impossible to create. The column carries a comment
saying it is superseded and to read `planting_detail` instead.

So the divergence the reviewer fears, a block saying Pinot Gris while its planting
says Chardonnay, cannot arise from anything the app does today. It could only
persist from data entered before `0039`.

**The real finding is narrower and is one I would not have looked for: the export
presents a superseded column as though it were current.** A reader with only the
export in front of them has no way to know which of two variety fields is
authoritative, and the reviewer reached the only conclusion available to them.
That is a defect in the export, not in the schema, and it is the sort of thing
only an outside reading finds.

## 4. Vessel ownership and what null means: taken

**Verified.** Six of eight vessels carry `owner_id` null, including the picking
bins, Eric, Skinny Boy and the 2200L VC.

The reviewer is right, and right for the reason they give rather than on style:
null is currently doing the work of "ours", which leaves nothing to write when a
vessel's owner is genuinely unknown. Two custom crush clients already keep barrels
in this barn. A borrowed macrobin whose grower nobody wrote down is a real object
and there is no way to say so.

Filed as **S-67**. Their preferred fix, writing the facility party onto the
vessels that belong to it and returning null to meaning unknown, is the better
one and is a data change rather than a migration, which makes it the winemaker's
call and a cheap one.

## 5. The export is not a photo backup: taken, and it is the sharpest one

**Verified.** Vessel rows carry paths like `<id>/photo.jpg` into a private
storage bucket. The export is json. The photographs are not in it.

The reviewer's framing is the right one: **if the button means "I can restore my
winery if the server explodes", it does not mean that.** That gap is silent until
the day somebody needs it, which is the worst shape a gap can have.

Filed as **S-68**, separately from S-29, which is about vocabulary ids being
reissued on a restore. This one is about bytes that were never in the file.

The honest interim is one hour of work: the export button says out loud that
photographs are not included. The right answer is a zip of the json plus the
bucket. I would rather ship the sentence today than the zip next week, because a
backup somebody trusts wrongly is worse than one they know the limits of.

The observation lands harder tonight than it would have this morning: migration
`0047` has just made photographs a first class record that can hang off any
subject, so from today the system will start accumulating a lot more of them.
The export's gap gets wider from here.

## 6. Lineage is untested: agreed without reservation, and it is the next thing

**Verified.** `lineage` has zero rows. All four existing lots were entered on
2026-09-14 and record present state rather than history.

The reviewer is right that this is reasonable when adopting a new system, right
that it means the database knows where the wine is and not how it got there, and
right that lineage becomes the most important part of the whole system once
pressing, splitting, blending and bottling start.

Their proposed test is the correct test, and it is close to the one this project
already intended: take the three Pinot Gris bins through pressing, press cuts,
settling, transfer, additions and blending, and check whether every pound and
litre reconstructs backward to the vineyard without loss or double counting.

Two things worth adding to their framing. The press path is built and asserted,
including cuts as of `0045`, so this is a test that can run rather than a feature
request. And the specific arithmetic to watch is the one `0045` settled: every
cut of one press draws a share of every parent proportional to fruit weight, so
free run and hard press are made of the same fruit in the same ratios. If that is
wrong, it is wrong in a way that only shows up on a real press with real cuts,
which is the Pinot Gris, which is tomorrow.

## What I am doing, in order

1. **Nothing, today, that delays the photographs.** The winemaker has three
   pictures of a scale that have been stuck on a phone since this morning, and
   `0047` and `0048` exist to unstick them. That ships first.
2. The export saying plainly that photographs are not in it. One hour, and it
   converts a silent gap into a stated one.
3. The Eola Springs vintage, by the winemaker, on the lot screen.
4. The vintage question asked rather than guessed: is a lot with no vintage a
   real thing here, or should it be an explicit non-vintage?
5. S-66's view, when something is actually asking the question.

## What this review is worth

The two findings I would not have found are 3 and 5, and neither is a schema
defect. Both are about what the export *says* to somebody who was not there,
which is the one thing nobody inside this project can test, because we all know
which column is superseded and which path leads to a bucket.

That is the argument for doing this again. Not a code review, which this project
has more of than it needs, but somebody reading the data cold and saying what
they think it means.
