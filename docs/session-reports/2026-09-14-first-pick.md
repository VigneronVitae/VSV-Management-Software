---
Type: record
Purpose: "Records the session in which the software was used for the thing it was built for: intake and press written the night before the first pick, and then changed all morning by a winemaker standing at a scale."
Depends on: []
Depended on by: [docs/session-reports/index.md]
---

# 2026-09-14: the first pick

Nine migrations, `0032` through `0040`. No numbered prompt and therefore no
prediction set to score, which is itself worth recording: every previous session
was steered by a written brief, and this one was steered by somebody weighing
fruit.

## What made this session different

**The deadline stopped being a date and became a person.** `CLAUDE.md` has said
since the scaffold that the deadline is harvest and does not move. On 2026-09-13
that was a sentence in a file. At 13:31 on 2026-09-14 the winemaker created a
block called Vitae Springs Vineyard Southeast, and at 13:33 a pick against it,
and from then on every change landed in a database that had that morning's fruit
in it.

Three things follow from that and they are the substance of this report.

The first is that **the build order in spec.md §7 was right, and it was right for
the reason it gave.** Intake is build order 2 because a bug there costs a bin
that cannot be reconstructed. Everything built on the night of the 13th was
intake and press, and everything asked for on the 14th was a refinement of them.
Nothing about the task board came up.

The second is that **the winemaker's own model beat mine every time it
disagreed.** A bin is a vessel: his move, and it collapsed most of intake into
machinery that already existed. Macrobin is a manufacturer rather than a kind of
vessel: his correction, and it is the same wrong-way knowledge `AR-E7` took out
of two enums. A block carries several varieties which each have their own
rootstock and age: his answer, and it is why `planting` exists at all rather than
a `variety_id` column on `block`.

The third is that **testing against the running cellar was wrong and I did it
four times.** More below.

## Intake, and the shape the winemaker chose

The interview before building mattered more than the building. Four rounds of
questions, and three answers changed the schema:

**A weighing is an event and a pick is a node.** Three bins on a scale produce
one number. That number is a measurement of three bins together and it does not
contain three weights, so `0033` does not store three weights. Offered the
choice between inventing per-bin figures and storing one measured total, he took
the total and asked for the option to split later. That is T0-2 applied to a
scale, and it is his instinct rather than an axiom being enforced on him.

**The unweighed bin is the point.** T1-4 says intake must be fast before it is
complete, which only works if incompleteness is visible. A bin with fruit and no
weight is a legitimate state reachable in one tap in a vineyard, and
`unweighed_bin` is what stops it being a silent one. The count is on the home
screen. `press` refuses a pick nobody ever weighed, because pressing is the last
moment the fruit exists as fruit.

**A pick with no weight reads "not weighed yet", never 0 lbs.** B11's lesson,
one table down, and the one place in this schema where a zero would be most
expensive.

`0034` followed the same night because Pinot Gris does not go to cold storage:
picked, weighed, pressed immediately, or it takes on colour.

## What he changed by asking

Five of the nine migrations exist because somebody was using the thing.

`0035` because he registered PB1, PB2 and PB3 one screen at a time and then added
them to a pick one tap at a time: six actions for one decision. The numbering
rule went into the kernel, because "the next bin after PB3" is exactly the three
line calculation `CLAUDE.md` forbids a client from owning.

`0036` because fruit arrives in the grower's bins. The interesting part is what
was refused: making Pearlstaad a `party` to borrow their bins would have put a
row in the table `node_read` scopes lot visibility by, in order to record a fact
about a plastic box. `block.vineyard` was already free text, so a bin on loan
says whose it is the same way. S-53 is the cost of that decision, named rather
than discovered later.

`0038` because he started a pick to see how the screen worked. Two verbs, because
there are two situations: cancelling keeps every weighing, and removing is narrow
enough to be honest. The split was not designed, it was read off the schema:
`node` already had `node_admin_delete` and a cellar update allow-list containing
`status` and `attributes`.

`0039` because the first export made it obvious that a vineyard was a string
typed onto each block. Three levels, and inheritance as a view rather than a
copy, so a block corrected next spring corrects every planting relying on it.

`0037`, the export, is the one he asked for as a backup and got as something
else. It runs as whoever asks, so two people get two different files and both are
correct. **It earned itself on first use**: the file showed `subject_resolver`
carrying `vineyard || ' ' || name` for a block, and `resolve_subject_name` runs
that expression inside `exception when others then return null`. Moving the
column without noticing would not have errored. Every block would silently have
stopped having a name.

## The backup that was not one

Asked what he could do without losing data, the honest answer required knowing
whether there was a backup. There was not.

`pg_dump` is not installed on the machine running this project: on a Supabase
local stack it lives inside the database container. The script called it anyway
and redirected straight at its final output path, so a run wrote three comment
lines, failed, and left a 120 byte file in `backups/` that looked like a backup.
The last real one was four days old, taken before intake existed.

**That is this project's standing failure mode arriving in the one place where
believing it costs the vintage.** A refusal that returns success. The script now
borrows `pg_dump` from the container, builds in a temporary file, counts the rows
and only moves it into place if there are any. A run that cannot dump leaves
nothing behind.

