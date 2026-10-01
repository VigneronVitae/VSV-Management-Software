---
Type: document
Purpose: "Says what this directory holds and why none of it is committed."
Depends on: [scripts/data-surface.py]
Depended on by: [scripts/import-machine.py, scripts/import-qfx.py, scripts/import-vinemap.py, scripts/seed-terms.py,
                 scripts/import-ledger.py, scripts/import-claims.py]
---

# Not in git

This directory holds one winery's own records: its vineyard, its machines, its
books. Nothing here is committed, and `scripts/data-surface.py` fails the gate if
any of it turns up in a migration instead.

The repository says what can exist. This directory says what does.

Put the real files here and load them with the importers in `scripts/`:

    scripts/import-vinemap.py   data/vineyard/vine-map.tsv
    scripts/import-claims.py    data/vineyard/claims.json
    scripts/import-machine.py   data/machines/<machine>/
    scripts/import-qfx.py       data/books/<download>.qfx

A fresh clone has an empty `data/` and a database with structure and no
instances, which is what somebody else installing this system should get.
