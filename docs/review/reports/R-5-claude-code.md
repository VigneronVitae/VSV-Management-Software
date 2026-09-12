# R-5: append-only history and derived over stored

**Target:** github.com/VigneronVitae/VSV-Management-Software
**Reviewed:** 2026-09-11
**Verdict in one line:** history is append-only for cellar users and fully rewritable by an admin with no trace, and the correction path the whole design rests on does not exist.

---

## Report header

**1. Tier: A.** Full tree on disk. `git clone https://github.com/VigneronVitae/VSV-Management-Software` over the Bash tool, first route, no fallback needed. All locators below are `path:line` against that tree.

**2. Commit.** `git rev-parse HEAD` returned verbatim:

```
c3eae3c7c262544e4b2e29526b513c964c6852fe
```

This is the baseline exactly, not a descendant. Subject line: "File the walk session report, and correct the reverse dependency edges."

**3. Canaries.** All present and correct.

| Canary | Result |
|---|---|
| Branch is `main`, not `claude/sql-files-to-markdown-i31rob` | `* main`, tracking `origin/main` |
| Tree is not the `LICENSE`-only pre-merge `main` | 42 tracked files |
| `supabase/migrations/0005_account_and_walk.sql` | present, 340 lines |
| `tests/schema_assertions.sql` | present, 412 lines |
| `packages/cellar/src/walk.ts` | present, 805 lines |
| `docs/session-reports/2026-09-08-walk.md` | present |
| Tracked file count | 42 |

**4. File table.** Whole tree on disk; every file below was read in full, and the whole tree was available for the greps cited.

| Path | State | Lines |
|---|---|---|
| `supabase/migrations/0001_core_schema.sql` | whole | 370 |
| `supabase/migrations/0002_derived_and_rls.sql` | whole | 334 |
| `supabase/migrations/0003_parties_and_products.sql` | whole | 284 |
| `supabase/migrations/0004_terms_and_effects.sql` | whole | 519 |
| `supabase/migrations/0005_account_and_walk.sql` | whole | 340 |
| `tests/schema_assertions.sql` | whole | 412 |
| `docs/compost-ledger.md` | whole | 72 |
| `docs/sorry-ledger.md` | whole | 156 |
| `docs/status-ledger.md` | whole | 112 |
| `CLAUDE.md` | whole | 130 |
| `packages/cellar/docs/spec.md` | whole | 328 |
| `packages/cellar/src/walk.ts` | whole | 805 |
| `packages/core/src/kernel.ts` | whole | read for the volume path |

The minimum corpus is covered, plus `0003`, `0005`, `compost-ledger.md`, and the TypeScript write path, so C-3 and the topping question are both reviewed at full scope.

### Execution numbers

The schema was executed, not read. Postgres 16.13 on this machine, fresh cluster, shim built to the prompt's spec: an `auth` schema with a `users` table; `auth.uid()` reading `request.jwt.claim.sub` first and falling back to the `request.jwt.claims` blob; roles `anon`, `authenticated`, `service_role` with Supabase's default `public` grants; an empty `supabase_realtime` publication; no `storage` schema.

| Number | Result |
|---|---|
| All five migrations applied clean | **Yes.** 0001 through 0005, `ON_ERROR_STOP=1`, exit 0 each. |
| Assertions in `tests/schema_assertions.sql` | **28 ran, 28 passed.** Terminated on `--- all assertions passed`, exit 0. |
| Storage-guarded block executed | **No, skipped.** `NOTICE: storage schema absent, skipping the vessel-photos bucket` at `0005_account_and_walk.sql:340`. |

That third number is the one two earlier reports in this series disagreed on. This shim has no `storage` schema, the guard at `0005:332` caught it, and the block did nothing. Any report claiming a different assertion count for `c3eae3c` is running a shim that stood up `storage`.

Probes ran under `set local role authenticated` with `request.jwt.claim.sub` set to a real `app_user` id, and under `set local role anon` with no claim. Five principals: an admin, a cellar user, a custom crush client with a `party` row, an authenticated principal with no `app_user` row, and `anon`. Nothing below labelled *probed* was reasoned to.

