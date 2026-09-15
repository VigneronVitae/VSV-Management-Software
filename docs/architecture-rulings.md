---
Type: ruling
Version: 2.1
Purpose: "Records every architectural decision governing the decomposition of this system into installable modules, with the reasoning, the falsifier, and the condition under which each ruling would be wrong."
Depends on: [packages/cellar/docs/spec.md, docs/methodology-lineage.md]
Depended on by: [docs/findings-ledger.md, docs/status-ledger.md, docs/session-reports/modularization-progress.md, supabase/migrations/0023_subject_resolver.sql, supabase/migrations/0024_task_board_via_registry.sql, supabase/migrations/0026_subject_type_registry.sql, supabase/migrations/0027_term_kind_registry.sql, scripts/status.sh, docs/practice-mode.md, docs/review/2026-09-15-what-other-apps-do.md]
---

# Architecture Rulings

**Version 2.1.** Versioning follows the rule below at the end of this document.

This system is one winery's production tracker and is intended to become a set of
modules a different operation can install a subset of. A farm with no winery installs
core and inventory. A winery that buys all its fruit installs no vineyard module. That
is a packaging requirement, not a deployment topology, and every ruling below follows
from it.

Each ruling states the decision, what it costs, what would show it wrong, and whether
it is settled or provisional. A ruling with no falsifier is a preference and should be
marked as one.

Nothing here is built. This document precedes the code so that the code can be checked
against something.

---

## Status

Nothing here is built. This document precedes the code so the code can be checked against
something. No ruling has been exercised by an install, which means every one of them is
evidence about intent rather than evidence about what works, and the falsifiers are the part
to watch.

Reversals are marked in place rather than removed. A ruling document that hides its own
revisions is worth less than one that carries them, and the revision is usually the more
informative half.

---

## A. Modules and dependency

**AR-A1. Decomposition is for packaging, not deployment. Settled.**
*Status:* ruled
One Postgres, one schema per module, one client per app. Separate databases would make
every cross-module write distributed with no rollback and would buy nothing a schema
boundary does not already provide. `create_vessel_with_wine` spans three candidate
modules and must remain a single transaction.
*Wrong if:* a consumer genuinely requires an independent deployment, for example a
tasting room point of sale that must operate while the winery database is unreachable.
That is an offline-client problem before it is a database-topology problem, and should
be solved as one.

**AR-A2. Candidate module assignment. Survived the survey, with one correction.**
*Status:* ruled
The A-1 catalog survey found all eight crossing foreign keys pointing the correct direction
and no cycle among the groupings. One declarative contradiction: `task_board`, addressed at
AR-E6. Three runtime-only contradictions: `subject_type`, `term_kind`, and five spanning
function bodies, addressed at AR-E7 and AR-B8.
*The result that matters:* 123 edges exist and 86 are declarative. The remaining 37 are
invisible to the catalog and are discovered by calling a function. The design was mostly
right; Postgres enforces less of it than the design assumed. That is an enforcement gap, not
an architecture gap, and AR-I4 is what closes it.

| Module | Holds | Hard depends on |
|---|---|---|
| core | party, app_user, location, term, event, task, task_claim_log, template, template_step, lineage, code resolution, provenance, postings, interlocks, contract registry | nothing |
| inventory | item, sighting, stock, consumption, maintenance schedule and history | core |
| winemaking | node, placement, vessel extension, transformation operations | core, inventory |
| vineyard | block, phenology, spray records | core, inventory |
| tasting room | retail extension, sales | core, inventory |
| marketing | listings, channels | core |
| finance | reporting over postings | core |

**AR-A3. Dependency runs one way and is declared. Settled.**
*Status:* ruled
A module may reference a module it declares a hard dependency on. Never the reverse,
never sideways, never undeclared. The hard-dependency graph is acyclic.
*Wrong if:* never. This is the property that makes uninstall real, and a single
wrong-way foreign key removes it.

**AR-A4. Three kinds of edge, and only one constrains uninstall. Settled.**
*Status:* ruled
A *hard dependency* is a real schema reference; it constrains install order and blocks
uninstall. A *provision* publishes rows conforming to a named contract. A *consumption*
reads a contract and must tolerate zero providers. Provisions and consumptions are not
dependencies. Marketing consuming `marketable@1` does not depend on winemaking in any
sense that should block anything.
*Wrong if:* a consumption is found that cannot function with zero providers, which would
mean it was a hard dependency misfiled.

**AR-A5. A module is a unit of installation. A contract is a unit of substitution. Settled.**
*Status:* ruled
These are not the same cut and conflating them produces modules that are really
contracts. Inventory is one module offering two contracts.

---

## B. The contract register

**AR-B1. Core holds a registry, not an enumeration. Settled.**
*Status:* ruled
Core does not define the set of contracts. It holds a registry that modules write to.
Adding a cidery or a hop farm is a manifest and a view, never a core migration.
*Wrong if:* the registry needs core to understand a contract's semantics in order to
serve it. It must not.

**AR-B2. A contract is a name, a version, and a typed column set. Settled.**
*Status:* ruled
A declaration is not a contract. If each module declares its own shape, a consumer
receives N shapes and the coupling removed from the foreign-key graph reappears inside
the consumer. The contract exists independently of both sides and the manifest
references it rather than defining it inline.

**AR-B3. Contract versions are append-only. Settled.**
*Status:* ruled
Never mutated after first release. Providers may publish several versions. Consumers
pin a version or a range.

**AR-B4. A contract becomes unowned when a second module provides it. Settled.**
*Status:* ruled
Invented by one module, moved into the registry when a second fills it. Winemaking
cannot hold the definition of `marketable` hostage once livestock also fills it.

**AR-B5. A contract admitted to seat one module is provisional and dies unless a second
exercises it. Settled.**
*Status:* ruled
Without this cap the register grows one contract per module, the consumer must
understand all of them, and the decomposition is a naming convention.
*Falsifier for the whole design:* if contract count rises roughly one per module as
modules arrive, this failed. If it flattens while modules keep arriving, the minimum
shared structure is real.

