#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Loads one machine: what it is, what it is made of, and the papers
#           written about it."
# Depends on: [data/README.md,
#             supabase/migrations/0105_a_machine_is_a_departure_from_its_model.sql,
#             supabase/migrations/0112_a_machine_decomposes_into_parts.sql,
#             supabase/migrations/0119_a_machine_keeps_its_papers.sql]
# Depended on by: [docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
# This used to be migration 0120. It is a script because a machine belongs to a
# winery: see `scripts/data-surface.py` for the rule.
#
# **Everything lands as `inferred`, and that is T0-4 rather than modesty.** A
# parts tree produced by a research model is a claim, however confident the prose
# is. Provenance belongs to whoever checked, and nobody has checked until they
# have stood in front of the machine with a spanner. The reports are kept whole
# beside the parts, because the extraction can be wrong in ways only the original
# shows.
#
# A directory holds:
#   machine.tsv     key and value: make, model, kind, name, serial, notes
#   documents.tsv   kind, title, source, url, file, about
#   parts.sql       one VALUES row per part, in the order a tree is built

import argparse
import io
import os
import re
import subprocess
import sys

CONTAINER = os.environ.get("VSV_DB_CONTAINER", "supabase_db_vsv-management-software")


def q(v):
    if v is None or v == "":
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


def pairs(path):
    out = {}
    multi = {}
    for line in io.open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        parts = line.rstrip("\n").split("\t")
        k = parts[0]
        v = parts[1] if len(parts) > 1 else ""
        if k in out:
            multi.setdefault(k, [out[k]]).append(v)
        out[k] = v
    for k, vs in multi.items():
        out[k] = vs
    return out


def rows(path):
    out = []
    for line in io.open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        out.append(line.rstrip("\n").split("\t"))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--db", default="postgres")
    args = ap.parse_args()

    meta = pairs(os.path.join(args.dir, "machine.tsv"))
    docs = rows(os.path.join(args.dir, "documents.tsv")) if os.path.exists(
        os.path.join(args.dir, "documents.tsv")) else []
    parts_sql = io.open(os.path.join(args.dir, "parts.sql"), encoding="utf-8").read()
    parts_sql = re.sub(r"^\s*--.*$", "", parts_sql, flags=re.M).strip().rstrip(";")
    n_parts = len(re.findall(r"^\s*\(", parts_sql, re.M))

    unread = meta.get("unread", [])
    if isinstance(unread, str):
        unread = [unread] if unread else []

    print("%s %s: %d parts, %d documents"
          % (meta.get("make", "?"), meta.get("model", "?"), n_parts, len(docs)))

    sql = ["begin;"]
    sql.append(
        "insert into machine_model (make, model, kind_id, note) select %s, %s, "
        "(select id from term where kind = 'machine_kind' and value = %s), %s "
        "where not exists (select 1 from machine_model where make = %s and model = %s);"
        % (q(meta["make"]), q(meta["model"]), q(meta.get("kind")), q(meta.get("model_note")),
           q(meta["make"]), q(meta["model"])))

    attrs = "jsonb_build_object('note', %s, 'presenting_problem', %s, 'plates_unread', %s::jsonb)" % (
        q(meta.get("note")), q(meta.get("problem")),
        q("[" + ",".join('"%s"' % u.replace('"', '\\"') for u in unread) + "]"))
    sql.append(
        "insert into machine (model_id, name, serial, acquired_at, attributes) "
        "select mm.id, %s, %s, %s, %s from machine_model mm "
        "where mm.make = %s and mm.model = %s "
        "and not exists (select 1 from machine m where m.model_id = mm.id and m.name = %s);"
        % (q(meta.get("name")), q(meta.get("serial")),
           ("date " + q(meta["acquired"])) if meta.get("acquired") else "null",
           attrs, q(meta["make"]), q(meta["model"]), q(meta.get("name"))))

    for kind, title, source, url, fname, about in [(r + [""] * 6)[:6] for r in docs]:
        body = io.open(os.path.join(args.dir, fname), encoding="utf-8").read() if fname else ""
        sql.append(
            "insert into machine_document (model_id, kind_id, title, source, url, body, provenance) "
            "select mm.id, (select id from term where kind = 'document_kind' and value = %s), "
            "%s, %s, %s, %s, 'inferred' from machine_model mm "
            "where mm.make = %s and mm.model = %s and not exists "
            "(select 1 from machine_document d where d.model_id = mm.id and d.title = %s and d.source = %s);"
            % (q(kind), q(title), q(source), q(url), q(body),
               q(meta["make"]), q(meta["model"]), q(title), q(source)))

    sql.append(
        "create temporary table _part (key text, parent_key text, name text, domain text, "
        "maker text, part_number text, quantity numeric, wear boolean, wear_life text, "
        "url text, note text, sort_order int) on commit drop;")
    sql.append("insert into _part values\n" + parts_sql + ";")

    sql.append("""
do $$
declare the_model uuid; the_doc uuid; depth int := 0; made int;
begin
  select id into the_model from machine_model where make = __MAKE__ and model = __MODEL__;
  select id into the_doc from machine_document
   where model_id = the_model order by at limit 1;

  loop
    insert into model_part
      (model_id, parent_id, name, domain_id, maker, part_number, quantity,
       wear, wear_life, url, note, document_id, provenance, sort_order, spec)
    select the_model, parent.id, w.name,
      (select t.id from term t where t.kind = 'part_domain' and t.value = w.domain),
      w.maker, w.part_number, w.quantity, w.wear, w.wear_life, w.url, w.note,
      the_doc, 'inferred', w.sort_order, jsonb_build_object('map_key', w.key)
    from _part w
    left join model_part parent
      on parent.model_id = the_model and parent.spec ->> 'map_key' = w.parent_key
    where not exists (select 1 from model_part mp
       where mp.model_id = the_model and mp.spec ->> 'map_key' = w.key)
      and (w.parent_key is null or parent.id is not null);
    get diagnostics made = row_count;
    depth := depth + 1;
    exit when made = 0 or depth > 10;
  end loop;

  if exists (select 1 from _part w where not exists (
    select 1 from model_part mp where mp.model_id = the_model
       and mp.spec ->> 'map_key' = w.key)) then
    raise exception 'FAIL: % parts did not land, so a parent key names nothing',
      (select count(*) from _part w where not exists (
        select 1 from model_part mp where mp.model_id = the_model
           and mp.spec ->> 'map_key' = w.key));
  end if;

  raise notice 'the machine decomposes into % parts',
    (select count(*) from model_part where model_id = the_model);
end $$;"""
        # Named placeholders, not %s: the body is plpgsql and its raise
        # messages carry % placeholders of their own.
        .replace("__MAKE__", q(meta["make"]))
        .replace("__MODEL__", q(meta["model"])))

    sql.append("commit;")
    body = "\n".join(sql)

    p = subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "psql", "-U", "postgres", "-d", args.db,
         "-v", "ON_ERROR_STOP=1", "-q"],
        input=body.encode("utf-8"), capture_output=True)
    sys.stdout.write(p.stdout.decode("utf-8", "replace"))
    sys.stderr.write(p.stderr.decode("utf-8", "replace"))
    return p.returncode


if __name__ == "__main__":
    sys.exit(main())
