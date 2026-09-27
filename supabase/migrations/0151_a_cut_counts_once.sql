-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A press's litres out are what was drawn off it, so a cut drawn into
--           a tank holding another of the same press's cuts counts once."
-- Depends on: [supabase/migrations/0143_a_record_can_say_when.sql,
--              supabase/migrations/0150_off_the_skins.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  scripts/smoke.ts]
-- Axioms enforced: T0-2. Litres out are summed from the draws, which are the
--                  record, rather than from lot quantities, which a blend
--                  changes after the fact.
-- Open sorries: S-148, the blended cut left open with no vessel.
-- ---------------------------------------------------------------------------

-- Found 2026-09-27 by scripts/smoke.ts pressing a red off its skins the way the
-- winemaker described it: free run and 2nd free run into one tank, press and
-- hard press into another. 370 L were drawn and the press said 440.
--
-- `draw_cut` sends a cut into a tank that already holds a lot by blending: the
-- resident lot grows to hold both, and the arriving cut becomes one of its
-- parents. The arriving cut kept its own quantity too, and `finish_press`
-- summed the quantities of every cut of the press. When the resident was
-- another cut of the same press, which is exactly where a 2nd free run goes,
-- those litres were counted twice: once in the free run that now held them,
-- once on the 2nd free run's own lot, which sat open in no vessel.
--
-- Every real pressing so far was checked: each recorded litres out equals the
-- sum of its draws, because none had yet sent two of its cuts into one tank.
-- Nothing already recorded changes.
--
-- **Closing the blended cut was tried and taken back.** It would have ended
-- the lot with litres and no vessel, but 0102 wants the same cut drawn into the
-- same tank twice to be one lot growing, and a closed lot is not found again,
-- so the second draw made a new one. The assertion suite said so at once. The
-- count is what was wrong and is what changes; the open lot is S-148.
--
-- Both functions are the live definitions with only these changes, restated
-- from `pg_get_functiondef` and diffed.

