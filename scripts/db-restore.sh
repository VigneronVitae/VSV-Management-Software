#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Puts a backup back into a freshly migrated database, exactly as it was dumped, and refuses to commit unless every table's row count and every foreign key agree with the backup."
# Depends on: [scripts/db-backup.sh, docs/sorry-ledger.md]
# Depended on by: [docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
#   bun run db:restore -- --into practice [file]
#   bun run db:restore -- --into cellar   [file]
#
# The file defaults to the newest backup in backups/ or $VSV_BACKUP_DIR.
#
# **Until 2026-09-27 no backup this project had ever taken could be restored.**
# Tested by resetting the practice stack and restoring the previous night's
# backup into it, which is what a disaster would ask of it. Two things failed:
#
#   * The old restore merged: every INSERT carried `ON CONFLICT DO NOTHING` so
#     the rows migrations had already seeded were skipped. But the clause was
#     added by a sed that only saw single-line statements, and 27 rows span
#     several lines (a note with a line break, a registry row holding SQL), so
#     the first of those hit a duplicate key and the restore stopped.
#   * Behind it, S-29. A freshly migrated database has seeded every vocabulary
#     row with a new random id, so the backup's own `chardonnay`, with the id
#     every lot points at, was the row being skipped as a duplicate. Had the
#     restore got that far, every lot would have pointed at a variety that did
#     not exist.
#
# **So this does not merge.** Inside one transaction it empties every table in
# `public`, including the vocabulary the migrations just seeded, and loads the
# backup verbatim, original ids and all. Triggers and foreign key checks are
# suspended while it loads (`session_replication_role = replica`, which is why
# this runs as `supabase_admin`), because the rows were consistent when they
# were dumped and a trigger re-deciding them on the way back in could change
# them. Then, before committing, it checks what it suspended:
#
#   * every table holds exactly as many rows as the backup has INSERTs for it;
#   * every foreign key in `public` holds, row by row.
#
# Either failing rolls the whole thing back and the database is as it was.
#
# **It refuses a database that already holds a cellar.** Restoring over real
# data would replace it, and the moment somebody reaches for this is the
# moment they are least likely to have checked which database they pointed it
# at. Reset first (`bun run db:reset` for the cellar, `practice reset` for
# practice), which is also what makes the schema match the backup's.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 2

INTO=""
FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --into) INTO="${2:-}"; shift 2 ;;
    *) FILE="$1"; shift ;;
  esac
done

case "$INTO" in
  cellar)   CONTAINER="${VSV_DB_CONTAINER:-supabase_db_vsv-management-software}"; STORAGE="supabase_storage_vsv-management-software" ;;
  practice) CONTAINER="supabase_db_vsv-sandbox"; STORAGE="supabase_storage_vsv-sandbox" ;;
  *)
    echo "say where: --into practice, or --into cellar. There is no default, on purpose." >&2
    exit 2
    ;;
esac

if [ -z "$FILE" ]; then
  FILE="$(ls -1t "${VSV_BACKUP_DIR:-backups}"/vsv-*.sql 2>/dev/null | head -1 || true)"
fi
if [ -z "${FILE:-}" ] || [ ! -f "$FILE" ]; then
  echo "no backup to restore. Run: bun run db:backup" >&2
  exit 1
fi

q() { docker exec "$CONTAINER" psql -U supabase_admin -d postgres -At -c "$1"; }

docker exec "$CONTAINER" true 2>/dev/null || { echo "the $INTO database is not running" >&2; exit 1; }

# The door.
held=$(q "select (select count(*) from public.node) + (select count(*) from public.bank_line) + (select count(*) from public.event);" 2>/dev/null || echo "?")
if [ "$held" != "0" ]; then
  echo "the $INTO database already holds records ($held lots, bank lines and events). A restore replaces everything, so it only goes into a freshly reset one." >&2
  exit 1
fi

# The schema has to be the one the backup was taken from: the dump is one
# positional INSERT per row, and a column added since would shift every value
# after it. Backups since 2026-09-27 say which migration they were taken at.
want=$(sed -n 's/^-- schema: \([0-9]*\).*/\1/p' "$FILE" | head -1)
have=$(q "select max(version) from supabase_migrations.schema_migrations;")
if [ -n "$want" ] && [ "$want" != "$have" ]; then
  echo "the backup was taken at migration $want and the $INTO database is at $have. Bring it to $want first; a row written for one schema does not fit another." >&2
  exit 1
fi
[ -n "$want" ] || echo "note: this backup predates the schema line, so it cannot say which migration it was taken at. The counts and keys below still decide."

echo "restoring $FILE into $INTO"

