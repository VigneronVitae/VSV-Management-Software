# R-2: direction of error on every null

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

The five files in `supabase/migrations/`, plus `packages/core/src/kernel.ts`. Absences in the schema are the bulk of this prompt; `packages/cellar/src/`, `supabase/config.toml`, and `apps/web/vite.config.ts` extend it to configuration and client and should be read if available.

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

Insert nulls and empties and read what the derived functions return.

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

For each thing that can be absent, state whether the absence removes a reading or inflates
one. Deflationary nulls compose safely. Inflationary nulls are the ones that have to be
guarded, and an inflationary null in a layer nothing checks is the failure that matters.

The repository already does this correctly in two places and says so: S-15, where an
operation whose meaning the kernel does not know records and drives nothing, and S-17, where
no seeded template means zero generated history and zero is truthful. Both are deflationary
and both are named. The question is what else is absent and was not named.

## The question

Enumerate every absence in the schema and the client and sort it by direction of error.

1. Every nullable column across the five migrations. For each: what reads it, and what does
   the reader compute when it is null? Name every case where null is treated as a value
   rather than as an absence, and every case where a null flows into an aggregate, a sum, a
   volume, or a count.

2. Every empty table on a fresh install: `term`, `template`, `template_step`, `party`,
   `location`, `vessel`, and any other. For each: what does a query against it return, and
   does the caller distinguish empty from no-match from error? S-17 names exactly this shape
   for one function. Find the others.

3. Every derived function in `0002` and `0005`: `block_composition`, `variety_composition`,
   vessel occupancy, `lot_state`, `next_cap_action`, and any others. For each: what does it
   return when its traversal hits a missing edge, a closed parent, a zero fraction, or a node
   with no lineage? A composition that silently normalizes over the parents it found rather
   than the parents that exist is an inflationary null and is the specific shape to hunt.

4. Every absence in configuration: `supabase/config.toml`, `apps/web/.env.example`,
   `biome.json`, `tsconfig.json`, `apps/web/vite.config.ts`. For each setting that is absent
   or left at a default, does the absence fail loudly at startup, fail loudly at first use, or
   change behaviour silently?

5. Produce a single table: Absence / Where it reads / Direction (deflationary or
   inflationary) / Named in the sorry ledger (yes with entry id, or no). The rows that are
   inflationary and unnamed are the output of this prompt.

---

## Finding format

Every finding:

```
**R-2-n. One line naming the defect.**
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
