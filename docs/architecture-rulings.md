---
Type: ruling
Version: 2.0
Purpose: "Records every architectural decision governing the decomposition of this system into installable modules, with the reasoning, the falsifier, and the condition under which each ruling would be wrong."
Depends on: [packages/cellar/docs/spec.md, docs/methodology-lineage.md]
Depended on by: [docs/findings-ledger.md, docs/status-ledger.md]
---

# Architecture Rulings

**Version 2.0.** Versioning follows the rule below at the end of this document.

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

**A-1. Decomposition is for packaging, not deployment. Settled.**
One Postgres, one schema per module, one client per app. Separate databases would make
every cross-module write distributed with no rollback and would buy nothing a schema
boundary does not already provide. `create_vessel_with_wine` spans three candidate
modules and must remain a single transaction.
*Wrong if:* a consumer genuinely requires an independent deployment, for example a
tasting room point of sale that must operate while the winery database is unreachable.
That is an offline-client problem before it is a database-topology problem, and should
be solved as one.

**A-2. Candidate module assignment. Survived the survey, with one correction.**
The A-1 catalog survey found all eight crossing foreign keys pointing the correct direction
and no cycle among the groupings. One declarative contradiction: `task_board`, addressed at
E-6. Three runtime-only contradictions: `subject_type`, `term_kind`, and five spanning
function bodies, addressed at E-7 and B-8.
*The result that matters:* 123 edges exist and 86 are declarative. The remaining 37 are
invisible to the catalog and are discovered by calling a function. The design was mostly
right; Postgres enforces less of it than the design assumed. That is an enforcement gap, not
an architecture gap, and I-4 is what closes it.

| Module | Holds | Hard depends on |
|---|---|---|
| core | party, app_user, location, term, event, task, task_claim_log, template, template_step, lineage, code resolution, provenance, postings, interlocks, contract registry | nothing |
| inventory | item, sighting, stock, consumption, maintenance schedule and history | core |
| winemaking | node, placement, vessel extension, transformation operations | core, inventory |
| vineyard | block, phenology, spray records | core, inventory |
| tasting room | retail extension, sales | core, inventory |
| marketing | listings, channels | core |
| finance | reporting over postings | core |

**A-3. Dependency runs one way and is declared. Settled.**
A module may reference a module it declares a hard dependency on. Never the reverse,
never sideways, never undeclared. The hard-dependency graph is acyclic.
*Wrong if:* never. This is the property that makes uninstall real, and a single
wrong-way foreign key removes it.

**A-4. Three kinds of edge, and only one constrains uninstall. Settled.**
A *hard dependency* is a real schema reference; it constrains install order and blocks
uninstall. A *provision* publishes rows conforming to a named contract. A *consumption*
reads a contract and must tolerate zero providers. Provisions and consumptions are not
dependencies. Marketing consuming `marketable@1` does not depend on winemaking in any
sense that should block anything.
*Wrong if:* a consumption is found that cannot function with zero providers, which would
mean it was a hard dependency misfiled.

**A-5. A module is a unit of installation. A contract is a unit of substitution. Settled.**
These are not the same cut and conflating them produces modules that are really
contracts. Inventory is one module offering two contracts.

---

## B. The contract register

**B-1. Core holds a registry, not an enumeration. Settled.**
Core does not define the set of contracts. It holds a registry that modules write to.
Adding a cidery or a hop farm is a manifest and a view, never a core migration.
*Wrong if:* the registry needs core to understand a contract's semantics in order to
serve it. It must not.

**B-2. A contract is a name, a version, and a typed column set. Settled.**
A declaration is not a contract. If each module declares its own shape, a consumer
receives N shapes and the coupling removed from the foreign-key graph reappears inside
the consumer. The contract exists independently of both sides and the manifest
references it rather than defining it inline.

**B-3. Contract versions are append-only. Settled.**
Never mutated after first release. Providers may publish several versions. Consumers
pin a version or a range.

**B-4. A contract becomes unowned when a second module provides it. Settled.**
Invented by one module, moved into the registry when a second fills it. Winemaking
cannot hold the definition of `marketable` hostage once livestock also fills it.

