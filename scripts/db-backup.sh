#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Writes everything in the cellar to a file that can be restored after a reset, because supabase db reset destroys it and the winemaker asked whether the app always has to."
# Depends on: [CLAUDE.md]
# Depended on by: [docs/status-ledger.md, scripts/db-restore.sh, scripts/practice.sh]
# ---------------------------------------------------------------------------
# Everything you have entered, saved to a file you can restore after a reset.
#
# Two things make this less obvious than it looks.
#
# The local `postgres` role is not a superuser, so pg_dump --disable-triggers is
# refused: it cannot switch off the foreign key triggers it would need to. So
# the dump is written as one INSERT per row, in dependency order, and the
# triggers simply run.
#
# And a restore lands on a database where the migrations have already run, so
# every row the migrations seed is already there. Rather than exclude those
# tables, which would also throw away the varieties and coopers you added
# yourself, every insert is made idempotent. Restoring twice is the same as
# restoring once.
# **This script used to be able to fail and leave a file behind that looked like
# a backup.** It wrote its header, ran pg_dump, and redirected straight at the
# final path, so a machine with no pg_dump on its PATH produced a 120 byte file
# in backups/ containing three comment lines and no rows. Found on the morning
# of the first pick, four days after the last real backup. That is this
# project's standing failure mode, a refusal that returns success, arriving in
# the one place where believing it costs the vintage.
#
# So: the dump is built in a temporary file, counted, and only moved into place
# if it actually contains rows. A run that cannot dump leaves nothing behind.
set -euo pipefail

: "${DATABASE_URL:=postgresql://postgres:postgres@127.0.0.1:54322/postgres}"

# pg_dump is not necessarily installed on the machine running this: on a
# Supabase local stack it lives inside the database container, and the client
# tools are not a separate install anybody remembers to do. Prefer the real one,
# fall back to the container, refuse if neither is there.
if command -v pg_dump >/dev/null 2>&1; then
  dump() { pg_dump "$DATABASE_URL" "$@"; }
  VIA="pg_dump on this machine"
else
  CONTAINER=$(docker ps --filter "name=supabase_db" --format '{{.Names}}' 2>/dev/null | head -1)
  if [ -z "$CONTAINER" ]; then
    echo "backup: no pg_dump on this machine and no running supabase_db container to borrow one from." >&2
    echo "backup: nothing was written. The cellar is NOT backed up." >&2
    exit 1
  fi
  dump() { docker exec "$CONTAINER" pg_dump -U postgres -d postgres "$@"; }
  VIA="pg_dump inside $CONTAINER"
fi

# Where the file lands. Defaults to the repository, which is where a person
# running this by hand expects it, and is overridden by the watchdog so the
# unattended daily copy lands on a different physical drive from the one the
# repository is on. Two fatal storage errors on D: in sixty days is the reason:
# a backup on the drive that is failing is a backup of the wrong thing.
: "${VSV_BACKUP_DIR:=backups}"

mkdir -p "$VSV_BACKUP_DIR"
OUT="$VSV_BACKUP_DIR/vsv-$(date +%Y%m%d-%H%M%S).sql"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

{
  echo "-- Vitae Springs data, $(date)."
  echo "-- Restore with: bun run db:restore"
  echo "-- Safe to run more than once."
  dump --data-only --inserts -t auth.users
  dump --data-only --inserts -n public
} | sed -E 's/^(INSERT INTO .*);$/\1 ON CONFLICT DO NOTHING;/' > "$TMP"

ROWS=$(grep -c "^INSERT" "$TMP" || true)

# A cellar with nothing in it is a real state and an empty dump of it is a
# correct answer, but it is indistinguishable from a dump that failed, and only
# one of those is safe to keep. So the empty case is said out loud.
if [ "$ROWS" -eq 0 ]; then
  echo "backup: the dump came back with no rows at all, via $VIA." >&2
  echo "backup: nothing written, because a file with no rows is indistinguishable from a backup that failed." >&2
  exit 1
fi

mv "$TMP" "$OUT"
trap - EXIT
echo "$OUT"
echo "rows: $ROWS"
echo "via:  $VIA"
