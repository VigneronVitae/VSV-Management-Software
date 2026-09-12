#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Runs the whole definition of green in one command: the checker, the
#           compiler, the linter, every migration from empty into a scratch
#           database, and the assertion suite against both that scratch database
#           and a copy of the cellar. Every phase of the modularization has to
#           end green and this is what says whether it did."
# Depends on: [scripts/verify.sh, tests/shim.sql, tests/schema_assertions.sql]
# Depended on by: [docs/session-reports/modularization-progress.md, docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
# Nothing here writes to the cellar database. The scratch database and the cellar
# copy are both created and dropped by this script; the cellar itself is only
# ever read, by pg_dump. If you are reading this while wondering whether running
# it during harvest is safe: the only statements that touch the cellar are
# `pg_dump` and the `select` that counts its tables.
#
# Bash and standard tools, plus the docker exec that every other database command
# in this repository already uses.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

CONTAINER="${VSV_DB_CONTAINER:-supabase_db_vsv-management-software}"
CELLAR="${VSV_CELLAR_DB:-postgres}"
SCRATCH=vsv_green_scratch
COPY=vsv_green_cellar_copy

fails=0
step() { printf '\n=== %s\n' "$*"; }
ok()   { printf 'ok    %s\n' "$*"; }
bad()  { printf 'FAIL  %s\n' "$*"; fails=$((fails + 1)); }

psql_() { docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 "$@"; }
admin() { docker exec "$CONTAINER" psql -U postgres -q -d postgres "$@"; }

# X-1-17: this used to exit here, so verify, typecheck and lint could not run
# in a clean clone with no stack up. Those three need no database. The database
# gates below fail loudly instead, which is the honest outcome: three of six
# passed and three could not be attempted.
db_up=yes
if ! docker exec "$CONTAINER" true 2>/dev/null; then
  db_up=no
fi

# ---------------------------------------------------------------------------
step "1. bun run verify"
# ---------------------------------------------------------------------------
if bash scripts/verify.sh > /tmp/green-verify.log 2>&1; then
  ok "$(tail -1 /tmp/green-verify.log | sed 's/^ok *//')"
else
  bad "verify: $(grep -c '^FAIL' /tmp/green-verify.log) problem(s), see /tmp/green-verify.log"
  grep '^FAIL' /tmp/green-verify.log | head -5 | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
step "2. bun run typecheck and bun run lint"
# ---------------------------------------------------------------------------
if bun run typecheck > /tmp/green-tsc.log 2>&1; then ok "typecheck, zero errors"
else bad "typecheck"; tail -5 /tmp/green-tsc.log | sed 's/^/      /'; fi

if bun run lint > /tmp/green-lint.log 2>&1; then ok "lint"
else bad "lint"; grep -E '^\S+\.(ts|json|css)' /tmp/green-lint.log | head -5 | sed 's/^/      /'; fi

# ---------------------------------------------------------------------------
step "3. every migration from empty, into a scratch database"
# ---------------------------------------------------------------------------
if [ "$db_up" != yes ]; then
  bad "cannot reach the database container $CONTAINER, so gates 3 to 5 were not attempted"
fi

# The shim first, because 0002 cannot apply without the realtime publication and
# every policy after it calls auth.uid(). tests/shim.sql says which needs which.
#
# Every database create and drop below is checked. X-1-14 found the harness
# discarding these, which lets an iteration run against a database that is not
# the one it thinks it built.
[ "$db_up" = yes ] && admin -c "drop database if exists $SCRATCH;" >/dev/null 2>&1
scratch_ok=no
if [ "$db_up" = yes ]; then
  if admin -c "create database $SCRATCH;" >/dev/null 2>&1; then
    scratch_ok=yes
  else
    bad "could not create the scratch database, so nothing below this line ran"
  fi
fi

if [ "$scratch_ok" = yes ] && ! psql_ -q -d "$SCRATCH" < tests/shim.sql > /tmp/green-shim.log 2>&1; then
  bad "the shim did not apply"; tail -5 /tmp/green-shim.log | sed 's/^/      /'
  scratch_ok=no
fi

applied=0; broke=""
if [ "$scratch_ok" = yes ]; then
  for f in supabase/migrations/0*.sql; do
    if psql_ -q -d "$SCRATCH" < "$f" > /tmp/green-mig.log 2>&1; then
      applied=$((applied + 1))
    else
      broke="$f"; break
    fi
  done
fi
total=$(ls supabase/migrations/0*.sql | wc -l | tr -d ' ')
if [ "$scratch_ok" != yes ]; then
  bad "migrations not attempted: there is no scratch database to apply them to"
elif [ -n "$broke" ]; then
  bad "$(basename "$broke") did not apply from empty ($applied of $total applied first)"
  grep -E '^(ERROR|FATAL)' /tmp/green-mig.log | head -3 | sed 's/^/      /'
else
  ok "$applied of $total migrations apply clean from empty"
fi

