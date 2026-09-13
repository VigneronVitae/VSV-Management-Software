#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Enforces the two gates in docs/review/CURRENT-BASELINE.md: that the
#           declarative layer's behavioural coverage never falls, and that every
#           refusal site in the kernel is either behaviourally covered or filed
#           as unreachable with a reason."
# Depends on: [scripts/mutate.sh, scripts/guards.sh]
# Depended on by: [docs/review/CURRENT-BASELINE.md, docs/session-reports/modularization-progress.md]
#
# The two files it reads that carry no header, because they are machine input:
#   docs/review/refusal-dispositions.tsv   which sites are filed unreachable, and why
#   docs/review/behavioural-baseline.tsv   the uncovered count per class that must not grow
# ---------------------------------------------------------------------------
#
# This is not in green.sh. It runs the whole mutation harness twice over 385
# mutations and takes thirty three minutes, measured, and a gate that slow
# inside the loop would be a gate people learn to skip. W-7 phase 2 says as much: split it
# out and state the runtime rather than reducing it to a sample.
#
# Run it before a phase that moves declarative objects or rewrites a function
# body. That is W-2 phases 6, 7 and 8, and anything like them afterwards.
#
# Two gates, deliberately shaped differently, because the two layers fail
# differently.
#
# The declarative gate is a ratchet on the uncovered count per class. Not a
# percentage: a percentage rises when the denominator grows, so adding thirty
# uncovered policies to a class that had two would improve it. The uncovered
# count is the thing that must not grow, which is the same as saying every new
# object has to be covered.
#
# The function-body gate is not a number at all. Every enumerated refusal site is
# behaviourally covered or filed unreachable with a reason. W-6 proposed a
# threshold of 80 percent on independently chosen substitutions; W-7 rejected it
# because a percentage invites the question of which substitutions, and that
# question is what produced two whole sessions. There is no sample here to argue
# about, so there is nothing for a threshold to do except permit a known gap
# without naming it.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

DISPOSITIONS=docs/review/refusal-dispositions.tsv
BASELINE=docs/review/behavioural-baseline.tsv
REPORT="${MUT_REPORT:-/tmp/vsv-ratchet}"

fails=0
bad() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
ok()  { printf 'ok    %s\n' "$1"; }

for f in "$DISPOSITIONS" "$BASELINE"; do
  [ -r "$f" ] || { echo "$f is missing, and this gate cannot be evaluated without it" >&2; exit 2; }
done

# ---------------------------------------------------------------------------
echo "running the mutation harness. This takes about half an hour."
# ---------------------------------------------------------------------------
rm -rf "$REPORT"
if ! MUT_REPORT="$REPORT" bash scripts/mutate.sh > /tmp/.ratchet-mutate.log 2>&1; then
  echo "the harness did not finish, so there is no measurement to gate on:" >&2
  tail -20 /tmp/.ratchet-mutate.log >&2
  exit 2
fi

# X-1's whole point, arriving inside the thing that enforces the fix. If the
# harness exits zero without writing its results, every loop below runs zero
# times and every gate passes.
# Existence, not size. An empty survived.tsv is the best outcome there is and the
# first version of this treated it as a missing file, so a run in which nothing
# survived would have refused to gate. Found by a run where nothing survived,
# which was itself void for a different reason.
for f in enumerated survived snapshot-only fixture-breakage score; do
  [ -e "$REPORT/$f.tsv" ] || { echo "the harness reported success and wrote no $f.tsv, refusing to gate" >&2; exit 2; }
done
for f in enumerated score; do
  [ -s "$REPORT/$f.tsv" ] || { echo "$f.tsv is empty, which no run can legitimately produce" >&2; exit 2; }
done

# ---------------------------------------------------------------------------
echo
echo "--- 1. the declarative ratchet"
# ---------------------------------------------------------------------------
# Uncovered, per class, is scored minus behavioural. A mutation the suite catches
# only through a pinned snapshot is uncovered: it noticed the catalog moved, not
# that anything refused.
uncovered_now() {   # $1 class
  local scored missed
  scored=$(awk -F'\t' -v c="$1" '$1==c' "$REPORT/enumerated.tsv" | grep -c .)
  missed=$(cat "$REPORT/survived.tsv" "$REPORT/snapshot-only.tsv" 2>/dev/null \
             | awk -F'\t' -v c="$1" '$1==c' | grep -c .)
  printf '%s %s' "$scored" "$missed"
}

