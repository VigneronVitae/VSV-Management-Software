# CC_R1.md

# R-1: the trust-field and admission boundary

**Commit reviewed:** `c3eae3c7c262544e4b2e29526b513c964c6852fe`, dated 2026-09-08, obtained by `git clone https://github.com/VigneronVitae/VSV-Management-Software` over HTTPS on 2026-09-11.

## Currency checks

| Check | Result |
|---|---|
| Commit | `git rev-parse HEAD` = `c3eae3c7c262544e4b2e29526b513c964c6852fe`. Equal to the review baseline, not an ancestor. |
| Branch | `main`. The stale `claude/sql-files-to-markdown-i31rob` exists on the remote and was not read. |
| LICENSE canary | Fails to trigger: the tree holds 42 tracked files, not a lone `LICENSE`. |
| Content canary | All four present: `supabase/migrations/0005_account_and_walk.sql`, `tests/schema_assertions.sql`, `packages/cellar/src/walk.ts`, `docs/session-reports/2026-09-08-walk.md`. Tracked file count is exactly 42. |

Every locator below is read at that SHA.

## How this review was conducted

This is the fourth session and the first three could not run the environment, so reasoning from SQL text alone was the failure mode most likely to repeat. It was avoided where it could be. A Postgres 16 cluster was initialised locally, a minimal Supabase shim was written (roles `anon` / `authenticated` / `service_role`, an `auth` schema with `users` and a `uid()` reading `request.jwt.claim.sub` then `request.jwt.claims`, and an empty `supabase_realtime` publication), and all five migrations were applied from empty. They apply clean. The repository's own `tests/schema_assertions.sql` then ran against that instance: **28 assertions, all 28 pass.** The status ledger's claim at `docs/status-ledger.md:40` is accurate.

Seventeen adversarial probes were then run against the same instance under `set local role authenticated` and `set local role anon`. Findings below marked *(probed)* were executed and their stated outcome is an observed one. Two of my own predictions were falsified by probing and the corrected results are what appear here: R-1-2 is not the defect I expected, and my first attempt at R-1-4 failed for a harness reason, not a schema one.

What the shim does **not** reproduce is the half S-7 names: GoTrue minting a real JWT and PostgREST mapping it to a role and a claim. Everything below is therefore a claim about Postgres policy evaluation. Where the distinction changes a verdict, it is stated.

---

## Findings

| id | one line | verdict |
|---|---|---|
| R-1-1 | `by_sensor` is an unchecked escape from the author check on `event` | EXPLOITABLE |
| R-1-2 | `lineage_closes_parent` silently does nothing when a non-admin presses | EXPLOITABLE |
| R-1-3 | Any authenticated principal may write lineage naming any node as parent, and lineage records no author | EXPLOITABLE |
| R-1-4 | `claim_task` accepts a null identity and freezes the task it claims | EXPLOITABLE |
| R-1-5 | Client read-scoping covers `node` alone; thirteen other tables are `using (true)` | EXPLOITABLE |
| R-1-6 | Deactivating a client party widens its read to the whole cellar | EXPLOITABLE |
| R-1-7 | `task_own_update` gates which row, never which columns | EXPLOITABLE |
| R-1-8 | `topping_check` lets the caller name the predicate that judges the pour | EXPLOITABLE |
| R-1-9 | A principal with a token and no `app_user` row writes events, nodes and lineage, unattributably | EXPLOITABLE |
| R-1-10 | `generate_inferred_history` takes an arbitrary `p_from`, so history can be backdated onto any readable lot | EXPLOITABLE |
| R-1-11 | Every public function is executable by `anon`; no migration revokes anything | EXPLOITABLE |
| R-1-12 | Every authenticated principal reads every vessel photo | EXPLOITABLE |
| R-1-13 | `confirm_event`'s inferred-only rule is a convention; the table's UPDATE path checks nothing | LATENT |
| R-1-14 | `node.provenance` has no verifier path at all | LATENT |
| R-1-15 | Composition functions run as invoker, so a client's composition silently truncates | LATENT |
| R-1-16 | The producer chooses between `observed` and `inferred`; the adopted pattern says the verifier recomputes | DIVERGENT |
| R-1-17 | `0002` says cellar users rack; racking needs an UPDATE they cannot perform | DIVERGENT |
| R-1-18 | S-7 says "treat the policies as correct"; 22 of 28 assertions never enter the `authenticated` role | DIVERGENT |
| R-1-19 | "A client is not told how many others exist" is not what the schema does | DIVERGENT |
| R-1-20 | CLAUDE.md's definition of done names a script that does not exist | DIVERGENT |
| R-1-21 | The walk offers admin-only actions to a cellar user with no role check | DIVERGENT |
| R-1-22 | A photo is uploaded before the transaction that would justify it | LATENT |
| R-1-23 | A principal linked to no party sees the whole cellar | BY DESIGN |
| R-1-24 | `create_vessel_with_wine` is security invoker and grants nothing | NOT A DEFECT |
| R-1-25 | All six `security definer` functions pin `search_path` | NOT A DEFECT |
| R-1-26 | All four views carry `security_invoker = true` | NOT A DEFECT |
| R-1-27 | The T0-4 insert trigger genuinely fires for every role | NOT A DEFECT |
| R-1-28 | Supabase's auth plumbing, Realtime fan-out, and the storage service | UNVERIFIED |

