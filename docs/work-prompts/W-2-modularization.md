# W-2: modularization

**Repository:** github.com/VigneronVitae/VSV-Management-Software, branch `main`
**Mode:** write, unsupervised, multi-session. Expect this to span several context windows.
**Governing documents:** `docs/architecture-rulings.md`, `docs/findings-ledger.md`, and
`docs/session-reports/2026-09-11-verification-surface.md`. Read all three before starting.

---

## The situation you are inheriting

A thirteen-report review corpus was run against this tree at five migrations and 42 files.
The tree now has twenty-two migrations and 96 files, because a wire session happened in
between. The findings ledger survived that because it is keyed by identifier rather than by
line number, and it is still the plan.

Two consequences shape this session.

Migrations `0006` through `0020` have never been reviewed by anything. The one defect known
in that range, every write path running as the caller against admin-only update policies, was
found only because ledger entry A14 generalized further than it was written to. Three of the
four findings in the last session came from surface the corpus never saw. **Splitting a tree
you have not read carries its defects across the boundary and makes them structural.** That
is why phase 2 exists and why it comes before any table moves.

And this is a live winery database during harvest. The app has to work at the end of every
phase. If you cannot get a phase to green, revert to the last green commit and write up why.
A half-applied schema split is worse than no schema split.

---

## Resumability

You will run out of context before you run out of work. Design for it.

Maintain `docs/session-reports/modularization-progress.md` from the first commit onward. It
is not a session report. It is the file a fresh session with no memory reads first, and it
must be sufficient on its own. Update it at the end of every phase, and also whenever you
make a decision a later session would otherwise have to re-derive.

It holds: the phase list with each marked not-started, in-progress, done or blocked; the last
green commit sha; the current migration number; every decision made and why; every deviation
from this prompt and why; and anything you discovered that changes a later phase.

When a session starts, read it, verify the tree matches what it claims, and continue. When a
session is running low, finish the phase or revert to green, update the file, and stop
cleanly. Do not start a phase you cannot finish.

## Green

Green means all of: `bun run verify` passes; `bun run typecheck` and `bun run lint` pass; all
migrations apply clean from empty to a scratch database; the full assertion suite passes
against that scratch database; and the assertion suite passes against a copy of the cellar
database. Every phase ends green and commits. No phase commits red.

The cellar database has real harvest data in it. Use `db:up`, never `db:reset`, and never run
a destructive statement against it. Test against a scratch database and a restored copy.

## Stop conditions

Stop, revert to green, write it up, and do not push through if: a migration cannot be made to
apply to both an empty and a populated database; the assertion count falls; you need a change
to the hosted Supabase project's settings, which you cannot make; a phase requires a decision
the ruling document does not cover; or you find a defect in the unreviewed range serious
enough that continuing would build on top of it.

Halting with a clear write-up is a good outcome. Twelve phases half-done is not.

---

## Phase 1: namespace collision

The findings ledger uses `A1` through `E12`. The architecture rulings number their sections
`A-1` through `J-2`. The compost ledger has used `C-1` onward since before either existed.
Three claimants on `C-3`, and `verify.sh` currently carries an exemption by name to work
around it.

Rename the rulings' section ids, since they are newest and least referenced. Prefix them so
they cannot collide with either ledger: `AR-A1`, `AR-B5`, `AR-J2` or similar. Update every
cross-reference inside the document, its changelog, and any reference elsewhere in the tree.
Then remove the `verify.sh` exemption and confirm the compost cross-reference check still
passes.

Bump the rulings document to 2.1 with a changelog entry. Patch-level would be wrong: ids are
how other documents refer to it.

**Done when** the exemption is gone, verify passes, and no id shape is used by two documents.

---

## Phase 2: read the unreviewed range

Fifteen migrations and everything the wire session added to the client. This is a review pass
with write access, and its output is ledger entries, not fixes.

Use the existing prompts as lenses rather than rerunning them: `docs/review/prompts/R-5`,
`R-6`, `G-1` and `G-4` are the four that bear on migrations. Apply their questions to `0006`
through `0022`. You have the advantage none of the original runs had, which is that you can
read the ledger first and check whether each known defect class recurs in the new code.