# What the backup says each table holds, so the database can be held to it.
expected=$(grep -oE '^INSERT INTO public\.[a-z_0-9]+ ' "$FILE" | awk '{print $3}' | sed 's/^public\.//' | sort | uniq -c \
  | awk 'BEGIN{ORS=""} {printf "%s(%s, %s)", (NR>1?",":""), "'"'"'" $2 "'"'"'", $1}')

{
  cat <<SQL
\set ON_ERROR_STOP on
begin;
set local session_replication_role = replica;

-- Empty every table, the seeded vocabulary included. Its ids are this
-- database's, and the backup's are the ones every row points at.
do \$\$
declare r record;
begin
  for r in select tablename from pg_tables where schemaname = 'public' loop
    execute format('truncate table public.%I cascade', r.tablename);
  end loop;
end \$\$;
SQL
  # Verbatim, minus the ON CONFLICT clauses older backups carry on public rows,
  # which are harmless into empty tables and kept only on auth and storage
  # rows, where a freshly started stack may already have one.
  cat "$FILE"
  cat <<SQL

-- A sequence is not data, so it came back at one. Moved past what is there.
do \$\$
declare r record; m bigint;
begin
  for r in
    select s.oid::regclass as seq, d.refobjid::regclass as tbl, a.attname as col
      from pg_class s
      join pg_depend d on d.objid = s.oid and d.deptype in ('a', 'i')
      join pg_attribute a on a.attrelid = d.refobjid and a.attnum = d.refobjsubid
     where s.relkind = 'S' and s.relnamespace = 'public'::regnamespace
  loop
    execute format('select max(%I) from %s', r.col, r.tbl) into m;
    if m is not null then
      perform setval(r.seq, m);
    end if;
  end loop;
end \$\$;

create temp table restore_expected (t text, n bigint) on commit drop;
insert into restore_expected values ${expected:-('none', 0)};

do \$\$
declare r record; got bigint; bad text := '';
begin
  for r in select * from restore_expected where t <> 'none' loop
    execute format('select count(*) from public.%I', r.t) into got;
    if got <> r.n then
      bad := bad || format('%s has %s rows and the backup has %s; ', r.t, got, r.n);
    end if;
  end loop;
  if bad <> '' then
    raise exception 'restore refused, nothing was changed: %', bad;
  end if;
end \$\$;

-- Every foreign key, checked by hand because loading suspended the checks.
do \$\$
declare r record; n bigint; bad text := '';
begin
  for r in
    select c.conname,
           c.conrelid::regclass as child,
           c.confrelid::regclass as parent,
           (select string_agg(format('c.%I', a.attname), ', ' order by k.ord)
              from unnest(c.conkey) with ordinality k(attnum, ord)
              join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum) as ccols,
           (select string_agg(format('p.%I', a.attname), ', ' order by k.ord)
              from unnest(c.confkey) with ordinality k(attnum, ord)
              join pg_attribute a on a.attrelid = c.confrelid and a.attnum = k.attnum) as pcols
      from pg_constraint c
     where c.contype = 'f' and c.connamespace = 'public'::regnamespace
  loop
    execute format(
      'select count(*) from %s c where row(%s) is not null and not exists (select 1 from %s p where row(%s) = row(%s))',
      r.child, r.ccols, r.parent, r.pcols, r.ccols) into n;
    if n > 0 then
      bad := bad || format('%s: %s rows in %s point at nothing in %s; ', r.conname, n, r.child, r.parent);
    end if;
  end loop;
  if bad <> '' then
    raise exception 'restore refused, nothing was changed: %', bad;
  end if;
end \$\$;

commit;
SQL
} | docker exec -i "$CONTAINER" psql -U supabase_admin -d postgres -q -v ON_ERROR_STOP=1 >/tmp/vsv-restore.log 2>&1 || {
  echo "restore refused or failed; the $INTO database is unchanged. The reason:" >&2
  grep -E "ERROR|refused" /tmp/vsv-restore.log | head -5 >&2
  exit 1
}

echo "rows: every table matches the backup"
echo "keys: every foreign key holds"

# The photographs. Files, not rows, so they are copied rather than loaded.
PHOTOS="$(dirname "$FILE")/photos"
if [ -d "$PHOTOS" ]; then
  if docker exec "$STORAGE" true 2>/dev/null; then
    docker cp "$PHOTOS/." "$STORAGE:/mnt/" && echo "photos: copied back from $PHOTOS"
  else
    echo "photos: the $INTO storage container is not running, so the photographs were not copied back. The rows that name them were." >&2
  fi
else
  echo "photos: none beside this backup. Backups taken before 2026-09-27 did not include them."
fi
echo "restored"
