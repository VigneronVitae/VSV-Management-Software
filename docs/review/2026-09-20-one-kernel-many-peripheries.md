---
Type: review
Purpose: "What systems built for many frontends do, read across every module rather than one, so that the next periphery in any modality is limited by taste rather than by what the contract can express, and so that the cross-module holes are named before somebody builds over them."
Depends on: [docs/architecture-rulings.md, supabase/migrations/0057_the_contract.sql, supabase/migrations/0122_money_that_has_already_moved.sql,
             supabase/migrations/0131_work_is_not_only_done_to_wine.sql,
             supabase/migrations/0132_a_place_is_inside_another_place.sql]
Depended on by: [docs/status-ledger.md]
---

# One kernel, many peripheries: what the contract would have to carry

Researched 2026-09-20 at the winemaker's request, and scoped by him twice while
it was being written. First: "part of the point of this is to build the backend
and an API so that the frontend can be diverse as possible." Then, when the draft
came back about the books alone: "I don't mean that just within the bookkeeping
part, but the entire system. Including probably multiple module and intra module
use."

That is AR-Q8 asked at full size, and it makes this a different document from the
one of 2026-09-15. That one asked what other winery software looks like. This one
asks what our own API would have to say before somebody could build a text, a
voice, a desktop or a wall-mounted periphery over **all six modules at once**,
including the parts where two modules are talking about the same afternoon.

The method is the same throughout: for each thing a mature system does, name what
the kernel must be able to express, then check whether ours expresses it. A
pattern the contract cannot support is not a design decision being deferred. It
is a decision already made, silently, by omission.

## First, the surface being judged

Counted from the registries on 2026-09-20, not from memory:

| module | capabilities | readables | path |
|---|---|---|---|
| cellar | 31 | 31 | `/cellar/` |
| shop | 5 | 7 | `/shop/` |
| vineyard | **0** | 4 | `/vineyard/` |
| books | 1 | 3 | `/books/` |
| inventory | **0** | **0** | none |
| core | 1 | 1 | n/a |

**Thirty-one of the thirty-nine capabilities are the cellar's.** What this repo
calls "the contract" is, numerically, the cellar's contract with four other
modules standing near it. That is not a criticism of the build order, which is
spec.md section 7 and is correct. It is the thing to know before assuming a
second periphery over the whole system is a matter of drawing screens.

**The vineyard has no verbs at all.** Its app ships, it is on the front door, and
the only write it performs is `addNote`, which is `cellar.add_note`. A vineyard
periphery built from `contract()` filtered to its own module would render a
read-only app, correctly, because that is what the registry says exists.

**Inventory has neither**, yet `count_supply` exists and is registered to
`cellar`. So the inventory module's one verb is filed under another module's
name. Nothing is broken by this; it means the registry cannot currently answer
"what can I do with supplies", which is the question a second periphery asks
first.

---

## The closest analogue anybody has built

**Home Assistant is the system to study here**, more than any winery software,
because it solved exactly the problem he is describing and at much larger scale.
One kernel, an ecosystem of unrelated frontends: a drag-and-drop dashboard, voice
assistants, phone apps, terminal clients, wall panels.

The two mechanisms are worth naming precisely.

**An entity registry.** Every controllable thing in the system, from any
integration, appears in one registry that stores metadata about it, described as
"a bridge between the raw state data from integrations and the user-facing entity
presentation". A frontend does not know what a Zigbee bulb is. It reads the
registry, learns there is a thing with a state and some services, and draws it.

**Our `readable` and `capability` registries are the same idea** and `0057` got
there independently. The difference is what the registry carries. Home Assistant
entities carry a device class, a unit, a state type, and which services apply.
Ours carry `relation`, `id_column`, `label_column`, and for a capability a list
of fields. That is enough to list things and write forms, which is why `apps/text`
works, and it is not enough to filter, sort, group, or subscribe.

**Subscription rather than polling.** Every Home Assistant UI element subscribes
to state changes over a WebSocket, reconnects automatically and queues messages
during downtime. Ours is request-response over PostgREST. A wall panel in the
barn showing what is fermenting would have to poll. Supabase has realtime on the
same stack we already run, so this is a thing not turned on rather than a thing
absent, but no periphery can discover it from `contract()`.

*Contract needs:* per-readable field types and filterability; a declared way to
subscribe.
*Contract has:* neither.

## Where the modules touch, and where they do not

The rule in CLAUDE.md is that a module package may import from `core` and never
from a sibling. That rule is about **code**. The interesting question he is
raising is about **data and verbs**, where the picture is different.

Four foreign keys cross module lines in the schema, and all four are honest:

- `node.block_id` : a lot knows which vineyard block it came off.
- `supply_movement.caused_by` : a supply movement knows the cellar event that
  consumed it.
