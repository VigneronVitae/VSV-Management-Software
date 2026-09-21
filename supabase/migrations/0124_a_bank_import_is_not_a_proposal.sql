-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Undoes a collision: 0122 created a table that already existed, and
--           0123 added a column to somebody else's."
-- Depends on: [supabase/migrations/0094_an_import_is_a_proposal.sql,
--              supabase/migrations/0122_money_that_has_already_moved.sql,
--              supabase/migrations/0123_the_bank_can_name_its_own_transactions.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  scripts/import-qfx.py]
-- Axioms enforced: none new. This removes a name meaning two things.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- **A mistake, and the shape of it is worth recording.** 0122 wrote
-- `create table if not exists import_batch (...)` without checking whether one
-- existed. One did: `0094` built a whole import framework around it, where an
-- import is a **proposal**, its steps name capabilities, and somebody reviews
-- them before they are applied. `if not exists` then did nothing, silently, and
-- 0122 appeared to succeed. 0123 went on to add a `format` column to 0094's
-- table, and the books importer failed on a column 0122 thought it had created.
--
-- `if not exists` is how a migration lies about what it did. It was right for
-- the other tables in 0122, which are new, and wrong here because the name was
-- taken.
--
-- **The two things are genuinely different and should not share a table.** An
-- import under 0094 is a proposal about facts somebody might be wrong about: a
-- barrel log read off a notebook, where a row may be misread and a human decides
-- whether to apply it. A bank download is not a proposal. The transactions
-- happened, the bank is authoritative about them, and there is nothing to
-- approve. What needs judgement is what each one was **for**, and that is
-- already a separate thing: an attestation, appended, by a named person.
--
-- So books gets its own table rather than overloading 0094's, and 0094's is put
-- back the way it was.

alter table bank_line drop constraint if exists bank_line_batch_id_fkey;
alter table import_batch drop column if exists format;

create table if not exists bank_import (
  id         uuid primary key default gen_random_uuid(),
  -- Which institution, and which file. The checksum so that the same file is
  -- recognisable on the way back in, and so a file edited between two imports
  -- is not mistaken for the one before it.
  institution text,
  filename   text not null,
  checksum   text,
  format     text not null,
  row_count  int,
  note       text,
  at         timestamptz not null default now(),
  by_user    uuid references app_user (id),

  constraint bank_import_says_what_it_read check (btrim(filename) <> ''),
  constraint bank_import_format_is_one_we_read
    check (format in ('qfx', 'qbo', 'ofx', 'csv'))
);

alter table bank_import enable row level security;

drop policy if exists bank_import_read on bank_import;
create policy bank_import_read on bank_import for select to authenticated
  using (is_admin());

drop policy if exists bank_import_write on bank_import;
create policy bank_import_write on bank_import to authenticated
  using (is_admin()) with check (is_admin());

comment on table bank_import is
  'One download from the bank. Not an import_batch: that is 0094''s proposal '
  'mechanism for facts somebody might have misread, and a bank statement is not '
  'a proposal.';

-- No rows have ever been in `bank_line`, so this repoints rather than migrates.
alter table bank_line
  add constraint bank_line_batch_id_fkey
  foreign key (batch_id) references bank_import (id) on delete cascade;

comment on column bank_line.batch_id is
  'Which download this line arrived in. With row_no it is the fallback identity '
  'for a spreadsheet import, which carries no FITID.';
