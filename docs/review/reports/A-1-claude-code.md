---
Type: review
Purpose: "Surveys the architectural commitments the existing tree makes, derived from the catalog of a live database built from the migrations, so that a module split can be priced rather than guessed at."
Depends on: [supabase/migrations/0001_core_schema.sql, supabase/migrations/0002_derived_and_rls.sql, supabase/migrations/0003_parties_and_products.sql, supabase/migrations/0004_terms_and_effects.sql, supabase/migrations/0005_account_and_walk.sql, tests/schema_assertions.sql, packages/core/src/kernel.ts, packages/cellar/docs/spec.md, docs/status-ledger.md, docs/sorry-ledger.md]
Depended on by: []
---

# A-1: architectural commitments of the existing tree

## Header

**Tier: A.** Full tree on disk. Route 1 (`git clone`) had already run: the repository
was present in the session working directory at `/home/user/VSV-Management-Software`
with a live `origin` remote. All reads are from disk. All database results are from a
Postgres 16 cluster built in this session.

**Commit.** `git rev-parse HEAD` returns verbatim:

```
c3eae3c7c262544e4b2e29526b513c964c6852fe
```

This is the baseline exactly, dated `Tue Sep 8 23:31:36 2026 +0000`. Neither ancestor
nor descendant: the same commit. `git rev-parse origin/main` returns the same SHA.

**Canary note, which matters.** The local `main` ref in this checkout is the stale
pre-merge `main`: `git diff --stat c3eae3c main` shows 42 files deleted and one line
added, leaving `LICENSE` alone. That is precisely the wrong tree this prompt warns
about. `origin/main` carries the real tree and equals the baseline. The review was
conducted against `c3eae3c`, reached through `origin/main` and the working branch,
never through local `main`.

**Canaries, all four present:**

| Canary | Status |
|---|---|
| `supabase/migrations/0005_account_and_walk.sql` | present, 340 lines |
| `tests/schema_assertions.sql` | present, 412 lines |
| `packages/cellar/src/walk.ts` | present, 805 lines |
| `docs/session-reports/2026-09-08-walk.md` | present, 202 lines |
| 42 tracked files | confirmed, `git ls-files \| wc -l` = 42 |

### The three execution numbers

1. **All five migrations applied clean** from empty, in order, under
   `ON_ERROR_STOP=1`. Each returned exit 0. The only output was two notices: pgcrypto
   already present, and the storage skip below.
2. **28 assertions ran, 28 passed.** `tests/schema_assertions.sql` exited 0 and printed
   `--- all assertions passed`. This matches the count in `docs/status-ledger.md`
   exactly, which is corroboration rather than coincidence.
3. **The storage-guarded block did not execute.** The shim was built without a
   `storage` schema, per this prompt's spec, and migration 0005 said so out loud:
   `NOTICE: storage schema absent, skipping the vessel-photos bucket`. So the assertion
   count of 28 is the no-storage number. A shim that stands up `storage` would run three
   more statements in 0005 and would still produce 28 assertions, because
   `tests/schema_assertions.sql` never touches storage.

### Shim, built to spec

Postgres 16.13. `auth` schema with a `users` table. `auth.uid()` reading
`request.jwt.claim.sub` first and falling back to the `request.jwt.claims` blob. Roles
`anon`, `authenticated`, `service_role` with default grants on `public`. An empty
`supabase_realtime` publication. No `storage` schema.

### File table

Every tracked file was read whole from disk. No truncation anywhere.

| Path | State | Lines |
|---|---|---|
| `supabase/migrations/0001_core_schema.sql` | whole | 370 |
| `supabase/migrations/0002_derived_and_rls.sql` | whole | 334 |
| `supabase/migrations/0003_parties_and_products.sql` | whole | 284 |
| `supabase/migrations/0004_terms_and_effects.sql` | whole | 519 |
| `supabase/migrations/0005_account_and_walk.sql` | whole | 340 |
| `tests/schema_assertions.sql` | whole | 412 |
| `packages/core/src/kernel.ts` | whole | 297 |
| `packages/core/src/types.ts` | whole | 125 |
| `packages/core/src/env.ts` | whole | 27 |
| `packages/core/src/index.ts` | whole | 6 |
| `packages/cellar/src/walk.ts` | whole | 805 |
| `packages/cellar/src/pickers.ts` | whole | 201 |
| `packages/cellar/src/ui.ts` | whole | 141 |
| `packages/cellar/src/scan.ts` | whole | 125 |
| `packages/cellar/src/sticky.ts` | whole | 35 |
| `packages/cellar/src/index.ts` | whole | 3 |
| `apps/web/src/index.ts` | whole | 27 |
| `apps/web/src/app.css` | whole | 330 |
| `apps/web/vite.config.ts` | whole | 8 |
| `apps/web/index.html` | whole | 14 |
| `apps/web/.env.example` | whole | 4 |
| `packages/cellar/docs/spec.md` | whole | 328 |
| `docs/status-ledger.md` | whole | 112 |
| `docs/sorry-ledger.md` | whole | 156 |
| `docs/compost-ledger.md` | whole | 72 |
| `docs/methodology-lineage.md` | whole | 334 |
| `docs/session-reports/2026-09-08-walk.md` | whole | 202 |
| `docs/session-reports/2026-09-08-scaffold.md` | whole | 153 |
| `docs/session-reports/index.md` | whole | 33 |
| `CLAUDE.md` | whole | 130 |
| `README.md` | whole | 59 |
| `supabase/config.toml` | whole | 56 |
| `tsconfig.json`, `biome.json`, `package.json` | whole | 40, 30, 24 |
| `packages/*/package.json`, `apps/web/package.json` | whole | 10, 11, 19 |
| `bun.lock`, `LICENSE`, `.gitignore`, `supabase/seed/.gitkeep` | whole | 218, 201, 47, 0 |

### Falsified predictions, disclosed

Three, and the third changed a number in this report.

**F-1. I predicted `is_admin()` being SECURITY DEFINER was load-bearing against RLS
recursion. Probe said otherwise, then partly restored it.** Setting `is_admin()` to
SECURITY INVOKER and reading `app_user` as an authenticated admin returned a row
normally. The reason is `app_user_read`, which is `USING (true)`: permissive policies
are OR'd, the blanket read satisfies the select inside `is_admin()`, and the recursion
never starts. Removing that blanket read as well produces
`ERROR: stack depth limit exceeded` with `is_admin` repeated hundreds of times in the
context. So the cycle is real and is masked by two independent guards, either one
sufficient. The corrected claim is in section 1.3.

**F-2. I predicted the catalog would refuse to move a table out from under a view.**
It does not. `ALTER TABLE vessel SET SCHEMA inventory` succeeded with `vessel_state`
depending on it, and Postgres silently rewrote the stored view definition to read
`inventory.vessel`. Views, foreign keys, triggers and policies all track by OID and
follow a table across schemas at zero cost. This makes the split cheaper than I
expected in one place and hides the expensive place, which is section 3.

**F-3. I reported a typecheck exit code that was measuring the wrong process.** My
first probe piped `bun run typecheck` into `tail` and read `$?` from `tail`. Re-run
without the pipe, the real exit code is 0, and separately I wrongly concluded that
`@supabase/supabase-js` was absent because I looked only in the root `node_modules`.
Bun installs workspace dependencies under `packages/core/node_modules`, where it is
present. The corrected finding in section 4 is stronger: typecheck passes with the
genuine Supabase type definitions loaded in the program and a nonexistent table name
in the call.

---

## 1. The actual coupling graph

Derived from `pg_depend` joined to `pg_class`, `pg_proc`, `pg_constraint`, `pg_trigger`,
`pg_policy`, `pg_rewrite` and `pg_attrdef`, against the live database.

**Raw count: 473 `pg_depend` rows resolve to an object in `public`.** Most are
mechanical (index to column, column to type, constraint to index). Collapsed to
distinct object-to-table edges of the kinds that constrain a module split, the count
is **123**, of which **86 are declarative** and **37 are enforceable only at runtime**.

### 1.0 A correction to the prompt's premise

**The tree has 15 tables, not sixteen.** Complete list, from
`pg_class` where `relkind='r'` in `public`: `app_user`, `block`, `event`, `lineage`,
`location`, `node`, `party`, `placement`, `task`, `task_claim_log`, `template`,
`template_step`, `term`, `vessel`, `vessel_code`. Plus three views: `lot_state`,
`task_board`, `vessel_state`. Plus 21 project functions, 38 policies, 3 triggers, 27
foreign keys, 10 enums.

### 1.1 The edge kinds, counted

| Dependent kind | Referenced kind | Raw rows |
|---|---|---|
| view | table.column | 84 |
| fk | table.column | 71 |
| default | table.column | 52 |
| index | table.column | 40 |
| policy | table | 38 |
| policy | function | 33 |
| fk | index | 27 |
| table.column | type | 20 |
| check | table.column | 18 |
| pkey | table.column | 16 |
| unique | table.column | 15 |
| default | type | 15 |
| policy | table.column | 8 |
| view.column | type | 8 |
| function | type | 6 |
| index | type | 4 |
| view | type | 4 |
| trigger | table | 3 |
| trigger | function | 3 |
| publication_rel | table | 3 |
| default | function | 2 |
| check | type | 2 |
| view | function | 1 |

