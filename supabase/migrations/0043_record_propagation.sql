-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Some measurements have to end up on paper as well as in here, and
--           the ones that have not yet are a list somebody can work through
--           rather than a thing anybody remembers."
-- Depends on: [supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0042_weighing_photo.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (what still needs writing down is derived from what has
--                  been written down, never tracked separately), T0-5 (a
--                  propagation is appended and not edited)
-- Open sorries: S-59 (retiring a document does not forgive its backlog, and
--               nothing can)
-- ---------------------------------------------------------------------------
--
-- The winemaker's words: "for this harvest weight sheets are also on two
-- physical documents", and then "a section that is measurements that need
-- propagated, that need cleared by filling the physical forms".
--
-- **This is `unweighed_bin` pointed at paperwork**, and it is the same shape for
-- the same reason. A derived list that must be empty is the only mechanism in
-- this app that has reliably caught things, because it does not depend on
-- anybody remembering to look for what is missing. It depends on what is
-- missing being visible without being looked for.
--
-- Three decisions, all his:
--
-- **A document is a named row you maintain, and it retires rather than
-- disappears.** A form you stopped keeping in October is still the form that was
-- required in September, and deleting it would take that fact with it.
--
-- **Each document says which kinds of measurement belong on it.** Weight sheets
-- take weighings. Something else takes additions. The pairing is rows rather
-- than a rule in code, so the next form somebody hands him is a row.
--
-- **Clearing is per document and records who and when.** A weighing due on two
-- sheets is on the list twice and comes off each as it is written, because doing
-- one and not the other is exactly the case a queue exists for.
--
-- **The dates matter more than they look.** A document carries the span over
-- which it was being kept. Without that, adding a form in October would put
-- every weighing since August on the list, and retiring one would silently
-- forgive work that really was outstanding. So an obligation exists for events
-- inside the span and nowhere else.

begin;

create table if not exists paper_record (
  id             uuid primary key default gen_random_uuid(),
  name           text not null unique,
  notes          text,
  -- When this form started being kept. Defaults to now, so adding a document
  -- creates obligations from here rather than a backlog stretching to the
  -- beginning of the vintage.
  effective_from timestamptz not null default now(),
  -- Retired rather than deleted. Null means still being kept.
  retired_at     timestamptz,
  created_at     timestamptz not null default now(),
  constraint paper_record_retired_after_it_started
    check (retired_at is null or retired_at >= effective_from)
);

create table if not exists paper_record_operation (
  paper_record_id uuid not null references paper_record (id) on delete cascade,
  operation_id    uuid not null,
  -- Pins the term to the operation vocabulary, the same way every other pointer
  -- into `term` has since 0027.
  operation_kind  text generated always as ('operation') stored,
  primary key (paper_record_id, operation_id),
  constraint paper_record_operation_is_an_operation
    foreign key (operation_id, operation_kind) references term (id, kind)
);

-- Appended, never edited. Somebody wrote a number on a form at a time, and that
-- is a fact about the past like any other.
create table if not exists propagation (
  id              uuid primary key default gen_random_uuid(),
  event_id        uuid not null references event (id) on delete cascade,
  paper_record_id uuid not null references paper_record (id) on delete cascade,
  written_at      timestamptz not null default now(),
  written_by      uuid references app_user (id),
  constraint propagation_once_per_document unique (event_id, paper_record_id)
);

alter table paper_record enable row level security;
alter table paper_record_operation enable row level security;
alter table propagation enable row level security;

-- Paperwork is the facility's business and none of a client's. A custom crush
-- client signing in to see their wine has no reason to learn which of this
-- winery's forms are behind.
drop policy if exists paper_record_read on paper_record;
create policy paper_record_read on paper_record for select to authenticated
  using (is_facility_user());

drop policy if exists paper_record_admin_write on paper_record;
create policy paper_record_admin_write on paper_record to authenticated
  using (is_admin()) with check (is_admin());

drop policy if exists paper_record_operation_read on paper_record_operation;
create policy paper_record_operation_read on paper_record_operation for select
  to authenticated using (is_facility_user());

drop policy if exists paper_record_operation_admin_write on paper_record_operation;
create policy paper_record_operation_admin_write on paper_record_operation
  to authenticated using (is_admin()) with check (is_admin());

drop policy if exists propagation_read on propagation;
create policy propagation_read on propagation for select to authenticated
  using (is_facility_user());

-- Anybody who works here may say they filled a form in, and says it as
-- themselves. The author is required rather than defaulted, so a tick can
-- always be asked about.
drop policy if exists propagation_insert on propagation;
create policy propagation_insert on propagation for insert to authenticated
  with check (is_facility_user() and written_by = auth.uid());

drop policy if exists propagation_admin_delete on propagation;
create policy propagation_admin_delete on propagation for delete to authenticated
  using (is_admin());

comment on table paper_record is
  'A physical document this winery keeps, and the span over which it kept it. '
  'Retired rather than deleted, because a form kept in September is still what '
  'was required in September. See 0043.';

comment on table propagation is
  'Somebody wrote a measurement onto a form, and when. Appended, never edited.';

-- ---------------------------------------------------------------------------
-- What is still owed to paper
-- ---------------------------------------------------------------------------

-- Derived, so it is right by construction and cannot be forgotten to update.
-- One row per measurement per document, because a weighing due on two sheets is
-- two pieces of work and doing one of them is not doing both.
create or replace view measurement_to_propagate with (security_invoker = true) as
select
  e.id            as event_id,
  p.id            as paper_record_id,
  p.name          as paper_record,
  e.at,
  coalesce(t.label, 'Something') as operation,
  coalesce(resolve_subject_name(e.subject_type, e.subject_id), e.subject_type) as subject,
  e.data,
  e.provenance
from event e
join paper_record_operation pro on pro.operation_id = e.operation_id
join paper_record p
  on p.id = pro.paper_record_id
 -- The obligation exists for what happened while the form was being kept, and
 -- nowhere else. Adding a document in October must not invent a backlog, and
 -- retiring one must not forgive the work that really was outstanding.
 and e.at >= p.effective_from
 and (p.retired_at is null or e.at < p.retired_at)
left join term t on t.id = e.operation_id and t.kind = 'operation'
where not exists (
  select 1 from propagation g
   where g.event_id = e.id and g.paper_record_id = p.id
);

comment on view measurement_to_propagate is
  'Measurements that belong on a physical form and have not been written onto '
  'it yet. One row per form, because doing one of two sheets is not doing both. '
  'The list that should be empty at the end of a day. See 0043.';

commit;
