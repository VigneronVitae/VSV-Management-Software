# G-4: security and operational posture

**Target:** github.com/VigneronVitae/VSV-Management-Software, default branch `main`, at or after `c3eae3c`
**Scope:** this repository only.
**Date:** 2026-09-10
**Part of:** a six-prompt general review set, G-1 through G-6. This file is self-contained. Run it alone.

This is an ordinary engineering review. The repository carries an unusual amount of
methodological apparatus: four ledgers, typed document headers, tiered axioms, an agent
contract. Read `CLAUDE.md` and `packages/cellar/docs/spec.md` for context on what the code is
meant to do, then ignore the apparatus. You are not auditing the method. You are reviewing
Postgres, TypeScript, and a web client the way you would review any other small production
system.

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

The five files in `supabase/migrations/`, plus `supabase/config.toml`, `packages/core/src/env.ts` and `kernel.ts`, and `.gitignore`. `bun.lock` and the `package.json` files extend it to the dependency question.

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

Enumerate execute grants on every function in `public` and report who holds them, since PostgreSQL grants EXECUTE to PUBLIC by default and nothing in this tree revokes it. Check `search_path` pinning on every `security definer` function. Then, for every table, probe read and write as anon, as an authenticated principal with no `app_user` row, as a cellar user, as a custom crush client, and as an admin, and build the resulting access matrix from observations rather than from policy text.

If you have no shell, say so in the header and mark every finding that would have been probed
UNVERIFIED with the probe you would have run. A reasoned reading is still worth having. A
reasoned reading presented as an observation is not.

---

## What this system is

Production tracking for a small winery in the Willamette Valley. Fruit arrives in bins, bins
become lots, lots move between vessels, people record what they did to them. Postgres on
Supabase, a static client in plain TypeScript against the DOM with no framework, used on
phones in a barrel room. Roughly 1,800 lines of TypeScript and five SQL migrations.

It is built for one winery this harvest and intended to be handed to other winemakers after
that. Harvest is weeks away and the date does not move.

## Scale bound

State any performance or architecture recommendation against these numbers, not against
imagined growth:

- About 50 vessels. Tanks, barrels, bins.
- Two labels and two custom crush clients.
- Five to ten users, rarely more than three at once.
- Low thousands of events per vintage. Tens of thousands of rows total after a decade.
- Lineage graphs a few levels deep, widening at blends.
- One Postgres instance. No read replicas, no sharding, no queue, no cache layer.

A recommendation premised on scale beyond this is out of scope and should not appear. Caching,
denormalization, background workers, and service decomposition are all wrong answers here
unless you can show a concrete query that is slow at the numbers above.

## Standing rules

1. **Cite `path:line` for every claim about the code.** A claim with no locator is a
   candidate and should be marked as such.
2. **Do not propose adding a dependency without flagging it as such.** The repository has a
   standing rule requiring consultation before any new dependency or external service, and
   the installed set is small on purpose. A finding whose only fix is a new library should say
   so plainly and should also say what the fix looks like without one.
3. **Do not propose a rewrite, a framework, or a restructure.** If the honest answer is that
   something should be rebuilt, say it in one sentence and then give the version that fits in
   the time available.
4. **Say when something is fine.** A review that flags everything is as useless as one that
   flags nothing.

---

## Severity scale

| Severity | Meaning |
|---|---|
| BLOCKER | Loses data, corrupts the record, or stops work in the cellar. |
| MAJOR | Wrong behaviour, a real security hole, or a defect that will cost hours to unpick later. |
| MINOR | Correct today, fragile under a plausible edit. |
| NIT | Style, naming, consistency. Group these; do not spend paragraphs on them. |
| NOT A DEFECT | Checked, and it holds. Worth saying for anything a reviewer would expect to be wrong. |
| UNVERIFIED | Could not be checked without a running Supabase instance, a real device, a camera, or real data. |

## Harvest triage

Tag every finding with one of three, because the deadline is the binding constraint:

- **BEFORE HARVEST.** The cost of shipping without this is higher than the cost of the delay.
- **DURING.** Safe to fix in place while the system is in use, because the change is additive
  or reversible.