**AR-B6. Four gate checks, run at install, no judgment required. Settled.**
*Status:* ruled
Every required consumption has a compatible provider. The hard-dependency graph is
acyclic. Every claimed contract version exists in the registry. Every provided view's
columns match its declaration. All four run against the catalogs in seconds.
Anything a machine can check with no judgment belongs in this floor. Nothing else does.
Whether a module's `marketable` rows are worth marketing is not checkable and is not
checked.

**AR-B7. Missing providers deflate. Settled.**
*Status:* ruled
A consumer with no provider shows nothing. Never an error, never a cached result, never
a guess. Emptiness is read from the absence of providers, never declared.

**AR-B8. A fifth gate check: function bodies resolve within declared dependencies. Settled.**
*Status:* ruled
Postgres does not track function body dependencies. Dropping a module removes only the
functions whose *return types* are tied to dropped relations; every function whose *body*
references them survives in the catalog with a signature and grants, and raises on first
call. Probed: dropping the winemaking tables removed two functions and silently kept nine
broken ones. So a module subset installs, reports success, presents a complete-looking
catalog, and fails on contact. The other four checks are catalog reads and cannot see this.
This one is a static parse of every function body against the module's declared dependency
set.
*Falsifier:* drop a module's tables and call every surviving function. Zero should raise.

**AR-B9. A gate returns three values. Settled.**
*Status:* ruled
Pass, refuse, and cannot-determine. The third is the honest output when a check falls
outside what the checker can decide, and it is not a hedge. Its default is refuse, because
an installer is alone in the room and a guessed yes is the inflationary case. This is the
same category as UNVERIFIED in the review protocol, which is the verdict that has done the
most work in practice.

**AR-B10. Every gate check names the layer that can refuse it. Settled.**
*Status:* ruled
A rule enforced at the wrong layer is a rule that drifts into prose. Four checks are catalog
reads, AR-B8 is a static parse, and PostgREST schema exposure is a deployment step no
migration can perform. The register carries a layer column, and a check with no layer that
can refuse it is not a check.
*Precedent from this tree, in the negative:* the write-admission boundary currently lives in
`supabase/config.toml` while the database does not know about it.

**AR-B11. The install gate returns a bit and a reason code. Settled.**
*Status:* ruled
Not a narrative. A verifier that explains itself richly is one that can be negotiated with
and optimized against. Frozen, read-only, minimal output surface.

---

## C. Extension

**AR-C1. Extension points are contracts with the arrows reversed. Settled.**
*Status:* ruled
A module declares `extends: channel@1`; another declares `fills: channel@1`. Same
registry, same gate checks, same versioning. Marketing never learns what a tasting room
is.

**AR-C2. An extension adds and does not modify. Settled.**
*Status:* ruled
It contributes a channel, a field, a filter, a display block. It does not alter the host
module's existing behaviour, override a default, or reach into the host's schema. Allow
modification and uninstalling an extension changes behaviour nobody knew depended on it,
which is a plugin system with global mutable state wearing a manifest.

**AR-C3. Filters are conjunctive and deflationary. Settled.**
*Status:* ruled
Any registered filter may hide. None may reveal. Absence of the filter module means
nothing is hidden. A filter that could surface a row would be an inflationary null and
is refused.

**AR-C4. Extension ordering is deterministic and explicit. Settled.**
*Status:* ruled
Sort by module name, or let the host carry an ordering table the operator controls.
Never registration order, which is install-history dependent and therefore different on
every farm.

---

## D. Inventory

**AR-D1. Two contracts, one module. Settled.**
*Status:* ruled
An *asset register* answers where is it, one row per physical object. A *stock ledger*
answers how many are left, fungible and depleting. A barrel is an asset. A case of wine
is stock. Different primary questions, different scan behaviour, different work-order
semantics.
*Wrong if:* a class of thing is found that needs both semantics simultaneously rather
than being two things.

**AR-D2. Individual versus pooled is a parameter on the asset contract, not a split. Settled.**
*Status:* ruled
Nobody asks where shovel number three is; they ask how many shovels are in the barn. A
tractor is individually identified, a shovel is pooled. This changes what a sighting
means and what a work order reserves. It correlates loosely with price and is caused by
whether the individuals are distinguishable and whether distinguishing them helps.

**AR-D3. Price is not a contract boundary. Settled.**
*Status:* ruled
A forty dollar shovel and a forty thousand dollar tractor answer the same primary
question. What price drives is an attribute cluster: acquisition cost and date, serial
or VIN, make and model, replacement value. Those become required above a threshold.

**AR-D4. The capitalization and insurance thresholds are devolving parameters. Settled.**
*Status:* ruled
The IRS de minimis safe harbour and an insurer's scheduling floor are both external and
both move. Hardcode either and the schema is wrong on a date nobody chose.

**AR-D5. Insurance and capital status are views, never columns. Settled.**
*Status:* ruled
Store no `is_scheduled` or `is_capital` flag. Derive from cost against the current
threshold. The insurer's form shapes a report and never a table, because it is an
external schema that will change.

**AR-D6. Belongs and last-seen are two facts. Settled.**
*Status:* ruled
`home_location_id` on the item is the static belongs-here. A `sighting` table,
append-only, gives last-seen as a derived read. This also repairs `vessel.location_id`,
which is the one place the current schema knowingly stores a mutable derived value.

**AR-D7. Maintenance is a contract on the asset register, not a submodule. Settled.**
*Status:* ruled
Service intervals are templates, services are events, parts consumed are stock draws,
downtime is an availability predicate. The machinery already exists in the wrong place.

**AR-D8. Winterization is a condition state, not a feature. Settled.**
*Status:* ruled
A template sets it seasonally and an interlock reads it. Same mechanism as maintenance
due, certification held, and pre-harvest interval elapsed.

---

## E. Core mechanisms

**AR-E1. Postings are one mechanism in core. Settled.**
*Status:* ruled
Expenses, revenue, and stock movement are the same event seen from different sides.
Every module posts. Finance reads only postings and depends on no producer.
No payment processing. Linking to external systems is a provider, not a core concern.