---

## The answer to the question

**It is a rule wearing a boundary's clothes, and the rule covers one value out of three.**

`refuse_self_granted_standing` at `supabase/migrations/0005_account_and_walk.sql:105-125` is a real boundary and it does what its comment says: nothing may be born `confirmed`, whoever is writing. That was probed and it holds for every role, because a `before insert` trigger is role-blind. It is also the whole of the enforcement. `provenance` is a three-valued enum and the producer picks freely between the other two. An event asserting `observed` on a press that never happened is accepted verbatim, from a cellar user, over the wire, with no verifier involved at any point.

That matters because T0-3 states the purpose in its own words: "an inferred press and a recorded press must never be indistinguishable." The value that makes them distinguishable is chosen by the producer. The axiom's stated source, at `packages/cellar/docs/spec.md:214-218`, is stronger still: the verifier "recomputes trust fields, discarding any the agent asserted." Nothing in the tree recomputes or discards. One value is refused and the rest is taken on trust.

The rest of the answer is that **the admission boundary is not where the documents put it.** Writes to `node`, `lineage` and `placement` are `with check (true)`, which is not a predicate, it is the absence of one. `event`'s check is a predicate with a disjunction that dissolves it. Per question 3: there is no table where the admission decision is a client routing decision *in the sense the question anticipates*, because there is barely an admission decision at all. The boundary that actually exists is the admin/cellar split on structural tables, and it works. The boundary the trust fields need does not exist.

---

## EXPLOITABLE

**R-1-1. `by_sensor` is an unchecked escape from the author check on `event`.**
*Verdict:* EXPLOITABLE *(probed)*
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:289-291`; the column at `supabase/migrations/0001_core_schema.sql:257`; the check constraint at `0001:266-267`.
*What is wrong:* The policy reads `with check (by_user = auth.uid() or by_sensor is not null)`. The second arm is satisfied by any non-null string the client sends, and satisfying it makes the first arm irrelevant, so `by_user` becomes free-form. The disjunction was meant to admit sensors that have no user; it admits users who send a sensor name.
*Steps:* Sign in as any cellar user. `app_user` is world-readable to `authenticated` (`0002:262-272`), so read the admin's uuid. Insert an event with `by_user` set to that uuid and `by_sensor` set to anything. Probed: the row lands with `by_user` = the admin's id. The event log now says an admin dosed 500ppm SO2 into a lot.
*How it surfaces:* Never, in the app. `nodeEvents` at `packages/core/src/kernel.ts:248` does not select `by_user` at all, so no screen shows authorship to be doubted.
*Resolves when:* the two cases are separated, so that a row carrying `by_sensor` is required to carry a null `by_user`, and a row carrying `by_user` is required to match `auth.uid()`.
*Load-bearing:* yes. Attribution is what the event table is for, and `task_claim_log` exists specifically to record who held what.

**R-1-2. `lineage_closes_parent` silently does nothing when a non-admin presses.**
*Verdict:* EXPLOITABLE *(probed)*
*Locator:* `supabase/migrations/0001_core_schema.sql:207-223`; the policy that defeats it at `0002:306-310`.
*What is wrong:* `close_parent_on_lineage()` is a plain `language plpgsql` trigger function with no `security definer`, so its `update node set status = 'closed'` runs as the invoker and is filtered by `node_admin_update`, which requires `is_admin()`. For a cellar user the update matches zero rows. A statement matching zero rows under RLS raises nothing. The trigger returns `new` and the insert succeeds.
*Steps:* As a cellar user, insert a node and a lineage edge naming an existing lot as parent. Probed: the edge is written and the parent's status is still `open`. The identical two statements run as an admin leave the parent `closed`. Same trigger, same data, different structural outcome, decided by the writer's role and reported to nobody.
*How it surfaces:* At harvest, as a bin that was pressed this morning still sitting in `lot_state` this afternoon, still offered as a press source, still counted in vessel occupancy. It surfaces as the data being wrong, long after the afternoon it went wrong.
*Resolves when:* the trigger function runs with rights sufficient to perform the close it exists to perform, or the close is moved somewhere that is not subject to the writer's own policy.
*Load-bearing:* yes. This is the mechanism S-3 is written about, and S-3 assumes it fires.

**R-1-3. Any authenticated principal may write lineage naming any node as parent, and lineage records no author.**
*Verdict:* EXPLOITABLE *(probed)*
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:302-304`; the table at `0001:195-202`; `node_bin_shares` at `0002:29-46`.
*What is wrong:* `lineage_insert` is `with check (true)`. The table's columns are `parent_id`, `child_id`, `fraction`, `created_at`, and that is all: there is no `created_by`, no owner predicate, and nothing that relates an edge to whoever wrote it. `fraction` is constrained to `(0, 1]` and to nothing else, and the sum of an edge's siblings is unconstrained.
*Steps:* As any cellar user, insert `(victim_node, my_node, 1.0)`. `node_bin_shares` now walks from my node into the victim's ancestry and `block_composition` and `variety_composition` report the victim's vineyards as mine. Probed end to end. Removing the edge requires `is_admin()`; a cellar user's `delete from lineage` matches zero rows and raises nothing, so the attacker cannot undo it either.
*How it surfaces:* At labelling or on a TTB return, as a composition figure nobody can source. There is no column to ask who wrote the edge.
*Resolves when:* an edge carries an author and the insert predicate says something about the relationship between the writer and the parent.
*Load-bearing:* yes. Lineage is the only structure the object model has; T0-1 puts everything else on top of it.