**B-5. A contract admitted to seat one module is provisional and dies unless a second
exercises it. Settled.**
Without this cap the register grows one contract per module, the consumer must
understand all of them, and the decomposition is a naming convention.
*Falsifier for the whole design:* if contract count rises roughly one per module as
modules arrive, this failed. If it flattens while modules keep arriving, the minimum
shared structure is real.

**B-6. Four gate checks, run at install, no judgment required. Settled.**
Every required consumption has a compatible provider. The hard-dependency graph is
acyclic. Every claimed contract version exists in the registry. Every provided view's
columns match its declaration. All four run against the catalogs in seconds.
Anything a machine can check with no judgment belongs in this floor. Nothing else does.
Whether a module's `marketable` rows are worth marketing is not checkable and is not
checked.

**B-7. Missing providers deflate. Settled.**
A consumer with no provider shows nothing. Never an error, never a cached result, never
a guess. Emptiness is read from the absence of providers, never declared.

**B-8. A fifth gate check: function bodies resolve within declared dependencies. Settled.**
Postgres does not track function body dependencies. Dropping a module removes only the
functions whose *return types* are tied to dropped relations; every function whose *body*
references them survives in the catalog with a signature and grants, and raises on first
call. Probed: dropping the winemaking tables removed two functions and silently kept nine
broken ones. So a module subset installs, reports success, presents a complete-looking
catalog, and fails on contact. The other four checks are catalog reads and cannot see this.
This one is a static parse of every function body against the module's declared dependency
set.
*Falsifier:* drop a module's tables and call every surviving function. Zero should raise.

**B-9. A gate returns three values. Settled.**
Pass, refuse, and cannot-determine. The third is the honest output when a check falls
outside what the checker can decide, and it is not a hedge. Its default is refuse, because
an installer is alone in the room and a guessed yes is the inflationary case. This is the
same category as UNVERIFIED in the review protocol, which is the verdict that has done the
most work in practice.

**B-10. Every gate check names the layer that can refuse it. Settled.**
A rule enforced at the wrong layer is a rule that drifts into prose. Four checks are catalog
reads, B-8 is a static parse, and PostgREST schema exposure is a deployment step no
migration can perform. The register carries a layer column, and a check with no layer that
can refuse it is not a check.
*Precedent from this tree, in the negative:* the write-admission boundary currently lives in
`supabase/config.toml` while the database does not know about it.

**B-11. The install gate returns a bit and a reason code. Settled.**
Not a narrative. A verifier that explains itself richly is one that can be negotiated with
and optimized against. Frozen, read-only, minimal output surface.

---

## C. Extension

**C-1. Extension points are contracts with the arrows reversed. Settled.**
A module declares `extends: channel@1`; another declares `fills: channel@1`. Same
registry, same gate checks, same versioning. Marketing never learns what a tasting room
is.

**C-2. An extension adds and does not modify. Settled.**
It contributes a channel, a field, a filter, a display block. It does not alter the host
module's existing behaviour, override a default, or reach into the host's schema. Allow
modification and uninstalling an extension changes behaviour nobody knew depended on it,
which is a plugin system with global mutable state wearing a manifest.

**C-3. Filters are conjunctive and deflationary. Settled.**
Any registered filter may hide. None may reveal. Absence of the filter module means
nothing is hidden. A filter that could surface a row would be an inflationary null and
is refused.

**C-4. Extension ordering is deterministic and explicit. Settled.**
Sort by module name, or let the host carry an ordering table the operator controls.
Never registration order, which is install-history dependent and therefore different on
every farm.

---

## D. Inventory

**D-1. Two contracts, one module. Settled.**
An *asset register* answers where is it, one row per physical object. A *stock ledger*
answers how many are left, fungible and depleting. A barrel is an asset. A case of wine
is stock. Different primary questions, different scan behaviour, different work-order
semantics.
*Wrong if:* a class of thing is found that needs both semantics simultaneously rather
than being two things.

**D-2. Individual versus pooled is a parameter on the asset contract, not a split. Settled.**
Nobody asks where shovel number three is; they ask how many shovels are in the barn. A
tractor is individually identified, a shovel is pooled. This changes what a sighting
means and what a work order reserves. It correlates loosely with price and is caused by
whether the individuals are distinguishable and whether distinguishing them helps.

