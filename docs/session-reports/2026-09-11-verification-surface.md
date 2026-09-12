---
Type: record
Purpose: "Records the session that archived the red team corpus, gave the repository a checker, and closed the write paths and the four cheapest exploitable findings, including the defect the corpus predicted four days before the code that contained it existed."
Depends on: []
Depended on by: [docs/session-reports/index.md]
---

# 2026-09-11: the verification surface

The session that ran W-1 against a tree the reviews had never seen.

## What arrived, and what it cost that the tree had moved

A handoff bundle: thirteen review prompts run across three engines, sixteen runs,
deduplicated into a 73-defect findings ledger and a 62-ruling architecture document.
Six of the runs built a Postgres 16 cluster, wrote an auth shim, applied the
migrations and probed under `set role authenticated`. They disclose their own
falsified predictions. One run found nothing because it had no egress and stopped
correctly, and was kept for that reason.

Every report carries a canary check against 42 tracked files and five migrations. The
tree they were handed to has 96 files and 22 migrations, because the wire session
happened in between. W-1 reserves migration `0006` for section A and `0006` through
`0020` were already spent.

That cost less than it looked. The ledger is keyed by policy name, function name and
constraint name precisely so that it survives the tree moving, and it does. Checked
against the current tree, nine entries were already discharged on arrival and the rest
were greppable exactly as promised. Two were made worse by work done after the review,
which is recorded in the ledger's new progress section rather than left for somebody
to notice.

## The finding nobody in the corpus could have made, which the corpus made anyway

A14 says: the `placement` update policy is admin only, so racking is refused the day it
is built, silently. Racking was built five days later, in `0014`.

None of the write paths added in `0007`, `0008`, `0013`, `0014`, `0015` or `0019` is
`security definer`. They run as the caller, against the admin-only update policies
`0002` put on `node`, `placement` and `vessel`. Probed as a cellar user, with the row
present and visible:

```
update placement set to_at = now()   ->  UPDATE 0
update node set status = 'closed'    ->  UPDATE 0
update vessel set capacity_l = 900   ->  UPDATE 0
```

Three zero-row updates, no error, no message.

The consequence is worse than nothing happening. `rack()` closes the source placement
and inserts the destination one, and inserts were open while updates were not, so a
cellar user racking a barrel got the destination without losing the source: the same
wine in two vessels, and the kernel returning its success payload. `update_vessel()`
reads its result back with `returning *`, gets no row, compares the resulting nulls
against the old thermal triple, finds them distinct, and writes a `setpoint_change`
event recording that the vessel now has no jacket, no setpoint and no mode. A silent
refusal produced a confident false record.

Everything built in the wire session worked because it was tested as the only admin in
the database.

`0021` fixes it with permissive update policies alongside the admin ones and a column
allow-list on three triggers, rather than by making six functions `security definer`.
Two reasons. It does not require restating eighteen kilobytes of function bodies that
would then exist in two migrations and drift. And it keeps the refusal loud: a cellar
user who touches a protected column is told which column, where before they were told
nothing at all. `owner_id` and `hidden` are deliberately absent from every list.

Creating a vessel stays admin only, because the assertion suite already said so on
purpose and a vessel is a structural fact in the same class as a location.

One bug in that work was caught by probing rather than by reading: a generated column
is computed after every before-trigger has run, so it reads null in `NEW` while `OLD`
carries its real value, and the first version of the trigger reported
`node.product_kind` as changed on every update anybody made.

## The suite could only ever run from empty

Three assertions assert properties of a winery that does not exist yet: that no node
can be created before the facility party, that exactly one facility party may be
active, that the first claimant becomes admin. All three are true only of an empty
database. The cellar database has had a facility party in it since the winery was
named, so the suite died at assertion three.

That put the definition of done at war with itself. It says run the assertions. It also
says use `db:up` rather than `db:reset`, because reset takes the inventory with it, and
that instruction was added in the previous session in answer to the winemaker asking
whether the app always has to destroy what he enters.

The suite now stands any existing facility party down for the duration and rolls it
back, and the first-claimant rule asserts both halves rather than the empty one. The
half that was never asserted is the one that protects a live winery: an account claimed
against a populated `app_user` is a cellar user, not an admin.

129 assertions now, passing against the cellar database and against a scratch database
built from all 22 migrations from empty.

## The archive

`docs/review/` holds fourteen prompts and sixteen reports. `docs/findings-ledger.md`
and `docs/architecture-rulings.md` are in `docs/` as the two governing documents. The
archive README states the four things W-1 asked for, and a fifth: that the tree moved
under the corpus, because a reader opening a report needs to know it describes five
migrations.

