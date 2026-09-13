#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Enumerates every refusal site in every function the kernel owns, so
#           that the coverage of the procedural layer is measured over the whole
#           population rather than over a sample somebody chose."
# Depends on: [tests/shim.sql]
# Depended on by: [scripts/mutate.sh, docs/session-reports/modularization-progress.md]
# ---------------------------------------------------------------------------
#
# W-6 measured the procedural surface three times, at 10 of 10, 6 of 9 and 5 of
# 16, ordered by how far each chooser stood from the code and ordered equally
# well by how hard each was looking for gaps. Nothing separates those
# explanations, so a gate written as a percentage over a sample invites the
# question of which sample, which is the question that produced two sessions.
#
# The answer is to stop sampling. This enumerates the population.
#
# A refusal site is any path that declines to do the thing the caller asked for.
# The loud form is `raise exception`. The quiet forms are where this class has
# hidden every previous time it was found: a guard that returns early and reports
# success, an `if not found` that does not raise, a `coalesce` supplying a
# permissive default, a conjunct on an update that simply stops narrowing.
#
# Output is one tab-separated row per site:
#
#   id      function:kind:n, stable under reformatting of other lines
#   fn      the function
#   kind    raise | guard | notfound | earlyreturn | permissive | silent | head
#   find    the exact text to substitute, with any newline written as backslash-n
#           so that one site is always one row
#   repl    the neutralised text, which is what a lost refusal looks like
#   occ     which occurrence of `find` inside the function definition, or 0 for a
#           site this instrument cannot substitute
#
# occ 0 is the honest column. A site that cannot be substituted is a hole in the
# instrument and not in the schema, and the one thing it must never do is vanish,
# because a site missing from the denominator and a site that does not exist
# produce the same percentage.
#
# The substitution is per site rather than per function on purpose: replacing
# `raise exception` across a function with three of them would remove three
# refusals in one mutation and score them as one.
#
# Three things the first pass got wrong, all of them silent:
#
#   Refusals expressed as a conjunct on an update. Nothing raises, no row is
#   matched, the caller is told it worked. That is ledger A14 and it is how six
#   kernel write paths did nothing for four days. Hence `silent`.
#
#   Carriage returns. 249 of 1459 source lines end in one, because some
#   migrations were written on Windows, and `btrim` with no argument does not
#   remove it. Every pattern anchored with a dollar therefore matched only lines
#   that came from a LF file, so the guard class was reading about half the
#   kernel and reporting a total for all of it.
#
#   Whole-line replacement. `if not found then return; end if;` is one line, and
#   swapping the line for `if false then` takes the `end if;` with it and yields
#   a function that will not compile. Three sites were reported as inapplicable
#   for that reason, which reads like a fact about the schema and was a fact
#   about this script. A guard is replaced up to its `then` and no further.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

CONTAINER="${VSV_DB_CONTAINER:-supabase_db_vsv-management-software}"
DB="${1:-postgres}"

if ! docker exec "$CONTAINER" true 2>/dev/null; then
  echo "cannot reach $CONTAINER" >&2; exit 2
fi

