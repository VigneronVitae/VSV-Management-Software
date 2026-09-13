#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Measures what fraction of deliberately injected schema defects the
#           assertion suite catches. A suite that passes tells you it ran; a
#           mutation score tells you whether it would have noticed."
# Depends on: [tests/shim.sql, tests/schema_assertions.sql, scripts/guards.sh]
# Depended on by: [docs/session-reports/modularization-progress.md, scripts/ratchet.sh]
# ---------------------------------------------------------------------------
#
# The G-5 review run measured 42 percent against 28 assertions and did not commit
# the harness, so the number could not be reproduced or improved against. That is
# the same defect as D1 and this file is the answer to it.
#
# Method, which is G-5's so the numbers are comparable: build one base database
# from the shim and every migration, then for each mutation copy it, apply that
# one mutation, run the assertion suite, and record whether the suite exited
# non-zero. Caught means non-zero. The copy is a template clone rather than a
# rebuild, which is what makes a hundred-odd mutations take minutes instead of an
# hour.
#
# The mutations are enumerated from the catalog rather than listed by hand, so
# the set grows with the schema instead of going stale the way a written list
# does. Eight classes:
#
#   check        every check constraint, dropped
#   loosen       every check constraint replaced with check (true)
#   unique       every unique constraint and unique index, dropped
#   trigger      every user trigger, disabled
#   policy       every row level security policy, dropped
#   weaken       every policy recreated with a predicate of true
#   rls          row level security itself, disabled per table
#   logic        every refusal site in every function, neutralised one at a time
#
# policy and weaken are not the same test and the difference matters. A pinned
# list of policy names catches every drop and nothing else; only weaken catches a
# policy that is still present and has stopped refusing anything, which is the
# failure mode a schema move actually produces.
#
# A mutation that cannot be applied at all, usually because something depends on
# it, is reported separately and counted in neither column, because it is not a
# defect the suite failed to catch.
#
# Nothing here touches the cellar database.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

CONTAINER="${VSV_DB_CONTAINER:-supabase_db_vsv-management-software}"
BASE=vsv_mut_base
WORK=vsv_mut_work
ONLY="${1:-}"

# X-1-2: q() used to end in 2>/dev/null and its output was appended straight to
# the mutation file. A query that errored contributed zero lines, its class
# vanished from the run, and the summary printed a clean score over a smaller
# denominator. Sabotaging one enumeration produced "210 mutations enumerated",
# no trigger row in the table, and "189 of 189 caught (100%)" with no warning.
# That is the tgenabled shape in the place it does the most damage.
q() {
  local out rc
  out=$(docker exec "$CONTAINER" psql -U postgres -At -d "$1" -c "$2" 2>/tmp/.mutate-q.err)
  rc=$?
  if [ "$rc" -ne 0 ] || [ -s /tmp/.mutate-q.err ]; then
    echo "ENUMERATION FAILED, refusing to score. psql exited $rc:" >&2
    sed 's/^/    /' /tmp/.mutate-q.err >&2
    echo "    query: $(printf '%s' "$2" | tr '
' ' ' | cut -c1-160)" >&2
    exit 2
  fi
  # A newline, because command substitution strips the trailing one and these
  # results are appended to a line-based file. Without it the first row of each
  # class lands on the last row of the previous one, and the enumerated total
  # quietly drops by one per class. It did, by seven, on the first run of this.
  printf '%s
' "$out"
}

# Every class asserts a non-zero row count, the way fingerprint() already asserts
# a non-empty result. A class with no members is either a broken query or a
# schema that lost every object of that kind, and both deserve an abort rather
# than a missing row in the table.
enumerate() {   # $1 class name, $2 database, $3 sql
  local before after
  before=$(grep -c . "$muts" 2>/dev/null); before=${before:-0}
  q "$2" "$3" >> "$muts"
  after=$(grep -c . "$muts" 2>/dev/null); after=${after:-0}
  if [ "$after" -le "$before" ]; then
    echo "ENUMERATION EMPTY for class '$1', refusing to score." >&2
    echo "    A class with no members is a broken query or a schema that lost every" >&2
    echo "    object of that kind. Either way the score would be over a denominator" >&2
    echo "    nobody chose." >&2
    exit 2
  fi
  printf '  %-8s %d mutations
' "$1" "$(( after - before ))"
}

