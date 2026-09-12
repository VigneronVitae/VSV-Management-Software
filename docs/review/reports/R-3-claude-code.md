# CC_R3: declared against exercised

**Reviewed:** `c3eae3c7c262544e4b2e29526b513c964c6852fe`, dated 2026-09-08, obtained by
`git clone https://github.com/VigneronVitae/VSV-Management-Software` (route 1) and read
entirely at that SHA.

---

## Currency, all four checks

| Check | Result |
|---|---|
| Commit | `git rev-parse HEAD` returns `c3eae3c7c262544e4b2e29526b513c964c6852fe`. Identical to the review baseline, neither ancestor nor descendant. `git merge-base --is-ancestor` confirms. |
| Branch | `main`. The stale `claude/sql-files-to-markdown-i31rob` exists on the remote and was not reviewed. Noted once below because it is one commit ahead of `main`, not behind. |
| LICENSE canary | Fails to trigger. The tree carries 42 files, not a lone `LICENSE`. |
| Content canary | All four present: `supabase/migrations/0005_account_and_walk.sql`, `tests/schema_assertions.sql`, `packages/cellar/src/walk.ts`, `docs/session-reports/2026-09-08-walk.md`. `git ls-files \| wc -l` returns 42, matching the stated baseline. |

Everything below was read at that SHA. Nothing was fetched by any other route.

**What was actually executed, so the UNVERIFIED rows are earned rather than assumed.**
A Postgres 16.13 cluster was initialised locally; `bun`, `node`, `npm` and `psql` are
present; the Docker daemon is not reachable and the Supabase CLI is not installed. All
five migrations were applied, the 412-line assertion file was run to completion, and the
client's `typecheck`, `lint`, `build`, `test` and `doctor` scripts were each run and their
exit codes recorded. The dependency graph was reconstructed by an independently written
script and replayed across eight commits of history.

---

## Findings

| id | One line | Verdict |
|---|---|---|
| R-3-1 | The committed Supabase config forbids sign-up, so the walk's own acceptance test cannot reach step two | EXPLOITABLE |
| R-3-2 | `bun run test` is in the definition of done and no `test` script exists | DIVERGENT |
| R-3-3 | Every "applies clean" and "all passing" grade rests on an auth shim that is not in the tree | DIVERGENT |
| R-3-4 | The dependency-graph check exists only as a sentence, and the invariant it guards already broke silently for five commits | DIVERGENT |
| R-3-5 | The status ledger says "Nothing is built" twenty-eight lines above three rows graded Built and verified | DIVERGENT |
| R-3-6 | Migrations 0001 and 0002 are graded "never run" by a table whose next row asserts they ran | DIVERGENT |
| R-3-7 | CLAUDE.md says the compost ledger holds five entries each with a reactivation condition; it holds six and two have none | DIVERGENT |
| R-3-8 | The em dash rule is stated absolutely and nothing enforces it | DIVERGENT |
| R-3-9 | The module-boundary rule defers to lint, the code it was waiting for now exists, and lint does not enforce it | LATENT |
| R-3-10 | The scaffold report claims database dumps are ignored; the most common dump filename is not | DIVERGENT |
| R-3-11 | The walk report miscounts the repository's own commits by five | DIVERGENT |
| R-3-12 | `bun run doctor` exits 1 and fails the definition of done | BY DESIGN |
| R-3-13 | `supabase db reset`, the first line of the definition of done, has never been run by anyone | UNVERIFIED |
| R-3-14 | The vessel-photos bucket and its two storage policies have never executed in any environment | UNVERIFIED |
| R-3-15 | The assertions write `auth.users` directly, which a real Supabase may refuse | UNVERIFIED |
| R-3-16 | RLS through a GoTrue-issued JWT | UNVERIFIED |
| R-3-17 | Both PostgREST wire formats the walk depends on | UNVERIFIED |
| R-3-18 | zxing against a real camera | UNVERIFIED |

---

## EXPLOITABLE