### Falsified predictions

Three, disclosed because they are the evidence the probes were real.

**First.** My initial role-by-statement matrix reported that an admin could delete a `node` that is a lineage parent (`OK rows=1`). That was wrong, and it was wrong because my harness was wrong: each probe ran in a subtransaction that committed on success, so the earlier `lineage DELETE` cell had already removed the referencing edge by the time the `node DELETE` cell ran. Rebuilt so every cell always rolls back, the same statement raises `23503` on `lineage_parent_id_fkey`. `ON DELETE RESTRICT` at `0001_core_schema.sql:196-197` does hold. The corrected result is R-5-10: the deletion path is two statements, not one.

**Second.** I expected deleting a row from `auth.users` to cascade history away, since `app_user.id` carries `on delete cascade` at `0001_core_schema.sql:88`. It does not. The delete raises `23503` on `node_created_by_fkey`, because `node.created_by` is `NO ACTION`. Account deletion is blocked rather than destructive. That is still a defect, and a different one, recorded as R-5-11.

**Third.** I expected a custom crush client whose `party.app_user_id` was nulled to be blinded, seeing none of its own wine. The probe showed the opposite: `is_facility_user()` coalesces a missing party to `true`, so the client is promoted to facility staff and the visible node count went from 1 to 4 of 4. Recorded as R-5-12, with the severity moved from confidentiality-neutral to a confidentiality breach.

---

## Finding table

| id | Verdict | One line |
|---|---|---|
| R-5-1 | EXPLOITABLE | `close_parent_on_lineage()` runs as invoker, so a press by a cellar user leaves the parent open and the same press by an admin closes it |
| R-5-2 | EXPLOITABLE | An admin rewrites any field of any event, `at` and `by_user` included, and nothing records that it happened |
| R-5-3 | EXPLOITABLE | A plain UPDATE reaches `provenance = 'confirmed'` on an observed event, the transition `confirm_event()` exists to refuse |
| R-5-4 | EXPLOITABLE | `node.quantity` and `placement.volume_l` are two stored volumes for the same wine, written from one input, with nothing linking them |
| R-5-5 | EXPLOITABLE | The correction path does not exist: no schema object reads `event.data`, so a correcting event changes no number anywhere |
| R-5-6 | EXPLOITABLE | Deleting one lineage edge silently de-normalizes `block_composition`, which returns 0.4 and reports nothing |
| R-5-7 | EXPLOITABLE | `task_claim_log` rows are deletable by cascade from `task` although no delete policy on that table exists for anyone |
| R-5-8 | EXPLOITABLE | Every RLS denial is a silent zero-row match, so a refused correction is indistinguishable from an applied one |
| R-5-9 | EXPLOITABLE | `node.status` and `closed_at` are stored derivations of lineage with no recompute and no staleness detection |
| R-5-10 | EXPLOITABLE | `ON DELETE RESTRICT` on lineage is a speed bump: delete the edge, then the node, both statements policy-permitted |
| R-5-11 | LATENT | Deleting a Supabase account fails for any user who ever created a node |
| R-5-12 | LATENT | `party.app_user_id` is `SET NULL`, and an unlinked client is then treated as facility staff and sees the whole cellar |
| R-5-13 | DIVERGENT | S-1 says the topping threshold is unchosen; the code has chosen it, at 100%, silently |
| R-5-14 | DIVERGENT | The sorry ledger's Discharged section reads "Nothing has been built" against five applied migrations and a passing test suite |
| R-5-15 | NOT A DEFECT | `event` has no delete policy, so no authenticated role can delete an event by any direct path |
| R-5-16 | NOT A DEFECT | Composition is genuinely functions over lineage, with no cached column anywhere. C-3 stayed dead at the level C-3 was about |
| R-5-17 | UNVERIFIED | Supabase's JWT-to-role mapping, which is the half of S-7 the assertions assume |
| R-5-18 | UNVERIFIED | How PostgREST surfaces a zero-row RLS denial to the phone |

---

## EXPLOITABLE

