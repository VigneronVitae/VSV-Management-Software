---
Type: review
Purpose: "What maintenance and inventory systems do elsewhere, measured against the shop module built this week, so the next decision about it is made against evidence rather than taste."
Depends on: [docs/status-ledger.md, supabase/migrations/0105_a_machine_is_a_departure_from_its_model.sql, supabase/migrations/0046_supply_inventory.sql]
Depended on by: [docs/status-ledger.md]
---

# The shop and the stores, as other people build them

Researched on 2026-09-17 at the winemaker's request, the day after the shop
module was built: *"Can you do some research into apps and systems that perform
this function now? The shop + inventory/etc."*

Same rule as the 2026-09-15 scouting document: everything below is either
something a shipping product does or something an industry body recommends, and
each finding ends with what it means for this repository. Where this app already
does the thing, it says so; where it does the thing differently on purpose, it
says why; and where it is simply missing something everyone else has, it says
that plainly.

The category is called CMMS, computerised maintenance management system, or EAM
for the larger ones. The ag-specific products are a thin layer over the same
ideas.

## What everybody agrees on

### The asset hierarchy, which this app does not have

Every CMMS organises equipment as a tree: site, then system, then asset, then
component, with explicit parent and child. [Fiix][fiix], [Accelix][accelix] and
[Maintainly][maintainly] all describe the same shape, and the field list is
remarkably consistent: asset tag, name, **parent asset**, type, manufacturer,
model number, serial number, location.

**This app has a flat list.** `machine` has a model, a serial, a location and a
vessel, and no parent. The winemaker's own example is the one that hurts:
*"tractor and tractor equipment"*. A mower and a sprayer are not independent
machines that happen to be near a tractor, and [LookOver][lookover] sells
precisely that connection, tracking "implement maintenance alongside the tractor
that powers it" with reminders like sharpen the mower blades every 25 hours of
mowing.

**What it means here.** A nullable `parent_id` on `machine` is a small migration
and would let an implement hang off the tractor it is pulled by. It is the
cheapest thing in this document and the one most clearly asked for by the example
he gave when describing the module. Worth doing before anything is entered,
because reparenting later means editing rows a person has already looked at.

### Make, model, serial, and a rule for what to bother recording

