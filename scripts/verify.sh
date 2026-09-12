#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Checks the claims this repository makes about itself, so that a rule
#           stated in a document is a rule rather than an intention. Every check
#           here corresponds to something CLAUDE.md or a ledger asserts and
#           nothing enforced."
# Depends on: [CLAUDE.md, docs/sorry-ledger.md, docs/compost-ledger.md,
#              docs/status-ledger.md, docs/findings-ledger.md]
# Depended on by: [docs/status-ledger.md, scripts/green.sh]
# ---------------------------------------------------------------------------
#
# Bash and standard tools only. No dependency is added by this file, which is
# the hard rule in CLAUDE.md and also the reason the module import check below
# is a grep rather than a Biome rule.
#
# Exit is non-zero if anything fails, and every failure names the file and what
# is wrong with it. A check that cannot fail is decoration, so each one was
# broken on purpose once and observed to fail; the session report says how.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fails=0
note()  { printf '      %s\n' "$*"; }
fail()  { printf 'FAIL  %s\n' "$*"; fails=$((fails + 1)); }
pass()  { printf 'ok    %s\n' "$*"; }
head_() { printf '\n--- %s\n' "$*"; }

# The review corpus is terminal. Thirteen engines wrote it, none of them read
# this repository's style rule, and nothing in the tree depends on any of it.
# Giving those files headers would enter them into the dependency graph as
# things other documents rely on, which inverts the relationship. So they are
# exempt from the header check and the em dash check, explicitly and here,
# rather than by accident.
corpus() { case "$1" in docs/review/prompts/*|docs/review/reports/*) return 0 ;; *) return 1 ;; esac; }

tracked() { git ls-files; }

# ---------------------------------------------------------------------------
head_ "1. the typed header graph"
# ---------------------------------------------------------------------------
# CLAUDE.md: "Keep both directions of the dependency fields accurate; a
# one-directional link is a broken link." A session report said this was checked
# by script. The script was never committed and the invariant broke silently
# twice, most recently for migrations 0016 through 0020.

edges=$(mktemp); headered=$(mktemp)
trap 'rm -f "$edges" "$headered"' EXIT

for f in $(tracked); do
  corpus "$f" && continue
  # .sh is scanned too. It was not until now, which meant this script's own
  # typed header was the one header in the tree nothing checked, and it named
  # package.json, a file that carries no header and never could.
  case "$f" in *.md|*.sql|*.sh) ;; *) continue ;; esac
  grep -q 'Depends on:' "$f" 2>/dev/null || continue
  echo "$f" >> "$headered"

  # Two header shapes. Markdown opens with a --- fence; SQL opens with a
  # contiguous run of -- comment lines. Either way the header becomes one line
  # so that a field wrapped across several lines reads the same as one that is not.
  if [ "$(head -1 "$f" | tr -d '\r')" = "---" ]; then
    hdr=$(sed -n '2,/^---[[:space:]]*$/p' "$f")
  else
    hdr=$(awk '/^#!/ {next} /^(--|#)/ {print; next} {exit}' "$f" | sed 's/^\(--\|#\)[[:space:]]*//')
  fi
  hdr=$(printf '%s' "$hdr" | tr '\r\n' '  ')

  for dir in "Depends on" "Depended on by"; do
    list=$(printf '%s' "$hdr" | sed -n "s/.*${dir}:[[:space:]]*\[\([^]]*\)\].*/\1/p")
    [ -z "$list" ] && continue
    # printf with a trailing newline on purpose: `read` returns non-zero on a
    # final line with no newline and the loop body never runs for it, which
    # silently drops the last entry of every list. That is a bug this script had
    # for about ten minutes and it is exactly the failure mode it exists to catch.
    printf '%s\n' "$list" | tr ',' '\n' | while read -r t; do
      t=$(printf '%s' "$t" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
      [ -z "$t" ] && continue
      printf '%s\t%s\t%s\n' "$f" "$dir" "$t" >> "$edges"
    done
  done
done

# An edge naming a path that does not exist.
while IFS=$'\t' read -r from dir to; do
  [ -e "$to" ] || fail "$from: '$dir' names $to, which does not exist"
done < "$edges"

# A one-directional edge. A depends on B means B must say it is depended on by A.
while IFS=$'\t' read -r from dir to; do
  case "$dir" in
    "Depends on")      want="Depended on by" ;;
    "Depended on by")  want="Depends on" ;;
  esac
  grep -q "^$(printf '%s' "$to" | sed 's/[].[^$*\/]/\\&/g')	${want}	$(printf '%s' "$from" | sed 's/[].[^$*\/]/\\&/g')$" "$edges" \
    || fail "$from: '$dir' names $to, and $to does not say '$want: $from'"
