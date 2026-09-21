#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Loads one winery's own additions to a vocabulary, which migrations
#           may not carry."
# Depends on: [data/README.md,
#             supabase/migrations/0027_term_kind_registry.sql]
# Depended on by: [docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
# A migration ships the kinds of vocabulary that exist and the members every
# installation would have: grape varieties, part domains, the lines of a public
# tax form. It may not ship the members one winery adds, because those describe
# how that operation is run, and sometimes who it pays.
#
# So those live in a TSV under `data/`, which is not committed, and this loads
# them. `scripts/data-surface.py` is what stops them drifting back into a
# migration.
#
#     scripts/seed-terms.py money_class data/books/money-classes.tsv
#
# Columns: value, label, sort order, and anything after that is folded into the
# term's `attributes` as `side` if it is one of in/out/neither.

import argparse
import io
import os
import subprocess
import sys

CONTAINER = os.environ.get("VSV_DB_CONTAINER", "supabase_db_vsv-management-software")


def q(v):
    return "'" + str(v).replace("'", "''") + "'"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("kind")
    ap.add_argument("path")
    ap.add_argument("--db", default="postgres")
    args = ap.parse_args()

    rows = []
    for line in io.open(args.path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 2:
            sys.exit("a row needs at least a value and a label: %r" % line)
        value, label = parts[0], parts[1]
        order = parts[2] if len(parts) > 2 and parts[2].strip() else "500"
        side = parts[3] if len(parts) > 3 and parts[3].strip() else None
        attrs = '{"side":"%s"}' % side if side in ("in", "out", "neither") else "{}"
        rows.append((value, label, order, attrs))

    if not rows:
        sys.exit("nothing to load")

    sql = (
        "insert into term (kind, value, label, sort_order, attributes) values\n"
        + ",\n".join("  (%s, %s, %s, %s, %s::jsonb)"
                     % (q(args.kind), q(v), q(l), o, q(a)) for v, l, o, a in rows)
        + "\non conflict (kind, value) do update set\n"
          "  label = excluded.label, sort_order = excluded.sort_order,\n"
          "  attributes = excluded.attributes, active = true;\n"
    )

    p = subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "psql", "-U", "postgres", "-d", args.db,
         "-v", "ON_ERROR_STOP=1", "-q"],
        input=sql.encode("utf-8"), capture_output=True)
    sys.stdout.write(p.stdout.decode("utf-8", "replace"))
    sys.stderr.write(p.stderr.decode("utf-8", "replace"))
    if p.returncode == 0:
        print("%d terms loaded into %s" % (len(rows), args.kind))
    return p.returncode


if __name__ == "__main__":
    sys.exit(main())
