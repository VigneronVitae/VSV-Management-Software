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
# does. Five classes:
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

q()  { docker exec "$CONTAINER" psql -U postgres -At -d "$1" -c "$2" 2>/dev/null; }
adm(){ docker exec "$CONTAINER" psql -U postgres -q -d postgres -c "$1" >/dev/null 2>&1; }

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

q "$BASE" "
select 'check' || chr(9) || t.relname || '.' || c.conname || chr(9) ||
       format('alter table public.%I drop constraint %I', t.relname, c.conname)
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and c.contype = 'c'
 order by t.relname, c.conname;" >> "$muts"

# Loosening rather than dropping, for check constraints only. A pinned inventory
# counts constraints by type and so cannot tell a constraint that still exists
# and refuses nothing; only this can. There is no equivalent for a unique
# constraint, which either is unique or is not.
q "$BASE" "
select 'loosen' || chr(9) || t.relname || '.' || c.conname || chr(9) ||
       format('alter table public.%I drop constraint %I; alter table public.%I add constraint %I check (true)',
              t.relname, c.conname, t.relname, c.conname)
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and c.contype = 'c'
 order by t.relname, c.conname;" >> "$muts"

q "$BASE" "
select 'unique' || chr(9) || t.relname || '.' || c.conname || chr(9) ||
       format('alter table public.%I drop constraint %I', t.relname, c.conname)
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and c.contype = 'u'
 order by t.relname, c.conname;" >> "$muts"

q "$BASE" "
select 'unique' || chr(9) || ix.relname || chr(9) || format('drop index public.%I', ix.relname)
  from pg_index i
  join pg_class t on t.oid = i.indrelid
  join pg_class ix on ix.oid = i.indexrelid
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and i.indisunique and not i.indisprimary
   and not exists (select 1 from pg_constraint c where c.conindid = i.indexrelid)
 order by ix.relname;" >> "$muts"

q "$BASE" "
select 'trigger' || chr(9) || t.relname || '.' || g.tgname || chr(9) ||
       format('alter table public.%I disable trigger %I', t.relname, g.tgname)
  from pg_trigger g
  join pg_class t on t.oid = g.tgrelid
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and not g.tgisinternal
 order by t.relname, g.tgname;" >> "$muts"

q "$BASE" "
select 'policy' || chr(9) || tablename || '.' || policyname || chr(9) ||
       format('drop policy %I on public.%I', policyname, tablename)
  from pg_policies where schemaname = 'public'
 order by tablename, policyname;" >> "$muts"

# Weakening rather than dropping. A pinned policy list catches a policy that
# disappears; only this catches one that is still there and no longer refuses
# anything, which is the failure mode a schema move actually produces. Recreated
# with the same name, same command, same roles, and a predicate of true.
q "$BASE" "
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
 order by tablename, policyname;" >> "$muts"

q "$BASE" "
select 'rls' || chr(9) || t.relname || chr(9) ||
       format('alter table public.%I disable row level security', t.relname)
  from pg_class t
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and t.relrowsecurity
 order by t.relname;" >> "$muts"

# Function bodies. Nine of G-5's forty five mutations were of this kind and the
# six classes above are all declarative, so without this a perfect score would
# mean "nothing can be removed" and would be read as "the kernel is correct".
# Each mutation is a substitution against pg_get_functiondef, so it carries the
# function's real signature, volatility and search_path rather than a copy that
# drifts. A substitution whose target string is gone reports as not applicable,
# which is also how this list tells you a function has changed shape.
q "$BASE" "
with m(fn, find, repl, note) as (values
  ('is_admin',                   'and active',                      '',                     'drops the active conjunct, which is ledger B10 in the client'),
  ('is_facility_user',           'is_admin() or (',                 'true or (',            'everyone becomes staff'),
  ('claim_account',              'when is_first then',              'when true then',       'every claimant becomes admin'),
  ('generate_inferred_history',  'as provenance',                   'as provenance',        'no-op probe, kept to show a substitution that changes nothing is caught by nothing'),
  ('close_node_when_empty',      'new.quantity <= 0',               'new.quantity < 0',     'a lot at exactly zero never closes'),
  ('bind_vessel_code',           'existing.vessel_id = p_vessel_id','true',                 'the cross-vessel guard goes, so a rebind returns silently'),
  ('cellar_writable_columns',    'if not (changed = any(tg_argv))', 'if false',             'the column allow-list stops refusing anything'),
  ('rack',                       'nullif(contributed, 0)',          'nullif(total_in, 0)',  'lineage shares divided by arrival rather than contribution, the wire session bug'),
  ('update_vessel',              'is distinct from',                'is not distinct from', 'a thermal change records only when nothing changed'),
  ('resolve_subject_name',       'is null then',                    'is not null then',     'the deflation inverts, so a present module resolves to null and an absent one is queried'),
  ('confirm_event',              'is_admin()',                      'true',                 'anyone may confirm, which is T0-4'),
  ('topping_check',              'and false',                       'and false',            'no-op probe')
)
select 'logic' || chr(9) || m.fn || ': ' || m.note || chr(9) || 'b64:' ||
       translate(encode(convert_to(replace(pg_get_functiondef(p.oid), m.find, m.repl), 'UTF8'), 'base64'), chr(10), '')
  from m
  join pg_proc p on p.proname = m.fn
  join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
 where position(m.find in pg_get_functiondef(p.oid)) > 0
   and m.find <> m.repl
 order by m.fn;" >> "$muts"