# ---------------------------------------------------------------------------
# How an assertion run is judged
# ---------------------------------------------------------------------------
#
# X-1-3: these gates used to decide by an anchored grep over the log, and psql's
# own client-side failures are written as `psql: error: ... FATAL: ...` with the
# FATAL mid-line, so the anchor missed them. A run that never happened reported
# ok. Running step 5's old code against a database that does not exist printed
# `ok 0 assertions pass`.
#
# Three things are required now, and all three are necessary. The exit status
# must be zero, because that is what ON_ERROR_STOP actually reports. There must
# be at least one `ok` notice, because a suite that connected and did nothing is
# not a pass. And the log must carry the suite's own terminator, because a run
# cut off halfway exits zero on some paths and is not a pass either.
# Sets ASSERT_N rather than echoing it: this printed its own ok line into a
# command substitution on the first attempt, so the run reported nothing at all.
assert_run() {   # $1 database, $2 logfile, $3 label; sets ASSERT_N
  local db="$1" log="$2" label="$3" rc n
  ASSERT_N=0
  psql_ -d "$db" < tests/schema_assertions.sql > "$log" 2>&1
  rc=$?
  n=$(grep -c '^NOTICE:  ok' "$log")

  if [ "$rc" -ne 0 ]; then
    bad "$label: the assertion suite exited $rc"
    grep -E '(ERROR|FATAL)' "$log" | head -3 | sed 's/^/      /'
    return 1
  fi
  if [ "$n" -eq 0 ]; then
    bad "$label: the suite exited zero and asserted nothing, so it did not run"
    tail -3 "$log" | sed 's/^/      /'
    return 1
  fi
  if ! grep -q 'all assertions passed' "$log"; then
    bad "$label: the suite did not reach its own terminator, so it stopped partway"
    tail -3 "$log" | sed 's/^/      /'
    return 1
  fi
  ok "$n assertions pass $label"
  ASSERT_N=$n; return 0
}

# ---------------------------------------------------------------------------
step "4. the assertion suite against that scratch database"
# ---------------------------------------------------------------------------
scratch_n=0
if [ "$scratch_ok" = yes ] && [ -z "$broke" ]; then
  assert_run "$SCRATCH" /tmp/green-assert-scratch.log "against a database built from empty"
  scratch_n=$ASSERT_N
else
  bad "assertions against scratch skipped: the migrations did not apply"
fi

# ---------------------------------------------------------------------------
step "5. the assertion suite against a copy of the cellar"
# ---------------------------------------------------------------------------
# pg_dump is the only thing in this script that touches the cellar, and it reads.
copy_ok=no
if [ "$db_up" = yes ]; then
  admin -c "drop database if exists $COPY;" >/dev/null 2>&1
  if admin -c "create database $COPY;" >/dev/null 2>&1; then
    copy_ok=yes
  else
    bad "could not create the cellar copy database"
  fi
fi

if [ "$copy_ok" = yes ]; then
  # X-1-13: `sh -c "pg_dump | psql"` reports psql's status, psql exits zero on
  # empty input, and pipefail does not reach the child shell. A total dump
  # failure printed `ok cellar copied, 0 tables`. The table count is now the
  # test rather than the decoration.
  docker exec "$CONTAINER" sh -c "pg_dump -U postgres -d $CELLAR | psql -U postgres -q -d $COPY" \
    > /tmp/green-copy.log 2>&1
  rows=$(docker exec "$CONTAINER" psql -U postgres -At -d "$COPY" \
           -c "select count(*) from pg_tables where schemaname not in ('pg_catalog','information_schema');" 2>/dev/null)
  rows=${rows:-0}
  if [ "$rows" -lt 1 ]; then
    bad "the cellar copy has $rows tables, so pg_dump produced nothing"
    tail -5 /tmp/green-copy.log | sed 's/^/      /'
    copy_ok=no
  else
    ok "cellar copied, $rows tables"
  fi
fi

copy_n=0
if [ "$copy_ok" = yes ]; then
  assert_run "$COPY" /tmp/green-assert-copy.log "against a copy of the cellar"
  copy_n=$ASSERT_N
else
  bad "assertions against the cellar copy skipped: there is no usable copy"
fi

# The two counts are allowed to differ, and by exactly one thing: the scratch
# database has no storage schema, so each storage-guarded block emits one notice
# saying it was skipped in place of the two assertions it would otherwise make.
# The expected gap is one per skipped block, counted from the scratch run rather
# than written down.
#
# X-1-3 also found this reconciliation guarded by `[ "$copy_n" -gt 0 ]`, so it
# was skipped in exactly the case where a run had not happened. It now runs
# whenever both gates reported success, and a zero on either side is already a
# failure above.
if [ "$scratch_n" -gt 0 ] && [ "$copy_n" -gt 0 ]; then
  skipped=$(grep -c 'no storage schema here' /tmp/green-assert-scratch.log)
  actual=$((copy_n - scratch_n))
  if [ "$actual" -ne "$skipped" ]; then
    bad "the two runs differ by $actual assertions and $skipped storage block(s) were skipped; those should match"
  fi
elif [ "$scratch_ok" = yes ] && [ "$copy_ok" = yes ]; then
  bad "one of the two assertion runs reported zero, so the reconciliation could not be done"
fi

admin -c "drop database if exists $SCRATCH;" >/dev/null 2>&1
admin -c "drop database if exists $COPY;" >/dev/null 2>&1

# ---------------------------------------------------------------------------
printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'ok    GREEN. %s assertions from empty, %s against the cellar copy.\n' "$scratch_n" "$copy_n"
  exit 0
fi
printf 'FAIL  NOT GREEN: %d problem(s). Do not commit this phase.\n' "$fails"
exit 1