done < "$edges"

# A headered file nothing points at. The root of the graph is spec.md, which
# depends on nothing and is depended on by most things; the orphan case is the
# other end, a document nobody reads.
while read -r f; do
  # README.md is the entry point. A graph has to start somewhere and the file a
  # stranger opens first is by definition depended on by nothing here.
  [ "$f" = "README.md" ] && continue
  grep -q "	Depends on	$(printf '%s' "$f" | sed 's/[].[^$*\/]/\\&/g')$" "$edges" \
    || fail "$f: carries a typed header and no file depends on it"
done < "$headered"

[ "$fails" -eq 0 ] && pass "$(wc -l < "$headered" | tr -d ' ') headered files, $(wc -l < "$edges" | tr -d ' ') edges, every one bidirectional and resolving"

# ---------------------------------------------------------------------------
head_ "2. the em dash rule"
# ---------------------------------------------------------------------------
# CLAUDE.md: "No em dashes anywhere, in code comments, docs, or commit messages."
em=$(printf '\342\200\224')
before=$fails
for f in $(tracked); do
  corpus "$f" && continue
  [ -f "$f" ] || continue
  n=$(grep -c -F "$em" "$f" 2>/dev/null) || n=0
  [ "$n" -gt 0 ] && fail "$f: $n em dash(es)"
done
# Commit messages are cheap to check and are named in the same rule.
bad=$(git log --format='%h %s' -n 100 2>/dev/null | grep -F "$em" | head -5)
[ -n "$bad" ] && fail "commit subjects carry em dashes:$(printf '\n      %s' "$bad")"
[ "$fails" -eq "$before" ] && pass "no em dash in any tracked file outside the corpus, or in the last 100 commit subjects"

# ---------------------------------------------------------------------------
head_ "3. ledger cross references"
# ---------------------------------------------------------------------------
before=$fails

sorries=$(grep -o '^\*\*S-[0-9]*' docs/sorry-ledger.md | tr -d '*' | sort -u)
[ -z "$sorries" ] && fail "docs/sorry-ledger.md: no entries found, so the id format changed and this check is blind"

for f in $(tracked); do
  corpus "$f" && continue
  [ -f "$f" ] || continue
  # Word-bounded on purpose. Without it 'VS-023', a vessel sticker in the
  # assertions, reads as a sorry numbered 023. This comment deliberately does
  # not write that id out, because this file is scanned too.
  for id in $(grep -o '\bS-[0-9][0-9]*\b' "$f" 2>/dev/null | sort -u); do
    printf '%s\n' "$sorries" | grep -qx "$id" || fail "$f: names $id, which is not in docs/sorry-ledger.md"
  done
done

composts=$(grep -o '^\*\*C-[0-9]*' docs/compost-ledger.md | tr -d '*' | sort -u)
[ -z "$composts" ] && fail "docs/compost-ledger.md: no entries found, so the id format changed and this check is blind"

for f in $(tracked); do
  corpus "$f" && continue
  [ -f "$f" ] || continue
  for id in $(grep -o '\bC-[0-9][0-9]*\b' "$f" 2>/dev/null | sort -u); do
    printf '%s\n' "$composts" | grep -qx "$id" || fail "$f: names $id, which is not in docs/compost-ledger.md"
  done
done

# Architecture rulings. Their ids used to be A-1, B-5, C-3 and so on, which
# collided with the compost ledger on C-1 through C-4 and forced an exemption
# here naming that file. Version 2.1 prefixed them all, so the namespaces are
# separate; this check is what makes them enforceable rather than merely
# separate, and it catches a reference pointing at a ruling that does not exist.
rulings=$(grep -o '^\*\*AR-[A-JQ][0-9]*' docs/architecture-rulings.md | tr -d '*' | sort -u)
[ -z "$rulings" ] && fail "docs/architecture-rulings.md: no AR- ids found, so the id format changed and this check is blind"

for f in $(tracked); do
  corpus "$f" && continue
  [ -f "$f" ] || continue
  for id in $(grep -o 'AR-[A-JQ][0-9][0-9]*' "$f" 2>/dev/null | sort -u); do
    printf '%s
