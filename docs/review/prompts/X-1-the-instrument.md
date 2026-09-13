# X-1: the instrument

**Target:** github.com/VigneronVitae/VSV-Management-Software, branch `main`, at or after `72612e7`
**Scope:** this repository only.
**Date:** 2026-09-12
**Part of:** the second review round, X-1 through X-3. Self-contained. Run it alone.
**Run this on a different engine than the one that wrote the code, if you have one.**

---

## Obtaining the code

**The default branch was wrong until recently and the old canary confirmed it.** Thirteen
earlier prompts in this series carried a check that verified branch, file count and four named
files. Every one of those checks passed against a tree thirty-one commits stale, because the
work sat on a side branch and `main` still pointed at the reviewed baseline. The check did not
decay. It kept working and the thing it identified moved. Read
`docs/review/CURRENT-BASELINE.md` first; it supersedes every canary block in the archive.

**Try in order, stop at the first that works.**

1. `git clone https://github.com/VigneronVitae/VSV-Management-Software`
2. `git clone --depth 1 https://github.com/VigneronVitae/VSV-Management-Software`
3. `gh repo clone VigneronVitae/VSV-Management-Software`
4. `curl -L https://codeload.github.com/VigneronVitae/VSV-Management-Software/tar.gz/refs/heads/main | tar xz`
5. Per-file over `https://raw.githubusercontent.com/VigneronVitae/VSV-Management-Software/main/PATH`

A `Could not resolve host` from the shell says nothing about a browsing or fetch tool in the
same session. Retry routes 4 and 5 on every surface before concluding anything.

**Confirm you have the right tree.** Head should be `72612e7` or a descendant, roughly 112
tracked files, migrations `0001` through `0027`. Identity comes from what the tree contains,
not from where it is parked: `scripts/mutate.sh`, `tests/shim.sql`, `scripts/verify.sh` and
`docs/review/CURRENT-BASELINE.md` exist now and existed nowhere in this repository's history
before September. If you have a tree with 42 files, five migrations and no `scripts/`
directory, you have the baseline the previous corpus already reviewed. Stop and re-clone.

Cite `path:line` if you cloned. If you are reading through anything that may truncate, cite
the file plus a quoted identifier and no line numbers.

---

This prompt has no predecessor. It is the important one.

## Why it exists

Four consecutive work sessions were written and reviewed by the same agent. Every gate
decision in them was made with two artifacts that agent authored: `tests/schema_assertions.sql`
and `scripts/mutate.sh`. The suite reports 198 of 198 mutations caught. An earlier independent
measurement, at 28 assertions, reported 42%.

Three times in this repository a green check has been proven hollow only by deliberately
breaking something. A harness guard failed open because `tgenabled` is `"char"` and needed a
cast, so degeneracy detection silently skipped every mutation while the score printed clean.
An assertion for the null-permit class passed, would have passed forever, and was inert. And a
canary block verified a tree that was thirty-one commits stale while reporting full marks.

**Your question is whether the instruments measure what they claim.** Not whether the schema
is correct. The instruments.

## What to do

1. **Break every assertion.** Remove or neuter each assertion in
   `tests/schema_assertions.sql` one at a time and confirm the suite fails, and fails naming
   the thing you removed. An assertion whose removal changes nothing is inert. An assertion
   that fails with a message pointing elsewhere is worse than inert, because it will send the
   next person to the wrong place.

2. **Break every check in `scripts/verify.sh`.** Same method. Each check is a claim about the
   tree; confirm each fails when its claim is falsified, and only then.

3. **Audit the harness for fail-open paths.** `scripts/mutate.sh` has eight mutation classes.
   For each: what happens when the enumeration query returns empty, when a catalog type needs
   a cast, when a mutation fails to apply, when the database errors mid-run. The `tgenabled`
   bug is one instance of a class. Find the rest. A harness that reports a clean score with a
   silently empty enumeration is the defect to hunt.

4. **Check the provenance of every reported number.** One session reported 20 exclusions where
   the run beside it produced 21, because a partial re-run of one class was carried forward as
   if it were a full run. Does the harness's summary state what it was computed from? Can a
   number be printed that did not come from the run it appears beside?

5. **Audit the A25 allow-list.** It has one entry. Confirm that entry belongs there and that
   nothing else should be on it. An allow-list is where a derived check goes to die.

6. **Probe the sampled class.** Seven of eight classes enumerate from the catalog and grow
   with the schema. The eighth is ten hand-chosen function-body substitutions. Write three
   substitutions the author did not choose, apply them, and report whether the suite catches
   them. That is the direct test of whether 198 of 198 means anything about the procedural
   surface.

7. **Check `bun run green` end to end.** Six gates. Does each one actually run, in a clean
   clone, and does a failure in any one fail the whole command?

Report the assertion count, the count that is inert, the count that fails misleadingly, and
every fail-open path found. If the instruments hold up, say so plainly and in one paragraph;
that result is as valuable as the alternative and less likely.

---

## Note on pushing and permissions

You are not expected to write in this session. If a tool call is refused by a permission
classifier rather than by git or the filesystem, that is the classifier. A retry is the correct
response and a workaround is not.

---

## Verdict scale

| Verdict | Meaning |
|---|---|
| EXPLOITABLE | A concrete path exists against the tree as it stands. State the steps. |
| LATENT | Real and currently unreachable. Name the change that reaches it. |
| DIVERGENT | Code and document disagree. Neither asserted wrong. |
| BY DESIGN | Named somewhere as deliberate. Cite the entry. |
| NOT A DEFECT | Checked, and it holds. |
| UNVERIFIED | Not checkable without something unavailable. |

## Scale bound

About 50 vessels, two labels, two custom crush clients, five to ten users, low thousands of
events a vintage. A defect needing a thousand vessels is LATENT, not EXPLOITABLE, and say what
volume reaches it.

## Finding format

```
**X-1-n. One line naming the defect.**
*Verdict:* one of the six.
*Locator:* path plus identifier. Never a bare line number.
*What is wrong:* two or three sentences.
*How it surfaces:* the concrete situation, or "silently, never."
*Resolves when:* the specific condition. Not a patch.
```

Open with a table of every finding, one line each. Group by verdict, EXPLOITABLE first.

## Closing instruction

Do not try to be reassuring. If a part of this is sound, say so in one line and spend the
space elsewhere. Mark UNVERIFIED and say what would check it rather than reasoning your way to
a verdict you did not earn. Report predictions that turned out false; in this series that
disclosure has been the most reliable signal that the probes were real.