Found because he asked a question, not because anything checked.

## What the apparatus caught, and what it did not

Caught, and each of these would have shipped:

- `block_only_on_bins` refused the child of a press carrying its parent's block.
  The constraint was right and I was wrong: T0-2 says composition downstream is
  derived by walking lineage, never copied.
- The `search_path` assertion caught four new functions that would have broken a
  restore.
- Six snapshot assertions caught deliberate schema changes and made me confirm
  each one in writing: policy count, constraint inventory, composite foreign
  keys, generated kind columns, delete behaviour, and the blanket-policy list.
- The A25 validator accounting refused to let `refuse_forking_a_pick` into the
  tree without a written account of its null behaviour.
- A fixture caught `block.variety`, which is how the second defect below was
  found.

Not caught, and shipped to a phone in a vineyard:

- **`block.variety` was `not null` and `0039` stopped anything writing it**, so
  adding a block failed entirely, including the inline one on the intake screen.
- **`add_bin_to_pick` built a pick's name from `b.vineyard`**, a column `0039`
  moved. Adding bins to an existing pick was unaffected, because the name is only
  built when a pick is created. So it works all morning and fails on the next load
  of fruit, which is the worst shape a defect on that path can have.

Both were found by the assertion suite an hour later rather than by him, which is
the only good thing about either.

## An assertion that read production data

The sharpest methodological finding of the session, and it cost nothing because
he found it by accident.

`0033`'s assertion checked that a bin type with no tare refuses. It did that by
reading whatever tare the facility happened to have. It passed against an empty
database and passed against a copy of the cellar, right up until the winemaker
typed 92 lbs into the running cellar mid-harvest, at which point the suite went
red for a reason that had nothing to do with the code.

**An assertion whose answer depends on production data is not an assertion.** It
now clears the tare itself before asserting the refusal, and the suite rolls back,
so the real number is untouched.

The same shape appeared a second time in the same session: the export's
row-level-security assertion compared an administrator's file to a client's and
found them identical, because the suite runs as the owning superuser for whom
row level security is not enforced at all. Without `set local role authenticated`
it passed while proving nothing.

## What I got wrong

**I tested against his live cellar, and he stopped me twice before I stopped
myself.** Four throwaway accounts created in a production database during
harvest, each one an `auth.users` row and an `app_user` row, one of which I left
behind and only found because it appeared in his own export. The reasoning each
time was that the write path needed proving before he relied on it, which is
true, and the conclusion was wrong: the cost of a phantom row appearing on his
phone mid-pick is his to accept and I never asked. There is no scratch instance
with its own API, which is the actual gap, and it is not filed because it is
infrastructure rather than a schema obligation.

**I shipped the export broken on a decoration.** It stamped the file with the
migration count, which reads `supabase_migrations`, a schema the `authenticated`
role has no rights to. So a nicety killed the whole feature, and killed it as
`permission denied for schema`, which the client correctly classified as a
Postgres-generated message and replaced with a sentence telling an administrator
to go ask an administrator. Two bugs, one of them mine twice over: the stamp, and
a refusal message that had never been read by somebody who was already an admin.

**I swallowed an error and then blamed the browser for it.** The service worker
registration ended in `.catch(() => undefined)`, so when it failed the install
button said "this browser has not offered". Diagnosing that cost a round of
guessing, at which point the swallowed error turned out to say exactly what was
wrong. The failure is kept now and the button distinguishes "your browser did not
offer" from "this app's worker did not load", because those are not the same
sentence.

**Two heredoc failures and two invalid uuids.** `\1` eaten out of a `sed`
backreference by a Python heredoc, which is the same collapse this repo has
recorded twice before and whose fix is `chr(92)`; and `v` used as a hexadecimal
digit, twice. The first would have silently emptied a backup had the row count
guard not been added in the same edit.

**I twice let the dev server serve stale code and concluded the feature was
broken.** Vite's watcher misses writes made by a Python script on this machine, so
the browser ran the previous build. The fix is `touch`, and the lesson is that a
negative result from a tool you did not verify is not a result.

## Where it stands

Green at 339 assertions from empty and 341 against a copy of the cellar, 280
refusal sites enumerated, 40 migrations.

Intake, press, bulk bins, bins on loan, cancel, export and the vineyard are built
and in use. The app has a manifest, icons, a service worker and an install
button. Route and draft persistence mean leaving to take a photo no longer costs
the form.

What is not built: rows, which he asked for and which are designed but not
started, and which are the thing that connects a bin to a part of a block. No
importer for the export, so the file is a faithful record and not a restore
point. No offline, so a cold start with no signal still fails, now knowing which
screen you wanted. And S-56, named in the last minutes of the session: a bin's
fill percentage is per bin in the schema and per action in the app, so bins
registered together cannot differ and none can be corrected afterwards. He added
that the day's bins were all full, which is why it was a note rather than a
problem, and it is the number a later session would divide a shared scale reading
by.

Two questions are open and both are his: whether a cellar hand may register bins,
and whether one may add a block. Both are one line.
