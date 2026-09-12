# G-1: Postgres schema, queries, and migrations review

**Reviewed commit:** `c3eae3c7c262544e4b2e29526b513c964c6852fe` — 2026-09-08 — current `main`, obtained through GitHub commit history plus commit-pinned `raw.githubusercontent.com` files after local clone/DNS access failed.

**Acquisition note:** The original prompt requires stopping if no current tree can be obtained. After that happened in the execution sandbox, the user explicitly asked to proceed with what remained accessible. This review therefore uses the current `main` commit plus commit-pinned raw reads of every file in the prescribed G-1 read set, `CLAUDE.md`, `packages/cellar/docs/spec.md`, and the four content canaries. It does **not** claim that a local checkout or a running Supabase instance was available.

## Current-tree proof

| Check | Result |
|---|---|
| Commit | PASS. GitHub's `main` history currently starts at `c3eae3c7c262544e4b2e29526b513c964c6852fe`, dated 2026-09-08. |
| Branch | PASS. The history inspected is `main`, not `claude/sql-files-to-markdown-i31rob`. |
| LICENSE canary | PASS. Current `main` is not the old LICENSE-only state; the repository exposes the application, docs, packages, Supabase, and tests trees. |
| Content canaries | PASS. `supabase/migrations/0005_account_and_walk.sql`, `tests/schema_assertions.sql`, `packages/cellar/src/walk.ts`, and `docs/session-reports/2026-09-08-walk.md` all exist at the pinned SHA. |
| Baseline file count | The web fallback did not provide a reliable recursive tracked-file count, so I did not invent one. The required structure and all four content canaries match the baseline. |

The prior session report itself says the five migrations applied cleanly **from empty** on scratch PostgreSQL 16, while `supabase db reset`, real JWT mapping, Storage, and the over-the-wire Supabase path were not exercised (`docs/session-reports/2026-09-08-walk.md:79-133`). That distinction matters below.

## Finding summary

| ID | Severity | Triage |
|---|---|---|
| G-1-1 | MAJOR | BEFORE HARVEST |
| G-1-2 | MAJOR | BEFORE HARVEST |
| G-1-3 | MAJOR | BEFORE HARVEST |
| G-1-4 | MAJOR | BEFORE HARVEST |
| G-1-5 | MAJOR | BEFORE HARVEST |
| G-1-6 | MAJOR | BEFORE HARVEST |
| G-1-7 | MAJOR | DURING |
| G-1-8 | MAJOR | DURING |
| G-1-9 | MAJOR | AFTER |
| G-1-10 | MINOR | DURING |
| G-1-11 | MINOR | DURING |
| G-1-12 | MINOR | AFTER |
| G-1-13 | UNVERIFIED | BEFORE HARVEST |
| G-1-14 | NOT A DEFECT | AFTER |
| G-1-15 | NOT A DEFECT | AFTER |
| G-1-16 | NOT A DEFECT | AFTER |

No BLOCKER was found. Six items are tagged BEFORE HARVEST; the remaining real defects are safe to correct during use or defer.

# MAJOR

