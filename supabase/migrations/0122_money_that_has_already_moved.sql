-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Bank lines as the bank stated them, and everything anybody says
--           about them as separate, dated, attributed claims."
-- Depends on: [supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0109_a_module_says_where_it_lives.sql,
--              docs/architecture-rulings.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  supabase/migrations/0123_the_bank_can_name_its_own_transactions.sql,
--                  supabase/migrations/0124_a_bank_import_is_not_a_proposal.sql,
--                  supabase/migrations/0125_the_categories_are_schedule_f.sql,
--                  scripts/import-qfx.py,
--                  supabase/migrations/0126_only_a_person_confirms.sql,
--                  supabase/migrations/0127_the_books_have_a_door.sql,
--                  packages/books/src/books.ts,
--                  scripts/import-ledger.py,
--                  supabase/migrations/0130_the_bank_says_more_than_a_name.sql,
--                  docs/review/2026-09-20-one-kernel-many-peripheries.md]
-- Axioms enforced: T0-2, the signed amount and the merchant memory are both
--                  derivations and neither is stored. T0-4, a suggestion is
--                  `inferred` and only a person makes it `observed`. T0-5, an
--                  attestation is appended and never edits the one before it.
--                  AR-E5, what a transaction is for is a vocabulary he owns.
-- Open sorries: S-100, nothing imports a file yet.
-- ---------------------------------------------------------------------------

-- **AR-J3 says this system does not take money, and this does not take money.**
-- Every row here describes a transfer that already happened somewhere else:
-- the till took the card, the credit union moved the balance, somebody handed over a
-- check. Nothing in this module initiates a transfer, charges anybody, or is
-- ever seen by a customer. It reads exports from the two systems that do the
-- money, which is the integration AR-J3 itself named as unbuilt: "something
-- else will take the money, and the same case of wine exists on both sides of
-- that line". The ruling's enforcement clause says it bites the day a module
-- proposes a price field. This is that day, and the answer is that the line
-- holds: recording is not taking.
--
-- **The bank gives its transactions no identity.** In the spreadsheet export
-- the `Transaction reference` column is empty on every row. There is nothing to
-- key on.
--
-- **And identity cannot be recovered from the content, because duplicates are
-- real.** A real account contains transactions identical in date, amount and
-- merchant: the same shop, the same total, twice or three times in a day. That
-- is ordinary, and deduplicating on content would silently delete the repeats,
-- which is this project's standing failure mode arriving in the one place where
-- believing it costs money.
--
-- So a line's identity is **which row of which imported file it came from**, and
-- the overlap between two exports is settled by counting rather than by
-- matching: if a file reports three identical lines on a date and we already
-- hold three, they are the same three. A count that cannot be explained is a
-- question for a person. See S-100.
--
-- **Several people may attest to one line; no number of attestations may make
-- one transaction into two.** That is the winemaker's own formulation, and it is
-- the same shape as two research reports about one machine and as the bank's
-- category sitting beside the winery's. Keep every claim, attribute each, derive
-- the current answer, and let disagreement be visible rather than letting the
-- last writer win.
--
-- **Nothing operational belongs in this file.** The schema is type level: what
-- an account is, what a transaction is, what somebody may say about one. No
-- amount, merchant, balance or account number is recorded in this repository at
-- any point. Those live in the winery's own database and nowhere else.

-- ---------------------------------------------------------------------------
-- The module
-- ---------------------------------------------------------------------------

insert into module (key, label, note, sort_order) values
  ('books', 'Books',
   'Expenses and income, as the bank and the till already recorded them. This system never takes money; it reads what the systems that do have already done.',
   35)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- What a transaction was for
-- ---------------------------------------------------------------------------

insert into term_kind (kind, module, label, sort_order) values
  ('money_class', 'books', 'What a transaction was for', 85)
on conflict (kind) do nothing;

-- **No categories are seeded here.** What a transaction was for is a list
-- that belongs to whoever is keeping the books: one winery's includes the
-- people it pays by name. 0125 ships the part that is public, which is IRS
-- Schedule F, and anything a particular winery adds to that is loaded from
-- `data/books/money-classes.tsv` by `scripts/seed-terms.py` and is not
-- committed. The kind exists; its members are not the software's business.

