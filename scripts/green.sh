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

if ! docker exec "$CONTAINER" true 2>/dev/null; then
  printf 'FAIL  cannot reach the database container %s\n' "$CONTAINER"
  printf '      start the stack, or set VSV_DB_CONTAINER\n'
  exit 2
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
# The shim first, because 0002 cannot apply without the realtime publication and
# every policy after it calls auth.uid(). tests/shim.sql says which needs which.
admin -c "drop database if exists $SCRATCH;" >/dev/null 2>&1
admin -c "create database $SCRATCH;" >/dev/null 2>&1
if ! psql_ -q -d "$SCRATCH" < tests/shim.sql > /tmp/green-shim.log 2>&1; then
  bad "the shim did not apply"; tail -5 /tmp/green-shim.log | sed 's/^/      /'
fi

applied=0; broke=""
for f in supabase/migrations/0*.sql; do
  if psql_ -q -d "$SCRATCH" < "$f" > /tmp/green-mig.log 2>&1; then
    applied=$((applied + 1))
  else
    broke="$f"; break
  fi
done
total=$(ls supabase/migrations/0*.sql | wc -l | tr -d ' ')
if [ -n "$broke" ]; then
  bad "$(basename "$broke") did not apply from empty ($applied of $total applied first)"
  grep -E '^(ERROR|FATAL)' /tmp/green-mig.log | head -3 | sed 's/^/      /'
else
  ok "$applied of $total migrations apply clean from empty"
fi

# ---------------------------------------------------------------------------
step "4. the assertion suite against that scratch database"
# ---------------------------------------------------------------------------
scratch_n=0
if [ -z "$broke" ]; then
  psql_ -d "$SCRATCH" < tests/schema_assertions.sql > /tmp/green-assert-scratch.log 2>&1
  scratch_n=$(grep -c '^NOTICE:  ok' /tmp/green-assert-scratch.log)
  if grep -qE '^(ERROR|FATAL)' /tmp/green-assert-scratch.log; then
    bad "assertions against the scratch database"
    grep -E '^(ERROR|FATAL)' /tmp/green-assert-scratch.log | head -3 | sed 's/^/      /'
  else
    ok "$scratch_n assertions pass against a database built from empty"
  fi
else
  bad "assertions against scratch skipped: the migrations did not apply"
fi

# ---------------------------------------------------------------------------
step "5. the assertion suite against a copy of the cellar"
# ---------------------------------------------------------------------------
# pg_dump is the only thing in this script that touches the cellar, and it reads.
admin -c "drop database if exists $COPY;" >/dev/null 2>&1
admin -c "create database $COPY;" >/dev/null 2>&1
if docker exec "$CONTAINER" sh -c "pg_dump -U postgres -d $CELLAR | psql -U postgres -q -d $COPY" \
     > /tmp/green-copy.log 2>&1; then
  rows=$(docker exec "$CONTAINER" psql -U postgres -At -d "$COPY" \
           -c "select count(*) from pg_tables where schemaname not in ('pg_catalog','information_schema');")
  ok "cellar copied, $rows tables"
else
  bad "could not copy the cellar database"; tail -5 /tmp/green-copy.log | sed 's/^/      /'
fi

copy_n=0
psql_ -d "$COPY" < tests/schema_assertions.sql > /tmp/green-assert-copy.log 2>&1
copy_n=$(grep -c '^NOTICE:  ok' /tmp/green-assert-copy.log)
if grep -qE '^(ERROR|FATAL)' /tmp/green-assert-copy.log; then
  bad "assertions against the cellar copy"
  grep -E '^(ERROR|FATAL)' /tmp/green-assert-copy.log | head -3 | sed 's/^/      /'
else
  ok "$copy_n assertions pass against a copy of the cellar"
fi

# The two counts are allowed to differ, and by exactly one thing: the scratch
# database has no storage schema, so each storage-guarded block emits one notice
# saying it was skipped in place of the two assertions it would otherwise make.
# The expected gap is therefore one per skipped block, counted from the scratch
# run rather than written down, so adding another guarded block does not require
# editing this number.
if [ "$scratch_n" -gt 0 ] && [ "$copy_n" -gt 0 ]; then
  skipped=$(grep -c 'no storage schema here' /tmp/green-assert-scratch.log)
  actual=$((copy_n - scratch_n))
  if [ "$actual" -ne "$skipped" ]; then
    bad "the two runs differ by $actual assertions and $skipped storage block(s) were skipped; those should match"
  fi
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