**G-1-1. Client-party RLS is scoped on `node` but not on the rest of the data surface.**  
*Severity:* MAJOR  
*Triage:* BEFORE HARVEST  
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:244-254`; `supabase/migrations/0003_parties_and_products.sql:216-223,254-260`; `supabase/migrations/0005_account_and_walk.sql:292-313`  
*What is wrong:* Migration 0002 grants every authenticated user `SELECT ... USING (true)` on `app_user`, `location`, `block`, `vessel`, `lineage`, `placement`, `event`, `template`, `template_step`, `task`, and `task_claim_log`. Migration 0003 replaces only `node_read`; `party` and `vessel_code` are also readable by every authenticated user, and the private photo bucket permits every authenticated user to read every vessel photo. A client login therefore does not satisfy the migration's own requirement that it see "their own wine and no more" (`supabase/migrations/0003_parties_and_products.sql:33-35`).  
*Why it matters here:* With two custom-crush clients, this is a direct cross-client confidentiality failure: a client can enumerate cellar structure, placements, events, tasks, parties, codes, and photos even when other lots are hidden from `node`. `task`, `event`, and `placement` are also in `supabase_realtime`, so the same broad read policies make their Postgres Changes eligible for every authenticated subscriber (`supabase/migrations/0002_derived_and_rls.sql:306-312`).  
*Fix:* Replace blanket client-facing reads with `is_facility_user()`-or-ownership predicates that follow `node.owner_id`; default client access to deny on tables with no defined ownership path. For harvest, make vessel-photo read/insert facility-only unless a party-scoped object path/policy is deliberately defined. This is a policy migration; no new dependency is needed.  
*Effort:* hours.

**G-1-2. Any authenticated client can insert structural cellar rows and events outside its own wine.**  
*Severity:* MAJOR  
*Triage:* BEFORE HARVEST  
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:268-291`; `supabase/migrations/0003_parties_and_products.sql:254-260`  
*What is wrong:* `node`, `lineage`, and `placement` inserts use `WITH CHECK (true)` for all authenticated users, and `event_insert` checks only that `by_user = auth.uid()` **or** that `by_sensor` is non-null. After a client signs in, it can therefore create nodes with arbitrary known owners, add lineage/placements against known UUIDs, and record events against arbitrary subjects; setting `by_sensor` also bypasses the human-author equality check.  
*Why it matters here:* This is not a scale problem. One client login can contaminate the production record or move apparent cellar state for another party, which is hours of harvest-time reconciliation.  
*Fix:* Make structural inserts facility-user-only unless a client write use case is explicitly required. If clients are meant to record events, scope event writes through the subject's owning node/party and make sensor ingestion a separate trusted path rather than `by_sensor IS NOT NULL`. This is a policy migration; no new dependency is needed.  
*Effort:* hours.

**G-1-3. Deactivating a linked client party turns that login into a facility user.**  
*Severity:* MAJOR  
*Triage:* BEFORE HARVEST  
*Locator:* `supabase/migrations/0003_parties_and_products.sql:230-260`  
*What is wrong:* `current_party_id()` ignores inactive parties, and `is_facility_user()` does the same lookup then `coalesce(..., true)`. A login still linked to an inactive client party therefore produces no active-party row and falls through to `true`, gaining the facility side of `node_read`.  
*Why it matters here:* Deactivation is exactly the action likely to be taken when a client should lose access. In the current logic it widens that client's node visibility instead.  
*Fix:* Distinguish "no party link exists" from "a party link exists but is inactive." For example, allow the harvest-intern case only when **no** `party` row references `auth.uid()`, and separately allow an active facility link; an inactive client link should return false. Add an assertion for an inactive client login. No new dependency is needed.  
*Effort:* minutes.

**G-1-4. `claim_task` is a `SECURITY DEFINER` write path that bypasses task RLS without checking who may claim.**  
*Severity:* MAJOR  
*Triage:* BEFORE HARVEST  
*Locator:* `supabase/migrations/0001_core_schema.sql:307-330`; `supabase/migrations/0002_derived_and_rls.sql:293-301`  
*What is wrong:* `claim_task` executes with owner privileges and updates an arbitrary open task by UUID, but it neither checks `auth.uid()` for null nor verifies that the caller is a facility user or eligible assignee. PostgreSQL grants `EXECUTE` on new functions to `PUBLIC` by default unless revoked, and this migration contains no function grant/revoke.  
*Why it matters here:* A signed-in custom-crush client can read all tasks under G-1-1, then invoke the definer function and claim a cellar task regardless of normal task policy. An anonymous caller with a leaked task UUID can also execute the function; `claimed_by` would remain null while status becomes `claimed`.  
*Fix:* Reject null identities, require a facility/eligible task actor inside the function, and `REVOKE EXECUTE ... FROM PUBLIC` followed by the narrow intended grant (normally `authenticated`). Keep the operation atomic. No new dependency is needed.  
*Effort:* minutes.

