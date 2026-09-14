-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A press is more than fruit in and litres out: the cuts it was
--           divided into, how long the skins were on, what the press was set to,
--           and whether it went in whole."
-- Depends on: [supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0034_press.sql,
--              supabase/migrations/0044_finishing_a_pick.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T0-2 (composition is derived from fruit weight and a cut is
--                  a fact about a lot, not a second composition)
-- Open sorries: S-62 (a cut is named and its position in the run is not)
-- ---------------------------------------------------------------------------
--
-- From the processing log Alexis handed over. The form asks for press program,
-- press fractions and cuts, whole cluster against destem, skin maceration time,
-- skin contact start and end, and total contact time. `0034` recorded fruit in,
-- litres out and where the juice went, which is the spine and about a third of
-- what the form wants.
--
-- **Cuts discharge S-52.** That sorry says the honest thing about pressing free
-- run and hard press separately: calling `press` twice records two lots whose
-- shares are proportional to fruit weight, which is arithmetically sound and
-- says nothing about one of them being the hard press. The resolution is not to
-- change the arithmetic. **Proportional by fruit weight is correct**, because a
-- hard press really is made of the same fruit as the free run and in the same
-- ratios; what was missing is that the cut is a fact about the lot and there was
-- nowhere to put it. So each cut becomes its own child carrying its own name,
-- and every child of one press draws the same share from every parent.
--
-- **One shape, not two.** `press` used to take destinations and make one child.
-- It now takes cuts, and a press with nothing to say about cuts is one cut with
-- no name, which is exactly what it did before. Keeping both would be two ways
-- to say the same thing, which is how they come to disagree.
--
-- **Skin contact is two timestamps and not three.** The form asks for start, end
-- and total, and the total is a subtraction. Storing it would be storing what is
-- derived, and the one time it disagreed with its own inputs nobody would know
-- which to believe. The press run is recorded the same way and is a separate
-- pair: how long the skins were on and how long the press ran are two different
-- facts, and one is usually a fraction of the other.

begin;

-- Two vocabularies, for the same reason. `free run` typed three ways is three
-- cuts, and "Champagne 1.2 bar" typed three ways is three programs, and a
-- program is the thing you most want to compare one run against another by. 0027
-- made adding one a row, and both are open, so the program somebody runs next
-- week does not need a migration.
--
-- No program is seeded. They belong to a particular press, and guessing at the
-- cycles on somebody's Bucher would be inventing vocabulary for them.
insert into term_kind (kind, label, module, sort_order)
values ('press_cut', 'Press cut', 'winemaking', 35)
on conflict (kind) do update
  set label = excluded.label, module = excluded.module;

insert into term (kind, value, label, sort_order) values
  ('press_cut', 'free_run',   'Free run',   10),
  ('press_cut', 'press',      'Press',      20),
  ('press_cut', 'hard_press', 'Hard press', 30)
on conflict (kind, value) do nothing;

insert into term_kind (kind, label, module, sort_order)
values ('press_program', 'Press program', 'winemaking', 36)
on conflict (kind) do update
  set label = excluded.label, module = excluded.module;

-- ---------------------------------------------------------------------------
-- The press, with cuts and with the detail the form asks for
-- ---------------------------------------------------------------------------

-- Dropped before replaced. 0036 shipped two `add_bins_to_pick` by adding
-- parameters with defaults and every call then failed with "is not unique".
drop function if exists press(jsonb, jsonb, jsonb, jsonb);

create or replace function press(
  p_sources jsonb,
  -- [{cut_id, name, destinations: [{vessel_id, volume_l}]}]. A press with
  -- nothing to say about cuts is one entry with a null cut, which is what this
  -- function did before cuts existed.
  p_cuts    jsonb,
  p_node    jsonb default '{}'::jsonb,
  -- program, whole_cluster_pct, skin_contact_start, skin_contact_end,
  -- temperature_c, note. All optional: a press nobody timed is still a press.
  p_detail  jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  src          jsonb;
  cut          jsonb;
  dst          jsonb;
  n            node%rowtype;
  want         numeric;
  total_in     numeric := 0;
  total_out    numeric := 0;
  cut_out      numeric;
  parent_ids   uuid[] := '{}';
  weights      numeric[] := '{}';
  child_ids    uuid[] := '{}';
  child        uuid;
  i            int;
  child_stage  node_stage;
  parent_stage node_stage;
  waiting      int := 0;
  v_id         uuid;
  vol          numeric;
  held         numeric;
  emptied      int := 0;
  ev_id        uuid := gen_random_uuid();
  wc           numeric := (p_detail ->> 'whole_cluster_pct')::numeric;
  started      timestamptz := (p_detail ->> 'skin_contact_start')::timestamptz;
  ended        timestamptz := (p_detail ->> 'skin_contact_end')::timestamptz;
  ran_from     timestamptz := (p_detail ->> 'pressed_from')::timestamptz;
  ran_to       timestamptz := (p_detail ->> 'pressed_to')::timestamptz;
begin
  if p_sources is null or jsonb_array_length(p_sources) = 0 then
    raise exception 'nothing was named to press';
  end if;
  if p_cuts is null or jsonb_array_length(p_cuts) = 0 then
    raise exception 'the juice has to go somewhere; name at least one vessel';
  end if;

  if wc is not null and (wc < 0 or wc > 100) then
    raise exception 'whole cluster of % percent is not a proportion', wc;
  end if;
  -- Skins do not come off before they go on. A pair this way round is a typo
  -- somebody would otherwise find in March as a negative contact time.
  if started is not null and ended is not null and ended < started then
    raise exception 'skin contact ended before it started';
  end if;
  if ran_from is not null and ran_to is not null and ran_to < ran_from then
    raise exception 'the press finished before it started';
  end if;
  if (p_detail ->> 'program_id') is not null and not exists (
    select 1 from term
     where id = (p_detail ->> 'program_id')::uuid and kind = 'press_program'
  ) then
    raise exception 'that is not a press program';
  end if;

  -- Pass one: read the parents and decide what may be pressed. Nothing is
  -- written until every source has been checked.
  for src in select value from jsonb_array_elements(p_sources)
  loop
    select * into n from node where id = (src ->> 'node_id')::uuid;
    if n.id is null then
      raise exception 'no lot with id %', src ->> 'node_id';
    end if;
    if n.status = 'closed' then
      raise exception '% is closed; there is nothing left in it to press', n.name;
    end if;
    if n.quantity is null then
      raise exception
        '% has never been weighed, and pressing it is the last moment anybody could. Weigh its bins first', n.name;
    end if;

    if parent_stage is null then
      parent_stage := n.stage;
    elsif parent_stage <> n.stage then
      raise exception
        'those lots are at different stages, so one press cannot be the right record for both';
    end if;

    want := coalesce((src ->> 'weight_lbs')::numeric, n.quantity);
    if want <= 0 then
      raise exception 'a press of % from % is not an amount', want, n.name;
    end if;
    if want > n.quantity then
      raise exception
        '% holds % and the press says %, so that is more fruit than there is',
        n.name, n.quantity, want;
    end if;

    parent_ids := parent_ids || n.id;
    weights    := weights || want;
    total_in   := total_in + want;

    select count(*) into i from unweighed_bin where node_id = n.id;
    waiting := waiting + i;
  end loop;

  child_stage := coalesce(
    (p_node ->> 'stage')::node_stage,
    case when parent_stage = 'bin' then 'ferment'::node_stage
         else 'maturation'::node_stage end);

  -- Pass two: check every destination before writing anything, so a press that
  -- is going to be refused does not half happen.
  for cut in select value from jsonb_array_elements(p_cuts)
  loop
    if (cut ->> 'cut_id') is not null and not exists (
      select 1 from term where id = (cut ->> 'cut_id')::uuid and kind = 'press_cut'
    ) then
      raise exception 'that is not a press cut';
    end if;
    if cut -> 'destinations' is null
       or jsonb_array_length(cut -> 'destinations') = 0 then
      raise exception 'a cut with no vessel to go into is not a cut';
    end if;
    for dst in select value from jsonb_array_elements(cut -> 'destinations')
    loop
      vol := (dst ->> 'volume_l')::numeric;
      if vol is null or vol <= 0 then
        raise exception 'a volume of % into a vessel is not a filling',
          coalesce(vol::text, 'nothing');
      end if;
      v_id := (dst ->> 'vessel_id')::uuid;
      if not exists (select 1 from vessel where id = v_id and active) then
        raise exception 'no active vessel with id %', v_id;
      end if;
      if exists (select 1 from placement where vessel_id = v_id and to_at is null) then
        raise exception
          'a vessel the juice is going into already holds a lot; rack it out first';
      end if;
      total_out := total_out + vol;
    end loop;
  end loop;

  -- One child per cut. Every child of one press draws the same share from every
  -- parent, because a hard press is made of the same fruit as the free run and
  -- in the same ratios. The cut is a fact about the lot rather than a second
  -- composition, which is what S-52 was waiting for.
  for cut in select value from jsonb_array_elements(p_cuts)
  loop
    child := gen_random_uuid();
    select coalesce(sum((d ->> 'volume_l')::numeric), 0) into cut_out
      from jsonb_array_elements(cut -> 'destinations') d;

    insert into node (id, stage, status, name, quantity, unit,
                      variety_id, vintage, product_type_id,
                      owner_id, created_by, attributes)
    select
      child, child_stage, 'open',
      coalesce(
        nullif(cut ->> 'name', ''),
        (select p.name from node p where p.id = parent_ids[1])
          || ' pressed'
          || coalesce(', ' || (select t.label from term t
                                where t.id = (cut ->> 'cut_id')::uuid), '')),
      cut_out, 'L',
      (select case when count(distinct p.variety_id) = 1
                   then (array_agg(distinct p.variety_id))[1] end
         from node p where p.id = any(parent_ids)),
      (select case when count(distinct p.vintage) = 1
                   then min(p.vintage) end
         from node p where p.id = any(parent_ids)),
      coalesce((select case when count(distinct p.product_type_id) = 1
                            then (array_agg(distinct p.product_type_id))[1] end
                  from node p where p.id = any(parent_ids)),
               term_id('product_type', 'wine')),
      (select p.owner_id from node p where p.id = any(parent_ids)
        order by p.quantity desc nulls last limit 1),
      auth.uid(),
      coalesce(p_node -> 'attributes', '{}'::jsonb)
        || jsonb_strip_nulls(jsonb_build_object(
             'cut',              (cut ->> 'cut_id')::uuid,
             'cut_label',        (select t.label from term t
                                   where t.id = (cut ->> 'cut_id')::uuid),
             -- Named in spec.md §2 as an attribute of a node since the scaffold,
             -- and nothing wrote it until now.
             'whole_cluster_pct', wc));

    child_ids := child_ids || child;

    for dst in select value from jsonb_array_elements(cut -> 'destinations')
    loop
      insert into placement (node_id, vessel_id, volume_l)
      values (child, (dst ->> 'vessel_id')::uuid, (dst ->> 'volume_l')::numeric);
    end loop;

    -- Lineage by fruit weight, the same for every cut. The denominator is what
    -- the parents put in rather than what came out, so the shares sum to one and
    -- the press yield does not change what the wine is made of.
    for i in 1 .. array_length(parent_ids, 1)
    loop
      insert into lineage (parent_id, child_id, fraction)
      values (parent_ids[i], child,
              greatest(least(weights[i] / nullif(total_in, 0), 1), 0.00001));
    end loop;
  end loop;

  -- Take the fruit out of the parents.
  for i in 1 .. array_length(parent_ids, 1)
  loop
    select quantity into held from node where id = parent_ids[i];
    update node set quantity = greatest(held - weights[i], 0)
     where id = parent_ids[i];

    if held - weights[i] <= 0.0001 then
      update placement set to_at = now()
       where node_id = parent_ids[i] and to_at is null;
      get diagnostics emptied = row_count;
    end if;
  end loop;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'press'), 'node', child_ids[1], auth.uid(), 'observed',
     jsonb_strip_nulls(coalesce(p_detail, '{}'::jsonb) || jsonb_build_object(
       'lbs_in',          total_in,
       'litres_out',      total_out,
       'yield_l_per_ton', round(total_out / nullif(total_in, 0) * 2000, 2),
       'parents',         to_jsonb(parent_ids::text[]),
       'cuts',            to_jsonb(child_ids::text[]),
       -- Two timestamps, not three. The total is a subtraction, and storing it
       -- would be storing what is derived and inviting it to disagree.
       'skin_contact_minutes',
         case when started is not null and ended is not null
              then round(extract(epoch from (ended - started)) / 60.0)
         end,
       -- The other duration, and a different fact: how long the skins were on
       -- and how long the press ran are two things the form asks for separately
       -- and one of them is often a fraction of the other.
       'press_minutes',
         case when ran_from is not null and ran_to is not null
              then round(extract(epoch from (ran_to - ran_from)) / 60.0)
         end,
       'program_label',
         (select t.label from term t
           where t.id = (p_detail ->> 'program_id')::uuid))));

  return jsonb_build_object(
    'node_id',         child_ids[1],
    'cuts',            to_jsonb(child_ids::text[]),
    'stage',           child_stage,
    'lbs_in',          total_in,
    'litres_out',      total_out,
    'yield_l_per_ton', round(total_out / nullif(total_in, 0) * 2000, 2),
    'bins_emptied',    emptied,
    'unweighed_left',  waiting,
    'event_id',        ev_id
  );
end;
$$;

comment on function press is
  'Fruit in, cuts out. Every cut of one press draws the same share from every '
  'parent, because a hard press is made of the same fruit as the free run; the '
  'cut is a fact about the lot rather than a second composition. Discharges '
  'S-52. See 0045.';

commit;
