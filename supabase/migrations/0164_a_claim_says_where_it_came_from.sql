-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Anything recorded about a vineyard from somewhere other than this
--           winery's own eyes says where it came from, in the source's own
--           words, and stays a claim until somebody here confirms it."
-- Depends on: [supabase/migrations/0064_typing_a_note.sql,
--              supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  scripts/import-claims.py, packages/vineyard/src/index.ts,
--                  packages/vineyard/src/claims.ts, supabase/migrations/0165_what_each_row_is_said_to_be.sql,
--                  supabase/migrations/0166_a_confirmation_happens.sql]
-- Axioms enforced: T0-4. A claim is born `inferred` whoever writes it, and only
--                  `confirm_note` promotes it, recording who did. T0-5. A claim
--                  is not edited; a better one is recorded beside it and both
--                  keep their sources.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- "Maybe also a research project to feed information about the vineyards
-- based on publicly available information, but keep the lineage so we know
-- where each claim's coming from." Eola Springs, Royer, Zenith and Tuckaway,
-- and, as it turned out, Vitae Springs itself: its planting years, rootstocks
-- and spacings are on a 2020 block map and nowhere in the database.
--
-- **A claim is a typed note with a source.** 0064 already made "a sentence
-- with a fact in it" the unit, with a kind, a value, the words it came from
-- and a provenance, and 0065 made confirming one its own act. What it lacked
-- was where the sentence came from. `source` is a page or a document, once;
-- `note_source` ties one note to one source with the exact words that support
-- it, where in the source they are, and, for a claim about some rows of a
-- block and not all of it, which rows.
--
-- **Sources disagree, and both stay.** The Eola-Amity Hills directory gives
-- Eola Springs 104 acres; an older profile gives it 70. Neither is deleted or
-- preferred by this schema. They are two claims with two sources and a person
-- decides, by confirming one.

-- The facts a vineyard is described by. Typed, so a claim can be confirmed and
-- an export can read a planting year as a number rather than parsing a sentence.
insert into term (kind, value, label, sort_order, attributes) values
  ('fact_kind', 'planted_year',  'Year planted',   40, '{"value_type": "number", "hint": "The year vines went in. A replanting is another claim."}'),
  ('fact_kind', 'rootstock',     'Rootstock',      41, '{"value_type": "text", "hint": "3309, Riparia Gloire, own roots."}'),
  ('fact_kind', 'spacing',       'Spacing',        42, '{"value_type": "text", "hint": "Between rows by between vines, in feet: 8 x 5."}'),
  ('fact_kind', 'acres_planted', 'Acres planted',  43, '{"value_type": "number", "unit": "acres"}'),
  ('fact_kind', 'elevation',     'Elevation',      44, '{"value_type": "text", "hint": "In feet, a range if the source gives one."}'),
  ('fact_kind', 'soils',         'Soils',          45, '{"value_type": "text"}'),
  ('fact_kind', 'aspect',        'Aspect',         46, '{"value_type": "text"}'),
  ('fact_kind', 'varieties',     'Varieties grown',47, '{"value_type": "text"}'),
  ('fact_kind', 'clones',        'Clones',         48, '{"value_type": "text"}'),
  ('fact_kind', 'owner',         'Owner',          49, '{"value_type": "text"}'),
  ('fact_kind', 'farmed_by',     'Farmed by',      50, '{"value_type": "text"}'),
  ('fact_kind', 'farming',       'Farming',        51, '{"value_type": "text", "hint": "Dry-farmed, organic, sustainable."}'),
  ('fact_kind', 'certification', 'Certification',  52, '{"value_type": "text"}'),
  ('fact_kind', 'appellation',   'Appellation',    53, '{"value_type": "text"}'),
  ('fact_kind', 'buyers',        'Fruit goes to',  54, '{"value_type": "text", "hint": "Wineries that buy from it, as a source names them."}'),
  ('fact_kind', 'history',       'History',        55, '{"value_type": "text"}')
on conflict (kind, value) do update set
  label = excluded.label, attributes = excluded.attributes, active = true;

-- ---------------------------------------------------------------------------
-- Where a claim came from
-- ---------------------------------------------------------------------------

