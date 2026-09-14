-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A pick that did not happen, and a pick that never should have
--           existed, are two different things and only one of them leaves a
--           record."
-- Depends on: [supabase/migrations/0013_close_on_empty.sql,
--              supabase/migrations/0033_intake.sql,
--              supabase/migrations/0037_export.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0039_vineyard.sql]
-- Axioms enforced: T0-5 (append only: a cancelled pick keeps its weighings),
--                  T1-4 (intake must be fast before it is complete, which
--                  means a wrong start has to be cheap to undo)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- Asked for on the first pick: a pick started to see how the screen worked, for
-- fruit that is actually arriving tomorrow.
--
-- **Two verbs, because there are two situations and one answer would be wrong
-- for both.**
--
-- `cancel_pick` is the cellar one. The fruit did not come, or it came from
-- somewhere else, or the wrong block was tapped after the bins were already
-- weighed. It frees the bins and takes the pick off the list, and it keeps
-- everything that was ever measured, because a weighing is an observation and
-- T0-5 says observations are not unmade. Any facility user may do it.
--
-- `remove_pick` is the administrator one, and it is narrow on purpose: a pick
-- that was cancelled, that nothing was ever weighed into, and that nothing
-- descends from. Such a row contains no observation at all, so deleting it
-- destroys no record, which is the only condition under which deleting is
-- honest. Everything else refuses.
--
-- The split falls out of the schema rather than being imposed on it: `node` has
-- `node_admin_delete` and a cellar update allow-list that already includes
-- `status` and `attributes`. So a cellar hand can say a pick did not happen and
-- only an administrator can make one disappear, without either rule being
-- written twice.

begin;

create or replace function cancel_pick(
  p_node_id uuid,
  p_reason  text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  n      node%rowtype;
  freed  int := 0;
  weighs int := 0;
begin
  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no pick with id %', p_node_id;
  end if;
  if n.stage <> 'bin' then
    raise exception '% is not a pick, so cancelling it is not the right word', n.name;
  end if;
  if coalesce((n.attributes ->> 'cancelled')::boolean, false) then
    raise exception '% was already cancelled', n.name;
  end if;

  -- The fruit went through a press and became something else. Undoing that is
  -- not a cancellation, it is a correction to the press, and pretending
  -- otherwise would leave a lot whose parent says it never happened.
  if exists (select 1 from lineage where parent_id = p_node_id) then
    raise exception
      '% has already been pressed, so it cannot be cancelled. Correct the press instead', n.name;
  end if;

  select count(*) into weighs
    from event
   where subject_type = 'node' and subject_id = p_node_id
     and operation_id = term_id('operation', 'weigh');

  -- The bins come back. This is most of what cancelling is for: a bin held by a
  -- pick that is not happening is a bin nobody can fill.
  update placement set to_at = now()
   where node_id = p_node_id and to_at is null;
  get diagnostics freed = row_count;

  update node
     set status = 'closed',
         closed_at = coalesce(closed_at, now()),
         attributes = attributes || jsonb_strip_nulls(jsonb_build_object(
           'cancelled', true,
           'cancelled_at', now(),
           'cancelled_reason', nullif(btrim(coalesce(p_reason, '')), '')))
   where id = p_node_id;

  return jsonb_build_object(
    'node_id',     p_node_id,
    'bins_freed',  freed,
    -- Said out loud, because it decides whether this row can be removed
    -- afterwards and because a person who weighed fruit into a pick they are
    -- now cancelling should see that the weighings are still there.
    'weighings_kept', weighs
  );
end;
$$;

-- Narrow on purpose. Everything this refuses is a row that contains something
-- somebody observed, and an observation is not a typo.
create or replace function remove_pick(p_node_id uuid)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  n      node%rowtype;
  weighs int;
  gone   int := 0;
begin
  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no pick with id %', p_node_id;
  end if;
  if n.stage <> 'bin' then
    raise exception '% is not a pick', n.name;
  end if;
  if not coalesce((n.attributes ->> 'cancelled')::boolean, false) then
    raise exception
      '% has not been cancelled. Cancel it first, so that removing it is a second decision rather than the same one', n.name;
  end if;
  if exists (select 1 from lineage where parent_id = p_node_id or child_id = p_node_id) then
    raise exception '% is part of a lineage, so removing it would orphan something', n.name;
  end if;

  select count(*) into weighs
    from event
   where subject_type = 'node' and subject_id = p_node_id
     and operation_id = term_id('operation', 'weigh');
  if weighs > 0 then
    raise exception
      '% has % weighing(s) recorded against it. Those are observations and they are not removed; the cancelled pick stays',
      n.name, weighs;
  end if;

  -- Any other event at all. The weigh check above names the common case in
  -- words somebody will understand; this one catches everything else rather
  -- than letting it be deleted quietly.
  if exists (select 1 from event where subject_type = 'node' and subject_id = p_node_id) then
    raise exception '% has events recorded against it, so it is a record rather than a mistake', n.name;
  end if;

  delete from placement where node_id = p_node_id;
  delete from node where id = p_node_id;
  get diagnostics gone = row_count;

  -- Deleting is admin only by policy, and a caller who may not delete gets no
  -- rows removed rather than an error, which would look like success. So the
  -- outcome is checked rather than assumed.
  if gone = 0 then
    raise exception 'that pick was not removed. Removing a pick is something only an administrator may do';
  end if;

  return jsonb_build_object('node_id', p_node_id, 'removed', true);
end;
$$;

commit;
