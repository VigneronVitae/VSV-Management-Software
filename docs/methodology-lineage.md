---
Type: reference
Purpose: "Records what each methodological element in this repository is for, what failure it prevents, what it costs, and when dropping it would be correct."
Depends on: [packages/cellar/docs/spec.md]
Depended on by: [CLAUDE.md, docs/architecture-rulings.md, docs/status-ledger.md, docs/sorry-ledger.md, docs/compost-ledger.md, docs/session-reports/index.md]
---

# Methodology Lineage

This repository carries more apparatus than a winery app needs on its face. Four
ledgers, session reports, typed headers, tiered axioms, an agent contract. This document says what each
piece is for, so that anyone working here (including its author in six months) can tell
which parts are load-bearing and which are habit.

Each entry names the failure it prevents, what it costs, and the condition under which
dropping it would be correct. An element that cannot answer all three is ritual and
should be removed.

---

## Where this came from

This is a workflow built from a contest field. In mid-2026 the Future of Life
Foundation ran an epistemic-tooling competition; roughly thirty entrants published
open-source repositories, all attacking some version of the problem of keeping a record
honest when part of the work is done by a language model. This repository's working
method was assembled by reading them. Wine is not epistemics, but the shared problem is exact: a fluent,
confident, occasionally wrong generator writing into a record that someone will later
trust.

The patterns below were the ones that recurred across independent projects, which is the
reason to believe they are load-bearing rather than stylistic. Several are adopted
almost unchanged. A few were rejected, and the rejections are listed at the end so the
absence is deliberate rather than an oversight.

The transfer is not automatic. Those projects tolerate slow feedback because their
outputs are arguments, which can be inspected at leisure. A winery app gets noisy,
delayed, confounded signal from a physical process. Apparatus tuned for the first can
become paperwork in the second, which is why every entry carries a drop condition.

---

## 1. Typed headers

**What.** Every document opens with `Type`, `Purpose`, `Depends on`,
`Depended on by`. Migrations add the axioms they enforce and the sorries they leave
open.

**Prevents.** Documents that quietly become obsolete because nothing points at them, and
edits that break something downstream the editor could not see. The bidirectional
dependency field is the load-bearing half: a one-directional link is a broken link, and
keeping both accurate is what makes a stale document detectable.

**Costs.** A few lines per file, and the discipline of updating both ends.

**Drop when.** The repository is small enough that a person holds the whole dependency
graph in their head. At roughly a dozen documents this is already false.

## 2. Tiered axioms

**What.** T0 non-negotiable, T1 strongly held and revisable with evidence, T2 the
functions the system must perform.

**Prevents.** Two failures at once. Litigating settled decisions repeatedly, and treating
a convenience as a principle. Putting a commitment in T0 means an agent cannot trade it
away for a simpler implementation; putting one in T1 means new evidence can move it
without a crisis.

**Costs.** You have to actually decide which tier something belongs in, which is harder
than it sounds and is most of the value.

**Drop when.** Never, if the system has more than one contributor or any agent
involvement. The tier is what makes "no, that's T0" a complete answer.

## 3. Status ledger

**What.** The single source of build truth. Every component graded: built and verified,
in progress, specified, deferred. If a maturity claim appears anywhere else in the repo,
it is wrong by construction.

**Prevents.** The drift where a README says a thing works, a design document assumes it,
and nobody can tell whether it was ever run. Also prevents the softer failure of hedging
in every paragraph, since prose elsewhere can state a fact and point here rather than
re-qualifying.

**Costs.** It has to be updated when things change, and an out-of-date status ledger is
worse than none, because it is authoritative and wrong.

**Drop when.** Everything is built and nothing is planned. Which is to say, never, while
the project is alive.

**Refinement worth adopting later.** `docxology/template` grades subsystems by
*last-verified date* rather than by whether they work. "When did anyone last check" is a
different and better question than "is it broken," and it is worth switching to once
things are actually built.

## 4. Sorry ledger

**What.** Every open gap, named, with what resolves it and whether it is load-bearing.
The name is borrowed from proof assistants, where a `sorry` marks a step asserted
without proof so the checker can flag it.

**Prevents.** The specific failure where a known gap is mentioned once in conversation,
implemented around, and forgotten, so that six months later a number is computed from
data that was never verified and nobody remembers that it wasn't.