**R-3-1. The committed Supabase config forbids sign-up, so the walk's own acceptance test cannot reach step two.**
*Verdict:* EXPLOITABLE.
*Locator:* `supabase/config.toml:49`, `supabase/config.toml:52`, against
`packages/cellar/src/walk.ts:126-134` and `packages/core/src/kernel.ts:40-43`;
acceptance test stated at `packages/cellar/src/walk.ts:43-45`.
*What is wrong:* `enable_signup = false` is set under both `[auth]` and `[auth.email]`.
`walk.ts` opens on a screen whose second button calls `signUp`, and the module's stated
acceptance test is "empty database, fresh account, and you get from sign up to a labelled
barrel with wine in it without touching SQL." The first account has to be creatable and
there is nobody to create it for you, so the setting closes the only door into the
application it ships with.
*How it surfaces:* clone at `c3eae3c`, `bun install`, `supabase start`, `bun run db:reset`,
`bun run dev`, open `localhost:5173`, type an email and password, press "Create an
account". GoTrue refuses the request and the screen shows the refusal in its error banner.
Every screen behind that button is unreachable. The refusal itself was not executed here,
because the Docker daemon is unreachable from this container; the config value is a fact
read at the SHA, and the repository's own later work names the same consequence
independently, on a commit that is not on `main`.
*Resolves when:* local development allows sign-up, or the first account is created by
some route the repository documents.
*Load-bearing:* yes. It blocks the single acceptance test the walk session was built
around, and it blocks it at step one, so nothing downstream of it can be tested either.

---

## DIVERGENT

**R-3-2. `bun run test` is in the definition of done and no `test` script exists.**
*Verdict:* DIVERGENT.
*Locator:* `CLAUDE.md:90` against `package.json:10-19`.
*What is wrong:* the block at `CLAUDE.md:81-93` defines done as five commands. One of
them, `bun run test`, has no corresponding entry in any `package.json` in the workspace.
Run, it falls through to `/usr/bin/test`, which exits 1 with "a package.json script
\"test\" was not found". The root `package.json` defines `typecheck`, `lint`, `format`,
`db:reset`, `doctor`, `db:test`, `dev` and `build`; `README.md:39-41` lists `typecheck`,
`lint` and `doctor` and is silent about `test`, so the README and the contract disagree
about what the repository can be asked to do.
*How it surfaces:* the first person who runs the definition of done top to bottom instead
of reading past it. Measured: exit code 1.
*Resolves when:* a `test` script exists, or the line leaves the block.
*Load-bearing:* yes. Two of the five commands in the definition of done cannot pass
(this one and R-3-12), which means nobody has ever executed the block as written and got
a clean result, which means the block is a description of intent rather than a gate.

**R-3-3. Every "applies clean" and "all passing" grade rests on an auth shim that is not in the tree.**
*Verdict:* DIVERGENT.
*Locator:* `docs/status-ledger.md:40`, `:41`, `:42`, `:44`;
`docs/session-reports/2026-09-08-scaffold.md:93-95`;
`docs/session-reports/2026-09-08-walk.md:94-95`; caused by
`supabase/migrations/0001_core_schema.sql:88` and `tests/schema_assertions.sql:111`.
*What is wrong:* both session reports say the verification ran against "a scratch
Postgres 16 with a minimal stand-in for what Supabase provides" and enumerate it:
`auth.users`, `auth.uid()`, the `authenticated` role, the `supabase_realtime`
publication. That stand-in is in neither report as code nor anywhere in the 42 tracked
files. Applied to a bare Postgres 16 in filename order, `0001` dies at line 93 with
`ERROR: schema "auth" does not exist` and the remaining four fall over behind it. The
status ledger grades four separate rows on the strength of a run nobody else can
reproduce from the repository.
*How it surfaces:* the first reviewer who tries to confirm a grade without Docker. Each
of them writes their own shim, and each shim is a different guess about what Supabase
provides. Reconstructing one here took about thirty lines, after which all five
migrations applied clean and all twenty-eight assertions passed, so the grades are
substantively correct and procedurally unsupported.
*Resolves when:* the shim is committed, or the grades cite `supabase db reset` as the
only environment they were earned in and stop claiming a scratch Postgres.
*Load-bearing:* yes. It is the difference between a check the repository carries and a
check a particular session happened to run, and the whole ledger's authority rests on
which of the two it is.

