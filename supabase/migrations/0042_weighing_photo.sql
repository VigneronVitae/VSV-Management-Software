-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A weighing can carry a photograph of the scale, because a number
--           somebody typed and a number somebody photographed are different
--           kinds of evidence."
-- Depends on: [supabase/migrations/0033_intake.sql,
--              supabase/migrations/0041_daily_log.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0043_record_propagation.sql]
-- Axioms enforced: T0-3 (provenance: what a record is evidence of, and how
--                  good that evidence is, travels with it)
-- Open sorries: S-58 (nothing checks that the photograph is of this weighing)
-- ---------------------------------------------------------------------------
--
-- The winemaker's words: weighing "should also want a picture of the scale. Not
-- require, necessarily, but want."
--
-- **Want rather than require is the whole design.** A weighing with no
-- photograph is a legitimate record and refusing one would be the opposite of
-- T1-4: the truck is waiting, the scale is read, and a phone that will not
-- accept the number without a picture is a phone somebody stops using. So the
-- column is nullable, the screen asks, and the result says whether it got one.
--
-- What it buys is the difference between a number and evidence of a number. A
-- typed weight is somebody's report; a photograph of the display is the thing
-- itself, and the two disagreeing is exactly the sort of error nobody finds in
-- March by staring at a spreadsheet.
--
-- The photograph goes in the same private bucket as vessel photographs and the
-- event carries its path, so it is behind the same signed url and the same row
-- level security as the weighing it belongs to.
--
-- **Dropped before replaced.** `create or replace function` keys on the argument
-- list, so adding a parameter with a default creates a second function and every
-- call then fails with "is not unique". That happened in `0036` and cost a test
-- run to find; it is not happening twice.

begin;

drop function if exists weigh_bins(uuid, uuid[], numeric, text, uuid);

