#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Writes everything in the cellar to a file that can be restored after a reset, because supabase db reset destroys it and the winemaker asked whether the app always has to."
# Depends on: [CLAUDE.md]
# Depended on by: [docs/status-ledger.md, scripts/db-restore.sh]
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
set -euo pipefail

: "${DATABASE_URL:=postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
mkdir -p backups
OUT="backups/vsv-$(date +%Y%m%d-%H%M%S).sql"

{
  echo "-- Vitae Springs data, $(date)."
  echo "-- Restore with: bun run db:restore"
  echo "-- Safe to run more than once."
  pg_dump "$DATABASE_URL" --data-only --inserts -t auth.users
  pg_dump "$DATABASE_URL" --data-only --inserts -n public
} | sed -E 's/^(INSERT INTO .*);$/\1 ON CONFLICT DO NOTHING;/' > "$OUT"

echo "$OUT"
grep -c "^INSERT" "$OUT" | xargs echo "rows:"