**Costs.** Naming a gap is uncomfortable and slower than proceeding. That discomfort is
the mechanism, not a side effect.

**Drop when.** Never. This is the one to keep if you keep only one. A project with seven
named gaps is in better shape than one with none and no ledger.

## 5. Compost ledger

**What.** Killed approaches, with why they died and the condition under which each
returns.

**Prevents.** Rebuilding something that already failed. In an agent-assisted project this
is the highest-frequency waste there is, because an agent has no memory of last month's
dead end and will cheerfully propose it again, persuasively.

**Costs.** One entry per kill, written while the reasoning is fresh.

**Drop when.** Never, while any agent works in the repository. The reactivation condition
is the part that distinguishes this from a list of failures: a kill without a revival
condition is a prejudice.

## 6. Provenance on every event

**What.** `observed`, `inferred`, or `confirmed`, on every recorded event.

**Prevents.** Computing a cost or a yield from history that was generated rather than
witnessed, without knowing it. Inferred history is genuinely useful for backfill; it
becomes a lie the moment it is indistinguishable from a record.

**Costs.** One column, one enum, and a rule about who may write which value.

**Drop when.** Backfill and template-generated history are removed entirely. As long as
the app generates any history it did not witness, this stays.

## 7. A producer cannot grant itself standing

**What.** Trust fields are written by the verifier, never by whoever supplied the data.
An agent generating inferred history may write `inferred` and may never write
`confirmed`.

**Prevents.** The generator marking its own work as checked, which it will do, because it
is trying to be helpful and the field is right there.

**Costs.** The write path has to strip and recompute rather than accept.

**Adopted from.** `Zhenia-Magic/ground-knowledge`, which implements this as a tool
boundary rather than a discipline: the agent writes deltas, and a deterministic
command-line tool merges them while discarding any trust fields the agent asserted. A
boundary a model cannot talk its way past is worth more than a rule it is asked to
follow.

**Drop when.** No agent or automated process writes to the system.

## 8. Derived over stored

**What.** Block composition, variety composition, and vessel occupancy are functions, not
columns.

**Prevents.** Two sources of truth diverging, which they will, the first time someone
corrects a volume after the fact.

**Costs.** Traversal on read, and eventually an index or a cache.

**Drop when.** Measured traversal cost at real data volume makes it untenable, and then
only as a cache with an explicit staleness marker, never as truth. See compost entry
C-3.

## 9. Append-only history

**What.** Corrections are new events. Cellar users insert and never update.

**Prevents.** History that can be silently rewritten, which is not history. Also makes the
record usable for the thing records are actually for, which is figuring out what happened
when something went wrong.

**Costs.** The UI has to make correction feel natural rather than punitive, or people will
avoid recording anything they might have to correct.

**Recurring in the field.** `Cbannon35/epistemic-stack` states it most directly, and
several other entrants landed on the same pair of invariants: append-only, with disagreement recorded rather than resolved by deletion, and
trust evaluated at read time rather than enforced at write time. Independent convergence
is the reason to take it seriously.

**Drop when.** Never for events. Structural objects such as vessels and templates are
editable because they describe the present, not the past.

## 10. Agent contract

**What.** `CLAUDE.md`: read order, standing hard rules, an explicit definition of done as
runnable commands, and a list of things deliberately removed.

**Prevents.** Three things. An agent solving a problem by installing a dependency. An
agent considering work finished when it compiles. And an agent rebuilding something
deliberately removed, because the removal is invisible in the code.

**Costs.** One file, kept current.

**Adopted from.** `Cbannon35/epistemic-stack` for the standing rule requiring
consultation before adding any dependency, with the installed set listed, and for the
practice of recording deliberately removed components so nothing rebuilds them.
`docxology/template` for stating definition-of-done as executable commands rather than
as a description.

**Drop when.** No agent works in the repository.

## 11. `doctor`

**What.** One command reporting what looks wrong: orphaned subject ids, bins with no
weights, lots with no placement, vessels holding two lots.

**Prevents.** The specific hole left by having one events table across four subject types,
which means `event.subject_id` cannot be a foreign key and a bad id fails silently. See
sorry S-4.

**Costs.** A query file, and remembering to run it.

**Adopted from.** `Zhenia-Magic/ground-knowledge`, where `doctor` is the health check
before handing a knowledge base to anyone else. Taken directly, including the name.

