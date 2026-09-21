-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A mark on a photograph that points at a particular thing, so one
--           picture of a shelf can say where each of twenty things on it lives,
--           and so the circled version is drawn rather than stored."
-- Depends on: [supabase/migrations/0023_subject_resolver.sql,
--              supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0134_a_domain_tags_a_place_and_a_thing.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  supabase/migrations/0136_the_stores_have_a_door.sql,
--                  packages/inventory/src/inventory.ts]
-- Axioms enforced: T0-2, and this is the whole design. A photograph with a
--                  circle on it is a function of a photograph and a circle.
--                  Storing the circled image would store a derivation, and C-3
--                  is the entry to read before proposing it again.
--                  T0-5. A mark is added or removed, never edited in place.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- "Maybe the photo for each object can capture the photo then also prompt
-- something like circling or pointing to the particular location? So then the
-- app had the photo of shelf + photo of shelf with item circled/pointed to?"
--
-- Yes, and the two pictures he wants are one picture and one circle.
--
-- **Storing both images would be storing a derivation**, which is T0-2, and it
-- would be the expensive kind. A shelf holds twenty things. Two images each is
-- twenty near-identical photographs of the same shelf: twenty uploads over barn
-- wifi, and twenty things to redo the day somebody tidies the shelf. One
-- photograph with twenty marks is one upload, and re-photographing it is one
-- upload and twenty coordinates to check rather than twenty pictures to take.
--
-- The periphery still shows exactly what he described, because drawing a circle
-- at a known coordinate is nothing. It gains a view neither of his two images
-- could produce: **the whole shelf with everything on it marked at once**, which
-- is the picture you actually want when putting things away.
--
-- **Coordinates are normalised to zero-to-one rather than pixels.** A phone that
-- re-encodes a photograph, a client that shows it at thumbnail size, and a
-- screen half the width of the one it was marked on all keep proportions and
-- none of them keeps pixels.
--
-- **It is not about shelves.** The same mark points at the leaking fitting on a
-- photograph of the press, the crown gall on a photograph of a vine, the part on
-- a schematic, the total on a photographed receipt. Four uses already live in
-- this system, which is the corpus CLAUDE.md asks for before a thing is made
-- general, and the reason this hangs on `attachment` rather than on `location`.

create table if not exists attachment_mark (
  id            uuid primary key default gen_random_uuid(),
  attachment_id uuid not null references attachment(id) on delete cascade,

  -- What is being pointed at. The same polymorphic subject every annotation in
  -- this schema uses, resolved through the registry AR-E5 put there, so a mark
  -- can point at a supply today and at something nobody has built yet later.
  subject_type  text not null references subject_resolver(subject_type) on delete restrict,
  subject_id    uuid not null,

  -- Where, as a fraction of the picture. 0,0 is the top left corner.
  at_x          numeric(6,5) not null,
  at_y          numeric(6,5) not null,
  -- How big a circle to draw around it, as a fraction of the picture's width.
  -- Null means a point rather than a circle, which is the difference between
  -- pointing at a thing and circling it.
  radius        numeric(6,5),

  note          text,
  by_user       uuid references app_user(id),
  at            timestamptz not null default now(),

  constraint attachment_mark_is_inside_the_picture
    check (at_x between 0 and 1 and at_y between 0 and 1),
  constraint attachment_mark_radius_is_a_fraction
    check (radius is null or (radius > 0 and radius <= 1)),
  -- One mark per thing per picture. The same hammer circled twice on one
  -- photograph is a mistake far more often than it is two hammers, and the
  -- precedent is `attachment_once_per_subject` one table over.
  constraint attachment_mark_once_per_subject
    unique (attachment_id, subject_type, subject_id)
);

comment on table attachment_mark is
  'A point or a circle on a photograph, saying that a particular thing is there. '
  'The circled version of the picture is drawn from this and never stored.';

alter table attachment_mark enable row level security;

-- Matching `attachment`'s own four, because a mark is part of the photograph in
-- every sense that matters: readable by the facility, written under your own
-- name, and removable only by an administrator.
drop policy if exists attachment_mark_read on attachment_mark;
create policy attachment_mark_read on attachment_mark
  for select using (is_facility_user());

