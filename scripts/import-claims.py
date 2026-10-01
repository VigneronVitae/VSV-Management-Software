#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Loads what sources say about vineyards, each claim with its source
#           and the source's own words, as inferred and never as confirmed."
# Depends on: [data/README.md,
#             supabase/migrations/0164_a_claim_says_where_it_came_from.sql]
# Depended on by: [docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
# Input: data/vineyard/claims.json, not committed, shaped as
#
#   sources:  { key: {kind, title, url?, publisher?, published_on?, retrieved_at?, note?} }
#   claims:   [ {vineyard | block, kind, value, statement?, source, excerpt,
#                locator?, rows?: [from, to]} ]
#   vineyards_to_add: [ names ]   vineyards the claims are about that do not exist yet
#
# Every claim goes through `record_claim`, the same function an administrator's
# screen calls, so the rules are the kernel's: born inferred, a source and its
# words or nothing. A claim already loaded, the same subject, kind, value and
# excerpt from the same source, is skipped, so running this twice adds nothing.
# All of it is one transaction: a claim the kernel refuses refuses the file.

import argparse
import json
import os
import subprocess
import sys

CONTAINER = os.environ.get("VSV_DB_CONTAINER", "supabase_db_vsv-management-software")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def lit(v):
    if v is None:
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default=os.path.join(ROOT, "data", "vineyard", "claims.json"))
    ap.add_argument("--db", default="postgres")
    ap.add_argument("--container", default=CONTAINER)
    args = ap.parse_args()

    with open(args.file, encoding="utf-8") as f:
        data = json.load(f)
    sources = data["sources"]

    sql = ["\\set ON_ERROR_STOP on", "begin;"]
    for name in data.get("vineyards_to_add", []):
        sql.append(f"insert into vineyard (name) values ({lit(name)}) on conflict (name) do nothing;")

    for i, c in enumerate(data["claims"]):
        src = sources.get(c["source"])
        if src is None:
            sys.exit(f"claim {i}: no source called {c['source']}")
        if "vineyard" in c:
            subject_type = "vineyard"
            subject = f"(select id from vineyard where name = {lit(c['vineyard'])})"
            label = c["vineyard"]
        elif "block" in c:
            subject_type = "block"
            subject = f"(select id from block where name = {lit(c['block'])})"
            label = c["block"]
        else:
            sys.exit(f"claim {i}: say which vineyard or block it is about")
        rows = c.get("rows")
        rng = f"int4range({int(rows[0])}, {int(rows[1])}, '[]')" if rows else "null"
        sql.append(
            f"""do $c$ begin
  if {subject} is null then
    raise exception 'claim {i}: there is no {subject_type} called %', {lit(label)};
  end if;
  if not exists (
    select 1 from sourced_claim sc
     where sc.subject_type = {lit(subject_type)} and sc.subject_id = {subject}
       and sc.kind = {lit(c['kind'])} and sc.value = {lit(str(c['value']).strip())}
       and sc.excerpt = {lit(c['excerpt'].strip())}
       and coalesce(sc.source_url, sc.source_title) = coalesce({lit(src.get('url'))}, {lit(src['title'])})
  ) then
    perform record_claim({lit(subject_type)}, {subject}, {lit(c['kind'])}, {lit(c['value'])},
                         {lit(c.get('statement'))}, {lit(json.dumps(src, ensure_ascii=False))}::jsonb,
                         {lit(c['excerpt'])}, {lit(c.get('locator'))}, {rng});
  end if;
end $c$;"""
        )

    sql.append("select count(*) || ' claims, ' || count(distinct source_id) || ' sources, ' "
               "|| count(*) filter (where provenance = 'confirmed') || ' confirmed' from sourced_claim;")
    sql.append("commit;")

    # Through a UTF-8 byte string, not text mode: Windows' default codepage
    # turns an umlaut into a byte psql rejects as invalid UTF-8.
    p = subprocess.run(
        ["docker", "exec", "-i", args.container, "psql", "-U", "postgres", "-d", args.db, "-q", "-At"],
        input="\n".join(sql).encode("utf-8"),
        capture_output=True,
    )
    out = p.stdout.decode("utf-8", "replace").strip()
    err = p.stderr.decode("utf-8", "replace").strip()
    if p.returncode != 0 or "ERROR" in err:
        print(err or out, file=sys.stderr)
        sys.exit("nothing was loaded")
    print(out)


if __name__ == "__main__":
    main()