The prompts and reports carry no typed header and are exempt from the header check and
the em dash check by name, with the reason in the script. A small correction to W-1:
it says the reports are full of em dashes, and two of the sixteen contain any, thirty
in total, both of them ChatGPT runs. The exemption is still needed and is smaller than
advertised.

## The checker, and what it found

`scripts/verify.sh`, wired to `bun run verify`. Seven checks, bash and standard tools,
no dependency added.

| Check | Guards |
|---|---|
| 1 | The typed header graph: both directions, every path resolving, no headered file nothing points at |
| 2 | The em dash rule, in tracked files and in commit subjects |
| 3 | Every `S-` and `C-` id referenced exists, every compost entry can be revived, every Deferred row names one |
| 4 | Counts stated in prose, derived and compared: compost entries, tracked files, migrations |
| 5 | Every command in the definition of done resolves to a script, and every path in it exists |
| 6 | That the status ledger's opening sentence agrees with its own grades |
| 7 | The module import rule |

Each one was broken on purpose and observed to fail before being trusted, which is the
part that separates a checker from a decoration. Ten cases: an edge to a missing file,
a one-directional edge, an orphan document, an em dash, an unfiled sorry id, a compost
entry with its reactivation line removed, a stale count, a renamed script, the ledger
contradiction restored, and a second module package importing from its sibling. All ten
were caught and the tree was restored each time.

What the first real run found:

**Forty nine one-directional header edges.** Every migration from `0006` on declared
what it depended on and not one of those parents said so in return. The invariant a
session report claimed was "checked by script" had been broken continuously since
`0006`. That is D4, and this is the second time the same invariant has been found
broken, which is the argument for the script existing.

**`bun run test` was not a script.** For eight sessions it ran `/usr/bin/test` with no
arguments and exited zero. Seven of the thirteen reports found it. It is now a script
that names what is missing and exits non-zero, the same shape as `doctor`: a command
that exists and cannot pass is honest, and one that does not exist and appears to pass
is not. S-38 records what it stands in for, which is that no test covers a line of
TypeScript, in a client where the corpus found nineteen defects.

**The compost ledger held eight entries against a rule saying five**, two of them with
no reactivation condition against a rule saying every entry has one, and one filed out
of order. Fixed. Both new reactivation conditions are marked as written by the agent
rather than by the winemaker, because a reactivation condition is a claim about when to
reconsider and these two touch how the winery runs. They are the two most likely things
in this session to be wrong.

**The status ledger opened with "Nothing is built"** above eighteen rows graded Built
and verified. True when written, false without changing, which is exactly the decay the
ledger exists to prevent, committed by the ledger itself. No grade was touched.

Two of the checker's own first findings were the checker being wrong rather than the
tree: `VS-023`, a vessel sticker in the assertions, read as a sorry id, and the archive
README's "42 tracked files" is a fact about another commit. Both are fixed in the
script where they happen, with the reason.

The module import rule reports as holding vacuously rather than as a green tick,
because with only `core` and `cellar` there is no sibling pair to examine. A check that
cannot fail should say so.

No CI, by instruction. The checks had to exist before a pipeline could run them.

## The four cheapest exploitable findings

`0022`. A1, A3, A6 and A8, which are the four one-line defects with the worst
consequences: six independent runs found A1, five found A3, five found A6, three found
A8.

**A1, probed before the fix.** As one client login, in one transaction: with the party
active, `is_facility_user()` false and zero nodes visible. With the party set inactive,
true, and the facility's lot visible by name. One `coalesce` did it. The old body asked
whether a linked party was a facility and defaulted a missing answer to true, so a
harvest intern with no party could see the cellar. A deactivated client has no findable
party row either, so the two cases became one and switching an account off promoted it.

Asking "are you a client" instead has no default to choose, and `exists` is never null.
Requiring an active `app_user` row in the same predicate discharges S-25, because an
authenticated identity that never claimed an account is now nobody here rather than
staff by default.

That made `is_facility_user()` and `0021`'s `is_cellar_staff()` the same predicate. Two
names for one question will drift, so the newer one is gone and the older one, already
used in twenty places, stays.

**A3, probed.** `event_insert` read `by_user = auth.uid() or by_sensor is not null`, so
any string in `by_sensor` unbound the author check. User A wrote an event carrying user
B's uuid and the word `anything`, and it was accepted. An author that can be chosen is
not provenance, which is what T0-3 says every event carries. The sensor branch is now
refused outright for the `authenticated` role rather than made trustworthy, because a
sensor needs an identity and a role that is not a person's. S-39.

