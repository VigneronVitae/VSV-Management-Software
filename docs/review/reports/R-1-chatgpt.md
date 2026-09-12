# R-1: trust-field and admission boundary audit

| Finding | Verdict | One-line result | Primary locator |
|---|---|---|---|
| R-1-1 | EXPLOITABLE | An authenticated account with no `app_user` row is treated as a facility reader and can read the application record before `claim_account`. | `supabase/migrations/0002_derived_and_rls.sql:245-256`; `supabase/migrations/0003_parties_and_products.sql:243-261` |
| R-1-2 | EXPLOITABLE | `node`, `lineage`, and `placement` insertion is token-only at the RLS boundary; the walk's account-claim gate is not a database admission check. | `supabase/migrations/0002_derived_and_rls.sql:278-293`; `packages/cellar/src/walk.ts:66-76` |
| R-1-3 | EXPLOITABLE | Open lineage admission lets an authenticated caller create a two-node cycle, close both parents, and poison recursive composition with no actor recorded on the edges. | `supabase/migrations/0001_core_schema.sql:179-207`; `supabase/migrations/0002_derived_and_rls.sql:27-44,278-293` |
| R-1-4 | EXPLOITABLE | The `by_sensor is not null` event branch lets any authenticated caller manufacture a sensor identity and bypass user binding, including forging another user's `by_user`. | `supabase/migrations/0001_core_schema.sql:231-251`; `supabase/migrations/0002_derived_and_rls.sql:269-277` |
| R-1-5 | EXPLOITABLE | `claim_task` can take an open task assigned to somebody else, and the direct own-row update policy does not restrict which task columns a holder may rewrite. | `supabase/migrations/0001_core_schema.sql:285-332`; `supabase/migrations/0002_derived_and_rls.sql:294-305` |
| R-1-6 | EXPLOITABLE | Client ownership scoping is enforced on `node` only; authenticated clients can still read other clients' events, placements, vessels, tasks, parties, codes, terms, and photo objects at the policy layer. | `supabase/migrations/0002_derived_and_rls.sql:245-256`; `supabase/migrations/0003_parties_and_products.sql:255-261`; `supabase/migrations/0005_account_and_walk.sql:287-317` |
| R-1-7 | DIVERGENT | T0-4 says trust fields are verifier-written, but the database boundary only refuses `confirmed` on INSERT; direct writers may choose `observed` or `inferred`. | `packages/cellar/docs/spec.md:42-49`; `supabase/migrations/0005_account_and_walk.sql:90-115` |
| R-1-8 | DIVERGENT | The tree calls event history append-only and provides a narrow confirmation function, but an admin RLS policy permits arbitrary direct event UPDATE. | `packages/cellar/docs/spec.md:47-49`; `supabase/migrations/0002_derived_and_rls.sql:269-277`; `supabase/migrations/0005_account_and_walk.sql:120-143` |
| R-1-9 | DIVERGENT | The walk is built around self-signup and a stranger's first run, while the checked-in local Supabase config disables signup and says open signup would allow event insertion. | `packages/cellar/src/walk.ts:42-48,112-129`; `supabase/config.toml:1-3,44-50` |
| R-1-10 | BY DESIGN | `event.subject_id` is deliberately not a foreign key; S-4 explicitly accepts the resulting orphan-subject risk until `doctor` checks it. | `supabase/migrations/0001_core_schema.sql:249-251`; `docs/sorry-ledger.md:34-37` |
| R-1-11 | NOT A DEFECT | A `node` or `event` cannot be born `confirmed`: both have database BEFORE INSERT triggers, generated history writes `inferred`, and `confirm_event` checks the verifier role. | `supabase/migrations/0005_account_and_walk.sql:96-143,156-204`; `tests/schema_assertions.sql:134-155,292-308` |
| R-1-12 | UNVERIFIED | The policy SQL is statically inspectable, but real JWT issuance, PostgREST role/`sub` plumbing, hosted auth settings, RPC exposure, and conditional Storage behavior were not exercised against a running Supabase instance. | `tests/schema_assertions.sql:13-19,32-40`; `docs/sorry-ledger.md:47-58`; `supabase/config.toml:1-3`; `supabase/migrations/0005_account_and_walk.sql:287-317` |

**Audit target:** immutable commit `c3eae3c7c262544e4b2e29526b513c964c6852fe`, which was the first commit shown for `main` in GitHub's branch history when checked on 2026-09-10.

**Method:** read-only static audit of that immutable tree. No patch was prepared. No running Supabase instance, real JWT, camera, phone, or hosted project was available, so runtime-only claims remain UNVERIFIED.

**Bottom line:** the narrow rule “nothing may be born `confirmed`” is a real database boundary (`supabase/migrations/0005_account_and_walk.sql:90-115`). The broader trust-field statement and, more importantly, the write-admission boundary are not comparably hard: authenticated-token possession is sufficient for several record-shaping writes, and some caller-supplied row fields are themselves used as admission evidence (`supabase/migrations/0002_derived_and_rls.sql:269-293`).

---

## EXPLOITABLE

