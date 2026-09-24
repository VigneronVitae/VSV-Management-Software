-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A receipt, a check or an invoice can be photographed, what it says
--           typed in beside the photograph, and matched to the bank transaction
--           it explains, with invoices known to be paid or owed."
-- Depends on: [supabase/migrations/0122_money_that_has_already_moved.sql,
--              supabase/migrations/0125_the_categories_are_schedule_f.sql,
--              supabase/migrations/0127_the_books_have_a_door.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/books/src/books.ts]
-- Axioms enforced: T0-4. A match is a person's statement and is only ever
--                  written by one. The kernel suggests; it never files.
--                  T0-5. What a paper says is appended, not edited. A misread
--                  amount is corrected by reading the paper again, and the
--                  earlier reading stays.
--                  T0-2. Paid, owed and overdue are derived from matches and
--                  dates, never stored.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- "I also want in books to be able to take a picture (receipt, check,
-- invoice, etc) and then manually fill in information about it." Asked what to
-- fill in: the kind of paper; the date, the amount and who; the category; a
-- check number and a note. Asked about matching: "Yes, suggest a match." Asked
-- about invoices: "Yes, due date and paid."
--
-- **The photographs do not go where the other photographs go.** `attachment`
-- and the `vessel-photos` bucket are readable by everybody who works here,
-- which is right for a barrel and wrong for a check: every books policy is
-- `is_admin()`, and a receipt carries the same facts as the bank line it
-- explains, often more. So papers get their own bucket, admin only, and the
-- path lives on the paper rather than in `attachment`, where a cellar hand
-- listing a lot's photos could have reached it through a join.
--
-- **What a paper says is a reading, and readings are appended.** The same shape
-- as `line_attestation`: the paper is a row that exists once, with its
-- photograph; each time somebody types what is on it, that is a new reading,
-- and the latest is what it says. A typed amount is the thing matching runs on,
-- so a typo has to be correctable, and correcting it by update would lose the
-- fact that it was ever wrong.
--
-- **The kernel suggests and a person matches.** Suggestions are a view: bank
-- lines with the same amount, going the right way, inside a window that
-- depends on what the paper is. A card receipt posts within days of the sale;
-- a check clears when it is cashed, which can be weeks; an invoice is paid when
-- it is paid. Nothing is written until somebody taps one.

-- ---------------------------------------------------------------------------
-- What kind of paper
-- ---------------------------------------------------------------------------

insert into term_kind (kind, label, module, sort_order) values
  ('paper_kind', 'Kind of paper', 'books', 160)
on conflict (kind) do update set
  label = excluded.label, module = excluded.module, sort_order = excluded.sort_order;

-- Four, and the AR-J4 test is easy: every business that spends money has these.
-- `window_before` and `window_after` are how many days either side of the
-- paper's date its bank line can land, which is a fact about the kind of paper
-- rather than about this winery, and living on the term means a cellar that
-- finds checks clearing slower changes a row.
insert into term (kind, value, label, sort_order, attributes) values
  ('paper_kind', 'receipt', 'Receipt', 100, '{"window_before": 3, "window_after": 10}'),
  ('paper_kind', 'check',   'Check',   200, '{"window_before": 0, "window_after": 60}'),
  ('paper_kind', 'invoice', 'Invoice', 300, '{"window_before": 0, "window_after": 120, "has_due": true}'),
  ('paper_kind', 'other',   'Other',   400, '{"window_before": 7, "window_after": 30}')
on conflict (kind, value) do update set
  label = excluded.label, sort_order = excluded.sort_order,
  attributes = excluded.attributes, active = true;

-- ---------------------------------------------------------------------------
-- The paper, and what it says
-- ---------------------------------------------------------------------------

create table money_paper (
  -- Client generated, so the photograph can be uploaded under the paper's id
  -- before the paper is written, and a retry finds the same paper.
  id          uuid primary key,
  photo_path  text,
  by_user     uuid not null default auth.uid() references app_user(id),
  created_at  timestamptz not null default now()
);

comment on table money_paper is
  'A receipt, check, invoice or other paper, photographed. What it says is in '
  'money_paper_reading, latest first.';

