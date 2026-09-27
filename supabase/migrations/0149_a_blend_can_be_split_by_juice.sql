-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "An administrator can say how a lot really divides between its
--           sources when the pounds going in got it wrong, and the lot's
--           history keeps both answers and why."
-- Depends on: [supabase/migrations/0147_a_pressing_knows_what_went_in.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-5. The shares are corrected in place, because lineage is
--                  the shape every composition is read from and two rows for
--                  one parent would double it; so the event carries the
--                  before and the after, and nothing about what was believed
--                  is lost.
--                  T0-4. Only a person restates a share, and only an
--                  administrator, which is who lineage has always let edit it.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- The Grüner Veltliner and the Müller Thurgau of 2026-09-23 were pressed
-- together on the 24th because yields were light: 1158 lbs and 312 lbs in, so
-- the pressing's lineage said 78.8 and 21.2. The winemaker: "Let's do it by
-- juice because the Müller was quite desiccated and not a lot of juice." About
-- 350 L and 50 L, so 87.5 and 12.5.
--
-- **Pounds are the right default and not always the right answer.** A press
-- splits its lot by the fruit that went in because that is the only figure
-- anybody has at the press. Fruit that has dried on the vine gives less juice
-- per pound than its neighbour, and then the pounds overstate it in every
-- composition read from the lot afterwards, which is the variety on a label.
-- So a person who knows better can restate the shares, and says on what
-- basis: juice, or something else in a note.

insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'restate_shares', 'Shares restated', 725, '{"effect": "measurement"}')
on conflict (kind, value) do update set label = excluded.label, active = true;

create or replace function restate_shares(
  p_node_id uuid,
  p_shares  jsonb,
  p_basis   text default null,
  p_note    text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  before jsonb;
  total  numeric;
  missing text;
  extra  text;
begin
  if not is_admin() then
    raise exception 'only an administrator restates what a lot is made of';
  end if;
  if not exists (select 1 from node where id = p_node_id) then
    raise exception 'there is no lot with that id';
  end if;
  if p_shares is null or jsonb_typeof(p_shares) <> 'object' or p_shares = '{}'::jsonb then
    raise exception 'say each source''s share, by its id';
  end if;

  -- Every current parent named, and nothing else. A share for a lot this one
  -- did not come from would invent a history; leaving one out would erase one.
  select string_agg(n.name, ', ') into missing
    from lineage l join node n on n.id = l.parent_id
   where l.child_id = p_node_id and not (p_shares ? l.parent_id::text);
  if missing is not null then
    raise exception 'say a share for every source: % is missing', missing;
  end if;
  select string_agg(k, ', ') into extra
    from jsonb_object_keys(p_shares) k
   where not exists (select 1 from lineage l where l.child_id = p_node_id and l.parent_id::text = k);
  if extra is not null then
    raise exception '% is not something this lot came from', extra;
  end if;

  select sum((v)::numeric) into total from jsonb_each_text(p_shares) as s(k, v);
  if exists (select 1 from jsonb_each_text(p_shares) as s(k, v) where (v)::numeric <= 0) then
    raise exception 'every source gave something, so every share is above nothing';
  end if;
  if abs(total - 1) > 0.001 then
    raise exception 'the shares add up to %, and a whole is 1', round(total, 4);
  end if;

  select jsonb_object_agg(l.parent_id, l.fraction) into before
    from lineage l where l.child_id = p_node_id;

  update lineage l
     set fraction = round((p_shares ->> l.parent_id::text)::numeric, 6)
   where l.child_id = p_node_id;

  insert into event (operation_id, subject_type, subject_id, by_user, provenance, data)
  values (term_id('operation', 'restate_shares'), 'node', p_node_id, auth.uid(), 'observed',
          jsonb_strip_nulls(jsonb_build_object(
            'before', before,
            'after',  p_shares,
            'basis',  nullif(btrim(p_basis), ''),
            'note',   nullif(btrim(p_note), ''))));

  return jsonb_build_object('node_id', p_node_id, 'before', before, 'after', p_shares);
end $$;

comment on function restate_shares is
  'Says how a lot really divides between its sources, keeping the old shares in the event.';

grant execute on function restate_shares(uuid, jsonb, text, text) to authenticated;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('cellar.restate_shares', 'cellar', 'Restate what a lot is made of',
   'When the pounds going in got the split wrong: fruit that dried on the vine gives less juice than it weighs. Administrators only; the old shares stay in the history.',
   'restate_shares',
   '[{"key": "lot", "type": "uuid", "label": "Which lot", "param": "p_node_id", "required": true},
     {"key": "shares", "type": "jsonb", "label": "Each source''s share", "param": "p_shares", "required": true,
      "hint": "By source id, adding to 1."},
     {"key": "basis", "type": "text", "label": "On what basis", "param": "p_basis", "required": false,
      "hint": "juice, for instance."},
     {"key": "note", "type": "text", "label": "Why", "param": "p_note", "required": false}]'::jsonb,
   126)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;