**R-1-1. An unclaimed authenticated account has cellar-wide read access before `claim_account`.**  
*Verdict:* EXPLOITABLE.  
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:245-256`; `supabase/migrations/0003_parties_and_products.sql:37-48,217-224,231-261`; `supabase/migrations/0004_terms_and_effects.sql:466-476`.  
*What is wrong:* The original read policy is `using (true)` for `app_user`, `location`, `block`, `vessel`, `node`, `lineage`, `placement`, `event`, `template`, `template_step`, `task`, and `task_claim_log`; 0003 only replaces the `node` policy (`supabase/migrations/0002_derived_and_rls.sql:245-256`; `supabase/migrations/0003_parties_and_products.sql:255-261`). The replacement is not an account-membership gate: `is_facility_user()` returns true when no active linked `party` row is found, and an unclaimed auth UID cannot be linked through `party.app_user_id` because that column references `app_user` (`supabase/migrations/0003_parties_and_products.sql:37-48,243-254`). `party`, `vessel_code`, and `term` are also readable by every authenticated role (`supabase/migrations/0003_parties_and_products.sql:217-224`; `supabase/migrations/0004_terms_and_effects.sql:466-469`). The database therefore conflates “claimed cellar user with no party, i.e. harvest intern” with “authenticated identity that has never joined the application.”  
*How it surfaces:* Provision an auth identity, obtain an authenticated session, do not call `claim_account`, and select from the public application tables. At the RLS layer that principal can read all of the tables named above, including every `node`; the official walk instead stops at the claim screen because `currentAppUser()` returns null (`packages/core/src/kernel.ts:71-80`; `packages/cellar/src/walk.ts:66-76`).  
*Resolves when:* absence of an `app_user` row is denied at the database read boundary, while the intended claimed cellar-user/no-party case is represented and admitted separately.  
*Load-bearing:* yes — this is the distinction between possession of an auth token and membership in the winery application.

**R-1-2. `node`, `lineage`, and `placement` admission is token-only; the account-claim gate lives in the client.**  
*Verdict:* EXPLOITABLE.  
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:278-293`; `supabase/migrations/0001_core_schema.sql:148-174,181-188,212-224`; `supabase/migrations/0003_parties_and_products.sql:64-74`; `packages/cellar/src/walk.ts:66-76`; `packages/core/src/kernel.ts:17-19`.  
*What is wrong:* All three INSERT policies are created `to authenticated with check (true)`, so none asks whether `auth.uid()` has an `app_user` row, is active, has the intended role, or owns the affected record (`supabase/migrations/0002_derived_and_rls.sql:278-293`). A `node` can omit `created_by` because that field is nullable, and after a facility party exists its `owner_id` defaults to that facility (`supabase/migrations/0001_core_schema.sql:148-174`; `supabase/migrations/0003_parties_and_products.sql:64-74`). The walk does require `currentAppUser()` before routing to operational screens, but that is a client routing decision, while the kernel explicitly describes itself as a thin pass-through rather than a rule boundary (`packages/cellar/src/walk.ts:66-76`; `packages/core/src/kernel.ts:17-19`).  
*How it surfaces:* An authenticated UID with no `app_user` row can insert a `node` after the facility exists, insert lineage between valid node IDs, and insert a placement into a valid empty vessel; schema constraints still apply, but no caller-membership predicate does (`supabase/migrations/0001_core_schema.sql:181-224`; `supabase/migrations/0002_derived_and_rls.sql:278-293`). The same policy shape also means setting an `app_user.active` flag false does not by itself block these inserts; the insert predicates never inspect that field (`supabase/migrations/0001_core_schema.sql:81-87`; `supabase/migrations/0002_derived_and_rls.sql:278-293`).  
*Resolves when:* each of these INSERT boundaries independently proves the caller's application membership, active status, permitted role, and record scope rather than relying on the walk's route.  
*Load-bearing:* yes — these tables define lot identity, transformations, and physical occupancy.

**R-1-3. Open lineage admission permits cycles that close lots and can wedge recursive composition.**  
*Verdict:* EXPLOITABLE.  
*Locator:* `supabase/migrations/0001_core_schema.sql:179-207`; `supabase/migrations/0002_derived_and_rls.sql:27-44,278-293`; `supabase/migrations/0004_terms_and_effects.sql:296-323`; `packages/cellar/docs/spec.md:94-98`.  
*What is wrong:* The tree describes lineage as a DAG, but the table only rejects a self-edge; it has no acyclicity check, and its INSERT policy accepts every authenticated caller (`packages/cellar/docs/spec.md:94-98`; `supabase/migrations/0001_core_schema.sql:179-188`; `supabase/migrations/0002_derived_and_rls.sql:278-293`). Inserting `A -> B` and then `B -> A` is therefore structurally admissible for two distinct valid nodes. Every inserted edge also fires `lineage_closes_parent`, which closes its parent, while `node_bin_shares()` follows parent edges with `UNION ALL` and has no visited-node/cycle termination condition (`supabase/migrations/0001_core_schema.sql:191-207`; `supabase/migrations/0002_derived_and_rls.sql:27-44`). `lineage` records `parent_id`, `child_id`, `fraction`, and `created_at`, but no actor identity (`supabase/migrations/0001_core_schema.sql:181-188`).  
*How it surfaces:* A bad-faith cellar user can insert the two reciprocal edges between accessible nodes. Both nodes are closed by the trigger and disappear from `lot_state`, which selects only non-closed nodes, while composition calls that traverse the cycle can continue recursively until the database terminates the statement or exhausts a resource limit (`supabase/migrations/0001_core_schema.sql:191-207`; `supabase/migrations/0002_derived_and_rls.sql:27-44`; `supabase/migrations/0004_terms_and_effects.sql:296-323`). The record shows the malicious edges and timestamps but not which authenticated principal wrote them (`supabase/migrations/0001_core_schema.sql:181-188`).  
*Resolves when:* the database admission boundary preserves acyclicity for every lineage insert and admits transformations only from an authorized, attributable operation.  
*Load-bearing:* yes — lineage is the source for derived composition and the trigger also changes current lot status.

**R-1-4. Caller-supplied `by_sensor` is accepted as proof of event authorship.**  
*Verdict:* EXPLOITABLE.  
*Locator:* `supabase/migrations/0001_core_schema.sql:231-251`; `supabase/migrations/0002_derived_and_rls.sql:269-277`; `supabase/migrations/0005_account_and_walk.sql:96-115`.  
*What is wrong:* The event INSERT policy accepts a row when `by_user = auth.uid()` **or merely when `by_sensor` is non-null** (`supabase/migrations/0002_derived_and_rls.sql:269-273`). `by_sensor` is just caller-supplied text, while the table's author check likewise requires only one of `by_user` or `by_sensor` to be non-null (`supabase/migrations/0001_core_schema.sql:231-247`). Because the policy's sensor branch is sufficient by itself, an authenticated caller may also put the UUID of any existing `app_user` into `by_user`; the foreign key proves that user exists, not that the caller is that user (`supabase/migrations/0001_core_schema.sql:236-247`; `supabase/migrations/0002_derived_and_rls.sql:270-273`). The provenance trigger prevents `confirmed` at INSERT but does not repair the author binding (`supabase/migrations/0005_account_and_walk.sql:96-115`).  
*How it surfaces:* An authenticated but unclaimed identity can insert an event with `by_sensor = 'whatever'` and `by_user = null`, or combine a fake sensor string with an existing admin's `by_user` UUID. The row is admitted even though no database fact binds either asserted producer identity to the caller (`supabase/migrations/0001_core_schema.sql:231-247`; `supabase/migrations/0002_derived_and_rls.sql:269-273`).  
*Resolves when:* event admission can establish a user identity or sensor identity from trusted caller context, and any row-level author fields are constrained to that established identity rather than being accepted as their own evidence.  
*Load-bearing:* yes — event authorship is part of the production record, and the current predicate lets the producer manufacture its own admission credential.

