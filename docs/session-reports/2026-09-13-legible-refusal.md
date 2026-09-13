---
Type: record
Purpose: "Records the W-9 session: the section B measurement finished and the reading-against-running ratio it was for, the degenerate policy list turned into an assertion, A5 decided and half closed, one path for the three refusal shapes, and the density class answered."
Depends on: []
Depended on by: [docs/session-reports/index.md]
---

# 2026-09-13: legible refusal

W-9, six phases, green at `0030`. Two migrations, both policy and function work,
no new tables.

## Predictions, scored

1. **Of the twelve unscored section B entries, seven to ten reproduce, one to
   three do not, one to two are unreachable.** **Correct on all three.** Eight,
   one, two, and one more confirmed in mechanism only.
2. **Across all seventeen, twelve to fifteen reproduce, and the ratio falls to
   about one to one.** **Right on the count, thirteen. Right about the direction
   and wrong about the size.** It fell to about one to two.
3. **Five to nine of the twenty degenerate policies are deliberately permissive.**
   **Correct: six.**
4. **No enumeration of sites would have caught B20, and two to five siblings.**
   **Right about the enumeration and wrong about the siblings: there are none.**
5. **Column privileges cannot answer which columns a caller may write.**
   **Correct**, and worse than expected: they report every column of `vessel` as
   updatable by `authenticated` and by `anon`.

## The section B scorecard, finished

Seventeen entries were open. W-8 reached five and W-9 phase 1 did the rest.

**Thirteen reproduce.** B3, B4, B5, B6, B7, B9, B10, B11, B13, B15, B16, B18, B19.

**One does not.** B17 predicted that an expired session offline is
indistinguishable from a sign-out and that the next write goes out as the anon
key. Neither happens. With a reachable network the token refreshes silently; with
an unreachable one the client retries the refresh in a loop, five times and
counting, while the button says "Working" for ever. **The failure the entry names
is not there and the failure underneath it is B16 with an auth retry loop on top**,
now filed as B26.

**Two are unreachable in this environment.** B8 needs a camera decoding frames and
I did not simulate one, because a simulated decode loop reproduces my harness. B2
needs a screen that adds an operation term inline and there is none: the inline
pickers are variety, product type, vessel type, location kind, cooper and wood.
`addTerm` is generic and nothing calls it with `operation`, so the path exists in
the kernel and not in the client.

**One is confirmed in mechanism only.** B12. `validity` and `badInput` appear zero
times in the whole client and every numeric read is
`value() ? Number(value()) : null`, so rejected text and an empty field are both
`""` and both write null. Producing a real `badInput` needs a keystroke and the
browser pane would not take one.

Four needed amending rather than confirming, and in every case running made the
entry worse or narrower rather than agreeing with it. **B3** keeps all six `keep`
checkboxes ticked while discarding every value, so the interface asserts a
carry-over it did not perform. **B4** does surface its error, which the entry does
not credit, and still leaves a vessel in the database with one of two codes bound
and a retry that duplicates it. **B5** breaks the hard rule in `CLAUDE.md` about
offline identity: the first attempt sent node `d6c8fcef`, the retry sent
`8bc0df50`. **B16** for a read has no progress indicator at all, where the entry
describes a write hanging on "Working".

## The ratio, which is what the phase was for

**Seven findings from running against thirteen confirmed by reading.** About one
new for every two the read got right. Reading's precision was 13 of 17, or 76
percent.

W-8 reported two new for every one confirmed, on five of seventeen. **That was
selection and the correction is the whole result.** W-8 spent itself on the part
of the surface it went looking at hardest, found the client-login leak there, and
computed a ratio over the third of the list it had reached. Working the remaining
twelve in order produced one new finding and a great many amendments.

The prediction named that mechanism in advance and said the ratio should fall to
about one to one. It fell further. What I underweighted is that a finished list is
mostly small local defects, and small local defects are exactly what reading is
good at, so completing the denominator does not just remove the selection bias, it
adds the entries reading finds most reliably.

**What this says about commissioning a review**, which is the thing the number is
for: reading is worth about three quarters of its own claims and running finds
roughly half as much again on top. Neither replaces the other, and the order
matters, because the amendments were worth more than the count suggests. Four of
thirteen entries said something materially wrong about a defect that was really
there.

## The exclusion list was a detector

Twenty `weaken` mutations have reported "degenerate, changed nothing" in every run
since W-4. They are degenerate because the policies are already `true`, so the
harness has been printing ledger A5 continuously in a column labelled excluded.
Five sessions read that list. None read it as a finding.

The assertion covering this was a pinned string gated behind `snapshots_on()`,
which is what it was: a photograph of twenty names, satisfiable with one paste. It
is a disposition list now. Every blanket-true policy carries `permissive` or
`finding` and a reason; a new one fails until somebody judges it; an entry for a
policy since narrowed fails too, so the narrowing and its record land together.
**The judgment costs a sentence rather than a paste**, and that is the whole of the
difference.

Six permissive: the vocabulary, the templates over it, the subject resolver
registry, and the rooms the vessels stand in. Fourteen findings, each naming its
ledger entry. After 0028, eleven.

## A5, decided

**AR-E10, redaction is row-level.** If you cannot see the lot, you do not get the
row. `vessel_state` proved column-level redaction contradicts itself: the count
came from rows a client could see and the names from columns they could not, so
the home screen said two of three while they could name one. The barn argument
does not carry, because presence yields one snapshot for the cost of walking there
and the view yields a time series for free.

**AR-E11, availability is a contract and contents are ownership.** Written,
deliberately unbuilt, because the magnitude case is unresolved.

