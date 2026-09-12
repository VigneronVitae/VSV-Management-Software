# R-5: append-only history and derived over stored

**Target:** github.com/VigneronVitae/VSV-Management-Software, default branch `main`, at or after `c3eae3c`
**Scope:** this repository only. No other repository is in scope and none needs to be read.
**Date:** 2026-09-10
**Part of:** a six-prompt set, R-1 through R-6. This file is self-contained. Run it alone.

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

`supabase/migrations/0001_core_schema.sql`, `0002_derived_and_rls.sql`, and `0004_terms_and_effects.sql`. `0005_account_and_walk.sql` and `docs/compost-ledger.md`, for entry C-3, extend it.

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

Attempt update and delete on `event`, `lineage`, `placement` and `node` as each role, and record whether the statement raises or silently matches zero rows, because those are different defects. Delete a parent row and observe what the foreign keys do. Insert a lineage edge as a cellar user and separately as an admin, then read the parent's status both times: a prior report in this series found `close_parent_on_lineage()` runs as the invoker and is filtered by the node update policy, so the close fires for one role and not the other. Confirm or refute that, then walk the volume-correction path end to end and report what the composition functions show before and after.

If you have no shell, say so in the header and mark every finding that would have been probed
UNVERIFIED with the probe you would have run. A reasoned reading is still worth having. A
reasoned reading presented as an observation is not.

---

## Standing rules

1. **Read-only.** Find, do not fix. A patch is out of scope and a proposed patch inside a
   finding buries the finding.
2. **The repository's own documents are claims, not ground.** `CLAUDE.md`,
   `packages/cellar/docs/spec.md`, the three ledgers in `docs/`, and the two session reports
   assert things about the code. Every one of those assertions is in scope as a target. A
   finding of the form "the document says X and the code does Y" is a first-class result, and
   which of the two is wrong is a separate question this report should not assume.
3. **Cite `path:line` for every claim about the tree.** A finding with no locator is a
   candidate and is marked as such.

---

## Scale bound

Grade reachability against the real deployment, not an imagined one: about 50 vessels, two
labels, two custom crush clients, five to ten users, low thousands of events a vintage, tens
of thousands of rows after a decade, one Postgres instance. A defect that needs a thousand
vessels or a million rows to bite is LATENT here, not EXPLOITABLE, and the report should say
what volume reaches it.

---

## Verdict scale

All six categories are available. The last two are what keep the report honest.

| Verdict | Meaning |
|---|---|
| EXPLOITABLE | A concrete path exists against the tree as it stands. State the steps. |
| LATENT | The defect is real and currently unreachable. Name the specific change that reaches it. |
| DIVERGENT | Code and document disagree. Neither is asserted wrong. |
| BY DESIGN | It looks wrong and is named somewhere as deliberate. Cite the ledger entry or comment by locator. |
| NOT A DEFECT | Checked, and it holds. |
| UNVERIFIED | Could not be checked without something unavailable: a running Supabase instance, a real JWT, a camera, a phone, real data. |

UNVERIFIED is the category that gets dropped and it is the one that matters most here. Three
of this repository's four sessions could not run the environment, and everything that has
failed so far failed there. A report with no UNVERIFIED rows has probably guessed.

---

## Principle under test

Two commitments, tested together because they fail together. Events are append-only and
corrections are new events. Nothing derived is stored, because two sources of truth diverge
the first time someone corrects a volume after the fact. Compost entry C-3 is a kill on
exactly this and carries a reactivation condition.

## The question

Can history be rewritten, and is anything derived also stored?

1. Enumerate every path that can modify or delete a row in `event`, `lineage`, `placement`, or
   any other history-bearing table. Include RLS policies, triggers, `security definer`
   functions, cascading deletes, and `on delete` clauses on foreign keys. A cascade is a
   deletion path even when no policy grants delete, and cascades are the ones that do not look
   like a write path.

2. State who can update an event, under what conditions, and what the record shows afterward.
   Then state whether an admin update is distinguishable, after the fact, from the event
   having always said that.

3. Enumerate every column that stores something computable from other rows: block composition,
   variety composition, vessel occupancy, lot state, volumes, counts, statuses, anything
   generated. For each stored derivation, state what recomputes it, what would make it stale,
   and whether anything detects staleness. Generated columns that are constants for
   foreign-key typing are not findings; say so and move on.

4. Trace correction. A cellar user records 400 litres and it was 380. Walk the full path by
   which that becomes correct in the record, through the schema as committed. State what the
   lineage fractions, the composition functions, and any dependent volume show before and
   after. If the path does not exist, that is the finding.

5. Test the topping and lineage threshold question against the code rather than against S-1.
   The sorry says the threshold is unchosen. Determine what the code does today in its
   absence, and state the direction of error in the block composition of a topped barrel.

6. Check the partial-consumption case named in S-3, where `lineage_closes_parent` closes a
   parent entirely on first child. Confirm or refute against the trigger as written, and state
   what the record shows for the material that remains.

---

## Finding format

Every finding:

```
**R-5-n. One line naming the defect.**
*Verdict:* one of the six.
*Locator:* path:line, or several.
*What is wrong:* two or three sentences. What the code does, and what it should do.
*How it surfaces:* the concrete situation in which someone notices, or "silently, never."
*Resolves when:* the specific condition. Not a patch.
*Load-bearing:* yes or no, with one clause saying why.
```

Group findings by verdict, EXPLOITABLE first. Open the report with a table of every finding
id, one line each, so the whole result is readable without scrolling. The format matches
`docs/sorry-ledger.md` so a confirmed finding drops in without rewriting.

---

## Closing instruction

Do not try to be reassuring. Try to be correct. If a part of this repository is sound, say so
in one line and spend the space on the parts that are not. If you cannot check something
without a running Supabase instance, a real token, a camera, or a phone, mark it UNVERIFIED
and say exactly what would check it; do not reason your way to a verdict you did not earn.