**R-1-5. The task boundary lets a caller steal assigned work and then rewrite more than claim state.**  
*Verdict:* EXPLOITABLE.  
*Locator:* `supabase/migrations/0001_core_schema.sql:285-332`; `supabase/migrations/0002_derived_and_rls.sql:294-305`; `packages/cellar/docs/spec.md:114-123,175-178`.  
*What is wrong:* `claim_task` is SECURITY DEFINER and updates any task whose ID matches, status is `open`, and `claimed_by` is null; it never checks `assignee`, caller role, or caller active status (`supabase/migrations/0001_core_schema.sql:308-332`). That is broader than the direct RLS update boundary, which only admits a row already claimed by or assigned to the caller, and broader than the board rule that unassigned tasks are claimable while assigned tasks go to a person (`supabase/migrations/0002_derived_and_rls.sql:294-305`; `packages/cellar/docs/spec.md:114-123,175-178`). Once a task qualifies for `task_own_update`, that policy constrains the row predicate but does not constrain which task columns the caller changes (`supabase/migrations/0001_core_schema.sql:285-303`; `supabase/migrations/0002_derived_and_rls.sql:298-302`).  
*How it surfaces:* A claimed cellar user calls `claim_task` with the UUID of an open task assigned to someone else; the definer update claims it for the caller. A task the caller holds can then be updated while retaining `claimed_by = auth.uid()` or `assignee = auth.uid()`, so the policy itself does not prevent changing subject, due window, instructions, recurrence, status, or other task columns (`supabase/migrations/0001_core_schema.sql:285-303`; `supabase/migrations/0002_derived_and_rls.sql:298-302`).  
*Resolves when:* claim admission enforces the board's assignment rule, and non-admin task writes are limited to the intended state transitions and fields rather than to any UPDATE on an own-row predicate.  
*Load-bearing:* yes — the board is the application’s direction/assignment surface, and the definer function can reach a row direct RLS would refuse.