- `glycol_hookup.vessel_id` and `machine.vessel_id` : the shop knows which
  vessel a machine is attached to.

**Nothing points at books.** Not one. A machine repair in the shop cost money. A
supply purchase in inventory cost money. The WWOOF groceries are a cellar-adjacent
fact and a books fact at once. Today those are two records that never meet, and
the only thing joining them is that a person remembers. This is the largest
cross-module hole in the system and it is the one his question surfaces.

It is worth being precise about why it is hard rather than just listing it.
Money arrives from the bank days later, in one line, possibly covering several
things from several modules. So the link is not a foreign key on the bank line:
it is a many-to-many between money that moved and work that was done, discovered
after the fact, and sometimes never. That shape is an attestation, which is
already the shape `line_attestation` has. What it lacks is the ability to point
at a machine, a supply or an event instead of only at a category.

**And that mechanism already exists in this repo.** `subject_resolver` registers
fifteen subject types today; `note` and `attachment` hang on
`(subject_type, subject_id)` and resolve through it. AR-E5 put it there. It is
the cross-module join this system already chose, it works, and books has never
been connected to it in either direction.

*Contract needs:* `bank_line` as a registered subject type, and an attestation
that can name a subject as well as a class.
*Contract has:* the resolver, fully built. The registrations, no.

## Odoo, and the thing we should not copy

Odoo is the other modular system worth looking at, and the lesson is mostly
negative. Modules there extend each other by **inheritance**: a module declares
`_inherit = ['sale.order', 'my.mixin']` and grafts fields and behaviour onto
another module's model. Odoo 19 refactored the framework for "cleaner decoupling
and enhanced module inter-communication", which is what a system says after
inheritance across module lines has become the problem.

That is precisely what CLAUDE.md's import rule forbids, and the rule is right.
The DDD literature reaches the same conclusion by a different road: bounded
contexts integrate through a shared kernel, a customer/supplier relationship, an
anti-corruption layer, or **domain events**, and event-driven integration is the
one it names as giving loose coupling.

**We already have the event.** `event` is append-only, carries an operation from
a registered vocabulary, and has a polymorphic subject. What we do not have is
any module reacting to another module's event, or any way for a periphery to ask
what happened across modules in one call. A day at this winery is one narrative:
fruit came off a block, went into a tank, the press was run, the pressure washer
was fixed, and four hundred dollars left the account. Five modules, one afternoon,
and no readable returns it.

*Contract needs:* a cross-module activity readable, ordered by time, resolving
subjects through the registry that already exists.
*Contract has:* no. Each module's history is readable only within that module.

## What the money apps do, which is the books half

Kept from the first draft because the findings hold, and because three of the
four generalise beyond books.

**A correction becomes a rule.** Monarch offers to make a rule when you change a
category, applying to future transactions or past ones. Actual Budget ships a
rules engine of IF/THEN conditions and actions, writable through its API. Ours is
`merchant_suggestion`, a view over confirmed attestations: honest, because it can
only repeat what a person said, and rigid, because it expresses exactly one rule
shape, *this description string was called that before*. It cannot say "an order
from this supplier above some threshold is a Farm Asset rather than Supplies",
which is the sort of thing the largest unexplained discrepancy in S-102 may turn
out to be.

**This generalises.** A rule is a business rule, and CLAUDE.md says those live in
the kernel. The same argument applies to the cellar: "a barrel topped more than
21 days ago needs topping" is a rule presently living in whoever is looking.

**Splitting one thing across several categories.** Firefly III splits a
withdrawal across several destination accounts. Beancount and hledger treat a
transaction as a list of postings that must balance, and Beancount's author
describes the design as "pessimistic", assuming the user will err and adding
constraints to catch it, which is a sentence that would sit comfortably in this
repo. `line_attestation` has eight columns and none is an amount, so a Costco run
covering four categories must be filed under whichever is largest. That is what
the spreadsheet did and it is why his pivot totals are approximately right.

**Bulk action over a selection.** Lunch Money does shift-click, then a bulk-edit
panel, then one save; its community has built CLI tools and a browser extension
on the same primitives, which is the diversity argument arriving from the field.
`attest_line` takes one line. Confirming 114 rows is 114 round trips over barn
wifi, and a periphery that offered "select all, file as supplies" would be
deciding for itself what happens when the fortieth fails.

**This generalises hardest of all.** `register_bins`, `weigh_bins`,
`move_vessels` and `add_vessels` are already plural, and most of the other
twenty-seven cellar capabilities are singular. Whether a verb takes one thing or
many is currently decided per capability with no stated rule.

**Attention without judgement.** Monarch separates *reviewed* from
*categorised*: swipe right to mark reviewed, swipe left to skip and be asked
again. Here `verified` is one bit and confirming a category is the only way to
mark a thing seen. `0129` made "I looked and cannot name it" sayable;
"I looked, not now" is still not. The same gap exists on the cellar's task board
and on anything else with a queue.

