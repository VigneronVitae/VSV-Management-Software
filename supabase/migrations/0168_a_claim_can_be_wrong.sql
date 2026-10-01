-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Somebody here can say a claim is wrong, and why, and what is
--           right if they know; or take back a confirmation; and every one of
--           those stays in the claim's history."
-- Depends on: [supabase/migrations/0164_a_claim_says_where_it_came_from.sql,
--              supabase/migrations/0165_what_each_row_is_said_to_be.sql,
--              supabase/migrations/0166_a_confirmation_happens.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/vineyard/src/claims.ts]
-- Axioms enforced: T0-5. A verdict is a row, never an edit; the latest one is
--                  the claim's standing and the earlier ones stay. T0-4. A
--                  correction is the person's own statement, recorded with them
--                  as its source, and confirmed by the same deliberate act.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- "I need to be able to disconfirm a claim as well," and of the research on
-- Vitae Springs itself: "that would be great to confirm or disconfirm and then
-- follow up on the disconfirmations."
--
-- **Three verdicts, kept in order.** `confirmed`, from confirm_note; `rejected`,
-- this is wrong and here is why; `reopened`, take back whichever came before,
-- which is what undoing a confirmation is. A claim's standing is its latest
-- verdict, and a claim with none is what a source says. Rejecting a confirmed
-- claim, or reopening one, returns its provenance to inferred: confirmed means
-- somebody here stands behind it, and nobody does any more.
--
-- **A rejected claim stops counting and starts a list.** `row_fact` no longer
-- reads it, so a wrong planting year leaves the map. `claim_to_follow_up`
-- lists every claim whose standing is rejected, with the reason, which is the
-- follow-up list.
--
-- **What is right, if the person knows.** Rejecting can carry the right value.
-- It is recorded as a new claim whose source is that person, and confirmed in
-- the same act, because the person saying it is the confirmation. Their words
-- are the excerpt. A source can now be a person for exactly this.

alter table source drop constraint if exists source_kind_check;
alter table source add constraint source_kind_check
  check (kind in ('web', 'document', 'person'));

create table if not exists claim_verdict (
  id       uuid primary key default gen_random_uuid(),
  note_id  uuid not null references note (id) on delete restrict,
  verdict  text not null check (verdict in ('confirmed', 'rejected', 'reopened')),
  reason   text,
  by_user  uuid references app_user (id),
  at       timestamptz not null default clock_timestamp(),
  -- A claim is not called wrong without saying why: the why is what the
  -- follow-up is.
  constraint claim_verdict_rejection_says_why
    check (verdict <> 'rejected' or nullif(btrim(reason), '') is not null)
);

comment on table claim_verdict is
  'What somebody here said about a claim, in order: confirmed, rejected with why, or reopened. The latest is its standing.';

create index if not exists claim_verdict_note on claim_verdict (note_id, at desc);

alter table claim_verdict enable row level security;
create policy claim_verdict_read on claim_verdict for select to authenticated
  using ((select is_facility_user()));
-- No write policy: verdicts arrive only through the functions below, which
-- run as their owner behind their own checks.

-- The latest verdict of a claim.
create or replace view claim_standing with (security_invoker = true) as
select distinct on (v.note_id)
       v.note_id, v.verdict, v.reason, v.by_user, u.name as by_name, v.at
  from claim_verdict v
  left join app_user u on u.id = v.by_user
 order by v.note_id, v.at desc, v.id desc;

-- ---------------------------------------------------------------------------
-- The verbs
-- ---------------------------------------------------------------------------

