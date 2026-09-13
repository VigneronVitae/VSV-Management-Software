#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Answers what is built, what is claimed and unchecked, and what is
#           only ruled, from the tree rather than from nine session reports."
# Depends on: [docs/architecture-rulings.md, tests/schema_assertions.sql]
# Depended on by: [scripts/green.sh, docs/session-reports/modularization-progress.md]
#
# It also reads docs/status-claims.tsv and docs/status-pending.tsv, which carry no
# typed header because they are machine input rather than documents.
# ---------------------------------------------------------------------------
#
# There are seventy one rulings, two ledgers and eleven session reports, and until
# this ran there was no way to answer "is AR-E6 built" except by reading four
# documents and trusting them. X-3 found those documents drifting from the tree in
# eight places, so trusting them is the thing that has already failed.
#
# Three counts, from three sources that cannot be edited into agreement:
#
#   built      a ruling whose mechanism is in the tree, and which at least one
#              behavioural assertion cites. A ruling that says built with nothing
#              citing it is a failure rather than a row.
#   claimed    built and unchecked, declared in docs/status-claims.tsv with the
#              session that claimed it and the reason nothing checks it. Counted,
#              printed, and deliberately not fatal.
#   ruled      a decision exists and no code does.
#
# **A ruling marked built whose only citing assertion is snapshot-only fails too.**
# W-6 cost a session to establish that a pinned catalog comparison notices the
# catalog moved and cannot notice that something stopped refusing. Letting a
# snapshot discharge a ruling here would re-admit exactly what that session was
# spent excluding, one document up.
#
# A citation is a comment line that **begins** with the identifier:
#
#     -- AR-E10. Redaction is row-level.
#
# and not a line that mentions one in passing, of which there are several. The
# distinction is the whole reliability of this check: a mention is prose and a
# citation is a claim, and only one of them should discharge anything.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

RULINGS=docs/architecture-rulings.md
SUITE=tests/schema_assertions.sql
CLAIMS=docs/status-claims.tsv
PENDING=docs/status-pending.tsv
REPORTS=docs/session-reports

fails=0
bad() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }

for f in "$RULINGS" "$SUITE" "$CLAIMS" "$PENDING"; do
  [ -r "$f" ] || { echo "$f is missing and this check cannot be evaluated without it" >&2; exit 2; }
done

# --- the rulings and their declared status ---------------------------------
# Every ruling carries exactly one status line immediately under its headline.
# A ruling with none is a failure: the point of this file is that a new ruling
# cannot be added without saying which of the three it is.
ids=$(mktemp); statuses=$(mktemp); cites=$(mktemp)
trap 'rm -f "$ids" "$statuses" "$cites"' EXIT

awk '
  /^\*\*AR-[A-Z][0-9]+\./ {
    id = $0; sub(/^\*\*/, "", id); sub(/\..*$/, "", id); pending = id; next
  }
  /^\*Status:\*/ {
    if (pending != "") {
      st = $0; sub(/^\*Status:\*[ \t]*/, "", st)
      print pending "\t" st
      pending = ""
    }
    next
  }
' "$RULINGS" > "$statuses"

grep -cE '^\*\*AR-[A-Z][0-9]+\.' "$RULINGS" > "$ids"
n_rulings=$(cat "$ids")
n_status=$(grep -c . "$statuses")
if [ "$n_rulings" -ne "$n_status" ]; then
  bad "$n_rulings rulings and $n_status status lines. Every ruling carries one, immediately under its headline."
fi

# --- citations, and whether each one is behavioural ------------------------
# For each citation, the enclosing assertion is the next `do $$ ... end $$;`
# block. A block containing snapshots_on() is a snapshot and does not discharge
# a ruling on its own.
awk '
  /^--[ \t]*AR-[A-Z][0-9]+/ {
    id = $0
    sub(/^--[ \t]*/, "", id)
    sub(/[^A-Za-z0-9-].*$/, "", id)
    waiting[++w] = id
    next
  }
  /^do \$\$/ { inblock = 1; snap = 0 }
  inblock && /snapshots_on\(\)/ { snap = 1 }
  inblock && /^end \$\$;/ {
    for (i = 1; i <= w; i++) print waiting[i] "\t" (snap ? "snapshot" : "behavioural")
    w = 0; inblock = 0
  }
  # A citation followed by another citation before any block still belongs to the
  # next block, which the array above already handles.
' "$SUITE" > "$cites"

# --- the three counts ------------------------------------------------------
n_built=0; n_claimed=0; n_ruled=0; n_super=0; n_question=0
while IFS=$'\t' read -r id st; do
  case "$st" in
    built*)
      n_built=$((n_built + 1))
      beh=$(awk -F'\t' -v i="$id" '$1==i && $2=="behavioural"' "$cites" | grep -c .)
      any=$(awk -F'\t' -v i="$id" '$1==i' "$cites" | grep -c .)
      if [ "$any" -eq 0 ]; then
        bad "$id says built and no assertion cites it. Cite it with a comment line beginning '-- $id', or say what it really is."
      elif [ "$beh" -eq 0 ]; then
        bad "$id says built and every assertion citing it is snapshot-only. A pinned list notices the catalog moved; it cannot notice something stopped refusing."
      fi
      ;;
    ruled*)          n_ruled=$((n_ruled + 1)) ;;
    superseded*)     n_super=$((n_super + 1)) ;;
    "open question"*) n_question=$((n_question + 1)) ;;
    *) bad "$id carries status '$st', which is not built, ruled, superseded or open question." ;;
  esac
done < "$statuses"

n_claimed=$(grep -vc '^#' "$CLAIMS")
n_claimed=${n_claimed:-0}

# --- pending, counted rather than remembered -------------------------------
# The session count is derived: how many session reports are dated after the day
# the item was named. A stored number is a number somebody has to remember to
# increase, and that is this document family's whole failure mode.
sessions_since() {
  local since="$1" n=0 f
  for f in "$REPORTS"/[0-9]*.md; do
    [ -e "$f" ] || continue
    local d; d=$(basename "$f" | cut -c1-10)
    [[ "$d" > "$since" ]] && n=$((n + 1))
  done
  printf '%d' "$n"
}

# ---------------------------------------------------------------------------
printf '\n--- status\n'
printf 'ok    %d rulings: %d built and asserted, %d ruled and unbuilt, %d superseded, %d open questions\n' \
  "$n_rulings" "$n_built" "$n_ruled" "$n_super" "$n_question"

if [ "$n_claimed" -gt 0 ]; then
  printf '      %d built and nothing checks them, declared in %s:\n' "$n_claimed" "$CLAIMS"
  awk -F'\t' '!/^#/ && NF >= 2 { printf "        %-52s %s\n", substr($1,1,52), $2 }' "$CLAIMS"
else
  printf 'ok    nothing is claimed and unchecked\n'
fi

printf '\n      pending, with the prompt that named it and sessions since:\n'
while IFS=$'\t' read -r item prompt since note; do
  case "$item" in ''|'#'*|item) continue ;; esac
  printf '        %-52s %-8s %2d sessions\n' "$(printf '%s' "$item" | cut -c1-52)" "$prompt" "$(sessions_since "$since")"
done < "$PENDING"

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'ok    status: every ruling says which it is, and every built one is cited by an assertion that exercises it\n'
  exit 0
fi
printf 'FAIL  status: %d problem(s)\n' "$fails"
exit 1
