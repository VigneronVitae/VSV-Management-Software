# W-1: the verification surface

**Repository:** github.com/VigneronVitae/VSV-Management-Software
**Baseline:** `c3eae3c7c262544e4b2e29526b513c964c6852fe`, branch `main`, 42 tracked files
**Mode:** write. This is work, not review.

---

## What you are given

Two documents accompany this prompt and both are authoritative.

`architecture-rulings.md` v2.0 records every architectural decision governing the planned
decomposition of this system into installable modules. It is a ruling document, not a
proposal. Where it conflicts with your judgment, follow it and say so in your report.

`findings-ledger.md` v1.0 deduplicates thirteen review reports into 73 distinct defects,
keyed by identifier rather than by line number. Section C and section D are in scope for this
session. **Sections A, B and E are out of scope.** Do not fix them, do not work around them,
and do not mention them in commits.

Read both before touching the tree. The ledger's dispositions are the plan; this prompt is
the first step of it.

---

## Scope

Four things, in order, and nothing else:

0. Archive the review corpus, so the ledger has visible evidence behind it.
1. Commit the auth shim, so the tree can verify its own claims.
2. Build `scripts/verify.sh` and wire it to `bun run verify`, so the document layer has a
   checker.
3. Fix the document defects the checker now catches.

The theme is that this repository currently asserts things about itself that nothing tests.
The goal of this session is that every claim in the tree is either true or failing a check.
No schema change. No client behaviour change. No new dependency without asking.

---

## 0. The archive

Thirteen review reports and their fourteen prompts accompany this prompt. They go into the
tree as corpus.

Layout, or something close to it if the tree's conventions suggest otherwise:

```
docs/review/
  README.md
  prompts/      R-1 .. R-6, G-1 .. G-6, A-1
  reports/      one file per run, named <prompt>-<engine>.md
```

Name reports by prompt and engine, because provenance is the point: `R-1-chatgpt.md`,
`R-1-claude-code.md`. Keep every duplicate. Keep the aborted G-1 run, which produced no
findings and is the most useful single artifact in the set about how the acquisition protocol
behaves under a sandbox with no egress.

`docs/review/README.md` states four things and should be short.

**The ledger governs.** `docs/findings-ledger.md` is the deduplicated result and the thing to
act on. The reports are evidence for its entries, not a second list of work. Where a report
and the ledger disagree, the ledger is what was decided and the disagreement is worth
reporting, not silently resolving.

**Locators are stale by design.** Every report cites `path:line` against
`c3eae3c7c262544e4b2e29526b513c964c6852fe`, one engine's line numbers drift by up to twenty
lines even at that commit, and the schema reorganization will move everything. Grep the
identifier, never the line. That is why the ledger is keyed the way it is.

**Provenance and method.** Which engine, which tier, whether it executed. Three runs built a
Postgres and probed; the rest read. A finding marked probed is an observation and a finding
that is not is a reading, and the reports say which.

**Convergence counts are in the ledger, not here.** Six reports finding one defect is in the
ledger's Found column. Do not recount from the corpus.

These files get no typed header. They are terminal: nothing depends on them and they depend
on nothing, and giving them headers would put them in the dependency graph as things other
documents rely on, which inverts the relationship. The `verify.sh` header check in step two
must therefore exempt `docs/review/reports/` and `docs/review/prompts/` explicitly rather
than by accident, and the exemption belongs in the script with a comment saying why.

Two smaller things. The reports are full of em dashes, so the em-dash check in step two needs
the same exemption or the archive fails the repository's own style rule on arrival. And
several reports quote `CLAUDE.md`, `spec.md` and the ledgers at length, so any future check
that greps for a phrase across the tree will find it in the corpus; scope such checks to
source and documents rather than to everything tracked.

---

## 1. The shim

Three review runs independently reconstructed a Postgres stand-in, applied all five
migrations, and ran `tests/schema_assertions.sql`. None of them committed it, so four grades
in `docs/status-ledger.md` rest on an artifact that does not exist in the tree. That is D1.

Build it to this spec exactly, because reports that used different shims reported different
assertion counts and the divergence took three runs to settle:

- Postgres 16.
- An `auth` schema with a `users` table.
- `auth.uid()` returning the JWT subject, reading `request.jwt.claim.sub` first and falling
  back to the `request.jwt.claims` blob.
- Roles `anon`, `authenticated`, `service_role`, with Supabase's default grants on `public`.
- An empty publication named `supabase_realtime`.
- No `storage` schema.

Put it at `tests/shim.sql` or wherever fits the tree's conventions, and wire it into the
existing `db:test` path so that a bare Postgres plus the shim plus the five migrations plus
the assertions is one command.

**The expected result, which you should confirm rather than assume:** five migrations apply
clean, 28 assertions run, 28 pass, and the storage-guarded block in `0005` is skipped with
its own notice. If you get a different number, that is a finding and it goes in your report.

**One asymmetry to document in the file.** `0005` guards its storage block on the schema
existing and says so. `0002` has no equivalent guard and cannot apply to a bare Postgres
without the shim. So the shim is a convenience for `0005` and a dependency for `0002`. A
comment at the top of the shim naming which migration needs which part is worth more than
the code, because the next person will otherwise assume it is optional.

---

## 2. The verifier

`scripts/verify.sh`, wired to `bun run verify`. Bash and standard tools. No new dependency.
Exit non-zero on any failure, with a message naming the file and what is wrong.

Each check below corresponds to a rule this repository states and does not enforce.

1. **The typed-header graph.** Every document carries `Depends on` and `Depended on by`.
   Reconstruct the graph across all headered files including migrations. Fail on: a
   one-directional edge, an edge naming a path that does not exist, and a headered file no
   other file points at. A session report says this was "checked by script" and the script
   was never committed; the invariant it guards broke silently for five commits. That is D4.