create table if not exists source (
  id           uuid primary key default gen_random_uuid(),
  -- A page somebody could open, or a document this winery holds.
  kind         text not null check (kind in ('web', 'document')),
  title        text not null check (btrim(title) <> ''),
  url          text,
  publisher    text,
  published_on date,
  retrieved_at timestamptz not null default now(),
  note         text,
  created_by   uuid references app_user (id),
  created_at   timestamptz not null default now(),
  -- A web source is a page, and a page has an address. A document may not.
  constraint source_web_has_an_address check (kind <> 'web' or url is not null)
);

comment on table source is
  'A page or a document claims were read from, with when it was read.';

create unique index if not exists source_once on source (kind, coalesce(url, title));

alter table source enable row level security;
create policy source_read on source for select to authenticated using (is_facility_user());
create policy source_admin_write on source for all to authenticated
  using (is_admin()) with check (is_admin());

create table if not exists note_source (
  note_id   uuid primary key references note (id) on delete restrict,
  source_id uuid not null references source (id) on delete restrict,
  -- The source's own words, which is what makes a claim checkable rather
  -- than a paraphrase somebody has to trust.
  excerpt   text not null check (btrim(excerpt) <> ''),
  -- Where in the source: a page, a section, a table.
  locator   text,
  -- Which rows of the block the claim is about, when it is not all of them:
  -- Southeast's rows 1 to 10 were planted in 1989 and 11 to 43 in 1998.
  row_range int4range check (row_range is null or not isempty(row_range))
);

comment on table note_source is
  'Ties a claim to the source it was read from, with the exact words and which rows it covers.';

alter table note_source enable row level security;
create policy note_source_read on note_source for select to authenticated using (is_facility_user());
create policy note_source_admin_write on note_source for all to authenticated
  using (is_admin()) with check (is_admin());

-- ---------------------------------------------------------------------------
-- Recording a claim
-- ---------------------------------------------------------------------------

