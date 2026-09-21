#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Every row a migration puts into the database, so that anything
#           describing this winery rather than any winery has to be judged."
# Depends on: [CLAUDE.md,
#             docs/architecture-rulings.md]
# Depended on by: [data/README.md,
#                 scripts/verify.sh]
# ---------------------------------------------------------------------------
#
# **The rule this enforces.** The repository says what can exist. It does not say
# what does exist. A migration may create a table, a vocabulary, a capability or
# a screen; it may not carry this winery's vineyard, its machines, its suppliers
# or its books.
#
# The operative question for a row, and it is answerable in one reading: **would
# another winery installing this system have this row?** A grape variety, yes. A
# part domain like `mechanical`, yes. A line of IRS Schedule F, yes, because it
# is a public tax form and the same for every farm. The name of a block, no. A
# category named after the person it pays, no. A bank transaction, obviously no.
#
# The examples stay abstract on purpose. A check that listed the private names it
# was looking for would publish them in the course of protecting them, which is
# why this is structural: it counts rows into tables that hold instances, and a
# person judges each site once.
#
# CLAUDE.md says this vintage is the worked case and the system is "meant to be
# handed to other winemakers after that harvest proves it". A repository that
# contains one winery's vine map and one winery's bank cannot be handed to
# anybody, and S-77 cannot be discharged while it is true. So this is not
# housekeeping; it is the stated purpose of the project made checkable.
#
# **Structure ships; instances do not.** The tables below are structure: they
# describe the system rather than the winery, and a row in them is as much a
# part of the software as a function is.

import io
import os
import re
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# Tables whose rows describe the system, not the winery. A screen, a module, a
# capability, a readable, a subject resolver and a kind of term are all
# statements about what the software is.
STRUCTURAL = {
    "term_kind", "screen", "module", "capability", "readable",
    "subject_resolver", "ruling", "axiom", "schema_migrations",
    # The contract's own bookkeeping: which capabilities are exempt from
    # which rule. A statement about the software.
    "capability_exemption",
}

# Tables that hold the winery's own records. A row here in a migration is the
# thing this check exists to find.
INSTANCE_HINTS = {
    "bank_line", "ledger_account", "line_attestation", "bank_import",
    "vineyard", "block", "planting", "vine_row", "plant_space", "plant_change",
    "machine", "machine_model", "model_part", "machine_document", "machine_work",
    "vessel", "node", "location", "party", "app_user", "supply", "note",
}

INSERT = re.compile(r"insert\s+into\s+([a-z_][a-z0-9_]*)", re.I)
# A row in a VALUES list: a line that starts with an open paren at the top level.
ROW = re.compile(r"^\s*\(", re.M)


def tracked():
    out = subprocess.run(["git", "ls-files", "supabase/migrations"],
                         cwd=ROOT, capture_output=True, text=True).stdout
    return [l for l in out.strip().split("\n") if l.endswith(".sql")]


def statements(sql):
    """Crude split on semicolons outside dollar quotes and single quotes."""
    out, buf, i, n = [], [], 0, len(sql)
    dollar = None
    while i < n:
        c = sql[i]
        if dollar:
            if sql.startswith(dollar, i):
                buf.append(dollar); i += len(dollar); dollar = None; continue
            buf.append(c); i += 1; continue
        m = re.match(r"\$[A-Za-z_]*\$", sql[i:])
        if m:
            dollar = m.group(0); buf.append(dollar); i += len(dollar); continue
        if c == "'":
            j = i + 1
            while j < n:
                if sql[j] == "'" and (j + 1 >= n or sql[j + 1] != "'"):
                    break
                if sql[j] == "'":
                    j += 2; continue
                j += 1
            buf.append(sql[i:j + 1]); i = j + 1; continue
        if c == ";":
            out.append("".join(buf)); buf = []; i += 1; continue
        buf.append(c); i += 1
    if buf:
        out.append("".join(buf))
    return out


def scan():
    found = []
    for path in tracked():
        sql = io.open(os.path.join(ROOT, path), encoding="utf-8").read()
        # Comments carry prose, not rows, and the prose check is a different one.
        bare = re.sub(r"^\s*--.*$", "", sql, flags=re.M)
        for st in statements(bare):
            # An insert inside a dollar-quoted block is program text: a function
            # body, or a DO block generating fixtures or backfilling. It is not
            # seed data carried in the file, and counting it made every
            # migration that writes a row at runtime look like a data dump.
            outer = re.sub(r"\$\$.*?\$\$", " ", st, flags=re.S)
            outer = re.sub(r"\$[A-Za-z_]+\$.*?\$[A-Za-z_]+\$", " ", outer, flags=re.S)
            m = INSERT.search(outer)
            if not m:
                continue
            st = outer
            table = m.group(1).lower()
            if table in STRUCTURAL:
                continue
            body = st[m.end():]
            rows = len(ROW.findall(body))
            if "select" in body.lower() and rows == 0:
                # insert ... select, which copies rows that already exist rather
                # than carrying new ones in the file.
                rows = 0
            if rows == 0:
                continue
            found.append((os.path.basename(path), table, rows))
    return found


def main():
    dispo_path = os.path.join(ROOT, "docs/review/data-dispositions.tsv")
    dispo = {}
    if os.path.exists(dispo_path):
        for line in io.open(dispo_path, encoding="utf-8"):
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 3:
                dispo[(parts[0], parts[1])] = (parts[2], parts[3] if len(parts) > 3 else "")

    found = scan()
    if "--list" in sys.argv:
        for f, t, n in sorted(found, key=lambda x: (-x[2], x[0])):
            key = (f, t)
            said = dispo.get(key, ("UNJUDGED", ""))[0]
            print("%-10s %-52s %-18s %5d" % (said, f, t, n))
        print("\n%d insert sites, %d rows" % (len(found), sum(n for _, _, n in found)))
        return 0

    unjudged = [(f, t, n) for f, t, n in found if (f, t) not in dispo]
    local = [(f, t, n) for f, t, n in found
             if dispo.get((f, t), ("", ""))[0] == "local"]

    fails = 0
    if unjudged:
        print("FAIL  %d insert sites put rows in the winery's own tables and are not judged" % len(unjudged))
        for f, t, n in sorted(unjudged, key=lambda x: -x[2])[:8]:
            print("        %-52s %-18s %5d rows" % (f, t, n))
        print("      Judge each in docs/review/data-dispositions.tsv as `universal`")
        print("      (any winery would have this row) or `local` (this winery's own,")
        print("      and it belongs in a seed outside the repository).")
        fails = 1
    if local:
        print("FAIL  %d insert sites are judged `local` and are still in the repository" % len(local))
        for f, t, n in sorted(local, key=lambda x: -x[2])[:8]:
            print("        %-52s %-18s %5d rows" % (f, t, n))
        fails = 1
    if not fails:
        print("ok    %d insert sites into the winery's tables, every one judged universal, %d rows"
              % (len(found), sum(n for _, _, n in found)))
    return fails


if __name__ == "__main__":
    sys.exit(main())