while IFS=$'\t' read -r class was_scored was_uncov; do
  case "$class" in ''|'#'*|class) continue ;; esac
  [ "$class" = logic ] && continue
  read -r scored uncov <<EOF
$(uncovered_now "$class")
EOF
  if [ "$scored" -eq 0 ]; then
    bad "$class: the baseline records $was_scored mutations and this run enumerated none"
  elif [ "$uncov" -gt "$was_uncov" ]; then
    bad "$class: $uncov uncovered, up from $was_uncov. A new object was added without covering it."
  fi
done < "$BASELINE"
[ "$fails" -eq 0 ] && ok "no declarative class has more uncovered mutations than the baseline"

# ---------------------------------------------------------------------------
echo
echo "--- 2. every refusal site covered or filed"
# ---------------------------------------------------------------------------
# The label the harness carries for a logic mutation is "id: text", so the id is
# everything before the first colon-space. Sites are identified by id and not by
# text, because the text changes whenever the function is reformatted and an
# identifier that moves is an identifier that quietly stops matching.
site_ids() { awk -F'\t' '$1=="logic"{ sub(/: .*$/, "", $2); print $2 }' "$1" | sort -u; }

all=$(site_ids "$REPORT/enumerated.tsv")
missed=$(cat "$REPORT/survived.tsv" "$REPORT/snapshot-only.tsv" 2>/dev/null > /tmp/.ratchet-missed.tsv; site_ids /tmp/.ratchet-missed.tsv)
filed=$(awk -F'\t' '$0 !~ /^#/ && NF >= 2 && $2 == "unreachable" && $3 != "" { print $1 }' "$DISPOSITIONS" | sort -u)

n_all=$(printf '%s\n' "$all" | grep -c .)
[ "$n_all" -eq 0 ] && { echo "no refusal sites were enumerated, refusing to gate" >&2; exit 2; }

# A site that survived and is not filed. This is the gate.
open=$(comm -23 <(printf '%s\n' "$missed" | grep .) <(printf '%s\n' "$filed" | grep .))
n_open=$(printf '%s\n' "$open" | grep -c .)
if [ "$n_open" -gt 0 ]; then
  bad "$n_open refusal site(s) neither behaviourally covered nor filed unreachable:"
  printf '%s\n' "$open" | sed 's/^/        /'
fi

# A filing for a site that no longer exists. The enumeration is regenerated every
# run, so an id that has gone means the function was rewritten and the reason
# recorded against it was written about different code.
stale=$(comm -23 <(printf '%s\n' "$filed" | grep .) <(printf '%s\n' "$all" | grep .))
if [ -n "$stale" ]; then
  bad "filed against a refusal site that is no longer enumerated:"
  printf '%s\n' "$stale" | sed 's/^/        /'
fi

# A filing the suite now catches. Nothing is unsafe, but the reason recorded
# against it is no longer true, and a ledger entry that is no longer true is the
# thing every one of these scripts exists to prevent.
covered_but_filed=$(comm -12 <(printf '%s\n' "$filed" | grep .) \
                             <(comm -23 <(printf '%s\n' "$all") <(printf '%s\n' "$missed" | grep .)))
if [ -n "$covered_but_filed" ]; then
  bad "filed unreachable and caught anyway, so the filing is out of date:"
  printf '%s\n' "$covered_but_filed" | sed 's/^/        /'
fi

n_missed=$(printf '%s\n' "$missed" | grep -c .)
n_filed=$(printf '%s\n' "$filed" | grep -c .)
[ "$n_open" -eq 0 ] && [ -z "$stale" ] && [ -z "$covered_but_filed" ] && \
  ok "$((n_all - n_missed)) of $n_all refusal sites behaviourally covered, $n_filed filed unreachable"

# ---------------------------------------------------------------------------
printf '\n'
if [ "$fails" -eq 0 ]; then
  echo "ok    RATCHET HELD."
  exit 0
fi
printf 'FAIL  RATCHET BROKEN: %d problem(s). Do not land this phase.\n' "$fails"
exit 1