-- ---------------------------------------------------------------------------
-- The accounts
-- ---------------------------------------------------------------------------

create table if not exists ledger_account (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  institution text,
  -- The bank's own number for the account. Worth knowing that a spreadsheet
  -- export opened in Excel can turn a long account number into a float and lose
  -- it, so an import should prefer a format that does not go through a
  -- spreadsheet at all.
  external_ref text,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),

  constraint ledger_account_says_what_it_is check (btrim(name) <> ''),
  unique (name)
);

alter table ledger_account enable row level security;

drop policy if exists ledger_account_read on ledger_account;
create policy ledger_account_read on ledger_account for select to authenticated
  using (is_admin());

drop policy if exists ledger_account_write on ledger_account;
create policy ledger_account_write on ledger_account to authenticated
  using (is_admin()) with check (is_admin());

-- **Administrator only, throughout this module.** Everywhere else in this system
-- a facility user may read, because what is in a tank is the cellar's business.
-- What is in the bank account is not, and a custom crush client, an intern and a
-- harvest hand have no reason to see it. This is the narrowest read policy in
-- the schema and it is deliberate.
comment on table ledger_account is
  'An account money moves through. Administrator only: the rest of this system '
  'is readable by the winery, and this part is not.';

-- ---------------------------------------------------------------------------
-- The imports
-- ---------------------------------------------------------------------------

create table if not exists import_batch (
  id          uuid primary key default gen_random_uuid(),
  source      text not null,
  filename    text not null,
  -- So the same file is recognisable when it comes back, and so a file that was
  -- edited between two imports is not mistaken for the one that came before.
  checksum    text,
  row_count   int,
  note        text,
  at          timestamptz not null default now(),
  by_user     uuid references app_user (id),

  constraint import_batch_says_where_it_came_from check (btrim(source) <> '')
);

alter table import_batch enable row level security;

drop policy if exists import_batch_read on import_batch;
create policy import_batch_read on import_batch for select to authenticated
  using (is_admin());

drop policy if exists import_batch_write on import_batch;
create policy import_batch_write on import_batch to authenticated
  using (is_admin()) with check (is_admin());

-- ---------------------------------------------------------------------------
-- The lines, exactly as the bank said them
-- ---------------------------------------------------------------------------

create table if not exists bank_line (
  id          uuid primary key default gen_random_uuid(),
  batch_id    uuid not null references import_batch (id) on delete cascade,
  -- Row of that file. With the batch, this is the line's whole identity, and it
  -- is the only identity available: see the header.
  row_no      int not null,
  account_id  uuid references ledger_account (id),

  -- The bank's own fields, unaltered.
  at          date not null,
  amount      numeric(14,2) not null,
  -- Unsigned in the export, with the sign carried in a separate column, so both
  -- are kept as given. The signed figure is a derivation and lives in a view:
  -- storing it as well would be the second answer T0-2 forbids, and his
  -- spreadsheet has been computing it by hand in a column called `Amount +-`.
  direction   text not null,
  description text not null,
  txn_type    text,
  txn_group   text,
  currency    text not null default 'USD',
  check_number text,
  -- What the bank guessed it was. Kept because it is evidence, and kept
  -- separate from what anybody here says, because it is the bank's claim and
  -- not the winery's. His spreadsheet keeps both columns too.
  bank_category text,
  -- Everything else the file carried, so a column nobody thought about is not
  -- lost on the way in.
  raw         jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),

  constraint bank_line_direction_is_a_direction
    check (direction in ('Debit', 'Credit')),
  constraint bank_line_amount_is_not_negative check (amount >= 0),
  constraint bank_line_says_what_it_was check (btrim(description) <> ''),
  unique (batch_id, row_no)
);

-- The matching index. Overlap between two exports is resolved by counting rows
-- with the same date, amount and description, so that is the lookup.
create index if not exists bank_line_match_idx
  on bank_line (account_id, at, amount, description);

alter table bank_line enable row level security;

drop policy if exists bank_line_read on bank_line;
create policy bank_line_read on bank_line for select to authenticated
  using (is_admin());