**G-1-5. The schema says event history is append-only, but admins can rewrite any event in place.**  
*Severity:* MAJOR  
*Triage:* BEFORE HARVEST  
*Locator:* `supabase/migrations/0001_core_schema.sql:11-14`; `supabase/migrations/0002_derived_and_rls.sql:268-276`; `supabase/migrations/0005_account_and_walk.sql:115-142`  
*What is wrong:* The RLS comment says "nobody may rewrite history" and corrections are new events, but `event_admin_update` grants admins unrestricted `UPDATE` over event rows. `confirm_event` already provides the one narrow in-place change the later migration needs: inferred to confirmed.  
*Why it matters here:* An accidental or ad-hoc admin update can silently change operation, subject, timestamp, author, payload, or provenance of the historical production record. That undermines exactly the record integrity this schema otherwise takes care to preserve.  
*Fix:* Drop the general `event_admin_update` policy. Keep confirmation through the existing `SECURITY DEFINER` verifier function, and represent other corrections as new events. This is a small policy migration; no dependency.  
*Effort:* minutes.

**G-1-6. Longer lineage cycles are legal and make composition recursion non-terminating.**  
*Severity:* MAJOR  
*Triage:* BEFORE HARVEST  
*Locator:* `supabase/migrations/0001_core_schema.sql:178-188`; `supabase/migrations/0002_derived_and_rls.sql:22-42`  
*What is wrong:* `lineage` forbids only `parent_id = child_id`; it does not enforce the stated DAG invariant for two or more nodes. `node_bin_shares` recursively follows parents with `UNION ALL` and has neither a visited set nor a depth bound, so a two-node cycle is sufficient to keep producing rows indefinitely. `block_composition` and `variety_composition` inherit the failure; `inferred_fraction` is safer because its recursive CTE uses `UNION` and deduplicates node IDs (`supabase/migrations/0002_derived_and_rls.sql:69-85`).  
*Why it matters here:* A single bad lineage edge can hang the composition query used for labeling/traceability. This has nothing to do with large scale: two nodes are enough.  
*Fix:* Enforce acyclicity on lineage insertion with a constraint trigger that rejects an edge when the proposed child is already an ancestor of the proposed parent. A defensive path/depth guard in the read function is reasonable, but the write-path DAG check is the fix. No new dependency.  
*Effort:* hours.

At the stated normal shape the traversal is otherwise cheap. A branching factor of 4 over 3 levels generates only 85 recursive rows. Path explosion becomes material around 5 parents over 7 levels (97,656 rows) and plainly slow around 6 over 8 levels (2,015,539 rows), both far beyond the stated "few levels" cellar graph.

**G-1-7. Sibling lineage fractions can sum above one, so derived composition can exceed 100%.**  
*Severity:* MAJOR  
*Triage:* DURING  
*Locator:* `supabase/migrations/0001_core_schema.sql:180-186`; `supabase/migrations/0002_derived_and_rls.sql:26-65`  
*What is wrong:* Each edge is constrained to `(0,1]`, but nothing constrains the sum of all parent fractions for one child. Two parents at `0.80000` each are valid rows and produce a derived total of `1.60000`. A total below one is preserved rather than normalized, which is useful for incomplete/unresolved composition; the defect is allowing totals above one.  
*Why it matters here:* The composition functions feed varietal/block provenance and can return confidently impossible percentages for a blend. The fix is additive and can be applied while the system is in use.  
*Fix:* Add a deferred constraint trigger on `lineage` that rejects a child whose parent-fraction sum exceeds `1.00000`; deliberately continue to allow totals below one. Validate existing data before enabling it. No dependency.  
*Effort:* hours.

**G-1-8. "Today" in cap-action sequencing means UTC day, not the winery's Pacific day.**  
*Severity:* MAJOR  
*Triage:* DURING  
*Locator:* `supabase/migrations/0004_terms_and_effects.sql:345-379`  
*What is wrong:* `next_cap_action` counts today's punchdowns/pumpovers with `e.at >= date_trunc('day', now())`. Supabase databases default to UTC, and PostgreSQL truncates `timestamptz` using the session time zone unless a zone is supplied. At the winery that means the sequence resets at 5:00 p.m. PDT or 4:00 p.m. PST rather than local midnight.  
*Why it matters here:* During active fermentation the function can recommend the wrong next cap action late in the cellar day, and the reset shifts by an hour across the harvest-season DST boundary.  
*Fix:* Make the business day explicit, e.g. compare against `date_trunc('day', now(), 'America/Los_Angeles')` on PostgreSQL 16, or compare Pacific-local dates with `AT TIME ZONE`. Keep stored timestamps as `timestamptz`; those are correct. No dependency.  
*Effort:* minutes.

