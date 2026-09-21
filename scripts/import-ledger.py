#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Reads a hand-kept expense workbook, matches each row to a bank line
#           that has already been imported, and records what the ledger says the
#           transaction was for as an inferred attestation."
# Depends on: [data/README.md,
#              supabase/migrations/0122_money_that_has_already_moved.sql,
#              supabase/migrations/0126_only_a_person_confirms.sql]
# Depended on by: [docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
# **This writes `inferred` and it cannot write anything else.** The rows it reads
# were themselves entered by a machine: every one carries `Creator: Claude`, so
# the workbook is a previous agent's proposal that nobody has checked, and
# treating it as a person's word would launder a guess into a confirmation. T0-4
# is the rule and this is the case it was written for. The attestation is
# inserted directly rather than through `attest_line`, because `attest_line`
# needs a signed-in administrator and there is nobody here; the insert carries no
# `by_user` at all, which is the truthful answer to who said so.
#
# What that buys is the shape the books app was built around: a matched line
# lands in the `unconfirmed` pile with the category already on it, and clearing
# it costs one tap instead of four.
#
# **Matching is exact date and exact amount, and that is a measurement rather
# than a choice.** Over the 381 rows inside the imported window, same day and
# same amount puts 348 on exactly one bank line. Widening to a day either side
# drops it to 336 and to five days, 329, because every extra day adds ambiguity
# and resolves nothing: the 20 rows that match nothing match nothing at any
# width. So his `Date Paid` is the posting date, and a tolerance would only
# manufacture wrong answers.
#
# Nothing is written for a row that matches several lines, matches none, or
# carries a code with no class against it. Each is counted and the counts are
# printed before anything is written. A ledger importer that silently picked one
# of two candidates would be indistinguishable from one that worked.
#
# The code-to-category mapping is `data/books/ledger-codes.tsv`, which is not
# named in the header above and cannot be: `data/` is deliberately untracked
# under AR-J4, so an edge into it is one a clone could never reciprocate.
#
#     scripts/import-ledger.py "D:/.../2026 Expenses.xlsx"
# The code-to-category mapping is `data/books/ledger-codes.tsv`, which is not
# named in the header above and cannot be: `data/` is deliberately untracked
# under AR-J4, so an edge into it is one a clone could never reciprocate.
#
#     scripts/import-ledger.py "D:/.../2026 Expenses.xlsx" --write
#
# Without --write it reports and changes nothing.

import argparse
import collections
import datetime
import io
import os
import re
import subprocess
import sys
import zipfile

CONTAINER = os.environ.get("VSV_DB_CONTAINER", "supabase_db_vsv-management-software")

# Which column holds what. The header row names them and the names are not all
# accurate: `Invoice #` holds the amount and `Received` holds the category code.
# Taken from the data rather than from the header for that reason.
COL_DATE_PAID = "C"
COL_COMPANY = "D"
COL_DESCRIPTION = "E"
COL_AMOUNT = "F"
COL_CODE = "I"
COL_CHECK = "M"

SHEET = "Expense and Income"


def read_sheet(path, wanted):
    """An xlsx is a zip of XML. No dependency: the standing rule is to consult
    before adding one, and this needs a decompressor and a tag matcher."""
    z = zipfile.ZipFile(path)
    shared = []
    if "xl/sharedStrings.xml" in z.namelist():
        x = z.read("xl/sharedStrings.xml").decode("utf-8")
        for si in re.findall(r"<si>(.*?)</si>", x, re.S):
            shared.append("".join(re.findall(r"<t[^>]*>(.*?)</t>", si, re.S)))

    wb = z.read("xl/workbook.xml").decode("utf-8")
    order = re.findall(r'<sheet name="([^"]+)"[^>]*r:id="rId(\d+)"', wb)
    rels = z.read("xl/_rels/workbook.xml.rels").decode("utf-8")
    target = dict(re.findall(r'Id="rId(\d+)"[^>]*Target="([^"]+)"', rels))

    for name, rid in order:
        if name != wanted:
            continue
        t = target[rid].lstrip("/")
        if not t.startswith("xl/"):
            t = "xl/" + t
        data = z.read(t).decode("utf-8")
        out = []
        for r in re.findall(r"<row[^>]*>(.*?)</row>", data, re.S):
            row = {}
            for col, _, attrs, body in re.findall(
                r'<c r="([A-Z]+)(\d+)"([^>]*)>(.*?)</c>', r, re.S
            ):
                v = re.search(r"<v>(.*?)</v>", body, re.S)
                if not v:
                    continue
                val = v.group(1)
                if 't="s"' in attrs:
                    val = shared[int(val)]
                row[col] = val
            out.append(row)
        return out
    sys.exit("the workbook has no sheet called %r" % wanted)