**AR-E2. Interlocks are one mechanism in core. Settled.**
*Status:* ruled
A spray pre-harvest interval, a feed withdrawal period, an applicator certification, an
expired permit, a dirty vessel, an overdue service, an unwinterized line. All are a
predicate over state that refuses a dispatch. Any module may register one. Core
evaluates the registered set. A module asks core whether a subject is clear, never asks
another module why.
*Wrong if:* a predicate is found that requires the asking module to understand the
answering module's domain.

**AR-E3. Lineage belongs in core. Settled, and this overturns an earlier assignment.**
*Status:* ruled
A calf has a dam and a sire. A graft has rootstock and scion. Saved seed has a parent
line. A blend has parent lots. Same relation. Lineage moves to core with closure
semantics stripped out.

**AR-E4. Closure is a property of the relation type, not a trigger on the table. Settled.**
*Status:* built, 0013_close_on_empty.sql
Breeding does not close the dam. Topping does not close the topping vessel. Scooping
DAP does not close the bag. Solera never closes anything. The current
`lineage_closes_parent` trigger is wrong rather than incomplete, which is S-3 arriving
from four unrelated directions.

**AR-E5. The polymorphic task subject stays polymorphic, and resolvers are registered. Settled.**
*Status:* built, 0023_subject_resolver.sql
A core table cannot carry a foreign key to a module that may not be installed, so
`subject_type` and `subject_id` are structurally forced rather than sloppy. Each module
registers a resolver so the pointer is checkable at runtime.
*This is a prerequisite for AR-E6, not a sibling.* Reversed in v1, corrected here: with the
registry built first, the scheduling move costs under a day because `task_board`'s `CASE`
becomes a lateral join. Built after, it costs half again as much and has to be redone.

**AR-E6. The scheduling block moves to core and points at a generic subject. Settled.**
*Status:* built, 0031_scheduling_to_core.sql
`template`, `template_step`, `task`, `task_claim_log`, and `event` are generic. Nothing
about them is winemaking. Maintenance, spray scheduling, tasting room opening
checklists, and inventory work orders are then free.
*Was blocked by:* `task_board`, a core view whose `CASE` over `subject_type` named `node`,
`vessel` and `block` declaratively. That single view was why core as drawn could not
install alone. **`0024` removed it** and this entry went on saying it was blocked for four
sessions, because a blocking relationship lived in a document and nothing re-read it. That
is the drift `scripts/status.sh` exists to stop, and it is the reason this ruling sat
available and untouched.

**AR-E7. Core enums that carry module vocabulary become registry rows. Settled.**
*Status:* built, 0026_subject_type_registry.sql and 0027_term_kind_registry.sql
`subject_type` names three higher-module tables. `term_kind` carries inventory and
winemaking vocabulary. Both are core objects holding higher-module knowledge, both are
wrong-way edges under AR-A3, and neither will ever fail to install. `0004` already performed
exactly this migration once, moving the winemaking enums into `term`, which makes this the
same migration twice more rather than a new idea.
*Wrong if:* a value set is genuinely fixed for every possible installer. Few are.

**AR-E8. `is_admin()`, `app_user` and `term` are the empirical core. Settled.**
*Status:* ruled
Measured rather than reasoned: `is_admin()` has in-degree 19, tied with `node` for highest
in the tree, and is called by 17 of 38 policies across 14 of 15 tables. A module installing
without it has seventeen policies that refuse to create. `term` has in-degree 18 and is the
tree's best existing contract. Everything else in core is negotiable.

**AR-E9. Measurements are a contract, not a module. Settled.**
*Status:* ruled
Brix, TA, pH, free SO2, soil tests, somatic cell counts, honey moisture. One contract,
per-domain panels, lab integration as a provider.

**AR-E10. Redaction is row-level. If you cannot see the lot, you do not get the row. Settled.**
*Status:* built, 0028_redaction_is_row_level.sql
Column-level redaction was tried and it contradicts itself. `vessel_state` drew the row
count from rows a viewer could see and the names from columns they could not, so a custom
crush client's home screen said two of three vessels held wine while they could name one.
That is not a bug in the view. Any column-level scheme reproduces a version of it, because
a count and a name drawn from one row under two different rules disagree somewhere, and the
disagreement is itself a disclosure.

The barn argument does not carry. A client standing in the cellar can count barrels, so the
objection runs that hiding a row denies them what they could see by walking in. Physical
presence yields one snapshot for the cost of being there. The view yields a time series for
free, and `node_id` with `current_volume_l` sampled across a season reconstructs another
client's tonnage, their racking cadence and their losses. Those are different things and
only one of them is a barrel.

What this costs, said plainly: a vessel holding wine the viewer may not see now reports as
empty rather than as occupied. That is a falsehood in place of a leak, it is the narrower of
the two errors, and AR-E11 is the thing that removes it.

---

**AR-E11. Availability is a contract; contents are ownership. Settled in principle, unbuilt.**
*Status:* ruled
What a custom crush client legitimately needs from a vessel they do not own is whether it
can take wine. That is a boolean over the exclusivity mechanism and it discloses neither
whose wine is in it nor how much. It is a contract in the AR-B sense: any module that can
hold a thing in a place answers it, and the cellar's answer happens to be
`placement_one_lot_per_vessel`.

Nothing is built for this. The exclusivity mechanism is still sketched and the magnitude
case is unresolved: whether availability should carry remaining capacity, which is a number
about somebody else's wine and therefore the same question again one level down. Building it
before that is settled would ship the trade rather than make it.

---

## F. Origin and composition

**AR-F1. Grapes are not privileged. An origin is derived, not declared. Settled.**
*Status:* ruled
A node with no lineage parents is an origin. That is a property of the graph, not a
stage enum and not a nullable foreign key. `node.block_id` is removed.

**AR-F2. An origin carries a typed source reference. Settled.**
*Status:* ruled
A vineyard block, a purchased fruit lot with a grower, a spirit lot, a botanical lot,
sugar, water. Bought fruit and grown fruit fill the same slot with different providers.