**R-1-4. `claim_task` accepts a null identity and freezes the task it claims.**
*Verdict:* EXPLOITABLE *(probed)*
*Locator:* `supabase/migrations/0001_core_schema.sql:335-360`; the recovery policy at `0002:319-322`.
*What is wrong:* The function is `security definer`, so it bypasses `task`'s policies entirely, and it never checks that `auth.uid()` is non-null. With no claim set it executes `set claimed_by = auth.uid()` as `set claimed_by = null`, which the nullable FK to `app_user` accepts. The guard `if claimed.id is null` tests whether a row was updated, not whether a person claimed it, so the null claim reads as success.
*Steps:* Call `claim_task(<task uuid>)` with no JWT at all. Probed under `role anon` with no `sub`: the task moves to `claimed` with `claimed_by` null, and the function returns the whole task row, `instructions` included, to the unauthenticated caller. Recovery then fails: `task_own_update` requires `claimed_by = auth.uid()`, and `null = uuid` is null rather than true, so no cellar user can release it. Probed: a cellar user's release attempt leaves the status at `claimed`. Only an admin can clear it.
*Precondition, stated plainly:* the caller needs a task uuid, and `task_read` is `to authenticated`, so `anon` cannot enumerate them. A signed-in custom crush client can: `task_read` is `using (true)` (see R-1-5), so a client reads every task id in the facility and can freeze the entire board one call at a time, which needs no anonymous access at all.
*Resolves when:* the function refuses a null `auth.uid()` before it writes.
*Load-bearing:* yes for the board, which is Stage 2 and unbuilt. The function is written and reachable now.

**R-1-5. Client read-scoping covers `node` alone; thirteen other tables are `using (true)`.**
*Verdict:* EXPLOITABLE *(probed)*
*Locator:* `supabase/migrations/0003_parties_and_products.sql:280-284`; the blanket loop it does not replace at `0002:262-272`.
*What is wrong:* `0003` drops and rewrites exactly one read policy. Every other table keeps the blanket `using (true)` from `0002`, and `party` and `vessel_code` get fresh blanket reads at `0003:236-244`. `node` is also the only table whose rows a client cannot reach by another route: `placement.node_id`, `event.subject_id` and both lineage columns carry node ids in plain sight.
*Steps:* Probed with a client login against a two-lot cellar. `node`: 1 of 2, correctly scoped. `event`: all of them, including the facility lot's chemistry (`{"brix": 22.4}` came back). `placement`: all of them. `task`: all of them. `app_user`, `vessel`, `party`, `vessel_code`, `term`, `template`, `lineage`, `task_claim_log`: all of them. `select count(distinct node_id) from placement` returns 2, which is the number `node_read` just spent a policy hiding.
*How it surfaces:* Silently, never, unless a client goes looking. A custom crush client who does can read every other client's sample chemistry and reconstruct the cellar graph.
*Resolves when:* the tables carrying a client's data are scoped the way `node` is, or the ownership join is made from the subject rather than left to each table.
*Load-bearing:* yes. `0003`'s stated reason for existing is what a client is permitted to see.