**The load-bearing absence in this table is the row that is missing: there is no
`function` to `table` row.** All 21 project functions are either plpgsql or old-style
string-body SQL, so their bodies are opaque to the catalog. The only `function` edges
present are the six to composite return types (`bind_vessel_code` to `vessel_code`,
`claim_account` to `app_user`, `claim_task` to `task`, `confirm_event` to `event`,
`resolve_vessel_code` to `vessel_state`, `term_id` to `term_kind`).

**Probed, not reasoned.** `select count(*) from a1.dep_edge where dependent like
'%node_bin_shares%'` returns 0, although the function's body joins `lineage` to `node`.
Then:

```
begin;
create schema winemaking;
alter table lineage set schema winemaking;   -- succeeds, catalog raises nothing
select * from node_bin_shares('...'::uuid);
-- ERROR: relation "lineage" does not exist
-- CONTEXT: SQL function "node_bin_shares" during inlining
```

The move is accepted at DDL time and the break arrives at call time. For plpgsql the
break is worse: `bind_vessel_code` declares `existing vessel_code`, so moving the table
yields `ERROR: type "vessel_code" does not exist ... during compilation`, meaning the
function fails before its first statement.

### 1.2 The 27 foreign key edges

| Edge | Constraint |
|---|---|
| event to app_user | `event_by_user_fkey` |
| event to term | `event_operation_is_an_operation` |
| lineage to node | `lineage_child_id_fkey` |
| lineage to node | `lineage_parent_id_fkey` |
| location to term | `location_kind_is_a_location_kind` |
| node to app_user | `node_created_by_fkey` |
| node to block | `node_block_id_fkey` |
| node to party | `node_owner_id_fkey` |
| node to term | `node_product_type_is_a_product_type` |
| node to term | `node_variety_is_a_variety` |
| party to app_user | `party_app_user_id_fkey` |
| placement to node | `placement_node_id_fkey` |
| placement to vessel | `placement_vessel_id_fkey` |
| task to app_user | `task_assignee_fkey`, `task_claimed_by_fkey`, `task_created_by_fkey` |
| task to template_step | `task_created_from_fkey` |
| task to term | `task_operation_is_an_operation` |
| task_claim_log to app_user | `task_claim_log_user_id_fkey` |
| task_claim_log to task | `task_claim_log_task_id_fkey` |
| template to term | `template_variety_is_a_variety` |
| template_step to template | `template_step_template_id_fkey` |
| template_step to term | `template_step_operation_is_an_operation` |
| vessel to location | `vessel_location_id_fkey` |
| vessel to party | `vessel_owner_id_fkey` |
| vessel to term | `vessel_type_is_a_vessel_type` |
| vessel_code to vessel | `vessel_code_vessel_id_fkey` |

### 1.3 Strongly connected components

**Among tables: none.** A recursive walk over the combined foreign-key and
trigger-write table graph to depth 12 returns zero cycles. `lineage` points at `node`
twice (parent and child), which is a self-referencing DAG within one table's rows
rather than a table-level cycle, and the spec is explicit that this is intended.

**Among policies and functions: exactly one, and it is masked.**

```
app_user  ->  policy app_user_admin_write  ->  is_admin()  ->  reads app_user
```

Two independent guards hold it open, per falsified prediction F-1:

1. `is_admin()` is SECURITY DEFINER owned by the migration role, which owns `app_user`,
   so RLS is skipped inside it.
2. `app_user_read` is `USING (true)`, and permissive policies are OR'd, so the inner
   select resolves without consulting `is_admin()`.

Remove either and the system still works. Remove both and it terminates with
`stack depth limit exceeded`, which is a resource error rather than a clean
`infinite recursion detected in policy` message. **This matters for a module split
specifically**: the most natural tightening of `app_user` in a multi-tenant or
multi-module world is replacing the blanket read with a scoped one, and doing that
while also making `is_admin()` invoker-rights turns 17 policies into a stack overflow.

### 1.4 Highest in-degree, which is the empirical core

| Object | In-degree | What it is |
|---|---|---|
| `is_admin()` | 19 | function |
| `node` | 19 | table |
| `term` | 18 | table |
| `app_user` | 12 | table |
| `party` | 9 | table |
| `placement` | 8 | table |
| `event` | 8 | table |
| `vessel` | 8 | table |

**`is_admin()` ties `node` for first place.** It is called by 17 of the 38 policies,
covering 14 of the 15 tables (every table except `task_claim_log`, which uses
`user_id = auth.uid()` directly). The other two policy-called functions are
`is_facility_user()` and `current_party_id()`, one policy each, both on `node_read`.

The empirical answer to what belongs in a core is therefore narrower and sharper than
the intuitive one: **`is_admin()`, `app_user`, and `term`**. A module that installs
without `is_admin()` has 17 policies that will refuse to create.

### 1.5 Per-table dependant counts, deduplicated

| Table | In-degree | FK | View | Trigger | Policy | Function body |
|---|---|---|---|---|---|---|
| `node` | 19 | 3 | 3 | 1 | 4 | 8 |
| `term` | 18 | 8 | 3 | 0 | 2 | 5 |
| `app_user` | 12 | 7 | 1 | 0 | 2 | 2 |
| `party` | 9 | 2 | 1 | 0 | 2 | 4 |
| `event` | 8 | 0 | 0 | 1 | 3 | 4 |
| `placement` | 8 | 0 | 2 | 0 | 4 | 2 |
| `vessel` | 8 | 2 | 3 | 0 | 2 | 1 |
| `lineage` | 7 | 0 | 0 | 1 | 4 | 2 |
| `task` | 6 | 1 | 1 | 0 | 3 | 1 |
| `block` | 5 | 1 | 1 | 0 | 2 | 1 |
| `location` | 5 | 1 | 2 | 0 | 2 | 0 |
| `vessel_code` | 5 | 0 | 1 | 0 | 2 | 2 |
| `template` | 4 | 1 | 0 | 0 | 2 | 1 |
| `template_step` | 4 | 1 | 0 | 0 | 2 | 1 |
| `task_claim_log` | 2 | 0 | 0 | 0 | 2 | 0 |

### 1.6 The complete table-to-dependant map

Read as: this table cannot be dropped or moved without dealing with these.

**`node`** (19). FK from: `lineage` (twice), `placement`. Views: `lot_state`,
`task_board`, `vessel_state`. Trigger: `node_no_self_confirm`. Policies: `node_read`,
`node_insert`, `node_admin_update`, `node_admin_delete`. Function bodies:
`block_composition`, `close_parent_on_lineage`, `create_vessel_with_wine`,
`generate_inferred_history`, `next_cap_action`, `node_bin_shares`, `topping_check`,
`variety_composition`.

**`term`** (18). FK from: `event`, `location`, `node` (twice), `task`, `template`,
`template_step`, `vessel`. Views: all three. Policies: `term_read`, `term_admin_write`.
Function bodies: `next_cap_action`, `operation_effect`, `term_id`, `topping_check`,
`variety_composition`.

**`app_user`** (12). FK from: `event`, `node`, `party`, `task` (three times),
`task_claim_log`. View: `task_board`. Policies: `app_user_read`,
`app_user_admin_write`. Function bodies: `claim_account`, `is_admin`.

**`party`** (9). FK from: `node`, `vessel`. View: `vessel_state`. Policies:
`party_read`, `party_admin_write`. Function bodies: `current_party_id`,
`facility_party_id`, `is_facility_user`, `topping_check`.

**`event`** (8). FK from: none. Views: none. Trigger: `event_no_self_confirm`.
Policies: `event_read`, `event_insert`, `event_admin_update`. Function bodies:
`confirm_event`, `generate_inferred_history`, `inferred_fraction`, `next_cap_action`.

**`placement`** (8). Views: `lot_state`, `vessel_state`. Policies: `placement_read`,
`placement_insert`, `placement_admin_update`, `placement_admin_delete`. Function
bodies: `create_vessel_with_wine`, `topping_check`.

**`vessel`** (8). FK from: `placement`, `vessel_code`. Views: all three. Policies:
`vessel_read`, `vessel_admin_write`. Function body: `create_vessel_with_wine`.

**`lineage`** (7). Trigger: `lineage_closes_parent`. Policies: `lineage_read`,
`lineage_insert`, `lineage_admin_update`, `lineage_admin_delete`. Function bodies:
`inferred_fraction`, `node_bin_shares`.

**`task`** (6). FK from: `task_claim_log`. View: `task_board`. Policies: `task_read`,
`task_admin_write`, `task_own_update`. Function body: `claim_task`.

**`block`** (5). FK from: `node`. View: `task_board`. Policies: `block_read`,
`block_admin_write`. Function body: `block_composition`.

**`location`** (5). FK from: `vessel`. Views: `task_board`, `vessel_state`. Policies:
`location_read`, `location_admin_write`. Function bodies: none.