**G-1-9. Migrations 0003-0005 are fresh-install migrations, not safe upgrades of populated predecessors.**  
*Severity:* MAJOR  
*Triage:* AFTER  
*Locator:* `supabase/migrations/0003_parties_and_products.sql:64-73,96-118`; `supabase/migrations/0004_terms_and_effects.sql:17-29,175-223`; `supabase/migrations/0005_account_and_walk.sql:77-86`  
*What is wrong:* On a database that already has nodes, 0003 adds `owner_id NOT NULL DEFAULT facility_party_id()` before a facility party can already exist, and it drops the old vessel `qr_code` without migrating values to `vessel_code`. Migration 0004 explicitly says "Nothing is preserved. The database is empty," then adds required term-id columns and drops their enum/text predecessors with no backfill; 0005 drops `template.variety` without mapping existing values into `variety_id`.  
*Why it matters here:* The current five-file sequence is reported to apply cleanly from empty, so this does not block a fresh harvest deployment. It does mean an installation stopped at an earlier migration cannot safely advance after it has collected real production data.  
*Fix:* Treat the current sequence as an install baseline. Before any real database is upgraded from an intermediate version, add forward migrations that seed/resolve the facility, copy QR codes, map enum/text values to term IDs, validate, then make columns `NOT NULL` and drop predecessors. With no down migrations, rollback after destructive steps is restore-from-backup or another forward repair migration. No dependency.  
*Effort:* days if an older populated database actually exists; otherwise document the baseline now and address upgrade migrations off-season.

# MINOR

**G-1-10. `operation_has_an_effect` accepts an operation with no effect at all.**  
*Severity:* MINOR  
*Triage:* DURING  
*Locator:* `supabase/migrations/0004_terms_and_effects.sql:40-59`; `tests/schema_assertions.sql:58-66`  
*What is wrong:* For an operation whose `attributes` lacks `effect`, `attributes ->> 'effect' IN (...)` evaluates to NULL; PostgreSQL CHECK constraints accept NULL as not-false. The assertion suite rejects an invalid value such as `"magic"` but does not test a missing key.  
*Why it matters here:* Every seeded operation is correct, so nothing is wrong today, but the facility-extensible vocabulary can admit a future operation the kernel cannot classify. That is exactly the sort of plausible edit MINOR is for.  
*Fix:* Require key presence/non-null as part of the check, for example `kind <> 'operation' OR (attributes ? 'effect' AND attributes ->> 'effect' IN (...))`, and add a missing-effect assertion. No dependency.  
*Effort:* minutes.

**G-1-11. Several physical/history fields accept obviously impossible values.**  
*Severity:* MINOR  
*Triage:* DURING  
*Locator:* `supabase/migrations/0001_core_schema.sql:120-139,147-173,211-218,284-301`  
*What is wrong:* `vessel.capacity_l`, `node.quantity`, and `placement.volume_l` have no non-negative check; `placement.to_at` can precede `from_at`; task `due_to` can precede `due_from`. Negative temperatures are physically plausible here and should **not** be constrained merely for being negative.  
*Why it matters here:* These are not expected normal writes, and the client screens already steer users toward sensible values, but one malformed API/offline write can create a state that later sums and views accept as real.  
*Fix:* After checking existing rows, add declarative CHECK constraints for non-negative physical quantities and ordered time ranges. This is an additive migration; no dependency.  
*Effort:* hours.

**G-1-12. Definer functions pin `search_path` to `public` but do not force `pg_temp` last.**  
*Severity:* MINOR  
*Triage:* AFTER  
*Locator:* `supabase/migrations/0001_core_schema.sql:87-98,307-330`; `supabase/migrations/0003_parties_and_products.sql:230-252`; `supabase/migrations/0005_account_and_walk.sql:33-64,119-142`  
*What is wrong:* The definer functions do set `search_path`, which is better than inheriting the caller's path, but PostgreSQL's security guidance recommends explicitly putting `pg_temp` last because the temporary schema is otherwise searched ahead of named schemas. The normal browser/PostgREST surface does not expose arbitrary temporary-table DDL, so this is hardening rather than the direct harvest exploit in G-1-4.  
*Why it matters here:* These functions run with elevated privileges; making their object resolution unambiguous is cheap insurance before the database gains more integration paths.  
*Fix:* Change each definer to `SET search_path = public, pg_temp` (or fully qualify objects) and pair definer functions with explicit EXECUTE grants. No dependency.  
*Effort:* minutes.

