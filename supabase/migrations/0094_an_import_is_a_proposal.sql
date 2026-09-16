-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Records from a spreadsheet, a photograph or a notebook arrive as a
--           proposal of capability calls that somebody confirms, so an import
--           can record nothing a person could not have recorded by hand."
-- Depends on: [supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0047_attachments.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0095_what_is_running.sql]
-- Axioms enforced: T0-4 (a reader proposes and only a person confirms; nothing
--                  imported passes as witnessed), T0-3 (every imported row says
--                  which document it came from and who let it in), AR-Q8 (the
--                  contract is the interface an importer is written against)
-- Open sorries: S-86 (an applied batch cannot be undone as a batch)
-- ---------------------------------------------------------------------------
--
-- The winemaker, thinking past this harvest: *"more I'm thinking about other
-- people transferring stuff to this"*, then *"plus importing all of the data we
-- have"*, then the shape of it: *"it needs to be able to ingest and format (even
-- if tagged as LLM assisted) structured data as excel sheets or hand written or
-- whatever."*
--
-- **An import is a sequence of capability calls, not a pile of rows.** That is
-- the one decision here and everything else follows from it. Loading rows
-- straight into tables would walk past every refusal the kernel exists to make:
-- a pick could arrive closed with fruit in it, a bin could hold two lots, a
-- weighing could name bins from another pick. Calls go through the same guards
-- as a person tapping a screen, so **an import can record nothing a person
-- could not have recorded by hand**, and the guards do not have to be repeated
-- anywhere.
--
-- It also means the thing an importer is written against already exists.
-- `contract()` returns 27 capabilities with their parameters, their types and
-- where each value comes from. An assistant handed that and a spreadsheet can
-- emit calls without anybody describing this schema to it, which is what the
-- second periphery in `apps/text` was built to prove and is the first use of
-- that proof for something other than proving it.
--
-- **Two tables, and the split matters.** A batch is the document and who let it
-- in. A step is one proposed call, its arguments, and what happened when it ran.
-- Steps survive a closed tab, a refusal, and a person stopping halfway, because
-- an import of three vintages is not one sitting.
--
-- **Nothing here applies anything.** Applying is the periphery calling the
-- capability the step names, through the same PostgREST call any screen makes,
-- and then saying what happened. That keeps dynamic SQL out of the kernel and
-- keeps one path to every write.

begin;

create table if not exists import_batch (
  id          uuid primary key default gen_random_uuid(),
  -- What it came from, as a person would say it: "2024 barrel log.xlsx", "the
  -- blue notebook, pages 4 to 11".
  source      text not null,
  -- Who or what turned that into calls. Free text on purpose: "Claude",
  -- "ChatGPT", "Randy, by hand". The winemaker asked for this to be tagged even
  -- when it is assisted, and a name somebody types is more honest than a flag
  -- this schema would have to keep a list of.
  reader      text not null,
  note        text,
  -- The document itself where there is one. An import whose source has been
  -- deleted is a claim with nothing behind it.
  attachment_id uuid references attachment (id),
  created_by  uuid references app_user (id),
  created_at  timestamptz not null default now(),
  -- Closed when somebody decides the batch is done with, applied or not. It
  -- does not mean every step ran: a batch with three rejected steps is finished
  -- and says so.
  closed_at   timestamptz,
  constraint import_batch_source_is_said check (btrim(source) <> ''),
  constraint import_batch_reader_is_said check (btrim(reader) <> '')
);

comment on table import_batch is
  'One document turned into proposed calls, and who turned it. The reader is '
  'named even when it is a person, because "tagged as LLM assisted" is only '
  'useful if the untagged case is also named. See 0094.';

alter table import_batch enable row level security;

drop policy if exists import_batch_read on import_batch;
create policy import_batch_read on import_batch for select to authenticated
  using (is_facility_user());
drop policy if exists import_batch_write on import_batch;
create policy import_batch_write on import_batch for all to authenticated
  using (is_facility_user()) with check (is_facility_user());

create table if not exists import_step (
  id        uuid primary key default gen_random_uuid(),
  batch_id  uuid not null references import_batch (id) on delete cascade,
  -- The order they were proposed in, which is the order they have to run in: a
  -- weighing cannot precede the pick it weighs.
  ordinal   int not null,
  -- The capability this step calls, by the key the contract uses.
  capability text not null references capability (key) on delete restrict,
  args      jsonb not null default '{}'::jsonb,
  -- Where in the source this came from, so a wrong number can be looked up
  -- against the paper: "row 14", "page 3, line 2".
  source_ref text,
  -- proposed, applied, rejected, or failed. A failure keeps the message,
  -- because the refusal is the most useful thing an import produces: it is the
  -- kernel saying this could not have happened.
  status    text not null default 'proposed',
  result    jsonb,
  error     text,
  decided_by uuid references app_user (id),
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  constraint import_step_status_is_known
    check (status in ('proposed', 'applied', 'rejected', 'failed')),
  constraint import_step_once_per_ordinal unique (batch_id, ordinal),
  -- An applied step says what it returned and a failed one says why. A step
  -- claiming to have applied with nothing to show for it is the shape of a
  -- silent success, which is A13.
  constraint import_step_applied_says_what
    check (status <> 'applied' or result is not null),
  constraint import_step_failed_says_why
    check (status <> 'failed' or error is not null)
);

comment on table import_step is
  'One proposed capability call from an import, and what happened to it. '
  'Nothing here applies anything: a periphery calls the capability and reports '
  'back, so there is one path to every write. See 0094.';

create index if not exists import_step_batch_idx
  on import_step (batch_id, ordinal);