**D-3. Price is not a contract boundary. Settled.**
A forty dollar shovel and a forty thousand dollar tractor answer the same primary
question. What price drives is an attribute cluster: acquisition cost and date, serial
or VIN, make and model, replacement value. Those become required above a threshold.

**D-4. The capitalization and insurance thresholds are devolving parameters. Settled.**
The IRS de minimis safe harbour and an insurer's scheduling floor are both external and
both move. Hardcode either and the schema is wrong on a date nobody chose.

**D-5. Insurance and capital status are views, never columns. Settled.**
Store no `is_scheduled` or `is_capital` flag. Derive from cost against the current
threshold. The insurer's form shapes a report and never a table, because it is an
external schema that will change.

**D-6. Belongs and last-seen are two facts. Settled.**
`home_location_id` on the item is the static belongs-here. A `sighting` table,
append-only, gives last-seen as a derived read. This also repairs `vessel.location_id`,
which is the one place the current schema knowingly stores a mutable derived value.

**D-7. Maintenance is a contract on the asset register, not a submodule. Settled.**
Service intervals are templates, services are events, parts consumed are stock draws,
downtime is an availability predicate. The machinery already exists in the wrong place.

**D-8. Winterization is a condition state, not a feature. Settled.**
A template sets it seasonally and an interlock reads it. Same mechanism as maintenance
due, certification held, and pre-harvest interval elapsed.

---

## E. Core mechanisms

**E-1. Postings are one mechanism in core. Settled.**
Expenses, revenue, and stock movement are the same event seen from different sides.
Every module posts. Finance reads only postings and depends on no producer.
No payment processing. Linking to external systems is a provider, not a core concern.

**E-2. Interlocks are one mechanism in core. Settled.**
A spray pre-harvest interval, a feed withdrawal period, an applicator certification, an
expired permit, a dirty vessel, an overdue service, an unwinterized line. All are a
predicate over state that refuses a dispatch. Any module may register one. Core
evaluates the registered set. A module asks core whether a subject is clear, never asks
another module why.
*Wrong if:* a predicate is found that requires the asking module to understand the
answering module's domain.

**E-3. Lineage belongs in core. Settled, and this overturns an earlier assignment.**
A calf has a dam and a sire. A graft has rootstock and scion. Saved seed has a parent
line. A blend has parent lots. Same relation. Lineage moves to core with closure
semantics stripped out.

**E-4. Closure is a property of the relation type, not a trigger on the table. Settled.**
Breeding does not close the dam. Topping does not close the topping vessel. Scooping
DAP does not close the bag. Solera never closes anything. The current
`lineage_closes_parent` trigger is wrong rather than incomplete, which is S-3 arriving
from four unrelated directions.

**E-5. The polymorphic task subject stays polymorphic, and resolvers are registered. Settled.**
A core table cannot carry a foreign key to a module that may not be installed, so
`subject_type` and `subject_id` are structurally forced rather than sloppy. Each module
registers a resolver so the pointer is checkable at runtime.
*This is a prerequisite for E-6, not a sibling.* Reversed in v1, corrected here: with the
registry built first, the scheduling move costs under a day because `task_board`'s `CASE`
becomes a lateral join. Built after, it costs half again as much and has to be redone.

**E-6. The scheduling block moves to core and points at a generic subject. Settled.**
`template`, `template_step`, `task`, `task_claim_log`, and `event` are generic. Nothing
about them is winemaking. Maintenance, spray scheduling, tasting room opening
checklists, and inventory work orders are then free.
*Blocked by:* `task_board`, a core view whose `CASE` over `subject_type` names `node`,
`vessel` and `block` declaratively. That single view is why core as drawn cannot install
alone. Probed: `drop table block cascade` reports the cascade to `task_board`.

**E-7. Core enums that carry module vocabulary become registry rows. Settled.**
`subject_type` names three higher-module tables. `term_kind` carries inventory and
winemaking vocabulary. Both are core objects holding higher-module knowledge, both are
wrong-way edges under A-3, and neither will ever fail to install. `0004` already performed
exactly this migration once, moving the winemaking enums into `term`, which makes this the
same migration twice more rather than a new idea.
*Wrong if:* a value set is genuinely fixed for every possible installer. Few are.