**R-5-1. `close_parent_on_lineage()` runs as the invoker and is filtered by the node update policy, so the same press produces two different records depending on who was holding the phone.**
*Verdict:* EXPLOITABLE. Probed, and this confirms the prior report in this series.
*Locator:* `supabase/migrations/0001_core_schema.sql:207-223`; `supabase/migrations/0002_derived_and_rls.sql:300-313`.
*What is wrong:* The trigger function is declared `language plpgsql` with no `security definer` (`pg_proc.prosecdef` is `f`, probed), so its `update node set status = 'closed'` executes with the inserting role's privileges and is filtered by `node_admin_update`, whose `using` clause is `is_admin()`. A cellar user may insert the lineage edge, because `lineage_insert` is `with check (true)`, but the parent update inside the trigger matches zero rows. The close should either happen for every writer or for none.
*How it surfaces:* Probed directly. Identical fixture, identical edge, only the JWT subject differs. Cellar user inserts the edge: parent `probe parent cellar` is `status = open`, `closed_at` null. Admin inserts the edge: parent `probe parent admin` is `status = closed`, `closed_at` set. No error either way. In the cellar the effect is that pressed bins stay on the open-lots screen after a press recorded by the person who did the press, and vanish from it after a press recorded by the winemaker. Nobody will connect that to who tapped the button.
*Resolves when:* the trigger function is `security definer`, or the close moves to a `security definer` function the write path calls, or the node update policy admits the trigger's write.
*Load-bearing:* Yes. A cellar user is exactly who records a press, so the failing case is the normal case and the working case is the exception.