**AR-F3. `block_composition` becomes a projection over general source composition. Settled.**
*Status:* ruled
Composition by block is one question. By supplier, by input type, by origin lot are
others. A vermouth answers without anything special happening.

**AR-F4. An unattributed origin is reported, never dropped. Settled.**
*Status:* ruled
The current function silently omits bins with no block and returns a short total. The
replacement returns an explicit unattributed share. Deflationary and visible.

**AR-F5. Removing `block_id` is what makes vineyard optional. Settled.**
*Status:* ruled
If `block` lives in vineyard and winemaking must not depend on vineyard, the column is a
wrong-way edge. The change that makes vermouth work is the change that makes vineyard
uninstallable, and both fix the puttonyos and the fortifying spirit.
*Falsifier:* after removal, winemaking installs with no vineyard module and the
assertion suite passes. If it does not, the coupling was deeper than one column.

**AR-F6. Lineage fractions carry a unit per edge. Settled.**
*Status:* ruled
Two kilos of botanicals into twenty litres of spirit. A puttony is a 25kg basket.
Fortifying spirit is litres at a proof. Composition either converts or refuses. It does
not silently normalize over what it happened to find.

**AR-F7. Quantity derives from an event series. Settled.**
*Status:* ruled
Appassimento, angel's share, ullage, disgorgement loss. Quantity is currently a stored
scalar on `node` and is the column that escaped derived-over-stored.

**AR-F8. Vintage derives from lineage. Settled.**
*Status:* ruled
Stored only on origins. A non-vintage cuvée and a solera have a vintage composition
rather than a vintage.

**AR-F9. Regulated composition carries a named convention and a basis. Settled.**
*Status:* ruled
Volume does not conserve and mass does not survive fermentation, so composition above
the origin is bookkeeping rather than physics. TTB thresholds for varietal, appellation,
and vintage claims are conventions computed a specific way. The label-facing answer is
the convention, not the truth. Generalizing to typed sources preserves this. Generalizing
to an untyped bag of parents loses it.

---

## G. Depth and providers

**AR-G1. A producer module deepens a slot rather than sending data. Settled.**
*Status:* ruled
Vineyard fills `fruit_source@1` and adds resolution behind it. Winemaking never learns
what a rootstock is. Same pattern for livestock deepening a carcass lot, orchard a cider
fruit lot, apiary a honey lot.

**AR-G2. A consumer renders an unresolved source. Settled.**
*Status:* ruled
A name and nothing else. Never an error, never a blank. Direction-of-error applied to
depth rather than to presence.

**AR-G3. A source contract must be shallow enough to fill by hand. Settled.**
*Status:* ruled
Test: can someone who bought two bins from a neighbour with a handshake fill it? If not,
the contract is a vineyard module in disguise and every non-vineyard install will fake
it.

---

## H. Transformation

**AR-H1. A style is a template, not a type. Settled.**
*Status:* ruled
The system knows fortification, secondary fermentation, fractional draw, maceration,
pressing, addition. Port is a named sequence of those with parameters. No `wine_style`
enum ever ships. If the schema learns the word retsina, something has gone wrong.

**AR-H2. Decisions are parameters on operations. Settled.**
*Status:* ruled
Whole cluster fraction, press cut points, yeast or ambient, temperature regime, SO2
timing, vessel choice, when you stopped. The ones worth capturing are those that change
the outcome and are not recoverable afterward.

**AR-H3. Intent is the third member of the provenance set. Settled.**
*Status:* ruled
`provenance` distinguishes observed from inferred. A template step is intent. The gap
between the template saying two bar and the event saying three is a fact about the
vintage.

**AR-H4. Cider and vermouth are the falsifiers, and vermouth is the real one. Settled.**
*Status:* ruled
Cider should cost a term vocabulary and three operations. Vermouth exercises AR-F6 on
every bottle. If either needs tables of its own, winemaking was renamed rather than
decomposed.

---

## I. Migrations and packaging

**AR-I1. Per-module migration numbering starts with the next module's first file. Settled.**
*Status:* ruled
Retrofitting a numbering scheme after two modules have diverged is worse than adopting
it cold.

**AR-I2. A `public` facade is optional and temporary if used at all. Settled.**
*Status:* ruled
The client has twelve `.from` calls across seven tables and four RPCs, all through
`kernel.ts`. That is an afternoon, not a compatibility problem. The real constraint is
PostgREST schema exposure, which is configuration.

**AR-I3. Cross-module reads are views. The interface stays PostgREST. Settled.**
*Status:* ruled
A contract is a view, the union over providers is a view, and a consumer reads it with the
client it already has. Gate checks are catalog reads plus one parse. A service layer would
buy somewhere to host the resolver registry and would cost an authorization layer
duplicating RLS, a deployment story that does not exist, and transactional writes across
modules. At ten users that trade is bad.
This is worth ruling explicitly because the manifest and the registry will start to feel like
application logic and invite a gateway. They are tables and a parse step.
*The one real cost:* PostgREST schema exposure is configuration outside any migration, which
no test currently covers. See AR-B10.

**AR-I4. Enforcement is a build step or it is a hope. Settled, and this is the survey's conclusion.**
*Status:* ruled
A rule that runs in CI is a rule. A rule in a document is an intention. This tree has
neither: `doctor` is a stub that cannot pass, `bun run test` does not exist, there is no
`.github/`, and the twenty-eight assertions run only when someone remembers. Thirty-seven of
123 edges are enforceable by nothing else.
A decomposition whose boundaries hold only by careful reading decays, and seven reviews
demonstrate what careful reading misses.
*Order:* `scripts/verify.sh` first, since it is an hour and catches the header graph, the
ledger cross-references and the style rule. `doctor` before intake, since orphans accumulate
before anything looks for them. CI last.

**AR-I5. Errors carry stable codes, not strings. Settled.**
*Status:* ruled
A consumer reading a union must distinguish no-providers from provider-failed from
not-authorized. The client currently surfaces a thrown error string on one screen.

**AR-I6. A manifest is structurally invalid without its contract versions. Settled.**
*Status:* ruled
Rejected by the shape before any checker runs, rather than by a check that could be skipped.