create or replace function weigh_bins(
  p_node_id    uuid,
  p_vessel_ids uuid[],
  p_gross_lbs  numeric,
  p_note       text default null,
  p_supersedes uuid default null,
  p_photo_path text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  n       node%rowtype;
  n_bins  int := coalesce(array_length(p_vessel_ids, 1), 0);
  n_here  int;
  tare    numeric := 0;
  net     numeric;
  v_id    uuid;
  already text;
  ev_id   uuid := gen_random_uuid();
  total   numeric;
begin
  if n_bins = 0 then
    raise exception 'no bins were named, so there is nothing this weight is of';
  end if;
  if p_gross_lbs is null or p_gross_lbs <= 0 then
    raise exception 'a gross weight of % is not a scale reading',
      coalesce(p_gross_lbs::text, 'nothing');
  end if;

  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no pick with id %', p_node_id;
  end if;
  if n.stage <> 'bin' then
    raise exception 'that lot is not a pick, so it is not weighed in bins';
  end if;
  if n.status = 'closed' then
    raise exception 'that pick is closed; its fruit has already gone somewhere';
  end if;

  select count(*) into n_here
    from placement
   where node_id = p_node_id and to_at is null and vessel_id = any(p_vessel_ids);
  if n_here <> n_bins then
    raise exception
      'some of those bins do not hold this pick, so this reading is not of it';
  end if;

  -- Already weighed, unless this is the correction of the reading that did it.
  -- Without the guard a second reading of the same bins adds its fruit a second
  -- time and the pick quietly doubles, which is invisible from every screen.
  select string_agg(u.bin_name, ', ' order by u.bin_name) into already
    from (
      select v.name as bin_name
        from unnest(p_vessel_ids) as x(vessel_id)
        join vessel v on v.id = x.vessel_id
       where not exists (
         select 1 from unweighed_bin ub
          where ub.node_id = p_node_id and ub.vessel_id = x.vessel_id)
    ) u;
  if already is not null and p_supersedes is null then
    raise exception
      'these bins have been weighed already: %. Correct that weighing rather than adding a second one',
      already;
  end if;

  if p_supersedes is not null and not exists (
    select 1 from event
     where id = p_supersedes
       and subject_type = 'node' and subject_id = p_node_id
       and operation_id = term_id('operation', 'weigh')
  ) then
    raise exception 'there is no weighing of this pick with id % to correct', p_supersedes;
  end if;

  foreach v_id in array p_vessel_ids loop
    tare := tare + bin_tare_lbs(v_id);
  end loop;

  net := p_gross_lbs - tare;
  if net <= 0 then
    raise exception
      'a gross of % lbs over bins weighing % lbs empty leaves % lbs of fruit, so one of those numbers is wrong',
      p_gross_lbs, tare, net;
  end if;

  insert into event
    (id, operation_id, subject_type, subject_id, by_user, provenance, data)
  values
    (ev_id, term_id('operation', 'weigh'), 'node', p_node_id, auth.uid(), 'observed',
     jsonb_strip_nulls(jsonb_build_object(
       'gross_lbs',  p_gross_lbs,
       'tare_lbs',   tare,
       'net_lbs',    net,
       'bins',       to_jsonb(p_vessel_ids::text[]),
       'note',       nullif(p_note, ''),
       -- Evidence, not decoration. A path here means somebody photographed the
       -- display; its absence means they did not, and the two must not read the
       -- same, which is why it is stripped rather than stored as an empty string.
       'photo_path', nullif(btrim(coalesce(p_photo_path, '')), ''),
       'supersedes', p_supersedes)));

  -- Recomputed from the events rather than added to, so a correction lands
  -- without anybody working out what the old reading contributed. The events are
  -- the record; quantity is the schema's place to keep the answer.
  select coalesce(sum((e.data ->> 'net_lbs')::numeric), 0) into total
    from event e
   where e.subject_type = 'node' and e.subject_id = p_node_id
     and e.operation_id = term_id('operation', 'weigh')
     and not exists (
       select 1 from event s
        where s.subject_type = 'node' and s.subject_id = p_node_id
          and s.operation_id = term_id('operation', 'weigh')
          and (s.data ->> 'supersedes')::uuid = e.id);

  update node set quantity = total, unit = 'lbs' where id = p_node_id;

  return jsonb_build_object(
    'event_id',  ev_id,
    'gross_lbs', p_gross_lbs,
    'tare_lbs',  tare,
    'net_lbs',   net,
    'total_lbs', total,
    -- Said back, so the screen can ask once more rather than pretend it did not
    -- notice. Wanting a thing and requiring it differ in what happens next, not
    -- in whether anybody mentions it.
    'photographed', p_photo_path is not null and btrim(p_photo_path) <> '',
    'unweighed', (select count(*) from unweighed_bin where node_id = p_node_id)
  );
end;
$$;

-- Weighings nobody photographed. Not a work queue in the way `unweighed_bin` is:
-- a bin with no weight is a thing that must be finished, and a weighing with no
-- photograph is merely one with weaker evidence behind it. It exists so that
-- "which of these numbers can I check" is answerable at all.
create or replace view weighing_without_photo with (security_invoker = true) as
select
  e.id        as event_id,
  e.subject_id as node_id,
  n.name      as pick_name,
  e.at,
  (e.data ->> 'net_lbs')::numeric as net_lbs
from event e
join node n on n.id = e.subject_id
where e.subject_type = 'node'
  and e.operation_id = term_id('operation', 'weigh')
  and not (e.data ? 'photo_path')
  and not exists (
    select 1 from event s
     where s.subject_type = 'node' and s.subject_id = e.subject_id
       and s.operation_id = term_id('operation', 'weigh')
       and (s.data ->> 'supersedes')::uuid = e.id
  );

comment on view weighing_without_photo is
  'Live weighings carrying no photograph of the scale. Weaker evidence rather '
  'than unfinished work, which is why this is not counted anywhere that nags. '
  'See 0042.';

commit;