**R-1-6. Deactivating a client party widens its read to the whole cellar.**
*Verdict:* EXPLOITABLE *(probed)*
*Locator:* `supabase/migrations/0003_parties_and_products.sql:265-276`, specifically the `coalesce(..., true)` at 272-275.
*What is wrong:* `is_facility_user()` treats "no active party row for this login" as facility, which is correct for the harvest intern (R-1-23) and is reached by two different situations. `party` carries `active`, and the subquery filters on it. Setting `active = false` on a client party makes the subquery return no row, the coalesce returns true, and the login the party was attached to is promoted from scoped to unrestricted.
*Steps:* Probed. Client login sees 1 of 2 lots. `update party set active = false`. Same login now sees 2 of 2. The uniqueness index at `0003:51-52` guarantees one party per login, so there is no second row to fall back to and no way for the function to tell an offboarded client from an intern.
*How it surfaces:* At the end of a custom crush arrangement, which is exactly when someone deactivates the party and exactly when the client should be seeing less rather than more.
*Resolves when:* the absence of a party and the presence of an inactive one are distinguished, rather than both collapsing to true.
*Load-bearing:* yes. Offboarding is the operation this gets wrong.

**R-1-7. `task_own_update` gates which row, never which columns.**
*Verdict:* EXPLOITABLE *(probed)*
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:319-322`.
*What is wrong:* The comment above it says cellar users "may only move a task they hold". The policy says they may update a row they hold. Postgres row policies have no column granularity, so holding a task confers write access to every column of it.
*Steps:* Probed as the assignee: `subject_id`, `operation_id`, `instructions` and `due_to` were all rewritten in one statement, and the `with check` was satisfied throughout because `assignee` was never touched. The task that said "punch down bay 3 twice today" now says something else, about a different lot, with a different operation.
*How it surfaces:* As a task that does not match what was assigned, with `created_from` still pointing at the template step that did not produce it.
*Resolves when:* the movable columns are separated from the rest, by a status-only function or by a trigger refusing changes to the others.
*Load-bearing:* not yet. Tasks are Stage 2 and the policy is written.

**R-1-8. `topping_check` lets the caller name the predicate that judges the pour.**
*Verdict:* EXPLOITABLE *(probed)*
*Locator:* `supabase/migrations/0004_terms_and_effects.sql:422-426` and 440-447.
*What is wrong:* `p_operation uuid default null` lets the caller supply the term whose `predicate.match` array decides which fields are compared. An operation term with no `predicate` yields an empty `fields` array, the `foreach` loop body never executes, and the function returns `(true, 'ok')`. The parameter exists so a cidery can configure the rule; it also lets the pourer choose it per call.
*Steps:* Probed. Chardonnay into a Riesling barrel with the seeded operation returns `ok=f, "variety mismatch: Chardonnay vs Riesling"`. The same two arguments with any predicate-free operation term named as `p_operation` return `ok=t, "ok"`. Every seeded treatment term qualifies; no term has to be created.
*How it surfaces:* Never from the database. `topping_check` reports, it does not refuse: nothing consumes its answer and no constraint depends on it, so a mismatched top is recorded either way.
*Resolves when:* the predicate is resolved from the operation being recorded rather than from an argument, or the argument is constrained to operations that carry one.
*Load-bearing:* not yet. Topping mode is Stage 2 and the first caller has not been written; it will be written against this signature.

**R-1-9. A principal with a token and no `app_user` row writes events, nodes and lineage, unattributably.**
*Verdict:* EXPLOITABLE *(probed)*
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:289-291` and 302-304; `is_facility_user` at `0003:272-275`.
*What is wrong:* This is question 4's principal: signed up through GoTrue, never called `claim_account`. Probed in full.
*Reads:* everything, including all of `node`, because `is_facility_user()` coalesces their missing party to true.
*Writes:* `by_user = auth.uid()` is refused, and the refusal is accidental rather than designed: `event.by_user` is an FK to `app_user` and there is no row, so it fails as `foreign_key_violation`. The `by_sensor` arm has no such FK, so an event with `by_sensor` set and `by_user` null is accepted. Probed: accepted. `node` insert with `created_by` left null: accepted. `lineage` insert: accepted, and closes nothing per R-1-2.
*Refused:* everything gated on `is_admin()`, and `claim_task`, which fails on the same FK.
*What the views do with their rows:* `task_board` left-joins `app_user` on `claimed_by` and `assignee`, so nothing this principal created carries a name. `lot_state` shows their nodes as ordinary lots. `inferred_fraction` counts their events into the trust ratio of whatever they attached them to.
*How it surfaces:* As events with no author in a table whose author column is not read by any screen.
*Resolves when:* write admission requires an `app_user` row rather than a token, at the policy rather than by FK accident.
*Load-bearing:* yes. Whether sign-up is open is a GoTrue setting this repository does not pin.

