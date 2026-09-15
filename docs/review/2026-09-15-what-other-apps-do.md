---
Type: review
Purpose: "What the two established winery systems do, what the field-work UX literature says, and which of it is worth trying here, so the next interface decision is made against evidence rather than taste."
Depends on: [docs/architecture-rulings.md, packages/cellar/docs/spec.md]
Depended on by: [docs/status-ledger.md]
---

# What other apps do, and which of it is worth stealing

Researched overnight on 2026-09-15 at the winemaker's request: "research other
apps and workflows and stuff, especially trying to find great UI and UXs so I
can try them out tomorrow. Ideally for pretty much the whole thing, like
locations being an actual location with little barrels and vessels in it or
something."

The point of this document is to stop the next interface argument being about
taste. Everything below is either something a shipping product does, or
something the field-work literature measured, and each one ends with what it
would mean here.

## The two that matter

**InnoVint** and **vintrace** are the systems a winery this size would otherwise
buy. Both are cloud, both are mature, and both have decided things that are worth
knowing before deciding them differently.

### What they agree on, which is the interesting part

**The work order is the central object.** Not the lot, not the vessel: the
instruction. A winemaker writes one, a cellar hand takes it, does it, and records
against it. vintrace prints them. InnoVint assigns them to individuals or teams
and lets several run at once. A client story describes the crew preferring
digital work orders partly because they could see *other people's*, which gave
"a holistic understanding of the winemaking process".

**This app has no such object.** It has `task`, built and unused, and it has
`plan_processing` from `0044` which is a plan with no screen. Everything else is
recorded by whoever did it, at the moment they did it. That is a real difference
in philosophy rather than a missing feature: this app is organised around *what
happened*, and theirs are organised around *what was asked for*.

Worth noticing before copying: a work order is most valuable when the person
deciding and the person doing are different people. At Vitae Springs they are
frequently the same person. The value is real when there is a crew and close to
zero when there is not.

**Offline is table stakes and both sell it.** InnoVint's InnoApp downloads the
day's work orders and completes them with no signal, and they call it "industry
first". That is AR-Q9 and AR-Q10 arriving from the market rather than from
EpiStack, and it is the strongest outside evidence that the private kernel is
the right direction rather than an elegant detour.

**The camera replaces typing.** InnoApp's camera is a barrel scanner; vintrace
does barcodes. This app has `vessel_code` and a scan screen already, which is
the same idea, and `0047` made photographs a first class record.

### What they do that this app does not

**Tank maps, which is exactly the winemaker's example.** Both have them.
vintrace does a bird's eye view for "displaying and planning the layout of your
tanks". InnoVint renders both a top-down and a 3D view in the browser, and the
important part is what they overlay: "lot code, date filled, current volume" on
the vessel itself, live. The map is not decoration, it is the vessel list with
position as the organising axis instead of a sort order.

That is the one to try first, and it is built: see the end of this document.

## What the field-work literature says

This is the part that applies whether or not anything above is copied, because
it is about a phone in a barn rather than about wine.

**Touch targets of at least 48 by 48 pixels, with generous spacing**, because
gloves. Measured in contextual inquiry with technicians, alongside glare
readability and unclear sync state as the three complaints.

**Primary actions belong in the bottom two thirds of the screen.** Thumbs reach
there. Top corners are for navigation and things done rarely. One-handed use is
the majority case, not the exception.

*This app currently puts its primary action wherever the form happens to end.*
The scale screen's "Record this weight" is below four fields, which on a phone
is often above the fold and sometimes below it, and nothing about its position
is deliberate.

**Avoid horizontal swipe entirely.** Wet hands, gloves, and a phone held at an
angle make it unreliable. Nothing here uses it, and nothing should start.

**A single tap must not complete something irreversible.** "A task completion
that triggers with a single tap is an accidental completion waiting to happen."
*This app is mostly right here and not everywhere: `finish_press` is one tap
behind a details element, and it closes a load.*