**E-8. `is_admin()`, `app_user` and `term` are the empirical core. Settled.**
Measured rather than reasoned: `is_admin()` has in-degree 19, tied with `node` for highest
in the tree, and is called by 17 of 38 policies across 14 of 15 tables. A module installing
without it has seventeen policies that refuse to create. `term` has in-degree 18 and is the
tree's best existing contract. Everything else in core is negotiable.

**E-9. Measurements are a contract, not a module. Settled.**
Brix, TA, pH, free SO2, soil tests, somatic cell counts, honey moisture. One contract,
per-domain panels, lab integration as a provider.

---

## F. Origin and composition

**F-1. Grapes are not privileged. An origin is derived, not declared. Settled.**
A node with no lineage parents is an origin. That is a property of the graph, not a
stage enum and not a nullable foreign key. `node.block_id` is removed.

**F-2. An origin carries a typed source reference. Settled.**
A vineyard block, a purchased fruit lot with a grower, a spirit lot, a botanical lot,
sugar, water. Bought fruit and grown fruit fill the same slot with different providers.

**F-3. `block_composition` becomes a projection over general source composition. Settled.**
Composition by block is one question. By supplier, by input type, by origin lot are
others. A vermouth answers without anything special happening.

**F-4. An unattributed origin is reported, never dropped. Settled.**
The current function silently omits bins with no block and returns a short total. The
replacement returns an explicit unattributed share. Deflationary and visible.

**F-5. Removing `block_id` is what makes vineyard optional. Settled.**
If `block` lives in vineyard and winemaking must not depend on vineyard, the column is a
wrong-way edge. The change that makes vermouth work is the change that makes vineyard
uninstallable, and both fix the puttonyos and the fortifying spirit.
*Falsifier:* after removal, winemaking installs with no vineyard module and the
assertion suite passes. If it does not, the coupling was deeper than one column.

**F-6. Lineage fractions carry a unit per edge. Settled.**
Two kilos of botanicals into twenty litres of spirit. A puttony is a 25kg basket.
Fortifying spirit is litres at a proof. Composition either converts or refuses. It does
not silently normalize over what it happened to find.

**F-7. Quantity derives from an event series. Settled.**
Appassimento, angel's share, ullage, disgorgement loss. Quantity is currently a stored
scalar on `node` and is the column that escaped derived-over-stored.

**F-8. Vintage derives from lineage. Settled.**
Stored only on origins. A non-vintage cuvée and a solera have a vintage composition
rather than a vintage.

**F-9. Regulated composition carries a named convention and a basis. Settled.**
Volume does not conserve and mass does not survive fermentation, so composition above
the origin is bookkeeping rather than physics. TTB thresholds for varietal, appellation,
and vintage claims are conventions computed a specific way. The label-facing answer is
the convention, not the truth. Generalizing to typed sources preserves this. Generalizing
to an untyped bag of parents loses it.

---

## G. Depth and providers

**G-1. A producer module deepens a slot rather than sending data. Settled.**
Vineyard fills `fruit_source@1` and adds resolution behind it. Winemaking never learns
what a rootstock is. Same pattern for livestock deepening a carcass lot, orchard a cider
fruit lot, apiary a honey lot.

**G-2. A consumer renders an unresolved source. Settled.**
A name and nothing else. Never an error, never a blank. Direction-of-error applied to
depth rather than to presence.

**G-3. A source contract must be shallow enough to fill by hand. Settled.**
Test: can someone who bought two bins from a neighbour with a handshake fill it? If not,
the contract is a vineyard module in disguise and every non-vineyard install will fake
it.

---

## H. Transformation

**H-1. A style is a template, not a type. Settled.**
The system knows fortification, secondary fermentation, fractional draw, maceration,
pressing, addition. Port is a named sequence of those with parameters. No `wine_style`
enum ever ships. If the schema learns the word retsina, something has gone wrong.

**H-2. Decisions are parameters on operations. Settled.**
Whole cluster fraction, press cut points, yeast or ambient, temperature regime, SO2
timing, vessel choice, when you stopped. The ones worth capturing are those that change
the outcome and are not recoverable afterward.

**H-3. Intent is the third member of the provenance set. Settled.**
`provenance` distinguishes observed from inferred. A template step is intent. The gap
between the template saying two bar and the event saying three is a fact about the
vintage.