**R-5-2. An admin rewrites any field of any event, and nothing anywhere records that it happened.**
*Verdict:* EXPLOITABLE. Probed.
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:293-295`; `supabase/migrations/0001_core_schema.sql:250-268`.
*What is wrong:* `event_admin_update` grants `for update` on `event` to any admin with no column restriction. Probed as admin, all four of these returned `rows=1`: rewriting `data`, backdating `at` by thirty days, reassigning `by_user` to a different person, and changing `provenance`. The `event` table carries no `updated_at`, no revision column, no superseding pointer, and no update trigger; a query of `information_schema.columns` for anything matching `updated|edited|revis|version|superseded|corrects|voided` on `event`, `lineage` and `placement` returned zero rows.
*How it surfaces:* Silently, never. That is the finding. An admin who backdates a sample event and reassigns its author produces a row indistinguishable, by any means the database offers, from an event that always said that. Question 2 of this prompt asks whether an admin update is distinguishable after the fact from the event having always said so. The answer is no, and there is no residue to find.
*Resolves when:* either `event_admin_update` is dropped so that corrections really are new events, or the update path writes a superseding row and the original becomes unreachable rather than overwritten.
*Load-bearing:* Yes. `spec.md:56-57` states T0-5 as "A record that can be silently rewritten is not a record." This is that record, and this is that rewrite.

**R-5-3. A plain UPDATE reaches `provenance = 'confirmed'` on an observed event, which is exactly the transition `confirm_event()` was written to refuse.**
*Verdict:* EXPLOITABLE. Probed.
*Locator:* `supabase/migrations/0005_account_and_walk.sql:104-125` and `:131-155`; `supabase/migrations/0002_derived_and_rls.sql:293-295`.
*What is wrong:* `refuse_self_granted_standing()` is wired as `event_no_self_confirm`, a **before insert** trigger. Probed: `pg_trigger` shows one non-internal trigger on `event`, firing on INSERT only. Nothing guards UPDATE. `confirm_event()` is careful, requires `is_admin()`, and narrows its own `update` to `provenance = 'inferred'` so that an observed event has no confirmation to gain. Probed, it refuses correctly: `ERROR: event ... is not an inferred event awaiting confirmation`. The plain UPDATE immediately afterwards, same role, same event, moved `observed` to `confirmed` and returned `rows=1`.
*How it surfaces:* An admin who recorded their own observation can stamp it confirmed, which is the precise shape of T0-4, "a producer cannot grant itself standing." It also lets any admin update lift `inferred` to `confirmed` in bulk without the per-event act `confirm_event()` models. `inferred_fraction()` at `0002:75-91` then reports a lower unwitnessed fraction than the history justifies, and every downstream cost and yield number inherits that.
*Resolves when:* the `refuse_self_granted_standing` trigger also fires `before update`, or `event_admin_update` excludes the `provenance` column.
*Load-bearing:* Yes. `CLAUDE.md:45-48` calls T0-4 "not negotiable for convenience", and the axiom is enforced on exactly one of the two paths that reach the column.

**R-5-4. `node.quantity` and `placement.volume_l` are two stored volumes for the same wine, written from a single input, with no constraint linking them.**
*Verdict:* EXPLOITABLE. Probed.
*Locator:* `supabase/migrations/0001_core_schema.sql:172-173` and `:233`; `supabase/migrations/0005_account_and_walk.sql:262-278`; `packages/cellar/src/walk.ts:642` and `:644`; `docs/compost-ledger.md`, entry C-3.
*What is wrong:* The walk screen reads one field and sends it twice. `walk.ts:642` writes `quantity: volume.value()` into the node payload and `walk.ts:644` writes `volumeL: volume.value()` for the placement; `create_vessel_with_wine` stores the first at `0005:271` and the second at `0005:278`. Two columns then hold the same fact with nothing reconciling them. A probe for check constraints on `node` or `placement` mentioning both `quantity` and `volume` returned zero.
*How it surfaces:* Probed end to end. Starting state, both 400. An admin corrects the placement to 380, which is the only correction path that exists (R-5-5). Afterwards `placement.volume_l` is 380, `lot_state.total_volume_l` is 380, and `node.quantity` is still 400. The vessel page and the lot page now disagree about the same barrel, and nothing flags it. C-3 killed a `blocks` column because "two sources of truth diverge the first time a volume is corrected." That is verbatim what was just probed, on a different pair of columns, and this pair was never named in the compost ledger.
*Resolves when:* one of the two becomes the source and the other becomes a function or is dropped, or a constraint ties them.
*Load-bearing:* Yes. Every volume the app can show comes from one of these two columns, and which one depends on which screen you are looking at.

**R-5-5. The correction path does not exist. Nothing in the schema reads `event.data`, so a correcting event is inert.**
*Verdict:* EXPLOITABLE. Probed.
*Locator:* `supabase/migrations/0001_core_schema.sql:258-259`; `supabase/migrations/0002_derived_and_rls.sql:118-150`; `supabase/migrations/0004_terms_and_effects.sql:299` and `:346`.
*What is wrong:* This is question 4 of the prompt walked in full, and the honest answer is that the path is absent. A probe of `pg_proc` across the `public` schema for any function body matching `data\s*->` returned **zero objects**. A grep of `supabase/` for `data ->>` returned nothing. `event.data` is written by every screen, documented at `0001:258` as carrying `volume_l`, and read by no view, no function, and no policy.
*How it surfaces:* Probed as the prompt specifies. A cellar user records 400 litres and it was 380. Before: `node.quantity` 400, `placement.volume_l` 400, `lot_state.total_volume_l` 400, `vessel_state.current_volume_l` 400, `event.data->>'volume_l'` 400. The cellar user does the sanctioned thing and inserts a new event carrying `{"volume_l": 380, "corrects": ...}`. It is accepted. The lot now has three events. After: every one of those four numbers is still 400. The cellar user's `update placement` and `update node` both match zero rows and raise nothing. Block composition is 0.6 Perlstaad / 0.4 Eola before and after, correctly, because lineage fractions are not what changed. The only statement in the system that makes the record say 380 is an admin `update placement`, which succeeded, and afterwards nothing in the database records that it was ever 400.
*Resolves when:* either volume becomes derived from the event stream so that a correcting event is the correction, or the append-only claim for volumes is withdrawn and the admin overwrite is named as the mechanism.
*Load-bearing:* Yes. "Corrections are new events" appears in `CLAUDE.md:52`, `spec.md:56`, `0001:26-27` and C-3's kill reason. For volume, which is the example every one of those four uses, it is not true.

**R-5-6. Deleting one lineage edge silently de-normalizes `block_composition`, which then returns shares summing to 0.4 and says nothing about it.**
*Verdict:* EXPLOITABLE. Probed.
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:29-59`; `supabase/migrations/0002_derived_and_rls.sql:309-311`.
*What is wrong:* `lineage_admin_delete` lets an admin remove a lineage row. `node_bin_shares()` walks up from the node and sums whatever paths it finds, with no assertion that the result reaches 1. With both edges present, probed, composition sums to 1.0000. Delete the Perlstaad edge and it sums to 0.4000: the lot reports as 40% Eola Springs and 60% nothing. The function returns successfully.
*How it surfaces:* Anywhere composition is used for a label or a TTB figure. A wine reported as 40% Eola Springs with no statement of what the other 60% is will read, to a downstream consumer, as a wine that is 40% of something and mostly unassigned, or worse, will be renormalized by whoever consumes it into 100% Eola Springs. The failure is silent at the database and only becomes visible to a person who happens to add the shares up.
*Resolves when:* the composition functions report their own total, or refuse to return a set that does not sum to 1 for a node with any lineage at all.
*Load-bearing:* Yes. Block and variety composition are what the appellation and varietal statements on a label are built from.

