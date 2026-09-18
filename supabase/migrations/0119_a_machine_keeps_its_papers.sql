-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A machine holds the documents written about it, and a part says
--           which document says so."
-- Depends on: [supabase/migrations/0105_a_machine_is_a_departure_from_its_model.sql,
--              supabase/migrations/0106_the_acts_a_shop_performs.sql,
--              supabase/migrations/0112_a_machine_decomposes_into_parts.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  supabase/migrations/0120_the_hot_water_pressure_washer.sql,
--                  supabase/migrations/0121_the_new_acts_say_what_they_take.sql]
-- Axioms enforced: T0-4. A parts list produced by a model is `inferred` and the
--                  document that produced it is named, so the claim can be
--                  traced back and argued with.
-- Open sorries: discharges S-95 for entering parts. No screen yet.
-- ---------------------------------------------------------------------------

-- "Take these reports and figure out and build out the hot water pressure
-- washer entry. Things like decomposing into parts, holding reports,
-- composition of, parts list with manufacturers and links."
--
-- **The shape of this comes from what happened when two models answered the
-- same prompt about the same machine.** One read the contactor's plate as
-- `93265-2 CAMDEC` and marked it read; the other called it a `SAW-4201` and
-- also marked it read. The photograph says 93265-2. One of them put a part
-- number that is not on the plate behind the marker that means "I can see this".
--
-- They also disagree on the burner: Wayne MSR-DC against Beckett ADC, with
-- igniter part numbers one digit apart, and neither is knowable because the
-- burner's plate was never photographed.
--
-- So a parts list is not a fact. It is a claim, by somebody, on a date, and the
-- useful thing to keep is **which** somebody. A tree imported without that
-- becomes the truth the moment it lands, and the disagreement, which is the most
-- informative thing in the whole exercise, is destroyed on the way in. Hence
-- `document_id` on a part, and a table for the documents to live in.

-- ---------------------------------------------------------------------------
-- What kinds of paper a machine has
-- ---------------------------------------------------------------------------

insert into term_kind (kind, module, label, sort_order) values
  ('document_kind', 'shop', 'Kind of document', 74)
on conflict (kind) do nothing;

insert into term (kind, value, label, sort_order) values
  ('document_kind', 'manual',          'Operator manual',    10),
  ('document_kind', 'parts_catalogue', 'Parts catalogue',    20),
  ('document_kind', 'schematic',       'Schematic',          30),
  ('document_kind', 'datasheet',       'Datasheet',          40),
  ('document_kind', 'report',          'Research report',    50),
  ('document_kind', 'plate',           'Photograph of a plate', 60),
  ('document_kind', 'correspondence',  'Correspondence',     70),
  ('document_kind', 'service_bulletin','Service bulletin',   80)
on conflict (kind, value) do nothing;

-- ---------------------------------------------------------------------------
-- The documents
-- ---------------------------------------------------------------------------

create table if not exists machine_document (
  id         uuid primary key default gen_random_uuid(),
  -- About the model or about this one machine, never both and never neither. A
  -- manual is true of every press of that model; a photograph of a plate is
  -- true of one.
  model_id   uuid references machine_model (id) on delete cascade,
  machine_id uuid references machine (id) on delete cascade,
  kind_id    uuid not null,
  kind_kind  text generated always as ('document_kind') stored,
  title      text not null,
  -- Who or what produced it. A manufacturer, a technician, or a model by name
  -- and version. Free text because the list is open and naming it precisely
  -- matters more than choosing from a list: "Gemini 3 Pro" and "Kimi K2" are
  -- different authors with different failure modes.
  source     text,
  url        text,
  -- The document itself when it is text. A report is worth keeping whole: the
  -- parts below are what somebody extracted from it, and the extraction can be
  -- wrong in ways only the original shows.
  body       text,
  at         date not null default current_date,
  -- T0-4. A research report is `inferred` however confident it sounds, and only
  -- a person who checked it may say otherwise.
  provenance provenance not null default 'inferred',
  created_at timestamptz not null default now(),
  created_by uuid references app_user (id),

  constraint machine_document_kind_is_a_document_kind
    foreign key (kind_id, kind_kind) references term (id, kind),
  constraint machine_document_says_what_it_is check (btrim(title) <> ''),
  -- One subject, exactly. A document about "the model, and also specifically
  -- this machine" is two documents or a wrong one.
  constraint machine_document_is_about_one_thing check (
    (model_id is not null) <> (machine_id is not null)
  )
);