**Offline is a trust problem as much as an interaction problem.** The literature
is blunt: the app should function identically online and offline and the worker
should never think about network state. Not a sync button, not a draft mode.
That is a higher bar than S-47 currently describes and it is the bar to hold
AR-Q9 to.

**Voice, when hands are full.** Listed repeatedly for field work. A winemaker at
a press with both hands occupied is the case. Nothing here does it and the
browser can: it would suit the note layer particularly, since a note is prose
and prose is what dictation is good at.

## From outside the trade

**Command palettes.** Linear and Superhuman put every action one keystroke away
and show the shortcut next to the command so muscle memory forms by itself.
Superhuman treats 50ms as the product.

Mostly this is a desktop pattern and this app is a phone. But there is a version
of it that fits: **the contract already enumerates every capability**, with a
label and a note written for a person. A search box over `contract()` that lets
somebody type "weigh" and get the weighing screen is a command palette that
nobody has to maintain, because it is generated from the same declaration a
second periphery would read. That is the cheapest interesting thing on this list.

**Everything is a block.** Notion's insight is that a page is a list of typed
blocks rather than a document. This app arrived at the same shape from the other
direction last night: a note is untyped, typing it makes it a fact, and a note
can hang off a note. Worth knowing that the pattern has a decade of evidence
behind it.

## What to try tomorrow, in the order I would try it

1. **The cellar map.** Built tonight, behind the layout switcher on the Vessels
   screen. It lays vessels out by location, sizes them by capacity, fills them by
   how full they are, and colours the ones that are not ours. No schema change,
   no positioning to set up. If the auto layout is wrong, the fix is to let you
   drag them, which is half a day and wants your opinion first.
2. **Thumb-first forms.** One screen, probably the scale, rebuilt with the action
   at the bottom and 48px targets. Cheap, and the literature is unambiguous.
3. **A command palette over the contract.** Type three letters, get the screen.
   Cheap because the contract already exists.
4. **Dictation on notes.** The note layer is prose and the browser has the API.
5. **Work orders**, and only if you actually have a crew this vintage. The
   evidence for them is strong and it is evidence from wineries with crews.

## Sources

- [InnoVint](https://www.innovint.us/), [Wine Production](https://www.innovint.us/product/wine-production/), [InnoApp](https://www.innovint.us/product/innoapp/), [3D Tank Maps](https://www.innovint.us/product/3d-tank-maps/), [InnoApp announcement](https://www.innovint.us/insight/mobile-wine-production/), [Tank Maps support](https://support.innovint.us/hc/en-us/tank-maps)
- [vintrace](https://www.vintrace.com/), [Setting Up a Tank Map](https://support.vintrace.com/hc/en-us/articles/32303327426964-Setting-Up-a-Tank-Map), [Creating a Work Order](https://support.vintrace.com/hc/en-us/articles/360000812015-Creating-a-Work-Order-Manually), [Union Wine Co, upgrading from pen and paper](https://www.vintrace.com/client-stories/upgrading-from-pen-and-paper-union-wine-co/)
- [InnoVint vs vintrace](https://balanced-business-group.squarespace.com/perspectives/choosing-the-right-winery-management-software-innovint-vs-vintrace)
- [Best practices for mobile field data collection](https://www.fulcrumapp.com/blog/best-practices-for-creating-mobile-apps-for-data-collection/), [Field service mobile UX redesign](https://www.simplileap.com/resources/case-studies/field-service-mobile-ux-redesign), [Offline mobile app design](https://openforge.io/offline-mobile-app-design/), [Designing for field teams](https://medium.com/@mrsikandar08/designing-mobile-apps-for-field-teams-offline-first-ux-and-on-device-intelligence-4194ab9f2279)
- [How to build a remarkable command palette](https://blog.superhuman.com/how-to-build-a-remarkable-command-palette/), [Command palette pattern](https://uxpatterns.dev/patterns/advanced/command-palette), [Linear design patterns](https://gunpowderlabs.com/2024/12/22/linear-delightful-patterns)
