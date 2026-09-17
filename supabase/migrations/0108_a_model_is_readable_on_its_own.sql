-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A machine model can be listed without owning a machine of it, which
--           is what registering a model and then a machine actually requires."
-- Depends on: [supabase/migrations/0106_the_acts_a_shop_performs.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0109_a_module_says_where_it_lives.sql]
-- Axioms enforced: AR-Q8 (a screen reads a readable; when there is no readable
--                  the screen invents one, and this is what it invented)
-- Open sorries: none. Discharges S-92.
-- ---------------------------------------------------------------------------
--
-- `0106` registered two readables and forgot the obvious third. With no way to
-- list models, the add-a-machine screen built its list out of the machines that
-- already existed, taking each one's model, which works for every model except
-- the one you have just created and are about to use.
--
-- So: register a model, go to add a machine, and the model is not in the list.
-- That is the first thing anybody does with this, and it is the shape AR-Q8
-- names: a screen with no readable does not stop, it invents one, and what it
-- invents is worse than what the kernel would have said.
--
-- Discharges S-92.

begin;

create or replace view machine_model_detail with (security_invoker = true) as
select
  mm.id,
  mm.make,
  mm.model,
  mm.make || ' ' || mm.model as name,
  k.label   as kind,
  mm.spec,
  mm.note,
  mm.active,
  -- How many of these this winery has, because a model with none is a model
  -- somebody registered and has not used yet, and that is worth seeing rather
  -- than being the reason it is invisible.
  (select count(*) from machine m where m.model_id = mm.id and m.active) as machines
from machine_model mm
left join term k on k.id = mm.kind_id
where mm.active;

comment on view machine_model_detail is
  'Machine models, whether or not anybody owns one. The count is how many of '
  'this winery''s machines are of it. See 0106 and 0108.';

grant select on machine_model_detail to authenticated;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('shop.models', 'shop', 'Machine models',
   'What each kind of machine is as the manufacturer ships it, whether or not one is here yet.',
   'machine_model_detail', 'id', 'name', 305)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

-- And the capability that makes a machine can now point at it, instead of
-- pointing at the machine list as a stand-in for a list of models.
update capability
   set fields = '[{"key":"name","param":"p_name","type":"text","required":true,"label":"Called"},
     {"key":"model","param":"p_model_id","type":"uuid","required":false,
      "label":"Which model","source":{"readable":"shop.models"}},
     {"key":"serial","param":"p_serial","type":"text","required":false,"label":"Serial number"},
     {"key":"vessel","param":"p_vessel_id","type":"uuid","required":false,
      "label":"It is also this vessel","source":{"readable":"cellar.vessels"}},
     {"key":"where","param":"p_location_id","type":"uuid","required":false,
      "label":"Where it lives","source":{"readable":"cellar.rooms"}},
     {"key":"acquired","param":"p_acquired_at","type":"date","required":false,
      "label":"When you got it"}]'::jsonb
 where key = 'shop.register_machine';

commit;