CREATE OR REPLACE FUNCTION public.draw_cut(p_load_id uuid, p_vessel_id uuid, p_volume_l numeric, p_cut_id uuid DEFAULT NULL::uuid, p_name text DEFAULT NULL::text, p_note text DEFAULT NULL::text, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  load_n    node%rowtype;
  cut_id    uuid;
  cut_n     node%rowtype;
  cut_stage node_stage;
  cut_label text;
  ev_id     uuid := gen_random_uuid();
  total     numeric;
  in_vessel numeric;
  cap       numeric;
  -- 0102. The lot already standing in the destination, if there is one.
  resident  uuid;
  held      numeric;
  new_total numeric;
  res_name  text;
  res_var   uuid;
  cut_var   uuid;
  blended   boolean := false;
begin
  perform happening_at(p_at);
  select * into load_n from node where id = p_load_id;
  if load_n.id is null then
    raise exception 'no load with id %', p_load_id;
  end if;
  if load_n.stage <> 'load' then
    raise exception 'that lot is not in a press, so nothing is being drawn off it';
  end if;
  if load_n.status = 'closed' then
    raise exception 'that press is finished; record a correction against it rather than drawing more';
  end if;
  if p_volume_l is null or p_volume_l <= 0 then
    raise exception 'a draw of % litres is not a volume',
      coalesce(p_volume_l::text, 'nothing');
  end if;
  if not exists (select 1 from vessel where id = p_vessel_id and active) then
    raise exception 'that vessel is not one juice can go into';
  end if;

  if p_cut_id is not null and not exists (
    select 1 from term where id = p_cut_id and kind = 'press_cut' and active) then
    raise exception 'that is not a press cut';
  end if;

  cut_stage := coalesce((load_n.attributes ->> 'cut_stage')::node_stage, 'ferment');
  cut_label := coalesce(
    nullif(btrim(coalesce(p_name, '')), ''),
    (select t.label from term t where t.id = p_cut_id),
    'Pressed');

  -- The same cut drawn again is the same lot getting bigger, not a second one.
  select n.* into cut_n
    from node n
    join lineage l on l.child_id = n.id and l.parent_id = p_load_id
   where n.status <> 'closed'
     and ((p_cut_id is not null and (n.attributes ->> 'cut')::uuid = p_cut_id)
       or (p_cut_id is null and n.attributes -> 'cut' is null
           and n.name = load_n.name || ' ' || cut_label))
   limit 1;

  if cut_n.id is null then
    cut_id := gen_random_uuid();
    insert into node
      (id, stage, status, name, quantity, unit, variety_id, vintage, non_vintage,
       product_type_id, owner_id, created_by, attributes)
    values
      (cut_id, cut_stage, 'open',
       load_n.name || ' ' || cut_label,
       0, 'L',
       load_n.variety_id, load_n.vintage, load_n.non_vintage,
       load_n.product_type_id, load_n.owner_id, auth.uid(),
       jsonb_strip_nulls(jsonb_build_object(
         'cut',       p_cut_id,
         'cut_label', cut_label)));
    insert into lineage (parent_id, child_id, fraction) values (p_load_id, cut_id, 1);
  else
    cut_id := cut_n.id;
  end if;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'press'), 'node', cut_id, auth.uid(), 'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'action',    'drawn',
       'load',      p_load_id,
       'vessel',    p_vessel_id,
       'volume_l',  p_volume_l,
       'cut',       p_cut_id,
       'note',      nullif(btrim(coalesce(p_note, '')), ''))));

  select coalesce(sum((e.data ->> 'volume_l')::numeric), 0) into total
    from event e
   where e.subject_type = 'node' and e.subject_id = cut_id
     and e.operation_id = term_id('operation', 'press')
     and e.data ->> 'action' = 'drawn'
     and not exists (
       select 1 from event s
        where s.subject_type = 'node' and s.subject_id = cut_id
          and (s.data ->> 'supersedes')::uuid = e.id);

  update node set quantity = total, unit = 'L' where id = cut_id;

  select coalesce(sum((e.data ->> 'volume_l')::numeric), 0) into in_vessel
    from event e
   where e.subject_type = 'node' and e.subject_id = cut_id
     and e.operation_id = term_id('operation', 'press')
     and e.data ->> 'action' = 'drawn'
     and (e.data ->> 'vessel')::uuid = p_vessel_id;

  if exists (select 1 from placement
              where node_id = cut_id and vessel_id = p_vessel_id and to_at is null) then
    update placement set volume_l = in_vessel
     where node_id = cut_id and vessel_id = p_vessel_id and to_at is null;
  else
    select p.node_id, p.volume_l, n.name, n.variety_id
      into resident, held, res_name, res_var
      from placement p join node n on n.id = p.node_id
     where p.vessel_id = p_vessel_id and p.to_at is null;

    if resident is null then
      insert into placement (node_id, vessel_id, volume_l)
      values (cut_id, p_vessel_id, in_vessel);

    else
      -- **The blend.** 0014's rule, now in the place a press needs it.
      blended   := true;
      held      := coalesce(held, 0);
      new_total := held + p_volume_l;

      -- Every parent's share is what it contributed over what is now there. The
      -- existing parents kept `held` between them, so they keep held/new_total
      -- of what they had, and the arriving cut takes the rest. Clamped the way
      -- 0014 clamps, because the constraint is fraction > 0.
      update lineage
         set fraction = greatest(
               least(fraction * held / nullif(new_total, 0), 1), 0.00001)
       where child_id = resident;

      -- The cut may already be a parent, from an earlier draw into this same
      -- tank, in which case its share grows rather than being written twice.
      insert into lineage (parent_id, child_id, fraction)
      values (cut_id, resident,
              greatest(least(p_volume_l / nullif(new_total, 0), 1), 0.00001))
      on conflict (parent_id, child_id) do update
        set fraction = least(lineage.fraction + excluded.fraction, 1);

      update placement set volume_l = new_total
       where vessel_id = p_vessel_id and to_at is null;
      update node set quantity = new_total, unit = 'L' where id = resident;

      -- The tank's own lot says what arrived in it. Without this the history of
      -- the wine in the tank is only readable from the other lot's events,
      -- which is the wrong way round: somebody looking at the tank is looking
      -- at this lot.
      insert into event
        (id, operation_id, subject_type, subject_id, by_user, provenance, data)
      values
        (gen_random_uuid(), term_id('operation', 'press'), 'node', resident,
         auth.uid(), 'observed',
         jsonb_build_object(
           'action',    'received',
           'from_cut',  cut_id,
           'load',      p_load_id,
           'vessel',    p_vessel_id,
           'volume_l',  p_volume_l,
           'drawn_by',  ev_id));

      -- So the screen can say it while the person is still at the press. Told,
      -- not refused: his ruling for barrels, for the same reason.
      cut_var := coalesce(cut_n.variety_id, load_n.variety_id);

      -- What is in the tank now, so over_capacity below reads the tank rather
      -- than this one cut.
      in_vessel := new_total;

    end if;
  end if;

  select capacity_l into cap from vessel where id = p_vessel_id;

  perform resume_at(was_at);
  return jsonb_build_object(
    'cut_id',     cut_id,
    'event_id',   ev_id,
    'cut',        cut_label,
    'volume_l',   p_volume_l,
    'cut_total',  total,
    'in_vessel',  in_vessel,
    'over_capacity', cap is not null and in_vessel > cap,
    -- 0102. Null when the tank was empty, which is the ordinary case.
    'blended_into', case when blended then res_name else null end,
    'variety_differs',
      blended and cut_var is not null and res_var is not null and cut_var <> res_var,
    -- 0151. What this press has given is what was drawn off it. Summing its
    -- cuts' quantities counted a cut twice once it had gone into a tank
    -- holding another of the same press's cuts.
    'load_total', (select coalesce(sum((d.data ->> 'volume_l')::numeric), 0)
                     from event d
                    where d.operation_id = term_id('operation', 'press')
                      and d.data ->> 'action' = 'drawn'
                      and d.data ->> 'load' = p_load_id::text
                      and not exists (select 1 from event s
                                       where (s.data ->> 'supersedes')::uuid = d.id))
  );
