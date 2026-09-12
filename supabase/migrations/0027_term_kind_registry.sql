-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Turns term_kind from a core enum carrying inventory and winemaking
--           vocabulary into rows in a registry. Adding a kind of vocabulary is
--           now a row, and core stops holding a fixed list of the things higher
--           modules are allowed to have words for."
-- Depends on: [supabase/migrations/0004_terms_and_effects.sql,
--              supabase/migrations/0011_vessel_type_fields.sql,
--              supabase/migrations/0019_procedures.sql,
--              supabase/migrations/0026_subject_type_registry.sql,
--              docs/architecture-rulings.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: none new. Like 0026 this removes a wrong-way edge rather than
--                  adding a rule.
-- Open sorries: none new. A16 is untouched and is neither better nor worse; see
--                the note at the end.
-- ---------------------------------------------------------------------------

-- AR-E7, second half, and the larger one. `term_kind` was a core enum listing
-- variety, cooper, wood, vessel_type, product_type, material_kind, operation and
-- location_kind. Four of those are winemaking vocabulary and one is inventory's,
-- so core held a fixed list of the things other modules may have words for, and
-- extending it meant a core migration.
--
-- `0004` set the precedent by moving the winemaking enums into `term`, and this
-- follows it: values become rows, columns become references, the type goes. The
-- kinds cannot land in `term` itself, because `term.kind` is what they classify,
-- so they land in a registry of their own with the module that owns each.
--
-- **Written against the catalog rather than by hand, which is a deviation worth
-- stating.** This touches nine generated columns, nine composite foreign keys,
-- two views, three constraints and an index, and hand-listing eighteen objects
-- is precisely where one gets missed. `0020` set the precedent for enumerating
-- from the catalog inside a migration, and the saved definitions are recreated
-- verbatim with one substitution, so nothing is reconstructed from memory. That
-- also means this migration adapts if a tenth generated column exists by the
-- time it runs.

-- ---------------------------------------------------------------------------
-- Save what has to come back
-- ---------------------------------------------------------------------------

-- Session lifetime rather than `on commit drop`: psql runs a file statement by
-- statement in autocommit, so a transaction-scoped temp table vanishes after the
-- first insert and everything after it fails on a table that does not exist.
drop table if exists _w4_saved;
create temporary table _w4_saved (what text, name text, def text);

-- Every view in public, and every function that returns one of them as a type.
-- Not only the two that select a *_kind column: `resolve_vessel_code` returns
-- `setof vessel_state`, so it depends on the view's composite type and blocks the
-- drop, and finding that out by being refused is the reason this takes all of
-- them rather than the two it first appeared to need. Their definitions are
-- recreated verbatim; none of them names the type, only columns.
insert into _w4_saved
select 'view', c.relname,
       format('create view public.%I%s as %s',
              c.relname,
              case when c.reloptions is not null
                   then ' with (' || array_to_string(c.reloptions, ', ') || ')'
                   else '' end,
              pg_get_viewdef(c.oid, true))
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'v';

insert into _w4_saved
select 'viewfn', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
       pg_get_functiondef(p.oid)
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and exists (
     select 1 from pg_class c join pg_namespace vn on vn.oid = c.relnamespace
      where vn.nspname = 'public' and c.relkind = 'v' and c.reltype = p.prorettype);

-- The nine composite foreign keys into term(id, kind).
insert into _w4_saved
select 'fk', t.relname || '.' || c.conname,
       format('alter table public.%I add constraint %I %s', t.relname, c.conname,
              pg_get_constraintdef(c.oid))
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
 where n.nspname = 'public' and c.contype = 'f'
   and pg_get_constraintdef(c.oid) like '%REFERENCES term(id, kind)%';

-- The nine generated columns. Only the expression is saved, because these are
-- altered in place rather than dropped and re-added.
--
-- **That is not a stylistic choice and the first version of this migration got it
-- wrong.** Dropping a generated column and adding it back moves it to the end of
-- the table, and `vessel_state` reads `visible_node(p.node_id)` through a
-- positional column alias list. Reordering `node` silently rebound
-- `product_type_id` to `hidden`, and the view came back with `uuid = text[]`.
-- It failed loudly here; in a migration that did not recreate the view it would
-- not have.
insert into _w4_saved
select 'gencol', c.relname || '.' || a.attname,
       replace(pg_get_expr(d.adbin, d.adrelid, true), '::term_kind', '::text')
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
 where n.nspname = 'public' and a.attgenerated = 's'
   and format_type(a.atttypid, null) = 'term_kind';

-- Column defaults that mention the type or call term_id. A default is a
-- dependency in its own right, which 0026 learned from procedure.subject_type and
-- this one learns again from node.product_type_id, whose default is
-- term_id('product_type'::term_kind, 'wine'). Saved with the cast rewritten and
-- restored after term_id exists again.
insert into _w4_saved
select 'default', c.relname || '.' || a.attname,
       format('alter table public.%I alter column %I set default %s',
              c.relname, a.attname,
              replace(pg_get_expr(d.adbin, d.adrelid, true), '::term_kind', '::text'))
  from pg_attrdef d
  join pg_class c on c.oid = d.adrelid
  join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and a.attgenerated = ''
   and pg_get_expr(d.adbin, d.adrelid, true) ~ '(term_kind|term_id)';

-- ---------------------------------------------------------------------------
-- Take it all down
-- ---------------------------------------------------------------------------

do $$
declare r record;
begin
  for r in select name from _w4_saved where what = 'viewfn' loop
    execute format('drop function public.%s', r.name);
  end loop;

  for r in select name from _w4_saved where what = 'view' loop
    execute format('drop view public.%I', r.name);
  end loop;

  for r in select split_part(name, '.', 1) as tbl, split_part(name, '.', 2) as con
             from _w4_saved where what = 'fk' loop
    execute format('alter table public.%I drop constraint %I', r.tbl, r.con);
  end loop;

  -- Altered in place, which keeps their position and therefore keeps every
  -- positional alias list in the views valid.
  for r in select split_part(name, '.', 1) as tbl, split_part(name, '.', 2) as col, def
             from _w4_saved where what = 'gencol' loop
    execute format('alter table public.%I alter column %I type text', r.tbl, r.col);
    execute format('alter table public.%I alter column %I set expression as (%s)',
                   r.tbl, r.col, r.def);
  end loop;

  for r in select split_part(name, '.', 1) as tbl, split_part(name, '.', 2) as col
             from _w4_saved where what = 'default' loop
    execute format('alter table public.%I alter column %I drop default', r.tbl, r.col);
  end loop;
end $$;

-- term's own constraints and index over kind.
alter table term drop constraint term_id_kind_key;
alter table term drop constraint term_kind_value_key;
alter table term drop constraint operation_has_an_effect;
drop index term_kind_idx;

-- term_id takes the enum in its signature, and two function bodies cast to it.
-- The trigger has to go before its function, and it is recreated at the bottom
-- alongside the rebuilt validator. It lives on `term`, because a vessel type's
-- field list is `term.attributes -> 'fields'` rather than a table of its own.
drop trigger term_vessel_type_fields_valid on term;

drop function term_id(term_kind, text);
drop function terms_for_vessel_field(uuid, text);
drop function validate_vessel_type_fields();

-- ---------------------------------------------------------------------------
-- The type becomes a table
-- ---------------------------------------------------------------------------

alter table term alter column kind type text;
drop type term_kind;

create table term_kind (
  kind        text primary key,
  module      text not null,
  label       text not null,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),

  constraint term_kind_is_a_bare_name check (kind ~ '^[a-z_][a-z0-9_]*$'),
  constraint term_kind_module_is_a_bare_name check (module ~ '^[a-z_][a-z0-9_]*$')
);

