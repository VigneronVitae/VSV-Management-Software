#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Checks every rpc call the client makes against the parameters the
#           kernel actually has, because an rpc argument is a string and nothing
#           else in this repository looks at it."
# Depends on: [tests/schema_assertions.sql]
# Depended on by: [scripts/green.sh]
# ---------------------------------------------------------------------------
#
# Written the moment after a press failed in the winemaker's hand with "could
# not find the function public.start_press(p_detail, p_node, p_press_vessel_id,
# p_source_ids) in the schema cache", mid harvest, with fruit in the bins.
#
# `0090` renamed that function's first parameter from `p_source_ids` to
# `p_vessel_ids` **on purpose**, so that every caller would have to be revisited
# rather than silently keep passing lot ids into a list of vessels. Three
# callers in the assertion suite were found and fixed that way, because they are
# SQL and the database refuses them. The fourth was this:
#
#     await kernel().rpc("start_press", { p_source_ids: args.sourceIds, ... })
#
# **TypeScript cannot see inside that object.** The argument names are keys in a
# bag handed to PostgREST, so the compiler is happy, the linter is happy, and
# the call fails at the moment somebody taps the button. It is the same class as
# the `bins_emptied` rename earlier the same evening, which was caught by
# reading rather than by any check.
#
# It reads `packages/core/src/kernel.ts`, which carries no typed header because
# no TypeScript file here does, so that dependency is said in prose rather than
# in the field: **this script is only as current as that file's shape**, and a
# call written some other way is a call it cannot see.
#
# So: read every `rpc("name", { ... })` out of the kernel and ask the database
# whether that function has those parameters. Both halves are cheap and the
# thing it catches costs a press.
#
# `VSV_RPC_SRC` points it at something else, which exists so this check can be
# shown to fail. A check that has never failed is a check nobody has reason to
# believe, and this one was written in answer to a defect it must catch.
#
# Two limits, stated rather than hidden. It only reads `packages/core/src`,
# which is where every call in this repository lives by rule, and it only sees
# argument names written literally, which is all of them today. A spread would
# be invisible to it and is worth not writing.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

DB="${1:-postgres}"
CONTAINER="${VSV_DB_CONTAINER:-supabase_db_vsv-management-software}"

fails=0
bad() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }

if ! docker exec "$CONTAINER" true 2>/dev/null; then
  echo "cannot reach $CONTAINER, so the kernel's parameters cannot be read" >&2
  exit 2
fi

# name<TAB>arg per line, from every rpc call in the client kernel. awk rather
# than a parser: the shape is `rpc("fn", {` then `p_x: ...` lines until `});`.
calls=$(awk '
  /rpc\("/ {
    line = $0
    sub(/.*rpc\("/, "", line)
    fn = line
    sub(/".*/, "", fn)
    inside = 1
    next
  }
  inside && /^[[:space:]]*}\)/ { inside = 0; next }
  inside && /^[[:space:]]*p_[a-z0-9_]+:/ {
    arg = $0
    sub(/^[[:space:]]*/, "", arg)
    sub(/:.*/, "", arg)
    print fn "\t" arg
  }
' ${VSV_RPC_SRC:-packages/core/src/*.ts} | sort -u)

if [ -z "$calls" ]; then
  echo "no rpc calls found, which cannot be right" >&2
  exit 2
fi

# Every function and its parameter names, from the catalog.
have=$(docker exec "$CONTAINER" psql -U postgres -At -d "$DB" -c "
  select p.proname || E'\t' || a.arg
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public',
    lateral unnest(coalesce(p.proargnames, '{}')) as a(arg)
   where p.prokind = 'f';" 2>/dev/null | sort -u)

n=0
while IFS=$'\t' read -r fn arg; do
  [ -z "$fn" ] && continue
  n=$((n + 1))
  if ! grep -qxF "$fn	$arg" <<<"$have"; then
    # Say what it does have, because the useful half of this message is the
    # name somebody meant.
    opts=$(grep "^$fn	" <<<"$have" | cut -f2 | paste -sd', ' -)
    if [ -z "$opts" ]; then
      bad "the client calls $fn, and the kernel has no such function"
    else
      bad "the client passes $arg to $fn, which takes: $opts"
    fi
  fi
done <<<"$calls"

if [ "$fails" -eq 0 ]; then
  printf 'ok    %d rpc arguments across the client all name a parameter the kernel has\n' "$n"
  exit 0
fi
exit 1