**AR-I7. Coliving is an acceptance test, not a roadmap item. Settled.**
*Status:* ruled
If core plus scheduling plus postings installs with no farm module and runs chores and
shared expenses, the decomposition is real. Keeping it as a test rather than a product
is what stops it acquiring an undeclared dependency.

---

## J. Distribution

**AR-J1. Reference for the invariant, copy for the adaptation. Settled.**
*Status:* ruled
What must be identical across every install ships as a pinned reference to a signed version,
so divergence is a hash mismatch. What must be locally owned ships as a copy, so an operator
can modify or reject it without forking anything. The core schema, the contract registry and
the gate checks are pinned. Templates, term vocabularies and policy defaults are copied.
This answers how a hop farm gets the fixed floor and still owns its own vocabulary.
*Enforcement:* the divergence check is a build step, per AR-I4. A modified core fails to build
rather than being argued about.

**AR-J2. Intent is stated before action, and corrections are the signal. Settled.**
*Status:* ruled
A resolver states what it inferred the requirement to be and the operator confirms or
corrects before anything is dispatched. Nearly free for a work-order resolver, and the
corrections are the data worth having, because they say the requirement tags are wrong.

---

## Open questions

**AR-Q1. Custody separated from ownership.**
*Status:* open question
A node has an owner and a custodian and they can differ. This makes tolling, co-packing,
boarding, and shared equipment the same module, and it decides whose name is on a TTB
filing when a client ferments at your facility. Not yet ruled because it touches
`node.owner_id`, which `0003` already shipped.

**AR-Q2. Which policy module was meant.**
*Status:* open question
Governance in the constitutional-kernel sense, or regulatory compliance. Different
modules, and only one is interesting.

**AR-Q3. Distribution scope.**
*Status:* open question
Wholesale allocation and shipping compliance, or DTC fulfilment, or both. The compliance
half pulls in state-by-state rules and is the heaviest item on the list.

**AR-Q4. Template confidentiality.**
*Status:* open question
A custom crush client's botanical formula is a `template` with `template_step` rows.
`template` has no owner column and its read policy is the blanket `using (true)` from
`0002`. This is a migration, not a policy edit, and it blocks handing the system to a
client. Belongs in `0006`.

**AR-Q7. Whether the contract register needs a hard cap as well as AR-B5.**
*Status:* open question
AR-B5 kills a contract that only ever seats one module. It does not cap the rate of admission.
A register that grows one contract per module, each genuinely exercised by two, still ends as
a structure whose navigability requires a cross-reference matrix. Whether the provisional
rule is sufficient or whether admission needs a per-round cap is unresolved, and the honest
answer is that it should be instrumented before it is decided: contract count against module
count, checked on every module landing.

**AR-Q8. Whether an interface is a periphery over a read and write contract.**
*Status:* built, 0057_the_contract.sql. The falsifier is run and not yet answered.
*Raised by the winemaker, 2026-09-15, from a crush pad, mid press.*

Four ways of recording a press shipped that day: say what came off, read the receiving
tank and let the kernel subtract, stay in a cut as a mode, or keep a log. His question on
seeing them: "should the UI/UX thing just be different contracts? So that might be a thing,
for like everything." Then, sharpening it: "some people might like text based UI/UXs, some
people might want interactive/visual, some people audio, etc. But UI/UX can just be a
contract for writing and reading", citing his own EpiStack and Knowledge Game.

**The sharpened version is a different and much better question, and it dissolves the
objection this entry first recorded.** The first draft of AR-Q8 argued that two of the four
ways would not fit a contract, because staying in a cut holds mode state between entries
and keeping a log renders history inline, and neither is a field list. That objection only
works if a contract is a description of a form. If a contract is what may be read, what may
be written, and what is refused, then mode state and history rendering are periphery
concerns and the contract is untouched by either. The objection was to a weaker idea than
the one being proposed.

**The borrowed shape is specific.** Knowledge Game holds the client unprivileged: reading
and writing cross a strict `periphery -> api -> kernel` boundary, and its falsifier is that
a minimal independent client, built in CI from the vendored public api alone, reproduces
every capability. EpiStack separates functions any installation must fill from contracts
chosen by whoever holds the context. Applied here: recording a press is a function every
winery must fill; asking for an increment or asking for a tank level is a contract this
winery chose, and a text, visual, audio or conversational periphery is another.

**It relocates a boundary this repository has already drawn, in the wrong place.**
`skins.ts` says a skin may change presentation and nothing else, because "the screens in
walk.ts decide what a person is asked and in what order, because that order is the
schema's, not a matter of taste". The four ways of pressing falsify that sentence. Read the
tank and say what came off ask different questions, in a different order, and both are
correct records of the same event. The line is not between styling and structure. It is
between the contract and the periphery, and `skins.ts` drew it one level too low.

**Half of it is built and unnamed.** `viewer_scope` answers what the caller is rather than
letting the client infer it. `writable_columns` answers which columns this caller may
write, because hardcoding them was ruled R-4. `terms_for_vessel_field` answers which
vocabulary a field may offer. `subject_resolver` answers what kinds of thing exist.
`hideable_fields` answers what may be redacted. That habit, which CLAUDE.md enforces as
"a client may not encode a business rule", **is** the contract. What is missing is that it
is discovered by reading `kernel.ts` rather than declared anywhere a second periphery could
read.

**One piece of evidence that the framing fits.** Every refusal in this kernel is a sentence
written for a person: "that bin already holds other fruit; empty it before filling it
again", "a reading below what the vessel holds is not more wine arriving". Those were
written for banners and they are exactly what a conversational or audio periphery needs as
its output surface. A kernel whose refusals are sentences is a kernel that was already
being written for more than one modality without anybody saying so.

*Built 2026-09-15, same day, on his instruction.* `0057` declares what a periphery may read,
what it may write and what each write asks for, as three registries with a `contract()`
function returning all of it in one call. `apps/text` is the second periphery: it imports
nothing from `cellar`, names no table, view, function or column, and renders its entire
interface from `contract()` at runtime.