comment on table term_kind is
  'Which kinds of vocabulary exist, and which module owns each. Was an enum in core listing winemaking and inventory words, which is the wrong-way edge AR-E7 describes. Adding a kind is a row.';

-- The eight that existed, with the module each belongs to. Reading this list is
-- the clearest statement of why the enum was wrong: only two of the eight are
-- core's business.
insert into term_kind (kind, module, label, sort_order) values
  ('variety',       'winemaking', 'Variety',        10),
  ('cooper',        'winemaking', 'Cooper',         20),
  ('wood',          'winemaking', 'Wood',           30),
  ('vessel_type',   'winemaking', 'Vessel type',    40),
  ('product_type',  'winemaking', 'Product type',   50),
  ('material_kind', 'inventory',  'Material kind',  60),
  ('operation',     'core',       'Operation',      70),
  ('location_kind', 'core',       'Location kind',  80);

alter table term_kind enable row level security;

create policy term_kind_read on term_kind
  for select to authenticated using (true);

create policy term_kind_admin_write on term_kind
  for all to authenticated
  using (is_admin()) with check (is_admin());

alter table term add constraint term_kind_is_registered
  foreign key (kind) references term_kind(kind) on delete restrict;

-- ---------------------------------------------------------------------------
-- Put it all back
-- ---------------------------------------------------------------------------

alter table term add constraint term_kind_value_key unique (kind, value);
alter table term add constraint term_id_kind_key unique (id, kind);
create index term_kind_idx on term(kind);

-- Recreated with text rather than the enum, and otherwise character for
-- character what 0004 wrote. Note that this preserves ledger A24: the predicate
-- still permits an operation carrying no effect at all, because `null in (...)`
-- is null and a check constraint passes on null. Fixing that is section A and
-- out of scope, and the assertion for A24 is written so that fixing it fails
-- that assertion.
alter table term add constraint operation_has_an_effect check (
  kind <> 'operation'
  or attributes ->> 'effect' in
     ('measurement', 'treatment', 'movement', 'transformation')
);