# The transport to scripts/mutate.sh addresses a function by name, so an overload
# would silently mutate whichever one the planner reached first. There are none
# today and this is here so that adding one is a loud event rather than a quiet
# halving of the population.
dupes=$(docker exec "$CONTAINER" psql -U postgres -At -d "$DB" -c "
select p.proname from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
 where p.prokind = 'f' group by p.proname having count(*) > 1;")
if [ -n "$dupes" ]; then
  echo "overloaded function names, which this enumeration cannot address:" >&2
  printf '%s\n' "$dupes" | sed 's/^/    /' >&2
  exit 2
fi

out=$(docker exec "$CONTAINER" psql -U postgres -At -d "$DB" -c "
with src as (
  select p.proname as fn, p.prosrc, pg_get_functiondef(p.oid) as def
    from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace and ns.nspname = 'public'
   where p.prokind = 'f'
),
body as (
  select s.fn, s.def, s.prosrc, l.n, l.line as raw,
         btrim(l.line, chr(13) || chr(10) || chr(9) || ' ') as line
    from src s
    cross join lateral unnest(string_to_array(s.prosrc, chr(10))) with ordinality as l(line, n)
),
-- Where this line begins inside the function definition. The substitution is
-- positional, so a line that appears three times yields three separately
-- scorable sites rather than one omitted one.
--
-- Counting occurrences of the text was the obvious way to do this and it is
-- wrong: a bare return is a substring of a conditional that ends in one, so the
-- count of matching lines and the count of matching substrings disagree, and six
-- sites had to be omitted. Reconstructing the offset is exact. The definition
-- carries a header the source does not, hence the strpos.
ranked as (
  select fn, def, n, line,
         strpos(def, prosrc) - 1
           + coalesce(sum(length(raw) + 1) over (partition by fn order by n
               rows between unbounded preceding and 1 preceding), 0)
           + position(line in raw) as at
    from body
),
-- The last executable line of each function. A trailing return is not a refusal,
-- it is how the function ends, and neutralising it to a no-op makes plpgsql raise
-- for reaching the end without a return. That mutation is caught by every fixture
-- that touches the function and would be scored as a refusal the suite noticed.
-- It noticed a broken function.
lastreal as (
  select fn, max(n) as last_n
    from body
   where line <> ''
     and line !~ '^--'
     and line !~* '^(begin|declare|else|end|end if|end loop|end case)[[:space:]]*;?$'
   group by fn
),
-- Which statement each line belongs to, so that a conjunct on an update can be
-- told from a predicate in a select. Postgres has no ignore nulls, so this
-- carries the line number of the most recent statement start and looks the
-- keyword up.
marked as (
  select r.*,
         max(case when r.line ~* '^(update|delete|insert|select)[[:space:]]' then r.n end)
           over (partition by r.fn order by r.n rows between unbounded preceding and current row)
           as stmt_at
    from ranked r
),
stmt as (
  select m.*,
         (select last_n from lastreal lr where lr.fn = m.fn) as last_n,
         (select lower(substring(b.line from '^[a-z]+'))
            from body b where b.fn = m.fn and b.n = m.stmt_at) as in_stmt,
         -- Where the conditional head that starts on this line finishes, for the
         -- heads that run past it. The first pass left these out because a
         -- per-line substitution cannot neutralise a condition spread over three
         -- lines. The obvious repair, prefixing the condition with false and, is
         -- wrong: where the condition is an or, and binds tighter, so half the
         -- guard survives. That is worse than leaving the site out, because it
         -- still scores. The substitution target spans lines instead, and the
         -- transport escapes the newline.
         (select r2.at + position('then' in r2.line) + 2
            from ranked r2
           where r2.fn = m.fn and r2.n >= m.n
             and r2.line ~* '[[:space:]]then([[:space:]]|;|$)|^then'
           order by r2.n limit 1) as head_end
    from marked m
),
sites as (
  select stmt.*,
         case
           -- The loud form. Neutralised to a notice rather than deleted, so the
           -- statement stays whole however many lines its arguments span and the
           -- control flow is otherwise untouched. A refusal that has become a log
           -- line is exactly the failure this class is about.
           when line ~* 'raise[[:space:]]+exception' then 'raise'
           -- A guard that tests for absence. The quiet half of the same shape,
           -- kept as its own label because it is diagnostically different even
           -- though it is neutralised the same way.
           when line ~* '^if[[:space:]]+not[[:space:]]+found[[:space:]]+then' then 'notfound'
           -- Any conditional whose head finishes on this line, whether or not its
           -- body does.
           when line ~* '^(if|elsif)[[:space:]]' and line ~* '[[:space:]]then([[:space:]]|;|$)'
             then 'guard'
           -- A conditional whose head does not finish on this line. Enumerated
           -- because it is a refusal site, not substituted because replacing one
           -- line of a head leaves the rest of the head dangling.
           when line ~* '^(if|elsif)[[:space:]]' then 'head'
           -- An early exit that reports success. Early is the whole of it: see
           -- lastreal above for why the closing return is not a site.
           when line ~* '^return([[:space:]]*;|[[:space:]]+null[[:space:]]*;|[[:space:]]+new[[:space:]]*;)'
                and n < last_n
             then 'earlyreturn'
           -- A default that permits. coalesce(x, true) is how is_facility_user
           -- resolved a missing party row to facility, which is ledger A1.
           when line ~* 'coalesce[[:space:]]*\(.*,[[:space:]]*(true|false)[[:space:]]*\)' then 'permissive'
           -- The quietest refusal there is, and the one the first pass missed. It
           -- is the extra conjunct that is the guard: a bare where on a primary
           -- key is the row selector, and neutralising that mutates which rows the
           -- statement touches rather than what it refuses, which is a different
           -- defect and a much easier one to notice.
           when in_stmt in ('update','delete')
                and (line ~* '^and[[:space:]]'
                     or (line ~* '^where[[:space:]]' and line ~* '[[:space:]]and[[:space:]]'))
             then 'silent'
           else null
         end as kind
    from stmt
),
subs as (
  select sites.*,
         case when kind in ('guard','notfound')
              then (regexp_match(line, '^((?:if|elsif)[[:space:]].*?[[:space:]]then)', 'i'))[1]
              when kind = 'head' and head_end is not null
              then substr(def, at::int, (head_end - at + 1)::int)
              else line
         end as find,
         case kind
           when 'raise'       then regexp_replace(line, 'raise[[:space:]]+exception', 'raise notice', 'i')
           when 'notfound'    then 'if false then'
           when 'guard'       then case when line ~* '^elsif' then 'elsif false then' else 'if false then' end
           when 'earlyreturn' then 'null;'
           when 'permissive'  then regexp_replace(line, '^(.*coalesce[[:space:]]*\(.*),[[:space:]]*false[[:space:]]*\)(.*)$', '\1, true)\2', 'i')
           when 'head'        then case when line ~* '^elsif' then 'elsif false then' else 'if false then' end
           when 'silent'      then
             (case when line ~* '^and[[:space:]]'
                   then regexp_replace(line, '^(and)[[:space:]].*$', '\1 true', 'i')
                   else regexp_replace(line, '^(where[[:space:]].*?)[[:space:]]and[[:space:]].*$', '\1 and true', 'i')
              end)
             -- The trailing semicolon is the statement terminator and .* eats it.
             || (case when line ~ ';[[:space:]]*$' then ';' else '' end)
         end as repl
    from sites where kind is not null
),
-- The reconstructed offset is checked against the definition before it is spent.
-- An offset that does not land on the text it claims is a site reported as
-- unsubstitutable rather than a site mutated at a position that means something
-- else, which would score a refusal that was never removed.
attributed as (
  select subs.*,
         case when find is null or repl is null or repl = find then 0
              -- The transport escapes a newline as backslash-n, so a backslash or
              -- a tab in the source would make the escaping ambiguous. Neither
              -- occurs in the kernel today and the day one does should not be the
              -- day a site is quietly mutated at the wrong offset.
              when find like '%' || chr(92) || '%' or find like '%' || chr(9) || '%' then 0
              when repl like '%' || chr(92) || '%' or repl like '%' || chr(9) || '%' then 0
              when substr(def, at::int, length(find)) <> find then 0
              else (length(substr(def, 1, (at + length(find) - 1)::int))
                    - length(replace(substr(def, 1, (at + length(find) - 1)::int), find, '')))
                   / nullif(length(find), 0)
         end as occ
    from subs
)
select fn || ':' || kind || ':' || row_number() over (partition by fn, kind order by n)
       || chr(9) || fn || chr(9) || kind
       || chr(9) || replace(coalesce(find, line), chr(10), '\n')
       || chr(9) || replace(coalesce(repl, ''), chr(10), '\n')
       || chr(9) || occ
  from attributed
 order by fn, n;" 2>/tmp/.guards.err)

if [ -n "$(cat /tmp/.guards.err 2>/dev/null)" ]; then
  echo "the enumeration query failed, refusing to report a total:" >&2
  sed 's/^/    /' /tmp/.guards.err >&2
  exit 2
fi

if [ -z "$out" ]; then
  echo "the enumeration returned nothing, which is a broken query and not a schema with no refusals" >&2
  exit 2
fi

# Everything goes to stdout, because the population is the point and a site this
# instrument cannot reach is still a site. What cannot be substituted is named on
# stderr as well, so that a caller which only reads the mutable rows is told what
# it did not get rather than left to infer it from a smaller number.
printf '%s\n' "$out"
printf '%s\n' "$out" | awk -F'\t' '
  $6 == 0 { held[++h] = $1 "\t" $4 }
  END {
    if (h > 0) {
      printf("# %d of %d enumerated site(s) could not be substituted:\n", h, NR) > "/dev/stderr"
      for (i = 1; i <= h; i++) printf("#   %s\n", held[i]) > "/dev/stderr"
    }
  }'
