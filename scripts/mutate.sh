#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Measures what fraction of deliberately injected schema defects the
#           assertion suite catches. A suite that passes tells you it ran; a
#           mutation score tells you whether it would have noticed."
# Depends on: [tests/shim.sql, tests/schema_assertions.sql]
# Depended on by: [docs/session-reports/modularization-progress.md]
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
#   logic        a function body, changed one substitution at a time
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
# The list is shared between two queries below rather than written twice, because
# the first version of the vanished-target check duplicated it and a duplicated
# list is a list that goes out of step.
#
# X-1-5 is the standing caveat on this class and it is not fixed here: ten
# substitutions chosen by the author score 10 of 10, and nine chosen
# independently score 6 of 9. The class samples the procedural surface; it does
# not cover it.
LOGIC_SUBS="
  ('is_admin',                   'and active',                      '',                     'author: drops the active conjunct, ledger B10 in the client'),
  ('is_facility_user',           'is_admin() or (',                 'true or (',            'author: everyone becomes staff'),
  ('claim_account',              'when is_first then',              'when true then',       'author: every claimant becomes admin'),
  ('close_node_when_empty',      'new.quantity <= 0',               'new.quantity < 0',     'author: a lot at exactly zero never closes'),
  ('bind_vessel_code',           'existing.vessel_id = p_vessel_id','true',                 'author: the cross-vessel guard goes, a rebind returns silently'),
  ('cellar_writable_columns',    'if not (changed = any(tg_argv))', 'if false',             'author: the column allow-list stops refusing'),
  ('rack',                       'nullif(contributed, 0)',          'nullif(total_in, 0)',  'author: shares divided by arrival not contribution, the wire session bug'),
  ('update_vessel',              'is distinct from',                'is not distinct from', 'author: a thermal change records only when nothing changed'),
  ('resolve_subject_name',       'is null then',                    'is not null then',     'author: the deflation inverts'),
  ('confirm_event',              'is_admin()',                      'true',                 'author: anyone may confirm, T0-4'),
  ('claim_task',                 'and status = ''open''',           'and status is not null', 'independent: a claimed task can be taken from whoever holds it'),
  ('validate_vessel_attributes', 'if coalesce((f ->> ''required'')::boolean, false) then', 'if false then', 'independent: required fields stop being required'),
  ('finish_run',                 'raise exception ''no such run''', 'null',                 'independent: finishing a run that does not exist writes against a null vessel'),
  ('visible_node',               'may_see_all_of',                  'true or may_see_all_of', 'independent: a client sees every field of every lot'),
  ('set_lot_hidden',             'if not may_set_privacy(p_node_id)', 'if false',           'independent: anyone sets what is hidden about another party''s wine'),
  ('validate_vessel_type_fields', 'not in (''term'', ''number'', ''text'')', 'is null and false', 'independent: a field of any kind at all is accepted'),
  ('record_event',               'if op_id is null then',           'if false then',        'independent: an unknown operation writes an event with a null operation'),
  ('fill_vessel',                'if occupied is not null then',    'if false then',        'independent: wine goes into a vessel that already holds some'),
  ('update_vessel',              'if not found then',               'if false then',        'independent: editing a vessel that does not exist reports success'),
  ('fork_lot',                   'if n_here = 0 then',              'if false then',        'independent: forking zero vessels off a lot'),
  ('register_subject_resolver',  'if not is_admin() then',          'if false then',        'independent: anyone registers a resolver, which reaches dynamic SQL'),
  ('rack',                       'and not p_allow_overfill',        'and false',            'independent: overfilling a vessel stops needing confirmation'),
  ('node_bin_shares',            '''composition'' = any(n.hidden)', 'false',                'independent: a hidden composition is disclosed anyway'),
  ('topping_check',              'if tgt is null then',             'if false then',        'independent: topping into a vessel with nothing in it'),
  ('claim_task',                 'and claimed_by is null',          'and true',             'independent: the second half of the claim guard'),
  ('fill_vessel',                'and active',                      '',                     'independent: wine goes into a deactivated vessel')
"

# X-1-7: this list is hand-maintained, and a substitution whose target string no
# longer occurs used to be dropped by the where clause at enumeration. It was
# absent from the total, absent from the inapplicable list, and absent from the
# summary, against a comment claiming it reported as not applicable. Refactoring
# any named function silently shrank the only class that tests procedural logic
# while the percentage stayed at 100.
#
# It aborts now, and names the substitution, because a hand-maintained list that
# has drifted from the code is not a smaller list, it is an unmaintained one.
missing=$(q "$BASE" "
with m(fn, find, repl, note) as (values $LOGIC_SUBS)
select m.fn || ': ' || m.find
  from m
  left join pg_proc p
    on p.proname = m.fn
   and p.pronamespace = 'public'::regnamespace
   and position(m.find in pg_get_functiondef(p.oid)) > 0
 where p.oid is null
 order by m.fn;")

if [ -n "$missing" ]; then
  echo "LOGIC SUBSTITUTION TARGETS HAVE GONE, refusing to score:" >&2
  printf '%s\n' "$missing" | sed 's/^/    /' >&2
  echo "    Either the function was refactored and the substitution needs rewriting," >&2
  echo "    or the function is gone and the entry should be removed. Both are" >&2
  echo "    deliberate acts. Silently dropping the entry is not." >&2
  exit 2
fi

enumerate logic "$BASE" "
with m(fn, find, repl, note) as (values $LOGIC_SUBS)
select 'logic' || chr(9) || m.fn || ': ' || m.note || chr(9) || 'b64:' ||
       translate(encode(convert_to(replace(pg_get_functiondef(p.oid), m.find, m.repl), 'UTF8'), 'base64'), chr(10), '')
  from m
  join pg_proc p on p.proname = m.fn
  join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
 where position(m.find in pg_get_functiondef(p.oid)) > 0
 order by m.fn;"

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
survivors=$(mktemp); inapplicable=$(mktemp); degenerate=$(mktemp); fixtures=$(mktemp); snaponly=$(mktemp); fixtures=$(mktemp)
trap 'rm -f "$muts" "$survivors" "$inapplicable" "$degenerate" "$fixtures"' EXIT

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

# The logic class is the only sampled class, and the whole point of X-1-5 is that
# who chose the sample decides the number. Reported split by provenance.
if [ "${seen[logic]:-0}" -gt 0 ]; then
  la=0; lai=0; li=0; lii=0
  while IFS=$'	' read -r cls lbl _; do
    [ "$cls" = logic ] || continue
    case "$lbl" in *"author:"*) la=$((la+1));; *) li=$((li+1));; esac
  done < "$muts"
  for f in "$survivors" "$snaponly"; do
    while IFS=$'	' read -r cls lbl _; do
      [ "$cls" = logic ] || continue
      case "$lbl" in *"author:"*) lai=$((lai+1));; *) lii=$((lii+1));; esac
    done < "$f"
  done
  echo
  echo "the logic class by who chose the substitution, which is X-1-5's point:"
  [ "$la" -gt 0 ] && printf '  author       %d of %d caught behaviourally
' "$((la-lai))" "$la"
  [ "$li" -gt 0 ] && printf '  independent  %d of %d caught behaviourally
' "$((li-lii))" "$li"
fi

if [ "$n_fix" -gt 0 ]; then
  echo
  echo "$n_fix of the behavioural catches are the mutation breaking a fixture the suite needs,"
  echo "so the message names the fixture rather than the defect:"
  sort "$fixtures" | awk -F'\t' '{printf "  %-8s %-44s %s\n", $1, $2, $3}'
fi

if [ "$n_degen" -gt 0 ]; then
  echo
  echo "$n_degen mutation(s) applied and changed nothing, so they are excluded from every column:"
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