**R-1-10. `generate_inferred_history` takes an arbitrary `p_from`, so history can be backdated onto any readable lot.**
*Verdict:* EXPLOITABLE *(probed)*
*Locator:* `supabase/migrations/0005_account_and_walk.sql:169-219`, specifically `at_time := p_from` at 201 and the insert at 208-212.
*What is wrong:* The function is invoker-rights, which is correct, and `p_from` defaults to `now()`, which is the intended call. It is also a plain parameter with no bound, and the function takes any `p_node_id` the caller can read. The events it writes carry `by_user = auth.uid()` and pass `event_insert` on the first arm.
*Steps:* Probed as a cellar user against a client-owned lot: one inferred event written and dated 2019-01-02, and `inferred_fraction` for that lot moved to 0.500. The invoker check does bite for a client caller, whose `select * into n from node` is RLS-filtered to nothing and raises `no such node`. For any facility user, who reads everything (R-1-23), it does not bite at all.
*How it surfaces:* As a provenance audit that reports a lot as half-unwitnessed, with the inferred half dated before the winery had the fruit.
*Resolves when:* `p_from` is bounded, or history generation is restricted to the node's creation path rather than callable per node.
*Load-bearing:* not yet, because S-17 means no template matches any variety and every call returns zero until the protocols are encoded. Encoding them is what makes this reachable.

**R-1-11. Every public function is executable by `anon`; no migration revokes anything.**
*Verdict:* EXPLOITABLE *(probed)*
*Locator:* absence, across all five migrations. `grep -rn "revoke" supabase/` returns nothing but prose.
*What is wrong:* PostgreSQL grants `EXECUTE` on a new function to `PUBLIC` by default. Nothing in the tree narrows it. Probed: `anon` may execute 59 of 59 functions in `public`, including all six `security definer` ones: `claim_account`, `claim_task`, `confirm_event`, `current_party_id`, `is_admin`, `is_facility_user`.
*Assessed one by one:* `claim_account` refuses a null `auth.uid()` explicitly at `0005:47-49`. `confirm_event` refuses a non-admin at `0005:140-141`. `is_admin`, `is_facility_user` and `current_party_id` return a harmless answer for a null uid, and `is_facility_user()` returning true for `anon` costs nothing because every policy is `to authenticated` (probed: `anon` sees zero node rows). `claim_task` is the one that does not check, and it is R-1-4.
*How it surfaces:* It does not, until a function is added that assumes a caller. The default is the problem; `claim_task` is the instance.
*Resolves when:* execute is revoked from `public` and granted to the roles each function is for.
*Load-bearing:* yes as a posture. The surface grows with every function added.

**R-1-12. Every authenticated principal reads every vessel photo.**
*Verdict:* EXPLOITABLE
*Locator:* `supabase/migrations/0005_account_and_walk.sql:324-327` and 335-338; the path construction at `packages/core/src/kernel.ts:279-280`.
*What is wrong:* `vessel_photos_read` is `for select to authenticated using (bucket_id = 'vessel-photos')`. The predicate names the bucket and nothing else, so there is no owner term and no relation to `vessel.owner_id` or `node.owner_id`. The comment two lines above at `0005:314` states the exact risk being taken: "A photo of a barrel shows a chalk mark with a client's lot on it." The bucket is private from the public internet and open to every signed-in principal, custom crush clients included. Paths are `${vesselId}/photo.${suffix}` and `vessel` is world-readable, so no enumeration is needed. `vessel_photos_insert` is the same shape, so any authenticated principal can also place an object at any path that is not yet taken.
*How it surfaces:* When a client reads a chalk mark naming another client's lot.
*Resolves when:* the read predicate joins the path's vessel to the reader's party the way `node_read` does.
*Load-bearing:* yes for the confidentiality `0003` exists to provide.
*What was verified and what was not:* the policy text was read at the SHA and contains no owner scoping, which is the finding. The `do $$` block is guarded on the `storage` schema existing and did not execute in my instance, so the policies were not observed in force. Confirming that needs a Supabase instance.

---

## LATENT

**R-1-13. `confirm_event`'s inferred-only rule is a convention; the table's UPDATE path checks nothing.**
*Verdict:* LATENT *(probed)*
*Locator:* `supabase/migrations/0005_account_and_walk.sql:131-155`; `event_admin_update` at `0002:293-295`; the trigger's binding at `0005:123-125`.
*What is wrong:* `refuse_self_granted_standing` is attached `before insert` only. `confirm_event` enforces `where ... and provenance = 'inferred'`, on the stated reasoning that "an observed event was already witnessed and has no confirmation to gain". `event_admin_update` permits the same principal to reach the same column directly with no predicate on the value.
*Steps:* Probed as the admin. `confirm_event` on an `observed` event raises, correctly: "is not an inferred event awaiting confirmation". `update event set provenance = 'confirmed' where id = <same row>` succeeds. Both statements, same session, same role, seconds apart.
*How it surfaces:* Never, as long as the only principal who can do it is the verifier who is meant to. It becomes a defect the moment `confirmed` is read as meaning `confirm_event` ran.
*Reaches it:* any of three changes. A provenance audit view (Stage 3, `docs/status-ledger.md:78`) that treats `confirmed` as evidence of a verification act. A second admin. An update path opened to cellar users for corrections, which CLAUDE.md forbids at line 52 and which is the change most likely to be proposed.
*Load-bearing:* no, today. It is the difference between a boundary and an honour system on the verifier side.

