-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A pick whose fruit is in the press cannot be pressed a second time."
-- Depends on: [supabase/migrations/0052_press_as_a_process.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0090_a_press_takes_bins.sql]
-- Axioms enforced: none. This is a defect fix.
-- ---------------------------------------------------------------------------
--
-- `0052` shipped with a hole that an assertion found within the hour, which is
-- the only good thing about it.
--
-- Starting a press empties the bins and leaves the pick's `quantity` alone,
-- because how much fruit it was is history worth keeping. `close_node_when_empty`
-- only fires on a quantity at or below zero, so the pick stayed open. Once the
-- press was finished and the press vessel was free, **the same pick could be
-- started again**, producing a second load made of fruit that was already juice.
-- Nothing would have refused it and the lineage would have looked reasonable.
--
-- Two changes, because either alone leaves a way in. The pick is closed when its
-- fruit goes into the press, which is what "its fruit has already gone
-- somewhere" already claimed. And a source with nothing in any vessel is refused
-- outright, which catches the same shape arriving by any other route.

begin;

create or replace function start_press(
  p_source_ids      uuid[],
  p_press_vessel_id uuid,
  p_node            jsonb default '{}'::jsonb,
  p_detail          jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  n_src        int := coalesce(array_length(p_source_ids, 1), 0);
  parent_stage node_stage;
  child_stage  node_stage;
  n            node%rowtype;
  total_lbs    numeric := 0;
  load_id      uuid := coalesce((p_node ->> 'id')::uuid, gen_random_uuid());
  ev_id        uuid := gen_random_uuid();
  src          uuid;
  emptied      int := 0;
  unweighed    int := 0;
  first_name   text;
begin
  if n_src = 0 then
    raise exception 'nothing was named to press';
  end if;
  if p_press_vessel_id is null then
    raise exception 'say which press this is going into, so the fruit is somewhere';
  end if;
  if not exists (select 1 from vessel where id = p_press_vessel_id and active) then
    raise exception 'that press is not an active vessel';
  end if;
  if exists (select 1 from placement
              where vessel_id = p_press_vessel_id and to_at is null) then
    raise exception
      'that press already has a load in it; finish that press before starting another';
  end if;

  foreach src in array p_source_ids loop
    select * into n from node where id = src;
    if n.id is null then
      raise exception 'no lot with id %', src;
    end if;
    if n.status = 'closed' then
      raise exception '% is closed; its fruit has already gone somewhere', n.name;
    end if;
    -- 0054. Status is not enough on its own: a pick whose bins were emptied into
    -- a press that has since been finished is spent, and without this it could
    -- be pressed a second time and produce a second load out of nothing. Found
    -- by the assertion that expected the second press to be refused.
    if not exists (select 1 from placement
                    where node_id = src and to_at is null) then
      raise exception
        '% has no fruit in any vessel, so there is nothing of it left to press', n.name;
    end if;
    if parent_stage is null then
      parent_stage := n.stage;
      first_name := n.name;
    elsif parent_stage <> n.stage then
      raise exception
        'those lots are at different stages, so one press cannot be the right record for both';
    end if;
    total_lbs := total_lbs + coalesce(n.quantity, 0);
    unweighed := unweighed + (select count(*) from unweighed_bin where node_id = src);
  end loop;

  -- Where the juice lands when it comes off. Decided here rather than at each
  -- draw, because it is a fact about what went in and somebody drawing the third
  -- pressure should not be asked it again.
  child_stage := case when parent_stage = 'bin' then 'ferment'::node_stage
                      else 'maturation'::node_stage end;

  -- Quantity null, unit null. T1-4: the load exists before anybody knows how
  -- much of it there is, the same way a bin does, and zero would be a lie about
  -- a measurement nobody has made.
  insert into node
    (id, stage, status, name, quantity, unit, variety_id, vintage, non_vintage,
     product_type_id, owner_id, created_by, attributes)
  select
    load_id, 'load', 'open',
    coalesce(nullif(p_node ->> 'name', ''), first_name || ' pressing'),
    null, null,
    (select case when count(distinct p.variety_id) = 1
                 then (array_agg(distinct p.variety_id))[1] end
       from node p where p.id = any(p_source_ids)),
    (select case when count(distinct p.vintage) = 1 and bool_and(not p.non_vintage)
                 then min(p.vintage) end
       from node p where p.id = any(p_source_ids)),
    (select case when count(distinct p.vintage) = 1 and bool_and(not p.non_vintage)
                 then false else true end
       from node p where p.id = any(p_source_ids)),
    coalesce((select case when count(distinct p.product_type_id) = 1
                          then (array_agg(distinct p.product_type_id))[1] end
                from node p where p.id = any(p_source_ids)),
             term_id('product_type', 'wine')),
    (select p.owner_id from node p where p.id = any(p_source_ids)
      order by p.quantity desc nulls last limit 1),
    auth.uid(),
    coalesce(p_node -> 'attributes', '{}'::jsonb)
      || jsonb_build_object('cut_stage', child_stage::text)
      || jsonb_strip_nulls(p_detail);

  -- The picks' shares, known now and never recomputed. A load made of 2000 lbs
  -- and 1000 lbs is two thirds and one third of whatever comes out of it, which
  -- is true before a drop has run.
  if total_lbs > 0 then
    insert into lineage (parent_id, child_id, fraction)
    select p.id, load_id, round(coalesce(p.quantity, 0) / total_lbs, 6)
      from node p where p.id = any(p_source_ids) and coalesce(p.quantity, 0) > 0;
  else
    -- Nothing was weighed. Equal shares is a guess and saying so is the only
    -- honest version of it, so the fractions go in evenly and the caller is told
    -- how many bins never reached a scale.
    insert into lineage (parent_id, child_id, fraction)
    select p.id, load_id, round(1.0 / n_src, 6)
      from node p where p.id = any(p_source_ids);
  end if;

  -- The bins empty here, which is the point of starting rather than recording at
  -- the end: they are available for the next pick while the press runs.
  for src in select unnest(p_source_ids) loop
    update placement set to_at = now()
     where node_id = src and to_at is null;
    get diagnostics emptied = row_count;
  end loop;
  select count(*) into emptied
    from placement where node_id = any(p_source_ids) and to_at is not null;

  -- 0054. The picks are spent. Their quantity stays, because how much fruit
  -- they were is history worth keeping, and `close_node_when_empty` only fires
  -- on a quantity of zero, which this is not. Leaving them open would show a
  -- pressed pick on the intake screen for the rest of the vintage.
  update node set status = 'closed', closed_at = coalesce(closed_at, now())
   where id = any(p_source_ids);

  -- Volume null: there is fruit in the press and nobody knows what it will give.
  insert into placement (node_id, vessel_id, volume_l)
  values (load_id, p_press_vessel_id, null);

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'press'), 'node', load_id, auth.uid(), 'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'action',     'started',
       'sources',    to_jsonb(p_source_ids::text[]),
       'press',      p_press_vessel_id,
       'lbs_in',     nullif(total_lbs, 0),
       'detail',     nullif(p_detail, '{}'::jsonb))));

  return jsonb_build_object(
    'node_id',    load_id,
    'event_id',   ev_id,
    'stage',      'load',
    'cut_stage',  child_stage,
    'lbs_in',     total_lbs,
    'bins_emptied', emptied,
    -- Not fatal and not silent, the same as the one-shot press: the fruit went
    -- in with containers that never reached a scale, and somebody should know
    -- while the pick can still be corrected.
    'unweighed_left', unweighed
  );
end;
$$;

commit;