2. **The em-dash rule.** Stated absolutely in `CLAUDE.md`. Fail on any em dash in any tracked
   file. Consider also checking commit messages if that is cheap. D9.

3. **Ledger cross-references.** Every sorry id referenced anywhere in the tree exists in
   `docs/sorry-ledger.md`. Every compost id referenced exists in `docs/compost-ledger.md`.
   Every status-ledger row graded Deferred names a compost entry, since the ledger's own
   definition of Deferred requires one. Every compost entry has a reactivation condition,
   since `CLAUDE.md` says they all do.

4. **Counts stated in prose.** `CLAUDE.md` says the compost ledger holds five entries and it
   holds six. Rather than fixing the number and leaving it to rot, have the checker derive
   the count and compare. Same for any other count stated in prose that is derivable.

5. **The definition of done exists.** Every command named in `CLAUDE.md`'s definition-of-done
   block resolves to a script in `package.json`. `bun run test` currently does not and
   silently executes `/usr/bin/test`, which is C1 and was found by seven separate reports.
   The check is that the command exists, not that it passes, because `doctor` is a stub by
   design and that is filed as S-4.

6. **Internal contradiction in the status ledger.** `docs/status-ledger.md` opens with
   "Nothing is built" and grades four rows Built and verified. A general checker for this is
   overreach; a specific one that fails if that phrase coexists with a Built row is honest
   and takes three lines.

7. **The module import rule.** `CLAUDE.md` says a module may import from `core` and never
   from a sibling, and says lint will enforce it once there is code to enforce it against.
   There is now. A review found Biome can express this with no new dependency; if that holds,
   put it in `biome.json` rather than in the shell script, since the closer to the compiler
   the better. If it does not hold, a grep in `verify.sh` is acceptable.

Do not add CI in this session. The checks have to exist before a pipeline can run them, and a
workflow file written now would be the only thing in the tree nobody has run.

---

## 3. The document fixes

Section C of the ledger, twelve entries. Most are mechanical once step two is failing on
them. Fix them so `bun run verify` passes.

Four need judgment rather than editing.

**C4, `config.toml:22`.** `major_version = 16` is refused by current Supabase CLI during
config validation, before any Docker work. 15 and 17 both pass. So the one Postgres major
this project has verified against is the one the tooling will not run, and the documented
setup path cannot start for anyone whose instance does not already exist. Do not change the
value silently. Either re-run the five migrations and 28 assertions against Postgres 17 and
change it with the evidence recorded, or leave it at 16 and add a comment naming the CLI
versions that accept it plus a README note. State which you did and why. If you re-verify
against 17, that result belongs in the session report as a number.

**C5, the hosted project's auth settings.** They exist nowhere in the repository, so the
state governing the live instance is unversioned and invisible to every review. This cannot
be fixed by editing a file. Write down what the repository can say: which settings matter,
what they should be, and that `config.toml` governs only the local stack. A short
`docs/hosted-settings.md` with a typed header, or a section in the README. Flag it as an open
question if you think it needs a ruling rather than a document.

**C6, `0001_core_schema.sql`.** Its header comment describes a schema that no longer exists
after `0003`, `0004` and `0005`. Do not rewrite migration history. The fix is either a
correction note in the header saying what superseded it, or a current schema description
living somewhere that is not a migration. Prefer the second and say where you put it.

**C10, the topping threshold.** S-1 says it is unchosen and the code chose 100% silently.
Do not choose it. Correct the sorry ledger to say what the code does and that the choice is
undeliberate, which is the honest state.

Leave `C2`'s underlying grades alone in one specific sense: fix the contradiction, but do not
upgrade any row to a stronger grade than the evidence supports. After the shim lands, four
rows become genuinely reproducible and can say so. Nothing else changes.

---

## What not to do

Do not fix anything in section A, B or E of the ledger, however small or however obvious it
looks while you are in the file. `0006` is a single migration written after the schema split
and pulling one policy fix forward means writing it twice. The client defects are a separate
session for the same reason.

Do not reorganize the schema, move tables between schemas, or start per-module migration
numbering. That is step five of the plan and it depends on work that does not exist yet.

Do not add a dependency without asking. `CLAUDE.md` states this and the Supabase CLI pin
discussed under C4 is exactly the case it is about.

Do not upgrade a status-ledger grade on the strength of a check you wrote in this session
without running it.

---

## Done means

`bun run verify` passes from a clean checkout. The shim is committed and a bare Postgres plus
the documented command reproduces 28 of 28. Every check in step two fails loudly when you
deliberately break the thing it guards, and you have tried that for each one rather than
assuming. Section C is either fixed or, for the four judgment items, explicitly ruled on in
writing.

The tree grows by roughly thirty files, most of them corpus. Anything in the repository that
states 42 needs updating, and the checker should derive that number rather than carry it.

---

## Report

A session report in `docs/session-reports/`, matching the convention of the two that exist,
with a typed header and an entry in the index. It should say:

Where the corpus landed and what the archive README says. What the shim reproduces, as
numbers. What each check in `verify.sh` guards and how you
confirmed it fails when it should, which is the part that separates a checker from a
decoration. Which of C4, C5, C6 and C10 you ruled which way and on what grounds. Anything in
section C that turned out to be wrong in the ledger, because the ledger is derived from
reports and has not been checked against the tree by anyone.

And one thing the ledger cannot tell you: while you are in these files, note anything that
looks like a defect nobody found. Thirteen reports read this tree and a fourteenth pass with
write access sees it differently. New findings go in the report, not in the code.