-- Finds or adds the source, writes the typed note as `inferred`, and ties
-- them. One call, so a claim cannot exist without its source or the other way
-- round. Administrators, or the loader, which runs as the database owner with
-- nobody signed in.
create or replace function record_claim(
  p_subject_type text,
  p_subject_id   uuid,
  p_kind         text,
  p_value        text,
  p_statement    text,
  p_source       jsonb,
  p_excerpt      text,
  p_locator      text default null,
  p_rows         int4range default null,
  p_at           timestamptz default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  kt      term%rowtype;
  src     uuid;
  nid     uuid := gen_random_uuid();
  s_kind  text := p_source ->> 'kind';
  s_title text := nullif(btrim(coalesce(p_source ->> 'title', '')), '');
  s_url   text := nullif(btrim(coalesce(p_source ->> 'url', '')), '');
begin
  if auth.uid() is not null and not is_admin() then
    raise exception 'only an administrator records what a source says about a vineyard'
      using errcode = 'insufficient_privilege';
  end if;
  if p_subject_type not in ('vineyard', 'block', 'vine_row') then
    raise exception 'a claim here is about a vineyard, a block or a row, not a %', p_subject_type;
  end if;
  if resolve_subject_name(p_subject_type, p_subject_id) is null then
    raise exception 'there is no % with id %', p_subject_type, p_subject_id;
  end if;
  select * into kt from term where kind = 'fact_kind' and value = p_kind and active;
  if kt.id is null then
    raise exception 'there is no kind of fact called %', p_kind;
  end if;
  if nullif(btrim(coalesce(p_value, '')), '') is null then
    raise exception 'say what the claim says';
  end if;
  if kt.attributes ->> 'value_type' = 'number' and btrim(p_value) !~ '^-?[0-9]+([.][0-9]+)?$' then
    raise exception '% is a number, and "%" is not one', kt.label, p_value;
  end if;
  if nullif(btrim(coalesce(p_excerpt, '')), '') is null then
    raise exception 'quote the source; a claim without the source''s own words cannot be checked';
  end if;
  if s_kind is null or s_title is null then
    raise exception 'say what the source is: its kind, web or document, and its title';
  end if;

  select id into src from source where kind = s_kind and coalesce(url, title) = coalesce(s_url, s_title);
  if src is null then
    insert into source (kind, title, url, publisher, published_on, retrieved_at, note, created_by)
    values (s_kind, s_title, s_url,
            nullif(btrim(coalesce(p_source ->> 'publisher', '')), ''),
            (p_source ->> 'published_on')::date,
            coalesce((p_source ->> 'retrieved_at')::timestamptz, now()),
            nullif(btrim(coalesce(p_source ->> 'note', '')), ''),
            auth.uid())
    returning id into src;
  end if;

  insert into note (id, subject_type, subject_id, body, by_user, at, kind_id,
                    value_num, value_text, provenance)
  values (nid, p_subject_type, p_subject_id,
          coalesce(nullif(btrim(coalesce(p_statement, '')), ''), kt.label || ': ' || btrim(p_value)),
          auth.uid(), coalesce(p_at, now()), kt.id,
          case when kt.attributes ->> 'value_type' = 'number' then btrim(p_value)::numeric end,
          case when kt.attributes ->> 'value_type' = 'number' then null else btrim(p_value) end,
          'inferred');

  insert into note_source (note_id, source_id, excerpt, locator, row_range)
  values (nid, src, btrim(p_excerpt), nullif(btrim(coalesce(p_locator, '')), ''), p_rows);

  return jsonb_build_object('note_id', nid, 'source_id', src);
end $$;

comment on function record_claim is
  'Records what a source says about a vineyard, block or row as an inferred typed note, with the source and its words.';

grant execute on function record_claim(text, uuid, text, text, text, jsonb, text, text, int4range, timestamptz) to authenticated;

-- Every claim with where it came from, for the vineyard screens and the export.
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
       lower(ns.row_range)                         as row_from,
       upper(ns.row_range) - 1                     as row_to,
       s.id                                   as source_id,
       s.kind                                 as source_kind,
       s.title                                as source_title,
       s.url                                  as source_url,
       s.publisher,
       s.published_on,
       s.retrieved_at,
       n.at,
       n.created_at
  from note n
  join note_source ns on ns.note_id = n.id
  join source s on s.id = ns.source_id
  join term t on t.id = n.kind_id
  left join vineyard v on n.subject_type = 'vineyard' and v.id = n.subject_id
  left join block b on n.subject_type = 'block' and b.id = n.subject_id
  left join vine_row vr on n.subject_type = 'vine_row' and vr.id = n.subject_id
  left join block br on br.id = vr.block_id;

comment on view sourced_claim is
  'Every claim about a vineyard with its kind, value, provenance, the source''s words and where it came from.';

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('vineyard.record_claim', 'vineyard', 'Record what a source says',
   'A fact about a vineyard, block or row, with the page or document it came from and its exact words. Always recorded as inferred; confirming is its own act.',
   'record_claim',
   '[{"key": "subject_type", "type": "text", "label": "About what", "param": "p_subject_type", "required": true},
     {"key": "subject_id", "type": "uuid", "label": "Which one", "param": "p_subject_id", "required": true},
     {"key": "kind", "type": "text", "label": "What kind of fact", "param": "p_kind", "required": true, "source": {"terms": "fact_kind"}},
     {"key": "value", "type": "text", "label": "The value", "param": "p_value", "required": true},
     {"key": "statement", "type": "text", "label": "The claim in a sentence", "param": "p_statement", "required": true,
      "hint": "Blank says the fact and its value."},
     {"key": "source", "type": "jsonb", "label": "The source", "param": "p_source", "required": true,
      "hint": "{\"kind\": \"web\", \"title\": ..., \"url\": ...}"},
     {"key": "excerpt", "type": "text", "label": "Its exact words", "param": "p_excerpt", "required": true},
     {"key": "locator", "type": "text", "label": "Where in it", "param": "p_locator", "required": false},
     {"key": "rows", "type": "text", "label": "Which rows", "param": "p_rows", "required": false},
     {"key": "at", "type": "timestamptz", "label": "As of", "param": "p_at", "required": false}]'::jsonb,
   420)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('vineyard.claims', 'vineyard', 'What sources say',
   'Every claim about a vineyard with its source and the source''s words.',
   'sourced_claim', 'note_id', 'statement', 412)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;