' "$rulings" | grep -qx "$id" || fail "$f: names $id, which is not a ruling in docs/architecture-rulings.md"
  done
done

# CLAUDE.md says every compost entry carries a reactivation condition.
for id in $composts; do
  body=$(awk -v id="$id" 'index($0,"**"id".")==1 {f=1; next} /^\*\*C-[0-9]+\./ {f=0} f' docs/compost-ledger.md)
  printf '%s' "$body" | grep -q 'Reactivate if:' \
    || fail "docs/compost-ledger.md: $id has no 'Reactivate if:' line, and CLAUDE.md says every entry has one"
done

# The status ledger's own definition of Deferred requires a compost entry.
while IFS= read -r row; do
  printf '%s' "$row" | grep -q 'C-[0-9]' \
    || fail "docs/status-ledger.md: a row graded Deferred names no compost entry: $(printf '%s' "$row" | cut -c1-60)"
done < <(grep '| Deferred |' docs/status-ledger.md)

[ "$fails" -eq "$before" ] && pass "every S-, C- and AR- id referenced in the tree exists, every compost entry can be revived, every Deferred row says how"

# ---------------------------------------------------------------------------
head_ "4. counts stated in prose"
# ---------------------------------------------------------------------------
# A number written into a sentence rots. These are derived and compared, so the
# sentence fails rather than quietly becoming false.
before=$fails

word_for() {
  case "$1" in
    1) echo one ;; 2) echo two ;; 3) echo three ;; 4) echo four ;; 5) echo five ;;
    6) echo six ;; 7) echo seven ;; 8) echo eight ;; 9) echo nine ;; 10) echo ten ;;
    11) echo eleven ;; 12) echo twelve ;; 13) echo thirteen ;; 14) echo fourteen ;;
    15) echo fifteen ;; 16) echo sixteen ;; 17) echo seventeen ;; 18) echo eighteen ;;
    19) echo nineteen ;; 20) echo twenty ;; *) echo "" ;;
  esac
}

n_compost=$(printf '%s\n' "$composts" | grep -c .)
claim=$(grep -io '\*\*Check the compost ledger[^.]*\.\*\* *[A-Za-z]* entries' CLAUDE.md | awk '{print tolower($(NF-1))}')
want=$(word_for "$n_compost")
if [ -n "$claim" ] && [ "$claim" != "$want" ]; then
  fail "CLAUDE.md: says '$claim entries' in the compost ledger; there are $n_compost ($want)"
fi