[ -n "$ONLY" ] && { grep "^$ONLY	" "$muts" > "$muts.f"; mv "$muts.f" "$muts"; }

total=$(grep -c . "$muts")
echo "$total mutations enumerated"
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
survivors=$(mktemp); inapplicable=$(mktemp); degenerate=$(mktemp)
trap 'rm -f "$muts" "$survivors" "$inapplicable" "$degenerate"' EXIT

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

declare -A seen caught
i=0
while IFS=$'\t' read -r class label sql; do
  [ -z "$class" ] && continue
  i=$((i + 1))
  adm "drop database if exists $WORK;"
  adm "create database $WORK template $BASE;"

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
  if docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 -d "$WORK" \
       < tests/schema_assertions.sql >/dev/null 2>&1; then
    printf '%s\t%s\n' "$class" "$label" >> "$survivors"
    printf '  %3d/%d  %-8s %-46s SURVIVED\n' "$i" "$total" "$class" "$label"
  else
    caught[$class]=$(( ${caught[$class]:-0} + 1 ))
    printf '  %3d/%d  %-8s %-46s caught\n' "$i" "$total" "$class" "$label"
  fi
done < "$muts"

adm "drop database if exists $WORK;"

# ---------------------------------------------------------------------------
echo
echo "| Class | Scored | Caught | Score |"
echo "|---|---|---|---|"
ts=0; tc=0
for class in check loosen unique trigger policy weaken rls logic; do
  s=${seen[$class]:-0}; c=${caught[$class]:-0}
  [ "$s" -eq 0 ] && continue
  ts=$((ts + s)); tc=$((tc + c))
  printf '| %s | %d | %d | %d%% |\n' "$class" "$s" "$c" "$(( c * 100 / s ))"
done
[ "$ts" -gt 0 ] && printf '| **Total** | **%d** | **%d** | **%d%%** |\n' "$ts" "$tc" "$(( tc * 100 / ts ))"

n_surv=$(grep -c . "$survivors" 2>/dev/null); n_surv=${n_surv:-0}
n_inap=$(grep -c . "$inapplicable" 2>/dev/null); n_inap=${n_inap:-0}
n_degen=$(grep -c . "$degenerate" 2>/dev/null); n_degen=${n_degen:-0}

echo
if [ "$n_surv" -gt 0 ]; then
  echo "survivors, which are the defects this suite would not notice:"
  sort "$survivors" | awk -F'\t' '{printf "  %-8s %s\n", $1, $2}'
else
  echo "no survivors: every scored mutation was caught."
fi

if [ "$n_degen" -gt 0 ]; then
  echo
  echo "$n_degen mutation(s) applied and changed nothing, so they are excluded from both columns:"
  sort "$degenerate" | awk -F'\t' '{printf "  %-8s %s\n", $1, $2}'
fi

if [ "$n_inap" -gt 0 ]; then
  echo
  echo "$n_inap mutation(s) could not be applied at all, so they are excluded from both columns:"
  sort "$inapplicable" | awk -F'\t' '{printf "  %-8s %s\n", $1, $2}'
fi

# The score never appears on its own. A bare percentage from this tool is a
# load-bearing number, it has been wrong in both directions inside one session,
# and it should not be possible to quote one without what it excluded.
echo
excluded=$(( n_degen + n_inap ))
if [ "$ts" -eq 0 ]; then
  echo "NO SCORE: nothing was scored. $excluded mutation(s) were excluded."
  exit 2
fi
printf '%d of %d scored mutations caught (%d%%), from %d enumerated.\n' \
  "$tc" "$ts" "$(( tc * 100 / ts ))" "$total"
if [ "$excluded" -gt 0 ]; then
  printf 'NOT A BARE SCORE: %d excluded, %d degenerate and %d inapplicable, listed above.\n' \
    "$excluded" "$n_degen" "$n_inap"
else
  echo 'Nothing was excluded: every enumerated mutation was applied and changed something.'
fi