**H-4. Cider and vermouth are the falsifiers, and vermouth is the real one. Settled.**
Cider should cost a term vocabulary and three operations. Vermouth exercises F-6 on
every bottle. If either needs tables of its own, winemaking was renamed rather than
decomposed.

---

## I. Migrations and packaging

**I-1. Per-module migration numbering starts with the next module's first file. Settled.**
Retrofitting a numbering scheme after two modules have diverged is worse than adopting
it cold.

**I-2. A `public` facade is optional and temporary if used at all. Settled.**
The client has twelve `.from` calls across seven tables and four RPCs, all through
`kernel.ts`. That is an afternoon, not a compatibility problem. The real constraint is
PostgREST schema exposure, which is configuration.

**I-3. Cross-module reads are views. The interface stays PostgREST. Settled.**
A contract is a view, the union over providers is a view, and a consumer reads it with the
client it already has. Gate checks are catalog reads plus one parse. A service layer would
buy somewhere to host the resolver registry and would cost an authorization layer
duplicating RLS, a deployment story that does not exist, and transactional writes across
modules. At ten users that trade is bad.
This is worth ruling explicitly because the manifest and the registry will start to feel like
application logic and invite a gateway. They are tables and a parse step.
*The one real cost:* PostgREST schema exposure is configuration outside any migration, which
no test currently covers. See B-10.

**I-4. Enforcement is a build step or it is a hope. Settled, and this is the survey's conclusion.**
A rule that runs in CI is a rule. A rule in a document is an intention. This tree has
neither: `doctor` is a stub that cannot pass, `bun run test` does not exist, there is no
`.github/`, and the twenty-eight assertions run only when someone remembers. Thirty-seven of
123 edges are enforceable by nothing else.
A decomposition whose boundaries hold only by careful reading decays, and seven reviews
demonstrate what careful reading misses.
*Order:* `scripts/verify.sh` first, since it is an hour and catches the header graph, the
ledger cross-references and the style rule. `doctor` before intake, since orphans accumulate
before anything looks for them. CI last.

**I-5. Errors carry stable codes, not strings. Settled.**
A consumer reading a union must distinguish no-providers from provider-failed from
not-authorized. The client currently surfaces a thrown error string on one screen.

**I-6. A manifest is structurally invalid without its contract versions. Settled.**
Rejected by the shape before any checker runs, rather than by a check that could be skipped.

**I-7. Coliving is an acceptance test, not a roadmap item. Settled.**
If core plus scheduling plus postings installs with no farm module and runs chores and
shared expenses, the decomposition is real. Keeping it as a test rather than a product
is what stops it acquiring an undeclared dependency.

---

## J. Distribution

**J-1. Reference for the invariant, copy for the adaptation. Settled.**
What must be identical across every install ships as a pinned reference to a signed version,
so divergence is a hash mismatch. What must be locally owned ships as a copy, so an operator
can modify or reject it without forking anything. The core schema, the contract registry and
the gate checks are pinned. Templates, term vocabularies and policy defaults are copied.
This answers how a hop farm gets the fixed floor and still owns its own vocabulary.
*Enforcement:* the divergence check is a build step, per I-4. A modified core fails to build
rather than being argued about.

**J-2. Intent is stated before action, and corrections are the signal. Settled.**
A resolver states what it inferred the requirement to be and the operator confirms or
corrects before anything is dispatched. Nearly free for a work-order resolver, and the
corrections are the data worth having, because they say the requirement tags are wrong.

---

## Open questions

**Q-1. Custody separated from ownership.**
A node has an owner and a custodian and they can differ. This makes tolling, co-packing,
boarding, and shared equipment the same module, and it decides whose name is on a TTB
filing when a client ferments at your facility. Not yet ruled because it touches
`node.owner_id`, which `0003` already shipped.

**Q-2. Which policy module was meant.**
Governance in the constitutional-kernel sense, or regulatory compliance. Different
modules, and only one is interesting.

**Q-3. Distribution scope.**
Wholesale allocation and shipping compliance, or DTC fulfilment, or both. The compliance
half pulls in state-by-state rules and is the heaviest item on the list.

**Q-4. Template confidentiality.**
A custom crush client's botanical formula is a `template` with `template_step` rows.
`template` has no owner column and its read policy is the blanket `using (true)` from
`0002`. This is a migration, not a policy edit, and it blocks handing the system to a
client. Belongs in `0006`.