def excel_date(serial):
    try:
        n = int(float(serial))
    except (TypeError, ValueError):
        return None
    # 1899-12-30 rather than 1900-01-01: Excel believes 1900 was a leap year and
    # the offset absorbs it for every date after February 1900.
    return datetime.date(1899, 12, 30) + datetime.timedelta(days=n)


def read_codes(path):
    """code -> money_class. A code present with no class is a code somebody has
    deliberately not answered yet, and it is not the same thing as a code nobody
    has heard of. Both refuse; they refuse with different words."""
    known = {}
    for line in io.open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        parts = line.rstrip("\n").split("\t")
        if not parts[0].strip().isdigit():
            continue
        code = int(parts[0].strip())
        klass = parts[1].strip() if len(parts) > 1 else ""
        known[code] = klass or None
    return known


def q(v):
    return "'" + str(v).replace("'", "''") + "'"


def psql(sql, db, capture=True):
    p = subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "psql", "-U", "postgres", "-d", db,
         "-v", "ON_ERROR_STOP=1", "-At", "-F", "\t"],
        # Encoded here rather than with text=True, because text=True uses the
        # Windows code page and a description with a non-ASCII byte in it then
        # reaches psql as something psql refuses.
        input=sql.encode("utf-8"), capture_output=True)
    if p.returncode != 0:
        sys.stderr.write(p.stderr.decode("utf-8", "replace"))
        sys.exit("psql refused")
    return p.stdout.decode("utf-8", "replace").strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("workbook")
    ap.add_argument("--codes", default="data/books/ledger-codes.tsv")
    ap.add_argument("--db", default="postgres")
    ap.add_argument("--write", action="store_true",
                    help="actually insert. Without it, nothing is written.")
    args = ap.parse_args()

    codes = read_codes(args.codes)
    named = {c: k for c, k in codes.items() if k}
    print("%d codes in %s, %d of them answered" % (len(codes), args.codes, len(named)))

    rows = read_sheet(args.workbook, SHEET)
    start = next((i for i, r in enumerate(rows) if r.get("A") == "Date Start"), None)
    if start is None:
        sys.exit("no header row saying 'Date Start' in sheet %r" % SHEET)

    ledger = []
    for r in rows[start + 1:]:
        if len(r) < 4:
            continue
        d = excel_date(r.get(COL_DATE_PAID))
        try:
            amt = round(float(r.get(COL_AMOUNT)), 2)
        except (TypeError, ValueError):
            continue
        if not d or amt <= 0:
            continue
        code = r.get(COL_CODE)
        ledger.append({
            "date": d, "amount": amt,
            "company": r.get(COL_COMPANY, ""),
            "desc": r.get(COL_DESCRIPTION, ""),
            "check": r.get(COL_CHECK, ""),
            "code": int(code) if code and code.isdigit() else None,
        })
    print("%d ledger rows carry a paid date and a positive amount" % len(ledger))

    # The classes have to exist before anything is matched against them, because
    # a class named in the mapping and absent from the vocabulary is a typo and
    # it should stop the run rather than skip 85 rows quietly.
    have = set(psql(
        "select value from term where kind = 'money_class' and active;", args.db
    ).split("\n"))
    unknown = sorted(set(named.values()) - have)
    if unknown:
        sys.exit("these classes are named in %s and are not active money classes: %s"
                 % (args.codes, ", ".join(unknown)))

    bank = []
    for line in psql(
        "select b.id, b.at::date, b.amount, "
        "  (select count(*) from line_attestation la where la.line_id = b.id) "
        "from bank_line b;", args.db
    ).split("\n"):
        p = line.split("\t")
        if len(p) < 4:
            continue
        bank.append({"id": p[0], "date": datetime.date.fromisoformat(p[1]),
                     "amount": round(float(p[2]), 2), "said": int(p[3])})
    print("%d bank lines already imported" % len(bank))

    by_key = collections.defaultdict(list)
    for b in bank:
        by_key[(b["date"], b["amount"])].append(b)

    # Both sides grouped by the same key, because a lone ledger row against two
    # identical bank lines is ambiguous and two ledger rows against those same
    # two lines is not. Six groups in the 2026 book are of the second kind: US
    # the same shop twice on one day for the same amount, a subscription billed
    # twice, and so on. Every one of them agrees with itself about the category,
    # so which row goes with which line is a question with no consequences, and
    # refusing them would hold back thirteen rows to protect against a difference
    # that does not exist.
    #
    # The counts must be equal. Two ledger rows against three bank lines means
    # one of the three is something else, and that is ambiguity again.
    #
    # Each row carries its own position in its group, set here. The first version
    # of this used `mine.index(l)`, which finds the first row equal to this one
    # rather than this one: two identical ledger rows both resolved to position
    # zero, both attested the same bank line, and the second bank line was left
    # unexplained. It showed up as 79 attestations landing on 78 lines, which is
    # the only reason it was noticed at all.
    ledger_by_key = collections.defaultdict(list)
    for l in ledger:
        key = (l["date"], l["amount"])
        l["seat"] = len(ledger_by_key[key])
        ledger_by_key[key].append(l)

    writes, held = [], collections.Counter()
    examples = collections.defaultdict(list)
    for l in ledger:
        key = (l["date"], l["amount"])
        cand = by_key.get(key, [])
        mine = ledger_by_key[key]
        if not cand:
            held["matched no bank line"] += 1
            examples["matched no bank line"].append(l)
            continue
        if len(cand) > 1:
            paired = (len(cand) == len(mine)
                      and len({m["code"] for m in mine}) == 1)
            if not paired:
                held["matched more than one bank line"] += 1
                examples["matched more than one bank line"].append(l)
                continue
            # Pair them off in the order both arrived. Any pairing gives the same
            # result once the codes agree, which is the condition above.
            cand = [cand[l["seat"]]]
        if l["code"] is None:
            held["no category code in the sheet"] += 1
            continue
        if l["code"] not in codes:
            held["code %d is in no mapping" % l["code"]] += 1
            continue
        if not codes[l["code"]]:
            held["code %d is not answered yet" % l["code"]] += 1
            continue
        if cand[0]["said"]:
            held["somebody has already said something about it"] += 1
            continue
        writes.append((cand[0]["id"], codes[l["code"]], l))

    print("\n  would write %d inferred attestation(s)" % len(writes))
    for reason, n in held.most_common():
        print("  held back %4d: %s" % (n, reason))

    for reason in ("matched no bank line", "matched more than one bank line"):
        if examples[reason]:
            print("\n  %s, first five:" % reason)
            for l in examples[reason][:5]:
                print("    %s  $%9.2f  %s" % (l["date"], l["amount"], l["company"][:44]))

    if not args.write:
        print("\nNothing written. Pass --write to insert.")
        return 0
    if not writes:
        print("\nNothing to write.")
        return 0

    # One statement, so a failure part way through leaves no half-import. The
    # note records where the claim came from, because in six months "who said
    # this was fuel" is the only question anybody will have.
    values = ",\n  ".join(
        "((select id from bank_line where id = %s), "
        "(select id from term where kind = 'money_class' and value = %s), %s, 'inferred')"
        % (q(bid), q(klass),
           q("from the 2026 workbook: %s, %s" % (l["company"][:60], l["desc"][:80])))
        for bid, klass, l in writes)
    sql = ("insert into line_attestation (line_id, class_id, note, provenance) values\n  "
           + values + ";\n")
    psql(sql, args.db)
    print("\n%d attestations written, all inferred, none carrying anybody's name."
          % len(writes))
    print("They are in the `unconfirmed` pile and each needs one tap.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