**`vessel_code`** (5). View: `vessel_state`. Policies: `vessel_code_read`,
`vessel_code_admin_write`. Function bodies: `bind_vessel_code`, `resolve_vessel_code`.

**`template`** (4). FK from: `template_step`. Policies: `template_read`,
`template_admin_write`. Function body: `generate_inferred_history`.

**`template_step`** (4). FK from: `task`. Policies: `template_step_read`,
`template_step_admin_write`. Function body: `generate_inferred_history`.

**`task_claim_log`** (2). Policies: `task_claim_log_read`, `claim_log_insert`. Nothing
else in the tree references it.

---

## 2. Edges that would cross a module line

Hypothesis under test, from the prompt. Tier ordering is core (1) below inventory (2)
below winemaking (3).

| Module | Tables |
|---|---|
| core | `party`, `app_user`, `location`, `term`, `event`, `task`, `task_claim_log`, `template`, `template_step` |
| inventory | `vessel`, `vessel_code` |
| winemaking | `node`, `lineage`, `placement`, `block` |

### 2.1 Table-rooted crossing edges: all eight point the right way

| Edge | Kind | From | To | Enforcement | Direction |
|---|---|---|---|---|---|
| `node_created_by_fkey` | fk | winemaking | core (`app_user`) | declarative | upward, ok |
| `node_owner_id_fkey` | fk | winemaking | core (`party`) | declarative | upward, ok |
| `node_product_type_is_a_product_type` | fk | winemaking | core (`term`) | declarative | upward, ok |
| `node_variety_is_a_variety` | fk | winemaking | core (`term`) | declarative | upward, ok |
| `placement_vessel_id_fkey` | fk | winemaking | inventory (`vessel`) | declarative | upward, ok |
| `vessel_location_id_fkey` | fk | inventory | core (`location`) | declarative | upward, ok |
| `vessel_owner_id_fkey` | fk | inventory | core (`party`) | declarative | upward, ok |
| `vessel_type_is_a_vessel_type` | fk | inventory | core (`term`) | declarative | upward, ok |

**This is the good news and it is genuine.** Every declarative table-to-table
dependency respects the proposed layering. The author's instinct about which things
depend on which is correct at the level the catalog enforces.

### 2.2 The wrong-way edges, which live in views, enums and function bodies

**W-1. `task_board` is a core view with declarative dependencies on two higher
modules.** This is the hardest edge in the tree, because it is real catalog
enforcement rather than a runtime surprise.

`task_board` reads `app_user`, `location`, `task`, `term` (all core), plus `block` and
`node` (winemaking) and `vessel` (inventory). The mechanism is the `CASE` over
`subject_type` at `supabase/migrations/0004_terms_and_effects.sql:363-368`:

```sql
case t.subject_type
  when 'node'     then (select name from node where id = t.subject_id)
  when 'vessel'   then (select name from vessel where id = t.subject_id)
  when 'location' then (select name from location where id = t.subject_id)
  when 'block'    then (select vineyard || ' ' || name from block where id = t.subject_id)
end as subject_name
```

Direction: core to winemaking and core to inventory. Kind: view. Enforcement:
**declarative**. Probed consequence, in section 6: dropping `block` alone cascades to
`task_board`, and dropping the winemaking tables destroys the task board entirely.

**W-2. `subject_type` is a core-resident enum whose values are the names of
higher-module tables.** `create type subject_type as enum ('node', 'vessel',
'location', 'block')` at `0001_core_schema.sql:59`. It types `event.subject_type` and
`task.subject_type`, both core tables. Three of its four values name tables outside
core. Enforcement: **runtime only**, because `subject_id` is deliberately not a foreign
key (sorry S-4).

This is the most important structural observation in the report, and it inverts how
`event` looks. In the catalog, `event` appears beautifully separable: in-degree 8, zero
inbound foreign keys, its own two foreign keys going cleanly upward to `app_user` and
`term`. That cleanliness is an artifact. **The absence of the foreign key that S-4
names is what makes the coupling invisible, and hiding a dependency is a different
thing from removing one.** Every event about a lot points at a winemaking row through
an unconstrained uuid.

**W-3. `term_kind` is a core enum carrying higher-module vocabulary.**
`create type term_kind as enum ('variety', 'cooper', 'wood', 'vessel_type',
'product_type', 'material_kind', 'operation', 'location_kind')` at
`0004_terms_and_effects.sql:40-43`. `vessel_type` is inventory. `variety`, `cooper` and
`wood` are winemaking or vineyard vocabulary. `material_kind` names the dry goods
module of spec section 8.1, which does not exist. Enforcement: declarative, through
`term_id_kind_key` and the seven composite foreign keys that reference `(id, kind)`.
Adding a module kind means altering a core enum, which the migration's own comment
anticipates: "Adding a kind means something in the kernel has to consume it."

**W-4. Five functions beyond `create_vessel_with_wine` span two modules.** The prompt
asked for the rest. Here they are, complete:

| Function | Modules spanned | Tables in body |
|---|---|---|
| `create_vessel_with_wine` | inventory + winemaking | `vessel` (i), `node` (w), `placement` (w) |
| `generate_inferred_history` | core + winemaking | `event`, `template`, `template_step` (c), `node` (w) |
| `inferred_fraction` | core + winemaking | `event` (c), `lineage` (w) |
| `next_cap_action` | core + winemaking | `event`, `term` (c), `node` (w) |
| `topping_check` | core + winemaking | `party`, `term` (c), `node`, `placement` (w) |
| `variety_composition` | core + winemaking | `term` (c), `node` (w) |

Every one is **runtime only**. A sixth, `resolve_vessel_code`, is nominally inventory
but returns `setof vessel_state`, and `vessel_state` spans all three modules, so it
spans all three transitively.

**W-5. All three views span all three modules.** Without exception.

| View | Reads |
|---|---|
| `lot_state` | `node` (w), `placement` (w), `term` (c), `vessel` (i) |
| `task_board` | `app_user` (c), `block` (w), `location` (c), `node` (w), `task` (c), `term` (c), `vessel` (i) |
| `vessel_state` | `location` (c), `node` (w), `party` (c), `placement` (w), `term` (c), `vessel` (i), `vessel_code` (i) |

**W-6. One trigger writes across tables, and it stays inside one module.**
`lineage_closes_parent` on `lineage` calls `close_parent_on_lineage()`, which updates
`node`. Both winemaking. The other two triggers, `node_no_self_confirm` and
`event_no_self_confirm`, share one function, `refuse_self_granted_standing()`, which
writes nothing and sits on one winemaking table and one core table. That shared
function is a genuine core primitive used by a higher module, which is the right
direction.

### 2.3 The verdict on the hypothesis

**The candidate assignment is contradicted by the graph in exactly one place that is
declaratively enforced, and in three places that are enforced only at runtime.**

The declarative contradiction is `task_board` (W-1). Putting `task` and its board in
core commits core to knowing about `node`, `vessel` and `block`. That single view is
the reason `core` as drawn cannot install alone, and section 6 demonstrates it.

The runtime contradictions are `subject_type` (W-2), `term_kind` (W-3), and the five
spanning functions (W-4). None of these will refuse to install. All of them will be
wrong in production.

**The deeper result: `event` and `task` are misassigned, or `subject_type` is.** Both
core tables are polymorphic over a set that is three-quarters higher-module. Either the
scheduling and event block moves up out of core, or the polymorphic pointer becomes
something a module can extend, which section 7 takes up.

---

## 3. What assumes a single schema

### 3.1 Unqualified references and search_path

**Zero schema qualification exists anywhere in the migrations, other than to `auth`.**
`grep -n "public\." supabase/migrations/*.sql` outside `set search_path` lines returns
nothing. There are 13 `auth.uid()` call sites across four of the five migrations, all
correctly qualified, which shows the author qualifies across schemas when he must. Every
reference to a `public` object is bare.

Search-path pinning splits perfectly along the security boundary:

| Status | Count | Functions |
|---|---|---|
| SECURITY DEFINER, `search_path` pinned | 6 | `claim_account`, `claim_task`, `confirm_event`, `current_party_id`, `is_admin`, `is_facility_user` |
| SECURITY INVOKER, unpinned | 15 | `bind_vessel_code`, `block_composition`, `close_parent_on_lineage`, `create_vessel_with_wine`, `facility_party_id`, `generate_inferred_history`, `inferred_fraction`, `next_cap_action`, `node_bin_shares`, `operation_effect`, `refuse_self_granted_standing`, `resolve_vessel_code`, `term_id`, `topping_check`, `variety_composition` |
| SECURITY DEFINER, unpinned | **0** | none |

**The dangerous class is empty**, which is a real credit to the tree: every
definer-rights function pins `search_path = public`, so none of them can be hijacked by
a caller's search path.

The 15 unpinned invoker functions carry a different risk, and it is precisely the
module-split risk. They resolve object names by the caller's search path at call time.
Today that is harmless, because there is one schema. The moment objects live in
`core`, `inventory` and `winemaking`, each of these resolves against whatever the
caller happens to have set, and PostgREST sets a search path from
`extra_search_path` in `supabase/config.toml`, currently `["public", "extensions"]`.