- **AFTER.** Real, and it can wait for the off-season without accruing damage.

A review that returns fifteen BEFORE HARVEST findings has not triaged. Be willing to say that
a genuine defect can wait.

---

## What to read

All five migrations with attention to the RLS section of `0002`, `packages/core/src/env.ts`
and `kernel.ts`, `supabase/config.toml`, `.gitignore`, `apps/web/.env.example`, `bun.lock`,
and the `LICENSE`.

This review is about ordinary application security and running the thing, not about the
repository's trust model.

## Review this

1. **RLS as the only boundary.** The anon key ships in the client and is meant to be public,
   which makes row-level security the entire access-control story. Read every policy and state,
   per table, exactly what an anonymous holder of that key can do and what an authenticated
   user with no other grant can do. Report every table with RLS enabled and no policy, every
   table with a policy and no RLS, and any policy whose `using` and `with check` clauses
   differ in a way that permits an unintended write.

2. **Policy correctness and cost.** Check each policy predicate for correctness against its
   intent, and separately for how it is evaluated per row. Calls to session functions inside a
   policy predicate can be evaluated once or once per row depending on how they are written;
   state which pattern each policy uses and whether it matters at the stated scale.

3. **Definer functions as an access path.** Every `security definer` function is a hole
   through RLS by design. For each: is the hole the intended size, does it pin `search_path`,
   and does it validate that the caller is entitled to the rows it touches.

4. **Auth configuration.** `supabase/config.toml` against what the client actually does.
   Signup enablement, email confirmation, JWT expiry, refresh token rotation and reuse
   interval, redirect URLs, and site URL. State every place the config and the client's
   expectations disagree, and what a user sees when they do.

5. **Storage.** Bucket creation, bucket policies, upload path, signed URL generation and
   expiry, file size limits, content type handling. State who can read an uploaded photo and
   for how long. Flag any path where a public bucket is created or a URL is unbounded.

6. **Secrets and the repository.** Check `.gitignore` coverage against every file that could
   carry a credential, check the git history for anything committed and later removed, and
   check that nothing in the tracked tree carries a service role key, a database password, or
   a filled `.env`.

7. **Dependencies.** The tree is deliberately thin. For each direct dependency: is it
   maintained, is the version pinned or floating, and what is the transitive count. Flag
   anything that pulls a large tree for a small use, and anything unmaintained. Do not propose
   replacements unless the current choice is actually a problem.

8. **Availability during harvest.** Supabase is a single external dependency and the cellar
   does not stop when it is unreachable. State what the app does when the API is down, what
   work is lost, and what the paper fallback would need to be. This is a design question the
   review should answer even though the code does not.

9. **Backup and restore.** What exists, what it would take to restore the database to a point
   in time, and how long that takes. A nightly export to git is specified and not built; state
   what the gap means in practice if a bad migration runs during harvest.

10. **Deployment.** How the client gets built and served, what the release process is, and
    what a rollback looks like if a deploy breaks mid-day. If no deployment story exists in
    the tree, say so and describe the smallest one that would work.

---

## Finding format

```
**G-4-n. One line naming the issue.**
*Severity:* BLOCKER | MAJOR | MINOR | NIT | NOT A DEFECT | UNVERIFIED
*Triage:* BEFORE HARVEST | DURING | AFTER
*Locator:* path:line
*What is wrong:* two or three sentences.
*Why it matters here:* tie it to the scale bound and the cellar, not to general principle.
*Fix:* the smallest change that closes it. Note if it needs a dependency or a migration.
*Effort:* minutes, hours, or days.
```

Open the report with a table of every finding id, severity, and triage, one line each. Group
the body by severity, BLOCKER first. Collapse NITs into a single list at the end.

---

## Closing instruction

Be direct and be specific. A finding with no locator and no concrete fix is not a finding. If
a section of this code is well built, say so in one line and move on; the value of this review
is in what it flags, and the credibility of every flag depends on the honesty of every pass.
Do not pad the report to look thorough.