do $$
declare r record;
begin
  for r in select def from _w4_saved where what = 'fk' order by name loop
    execute r.def;
  end loop;
  for r in select def from _w4_saved where what = 'view' order by name loop
    execute r.def;
  end loop;
  for r in select def from _w4_saved where what = 'viewfn' order by name loop
    execute r.def;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- The three functions, taking and casting text
-- ---------------------------------------------------------------------------

create or replace function term_id(p_kind text, p_value text)
returns uuid
language sql
stable
set search_path = public, pg_temp
as $$
  select id from term where kind = p_kind and value = p_value;
$$;

-- Both bodies are 0009's and 0011's, character for character, with the single
-- change each needs. They are reproduced here rather than saved and substituted
-- because one of them cannot be substituted safely, which is the next comment.

create or replace function terms_for_vessel_field(p_vessel_type_id uuid, p_field_key text)
returns setof term
language sql
stable
set search_path = public, pg_temp
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
     and t.kind = (spec.f ->> 'term_kind')::text
     and (
       spec.f ->> 'contract' is null
       or t.attributes ->> 'contract' is null
       or t.attributes ->> 'contract' = spec.f ->> 'contract'
     )
   order by t.sort_order, t.label;
$$;

-- **The one place in this migration where a blind substitution would have been a
-- silent defect, and the reason the bodies are not machine-rewritten.**
--
-- This validator checked that a picker names a real vocabulary by casting the
-- text to the enum and catching the failure. That is a perfectly good check while
-- `term_kind` is a closed type: an unknown word cannot be cast and the exception
-- handler turns it into a readable message. It is the check that produced the
-- error 0020 records, "field maker names vocabulary cooper, which does not
-- exist".
--
-- Rewrite `::term_kind` to `::text` and the cast always succeeds. The exception
-- handler never fires, the validator silently stops validating, and a vessel type
-- can name a vocabulary that does not exist with nothing to say so. That is
-- exactly the shape W-4 warns this conversion produces: a value that was
-- unrepresentable becomes representable, and a predicate written against a closed
-- set now has a third answer.
--
-- So the check becomes a lookup in the registry, which is what the registry is
-- for, and the message it raises is unchanged.
create or replace function validate_vessel_type_fields()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  f    jsonb;
  seen text[] := '{}';
  k    text;
begin
  if new.kind <> 'vessel_type' or not (new.attributes ? 'fields') then
    return new;
  end if;

  if jsonb_typeof(new.attributes -> 'fields') <> 'array' then
    raise exception 'fields must be a list';
  end if;

  for f in select value from jsonb_array_elements(new.attributes -> 'fields')
  loop
    k := f ->> 'key';
    if k is null or btrim(k) = '' then
      raise exception 'every field needs a key';
    end if;
    if k = any(seen) then
      raise exception 'two fields share the key %', k;
    end if;
    seen := seen || k;

    if (f ->> 'kind') not in ('term', 'number', 'text') then
      raise exception 'field % has kind %, which is not term, number or text',
        k, coalesce(f ->> 'kind', 'nothing');
    end if;

    if (f ->> 'kind') = 'term' then
      if f ->> 'term_kind' is null then
        raise exception 'field % is a picker and names no vocabulary', k;
      end if;
      -- Was: perform (f ->> 'term_kind')::term_kind, inside a begin/exception.
      if not exists (select 1 from term_kind tk where tk.kind = f ->> 'term_kind') then
        raise exception 'field % names vocabulary %, which does not exist',
          k, f ->> 'term_kind';
      end if;
    end if;

    if (f ->> 'min') is not null and (f ->> 'max') is not null
       and (f ->> 'min')::numeric > (f ->> 'max')::numeric then
      raise exception 'field % has a minimum above its maximum', k;
    end if;
  end loop;

  return new;
end;
$$;

create trigger term_vessel_type_fields_valid
  before insert or update on term
  for each row execute function validate_vessel_type_fields();

-- ---------------------------------------------------------------------------
-- The defaults, now that term_id exists again
-- ---------------------------------------------------------------------------

do $$
declare r record;
begin
  for r in select def from _w4_saved where what = 'default' order by name loop
    execute r.def;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- A16, recorded rather than touched
-- ---------------------------------------------------------------------------

-- W-2 asked that this migration say whether it makes A16 better or worse. A16 is
-- that `term.value`, the join key the database resolves terms by, is derived by
-- eight chained string operations in one TypeScript file.
--
-- Neither. `term.value` is untouched, and `term.kind` moving from an enum to a
-- text reference changes nothing about how a value is derived or matched. The one
-- thing worth noting for whoever does fix it: `kind` is now subject to the same
-- class of problem, since it is text with a foreign key rather than a closed
-- type, and the bare-name check on term_kind is what keeps it from drifting the
-- way value has.

drop table _w4_saved;