**R-1-6. Ownership scoping protects `node` but leaves the rest of a client's production graph readable.**  
*Verdict:* EXPLOITABLE.  
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:245-256`; `supabase/migrations/0003_parties_and_products.sql:19-22,123-167,217-224,255-261`; `supabase/migrations/0004_terms_and_effects.sql:240-342,466-476`; `tests/schema_assertions.sql:351-369`; `supabase/migrations/0005_account_and_walk.sql:287-317`.  
*What is wrong:* 0003 says ownership drives what a client is permitted to see, but the migration replaces only `node_read`; the blanket authenticated reads from 0002 remain on `app_user`, `location`, `block`, `vessel`, `lineage`, `placement`, `event`, `template`, `template_step`, `task`, and `task_claim_log` (`supabase/migrations/0003_parties_and_products.sql:19-22,255-261`; `supabase/migrations/0002_derived_and_rls.sql:245-256`). `party`, `vessel_code`, and `term` are also authenticated-wide (`supabase/migrations/0003_parties_and_products.sql:217-224`; `supabase/migrations/0004_terms_and_effects.sql:466-469`). The security-invoker views cannot restore confidentiality that their unrestricted base tables already disclose: `vessel_state` exposes placement `node_id`, volume, owner and vessel information, and `task_board` starts from the unrestricted task set (`supabase/migrations/0004_terms_and_effects.sql:240-285,324-342`). The test labeled as client scoping asserts only the number of visible `node` rows (`tests/schema_assertions.sql:351-369`). The conditional vessel-photo policies also grant SELECT and INSERT to every authenticated principal for the bucket, without an owner predicate (`supabase/migrations/0005_account_and_walk.sql:287-317`).  
*How it surfaces:* A client login that correctly sees only its own `node` rows can directly select all `event`, `lineage`, `placement`, `vessel`, `task`, `party`, `vessel_code`, and `term` rows admitted by those policies, and can derive other clients' activity and identifiers from them (`supabase/migrations/0002_derived_and_rls.sql:245-256`; `supabase/migrations/0003_parties_and_products.sql:217-224`; `supabase/migrations/0004_terms_and_effects.sql:466-469`). Where the Storage block is installed, the same authenticated client is also admitted to all objects in the private `vessel-photos` bucket at the policy layer (`supabase/migrations/0005_account_and_walk.sql:287-317`).  
*Resolves when:* ownership scoping covers every base table, view, RPC result, and storage object that reveals another client's production record, and the client test asserts those surfaces rather than only `node`.  
*Load-bearing:* yes — custom-crush ownership was added specifically because clients must not see one another's wine.

---

## DIVERGENT

**R-1-7. The T0-4 prose describes verifier-written trust fields; the trigger enforces only “not confirmed at INSERT.”**  
*Verdict:* DIVERGENT.  
*Locator:* `packages/cellar/docs/spec.md:42-49,184-189`; `CLAUDE.md:35-45`; `supabase/migrations/0001_core_schema.sql:148-174,231-247`; `supabase/migrations/0002_derived_and_rls.sql:70-86,269-293`; `supabase/migrations/0005_account_and_walk.sql:90-115`; `packages/core/src/types.ts:90-101`; `tests/schema_assertions.sql:134-155`.  
*What is wrong:* The spec says trust fields are written by the verifier and the adopted delta-and-verify boundary discards producer-asserted trust fields; `CLAUDE.md` likewise says never write a trust field on behalf of a producer (`packages/cellar/docs/spec.md:42-49,184-189`; `CLAUDE.md:35-45`). The database trigger is explicitly narrower: it rejects only `new.provenance = 'confirmed'` on INSERT (`supabase/migrations/0005_account_and_walk.sql:90-115`). Both tables have a default of `observed`, but direct writers may explicitly supply `observed` or `inferred`; the current typed walk payload happens not to expose node provenance, which is client discipline rather than a database recomputation boundary (`supabase/migrations/0001_core_schema.sql:165-168,241-247`; `packages/core/src/types.ts:90-101`). The distinction is observable downstream because `inferred_fraction` counts event provenance (`supabase/migrations/0002_derived_and_rls.sql:70-86`). The schema assertion checks only that `confirmed` cannot be born; it does not assert that a producer cannot choose `observed` versus `inferred` (`tests/schema_assertions.sql:134-155`).  
*How it surfaces:* Directly insert an otherwise-admissible `event` or `node` with explicit `provenance = 'inferred'` or `provenance = 'observed'`; the T0-4 trigger accepts either, even though the documents describe the verifier as the writer of trust fields (`supabase/migrations/0005_account_and_walk.sql:96-115`).  
*Resolves when:* either the written axiom is narrowed to the boundary actually enforced (“producer cannot create `confirmed`”), or the database becomes the chooser/recomputer for every trust-field value the documents call verifier-owned.  
*Load-bearing:* yes — provenance is consumed as trust information, including by downstream inferred-fraction calculations.

**R-1-8. Event history is called append-only, but admins have an unrestricted direct UPDATE path around `confirm_event`.**  
*Verdict:* DIVERGENT.  
*Locator:* `packages/cellar/docs/spec.md:47-49`; `CLAUDE.md:44-45`; `supabase/migrations/0002_derived_and_rls.sql:269-277`; `supabase/migrations/0005_account_and_walk.sql:115-143`.  
*What is wrong:* T0-5 says history is append-only and a silently rewritable record is not a record; the migration comment says “nobody may rewrite history” (`packages/cellar/docs/spec.md:47-49`; `supabase/migrations/0002_derived_and_rls.sql:269-270`). Immediately below, `event_admin_update` authorizes admins to UPDATE any event row subject to `is_admin()`, with no column or transition restriction (`supabase/migrations/0002_derived_and_rls.sql:274-277`). `confirm_event` is much narrower — admin only and `inferred -> confirmed` only — but the generic update policy permits the same admin to change provenance directly as well as edit author, timestamp, subject, data, or other mutable event columns (`supabase/migrations/0005_account_and_walk.sql:115-143`; `supabase/migrations/0001_core_schema.sql:231-247`).  
*How it surfaces:* An admin can directly UPDATE an observed event to `confirmed`, or rewrite its record fields, without passing through the transition checks in `confirm_event`; no UPDATE trigger in the T0-4 block refuses that path (`supabase/migrations/0002_derived_and_rls.sql:274-277`; `supabase/migrations/0005_account_and_walk.sql:96-143`).  
*Resolves when:* the tree has one declared and enforced event-mutation model: either history is truly append-only apart from explicitly named verifier transitions, or the documents acknowledge the broader admin rewrite authority.  
*Load-bearing:* yes — the append-only property is the basis for treating the event table as a record rather than mutable state.

**R-1-9. The first-run account story and the checked-in local auth configuration disagree about signup.**  
*Verdict:* DIVERGENT.  
*Locator:* `packages/cellar/src/walk.ts:42-48,112-129`; `packages/core/src/kernel.ts:38-41`; `supabase/config.toml:1-3,37-50`.  
*What is wrong:* The walk's acceptance story is a stranger with an empty database and a fresh account, its sign-in screen offers “Create an account,” and the kernel calls `auth.signUp()` (`packages/cellar/src/walk.ts:42-48,112-129`; `packages/core/src/kernel.ts:38-41`). The repository's local Supabase config disables both general and email signup and says there is no public signup because an open one would let anyone insert events (`supabase/config.toml:37-50`). The same config states that hosted project state is outside the repository, so the hosted answer cannot be inferred from this file (`supabase/config.toml:1-3`).  
*How it surfaces:* Against the checked-in local configuration, the walk presents a self-signup action for an auth service configured not to accept that action; against a hosted project, reachability depends on state that this repository explicitly does not describe (`packages/cellar/src/walk.ts:112-129`; `supabase/config.toml:1-3,44-50`). This does not invalidate the R-1 hypothetical of an already-authenticated unclaimed principal; it means the repository gives two different answers about how such a principal comes to exist.  
*Resolves when:* the first-run acceptance story, sign-up UI, local auth configuration, and declared hosted onboarding model agree on whether self-signup exists and how accounts are provisioned.  
*Load-bearing:* yes — it controls the reachability of the unaffiliated-authenticated threat case.

---

## BY DESIGN

**R-1-10. `event.subject_id` has no foreign key, and the tree explicitly carries that integrity gap as S-4.**  
*Verdict:* BY DESIGN.  
*Locator:* `supabase/migrations/0001_core_schema.sql:231-251`; `docs/sorry-ledger.md:34-37`; `packages/cellar/docs/spec.md:105-112,189-192`.  
*What is wrong:* `event.subject_id` is deliberately polymorphic and is not a foreign key; the schema comment says validation must happen on write and periodically, while S-4 records that a bad subject ID fails silently until `doctor` checks it (`supabase/migrations/0001_core_schema.sql:231-251`; `docs/sorry-ledger.md:34-37`). The spec repeats that `doctor` is the intended detector for orphaned event subjects (`packages/cellar/docs/spec.md:189-192`). This is therefore a real integrity weakness, but it is named as deliberate rather than an undisclosed admission mistake.  
*How it surfaces:* An otherwise-admissible event can name a UUID that does not exist in the table implied by `subject_type`; the insert can succeed and downstream event counts can include the orphan until a separate checker identifies it (`supabase/migrations/0001_core_schema.sql:231-251`; `docs/sorry-ledger.md:34-37`).  
*Resolves when:* S-4's stated condition is met: `doctor` checks subject integrity and is run on a schedule (`docs/sorry-ledger.md:34-37`).  
*Load-bearing:* yes — S-4 says every event count remains unvalidated until that check exists and runs.

---

## NOT A DEFECT

**R-1-11. “Nothing may be born confirmed” is a database boundary, not a client convention.**  
*Verdict:* NOT A DEFECT.  
*Locator:* `supabase/migrations/0005_account_and_walk.sql:90-143,145-204`; `tests/schema_assertions.sql:134-155,263-308`.  
*What is wrong:* Nothing in this narrow invariant is wrong at this commit. A shared BEFORE INSERT trigger rejects `confirmed` on both `node` and `event`, generated history explicitly inserts `inferred`, and `confirm_event` refuses a non-admin and only changes an inferred event to confirmed (`supabase/migrations/0005_account_and_walk.sql:90-143,145-204`). The schema assertions exercise both born-confirmed rejections, verify generated history is inferred, verify a cellar caller cannot confirm, and verify an admin can (`tests/schema_assertions.sql:134-155,263-308`). Those assertions prove the database behavior they invoke; they do not prove JWT/PostgREST plumbing, which is separated into R-1-12.  
*How it surfaces:* A direct INSERT of a `node` or `event` with `provenance = 'confirmed'` raises `insufficient_privilege` even if the client supplied the field itself (`supabase/migrations/0005_account_and_walk.sql:96-115`).  
*Resolves when:* N/A — the checked condition holds at this commit; it remains sound only while both BEFORE INSERT triggers remain attached and verifier confirmation stays a separate database operation.  
*Load-bearing:* yes — this is the actual hard boundary currently implementing the “no self-confirmation at birth” subset of T0-4.

---

## UNVERIFIED

**R-1-12. Real Supabase identity plumbing and environment-dependent exposure were not checked.**  
*Verdict:* UNVERIFIED.  
*Locator:* `tests/schema_assertions.sql:13-19,32-40`; `docs/sorry-ledger.md:47-58`; `supabase/config.toml:1-3`; `supabase/migrations/0005_account_and_walk.sql:287-317`.  
*What is wrong:* The repository itself says the SQL assertions exercise Postgres policy evaluation rather than Supabase's JWT-to-role mapping; the helper writes `request.jwt.claim.sub` and the claims object directly (`tests/schema_assertions.sql:13-19,32-40`; `docs/sorry-ledger.md:47-58`). The local config explicitly says hosted project state is outside the repository, and the photo policies are installed only when the Supabase `storage` schema exists (`supabase/config.toml:1-3`; `supabase/migrations/0005_account_and_walk.sql:287-317`). Static inspection therefore establishes the policy predicates and function bodies, not that a real issued JWT reaches them with the expected role/`sub`, that the hosted auth configuration matches local assumptions, or that Storage/RPC exposure behaves as assumed.  
*How it surfaces:* This gap only resolves under a real Supabase stack. Apply the five migrations, provision real admin/cellar/client accounts plus one authenticated identity with no `app_user` row, obtain their actual JWTs, and repeat the read/write matrix below through PostgREST/RPC; also exercise vessel-photo SELECT/INSERT through Storage. Confirm that the JWT maps to `authenticated`, `auth.uid()` is the token subject, the same RLS decisions occur, the definer RPCs are exposed only to the intended roles, and the conditional Storage policies are present.  
*Resolves when:* those real-token, real-API checks are run against the deployment configuration that will actually host the app, with the results recorded against S-7 (`docs/sorry-ledger.md:47-58`).  
*Load-bearing:* yes — all static RLS conclusions depend on the platform delivering the caller identity and role the policies inspect.

---

# Required traces

## 1. Every path into `node.provenance` and `event.provenance`

| Target | Write path | Who chooses the value? | What refuses a wrong choice? |
|---|---|---|---|
| `node.provenance` | Direct INSERT into `node` | Caller may omit it (database default `observed`) or explicitly send `observed`, `inferred`, or `confirmed` (`supabase/migrations/0001_core_schema.sql:148-174`). | The BEFORE INSERT trigger rejects only `confirmed`; `observed` and `inferred` are accepted if the row otherwise passes (`supabase/migrations/0005_account_and_walk.sql:90-115`). RLS does not recompute it; node INSERT is `with check (true)` (`supabase/migrations/0002_derived_and_rls.sql:278-293`). |
| `node.provenance` | `create_vessel_with_wine` | The function's node INSERT omits the provenance column, so the database default chooses `observed`; the JSON node payload has no provenance field in the current typed client (`supabase/migrations/0005_account_and_walk.sql:216-278`; `packages/core/src/types.ts:90-101`). | The same node BEFORE INSERT trigger still runs because the function is security invoker; the function itself does not expose a provenance argument (`supabase/migrations/0005_account_and_walk.sql:90-115,213-278`). Its first vessel INSERT is still subject to ordinary vessel policy (`supabase/migrations/0005_account_and_walk.sql:213-241`; `supabase/migrations/0002_derived_and_rls.sql:257-268`). |
| `node.provenance` | Direct UPDATE of an existing `node` | An admin can choose the replacement value because the generic node admin-update policy authorizes UPDATE without a provenance transition predicate (`supabase/migrations/0002_derived_and_rls.sql:278-293`). | No T0-4 UPDATE trigger is attached to `node`; the T0-4 trigger block attaches only BEFORE INSERT triggers (`supabase/migrations/0005_account_and_walk.sql:90-115`). The RLS gate is `is_admin()` (`supabase/migrations/0002_derived_and_rls.sql:283-288`). |
| `event.provenance` | Direct INSERT into `event` | Caller may omit it (default `observed`) or explicitly send a provenance value (`supabase/migrations/0001_core_schema.sql:231-247`). | BEFORE INSERT rejects only `confirmed`; event RLS checks author fields, not provenance (`supabase/migrations/0005_account_and_walk.sql:96-115`; `supabase/migrations/0002_derived_and_rls.sql:269-273`). |
| `event.provenance` | `generate_inferred_history` | The database function chooses `inferred` explicitly for every generated event (`supabase/migrations/0005_account_and_walk.sql:156-204`). | It is security invoker, so ordinary event INSERT policy and constraints apply, and the shared trigger would reject `confirmed` if the function tried to write it (`supabase/migrations/0005_account_and_walk.sql:145-204`; `supabase/migrations/0002_derived_and_rls.sql:269-273`). |
| `event.provenance` | `confirm_event` | The verifier function chooses `confirmed`; caller supplies only an event UUID (`supabase/migrations/0005_account_and_walk.sql:120-143`). | SECURITY DEFINER bypasses row RLS, so the function itself checks `is_admin()` and only updates rows currently `inferred` (`supabase/migrations/0005_account_and_walk.sql:120-143`). |
| `event.provenance` | Direct UPDATE of an existing `event` | An admin can choose the replacement value — and other event fields — through `event_admin_update` (`supabase/migrations/0002_derived_and_rls.sql:274-277`). | RLS checks only `is_admin()` before and after; there is no provenance transition check in that policy and no event UPDATE trigger in the T0-4 block (`supabase/migrations/0002_derived_and_rls.sql:274-277`; `supabase/migrations/0005_account_and_walk.sql:90-143`). |

The current kernel does **not** expose a direct event-insert function (`packages/core/src/kernel.ts:1-274`); its production writes visible there are vocabulary/location/party/vessel writes plus the composite vessel-with-wine RPC, while `nodeEvents` is a read (`packages/core/src/kernel.ts:96-109,143-171,187-249`). The absence of a client call is not the trust boundary: the database INSERT paths above remain independently defined by the schema and policies (`packages/core/src/kernel.ts:17-19`; `supabase/migrations/0002_derived_and_rls.sql:269-293`).

## 2. Every SECURITY DEFINER function in the five migrations

There are six SECURITY DEFINER functions in the five migration files at this commit. 0002 and 0004 contain no `security definer` declaration (`supabase/migrations/0002_derived_and_rls.sql:1-313`; `supabase/migrations/0004_terms_and_effects.sql:1-476`); the six declarations and bodies are at the locators in this table.

| Function | Reads | Writes | Argument/caller validation | Can reach rows direct RLS would refuse? | `search_path` |
|---|---|---|---|---|---|
| `is_admin()` | `app_user` for `id = auth.uid()` with role `admin` and `active` (`supabase/migrations/0001_core_schema.sql:88-99`). | None. | No args; identity comes from `auth.uid()`, and both role and active status are tested (`supabase/migrations/0001_core_schema.sql:88-99`). | It bypasses `app_user` RLS to answer the helper predicate, but the table also has authenticated-wide SELECT in 0002; its important use is as the database predicate for admin writes (`supabase/migrations/0002_derived_and_rls.sql:245-268`). | Pinned: `set search_path = public` (`supabase/migrations/0001_core_schema.sql:88-99`). |
| `claim_task(p_task_id)` | `task` through the UPDATE predicate/RETURNING (`supabase/migrations/0001_core_schema.sql:308-332`). | Sets `status='claimed'`, `claimed_by=auth.uid()`, `claimed_at=now()` on one task (`supabase/migrations/0001_core_schema.sql:316-324`). | Validates only task ID, `status='open'`, and `claimed_by is null`; it does not test assignee, role, active app-user state, or an app-user row before the UPDATE (`supabase/migrations/0001_core_schema.sql:308-332`). | **Yes.** A task assigned to another user would fail direct `task_own_update`, but the definer function does not apply that row predicate (`supabase/migrations/0002_derived_and_rls.sql:294-302`). This is R-1-5. | Pinned: `set search_path = public` (`supabase/migrations/0001_core_schema.sql:308-332`). |
| `current_party_id()` | `party`, filtered to active row linked to `auth.uid()` (`supabase/migrations/0003_parties_and_products.sql:231-239`). | None. | No args; returns the caller's linked active party or null (`supabase/migrations/0003_parties_and_products.sql:231-239`). | It can read through party RLS as definer, but direct party SELECT is already `using (true)` (`supabase/migrations/0003_parties_and_products.sql:217-224`). | Pinned: `set search_path = public` (`supabase/migrations/0003_parties_and_products.sql:231-239`). |
| `is_facility_user()` | Calls `is_admin()` and reads `party` for the caller (`supabase/migrations/0003_parties_and_products.sql:243-254`). | None. | No args; critically, absence of a matching active party is converted to `true` by `coalesce(..., true)` (`supabase/migrations/0003_parties_and_products.sql:243-254`). | **Yes for node visibility.** It is used inside `node_read`, and the no-party fallback broadens that policy to an unclaimed auth UID as well as the intended no-party cellar user (`supabase/migrations/0003_parties_and_products.sql:239-261`). This is R-1-1. | Pinned: `set search_path = public` (`supabase/migrations/0003_parties_and_products.sql:243-254`). |
| `claim_account(p_name)` | Reads caller's `app_user` row and counts `app_user` after an advisory lock (`supabase/migrations/0005_account_and_walk.sql:34-65`). | Inserts exactly `id = auth.uid()` with supplied name and computed role when no row exists (`supabase/migrations/0005_account_and_walk.sql:43-65`). | Rejects null `auth.uid()`, returns an existing own row idempotently, serializes the first-user decision, and never accepts a caller-supplied user ID or role (`supabase/migrations/0005_account_and_walk.sql:34-65`). | **Yes, intentionally.** Direct `app_user` writes are admin-only, so this is the bootstrap path that creates the caller's own row and computes first-user admin versus later cellar (`supabase/migrations/0002_derived_and_rls.sql:257-268`; `supabase/migrations/0005_account_and_walk.sql:26-65`). | Pinned: `set search_path = public` (`supabase/migrations/0005_account_and_walk.sql:34-65`). |
| `confirm_event(p_event_id)` | Calls `is_admin()` and selects the target through UPDATE/RETURNING (`supabase/migrations/0005_account_and_walk.sql:120-143`). | Changes only `event.provenance` to `confirmed` where it is currently `inferred` (`supabase/migrations/0005_account_and_walk.sql:131-143`). | Rejects non-admin callers and rejects a target that is not an inferred event (`supabase/migrations/0005_account_and_walk.sql:128-143`). | It bypasses event RLS, but a direct admin UPDATE policy already exists; the function is narrower than that policy rather than broader (`supabase/migrations/0002_derived_and_rls.sql:274-277`). | Pinned: `set search_path = public` (`supabase/migrations/0005_account_and_walk.sql:120-143`). |

No missing `search_path` pin was found among those six declarations: every one explicitly sets `search_path = public` (`supabase/migrations/0001_core_schema.sql:88-99,308-332`; `supabase/migrations/0003_parties_and_products.sql:231-254`; `supabase/migrations/0005_account_and_walk.sql:34-65,120-143`).

## 3. Write-admission boundary

| Table | Who may INSERT at RLS layer? | What the database requires beyond authenticated role | Where the actual boundary lives |
|---|---|---|---|
| `event` | Any `authenticated` role whose row passes `by_user = auth.uid() OR by_sensor is not null` (`supabase/migrations/0002_derived_and_rls.sql:269-273`). | Schema requires at least one author field; `by_user`, if present, must reference an `app_user`; the T0-4 trigger rejects `confirmed` at INSERT (`supabase/migrations/0001_core_schema.sql:231-247`; `supabase/migrations/0005_account_and_walk.sql:96-115`). The sensor branch does **not** require an `app_user` row or trusted sensor identity (`supabase/migrations/0002_derived_and_rls.sql:269-273`). | RLS author predicate + table constraints + provenance trigger; the weak part is that a caller-supplied sensor string satisfies the author predicate. |
| `node` | Any `authenticated` role; `with check (true)` (`supabase/migrations/0002_derived_and_rls.sql:278-293`). | Table/FK constraints, non-null owner after 0003, and the no-`confirmed` INSERT trigger (`supabase/migrations/0001_core_schema.sql:148-174`; `supabase/migrations/0003_parties_and_products.sql:64-74`; `supabase/migrations/0005_account_and_walk.sql:96-115`). No caller membership/active/role predicate exists in the INSERT policy (`supabase/migrations/0002_derived_and_rls.sql:278-293`). | Database constraints enforce row shape; **application membership is only a walk routing decision** (`packages/cellar/src/walk.ts:66-76`). |
| `lineage` | Any `authenticated` role; `with check (true)` (`supabase/migrations/0002_derived_and_rls.sql:278-293`). | Parent/child FKs, positive fraction no greater than one, non-self edge; after INSERT, a trigger closes the parent (`supabase/migrations/0001_core_schema.sql:181-207`). No role, ownership, actor, status, or acyclicity predicate is present (`supabase/migrations/0001_core_schema.sql:181-207`; `supabase/migrations/0002_derived_and_rls.sql:278-293`). | Token admission plus structural constraints only. |
| `placement` | Any `authenticated` role; `with check (true)` (`supabase/migrations/0002_derived_and_rls.sql:278-293`). | Valid node/vessel FKs and the unique active-vessel occupancy index; no caller membership, role, ownership, or app-user predicate (`supabase/migrations/0001_core_schema.sql:212-224`). | Token admission plus structural constraints only. |
| `term` | Authenticated SELECT; writes require `is_admin()` (`supabase/migrations/0004_terms_and_effects.sql:466-476`). | `is_admin()` requires caller UID to have an active `app_user` row with role `admin` (`supabase/migrations/0001_core_schema.sql:88-99`). | Database RLS. The picker may offer “Add one,” but the actual admission boundary is the term policy (`packages/cellar/src/pickers.ts:56-76`; `supabase/migrations/0004_terms_and_effects.sql:466-476`). |

The walk's facility screen also checks `user.role !== "admin"` before showing facility creation, but `party` writes independently require `is_admin()` in RLS, so that particular UI check is backed by a database predicate (`packages/cellar/src/walk.ts:164-215`; `supabase/migrations/0003_parties_and_products.sql:217-230`). By contrast, the walk's “must have an `app_user` row before home” gate has no corresponding predicate on `node`, `lineage`, or `placement` INSERT (`packages/cellar/src/walk.ts:66-76`; `supabase/migrations/0002_derived_and_rls.sql:278-293`).

## 4. Authenticated principal with no `app_user` row

This section assumes the platform has produced a real authenticated principal but `claim_account` has not been called, exactly as the R-1 scenario asks. Whether the real hosted auth stack can produce and route that principal as assumed is R-1-12.

### Reads

At the RLS/policy layer, the principal can read:

- `app_user`, `location`, `block`, `vessel`, `lineage`, `placement`, `event`, `template`, `template_step`, `task`, and `task_claim_log`, because their authenticated read policies are `using (true)` (`supabase/migrations/0002_derived_and_rls.sql:245-256`).
- `node`, because `is_facility_user()` maps the absence of an active linked party to `true`; without an `app_user` row the caller cannot be the `app_user_id` of a valid party row (`supabase/migrations/0003_parties_and_products.sql:37-48,243-261`).
- `party` and `vessel_code`, because both have authenticated-wide SELECT policies (`supabase/migrations/0003_parties_and_products.sql:213-224`).
- `term`, because its read policy is authenticated-wide (`supabase/migrations/0004_terms_and_effects.sql:466-469`).
- The data underlying `vessel_state`, `lot_state`, and `task_board` is therefore not filtered on account membership; the views are security invoker and their final definitions are at `supabase/migrations/0004_terms_and_effects.sql:240-342`.
- If the conditional Storage block was installed because a `storage` schema exists, the bucket policies admit authenticated SELECT on all objects in `vessel-photos` (`supabase/migrations/0005_account_and_walk.sql:287-317`). Actual Storage API behavior is part of R-1-12.

### Writes

At the policy/constraint layer, the same still-unclaimed principal can:

- INSERT `node` once a facility party exists, because node INSERT is `with check (true)`, `created_by` may be null, and owner defaults to the facility (`supabase/migrations/0002_derived_and_rls.sql:278-293`; `supabase/migrations/0001_core_schema.sql:148-174`; `supabase/migrations/0003_parties_and_products.sql:64-74`). It may not insert the node as `confirmed` because the trigger refuses that value (`supabase/migrations/0005_account_and_walk.sql:96-115`).
- INSERT `lineage` between valid distinct nodes; the insert closes the parent and there is no actor column on the edge (`supabase/migrations/0001_core_schema.sql:181-207`; `supabase/migrations/0002_derived_and_rls.sql:278-293`).
- INSERT `placement` for valid node/vessel IDs if the structural constraints, including one-current-lot-per-vessel, permit it (`supabase/migrations/0001_core_schema.sql:212-224`; `supabase/migrations/0002_derived_and_rls.sql:278-293`).
- INSERT `event` by setting any non-null `by_sensor`; `by_user` may be null, so no `app_user` FK need be satisfied (`supabase/migrations/0001_core_schema.sql:231-247`; `supabase/migrations/0002_derived_and_rls.sql:269-273`). It may not insert `confirmed` (`supabase/migrations/0005_account_and_walk.sql:96-115`).
- Call `claim_account`, which intentionally creates its own `app_user` row; after that call it is no longer the principal in this scenario (`supabase/migrations/0005_account_and_walk.sql:34-65`).
- If Storage exists and the policy is active, INSERT an object into `vessel-photos` at the policy layer because the policy checks only authenticated role and bucket ID (`supabase/migrations/0005_account_and_walk.sql:287-317`).

It cannot, while remaining unclaimed:

- Directly write `app_user`, `location`, `block`, `vessel`, `template`, or `template_step`, because those structural writes require `is_admin()`, which requires an active admin `app_user` row (`supabase/migrations/0002_derived_and_rls.sql:257-268`; `supabase/migrations/0001_core_schema.sql:88-99`).
- Write `party` or `vessel_code`, which also require `is_admin()` (`supabase/migrations/0003_parties_and_products.sql:219-230`).
- Write `term`, which requires `is_admin()` (`supabase/migrations/0004_terms_and_effects.sql:473-476`).
- Successfully become `task.claimed_by` or `task.assignee` without first having an `app_user` row because both columns reference `app_user`; `claim_task` would attempt to store `auth.uid()` into `claimed_by`, so the FK remains a constraint even though the function is SECURITY DEFINER (`supabase/migrations/0001_core_schema.sql:285-332`). Likewise an own-ID `task_claim_log` insert would hit its `app_user` FK (`supabase/migrations/0001_core_schema.sql:335-341`; `supabase/migrations/0002_derived_and_rls.sql:303-305`).
- Use `confirm_event`, because the function calls `is_admin()` and rejects a non-admin caller (`supabase/migrations/0005_account_and_walk.sql:120-143`).
- Use `create_vessel_with_wine` successfully through its first structural vessel write, because it is deliberately security invoker and vessel write policy is admin-only (`supabase/migrations/0005_account_and_walk.sql:213-241`; `supabase/migrations/0002_derived_and_rls.sql:257-268`).

### What the UI and views do with rows this principal created

The official walk never reaches home: `currentAppUser()` returns null and `route()` sends the session to `claimScreen` (`packages/core/src/kernel.ts:71-80`; `packages/cellar/src/walk.ts:66-76`). That is why these writes are invisible through the intended route while still being admitted at the database boundary.

`task_board` does not derive tasks from the rogue node/event/lineage/placement rows; it selects existing task rows and joins `claimed_by` and `assignee` to `app_user` (`supabase/migrations/0004_terms_and_effects.sql:324-342`). Because those task user columns are foreign keys to `app_user`, an unclaimed UID cannot produce a task row whose joined name is merely blank; it is prevented from occupying those user fields (`supabase/migrations/0001_core_schema.sql:285-303`).

The inventory views are different. `lot_state` exposes nodes without joining `created_by`, and `vessel_state` exposes placements without an actor field, so an unclaimed principal's admitted node/placement rows look like ordinary inventory state rather than “rows from an unclaimed account” (`supabase/migrations/0004_terms_and_effects.sql:240-323`). `lineage` has no actor column at all (`supabase/migrations/0001_core_schema.sql:181-188`). An event inserted through the sensor branch may carry `by_user = null` and only the caller-chosen sensor string, or may carry another existing user's UUID together with that string (`supabase/migrations/0001_core_schema.sql:231-247`; `supabase/migrations/0002_derived_and_rls.sql:269-273`). In other words, the schema does not create a reliable `app_user` join that retrospectively identifies the unaffiliated principal for the rows it is permitted to create.

## 5. Most damaging bad-faith cellar action

The strongest static path found is lineage poisoning, not provenance self-confirmation. A bad-faith cellar principal may insert lineage because the policy is open to every authenticated role (`supabase/migrations/0002_derived_and_rls.sql:278-293`). Two reciprocal edges between distinct valid nodes satisfy the table's only graph-shape check, because `no_self_parent` rejects only `parent_id = child_id` (`supabase/migrations/0001_core_schema.sql:181-188`). Each edge then closes its parent (`supabase/migrations/0001_core_schema.sql:191-207`), causing the affected nodes to disappear from `lot_state`'s open-lot view (`supabase/migrations/0004_terms_and_effects.sql:296-323`), and the resulting cycle feeds `node_bin_shares()`'s `UNION ALL` recursion with no cycle guard (`supabase/migrations/0002_derived_and_rls.sql:27-44`).

The damage is visible as suspicious lineage edges, changed node status, and timestamps, but attribution is weak: `lineage` has no `created_by`/actor field (`supabase/migrations/0001_core_schema.sql:181-188`). A forged event is stealthier in attribution terms because the caller may manufacture `by_sensor`, but the lineage cycle is more damaging to current state because it can both retire lots and make composition traversal fail to terminate normally (`supabase/migrations/0001_core_schema.sql:191-207`; `supabase/migrations/0002_derived_and_rls.sql:27-44,269-293`).

---

# Test coverage: what is proved and what is assumed

`tests/schema_assertions.sql` is explicit that it checks Postgres policy evaluation and not Supabase JWT-to-role plumbing (`tests/schema_assertions.sql:13-19`). Its `test_act_as` helper writes the `sub` claim settings directly (`tests/schema_assertions.sql:32-40`). The RLS section then switches to role `authenticated` for claimed users and proves that a cellar user is refused location/vessel/term writes, may insert an event, and sees nodes; the client test proves only node ownership scoping (`tests/schema_assertions.sql:311-369`).

That means the following are statically exercised:

- born-`confirmed` node/event refusal (`tests/schema_assertions.sql:134-155`);
- generated history stamped `inferred` and the `confirm_event` role check (`tests/schema_assertions.sql:263-308`);
- selected RLS outcomes for already-claimed cellar/client accounts (`tests/schema_assertions.sql:311-369`).

The following R-1 paths are not covered by those assertions at this commit:

- an authenticated UID with no `app_user` row;
- node/lineage/placement INSERT under that UID or under a hostile cellar UID;
- the `by_sensor` event-admission branch;
- a forged `by_user` combined with non-null `by_sensor`;
- a lineage cycle and recursive composition against it;
- `claim_task` against a task assigned to somebody else;
- column breadth of `task_own_update`;
- client reads of non-`node` tables/views/storage;
- real GoTrue JWT issuance, PostgREST role mapping, RPC exposure, and Storage API enforcement.

The file itself names the JWT/plumbing half as S-7 rather than claiming the tests prove it (`tests/schema_assertions.sql:13-19`; `docs/sorry-ledger.md:47-58`).

---

# Answer to the R-1 question

**Is it a boundary, or is it a rule?**

For one narrow transition, it is a boundary: a producer cannot INSERT a `node` or `event` already marked `confirmed`, because a database trigger refuses the row regardless of what the client sends (`supabase/migrations/0005_account_and_walk.sql:90-115`).

For the broader statement “trust fields are written by the verifier,” it is still partly a rule: direct writers can choose `observed` versus `inferred`, and only `confirmed` is recomputed/refused at the write boundary (`packages/cellar/docs/spec.md:42-49`; `supabase/migrations/0001_core_schema.sql:165-168,241-247`; `supabase/migrations/0005_account_and_walk.sql:90-115`).

For admission, several important paths are weaker still. `node`, `lineage`, and `placement` accept any authenticated role; `event` accepts a caller-supplied non-null sensor string as sufficient admission evidence; and `is_facility_user()` turns “no linked party” into facility-wide node read access without first requiring an `app_user` row (`supabase/migrations/0002_derived_and_rls.sql:269-293`; `supabase/migrations/0003_parties_and_products.sql:243-261`). The database boundary therefore does not consistently distinguish “has a token” from “has standing in the application.”