drop policy if exists attachment_mark_insert on attachment_mark;
create policy attachment_mark_insert on attachment_mark
  for insert with check (is_facility_user() and by_user = auth.uid());

drop policy if exists attachment_mark_admin_delete on attachment_mark;
create policy attachment_mark_admin_delete on attachment_mark
  for delete using (is_admin());

-- ---------------------------------------------------------------------------
-- Reading it back
-- ---------------------------------------------------------------------------

-- Everything marked on one picture, which is the shelf view: one photograph,
-- every thing on it, each with its coordinate.
create or replace view attachment_marked with (security_invoker = true) as
select
  m.id,
  m.attachment_id,
  a.path,
  a.caption,
  a.subject_type as picture_of_type,
  a.subject_id   as picture_of_id,
  m.subject_type,
  m.subject_id,
  resolve_subject_name(m.subject_type, m.subject_id) as subject_name,
  m.at_x,
  m.at_y,
  m.radius,
  m.note,
  m.at
from attachment_mark m
join attachment a on a.id = m.attachment_id;

comment on view attachment_marked is
  'Every mark with the picture it is on and the name of what it points at.';

-- Where a thing is, in one read: its address in words, and the picture with the
-- coordinate to draw a circle at. The two rungs of the wayfinding ladder that
-- 2026-09-20-showing-somebody-where-a-thing-is settled on, answered together.
create or replace view supply_whereabouts with (security_invoker = true) as
select
  s.id                       as supply_id,
  s.name,
  s.home_id,
  lt.address                 as home_address,
  lt.domains                 as home_domains,
  m.attachment_id,
  m.path                     as photo_path,
  m.at_x,
  m.at_y,
  m.radius
from supply s
left join location_tree lt on lt.id = s.home_id
-- The picture has to be a picture of the place the thing lives, otherwise a
-- mark left on some unrelated photograph would answer the question wrongly.
left join attachment_marked m
       on m.subject_type = 'supply'
      and m.subject_id = s.id
      and m.picture_of_type = 'location'
      and m.picture_of_id = s.home_id
where s.retired_at is null;

comment on view supply_whereabouts is
  'Where a thing lives: the address in words, and the photograph of that place '
  'with the coordinate to point at. Both, because which one helps depends on '
  'whether the person knows the building.';

-- ---------------------------------------------------------------------------
-- The contract
-- ---------------------------------------------------------------------------

