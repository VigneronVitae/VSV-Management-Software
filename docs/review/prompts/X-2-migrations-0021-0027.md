# X-2: migrations 0021 through 0027

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

A rebaseline of R-5 and G-4 onto the range nothing independent has read.

## Scope

Migrations `0021` through `0027`. Everything before `0021` was reviewed by the earlier corpus.
This range includes both enum conversions, the A22 permission split, and the fixes for
findings the same agent filed.

Read `docs/findings-ledger.md` first. You have an advantage the original runs did not: you
know which defect classes this tree produces, so check whether each recurs in the new code
rather than hunting blind.

## The five known classes

For every object added or changed in this range:

**The null-permit class, A25.** A predicate that cannot determine an answer permits instead of
refusing. Three instances so far: `coalesce(..., true)` in `is_facility_user()`,
`may_see_all_of` returning null, and a check constraint reading `false or null`. The cause was
narrowed to untyped JSON reads flowing into boolean contexts. Every `->>` result entering a
predicate is population. So is every `attributes` bag on `node`, `vessel` and `term`, which is
where per-domain extension will land.

**The silent-refusal class, A13.** RLS denials are zero-row matches, not errors. Does a
refused write in this range return zero rows or raise? A22's permission split is the obvious
place to check.

**The caller-context class, A14.** Write paths running as the invoker against admin-only
policies. Six functions fixed in `0021`, a seventh found later in `bind_vessel_code`. Is there
an eighth in this range?

**The blanket-read class, A5.** `0002` put `using (true)` on thirteen tables and `0003`
narrowed one. `vessel_type_note` repeated it. Did anything in this range add a table with the
same default?

**The stored-derivation class, A18 and A19.** A derived value stored with nothing recomputing
it and nothing detecting staleness.

## Specific to this range

`0026` deletes `subject_type` into the resolver registry. `0027` moves `term_kind` across nine
generated columns, nine composite foreign keys, four views and two typed defaults. Two traps
were caught by reading rather than by any instrument: dropping a generated column moves it to
the end of the table, and a view reading through a positional alias list silently rebinds; and
a validator proving a vocabulary exists by casting to an enum would have become a validator
that always succeeds if the cast were rewritten to `::text`.

Both are invisible to the assertion suite and to the mutation harness. **Look for a third.**
Every column moved, every view with a positional alias list, every validator whose proof is a
cast failure.

`0025` implements the A22 ruling: bind an unbound code as any worker, rebind only as admin,
with the refusal naming the barrel rather than its uuid. S-43 records that the permitted path
leaves no trace. Probe both halves and assess the untraced bind against A17's class, where a
correct-looking screen produced a record that could not answer who did it.

## Execution

Build the shim to `tests/shim.sql`, apply all twenty-seven migrations, run the suite, and probe
under `set local role` as: an admin, a cellar user, a custom crush client with a party row, an
authenticated principal with no `app_user` row, and `anon`. Never as the migration owner; RLS
does not apply to a table owner and a superuser probe proves nothing.

Mark every executed finding as probed.

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
**X-2-n. One line naming the defect.**
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