**R-3-4. The dependency-graph check exists only as a sentence, and the invariant it guards already broke silently for five commits.**
*Verdict:* DIVERGENT.
*Locator:* `docs/session-reports/2026-09-08-scaffold.md:106-107`; convention stated at
`CLAUDE.md:112-115`. No script file is tracked anywhere in the repository.
*What is wrong:* the scaffold report says "Ten headered files, twenty-eight dependency
edges, every edge bidirectional, checked by script rather than by reading." It is the
only "by script" claim in either report, and the script is not committed. An
independently written reconstruction confirms the numbers exactly at `c6a04a3`: ten
headered files, twenty-eight declared relations, zero one-directional edges. Replayed
forward across the commits that followed, the invariant does not hold:

| Commit | Headered files | Declared relations | One-directional edges |
|---|---|---|---|
| `7d527cc` | 12 | 31 | 0 |
| `f5ef16d` | 12 | 31 | 0 |
| `0e5302d` | 13 | 36 | **5** |
| `0989802` | 13 | 36 | **4** |
| `3ee3cff` | 13 | 38 | **4** |
| `3cde9a0` | 15 | 48 | **14** |
| `114b7fb` | 15 | 48 | **14** |
| `c3eae3c` | 16 | 49 | 0 |

The graph was broken for five consecutive commits, peaking at fourteen one-directional
edges, and was repaired by hand only in the last commit on the branch, whose message is
"correct the reverse dependency edges". This is not a prediction that an unenforced
invariant can be silently falsified. It is a record of it having happened, in exactly the
window where the check existed only as a sentence in a session report.
*How it surfaces:* it already did, and was caught by a human reading rather than by
anything the repository runs.
*Resolves when:* the checker is a committed command that fails on a one-directional
edge, a dangling path, or an orphaned headered file.
*Load-bearing:* yes. `CLAUDE.md:115` says "a one-directional link is a broken link", and
the typed headers are how an agent is supposed to navigate the repository at all.

**R-3-5. The status ledger says "Nothing is built" twenty-eight lines above three rows graded Built and verified.**
*Verdict:* DIVERGENT.
*Locator:* `docs/status-ledger.md:12` against `docs/status-ledger.md:40`, `:53`, `:58`;
repeated at `docs/sorry-ledger.md:156`.
*What is wrong:* the ledger's "In one read" section opens "Nothing is built. This ledger
exists before the code does, which is the point." Three rows in the same file are graded
Built and verified, and the file's own definition of that grade at `:28` is "Coded, and
its check passes." The sorry ledger's Discharged section carries the same stale sentence:
"*None. Nothing has been built.*" The summary was written when it was true and has
outlived two sessions of code.
*How it surfaces:* silently, to whoever reads the first paragraph and stops, which is
what a section titled "In one read" invites. `CLAUDE.md:11-12` makes this file the single
source of build truth, so its own summary contradicting its own table is the sharpest
version of the failure this repository is arranged to prevent.
*Resolves when:* the summary states what the table states.
*Load-bearing:* yes. It is the first sentence of the document every other document
defers to.

