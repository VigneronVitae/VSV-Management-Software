-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Moving vessels is one act on a set of them, and it is called
--           move_vessels because it moves vessels and not only bins."
-- Depends on: [supabase/migrations/0044_finishing_a_pick.sql,
--              supabase/migrations/0057_the_contract.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-3 (the column says where a vessel is and the event says
--                  when it got there), AR-Q8 (declared once, so the screen that
--                  does it in a batch is not a second opinion about what a move
--                  is)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"There should also be a batch option for things like moving
-- barrels. Like I'd love to be able to select 6 barrels to move to a new room,
-- or put the 5 picking bins in the south bay, etc, without doing it
-- individually."*
--
-- **The kernel has done this since `0044` and no screen has ever called it.**
-- `move_bins` takes an array of vessel ids and a location, updates each and
-- writes a `move_vessel` event for each. It was written for cold storage, it
-- never checked that a vessel was a bin, and it has sat with two assertions
-- over it, no screen above it, and an exemption in the contract reading "not
-- yet declared". Asserted and unreachable is its own kind of finished: the
-- suite proved the act works and nobody could perform it.
--
-- So there are two things wrong and neither is the batch.
--
-- **The name lies.** A barrel moved by a function called `move_bins` is a
-- barrel moved by a function that says it does something else. The bins were
-- the first caller, not the subject.
--
-- **It was never declared**, so no periphery could find it, which is exactly
-- how a capability ends up with no screen for four sessions.
--
-- The body is unchanged apart from one added guard. `move_bins` is dropped
-- rather than kept as an alias: nothing calls it, and a second name for one act
-- is a call nobody can choose between.

begin;

create or replace function move_vessels(
  p_vessel_ids  uuid[],
  p_location_id uuid
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  v_id  uuid;
  moved int := 0;
  place text;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here moves vessels'
      using errcode = 'insufficient_privilege';
  end if;

  if coalesce(array_length(p_vessel_ids, 1), 0) = 0 then
    raise exception 'no vessels were named, so there is nothing to move';
  end if;

  select name into place from location where id = p_location_id;
  if place is null then
    raise exception 'there is no such location to move them to';
  end if;

  foreach v_id in array p_vessel_ids
  loop
    update vessel set location_id = p_location_id where id = v_id and active;
    if not found then
      -- The whole batch fails rather than part of it. Six barrels selected and
      -- five moved is a state nobody asked for and nobody would notice: the
      -- screen would say it worked and one barrel would be in the wrong room.
      raise exception 'no active vessel with id %', v_id;
    end if;
    -- The column says where it is and the event says when it got there. The
    -- second is the one that answers how long fruit sat in the cold.
    insert into event (operation_id, subject_type, subject_id, by_user, provenance, data)
    values (term_id('operation', 'move_vessel'), 'vessel', v_id, auth.uid(), 'observed',
            jsonb_build_object('location_id', p_location_id));
    moved := moved + 1;
  end loop;

  return jsonb_build_object('moved', moved, 'location_id', p_location_id,
                            'location', place);
end;
$$;

revoke all on function move_vessels(uuid[], uuid) from public;
grant execute on function move_vessels(uuid[], uuid) to authenticated;

-- Nothing called it, so nothing breaks. A second name for one act is a call
-- nobody can choose between, which 0036, 0068 and 0087 each paid for once.
drop function if exists move_bins(uuid[], uuid);
delete from capability_exemption where fn = 'move_bins';

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.rooms_to_move_to', 'cellar', 'Rooms',
   'Where a vessel can be moved to.',
   'room_climate', 'id', 'name', 155)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('cellar.move_vessels', 'cellar', 'Move vessels to a room',
   'Any number of them at once. Six barrels to a new room, or five bins to the '
   'south bay, is one act rather than six.',
   'move_vessels', 'cellar.vessels',
   '[{"key":"vessels","param":"p_vessel_ids","type":"uuid[]","required":true,
      "label":"Which ones",
      "source":{"readable":"cellar.vessels"}},
     {"key":"room","param":"p_location_id","type":"uuid","required":true,
      "label":"Where they are going",
      "source":{"readable":"cellar.rooms_to_move_to"}}]'::jsonb, 260)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

commit;