**Drop when.** The schema can enforce everything `doctor` checks, which it cannot while
the events table stays polymorphic.

## 12. Replay fixtures

**What.** A seeded dataset booting the app into a plausible mid-harvest state.

**Prevents.** Developing against real data during harvest, which is how you lose real data
during harvest. Also makes a fork immediately explorable rather than an empty shell.

**Costs.** Maintaining the fixture as the schema moves.

**Adopted from.** `tmulab/tacet`, which states its reproducibility target as fresh clone
to running process in five minutes, with a replay mode that needs no model calls, so a
stranger can evaluate it without credentials. That is the right bar.

**Drop when.** Never, while the app is under development and in use simultaneously, which
is the whole harvest.

## 13. Backlog protocol

**What.** A one-directional channel from this repository to any framework it builds on:
build local-first, prove it on the real case, then log the upstream need. Framework edits
never happen here.

**Prevents.** Application work contaminating framework work, and framework generalization
creeping into an application that does not need it.

**Costs.** Discipline at the moment you notice a general pattern and want to fix it in the
general place.

**Adopted from.** `zby/commonplace-epistack`, which runs an explicit one-directional
backlog protocol between its casework repository and the framework it builds on.

**Drop when.** There is no upstream framework in the picture.

## 14. Disposability declaration, revised

**What.** The spec used to state outright that this is a tool for one harvest and not a
product. That is now false. Two custom crush clients own wine in this cellar and the
intent is to hand this to other winemakers, so the declaration has been replaced with a
narrower one: this vintage is the worked case, and generalisation happens after it runs.

**Prevents.** The same failure by a different route. An agent asked to build well will
build for scale unless told not to, and "we will generalise later, from the real thing"
holds that off as effectively as "we will never generalise" did. What changed is that
the restriction now has to name what is deferred instead of denying the question: no
multi-facility tenancy, no `org_id`, no abstraction the vintage has not asked for.

**Costs.** More words than "disposable", and a line that has to be revisited when a
second facility appears rather than one that stays true by construction. The version
that was true forever was also the version that was about to be wrong.

**Adopted from.** `tmulab/tacet`, which declares its entry throwaway by design and names
the production effort as a separate future thing, so that simplifying does not feel like
abandoning. The second half of that is what survives here.

**Drop when.** A second facility actually exists, at which point the deferred `org_id`
stops being deferred and this entry gets rewritten again rather than quietly ignored.
This entry is now on its second rewrite, which is the mechanism working.

## 15. Session reports

**What.** One record per working session, in `docs/session-reports/`. What was
decided, what the handover documents did not settle, what was verified and by what
means, and what was left open.

**Prevents.** The loss of reasoning that happened in conversation and landed in no
file. The other apparatus here catches specific shapes: the sorry ledger catches
gaps, the compost ledger catches kills, commit messages catch changes. None of them
catches the decision nobody flagged as a decision, which is the one where an agent
picked a default, was not wrong, and left no trace of having chosen. Six months
later that default reads as though the schema always required it.

**Costs.** One file per session, written at the end while it is fresh, and honest
about what was not verified. The second half is the expensive half and it is the
half that makes the record worth reading.

**Not adopted from anywhere.** This one is local rather than scouted from the
contest field. Treat it with more suspicion than the entries above: independent
convergence is the reason to trust those, and this has none behind it.

**Drop when.** Commit messages carry the whole record. That is a real condition,
not a rhetorical one: if a session produces three commits whose messages already
say why, the report is a fourth copy. It earns its place on sessions that make many
decisions at once, which is what a scaffold session is.

---

## What did not transfer

Named here so the absence is deliberate.

**Content addressing, tamper-evident history, admission gates, cross-party standing.**
Several entrants carry substantial machinery for parties who do not trust each
other. This winery is one party. Importing it would mean paying full overhead against a
threat model that does not exist.

**Multi-model adversarial checking.** Valuable where a confident wrong answer costs months
and cannot be checked cheaply. Here the check is whether the app matches what happened in
the cellar, which one person confirms by looking.

**Generator and verifier as separate working roles.** Retained as a *data* rule (entry 7)
and dropped as a workflow. Where the output is an argument, a separate verifier catches a
fluent fabrication. In a CRUD app the verifier is the type checker and the person using
it.

**Scheduled structured reassessment.** The winery has its own cadence and harvest is not
the time for review. Revisit after the vintage is in.
