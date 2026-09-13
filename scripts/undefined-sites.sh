#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Enumerates every place in the client where an absent value meets a
#           comparison or a default, so that the class W-8 went looking for is
#           counted over the whole client rather than over a sample."
# Depends on: [README.md]
# Depended on by: [docs/session-reports/modularization-progress.md]
#
# It reads the client sources, which carry no typed header because they are
# TypeScript and the header convention covers documents and scripts.
# ---------------------------------------------------------------------------
#
# This is not a gate and it is not a score. W-8 says explicitly to build neither,
# because a gate written before the surface is known measures the wrong thing,
# which W-6 and W-7 both demonstrated. It is a list, and its only job is to be
# complete so that the triage beside it can be read as covering everything.
#
# The class is A25 arriving in TypeScript, and half the intuition from four
# sessions of SQL nulls transfers while the other half is backwards:
#
#   undefined !== 222   is true,  so an equality check fires rather than going quiet
#   undefined <  222    is false
#   undefined >  222    is also false
#
# So an equality test on an absent value is loud and an ordering test on one
# permits from both sides. In SQL both go quiet. The ordering comparisons are
# therefore the dangerous half and they are listed first.
#
#   ordering     a <, >, <= or >= that permits from both sides when either operand
#                is absent
#   or-default   a || supplying a default, which swallows 0 and the empty string.
#                A volume of zero is a real value here, and an emptied vessel is
#                the case that produced ledger B11
#   optional     an ?. that turns a missing object into a missing value, which is
#                then usually fed to one of the two above
#
# Output is one tab-separated row per site: file, line, kind, text.
#
# Whether a site is a defect is a judgment and is not made here. Most are not:
# TypeScript proves a great many of these operands non-null already, which is the
# one respect in which this layer is better defended than the SQL was. The
# judgment for this run is in the W-8 session report, against the committed
# output at docs/review/undefined-sites.tsv.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

files=$(git ls-files 'packages/*/src/*.ts' 'apps/*/src/*.ts')
if [ -z "$files" ]; then
  echo "no client sources found, which is a broken glob and not a client with no code" >&2
  exit 2
fi

emit() {   # $1 kind, $2 grep -E pattern, $3 optional exclude pattern
  local kind="$1" pat="$2" excl="${3:-}"
  # shellcheck disable=SC2086
  grep -nE "$pat" $files 2>/dev/null \
    | { [ -n "$excl" ] && grep -vE "$excl" || cat; } \
    | while IFS=: read -r f n rest; do
        printf '%s\t%s\t%s\t%s\n' "$f" "$n" "$kind" "$(printf '%s' "$rest" | sed 's/^[[:space:]]*//')"
      done
}

{
  # A comparison here is spaced, because biome formats it that way. Requiring
  # the spaces is what separates `fill > 1` from `Promise<{`, `Array<{` and
  # `} | null>`, which the first version of this counted as nine comparisons that
  # were type annotations. An unspaced `a<b` would be missed, and biome check
  # runs in `bun run green`, so that is a stated limitation rather than a hole.
  emit ordering   '[^=<>!&|-] (<|>|<=|>=) '
  emit or-default '\|\|'
  emit optional   '\?\.'
} | sort -t"$(printf '\t')" -k3,3 -k1,1 -k2,2n

n=$( { emit ordering '[^=<>!&|-] (<|>|<=|>=) '; emit or-default '\|\|'; emit optional '\?\.'; } | grep -c . )
if [ "$n" -eq 0 ]; then
  echo "the enumeration found nothing, which is a broken pattern and not a client with no comparisons" >&2
  exit 2
fi
printf '# %d sites\n' "$n" >&2
