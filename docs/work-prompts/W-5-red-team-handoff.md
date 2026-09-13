# W-5: hand the tree to a red team

**Repository:** github.com/VigneronVitae/VSV-Management-Software, branch `main`
**State:** W-4 complete and green at `0027`. Six commits unpushed or partially pushed.
**Mode:** write, short session. This is a handoff, not development.

---

## Why

Everything since W-1 is one agent writing migrations and the same agent reviewing them.
Migrations `0021` through `0027` have never been read by anything independent, and that range
includes both enum conversions and the A22 permission split. The assertion suite and
`scripts/mutate.sh` are both agent-authored, every gate decision for three sessions was made
with them, and the `tgenabled` fingerprint bug showed the harness can report a clean score
while silently skipping a whole check.

The next reviewer needs a tree that states its own current condition accurately. That is the
whole job here.

---

## Do

**Push everything.** Confirm `main` is clean, all six commits are pushed, and the remote head
matches local. Report the sha.

**Restate the baseline facts.** Every review prompt in `docs/review/prompts/` carries a canary
block naming `c3eae3c7c262544e4b2e29526b513c964c6852fe`, 42 tracked files, and four files
whose presence identifies the tree. All three are now wrong. Do not edit the archived prompts,
which are corpus. Instead write `docs/review/CURRENT-BASELINE.md`: the current head sha, the
current tracked file count derived rather than typed, the current migration range, and a
replacement canary set of four to six files that identify the tree as it stands now. Say
plainly that the archived prompts' canary blocks are historical and this file supersedes them.

**Make the instruments findable.** A short section in that same file naming what a reviewer
should know exists: `tests/shim.sql` and what it does and does not provide, `scripts/mutate.sh`
and its eight classes and which seven derive from the catalog, `bun run green` and the six
gates it runs, and the A25 allow-list and where it lives. A reviewer who does not know the
harness samples function bodies by hand will read the 100% wrong, and that is the single most
important sentence in the handoff.

**Update the ledger's own header.** `docs/findings-ledger.md` describes a tree of 42 files and
five migrations. Bump it, note the current range, and record which entries have been
discharged since. Do not re-derive the whole ledger; just make its front matter true.

**Verify the story.** Run `bun run green` from a clean clone of the pushed remote, not from
your working tree. Report every number it prints. If anything differs from what the session
reports claim, that difference is the most useful thing in this session and goes at the top of
the report.

---

## Do not

Start phase 6. Fix anything in section A or B. Add assertions. Touch the archived prompts or
reports. Add CI.

---

## Report

Short. The pushed sha, the numbers from the clean-clone run, what `CURRENT-BASELINE.md` says,
and anything that did not match.
