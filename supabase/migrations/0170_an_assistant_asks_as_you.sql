-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Somebody here can ask the app a question in a sentence, and an
--           assistant answers by reading what that person may read, and
--           proposes what to record for them to confirm; it never records
--           anything itself, and every question is kept."
-- Depends on: [supabase/migrations/0152_who_may_do_what.sql,
--              supabase/migrations/0167_the_vineyard_asks_once.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  supabase/functions/agent/index.ts,
--                  supabase/functions/agent/tools.ts,
--                  packages/cellar/src/index.ts, docs/the-assistant.md]
-- Axioms enforced: T0-4. The assistant writes nothing: a proposal is recorded
--                  by the person who confirms it, through the same capability
--                  they would have used by hand, so whatever it records is
--                  theirs. T0-5. A question, its answer and what became of each
--                  proposal are rows that are never edited. A13. A question
--                  ends in an answer or in a failure that says what failed.
-- Open sorries: S-152.
-- ---------------------------------------------------------------------------

-- "A way for an AI agent can navigate within, not server admin access like
-- you have, but more like an LLM call." Answer, and propose actions the person
-- confirms; administrators first.
--
-- **The assistant is the person asking, with less.** It runs in an edge
-- function that holds the provider's key and nothing else: every read goes
-- to the API with the asker's own sign-in, so row level security decides what
-- it sees exactly as it decides what their phone sees. It cannot see more
-- than they can, and it sees less: only the readables and capabilities in
-- `agent_contract()`, which leaves out any module an administrator has closed
-- to it. The books start closed: money is the one thing on this server that
-- should not go to an outside provider because somebody asked about a tank.
--
-- **A proposal is a filled-in form, not an action.** The assistant names a
-- capability from the contract and the values for its fields. The phone
-- shows that form with every value labelled, and Confirm calls the
-- capability as the person, the same call the screen would have made. Nothing
-- the assistant says reaches the database except through that tap. So there
-- is no new write path to guard: the capability's own checks are the guard,
-- and a refusal reads the way it would have by hand.
--
-- **Who may ask is a permission like the others.** `agent.ask` starts off for
-- cellar hands, so administrators only, and the same settings screen widens
-- it.

insert into permission (key, module, label, note, sort_order) values
  ('agent.ask', 'core', 'Ask the assistant',
   'Ask questions in a sentence and get proposals to confirm. Each question goes to the outside provider set up on the winery computer, with whatever the answer needed to read.',
   600)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  sort_order = excluded.sort_order;

-- Which modules the assistant may read and propose in. A column on the module
-- rather than a table of its own: there are six and each has one answer.
-- `core` has no row, because it is not a module somebody switches on; it is
-- what the others stand on, so it is always open to the assistant.
alter table module add column if not exists agent_reads boolean not null default true;
comment on column module.agent_reads is
  'Whether the assistant may read this module''s readables and propose its capabilities.';
update module set agent_reads = false where key = 'books';

-- ---------------------------------------------------------------------------
-- The record
-- ---------------------------------------------------------------------------

create table if not exists agent_turn (
  -- Made by the edge function before the provider is called, so a turn that
  -- never comes back still has a name in the function's log.
  id            uuid primary key,
  asked_by      uuid not null references app_user (id),
  asked_at      timestamptz not null default clock_timestamp(),
  provider      text not null check (provider in ('anthropic', 'openai', 'deepseek', 'kimi')),
  model         text not null,
  question      text not null check (nullif(btrim(question), '') is not null),
  answer        text,
  stop_reason   text,
  -- What it read: readable, filters, how many rows. Not the rows themselves;
  -- those are in the tables and are not copied twice.
  reads         jsonb not null default '[]'::jsonb check (jsonb_typeof(reads) = 'array'),
  -- What it proposed, each with the capability and the labelled values the
  -- person was shown.
  proposals     jsonb not null default '[]'::jsonb check (jsonb_typeof(proposals) = 'array'),
  -- Null when the provider never answered. Spelled out, so the check says
  -- yes or no to every row rather than nothing (A25).
  input_tokens  int check (input_tokens is null or input_tokens >= 0),
  output_tokens int check (output_tokens is null or output_tokens >= 0),
  failure       text,
  -- A13. A turn that neither answered nor said why not is the silent success
  -- this rule exists to refuse.
  constraint agent_turn_ends_somehow
    check (nullif(btrim(answer), '') is not null or nullif(btrim(failure), '') is not null
           or proposals <> '[]'::jsonb)
);

