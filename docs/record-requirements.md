---
Type: record
Purpose: "The four paper forms Alexis handed over, field by field, against what the app records today. The forms are a statement of what must be captured, so this is the acceptance criteria for the recording surface rather than a list of paperwork."
Depends on: [packages/cellar/docs/spec.md, docs/sorry-ledger.md]
Depended on by: [docs/session-reports/index.md]
---

# What has to be recorded

Four forms were handed over on 2026-09-14, the day of the first pick, with the
framing that matters: **these are Alexis saying what information she wants
recorded.** They are not a paperwork obligation that the app happens to sit
beside. They are a specification of the recording surface, written by the person
who will be looking for the numbers in March.

So this document is a coverage list, and the gaps in it are work.

Two things it is deliberately not. It is not the propagation queue: `0043` tracks
which measurements still have to be copied onto physical documents, which is a
different question from whether the app can capture them at all. And it is not a
schedule: the order at the bottom is what the season forces, not what anybody
promised.

## Reading the status column

| Status | Means |
|---|---|
| **held** | The app records this today and a screen collects it |
| **derivable** | The data exists and nothing presents it in this shape |
| **absent** | Nothing in the schema holds it |

## Fruit receiving

The one the first pick already exercised. `0033` was built from the same
practice this form describes, which is why it lines up.

| Field | Status | Where, or what is missing |
|---|---|---|
| Vineyard | held | `vineyard`, since `0039` |
| Grape variety | held | `node.variety_id`, and `planting` per block |
| Harvest date | held | the pick's `created_at` |
| Date/time received | **absent** | picked and received are the same moment today, and for bought-in fruit they are not |
| Tonnage | derivable | `node.quantity` in lbs; tons is a division nothing performs |
| Containers | held | bins, as placements on the pick |
| Gross weight | held | `weigh_bins`, on the weighing event |
| Tare | held | as above, summed per bin from the bin type |
| Net fruit weight | held | as above, and it is what the pick's quantity is |
| Condition | **absent** | no field for how the fruit looked |

**Two gaps and both are small.** Fruit condition is a text field on the pick.
Date received matters the moment fruit arrives that somebody else picked, which
is Pearlstaad, which is tomorrow.

## Must chemistry

Taken at receiving, per lot. **Nothing here is held.** The `sample` operation
exists as a vocabulary row and has never had a screen or a typed shape behind it:
this is build order 4 in spec.md §7, arriving earlier than the build order
expected because the form is filled in at the crush pad.

| Field | Status | Note |
|---|---|---|
| Lot name | held | `node.name` |
| Variety(ies) | held | `node.variety_id`; a blend of several is lineage |
| Date harvested | held | the pick |
| Brix | **absent** | |
| pH | **absent** | |
| TA | **absent** | |
| YAN | **absent** | |
| AAN | **absent** | |
| Malic acid | **absent** | |
| Temperature | derivable | `temp_reading` exists as an operation with no screen |
| Other | **absent** | the form's own escape hatch, which the schema should copy |
| Fruit condition | **absent** | the same field the receiving form wants |

**This is the urgent one.** Receiving chemistry is taken as fruit arrives and
there is nowhere to put it, so today it exists only on paper.

## Processing log

Press and ferment set-up, per lot. About a third held, and the third that is held
is the part `0034` built.

| Field | Status | Note |
|---|---|---|
| Wine/lot name | held | |
| Variety/blend | held | |
| AVA/grower | derivable | grower is the vineyard; **AVA is absent** |
| Farming certifications | **absent** | belongs on the vineyard or the block |
| Current vessel | held | placement |
| Lot size | held | `node.quantity` |
| Processing date/time | held | the press event |
| Skin maceration time | **absent** | |
| Press program | **absent** | |
| Press fractions/cuts | **absent** | filed as S-52 on the morning of the first pick |
| Whole cluster / destem | **absent** | `whole_cluster_pct` is named in spec.md §2 as an attribute and nothing writes it |
| Tonnage pressed | held | `press` records lbs in |
| Must yield gal/L | held | `press` returns and records litres out and L per ton |
| Skin contact start / end / total | **absent** | total is a subtraction, so two timestamps buy all three |
| Temperature | derivable | `temp_reading`, no screen |
| Additions + date + wine volume | **absent** | `addition` is an operation with no screen; volume at the time is derivable from placements |
| Yeast inoculation date and strain | **absent** | |
| Malolactic inoculation date and strain | **absent** | `malo_check` exists and is not this |
| SO2 additions + date + wine volume | **absent** | |
| Destination vessel(s) | held | `press` places the child |

## Assemblage and pre bottling

The furthest from harvest and the least built. Recorded here so the shape is
known before anybody designs around it.

| Field | Status | Note |
|---|---|---|
| Wine/lot name, variety/blend, volume | held | |
| AVA/grower | derivable | as above, and AVA is absent |
| Date assembled | held | the blend event |
| pH, TA, residual sugar, malic acid, free SO2 | **absent** | the same chemistry gap as must chemistry, at the other end of the year |
| Wine blending components | **derivable** | this is exactly what `lineage` holds, and `block_composition` already walks it. Nothing presents it as a list |
| Pre bottling treatments: addition, date, rate | **absent** | |
| SO2 additions: amount, date, rate, free SO2 before and after | **absent** | before and after are two measurements bracketing a treatment, which is a shape nothing in the schema expresses yet |
| Historical additions: addition, date, wine volume at addition, component, percent of total | **derivable and hard** | every part is derivable from events plus placements, and the percent-of-total column is the one that needs care, because the denominator moves |

## What this comes to

**One class of thing accounts for most of the absences: a measurement with named
parameters.** Brix, pH, TA, YAN, AAN, malic, free SO2, residual sugar, temperature
are the same shape asked at four points in the year. Building nine columns would
be wrong; building a measurement that carries named readings, with the parameter
list as registry rows the way `0027` made every other list a row, covers all four
forms at once and the fifth form nobody has handed over yet.

**The second class is a treatment with a rate and a volume.** Additions, SO2,
pre-bottling. Same shape, three names.

**The third is press detail**, which is specific to one operation and is a set of
fields on the press event.

The order, which is the winemaker's and not the one this document first
proposed. Readings look urgent because the form is being filled in by hand
today, and he moved them down for a better reason than urgency: **the chemistry
specification is not finished.** More parameters are expected, so building the
reading surface now means building it twice, and the second build would land on
top of a season of real data. Press detail has no such problem: the form in hand
is the whole of it.

1. **Press detail.** Cuts, program, skin contact, whole cluster, yeast and
   malolactic strains. Specified completely by the processing log, needed as soon
   as reds come in, and cuts are already filed as S-52.
2. **Fruit condition and date received.** Two fields, and the second matters the
   first time fruit somebody else picked arrives, which is the next delivery.
3. **Readings.** Once the parameter list has settled. The shape is known already
   and it is the registry pattern: parameters as rows, so the list that has not
   settled is data rather than a schema.
4. **Additions and SO2.** Needed through fermentation rather than at the crush
   pad.
5. **Assemblage.** Next year, except for the blending-components list, which is
   lineage already and only wants presenting.