# UNVERIFIED

**G-1-13. Real Supabase JWT/RLS, Storage, and wire-format behavior have not been exercised.**  
*Severity:* UNVERIFIED  
*Triage:* BEFORE HARVEST  
*Locator:* `tests/schema_assertions.sql:12-24`; `supabase/config.toml:0-20,33-49`; `docs/session-reports/2026-09-08-walk.md:113-133`  
*What is wrong:* The SQL tests simulate `auth.uid()` by setting JWT claims directly; the repository explicitly records that `supabase db reset`, GoTrue-issued tokens, PostgREST RPC mapping, Storage bucket/policies, and real-JWT RLS were not run in the prior environment. I also did not have a running Supabase instance in this review.  
*Why it matters here:* Several BEFORE HARVEST findings sit exactly on those boundaries. A real client JWT test is the fastest way to prove the repaired policies actually behave as intended.  
*Fix:* Before cellar use, run the migrations through `supabase db reset`/a disposable Supabase project and execute tests with three real identities: admin, unlinked cellar user, and linked client; include Realtime subscriptions, `claim_task`, and vessel-photo access. This uses the repository's existing Supabase tooling; no new dependency is proposed.  
*Effort:* hours.

# NOT A DEFECT

**G-1-14. Numeric precision is conservative for the stated winery scale; recursive multiplication does not repeatedly round to a column scale.**  
*Severity:* NOT A DEFECT  
*Triage:* AFTER  
*Locator:* `supabase/migrations/0001_core_schema.sql:103-108,120-130,147-160,180-188,211-218`; `supabase/migrations/0002_derived_and_rls.sql:26-65`  
*What is wrong:* Nothing found in the reviewed arithmetic. Volumes use `numeric(10,2)`, lot quantities `numeric(12,3)`, temperatures `numeric(5,2)`, and lineage fractions `numeric(6,5)`; `node_bin_shares` promotes the running share to unconstrained `numeric` and multiplies exact numerics, so it does not round back to five places at each recursive level.  
*Why it matters here:* At about 50 vessels, summing two-decimal placement volumes has more precision than cellar operations need; the only composition-integrity defect is the missing sibling-sum constraint in G-1-7, not numeric overflow or floating-point drift.  
*Fix:* None. Keep `numeric`; do not introduce floating point or a denormalized cached composition.  
*Effort:* none.

The only quantization of a lineage edge is the stored five-decimal fraction itself. Multiplying/summing those values remains exact decimal arithmetic. No reviewed SQL multiplies a `numeric(10,2)` volume by a differently scaled stored numeric.

**G-1-15. Final views are security-invoker and the important query shapes have supporting indexes at this scale.**  
*Severity:* NOT A DEFECT  
*Triage:* AFTER  
*Locator:* `supabase/migrations/0001_core_schema.sql:175-188,222-225,251-253,303-305`; `supabase/migrations/0003_parties_and_products.sql:102-175`; `supabase/migrations/0004_terms_and_effects.sql:61-80,187-205,239-341`  
*What is wrong:* Nothing in the view/index mechanics themselves. The final `vessel_state`, `lot_state`, and `task_board` definitions use `security_invoker = true`; their data leak today comes from overly broad underlying policies, not view-owner privilege. Recursive lineage walks have `lineage(child_id)`, current-placement lookups have partial vessel/node indexes, code resolution has the unique `code` index, `term_id` has `(kind,value)`, event-by-subject/time has `event_subject_idx`, and the open task board has `task_board_idx`.  
*Why it matters here:* With tens of thousands of rows after a decade, the remaining scans are small enough that adding cache layers, workers, replicas, or denormalized state would be the wrong trade.  
*Fix:* None for performance. Do not add indexes merely to eliminate tiny sequential scans.  
*Effort:* none.

Within the prescribed SQL read set, some indexes have no demonstrated query that needs them as its leading access path, notably `vessel_location_idx`, `node_stage_idx`, `node_block_idx`, `vessel_owner_idx`, `node_product_type_idx`, and `task_subject_idx` (`supabase/migrations/0001_core_schema.sql:141-142,175-177,303-305`; `supabase/migrations/0003_parties_and_products.sql:74-81,91-93`). I would **not** remove them for harvest: at this data size their maintenance cost is negligible, and several plausibly serve client list/filter queries outside the G-1 SQL read set.

