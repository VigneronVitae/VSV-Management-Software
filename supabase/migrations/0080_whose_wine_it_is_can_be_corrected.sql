-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Whose wine a lot is can be corrected after it is recorded, by a
--           path that leaves an event behind, because it decides who can see
--           the wine and it was until now unchangeable."
-- Depends on: [supabase/migrations/0018_lot_privacy.sql,
--              supabase/migrations/0057_the_contract.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-3 (a correction to whose wine it is leaves a record of
--                  who said so and when), T0-5 (the correction is a new event
--                  rather than a quiet overwrite)
-- Open sorries: S-81 (children are not carried along)
-- ---------------------------------------------------------------------------
--
-- The winemaker, looking at a pick recorded an hour earlier: *"owner of the
-- chardonnay is Amica Luna in the Pearlstaad bins."* The pick is named
-- "2026 Chardonnay Pearlstaad Amica Luna" and is owned by Vitae Springs,
-- because the owner is chosen when the bins are recorded and picking fruit into
-- bins is the fastest thing anybody does all day.
--
-- **There was no way to fix it.** Eighteen functions read `owner_id` and every
-- one that writes it writes it at creation: `add_bins_to_pick`, `fill_vessel`,
-- `create_vessel_with_wine`, `fork_lot`. Nothing could change it afterwards, so
-- the only remedy was an update straight against the table, which is the thing
-- this repository exists to avoid.
--
-- **This is not cosmetic.** `owner_id` is what `visible_node` reads: it decides
-- whether a custom crush client sees a lot at all. A lot filed under the wrong
-- party is either a client who cannot see their own fruit or, worse, a client
-- who can see somebody else's. So the correction records who made it, which
-- `update node set owner_id` never would.
--
-- **Descendants are not carried along, and that is S-81.** This pick has no
-- children yet. One that does would have pressed into a lot that took a copy of
-- the owner at the moment it was created, and walking the lineage to rewrite
-- those is a bigger decision than this: a child can legitimately belong to
-- somebody else, which is what a custom crush arrangement looks like when fruit
-- is sold mid-process. So this counts them and says so, rather than guessing.

begin;

insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'reassign', 'Owner corrected', 72,
   -- Measurement, which is the closest this vocabulary has to "a fact about the
   -- record rather than about the wine". Nothing was done to the wine: somebody
   -- wrote down the wrong party and somebody else noticed.
   '{"effect": "measurement"}'::jsonb)
on conflict (kind, value) do nothing;

create or replace function set_lot_owner(
  p_node_id  uuid,
  p_owner_id uuid,
  p_note     text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  n       node%rowtype;
  o       party%rowtype;
  was     uuid;
  kids    int;
  eid     uuid;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here says whose wine a lot is'
      using errcode = 'insufficient_privilege';
  end if;

  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no lot with id %', p_node_id;
  end if;

  select * into o from party where id = p_owner_id;
  if o.id is null then
    raise exception 'no party with id %', p_owner_id;
  end if;
  if not o.active then
    raise exception
      '% is not an active party, and filing wine under a retired one is how it goes missing', o.name;
  end if;

  was := n.owner_id;

  if was = p_owner_id then
    -- Not a refusal. Nothing needed doing and saying so is more useful than
    -- either an error or a silent success that looks like a change.
    return jsonb_build_object('id', p_node_id, 'owner', o.name, 'changed', false);
  end if;

  update node set owner_id = p_owner_id where id = p_node_id;

  -- The record of the correction. Without this the column simply reads
  -- differently one day than it did the day before, with nothing to say why,
  -- and whose wine it is, is the one thing a client will one day ask about.
  insert into event (subject_type, subject_id, operation_id, by_user, data)
  values ('node', p_node_id, term_id('operation', 'reassign'), auth.uid(),
          jsonb_build_object('from', was, 'to', p_owner_id,
                             'note', nullif(btrim(coalesce(p_note, '')), '')))
  returning id into eid;

  -- Everything that came off this lot and still carries the old party. Counted
  -- rather than changed: see S-81 and the header.
  with recursive down as (
    select l.child_id as id from lineage l where l.parent_id = p_node_id
    union all
    select l.child_id from down d join lineage l on l.parent_id = d.id
  )
  select count(*) into kids
    from down d join node c on c.id = d.id
   where c.owner_id is not distinct from was;

  return jsonb_build_object(
    'id', p_node_id, 'owner', o.name, 'changed', true, 'event', eid,
    'descendants_still_on_the_old_owner', kids);
end;
$$;

revoke all on function set_lot_owner(uuid, uuid, text) from public;
grant execute on function set_lot_owner(uuid, uuid, text) to authenticated;

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('cellar.set_lot_owner', 'cellar', 'Say whose wine a lot is',
   'Corrects the party a lot is filed under. It decides who can see the wine, '
   'so the change records who made it.',
   'set_lot_owner', 'cellar.lot_detail',
   '[{"key":"lot","param":"p_node_id","type":"uuid","required":true,
      "label":"Which lot",
      "source":{"readable":"cellar.lot_detail"}},
     {"key":"owner","param":"p_owner_id","type":"uuid","required":true,
      "label":"Whose it is"},
     {"key":"note","param":"p_note","type":"text","required":false,
      "label":"Why",
      "note":"What was wrong, for whoever reads this back."}]'::jsonb, 240)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

commit;