create index if not exists machine_document_by_model on machine_document (model_id);
create index if not exists machine_document_by_machine on machine_document (machine_id);

alter table machine_document enable row level security;

drop policy if exists machine_document_read on machine_document;
create policy machine_document_read on machine_document for select to authenticated
  using (is_facility_user());

drop policy if exists machine_document_write on machine_document;
create policy machine_document_write on machine_document to authenticated
  using (is_facility_user()) with check (is_facility_user());

comment on table machine_document is
  'Manuals, schematics, reports and photographs of plates, about a model or '
  'about one machine. A research report is inferred however confident it reads.';

-- ---------------------------------------------------------------------------
-- A part says who makes it, where to read about it, and who says so
-- ---------------------------------------------------------------------------

-- The manufacturer of the part, which is usually not the manufacturer of the
-- machine. The pump on this washer is a General Pump, the engine a Briggs &
-- Stratton, the reel a Coxreels. Ordering anything requires the part's own
-- maker, and burying it in `spec` would make the one field a parts list exists
-- for into a thing you have to go digging for.
alter table model_part add column if not exists maker text;

-- Where the datasheet or the catalogue entry is. E-1 asks for a cited URL per
-- component and the whole value of that is lost if there is nowhere to put it.
alter table model_part add column if not exists url text;

alter table model_part add column if not exists wear boolean not null default false;

-- Free text, not hours. The reports gave "2,500 hrs", "every tune-up", "3 to 5
-- years" and "condition-based", and forcing those into a number would either
-- drop three of the four or invent figures for them.
alter table model_part add column if not exists wear_life text;

-- Which document asserts this part. Null means somebody typed it in from the
-- machine itself, which is the strongest kind and needs no citation.
alter table model_part add column if not exists document_id uuid
  references machine_document (id) on delete set null;

alter table model_part add column if not exists provenance provenance not null
  default 'inferred';

create index if not exists model_part_by_document on model_part (document_id);

comment on column model_part.document_id is
  'Which document claims this part. Two reports on the same machine disagreed '
  'about the burner and about a contactor part number, so a part is a claim by '
  'somebody rather than a fact, and the somebody is kept.';

-- ---------------------------------------------------------------------------
-- The acts
-- ---------------------------------------------------------------------------

-- S-95: the tree existed and nothing could put anything in it.
create or replace function add_model_part(
  p_model_id    uuid,
  p_name        text,
  p_domain      text default null,
  p_parent_id   uuid default null,
  p_maker       text default null,
  p_part_number text default null,
  p_quantity    numeric default null,
  p_wear        boolean default false,
  p_wear_life   text default null,
  p_url         text default null,
  p_note        text default null,
  p_document_id uuid default null,
  p_sort_order  int default 100
)
returns model_part
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  made model_part;
  dom  uuid;
begin
  if not is_facility_user() then
    raise exception 'only this winery may describe what a machine is made of';
  end if;

  if p_domain is not null then
    select t.id into dom from term t
     where t.kind = 'part_domain' and t.value = p_domain and t.active;
    if dom is null then
      raise exception 'there is no part domain called %', p_domain;
    end if;
  end if;

  -- A parent from another model would make a tree that spans two machines.
  if p_parent_id is not null and not exists (
    select 1 from model_part mp
     where mp.id = p_parent_id and mp.model_id = p_model_id
  ) then
    raise exception 'that parent part belongs to a different model';
  end if;

  insert into model_part
    (model_id, parent_id, name, domain_id, maker, part_number, quantity,
     wear, wear_life, url, note, document_id, sort_order, created_by)
  values
    (p_model_id, p_parent_id, p_name, dom, p_maker, p_part_number, p_quantity,
     coalesce(p_wear, false), p_wear_life, p_url, p_note, p_document_id,
     coalesce(p_sort_order, 100), auth.uid())
  returning * into made;

  return made;
