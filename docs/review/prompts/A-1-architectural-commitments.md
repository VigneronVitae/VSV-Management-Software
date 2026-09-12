# A-1: architectural commitments of the existing tree

**Target:** github.com/VigneronVitae/VSV-Management-Software, default branch `main`, at or after `c3eae3c`
**Scope:** this repository only.
**Date:** 2026-09-11
**Part of:** the VSV review set, alongside R-1 through R-6 and G-1 through G-6. Self-contained. Run it alone.

---

## Obtaining the code, and declaring how well you got it

Do this first. The failure to avoid is not a review that stops; it is a review conducted at
partial access and presented as if it were conducted at full access. Partial access is
workable. Undeclared partial access is not.

**Try these in order and stop at the first that works.**

1. `git clone https://github.com/VigneronVitae/VSV-Management-Software`
2. `git clone --depth 1 https://github.com/VigneronVitae/VSV-Management-Software`
3. `gh repo clone VigneronVitae/VSV-Management-Software` if the GitHub CLI is available
4. `git clone git@github.com:VigneronVitae/VSV-Management-Software.git` if an SSH key is
   configured
5. Tarball, which needs no git:
   `curl -L https://codeload.github.com/VigneronVitae/VSV-Management-Software/tar.gz/refs/heads/main | tar xz`
6. Per-file over raw, which serves current branch content rather than rendered HTML:
   `https://raw.githubusercontent.com/VigneronVitae/VSV-Management-Software/main/PATH`
7. The API contents endpoint, which returns base64 and declares its own truncation:
   `https://api.github.com/repos/VigneronVitae/VSV-Management-Software/contents/PATH?ref=main`

**A failure in one tool surface is not a failure of the network.** If shell commands return
`Could not resolve host`, the sandbox shell has no egress, which says nothing about a browsing
or fetch tool in the same session. Retry routes 6 and 7 through every surface available before
concluding anything. Enumerate the file paths from the rendered directory listing if you must,
then pull the content itself over raw. A review assembled that way is a good review and the
tier line is where you say so.

## Access tiers

Name your tier in the report header and apply its citation rule. The tiers differ mainly in
how much a line number can be trusted.

| Tier | How you got it | Citation rule | Scope |
|---|---|---|---|
| **A** | Full tree on disk at a pinned SHA | `path:line` | Full |
| **B** | Whole files over raw or the API at a pinned SHA | `path:line`, after confirming each file is whole | Full |
| **C** | Rendered pages, search results, or any fetch that may truncate | `path` plus a quoted unique identifier. **No line numbers.** | Reduced, coverage declared |
| **D** | No repository access; files pasted into the conversation | `path` plus identifier | Whatever was pasted |
| **E** | Nothing, and nothing can be requested | Stop | None |

Tier B is a full review. Do not treat it as second best or hedge its findings.

Tier C is a real tier and working at it is correct. Rendered pages truncate long files
silently and their numbering does not reliably survive a fetch, so a Tier C line number is a
guess wearing the costume of a fact. Cite the file and the identifier, for example
`supabase/migrations/0002_derived_and_rls.sql`, policy `event_insert`, and let the reader grep.
A wrong locator costs more than a missing one, because the reader follows it.

**Before reporting Tier E, ask.** A missing file is one message away. Name the exact paths you
need and request them. Stopping without asking is the wrong failure, and so is stopping
because the first surface you tried had no DNS.

## Minimum corpus for this prompt

Everything. This prompt is a survey of the whole tree: all five migrations, all of `packages/` and `apps/`, every file in `docs/`, `CLAUDE.md`, and a complete file listing. Without the migrations there is no coupling graph; without the client there is no call-site count; without the docs there is no stated intent to compare against.

With the minimum, review. With more, review more and say so. With less, ask for the missing
paths by name; if they cannot be supplied, report on what you have, state the reduced scope in
the header, and mark every finding that depends on an unread file UNVERIFIED rather than
dropping it.

## Report header

Every report, at every tier, opens with:

1. **Tier**, and the route and tool surface that worked.
2. **Commit.** `git rev-parse HEAD` verbatim if you have it, otherwise the ref you read and how
   you identified it. Baseline is `c3eae3c7c262544e4b2e29526b513c964c6852fe`, dated 2026-09-08;
   your tree should be that commit or a descendant, and if it is an ancestor say so. Do not
   describe where a SHA appeared on a web page as though it were command output.
3. **Canaries.** `main`, not the stale `claude/sql-files-to-markdown-i31rob`. A tree holding
   only `LICENSE` is pre-merge `main` and is the wrong tree. Present at the baseline:
   `supabase/migrations/0005_account_and_walk.sql`, `tests/schema_assertions.sql`,
   `packages/cellar/src/walk.ts`, `docs/session-reports/2026-09-08-walk.md`. 42 tracked files.