# X-1-14: adm() discarded its own status, so a failed drop meant a failed create
# meant an iteration mutating a database that still carried the previous
# mutation, scored against a schema with two defects in it.
adm(){ docker exec "$CONTAINER" psql -U postgres -q -d postgres -c "$1" >/dev/null 2>&1; }

adm_or_die() {
  if ! adm "$1"; then
    echo "database administration failed, refusing to score: $1" >&2
    exit 2
  fi
}

# W-10. The inputs, fingerprinted, because editing one of them mid-run is now the
# second measurement this project has lost that way and the first cost thirty
# minutes with a rule written down immediately afterwards.
#
# W-8 edited this script while it was running, and bash reads a script
# incrementally, so it misparsed its own scoring section after completing every
# mutation. W-10 edited tests/schema_assertions.sql while this was reading it once
# per mutation, and the run reported 356 of 367 behavioural with 294 of those
# being fixture breakage, against 34 the session before. **A number that good is
# the shape of a broken suite, not of a covered schema**, and nothing said so.
#
# So the rule becomes a check. If anything this run depends on changes underneath
# it, the score is void and saying so is cheaper than discovering it from the
# fixture column.
inputs_fingerprint() {
  cat tests/schema_assertions.sql tests/shim.sql scripts/guards.sh "$0"       supabase/migrations/0*.sql 2>/dev/null | cksum
}
INPUTS_AT_START=$(inputs_fingerprint)

if ! docker exec "$CONTAINER" true 2>/dev/null; then
  echo "cannot reach $CONTAINER"; exit 2
fi

# ---------------------------------------------------------------------------
echo "building the base database from the shim and every migration"
# ---------------------------------------------------------------------------
adm "drop database if exists $BASE;"
adm "create database $BASE;"
docker exec -i "$CONTAINER" psql -U postgres -q -v ON_ERROR_STOP=1 -d "$BASE" < tests/shim.sql >/dev/null 2>&1 \
  || { echo "the shim did not apply"; exit 2; }
for f in supabase/migrations/0*.sql; do
  docker exec -i "$CONTAINER" psql -U postgres -q -v ON_ERROR_STOP=1 -d "$BASE" < "$f" >/dev/null 2>&1 \
    || { echo "$f did not apply"; exit 2; }
done

# A baseline run, because a mutation score computed against a suite that was
# already failing would be meaningless.
adm "drop database if exists $WORK;"
adm "create database $WORK template $BASE;"
if ! docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 -d "$WORK" < tests/schema_assertions.sql >/dev/null 2>&1; then
  echo "the suite does not pass on an unmutated database; fix that first"; exit 2
fi
baseline=$(docker exec -i "$CONTAINER" psql -U postgres -d "$WORK" < tests/schema_assertions.sql 2>&1 | grep -c '^NOTICE:  ok')
adm "drop database if exists $WORK;"
echo "baseline: the suite passes, $baseline assertions"
echo

# ---------------------------------------------------------------------------
# Enumerate the mutations. Each line is: class<TAB>label<TAB>sql
# ---------------------------------------------------------------------------
muts=$(mktemp)
trap 'rm -f "$muts"' EXIT

enumerate check "$BASE" "
select 'check' || chr(9) || t.relname || '.' || c.conname || chr(9) ||
       format('alter table public.%I drop constraint %I', t.relname, c.conname)
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and c.contype = 'c'
 order by t.relname, c.conname;"

# Loosening rather than dropping, for check constraints only. A pinned inventory
# counts constraints by type and so cannot tell a constraint that still exists
# and refuses nothing; only this can. There is no equivalent for a unique
# constraint, which either is unique or is not.
enumerate loosen "$BASE" "
select 'loosen' || chr(9) || t.relname || '.' || c.conname || chr(9) ||
       format('alter table public.%I drop constraint %I; alter table public.%I add constraint %I check (true)',
              t.relname, c.conname, t.relname, c.conname)
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and c.contype = 'c'
 order by t.relname, c.conname;"

enumerate unique "$BASE" "
select 'unique' || chr(9) || t.relname || '.' || c.conname || chr(9) ||
       format('alter table public.%I drop constraint %I', t.relname, c.conname)
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and c.contype = 'u'
 order by t.relname, c.conname;"

enumerate unique "$BASE" "
select 'unique' || chr(9) || ix.relname || chr(9) || format('drop index public.%I', ix.relname)
  from pg_index i
  join pg_class t on t.oid = i.indrelid
  join pg_class ix on ix.oid = i.indexrelid
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and i.indisunique and not i.indisprimary
   and not exists (select 1 from pg_constraint c where c.conindid = i.indexrelid)
 order by ix.relname;"