**G-1-16. The enums left after 0004 are appropriately fixed-tier concepts.**  
*Severity:* NOT A DEFECT  
*Triage:* AFTER  
*Locator:* `supabase/migrations/0001_core_schema.sql:31-58`; `supabase/migrations/0003_parties_and_products.sql:29-40`; `supabase/migrations/0004_terms_and_effects.sql:23-39,221-223`  
*What is wrong:* Nothing found. Migration 0004 correctly moved facility-configurable vessel/product/operation vocabulary to `term` and retained enums for concepts the kernel has to interpret.  
*Why it matters here:* Adding a value to these remaining enums should be an explicit schema/code decision, not an admin picker action. That is the right boundary for a five-to-ten-user production system.  
*Fix:* None. Adding any remaining enum value costs a migration (`ALTER TYPE ... ADD VALUE`) and, for most of them, corresponding kernel/policy/UI handling.  
*Effort:* none.

Remaining fixed enums and why they belong there:

| Enum | Assessment / cost of a new value |
|---|---|
| `node_stage` | Fixed lifecycle semantics. New value needs migration plus stage-dependent behavior/UI review. |
| `node_status` | Fixed state machine. New value needs migration plus every status filter/transition reviewed. |
| `provenance` | Fixed trust semantics. New value needs migration plus verification/reporting semantics. |
| `quantity_unit` | Correctly fixed **for now** because unit conversion is not implemented as configurable vocabulary. New unit needs migration plus conversion/display logic. |
| `thermal_mode` | Fixed controller state. New value needs migration plus temperature-control behavior. |
| `subject_type` | Fixed polymorphic dispatch set. New value needs migration plus every subject-name/validation branch. |
| `task_status` | Fixed workflow state. New value needs migration plus board/transition behavior. |
| `user_role` | Fixed authorization role. New value needs migration plus policy semantics. |
| `party_kind` | Fixed ownership/RLS role. New value needs migration plus ownership/access semantics. |
| `term_kind` | Intentionally fixed meta-vocabulary; `supabase/migrations/0004_terms_and_effects.sql:32-38` explicitly says a new kind implies a kernel consumer. |

# Function audit

The volatility markings are generally good. Functions that only read tables are `STABLE`; functions/triggers that write rely on PostgreSQL's default `VOLATILE`, which is correct. No reviewed table-reading function should be `IMMUTABLE`.