4. **File table.** Every file attempted: path, whole or partial or failed, line count where you
   have one. Partial means a truncation marker, content stopping mid-statement, or inability to
   tell. Inability to tell is partial.

Pin to one commit and read everything at it. Address any later fetch by that SHA rather than by
`main`, so a push mid-review cannot leave half your findings describing a different tree.

---

## Execute the schema. Do not review it by reading alone.

Two prior reviews in this series built a local Postgres, applied the migrations, and probed.
Both found defects that reading cannot reach, and one falsified two of its own predictions in
the process. Reading SQL and reasoning about what it would do is the failure mode this section
exists to prevent. If you have a shell, execute.

**The shim.** Build it to this spec, not to your own taste, so that counts and results are
comparable across reports:

- Postgres 16.
- An `auth` schema with a `users` table.
- `auth.uid()` returning the JWT subject, reading `request.jwt.claim.sub` first and falling
  back to the `request.jwt.claims` blob.
- Roles `anon`, `authenticated`, `service_role`, with Supabase's default grants on `public`.
- An empty publication named `supabase_realtime`.
- No `storage` schema unless you can stand one up. Migration `0005` guards its storage block on
  that schema existing, so without it that block is skipped.

**Report three numbers in your header.** Whether all five migrations applied clean; how many
assertions in `tests/schema_assertions.sql` ran and how many passed; and whether the
storage-guarded block executed. Two earlier reports in this series reported different assertion
counts for the same commit because their shims differed on that last point. State it so the
next reader can tell.

**Probe under roles, not as superuser.** `set local role authenticated` with a `request.jwt.claim.sub`
set to a real `app_user` id, and separately `set local role anon` with no claim. RLS does not
apply to the table owner, so a probe run as the migration user proves nothing. Probe at least
as: an admin, a cellar user, a custom crush client with a party row, an authenticated principal
with no `app_user` row, and `anon`.

**Mark every executed finding as probed, and report falsified predictions.** If you expected a
defect and the probe showed otherwise, say so and keep the corrected result. That disclosure is
worth more than the finding it replaces, because it is the only evidence in the report that the
probes were real.

**What to execute for this prompt specifically.**

Apply the migrations, then derive the dependency graph from the catalog rather than by reading: `pg_depend` joined to `pg_class`, `pg_proc`, `pg_constraint`, `pg_trigger`, `pg_policy` and `pg_rewrite` gives you every real edge, including the ones a grep over the SQL text misses because they run through a view or a trigger. Report the edge count and list the edges themselves. Then, for each table, list every function, policy, trigger, view and constraint that references it. That table-to-dependant map is the single most useful artifact this prompt can produce and it should appear in full.

If you have no shell, say so in the header and mark every finding that would have been probed
UNVERIFIED with the probe you would have run. A reasoned reading is still worth having. A
reasoned reading presented as an observation is not.

---

## What this prompt is, and is not

This is a survey, not a proposal. The output is a description of what the existing tree commits
its author to, expressed precisely enough to price a decision he has not yet made.

**Do not design an architecture.** Do not recommend a pattern, a topology, a framework, a
message bus, or a service boundary. Do not write a target state. If you find yourself producing
a paragraph that would read the same against any codebase, delete it. Every claim in your
output should be falsifiable by someone reading this specific tree.

The author is considering splitting this system into installable modules: a core, an inventory
module, a winemaking module, and later others, so that a farm with no winery or a winery with
no vineyard can install a subset. The intent is packaging rather than deployment topology, and
the working assumption is one Postgres with a schema per module rather than separate databases.
That intent is context for what to measure. It is not a conclusion to support, and if the tree
makes it expensive or impossible, say so plainly and show the evidence.

---

## 1. The actual coupling graph

Derive it from the catalog, not from reading. Report:

1. Every dependency edge among tables, functions, views, triggers, policies and constraints,
   with a count.
2. For each of the sixteen tables, everything that references it.
3. Strongly connected components, if any. A cycle in the dependency graph is a set of objects
   that cannot be separated at all, and finding one now is worth more than finding it in
   October.
4. The objects with the highest in-degree. Those are the things every module would need, which
   is the empirical answer to what belongs in a core, as opposed to the intuitive one.

## 2. Edges that would cross a module line

Take this candidate assignment as a hypothesis to test, not a design to endorse:

- **core**: `party`, `app_user`, `location`, `term`, `event`, `task`, `task_claim_log`,
  `template`, `template_step`, code resolution, provenance
- **inventory**: nothing yet; `vessel` and `vessel_code` are the candidates to move here
- **winemaking**: `node`, `lineage`, `placement`, `block`