Specific things to check, because they are known to recur:

Every function added since `0006`: is it `security definer` or not, and is that the right
answer? A14's generalization was that write paths run as the caller against admin-only
policies. `0021` fixed six functions. Confirm there is not a seventh.

Every new policy against the A5 pattern: `0002`'s loop put blanket `using (true)` on thirteen
tables, and `0003` narrowed exactly one. Did anything added since narrow any more, or add new
tables with the same default?

Every new table for the A13 pattern: does a refused write return zero rows or an error?

Every new derived function for the A10 pattern: does it inner-join something optional and
silently return a short total?

Every new stored column for the A18 and A19 pattern: is it a derivation that nothing
recomputes?

Then rerun the mutation test from `G-5`. It scored 42% against 28 assertions. There are now
129. More assertions is not the same as stronger assertions, and you are about to rely on
that suite to police a schema move. **If the mutation score has not improved, say so plainly
and treat it as a stop condition for phase 7 specifically.** A schema split policed by a
suite that misses more than half of injected defects is not policed.

File everything new into `docs/findings-ledger.md` in its existing five-disposition shape,
bump it to 1.1, and add a changelog. Do not fix what you find unless it blocks a later phase,
and if it does, say so in the progress file.

**Done when** every migration from `0006` to `0022` has been read against those five patterns,
the mutation score is measured and recorded, and the ledger is updated.

---

## Phase 3: the resolver registry

`AR-E5`. This is the prerequisite for everything after it, and A-1 measured that building it
first makes the scheduling move cost under a day where building it second costs half again.

`task.subject_type` and `task.subject_id` are a polymorphic pointer with no foreign key. That
is structurally forced, not sloppy: a core table cannot carry a foreign key to a module that
may not be installed. What is missing is that each module should register a resolver, so the
pointer is checkable at runtime even though it cannot be checked declaratively.

Build the registry table and the resolver mechanism. A resolver maps a subject type to the
relation that holds it and the expression that renders its display name. Registration is a
row, not a code change.

**Done when** a subject type can be registered, resolved and rendered without any core object
naming a module table, and the assertion suite covers registration, resolution, and the
behaviour when a subject's module is absent.

---

## Phase 4: `task_board`

The single declarative reason core cannot install alone. It is a core view whose `CASE` over
`subject_type` names `node`, `vessel` and `block`, recorded in `pg_rewrite`. Probed:
`drop table block cascade` reports the cascade to `task_board`.

Rewrite it against phase 3's registry as a lateral join. After this, core names no
module table declaratively.

**Done when** `task_board` returns identical rows to before, proven by comparing output
against the cellar copy before and after, and `drop table block cascade` on a scratch database
no longer reports a cascade to it.

---

## Phase 5: enums to registry rows

`AR-E7`. `subject_type` is a core enum naming three higher-module tables. `term_kind` is a
core enum carrying inventory and winemaking vocabulary. Both are wrong-way edges that will
never fail to install.

`0004` already performed exactly this migration once, moving the winemaking enums into
`term`. Follow that precedent rather than inventing a second pattern.

Watch `term.value` while you are in here. It is the join key the database resolves terms by,
and its derivation lives in eight chained string operations in one TypeScript file. That is
ledger A16 and it is section A work, so do not fix it now, but if this phase makes it worse
or easier, record which in the progress file.

**Done when** neither enum names a module concept, and adding a new subject type or term kind
is a row.

---

## Phase 6: the scheduling block to core

`AR-E6`. `template`, `template_step`, `task`, `task_claim_log` and `event` are generic.
Nothing about them is winemaking. Moving them is what makes maintenance scheduling, spray
scheduling, tasting room checklists and inventory work orders free later.

This is where per-module migration numbering begins. `AR-I1` says retrofitting a numbering
scheme after two modules diverge is worse than adopting it cold, and this is the first
migration that belongs to a module rather than to the tree. Design the scheme, write it down
in the progress file and in the rulings document, and start it here. The existing `0001`
through `0022` stay as they are; do not renumber history.