-- confirm_note, as 0166 left it, now also writes the verdict when the note is
-- a claim, so a claim's history says who confirmed it and when.
create or replace function confirm_note(p_note_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  n       note%rowtype;
  changed int;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here confirms a fact'
      using errcode = 'insufficient_privilege';
  end if;
  select * into n from note where id = p_note_id;
  if n.id is null then
    raise exception 'there is no note with id %', p_note_id;
  end if;
  if n.kind_id is null then
    raise exception 'that note has not been typed, so there is no fact in it to confirm';
  end if;
  if n.provenance = 'confirmed' then
    return jsonb_build_object('id', p_note_id, 'provenance', 'confirmed', 'already', true);
  end if;

  perform set_config('vsv.confirming_note', 'yes', true);
  update note set provenance = 'confirmed' where id = p_note_id;
  get diagnostics changed = row_count;
  perform set_config('vsv.confirming_note', '', true);
  if changed <> 1 then
    raise exception 'the note was not confirmed; nothing changed';
  end if;

  insert into note (subject_type, subject_id, body, by_user)
  values ('note', p_note_id, 'checked and confirmed', auth.uid());
  if exists (select 1 from note_source where note_id = p_note_id) then
    insert into claim_verdict (note_id, verdict, by_user) values (p_note_id, 'confirmed', auth.uid());
  end if;

  return jsonb_build_object('id', p_note_id, 'provenance', 'confirmed', 'already', false);
end $$;

revoke all on function confirm_note(uuid) from public;
grant execute on function confirm_note(uuid) to authenticated;

create or replace function reject_claim(
  p_note_id uuid,
  p_reason  text,
  p_right   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  n        note%rowtype;
  kt       term%rowtype;
  ns       note_source%rowtype;
  who      text;
  src      uuid;
  fixed    uuid;
  right_v  text := nullif(btrim(coalesce(p_right, '')), '');
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here says a claim is wrong'
      using errcode = 'insufficient_privilege';
  end if;
  select * into n from note where id = p_note_id;
  select * into ns from note_source where note_id = p_note_id;
  if n.id is null or ns.note_id is null then
    raise exception 'there is no claim with id %', p_note_id;
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'say what is wrong with it; that is what the follow-up starts from';
  end if;
  select * into kt from term where id = n.kind_id;
  if right_v is not null and kt.attributes ->> 'value_type' = 'number'
     and right_v !~ '^-?[0-9]+([.][0-9]+)?$' then
    raise exception '% is a number, and "%" is not one', kt.label, right_v;
  end if;

  update note set provenance = 'inferred' where id = p_note_id and provenance = 'confirmed';
  insert into claim_verdict (note_id, verdict, reason, by_user)
  values (p_note_id, 'rejected', btrim(p_reason), auth.uid());

  -- What is right, from the person who knows, as a claim of its own.
  if right_v is not null then
    select coalesce(u.name, 'somebody here') into who from app_user u where u.id = auth.uid();
    who := coalesce(who, 'somebody here');
    select id into src from source where kind = 'person' and title = who;
    if src is null then
      insert into source (kind, title, publisher, created_by)
      values ('person', who, 'Vitae Springs', auth.uid())
      returning id into src;
    end if;
    fixed := gen_random_uuid();
    insert into note (id, subject_type, subject_id, body, by_user, kind_id,
                      value_num, value_text, provenance)
    values (fixed, n.subject_type, n.subject_id,
            kt.label || ': ' || right_v || ', corrected by ' || who,
            auth.uid(), n.kind_id,
            case when kt.attributes ->> 'value_type' = 'number' then right_v::numeric end,
            case when kt.attributes ->> 'value_type' = 'number' then null else right_v end,
            'inferred');
    insert into note_source (note_id, source_id, excerpt, locator, row_range)
    values (fixed, src, btrim(p_reason), 'in place of a claim marked wrong', ns.row_range);
    perform confirm_note(fixed);
  end if;

  return jsonb_build_object('note_id', p_note_id, 'verdict', 'rejected', 'correction', fixed);
end $$;

comment on function reject_claim is
  'Says a claim is wrong and why, and, if the person knows, records what is right as their own confirmed claim.';

revoke all on function reject_claim(uuid, text, text) from public;
grant execute on function reject_claim(uuid, text, text) to authenticated;

create or replace function reopen_claim(p_note_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  n note%rowtype;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here reopens a claim'
      using errcode = 'insufficient_privilege';
  end if;
  select * into n from note where id = p_note_id;
  if n.id is null or not exists (select 1 from note_source where note_id = p_note_id) then
    raise exception 'there is no claim with id %', p_note_id;
  end if;
  update note set provenance = 'inferred' where id = p_note_id and provenance = 'confirmed';
  insert into claim_verdict (note_id, verdict, reason, by_user)
  values (p_note_id, 'reopened', nullif(btrim(coalesce(p_reason, '')), ''), auth.uid());
  return jsonb_build_object('note_id', p_note_id, 'verdict', 'reopened');
end $$;

comment on function reopen_claim is
  'Takes back whatever was last said about a claim, a confirmation or a rejection, leaving it as what its source says.';

revoke all on function reopen_claim(uuid, text) from public;
grant execute on function reopen_claim(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- The views learn the verdicts
-- ---------------------------------------------------------------------------

-- Replaced in place with the standing appended.
create or replace view sourced_claim with (security_invoker = true) as
select n.id                                   as note_id,
       n.subject_type,
       n.subject_id,
       resolve_subject_name(n.subject_type, n.subject_id) as about,
       coalesce(v.id, b.vineyard_id, br.vineyard_id) as vineyard_id,
       t.value                                as kind,
       t.label                                as kind_label,
       t.attributes ->> 'unit'                as unit,
       coalesce(n.value_num::text, n.value_text) as value,
       n.value_num,
       n.body                                 as statement,
       n.provenance,
       ns.excerpt,
       ns.locator,
       lower(ns.row_range)                    as row_from,
       upper(ns.row_range) - 1                as row_to,
       s.id                                   as source_id,
       s.kind                                 as source_kind,
       s.title                                as source_title,
       s.url                                  as source_url,
       s.publisher,
       s.published_on,
       s.retrieved_at,
       n.at,
       n.created_at,
       cs.verdict,
       cs.reason                              as verdict_reason,
       cs.by_name                             as verdict_by,
       cs.at                                  as verdict_at
  from note n
  join note_source ns on ns.note_id = n.id
  join source s on s.id = ns.source_id
  join term t on t.id = n.kind_id
  left join vineyard v on n.subject_type = 'vineyard' and v.id = n.subject_id
  left join block b on n.subject_type = 'block' and b.id = n.subject_id
  left join vine_row vr on n.subject_type = 'vine_row' and vr.id = n.subject_id
  left join block br on br.id = vr.block_id
  left join claim_standing cs on cs.note_id = n.id;

-- A wrong claim no longer says what a row is.
create or replace view row_fact with (security_invoker = true) as
with candidate as (
  select vr.id     as row_id,
         vr.block_id,
         vr.number as row_number,
         sc.kind,
         sc.kind_label,
         sc.value,
         sc.provenance,
         sc.source_title,
         (sc.subject_type = 'vine_row' or sc.row_from is not null) as specific
    from vine_row vr
    join sourced_claim sc
      on (sc.subject_type = 'block' and sc.subject_id = vr.block_id
          and (sc.row_from is null or vr.number between sc.row_from and sc.row_to))
      or (sc.subject_type = 'vine_row' and sc.subject_id = vr.id)
   where sc.kind in ('planted_year', 'rootstock', 'spacing')
     and sc.verdict is distinct from 'rejected'
),
ranked as (
  select c.*,
         dense_rank() over (partition by c.row_id, c.kind
                            order by (c.provenance = 'confirmed') desc, c.specific desc) as rk
    from candidate c
)
select row_id,
       block_id,
       row_number,
       kind,
       min(kind_label)                                         as kind_label,
       string_agg(distinct value, ' or ' order by value)       as value,
       bool_and(provenance = 'confirmed')                      as confirmed,
       count(distinct value) > 1                               as disputed,
       string_agg(distinct source_title, '; ' order by source_title) as sources
  from ranked
 where rk = 1
 group by row_id, block_id, row_number, kind;

create or replace view claim_to_follow_up with (security_invoker = true) as
select sc.*
  from sourced_claim sc
 where sc.verdict = 'rejected';

comment on view claim_to_follow_up is
  'Every claim somebody here has said is wrong, with why: what is left to find out.';

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('vineyard.reject_claim', 'vineyard', 'Say a claim is wrong',
   'With why, and what is right if you know; what is right is recorded as your own confirmed claim.',
   'reject_claim',
   '[{"key": "claim", "type": "uuid", "label": "Which claim", "param": "p_note_id", "required": true, "source": {"readable": "vineyard.claims"}},
     {"key": "reason", "type": "text", "label": "What is wrong", "param": "p_reason", "required": true},
     {"key": "right", "type": "text", "label": "What is right, if you know", "param": "p_right", "required": false}]'::jsonb,
   421),
  ('vineyard.reopen_claim', 'vineyard', 'Take back a verdict',
   'Undoes the last confirmation or rejection, leaving the claim as what its source says.',
   'reopen_claim',
   '[{"key": "claim", "type": "uuid", "label": "Which claim", "param": "p_note_id", "required": true, "source": {"readable": "vineyard.claims"}},
     {"key": "reason", "type": "text", "label": "Why", "param": "p_reason", "required": false}]'::jsonb,
   422)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('vineyard.to_follow_up', 'vineyard', 'Claims to follow up',
   'Every claim marked wrong, with why.',
   'claim_to_follow_up', 'note_id', 'statement', 414)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;