# docs/review and docs/session-reports are skipped entirely here. The archive
# README states counts about c3eae3c, and a session report describes the tree as
# it stood on a date and is append-only by the convention in its own index. Both
# are history rather than claims about now, and a count check that cannot tell
# the difference would force history to be rewritten to stay green.
history() { case "$1" in docs/review/*|docs/session-reports/*) return 0 ;; *) return 1 ;; esac; }
n_files=$(tracked | grep -c .)
for f in $(tracked); do
  history "$f" && continue
  [ -f "$f" ] || continue
  for claimed in $(grep -o '[0-9][0-9]* tracked files' "$f" 2>/dev/null | awk '{print $1}' | sort -u); do
    [ "$claimed" = "$n_files" ] || fail "$f: says $claimed tracked files; there are $n_files"
  done
done

n_migrations=$(ls supabase/migrations/*.sql 2>/dev/null | grep -c .)
for f in $(tracked); do
  history "$f" && continue
  [ -f "$f" ] || continue
  for claimed in $(grep -o '[0-9][0-9]* migrations' "$f" 2>/dev/null | awk '{print $1}' | sort -u); do
    [ "$claimed" = "$n_migrations" ] || fail "$f: says $claimed migrations; there are $n_migrations"
  done
done

[ "$fails" -eq "$before" ] && pass "the compost count, the tracked file count and the migration count are what the prose says"

# ---------------------------------------------------------------------------
head_ "5. the definition of done exists"
# ---------------------------------------------------------------------------
# Every command in CLAUDE.md's definition-of-done block must resolve. The check
# is that the command exists, not that it passes: doctor is a stub by design and
# that is filed as S-4.
before=$fails
done_block=$(awk '/^## What done means/ {f=1} f && /^```sh/ {p=1; next} p && /^```/ {exit} p' CLAUDE.md)
[ -z "$done_block" ] && fail "CLAUDE.md: no shell block under 'What done means', so the definition of done is prose"

printf '%s\n' "$done_block" | grep -o 'bun run [a-z:._-]*' | awk '{print $3}' | sort -u | while read -r s; do
  [ -z "$s" ] && continue
  grep -q "\"$s\"[[:space:]]*:" package.json \
    || echo "MISSING:$s"
done > /tmp/.verify_missing_scripts 2>/dev/null || true
while IFS= read -r m; do
  [ -z "$m" ] && continue
  s=${m#MISSING:}
  fail "CLAUDE.md: the definition of done runs 'bun run $s' and package.json has no such script"
done < /tmp/.verify_missing_scripts
rm -f /tmp/.verify_missing_scripts

printf '%s\n' "$done_block" | grep -o '[a-zA-Z0-9_/.-]*\.sql' | sort -u | while read -r p; do
  [ -e "$p" ] || echo "MISSING:$p"
done > /tmp/.verify_missing_paths 2>/dev/null || true
while IFS= read -r m; do
  [ -z "$m" ] && continue
  fail "CLAUDE.md: the definition of done names ${m#MISSING:}, which does not exist"
done < /tmp/.verify_missing_paths
rm -f /tmp/.verify_missing_paths

[ "$fails" -eq "$before" ] && pass "every command and path in the definition of done resolves"

# ---------------------------------------------------------------------------
head_ "6. the status ledger does not contradict itself"
# ---------------------------------------------------------------------------
# A general checker for this would be overreach. This one is specific and takes
# three lines: the ledger cannot open by saying nothing is built and then grade
# rows Built.
before=$fails
if grep -q 'Nothing is built' docs/status-ledger.md && grep -q '| Built' docs/status-ledger.md; then
  fail "docs/status-ledger.md: says 'Nothing is built' and grades $(grep -c '| Built' docs/status-ledger.md) rows Built"
fi
if grep -q 'Nothing is built' docs/sorry-ledger.md && grep -q '| Built' docs/status-ledger.md; then
  fail "docs/sorry-ledger.md: repeats 'Nothing is built' while the status ledger grades rows Built"
fi
[ "$fails" -eq "$before" ] && pass "the status ledger's opening sentence agrees with its own grades"

# ---------------------------------------------------------------------------
head_ "7. the module import rule"
# ---------------------------------------------------------------------------
# CLAUDE.md: "A module package may import from core and never from a sibling."
# This is a grep rather than a Biome rule on purpose. Biome cannot currently run
# to completion in this repository on a Windows checkout, because core.autocrlf
# rewrites five config files to CRLF and the formatter refuses them, so a rule
# living there would be unenforceable exactly where it is needed. Moving it into
# Biome is right once that is fixed, since the closer to the compiler the better.
before=$fails
pairs=0
modules=$(ls -d packages/*/ 2>/dev/null | sed 's#packages/##; s#/##')
for m in $modules; do
  [ "$m" = "core" ] && continue
  for sib in $modules; do
    [ "$sib" = "$m" ] && continue
    [ "$sib" = "core" ] && continue
    pairs=$((pairs + 1))
    hits=$(grep -rn "from \"$sib\|from '$sib\|require(\"$sib\|require('$sib" "packages/$m/src" 2>/dev/null | head -3)
    [ -n "$hits" ] && fail "packages/$m imports from sibling module '$sib':$(printf '\n      %s' "$hits")"
  done
done
if [ "$fails" -ne "$before" ]; then
  :
elif [ "$pairs" -eq 0 ]; then
  # Said out loud rather than printed as a green tick. With only core and one
  # module there is no sibling pair to examine, so this check currently proves
  # nothing. It was exercised by adding a second module package and watching it
  # fire; it starts meaning something on its own the day a second module lands.
  pass "the module import rule holds vacuously: $(printf '%s\n' "$modules" | grep -cv '^core$') module besides core, so there is no sibling to import from"
else
  pass "no module package imports from a sibling across $pairs ordered pair(s); core is the only shared floor"
fi

# ---------------------------------------------------------------------------
printf '\n'
if [ "$fails" -eq 0 ]; then
  pass "verify: everything this repository claims about itself is true"
  exit 0
fi
printf 'FAIL  verify: %d problem(s)\n' "$fails"
exit 1
