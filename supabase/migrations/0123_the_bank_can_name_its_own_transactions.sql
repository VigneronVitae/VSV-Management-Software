-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A bank line can carry the bank's own identifier, and where it does,
--           importing the same transaction twice becomes impossible rather than
--           merely unlikely."
-- Depends on: [supabase/migrations/0122_money_that_has_already_moved.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  supabase/migrations/0124_a_bank_import_is_not_a_proposal.sql,
--                  scripts/import-qfx.py,
--                  supabase/migrations/0130_the_bank_says_more_than_a_name.sql]
-- Axioms enforced: A13. Counting lookalike rows to decide what is new is a
--                  procedure, and a procedure can be got wrong quietly. A
--                  unique index cannot.
-- Open sorries: none new. Narrows S-100.
-- ---------------------------------------------------------------------------

-- 0122 was written against the spreadsheet export, where `Transaction
-- reference` is empty on every row, and it concluded that a line's identity has
-- to come from which row of which file it arrived in. That conclusion was right
-- about the spreadsheet and wrong about the bank.
--
-- **the credit union's download offers Spreadsheet, PDF, Quicken and QuickBooks.** The last
-- two are OFX underneath: Quicken takes QFX, QuickBooks takes QBO, and both
-- formats carry `FITID`, the Financial Institution Transaction ID, which the
-- standard requires to be unique within an account. That is precisely the field
-- the spreadsheet drops.
--
-- So where the import is OFX, the double-counting problem stops being something
-- the importer has to be careful about and becomes something the database will
-- not allow. The multiplicity matching stays for the spreadsheet path, because
-- that is the only path for a check register, an old file, or a second
-- institution that offers nothing better.

alter table bank_line add column if not exists external_id text;

comment on column bank_line.external_id is
  'The bank''s own identifier for the transaction: FITID from an OFX, QFX or QBO '
  'download. Null for a spreadsheet import, which carries none.';

-- Partial, because only the OFX path has one, and a null identifier must not
-- collide with another null identifier. Within one account, the bank promises
-- this is unique, so the same transaction can be imported any number of times
-- and land once.
create unique index if not exists bank_line_external_id_is_unique
  on bank_line (account_id, external_id)
  where account_id is not null and external_id is not null;

-- Which format a batch came from, so that a spreadsheet import is not mistaken
-- for an authoritative one and so the importer knows which rule to apply.
alter table import_batch add column if not exists format text;

comment on column import_batch.format is
  'csv, qfx, qbo or ofx. Decides whether lines carry the bank''s own identifier '
  'or have to be matched by counting.';