end $$;

create or replace function add_machine_document(
  p_kind       text,
  p_title      text,
  p_model_id   uuid default null,
  p_machine_id uuid default null,
  p_source     text default null,
  p_url        text default null,
  p_body       text default null,
  p_at         date default null
)
returns machine_document
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  made machine_document;
  k    uuid;
begin
  if not is_facility_user() then
    raise exception 'only this winery may file a document about a machine';
  end if;

  select t.id into k from term t
   where t.kind = 'document_kind' and t.value = p_kind and t.active;
  if k is null then
    raise exception 'there is no kind of document called %', p_kind;
  end if;

  insert into machine_document
    (model_id, machine_id, kind_id, title, source, url, body, at, created_by)
  values
    (p_model_id, p_machine_id, k, p_title, p_source, p_url, p_body,
     coalesce(p_at, current_date), auth.uid())
  returning * into made;

  return made;
end $$;

-- ---------------------------------------------------------------------------
-- Reading it back
-- ---------------------------------------------------------------------------

-- The tree with everything a person ordering a part needs on the row, rather
-- than in three joins they have to know to make.
create or replace view model_part_detail with (security_invoker = true) as
select
  mp.id,
  mp.model_id,
  mm.make || ' ' || mm.model as model,
  mp.parent_id,
  parent.name   as parent,
  mp.name,
  d.value       as domain,
  d.label       as domain_label,
  mp.maker,
  mp.part_number,
  mp.quantity,
  mp.wear,
  mp.wear_life,
  mp.url,
  mp.note,
  mp.provenance,
  mp.document_id,
  doc.title     as document,
  doc.source    as document_source,
  mp.sort_order
from model_part mp
join machine_model mm on mm.id = mp.model_id
left join model_part parent on parent.id = mp.parent_id
left join term d on d.id = mp.domain_id
left join machine_document doc on doc.id = mp.document_id;

comment on view model_part_detail is
  'Every part of every model with its maker, part number, wear life, link, and '
  'which document claims it.';

create or replace view machine_paper with (security_invoker = true) as
select
  md.id,
  md.model_id,
  md.machine_id,
  coalesce(m.name, mm.make || ' ' || mm.model) as about,
  case when md.machine_id is not null then 'machine' else 'model' end as about_what,
  k.value  as kind,
  k.label  as kind_label,
  md.title,
  md.source,
  md.url,
  -- The body is often a whole report. Whether there is one is what a list needs;
  -- the text itself is fetched when somebody opens it.
  md.body is not null and btrim(md.body) <> '' as has_text,
  length(coalesce(md.body, ''))                as text_length,
  md.at,
  md.provenance
from machine_document md
join term k on k.id = md.kind_id
left join machine m on m.id = md.machine_id
left join machine_model mm on mm.id = md.model_id;

comment on view machine_paper is
  'Every document about a machine or a model, without dragging the text of each '
  'one along with the list.';

-- ---------------------------------------------------------------------------
-- The contract
-- ---------------------------------------------------------------------------

insert into capability (key, module, label, note, fn, sort_order) values
  ('shop.add_model_part', 'shop', 'Say what a model is made of',
   'Adds one part to a model''s decomposition, under a parent part or at the top. Carries the maker, the part number, a link, whether it wears out, and which document claims it.',
   'add_model_part', 312),
  ('shop.add_machine_document', 'shop', 'File a document about a machine',
   'Files a manual, schematic, datasheet, research report, photograph of a plate or a piece of correspondence, against a model or against one machine.',
   'add_machine_document', 313)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, sort_order = excluded.sort_order;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('shop.model_part_detail', 'shop', 'Parts, with makers and links',
   'Every part of every model: maker, part number, quantity, wear life, datasheet link, and which document claims it.',
   'model_part_detail', 'id', 'name', 314),
  ('shop.machine_papers', 'shop', 'Documents about a machine',
   'Manuals, schematics, datasheets, research reports and photographs of plates, by machine or by model.',
   'machine_paper', 'id', 'title', 315)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;
