#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Reads a QFX, QBO or OFX download from the bank and puts its
#           transactions in, once, however many times it is run."
# Depends on: [data/README.md,
#             supabase/migrations/0122_money_that_has_already_moved.sql,
#             supabase/migrations/0123_the_bank_can_name_its_own_transactions.sql,
#             supabase/migrations/0124_a_bank_import_is_not_a_proposal.sql]
# Depended on by: [docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
# **Why this format and not the spreadsheet.** the credit union's download offers
# Spreadsheet, PDF, Quicken and QuickBooks. The spreadsheet leaves `Transaction
# reference` empty on every row, so a line has no identity and an overlapping
# export has to be reconciled by counting rows that look alike, which is a
# procedure that can be got quietly wrong. Quicken and QuickBooks are OFX
# underneath and carry `FITID`, which the standard requires to be unique within
# an account. 0123 puts a unique index on it, so running this twice lands each
# transaction once because the database will not do otherwise.
#
# Measured against the same account's spreadsheet export, the QFX is better on
# every axis:
#   - every transaction carries a FITID, and they are distinct
#   - NAME is a normalised merchant name, where the CSV glues the card type and a
#     reference number onto the end and makes every row unrepeatable
#   - MEMO carries the full detail: location, card last four, the merchant
#     category code, and the real transaction date as distinct from the posting
#     date, which the CSV does not have at all
#   - checks arrive as NAME "Check #<number>", so nothing is lost by dropping the
#     CSV
#
# The one thing the spreadsheet has that this does not is the bank's own
# `Category` guess. That is no loss: it was only ever evidence, and what this
# winery calls a transaction is an attestation by a person.
#
# No dependency: standard library only, and psql through the container, which is
# how every other script here talks to the database.

import argparse
import hashlib
import io
import os
import re
import subprocess
import sys
from xml.etree import ElementTree as ET

CONTAINER = os.environ.get("VSV_DB_CONTAINER", "supabase_db_vsv-management-software")


def q(v):
    """A SQL literal, or null."""
    if v is None or v == "":
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


