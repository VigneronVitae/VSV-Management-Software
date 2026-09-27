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
# **A restore replaces; it does not merge.** Until 2026-09-27 every INSERT was
# made idempotent so a restore could land on top of the rows migrations seed.
# That never worked: the clause was added only to single-line statements, and
# the seeded vocabulary has new ids after every reset (S-29), so merging would
# have skipped exactly the rows everything points at. scripts/db-restore.sh now
# empties the tables and loads this file verbatim, so public rows carry no
# ON CONFLICT and the file says which migration it was taken at, because a
# positional INSERT only fits the schema it came from.
#
# **The photographs go with it.** The scale photographs, the vessel photos and
# the receipts live as files in the storage container, not as rows, and until
# 2026-09-27 no backup included them. The storage rows that name them are
# dumped here, and the files are mirrored into `photos/` beside the SQL.
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

# Which migration this was taken at. Read with the same tool the dump uses.
if command -v psql >/dev/null 2>&1; then
  SCHEMA=$(psql "$DATABASE_URL" -At -c "select max(version) from supabase_migrations.schema_migrations;" 2>/dev/null || true)
else
  SCHEMA=$(docker exec "${CONTAINER:-supabase_db_vsv-management-software}" psql -U postgres -d postgres -At \
    -c "select max(version) from supabase_migrations.schema_migrations;" 2>/dev/null || true)
fi

idempotent() { sed -E 's/^(INSERT INTO .*);$/\1 ON CONFLICT DO NOTHING;/'; }

# pg_dump on Windows writes every newline as CRLF, including the newlines
# inside a value: a note with a line break comes out with a carriage return
# in it that the note never had. Git Bash's sed and grep read in text mode and
# hide this, which is why the old pipeline, which sent everything through sed,
# happened to be right, and why removing sed from the public rows on
# 2026-09-27 put a stray \r into three tables. Found by restoring and comparing
# every table's checksum against the live cellar. `-b` reads the bytes as they
# are, and `\r$` removes exactly the one carriage return Windows added, so a
# value that really held CRLF keeps its own.
unwindows() { sed -b 's/\r$//'; }

{
  echo "-- Vitae Springs data, $(date)."
  echo "-- schema: ${SCHEMA:-unknown}"
  echo "-- Restore with: bun run db:restore -- --into cellar, onto a freshly reset database."
  # A fresh stack may already have an account or a bucket, so these two keep
  # the clause. Every row in public goes into an emptied table and needs none.
  dump --data-only --inserts -t auth.users | unwindows | idempotent
  dump --data-only --inserts -n public | unwindows
  dump --data-only --inserts -t storage.buckets -t storage.objects | unwindows | idempotent
} > "$TMP"

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
echo "schema: ${SCHEMA:-unknown}"

# The photographs. One mirror beside the dumps rather than a copy per night,
# because an uploaded photograph is never overwritten (every upload is
# `upsert: false` under a new path), so last night's mirror plus tonight's new
# files is every photograph there has been.
#
# A copy that fails says so and exits non-zero, after the SQL is safely
# written: the rows are the harder thing to lose, and a backup that quietly
# left the photographs out is the A13 shape this script was rewritten to end.
STORAGE="${VSV_STORAGE_CONTAINER:-supabase_storage_vsv-management-software}"
PHOTOS="$VSV_BACKUP_DIR/photos"
if docker exec "$STORAGE" true 2>/dev/null; then
  mkdir -p "$PHOTOS"
  if docker cp "$STORAGE:/mnt/." "$PHOTOS/" 2>/dev/null; then
    echo "photos: $(find "$PHOTOS" -type f | wc -l | tr -d ' ') files in $PHOTOS"
  else
    echo "photos: the copy out of $STORAGE failed. The rows are backed up; the photographs are NOT." >&2
    exit 4
  fi
else
  echo "photos: no running $STORAGE, so the photographs are NOT backed up. The rows are." >&2
  exit 4
fi
