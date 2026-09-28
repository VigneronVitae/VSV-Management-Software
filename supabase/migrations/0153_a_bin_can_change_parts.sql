-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A bin recorded in the wrong part of a pick can be moved to the
--           right one before it is weighed, and the move stays in both picks'
--           histories."
-- Depends on: [supabase/migrations/0146_harvest_weights.sql,
--              supabase/migrations/0143_a_record_can_say_when.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts, scripts/smoke.ts,
--                  supabase/migrations/0155_doctor.sql]
-- Axioms enforced: T0-5. The bin's placement changes pick, which is the one
--                  column a cellar hand has always been allowed to change on
--                  it, so the move is written as an event on both picks, with
--                  the bins, where they came from and where they went.
--                  A13. A weighed bin is refused in a sentence, not moved
--                  without its weight.
-- Open sorries: S-149 (a weighed bin cannot move).
-- ---------------------------------------------------------------------------

-- The Pinot Noir of 2026-09-23 came off one block, "Overlook Pommard and 777",
-- as nine bins in one pick. The vineyard module already knew rows 1 to 28 are
-- Pommard and 29 to 53 are 777, and the bins were labelled with the fruit in
-- them, but the pick could not say which bin was which, so the scale sheet
-- could not either. The winemaker weighed three and wrote "Pom" in the note.
--
-- The block is split in two along those rows, in the cellar, as data: each
-- clone becomes its own block, and a pick is already one block and one
-- variety, so each clone is its own pick with no new field. What was missing
-- is the correction: a bin that went into the wrong part. That is this verb.
--
-- **Only between picks that could be the same fruit's.** Same owner, same
-- vintage, both still bins. A bin moved to somebody else's fruit is a change
-- of ownership, which is `reassign_owner`'s job and says so.
--
-- **Only unweighed bins.** See S-149.

insert into term (kind, value, label, sort_order, attributes) values
  ('operation', 'bins_moved', 'Bins moved to another part', 726, '{"effect": "measurement"}')
on conflict (kind, value) do update set label = excluded.label, active = true;

-- Which picks the bins of this one could move to. The rule the verb applies,
-- said once, so the scale screen offers exactly the picks the verb accepts.
-- The same picking day first, because that is nearly always the answer.
create or replace function pick_siblings(p_node_id uuid)
returns table (id uuid, name text, block text, variety text, picked date, bins bigint)
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select f.id, f.name, f.block, f.variety, f.picked, f.bins_held
    from fruit_log f
    join node n on n.id = f.id
    join node me on me.id = p_node_id
   where f.id <> p_node_id
     and n.status <> 'closed'
     and n.owner_id = me.owner_id
     and n.vintage is not distinct from me.vintage
   order by f.picked = (select picked from fruit_log where id = p_node_id) desc,
            f.picked desc, f.name;
$$;

comment on function pick_siblings is
  'The open picks a bin of this one could be moved to: same owner, same vintage.';

grant execute on function pick_siblings(uuid) to authenticated;

create or replace function move_bins_to_pick(
  p_vessel_ids uuid[],
  p_to_node    uuid,
  p_note       text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  target  node%rowtype;
  source  node%rowtype;
  sources uuid[];
  missing text;
  weighed text;
  moved   int;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here says which pick a bin belongs to'
      using errcode = 'insufficient_privilege';
  end if;
  if p_vessel_ids is null or cardinality(p_vessel_ids) = 0 then
    raise exception 'say which bins';
  end if;

  select * into target from node where id = p_to_node;
  if target.id is null then
    raise exception 'there is no pick with that id';
  end if;
  if target.stage <> 'bin' then
    raise exception '% is not a pick, so bins cannot move into it', target.name;
  end if;
  if target.status = 'closed' then
    raise exception '% is closed; its fruit has already gone somewhere', target.name;
  end if;

  select string_agg(v.name, ', ') into missing
    from vessel v
   where v.id = any (p_vessel_ids)
     and not exists (
       select 1 from placement p join node n on n.id = p.node_id
        where p.vessel_id = v.id and p.to_at is null
          and n.stage = 'bin' and n.status <> 'closed');
  if missing is not null then
    raise exception '% % not holding fruit from a pick',
      missing, case when missing like '%,%' then 'are' else 'is' end;
  end if;

  select array_agg(distinct p.node_id) into sources
    from placement p
   where p.vessel_id = any (p_vessel_ids) and p.to_at is null;
  if cardinality(sources) > 1 then
    raise exception 'those bins are from different picks; move one pick''s bins at a time';
  end if;
  select * into source from node where id = sources[1];
  if source.id = target.id then
    raise exception 'those bins are already part of %', target.name;
  end if;
  if source.owner_id <> target.owner_id then
    raise exception
      '% and % are different owners'' fruit; changing whose fruit it is is Owner corrected, not a move',
      source.name, target.name;
  end if;
  if source.vintage is distinct from target.vintage then
    raise exception '% and % are different vintages', source.name, target.name;
  end if;

  -- S-149. A standing reading that names the bin, the same test unweighed_bin
  -- uses, so a bin the scale screen offers is a bin this accepts.
  select string_agg(v.name, ', ') into weighed
    from vessel v
   where v.id = any (p_vessel_ids)
     and not exists (select 1 from unweighed_bin u where u.vessel_id = v.id);
  if weighed is not null then
    raise exception
      '% % been weighed as part of %. A reading is of one pick''s fruit, so a weighed bin stays where it was weighed',
      weighed, case when weighed like '%,%' then 'have' else 'has' end, source.name;
  end if;

  update placement
     set node_id = target.id
   where vessel_id = any (p_vessel_ids) and to_at is null and node_id = source.id;
  get diagnostics moved = row_count;

  insert into event (operation_id, subject_type, subject_id, by_user, provenance, data)
  select term_id('operation', 'bins_moved'), 'node', s, auth.uid(), 'observed',
         jsonb_strip_nulls(jsonb_build_object(
           'bins', to_jsonb(p_vessel_ids),
           'from', source.id,
           'to',   target.id,
           'note', nullif(btrim(p_note), '')))
    from unnest(array[source.id, target.id]) s;

  return jsonb_build_object(
    'moved',     moved,
    'from',      source.id,
    'from_name', source.name,
    'from_bins', (select count(*) from placement where node_id = source.id and to_at is null),
    'to',        target.id,
    'to_name',   target.name,
    'to_bins',   (select count(*) from placement where node_id = target.id and to_at is null));
end $$;

comment on function move_bins_to_pick is
  'Moves unweighed bins recorded in the wrong part of a pick to the right one, '
  'writing the move into both picks'' histories.';

grant execute on function move_bins_to_pick(uuid[], uuid, text) to authenticated;

insert into capability_exemption (fn, reason) values
  ('pick_siblings', 'Lists the picks a bin could move to. Read by the scale screen to offer exactly what move_bins_to_pick accepts; it changes nothing.')
on conflict (fn) do update set reason = excluded.reason;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('cellar.move_bins_to_pick', 'cellar', 'Move bins to another part of a pick',
   'For a bin recorded in the wrong part, the 777 under the Pommard. Unweighed bins only; the move is kept in both picks'' histories.',
   'move_bins_to_pick',
   '[{"key": "bins", "type": "uuid[]", "label": "Which bins", "param": "p_vessel_ids", "required": true},
     {"key": "to", "type": "uuid", "label": "Into which pick", "param": "p_to_node", "required": true},
     {"key": "note", "type": "text", "label": "Why", "param": "p_note", "required": false}]'::jsonb,
   127)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;