def parse(path):
    raw = io.open(path, encoding="utf-8", errors="replace").read()
    if "<OFX>" not in raw:
        sys.exit("that file has no <OFX> in it, so it is not a QFX, QBO or OFX download")
    # OFX 2.x is XML with a processing instruction in front of it. OFX 1.x is
    # SGML and would need more than this; the bank emits 2.2, so this refuses
    # rather than half-parsing something it does not understand.
    body = raw[raw.index("<OFX>"):]
    try:
        root = ET.fromstring(body)
    except ET.ParseError as e:
        sys.exit(
            "this reads OFX 2.x, which is XML. That file did not parse: %s.\n"
            "If the bank sent OFX 1.x (SGML, no closing tags) it needs a different reader." % e
        )

    acct = root.find(".//BANKACCTFROM")
    if acct is None:
        sys.exit("no BANKACCTFROM in that file, so there is no account to attach anything to")

    out = {
        "org": root.findtext(".//FI/ORG"),
        "acctid": acct.findtext("ACCTID"),
        "bankid": acct.findtext("BANKID"),
        "accttype": acct.findtext("ACCTTYPE"),
        "start": (root.findtext(".//DTSTART") or "")[:8],
        "end": (root.findtext(".//DTEND") or "")[:8],
        "tx": [],
    }

    for t in root.findall(".//STMTTRN"):
        fitid = (t.findtext("FITID") or "").strip()
        amt = (t.findtext("TRNAMT") or "").strip()
        posted = (t.findtext("DTPOSTED") or "")[:8]
        if not fitid or not amt or len(posted) != 8:
            # Refuse rather than guess. A transaction with no identity is the one
            # thing this importer cannot be asked to handle safely.
            sys.exit("a transaction is missing FITID, TRNAMT or DTPOSTED; nothing was imported")
        name = (t.findtext("NAME") or "").strip()
        memo = (t.findtext("MEMO") or "").strip()
        value = float(amt)
        check = t.findtext("CHECKNUM")
        if not check:
            # Checks come through as NAME "Check #969" rather than in CHECKNUM.
            m = re.match(r"Check\s*#?\s*(\d+)", name, re.I)
            if m:
                check = m.group(1)
        out["tx"].append({
            "fitid": fitid,
            "at": "%s-%s-%s" % (posted[:4], posted[4:6], posted[6:8]),
            "amount": abs(value),
            "direction": "Debit" if value < 0 else "Credit",
            "name": name,
            "memo": memo,
            "trntype": t.findtext("TRNTYPE"),
            "check": check,
        })
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--account", help="what to call the account, if it is new")
    ap.add_argument("--db", default="postgres")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    data = parse(args.path)
    digest = hashlib.sha256(io.open(args.path, "rb").read()).hexdigest()
    name = args.account or ("%s %s" % (data["org"] or "Bank", data["accttype"] or "account"))

    print("%s %s, account %s, %s to %s, %d transactions"
          % (data["org"], data["accttype"], data["acctid"], data["start"], data["end"], len(data["tx"])))

    lines = []
    lines.append("begin;")
    lines.append(
        "insert into ledger_account (name, institution, external_ref) "
        "select %s, %s, %s where not exists "
        "(select 1 from ledger_account where external_ref = %s);"
        % (q(name), q(data["org"]), q(data["acctid"]), q(data["acctid"])))
    lines.append(
        "insert into bank_import (institution, filename, checksum, row_count, format) "
        "values (%s, %s, %s, %d, 'qfx');"
        % (q(data["org"] or "bank"), q(os.path.basename(args.path)), q(digest), len(data["tx"])))

    # Every row in one statement, so a file either lands or does not.
    vals = []
    for i, t in enumerate(data["tx"], start=1):
        vals.append(
            "(%d, %s, %s, %s, %s, %s, %s, %s, %s)"
            % (i, q(t["fitid"]), q(t["at"]), t["amount"], q(t["direction"]),
               q(t["name"] or t["memo"][:60] or "(no description)"),
               q(t["trntype"]), q(t["check"]), q(t["memo"])))

    lines.append("""
insert into bank_line
  (batch_id, row_no, account_id, external_id, at, amount, direction,
   description, txn_type, check_number, raw)
select
  (select id from bank_import order by at desc limit 1),
  v.row_no,
  (select id from ledger_account where external_ref = %s),
  v.fitid, v.at::date, v.amount, v.direction, v.description, v.trntype,
  v.checknum, jsonb_build_object('memo', v.memo)
from (values
%s
) as v(row_no, fitid, at, amount, direction, description, trntype, checknum, memo)
-- The bank promises FITID is unique within the account, and 0123 holds it to
-- that. Running this twice lands each transaction once, and the second run
-- reports how many it already had rather than silently doing nothing.
on conflict (account_id, external_id)
  where account_id is not null and external_id is not null
  do nothing;""" % (q(data["acctid"]), ",\n".join(vals)))

    lines.append("""
do $$
declare
  had int; got int;
begin
  select row_count into had from bank_import order by at desc limit 1;
  select count(*) into got from bank_line
   where batch_id = (select id from bank_import order by at desc limit 1);
  raise notice 'file held %, of which % were new and % were already here', had, got, had - got;
end $$;""")
    lines.append("commit;")

    sql = "\n".join(lines)
    if args.dry_run:
        print(sql[:1500])
        print("... %d bytes of SQL, not applied" % len(sql))
        return

    p = subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "psql", "-U", "postgres", "-d", args.db,
         "-v", "ON_ERROR_STOP=1", "-q"],
        # Bytes, explicitly UTF-8. With text=True Python encodes using the
        # platform codepage, and on Windows that turns an umlaut into a byte
        # psql rejects as invalid UTF-8. Grüner Veltliner found this.
        input=sql.encode("utf-8"), capture_output=True)
    sys.stdout.write(p.stdout.decode("utf-8", "replace"))
    sys.stderr.write(p.stderr.decode("utf-8", "replace"))
    sys.exit(p.returncode)


if __name__ == "__main__":
    main()