**R-3-6. Migrations 0001 and 0002 are graded "never run" by a table whose next row asserts they ran.**
*Verdict:* DIVERGENT.
*Locator:* `docs/status-ledger.md:37`, `:38` against `docs/status-ledger.md:40` and
`tests/schema_assertions.sql:6-10`.
*What is wrong:* rows 37 and 38 read "`0001_core_schema.sql` written, never run" and
"`0002_derived_and_rls.sql` written, never run". Row 40 grades the assertion file Built
and verified with twenty-eight assertions passing, and that file declares a dependency on
all five migrations and cannot execute unless every one of them has been applied. The
same table therefore says the first two migrations have never run and that something
requiring them to have run passes. Rows 41, 42 and 44 use a more careful phrasing
("applies clean from empty ... against a scratch Postgres 16", "never run against this
project's own instance") which rows 37 and 38 did not receive when the later work landed.
*How it surfaces:* silently. Someone budgets time to first-run two migrations that have
in fact been run, or trusts a "Specified" grade on schema that is further along than the
grade admits.
*Resolves when:* rows 37 and 38 carry the same phrasing as rows 41, 42 and 44.
*Load-bearing:* yes, in the direction that matters least loudly: it understates maturity,
which is the safer error, but it makes the grade column unreliable in both directions.

**R-3-7. CLAUDE.md says the compost ledger holds five entries each with a reactivation condition; it holds six and two have none.**
*Verdict:* DIVERGENT.
*Locator:* `CLAUDE.md:54-55` against `docs/compost-ledger.md`, entries at `:13`, `:24`,
`:35`, `:43`, `:52`, `:66`; missing conditions at `:43-50` (C-4) and `:66-72` (C-5);
self-description at `docs/compost-ledger.md:10-11`.
*What is wrong:* three separate claims fail at once. The count is six, not five. C-4 and
C-5 carry no "*Reactivate if:*" line, so "each with a reactivation condition" is false
for a third of the ledger, and the ledger's own opening sentence, "Each entry carries
what was tried, why it died, and what would bring it back", is false about itself. The
entries are also out of sequence: C-6 sits at line 52 and C-5 at line 66. The scaffold
report at `:74-79` records removing raw counts from prose for precisely this reason, and
this one survived.
*How it surfaces:* an agent told to check five entries checks five, and C-6, the newest
and the one a status-ledger grade depends on, is the sixth.
*Resolves when:* the number leaves the prose, and C-4 and C-5 either carry a
reactivation condition or the ledger stops claiming all entries do.
*Load-bearing:* yes. `CLAUDE.md:54-57` calls checking this ledger "the specific failure
this file exists to prevent", and a count is the one part of the instruction an agent can
follow wrongly while believing it followed it.

**R-3-8. The em dash rule is stated absolutely and nothing enforces it.**
*Verdict:* DIVERGENT.
*Locator:* `CLAUDE.md:121`; claimed as checked once at
`docs/session-reports/2026-09-08-scaffold.md:110`; `biome.json:17-22`.
*What is wrong:* "No em dashes anywhere, in code comments, docs, or commit messages" is
unconditional. Checked mechanically at this SHA, it holds: zero U+2014 and zero U+2013 in
any of the 42 tracked files, and zero in any of the seventeen commit messages across both
refs. The rule is true and unchecked. Biome's recommended preset has nothing to say about
prose, no script in `package.json` scans for it, and no hook exists, so the only thing
standing between the convention and its first violation is that everyone has remembered.
*How it surfaces:* silently, on the first pasted paragraph. The verdict is DIVERGENT
rather than NOT A DEFECT because the question is which claims a future edit can falsify
without anything noticing, and this is one of them.
*Resolves when:* a committed command fails on a match, over both the tree and the commit
range.
*Load-bearing:* no. A stray em dash costs nothing but the rule's own credibility, and the
credibility is the reason it is stated absolutely.

**R-3-9. The module-boundary rule defers to lint, the code it was waiting for now exists, and lint does not enforce it.**
*Verdict:* LATENT.
*Locator:* `CLAUDE.md:71-75`, restated at `packages/cellar/src/index.ts:2`; `biome.json:17-22`.
*What is wrong:* the rule says "A module package may import from `core` and never from a
sibling module", and then names its own enforcement schedule: "Lint will enforce this once
there is code to enforce it against; until then it is enforced here." There is code now.
Three packages exist, `cellar` imports `core` in earnest, and the condition the sentence
set has arrived. Biome is configured with `"preset": "recommended"` and no import
restriction, so nothing changed when it did. Probed directly: a fourth package importing
`mountWalk` from `cellar` passes both `bun run typecheck` (exit 0) and `bun run lint`
(clean, once the probe's own JSON formatting is fixed).
*How it surfaces:* the first sibling module. Today there is one module, so the defect is
unreachable; it becomes reachable the moment a `cases` or `sales` package exists, which
is the exact scenario `CLAUDE.md:72-73` describes.
*Resolves when:* Biome carries a restricted-import rule naming the sibling paths, or the
sentence stops promising an enforcement that is not scheduled.
*Load-bearing:* yes, prospectively. `CLAUDE.md:73-74` makes this the rule that decides
whether shared code moves down into `core` or gets duplicated, and a second module is the
entire point of the worked-case framing.

**R-3-10. The scaffold report claims database dumps are ignored; the most common dump filename is not.**
*Verdict:* DIVERGENT.
*Locator:* `docs/session-reports/2026-09-08-scaffold.md:108-109` against
`.gitignore:24-33`.
*What is wrong:* the report lists "database dumps confirmed ignored by `git check-ignore`"
among the things verified. `.gitignore` covers `*.dump`, `*.sql.gz`, `*.backup` and
`dumps/`. `pg_dump` without `-Fc` writes plain SQL, and `pg_dump -f backup.sql` is the
form most people type. Checked: `db.dump` and `prod.dump` are ignored; `dump.sql`,
`backup.sql`, `pgdump.sql` and `supabase/dump.sql` are not. A blanket `*.sql` is not
available here because five migrations and the assertion file are tracked `.sql`, which
is presumably why the pattern stops where it does, but the report states the conclusion
rather than the boundary.
*How it surfaces:* someone dumps a development database to the repository root during
harvest, sees it in `git status`, and `git add -A` takes it. `.gitignore:24-26` says
"Real winery data never lands in git", which is the thing at stake.
*Resolves when:* the ignore covers plain-SQL dumps by location rather than by extension,
or the report's claim narrows to the extensions it actually checked.
*Load-bearing:* yes. It is a data-exposure claim, and it is stated as verified.

**R-3-11. The walk report miscounts the repository's own commits by five.**
*Verdict:* DIVERGENT.
*Locator:* `docs/session-reports/2026-09-08-walk.md:167`.
*What is wrong:* "Every commit of both sessions, twenty-one of them now, lives on
`claude/sql-files-to-markdown-i31rob`". Counted: sixteen commits on that branch after
`Initial commit`, fifteen at the moment the sentence was written. The surrounding
argument, that a fresh clone of the default branch got only a licence, is correct and was
the most useful thing either report says; only the number is wrong. The same report
corrects a different miscount four lines earlier, at `:121-123`, where the commit message
on `3cde9a0` says twenty-nine assertions and the file has twenty-eight. Verified: twenty-
eight `test_ok` call sites, twenty-eight `ok` lines emitted at runtime.
*How it surfaces:* silently. Reports are append-only per `docs/session-reports/index.md:25`,
so the number is permanent and only a later report can correct it.
*Resolves when:* a later report notes the count, per the append-only convention.
*Load-bearing:* no. Nothing downstream reads it, and the claim it decorates is sound.

---

## BY DESIGN

**R-3-12. `bun run doctor` exits 1 and fails the definition of done.**
*Verdict:* BY DESIGN.
*Locator:* `package.json:15`; named deliberate at `CLAUDE.md:95-97`,
`docs/status-ledger.md:77`, `README.md:39-41`, and sorry `S-4` at
`docs/sorry-ledger.md:39-42`.
*What is wrong:* nothing that is not already named. The script echoes a message pointing
at S-4 and exits 1. It is the fourth of the five commands in the definition of done, so
the block cannot pass today, and the repository says so in four places rather than
pretending otherwise. Recorded because the block is a gate that no tree can currently
pass, and a reader should know that is deliberate for this command and accidental for
`bun run test`.
*How it surfaces:* exit code 1, with the reason in the output.
*Resolves when:* `doctor` checks `event.subject_id` for orphans, which is S-4's own
resolution condition.
*Load-bearing:* yes, as a gap. `CLAUDE.md:95-97` calls it "the only thing standing
between the schema and orphaned records", and it is not standing there yet.

---

## UNVERIFIED

**R-3-13. `supabase db reset` has never been run by anyone.**
*Verdict:* UNVERIFIED.
*Locator:* `CLAUDE.md:83`; `package.json:14`; named open at
`docs/session-reports/2026-09-08-scaffold.md:114-118`,
`docs/session-reports/2026-09-08-walk.md:135`, and `:185`.
*What would check it:* a machine with Docker and the Supabase CLI, running
`bun run db:reset` against a clean local stack. It is the first line of the definition of
done, it has been the outstanding acceptance criterion across both sessions, and it is
the command that would have surfaced R-3-1 immediately. The migrations were applied here
with `psql` in filename order, which is the same sequence and not the same command; the
CLI also brings the real `auth` and `storage` schemas, which is exactly the difference
R-3-3 and R-3-14 turn on.

**R-3-14. The vessel-photos bucket and its two storage policies have never executed in any environment.**
*Verdict:* UNVERIFIED.
*Locator:* `supabase/migrations/0005_account_and_walk.sql:302-340`, guard at `:309-312`;
named at `docs/session-reports/2026-09-08-walk.md:147`; client side at
`packages/core/src/kernel.ts:276-297`.
*What would check it:* the same running Supabase stack. The block is guarded on the
`storage` schema existing and returns early when it does not. Confirmed here: after all
five migrations applied, `pg_namespace` contains no `storage` row, so the guard fired and
the entire block, the bucket insert and both policies, did nothing. The guard is honest
and commented as such, and the consequence is that bucket creation, the two policies, the
upload path and the signed-url path have collectively never run anywhere.

**R-3-15. The assertions write `auth.users` directly, which a real Supabase may refuse.**
*Verdict:* UNVERIFIED.
*Locator:* `tests/schema_assertions.sql:111-114`; invoked by `package.json:16`.
*What would check it:* running `bun run db:test` against a Supabase-provisioned database
as the role the `DATABASE_URL` in that environment actually grants. Under the
reconstructed shim the insert is trivial, because the shim's `auth.users` is a two-column
table owned by the connecting role. Under a real stack `auth.users` is owned by
`supabase_auth_admin` and carries columns GoTrue maintains. Whether the assertion file
runs at all outside the shim is therefore open, which means the one committed check in
the repository may be the one that only passes in the environment that is not committed.
This compounds R-3-3 rather than duplicating it: R-3-3 is that the shim is missing, this
is that the shim may be load-bearing in a way that does not transfer.

**R-3-16. RLS through a GoTrue-issued JWT.**
*Verdict:* UNVERIFIED.
*Locator:* sorry `S-7` at `docs/sorry-ledger.md:54-65`; `docs/status-ledger.md:39`;
`tests/schema_assertions.sql:36-42`, `:354`, `:393`.
*What would check it:* a real Supabase instance with two real accounts, signing in
through the client and confirming the same refusals. The assertions set
`request.jwt.claim.sub` directly with `set_config`, then `set local role authenticated`.
Confirmed here: the policies hold under that construction. Five RLS assertions pass,
including a client login seeing one lot and none of the other six. What is assumed is
GoTrue issuing the token and PostgREST mapping it to the `authenticated` role. The sorry
ledger states this precisely and the status ledger row matches it. This is the one place
where the declared and the exercised are already in agreement, and it is worth saying so.

**R-3-17. Both PostgREST wire formats the walk depends on.**
*Verdict:* UNVERIFIED.
*Locator:* `packages/core/src/kernel.ts:63-75` and `:224-241`; named at
`docs/session-reports/2026-09-08-walk.md:145` and `:149`.
*What would check it:* the walk run against a real PostgREST. `claim_account` returns a
composite, which PostgREST renders as a bare object where a set-returning function comes
back as an array; the client accepts either at `kernel.ts:72` rather than betting, which
is the right hedge and is not a test. `create_vessel_with_wine` takes two `jsonb`
arguments that have never been mapped over the wire. The walk report names these as the
two likeliest places for a first run to break and it is right to.

**R-3-18. zxing against a real camera.**
*Verdict:* UNVERIFIED.
*Locator:* `packages/cellar/src/scan.ts:25`; `docs/status-ledger.md:57`;
`docs/session-reports/2026-09-08-walk.md:148`.
*What would check it:* a phone, in a barrel room, with a wet lens. Nothing about a
camera can be checked from here and the repository does not claim otherwise. Manual entry
sits beside the scanner rather than behind it, per the decision at
`docs/session-reports/2026-09-08-walk.md:89-90`, which is the correct hedge for a check
nobody can run until harvest.

---

## The question, answered

### 1. Every claim graded Built and verified or In progress

| Claim | Locator | Supporting check | Committed and runnable? | Verdict |
|---|---|---|---|---|
| Schema assertions, 28 assertions all passing | `docs/status-ledger.md:40` | `tests/schema_assertions.sql`, run via `package.json:16` | File yes, environment no. Re-run here: 28 `ok` lines, exit 0, against a reconstructed shim | DIVERGENT (R-3-3) |
| Backfill path, kernel: `create_vessel_with_wine` asserted | `docs/status-ledger.md:53` | `tests/schema_assertions.sql:253-288` | Same. Re-run here: "vessel, lot, placement and two codes in one action" passes | DIVERGENT (R-3-3) |
| Inferred history generation: `generate_inferred_history` asserted | `docs/status-ledger.md:58` | `tests/schema_assertions.sql:290-320` | Same. Re-run here: history generated, every event stamped `inferred`. The assertion seeds its own template; production seeds none, which S-17 names | DIVERGENT (R-3-3) |
| Row-level security, policies exercised with three accounts | `docs/status-ledger.md:39` | `tests/schema_assertions.sql:343-408` | Same. Re-run here: 5 RLS assertions pass. Row's own caveat matches S-7 exactly | NOT A DEFECT for the grade; UNVERIFIED for the wiring (R-3-16) |
| Backfill path, screens: written, typechecked, built, never run | `docs/status-ledger.md:54` | `bun run typecheck`, `bun run lint`, `vite build` | Yes. Re-run here: all three exit 0 | NOT A DEFECT |
| Sign up and account claim: `claim_account` asserted, screens unrun | `docs/status-ledger.md:55` | `tests/schema_assertions.sql:109-140` for the function; nothing for the screens | Function yes, screens no | EXPLOITABLE (R-3-1). The row is honest about the screens being unrun and does not know they are unrunnable |
| First run, facility party: screen written | `docs/status-ledger.md:56` | None. `walk.ts:175-231` exists and no check touches it | No | UNVERIFIED. Only a first run tells you whether the explanation lands |
| Code binding by camera: zxing, never run against a camera | `docs/status-ledger.md:57` | `bind_vessel_code` asserted at `tests/schema_assertions.sql:222-250`; the camera itself unchecked | Binding yes, camera no | UNVERIFIED (R-3-18) |

### 2. The definition of done, command by command

| Command | Script exists? | Does what its name says? | Can it pass today? |
|---|---|---|---|
| `supabase db reset` | `package.json:14`, aliased `db:reset` | Presumed | Not checkable here. Never run by anyone (R-3-13) |
| `psql < tests/schema_assertions.sql` | File exists | Yes, 28 assertions in one rolled-back transaction | Only after `supabase db reset` or an uncommitted shim. As literally written, with no database argument, it exits 3 (R-3-3) |
| `bun run typecheck` | `package.json:11` | Yes | **Yes.** Exit 0 |
| `bun run lint` | `package.json:12` | Yes, Biome recommended preset | **Yes.** Exit 0, 20 files |
| `bun run test` | **No** | n/a | **No.** Exit 1, no such script (R-3-2) |
| `bun run doctor` | `package.json:15` | No. It echoes and exits 1 | **No,** deliberately (R-3-12). Replay fixtures do not exist either; `docs/status-ledger.md:80` grades them Specified |

Two of six cannot succeed against the tree as committed, one by design and one by
omission, and a third cannot be attempted in any environment the repository has ever met.

### 3. Verified "by script"

One claim in either report attaches itself to a script:
`docs/session-reports/2026-09-08-scaffold.md:106-107`, the dependency graph. No script
file is tracked anywhere in the repository. See R-3-4, where the invariant it checked is
shown to have broken for five commits immediately afterward. The scaffold report's other
verification lines are either reproducible commands (`git check-ignore`, `bun run
typecheck`, `bun run lint`, `bun run doctor`) or SQL now superseded by the committed
assertion file, and the walk report's are the assertion file plus `typecheck`, `lint` and
`vite build`. Those are committed. The one narrative check with no artifact at all is the
walk report's "the built app boots in a 390 pixel viewport with no page errors and no
horizontal scroll" at `:125-127`, which is a browser observation with nothing in the tree
that repeats it.

### 4. The typed-header graph

**Sound.** Sixteen headered files, forty-nine declared relations, every edge bidirectional,
no edge pointing at a path that does not exist, no headered file without an inbound
reference. Reconstructed independently, including the multi-line SQL comment headers on
all five migrations and the assertion file. This is the cleanest thing in the repository
and the last commit on the branch is what made it so. See R-3-4 for what that implies
about the next commit.

### 5. Ledger cross-references

Both directions hold. Every sorry id referenced anywhere in the tree, S-1 through S-17,
exists in `docs/sorry-ledger.md`; every id defined there is referenced somewhere. Every
compost id referenced, C-1 through C-6, exists in `docs/compost-ledger.md`, and the
reverse holds. Every axiom referenced, T0-1 through T0-5 and T1-1 through T1-4, is defined
in `packages/cellar/docs/spec.md:44-68`. The one string that looks like a dangling sorry,
`S-023`, is a vessel sticker code at `tests/schema_assertions.sql:228`. The single row
graded Deferred, `docs/status-ledger.md:43`, names C-6, and C-6 exists and carries a
reactivation condition, which is the ledger's own requirement met.

Internal contradictions found: R-3-5 (status ledger summary against its own table, and
the sorry ledger's Discharged section), R-3-6 (two rows of one table against a third), and
R-3-7 (CLAUDE.md's count against the compost ledger, and the compost ledger's opening
sentence against two of its own entries).

### 6. Style compliance

**Clean.** Zero U+2014 and zero U+2013 across all 42 tracked files and across all seventeen
commits reachable from either ref. The convention holds as a fact and not as a check,
which is R-3-8.

---

## What is sound

The typed-header graph at this SHA, the ledger cross-references in both directions, the em
dash convention as a matter of fact, and the twenty-eight assertions, which are a real
check of real constraints and which pass. `bun run typecheck`, `bun run lint` and `vite
build` all exit 0 against the committed tree. `packages/core/src/kernel.ts` is a thin pass
through with no business rule computed on the client side, which is the hard rule at
`CLAUDE.md:62-66` actually honoured in code rather than only asserted. S-7's phrasing, the
`storage` guard's comment at `0005:302-307`, and the walk report's unverified table are
three places where the repository states the boundary of what it checked more precisely
than this review would have needed it to.

The pattern across the findings is narrow. The design documents are accurate about design
and the session reports are unusually honest about what they could not exercise. What
fails is the layer between them: claims that were true when written and that nothing
re-checks. Four of the eleven DIVERGENT findings are stale sentences that outlived the
code they described, and one of them, R-3-4, is a documented case of the invariant
breaking and staying broken for five commits because the only thing that had ever checked
it was a session that had ended.
