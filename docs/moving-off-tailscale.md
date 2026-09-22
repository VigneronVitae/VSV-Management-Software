---
Type: runbook
Purpose: "Everything needed to serve this winery's apps through Cloudflare Tunnel instead of Tailscale, in the order it has to happen, with the parts that are mine separated from the parts that are his."
Depends on: [scripts/watchdog.ps1, docs/first-run.md]
Depended on by: [docs/status-ledger.md,
                 packages/core/src/where.ts,
                 deploy/cloudflared/config.yml]
---

# Moving off Tailscale

Written 2026-09-21, the day before the Tailscale trial expires.

## Why the bill arrived

The tailnet is registered as `vitaesprings.com`. Tailscale classifies a tailnet
created under a custom domain as business use automatically, and puts it on a
trial rather than the free Personal plan. It is not about volume: this tailnet
has one user and two devices, which is comfortably inside Personal's limits of
six users and unlimited devices.

Whether a winery's operations network is commercial use is a real question and
Tailscale's answer is yes. This document does not argue with that.

## The thing that makes this a migration rather than a swap

**The API hostname is compiled into every app.** `VITE_SUPABASE_URL` is read at
build time, so each of the five bundles contains
`https://vsv-desktop.tail7e3cc4.ts.net:8443` as a literal string. Serving the
apps from somewhere else changes where the HTML comes from and not where the data
comes from, and the data is the part that stops working.

Three consequences, in increasing order of annoyance:

1. Every app has to be rebuilt after the endpoint changes.
2. The Supabase API itself has to be routed, not just the five apps.
3. **Everybody is signed out.** supabase-js keeps the session in `localStorage`,
   which is per origin, and the origin changes. Installed PWAs point at the old
   origin and have to be re-added to the home screen.

None of that is hard. All of it is badly timed: there are thirteen open lots and
fruit still coming.

## The recommendation

**Pay Tailscale for one month and do this after harvest.** Starter is $6 per user
per month. The migration below is perhaps three hours including testing, and the
failure mode if it goes wrong at 6am is that nobody can record a pressing.

This document exists so that the decision is a decision. If the answer is to do
it now, everything is here.

**Decided 2026-09-22: Tailscale paid for one month.** The move happens after
harvest, before that month runs out (around 2026-10-22).

One thing has changed since this was written, and it makes the move smaller.
`packages/core/src/where.ts` means the API hostname is no longer compiled in:
each app reads `where.json` beside it, which already lists Cloudflare first and
Tailscale second, and uses whichever answers. So steps 8 and 9 below, the five
`.env.local` edits and the five rebuilds, are no longer needed, and rolling back
is editing `where.json` rather than rebuilding. The origin still changes for the
apps themselves, so the one-time sign-out in consequence 3 still applies.

## What is already true

- `cloudflared` 2026.8.3 is installed on the desktop.
- A quick tunnel works from this machine, outbound only, no ports opened. Proven
  2026-09-21: `cloudflared tunnel --url http://localhost:5177` returned a working
  `trycloudflare.com` hostname and registered two connections.
- `vite preview --base /books/` serves correctly under a path prefix, which
  matters because **cloudflared does not strip path prefixes and
  `tailscale serve --set-path` does**. Without `--base` every app would 404
  behind Cloudflare.
- Every app is built with `base: "./"`, so relative assets resolve under any
  prefix. No manifest changes, no URL changes, no PWA reinstall, as long as the
  path structure is kept.

## The DNS problem, and the safe way round it

`vitaesprings.com` is on Google Cloud DNS, and mail is Google Workspace: five MX
records. The usual Cloudflare Tunnel setup asks you to move the zone's
nameservers to Cloudflare, which imports the records automatically and
occasionally imperfectly. **Doing that to a zone carrying live business email,
the day before a deadline, is the part of this plan most likely to cause real
damage.**

Instead, delegate one subdomain:

1. Add `vsv.vitaesprings.com` to Cloudflare as its own zone.
2. Cloudflare assigns two nameservers for it.
3. In Google Cloud DNS, add **NS** records for the `vsv` label pointing at those
   two nameservers.

The apex, `www`, and every MX record stay at Google and are never touched. Only
`vsv.vitaesprings.com` and things under it resolve through Cloudflare.

A CNAME from Google Cloud DNS straight to `<id>.cfargotunnel.com` does not work:
those names only resolve for zones Cloudflare serves, because Cloudflare has to
terminate the TLS and route the connection.

## Steps that are his

These need a Cloudflare account and a browser, and cannot be done by an agent.

1. **Sign in to Cloudflare** and add `vsv.vitaesprings.com` as a zone. Free plan.
2. **`cloudflared tunnel login`** on the desktop. Opens a browser, authorises the
   machine, writes a certificate to `%USERPROFILE%\.cloudflared\cert.pem`.
3. **`cloudflared tunnel create vsv`**. Prints a tunnel UUID and writes
   `%USERPROFILE%\.cloudflared\<uuid>.json`. Put the UUID into the config below.
4. **Route the hostname**: `cloudflared tunnel route dns vsv vsv.vitaesprings.com`
5. **Add the NS records** at Google Cloud DNS as described above, and wait for
   them to resolve. `nslookup -type=ns vsv.vitaesprings.com` tells you when.
6. **Cloudflare Access**, optional and recommended: a policy on
   `vsv.vitaesprings.com` allowing the four email addresses. Free to fifty users.
   Without it the apps are publicly reachable and defended only by their own
   sign-in screens, which is the same posture as any web app but is a choice
   worth making deliberately.

## Steps that are mine

Once the tunnel exists and the UUID is known:

7. Put the UUID in `deploy/cloudflared/config.yml`.
8. Change `VITE_SUPABASE_URL` in all five `apps/*/.env.local` from
   `https://vsv-desktop.tail7e3cc4.ts.net:8443` to
   `https://api.vsv.vitaesprings.com`, and `VITE_PRACTICE_URL` from `:8444` to
   `https://practice.vsv.vitaesprings.com`.
9. Rebuild all five apps.
10. Change `scripts/watchdog.ps1` to start each preview with its `--base`, since
    Cloudflare does not strip the prefix.
11. Run `cloudflared tunnel run vsv`, and install it as a Windows service so it
    survives a reboot: `cloudflared service install`.

## The order that matters

Do **not** turn Tailscale off until the new path is proven. Both can run at once:
they are separate outbound connections and neither knows about the other. Keep
Tailscale until a phone has signed in through Cloudflare and recorded something.

## Rolling back

Change the five `.env.local` files back, rebuild, and stop `cloudflared`.
Tailscale is untouched throughout. The only thing not recoverable by that route
is the signed-out sessions, and those cost a sign-in each.

## If the deadline wins

A quick tunnel needs no account, no DNS and no zone:

    cloudflared tunnel --url http://localhost:5176

It prints a random `trycloudflare.com` hostname that changes on every restart and
has no access control. It is a way not to be locked out of the cellar app for an
afternoon. It is not a way to run a winery, and the Supabase endpoint would need
its own tunnel and its own rebuild, which is most of the work above anyway.