**Q-7. Whether the contract register needs a hard cap as well as B-5.**
B-5 kills a contract that only ever seats one module. It does not cap the rate of admission.
A register that grows one contract per module, each genuinely exercised by two, still ends as
a structure whose navigability requires a cross-reference matrix. Whether the provisional
rule is sufficient or whether admission needs a per-round cap is unresolved, and the honest
answer is that it should be instrumented before it is decided: contract count against module
count, checked on every module landing.

**Q-5. Solera truncation depth.**
Perpetual fractional draw has no terminating lineage walk. Composition converges as a
geometric series, so the implementation computes a limit with a stated truncation depth.
That depth is a devolving parameter and is not chosen.

**Q-6. Package as vessel.**
Méthode traditionnelle ferments in the bottle, so a lot becomes eight thousand vessels.
This is D-2's individual-versus-pooled parameter arriving on the winemaking side, and it
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

### 2.0 (2026-09-11)

*Cause: the A-1 architectural survey. A Postgres 16 instance built from the five migrations
at `c3eae3c`, the dependency graph derived from the catalog rather than from reading, and
module removal probed directly.*

**Reversed**

- **E-5 and E-6 swapped.** v1 listed the scheduling move and the resolver registry as
  siblings. The registry is a prerequisite: built first, the scheduling move costs under a
  day because `task_board`'s `CASE` becomes a lateral join. Built second, it costs half again
  and is partly redone.
- **E-3, carried forward from v1.** Lineage moved from winemaking to core. A dam and a sire,
  rootstock and scion, and a parent seed line are one relation. Recorded here because v1
  made the reversal silently in its own text.

**Added**

- **B-8**, function bodies resolve within declared dependencies. Postgres tracks function
  return types and not function bodies, so dropping the winemaking tables removed two
  functions and silently kept nine broken ones. The other four gate checks are catalog reads
  and structurally cannot see this. This is a static parse.
- **B-9**, three-valued gate. Pass, refuse, cannot-determine, defaulting to refuse.
- **B-10**, every check names the layer that can refuse it.
- **B-11**, the install gate returns a bit and a reason code, not a narrative.
- **E-7**, core enums carrying module vocabulary become registry rows. `subject_type` and
  `term_kind` are both core objects holding higher-module knowledge, and `0004` already
  performed this migration once for the winemaking enums.
- **E-8**, the empirical core is `is_admin()`, `app_user` and `term`. Measured: `is_admin()`
  has in-degree 19, tied with `node`, called by 17 of 38 policies across 14 of 15 tables.
- **I-3**, cross-module reads are views and the interface stays PostgREST.
- **I-4**, enforcement is a build step or it is a hope. This is the survey's actual
  conclusion.
- **I-5**, errors carry stable codes.
- **I-6**, a manifest without contract versions is structurally invalid.
- **Section J**, distribution. J-1 pins the invariant and copies the adaptation. J-2 states
  intent before action.
- **Q-7**, whether the register needs an admission-rate cap as well as B-5. To be
  instrumented rather than argued.

**Amended**

- **A-2** now carries the measured result instead of my reasoning, and is no longer
  provisional. All eight crossing foreign keys point the right way and there is no cycle. One
  declarative contradiction, `task_board`. Three runtime-only ones.
- **Q-4** unchanged in substance and now has a date, since it blocks handing the system to a
  custom crush client.
- Renumbering: old E-7 became E-9, old I-3 became I-7.

**The result worth carrying forward.** 123 edges exist and 86 are declarative. The other 37
are invisible to the catalog and are found by calling a function. The design was mostly
right and Postgres enforces less of it than the design assumed. That is an enforcement gap
rather than an architecture gap, which is why I-4 exists and why it is the item to act on
first.

### 1.0 (2026-09-11)

*Cause: initial draft, written from an extended design conversation and deliberately ahead of
the survey so the survey had something to contradict.*

Forty-two rulings in nine groups, six open questions. A-2 marked provisional as the ruling
most exposed to the dependency graph. Everything else reasoned from the packaging
requirement: a farm with no winery installs core and inventory, a winery that buys all its
fruit installs no vineyard module.
