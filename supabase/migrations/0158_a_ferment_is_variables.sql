-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Everything measured or done to a fermenting lot is one variable at
--           one time with one value, so it can be drawn, exported and modelled
--           whichever way somebody wants."
-- Depends on: [supabase/migrations/0067_sampling.sql,
--              supabase/migrations/0064_typing_a_note.sql,
--              supabase/migrations/0143_a_record_can_say_when.sql,
--              supabase/migrations/0150_off_the_skins.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts, scripts/smoke.ts,
--                  supabase/migrations/0162_a_temperature_and_the_cap.sql]
-- Axioms enforced: T0-2. The series is a view over the notes and events
--                  already written; nothing is copied into it.
--                  T0-5. A reading is a sample event and typed notes about
--                  it, the shape 0067 settled; a correction is another reading.
-- Open sorries: S-150 (whether cap work on one fermenter forks the lot).
-- ---------------------------------------------------------------------------

-- The Pommard went into MB01 on 2026-09-27 and is fermenting on its skins.
-- Asked whether the ferment chart should carry punchdowns and pumpovers or
-- only Brix and temperature, the winemaker: "I want them all saved as
-- variables that can be modeled in whichever way."
--
-- **Nothing new is stored.** A Brix was already a typed note about a sample
-- (0064, 0067), and a punchdown was already an event (0004). What was missing
-- was one place that reads them all as the same kind of row, and one verb that
-- records a reading without three round trips. `lot_series` is the first: one
-- row per variable per moment, `reading` or `action`, with its value, its unit,
-- which fermenter, and whether it was entered after the fact. The screen draws
-- it and the spreadsheet is it.
--
-- **Readings are of a fermenter, and belong to whatever lot it held.** A Brix
-- is taken from one vessel, and two fermenters of one lot read differently, so
-- the sample is of the vessel and the view finds the lot that was in it at the
-- time, the way `sample` has since 0067.
--
-- **Only Brix is added.** It is the one reading every winery takes the same
-- way. Temperature is not, because a thermometer in a fermenter reads in
-- whichever unit it reads in and this app has not been told; anyone can add it,
-- with its unit, under "What a note can be turned into", and the log offers
-- every numeric kind there is.

insert into term (kind, value, label, sort_order, attributes) values
  ('fact_kind', 'brix', 'Brix', 20,
   '{"value_type": "number", "unit": "°Bx", "hint": "Sugar, from the density meter or a refractometer."}'::jsonb)
on conflict (kind, value) do update set
  label = excluded.label, attributes = excluded.attributes, active = true;

-- The two things done to a cap. Marked rather than listed in a client, so the
-- ferment log offers what the kernel says belongs there.
update term set attributes = attributes || '{"cap": true}'::jsonb
 where kind = 'operation' and value in ('punchdown', 'pumpover');

-- ---------------------------------------------------------------------------
-- One reading, or several, from one fermenter
-- ---------------------------------------------------------------------------

