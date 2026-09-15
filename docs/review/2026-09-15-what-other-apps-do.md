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

The winemaker asked for this half specifically: "make sure to do more research
too, best app UI and UXs". None of it is about wine and all of it is about a
person entering something into a phone.

### Capture speed is the whole game

Drafts is held up as the standard for capture because it "opens immediately to a
blank page, ready for input. There's no navigating to an inbox, no choosing a
project, no friction." The benchmark stated across the productivity writing is
**under three taps from intent to captured**.

*Count them here.* Recording that the fruit looked good, this evening, against
the Pinot Gris: home, Picking, the pick, Notes and photographs, type, Add. Six,
and two of those are choosing where the thing lives. The palette built tonight
takes two off that, and the question left over is whether a note wants a capture
route that does not begin by choosing a subject at all.

### Undo beats confirmation, and friction should be a ladder

The best sentence found all night, from the destructive-actions literature:
**"Design the friction as a ladder, no confirmation, simple confirmation,
explicit-consequence confirmation, type-to-confirm, and place each action on the
rung its real risk earns."** When every destructive action wears the same generic
confirmation, people stop being able to tell the reversible from the
catastrophic.

*This app's ladder is in no order at all.* `db:reset` sits on the top rung,
correctly, behind an environment variable nobody types by accident.
`finish_press` closes a load and is one tap behind a details element. `practice
reset` destroys a whole stack and asks nothing, which is right because nothing
in it is real. Deleting a photograph is administrator-only. Those are four rungs
assigned by whoever happened to be writing at the time rather than by risk, and
they want going through once.

The other half is that **undo beats confirmation wherever the thing is
reversible**, because it keeps the common case fast and taxes only the accident.
An append-only kernel cannot undo, and it already has the right idea under
another name: a correction is a new event, and `weigh_bins` takes `supersedes`.
An undo offered for a few seconds after a weighing, which quietly writes the
superseding event, is that pattern spelled the way this schema spells it.

### One question per screen

The conversational-form literature is blunt about long forms on a phone: one
question per screen, "with the context needed to answer it and nothing else",
rather than "handing someone a clipboard with forty fields". A clipboard is
literally what this app replaced.

*This is the strongest candidate for a fifth press layout and it is not built*,
because four is already more than anybody asked for and a fifth should wait until
he says which of the four he uses. But "how many litres" as an entire screen,
with a numeric pad and nothing else on it, is the press that somebody with one
free hand would want.

### Timelines are for auditing, feeds are for catching up

Worth keeping apart. A timeline exists so that somebody can "reconstruct a
sequence, audit a process, or follow progress over time". A feed exists to
surface what is recent. This app has `node_history` and the day log, which are
one of each, and neither is drawn as either: both are lists.

The lot history is the one that should be a vertical timeline, because its whole
job is reconstructing what happened to a barrel and in what order, and that is
the thing a buyer asks about.

### Numbers

Steppers beat keypads for small adjustments and lose for large ones; the guidance
is to offer both, and to put the unit in the field. **`inputmode` was missing
from every numeric field in this app**, so a phone offered the full keyboard for
a gross weight. Fixed tonight in `ui.ts`, which reaches every number in the
application, and it is the cheapest thing in this document by a distance.

### Sunlight

Field-work guidance: high luminance contrast, no soft greys, and **give somebody
a mode they can choose** rather than guessing from an ambient sensor. A vineyard
at noon was always going to happen to this app and it had no answer. There is now
a Daylight skin: black on white, two-pixel rules, heavier type, and the map fill
turned up from a wash to a solid.


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

**Four of these are built and waiting.** The rest are the argument for what
comes after them.

1. **The cellar map.** Built. Vessels, then Layout: Map. Laid out by room, sized
   by capacity, filled by how full, dashed when empty, heavy border when the wine
   is somebody else's. Nothing positioned by hand, because asking somebody to
   place sixty vessels before they see anything is how a feature goes unused. If
   the layout is wrong the fix is dragging, which is half a day and wants your
   opinion on this first.
2. **Daylight skin.** Built. For a phone in a vineyard at noon.
3. **Go anywhere.** Built, on the home screen. Type three letters and get a
   screen, a vessel by name, or the thing you want to record. Generated from
   `contract()`, so a capability added in a later migration turns up in it
   without anybody remembering to add it.
