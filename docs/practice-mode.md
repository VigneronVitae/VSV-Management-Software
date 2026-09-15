---
Type: reference
Purpose: "How to run the practice cellar: a second stack with nothing real in it, where trying a thing and deleting it afterwards is allowed."
Depends on: [scripts/practice.sh, scripts/db-reset-guard.sh, docs/architecture-rulings.md]
Depended on by: [docs/status-ledger.md]
---

# Practice mode

The winemaker, mid harvest: "how can I have a server or delete things or whatever
so I can actually play around and try out things and delete them later, but also
use the app to record".

The honest answer was that he could not. Everything went into one cellar, and the
schema makes events and lineage deliberately hard to delete, which is correct for
a real record and useless for trying something out.

So there are two stacks. **The cellar, where nothing may be reset, and practice,
where anything may.**

His framing of the switch is what shaped it: "maybe it's a debugging mode that
actually ships". A developer's toggle can be obscure; a shipped feature has to be
understood by somebody who did not build it. So practice mode is a feature every
winery gets, and the words for it avoid every programmer's word: not sandbox, not
staging, not dev.

## Running it

```sh
bun run practice start    # bring it up
bun run practice up       # apply migrations to it
bun run practice seed     # copy the cellar in, so there is something to play with
bun run practice status   # which stacks are up, and how much is in each
bun run practice reset    # empty it. Allowed here and nowhere else
bun run practice stop
```

`seed` reads the cellar with `pg_dump` and never writes to it, the same as
`scripts/green.sh`. It replaces whatever was in practice.

The two stacks sit on port blocks a hundred apart, so the numbers read as a pair:

| | cellar | practice |
|---|---|---|
| API | 54321 | 54421 |
| database | 54322 | 54422 |
| studio | 54323 | 54423 |

On the tailnet, `:8443` is the cellar's API and `:8444` is practice's.

## Using it from the app

Set up, then Practice mode. Switching signs you out, because the two stacks have
separate logins and the session genuinely cannot travel. That is also the point:
being asked to sign in again is the clearest possible signal that you have moved,
at the one moment it matters most.

**Every screen in practice carries a band across the top, and the page carries a
border.** If you cannot see one, you are in the real cellar and what you record
counts. The band is built in `ui.ts`'s `screen()`, which every screen in the app
is made from, so a screen written next year gets it without its author knowing it
exists. That is deliberate: the way this fails is one screen somebody forgot to
mark.

A build with no practice stack configured never offers the switch at all. See
`VITE_PRACTICE_URL` in `apps/web/.env.example`.

## What stops you resetting the wrong one

`bun run db:reset` used to be `supabase db reset`, and the only thing between that
command and this winery's harvest was a paragraph in CLAUDE.md asking people not
to run it. That paragraph is still right and it was never a control.

It matters more now than it did. Practice mode exists so that resetting is a
normal thing to do, and somebody who has spent an afternoon resetting practice is
somebody who will eventually run it in the other window. So `db:reset` now counts
what is in the cellar and refuses, pointing at `practice reset`, which is almost
certainly what was meant. `scripts/db-reset-guard.sh` says how to override it,
and the override is deliberately awkward enough that the only way to find it is
to have read the file.

## What this is not

It is not a private kernel. **AR-Q9** records the better split the winemaker
proposed while this was being built: everything you record is yours until you
submit it, with your own kernel on your own device and the server as the public
one. That answers this problem, the offline gap S-47, and several people
recording at once, all as one thing. It also costs a fortnight and contains
S-32's unanswered question about who authored an event that crossed a boundary.

Practice mode is twenty minutes and it was harvest. That is a cost decision
rather than a design one, and AR-Q9 is where the design one is written down.
