---
Type: record
Purpose: "What was decided in the sessions of 2026-09-19 to 22 and would otherwise exist nowhere: why the repository carries types rather than records, why a transport is asked for rather than compiled in, and the three failure modes that recurred after being written down."
Depends on: []
Depended on by: [docs/session-reports/index.md]
---

# Five apps wide

Four days, migrations `0122` to `0141`, two new peripheries, and one rule about
what may be published. Written as history: it describes the repository as it
stood on 2026-09-22 and does not become stale when the repository moves on. What
is still open is in the sorry ledger, which is where a later session should look.

## AR-J4, and the thing that forced it

He asked, mid-build, whether the bank data was going to GitHub. The answer at
that moment was that some of it already had: two migrations were carrying 129 KB
of one winery's records, a vine map of 13,539 plant spaces and a machine with its
serials.

The rule that came out of it is one reading: **would another winery installing
this system have this row?** A grape variety yes, a line of Schedule F yes,
because it is a public form; the name of a block no, a bank transaction
obviously no. `scripts/data-surface.py` enforces it by enumerating every insert
into a table that holds instances and refusing anything unjudged.

**What the enforcement could not see was prose**, which is S-139 and which is the
most important sentence in this report. The first push was held while a card's
last four digits, a point-of-sale authorisation reference, a merchant's street
address and a year of category spending totals were removed from migrations and
ledgers. The linter reported 44 insert sites, every one judged universal, and was
correct about all 44. Every leak was a comment.

Six money classes named after companies also shipped, against an instruction
given in as many words the day before. `0138` renames them to what the vendor is
rather than who it is. A rule stated once in conversation and enforced nowhere is
a rule that holds until somebody is busy.

## The contract, asked at full size

His question was whether the backend could be shaped so the frontend could be as
diverse as possible, and then, when the answer came back about one module, that
he meant the whole system.

Counting rather than remembering turned out to matter: 31 of 39 capabilities were
the cellar's, the vineyard shipped an app with no verbs at all and wrote through
`cellar.add_note`, and inventory owned neither a verb nor a view while its one
real capability was filed under cellar. Four foreign keys crossed module lines
and none pointed at books, so a machine repair and the money that paid for it
were two records that never met.

**The mechanism to join them was already built and unused.** `subject_resolver`
had fifteen registered types and `note` and `attachment` already hung on it.
`0131` opened `event` to subjects that are not wine lots, `0134` let a domain tag
a place and a thing alike, `0135` let a photograph point at something. None of
those invented a mechanism; each one used the one AR-E5 put there.

The finding worth keeping: **not one interface idea worth stealing from Home
Assistant, Odoo, Monarch, Actual, Lunch Money, Firefly or Beancount turned out to
rest on something a client draws.** Every one rested on something the kernel says.

## Where the kernel is, asked rather than compiled

The Tailscale trial ended because a tailnet registered under a custom domain is
classified as business use, which had nothing to do with volume: one user, two
devices, inside the free plan.

The swap looked like a proxy change and was not. `VITE_SUPABASE_URL` is read at
build time, so the hostname was a literal string inside all five bundles, and
moving the apps would have moved the HTML and not the data.

His answer was better than the migration: make it derivable, and have several
work at once. `where.json` is served beside each app and lists routes rather than
holding a value; the app tries them in order and remembers the winner. Both
transports can be live simultaneously, and turning one off is an edit and a
reload.

It deliberately discovers nothing. A convention like "the api is this host with
api in front" works until it does not, and then fails by connecting somewhere
unexpected rather than by saying so.

## Three failure modes that recurred after being written down

This is the section a later session should read first, because each of these had
already been documented when it happened again.

**A check whose coverage is a literal list will be wrong in the direction of
passing.** `verify.sh` had a hardcoded extension list, wrong four times over four
languages, carrying a comment that predicted the fifth. The fifth was YAML and
the comment did not prevent it. The list is now gone: the question is asked of
the file, not of its name.

**A Windows path inside a Python string turns the backspace and vertical-tab
escapes into those characters.** Documented on 2026-09-13. Done again on
2026-09-21 to `scripts/watchdog.ps1`, where two of the five app directories
became control characters; the file parsed cleanly, so the parse check written
that same day passed, and the watchdog could not have restarted two of the apps
it exists to restart. Then done a **third** time, to `verify.sh` itself, while
adding the check for it, because the obvious way to write that pattern is full of
the very escapes that get eaten. A fourth time, to the status-ledger row that
recorded the repair, and that one the new check refused before it was committed.

**`create or replace` does less than it sounds like.** With a new parameter a
function overloads rather than replaces; a view will not move or rename a column.
Three functions and two views in four days.

The common shape: in every case the second occurrence came after the first was
written up. Writing a thing down is not a check. The three that now exist,
control characters, the header graph without an extension list, and the contract
comparing `capability.fn` against the catalog, each caught something within a
minute of it being introduced.

## The thing an agent should treat as absolute

Check references before deleting. Four `vessel_maker` rows looked exactly like
pollution from a suite that had been run repeatedly minutes earlier. They were
real coopers on four real barrels, added through the app that afternoon. What the
suite was actually doing was colliding with the winery's own vocabulary, because
it hardcoded a real cooper's name as a fixture and he had bought that barrel.

## The read on where this left the system

Five apps wide and one harvest deep. The width grew across these four days and
the depth did not: four migrations of tool infrastructure and a fifth periphery
against six picks and thirteen open lots entered by hand during the fortnight
that cannot be repeated. `docs/review/2026-09-21-where-this-is-going.md` argues
it at length and is meant to be disagreed with.