**R-5-7. `task_claim_log` history is deletable by cascade from `task`, though the table has no delete policy for anyone.**
*Verdict:* EXPLOITABLE. Probed.
*Locator:* `supabase/migrations/0001_core_schema.sql:364-370`; `supabase/migrations/0002_derived_and_rls.sql:324-325`.
*What is wrong:* This is the cascade the prompt warns does not look like a write path. `task_claim_log.task_id` carries `on delete cascade`. A query of `pg_policies` confirms the table has exactly two policies, `task_claim_log_read` and `claim_log_insert`, and no DELETE policy at all, so a direct `delete from task_claim_log` matches zero rows for every one of the five principals probed, admin included. Cascades do not consult RLS. Probed: as admin, one `delete from task` took `task_claim_log` from one row to zero.
*How it surfaces:* `0001:362-363` says a task claimed at 8am and released at 4pm is different from one nobody touched, which is the reason the log exists. Deleting the task erases that difference, and the person deleting the task has no indication that a second table was emptied. The equivalent cascade reaches `vessel_code` from `vessel` (`0003:117`) and `template_step` from `template` (`0001:292`).
*Resolves when:* the cascade becomes `restrict`, or the log carries the task's identity rather than a foreign key to it.
*Load-bearing:* No for the app's core record, since claim history drives nothing downstream, but yes for the append-only claim as stated, because it is a history table that a policy protects and a foreign key does not.