Worth naming: the six pinned functions are pinned to `public` literally. After a split
they would resolve to a schema that no longer holds their tables, so the pin becomes an
active fault rather than a protection. `is_admin()` pinned to `public` while `app_user`
lives in `core` fails on all 17 policies that call it.

### 3.2 Policy predicates calling functions defined elsewhere

38 policies. 19 of them call a function:

| Function | Policies calling it | Tables |
|---|---|---|
| `is_admin()` | 17 | all except `task_claim_log` |
| `is_facility_user()` | 1 | `node_read` |
| `current_party_id()` | 1 | `node_read` |

Policy-to-function edges are recorded in `pg_depend` (33 raw rows), so they are
declarative: the catalog will refuse to drop `is_admin()` while a policy uses it. What
the catalog does **not** protect is the function's own body reference to `app_user`,
which is runtime only per section 1.1.

So the failure shape after a split is specific and worth stating plainly: `is_admin()`
survives the move, all 17 policies keep pointing at it, and every one of them starts
raising `relation "app_user" does not exist` on the first row read. The policies look
intact in `\d`. They fail on a phone in a barrel room.

### 3.3 Triggers writing to a table other than their own

Exactly one: `lineage_closes_parent` on `lineage` updates `node`. Both winemaking, so
it survives the proposed split intact. The other two triggers write nothing.

### 3.4 Views spanning candidate modules

All three, as tabulated in W-5. There is no view confined to a single candidate module.

Probed cost of this, which is the migration-ordering cost in section 5:

```
alter table node drop column vintage;
-- ERROR: cannot drop column vintage of table node because other objects depend on it
-- DETAIL: view vessel_state depends on column vintage of table node
--         function resolve_vessel_code(text) depends on type vessel_state
--         view lot_state depends on column vintage of table node
```

**A winemaking column change is blocked by an inventory view.** Adding a column is
free and needs no view rebuild, probed separately. Changing or dropping one requires
dropping and recreating views owned by two other modules, in the right order, in one
transaction. That asymmetry is the whole shape of the migration problem.

### 3.5 The polymorphic pointer

**What enforces it today.** Nothing in the database. `task.subject_type` and
`event.subject_type` are typed `subject_type`, so the *kind* is constrained to four
values. `subject_id` is a bare `uuid not null` with no foreign key, which is sorry S-4,
declared before the code that created it. `CLAUDE.md` names `doctor` as the only thing
standing between the schema and orphaned records.

**`doctor` does not exist.** `package.json:13`:

```json
"doctor": "echo 'doctor: not implemented. See sorry S-4 ...' && exit 1"
```

It is a stub that exits 1. The definition of done in `CLAUDE.md` says `bun run doctor`
is not optional and must report nothing against replay fixtures. It currently reports a
message and fails. `docs/status-ledger.md` grades it Specified, so the tree is honest
about this; the point here is that the single enforcement mechanism for the single
largest cross-module pointer is at grade Specified.

**What would enforce it across schemas.** Nothing that exists in Postgres. A foreign
key cannot target a union of tables, and cross-schema makes it strictly worse, because
the resolution target now depends on which modules are installed. The options the tree
leaves open are a resolver function per module registering itself, a check constraint
per installed module, or `doctor` growing a per-module subject validator. The third is
the only one consistent with the rest of the tree, since it is the mechanism already
named.

**What happens when the target's module is absent.** Probed in section 6: the *row*
survives, because there is no constraint to violate. The *view* does not, because
`task_board`'s `CASE` arm names the table directly. So an install without winemaking
has tasks whose `subject_type` is `'node'`, no table to resolve them against, no
constraint objecting, and no board to show them on. The task rows are readable and
meaningless, which is the silent failure mode the sorry ledger calls "the worse kind"
about S-3.

**Open: what fraction of events and tasks point at each `subject_type` in practice.**
*Why:* the database is empty, and `docs/status-ledger.md` records that no migration has
run against the project's own instance. *What would settle it:* one harvest of real
rows, or the replay fixtures listed at grade Specified in Stage 3.

### 3.6 One undeclared gap, found by probe

`block.variety` is `text not null` and is the only free-text vocabulary column left in
the tree. Migration 0004 moved `node.variety`, `vessel.type`, `event.type`, `task.type`
and `template_step.type` onto `term`, and 0005 moved `template.variety`. `block.variety`
was left behind.

Complete list of remaining `text` columns, from the catalog: `app_user.name`,
`block.name`, `block.notes`, `block.variety`, `block.vineyard`, `event.by_sensor`,
`location.name`, `node.name`, `party.name`, `task.instructions`,
`template.name`, `template_step.offset_from`, `term.label`, `term.value`,
`vessel.name`, `vessel_code.code`, `vessel_code.label`. Every one is a proper name, a
note, or a machine key, except `block.variety`, which is vocabulary that `term` already
holds under kind `variety`.

Consequence: a block can carry `'Pinot Noir'` while every node carries
`term_id('variety','pinot_noir')`, and nothing compares them. T1-1 says pickers rather
than text fields. `docs/sorry-ledger.md` has no entry for this, and `CLAUDE.md` requires
a gap to be recorded before the code that creates it. This one arrived when 0004
converted its siblings and passed over it.

Secondary, smaller: `template_step.offset_from` is `text not null default 'previous'`
with no check constraint, so it accepts any string where two values are meaningful.

---

## 4. The client's coupling surface

### 4.1 Counted, not estimated

**18 call sites. All 18 are in one file, `packages/core/src/kernel.ts`.**
`packages/cellar/src/` and `apps/web/src/` contain zero `.from()`, `.rpc()`, `.storage`
or `createClient` calls. The only string in those directories that looks like a table
name is `stickyKey: "location"` at `packages/cellar/src/walk.ts:377`, which is a
localStorage key.

| Line | Kind | Object named | Module |
|---|---|---|---|
| `kernel.ts:70` | `.rpc()` | `claim_account` | core |
| `kernel.ts:81` | `.from()` | `app_user` | core |
| `kernel.ts:93` | `.from()` | `term` | core |
| `kernel.ts:112` | `.from()` | `term` | core |
| `kernel.ts:136` | `.from()` | `party` | core |
| `kernel.ts:147` | `.from()` | `party` | core |
| `kernel.ts:161` | `.from()` | `party` | core |
| `kernel.ts:171` | `.from()` | `location` | core |
| `kernel.ts:180` | `.from()` | `location` | core |
| `kernel.ts:191` | `.from()` | `vessel_state` | inventory view, spans all three |
| `kernel.ts:199` | `.rpc()` | `resolve_vessel_code` | inventory, spans all three |
| `kernel.ts:210` | `.rpc()` | `bind_vessel_code` | inventory |
| `kernel.ts:220` | `.from()` | `vessel` | inventory |
| `kernel.ts:232` | `.rpc()` | `create_vessel_with_wine` | inventory + winemaking |
| `kernel.ts:247` | `.from()` | `event` | core |
| `kernel.ts:262` | `.from()` | `term` | core |
| `kernel.ts:282` | `.storage.from()` | bucket `vessel-photos` | storage |
| `kernel.ts:293` | `.storage.from()` | bucket `vessel-photos` | storage |

Twelve `.from()`, four `.rpc()`, two storage. Distinct database objects named: seven
(`app_user`, `term`, `party`, `location`, `event`, `vessel`, `vessel_state`) plus four
functions plus one bucket.

**A structural result worth stating: the client never names a winemaking table.** No
`.from("node")`, no `.from("placement")`, no `.from("lineage")`, no `.from("block")`,
no `.from("task")`. The client's entire winemaking coupling runs through one RPC
(`create_vessel_with_wine`) and one view (`vessel_state`). This is the single most
favourable fact in the tree for a module split, and it is a direct consequence of the
`CLAUDE.md` rule that a client may not encode a business rule.

### 4.2 What schema-qualifying would cost

**Call sites changed: at most 18, in one file.** The mechanics are not a string edit.
PostgREST selects a schema by the `Accept-Profile` and `Content-Profile` headers, and
`supabase-js` exposes that as `.schema(name)`, whose signature in the installed
`@supabase/postgrest-js` is:

```ts
schema<DynamicSchema extends string & keyof Omit<Database, '__InternalSupabase'>>(
  schema: DynamicSchema
): PostgrestClient<...>
```

So `kernel().from("vessel")` becomes `kernel().schema("inventory").from("vessel")`.
Realistically that is one helper per module in `kernel.ts` and 18 edited lines: two to
four hours including running the assertions.

### 4.3 What would catch a mistake, probed

**Nothing in the build catches it.** Probed by editing `kernel.ts` to introduce three
faults at once, a nonexistent table, a schema-prefixed table name, and a misspelled
RPC:

```
.from("vessel_state")   ->  .from("inventory.vessel_state")
.from("term")           ->  .from("nonexistent_table")
.rpc("claim_account")   ->  .rpc("claim_acount")
```