drop policy if exists bank_line_write on bank_line;
create policy bank_line_write on bank_line to authenticated
  using (is_admin()) with check (is_admin());

comment on table bank_line is
  'One transaction as the bank stated it. Never edited: a correction is a new '
  'import, and what anybody thinks it was for is an attestation, not a change.';

-- ---------------------------------------------------------------------------
-- What people say about them
-- ---------------------------------------------------------------------------

create table if not exists line_attestation (
  id          uuid primary key default gen_random_uuid(),
  line_id     uuid not null references bank_line (id) on delete cascade,
  class_id    uuid not null,
  class_kind  text generated always as ('money_class') stored,
  note        text,
  at          timestamptz not null default now(),
  by_user     uuid references app_user (id),
  -- T0-4. A suggestion from the merchant memory writes `inferred`. A person
  -- confirming writes `observed`. Nothing in this module may write `confirmed`
  -- on anybody's behalf, and the memory below is built only from what people
  -- have confirmed, so a guess can never teach itself.
  provenance  provenance not null default 'inferred',

  constraint line_attestation_class_is_a_money_class
    foreign key (class_id, class_kind) references term (id, kind)
);

create index if not exists line_attestation_by_line
  on line_attestation (line_id, at desc);

alter table line_attestation enable row level security;

drop policy if exists line_attestation_read on line_attestation;
create policy line_attestation_read on line_attestation for select to authenticated
  using (is_admin());

drop policy if exists line_attestation_write on line_attestation;
create policy line_attestation_write on line_attestation to authenticated
  using (is_admin()) with check (is_admin());

comment on table line_attestation is
  'Somebody saying what a transaction was for, on a date. Append only and many '
  'per line: several people may attest to one transaction, and no number of '
  'attestations may make one transaction into two.';

-- ---------------------------------------------------------------------------
-- What is true now, which is a function of what people have said
-- ---------------------------------------------------------------------------

create or replace view bank_line_now with (security_invoker = true) as
select
  b.id,
  b.batch_id,
  b.row_no,
  b.account_id,
  a.name  as account,
  b.at,
  b.amount,
  b.direction,
  -- The derivation his spreadsheet does by hand, done once here.
  case when b.direction = 'Debit' then -b.amount else b.amount end as signed_amount,
  b.description,
  b.txn_type,
  b.check_number,
  b.bank_category,
  -- The latest word. A person's word beats a suggestion whatever the order they
  -- arrived in, because a machine writing after a human must not overwrite them.
  latest.class,
  latest.class_label,
  latest.provenance,
  latest.by_user,
  latest.at as said_at,
  -- Confirmed by a person, which is the state a hand-kept ledger records in a
  -- column somebody ticks.
  coalesce(latest.provenance, 'inferred') = 'observed' as verified,
  (select count(*) from line_attestation la where la.line_id = b.id) as attestations,
  -- Two people who disagree. Not an error: a thing to look at.
  (select count(distinct la.class_id) from line_attestation la
    where la.line_id = b.id) > 1 as disputed
from bank_line b
left join ledger_account a on a.id = b.account_id
left join lateral (
  select t.value as class, t.label as class_label, la.provenance, la.by_user, la.at
    from line_attestation la
    join term t on t.id = la.class_id
   where la.line_id = b.id
   order by (la.provenance = 'observed') desc, la.at desc
   limit 1
) latest on true;

comment on view bank_line_now is
  'Every bank line with the signed amount, what it is currently taken to be, '
  'who said so, whether a person confirmed it, and whether anybody disagrees.';

-- ---------------------------------------------------------------------------
-- The merchant memory, which is a view and not a model
-- ---------------------------------------------------------------------------

-- **No training, no dependency, no staleness.** Merchant strings repeat heavily:
-- a working account visits the same suppliers over and over, and a winery that
-- has been classifying its own transactions by hand already holds the answer for
-- most of them. So the suggestion for a new line is simply what this winery has
-- most often confirmed for that exact description, and it improves every time
-- somebody confirms one.
--
-- Built only from `observed` attestations. A memory that learned from its own
-- guesses would converge on whatever it said first.
create or replace view merchant_memory with (security_invoker = true) as
select
  b.description,
  t.value  as class,
  t.label  as class_label,
  count(*) as times,
  max(la.at) as last_said