## What generalises, ranked

Every item below is a kernel change, not a screen. That is the finding: not one
interface idea worth stealing from Home Assistant, Odoo, Monarch, Actual, Lunch
Money, Firefly or Beancount turned out to rest on something a client draws.

1. **Register `bank_line` as a subject type.** One migration, no new machinery.
   It gives receipts and notes on a transaction using the storage bucket, the
   policies and the upload code the cellar has had since `0002`, and it is the
   half of his original expenses request that has never been built. Nearly free,
   so it goes first.
2. **Let an attestation name a subject, not only a class.** This is the
   cross-module join. It is what lets a bank line say "this was the pressure
   washer" and a machine say "this is what it has cost", using the resolver
   already in place, without a foreign key from books to every module.
3. **An amount on an attestation.** Constraint-shaped: parts must sum to the
   line, and the kernel refuses when they do not. Real case already in hand.
4. **Declared field types and filters on a readable.** The item that decides
   whether a voice or conversational periphery is buildable at all, because its
   first question is always a filter. Also the item that would let the vineyard
   and inventory registries become useful rather than thin.
5. **A rule object.** Largest behaviour change, most design, clearest argument
   for living in the kernel. Applies to books first and the cellar soon after.
6. **A stated position on plural capabilities**, then batch where it fits.
   Cheap, and it turns 114 taps into one.
7. **A cross-module activity readable**, so one afternoon reads as one story.
8. **Attention without judgement**, and **subscription**. Both real, both fine
   to leave until something asks.

And two that are not on the list but are prerequisites for trusting it:

**Give the vineyard and inventory their own verbs**, or move `count_supply` to
inventory and accept that the vineyard writes through core. Either is fine; the
present state, where the registry misdescribes what exists, is not. A periphery
built from a registry that is wrong is wrong in the same way.

**Run `apps/text` against every module.** AR-Q8's falsifier is that a minimal
independent client built from the vendored public API alone reproduces every
capability. `apps/text` is that client and it has only ever been pointed at the
cellar. Nothing above is trustworthy as a *complete* list until it has been run
across all six, and running it is cheaper than any item on this list.

## Sources

- [Home Assistant, entity developer docs](https://developers.home-assistant.io/docs/core/entity/)
- [Home Assistant, entity registry](https://mantikor.github.io/docs/configuration/entity-registry/)
- [Home Assistant frontend architecture](https://deepwiki.com/home-assistant/frontend)
- [Home Assistant, Lovelace core architecture](https://deepwiki.com/home-assistant/frontend/3.1-lovelace-core-architecture)
- [Odoo modular architecture](https://rootstack.com/en/blog/modular-architecture-odoo-how-it-works-and-why-its-key-successful-implementation)
- [Odoo 19 module architecture deep dive](https://arsalanyasin.com.au/odoo19-module-architecture-deep-dive/)
- [Martin Fowler, bounded context](https://martinfowler.com/bliki/BoundedContext.html)
- [Introduction to bounded context integration](https://www.oreilly.com/library/view/patterns-principles-and/9781118714706/c11.xhtml)
- [Context mapping](https://www.oreilly.com/library/view/what-is-domain-driven/9781492057802/ch04.html)
- [Monarch, reviewing transactions](https://help.monarch.com/hc/en-us/articles/5528707082516-Reviewing-Transactions)
- [Monarch, review on the go and smart split](https://www.monarch.com/blog/review-on-the-go-and-smart-split)
- [Lunch Money, transaction actions](https://support.lunchmoney.app/finances/transactions/transaction-actions)
- [Lunch Money, rules](https://support.lunchmoney.app/setup/rules)
- [Actual Budget, API reference](https://actualbudget.org/docs/api/reference/)
- [Actual Budget, transaction management](https://deepwiki.com/actualbudget/actual/6-transaction-management)
- [Firefly III, transactions](https://docs.firefly-iii.org/explanation/financial-concepts/transactions/)
- [Plain Text Accounting](https://plaintextaccounting.org/)
- [Beancount documentation](https://beancount.github.io/docs/)
- [Plaid, transactions API](https://plaid.com/docs/api/products/transactions/)
- [Expensify, statement matching and reconciliation](https://help.expensify.com/articles/new-expensify/reports-and-expenses/Statement-Matching-and-Reconciliation)
- [Ramp, receipt scanning in expense management](https://ramp.com/blog/receipt-scanning-expense-management)
- [NN/g, using swipe to trigger contextual actions](https://www.nngroup.com/articles/contextual-swipe/)
- [Bulk operations in REST APIs](https://www.mscharhag.com/api-design/bulk-and-batch-operations)
- [Traction Ag, farm accounting](https://tractionag.com/)