4. **Numeric keypads everywhere.** Built, and invisible until you try to type a
   weight, at which point it is the difference between recording a number and
   deciding to do it later.
5. **Thumb-first forms.** Not built. One screen, probably the scale, with the
   action at the bottom and 48 pixel targets. The literature is unambiguous and
   the change is mechanical.
6. **A press layout that asks one question per screen.** Not built, deliberately.
   It would be a fifth and you have not said which of the four you use.
7. **Dictation on notes.** Not built. The note layer is prose, the browser has
   the API, and both hands are full at a press.
8. **The friction ladder, gone through once.** Not built. Four destructive
   actions on four rungs nobody chose on purpose.
9. **Work orders**, and only if you have a crew this vintage. The evidence is
   strong and every bit of it comes from wineries with crews.

## Sources

- [InnoVint](https://www.innovint.us/), [Wine Production](https://www.innovint.us/product/wine-production/), [InnoApp](https://www.innovint.us/product/innoapp/), [3D Tank Maps](https://www.innovint.us/product/3d-tank-maps/), [InnoApp announcement](https://www.innovint.us/insight/mobile-wine-production/), [Tank Maps support](https://support.innovint.us/hc/en-us/tank-maps)
- [vintrace](https://www.vintrace.com/), [Setting Up a Tank Map](https://support.vintrace.com/hc/en-us/articles/32303327426964-Setting-Up-a-Tank-Map), [Creating a Work Order](https://support.vintrace.com/hc/en-us/articles/360000812015-Creating-a-Work-Order-Manually), [Union Wine Co, upgrading from pen and paper](https://www.vintrace.com/client-stories/upgrading-from-pen-and-paper-union-wine-co/)
- [InnoVint vs vintrace](https://balanced-business-group.squarespace.com/perspectives/choosing-the-right-winery-management-software-innovint-vs-vintrace)
- [Best practices for mobile field data collection](https://www.fulcrumapp.com/blog/best-practices-for-creating-mobile-apps-for-data-collection/), [Field service mobile UX redesign](https://www.simplileap.com/resources/case-studies/field-service-mobile-ux-redesign), [Offline mobile app design](https://openforge.io/offline-mobile-app-design/), [Designing for field teams](https://medium.com/@mrsikandar08/designing-mobile-apps-for-field-teams-offline-first-ux-and-on-device-intelligence-4194ab9f2279)
- [Best single-purpose apps for getting things done](https://froxi.ai/blog/best-single-purpose-apps-for-getting-things-done-in-2026), [Mobile UX design examples](https://www.eleken.co/blog-posts/mobile-ux-design-examples)
- [SaaS destructive actions and confirmation patterns](https://www.saasui.design/blog/saas-destructive-actions-confirmation-ux-patterns), [Warning message UI](https://blog.logrocket.com/ux-design/double-check-user-actions-confirmation-dialog/), [Managing dangerous actions](https://www.smashingmagazine.com/2024/09/how-manage-dangerous-actions-user-interfaces/)
- [Conversational form design](https://roundpushpin.com/knowledge/conversational-form-design), [Progressive disclosure in mobile UX](https://www.digia.tech/post/progressive-disclosure-mobile-ux/), [Four principles to reduce cognitive load in forms](https://www.nngroup.com/articles/4-principles-reduce-cognitive-load/)
- [Design guidelines for input steppers](https://www.nngroup.com/articles/input-steppers/), [Finger-friendly numerical inputs with inputmode](https://css-tricks.com/finger-friendly-numerical-inputs-with-inputmode/)
- [Timeline UI design](https://www.eleken.co/blog-posts/timeline-ui-design), [Timeline pattern](https://uxpatterns.dev/patterns/data-display/timeline)
- [Designing a mobile UI for bright sunlight](https://www.linkedin.com/advice/3/how-can-you-design-mobile-app-user-t85ue), [Industrial UX: sunlight susceptible screens](https://medium.com/@callumjcoe/industrial-ux-sunlight-susceptible-screens-2e52b1d9706b)
- [How to build a remarkable command palette](https://blog.superhuman.com/how-to-build-a-remarkable-command-palette/), [Command palette pattern](https://uxpatterns.dev/patterns/advanced/command-palette), [Linear design patterns](https://gunpowderlabs.com/2024/12/22/linear-delightful-patterns)