from line_attestation la
join bank_line b on b.id = la.line_id
join term t on t.id = la.class_id
where la.provenance = 'observed'
group by b.description, t.value, t.label;

comment on view merchant_memory is
  'What this winery has confirmed a given merchant string to be, and how often. '
  'The suggestion for a new line, derived from its own confirmed history rather '
  'than from a model. Guesses are excluded so it cannot teach itself.';

create or replace view merchant_suggestion with (security_invoker = true) as
select distinct on (description)
  description, class, class_label, times, last_said
from merchant_memory
order by description, times desc, last_said desc;

-- ---------------------------------------------------------------------------
-- The three queues, which are the work
-- ---------------------------------------------------------------------------

create or replace view money_queue with (security_invoker = true) as
select
  n.*,
  case
    when n.attestations = 0 then 'unexplained'
    when n.disputed      then 'disputed'
    when not n.verified  then 'unconfirmed'
    else 'settled'
  end as queue,
  -- What the memory would say, for a line nobody has typed yet.
  s.class       as suggested,
  s.class_label as suggested_label,
  s.times       as suggested_on
from bank_line_now n
left join merchant_suggestion s on s.description = n.description;

comment on view money_queue is
  'Every line with which pile it is in: unexplained, disputed, unconfirmed or '
  'settled, and what the merchant memory would suggest for it.';

-- ---------------------------------------------------------------------------
-- The acts
-- ---------------------------------------------------------------------------

create or replace function attest_line(
  p_line_id uuid,
  p_class   text,
  p_note    text default null,
  p_confirm boolean default true
)
returns line_attestation
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  made line_attestation;
  cls  uuid;
begin
  if not is_admin() then
    raise exception 'only an administrator may say what a transaction was for';
  end if;

  select t.id into cls from term t
   where t.kind = 'money_class' and t.value = p_class and t.active;
  if cls is null then
    raise exception 'there is no class of transaction called %', p_class;
  end if;

  if not exists (select 1 from bank_line where id = p_line_id) then
    raise exception 'that transaction is not there to say anything about';
  end if;

  insert into line_attestation (line_id, class_id, note, by_user, provenance)
  values (
    p_line_id, cls, p_note, auth.uid(),
    -- A person calling this is confirming. The importer passes false when it is
    -- only repeating what the memory suggested, and T0-4 forbids it writing
    -- anything stronger.
    case when coalesce(p_confirm, true) then 'observed' else 'inferred' end)
  returning * into made;

  return made;
end $$;

-- ---------------------------------------------------------------------------
-- The contract
-- ---------------------------------------------------------------------------

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('books.attest_line', 'books', 'Say what a transaction was for',
   'Records what somebody says a bank line was for. Append only: several people may attest to one transaction, and the disagreement is kept rather than resolved.',
   'attest_line',
   '[{"key": "line", "type": "uuid", "label": "Which transaction", "param": "p_line_id", "required": true,
      "source": {"readable": "books.money_queue"}},
     {"key": "class", "type": "text", "label": "What it was for", "param": "p_class", "required": true,
      "source": {"terms": "money_class"}},
     {"key": "note", "type": "text", "label": "Anything worth knowing", "param": "p_note", "required": false},
     {"key": "confirm", "type": "boolean", "label": "You are confirming this rather than guessing", "param": "p_confirm", "required": false}]'::jsonb,
   350)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('books.money_queue', 'books', 'Every transaction and what is left to do',
   'Bank lines with the signed amount, what they are taken to be, and which pile they are in: unexplained, disputed, unconfirmed or settled.',
   'money_queue', 'id', 'description', 351),
  ('books.merchant_memory', 'books', 'What a merchant has been called before',
   'What this winery has confirmed each merchant string to be, and how often. The source of the suggestion on a new line.',
   'merchant_suggestion', 'description', 'class_label', 352),
  ('books.accounts', 'books', 'Accounts', 'The accounts money moves through.',
   'ledger_account', 'id', 'name', 353)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;