**R-1-14. `node.provenance` has no verifier path at all.**
*Verdict:* LATENT *(probed)*
*Locator:* `supabase/migrations/0005_account_and_walk.sql:119-121`; the column at `0001:178`; `node_admin_update` at `0002:306-308`.
*What is wrong:* The insert trigger is attached to `node` as well as `event`, which implies nodes have a confirmation lifecycle. There is no `confirm_node`. The only route from `observed` to `confirmed` on a node is an unguarded admin `update`, which no trigger sees.
*Steps:* Probed: `update node set provenance = 'confirmed'` as admin, accepted, no trigger fired, no function involved.
*How it surfaces:* Never yet. `lot_state` selects `n.provenance` at `0004:344` and no screen reads it.
*Reaches it:* the first thing that reads `node.provenance` and means something by it.
*Load-bearing:* no. Naming it matters because the insert trigger reads as though the other half exists.

**R-1-15. Composition functions run as invoker, so a client's composition silently truncates.**
*Verdict:* LATENT
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:29-46`, 48-59, 61-71.
*What is wrong:* `node_bin_shares` is a plain SQL function, so `node_read` applies inside it. The recursive CTE walks `lineage`, which is world-readable, then joins `node` to keep the bins. For a client caller, a bin the policy hides contributes no row to the join and no error. `block_composition` and `variety_composition` are built on it and inherit the behaviour, and the shares they return no longer sum to one.
*How it surfaces:* As a composition that is quietly short. `block_composition` returns fewer rows rather than raising, and nothing in the return shape says a row was withheld.
*Reaches it:* the first client-facing screen that calls a composition function, or the first blend that crosses an ownership line.
*Load-bearing:* no today, because nothing calls these functions yet. Yes the moment something does, because T0-2's argument for deriving is that a derived value cannot drift, and a value that depends on the reader has drifted.

---

## DIVERGENT

**R-1-16. The producer chooses between `observed` and `inferred`; the adopted pattern says the verifier recomputes.**
*Verdict:* DIVERGENT *(probed)*
*Locator:* `supabase/migrations/0005_account_and_walk.sql:105-117` against `packages/cellar/docs/spec.md:214-218` and `CLAUDE.md:46-48`.
*What is wrong:* The spec describes the adopted boundary as one where the verifier "recomputes trust fields, discarding any the agent asserted". The implementation refuses one enum value at insert and accepts the other two as sent. Probed: a cellar user wrote `observed` on a fabricated press, and `inferred` on another, both accepted; `confirmed` raised.
*How it surfaces:* As a `sample` the app shows with an `observed` tag, from a producer, unwitnessed.
*Resolves when:* either the code recomputes rather than refusing, or the spec and CLAUDE.md say that the boundary covers promotion to `confirmed` and that `observed` is producer-asserted. Which of the two should move is not this report's call.
*Load-bearing:* yes. It is the axiom the prompt is named after and the one three documents cite.

**R-1-17. `0002` says cellar users rack; racking needs an UPDATE they cannot perform.**
*Verdict:* DIVERGENT *(probed)*
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:297-298` against `placement_admin_update` at 306-308; the occupancy index at `0001:241-242`.
*What is wrong:* The comment says "cellar users create these through the press and rack screens, so inserts are open". A rack is two operations: close the old placement by setting `to_at`, and insert the new one. `to_at` is only reachable by UPDATE and UPDATE is admin-only. The unique index then refuses the new placement while the old one is open, so the insert half fails too.
*Steps:* Probed. A cellar user's `update placement set to_at = now()` matched 0 rows and raised nothing. A rack by a cellar user cannot complete, and the first half of it fails silently.
*How it surfaces:* When the rack screen is built, as a save that reports success and changes nothing.
*Resolves when:* either the policy admits closing a placement, or the comment and the rack design say an admin racks.
*Load-bearing:* yes for Stage 1. Racking is `rack` at `0004:156` and a movement effect in the kernel's four.