**What the declaration found, on its first day, is the argument for it.** Four things, none
of which any person had noticed. `cellar.open_picks` named a relation that did not exist,
because what counts as an open pick was three filters typed into `kernel.ts` (0058).
`pick_weighing` had no column naming the pick it was of, because the screen that reads it
already knew (0059). The reverse check listed twenty nine callable functions the contract
had never heard of, eleven sessions of drift nobody had a way to see (0060). And two
capabilities declared from memory rather than from the catalog had wrong parameter names,
which is the check catching the person who wrote the check (0061).

*Still open, and this is what `built` does not mean.* **The falsifier has not been answered.**
`apps/text` typechecks, lints, and starts; it has not been driven end to end against a real
login by its author, because that is the winemaker's account and not mine to use. Until
somebody records a press through it, this entry is a claim with an experiment attached
rather than a finding. The specific thing to watch is whether the person driving it ever
has to go and read a screen to know what to do next, which is S-72's gap: the contract
declares shape and says nothing about sequence.

*What it would cost to be wrong in each direction.* Building it now, on one module's worth
of evidence, is the guess-dressed-as-foresight that CLAUDE.md forbids and that C-4 is the
compost entry for. Not building it means every new modality is a rewrite of `walk.ts`, and
`walk.ts` is five thousand lines and growing, which is the cost already being paid. The
cheap move available today is neither: stop adding knowledge to the client that the kernel
could answer, which is a rule this repository already has and does not yet check.

**AR-Q9. Whether the split is practice against real, or private kernel against public.**
*Status:* open question
*Raised by the winemaker, 2026-09-15, while practice mode was being built.*

He asked for somewhere to try things and delete them while still recording real work. That
was being built as a second stack with a switch, and then: "or is the better split more like
a private kernel (debug mode) vs a public kernel (submitting it to the server)?"

**It is a better split, and it is not the same question.** Practice mode answers "I want a
place where nothing counts". A private kernel answers "everything I do is mine until I say
it counts", which is a different and stronger claim. It is also his own architecture again:
Knowledge Game keeps personal data in a local vault, structurally isolated from public
contributions, with the kernel running on the device and contributions crossing into the
public graph through a gate.

**What it would solve that practice mode does not.** Three things at once rather than one.
Trying something and throwing it away becomes the default state of your own device rather
than a mode to be in, which removes the entire failure practice mode is designed against:
there is no wrong mode to be in, because everything starts private and submitting is a
deliberate act. It answers S-47, the offline gap, as a consequence rather than as a second
project. And it is the right shape for several people on several phones at one winery,
which is where this is going.

**What it costs, and this is the part to be honest about.** A private kernel is not a
feature, it is a second implementation of the kernel: the schema running on the device, the
migrations applied there, and a submit protocol between them. Two of the hardest problems in
this repository are already sitting in that protocol and are already filed. S-32 says an
imported event has no author who exists in the receiving database, and `has_an_author`
refuses the row; the spec's §7 says the same thing at more length and calls provenance
across the boundary the hard part. A submit path is that problem, every time somebody
presses a button. Weeks, not hours, and during harvest neither.

**They are not alternatives, which is the useful part.** Even with a private kernel there is
a thing practice mode does that it cannot: rehearse a *submitted* workflow. Once something
has crossed into the public kernel it is append-only there, so "let me see what happens when
I finish this press" still wants a public kernel that does not matter. A private kernel
makes practice mode smaller rather than unnecessary: one stack to rehearse against, instead
of a mode the whole app has to be marked for.

*Resolves when:* somebody wants two people recording at once, or wants to record with no
signal. Either of those makes the private kernel the cheaper answer rather than the more
elegant one, and until one of them is real, practice mode is the honest amount of machinery
for the problem as stated. **The thing that would settle it early** is the submit protocol:
if S-32's authorship question is answered for the import case anyway, the private kernel
stops being weeks and starts being days.

*Recorded while building the other one.* Practice mode shipped the same day because the
winemaker needed somewhere to try things during a harvest, and because a second stack is
twenty minutes where this is a fortnight. That is a cost decision rather than a design one,
and it is written down here so that nobody later reads the second stack as a considered
rejection of this.

### What ships, asked the same evening

"Perhaps the private kernel will be shipped as the actual kernel and practice mode will be
the debug mode? Or should the regular one also ship with both?"

**They are two axes and not a sequence, which is what makes the answer clean.** Private
against public is about *authority*: who has agreed that this is true. Your device holds
what you have said; the server holds what the winery has accepted. Practice against real is
about *consequence*: whether there is wine involved at all. All four quadrants mean
something, which is the test for whether two things are really one axis. Private and real
is a phone in a barn before anybody submits. Public and real is the record. Private and
practice is somebody trying a thing. Public and practice is two people rehearsing a
handover, or training somebody, or testing that a submit does what they think.

**So the private kernel is the kernel, and not a mode.** The app writes to the device
first, always, with no setting for it. "Practice" then stops being somewhere you go and
becomes an ordinary thing that happens: you did some things, you did not submit them, you
deleted them. The per-user practice mode built today is subsumed entirely, and with it goes
its single failure, which is being in the wrong one. There is no wrong one to be in.

**What survives is smaller and it is not a mode.** Public-and-practice still needs a second
server, because rehearsing a *submit* cannot be done on the side that is not submitting, and
training a new hire on a two-person workflow needs two people against one shared thing. But
that is an installation an administrator points at, the way a staging environment is, not a
switch on every phone. It does not need a band on every screen, because somebody signed into
a different winery is not confused about which winery they are in.

*So the answer to "should the regular one ship with both" is no.* Ship the private kernel as
the kernel, ship a rehearsal installation as an administrator's option, and delete
practice-as-a-mode on the day the first of those lands. What was built on 2026-09-15 is
scaffolding with a known end, and this paragraph is the end.

### The risk inverts, and the inverted one is worse

Worth writing down before anybody builds this, because it is the thing that will be missed.

Today's danger is recording a real pick into practice: loud, recoverable, and defended
against with a band on every screen. **A private kernel replaces it with recording a real
pick and never submitting it.** The weight sits on one phone in a barn, nobody else can see
it, the person who recorded it believes they are done, and every screen agrees with them.
That is A13 in a new place and it is worse than the one it replaces, because the failure is
silent and looks exactly like success.

