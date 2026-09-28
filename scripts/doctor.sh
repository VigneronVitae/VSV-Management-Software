#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Asks a database what looks wrong and says it in sentences, failing
#           when anything is wrong rather than merely worth a look."
# Depends on: [supabase/migrations/0155_doctor.sql]
# Depended on by: [README.md, scripts/green.sh, docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
# Usage: bun run doctor                  the cellar
#        bun run doctor -- --practice    the practice stack
#        bun run doctor -- --container X any database container with 0155 in it
#        bun run doctor -- --database D  another database in that container, which
#                                        is how scripts/green.sh asks its scratch copies
#
# Everything is in `doctor()`, in the kernel, so the checks are the same
# whether this asks or an app does. This only chooses a database, reads the
# answer in a read-only transaction and decides the exit code: 1 when anything
# is `wrong`, 0 when there is nothing or only things to `look` at, 2 when the
# question could not be asked at all. A doctor that cannot reach the patient
# does not get to say it is healthy.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

CONTAINER="${VSV_DB_CONTAINER:-supabase_db_vsv-management-software}"
DATABASE=postgres
WHICH="the cellar"
while [ $# -gt 0 ]; do
  case "$1" in
    --practice)  CONTAINER="supabase_db_vsv-sandbox"; WHICH="practice" ;;
    --container) shift; CONTAINER="${1:-}"; WHICH="$CONTAINER" ;;
    --database)  shift; DATABASE="${1:-}"; WHICH="$DATABASE" ;;
    *) echo "doctor: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

out=$(docker exec -i "$CONTAINER" psql -U postgres -d "$DATABASE" -X -q -At -F $'\t' \
        -v ON_ERROR_STOP=1 2>&1 <<'SQL'
begin transaction read only;
-- A dash rather than nothing, because read collapses two tabs into one and
-- an empty field would shift every field after it.
select severity, check_name, coalesce(sorry, '-'), said
  from doctor()
 order by severity desc, check_name, said;
rollback;
SQL
)
if [ $? -ne 0 ]; then
  echo "doctor: could not ask $WHICH ($CONTAINER):" >&2
  printf '%s\n' "$out" | head -5 | sed 's/^/  /' >&2
  exit 2
fi

wrong=0
look=0
while IFS=$'\t' read -r severity check sorry said; do
  [ -z "$severity" ] && continue
  case "$severity" in
    wrong) wrong=$((wrong + 1)); printf 'WRONG  %s: %s\n' "$check" "$said" ;;
    look)  look=$((look + 1))
           printf 'look   %s: %s%s\n' "$check" "$said" "$([ "$sorry" != "-" ] && printf ' (known, %s)' "$sorry")" ;;
  esac
done <<< "$out"

if [ "$wrong" -gt 0 ]; then
  echo "doctor: $wrong wrong, $look to look at, in $WHICH"
  exit 1
fi
if [ "$look" -gt 0 ]; then
  echo "doctor: nothing wrong in $WHICH; $look to look at"
else
  echo "doctor: nothing wrong in $WHICH"
fi
exit 0