`0028` implements the first with three policy edits and no new schema. The
predicate is deliberately not "the viewer may read the node": `node_read` denies a
facility user any lot with a hidden field, so scoping that way would take a hidden
lot's placement away from the hand who has to rack it. What is wanted is
`visible_node`'s first gate and not its second.

Measured in the running client: the client's home screen went from "2 of 3" with
one nameable lot to "1 of 4" with one nameable lot. `placement` three rows to one,
`event` one to zero, `lineage` to zero.

**S-44 is what it cost.** A vessel holding wine this viewer may not see reports as
empty, which is false. It is the narrower error, and it is asserted rather than
only described, so that when AR-E11 is built the assertion for it fails.

## One path for three shapes

The read case cannot be answered by asking about the rows, and every way of trying
discloses the thing being withheld. So `viewer_scope()` does not answer "was I
refused". It answers what the caller is, and emptiness is read in that light. An
empty result plus a known standing is complete and true. That is weaker than
naming what was withheld, and naming it is the thing that must not be built.

It discloses nothing: every field is a fact about the caller. It is written in SQL
rather than plpgsql so it has no branches and adds no refusal sites, and gate 6
still reports 176.

**The thing that made three shapes possible was one line repeated thirty four
times.** Every kernel wrapper ended `throw new Error(error.message)`, which
discards the SQLSTATE. The code that needed to tell the shapes apart never saw the
thing that tells them apart. `KernelError` keeps it.

**And then I keyed on it, and the key was wrong.** P0001 is a raise and 42501 is a
policy, which is true and useless: `cellar_writable_columns` raises using errcode
42501 on purpose so PostgREST answers 403. The best refusal message in the tree
arrives under the same code as a bare policy denial, and keying on the code
replaced it with a generic sentence. **I made the one shape that already worked
worse**, and found out by re-running the exact check W-8 ran. The rule is inverted
now: relay the message, because somebody wrote it, unless it is one of the two
strings Postgres generates on its own.

It closes B10 as well, because deciding who may enter is the same question. A
deactivated account now stops at a screen that says which of the two reasons
applies.

## The density class, and whether the method transfers

B20 is fixed by one line of judgment rather than seven better fallbacks: a row
missing from a read that succeeded is an outcome and not a rendering condition, so
`resultScreen` stops rendering and says the write went through and gives the two
identifiers.

**How I looked for siblings.** Two passes.
`scripts/undefined-sites.sh --density` counts absent-value fallbacks per function,
because a density is a property of a render path. Then the structural signature of
B20 specifically: a row obtained by `.find()` on a fetched list, or a kernel call
that can return null, and then rendered.

**None.** Six `.find()` sites: one is B20, one returns null explicitly, one is
validation, one is cosmetic, one shows the raw identifier rather than inventing a
name, and one carries a single generic label. `resolveCode` can return null and its
caller has an explicit not-found branch.

**Does an enumeration exist that would have caught B20? No, and not one of that
kind.** Every one of its seven sites was correct, and an enumeration's unit is the
site. The density pass ranks `resultScreen` second, which is close to luck: by
fallbacks per line it sits below two UI helpers, so the count is not the signal.

The signal is a render path whose input can be absent and which has no branch for
that absence. **The thing that enforces that already exists and was being declined
one expression at a time.** `strictNullChecks` is on. `?.` is how the code opted
out of it seven times in one function. A type that is not optional would have
demanded the branch. **The client has a defence here that the SQL never had**, and
the W-7 method does not transfer to this class.

## Asking rather than remembering

A cellar hand now sees all fifteen vessel fields, twelve as the values they hold
and three as inputs. Where the three come from is the point: `0030` reads the
allow-list out of `cellar_writable_columns`'s own trigger arguments, so the answer
comes from the place that enforces it. An assertion fails if the names are ever
kept beside the trigger rather than read out of it.

Column privileges cannot answer it, which is S-45. Grants are per database role;
admin and cellar are both `authenticated`.

Two things this turned up. **Locking by container would have been a regression**:
`openSlot` and `moreSlot` hold the vessel type's fields and the glycol block
together, and glycol, setpoint and mode are exactly the three a cellar hand may
write. **And locking the controls is cosmetic on its own**: the save still failed
until the patch carried only the writable columns, which is B23.

## Closed this session

B10, B11, B20, B23, and A5 for the three tables that carry wine. B26 opened.
S-44 and S-45 filed.

## What I got wrong

**The SQLSTATE discriminator.** Reasoned from the standard, shipped it, and it ate
the best refusal message in the system. Caught only because I re-ran W-8's own
check rather than trusting that a repair repairs.

**Predicted two to five B20 siblings; there are none.** I generalised from one
instance to a class before looking, which is the thing W-6 and W-7 were about, in
the small.

**Predicted the ratio at one to one and it is one to two.** The direction was
right and the reasoning was half right: I accounted for removing the selection
bias and not for what completing a list adds, which is the entries reading is best
at.

**I nearly locked the glycol block**, which would have taken away the only three
things a cellar hand can do while fixing the complaint that they cannot do
anything. Caught before shipping by reading what the container held.

**The heredoc backslash collapse, a fifth session running.** `\\n` in a Python
heredoc became a real newline inside an awk program and produced an unterminated
string. The rule that works is `chr(92)` and I keep reaching for it only after the
first failure.

**One thing worth keeping.** Both break tests this session were caught by a
different assertion than the one written for them: the blanket-policy test tripped
the policy count first, and the hardcoded allow-list tripped the no-trigger case
rather than the drift comparison. That is an argument for several overlapping
checks rather than one exact one, and it is also a warning that a break test which
passes may not have exercised what you think.