| Function | Locator | Volatility / security / null behavior | Result |
|---|---|---|---|
| `is_admin()` | `0001_core_schema.sql:87-98` | `STABLE`, definer, pinned `public`; no args. | Correct volatility; see G-1-12. |
| `close_parent_on_lineage()` | `0001_core_schema.sql:191-206` | default `VOLATILE`, invoker trigger, writes `node`. | Correct. |
| `claim_task(uuid)` | `0001_core_schema.sql:307-330` | default `VOLATILE`, definer; null/unknown id raises unavailable after no update. | Volatility correct; authorization defective, G-1-4. |
| `node_bin_shares(uuid)` | `0002_derived_and_rls.sql:26-43` | `STABLE`, invoker; null yields no bin rows. | Volatility correct; cycle safety defective, G-1-6. |
| `block_composition(uuid)` | `0002_derived_and_rls.sql:44-55` | `STABLE`, invoker; inherits empty/null and cycle behavior. | Correct except inherited G-1-6/G-1-7. |
| `variety_composition(uuid)` | `0004_terms_and_effects.sql:227-238` | `STABLE`, invoker; inherits `node_bin_shares`. | Correct except inherited G-1-6/G-1-7. |
| `inferred_fraction(uuid)` | `0002_derived_and_rls.sql:69-86` | `STABLE`, invoker; recursive `UNION` terminates on cycles; null/no events returns 0. | Fine. |
| `facility_party_id()` | `0003_parties_and_products.sql:54-60` | `STABLE`, invoker; returns null if no active facility. | Fine; callers intentionally rely on NOT NULL to refuse premature node creation. |
| `resolve_vessel_code(text)` | `0004_terms_and_effects.sql:285-294` | `STABLE`, invoker; null/unknown code returns no rows. | Fine. |
| `bind_vessel_code(...)` | `0003_parties_and_products.sql:181-208` | default `VOLATILE`, invoker; null code reaches NOT NULL failure. | Correct volatility. |
| `current_party_id()` | `0003_parties_and_products.sql:230-238` | `STABLE`, definer; no args. | Correct volatility; inactive-party interaction contributes to G-1-3. |
| `is_facility_user()` | `0003_parties_and_products.sql:239-252` | `STABLE`, definer; no args. | Logic defective, G-1-3; see G-1-12 for path hardening. |
| `term_id(kind,text)` | `0004_terms_and_effects.sql:64-72` | `STABLE`, invoker; null/unknown key returns null. | Fine. |
| `operation_effect(uuid)` | `0004_terms_and_effects.sql:73-81` | `STABLE`, invoker; unknown id returns null; missing effect can also return null because of G-1-10. | Function itself fine. |
| `next_cap_action(uuid)` | `0004_terms_and_effects.sql:345-380` | `STABLE`, invoker; absent/null node falls through to default punchdown sequence. | Volatility correct; UTC-day defect is G-1-8. The nonexistent-node fallback is worth tightening when this function is next touched, but I did not elevate it beyond that. |
| `topping_check(...)` | `0004_terms_and_effects.sql:384-460` | `STABLE`, invoker; empty target explicitly returns false; predicate fields intentionally compare null-to-null per comments. | Fine for stated design. |
| `claim_account(text)` | `0005_account_and_walk.sql:33-64` | default `VOLATILE`, definer; explicitly rejects unauthenticated caller; null name ultimately fails NOT NULL. | Correct core behavior; see G-1-12. |
| `refuse_self_granted_standing()` | `0005_account_and_walk.sql:95-114` | default `VOLATILE`, invoker trigger. | Correct. |
| `confirm_event(uuid)` | `0005_account_and_walk.sql:119-142` | default `VOLATILE`, definer; requires admin and errors for null/non-inferred target. | Correct narrow verifier path; see G-1-12. |
| `generate_inferred_history(...)` | `0005_account_and_walk.sql:155-203` | default `VOLATILE`, invoker; unknown/null node errors, missing variety/template returns 0. | Correct. |
| `create_vessel_with_wine(...)` | `0005_account_and_walk.sql:215-277` | default `VOLATILE`, invoker; composes ordinary writes in one transaction. | Correct security choice; table policies remain the boundary. |

# Constraint and partial-index audit notes

- `placement_one_lot_per_vessel` uses `WHERE to_at IS NULL`, exactly matching the stated rule that a vessel holds one current lot while a lot may span many vessels (`supabase/migrations/0001_core_schema.sql:220-225`). **Correct.**
- `party_one_facility` uses `WHERE kind = 'facility' AND active`, permitting an old facility to be deactivated before another becomes active (`supabase/migrations/0003_parties_and_products.sql:48-52`). **Reasonable for the one-active-facility model.**
- `task_board_idx` uses the same open/claimed predicate as the board view (`supabase/migrations/0001_core_schema.sql:303-305`; `supabase/migrations/0004_terms_and_effects.sql:323-341`). **Correct.**
- Composite `(term_id, kind)` foreign keys turn picker/type expectations into database constraints (`supabase/migrations/0004_terms_and_effects.sql:60-61,175-219`). **Well built.**
- `event.subject_id` deliberately has no FK because its target table depends on `subject_type` (`supabase/migrations/0001_core_schema.sql:248-250`). I did not call that a defect in this review; the repository explicitly owns it as a validation/doctor responsibility.
- `event.has_an_author` permits both `by_user` and `by_sensor` at once even though the comment says a sensor is set "instead of" a user (`supabase/migrations/0001_core_schema.sql:235-246`). I would change this to exactly-one (`num_nonnulls(...) = 1`) when the sensor ingestion path is implemented, but the more urgent current defect is the `by_sensor` RLS bypass in G-1-2.

# Timestamp and DST audit

