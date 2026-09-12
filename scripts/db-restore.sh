#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Puts a backup back after a reset. Imperfect by S-29: seeded vocabulary is reissued with new ids on every reset, so restored lots point at varieties that no longer exist."
# Depends on: [scripts/db-backup.sh, docs/sorry-ledger.md]
# Depended on by: [docs/status-ledger.md]
# ---------------------------------------------------------------------------
# Puts a backup back after a reset. Takes the file to restore, or the newest.
set -euo pipefail

: "${DATABASE_URL:=postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
FILE="${1:-$(ls -1t backups/*.sql 2>/dev/null | head -1)}"

if [ -z "${FILE:-}" ] || [ ! -f "$FILE" ]; then
  echo "no backup to restore. Run: bun run db:backup" >&2
  exit 1
fi

echo "restoring $FILE"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "$FILE" >/dev/null
echo "restored"