create table money_paper_reading (
  id            uuid primary key default gen_random_uuid(),
  paper_id      uuid not null references money_paper(id) on delete cascade,
  kind_id       uuid not null,
  kind_kind     text not null default 'paper_kind' check (kind_kind = 'paper_kind'),
  -- Out is money the winery paid, in is money it was paid. A sales invoice and
  -- a vendor's invoice are both invoices, and which way the money goes is what
  -- decides which bank lines can be its payment.
  direction     text not null default 'out' check (direction in ('out', 'in')),
  on_date       date,
  -- Null is a paper nobody has read the total off yet, which is allowed; a
  -- total that is there is above nothing. Said both ways, because a check that
  -- answers null for a null amount is A25.
  amount        numeric(12, 2) check (amount is null or amount > 0),
  who           text,
  class_id      uuid,
  class_kind    text not null default 'money_class' check (class_kind = 'money_class'),
  check_number  text,
  due_on        date,
  note          text,
  by_user       uuid not null default auth.uid() references app_user(id),
  -- `clock_timestamp()`, not `now()`. Latest wins, and `now()` is the start of
  -- the transaction, so two readings written in one would tie and the winner
  -- would be whichever random id sorted higher. Found by the assertion suite,
  -- which reads a paper three times in one transaction.
  at            timestamptz not null default clock_timestamp(),
  constraint money_paper_reading_kind_is_a_paper_kind
    foreign key (kind_id, kind_kind) references term(id, kind),
  constraint money_paper_reading_class_is_a_money_class
    foreign key (class_id, class_kind) references term(id, kind)
);

create index money_paper_reading_paper_idx on money_paper_reading (paper_id, at desc);

comment on table money_paper_reading is
  'What somebody read off a paper. Appended; the latest reading of a paper is what it says.';

-- A person saying this paper is that bank line, or taking it back. Appended,
-- latest per pair wins, the same as every statement in the books.
create table paper_match (
  id        uuid primary key default gen_random_uuid(),
  paper_id  uuid not null references money_paper(id) on delete cascade,
  line_id   uuid not null references bank_line(id) on delete cascade,
  matched   boolean not null default true,
  by_user   uuid not null default auth.uid() references app_user(id),
  -- `clock_timestamp()` for the same reason as a reading: latest per pair wins.
  at        timestamptz not null default clock_timestamp()
);

create index paper_match_paper_idx on paper_match (paper_id, line_id, at desc);
create index paper_match_line_idx on paper_match (line_id);

comment on table paper_match is
  'A person saying a paper is explained by a bank line, or taking that back. Latest per pair wins.';

-- Administrators only, like every other table in the books.
alter table money_paper enable row level security;
alter table money_paper_reading enable row level security;
alter table paper_match enable row level security;

create policy money_paper_read on money_paper for select to authenticated using (is_admin());
create policy money_paper_write on money_paper for insert to authenticated with check (is_admin());
-- The one update there is: a photograph that failed over a bad connection and
-- went up afterwards fills an empty path. A path already there is never
-- replaced, which the `using` clause says and `record_paper` relies on.
create policy money_paper_late_photo on money_paper for update to authenticated
  using (is_admin() and photo_path is null) with check (is_admin());
create policy money_paper_reading_read on money_paper_reading for select to authenticated using (is_admin());
create policy money_paper_reading_write on money_paper_reading for insert to authenticated with check (is_admin());
create policy paper_match_read on paper_match for select to authenticated using (is_admin());
create policy paper_match_write on paper_match for insert to authenticated with check (is_admin());

-- ---------------------------------------------------------------------------
-- The photographs, somewhere only administrators can see
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    raise notice 'storage schema absent, skipping the money-papers bucket';
    return;
  end if;

  insert into storage.buckets (id, name, public)
  values ('money-papers', 'money-papers', false)
  on conflict (id) do nothing;

  drop policy if exists money_papers_read on storage.objects;
  drop policy if exists money_papers_insert on storage.objects;
  execute $p$
    create policy money_papers_read on storage.objects
      for select to authenticated using (bucket_id = 'money-papers' and is_admin())
  $p$;
  execute $p$
    create policy money_papers_insert on storage.objects
      for insert to authenticated with check (bucket_id = 'money-papers' and is_admin())
  $p$;
end $$;

-- ---------------------------------------------------------------------------
-- What each paper says now, and whether it is accounted for
-- ---------------------------------------------------------------------------