comment on table agent_turn is
  'Every question put to the assistant, with what it answered, read and proposed.';

create index if not exists agent_turn_by on agent_turn (asked_by, asked_at desc);

create table if not exists agent_outcome (
  id          uuid primary key default gen_random_uuid(),
  -- Restrict, like a verdict on a claim: what became of a proposal is
  -- evidence about the question, and outlives nothing it was about.
  turn_id     uuid not null references agent_turn (id) on delete restrict,
  proposal    int not null check (proposal >= 0),
  outcome     text not null check (outcome in ('done', 'declined', 'refused')),
  -- What the capability returned when done, what it said when refused.
  result      jsonb,
  said        text,
  decided_by  uuid not null references app_user (id),
  decided_at  timestamptz not null default clock_timestamp(),
  constraint agent_outcome_refusal_says_what
    check (outcome <> 'refused' or nullif(btrim(said), '') is not null)
);

comment on table agent_outcome is
  'What became of each proposal: confirmed and done, declined, or refused by the capability. A retry is another row.';

create index if not exists agent_outcome_turn on agent_outcome (turn_id, proposal, decided_at desc);

alter table agent_turn enable row level security;
alter table agent_outcome enable row level security;

-- The asker reads their own; an administrator reads everybody's, because
-- knowing what the assistant was asked and did is how it is supervised.
create policy agent_turn_read on agent_turn for select to authenticated
  using (asked_by = (select auth.uid()) or (select is_admin()));
create policy agent_outcome_read on agent_outcome for select to authenticated
  using (decided_by = (select auth.uid()) or (select is_admin()));
-- No write policy on either: rows arrive through the two functions below, and
-- nothing edits or removes one.

-- ---------------------------------------------------------------------------
-- What the assistant may see
-- ---------------------------------------------------------------------------

create or replace function agent_contract()
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  c jsonb;
begin
  if not may('agent.ask') then
    raise exception 'asking the assistant is for administrators unless an administrator has allowed cellar hands';
  end if;
  c := contract();
  return jsonb_build_object(
    'viewer', c -> 'viewer',
    'today', to_char(now() at time zone 'America/Los_Angeles', 'YYYY-MM-DD'),
    'now', now(),
    'modules', coalesce((
      select jsonb_agg(jsonb_build_object('key', m.key, 'label', m.label, 'note', m.note)
                       order by m.sort_order)
        from module m where m.active and m.agent_reads), '[]'::jsonb),
    'readables', coalesce((
      select jsonb_agg(r)
        from jsonb_array_elements(c -> 'readables') r
       where not exists (select 1 from module m
                          where m.key = r ->> 'module' and not m.agent_reads)), '[]'::jsonb),
    'capabilities', coalesce((
      select jsonb_agg(k)
        from jsonb_array_elements(c -> 'capabilities') k
       where not exists (select 1 from module m
                          where m.key = k ->> 'module' and not m.agent_reads)), '[]'::jsonb));
end $$;

comment on function agent_contract is
  'The contract as the assistant may use it: only modules open to it, and only for somebody who may ask.';

grant execute on function agent_contract() to authenticated;

create or replace function set_agent_reads(p_module text, p_open boolean)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if not is_admin() then
    raise exception 'only an administrator decides what the assistant may read';
  end if;
  if p_open is null then
    raise exception 'say yes or no';
  end if;
  update module set agent_reads = p_open where key = p_module;
  if not found then
    raise exception 'there is no module called %', p_module;
  end if;
  return (select jsonb_build_object('key', m.key, 'label', m.label, 'agent_reads', m.agent_reads)
            from module m where m.key = p_module);
end $$;

