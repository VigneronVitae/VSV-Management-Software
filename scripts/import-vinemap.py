#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Loads a vineyard's vine map: its rows, its plant spaces, and what
#           stands in each of them."
# Depends on: [data/README.md,
#             supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql,
#             supabase/migrations/0117_the_vine_map_is_loaded.sql]
# Depended on by: [docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
# This used to be migration 0117. It is a script because a vineyard belongs to a
# winery and not to the software: see `scripts/data-surface.py` for the rule and
# `data/README.md` for where the files go.
#
# **The reconciliation moved here with it, and that is the point.** A vine map is
# decoded from cell colours, and a decode is a guess until it is checked. The
# check is the winemaker's own legend: he wrote down how many of each variety are
# in each block, and the count that comes out of the decode has to match it. That
# ran inside the migration, and it caught a real failure once: a version that
# applied perfectly against a populated database and loaded nothing at all from
# an empty one. Without the assertion it would have reported success and created
# nothing.
#
# So this refuses rather than reports. If the counts do not reconcile, nothing is
# committed.
#
# Input, all under data/vineyard/ and none of it committed:
#   vine-map.tsv   block, row number, orientation, one character per plant space
#   vine-key.tsv   character, state, variety
#   legend.tsv     block, variety, clone, plants   (what the counts must come to)

import argparse
import io
import os
import subprocess
import sys

CONTAINER = os.environ.get("VSV_DB_CONTAINER", "supabase_db_vsv-management-software")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def q(v):
    if v is None or v == "":
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