| Check | Result |
|---|---|
| `bun run typecheck` (tsc, `strict`, real Supabase types in the program) | **exit 0, zero errors** |
| `bun run lint` (Biome 2.5.12, recommended preset) | **passes on the names** |

Biome did flag the modified file, and I checked what it flagged: line width. Its
message is `Formatter would have printed the following content` on line 191, because
the longer string pushed past `lineWidth: 88`. With the edit made on a short line
(`.from("nonexistent_table")`), Biome reports `Checked 20 files. No fixes applied.`

The reason typecheck passes is at `kernel.ts:27`:

```ts
client = createClient(url, anonKey);
```

with no `Database` generic. `Database` defaults to a permissive type, so `.from()`
accepts any string and `.rpc()` accepts any name. No generated types file exists in
`packages/core/src/` (the directory holds `env.ts`, `index.ts`, `kernel.ts`,
`types.ts` only).

**The failure is at runtime, on one screen, as a thrown `Error(error.message)`.** Every
kernel function follows the same shape: `if (error) throw new Error(error.message)`.
So a wrong schema surfaces as a PostgREST error string in whatever UI banner the screen
that called it happens to have.

What would catch it: `supabase gen types typescript` committed as a `Database` type and
passed to `createClient<Database>`. That turns all three faults into compile errors and
would also catch the second uncaught surface below.

### 4.4 A second uncaught surface: hand-mirrored enums

`packages/core/src/types.ts` mirrors seven Postgres types by hand, none generated:

| TS type | Line | Mirrors |
|---|---|---|
| `TermKind` | 7 | enum `term_kind`, 8 values |
| `Effect` | 17 | the `operation_has_an_effect` CHECK, 4 values |
| `Role` | 29 | enum `user_role` |
| `PartyKind` | 38 | enum `party_kind` |
| `NodeStage` | 56 | enum `node_stage` |
| `Provenance` | 58 | enum `provenance` |
| `subject_type` | 120 | enum `subject_type`, inline on `EventRow` |

Adding a module that extends `term_kind` or `subject_type` requires editing both sides,
and a drift produces no error at build time. `types.ts:120` is the same core-resident,
higher-module-naming union as W-2, duplicated in the client.

### 4.5 PostgREST against a multi-schema database

**What the tree configures**, `supabase/config.toml:7-12`:

```toml
[api]
enabled = true
port = 54321
schemas = ["public", "graphql_public"]
extra_search_path = ["public", "extensions"]
max_rows = 1000
```

**How exposure works.** PostgREST serves only the schemas named in that list. The first
entry is the default; others are reachable per-request via `Accept-Profile` on reads
and `Content-Profile` on writes. A schema absent from the list is invisible over the
API regardless of its grants, so a module whose schema was omitted returns a
schema-not-found error rather than a permission error.

**What that means here.** A split requires editing this list for every module, and the
list is a deployment fact rather than a migration fact: it lives in `config.toml` for
local and in the hosted project's API settings for production, which
`supabase/config.toml:1-3` explicitly says is out of the repository. So installing a
module correctly would involve one step that no migration performs and no test covers.

---

## 5. Migration ordering

### 5.1 What breaks if the single sequence is split

**Migrations 0001 through 0004 each touch all three candidate modules.** Counted by
DDL statement against the table-to-module map:

| Migration | core | inventory | winemaking | Modules |
|---|---|---|---|---|
| `0001_core_schema` | 7 create table | 1 create table | 4 create table | all three |
| `0002_derived_and_rls` | 7 alter, 2 publication | 1 alter | 4 alter, 1 publication | all three |
| `0003_parties_and_products` | 1 create, 1 alter | 1 create, 3 alter | 2 alter | all three |
| `0004_terms_and_effects` | 1 create, 8 alter | 3 alter | 3 alter | all three |
| `0005_account_and_walk` | 4 alter | via function | via trigger | all three |

0005 looks single-module by table DDL, and is not: it creates `node_no_self_confirm` on
`node` (winemaking) and `event_no_self_confirm` on `event` (core) from one shared
function, and it creates `create_vessel_with_wine`, which spans inventory and
winemaking.

**The statements that depend on ordering across a candidate module boundary:**

1. `0003:81`. `alter table node add column owner_id uuid not null default
   facility_party_id() references party(id)`. A winemaking column whose default calls a
   core function created 20 lines earlier in the same file, and whose foreign key
   targets a core table created 41 lines earlier. Split per module, `winemaking/0002`
   must run after `core/000N`, and the manifest must say so.

2. `0004:181-187`. The drop block:
   ```sql
   drop function resolve_vessel_code(text);   -- inventory
   drop view vessel_state;                    -- spans all three
   drop view lot_state;                       -- spans all three
   drop view task_board;                      -- spans all three
   drop function variety_composition(uuid);   -- core + winemaking
   drop function topping_check(uuid, uuid);   -- core + winemaking
   drop function next_cap_action(uuid);       -- core + winemaking
   ```
   **This block is the hardest thing in the tree to split.** Every drop must precede
   every `alter table` in lines 199 to 251, and those alters are spread across core
   (`event`, `task`, `template_step`), inventory (`vessel`) and winemaking (`node`).
   Then all seven objects come back at lines 257 to 502. Per-module sequences cannot
   express "all three modules drop their views, then all three alter their columns,
   then all three rebuild", because each module's file runs to completion before the
   next starts. Probed in 3.4: the alters genuinely fail while the views exist.

3. `0004:249-251`. `drop type product_type; drop type vessel_type; drop type
   event_type`. Core-defined types dropped only after inventory and winemaking have
   stopped using them.

4. `0005:88-95`. `alter table template ... drop column variety`, a core table, using
   `term_kind` from core. Self-contained.

### 5.2 Can 0002's RLS block be split by module

**Yes, and it is the cheapest thing in this section.** The three `do $$ ... foreach`
loops are over array literals:

| Loop | Lines | Tables | Module mix |
|---|---|---|---|
| blanket read | 262-272 | 12 tables | 7 core, 1 inventory, 4 winemaking |
| admin write | 275-285 | `app_user`, `location`, `block`, `vessel`, `template`, `template_step` | 4 core, 1 inventory, 1 winemaking |
| node/lineage/placement | 299-312 | `node`, `lineage`, `placement` | 3 winemaking, already single-module |

Splitting is editing three array literals into five or six smaller ones and moving each
to its module's file. The loops carry no cross-table logic: each iteration executes one
`format()`'d `create policy` against one table. One of the three is already
single-module.

The real dependency is on `is_admin()`, which 17 of the generated policies call. Every
module's RLS file must run after the core file that defines it.

### 5.3 What a dependency manifest would have to declare

Derived from the graph in section 1 rather than asserted:

| Module | Must declare a dependency on | Because of |
|---|---|---|
| inventory | core | `vessel_location_id_fkey`, `vessel_owner_id_fkey`, `vessel_type_is_a_vessel_type`, plus `is_admin()` for 4 policies |
| winemaking | core | `node_created_by_fkey`, `node_owner_id_fkey`, both `term` foreign keys, plus `is_admin()` for 12 policies |
| winemaking | inventory | `placement_vessel_id_fkey` |
| core | **inventory and winemaking**, for `task_board` alone | the `CASE` at `0004:363-368` |

That last row is the manifest declaring a cycle, which is the manifest's own way of
reporting W-1. It disappears the moment `task_board` stops naming higher-module tables.

Beyond ordering, the manifest would have to declare **what each module contributes to
core's extension points**, because ordering alone cannot express these:

- which `term_kind` values the module adds (`vessel_type` for inventory; `variety`,
  `cooper`, `wood` for winemaking)
- which `subject_type` values the module adds, and the resolver for each
- which function each module expects core to provide, `is_admin()` above all

### 5.4 The cost of deferring

**Free today, permanently bifurcated after intake.** The database is empty:
`docs/status-ledger.md` grades every migration Specified with "written, never run"
against the project's own instance, and `0004:30` states "Nothing is preserved. The
database is empty."

While that holds, renumbering is editing filenames and running `supabase db reset`,
because nothing has an applied-migrations table to reconcile against.

Once intake writes production rows, applied migrations cannot be renumbered: their
names are recorded in `supabase_migrations.schema_migrations` on the hosted project,
and rewriting them means either a manual edit of that table on a live database or a
permanent divergence between what the repo says and what the server ran. The realistic
path after that point is leaving `0001` through `000N` as a global prefix and starting
per-module numbering alongside, which means the tree carries two numbering schemes
forever and every future reader has to learn which files predate the split.

**This is the one item in the bill that is materially harder after intake, and it is
also the cheapest one to do now.**

---

## 6. The install-alone test

Run empirically. Method: apply all five migrations, then drop the tables of the absent
modules with `CASCADE` inside a transaction, and record exactly what Postgres takes
with them. `CASCADE`'s notice is the answer to "what refuses to exist without this",
computed by the catalog rather than by me.

### 6.1 Case 1: a farm with no winery (core plus inventory)