For every dependency edge that crosses one of those lines, report: the edge, its direction, its
kind (foreign key, function body, policy predicate, trigger, view), and whether it is
declarative or only enforceable at runtime. Then state which edges point the wrong way, where
wrong means a lower module referencing a higher one, since those are precisely what make a
module uninstallable alone.

Flag any function whose body spans two candidate modules. `create_vessel_with_wine` is the
obvious one. Find the rest.

## 3. What assumes a single schema

Enumerate, with locators:

1. Every unqualified object reference in a function body, and whether the function pins
   `search_path`. An unpinned definer function that resolves objects by search order behaves
   differently once objects live in different schemas.
2. Every policy predicate that calls a function defined elsewhere, and what happens to it if
   the function moves.
3. Every trigger that writes to a table other than its own.
4. Every view that spans candidate modules.
5. The polymorphic pointer `task.subject_type` and `task.subject_id`. Report what enforces it
   today, what would enforce it across schemas, and what happens when the target's module is
   not installed.

## 4. The client's coupling surface

Count it, do not estimate it. Every `.from()`, `.rpc()`, and storage call in `packages/` and
`apps/`, with the object each names and the file it sits in. Then state what schema-qualifying
the database would cost the client in call sites changed, and what would catch a mistake. Note
specifically whether TypeScript, Biome, or the Supabase client types would fail at build time
on a wrong or missing schema, or whether the failure is only at runtime on one screen.

Also report how PostgREST exposure works against a multi-schema database, and what the tree
currently configures.

## 5. Migration ordering

The tree has a single global sequence `0001` through `0005`. Report:

1. What in the sequence would break if it were split into per-module sequences, and which
   statements depend on the order of statements in a different candidate module.
2. Whether `0002`'s RLS block could be split by module, given it is written as loops over table
   lists.
3. What a dependency manifest would have to declare for the split sequences to apply in a valid
   order, derived from the graph in section 1 rather than asserted.
4. The cost of deferring: what gets more expensive if per-module numbering starts after another
   module already exists, as against starting with the next migration written.

## 6. The install-alone test

This is the load-bearing section. For each candidate module, construct the minimum set of
objects that would have to exist for it to install and function with only its declared
dependencies present. Then state what is missing, what would have to move, and what would have
to be duplicated.

Run the test concretely for two cases:

1. **A farm with no winery.** Core plus inventory. Which tables, which functions, which
   policies, and what refuses to apply.
2. **A winery with no vineyard.** Core, inventory, winemaking, no vineyard module. `block`
   is the pressure point: report exactly which columns and references a fruit-buying winery
   needs and which belong to growing.

## 7. Contracts already present

Something in the tree may already behave like a contract, meaning a shape defined independently
of what fills it. The `term` table, the polymorphic task subject, `provenance`, and the
`attributes` jsonb bags are candidates. For each, report whether it is genuinely a contract, a
convention, or an escape hatch, and what would have to be true for it to carry a versioned
shape across modules.

## 8. Hosting and deployment, as the tree commits to them

Report what exists and what the existing choices constrain, without recommending a host.

1. What the tree configures for deployment today, and what is absent.
2. The client is static and holds a public anon key, which makes RLS the only access boundary.
   State what that forecloses: what could not be added without a server, and which of the
   candidate modules would need one.
3. What changes about hosting if modules become separately installable. Schema exposure,
   migration application order, and how an installed-module set would be discovered at runtime.
4. What the absence of CI costs specifically for a multi-module tree, as against the single one.
5. Backup, restore and rollback across a set of schemas that version independently.

## 9. The bill

Close with a priced summary. For each of: splitting schemas, per-module migration numbering,
moving the scheduling block to core, qualifying the client, and adding a module manifest, give
an effort estimate in hours or days, what could go wrong, what would catch it, and whether
deferring it makes it cheaper, the same, or more expensive. Mark anything that becomes
materially harder once intake writes production rows.

Be specific about what is genuinely irreversible as against merely annoying. Most of this is
annoying.

---

## Output format

Sections 1 through 8 in order, each answering its own questions. Tables where the content is
tabular, which is most of sections 1, 2, 4 and 6. Section 9 is a single priced table plus a
short paragraph.

For anything you could not determine:

```
**Open: one line naming what is undetermined.**
*Why:* what was missing or unexecutable.
*What would settle it:* the specific command, file, or decision.
```

## Closing instruction

The value here is precision about this tree, not fluency about architecture. A sentence that
would be true of any Postgres application is noise. A count, a locator, an edge, or a named
function that spans a boundary is signal. If the candidate module assignment in section 2 is
contradicted by the graph in section 1, say so directly and show the edges; that is the most
useful result this prompt can produce.