grant execute on function set_agent_reads(text, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Keeping the record
-- ---------------------------------------------------------------------------

create or replace function record_agent_turn(
  p_id uuid, p_provider text, p_model text, p_question text,
  p_answer text, p_stop_reason text, p_reads jsonb, p_proposals jsonb,
  p_input_tokens int, p_output_tokens int, p_failure text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Definer so the table needs no write policy; these checks are the policy.
  if auth.uid() is null or not may('agent.ask') then
    raise exception 'asking the assistant is for administrators unless an administrator has allowed cellar hands';
  end if;
  insert into agent_turn (id, asked_by, provider, model, question, answer, stop_reason,
                          reads, proposals, input_tokens, output_tokens, failure)
  values (p_id, auth.uid(), p_provider, p_model, p_question, p_answer, p_stop_reason,
          coalesce(p_reads, '[]'::jsonb), coalesce(p_proposals, '[]'::jsonb),
          p_input_tokens, p_output_tokens, p_failure);
  return p_id;
end $$;

revoke execute on function record_agent_turn(uuid, text, text, text, text, text, jsonb, jsonb, int, int, text) from public, anon;
grant execute on function record_agent_turn(uuid, text, text, text, text, text, jsonb, jsonb, int, int, text) to authenticated;

create or replace function record_agent_outcome(
  p_turn_id uuid, p_proposal int, p_outcome text, p_result jsonb, p_said text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  t agent_turn;
  v_id uuid := gen_random_uuid();
begin
  select * into t from agent_turn where id = p_turn_id;
  if not found then
    raise exception 'there is no question with that id';
  end if;
  -- Only the person who asked decides what becomes of its proposals: the
  -- proposal was made to them, with what they may see.
  if t.asked_by is distinct from auth.uid() then
    raise exception 'only the person who asked can confirm or decline what the assistant proposed';
  end if;
  if p_proposal is null or p_proposal < 0 or p_proposal >= jsonb_array_length(t.proposals) then
    raise exception 'that question had no proposal %', p_proposal;
  end if;
  insert into agent_outcome (id, turn_id, proposal, outcome, result, said, decided_by)
  values (v_id, p_turn_id, p_proposal, p_outcome, p_result, p_said, auth.uid());
  return v_id;
end $$;

revoke execute on function record_agent_outcome(uuid, int, text, jsonb, text) from public, anon;
grant execute on function record_agent_outcome(uuid, int, text, jsonb, text) to authenticated;

-- The log as a person reads it: each question with who asked and what became
-- of its proposals.
create or replace view agent_log with (security_invoker = true) as
select t.id, t.asked_at, t.asked_by, u.name as asked_by_name, t.provider, t.model,
       t.question, t.answer, t.failure, t.stop_reason,
       jsonb_array_length(t.reads) as reads,
       jsonb_array_length(t.proposals) as proposals,
       (select count(distinct o.proposal) from agent_outcome o
         where o.turn_id = t.id and o.outcome = 'done') as proposals_done,
       t.input_tokens, t.output_tokens
  from agent_turn t
  join app_user u on u.id = t.asked_by;

comment on view agent_log is
  'Every question put to the assistant, newest first by asked_at, with who asked and how many of its proposals were done.';

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('core.assistant_log', 'core', 'What the assistant was asked',
   'Every question put to the assistant, what it answered and how many of its proposals were confirmed.',
   'agent_log', 'id', 'question', 950)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('core.set_agent_reads', 'core', 'Decide what the assistant may read',
   'Administrators only. A module closed to the assistant is neither read nor proposed in.',
   'set_agent_reads',
   '[{"key": "module", "type": "text", "label": "Which module", "param": "p_module", "required": true,
      "source": {"readable": "core.modules"}},
     {"key": "open", "type": "boolean", "label": "The assistant may read it", "param": "p_open", "required": true}]'::jsonb,
   910)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into capability_exemption (fn, reason) values
  ('agent_contract', 'The contract as the assistant may use it. It changes nothing.'),
  ('record_agent_turn', 'The edge function''s record of a question it answered, as the person who asked. Not a thing a person records.'),
  ('record_agent_outcome', 'What became of a proposal, recorded by the phone as the person confirms or declines it. The capability confirmed is the record of the act.')
on conflict (fn) do update set reason = excluded.reason;

-- The screen, so a note can be about it like any other.
insert into screen (key, label) values ('ask', 'Ask')
on conflict (key) do nothing;