```
drop table block, node, lineage, placement cascade;
NOTICE:  drop cascades to 4 other objects
DETAIL:  drop cascades to view vessel_state
         drop cascades to function resolve_vessel_code(text)
         drop cascades to view lot_state
         drop cascades to view task_board
```

| Survives | Destroyed | Module of the destroyed thing |
|---|---|---|
| 11 tables: `app_user`, `event`, `location`, `party`, `task`, `task_claim_log`, `template`, `template_step`, `term`, `vessel`, `vessel_code` | `vessel_state` | **inventory** |
| | `resolve_vessel_code` | **inventory** |
| | `lot_state` | winemaking, expected |
| | `task_board` | **core** |

**The farm loses three things it should keep.** `vessel_state` is the vessel page and
the only object `kernel.ts:191` reads to list vessels. `resolve_vessel_code` is what
`kernel.ts:199` calls for every barcode scan, so scanning stops working. `task_board`
is the board.

What would have to move or be duplicated for this case to work:

1. `vessel_state` splits into an inventory view that reads `vessel`, `vessel_code`,
   `location`, `party`, `term`, and an optional winemaking extension supplying
   `node_id`, `lot_name`, `variety`, `vintage`, `product_type`, `lot_owner_id`,
   `current_volume_l`, `filled_at`, `is_empty`. The last one is the catch: `is_empty`
   is `(p.node_id is null)`, so occupancy itself is a winemaking concept in this tree.
   An inventory module with no winemaking has vessels that cannot be full.
2. `resolve_vessel_code` returns `setof vessel_state`, so it follows whatever
   `vessel_state` becomes. `kernel.ts:198-203` reads `rows[0]`, so the client shape
   survives a narrower view.
3. `task_board` loses its `node` and `block` arms.

### 6.2 Case 2: a winery with no vineyard

```
drop table block cascade;
NOTICE:  drop cascades to 2 other objects
DETAIL:  drop cascades to constraint node_block_id_fkey on table node
         drop cascades to view task_board
```

**`block` is the cheapest removal in the tree.** Two declarative dependants, plus
`block_composition()` breaking at runtime. `node.block_id` is nullable and already
constrained to bins by `block_only_on_bins`, so the column can stay with every value
null and the check still holds.

**Which of `block`'s columns a fruit-buying winery needs.** All four of the meaningful
ones:

| Column | Type | Fruit-buyer needs it | Why |
|---|---|---|---|
| `vineyard` | text | **yes** | the grower's name is required on the label and in TTB records |
| `name` | text | **yes** | "Perlstaad" and "Eola Springs" appear in `0002:27`'s own worked example of a barrel's composition |
| `variety` | text | **yes** | what was bought |
| `notes` | text | yes, weakly | |
| `id`, `created_at` | uuid, timestamptz | yes | identity |

**Nothing currently on `block` belongs to growing.** The growing half is entirely
absent: no farming events, no phenology, no yield estimates, and spec section 8.4 is
explicit that clone and rootstock are wanted on `block` and are not there. So the
correct reading is that `block` today is a **fruit-source identity** table, which a
fruit-buying winery needs in full, and a vineyard module would be the thing that adds
growing to it rather than the thing that owns it.

The pressure point is therefore the reverse of the prompt's framing. `block` is not a
vineyard table a winery could drop. It is a winemaking table a vineyard module would
extend. The only thing a fruit-buyer would want changed is `block.variety` becoming a
`term` reference (section 3.6), because a purchased-fruit record should use the same
vocabulary as the lot it becomes.

### 6.3 Case 3: core alone, which is the decisive result

```
drop table block, node, lineage, placement, vessel, vessel_code cascade;
NOTICE:  drop cascades to 5 other objects
DETAIL:  drop cascades to function bind_vessel_code(uuid,text,text,uuid)
         drop cascades to view vessel_state
         drop cascades to function resolve_vessel_code(text)
         drop cascades to view lot_state
         drop cascades to view task_board
```

Nine tables survive: `app_user`, `event`, `location`, `party`, `task`,
`task_claim_log`, `template`, `template_step`, `term`. Zero views survive.

**And 19 of the 21 functions survive, of which 9 are broken.** The survivors include
`block_composition`, `close_parent_on_lineage`, `create_vessel_with_wine`,
`generate_inferred_history`, `inferred_fraction`, `next_cap_action`, `node_bin_shares`,
`topping_check` and `variety_composition`. Every one of those nine references a dropped
table in its body. Every one exists in `\df`, has a signature, has grants, and raises
`relation ... does not exist` on first call.

Only two functions were dropped, `bind_vessel_code` and `resolve_vessel_code`, and only
because their **return types** are composite types tied to dropped relations. Their
bodies had nothing to do with it.

**This is the whole finding of the report in one number: the catalog removed 2
functions and silently kept 9 broken ones.** A module system built on this tree
inherits that ratio. Installing a subset produces a database that reports success, has
a complete-looking function list, and fails on contact.

### 6.4 Minimum object set per module

**core**, to install and function alone:

| Present and sufficient | 9 tables, `claim_account`, `claim_task`, `confirm_event`, `current_party_id`, `facility_party_id`, `is_admin`, `is_facility_user`, `operation_effect`, `term_id`, `refuse_self_granted_standing`, 20 policies |
| Must move out | `task_board` (or lose its `subject_name` column), `generate_inferred_history`, `inferred_fraction`, `next_cap_action`, `variety_composition` |
| Must change | `subject_type` enum, from a fixed four-value enum to something a module can extend; `term_kind` likewise |
| Must gain | a registry of installed modules and a subject resolver per module, neither of which exists |

**inventory**, given core:

| Present | `vessel`, `vessel_code`, `bind_vessel_code`, 4 policies |
| Must be rebuilt | `vessel_state`, split so that the winemaking columns are optional |
| Must be duplicated or moved down | nothing; its two foreign keys to core are clean |
| Blocked on | whether `is_empty` and occupancy belong to inventory or winemaking, which this tree answers "winemaking" by putting them on `placement` |

**winemaking**, given core and inventory:

| Present | `node`, `lineage`, `placement`, `block`, `node_bin_shares`, `block_composition`, `close_parent_on_lineage`, `lineage_closes_parent`, `node_no_self_confirm`, 14 policies |
| Must move up from core | the five spanning functions in W-4 |
| Must be rebuilt | `lot_state` |
| Must contribute to core | `term_kind` values `variety`, `cooper`, `wood`; `subject_type` values `node` and `block`; a subject resolver for each |

---

## 7. Contracts already present

For each candidate: a **contract** is a shape defined independently of what fills it
and enforced against fillers; a **convention** is a shape agreed and unenforced; an
**escape hatch** is a place where shape is declined.

### 7.1 `term`: a genuine contract, and the tree's best asset

**Verdict: contract.** It is the only one of the four that the database enforces.

The mechanism is the composite key trick at `0004:68` and its seven users:

```sql
alter table term add constraint term_id_kind_key unique (id, kind);
```

then on each referencing table, a generated column pinning the kind and a two-column
foreign key:

```sql
add column variety_id   uuid,
add column variety_kind term_kind generated always as ('variety'::term_kind) stored,
add constraint node_variety_is_a_variety
  foreign key (variety_id, variety_kind) references term(id, kind),
```

That turns "the picker only offers varieties" into a constraint the database checks, as
the migration's own comment says. Assertion 6 of 28 confirms it, and the comment at
`0004:194-197` correctly identifies this as the opposite case from `event.subject_id`.

**What it would take to carry a versioned shape across modules.** Two things, one
small and one structural.

Small: `term.attributes` is `jsonb not null default '{}'` with exactly one constraint,
`operation_has_an_effect`, which checks that an operation's `effect` is one of four
values. Every other attribute shape is unchecked, including the `predicate.match` array
that `topping_check` reads at `0004:443`. A versioned shape needs a `schema_version`
key and a check per kind.

Structural: `term_kind` is a Postgres enum, so a module adding a kind must `alter type`
a core-owned type. Kinds are the thing that would need to become extensible, and the
migration's own comment defends the enum on the grounds that "adding a kind means
something in the kernel has to consume it", which is exactly right in a single-module
world and is exactly the constraint a module system removes.

### 7.2 The polymorphic task and event subject: a convention

**Verdict: convention, halfway to a contract.** The `kind` half is a contract, since
`subject_type` is an enum the database enforces. The `identity` half is declined: S-4,
no foreign key, and `doctor` unimplemented.

It is an unusually well-documented convention. The spec justifies it at section 2
(a room thermometer, a vessel setpoint, a lot Brix reading, a block sample sharing one
table), `0001:270-272` repeats the reasoning inline, and the sorry ledger names the
cost. The tree knows exactly what it traded.

**What it would take to carry a versioned shape across modules.** A registry, which is
the same thing section 6.4 says core must gain:

- a `subject_kind` table replacing the enum, one row per resolvable kind, with the
  owning module and a resolver function name
- `task_board`'s `CASE` becoming a lateral join to that resolver, which removes W-1,
  the only declarative wrong-way edge in the tree
- `doctor` iterating the registry rather than a hardcoded list

