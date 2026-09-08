---
Type: specification
Purpose: "Specifies the winery production app's object model, interaction modes, and build order, as the single source of design truth every other document cites."
Depends on: []
Depended on by: [CLAUDE.md, README.md, docs/methodology-lineage.md, docs/status-ledger.md, docs/sorry-ledger.md, docs/compost-ledger.md, supabase/migrations/0001_core_schema.sql, supabase/migrations/0002_derived_and_rls.sql, supabase/migrations/0003_parties_and_products.sql]
---

# Winery Production App, Spec v0.2

Vitae Springs / Amica Luna. Target: usable for the 2026 harvest, extended in place
during the season.

Two labels, shared production. Roughly 5 bins per pick. Six varieties with distinct
protocols. Existing measurement capture is Anton Paar Wine Meister on iPad, which
stays; readings are transcribed manually into this app.

**This vintage is the worked case.** The 2026 harvest at one winery is what this is
built against, and it is built to be handed to other winemakers afterward. Those two
facts fit together in one order only: generalisation happens after the vintage runs,
against something real, rather than now against a guess about what other winemakers
need. Two custom crush clients are already on the books, so the second user is no
longer hypothetical, which means the restriction has to name what is deferred rather
than pretend the question will not come up.

What that rules out, concretely:

- **No multi-facility tenancy now.** `owner_id` on the node is in from the start
  because retrofitting it would mean assigning every existing lot by hand, and there
  is wine in this cellar that other people own. A facility-level `org_id` is a
  different problem and is deferred until a second facility actually exists.
- **No abstraction the vintage has not asked for.** A thing used in one place stays
  in one place. The generalisation pass has a real corpus to work from later; it does
  not have one now.

**The deadline is harvest and it does not move.** Build order in section 7 is ordered
by irrecoverability of failure, not by architectural foundation.

---

## 1. Design axioms

### Tier 0: non-negotiable

- **T0-1. One node type.** Bins, press loads, ferment lots, and blends are the same
  object at different stages. Lineage edges carry the structure. There is no special
  case for a load made of loads.
- **T0-2. Derived over stored.** Block composition, variety composition, and vessel
  occupancy are computed from lineage and placements. Two sources of truth diverge
  the first time a volume is corrected.
- **T0-3. Provenance on every event.** `observed`, `inferred`, or `confirmed`. An
  inferred press and a recorded press must never be indistinguishable. Anything
  computed downstream reports how much of its input was never witnessed.
- **T0-4. A producer cannot grant itself standing.** Trust fields are written by the
  verifier, never by whoever supplied the data. An agent generating inferred history
  writes `inferred` and cannot write `confirmed`.
- **T0-5. History is append-only.** Corrections are new events. Cellar users insert
  and never update. A record that can be silently rewritten is not a record.

### Tier 1: strongly held, revisable with evidence

- **T1-1. Pickers, not text fields.** Cellar users select from existing objects.
  Free-text vessel names from three people is how the data becomes unusable.
- **T1-2. Local-first for append-only writes, server-authoritative for mutable
  state.** Events sync opportunistically; task claiming fails visibly when offline.
- **T1-3. Every scan is a reconciliation opportunity.** The person is standing in
  front of the thing. Confirm location and lot identity while that is free.
- **T1-4. Intake must be fast before it is complete.** The truck is waiting and hands
  are cold. Everything else can be entered later; a bin that was never weighed
  cannot be recovered.

### Tier 2: functions the app must perform

| # | Function | Notes |
|---|----------|-------|
| 2.1 | Intake | Planned and actual picks, bin weights, location |
| 2.2 | Transformation | Press, destem, blend. Where lots acquire identity |
| 2.3 | Placement | Which lot is in which vessel, when |
| 2.4 | Observation | Samples, readings, treatments. Transcribed or sensed |
| 2.5 | Direction | Tasks, the board, cap management mode |
| 2.6 | Reconciliation | Scanning, `doctor`, provenance audit |

---

## 2. Schema

### node

Everything that is wine or becomes wine.

| field | notes |
|---|---|
| id | uuid, client-generated so offline writes have identity |
| stage | `bin` \| `load` \| `ferment` \| `maturation` \| `finished` |
| status | `planned` \| `open` \| `closed` |
| variety | |
| vintage | |
| block_id | input only at `stage=bin`; composition downstream is derived (T0-2) |
| name | autopopulated, editable |
| quantity | weight at bin stage, volume after |
| unit | `lbs` \| `kg` \| `L` \| `gal` |
| attributes | bag: `whole_cluster_pct`, `style_intent`, `pick_number`, `cap_rule` |
| provenance | per T0-3 |
| closed_at | set by trigger when the node becomes a parent |

Nodes may be created at any stage with no ancestry. A backfilled 2024 Chardonnay
enters at `maturation`, participates fully, and grounds nothing about its own history
until lineage is supplied. This is the untyped floor: nothing is refused, and what is
missing costs exactly the capability it supports.

### lineage

`parent_id`, `child_id`, `fraction`. A DAG with splits and merges: three Chardonnay
vineyards feed single-vineyard bottlings and two of them also feed reserve and
distribution blends. Fractions are computed from entered volumes, never typed.

### vessel, placement, location

Vessels carry type, name, capacity, location, thermal state, and a loose attribute bag
(cooper, wood, fill count, toast). Placements join a node to a vessel with a volume and
a time range; a vessel is occupied if it has a placement with null `to_at`. Locations
carry ambient temperature; a jacketed vessel's setpoint overrides it. Cold soak and
cold crash are therefore derivable states, not only logged events.

