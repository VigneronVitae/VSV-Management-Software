---
Type: reference
Purpose: "The shortest path from a fresh clone to a real record in the database, and the way to stand up an isolated stack so that walking it a second time cannot touch a cellar that has wine in it."
Depends on: [README.md]
Depended on by: [docs/session-reports/index.md]
---

# The first run

This is convenience, not verification. It records what W-8 had to work out, so
that the next run is cheaper than that one was. Nothing here is a check and
nothing here should be cited as evidence that anything works.

## The walk that produces a record

Six screens, admin, about two minutes. Every step writes and each is verifiable
in the database afterwards.

1. **Create an account.** Email and a password of at least six characters. The
   first account to name itself becomes the administrator, decided by
   `claim_account` rather than by the client.
2. **Name yourself.** This writes the `app_user` row.
3. **Name the facility.** Nothing can be created before this, because every lot
   has an owner and lots default to the facility party. The screen says so.
4. **Vessel and wine.** Type, name, capacity; variety, vintage, product type,
   volume. One call to `create_vessel_with_wine`, which writes the vessel, the
   lot and the placement together.
5. **Empty vessel.** A second vessel, so there is somewhere to rack to.
6. **Rack.** Choose out of, litres, **Add**; into, litres, **Add**. The rows have
   to be added, and the preview stays empty until they are. The preview is a call
   to `rack_plan`, so what it says a rack means is the kernel's answer and not the
   client's. Then **Rack it**.

Afterwards:

```sh
psql "$DATABASE_URL" -c "select v.name, p.volume_l, p.to_at is null as open, n.name, n.quantity
  from placement p join vessel v on v.id = p.vessel_id join node n on n.id = p.node_id order by v.name"
psql "$DATABASE_URL" -c "select t.value, e.provenance from event e join term t on t.id = e.operation_id"
```

A clean run leaves the source placement closed at what it held, the destination
open at what arrived, the lot's quantity down by the loss, and exactly one `rack`
event marked `observed`.

## Standing up a stack that is not the winery's

`project_id` in `supabase/config.toml` is fixed, so the CLI derives container
names from it and every clone on a machine drives the same stack. To get an
isolated one, change these in the clone before `supabase start`:

| Key | To |
|---|---|
| `project_id` | anything else, `vsv-scratch` |
| `[api] port` | 55321 |
| `[db] port` | 55322 |
| `[db] shadow_port` | 55320 |
| `[studio] port` | 55323 |
| `[inbucket] port` | 55324 |
| `[auth] site_url` | `http://localhost:5173` |

Then `VITE_SUPABASE_URL=http://127.0.0.1:55321` in `apps/web/.env.local` with the
anon key that `supabase start` prints, which differs per stack.

**Do this before running anything against a database with wine in it.** The
config comment about `site_url` says a fresh clone should change it because
GoTrue silently rejects a redirect to a host it does not name; the same sentence
is true of every other value in that table for a different reason.

## Two things the walk does not tell you

**A second dev server picks a different port.** Vite takes 5174, then 5175, and
`additional_redirect_urls` names 5173 only. Nothing in this client uses a
redirect flow today, so it does not bite, and it will the moment one is added.

**The account a custom crush client creates is staff until it is attached.** The
Clients screen says so in as many words. There is no way to attach a login that
does not yet exist, so the window is structural rather than an oversight, and
during it that account can read every lot in the cellar.