That is one table, one view rewrite, and the `doctor` that `CLAUDE.md` already requires.
It is the highest-leverage change available, because it converts the worst edge into a
mechanism.

### 7.3 `provenance`: a contract, and the only one enforced at the write path

**Verdict: contract, and the strongest in the tree.** Three values, on `node` and
`event`, defaulting to `observed`. What makes it a contract rather than a column is
`0005:105-125`:

```sql
create or replace function refuse_self_granted_standing() ... 
  if new.provenance = 'confirmed' then raise exception ... (T0-4)
```

with `before insert` triggers on both tables, plus `confirm_event()` as the only path
to `confirmed`, gated on `is_admin()`, and moving only `inferred` to `confirmed`.
Assertions confirm all of it: a node cannot be born confirmed, an event cannot be born
confirmed, a cellar user may not confirm, a verifier may.

**This is the one place where the tree enforces an axiom rather than documenting it**,
and `0005:20-24` says so: none of the three rules there survives being implemented in a
client.

**What it would take to carry across modules.** Very little, and that is the point. The
trigger function names no table: it reads `new.provenance` and nothing else. Any module
adding a provenance-bearing table attaches the same trigger. The one requirement is
that `refuse_self_granted_standing()` lives in core and every module's `before insert`
trigger references it, which after a schema split means a qualified reference or a
pinned `search_path`, since it is currently unpinned (section 3.1).

`inferred_fraction()` is the reporting half and it spans core and winemaking (W-4),
so the axiom's enforcement is module-portable while its measurement is not.

### 7.4 The `attributes` jsonb bags: escape hatches, deliberately

**Verdict: escape hatch on `vessel` and `node`; a contract in one corner of `term`.**

Four bags: `vessel.attributes`, `node.attributes`, `term.attributes`,
`template_step.default_data`, plus `task.recurrence` and `event.data`. All
`jsonb not null default '{}'`. Only one carries a constraint,
`operation_has_an_effect`.

The comments are candid that these are hatches. `0001:142-143`: "Loose because barrels
and tanks want different things and this is not worth normalising."

Two of them are load-bearing despite being unchecked, which is the risk:

- `node.attributes -> 'cap_rule'` drives `next_cap_action()`, the app's only directive
  feature. The shape is documented in a comment at `0002:178-179` and enforced nowhere.
  `next_cap_action` handles a missing rule by defaulting to `punchdown` and handles a
  malformed one by returning zero rows from its final select.
- `term.attributes -> 'predicate' -> 'match'` drives `topping_check()`, which decides
  whether pouring is safe. `0004:448-450` names the failure honestly: a predicate naming
  an absent field compares null to null and passes, "the untyped floor behaving as
  designed". Two assertions exercise both directions.

**What it would take to carry a versioned shape across modules.** A per-kind schema
check. The `operation_has_an_effect` constraint is a working template for exactly one
key, and generalising it means either a check constraint per kind or a validating
trigger. The `cap_rule` bag is the more urgent of the two, because it is on a
winemaking table, is read by a function the graph puts in core, and has no constraint
at all.

---

## 8. Hosting and deployment, as the tree commits to them

### 8.1 What exists, and what is absent

| Present | Where |
|---|---|
| Supabase CLI local config | `supabase/config.toml`, 56 lines, stating in its first three lines that it describes local development only |
| Postgres major version pin, 16 | `config.toml:19`, with a comment recording that session 1 pinned 15 and verified on 16, "so the pin was a claim rather than a fact" |
| PostgREST schema exposure | `config.toml:10`, `["public", "graphql_public"]` |
| Auth policy | `config.toml:51`, `enable_signup = false` |
| Storage bucket, guarded | `0005:307-340`, private `vessel-photos` |
| Vite build | `apps/web/vite.config.ts`, 8 lines, no plugins, `outDir: "dist"` |
| Build-time config | `apps/web/.env.example`, `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` |

| Absent | Consequence |
|---|---|
| **CI of any kind.** No `.github/`, no workflow yaml anywhere in the tree | section 8.4 |
| Any hosted-project descriptor | linking is `supabase link`, state deliberately outside the repo |
| `doctor` | stub, `package.json:13`, exits 1 |
| Generated `Database` types | section 4.3 |
| Seed data | `supabase/seed/.gitkeep`, 0 bytes |
| Backup or restore configuration | section 8.5 |

One tension worth naming: `config.toml:51` sets `enable_signup = false` with the
comment "There is no public signup for a winery app", while `claim_account()` exists
precisely so the first sign-up becomes admin, and `kernel.ts:40-43` exposes `signUp`.
The status ledger grades "Sign up and account claim" as In progress with "the screens
above it are unrun". So the first run this config permits and the first run the kernel
implements are two different first runs, and which one is right has not been settled by
running it.

### 8.2 A static client holding an anon key, and what that forecloses

The client is static: Vite to `dist`, no server component, config substituted at build
time by `packages/core/src/env.ts`. The anon key ships in the bundle. **RLS is the only
access boundary.**

Probed, with real rows present, to check what that boundary actually holds:

```
insert into app_user ...; insert into party ...; insert into node ...;
set local role anon;
select count(*) from node;      -- 0
select count(*) from term;      -- 0
select count(*) from app_user;  -- 0
```

and an insert attempt:

```
ERROR: new row violates row-level security policy for table "event"
```

**The boundary holds.** All 38 policies are `to authenticated`, so `anon` has no
policy on any of the 15 tables and RLS defaults to deny. The key in the bundle grants
nothing before a sign-in. This is the correct result and it deserves saying plainly,
because "public anon key" reads alarming and here it is doing exactly what it should.

**What it forecloses.** Anything that must be true regardless of who is asking, and
anything requiring a secret:

| Foreclosed without a server | Why |
|---|---|
| Scheduled work of any kind | template-driven task seeding on stage entry (spec section 2, "Forward, templates seed tasks on stage entry") has no trigger; `generate_inferred_history` runs only when a user calls it |
| `doctor` on a schedule | S-4 says "Resolves when: `doctor` checks it **and is run on a schedule**". A static client cannot run a schedule |
| Nightly git export | compost C-2's surviving fragment, "Adopted", needs credentials no phone may hold |
| TTB report generation | S-9's single conversion point has no server-side home |
| Any outbound integration | Wine Meister export (S-6) |
| Rate limiting, audit beyond `event` | no chokepoint |

**Which candidate modules would need a server.** Measured against what the tree already
names rather than invented:

- **core: yes, and already.** `doctor` on a schedule and template-driven task seeding
  are both core concerns (`task`, `template`, `template_step` are core) and both need
  something that runs without a user.
- **inventory: no.** `vessel`, `vessel_code`, `bind_vessel_code` are entirely
  user-driven.
- **winemaking: no, today.** It becomes yes at the compliance stage, since S-9 through
  S-11 imply reporting.

So the split does not create a server requirement. Core already has one, unbudgeted.

### 8.3 What changes about hosting if modules become separately installable

**Schema exposure.** Each module's schema must be added to PostgREST's list. That list
lives in `config.toml` locally and in the hosted project's API settings in production,
and by the repo's own statement that hosted state stays out of the repository, no
migration can perform this step. So every module install has a manual step outside the
migration system, and a module installed correctly at the database level is invisible
over the API until someone edits a setting in a web console. There is no test for this
and no place in the tree where it would be recorded.

Second-order: PostgREST caches its schema. A newly exposed schema requires a reload
notification, which is automatic on Supabase and is a thing to know about.

Third: `extra_search_path = ["public", "extensions"]` at `config.toml:11` is what the
15 unpinned functions of section 3.1 will resolve against. Splitting schemas without
revisiting this line is the specific mechanism by which those functions break.

**Migration application order.** `supabase db reset` applies
`supabase/migrations/*.sql` in lexical filename order, one global sequence. There is no
notion of a module, a manifest, or a dependency. Per-module ordering means either
encoding the order into filenames across directories, which is the global sequence
again with extra steps, or a tool that reads a manifest, which does not exist. Section
5.3 gives the edges such a manifest would have to declare, including the `task_board`
cycle.

**Runtime discovery of the installed set.** Nothing in the tree discovers anything.
`kernel.ts` names seven objects and four functions as literals and assumes all of them
exist. A missing module surfaces as a thrown `Error(error.message)` from whichever of
the 18 call sites is hit first.

The tree does hold one working pattern for exactly this problem, at `0005:307-311`:

```sql
if not exists (select 1 from information_schema.schemata where schema_name = 'storage') then
  raise notice 'storage schema absent, skipping the vessel-photos bucket';
  return;
end if;
```

That is a module-presence check, written for storage, and the comment calls the guard
"the honest form of that dependency". It is the shape a module manifest would
generalise, and it is already in the tree and already verified: it fired in this
session's run.

### 8.4 What the absence of CI costs, specifically for a multi-module tree

There is no CI. The cost today is bounded, because the definition of done in
`CLAUDE.md` is five commands a person can run in a minute, and because one person is
running them. The cost after a split is different in kind, and the difference is
combinatorial rather than incremental.