create index if not exists import_step_waiting_idx
  on import_step (batch_id) where status = 'proposed';

alter table import_step enable row level security;

drop policy if exists import_step_read on import_step;
create policy import_step_read on import_step for select to authenticated
  using (is_facility_user());
drop policy if exists import_step_write on import_step;
create policy import_step_write on import_step for all to authenticated
  using (is_facility_user()) with check (is_facility_user());

-- ---------------------------------------------------------------------------
-- Proposing
-- ---------------------------------------------------------------------------

-- Checked against the contract at the moment of proposing rather than at the
-- moment of running, so a spreadsheet naming a capability that does not exist,
-- or missing a parameter the kernel has no default for, is caught while
-- somebody is still looking at the document rather than three hundred rows into
-- applying it.
create or replace function propose_import(
  p_source    text,
  p_reader    text,
  p_steps     jsonb,
  p_note      text default null,
  p_attachment uuid default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  batch_id uuid;
  step     jsonb;
  i        int := 0;
  cap      capability%rowtype;
  missing  text;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here brings records in'
      using errcode = 'insufficient_privilege';
  end if;

  if p_steps is null or jsonb_typeof(p_steps) <> 'array'
     or jsonb_array_length(p_steps) = 0 then
    raise exception 'an import with no steps in it is not an import';
  end if;

  insert into import_batch (source, reader, note, attachment_id, created_by)
  values (btrim(p_source), btrim(p_reader),
          nullif(btrim(coalesce(p_note, '')), ''), p_attachment, auth.uid())
  returning id into batch_id;

  for step in select * from jsonb_array_elements(p_steps)
  loop
    i := i + 1;

    select * into cap from capability where key = step ->> 'capability';
    if cap.key is null then
      raise exception
        'step % names %, which is not something this winery can record. The contract lists what is',
        i, coalesce(step ->> 'capability', 'nothing');
    end if;

    -- Every parameter the kernel has no default for. The contract already
    -- asserts that its own field list covers those, so this is the same check
    -- pointed at the data instead of at the declaration.
    select string_agg(f ->> 'param', ', ') into missing
      from jsonb_array_elements(cap.fields) f
     where coalesce((f ->> 'required')::boolean, false)
       and not (step -> 'args' ? (f ->> 'param'));
    if missing is not null then
      raise exception 'step % of this import leaves out %, which % cannot do without',
        i, missing, cap.label;
    end if;

    insert into import_step
      (batch_id, ordinal, capability, args, source_ref)
    values
      (batch_id, i, cap.key,
       coalesce(step -> 'args', '{}'::jsonb),
       nullif(btrim(coalesce(step ->> 'source_ref', '')), ''));
  end loop;

  return jsonb_build_object(
    'batch', batch_id,
    'source', btrim(p_source),
    'reader', btrim(p_reader),
    'steps', i);
end;
$$;

revoke all on function propose_import(text, text, jsonb, text, uuid) from public;
grant execute on function propose_import(text, text, jsonb, text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Saying what happened
-- ---------------------------------------------------------------------------

create or replace function settle_import_step(
  p_step_id uuid,
  p_status  text,
  p_result  jsonb default null,
  p_error   text  default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  st import_step%rowtype;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here decides an import step'
      using errcode = 'insufficient_privilege';
  end if;

  select * into st from import_step where id = p_step_id;
  if st.id is null then
    raise exception 'no import step with id %', p_step_id;
  end if;
  if st.status <> 'proposed' then
    raise exception
      'that step is already %, and a step that has run is history rather than a plan',
      st.status;
  end if;
  if p_status not in ('applied', 'rejected', 'failed') then
    raise exception '% is not something that happens to an import step', p_status;
  end if;

  update import_step
     set status = p_status,
         result = p_result,
         error  = nullif(btrim(coalesce(p_error, '')), ''),
         decided_by = auth.uid(),
         decided_at = now()
   where id = p_step_id;

  return jsonb_build_object(
    'step', p_step_id, 'status', p_status,
    'left', (select count(*) from import_step
              where batch_id = st.batch_id and status = 'proposed'));
end;
$$;

revoke all on function settle_import_step(uuid, text, jsonb, text) from public;
grant execute on function settle_import_step(uuid, text, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------------
-- What is waiting
-- ---------------------------------------------------------------------------

create or replace view import_waiting with (security_invoker = true) as
select
  b.id            as batch_id,
  b.source,
  b.reader,
  b.note,
  b.created_at,
  u.name          as brought_by,
  b.closed_at,
  count(*)                                             as steps,
  count(*) filter (where s.status = 'proposed')        as waiting,
  count(*) filter (where s.status = 'applied')         as applied,
  count(*) filter (where s.status = 'rejected')        as rejected,
  count(*) filter (where s.status = 'failed')          as failed
from import_batch b
left join import_step s on s.batch_id = b.id
left join app_user u on u.id = b.created_by
group by b.id, b.source, b.reader, b.note, b.created_at, u.name, b.closed_at;

comment on view import_waiting is
  'Imports and how far through each one is. A batch with failures is the useful '
  'one: those are the kernel saying the document describes something that could '
  'not have happened. See 0094.';

grant select on import_waiting to authenticated;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.imports', 'cellar', 'Imports',
   'Records brought in from a spreadsheet, a photograph or a notebook, and how '
   'far through each one is.',
   'import_waiting', 'batch_id', 'source', 180)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into capability_exemption (fn, reason) values
  ('propose_import', 'Brings in proposed calls to other capabilities. Declaring it as one would let an import propose itself.'),
  ('settle_import_step', 'Records what happened to a proposed call. Bookkeeping about a capability rather than one.')
on conflict (fn) do nothing;

commit;