This repository already has the answer to that shape and has used it five times.
`unweighed_bin` exists because T1-4 allows a bin with no weight, which is only safe if the
count of them is somewhere nobody has to go looking for it. `bin_to_return`,
`measurement_to_propagate`, `supply_below_level` and `weighing_without_photo` are the same
move. **An unsubmitted count belongs on the home screen next to the unweighed bins**, and it
should be built in the same commit as the private kernel rather than after somebody loses a
morning's weights. A private kernel without that list is not a smaller version of this
design, it is a worse version of the current one.

### "The diff, essentially"

His word for that list, and it is the better one, because it says what the thing *is*
instead of what it is for.

**A diff is derived, and a queue is stored.** The difference matters here more than it
usually does. A pending-submissions table is a cache of "what has not gone yet", and T0-2
says never store what is derived, and C-3 is the compost entry for the last time this
project cached a derivation. A diff needs no such table: it is what this kernel holds that
the public one does not, computed by asking.

**And computing it is nearly trivial, because of two decisions already made.** Ids are
client-generated uuids, ruled at the top of CLAUDE.md so that an offline write has identity
before the server sees it. Events are append-only, T0-5, and corrections are new events
rather than edits. Together those mean the diff over the part that matters is a set
difference on ids. No timestamps, no vector clocks, no last-writer-wins, and no merge: two
kernels cannot disagree about an event, because neither can change one.

**The mutable columns do not need to travel at all.** `node.quantity`, `node.status`,
`placement.to_at` are recomputed from events by triggers and functions already in the
schema. Ship the events and the receiving kernel arrives at the same numbers by running the
same code. That is the same property `weigh_bins` relies on when it recomputes a pick's
total from its weighings rather than adding to it, and it is why a submit protocol is mostly
an insert in dependency order rather than a reconciliation.

### A correction to the cost above

The paragraph further up says this design "contains S-32's unanswered question about who
authored an event that crossed a boundary". **That is wrong and it made the estimate worse
than it should have been.** S-32 is about an event arriving from *another facility*, whose
author has no account here and never will, which is why `has_an_author` refuses the row. The
private and public kernels of one winery are not that case: they are the same staff, the
same roster, and the author of every event submitted from a phone already has an account on
the server, because that is how they signed in to record it.

So the hard problem in S-32 belongs to import and export across wineries, and not to this.
What is genuinely left is narrower: the order rows must be inserted in, and what discard
means for something already submitted, which is a question about wine rather than about
schemas. A fortnight was the wrong number and it was arrived at by conflating two boundaries
that look alike and are not.

**One more thing falls out.** If submit is "the rows this kernel has that yours does not, in
dependency order", then the export and import work in spec.md §7 is the same mechanism
pointed at a stranger instead of at your own server, with S-32 as the extra thing that is
true only in the stranger case. Building submit gets most of export for free, which is the
opposite of the usual relationship between a sync feature and a migration feature.

**AR-Q10. What runs the kernel on the device.**
*Status:* open question. Measured rather than argued, and the measurement is evidence
rather than a decision: nothing is built on it yet.
*Asked by the winemaker, 2026-09-15: "what could run the kernel on the device?", and
"could we just do the whole thing on the phone not needing postgres?"*

**The second question is the one with a real answer, and the answer is no.** Not because it
cannot be done, but because of what it costs. The kernel is 57 plpgsql functions, 22 sql
functions, 18 triggers, 93 policies and 19 views. Rewriting that in TypeScript is a second
implementation of every rule in the system, which is the exact failure CLAUDE.md's hardest
rule exists to prevent: two implementations of a rule disagree eventually, and the
disagreement is silent. The 456 assertions prove the Postgres one and would prove nothing
about a second one. A device kernel is only worth having if it is *the same kernel*.

**So the question is whether Postgres runs on a phone, and it was measured rather than
argued.** PGlite 0.5.8, Postgres 18.3 compiled to WASM, under 3MB gzipped, persisting to
IndexedDB, in a scratch directory outside the repository:

- plpgsql is present, roles can be created, and `SET ROLE` works, so row level security is
  live rather than inert. That was the thing most likely to disqualify it.
- All 70 migrations apply, with `tests/shim.sql` in front exactly as `scripts/green.sh` uses
  it against a bare Postgres. 57 plpgsql functions, 93 policies, 19 views, 37 tables, and a
  constraint census identical to Postgres 17 with the same shim.
- `contract()` executes.
- **The whole assertion suite completes without raising.**

Two fixes were needed and neither was in the kernel. Both were in the suite, and both are
version couplings nobody knew were there:

1. The constraint census grouped over every `contype` in the catalog. **Postgres 18 records
   NOT NULL constraints in `pg_constraint` and Postgres 17 does not**, so the same schema
   reported `n=181` on one and nothing on the other. It now names the four kinds it means.
2. Twelve handlers caught `foreign_key_violation` for an `ON DELETE RESTRICT` refusal.
   **Postgres 18 raises those as `restrict_violation`**, which is more precise and which
   those handlers did not catch, so a refusal the suite was asserting escaped as a failure.
   They now catch both.

*Both would have fired the day this winery's server was upgraded to Postgres 18, with no
warning and no connection to whatever change was being made at the time.* That is worth more
than the WASM result: a test suite that silently depends on a major version is a suite that
goes red for a reason nobody can find.

*What is still unmeasured, and must be before this is built.* Photographs: PGlite has no
storage API, so the bucket needs separate handling on the device. Durability: IndexedDB with
a leader-elected single connection across tabs, and the docs do not state what happens to an
in-flight transaction when the leader tab dies. Size on a barn connection, once. And
`auth.uid()`, which the shim provides for tests and which a device kernel needs as something
real, though with one user on one device that is a stub rather than a problem.

*Resolves when:* somebody builds the submit path of AR-Q9 against a PGlite kernel. The
experiment above is the reason to expect that to work rather than a reason to believe it
does.