| Today | After a split |
|---|---|
| One command sequence: `db reset`, `schema_assertions.sql`, `typecheck`, `lint`, `test`, `doctor` | The same sequence per installable **combination**: core alone, core+inventory, core+winemaking, all three, and each of those against the assertions that apply |
| One migration order to verify | One order per combination, plus the manifest itself |
| A broken function shows up when a person calls it | A broken function shows up when a person on a **different install** calls it, and section 6.3 says the catalog will not have flagged it |

The specific thing CI would buy that nothing else can: **section 6.3's nine silently
broken functions are detectable only by executing each function on each install
combination.** Reading finds them only if someone reads all 21 bodies against a
module map. `tests/schema_assertions.sql` is well placed to be that check, since 28
assertions already call most of these functions, and it needs a way to run against a
partial install and to know which assertions apply.

Second cost, smaller and more likely to bite first: section 4.3 established that a
wrong schema in the client passes both `typecheck` and `lint`. With one schema that is
theoretical. With four it is the most likely mistake anyone makes, it happens in the
one file the whole client depends on, and the only thing that would catch it is a
generated `Database` type that does not exist.

Third: `supabase/config.toml:19` records that a version pin was "a claim rather than a
fact" until someone verified it. That correction was made by hand. Every per-module
claim will be the same kind of claim.

### 8.5 Backup, restore and rollback across independently versioned schemas

**Nothing in the tree configures any of the three.** What the tree commits to:

**Backup.** Compost C-2's surviving fragment, a nightly export to a repository for
version history and offsite backup, is marked Adopted in the compost ledger and graded
Specified in Stage 3. It is not built and, per 8.2, cannot run from the client. Across
modules the question it has to answer changes: a dump of one schema is restorable only
against a database whose core is at a compatible version, so the export has to carry
the installed-module set and each module's version, which is the manifest again.

**Restore.** The hard case is a partial restore, which is the case a module system
invites. `node_bin_shares` walks `lineage` recursively with no depth bound and no cycle
guard; a winemaking restore that lands rows referencing core rows absent from the
target has no foreign key to stop it for `event.subject_id`, and `doctor` is the only
thing that would notice, and it is a stub.

**Rollback.** There are no down migrations anywhere. The recovery path is `supabase db
reset`, which is correct and cheap on an empty database and is unavailable the day
after intake. Per-module versioning multiplies this: rolling core back below a version
that winemaking's foreign keys require has no mechanism to refuse.

**The one genuinely load-bearing fact here is timing.** Every item in this section is
cheap while the database is empty and becomes a real engineering problem the first day
a bin is recorded. `docs/status-ledger.md` puts intake at build order 2, described as
"The object that must exist before all others, and the one where a missed record is
unrecoverable."

**Open: whether the hosted project exists and what its API settings expose.**
*Why:* `supabase/config.toml:1-3` states that hosted state stays out of the repository,
and the status ledger records that no migration has run against the project's own
instance. Nothing in the tree can answer it. *What would settle it:* `supabase projects
list` and the project's API settings page, or the winemaker confirming no hosted
project exists yet.

---

## 9. The bill

Effort assumes one developer already familiar with this tree. "Empty" means the
database still holds no production rows, which is true at `c3eae3c`.

| Item | Effort | What could go wrong | What would catch it | Deferring |
|---|---|---|---|---|
| **Split schemas** (15 tables, 3 views, 21 functions into `core`/`inventory`/`winemaking`) | **2 to 3 days** | The 15 unpinned functions resolve against the caller's `search_path` and break at call time, silently at DDL time (probed). The 6 pinned ones are pinned to `public` literally and break on every call including all 17 `is_admin()` policies | `tests/schema_assertions.sql`, which calls most functions, **if** re-run after the move. The catalog catches nothing: views, FKs, triggers and policies follow by OID at zero cost (probed) | **Same.** `alter table set schema` is metadata-only, so row count is irrelevant. The cost is in the 21 function bodies and that is fixed |
| **Per-module migration numbering** | **0.5 day now** | Renumbering rewrites an applied-migration history | `supabase db reset` from empty, which is the whole test while empty | **⚠ Materially more expensive after intake.** Applied migration names live in `supabase_migrations.schema_migrations` on the hosted project. After intake the realistic path is a permanent two-scheme tree. **This is the one item with a date on it** |
| **Move the scheduling block to core** (`task`, `task_claim_log`, `template`, `template_step`, `claim_task`, `task_board`) | **1 to 1.5 days** | `task_board`'s `CASE` over `subject_type` names `node`, `vessel` and `block` declaratively (W-1). Dropping winemaking destroys the board (probed, 6.1). `generate_inferred_history` spans core and winemaking | Case 1 of the install-alone test, which is four lines of SQL and could be a test today | **Same,** with one caveat: if the registry in 7.2 is built first this collapses to under a day, because the `CASE` becomes a lateral join |
| **Qualify the client** (18 call sites, 1 file) | **2 to 4 hours** | Nothing in the build catches a wrong or missing schema: `typecheck` exit 0 and Biome clean with a nonexistent table, a schema-prefixed name and a misspelled RPC, all three at once (probed). Failure is runtime, on one screen, as a thrown error string | Only a generated `Database` type passed to `createClient<Database>`, which does not exist. Add **0.5 day** for `supabase gen types` and wiring it, and it also catches the 7 hand-mirrored enums in `types.ts` | **Same.** 18 call sites in one file is the most favourable client surface this could have. The number grows with screens, not with rows |
| **Add a module manifest** (declared deps, installed-module registry, subject resolver per module) | **1.5 to 2 days** | The manifest must declare a cycle (core depends on winemaking and inventory for `task_board` alone) until W-1 is fixed. PostgREST schema exposure is a manual step outside the repo that no migration can perform and no test covers | Nothing today. The pattern exists at `0005:307-311`, the storage guard, which the migration's own comment calls "the honest form of that dependency" | **Same,** and cheaper if `subject_type` becomes a registry first |
| *Prerequisite worth pricing separately:* **implement `doctor`** | **1 day** | It is the only enforcement for `event.subject_id` (S-4) and for the 9 silently-broken functions of 6.3 | Itself | **⚠ More expensive after intake:** orphans accumulate before anything looks for them |

### Genuinely irreversible, as against merely annoying

**Irreversible today: nothing.** The database is empty. `docs/status-ledger.md` grades
every migration "written, never run" against the project's own instance and `0004:30`
states "Nothing is preserved. The database is empty." Every item above is currently a
text edit plus `supabase db reset`.

**Becomes irreversible at intake, and only these:**

1. **Migration numbering.** Applied names cannot be renumbered on a live hosted
   project without hand-editing `supabase_migrations.schema_migrations`. After intake
   the tree carries two numbering schemes forever. This is the only item where
   deferring changes the *outcome* rather than the cost.
2. **`subject_type` semantics.** Changing what a value means after `event` and `task`
   rows carry it requires a backfill with no foreign key to validate against and no
   `doctor` to check the result.
3. **Anything S-8 through S-12 touches.** Already recorded in the sorry ledger as
   blocked on the compliance advisor, and S-12 is the one the ledger says has a date on
   it, because bottling happens whether or not the event recording it is complete.

**Everything else is annoying.** Schema splitting, client qualification, the manifest,
and the scheduling move are all mechanical, all bounded, all verifiable by commands
that already exist in `CLAUDE.md`'s definition of done, and none of them gets worse with
row count.

The shape of the recommendation-free conclusion: the expensive thing in this tree is
not the coupling, which is unusually clean at the declarative level, with all eight
crossing foreign keys pointing the right way. The expensive thing is that **123 distinct
edges exist and only 86 are declarative**, so 37 of them will be discovered by calling
a function rather than by applying a migration. Core alone keeps nine broken functions
and reports success. The fix for that is `doctor` and CI, both of which the tree already
names, one at grade Specified and one absent entirely.

---

## Contradiction summary

The prompt asks that a contradiction between the candidate assignment in section 2 and
the graph in section 1 be stated directly, with edges. There is one, and it is
declarative rather than a matter of taste:

**`task_board` places core in dependency on winemaking and inventory, in the catalog.**

- Edge: `task_board` (core view) to `node`, `vessel`, `block`
- Direction: downward-module to upward-module, the wrong way
- Kind: view
- Enforcement: declarative, recorded in `pg_rewrite` and `pg_depend`
- Locator: `supabase/migrations/0004_terms_and_effects.sql:363-368`
- Probed consequence: `drop table block cascade` reports
  `drop cascades to view task_board`; `drop table block, node, lineage, placement
  cascade` reports the same plus `vessel_state`, `resolve_vessel_code` and `lot_state`

Three further contradictions are real and are enforced only at runtime, so they will
survive any install and fail in use: the `subject_type` enum (core, naming three
higher-module tables, with no foreign key by S-4), the `term_kind` enum (core, carrying
inventory and winemaking vocabulary), and the five functions of W-4 that span core and
winemaking.

The most useful single sentence: **`event` looks separable in the catalog only because
sorry S-4 removed the foreign key that would have shown it is not.**