**R-1-18. S-7 says "treat the policies as correct"; 22 of 28 assertions never enter the `authenticated` role.**
*Verdict:* DIVERGENT *(probed)*
*Locator:* `docs/sorry-ledger.md:54-65`, especially 65; `tests/schema_assertions.sql:354, 386, 393, 396`.
*What is wrong:* S-7 correctly names the `sub`-claim gap. It is not the whole gap. `set local role authenticated` appears twice in the file, and only 6 of the 28 `test_ok` calls sit inside those two blocks. The other 22 run as the table owner, for whom RLS does not apply. They are still good assertions: they prove triggers, check constraints, foreign keys and function bodies, and a `before insert` trigger is role-blind so R-1-27 stands on them. They prove nothing about admission.
*Which half is which, per the prompt's instruction:* proven by assertion are the T0-4 insert trigger, the operation-effect constraint, the one-facility index, the composite term FK, `claim_account`'s first-account rule and idempotence, `bind_vessel_code`'s idempotence and refusal, `create_vessel_with_wine`'s atomicity, `generate_inferred_history`'s stamping, and `confirm_event`'s admin guard. Proven under a policy are exactly six things: three admin-write refusals, one event insert, one intern read, one client read. Everything in the EXPLOITABLE section above is outside both sets.
*How it surfaces:* As `docs/status-ledger.md:39` grading RLS "In progress" on a basis narrower than it reads, and S-7's closing line advising that the policies be treated as correct.
*Resolves when:* S-7 distinguishes the claim gap from the role-coverage gap, and says which policies have been exercised rather than which file exercises policies.
*Load-bearing:* yes. This ledger is the repository's account of what it knows, and CLAUDE.md:11-12 makes it the single source of build truth.

**R-1-19. "A client is not told how many others exist" is not what the schema does.**
*Verdict:* DIVERGENT *(probed)*
*Locator:* `supabase/migrations/0003_parties_and_products.sql:278-279` against the finding at R-1-5.
*What is wrong:* The comment states an outcome the policy below it cannot produce alone, because the count is available from `placement`, from `event`, from `lineage`, and from `party` itself, all world-readable.
*How it surfaces:* As a comment a later reader trusts. It is the kind of statement that stops the next person from checking.
*Resolves when:* the comment describes the one policy it sits above, or the other tables are scoped so the comment becomes true.
*Load-bearing:* yes, as the reason R-1-5 is likely to go unnoticed.

**R-1-20. CLAUDE.md's definition of done names a script that does not exist.**
*Verdict:* DIVERGENT
*Locator:* `CLAUDE.md:81-93` against `package.json:10-19`.
*What is wrong:* The block lists `bun run test`. `package.json` defines `typecheck`, `lint`, `format`, `db:reset`, `doctor`, `db:test`, `dev`, `build`. There is no `test`. The block also spells the schema run as `psql < tests/schema_assertions.sql`, which drops the `ON_ERROR_STOP` that `db:test` sets and that the file's own header at `tests/schema_assertions.sql:20` requires; without it a failing assertion does not stop the run.
*Note on `doctor`:* `package.json:15` is an honest stub that prints its own reason and exits 1, so the definition of done is unreachable by construction while S-4 is open. That is consistent with the ledger and is not a defect.
*How it surfaces:* The first time someone runs the block top to bottom.
*Resolves when:* the commands in CLAUDE.md and the scripts in `package.json` are the same set.
*Load-bearing:* no.

**R-1-21. The walk offers admin-only actions to a cellar user with no role check.**
*Verdict:* DIVERGENT
*Locator:* `packages/cellar/src/walk.ts:249-252`; the only role check in the file at `walk.ts:200`; the comment at `supabase/migrations/0004_terms_and_effects.sql:513-516`.
*What is wrong:* `0004`'s comment says the inventory walk "needs an admin, which the walk is". `homeScreen` renders "Add a vessel and put wine in it", "Add an empty vessel" and "Add a location" unconditionally; `user.role` is read once in the whole module, for the facility screen. A cellar user reaches the form, fills it in, and gets a raw PostgREST permission message through `fail()`.
*How it surfaces:* As a cellar user filling in eleven fields in a barrel room and being refused at save.
*Resolves when:* either the home screen gates on role the way `facilityScreen` does, or the comment stops asserting that the walk is admin.
*Load-bearing:* no. The database refuses correctly, which is the part that matters; this is the UI disagreeing with a comment about it.

**R-1-22. A photo is uploaded before the transaction that would justify it.**
*Verdict:* LATENT
*Locator:* `packages/cellar/src/walk.ts:517-519` and 630-632.
*What is wrong:* Both save paths call `uploadVesselPhoto` and then the write that may be refused. A cellar user hitting R-1-21's refusal, or any failed transaction, leaves an object at `${vesselId}/photo.jpg` for a vessel that does not exist. No DELETE policy is created on `storage.objects` at `0005:307-339`, so nothing can remove it.
*How it surfaces:* As bucket growth nobody can account for, and as a path collision if the same client-generated uuid is retried.
*Reaches it:* the first refused or failed save with a photo attached, which R-1-21 makes likely rather than rare.
*Load-bearing:* no.

---

## BY DESIGN