**AR-Q5. Solera truncation depth.**
*Status:* open question
Perpetual fractional draw has no terminating lineage walk. Composition converges as a
geometric series, so the implementation computes a limit with a stated truncation depth.
That depth is a devolving parameter and is not chosen.

**AR-Q6. Package as vessel.**
*Status:* open question
Méthode traditionnelle ferments in the bottle, so a lot becomes eight thousand vessels.
This is AR-D2's individual-versus-pooled parameter arriving on the winemaking side, and it
also kills the assumption that packaging is terminal.

---

## Versioning

**Major** when a settled ruling reverses, when a section is added or removed, or when the
module list changes. A consumer of this document has to re-read it.

**Minor** when a ruling is added, a falsifier changes, or an open question resolves into a
ruling. Additive; prior rulings still hold.

**Patch** for wording, locators, and cross-references that change nothing about what is ruled.

An open question opening or a status note changing is not a version bump.

Each entry below names what changed and what caused it. A change with no cause recorded is a
preference, and should be marked as one.

---

## Changelog

### 2.1 (2026-09-11)

*Cause: three documents laid claim to the same id shape, and one of them was this one.*

**Renamed, every section id.** `A-1` became `AR-A1`, `J-2` became `AR-J2`, and so on for
all 69 of them. Nothing else changed: no ruling was added, removed, reversed or reworded,
and the falsifiers are untouched. This is a minor rather than a patch bump because ids
are how other documents refer to this one, so a consumer has to re-read even though no
decision moved.

The collision was real and had three claimants. `docs/compost-ledger.md` has used `C-1`
onward since before either of the other two existed. `docs/findings-ledger.md` numbers
its findings `A1` through `E12`, without hyphens, which does not collide. This document
numbered its sections `A-1` through `J-2`, which collides with the compost ledger on
`C-1` through `C-4` directly. `scripts/verify.sh` carried an exemption naming this file,
so that its cross-reference check would not read `C-3` here as a reference to the
compost entry about storing block composition on the node. That exemption is now gone
and the check runs against this document like any other.

Two references to `A-1` are deliberately not renamed. They name the review prompt
`docs/review/prompts/A-1-architectural-commitments.md`, the architectural survey that
caused version 2.0, rather than ruling `AR-A1`. After this rename a bare `A-1` means
the prompt and an `AR-` prefixed id means a ruling, with no overlap.

`verify.sh` now also checks that every `AR-` id referenced anywhere in the tree exists
here. Separating the namespaces stops two documents meaning different things by one
string; checking them stops a reference pointing at nothing. The second is worth having
because the findings ledger already contains one that does: entry A12 cites "E-4's
premise", and `E-4` resolves to nothing in this repository under any reading. It is left
as it stands rather than guessed at, and is recorded in the modularization progress file.

### 2.0 (2026-09-11)

*Cause: the A-1 architectural survey. A Postgres 16 instance built from the five migrations
at `c3eae3c`, the dependency graph derived from the catalog rather than from reading, and
module removal probed directly.*

**Reversed**

- **AR-E5 and AR-E6 swapped.** v1 listed the scheduling move and the resolver registry as
  siblings. The registry is a prerequisite: built first, the scheduling move costs under a
  day because `task_board`'s `CASE` becomes a lateral join. Built second, it costs half again
  and is partly redone.
- **AR-E3, carried forward from v1.** Lineage moved from winemaking to core. A dam and a sire,
  rootstock and scion, and a parent seed line are one relation. Recorded here because v1
  made the reversal silently in its own text.

**Added**

- **AR-B8**, function bodies resolve within declared dependencies. Postgres tracks function
  return types and not function bodies, so dropping the winemaking tables removed two
  functions and silently kept nine broken ones. The other four gate checks are catalog reads
  and structurally cannot see this. This is a static parse.
- **AR-B9**, three-valued gate. Pass, refuse, cannot-determine, defaulting to refuse.
- **AR-B10**, every check names the layer that can refuse it.
- **AR-B11**, the install gate returns a bit and a reason code, not a narrative.
- **AR-E7**, core enums carrying module vocabulary become registry rows. `subject_type` and
  `term_kind` are both core objects holding higher-module knowledge, and `0004` already
  performed this migration once for the winemaking enums.
- **AR-E8**, the empirical core is `is_admin()`, `app_user` and `term`. Measured: `is_admin()`
  has in-degree 19, tied with `node`, called by 17 of 38 policies across 14 of 15 tables.
- **AR-I3**, cross-module reads are views and the interface stays PostgREST.
- **AR-I4**, enforcement is a build step or it is a hope. This is the survey's actual
  conclusion.
- **AR-I5**, errors carry stable codes.
- **AR-I6**, a manifest without contract versions is structurally invalid.
- **Section J**, distribution. AR-J1 pins the invariant and copies the adaptation. AR-J2 states
  intent before action.
- **AR-Q7**, whether the register needs an admission-rate cap as well as AR-B5. To be
  instrumented rather than argued.

**Amended**

- **AR-A2** now carries the measured result instead of my reasoning, and is no longer
  provisional. All eight crossing foreign keys point the right way and there is no cycle. One
  declarative contradiction, `task_board`. Three runtime-only ones.
- **AR-Q4** unchanged in substance and now has a date, since it blocks handing the system to a
  custom crush client.
- Renumbering: old AR-E7 became AR-E9, old AR-I3 became AR-I7.

**The result worth carrying forward.** 123 edges exist and 86 are declarative. The other 37
are invisible to the catalog and are found by calling a function. The design was mostly
right and Postgres enforces less of it than the design assumed. That is an enforcement gap
rather than an architecture gap, which is why AR-I4 exists and why it is the item to act on
first.

### 1.0 (2026-09-11)

*Cause: initial draft, written from an extended design conversation and deliberately ahead of
the survey so the survey had something to contradict.*

Forty-two rulings in nine groups, six open questions. AR-A2 marked provisional as the ruling
most exposed to the dependency graph. Everything else reasoned from the packaging
requirement: a farm with no winery installs core and inventory, a winery that buys all its
fruit installs no vineyard module.
