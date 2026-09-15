#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Runs the practice stack: a second, identical database with nothing
#           real in it, where trying a thing and throwing it away is allowed."
# Depends on: [scripts/db-backup.sh]
# Depended on by: [docs/practice-mode.md, scripts/db-reset-guard.sh]
# ---------------------------------------------------------------------------
#
# The winemaker: "how can I have a server or delete things or whatever so I can
# actually play around and try out things and delete them later, but also use
# the app to record".
#
# **The honest answer was that he could not.** Everything went into one cellar,
# and the schema makes events and lineage deliberately hard to delete, which is
# right for a real record and useless for trying something. So there are two
# stacks: the cellar, where nothing may be reset, and this one, where anything
# may.
#
# His framing of the switch is the one that shaped this: "maybe it's a debugging
# mode that actually ships". So practice mode is a feature every winery gets
# rather than a thing wired up for one person, and the words here are written
# for a winemaker rather than for whoever wrote it.
#
# Every command below names the practice stack explicitly. None of them can
# reach the cellar, which is why they are in their own file rather than as flags
# on the scripts that can.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

WORKDIR=sandbox
CELLAR_DB_CONTAINER="${VSV_DB_CONTAINER:-supabase_db_vsv-management-software}"
PRACTICE_DB_CONTAINER="supabase_db_vsv-sandbox"

say() { printf '%s\n' "$*"; }
die() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }

command -v supabase >/dev/null 2>&1 || PATH="$PATH:$HOME/scoop/shims"
command -v supabase >/dev/null 2>&1 || die "the supabase cli is not on PATH"

case "${1:-}" in

start)
  supabase start --workdir "$WORKDIR" || die "the practice stack did not start"
  say "Practice stack up. API on 54421, database on 54422, studio on 54423."
  ;;

stop)
  supabase stop --workdir "$WORKDIR"
  ;;

up)
  supabase migration up --workdir "$WORKDIR" || die "migrations did not apply"
  ;;

# Everything this script exists for. Safe here and nowhere else.
reset)
  say "Resetting the practice stack. The cellar is not touched."
  supabase db reset --workdir "$WORKDIR" || die "the reset failed"
  say "Done. Practice is empty, with the seeded vocabulary and nothing else."
  ;;

# A copy of the cellar to play with, which is what makes practice useful on the
# first day rather than after an hour of typing.
#
# **This reads the cellar and never writes to it.** `pg_dump` is the only thing
# here that touches it, the same as scripts/green.sh.
seed)
  docker exec "$CELLAR_DB_CONTAINER" true 2>/dev/null \
    || die "the cellar stack is not running, so there is nothing to copy"
  docker exec "$PRACTICE_DB_CONTAINER" true 2>/dev/null \
    || die "the practice stack is not running. Run practice start first"

  say "Copying the cellar into practice. This replaces whatever is in practice now."
  # Through a file rather than a pipe between two containers. X-1-13: a pipe
  # reports the reader's status, psql exits zero on empty input, and a dump that
  # produced nothing then looks like a success.
  tmp="$(mktemp)"
  if ! docker exec "$CELLAR_DB_CONTAINER" \
       pg_dump -U postgres -d postgres --no-owner --no-privileges > "$tmp"; then
    rm -f "$tmp"; die "could not read the cellar"
  fi
  lines=$(wc -l < "$tmp")
  if [ "$lines" -lt 100 ]; then
    rm -f "$tmp"; die "the dump is $lines lines, which is not a cellar"
  fi

  docker exec "$PRACTICE_DB_CONTAINER" \
    psql -U postgres -d postgres -q \
    -c "drop schema if exists public cascade; create schema public;" >/dev/null 2>&1 \
    || { rm -f "$tmp"; die "could not clear practice"; }

  if ! docker exec -i "$PRACTICE_DB_CONTAINER" psql -U postgres -q -d postgres < "$tmp" \
       > /tmp/practice-seed.log 2>&1; then
    say "psql reported problems; see /tmp/practice-seed.log"
  fi
  rm -f "$tmp"

  rows=$(docker exec "$PRACTICE_DB_CONTAINER" psql -U postgres -At -d postgres \
           -c "select count(*) from pg_tables where schemaname = 'public';" 2>/dev/null)
  [ "${rows:-0}" -gt 0 ] || die "practice has ${rows:-0} tables, so the copy did not land"
  say "Practice now has $rows tables copied from the cellar."
  say
  say "Note: logins are per stack, so rows copied in will read as recorded by"
  say "nobody until you sign up in practice and record something yourself."
  ;;

status)
  for pair in "cellar:$CELLAR_DB_CONTAINER" "practice:$PRACTICE_DB_CONTAINER"; do
    name="${pair%%:*}"; container="${pair##*:}"
    if docker exec "$container" pg_isready -U postgres >/dev/null 2>&1; then
      n=$(docker exec "$container" psql -U postgres -At -d postgres \
            -c "select count(*) from node;" 2>/dev/null)
      say "$name: up, ${n:-?} lots"
    else
      say "$name: down"
    fi
  done
  ;;

*)
  cat <<'USAGE'
practice start   bring the practice stack up
practice up      apply migrations to it
practice seed    copy the cellar into it, to have something to play with
practice reset   empty it and start again. Allowed here and nowhere else
practice status  which stacks are up and how much is in each
practice stop    shut it down
USAGE
  ;;
esac