enumerate trigger "$BASE" "
select 'trigger' || chr(9) || t.relname || '.' || g.tgname || chr(9) ||
       format('alter table public.%I disable trigger %I', t.relname, g.tgname)
  from pg_trigger g
  join pg_class t on t.oid = g.tgrelid
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and not g.tgisinternal
 order by t.relname, g.tgname;"

enumerate policy "$BASE" "
select 'policy' || chr(9) || tablename || '.' || policyname || chr(9) ||
       format('drop policy %I on public.%I', policyname, tablename)
  from pg_policies where schemaname = 'public'
 order by tablename, policyname;"

# Weakening rather than dropping. A pinned policy list catches a policy that
# disappears; only this catches one that is still there and no longer refuses
# anything, which is the failure mode a schema move actually produces. Recreated
# with the same name, same command, same roles, and a predicate of true.
enumerate weaken "$BASE" "
select 'weaken' || chr(9) || tablename || '.' || policyname || chr(9) ||
       format('drop policy %I on public.%I; create policy %I on public.%I for %s to %s%s%s',
              policyname, tablename, policyname, tablename,
              case cmd when 'ALL' then 'all' when 'SELECT' then 'select'
                       when 'INSERT' then 'insert' when 'UPDATE' then 'update'
                       else 'delete' end,
              array_to_string(roles, ', '),
              case when qual is not null then ' using (true)' else '' end,
              case when with_check is not null or cmd in ('INSERT','ALL','UPDATE')
                   then ' with check (true)' else '' end)
  from pg_policies where schemaname = 'public'
   -- No exclusion here any more. A policy that is already wide open cannot be
   -- weakened, and nineteen of these inject no defect at all, but they are now
   -- detected by the fingerprint after applying and named as degenerate in the
   -- output. Dropping them at enumeration was correct and invisible, and
   -- invisible is half of what was wrong with it.
 order by tablename, policyname;"

enumerate rls "$BASE" "
select 'rls' || chr(9) || t.relname || chr(9) ||
       format('alter table public.%I disable row level security', t.relname)
  from pg_class t
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and t.relrowsecurity
 order by t.relname;"

# Function bodies. The six classes above are all declarative, so without this a
# perfect score would mean "nothing can be removed" and would be read as "the
# kernel is correct". Each mutation is a substitution against
# pg_get_functiondef, so it carries the function's real signature, volatility and
# search_path rather than a copy that drifts.
#
# This class used to be a list of substitutions written by hand, and X-1-5 was the
# standing caveat on it: ten chosen by the author scored 10 of 10, nine chosen by
# X-1 scored 6 of 9, sixteen chosen by W-6 scored 5 of 16. The three figures are
# ordered by how far each chooser stood from the code and ordered equally well by
# how hard each was looking for gaps, and nothing separates those explanations.
# W-6 proposed fixing it by constraining who chooses. That constrains the chooser
# and not the choice.
#
# The population has no chooser. scripts/guards.sh enumerates every refusal site
# in every function the kernel owns and this class now substitutes against all of
# them, so the denominator is the surface rather than a sample of it.
sites=$(bash scripts/guards.sh "$BASE" 2>/tmp/.guards-held)
if [ -z "$sites" ]; then
  echo "THE REFUSAL ENUMERATION RETURNED NOTHING, refusing to score." >&2
  sed 's/^/    /' /tmp/.guards-held >&2
  exit 2
fi
n_all=$(printf '%s\n' "$sites" | grep -c .)
# guards.sh emits the population, including any site it cannot substitute. Those
# are named, not dropped: a site missing from the denominator and a site that does
# not exist produce the same percentage, and only one of them is true.
mutable=$(printf '%s\n' "$sites" | awk -F'\t' '$6 > 0')
n_sites=$(printf '%s\n' "$mutable" | grep -c .)
if [ "$n_sites" -ne "$n_all" ]; then
  echo "  note: $(( n_all - n_sites )) of $n_all enumerated refusal sites cannot be substituted"
fi
# The one character the transport reserves. No source line contains one and
# this is here so that the first one that does is an abort rather than a class
# that came up short without saying so.
if printf '%s\n' "$sites" | grep -q "$(printf '\x01')"; then
  echo "a refusal site contains the transport quote character, refusing to score." >&2
  exit 2
