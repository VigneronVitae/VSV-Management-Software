---
Type: record
Purpose: "Records the W-10 session: status turned from prose into a check that runs in green, the client's unverified claims declared and counted, the scheduling block moved to core five sessions late, and X-2's six findings decided rather than excluded a fifth time."
Depends on: []
Depended on by: [docs/session-reports/index.md]
---

# 2026-09-13: status, then the oldest debt

W-10, four phases, green at `0031`. One migration.

## The push did not happen

W-10 opens "First, push." It was refused by this environment's permission
classifier twice, not by git and not by the remote, so the session continued
around it and everything else here is independent of it. **It went through at the
end of the session, once the winemaker was at the terminal: `origin/main` is
`514b4bd`, twenty six commits, W-7 through W-10.**

**And it was worse than a blocked push, which the blocked push hid.** I
fast-forwarded `main` at the start of the session and then went on committing to
`claude/sql-files-to-markdown-i31rob`, so by the end `main` pointed at a commit in
the middle of W-9 and everything since had landed somewhere else. Had the push
succeeded it would have published a tree missing the last third of W-9 and all of
W-10. Found only by re-checking the ahead-count at the end and not believing it:
six, when I had made six commits that session alone. `main` is fast-forwarded
again, and the twenty six commits that had accumulated since W-6 went up together.

The rule this leaves, written into `CURRENT-BASELINE.md`: **fast-forwarding the
default branch is the last thing a session does, not the first.** Done first it
records an intention. Done last it records what happened.

## Predictions, scored

1. **Eight to fourteen built, four to six claimed, fifty or more ruled.**
   **Wrong on two of three.** Five built, seven claimed, fifty nine ruled and
   seven open questions. I overestimated built by being generous about what
   "built" means before I had to write the check that decides it; having written
   it, only five rulings have a mechanism in the tree that an assertion fails
   without.
2. **Four to nine disagreements between a document and the tree.** **Correct:
   eight**, and six of them are the same sentence in the same file.
3. **The ratchet does not hold on the first attempt, and that is it working.**
   **Correct, and for a better reason than the one I gave.** I predicted new
   objects starting uncovered. What happened is that an existing site lost
   coverage it never really had.
4. **Two to four of the six findings turn out not to need supervision.**
   **Correct, four**, and the reclassification is sharper than the prediction: two
   more need it for half of themselves.
5. **At least one ruling I mark built will have no assertion citing it.**
   **Wrong.** All five had one or got one, because writing the check first made me
   conservative about the claim, which is the check working on its author before
   it worked on anything else.

## The three counts

```
71 rulings: 5 built and asserted, 59 ruled and unbuilt, 0 superseded, 7 open questions
7 built and nothing checks them
```

`scripts/status.sh` runs in green as gate 7. A ruling marked `built` with no
assertion citing it fails. A ruling whose only citing assertion is snapshot-only
fails too, because W-6 cost a session to establish that a pinned list notices the
catalog moved and cannot notice something stopped refusing, and letting a snapshot
discharge a ruling would re-admit that one document up. All three failure modes
break-tested, and the snapshot one needed two attempts: the first attached the
citation to the one assertion W-9 had de-snapshotted.

A citation is a comment line that **begins** with the identifier. A line
mentioning one in passing is not, and there are six of those. That distinction is
the whole reliability of the check.

**The middle column is the client, and it is declared rather than forced.** Seven
rows in `docs/status-claims.tsv`, each with the session that claimed it and the
reason nothing checks it. Counted, printed on every run, not fatal. That is the
degenerate-policy move again: the state is allowed and somebody has to write a
sentence.

## Eight disagreements, and six of them are one sentence

**`docs/status-ledger.md` graded five migrations Specified**, three of them saying
they had never been run or had only been tried on Postgres 16, while
`bun run green` applied all of them from empty on 17 in every session for nine
sessions. A sixth row said the client screens had never run against a Supabase
instance, which W-8 did.

That file's own opening paragraph says it exists to prevent a claim that was true
when written and stopped being true without the sentence changing, and it names
its own first occurrence of doing exactly that. **This is the second.**

So the fix is a check rather than an edit. `verify`'s check 6 now fails on any
migration graded Specified, because there is one set of migrations and green runs
all of it, which makes the grade decidable from a directory listing instead of
from somebody's memory.

**The seventh and eighth.** `AR-E6` still said it was blocked by `task_board`,
which `0024` removed four sessions ago, and the reconstruction attached to this
prompt attributed the unblocking to `0026` instead. Two documents, two different
wrong blockers, and a ruling sitting available that nobody picked up because the
fact lived in prose.

**One collision worth recording.** The prompt offered a reconstructed status
ledger "as `docs/status-ledger.md` if it is not already in the tree". It is
already in the tree, as a different and load-bearing document that `CLAUDE.md`
names as the single source of build truth. Writing the attachment to that path
would have destroyed it. The reconstruction's content is distributed instead: the
ruling statuses into `architecture-rulings.md`, the middle column into
`status-claims.tsv`, the pending counter into `status-pending.tsv`, and the script
it specifies into `scripts/status.sh`.

## The scheduling block, five sessions late

