---
Type: reference
Purpose: "Explains what the review corpus is, how to read a report against a tree that has moved, and why the findings ledger rather than any report is the thing to act on."
Depends on: [docs/review/CURRENT-BASELINE.md]
Depended on by: [docs/findings-ledger.md]
---

# The review corpus

Thirteen review prompts run across three engines in September 2026, sixteen runs,
roughly 200 findings. `prompts/` holds every prompt at the version it was run at, plus
`W-1-verification-surface.md`, the work prompt that brought the corpus into this tree.
`reports/` holds one file per run, named by prompt and engine.

## The ledger governs

`docs/findings-ledger.md` is the deduplicated result and the thing to act on. These
reports are evidence for its entries, not a second list of work. Where a report and the
ledger disagree, the ledger is what was decided, and the disagreement is worth reporting
rather than silently resolving.

## Locators are stale by design

Every report cites `path:line` against `c3eae3c7c262544e4b2e29526b513c964c6852fe`, which
was `main` at 42 tracked files and five migrations. One engine's line numbers drift by up
to twenty lines even at that commit. Grep the identifier, never the line. That is why the
ledger is keyed by policy name, function name and constraint name instead.

## Provenance and method

Each report states its engine, its access tier, and whether it executed anything. Six runs
built a Postgres 16 cluster, wrote an auth shim, applied the five migrations and probed
under `set role authenticated`; the rest read. A finding marked probed is an observation
and a finding that is not is a reading, and the reports say which.

`G-1-chatgpt-aborted.md` found nothing and is kept deliberately. It is the clearest
evidence in the set about how the acquisition ladder behaves in a sandbox with no egress,
and it is the reason the ladder was rewritten afterwards.

`G-1-claude-code.md` reports 22 assertions where every other run reports 28. That is a
deficient shim, settled on the third independent run, and it is why `W-1` specifies the
shim exactly rather than leaving it to invention.

## Convergence counts are in the ledger

The Found column in the ledger is how many separate runs confirmed a defect. Do not
recount it from the corpus.

## The tree moved under this corpus

The baseline is five migrations, 42 files and 28 assertions. The corpus landed in a tree
of twenty migrations, 61 files and 107 assertions, on Postgres 17 rather than 16. Nine
entries were already discharged on arrival by work done between the baseline and the
archive, and the session report for the archive says which. Two consequences worth
carrying:

The ledger reserves migration `0006` for its section A. That number was spent before the
corpus arrived, so section A lands wherever the numbering has reached.

A report describing a file that no longer exists is not wrong, it is dated. Check the
ledger's disposition before concluding that a finding is stale, because several of them
predicted defects in code written after the review and were right.

## These files carry no typed header

The prompts and reports are terminal. Nothing in the tree depends on them and they depend
on nothing, and giving them headers would enter them into the dependency graph as things
other documents rely on, which inverts the relationship. `scripts/verify.sh` must exempt
`docs/review/prompts/` and `docs/review/reports/` from the header check and from the em
dash check explicitly, with a comment saying why: the reports are full of em dashes and
were written by engines that never read this repository's style rule.

Several reports quote `CLAUDE.md`, `spec.md` and the ledgers at length. Any check that
greps for a phrase across the tree will find it here, so scope such checks to source and
documents rather than to everything tracked.
