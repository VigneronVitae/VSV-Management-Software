-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Lets anyone say a vessel type is wrong without letting anyone but
--           an admin make it wrong. A cellar hand at the tank who notices a
--           missing field leaves a note; an admin reads it and decides. The
--           note is the suggestion, not the change."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              supabase/migrations/0011_vessel_type_fields.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-4 (a producer cannot grant itself standing: writing a
--                  note is not the same as changing the form)
-- Open sorries: none new
-- ---------------------------------------------------------------------------

-- The permission question this answers is narrower than it looks. Editing a
-- vessel type changes what every vessel of that type is asked, retroactively,
-- for everyone. That is admin work and stays admin work. But the person who
-- discovers the gap is almost never the admin: it is whoever is standing at the
-- tank at 6am finding nowhere to write down the thing they just measured.
--
-- Blocking them loses the observation. Letting them edit loses the form. A note
-- keeps both: the observation is recorded immediately, and the change still
-- takes a decision.

create table vessel_type_note (
  id             uuid primary key default gen_random_uuid(),
  vessel_type_id uuid not null references term(id) on delete cascade,
  body           text not null check (length(btrim(body)) > 0),
  created_by     uuid references app_user(id),
  created_at     timestamptz not null default now(),
  resolved_at    timestamptz,
  resolved_by    uuid references app_user(id),

  -- Resolved is a decision an admin made, so it carries who made it, the same
  -- way provenance does on an event.
  constraint resolved_has_an_author
    check ((resolved_at is null) = (resolved_by is null))
);

create index vessel_type_note_open_idx
  on vessel_type_note(vessel_type_id) where resolved_at is null;

alter table vessel_type_note enable row level security;

-- Anyone signed in may write one. This is the whole point.
create policy vessel_type_note_insert on vessel_type_note
  for insert to authenticated
  with check (created_by = auth.uid());

-- Anyone may read them, including the person who wrote one. Hiding a note from
-- its author would mean they cannot tell whether it landed, and would make the
-- second thing they do a duplicate of the first.
create policy vessel_type_note_read on vessel_type_note
  for select to authenticated using (true);

-- Resolving is the admin half of the decision.
create policy vessel_type_note_resolve on vessel_type_note
  for update to authenticated using (is_admin()) with check (is_admin());

-- ---------------------------------------------------------------------------
-- A descriptor that would break the form is refused
-- ---------------------------------------------------------------------------

-- Without this an admin can save a field with no key, or a term field naming a
-- vocabulary that does not exist, and every vessel form for that type breaks at
-- once for everybody. The editor is the only thing that writes these, so the
-- check belongs where a second editor would also hit it.
create or replace function validate_vessel_type_fields()
returns trigger
language plpgsql
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
      begin
        perform (f ->> 'term_kind')::term_kind;
      exception when others then
        raise exception 'field % names vocabulary %, which does not exist',
          k, f ->> 'term_kind';
      end;
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