**R-1-23. A principal linked to no party sees the whole cellar.**
*Verdict:* BY DESIGN
*Locator:* named at `supabase/migrations/0003_parties_and_products.sql:262-264`, asserted at `tests/schema_assertions.sql:382-384`, recorded at `docs/sorry-ledger.md:56-59`.
*What is wrong:* Nothing. The harvest intern owns nothing and needs to see everything, and the coalesce is the deliberate mechanism. It is listed here because it is the same line of code as R-1-6 and the two cases must be separated by anything that fixes one. It is also the reason R-1-10 reaches any lot.
*Load-bearing:* yes as context for R-1-6.

---

## NOT A DEFECT

Checked, and they hold. One line each, per the closing instruction.

**R-1-24.** `create_vessel_with_wine` is invoker-rights and the comment at `0005:230-231` is accurate: probed as a cellar user, the call was refused at the first insert by `vessel`'s own policy, so composing four writes into one transaction granted nothing.

**R-1-25.** All six `security definer` functions pin `set search_path = public` (`0001:100, 339`; `0003:257, 270`; `0005:41, 135`), which is the pinning question 2 asks about, and none of them takes a schema-qualifiable identifier from a caller.

**R-1-26.** All four views carry `security_invoker = true` (`0003:138, 181, 182`; `0004:271, 329, 358`), including `vessel_state` after both of its rebuilds, so the one route that would have handed a client every lot regardless of `node_read` is closed.

**R-1-27.** The T0-4 insert trigger refuses `confirmed` for every role, not only for the owner the assertions run as, because a `before insert` trigger is role-blind: probed as `authenticated`, refused with `insufficient_privilege`.

**R-1-28.** `event` has no DELETE policy at all, so no principal including an admin can delete an event through PostgREST, which is T0-5's append-only half enforced as a boundary rather than a rule.

---

## UNVERIFIED

Named with what would check each, per the closing instruction. No verdict was reasoned onto any of these.

**Supabase's auth plumbing.** My shim wrote `auth.uid()` myself. GoTrue minting a JWT, PostgREST mapping it to `authenticated` and setting `request.jwt.claim.sub`, and the role a PostgREST RPC actually runs under are untested here as they are in the repository's assertions. *Checks it:* the walk run against a real Supabase project with two real accounts. This is the remainder of S-7 and R-1-18 does not shrink it.

**Whether `claim_task` is reachable over HTTP by `anon`.** The database-level grant was probed and is present (R-1-11). Whether PostgREST exposes it to a caller holding only the publishable anon key depends on the project's exposed schema and role configuration. *Checks it:* an unauthenticated `POST /rest/v1/rpc/claim_task` against a real project.

**Realtime fan-out.** `task`, `event` and `placement` are added to `supabase_realtime` at `0002:332-334`. Whether Supabase Realtime evaluates `node_read` and the blanket read policies per subscriber, and therefore whether a client login receives change payloads for another party's lots, is a property of the Realtime server and not of these migrations. Given R-1-5 the payloads may be readable anyway, which is a reason to check rather than to skip it. *Checks it:* two authenticated subscriptions against a real project, one facility and one client.

**The storage bucket in force.** The guarded block at `0005:307-339` did not execute in a database with no `storage` schema, so R-1-12 rests on reading the policy text. *Checks it:* the same two accounts against a real project's bucket.

**Camera capture.** `packages/cellar/src/scan.ts` and the zxing path have never met a camera; the status ledger says so at line 57. *Checks it:* a phone in a barrel room.

**Whether any of this reaches real data.** Nothing is deployed and `docs/status-ledger.md:12` says so. Every EXPLOITABLE finding above is exploitable against the schema as written, not against a running winery.

---

## Closing

The parts that are sound are sound for a reason and the reason is visible in the code: invoker-rights on the composing function, `security_invoker` on all four views, `search_path` pinned on all six definer functions, no DELETE on `event`, and an insert trigger that genuinely cannot be talked past. That set is not an accident and it is worth saying in one line.

The pattern in what fails is narrower than a list of twelve suggests. Three shapes produce almost all of it. A disjunction whose second arm dissolves the first (`event_insert`, `is_facility_user`). A check that is `true`, which is the absence of a check written in the syntax of one (`node`, `lineage`, `placement`). And a rule placed in a function while the table underneath it stays open, so the rule holds exactly as long as everyone uses the function (`confirm_event`, `claim_task`, `topping_check`).

The prompt's question was whether T0-4 is a boundary or a rule. It is a boundary for one value of three, and the two it leaves to the producer include the one T0-3 says must stay distinguishable. That is the honest answer and it is narrower than either `CLAUDE.md:46-48` or `packages/cellar/docs/spec.md:214-218` currently claims.

The finding that will cost the most is not one of those. It is R-1-2: the same press, by two different people, leaves the database in two different structural states, and the one that leaves it wrong raises nothing. That is a bin still open after it was pressed, discovered weeks later, during the one part of the year the build order at `packages/cellar/docs/spec.md:249-257` is arranged around because its failures cannot be reconstructed.