create or replace function record_reading(
  p_vessel_id uuid,
  p_readings  jsonb,
  p_at        timestamptz default null,
  p_note      text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  was_at   text := current_setting('vsv.occurred_at', true);
  ev_id    uuid := gen_random_uuid();
  at_      timestamptz;
  vname    text;
  lot      uuid;
  lot_name text;
  k        text;
  v        jsonb;
  said     text;
  kt       term%rowtype;
  n        int := 0;
begin
  if not is_facility_user() then
    raise exception 'readings are taken by people who work here'
      using errcode = 'insufficient_privilege';
  end if;
  perform happening_at(p_at);
  at_ := occurred_at();

  if p_readings is null or jsonb_typeof(p_readings) <> 'object' then
    raise exception 'say what was read, by kind: {"brix": 22.4}';
  end if;
  select name into vname from vessel where id = p_vessel_id and active;
  if vname is null then
    raise exception 'there is no vessel with that id to take a reading from';
  end if;
  select p.node_id, n.name into lot, lot_name
    from placement p join node n on n.id = p.node_id
   where p.vessel_id = p_vessel_id and p.from_at <= at_
     and (p.to_at is null or p.to_at > at_);
  if lot is null then
    raise exception '% held nothing then, so a reading from it is a reading of nothing', vname;
  end if;

  insert into event (id, operation_id, subject_type, subject_id, by_user, at, provenance, data)
  values (ev_id, term_id('operation', 'sample'), 'vessel', p_vessel_id, auth.uid(), at_,
          'observed',
          jsonb_strip_nulls(jsonb_build_object('note', nullif(btrim(coalesce(p_note, '')), ''))));

  for k, v in select * from jsonb_each(p_readings) loop
    select * into kt from term where kind = 'fact_kind' and value = k and active;
    if kt.id is null then
      raise exception 'there is no kind of reading called %', k;
    end if;
    said := nullif(btrim(coalesce(v #>> '{}', '')), '');
    -- A blank box on the form is not a reading.
    continue when said is null;
    if kt.attributes ->> 'value_type' = 'number' and said !~ '^-?[0-9]+([.][0-9]+)?$' then
      raise exception '% is a number, and "%" is not one', kt.label, said;
    end if;
    insert into note (subject_type, subject_id, about_event, body, by_user, at,
                      kind_id, value_num, value_text)
    values ('vessel', p_vessel_id, ev_id,
            kt.label || ' ' || said || coalesce(' ' || (kt.attributes ->> 'unit'), ''),
            auth.uid(), at_, kt.id,
            case when kt.attributes ->> 'value_type' = 'number' then said::numeric end,
            case when kt.attributes ->> 'value_type' = 'number' then null else said end);
    n := n + 1;
  end loop;

  if n = 0 then
    raise exception 'every box was blank, so nothing was read';
  end if;

  perform resume_at(was_at);
  return jsonb_build_object('event_id', ev_id, 'vessel', vname, 'lot', lot_name,
                            'node_id', lot, 'readings', n);
end $$;

comment on function record_reading is
  'Takes a sample from one vessel and records what it read, by kind, as typed notes about it.';

grant execute on function record_reading(uuid, jsonb, timestamptz, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Every variable, one row a moment
-- ---------------------------------------------------------------------------

create or replace view lot_series with (security_invoker = true) as
-- Readings from a vessel, for the lot it held when they were taken.
select p.node_id,
       n.name                          as lot,
       v.id                            as vessel_id,
       v.name                          as vessel,
       nt.at,
       t.value                         as variable,
       t.label,
       'reading'::text                 as kind,
       nt.value_num,
       nt.value_text,
       t.attributes ->> 'unit'         as unit,
       nt.body                         as note,
       nt.id                           as source_id,
       (nt.at < nt.created_at)         as entered_late
  from note nt
  join term t on t.id = nt.kind_id and t.kind = 'fact_kind'
  join vessel v on nt.subject_type = 'vessel' and v.id = nt.subject_id
  join placement p on p.vessel_id = v.id and p.from_at <= nt.at
                  and (p.to_at is null or p.to_at > nt.at)
  join node n on n.id = p.node_id
union all
-- Readings about the lot itself.
select n.id, n.name, null::uuid, null::text, nt.at, t.value, t.label, 'reading',
       nt.value_num, nt.value_text, t.attributes ->> 'unit', nt.body, nt.id,
       (nt.at < nt.created_at)
  from note nt
  join term t on t.id = nt.kind_id and t.kind = 'fact_kind'
  join node n on nt.subject_type = 'node' and n.id = nt.subject_id
union all
-- What was done to the lot. Bookkeeping that is not something done to wine is
-- left out: taking the sample itself, the scale, watching, and corrections to
-- the record rather than to the wine.
select n.id, n.name,
       (e.data ->> 'vessel')::uuid,
       (select vv.name from vessel vv where vv.id::text = e.data ->> 'vessel'),
       e.at, o.value, o.label, 'action',
       case when (e.data ->> 'amount') ~ '^-?[0-9]+([.][0-9]+)?$'
            then (e.data ->> 'amount')::numeric end,
       e.data ->> 'what',
       e.data ->> 'unit',
       e.data ->> 'note',
       e.id,
       entered_late(e)
  from event e
  join term o on o.id = e.operation_id
  join node n on e.subject_type = 'node' and n.id = e.subject_id
 where o.value not in ('sample', 'weigh', 'watch', 'unwatch', 'restate_shares',
                       'bins_moved', 'reassign')
union all
-- What was done to a vessel while it held the lot: a jacket turned on, a
-- temperature read off a dial.
select p.node_id, n.name, v.id, v.name, e.at, o.value, o.label, 'action',
       case when (coalesce(e.data ->> 'setpoint_c', e.data ->> 'temp_c')) ~ '^-?[0-9]+([.][0-9]+)?$'
            then coalesce(e.data ->> 'setpoint_c', e.data ->> 'temp_c')::numeric end,
       e.data ->> 'mode',
       case when e.data ? 'setpoint_c' or e.data ? 'temp_c' then '°C' end,
       e.data ->> 'note',
       e.id,
       entered_late(e)
  from event e
  join term o on o.id = e.operation_id
  join vessel v on e.subject_type = 'vessel' and v.id = e.subject_id
  join placement p on p.vessel_id = v.id and p.from_at <= e.at
                  and (p.to_at is null or p.to_at > e.at)
  join node n on n.id = p.node_id
 where o.value not in ('sample', 'move_vessel');

comment on view lot_series is
  'Every reading taken from and everything done to a lot, one variable at one time a row: '
  'the shape a chart draws and a model reads. Derived from notes and events.';

-- The lots worth a ferment log: fermenting, whether on skins or not, with
-- the vessels they are in now.
create or replace view ferment_lot with (security_invoker = true) as
select n.id as node_id, n.name, n.quantity, n.unit,
       coalesce((n.attributes ->> 'on_skins')::boolean, false) as on_skins,
       array_agg(v.id order by v.name)   as vessel_ids,
       array_agg(v.name order by v.name) as vessels,
       -- When it first went into a vessel, not when it was last racked: the
       -- start of the ferment is what hours-in counts from.
       (select min(p0.from_at) from placement p0 where p0.node_id = n.id) as since
  from node n
  join placement p on p.node_id = n.id and p.to_at is null
  join vessel v on v.id = p.vessel_id
 where n.status = 'open' and n.stage = 'ferment'
 group by n.id, n.name, n.quantity, n.unit, n.attributes;

comment on view ferment_lot is
  'Every lot fermenting now, with its fermenters: what the ferment log offers.';

-- ---------------------------------------------------------------------------
-- The contract
-- ---------------------------------------------------------------------------

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('cellar.record_reading', 'cellar', 'Take a reading',
   'A Brix, or any other kind of reading, from one fermenter. Blank boxes are skipped.',
   'record_reading',
   '[{"key": "vessel", "type": "uuid", "label": "From which vessel", "param": "p_vessel_id", "required": true,
      "source": {"readable": "cellar.vessels"}},
     {"key": "readings", "type": "jsonb", "label": "What it read", "param": "p_readings", "required": true,
      "hint": "By kind: {\"brix\": 22.4}"},
     {"key": "at", "type": "timestamptz", "label": "When", "param": "p_at", "required": false,
      "hint": "Blank means now."},
     {"key": "note", "type": "text", "label": "Anything else", "param": "p_note", "required": false}]'::jsonb,
   128)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.lot_series', 'cellar', 'Ferment log',
   'Every reading and everything done to a lot, one variable at one time a row.',
   'lot_series', 'source_id', 'label', 18),
  ('cellar.ferment_lots', 'cellar', 'Fermenting now',
   'Every lot fermenting, with its fermenters.',
   'ferment_lot', 'node_id', 'name', 19)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into screen (key, label) values ('ferment', 'Ferment log')
on conflict (key) do nothing;
