---
Type: record
Purpose: "Answers how somebody who is not the winemaker gets this app on their phone, what each route costs, and the one thing that must be fixed before any of them is safe."
Depends on: [docs/sorry-ledger.md, supabase/migrations/0068_an_invite_to_claim.sql]
Depended on by: [docs/status-ledger.md]
---

# Getting somebody else on it

The winemaker: *"how could I do this so my interns don't need to download an app
besides the vitae springs app?"*

## The short answer

They already do not. It is a progressive web app: an intern opens a link in
Safari or Chrome, taps Add to Home Screen, and it behaves like an app from then
on. Its own icon, no browser chrome, works with no signal, and no app store
account. `install.ts` has offered that since the phone first ran it, and the home
screen has a button that asks the browser to do it rather than making anybody
hunt through a menu.

**The thing in the way was never the download. It is the link.**

## What is actually in the way

Today the only route to the app is Tailscale. That means the intern installs
Tailscale, which is a second app, and joins the winemaker's private network,
which gives their phone a route to everything else on it. That is the opposite
of what he asked for, twice over.

Getting off Tailscale means the app is reachable from the internet, and two
separate things made that unsafe.

**The first is closed.** `0068`. Until it landed, reaching the sign-up page was
the same thing as working here: sign up, claim, and the schema treated you as
staff, with both custom crush clients' wine behind it. Now claiming needs a
six-character invite an administrator hands out, good for a week and usable once.
The first claim on a fresh install still needs none, because there is nobody to
issue one and that claim is what creates the person who issues the rest. S-78,
discharged.

**The second is open and it is the one that matters.** S-77. This stack is signed
with Supabase's published demo keys: the JWT secret is
`super-secret-jwt-token-with-at-least-32-characters-long`, which is in Supabase's
own documentation because it is what every local stack starts with. Anybody who
can reach the API can mint a `service_role` token and read and write everything,
row level security included, with no password and no account. The invite is a
lock on a door that is standing beside an open window.

Today that is bounded by Tailscale: the keys are not the control, the network is.
**The moment anything makes this reachable from the internet, the keys are the
only control there is, and they are printed in the manual.**

So nothing here is a decision about interns. It is a decision about hosting, and
it is the winemaker's to make.

## The three routes, and what each costs

### 1. Stay on Tailscale, and let interns in on it

What it is today. Each intern installs Tailscale and is invited to the tailnet.

*Costs:* the second app he asked to avoid, and a phone on his private network. A
tailnet ACL can narrow that to the one machine, which is worth doing whatever
else happens.

*Effort:* none, it works now. *Safe:* yes, S-77 stays bounded by the network.

### 2. Tailscale Funnel, the same stack exposed

`tailscale funnel` puts the existing machine on a public HTTPS address with no
change to anything.

*This is the dangerous one, because it is one command.* It exposes the demo keys
to the internet, which is S-77 read out loud. **Do not run it until the keys are
rotated.** Rotating them is mechanical: a new `jwt_secret` and new anon and
service keys in `config.toml`, the stack restarted, and the client's key updated.
Half an hour, and it wants doing with the cellar quiet, because every signed-in
phone is signed out by it.

*Effort:* half an hour on the keys, then one command. *Safe after that:* mostly.
It is still a laptop in a barn: if it sleeps, the app is gone, and nothing
backs it up but `db:backup`.

### 3. Hosted Supabase, the app on a static host

A Supabase project generates its own keys, so S-77 does not exist there. The
client is static files and goes anywhere that serves them.

*Costs:* a monthly bill, a migration of the real cellar data mid-harvest, and a
dependency on somebody else's uptime during the three weeks when being unable to
record a weighing costs a bin. It also needs a decision this repo has deliberately
not taken: an external service, which is a standing consult.

*Effort:* half a day, and not during harvest.

## The recommendation

**Route 1 through the end of this harvest, route 3 after it.**

Two interns on a tailnet for three weeks is a known quantity. Moving the live
record of a harvest onto a new host in the middle of that harvest is not, and the
build order in spec.md is ordered by irrecoverability for exactly this reason: a
bad afternoon on the task board is an afternoon, and a bin that cannot be
reconstructed is gone.

If he wants route 2 anyway, the sequence is not negotiable: **rotate the keys
first, then funnel.** The invite gate is already in place and waiting.

## What an intern actually does, once the link exists

1. He opens Letting somebody in, under Set up, and makes an invite. It says a
   six-character code.
2. He reads it to them.
3. They open the link, tap Add to Home Screen, sign up, and type the code.
4. They are a cellar user: they can record, and they cannot hand out invites.

If the code is overheard it is worth nothing twice, and if it sits unused for a
week it expires. The one that was used keeps his name on it, because who let
somebody in is the only record there will ever be.
