-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "An administrator decides which of the things only administrators
--           could do a cellar hand may do too, and a cellar hand who may not is
--           told so in a sentence rather than by the database."
-- Depends on: [supabase/migrations/0002_derived_and_rls.sql,
--              supabase/migrations/0148_reds_go_into_fermenters.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  packages/cellar/src/index.ts, scripts/smoke.ts]
-- Axioms enforced: A13. A refusal says what was refused and who can change
--                  it, instead of "new row violates row-level security policy".
-- Open sorries: none new. S-145 is discharged.
-- ---------------------------------------------------------------------------

-- S-145 asked whether a cellar hand should be able to register a new bin in
-- the middle of a pick, and the answer was a better question: "maybe that
-- should be a setting the admins can toggle, like in general what permissions
-- are admin vs cellar."
--
-- **Settings widen; they never narrow.** Each is a row in `permission`, and
-- each table it governs gets one more permissive policy, `may(key)`, beside
-- the administrator's. Row level security ORs permissive policies, so with a
-- setting off nothing is different from yesterday, and with it on a cellar
-- hand has exactly what the setting says and nothing more. No existing policy
-- is rewritten.
--
-- **Only the decisions a winery would actually make differently.** The books,
-- accounts, invitations, custom crush clients and the contract registry stay
-- administrators' outright. What is here is what a cellar hand could plausibly
-- need on a harvest morning with nobody else about: a new bin, a new cooper, a
-- new place, the vineyard, the stores. Every one starts off, which is how the
-- winery runs today.
--
-- **The refusal is a door, not the database.** Every verb that adds a vessel
-- already lets anybody who works here through and then the table refuses them
-- in Postgres's words. A trigger in front of each table now refuses first, in a
-- sentence that says who can change it. It stands aside when nobody is signed
-- in, which is a migration or the assertion suite, because row level security
-- is still behind it and says the rest.

create table permission (
  key         text primary key,
  module      text not null,
  label       text not null,
  note        text not null,
  cellar_may  boolean not null default false,
  sort_order  int not null default 0,
  changed_by  uuid references app_user(id),
  changed_at  timestamptz
);

comment on table permission is
  'What a cellar hand may do beyond the default, as administrators have set it. '
  'Each row widens access; none narrows it.';

alter table permission enable row level security;
create policy permission_read on permission for select to authenticated using (true);
create policy permission_admin_write on permission for all to authenticated
  using (is_admin()) with check (is_admin());

insert into permission (key, module, label, note, sort_order) values
  ('vessels.register', 'cellar', 'Register vessels and bins',
   'Add a vessel, or new picking bins in the middle of a pick.', 100),
  ('vocabulary.add', 'core', 'Add to the lists',
   'Add a variety, a cooper, a maker, a way of sorting or any other entry from a picker''s "Add one".', 200),
  ('places.edit', 'core', 'Arrange places',
   'Add places and move them inside one another.', 300),
  ('vineyard.edit', 'vineyard', 'Edit the vineyard',
   'Vineyards, blocks, rows, plantings and plant spaces.', 400),
  ('stores.edit', 'inventory', 'Edit the stores',
   'Add supplies and change what is recorded about them.', 500)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  sort_order = excluded.sort_order;