`AR-E6` says `template`, `template_step`, `task` and `task_claim_log` are generic.
Every outward edge already was, except one: `template.variety_id`, with a
generated `variety_kind` pinned to `'variety'`. `term_kind` records in a row that
`variety` belongs to winemaking, so a core table carried "a schedule is for a
grape variety", which is the wrong-way knowledge `AR-E7` took out of two enums, in
a column instead.

`0031` makes the vocabulary a parameter. A spray schedule applies to a variety, a
steaming schedule to a vessel type, an opening checklist to a location kind, and
the composite foreign key still proves the term is of the kind claimed. What
changes is that core stops naming which kind it is, and
`generate_inferred_history` asks for `'variety'` itself.

**Both traps W-10 named were handled rather than survived.** The generated-column
reorder is avoided outright: `variety_id` is renamed, which holds its position,
and `variety_kind` was already last so its replacement lands where it was.
Verified in `pg_attribute` afterwards. The cast-to-enum validator does not apply
and that was checked rather than assumed: what proves the kind here is a composite
foreign key, which is a constraint and not a cast.

Three snapshot assertions fired and each was right.

## Whether the ratchet held

**It did not, and that is the answer.** Its first use on a structural change it
was not built during, and it broke on two refusal sites in `visible_node`: the
row-visibility gate and the return inside it.

A scheduling migration has no business touching lot privacy, so the first question
was whether this was an artefact. It is not. **`visible_node`'s entire
row-visibility check can be replaced with `if false then` and all 287 assertions
pass**, which means a client can be handed a lot they do not own, redacted rather
than refused.

What had been catching it was fixture breakage somewhere else, and `0031` moved
the fixture. **Fixture breakage is not coverage.** The harness has printed that
distinction as a column since W-6 and this is the first time it has cost
something. The two assertions W-7 wrote for this function ask an admin and a
facility hand, and both of them pass the gate, so neither could ever have seen it
removed: they are about redaction, and redaction is the second question.

The new assertion asks a client for a lot that is not theirs and requires nothing
back, with a blindness guard beside it. Break-tested against the exact mutation
the ratchet flagged.

**So the ratchet earned itself in one use**, on a defect no part of this session
was looking for, in a file the change did not touch.

The second run held: **316 of 369 behavioural, 165 of 176 refusal sites covered,
eleven filed**, and fixture breakage back to 29 from the 294 of the void run.

The baseline is re-cut to the new numbers rather than left as headroom, which is
what a ratchet is for. `weaken` went from 33 uncovered to none and `policy` from
42 to 32, because narrowing three blanket reads in `0028` gave 33 weaken
mutations something to be caught by. A baseline left where it was would have
permitted losing all of that silently.

## The six findings, decided

Four consecutive prompts excluded them by name as "a supervised migration
session". Read one at a time instead of as a block, four of the six contain no
question: they are null logic in validators, the A25 class, and a guard that a
missing key walks around should refuse without anybody being asked.

The other two contain a defect and a question, and the halves separate. That a
rebind leaves the previous binding's timestamp and label is a falsehood, and
removing it needs no judgment. Whether the row should say who moved the sticker
is a decision about what the record is for. That a deactivated code returns
success is wrong however you answer it. Whether re-binding should reactivate it is
winery practice.

So two questions, written to be answerable in thirty seconds at the press, with a
named trigger: **the next session that touches `bind_vessel_code` for any reason,
or the first time a sticker is actually moved in the cellar.** Not a date. The
trigger exists so a fifth exclusion has to be somebody choosing one.

The pending row splits in two to match, so the counter stops printing one line
that hid the fact that four of the six were never waiting on anybody.

## What I got wrong

**I edited the assertion suite while the mutation harness was reading it.** Once
per mutation, for a thirty five minute run, which came back 356 of 367
behavioural with 294 of those being fixture breakage against 34 the session
before. A number that good is the shape of a broken suite and nothing said so.
This is the second measurement lost this way in three sessions: W-8 edited
`mutate.sh` mid-run, and I wrote the rule down immediately afterwards and then
broke it in a different file.

So the rule is a check now. The harness fingerprints its inputs at the start and
refuses to print a score if any of them moved, and refuses if fixture breakage is
more than half the behavioural figure, because a suite failing for its own reasons
catches everything.

**`ratchet.sh` would have refused a perfect run.** It required `survived.tsv` to
be non-empty, and an empty survivors file is the best outcome there is. Found by a
run in which nothing survived, which was itself void for the reason above, so one
broken measurement revealed two instrument defects and neither was what it was
looking for.

**Two of five predictions**, and the interesting one is 5: I predicted I would
mark something built without an assertion, and I did not, because writing the
check made me conservative about the claim before the check ran. Predicting your
own carelessness and then being careful is a strange way to be wrong.

**The push, and the branch under it.** Refused by the environment twice, and the
session continued around it, which is right. What is not right is that I
fast-forwarded `main` at the start and then committed to the working branch for
the rest of the session, so the thing I was trying to push was six commits behind
what I had written. A blocked push is the only reason that did not ship. I found
it by disbelieving an ahead-count of six after making six commits, which is a
thin margin to have caught it by.
