# X-3: the documents against the tree

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

A rebaseline of R-3 onto a tree that has doubled and now carries four ledgers, a rulings
document, a progress file, four session reports and an archived review corpus.

## Why this one is different now

At the baseline this prompt found a status ledger that opened with "Nothing is built" above
four rows graded Built and verified. The document layer has since acquired a checker,
`scripts/verify.sh`, and a great deal more prose. The question is no longer whether the
documents contradict the tree. It is whether the checker makes them true or merely makes them
consistent.

## What to do

1. **Every maturity claim against the tree.** `docs/status-ledger.md`, the sorry ledger, the
   compost ledger, the findings ledger, `CLAUDE.md`, the rulings document, and four session
   reports. For each claim: locate the artifact, locate the check, and say whether the check
   is a committed runnable thing or a sentence.

2. **What `verify.sh` does not check.** This is the substance of this prompt. Enumerate every
   rule stated anywhere in the document layer, then subtract the ones the checker covers. The
   remainder is the current unenforced surface. Rank it by how silently each would break.

3. **The exemption list.** `verify.sh` carries exemptions: the archived corpus for em dashes
   and for the header graph, and a narrowed count-check exemption. Every exemption is a hole
   with a reason. Confirm each reason still holds and that no exemption is broader than its
   reason requires.

4. **The ledgers against each other.** Every id referenced anywhere resolves. The findings
   ledger cites `AR-` ids that must exist in the rulings document. The rulings document cites
   sorry and compost ids. A cross-reference that resolves to nothing is what caught the `E-4`
   dangle; find the others.

5. **Discharged entries.** Nine ledger entries discharged themselves when the wire session
   landed. Since then more have been fixed. Is the ledger's record of what is discharged
   accurate, or does it still list as open things the tree has fixed, and the reverse?

6. **The session reports as claims.** Four exist and they are append-only by convention. Each
   reports numbers. Recompute them. One has already been found to carry a forward-carried
   count from an earlier partial run. Check the others: every score, every assertion count,
   every file count, every "verified" against what the tree does now.

7. **`docs/review/CURRENT-BASELINE.md`.** It supersedes the canary blocks in thirteen archived
   prompts. Confirm its counts are derived and correct, that its six replacement canaries
   genuinely identify this tree and no earlier one, and that nothing else in the tree still
   states the superseded figures.

Report as a table of Claim / Locator / Supporting check / Verdict. A claim that is true and
unenforced is DIVERGENT, not NOT A DEFECT, because this prompt is about which claims a future
edit can silently falsify.

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
**X-3-n. One line naming the defect.**
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