**A6.** Both vessel-photos policies admitted every login, eighteen lines under `0005`'s
comment explaining that the bucket is private because a barrel photo shows a chalk mark
with a client's lot on it. Staff only now, in both directions. A client sees no
photographs at all, which is the honest answer while a photo records nothing about what
was in the vessel when it was taken: deriving the owner from the current placement
would show an old photograph to whoever holds the barrel now and hide it from the person
whose wine it shows. S-40.

**A8.** `claim_task` was `security definer` with no view on the caller. A null uid wrote
null into `claimed_by` while setting status to `claimed`, which satisfies neither guard
on any later attempt, so the task was wedged and no cellar user could recover it. An
open task assigned to a named person could be taken by anybody, which makes assignment
decorative. The definer stays, because claiming has to be one atomic update, and it now
does what a definer function owes: it decides who may call it.

## The judgment items in W-1 section 3

**C4, `config.toml`.** Already resolved before this session, and now with better
evidence: `major_version = 17`, with 22 migrations applying clean from empty and 129
assertions passing against it. The version the project had verified against was the one
the tooling refuses; that is no longer true.

**C10, the topping threshold.** S-1 said the threshold was unchosen. It was chosen, at
one hundred percent, silently: `0004` seeds the `topping` operation with
`"effect": "treatment"`, a treatment writes no lineage by definition, so no amount of
topping wine ever becomes a parent. Per W-1 the threshold was not chosen here; the sorry
now says what the code does and adds the consequence, which is that a barrel topped ten
times from another lot still reports as one hundred percent its original block.

**C5, the hosted project's auth settings, and C6, `0001`'s header describing a schema
that no longer exists.** Both open. C6 in particular wants a current schema description
living somewhere that is not a migration, and writing one that does not rot means
deriving it, which is a script rather than a document. Named here rather than guessed
at.

## New findings, from a fourteenth pass with write access

Four, none of them in the corpus.

**The vessel-photos bucket had no update policy.** `uploadVesselPhoto` passes
`upsert: true` to the fixed path `<vessel_id>/photo.<ext>`, so the first photograph of
a vessel succeeds and every later one fails. Nobody would have found this until
somebody re-photographed a barrel. Fixed in `0022`.

**`bun run lint` cannot pass on a Windows checkout.** Five files fail Biome on line
endings alone: `biome.json`, `tsconfig.json` and three `package.json`s. `core.autocrlf`
gives them CRLF and the formatter wants LF. It is in the definition of done and it
cannot pass, which is C1's shape in a different file. The fix is a `.gitattributes`
pinning `eol=lf`, which rewrites line endings tree-wide on the next checkout, so it is
named here rather than done unasked. It is also why the module import rule is a grep
rather than a Biome rule.

**`0020` breaks on any install where pgcrypto lands in `public`.** It pins
`search_path` on every function in `public` with no `proconfig`, which on such an
install includes `digest` and the rest of pgcrypto, and the migration fails with "must
be owner of function digest". Supabase puts extensions in their own schema so this does
not bite here. It would bite the first person to install this on a plain Postgres, which
is the case `0005` guards for and this does not.

**The compost ledger and the architecture rulings use the same id shape for different
things.** Compost entries are `C-1` through `C-8`; the rulings document numbers its own
sections `A-1`, `B-5`, `C-3` and so on. `verify.sh` exempts the rulings document from
the compost cross-reference check by name, with a comment. That is a workaround for a
collision that should be resolved by renaming one of the two namespaces.

## What is still open

Section A minus A1, A2, A3, A6, A8 and A14. The seven largest items in it are the
policy loop from `0002` that still reads blanket true on thirteen tables, the admin
event rewrite, lineage acyclicity, `block_composition` dropping unattributed bins,
template confidentiality, and the module-boundary work on `subject_type` and
`term_kind`. Section B, nineteen client defects, is a separate session by W-1's own
instruction. Section E is twelve deferrals with conditions, and E7, the realtime
publication, has a condition that reads "before any second client subscribes".

A13 deserves naming twice. It is the observation that every denial in this schema is a
zero-row match rather than an error, and it is the entry this session both confirmed and
failed to answer: confirmed, because it predicted the exact shape of a defect written
four days after it was filed, and unanswered, because `0021` improves it for one
principal on three tables and S-37 holds the rest. It is the most valuable single entry
in the corpus and it is still open.