The schema consistently uses `timestamptz` for recorded instants: user/location/vessel/node creation, lineage creation, placement intervals, event timestamps, task due/claim/create times, and code timestamps (`supabase/migrations/0001_core_schema.sql:23-24,80-85,103-108,120-137,147-168,180-184,211-218,230-243,284-301`; `supabase/migrations/0003_parties_and_products.sql:102-108`). That is the correct storage choice across the November daylight-saving transition; instants remain unambiguous in UTC.

The defect is not the column types. It is interpreting "today" without the winery's zone in `next_cap_action`, covered by G-1-8.

# Realtime publication

`supabase_realtime` contains exactly these application tables in the reviewed migrations:

- `task`
- `event`
- `placement`

Locator: `supabase/migrations/0002_derived_and_rls.sql:306-312`.

Supabase Postgres Changes applies table RLS to decide which records a client may receive. Therefore the publication mechanism itself does not bypass RLS. The current problem is that all three tables retain authenticated `SELECT USING (true)` from 0002, so every authenticated user is allowed to read—and therefore subscribe to changes from—all three. Fixing G-1-1 fixes the replication audience as well.

# Migration order, locks, replay, rollback

- `0001` and `0002` are structurally plausible on their intended predecessor state; `0002` mainly creates views/functions/policies/index/publication membership.
- `0003` is the first migration that is not a safe upgrade over populated `0001`/`0002`, for the owner default and QR-code drop described in G-1-9.
- `0004` explicitly assumes an empty database and performs the largest destructive conversion (`supabase/migrations/0004_terms_and_effects.sql:17-29,158-223`).
- `0005` is mostly additive, but its template-variety conversion still drops old text without a backfill (`supabase/migrations/0005_account_and_walk.sql:77-86`).
- On a fresh database, the repository's scratch-Postgres report says all five applied in order (`docs/session-reports/2026-09-08-walk.md:79-107`). I did not rerun that database test here.
- The `ALTER TABLE`, view drops/recreates, index creation, and type drops take ordinary PostgreSQL DDL locks. At this application's tens-of-thousands-of-rows ceiling, lock duration itself is not the reason to redesign these migrations; data conversion is the real issue.
- There are no down migrations. Before destructive production upgrades, rollback must mean a verified backup/restore plan or a tested forward repair migration. Once 0003/0004/0005 predecessor columns are dropped, SQL alone cannot reconstruct values that were never copied.

# Index/query-shape conclusion

At the stated scale I found no missing index worth a harvest change. The important shapes are covered:

- lineage recursion: `lineage(child_id)` — `supabase/migrations/0001_core_schema.sql:188`
- current vessel occupancy: partial unique `placement(vessel_id) WHERE to_at IS NULL` — `supabase/migrations/0001_core_schema.sql:222-223`
- current placements by lot: `placement(node_id) WHERE to_at IS NULL` — `supabase/migrations/0001_core_schema.sql:225`
- event history by subject/time: `event(subject_type,subject_id,at DESC)` — `supabase/migrations/0001_core_schema.sql:251`
- inferred-event review: partial provenance index — `supabase/migrations/0001_core_schema.sql:253`
- task board: partial `(status,due_to)` — `supabase/migrations/0001_core_schema.sql:303-305`
- code resolution: unique `vessel_code(code)` — `supabase/migrations/0003_parties_and_products.sql:102-113`
- term lookup: unique `(kind,value)` — `supabase/migrations/0004_terms_and_effects.sql:40-63`
- ownership policy: `node(owner_id)` — `supabase/migrations/0003_parties_and_products.sql:72-74`

No caching, denormalization, queue, service split, replica, or background worker is warranted by these query shapes at this winery's scale.

# NITs

No NIT-only findings. The report intentionally does not turn naming/style preferences into defects.

# External behavior checked against current documentation

Three conclusions above depend on platform/database behavior rather than repository text alone:

1. Supabase databases use UTC as the default database timezone.
2. PostgreSQL `date_trunc` on `timestamptz` uses the current session timezone unless a timezone is supplied.
3. PostgreSQL grants new functions `EXECUTE` to `PUBLIC` by default, and its `SECURITY DEFINER` guidance recommends a safe `search_path` with `pg_temp` explicitly last.
4. Supabase Postgres Changes sends RLS-protected records only to clients allowed to read them.

Those checks support G-1-4, G-1-8, G-1-12, and the Realtime conclusion; they do not replace the repository locators above.