def rows(path):
    out = []
    for line in io.open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        out.append(line.rstrip("\n").split("\t"))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.path.join(ROOT, "data/vineyard"))
    ap.add_argument("--vineyard", required=True, help="what the vineyard is called")
    ap.add_argument("--db", default="postgres")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    mapping = rows(os.path.join(args.dir, "vine-map.tsv"))
    key = rows(os.path.join(args.dir, "vine-key.tsv"))
    legend_path = os.path.join(args.dir, "legend.tsv")
    legend = rows(legend_path) if os.path.exists(legend_path) else []

    blocks = sorted({r[0] for r in mapping})
    print("%d rows across %d blocks, %d characters in the key, %d legend counts"
          % (len(mapping), len(blocks), len(key), len(legend)))
    if not legend:
        print("  no legend.tsv, so nothing will be reconciled. That is a worse import.")

    sql = ["begin;"]
    sql.append("insert into vineyard (name) select %s where not exists "
               "(select 1 from vineyard where name = %s);" % (q(args.vineyard), q(args.vineyard)))

    sql.append("create temporary table _map_block (map_name text primary key, block_id uuid) on commit drop;")
    sql.append("insert into _map_block (map_name, block_id) select x.map_name, "
               "(select b.id from block b join vineyard v on v.id = b.vineyard_id "
               " where v.name = %s and b.name = x.map_name) from (values %s) as x(map_name);"
               % (q(args.vineyard), ", ".join("(%s)" % q(b) for b in blocks)))
    sql.append("insert into block (vineyard_id, name) select v.id, mb.map_name from _map_block mb "
               "cross join vineyard v where mb.block_id is null and v.name = %s;" % q(args.vineyard))
    sql.append("update _map_block mb set block_id = b.id from block b join vineyard v on v.id = b.vineyard_id "
               "where v.name = %s and b.name = mb.map_name and mb.block_id is null;" % q(args.vineyard))

    sql.append("create temporary table _vine_map (block text, row_no int, orientation text, strip text) on commit drop;")
    sql.append("insert into _vine_map values\n" + ",\n".join(
        "  (%s, %s, %s, %s)" % (q(r[0]), r[1], q(r[2]), q(r[3])) for r in mapping) + ";")
    sql.append("create temporary table _vine_key (ch text primary key, state text, variety text) on commit drop;")
    sql.append("insert into _vine_key values\n" + ",\n".join(
        "  (%s, %s, %s)" % (q(r[0]), q(r[1]), q(r[2])) for r in key) + ";")

    sql.append("""
insert into vine_row (block_id, number, orientation)
select mb.block_id, m.row_no, m.orientation
  from _vine_map m join _map_block mb on mb.map_name = m.block
on conflict (block_id, number) do nothing;

insert into plant_space (row_id, number)
select vr.id, g.i
  from _vine_map m
  join _map_block mb on mb.map_name = m.block
  join vine_row vr on vr.block_id = mb.block_id and vr.number = m.row_no
  cross join lateral generate_series(1, length(m.strip)) as g(i)
 where substr(m.strip, g.i, 1) <> ' '
on conflict (row_id, number) do nothing;

insert into plant_change (space_id, at, state_id, variety_id, clone, provenance)
select ps.id, current_date, st.id, t.id,
       (select c.clone from _clone c
         where c.block = m.block and vr.number between c.row_from and c.row_to
           and k.variety = c.variety limit 1),
       'inferred'
  from _vine_map m
  join _map_block mb on mb.map_name = m.block
  join vine_row vr on vr.block_id = mb.block_id and vr.number = m.row_no
  cross join lateral generate_series(1, length(m.strip)) as g(i)
  join _vine_key k on k.ch = substr(m.strip, g.i, 1)
  join plant_space ps on ps.row_id = vr.id and ps.number = g.i
  join term st on st.kind = 'plant_state' and st.value = k.state
  left join term t on t.kind = 'variety' and t.value = k.variety
 where substr(m.strip, g.i, 1) <> ' '
   and not exists (select 1 from plant_change pc where pc.space_id = ps.id);""")

    # Clones are positional where a map paints two of them the same colour, so
    # they come from their own file rather than from the strip.
    clone_path = os.path.join(args.dir, "clones.tsv")
    clones = rows(clone_path) if os.path.exists(clone_path) else []
    sql.insert(-1, "create temporary table _clone (block text, row_from int, row_to int, variety text, clone text) on commit drop;")
    if clones:
        sql.insert(-1, "insert into _clone values\n" + ",\n".join(
            "  (%s, %s, %s, %s, %s)" % (q(c[0]), c[1], c[2], q(c[3]), q(c[4])) for c in clones) + ";")

    if legend:
        checks = []
        for i, (b, variety, clone, plants) in enumerate(legend):
            # Only the first branch of a UNION names its columns; the rest
            # inherit. Without names the loop variable has no fields to read.
            names = (" as block", " as variety", " as clone", "::int as plants") if i == 0 \
                else ("", "", "", "::int")

            # Always a string, never null. `q` turns an empty field into SQL
            # NULL, which is right for a column that may be absent and wrong
            # here: the legend compares against coalesce(...,''), and NULL = ''
            # is NULL, so every line with no clone matched nothing and the check
            # reported zero against a real count. It refused, correctly, on its
            # own bug.
            def qs(v):
                return "'" + str(v or "").replace("'", "''") + "'"

            checks.append("  select %s%s, %s%s, %s%s, %s%s" % (
                qs(b), names[0], qs(variety), names[1], qs(clone), names[2], plants, names[3]))
        # Built by concatenation, not by % formatting: the body is plpgsql and
        # its raise messages are full of % placeholders of their own.
        sql.append(
            "\ndo $$\n"
            "declare r record; have int;\n"
            "begin\n"
            "  for r in " + "\n    union all\n".join(checks).strip() + " loop\n"
            "    select count(*) into have\n"
            "      from plant_space_now n\n"
            "      join _map_block mb on mb.block_id = n.block_id and mb.map_name = r.block\n"
            "      left join term t on t.id = n.variety_id\n"
            "     where coalesce(t.label, '') = r.variety\n"
            "       and coalesce(n.clone, '') = r.clone\n"
            "       and n.state <> 'empty';\n"
            "    if have <> r.plants then\n"
            "      raise exception 'FAIL: % % % loaded % and the legend says %',\n"
            "        r.block, r.variety, r.clone, have, r.plants;\n"
            "    end if;\n"
            "  end loop;\n"
            "  raise notice 'the vine map reconciles to its legend on every line';\n"
            "end $$;")

    sql.append("commit;")
    body = "\n".join(sql)

    if args.dry_run:
        print(body[:1200])
        print("... %d bytes, not applied" % len(body))
        return 0

    p = subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "psql", "-U", "postgres", "-d", args.db,
         "-v", "ON_ERROR_STOP=1", "-q"],
        # Bytes, explicitly UTF-8. With text=True Python encodes using the
        # platform codepage, and on Windows that turns an umlaut into a byte
        # psql rejects as invalid UTF-8. Grüner Veltliner found this.
        input=body.encode("utf-8"), capture_output=True)
    sys.stdout.write(p.stdout.decode("utf-8", "replace"))
    sys.stderr.write(p.stderr.decode("utf-8", "replace"))
    return p.returncode


if __name__ == "__main__":
    sys.exit(main())