The identity triple is universal. More useful is [Maintainly's][maintainly] rule
of thumb for deciding what belongs in the system at all: **the existence of a
serial number is a good indicator that the equipment should be tracked.**

That is a better answer than anything in this repository for the question the
winemaker actually asked, which was where the boundary of "machinery" sits. It
puts the press, the tractor, the implements and the sorting line in, and leaves
shovels out, without anybody having to argue about it.

**What it means here.** Nothing to build. It is a sentence worth putting on the
add-a-machine screen, where it would answer the question at the moment somebody
is asking it.

### Usage meters, which are the foundation of everything they schedule

Farm maintenance software is organised around hours. [MaintainX][maintainx],
[Farmbrite][farmbrite] and [LookOver][lookover] all schedule on a meter rather
than a calendar: engine hours, acres, cycles. The reminders quoted in their
marketing are all of the form "every 25 hours" or "at the start of each season".

**This app has no meter and no schedule**, deliberately: S-91 records that the
winemaker asked for lineage including maintenance rather than a maintenance
planner, and that a due date nobody set produces a screen full of red that people
learn to ignore.

**What it means here.** The reasoning in S-91 still holds for *reminders*, and it
does not hold for *meters*. An hour reading is an observation, like a Brix
reading: somebody looked at a gauge and wrote down a number. Recording hours
would cost one kind of `machine_work` entry, would immediately answer "how many
hours was it on when that failed", and would leave scheduling a separate decision
made later with evidence. Meters first, reminders only if the meters get used.

## What almost nobody does, and this app does

### Deriving what a machine is from what was done to it

The nearest thing in the industry is configuration management, and the vocabulary
is instructive. [CMstat][cmstat] describes tracking the "As-X" configurations
across a lifetime, as-procured, as-installed, as-maintained, as-modified, and
calls this **"one of the most challenging tasks in asset-oriented configuration
management"**. [AssetWatch][assetwatch] defines configuration as the arrangement
and specification of an asset's components, and says the point of tracking
changes is to support troubleshooting.

But the mechanism they recommend is to **update the record**. Retrofit guidance
from [MCC Panels][mcc] is explicit: after a modification, "CMMS/EAM records should
be updated so spares and service intervals match the new equipment", alongside
retaining evidence of the original and modified design.

**This app derives instead.** `machine_spec` reads the model's specification and
applies every modification over the top, so the press reads single phase until
the VFD install is recorded and three phase after, and no field is ever edited.
The industry's own literature says the hard part is keeping the as-maintained
configuration honest over a long life, which is exactly the failure that
derivation cannot have.

**What it means here.** Keep it, and know that it is unusual rather than
obviously right. The cost is that a specification can only change through a dated
entry, which is more typing at the moment of the change and less lying afterwards.
The retrofit guidance has one thing worth stealing directly: keep the evidence.
Torque values, test results, serial numbers of the parts fitted, commissioning
photographs. Photographs already attach to a machine, because `0101` made the
subject registry general, and nothing has used that yet.

## The bridge the winemaker asked about, which is half built already

He asked about "the shop + inventory". In every CMMS these are one system, and
the join is specific and always the same:

**Parts are linked to assets and consumed by work orders.** [eWorkOrders][ework]
describes the mechanic logging parts used on a work order and the quantity on
hand decrementing automatically, with no separate storeroom transaction.
[Oxmaint][oxmaint] adds the reorder side: consumption history from closed work
orders drives reorder alerts, with the standard formula reorder point = average
daily usage times lead time, plus safety stock. The claimed payoff everywhere is
cost-per-asset: what this machine has cost to keep running.

**This repository already has most of the inventory half, and it is older than
the shop.** `0046` built `supply` with a unit, a reorder level and a supplier,
`supply_movement` with kinds, and `shopping_item`. Two things in it are striking
now:

- The movement kinds are `received`, `used`, `discarded`, **`broken`**,
  **`repaired`**, `counted`. Two of those six are maintenance vocabulary. The
  inventory module was written expecting exactly this connection.
- `supply_movement.caused_by` is a foreign key into `event`, which is how a
  movement says what consumed it.

**And the shop cannot use it.** `machine_work` is its own table, not an event, so
a repair has no `event.id` for a movement to point at. The bridge that `0046`
anticipated cannot be built without either machine work writing an event, or
`caused_by` widening to the subject registry the way notes and attachments did.

**What it means here.** This is the most valuable finding in the document,
because it is a connection the repository already half made and then lost. Two
honest ways forward, and the choice is a real one:

1. **A machine work entry writes an event.** Then `caused_by` works unchanged,
   the work appears in the same history as everything else, and the cost is that
   the shop starts depending on the event table's rules.
2. **`caused_by` becomes a subject reference.** Wider, matches how `note` and
   `attachment` already point at anything, and costs a migration touching a table
   with movements in it.

Neither is urgent while `supply` has one row and `supply_movement` has none.

## Where a winery would otherwise buy this

[vintrace][vintrace], [Vinsight][vinsight] and [Ekos][ekos] all cover dry goods
and additives alongside bulk and packaged wine, which is the same inventory the
`0046` tables were built for. None of them do equipment maintenance: a winery
running vintrace and needing to track the tractor buys a CMMS as well. The
combination the winemaker is describing, one system where the press is both the
thing that makes wine and the thing that needs a hydraulic filter, is not
something the winery software vendors sell.

That is a finding worth sitting with. It is either an opportunity or a warning,
and this document cannot tell which.

## The trellis idea, confirmed from an unexpected direction

He described the machine record as *"a trellis for AI mechanic help and
electrical help"*. The industry arrived at the same place in 2026 and states the
precondition more bluntly than he did.

The pattern is retrieval over the manuals plus the maintenance history:
[Fabrico][fabrico] describes an assistant sitting on top of the CMMS, the logs
and the PDF manual library, answering from those documents rather than from
general knowledge. The number they all quote is that technicians lose up to a
fifth of the day looking for information, and [F7i][f7i] puts diagnostic time at
roughly half of downtime: the time spent working out what is wrong, not fixing
it.

The warning is the useful part, and it is the same sentence in several places:
**you cannot put an assistant on top of a paper-based maintenance department; the
structured record has to exist first.**

**What it means here.** The order of work he chose was right, and for a reason he
stated before anyone else did: the contract is the trellis, and the machine
history is what it is a trellis *over*. It also says what makes the record worth
having later, which is not the tidy fields. It is the quirks, the failures, and
the departures from stock, because those are the things a manual cannot tell an
assistant and a person would otherwise have to remember.

## What this document recommends, in order

1. **A parent on `machine`,** so an implement hangs off its tractor. Cheapest,
   most clearly asked for, and worth doing before data exists.
2. **Hours as a kind of work entry.** An observation, not a schedule. Everything
   anybody might later want to schedule depends on having them.
3. **The serial-number rule on the add-a-machine screen,** as one sentence.
4. **Decide the `caused_by` question** before `supply_movement` has rows in it,
   not after.
5. **Nothing about reminders,** until the meters have been used for a season and
   there is evidence about what anybody actually wants reminding of.

## Sources

[fiix]: https://fiixsoftware.com/blog/how-to-set-up-asset-hierarchy-for-maintenance/
[accelix]: https://www.accelix.com/understanding-hierarchical-structures-in-cmms/
[maintainly]: https://maintainly.com/articles/how-to-determine-what-equipment-should-be-tracked-when-setting-up-an-asset-hierarchy
[lookover]: https://lookover.app/farm-equipment-maintenance-app/
[maintainx]: https://www.getmaintainx.com/industries/agriculture-and-farm-maintenance-software
[farmbrite]: https://www.farmbrite.com/resource-management
[cmstat]: https://cmstat.com/cmsights-news-posts/asset-lifecycle-configuration-management
[assetwatch]: https://www.assetwatch.com/glossary/configuration
[mcc]: https://mccpanels.com/knowledge/panel-retrofit-modernization
[ework]: https://eworkorders.com/cmms-spare-parts-inventory/
[oxmaint]: https://oxmaint.com/article/spare-parts-inventory-management-cmms
[vintrace]: https://www.encompasstech.com/vintrace/wine-production-software
[vinsight]: https://www.vinsight.net/
[ekos]: https://www.guideflow.com/blog/winery-software
[fabrico]: https://www.fabrico.io/blog/ai-maintenance-assistant-software-guide-2026/
[f7i]: https://f7i.ai/blog/beyond-the-cmms-how-maintenance-assistants-ai-industrial-technology-is-redefining-reliability-in-2026

- Asset hierarchy and the field list: [Fiix][fiix], [Accelix][accelix],
  [Maintainly][maintainly]
- What to bother tracking: [Maintainly][maintainly]
- Ag equipment and meter-based scheduling: [LookOver][lookover],
  [MaintainX][maintainx], [Farmbrite][farmbrite]
- Configuration and as-built tracking: [CMstat][cmstat], [AssetWatch][assetwatch],
  [MCC Panels][mcc]
- Parts, work orders and reorder points: [eWorkOrders][ework], [Oxmaint][oxmaint]
- Winery inventory: [vintrace][vintrace], [Vinsight][vinsight], [Ekos][ekos]
- AI maintenance assistants: [Fabrico][fabrico], [F7i][f7i]