-- May the person asking do this? An administrator may do everything; a cellar
-- hand may do what a setting allows; nobody else may do any of it.
create or replace function may(p_key text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select is_admin()
      or (is_facility_user()
          and exists (select 1 from permission where key = p_key and cellar_may));
$$;

comment on function may is
  'True when the person asking may do what the permission names: an administrator '
  'always, a cellar hand when an administrator has allowed it.';

grant execute on function may(text) to authenticated;

-- The one verb that changes a setting. Administrators only; who changed it and
-- when are kept on the row.
create or replace function set_permission(p_key text, p_cellar_may boolean)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if not is_admin() then
    raise exception 'only an administrator decides what cellar hands may do';
  end if;
  if p_cellar_may is null then
    raise exception 'say yes or no';
  end if;
  update permission
     set cellar_may = p_cellar_may, changed_by = auth.uid(), changed_at = now()
   where key = p_key;
  if not found then
    raise exception 'there is no setting called %', p_key;
  end if;
  return (select to_jsonb(p) from permission p where p.key = p_key);
end $$;

grant execute on function set_permission(text, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- The policies each setting adds
-- ---------------------------------------------------------------------------

create policy vessel_insert_if_allowed on vessel for insert to authenticated
  with check (may('vessels.register'));

create policy term_insert_if_allowed on term for insert to authenticated
  with check (may('vocabulary.add'));

create policy location_insert_if_allowed on location for insert to authenticated
  with check (may('places.edit'));
create policy location_update_if_allowed on location for update to authenticated
  using (may('places.edit')) with check (may('places.edit'));

create policy vineyard_insert_if_allowed on vineyard for insert to authenticated
  with check (may('vineyard.edit'));
create policy vineyard_update_if_allowed on vineyard for update to authenticated
  using (may('vineyard.edit')) with check (may('vineyard.edit'));
create policy block_insert_if_allowed on block for insert to authenticated
  with check (may('vineyard.edit'));
create policy block_update_if_allowed on block for update to authenticated
  using (may('vineyard.edit')) with check (may('vineyard.edit'));
create policy vine_row_insert_if_allowed on vine_row for insert to authenticated
  with check (may('vineyard.edit'));
create policy vine_row_update_if_allowed on vine_row for update to authenticated
  using (may('vineyard.edit')) with check (may('vineyard.edit'));
create policy planting_insert_if_allowed on planting for insert to authenticated
  with check (may('vineyard.edit'));
create policy planting_update_if_allowed on planting for update to authenticated
  using (may('vineyard.edit')) with check (may('vineyard.edit'));
create policy plant_space_insert_if_allowed on plant_space for insert to authenticated
  with check (may('vineyard.edit'));
create policy plant_space_update_if_allowed on plant_space for update to authenticated
  using (may('vineyard.edit')) with check (may('vineyard.edit'));

create policy supply_insert_if_allowed on supply for insert to authenticated
  with check (may('stores.edit'));
create policy supply_update_if_allowed on supply for update to authenticated
  using (may('stores.edit')) with check (may('stores.edit'));

-- ---------------------------------------------------------------------------
-- The door in front of each table
-- ---------------------------------------------------------------------------

create or replace function permission_door()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  k text := tg_argv[0];
  what text := tg_argv[1];
begin
  -- Only in front of the app's own roles, exactly where row level security
  -- stands. The table's owner, which is a migration or the assertion suite
  -- setting up, is never subject to row level security and is not subject to
  -- this either; and nobody signed in is left to row level security to refuse.
  if current_user not in ('authenticated', 'anon') or auth.uid() is null then
    return new;
  end if;
  -- As `insufficient_privilege`, the SQLSTATE row level security itself would
  -- have raised. It is the same refusal in better words, and anything that
  -- tells a refusal from a failure by its code goes on telling it.
  if not may(k) then
    raise exception using
      errcode = 'insufficient_privilege',
      message = format('%s is for administrators here. An administrator can let cellar hands do it, under Who may do what.', what);
  end if;
  return new;
end $$;

create trigger vessel_permission_door before insert on vessel
  for each row execute function permission_door('vessels.register', 'Registering a vessel or a bin');
create trigger term_permission_door before insert on term
  for each row execute function permission_door('vocabulary.add', 'Adding to the lists');
create trigger location_permission_door before insert on location
  for each row execute function permission_door('places.edit', 'Adding a place');
create trigger vineyard_permission_door before insert on vineyard
  for each row execute function permission_door('vineyard.edit', 'Adding a vineyard');
create trigger block_permission_door before insert on block
  for each row execute function permission_door('vineyard.edit', 'Adding a block');
create trigger vine_row_permission_door before insert on vine_row
  for each row execute function permission_door('vineyard.edit', 'Adding a row');
create trigger planting_permission_door before insert on planting
  for each row execute function permission_door('vineyard.edit', 'Adding a planting');
create trigger plant_space_permission_door before insert on plant_space
  for each row execute function permission_door('vineyard.edit', 'Adding a plant space');
create trigger supply_permission_door before insert on supply
  for each row execute function permission_door('stores.edit', 'Adding a supply');

insert into capability_exemption (fn, reason) values
  ('may', 'Answers whether the person asking may do something. Read by policies and by screens deciding what to offer; it changes nothing.'),
  ('permission_door', 'A trigger function in front of the tables settings govern, refusing in a sentence before row level security refuses in Postgres''s words.')
on conflict (fn) do update set reason = excluded.reason;

insert into capability (key, module, label, note, fn, fields, sort_order) values
  ('core.set_permission', 'core', 'Decide what cellar hands may do',
   'Administrators only. Each setting widens what a cellar hand may do; none narrows it.',
   'set_permission',
   '[{"key": "key", "type": "text", "label": "Which setting", "param": "p_key", "required": true,
      "source": {"readable": "core.permissions"}},
     {"key": "cellar_may", "type": "boolean", "label": "Cellar hands may", "param": "p_cellar_may", "required": true}]'::jsonb,
   900)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, fields = excluded.fields, sort_order = excluded.sort_order;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('core.permissions', 'core', 'Who may do what',
   'What cellar hands may do beyond the default, as administrators have set it.',
   'permission', 'key', 'label', 900)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into screen (key, label) values
  ('permissions', 'Who may do what')
on conflict (key) do nothing;
