-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The modules, as rows, so the front door lists what this winery has
--           rather than a list somebody typed into a client."
-- Depends on: [supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0108_a_model_is_readable_on_its_own.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0110_the_front_door_opens_before_you_sign_in.sql,
--                  supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql]
-- Axioms enforced: AR-E5 (a registry row rather than a list in a client), T0-2
--                  (whether a module has anything in it is counted from the
--                  contract, not declared twice)
-- Open sorries: S-94
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"Could we have /cellar/ be the cellar one and the root be the
-- chooser that you pick cellar/shop/inventory/marketing/get new modules/etc?"*
--
-- **The module column already exists everywhere and nothing has ever read it.**
-- `readable`, `capability` and `term_kind` have carried one since `0027`, and
-- today they name six: cellar with 62 rows, shop with 8, winemaking with 7, core
-- with 4, and inventory and vineyard with one each. What was missing is anything
-- saying what a module *is*, and in particular which of them a person can open.
--
-- Because that is the distinction the front door needs. `winemaking` and `core`
-- are vocabularies the kernel speaks, not places to go; `cellar` and `shop` are
-- apps; `inventory` and `vineyard` are neither yet, being a handful of kernel
-- rows and no screens at all. A chooser that lists all six equally would offer
-- four doors that open onto nothing.
--
-- So a row per module says its name, what it is for, and where its periphery
-- lives when it has one. A module with no path is not a broken link, it is a
-- module somebody has started in the kernel and not yet given a face, and saying
-- so is more useful than hiding it: it is the honest version of "get new
-- modules".
--
-- **How much is in it is counted, never declared.** `module_detail` counts the
-- readables and capabilities each one owns, so a module cannot claim to be
-- substantial while being empty, and inventory saying "1 capability" is the true
-- picture of inventory.

begin;

create table if not exists module (
  key        text primary key,
  label      text not null,
  note       text not null,
  -- Where its periphery is served, relative to the front door. Null means the
  -- kernel knows about this module and nobody can open it yet.
  path       text,
  -- Ordinary sorting, with the built ones first because those are the ones
  -- somebody is actually trying to reach.
  sort_order int not null default 100,
  active     boolean not null default true,
  constraint module_says_something check (btrim(label) <> '' and btrim(note) <> ''),
  -- A path is a path. Anything else is a typo that becomes a link to nowhere.
  constraint module_path_is_a_path check (path is null or path ~ '^/[a-z0-9/-]*$')
);

comment on table module is
  'The modules this winery has, and where each one can be opened. A null path '
  'is a module the kernel knows and nobody can open yet. See 0109.';

alter table module enable row level security;

drop policy if exists module_read on module;
-- Readable by anybody signed in, including a client: the front door has to draw
-- itself before it knows who is looking, and the list of modules says nothing
-- about whose wine is in what.
create policy module_read on module for select to authenticated using (true);
drop policy if exists module_write on module;
create policy module_write on module for all to authenticated
  using (is_admin()) with check (is_admin());

insert into module (key, label, note, path, sort_order) values
  ('cellar', 'Cellar',
   'Vessels, lots, picking, pressing, racking. What happens to wine.',
   '/cellar/', 10),
  ('shop', 'Shop',
   'Machines, what they are, and everything done to them. The press, the tractor, the sorting line.',
   '/shop/', 20),
  -- Kernel rows and no face. Listed rather than hidden, because "started and
  -- not finished" is a truer thing to show somebody than nothing at all.
  ('inventory', 'Stores',
   'Dry goods and what is on the shelves. The kernel has a little of this and there is no screen yet.',
   null, 30),
  ('vineyard', 'Vineyards',
   'Blocks, plantings and what is growing where. Reachable from the cellar app today rather than on its own.',
   null, 40),
  -- Named by the winemaker as one he expects. Nothing in the kernel yet, and
  -- saying so is the point of listing it.
  ('marketing', 'Marketing',
   'Nothing here yet. Named because it is expected, so that wanting it is written down somewhere other than a conversation.',
   null, 50)
on conflict (key) do update set
  label = excluded.label, note = excluded.note,
  path = excluded.path, sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- What the front door reads
-- ---------------------------------------------------------------------------

create or replace view module_detail with (security_invoker = true) as
select
  m.key,
  m.label,
  m.note,
  m.path,
  m.sort_order,
  (m.path is not null) as openable,
  -- Counted from the contract rather than stated here, so a module cannot say
  -- it is substantial while being empty.
  (select count(*) from readable r where r.module = m.key)   as readables,
  (select count(*) from capability c where c.module = m.key) as capabilities
from module m
where m.active
order by m.sort_order, m.label;

comment on view module_detail is
  'The modules, with how much of the contract each one owns. The front door '
  'draws itself from this. See 0109.';

grant select on module_detail to authenticated;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('core.modules', 'core', 'Modules',
   'What this winery has, and where each part of it can be opened.',
   'module_detail', 'key', 'label', 1)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

commit;