create view money_paper_now with (security_invoker = true) as
with latest as (
  select distinct on (r.paper_id) r.*
    from money_paper_reading r
   order by r.paper_id, r.at desc, r.id desc
),
matches as (
  select distinct on (m.paper_id, m.line_id) m.paper_id, m.line_id, m.matched
    from paper_match m
   order by m.paper_id, m.line_id, m.at desc, m.id desc
)
select
  p.id,
  p.photo_path,
  p.created_at,
  k.value          as kind,
  k.label          as kind_label,
  l.direction,
  l.on_date,
  l.amount,
  l.who,
  c.value          as class,
  c.label          as class_label,
  l.check_number,
  l.due_on,
  l.note,
  l.at             as read_at,
  (select count(*) from money_paper_reading r where r.paper_id = p.id) as readings,
  coalesce((select array_agg(x.line_id order by x.line_id)
              from matches x where x.paper_id = p.id and x.matched), '{}') as line_ids,
  exists (select 1 from matches x where x.paper_id = p.id and x.matched) as matched,
  -- Owed and overdue only mean anything for a paper that has a due date, which
  -- is an invoice. Paid is simply matched: the bank line is the payment.
  case when l.due_on is not null
        and not exists (select 1 from matches x where x.paper_id = p.id and x.matched)
       then true else false end as owed,
  case when l.due_on is not null and l.due_on < current_date
        and not exists (select 1 from matches x where x.paper_id = p.id and x.matched)
       then true else false end as overdue
from money_paper p
join latest l on l.paper_id = p.id
join term k on k.id = l.kind_id
left join term c on c.id = l.class_id;

comment on view money_paper_now is
  'Every paper with its latest reading, the bank lines a person matched it to, '
  'and whether an invoice is still owed or overdue. All derived.';

-- Suggestions. The same amount, going the right way, landing inside the
-- paper's kind's window, and not already matched to some other paper. Ranked
-- by how far apart the dates are, with an agreeing check number first because
-- that is as close to proof as a bank statement gets.
create view paper_match_suggestion with (security_invoker = true) as
select
  p.id           as paper_id,
  b.id           as line_id,
  b.at,
  b.amount,
  b.direction,
  b.description,
  b.check_number,
  (b.at - p.on_date) as days_after,
  (p.check_number is not null and b.check_number is not null
    and btrim(p.check_number) = btrim(b.check_number)) as check_number_agrees
from money_paper_now p
join term k on k.kind = 'paper_kind' and k.value = p.kind
join bank_line b
  on b.amount = p.amount
 and b.direction = case p.direction when 'out' then 'Debit' else 'Credit' end
 and b.at between p.on_date - coalesce((k.attributes ->> 'window_before')::int, 7)
              and coalesce(p.due_on, p.on_date) + coalesce((k.attributes ->> 'window_after')::int, 30)
where not p.matched
  and p.amount is not null
  and p.on_date is not null
  and not exists (
    select 1 from money_paper_now o
     where o.id <> p.id and b.id = any(o.line_ids)
  );

comment on view paper_match_suggestion is
  'Bank lines that could be a paper''s payment: same amount, right direction, '
  'inside the window its kind allows, and not already some other paper''s.';

-- ---------------------------------------------------------------------------
-- The two verbs
-- ---------------------------------------------------------------------------