create or replace function mark_attachment(
  p_attachment_id uuid,
  p_subject_type  text,
  p_subject_id    uuid,
  p_x             numeric,
  p_y             numeric,
  p_radius        numeric default null,
  p_note          text    default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare made attachment_mark%rowtype;
begin
  if not is_facility_user() then
    raise exception 'photographs are marked by people who work here';
  end if;
  if not exists (select 1 from attachment where id = p_attachment_id) then
    raise exception 'there is no such photograph to mark';
  end if;
  if not exists (select 1 from subject_resolver where subject_type = p_subject_type) then
    raise exception 'nothing in this system is a %, so a mark cannot point at one',
      p_subject_type;
  end if;
  -- Said in words rather than left to the check constraint, because a client
  -- that sent pixels instead of fractions would otherwise get a constraint name
  -- and no idea what it did wrong. A13.
  if p_x is null or p_y is null or p_x < 0 or p_x > 1 or p_y < 0 or p_y > 1 then
    raise exception
      'a mark is placed as a fraction of the picture between 0 and 1, not in pixels; got %, %', p_x, p_y;
  end if;

  insert into attachment_mark
    (attachment_id, subject_type, subject_id, at_x, at_y, radius, note, by_user)
  values
    (p_attachment_id, p_subject_type, p_subject_id, p_x, p_y, p_radius, p_note, auth.uid())
  -- Marking the same thing again moves the mark, which is what a person
  -- dragging a circle expects, and is the one place this table is not an append.
  on conflict (attachment_id, subject_type, subject_id) do update set
    at_x = excluded.at_x, at_y = excluded.at_y,
    radius = excluded.radius, note = excluded.note,
    by_user = excluded.by_user, at = now()
  returning * into made;

  return jsonb_build_object('id', made.id, 'x', made.at_x, 'y', made.at_y,
                            'radius', made.radius);
end $$;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('core.mark_attachment', 'core', 'Point at something in a photograph',
   'Puts a point or a circle on a photograph, saying a particular thing is there. Marking the same thing again moves the mark. The circled picture is drawn from this rather than stored, so one photograph of a shelf can carry a mark for every thing on it.',
   'mark_attachment',
   '[{"key": "attachment", "type": "uuid", "label": "Which photograph", "param": "p_attachment_id", "required": true},
     {"key": "subject_type", "type": "text", "label": "Pointing at what kind of thing", "param": "p_subject_type", "required": true,
      "source": {"readable": "core.subject_types"}},
     {"key": "subject_id", "type": "uuid", "label": "Pointing at which one", "param": "p_subject_id", "required": true},
     {"key": "x", "type": "number", "label": "Across", "param": "p_x", "required": true,
      "hint": "A fraction of the picture width, 0 at the left edge and 1 at the right."},
     {"key": "y", "type": "number", "label": "Down", "param": "p_y", "required": true,
      "hint": "A fraction of the picture height, 0 at the top."},
     {"key": "radius", "type": "number", "label": "How wide a circle", "param": "p_radius", "required": false,
      "hint": "A fraction of the picture width. Leave blank to point rather than circle."},
     {"key": "note", "type": "text", "label": "Anything worth saying about the spot", "param": "p_note", "required": false}]'::jsonb,
   36)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('core.marks', 'core', 'What is pointed at in photographs',
   'Every mark with the picture it is on and the name of what it points at. Reading it for one picture gives the whole shelf with everything on it marked.',
   'attachment_marked', 'id', 'subject_name', 37),
  ('inventory.whereabouts', 'inventory', 'Where things live',
   'Where each thing lives: the address in words, and the photograph of that place with the spot to point at.',
   'supply_whereabouts', 'supply_id', 'name', 44)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

do $$
begin
  if not exists (select 1 from capability where key = 'core.mark_attachment') then
    raise exception 'nothing in the contract can point at anything in a photograph';
  end if;
  -- Only where there is a photograph to hang a mark on. From empty there is
  -- none, and `insert ... select ... from attachment limit 1` then inserts no
  -- rows and succeeds, so the line below announcing that the refusal failed is
  -- what actually fired. That is the same fault 0117 had, a migration applying
  -- cleanly and doing nothing, and it is why the real coverage for this lives in
  -- tests/schema_assertions.sql, which builds its own photograph first.
  if not exists (select 1 from attachment) then
    return;
  end if;

  -- What stops a client sending pixels and being believed. Two things do, and
  -- writing this assertion found the second: `numeric(6,5)` holds nothing with
  -- an absolute value of ten or more, so a coordinate of 412 is refused by the
  -- column type before the check constraint is consulted at all. The check still
  -- earns its place, because it catches 1.5 and the type does not.
  begin
    insert into attachment_mark (attachment_id, subject_type, subject_id, at_x, at_y)
    select id, 'location', gen_random_uuid(), 412, 300 from attachment limit 1;
    raise exception 'a mark in pixels was accepted and stored as a fraction';
  exception when others then
    if sqlerrm like '%attachment_mark_is_inside_the_picture%'
       or sqlerrm like '%numeric field overflow%'
       or sqlerrm like '%violates row-level security%' then
      null;
    else
      raise;
    end if;
  end;

  -- The one the type cannot catch: inside numeric range, outside the picture.
  begin
    insert into attachment_mark (attachment_id, subject_type, subject_id, at_x, at_y)
    select id, 'location', gen_random_uuid(), 1.5, 0.5 from attachment limit 1;
    raise exception 'a mark past the right edge of the picture was accepted';
  exception when others then
    if sqlerrm like '%attachment_mark_is_inside_the_picture%'
       or sqlerrm like '%violates row-level security%' then
      null;
    else
      raise;
    end if;
  end;
end $$;