**R-5-8. Every RLS denial is a silent zero-row match, so a refused correction is indistinguishable from an applied one.**
*Verdict:* EXPLOITABLE. Probed.
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:300-313` and `:289-295`.
*What is wrong:* The prompt asks whether a denied statement raises or silently matches zero rows, because those are different defects. Across an eighteen-statement by five-principal matrix, the answer is uniform: **nothing raises.** Every denial came back `OK rows=0`. That is correct Postgres behaviour, since a `using` clause filters rather than rejects, and it is the wrong behaviour for this application. A `with check` violation would raise `42501`; a `using` violation cannot.
*How it surfaces:* A cellar user on a phone taps to correct a volume. The `update` returns success with zero rows affected. Whatever the client does with that, it did not get an error, and `walk.ts` has no zero-row branch. The user has every reason to believe the correction landed. This is the mechanism that makes R-5-5 dangerous rather than merely incomplete: the sanctioned correction does nothing and the unsanctioned one reports nothing.
*Resolves when:* the write paths go through functions that check affected rows and raise, or the client treats a zero-row write as a failure.
*Load-bearing:* Yes. It converts three separate findings from "does not work" into "does not work and says it did."

**R-5-9. `node.status` and `node.closed_at` are stored derivations of lineage, with no recompute path and nothing that detects staleness.**
*Verdict:* EXPLOITABLE. Probed.
*Locator:* `supabase/migrations/0001_core_schema.sql:162`, `:180`, `:207-223`.
*What is wrong:* `0001:205` states the rule as "a node that has fed something is spent", which makes closure a function of whether any lineage row names the node as parent. It is stored instead, computed once by an after-insert trigger. Probed: `pg_trigger` carries no delete trigger on `lineage`. Delete the only edge out of a closed parent and the parent stays `closed` with `closed_at` set, forever. A probe counting nodes that are closed with no lineage edge found one, and nothing in the schema runs that query.
*How it surfaces:* A lot disappears from `lot_state` (which filters `status <> 'closed'` at `0002:150`) and never comes back, or a lot that should be closed stays open because of R-5-1. Both are the same defect: the status column and the lineage it is supposed to summarize can differ, and only lineage is authoritative. C-3 forbids storing what is derivable from lineage; `status` is derivable from lineage and is stored.
*Resolves when:* `status` becomes a function over lineage, or a delete trigger restores it, or the divergence is reported by `doctor`.
*Load-bearing:* Yes. `status` gates the open-lots screen, which is what the cellar works from.

**R-5-10. `ON DELETE RESTRICT` on lineage is a speed bump, not a boundary: delete the edge, then the node, both statements policy-permitted.**
*Verdict:* EXPLOITABLE. Probed. This is the corrected form of my first falsified prediction.
*Locator:* `supabase/migrations/0001_core_schema.sql:196-197`, `:230-231`; `supabase/migrations/0002_derived_and_rls.sql:309-311`.
*What is wrong:* `lineage.parent_id` and `child_id` are both `on delete restrict`, and probed, they hold: a single `delete from node` on a lineage parent raises `23503` for an admin and even for the table owner. But `lineage_admin_delete` and `node_admin_delete` are both granted to admins, so the two-statement sequence succeeds. Probed: `delete from lineage where parent_id = ...; delete from node where id = ...` returned `rows=1`. Once the node is gone, so is every record that the bin existed, and the child's composition silently changes as in R-5-6.
*How it surfaces:* Not by accident. This needs an admin who intends it. The finding is that the schema offers no resistance beyond ordering, and leaves nothing behind, so the state after is not distinguishable from a bin that was never recorded.
*Resolves when:* `node_admin_delete` and `lineage_admin_delete` are dropped in favour of a soft-delete, or deletion of a node with any history is refused outright.
*Load-bearing:* Yes. It is the complete answer to question 1 for the delete direction: the only thing standing between an admin and a rewritten history is one extra statement.

---

## LATENT

**R-5-11. Deleting a Supabase account fails outright for any user who ever created a node.**
*Verdict:* LATENT. Probed, and this is my second falsified prediction.
*Locator:* `supabase/migrations/0001_core_schema.sql:88`, `:183`, `:255`.
*What is wrong:* I predicted the `on delete cascade` from `app_user` to `auth.users` would cascade history away. It does not. `node.created_by` and `event.by_user` reference `app_user(id)` with no `on delete` clause, so both default to `NO ACTION`. Probed: deleting the cellar user's `auth.users` row raised `23503` on `node_created_by_fkey` and rolled the whole delete back. The account cannot be removed. The same probe on the client user, who authored nothing, succeeded.
*How it surfaces:* Not yet. It surfaces the first time someone leaves the winery and an admin tries to remove their account in the Supabase dashboard, which returns an opaque foreign-key error naming a table the dashboard does not show. At five to ten users over a decade this is a handful of occurrences, which is why it is LATENT rather than EXPLOITABLE.
*Resolves when:* `app_user.active = false` is established as the deactivation path and account deletion is documented as unsupported, or the two references become `set null` and events keep their authorship some other way.
*Load-bearing:* No. It fails loudly, which is the right direction for this kind of defect. Recorded because the cascade inventory question asked for it and because my expectation was the opposite.

**R-5-12. `party.app_user_id` is `SET NULL`, and a client whose link is nulled is then treated as facility staff and sees every lot in the cellar.**
*Verdict:* LATENT. Probed.
*Locator:* `supabase/migrations/0003_parties_and_products.sql:44`; `:253-259`; `:265-277`; `:281-283`.
*What is wrong:* `party.app_user_id references app_user(id) on delete set null`. `current_party_id()` resolves a login to a party through that column, and `node_read` admits a client via `is_facility_user() or owner_id = current_party_id()`. The first disjunct is the problem: `is_facility_user()` coalesces a missing party row to `true`, because the case it was written for is the harvest intern who owns nothing and needs to see everything. A client whose party link has been nulled is indistinguishable from that intern.
*How it surfaces:* Probed. Baseline, the client login sees 1 node, its own lot, which is what `tests/schema_assertions.sql:408` asserts. Null the `app_user_id` on the Amica Luna party and log in again as the same account: `is_facility_user()` returns `t`, `current_party_id()` returns null, and the client sees **4 of 4 nodes**, the entire cellar including the facility's own lots. I had predicted this would blind the client rather than widen them; the probe showed the opposite and this is the corrected result. The trigger in practice is deleting the `auth.users` row of an admin or staff member, since `party.app_user_id` is nulled by any delete of the referenced `app_user` row, and the comment at `0003:26-28` names exactly this confidentiality boundary as the reason ownership exists.
*Resolves when:* `is_facility_user()` distinguishes "linked to no party" from "linked to a party that is not the facility", or the link is `restrict`, or the intern case is granted by role rather than by the absence of a party.
*Load-bearing:* Yes. It is the one finding here that crosses a client-confidentiality line rather than a record-integrity one. It stays LATENT because reaching it needs an account deletion, which at five to ten users is rare, and the schema assertions pass over the intact case.

---

## DIVERGENT

**R-5-13. S-1 says the topping threshold is unchosen. The code has chosen it, at 100%, and says nothing.**
*Verdict:* DIVERGENT. Probed.
*Locator:* `docs/sorry-ledger.md`, S-1; `supabase/migrations/0004_terms_and_effects.sql:150-152`.
*What is wrong:* S-1 records that below some percentage a topping should record volume and source without writing lineage, and that the percentage is not chosen. In the committed schema `topping` carries `{"effect": "treatment"}`. Treatments change the wine in place and write no lineage. A probe of every function body for `threshold`, `topping_fraction` or `min_fraction` returned zero. So the threshold is not unchosen; it is 100%, by the effect assignment, and no topping will ever write a lineage edge at any volume.
*How it surfaces:* Probed. A barrel holding 225 L of 100% Perlstaad, topped with 5 L of the Eola lot, recorded exactly as the kernel would record it. Composition before: Perlstaad 1.0000. Composition after: Perlstaad 1.0000. Truth is roughly 0.978 / 0.022. **The direction of error is that the topped barrel's composition overstates its original blocks and reports the topping source as zero**, and the error accumulates monotonically over a maturation season, because every topping is in the same direction and none is ever recorded structurally. The same probe showed `placement.volume_l` still 225 after adding 5 L, so the volume half is unrecorded too.
*Resolves when:* a threshold is set with its reason recorded, per S-1, and toppings above it write lineage. Which of the two, the sorry or the effect assignment, is wrong is not this report's to decide.
*Load-bearing:* Yes, and S-1 says so itself: it affects whether block composition on a topped barrel is honest. Today it is not, and the dishonesty is one-directional.

**R-5-14. The sorry ledger's Discharged section reads "Nothing has been built" against five applied migrations and a passing test suite.**
*Verdict:* DIVERGENT.
*Locator:* `docs/sorry-ledger.md`, final line; five files under `supabase/migrations/`; `tests/schema_assertions.sql`.
*What is wrong:* The ledger closes with "*None. Nothing has been built.*" The tree at this commit contains five migrations that apply clean and 28 assertions that pass. S-7's own entry contradicts the closing line, describing what the assertions now exercise. The ledger is the document this project uses to know what is still owed, so a stale Discharged section is a real defect in the instrument.
*How it surfaces:* Whoever reads the ledger next either trusts the closing line and assumes no ground has been taken, or notices the contradiction and stops trusting the ledger.
*Resolves when:* the section records what the assertions discharged, or the line is corrected to say that nothing has been discharged yet, which is a different claim from nothing having been built.
*Load-bearing:* No. It misleads a reader and changes no behaviour.

---

## NOT A DEFECT

**R-5-15. `event` has no delete policy, so no authenticated role can delete an event by any direct path.** Probed across all five principals: `delete from event` returned `rows=0` for the admin as well. `pg_policies` confirms `event` carries exactly three policies, for SELECT, INSERT and UPDATE, and none for DELETE. No cascade reaches `event` either; the only foreign key out of it is `by_user`, which points away. Events cannot be destroyed, only rewritten, which is R-5-2. The delete half of question 1 comes back clean and that is worth one line.

**R-5-16. Composition is genuinely derived, with no cached column anywhere.** `node_bin_shares`, `block_composition`, `variety_composition` and `inferred_fraction` (`0002:29-91`) are functions over lineage; `vessel_state`, `lot_state` and `task_board` are views, all three `security_invoker` (`0003:181-183`, `0004:270`, `:328`, `:355`). Nothing caches a composition. C-3 stayed dead at the level C-3 was about. The `variety_kind`, `product_kind`, `type_kind`, `operation_kind` and `kind_kind` columns are `generated always as` constants existing only so a composite foreign key can name both id and kind, exactly as `0004:206-211` explains; they are not stored derivations and are not findings. Where C-3's failure mode did come back is R-5-4 and R-5-9, on volume and on status, which are the two things the ledger entry did not name.

---

## UNVERIFIED

**R-5-17. Supabase's JWT-to-role mapping, which is the half of S-7 the assertions assume.**
*Verdict:* UNVERIFIED.
*What would check it:* a running Supabase instance with GoTrue issuing real tokens for two real accounts, and PostgREST mapping them to the `authenticated` role. My shim sets `request.jwt.claim.sub` directly, exactly as `tests/schema_assertions.sql:36-42` does, so every probe in this report proves what Postgres decides and assumes what Supabase decides. S-7 states this limit accurately and should stay open. Note the specific dependency: R-5-1 turns entirely on `is_admin()` resolving `auth.uid()` correctly at trigger time, so if the plumbing differs, R-5-1's asymmetry could differ with it.

**R-5-18. How PostgREST surfaces a zero-row RLS denial to the phone.**
*Verdict:* UNVERIFIED.
*What would check it:* the walk run against a real Supabase instance as a cellar user, watching the HTTP response to a refused `update`. At the SQL level the statement succeeds with zero rows affected (probed). Whether PostgREST returns 204, an empty 200, or something the client's error branch catches determines whether R-5-8 is invisible to the user or merely confusing. `packages/cellar/src/walk.ts` has no zero-row branch that I could find, which is why I expect invisible, but that is a reading and not an observation.

**Also unverified:** the storage-guarded block at `0005:332-340`, which this shim skipped by design; whether `alter publication supabase_realtime add table event` (`0002:333`) broadcasts an admin's UPDATE to other phones as a new event, which would make R-5-2 visible in a way the database does not record; and whether Supabase's own account-deletion path, which runs as `supabase_auth_admin` rather than the migration owner, hits the same foreign-key block as R-5-11.

---

## Closing

The question was whether history can be rewritten and whether anything derived is also stored. Both answers are yes, and they fail together exactly as the prompt predicted they would.

History is append-only for cellar users and fully mutable for admins, with no trace of the mutation, which means the guarantee is a policy convention rather than a property of the record. Derived-over-stored holds precisely where C-3 looked and fails on the two things C-3 did not name: volume, which is stored twice from one input, and status, which is stored once and never recomputed. The correction walk in question 4 terminates at an admin overwrite, because the append-only correction it was supposed to terminate at is written, accepted, and read by nothing.

What is sound: the composition functions, the view layer, the insert-side provenance guard, and the absence of any delete path to `event`. Those hold under probe and they are not the problem.

The single most useful thing in this report is R-5-1, because it is the one defect that fires during normal work by the person the system was built for, produces no error, and leaves a record that is wrong in a way nobody will trace back to its cause.