-- New or corrected, the same verb. A first call makes the paper and its first
-- reading; a later call with the same id is somebody reading it again.
create or replace function record_paper(
  p_id            uuid,
  p_kind          text,
  p_direction     text        default 'out',
  p_on_date       date        default null,
  p_amount        numeric     default null,
  p_who           text        default null,
  p_class         text        default null,
  p_check_number  text        default null,
  p_due_on        date        default null,
  p_note          text        default null,
  p_photo_path    text        default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  k_id   uuid;
  c_id   uuid;
  r_id   uuid;
  first  boolean := false;
begin
  if not is_admin() then
    raise exception 'the books are administrators only';
  end if;
  if p_id is null then
    raise exception 'a paper needs an id before it is written';
  end if;

  select id into k_id from term where kind = 'paper_kind' and value = p_kind and active;
  if k_id is null then
    raise exception '"%" is not a kind of paper; the kinds are %', p_kind,
      (select string_agg(value, ', ' order by sort_order) from term where kind = 'paper_kind' and active);
  end if;
  if p_class is not null then
    select id into c_id from term where kind = 'money_class' and value = p_class and active;
    if c_id is null then
      raise exception '"%" is not a category in the books', p_class;
    end if;
  end if;
  if p_amount is not null and p_amount <= 0 then
    raise exception 'an amount of % is not what a paper says; which way the money went is its own answer', p_amount;
  end if;
  if p_due_on is not null and p_on_date is not null and p_due_on < p_on_date then
    raise exception 'that is due on % and dated %, so it was due before it was written', p_due_on, p_on_date;
  end if;

  if not exists (select 1 from money_paper where id = p_id) then
    insert into money_paper (id, photo_path) values (p_id, p_photo_path);
    first := true;
  elsif p_photo_path is not null then
    -- The one thing about the paper row that can arrive late: the photograph
    -- failed on the first save over a bad connection and went up afterwards.
    -- Only ever filled, never replaced, so nothing somebody saw is swapped.
    update money_paper set photo_path = p_photo_path where id = p_id and photo_path is null;
  end if;

  insert into money_paper_reading
    (paper_id, kind_id, direction, on_date, amount, who, class_id,
     check_number, due_on, note)
  values
    (p_id, k_id, coalesce(p_direction, 'out'), p_on_date, p_amount, nullif(btrim(p_who), ''), c_id,
     nullif(btrim(p_check_number), ''), p_due_on, nullif(btrim(p_note), ''))
  returning id into r_id;

  return jsonb_build_object(
    'paper_id',    p_id,
    'reading_id',  r_id,
    'new',         first,
    'suggestions', (select count(*) from paper_match_suggestion s where s.paper_id = p_id));
end $$;

comment on function record_paper is
  'Writes a paper and what it says, or reads an existing paper again. The latest reading is what it says.';

create or replace function match_paper(
  p_paper_id uuid,
  p_line_id  uuid,
  p_matched  boolean default true
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if not is_admin() then
    raise exception 'the books are administrators only';
  end if;
  if not exists (select 1 from money_paper where id = p_paper_id) then
    raise exception 'there is no paper with that id';
  end if;
  if not exists (select 1 from bank_line where id = p_line_id) then
    raise exception 'there is no bank transaction with that id';
  end if;

  insert into paper_match (paper_id, line_id, matched)
  values (p_paper_id, p_line_id, p_matched is not false);

  return jsonb_build_object(
    'paper_id', p_paper_id,
    'line_id',  p_line_id,
    'matched',  p_matched is not false);
end $$;

comment on function match_paper is
  'A person saying a paper is explained by a bank line, or taking that back.';

grant execute on function record_paper(uuid, text, text, date, numeric, text, text, text, date, text, text) to authenticated;
grant execute on function match_paper(uuid, uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- The contract
-- ---------------------------------------------------------------------------

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('books.record_paper', 'books', 'Photograph a paper and say what it says',
   'A receipt, check, invoice or other paper: its photograph and what it says. Called again with the same id, it is somebody reading the paper again, and the latest reading counts.',
   'record_paper',
   '[{"key": "id", "type": "uuid", "label": "The paper", "param": "p_id", "required": true,
      "hint": "Made by the client, so the photograph can go up under it first."},
     {"key": "kind", "type": "text", "label": "What it is", "param": "p_kind", "required": true,
      "source": {"terms": "paper_kind"}},
     {"key": "direction", "type": "text", "label": "Money out or in", "param": "p_direction", "required": false,
      "hint": "out or in. Blank means out."},
     {"key": "on_date", "type": "date", "label": "The date on it", "param": "p_on_date", "required": false},
     {"key": "amount", "type": "numeric", "label": "The total", "param": "p_amount", "required": false},
     {"key": "who", "type": "text", "label": "Who it is from or to", "param": "p_who", "required": false},
     {"key": "class", "type": "text", "label": "What it was for", "param": "p_class", "required": false,
      "source": {"terms": "money_class"}},
     {"key": "check_number", "type": "text", "label": "Check number", "param": "p_check_number", "required": false},
     {"key": "due_on", "type": "date", "label": "Due", "param": "p_due_on", "required": false},
     {"key": "note", "type": "text", "label": "Anything worth knowing", "param": "p_note", "required": false},
     {"key": "photo_path", "type": "text", "label": "The photograph", "param": "p_photo_path", "required": false}]'::jsonb,
   360),
  ('books.match_paper', 'books', 'Say which transaction a paper is',
   'A person saying a paper is explained by a bank line, or taking it back. The suggestions are only ever suggestions.',
   'match_paper',
   '[{"key": "paper", "type": "uuid", "label": "The paper", "param": "p_paper_id", "required": true,
      "source": {"readable": "books.money_papers"}},
     {"key": "line", "type": "uuid", "label": "The transaction", "param": "p_line_id", "required": true,
      "source": {"readable": "books.paper_suggestions"}},
     {"key": "matched", "type": "boolean", "label": "It is this one", "param": "p_matched", "required": false,
      "hint": "False takes a match back."}]'::jsonb,
   361)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('books.money_papers', 'books', 'Papers',
   'Every receipt, check, invoice and other paper, what it says, which transactions it is matched to, and whether an invoice is owed or overdue.',
   'money_paper_now', 'id', 'who', 362),
  ('books.paper_suggestions', 'books', 'Which transaction a paper might be',
   'Bank lines with the same amount, going the right way, inside the window the kind of paper allows.',
   'paper_match_suggestion', 'line_id', 'description', 363)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into screen (key, label) values
  ('papers', 'Papers'),
  ('paper',  'One paper')
on conflict (key) do nothing;