fi

# The transport is copy from stdin rather than a values list, because the fields
# are arbitrary source lines and every quoting scheme that has to escape them is
# a defect waiting for the first function that uses that character. csv format
# with a quote character no source line can contain is the one shape that needs
# no escaping at all: text format would read a backslash in a function body as an
# escape, and the day the kernel gains its first backslash should not be the day
# the logic class quietly loses a row.
logic_sql="
with u as (
  select id, fn, replace(find, '\n', chr(10)) as find,
              replace(repl, '\n', chr(10)) as repl, occ
    from w7_sites)
select 'logic' || chr(9) || s.id || ': ' || replace(s.find, chr(10), ' ') || chr(9) || 'b64:' ||
       translate(encode(convert_to(
         array_to_string((string_to_array(d.def, s.find))[1:s.occ], s.find)
         || s.repl
         || array_to_string((string_to_array(d.def, s.find))[s.occ+1:], s.find),
       'UTF8'), 'base64'), chr(10), '')
  from u s
  join (select p.proname as fn, pg_get_functiondef(p.oid) as def
          from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public') d
    on d.fn = s.fn
 order by s.id;"

before=$(grep -c . "$muts" 2>/dev/null); before=${before:-0}
{
  echo "create temp table w7_sites(id text, fn text, kind text, find text, repl text, occ int);"
  echo "copy w7_sites from stdin with (format csv, delimiter E'\t', quote E'\x01', escape E'\x01');"
  printf '%s\n' "$mutable"
  echo "\."
  echo "$logic_sql"
} | docker exec -i "$CONTAINER" psql -U postgres -At -q -v ON_ERROR_STOP=1 -d "$BASE" \
      >> "$muts" 2>/tmp/.mutate-q.err
rc=$?
if [ "$rc" -ne 0 ] || [ -s /tmp/.mutate-q.err ]; then
  echo "THE LOGIC ENUMERATION FAILED, refusing to score. psql exited $rc:" >&2
  sed 's/^/    /' /tmp/.mutate-q.err >&2
  exit 2
fi
after=$(grep -c . "$muts" 2>/dev/null); after=${after:-0}
n_logic=$(( after - before ))

# X-1-7 in its new form. The old check asked whether a hand-written target string
# still existed, because the list could drift from the code. This list cannot
# drift, it is read out of the same database in the same run, so the failure it
# has to catch is a different one: a site enumerated and then lost on the way to
# the mutation file. A site that is silently absent is scored as a site that does
# not exist, and the two look identical inside a percentage.
if [ "$n_logic" -ne "$n_sites" ]; then
  echo "REFUSAL SITES LOST BETWEEN ENUMERATION AND MUTATION, refusing to score." >&2
  echo "    guards.sh emitted $n_sites sites and $n_logic became mutations." >&2
  exit 2
fi
printf '  %-8s %d mutations\n' logic "$n_logic"

# A site guards.sh could not attribute to a position is a hole in the instrument
# and not in the schema. It is printed rather than counted, because a hole
# counted as covered is the thing this project keeps finding.
if [ -s /tmp/.guards-held ]; then
  sed 's/^/  /' /tmp/.guards-held
fi

[ -n "$ONLY" ] && { grep "^$ONLY	" "$muts" > "$muts.f"; mv "$muts.f" "$muts"; }

total=$(grep -c . "$muts")
# X-1-10: a filtered run used to print output identical in shape to a full one,
# which is exactly how a single-class number got quoted as a whole-run number and
# produced the 20 against 21 exclusion error the progress file corrects. The
# scope is now named at the top and repeated in the closing line.
SCOPE=$( [ -n "$ONLY" ] && echo "class '$ONLY' only" || echo "all classes" )
echo "$total mutations enumerated, $SCOPE"
echo

# ---------------------------------------------------------------------------
# Run them.
# ---------------------------------------------------------------------------
#
# Three outcomes are not a score. A mutation can fail to apply, or apply and
# change nothing, and in both cases the suite's behaviour says nothing about the
# suite. Both are named in the output and excluded from numerator and
# denominator, because a harness that reports a number without reporting that the
# number is unsound is the exact defect this whole line of work exists to correct,
# arriving from inside the instrument.
survivors=$(mktemp); inapplicable=$(mktemp); degenerate=$(mktemp); snaponly=$(mktemp); fixtures=$(mktemp)
trap 'rm -f "$muts" "$survivors" "$inapplicable" "$degenerate" "$fixtures" "$snaponly"' EXIT

# A fingerprint of everything any mutation class can touch. Taken before and
# after a mutation is applied: if it does not move, the mutation changed nothing
# and scoring it would be measuring the suite against a schema nobody altered.
#
# This replaces the enumeration-time exclusion of weaken mutations whose policy
# was already `true`. That exclusion was correct and invisible, which is half of
# what was wrong with it; these are named.
fingerprint() {
  docker exec "$CONTAINER" psql -U postgres -At -d "$1" -c "
    select md5(string_agg(line, '|' order by line)) from (
      select 'c:' || t.relname || '.' || c.conname || ':' || pg_get_constraintdef(c.oid) as line
        from pg_constraint c join pg_class t on t.oid = c.conrelid
        join pg_namespace n on n.oid = t.relnamespace where n.nspname = 'public'
      union all
      select 'i:' || ix.relname || ':' || pg_get_indexdef(i.indexrelid)
        from pg_index i join pg_class t on t.oid = i.indrelid
        join pg_class ix on ix.oid = i.indexrelid
        join pg_namespace n on n.oid = t.relnamespace where n.nspname = 'public'
      union all
      select 'g:' || t.relname || '.' || g.tgname || ':' || g.tgenabled::text
        from pg_trigger g join pg_class t on t.oid = g.tgrelid
        join pg_namespace n on n.oid = t.relnamespace
       where n.nspname = 'public' and not g.tgisinternal
      union all
      select 'p:' || tablename || '.' || policyname || ':' || cmd || ':' ||
             array_to_string(roles, ',') || ':' || coalesce(qual, '-') || ':' || coalesce(with_check, '-')
        from pg_policies where schemaname = 'public'
      union all
      select 'r:' || t.relname || ':' || t.relrowsecurity::text || t.relforcerowsecurity::text
        from pg_class t join pg_namespace n on n.oid = t.relnamespace
       where n.nspname = 'public' and t.relkind = 'r'
      union all
      select 'f:' || p.proname || ':' || md5(pg_get_functiondef(p.oid))
        from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.prokind = 'f'
    ) x;" 2>/dev/null
}

declare -A seen caught_b caught_s fixture
i=0
while IFS=$'\t' read -r class label sql; do
  [ -z "$class" ] && continue
  i=$((i + 1))
  adm "drop database if exists $WORK;"
  adm_or_die "create database $WORK template $BASE;"

  before=$(fingerprint "$WORK")
  # An empty fingerprint means the query is broken, not that the schema is. The
  # first version of this silently skipped degeneracy detection when that
  # happened, because `tgenabled` is "char" and concatenating it raised, which
  # is the same fail-open shape W-4 exists to correct occurring inside the fix
  # for it. It aborts now.
  if [ -z "$before" ]; then
    echo "the fingerprint query returned nothing, so degeneracy cannot be detected; refusing to score" >&2
    exit 2
  fi

  # A mutation whose statement spans lines cannot travel in a line-based file,
  # and `read` silently truncates it at the first newline, which reported all ten
  # function-body mutations as inapplicable until this existed. Those arrive
  # base64 encoded and are decoded here.
  if [ "${sql#b64:}" != "$sql" ]; then
    printf '%s' "${sql#b64:}" | base64 -d > /tmp/.mutation.sql
    applied_ok=$(docker exec -i "$CONTAINER" psql -U postgres -q -v ON_ERROR_STOP=1 -d "$WORK" < /tmp/.mutation.sql >/dev/null 2>&1 && echo yes || echo no)
  else
    applied_ok=$(docker exec "$CONTAINER" psql -U postgres -q -v ON_ERROR_STOP=1 -d "$WORK" -c "$sql" >/dev/null 2>&1 && echo yes || echo no)
  fi
  if [ "$applied_ok" = "no" ]; then
    printf '%s\t%s\n' "$class" "$label" >> "$inapplicable"
    printf '  %3d/%d  %-8s %-46s not applicable\n' "$i" "$total" "$class" "$label"
    continue
  fi

  after=$(fingerprint "$WORK")
  if [ "$before" = "$after" ]; then
    printf '%s\t%s\n' "$class" "$label" >> "$degenerate"
    printf '  %3d/%d  %-8s %-46s degenerate, changed nothing\n' "$i" "$total" "$class" "$label"
    continue
  fi

  seen[$class]=$(( ${seen[$class]:-0} + 1 ))

  # Two passes, and they answer different questions. This is W-6 phase 2 and it
  # is the most consequential change in the harness.
  #
  # Pass one runs with the snapshot assertions switched off, so only an assertion
  # that exercises the schema can catch anything. That is the behavioural score
  # and it is the gate.
  #
  # Pass two runs only for what survived pass one, with the snapshots back on. A
  # mutation caught only there was caught by a pinned catalog comparison noticing
  # that the catalog moved. That is a change detector, it is worth having, and it
  # is not evidence that anything was refused.
  #
  # X-1 measured 86 of 198 catches to be snapshot-only, so the combined figure
  # this harness reported for two sessions was 198 of 198 and the behavioural
  # figure was 112 of 198.
  run_suite() {   # $1 = on|off ; sets RC and OKS
    if [ "$1" = off ]; then
      docker exec -i -e PGOPTIONS="-c vsv.snapshots=off" "$CONTAINER" \
        psql -U postgres -v ON_ERROR_STOP=1 -d "$WORK" \
        < tests/schema_assertions.sql > /tmp/.mutate-run.log 2>&1
    else
      docker exec -i "$CONTAINER" \
        psql -U postgres -v ON_ERROR_STOP=1 -d "$WORK" \
        < tests/schema_assertions.sql > /tmp/.mutate-run.log 2>&1
    fi
    RC=$?
    OKS=$(grep -c '^NOTICE:  ok' /tmp/.mutate-run.log)
  }

  run_suite off

  # X-1-8: a suite that did not run is not evidence about the schema. psql exits
  # non-zero when it cannot connect, when the role is missing and when the
  # database was dropped, exactly as it does when an assertion fails, so a
  # harness that lost Postgres used to score every remaining mutation as caught
  # and finish at 100 percent.
  if [ "$RC" -ne 0 ] && [ "$OKS" -eq 0 ]; then
    echo "THE ASSERTION SUITE DID NOT RUN on mutation '$class $label', refusing to score." >&2
    grep -iE 'error|fatal' /tmp/.mutate-run.log | head -3 | sed 's/^/    /' >&2
    exit 2
  fi

  if [ "$RC" -ne 0 ]; then
    # X-1-15: a mutation can break a fixture the suite needs before any assertion
    # is reached, and the message then names the fixture rather than the defect.
    # Still the mutated schema failing, still counted, but in its own column so
    # the number is not read as behavioural detection when it is a not-null
    # violation on a fixture.
    if grep -q 'FAIL:' /tmp/.mutate-run.log; then
      caught_b[$class]=$(( ${caught_b[$class]:-0} + 1 ))
      printf '  %3d/%d  %-8s %-44s caught, behavioural\n' "$i" "$total" "$class" "$label"
    else
      caught_b[$class]=$(( ${caught_b[$class]:-0} + 1 ))
      fixture[$class]=$(( ${fixture[$class]:-0} + 1 ))
      printf '%s\t%s\t%s\n' "$class" "$label" \
        "$(grep -m1 -E '^(ERROR|FATAL|psql:)' /tmp/.mutate-run.log | cut -c1-90)" >> "$fixtures"
      printf '  %3d/%d  %-8s %-44s caught, by breaking a fixture\n' "$i" "$total" "$class" "$label"
    fi
  else
    run_suite on
    if [ "$RC" -ne 0 ] && [ "$OKS" -eq 0 ]; then
      echo "THE ASSERTION SUITE DID NOT RUN on the snapshot pass for '$class $label'." >&2
      exit 2
    fi
    if [ "$RC" -ne 0 ]; then
      caught_s[$class]=$(( ${caught_s[$class]:-0} + 1 ))
      printf '%s\t%s\n' "$class" "$label" >> "$snaponly"
      printf '  %3d/%d  %-8s %-44s caught by a snapshot only\n' "$i" "$total" "$class" "$label"
    else
      printf '%s\t%s\n' "$class" "$label" >> "$survivors"
      printf '  %3d/%d  %-8s %-44s SURVIVED BOTH\n' "$i" "$total" "$class" "$label"
    fi
  fi
done < "$muts"

adm "drop database if exists $WORK;"

# ---------------------------------------------------------------------------
echo
echo "| Class | Scored | Behavioural | of which fixture | Snapshot only | Behavioural score |"
echo "|---|---|---|---|---|---|"
ts=0; tb=0; tf=0; tsn=0
for class in check loosen unique trigger policy weaken rls logic; do
  n=${seen[$class]:-0}; b=${caught_b[$class]:-0}; f=${fixture[$class]:-0}; sn=${caught_s[$class]:-0}
  [ "$n" -eq 0 ] && continue
  ts=$((ts + n)); tb=$((tb + b)); tf=$((tf + f)); tsn=$((tsn + sn))
  printf '| %s | %d | %d | %d | %d | %d%% |\n' "$class" "$n" "$b" "$f" "$sn" "$(( b * 100 / n ))"
done
[ "$ts" -gt 0 ] && printf '| **Total** | **%d** | **%d** | **%d** | **%d** | **%d%%** |\n' \
  "$ts" "$tb" "$tf" "$tsn" "$(( tb * 100 / ts ))"

n_surv=$(grep -c . "$survivors" 2>/dev/null); n_surv=${n_surv:-0}
n_inap=$(grep -c . "$inapplicable" 2>/dev/null); n_inap=${n_inap:-0}
n_degen=$(grep -c . "$degenerate" 2>/dev/null); n_degen=${n_degen:-0}
n_fix=$(grep -c . "$fixtures" 2>/dev/null); n_fix=${n_fix:-0}
n_snap=$(grep -c . "$snaponly" 2>/dev/null); n_snap=${n_snap:-0}

echo
if [ "$n_surv" -gt 0 ]; then
  echo "survived both passes, which are the defects nothing in this suite would notice:"
  sort "$survivors" | awk -F'\t' '{printf "  %-8s %s\n", $1, $2}'
else
  echo "nothing survived both passes."
fi

if [ "$n_snap" -gt 0 ]; then
  echo
  echo "$n_snap caught only by a snapshot. A pinned catalog comparison noticed the catalog"
  echo "moved. Nothing refused anything, and these are not evidence about behaviour:"
  sort "$snaponly" | awk -F'\t' '{printf "  %-8s %s\n", $1, $2}'
fi

# The logic class covers the whole refusal surface now rather than a sample of
# it, so the useful cut is no longer who chose the substitution. It is what kind
# of refusal was removed. A raise that has become a notice and a conjunct that
# has stopped narrowing an update fail in very different ways, and there is no
# reason to expect the suite to be equally able to see them.
if [ "${seen[logic]:-0}" -gt 0 ]; then
  declare -A ktot=() kmiss=()
  while IFS=$'	' read -r cls lbl _; do
    [ "$cls" = logic ] || continue
    k=${lbl#*:}; k=${k%%:*}
    ktot[$k]=$(( ${ktot[$k]:-0} + 1 ))
  done < "$muts"
  for f in "$survivors" "$snaponly"; do
    while IFS=$'	' read -r cls lbl _; do
      [ "$cls" = logic ] || continue
      k=${lbl#*:}; k=${k%%:*}
      kmiss[$k]=$(( ${kmiss[$k]:-0} + 1 ))
    done < "$f"
  done
  echo
  echo "the refusal surface by kind of refusal:"
  for k in raise guard notfound earlyreturn permissive silent; do
    t=${ktot[$k]:-0}; [ "$t" -eq 0 ] && continue
    m=${kmiss[$k]:-0}
    printf '  %-12s %d of %d caught behaviourally\n' "$k" "$((t-m))" "$t"
  done
fi

if [ "$n_fix" -gt 0 ]; then
  echo
  echo "$n_fix of the behavioural catches are the mutation breaking a fixture the suite needs,"
  echo "so the message names the fixture rather than the defect:"
  sort "$fixtures" | awk -F'\t' '{printf "  %-8s %-44s %s\n", $1, $2, $3}'
fi

if [ "$n_degen" -gt 0 ]; then
  echo
  # W-9 phase 2. Excluding these from the score is right and reading past them
  # was not: a weaken mutation that changes nothing is a policy that was already
  # blanket true, and twenty of them printed here every run for three sessions
  # while ledger A5 sat open and a live run found it by hand. They are judged now,
  # in tests/schema_assertions.sql, and this line says so because the last five
  # sessions all read this list and none of them read it as a finding.
  echo "$n_degen mutation(s) applied and changed nothing, so they are excluded from every column."
  echo "  A degenerate weaken is a policy with nothing left to weaken. Every one is"
  echo "  dispositioned in tests/schema_assertions.sql; a new one fails there."
  sort "$degenerate" | awk -F'\t' '{printf "  %-8s %s\n", $1, $2}'
fi

if [ "$n_inap" -gt 0 ]; then
  echo
  echo "$n_inap mutation(s) could not be applied at all, so they are excluded from every column:"
  sort "$inapplicable" | awk -F'\t' '{printf "  %-8s %s\n", $1, $2}'
fi

# Two numbers, never one, and never a bare percentage. A single figure from this
# tool was read for two sessions as a statement about the kernel when 43 percent
# of it was a string comparison noticing that a list of names had grown.
echo
excluded=$(( n_degen + n_inap ))
if [ "$ts" -eq 0 ]; then
  echo "NO SCORE: nothing was scored. $excluded mutation(s) were excluded."
  exit 2
fi
if [ "$(inputs_fingerprint)" != "$INPUTS_AT_START" ]; then
  echo "THE INPUTS CHANGED WHILE THIS RAN, so the score is void." >&2
  echo "    One of tests/schema_assertions.sql, tests/shim.sql, scripts/guards.sh," >&2
  echo "    this script or a migration was edited after the run began. Every" >&2
  echo "    mutation after that point was scored against a different suite." >&2
  exit 2
fi

# A suite that is failing for its own reasons catches every mutation, and the
# fixture column is where that shows. It was 34 of 268 in W-9 and 294 of 356 in
# the run that prompted this check. There is no correct threshold, and a share
# above half means the suite was probably broken rather than the schema covered.
if [ "$tb" -gt 0 ] && [ $(( tf * 2 )) -gt "$tb" ]; then
  echo "MOST CATCHES ARE FIXTURE BREAKAGE, $tf of $tb, so this score is not about coverage." >&2
  echo "    A suite failing for its own reasons catches everything. Check that the" >&2
  echo "    assertion suite passes unmutated before reading any of this." >&2
  exit 2
fi

echo "SCORES, $SCOPE, from $total enumerated:"
printf '  behavioural  %d of %d (%d%%)   the gate. An assertion exercised the schema and refused.\n' \
  "$tb" "$ts" "$(( tb * 100 / ts ))"
printf '  snapshot     %d of %d (%d%%)   a change detector. A pinned list noticed the catalog moved.\n' \
  "$tsn" "$ts" "$(( tsn * 100 / ts ))"
printf '  neither      %d of %d\n' "$n_surv" "$ts"
if [ "$tf" -gt 0 ]; then
  printf '  of the behavioural figure, %d are fixture breakage rather than detection.\n' "$tf"
fi
if [ "$excluded" -gt 0 ]; then
  printf '  %d excluded, %d degenerate and %d inapplicable, listed above.\n' \
    "$excluded" "$n_degen" "$n_inap"
else
  echo '  nothing excluded: every enumerated mutation applied and changed something.'
fi

# The gate in docs/review/CURRENT-BASELINE.md is enforced by scripts/ratchet.sh,
# which needs the outcome of each mutation rather than the prose above. Prose is
# what the last two gates were written against, and parsing it is how a gate ends
# up agreeing with a run that did not happen.
if [ -n "${MUT_REPORT:-}" ]; then
  mkdir -p "$MUT_REPORT" || { echo "cannot write $MUT_REPORT" >&2; exit 2; }
  cp "$muts"         "$MUT_REPORT/enumerated.tsv"
  cp "$survivors"    "$MUT_REPORT/survived.tsv"
  cp "$snaponly"     "$MUT_REPORT/snapshot-only.tsv"
  cp "$fixtures"     "$MUT_REPORT/fixture-breakage.tsv"
  cp "$inapplicable" "$MUT_REPORT/inapplicable.tsv"
  cp "$degenerate"   "$MUT_REPORT/degenerate.tsv"
  {
    printf 'scored	%d
'       "$ts"
    printf 'behavioural	%d
'  "$tb"
    printf 'fixture	%d
'      "$tf"
    printf 'snapshot	%d
'     "$tsn"
    printf 'survived	%d
'     "$n_surv"
    printf 'degenerate	%d
'   "$n_degen"
    printf 'inapplicable	%d
' "$n_inap"
  } > "$MUT_REPORT/score.tsv"
  echo
  echo "machine readable results written to $MUT_REPORT"
fi