**Done when** the scheduling tables live in core, point at a generic registered subject, and
the assertion suite passes unchanged.

---

## Phase 7: the schema split

The big one. Only attempt it if phase 2's mutation score came back acceptable.

Three schemas to start: `core`, `inventory`, `winemaking`. The candidate assignment is in the
rulings at `AR-A2` and survived the A-1 survey with the corrections phases 4 and 5 just made.
`alter table set schema` is metadata-only, so row count is irrelevant and the cellar
database's size does not make this slower.

**Build a `public` facade and do not touch the client in this phase.** One view per moved
table, in `public`, with `security_invoker = true` so RLS still evaluates as the caller. The
client keeps working with zero changes and zero configuration changes. This matters more than
usual right now: PostgREST exposes schemas explicitly, that setting lives in the hosted
project's dashboard, it is unversioned, and you cannot change it. A split without a facade
would take the app down until somebody logs into a dashboard. A split with one is invisible.

Generate the facade views from a list rather than writing them by hand, so it cannot drift
out of completeness.

Then apply `AR-B8`: write the fifth gate check. Postgres tracks function return types and not
function bodies, so dropping a module's tables leaves every function whose body references
them in the catalog with a signature and grants, raising on first call. Measured in the
survey: two functions dropped, nine broken ones silently kept. Four catalog checks cannot see
this. Write the static parse, add it to `verify.sh`, and prove it by dropping a module's
tables on a scratch database and confirming zero surviving functions raise.

**Done when** every table is in its module schema, the facade is complete and generated, the
client works untouched, all 129 assertions pass, and the function-body check exists and has
been observed to catch a real break.

---

## Phase 8: the manifest and the register

`AR-B1` through `AR-B11`. A module declares hard dependencies, provisions and consumptions.
A contract is a name, an append-only version and a typed column set. Provisions are views
matching the declaration. Consumers read the union over registered providers.

Five gate checks, run at install, no judgment: every required consumption has a compatible
provider; the hard-dependency graph is acyclic; every claimed contract version exists; every
provided view's columns match its declaration; and every function body resolves within
declared dependencies, from phase 7.

`AR-B9`: the gate returns pass, refuse, or cannot-determine, with cannot-determine defaulting
to refuse. `AR-B10`: each check names the layer that can refuse it, and the register carries
that as a column. `AR-B11`: the gate returns a bit and a reason code, not a narrative.

Then prove the whole thing with the falsifier the rulings already state. On a scratch
database, install core alone and confirm it works. Install core plus inventory and confirm.
Then `AR-F5`: winemaking with no vineyard module present, and the assertion suite still
passing. That last one is the test of whether `block_id` was really the only coupling.

**Done when** the three installs succeed, a deliberately broken manifest is refused with a
reason code, and the falsifier result is recorded whichever way it went.

---

## Out of scope

Section B of the ledger, all nineteen client defects, including B1, which is one CSS line and
sixty percent of a screen. It is a separate session by design and it touches files phase 7
does not.

Section A beyond what phases 4, 5 and 7 force. `0006` is long spent; section A now needs a
new migration number and a supervised session.

Section E deferrals. The topping threshold, which W-1 already ruled is not to be chosen by an
agent. `owner_id` and `hidden`, which `0021` deliberately kept out of every column allow-list.
Adding CI. Adding any dependency without asking.

Do not migrate client call sites off the facade. That is a supervised session paired with the
dashboard configuration change, and doing it unsupervised risks the app during harvest for no
gain.

---

## The report

A session report per completed session in `docs/session-reports/`, in the tree's convention,
plus the running progress file.

Report what each phase changed and what proves it, as commands and numbers rather than as
claims. Report the mutation score before and after phase 2 explicitly. Report the falsifier
result from phase 8 whichever way it went, because a failed falsifier is the most useful
single result available here: it would mean the coupling is deeper than one column and the
module boundary is wrong.

And keep doing what the last session did well: record the predictions you made that turned
out false. The corpus's credibility comes from the runs that disclosed their own misses, and
so does yours.