### event

One table for everything that happens, with `subject_type` in `node | vessel |
location | block`. Subject polymorphism is what lets a room thermometer, a vessel
setpoint change, a lot Brix reading, and a pre-harvest block sample share a table.

A setpoint is a decision; a reading is an observation. Both are events, distinguished
by type and subject. Keep both histories.

### task, template, user

Tasks carry a type, a subject, a due window, an optional assignee, and claim state.
Unassigned tasks are claimable from the board; claiming is a database-side conditional
update, never read-then-write.

Templates are generators only. A lot holds whatever tasks and events it accumulated;
divergence by vintage is expected rather than versioned. Forward, templates seed tasks
on stage entry. Backward, they generate inferred history for backfilled lots.

Two roles: `admin` creates structural objects, `cellar` records what happened.

---

## 3. Operation vocabulary

Six protocols, one shared vocabulary, four kinds by effect on state.

**Measurements** observe and change nothing: `sample`, `temp_reading`.

**Treatments** change the wine in place: `addition`, `punchdown`, `pumpover`,
`batonnage`, `topping`, `cold_soak`, `cold_crash`, `cold_stabilize`, `filter`,
`halt_fermentation`, `malo_check`.

**Movements** change vessels without changing the lot: `rack`, `consolidate`,
`distribute_lees`, `move_vessel`.

**Transformations** close nodes and open new ones, writing lineage: `press`,
`destem`, `blend`, `bottle`.

`press` is both movement and transformation and differs by color: whites press before
fermentation, reds press off skins after. Same verb, different position in the
sequence, same effect on lineage.

---

## 4. Lifecycles

**Pick.** `planned` then `actual`. Interns see what fruit is coming. Partial
fulfilment closes the actual pick with what arrived and spawns a new planned pick for
the remainder. Plan-versus-actual accumulates yield data across vintages that would
otherwise never be captured.

**Bin to lot.** The bin is atomic and carries one block. A lot is created by the
operation that combines material, not by arrival. Two days of Riesling pressed
together is one press consuming several bins. Per-bin yield falls out when a load
draws from one block and is genuinely unknowable when it mixes three, which is correct
rather than a limitation.

---

## 5. Interaction modes

**Intake.** Tap today's scheduled pick, enter bin weights, confirm location. One
screen at five bins per pick.

**Press.** Select bins or existing lots from the same picker; the screen does not need
to know which. Select destination vessels, enter volumes out, name the result. The
vessel picker shows empty vessels or vessels already holding this lot, since
consolidating from fermentation height means adding to a partly full vessel.

**Topping mode.** Scan the source lot once, then scan each barrel *before* pouring.
Variety, color, and vintage compatibility is checked at the moment it can still
prevent the mistake. Session list with undo. Volume added is usually unknowable, so
the record is that it happened and from which source.

**Cap management mode.** Scan the fermenter; the app answers punchdown or pumpover,
derived from the lot's `cap_rule` plus today's event history. This is the first place
the app directs rather than records, and it works because the rule plus the record
determines the answer, which makes recording self-enforcing.

**Board.** Unassigned tasks are claimable, assigned tasks go to a person. Who does
what, how long tasks sit unclaimed, and what nobody picks up are recorded, which
surfaces training gaps without anyone reporting them.

---

## 6. Adopted from the contest field

Scouted from the 27 competition repositories. Each is adopted for a stated reason.

**The delta-and-verify boundary** (Zhenia-Magic/ground-knowledge). An agent writes
deltas; a deterministic tool merges them and recomputes trust fields, discarding any
the agent asserted. This is T0-4 implemented as a tool boundary rather than as a
discipline. It applies directly to inferred history: the generator proposes, the
verifier stamps.

**`doctor`** (same source). One command reporting what looks wrong before handoff.
Given that `event.subject_id` cannot be a foreign key, this is the only thing that
catches orphaned subjects. Also catches bins with no weights, lots with no placement,
and vessels holding two lots.

**Replay fixtures** (tmulab/tacet). A seeded dataset booting the app into a plausible
mid-harvest state, so development and demos never touch real data and a fork is
immediately explorable. Their stated target, fresh clone to running in five minutes,
is the right bar.

**Standing hard rules in the agent file** (Cbannon35). Consult before adding any
dependency, with the installed set listed. Prevents the drift you get from an agent
that solves problems by installing things.

**Removed-thing records in the agent file** (same source). A one-line note that a
component was deliberately removed, with the date, so nothing rebuilds it. This is a
compost entry at file scale.

**The backlog protocol** (zby/commonplace-epistack). One-directional channel from
application work to framework work: build local-first, prove on a worked case, then
log the upstream need. Adopted to keep this repo from contaminating EpiTrellis and
vice versa.

---

## 7. Build order

1. **Locations, vessels, users, and the backfill path.** Creating a barrel of
   Chardonnay registers vessel, lot, and placement in one action, then generates
   inferred history from the variety template for confirmation.
2. **Intake.** The object that must exist before all others, and the one where a
   missed record is unrecoverable.
3. **Press and destem.** Where lots acquire identity.
4. **Events and samples.** Manual transcription from Wine Meister.
5. **Tasks and the board.**
6. **Topping and cap management modes.** These need QR codes.
7. **Derived views and `doctor`.**

Ship 1 and 2 solid before harvest. Everything after is built during pressing downtime,
because harvest does not pause and a bug during intake means a bin that never got
recorded.