end;
$function$;
CREATE OR REPLACE FUNCTION public.finish_press(p_load_id uuid, p_detail jsonb DEFAULT '{}'::jsonb, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  was_at text := current_setting('vsv.occurred_at', true);
  load_n  node%rowtype;
  out_l   numeric;
  lbs_in  numeric;
  ev_id   uuid := gen_random_uuid();
  cuts    int;
begin
  perform happening_at(p_at);
  select * into load_n from node where id = p_load_id;
  if load_n.id is null then
    raise exception 'no load with id %', p_load_id;
  end if;
  if load_n.stage <> 'load' then
    raise exception 'that lot is not in a press';
  end if;
  if load_n.status = 'closed' then
    raise exception 'that press is already finished';
  end if;

  select count(*) into cuts
    from node n join lineage l on l.child_id = n.id and l.parent_id = p_load_id;
  -- 0151. What came off is what was drawn, from the draws themselves. The sum
  -- of the cuts' quantities counted a cut twice once it had been drawn into a
  -- tank already holding another of this press's cuts, which is where a red's
  -- 2nd free run goes: into the free run's tank.
  select coalesce(sum((d.data ->> 'volume_l')::numeric), 0) into out_l
    from event d
   where d.operation_id = term_id('operation', 'press')
     and d.data ->> 'action' = 'drawn'
     and d.data ->> 'load' = p_load_id::text
     and not exists (select 1 from event s where (s.data ->> 'supersedes')::uuid = d.id);

  if cuts = 0 then
    raise exception
      'nothing has been drawn off this press yet, so finishing it would record a press that produced nothing';
  end if;

  select coalesce(sum((e.data ->> 'lbs_in')::numeric), 0) into lbs_in
    from event e
   where e.subject_type = 'node' and e.subject_id = p_load_id
     and e.operation_id = term_id('operation', 'press')
     and e.data ->> 'action' = 'started';

  -- The load is spent: what went in came out as the cuts. Its quantity is set to
  -- what it gave rather than left null, because by now it is known.
  update node
     set quantity = out_l,
         unit = 'L',
         status = 'closed',
         closed_at = occurred_at(),
         attributes = attributes || jsonb_strip_nulls(p_detail)
   where id = p_load_id;

  update placement set to_at = occurred_at()
   where node_id = p_load_id and to_at is null;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'press'), 'node', p_load_id, auth.uid(), 'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'action',    'finished',
       'litres_out', out_l,
       'cuts',      cuts,
       'detail',    nullif(p_detail, '{}'::jsonb))));

  perform resume_at(was_at);
  return jsonb_build_object(
    'node_id',    p_load_id,
    'event_id',   ev_id,
    'lbs_in',     lbs_in,
    'litres_out', out_l,
    'cuts',       cuts,
    -- The number the whole exercise is for. Null rather than zero when nothing
    -- was weighed, because a yield computed from no weight is not a yield.
    'yield_l_per_ton',
      case when lbs_in > 0 then round(out_l / (lbs_in / 2000.0), 2) end
  );
end;
$function$;
