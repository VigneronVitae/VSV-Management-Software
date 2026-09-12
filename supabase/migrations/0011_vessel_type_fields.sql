-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Moves the vessel form's field list out of the client and into the
--           vessel type, so a type can say which fields it has rather than only
--           which of a fixed five it opens. A cooper, a toast level, a shape and
--           an oxygen ingress figure are all the same kind of thing: a fact this
--           facility wants recorded about this sort of vessel."
-- Depends on: [supabase/migrations/0004_terms_and_effects.sql,
--              supabase/migrations/0009_vessel_type_form.sql,
--              supabase/migrations/0010_glycol_by_type.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql, supabase/migrations/0012_vessel_type_notes.sql]
-- Axioms enforced: T1-1 (pickers, not text fields), T0-2 (the database refuses
--                  what is meaningless rather than the screen declining to ask)
-- Open sorries: S-20 (a field descriptor carries unit, and unit is display only)
-- Reactivates: C-6, whose kill reason was that configuration screens would be
--              built "before anyone had discovered which fields they actually
--              want to edit". They have now been discovered and named: toast
--              level, fill number, shape, oxygen ingress.
-- ---------------------------------------------------------------------------

-- A field descriptor. Every key except the first four is optional, and the ones
-- this migration does not yet enforce are reserved on purpose so that adding
-- enforcement later is a change to one function rather than to every stored
-- vessel type.
--
--   key         stable identifier, and the key inside vessel.attributes
--   label       what the form calls it
--   kind        term | number | text
--   sort_order  position in the form
--
--   term_kind   for kind = term: which vocabulary it draws from
--   contract    for kind = term: which partition of that vocabulary
--   open        expanded by default, rather than behind More details
--   hint        the small grey line under the input
--   unit        for kind = number: shown beside the input. Display only, S-20
--   required    refused when absent
--   min, max    for kind = number: refused when outside
--
-- Built-in fields are deliberately not in this list. name, capacity, location,
-- owner, photo and codes are structural, and the jacket is three real columns
-- the kernel computes effective_temp_c from, so none of them can be a facility
-- invention. The jacket's visibility stays in `expand`, which is the one thing
-- about a built-in that a type may decide.

-- ---------------------------------------------------------------------------
-- The four seeded types describe themselves
-- ---------------------------------------------------------------------------

update term
   set attributes = attributes || jsonb_build_object('fields', jsonb_build_array(
         jsonb_build_object('key','maker','label','Cooper','kind','term',
                            'term_kind','cooper','contract','cooper',
                            'open',true,'sort_order',10),
         jsonb_build_object('key','wood','label','Wood','kind','term',
                            'term_kind','wood','open',true,'sort_order',20),
         jsonb_build_object('key','fill_count','label','Fill count','kind','number',
                            'hint','How many wines this barrel has held, this one included.',
                            'open',true,'min',0,'sort_order',30),
         jsonb_build_object('key','toast','label','Toast','kind','text',
                            'open',true,'sort_order',40)))
 where kind = 'vessel_type' and value = 'barrel';

update term
   set attributes = attributes || jsonb_build_object('fields', jsonb_build_array(
         jsonb_build_object('key','maker','label','Manufacturer','kind','term',
                            'term_kind','cooper','contract','manufacturer',
                            'open',false,'sort_order',10)))
 where kind = 'vessel_type' and value in ('tank', 'fermenter', 'macrobin');

-- ---------------------------------------------------------------------------
-- Which terms a given field on a given type may offer
-- ---------------------------------------------------------------------------

-- Generalises makers_for_vessel_type, which only knew about one field. A term
-- with no contract satisfies every contract, which is what keeps anything added
-- before 0009 visible.
create or replace function terms_for_vessel_field(
  p_vessel_type_id uuid,
  p_field_key      text
)
returns setof term
language sql
stable
as $$
  with spec as (
    select f
      from term vt,
           lateral jsonb_array_elements(coalesce(vt.attributes -> 'fields', '[]'::jsonb)) f
     where vt.id = p_vessel_type_id
       and f ->> 'key' = p_field_key
     limit 1
  )
  select t.*
    from term t, spec
   where t.active
     and t.kind = (spec.f ->> 'term_kind')::term_kind
     and (
       spec.f ->> 'contract' is null
       or t.attributes ->> 'contract' is null
       or t.attributes ->> 'contract' = spec.f ->> 'contract'
     )
   order by t.sort_order, t.label;
$$;

-- Kept so nothing that already calls it breaks. It is now the special case of
-- the general function rather than its own idea.
create or replace function makers_for_vessel_type(p_vessel_type_id uuid)
returns setof term
language sql
stable
as $$
  select * from terms_for_vessel_field(p_vessel_type_id, 'maker');
$$;

-- ---------------------------------------------------------------------------
-- The declared constraints, enforced
-- ---------------------------------------------------------------------------

-- A descriptor that says required and is not enforced is a lie told by a form.
-- This runs on every vessel write, so a second client gets the same refusals
-- without reimplementing them, which is the whole reason it is not in a screen.
create or replace function validate_vessel_attributes(
  p_type_id    uuid,
  p_attributes jsonb
)
returns void
language plpgsql
stable
as $$
declare
  f    jsonb;
  v    jsonb;
  name text;
  num  numeric;
begin
  for f in
    select value from jsonb_array_elements(
      coalesce((select attributes -> 'fields' from term where id = p_type_id),
               '[]'::jsonb))
  loop
    name := coalesce(f ->> 'label', f ->> 'key');
    v    := p_attributes -> (f ->> 'key');

    if v is null or jsonb_typeof(v) = 'null'
       or (jsonb_typeof(v) = 'string' and (v #>> '{}') = '') then
      if coalesce((f ->> 'required')::boolean, false) then
        raise exception '% is required for this vessel type', name;
      end if;
      continue;
    end if;

    if (f ->> 'kind') = 'number' then
      begin
        num := (v #>> '{}')::numeric;
      exception when others then
        raise exception '% must be a number', name;
      end;
      if (f ->> 'min') is not null and num < (f ->> 'min')::numeric then
        raise exception '% must be at least %', name, f ->> 'min';
      end if;
      if (f ->> 'max') is not null and num > (f ->> 'max')::numeric then
        raise exception '% must be at most %', name, f ->> 'max';
      end if;

    elsif (f ->> 'kind') = 'term' then
      if not exists (
        select 1 from terms_for_vessel_field(p_type_id, f ->> 'key') t
         where t.id::text = (v #>> '{}')
      ) then
        raise exception '% must be chosen from its own list', name;
      end if;
    end if;
  end loop;
end;
$$;

create or replace function vessel_attributes_guard()
returns trigger
language plpgsql
as $$
begin
  perform validate_vessel_attributes(new.type_id, new.attributes);
  return new;
end;
$$;

create trigger vessel_attributes_valid
  before insert or update of attributes, type_id on vessel
  for each row execute function vessel_attributes_guard();
