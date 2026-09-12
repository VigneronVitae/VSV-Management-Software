# G-1: Postgres schema, queries, and migrations

**Commit reviewed:** `c3eae3c7c262544e4b2e29526b513c964c6852fe`, dated 2026-09-08, obtained by `git clone https://github.com/VigneronVitae/VSV-Management-Software` (route 1).

## Currency checks

| Check | Result |
|---|---|
| Commit | `git rev-parse HEAD` = `c3eae3c7c262544e4b2e29526b513c964c6852fe`. Exactly the review baseline, not an ancestor. |
| Branch | `main`. Not `claude/sql-files-to-markdown-i31rob`. |
| LICENSE canary | Tree contains 42 tracked files, not a lone LICENSE. |
| Content canary | All four present: `supabase/migrations/0005_account_and_walk.sql`, `tests/schema_assertions.sql`, `packages/cellar/src/walk.ts`, `docs/session-reports/2026-09-08-walk.md`. Tracked file count is 42, matching the stated baseline. |

Every file was read at that SHA. Nothing was fetched over raw, the API, or a rendered page.

## How this review was conducted

Reading alone would have left half of this report as conjecture, so the schema was executed. A local Postgres 16.13 cluster was built, given a minimal `auth` shim (`auth.users`, `auth.uid()` reading both the singular claim and the claims blob, the `anon`/`authenticated`/`service_role` roles, Supabase's default grants in `public`, and an empty `supabase_realtime` publication), and all five migrations were applied in order. They apply clean. `tests/schema_assertions.sql` then ran against that database and all 22 assertions pass.

Each finding below that says "reproduced" was executed against that database. Findings marked UNVERIFIED could not be, and say why.

---

## Findings

| id | Severity | Triage | Issue |
|---|---|---|---|
| G-1-1 | MAJOR | BEFORE HARVEST | `next_cap_action` counts events that have not happened yet |
| G-1-2 | MAJOR | BEFORE HARVEST | The cellar's day starts at 5pm the previous afternoon |
| G-1-3 | MAJOR | BEFORE HARVEST | `generate_inferred_history` dates its history in the future |
| G-1-4 | MAJOR | DURING | Nothing prevents a lineage cycle, and `node_bin_shares` never terminates on one |
| G-1-5 | MAJOR | DURING | `block_composition` drops bins with no block and reports a short total in silence |
| G-1-6 | MAJOR | BEFORE HARVEST | Deactivating a client party promotes that login to full cellar read |
| G-1-7 | MAJOR | BEFORE HARVEST | Client scoping covers `node` only; `event`, `placement` and `lineage` are open to every login |
| G-1-8 | MAJOR | BEFORE HARVEST | `claim_task` has no signed-in check and permanently wedges the task |
| G-1-9 | MAJOR | AFTER | An admin can rewrite and back-date any event |
| G-1-10 | MAJOR | DURING | Every login reads and writes every object in the vessel-photos bucket |
| G-1-11 | MINOR | DURING | `topping_check` raises an internal error if the `topping` term is renamed |
| G-1-12 | MINOR | DURING | Nothing constrains lineage fractions to sum to one |
| G-1-13 | MINOR | DURING | Whoever signs in first becomes admin |
| G-1-14 | MINOR | DURING | Numeric columns accept values the cellar cannot produce |
| G-1-15 | MINOR | DURING | `quantity` and `unit` are independently nullable |
| G-1-16 | MINOR | AFTER | Realtime broadcasts every event and placement to every login |
| G-1-17 | MINOR | AFTER | An event's author is satisfiable by any string in `by_sensor` |
| G-1-18 | MINOR | AFTER | `template_step.offset_from` is stored and never read |
| G-1-19 | MINOR | AFTER | `event.task_id` is not a foreign key |
| G-1-20 | MINOR | AFTER | The migration sequence applies only to an empty database |
| G-1-21 | UNVERIFIED | DURING | Replacing a vessel photo likely fails: no update policy on `storage.objects` |
| G-1-22 | UNVERIFIED | AFTER | Whether Supabase Realtime applies RLS to the replication stream on the hosted project |
| G-1-23 | NIT | AFTER | Eleven indexes, and the client issues no query that needs any of them |

**No BLOCKERs.** Nothing in these five migrations loses data or stops work on the system as it stands: applied to an empty database and driven by the walk screen, the schema holds. The two findings that would corrupt the record (G-1-3, G-1-5) are inert today because no template is seeded and no bin carries a `block_id`, and both become live during harvest.

---

## MAJOR

**G-1-1. `next_cap_action` counts events that have not happened yet.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `supabase/migrations/0004_terms_and_effects.sql:402-410`
*What is wrong:* `done_today` counts every punchdown and pumpover with `e.at >= date_trunc('day', now())`. There is no upper bound, so an event dated next week counts as done today. Combined with G-1-3, which stamps generated history in the future, a lot carried in during the walk arrives with its cap rotation already advanced by work nobody did.
*Why it matters here:* reproduced. A Pinot Noir lot with `{"sequence": ["punchdown", "pumpover"]}` and three future-dated inferred punchdowns: `next_cap_action` answers `pumpover`, the correct answer counting only what has actually happened is `punchdown`. A cellar hand at 7am does what the phone says. Pumping over a cap that needs punching is a real extraction decision on a fermenter, not a cosmetic error, and this is the screen whose whole purpose is to make recording self-enforcing.
*Fix:* add `and e.at <= now()` to the where clause. One line, no migration to the data.
*Effort:* minutes.

**G-1-2. The cellar's day starts at 5pm the previous afternoon.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `supabase/migrations/0004_terms_and_effects.sql:408`
*What is wrong:* `date_trunc('day', now())` truncates in the session timezone, which on Supabase is UTC. Reproduced on the test cluster: `date_trunc('day', now())` resolves to `2026-09-11 00:00 UTC`, which is `2026-09-10 17:00` in the Willamette Valley.
*Why it matters here:* during harvest, punchdowns run into the evening. Every cap action recorded after 5pm counts toward the next morning's rotation, so the count the morning crew's answer is derived from is wrong by however many evening actions happened. With a two-element sequence an odd number of evening actions inverts the answer. This is not a daylight-saving problem: harvest is September and October, and the DST boundary is in November. It is the standing offset, and it is wrong every day of the year.
*Fix:* `date_trunc('day', now() at time zone 'America/Los_Angeles') at time zone 'America/Los_Angeles'`. Better, since the app is intended for other winemakers: put the zone on a facility row or a `term` of kind `location_kind` and read it, so a fork in another state does not inherit Oregon. The one-line version first.
*Effort:* minutes for the hardcoded zone, an hour for the configurable one.

**G-1-3. `generate_inferred_history` dates its history in the future.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `supabase/migrations/0005_account_and_walk.sql:201-206`, call site at `:286`
*What is wrong:* `at_time` starts at `p_from`, which defaults to `now()`, and each step adds its `offset_interval` forward. `create_vessel_with_wine` calls it with no `p_from`, so every generated event lands at `now()` plus a positive offset. The comment at `:161-163` says templates run backward. The arithmetic runs forward.
*Why it matters here:* reproduced. A 2024 Pinot Noir carried in on the walk, under a three-step template, was given a punchdown dated 2026-09-12, a punchdown dated 2026-09-25 and a **press dated 2026-10-05**, all stamped `inferred`, all after the date of the walk. That is not a reconstruction of what happened to a barrel already in the cellar, it is a schedule, written into the same table as the record. It pollutes `inferred_fraction`, it feeds G-1-1, and any screen listing a lot's history shows a press that has not occurred. The repository's own assertions at `tests/schema_assertions.sql:297-320` generate two such events and check their provenance but never check their `at`, which is why this passes.
*Why it is not a BLOCKER:* S-17 is open, no template is seeded, so today the function returns 0 and writes nothing. The first seeded template makes it live.
*Fix:* the call site is the cheap correction: pass a `p_from` in the past, derived from the lot's entry. The correct fix is to run the template backward as the comment says, `at_time := p_from - (sum of remaining offsets)`, then step forward, so the last generated event lands at the walk and everything before it is genuinely history. Guard it: refuse to write an event with `at > now()` from this function, which also documents the intent.
*Effort:* an hour, plus an assertion that no generated event is dated after `now()`.

**G-1-4. Nothing prevents a lineage cycle, and `node_bin_shares` never terminates on one.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:34-40`; the absent guard at `supabase/migrations/0001_core_schema.sql:195-202`
*What is wrong:* `lineage` enforces `no_self_parent` and nothing else. A two-node cycle, A parent of B and B parent of A, inserts without complaint, and the `insert` policy is `with check (true)` for any authenticated user. `node_bin_shares` recurses with `union all` and cannot deduplicate, because the same id legitimately arrives by several paths carrying different shares. Reproduced: the cycle inserted cleanly and `select count(*) from node_bin_shares(...)` was still running when a 5-second statement timeout killed it. `inferred_fraction` at `:80-84` survives the same cycle because it uses `union`, which is accidental protection rather than designed.
*Why it matters here:* a lot page that hangs, on a phone, in a barrel room, and burns a connection until the timeout fires. On a bare Postgres, which migration 0005's own comment says the project cares about supporting, `statement_timeout` is 0 and the worktable grows until the instance runs out of memory.
*Why it is DURING and not BEFORE HARVEST:* the existing screens cannot produce a cycle. The blend path writes parent to newly-created child, so the edge always points at a node that did not exist a moment ago. A cycle needs hand-written SQL or a future screen that lets a user pick an existing node as a blend child. Fix it before that screen ships.
*Fix:* carry the path and refuse to revisit. `select p_node_id as id, 1.0::numeric as share, array[p_node_id] as path` in the anchor, `select l.parent_id, up.share * l.fraction, up.path || l.parent_id` in the recursive term, and `where not l.parent_id = any(up.path)` on the join. A belt-and-braces `before insert` trigger on `lineage` refusing an edge whose child is already an ancestor of its parent closes it at the write path too, and costs one traversal per blend.
*Effort:* an hour including a cycle assertion in `tests/schema_assertions.sql`.

**G-1-5. `block_composition` drops bins with no block and reports a short total in silence.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:53-56`, the inner `join block b on b.id = n.block_id` at `:56`
*What is wrong:* the join to `block` is inner. A bin with a null `block_id`, which `block_only_on_bins` at `0001:185-186` permits and nothing requires, contributes its share to `node_bin_shares` and then vanishes from the result. The caller receives a set of rows with no indication that anything was dropped.
*Why it matters here:* reproduced. A three-way equal blend of three bins, two with blocks and one without, returns two rows summing to **0.66666**. A person reading that as a composition sees Perlstaad 33% and Eola Springs 33% and would reasonably normalise to fifty-fifty. This is the function the TTB and label numbers come off. `variety_composition` at `0004:257-268` was corrected to a left join and does report the unknown bucket, so the pattern is already understood in the codebase; `block_composition` did not get the same treatment.
*Why it is DURING:* nothing calls `block_composition` yet and no node carries a `block_id`, because the intake screen is not built. Harvest is when bins start carrying blocks.
*Fix:* change to `left join block b`, group by `b.id, b.vineyard, b.name` as now, and let the null row through as an explicit unknown. Then have the caller show the total and flag it when it is not 1. A companion `composition_total(uuid)` returning `sum(share)` from `node_bin_shares` makes that one call instead of arithmetic in the client.
*Effort:* minutes for the join, an hour with the total and the display.

**G-1-6. Deactivating a client party promotes that login to full cellar read.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `supabase/migrations/0003_parties_and_products.sql:272-275`
*What is wrong:* `is_facility_user()` coalesces the "no party" case to `true`, deliberately, so a harvest intern linked to nothing sees everything. But the subselect is filtered by `and active`, so a client whose party is deactivated also produces no row, also coalesces to `true`, and becomes a facility user.
*Why it matters here:* reproduced. Before `update party set active = false`, the client login saw 0 of 8 nodes. After it, 8 of 8. The obvious administrative action for "this custom crush contract has ended, switch them off" is the exact action that hands them the whole cellar. Nothing in the assertions covers it; `tests/schema_assertions.sql:389-408` tests the active-client case only.
*Fix:* separate "has no party" from "has an inactive party":
```sql
select is_admin() or coalesce(
  (select kind = 'facility' from party where app_user_id = auth.uid()),
  true);
```
Dropping `and active` from the lookup means a deactivated client is still evaluated as a client and sees their own lots and nothing else. If a deactivated party should see nothing at all, add `and active` to the `node_read` predicate instead, where it fails closed.
*Effort:* minutes, plus an assertion.

**G-1-7. Client scoping covers `node` only; `event`, `placement` and `lineage` are open to every login.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `supabase/migrations/0003_parties_and_products.sql:280-283`, against the blanket read loop at `supabase/migrations/0002_derived_and_rls.sql:262-272`
*What is wrong:* 0003 drops and replaces `node_read` and stops there. The `select ... using (true)` policies written for the other eleven tables in 0002 stand.
*Why it matters here:* reproduced, as the client login in the fixture: `node` 0 of 8, and then `event` 4 of 4, `placement` 2 of 2, `lineage` 3 of 3, `vessel` and `block` and `app_user` all of them. A custom crush client sees every Brix, pH and addition in `event.data` for lots they do not own, every vessel those lots are in, and, in `lineage.fraction`, the facility's exact blend recipes to five decimal places. The comment above the policy says "A client sees their own lots and is not told how many others exist." That claim is false as written. Two custom crush clients are on the books per the spec, and the promise a custom crush facility makes to its clients about each other is the contract.
*The gate:* `party.app_user_id` is nullable and a client may own wine and never log in. This is harmless until the first client login is issued. Fix it before that, which on the current build order is before harvest.
*Fix:* scope the three tables that carry wine. `placement` scopes through its node, `lineage` through both endpoints, `event` through `node` for `subject_type = 'node'`:
```sql
drop policy event_read on event;
create policy event_read on event for select to authenticated using (
  is_facility_user()
  or (subject_type <> 'node')
  or exists (select 1 from node n
              where n.id = event.subject_id and n.owner_id = current_party_id()));
```
with the same shape for `placement` and `lineage`. `event.subject_id` is not a foreign key (S-4), hence the `subject_type` branch. `vessel`, `block`, `location` and `term` are structural and a client seeing them leaks nothing about wine; leave them.
*Effort:* two to three hours including assertions for each table, which the existing RLS test harness makes straightforward.

**G-1-8. `claim_task` has no signed-in check and permanently wedges the task.**
*Severity:* MAJOR
*Triage:* BEFORE HARVEST
*Locator:* `supabase/migrations/0001_core_schema.sql:335-360`; contrast the guard `claim_account` does have at `supabase/migrations/0005_account_and_walk.sql:47-49`
*What is wrong:* `claim_task` is `security definer`, `execute` is granted to `public` by Supabase's default privileges, and it never checks that `auth.uid()` is non-null. Called without a session it sets `status = 'claimed'`, `claimed_by = null`, `claimed_at = now()`.
*Why it matters here:* reproduced as the `anon` role with no claim set. The task came back `claimed`, `claimed_by` null, timestamp set. The next real cellar user to try it gets `task ... is not available`, permanently, because the guard is `status = 'open'`. It still appears on `task_board` with a null `claimed_by_name`. Recovery is an admin `update task set status = 'open'` in the SQL editor, once somebody works out what happened.
*The accidental path, which matters more than the deliberate one:* `jwt_expiry` is 3600 in `supabase/config.toml:44`. A phone whose refresh fails on barrel-room wifi keeps the anon key and falls back to the `anon` role. A cellar hand taps claim, the call succeeds, the phone shows success, and the task is dead. Nothing calls `claim_task` today, so nothing is broken right now; the task board is the screen that makes it live.
*Fix:* the three lines `claim_account` already uses, at the top of the function:
```sql
if auth.uid() is null then
  raise exception 'not signed in' using errcode = 'insufficient_privilege';
end if;
```
and `revoke execute on function claim_task(uuid) from anon;` as a second line of defence. Worth sweeping the other definer functions for the same omission at the same time: `confirm_event` checks `is_admin()` and is fine, `is_admin` and `current_party_id` return false or null for a null uid and are fine.
*Effort:* minutes.

**G-1-9. An admin can rewrite and back-date any event.**
*Severity:* MAJOR
*Triage:* AFTER
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:293-295`, with the insert-only triggers at `supabase/migrations/0005_account_and_walk.sql:119-125`
*What is wrong:* `refuse_self_granted_standing` fires `before insert` only. `event_admin_update` permits an admin to update any column of any event. Nothing guards `provenance`, `at`, `data` or `by_user` on update.
*Why it matters here:* reproduced. One statement changed a recorded sample from `{"brix": 24.6}` to `{"brix": 21.0}`, moved its timestamp three days earlier, and set `provenance` to `confirmed` on an event that was never inferred. The comment two lines above the policy reads "anyone may record, nobody may rewrite history. Corrections are new events, not edits", and `0001`'s header claims T0-5 append-only is enforced. Neither holds for the one role that matters. The winemaker is the admin and is not an adversary, so this is a missing guardrail rather than a hole; a back-dated Brix is still exactly what a TTB audit turns on, and nothing records that the edit happened.
*Fix:* narrow the policy instead of removing it, because an admin does need to correct a typo in a note. A `before update` trigger on `event` that refuses any change to `at`, `data`, `subject_id`, `subject_type` or `by_user`, and permits `provenance` only on the `inferred` to `confirmed` transition, leaves `confirm_event` working and closes everything else. If a correction to a value is genuinely needed, it is a new event, which is what the design already says.
*Effort:* an hour with an assertion.

**G-1-10. Every login reads and writes every object in the vessel-photos bucket.**
*Severity:* MAJOR
*Triage:* DURING
*Locator:* `supabase/migrations/0005_account_and_walk.sql:325-327` and `:336-338`
*What is wrong:* `vessel_photos_read` is `to authenticated using (bucket_id = 'vessel-photos')` with no ownership predicate, and `vessel_photos_insert` is the same on the write side. Any signed-in account reads every photo and writes to any path in the bucket.
*Why it matters here:* the comment directly above says "Private. A photo of a barrel shows a chalk mark with a client's lot on it." Private from `anon`, yes. Not private from the other custom crush client, which is the party the comment is worried about. Same exposure as G-1-7 through a channel the node policy does not touch, and the client code at `packages/core/src/kernel.ts:283` writes to a fully predictable path, `<vesselId>/photo.<ext>`, so anything readable is also guessable and overwritable.
*Fix:* the object path already starts with the vessel id, so scope on it:
```sql
using (bucket_id = 'vessel-photos'
       and (is_facility_user()
            or exists (select 1 from vessel v
                        where v.id = (storage.foldername(name))[1]::uuid
                          and v.owner_id = current_party_id())))
```
A vessel with a null `owner_id` is facility-owned and covered by the first branch. Same predicate on insert. Tighten the insert side further with a `name` pattern check if a cellar user should not be able to write outside a vessel folder.
*Effort:* an hour, and it needs the Supabase stack to test, so it cannot be asserted in the bare-Postgres harness.

---

## MINOR

**G-1-11. `topping_check` raises an internal error if the `topping` term is renamed.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `supabase/migrations/0004_terms_and_effects.sql:442-446` and `:491`
*What is wrong:* `fields` is populated by `select ... into fields from term where t.id = op`. If no row matches, the select assigns nothing and `fields` stays null. `foreach f in array fields` then raises `FOREACH expression must not be null`.
*Why it matters here:* reproduced by `update term set value = 'top_up' where value = 'topping'`, which is precisely the edit 0004's own comment at `:419-421` invites ("a cidery that tops across vintages edits one row"). The topping screen then throws a PL/pgSQL internal error instead of answering, and the error tells nobody anything. It fails closed rather than open, which is the right direction, but the vocabulary is meant to be editable and one edit breaks a screen.
*Fix:* `fields := coalesce(fields, '{}'::text[]);` after the select, and raise a real message if `op` resolves to nothing: `if op is null then return query select false, 'no topping operation is configured'; return; end if;`.
*Effort:* minutes.

**G-1-12. Nothing constrains lineage fractions to sum to one.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `supabase/migrations/0001_core_schema.sql:198`
*What is wrong:* `fraction` is checked individually, `> 0 and <= 1`, and never collectively. Nothing requires a child's parent fractions to sum to 1, and nothing stops a parent's outgoing fractions from summing past 1, which is S-3 already on the ledger.
*Why it matters here:* combined with G-1-5 it means a composition total can be short for three independent reasons and the caller cannot distinguish them. The rounding contribution is negligible and worth stating so it does not get fixed by mistake: `numeric(6,5)` rounds a third to 0.33333, so three equal siblings sum to 0.99999, an error of one part in 10^5 against a 75% varietal threshold. That is not the problem. The missing sum is.
*Fix:* not a constraint. A deferrable constraint trigger would fire on the first insert of a multi-parent blend and block the second, which is wrong. Expose it instead: `composition_total(p_node_id)` over `node_bin_shares`, shown on the lot page, flagged when it is outside a tolerance of 1. Correctness becomes visible rather than enforced, which suits a record that is built up over several screens.
*Effort:* an hour.

**G-1-13. Whoever signs in first becomes admin.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `supabase/migrations/0005_account_and_walk.sql:56-65`
*What is wrong:* `claim_account` grants admin to the first account to call it. With `enable_signup = false` in `supabase/config.toml:49`, accounts are created by hand in the Supabase dashboard, possibly several at once before anyone signs in. The first person to open the app on their phone is then the admin.
*Why it matters here:* if that is a harvest intern rather than the winemaker, the winemaker cannot create vessels, locations or terms, and cannot promote themselves, because `app_user` is admin-write. Recovery is one `update app_user set role = 'admin'` in the SQL editor, so this is not expensive, only surprising at a bad moment. The advisory lock at `:59` correctly closes the concurrent-signup race it was written for; this is the sequential case, which it was not.
*Fix:* procedural first, and free: the winemaker signs in before anyone else is told the app exists. In code, gate the admin grant on an explicit bootstrap value rather than on ordering, for instance a `term` of kind `location_kind` is the wrong home for it but a one-row `facility_config` table read by `claim_account` is not, or simply have the person creating the auth accounts insert the admin's `app_user` row by hand and let `claim_account` handle everyone else.
*Effort:* minutes for the procedure, an hour for the code.

**G-1-14. Numeric columns accept values the cellar cannot produce.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `supabase/migrations/0001_core_schema.sql:116` (`ambient_c`), `:134` (`capacity_l`), `:139-140` (`setpoint_c`), `:165` (`vintage`), `:172` (`quantity`), `:233` (`volume_l`)
*What is wrong:* every one of these is unconstrained beyond its precision. `setpoint_c numeric(5,2)` accepts 900. `volume_l` and `capacity_l` and `quantity` accept negatives. `vintage int` accepts 20226, which is a plausible mistype for 2026 on a phone keyboard.
*Why it matters here:* the sharp one is `vintage`, because it is typed on the intake screen under time pressure and because it is what `topping_check` compares. A lot entered as vintage 20226 will refuse to accept a top from its own siblings and the reason string will say "vintage mismatch" without saying which value is absurd. The thermal ones are less sharp: a 900 degree setpoint on a glycol jacket is a display problem, not a wine problem, since nothing actuates from this database.
*Fix:* one migration of check constraints. `vintage between 1900 and 2100`, `volume_l >= 0`, `capacity_l > 0`, `quantity >= 0`, `setpoint_c between -20 and 60`, `ambient_c between -20 and 60`. Additive, no rewrite, and safe to apply to a table with data because no existing row can violate them.
*Effort:* half an hour.

**G-1-15. `quantity` and `unit` are independently nullable.**
*Severity:* MINOR
*Triage:* DURING
*Locator:* `supabase/migrations/0001_core_schema.sql:172-173`
*What is wrong:* nothing ties them. A node can carry `quantity = 1400` with `unit` null, which is a number with no meaning, or `unit = 'lbs'` with no quantity, which is harmless noise.
*Why it matters here:* `quantity_unit` mixes mass and volume in one enum, `('lbs','kg','L','gal')`, and S-9 defers conversion. Until conversion exists, the unit is the only thing that makes the number readable, and a bin recorded as 1400 with no unit during a busy intake is unrecoverable later: 1400 lbs and 1400 L are both plausible for a macrobin.
*Fix:* `check (num_nonnulls(quantity, unit) <> 1)`. Additive and satisfiable by every existing row.
*Effort:* minutes.

**G-1-16. Realtime broadcasts every event and placement to every login.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:332-334`
*What is exactly published, verified against the live cluster:* the `supabase_realtime` publication carries three tables, `event`, `placement` and `task`, with all four operations enabled (insert, update, delete, truncate) and replica identity `default` on each, meaning the primary key only. So: delete payloads carry the id and nothing else, and update payloads carry no `old_record`. Row security is enabled but not forced on all three, which is the correct setting, since the tables are never accessed as their owner by the API.
*To whom:* Supabase's Realtime applies each subscriber's RLS `select` policy to `postgres_changes` rows. Those policies are `using (true)` for `authenticated` on all three tables, so today every signed-in account receives every insert to `event` and `placement` as it happens. That is the same exposure as G-1-7, through a channel that is easy to forget when the table policies are eventually tightened. Fixing G-1-7 fixes this, because the broadcast filter is the read policy.
*Why it matters here:* the stated purpose at `:330` is that the board shows a claimed task as claimed on someone else's phone. That needs `task`. `event` and `placement` are published for a live lot page that does not exist yet, and at three concurrent users the polling this replaces would cost nothing.
*Fix:* nothing structural. When G-1-7 lands, re-check the broadcast, and consider dropping `event` and `placement` from the publication until a screen actually subscribes to them.
*Effort:* minutes to drop the two tables, none if G-1-7 is done first.

**G-1-17. An event's author is satisfiable by any string in `by_sensor`.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `supabase/migrations/0001_core_schema.sql:266-267`, policy at `supabase/migrations/0002_derived_and_rls.sql:289-291`
*What is wrong:* `has_an_author` is an `or`, and `event_insert`'s check is the same `or`. Reproduced: a cellar user inserted an event with `by_user` null and `by_sensor` set to a string naming a sensor that does not exist, and it was accepted.
*Why it matters here:* T0-3 wants provenance on every event, and the author is half of provenance. There are no sensors yet, so nothing legitimate uses this branch; the exposure is that an event can be written with no traceable human. It takes a hand-crafted call, the UI offers no path to it, so this is a boundary that is not yet a boundary rather than an active problem.
*Fix:* when sensors arrive they will need a registry anyway. Until then, `with check (by_user = auth.uid())` on the insert policy, and let the sensor path be a separate policy granted to `service_role`, which is how an automated reading should arrive in any case.
*Effort:* minutes.

**G-1-18. `template_step.offset_from` is stored and never read.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* declared at `supabase/migrations/0001_core_schema.sql:296-297`, never referenced; the loop that should read it is `supabase/migrations/0005_account_and_walk.sql:203-215`
*What is wrong:* the column says an offset is measured from the previous step or from stage entry. `generate_inferred_history` accumulates unconditionally, so every step is treated as `previous`. A template authored with `offset_from = 'stage_entry'` produces silently wrong timestamps, with no error.
*Why it matters here:* no template exists yet (S-17), so nothing is wrong today. It is a trap laid for whoever writes the first template, and the failure is quiet.
*Fix:* either read it, which is four lines inside the loop resetting `at_time` to `p_from` when `offset_from = 'stage_entry'`, or drop the column and the idea with it. Reading it is cheaper than explaining it later, and G-1-3 is going to rewrite this loop anyway; do both at once.
*Effort:* minutes, folded into G-1-3.

**G-1-19. `event.task_id` is not a foreign key.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `supabase/migrations/0001_core_schema.sql:263`
*What is wrong:* `task_id uuid` with no reference, though `task` is created 46 lines later in the same file. S-4 covers `subject_id`, where polymorphism makes a foreign key impossible; `task_id` has no such excuse and looks like an oversight rather than a decision.
*Why it matters here:* an event claiming to satisfy a task that does not exist is a broken link in the one direction that connects the board to the record. Nothing reads it yet, so nothing breaks.
*Fix:* `alter table event add constraint event_task_fk foreign key (task_id) references task(id) on delete set null;`. Additive, applies to a table with data, and no existing row can violate it because nothing writes the column.
*Effort:* minutes.

**G-1-20. The migration sequence applies only to an empty database.**
*Severity:* MINOR
*Triage:* AFTER
*Locator:* `supabase/migrations/0003_parties_and_products.sql:81` and `:130-132`; `supabase/migrations/0004_terms_and_effects.sql:216`, `:225`, `:234`, `:242`
*What is wrong:* three distinct one-way steps.
1. `add column owner_id uuid not null default facility_party_id()` takes Postgres's fast path, because a `stable` default is evaluated once at `alter` time rather than per existing row. No facility party exists at that moment, so the stored value is null. Reproduced against a database carrying one node row: `ERROR: column "owner_id" of relation "node" contains null values`, at `0003:81`. Seeding the facility party before the `alter` fixes it, and was also reproduced: the existing row picked up the owner correctly.
2. `drop index vessel_qr_idx; alter table vessel drop column qr_code;` at `:131-132` discards every QR code with no path into the `vessel_code` table created 17 lines earlier. Reproduced: `vessel_code` is empty afterwards and the sticker is gone.
3. 0004 adds four `not null` columns with no default (`vessel.type_id`, `event.operation_id`, `task.operation_id`, `template_step.operation_id`). Each fails against any existing row. 0004's header says so out loud at `:30`, "Nothing is preserved. The database is empty", so this one is a stated decision rather than an oversight.
*Why it matters here:* nothing is deployed, so nothing is at risk, and a second winery installing from 0001 forward onto an empty database is fine too. It matters because there are no down migrations and the sequence is now the only description of how to reach this schema. A rollback, if one were ever needed, is a restore from a Supabase point-in-time backup, not a migration. That is worth writing down somewhere other than a review.
*Fix:* for (1), move a facility party insert above the `alter`, or add the column nullable, backfill, then set `not null`. For (2), one statement before the drop: `insert into vessel_code (vessel_id, code, label) select id, qr_code, 'legacy' from vessel where qr_code is not null;`. For (3), leave it and keep the header comment honest.
*Effort:* half an hour for all three, and the honest question is whether editing already-written migrations is worth it given nothing has run them. If they stay as they are, say so in `docs/status-ledger.md` rather than in a comment nobody reads at deploy time.

---

## UNVERIFIED

**G-1-21. Replacing a vessel photo likely fails: no update policy on `storage.objects`.**
*Severity:* UNVERIFIED
*Triage:* DURING
*Locator:* `supabase/migrations/0005_account_and_walk.sql:330-339`; client at `packages/core/src/kernel.ts:280-287`
*What is wrong:* the migration creates `select` and `insert` policies on `storage.objects` and no `update` policy. The client uploads with `{ upsert: true }` to a deterministic path, `<vesselId>/photo.<ext>`. Supabase's storage API implements upsert over an existing object as an update to the object row, which needs an `update` policy. If that is right, the first photo of a barrel works and every retake fails with an RLS error.
*Why it is UNVERIFIED:* the storage schema does not exist on a bare Postgres, so 0005's guarded block skipped it in this replay, exactly as its comment at `:302-306` says it will. Confirming this needs the Supabase stack running.
*Why it matters here:* a blurry first photo of a barrel head, on a phone, in a dim barrel room, is the common case and not the exception.
*Fix:* add the third policy with the same predicate as the other two, and with G-1-10's ownership scope once that lands:
```sql
create policy vessel_photos_update on storage.objects
  for update to authenticated
  using (bucket_id = 'vessel-photos') with check (bucket_id = 'vessel-photos');
```
Check it by uploading twice to the same path against a local `supabase start`.
*Effort:* minutes for the policy, plus whatever it costs to stand the stack up.

**G-1-22. Whether Realtime applies RLS to the replication stream on the hosted project.**
*Severity:* UNVERIFIED
*Triage:* AFTER
*Locator:* `supabase/migrations/0002_derived_and_rls.sql:332-334`
*What is wrong:* the publication contents and replica identities were read off the live cluster and are stated exactly in G-1-16. Whether the Realtime service in front of them applies each subscriber's `select` policy, and whether it does so for delete events, is a property of Supabase's Realtime server and its configuration on the hosted project, not of this schema. This cannot be settled from the repository.
*Fix:* nothing to fix here. When a hosted project exists, subscribe as a client login and confirm what arrives. Note it as the remaining half of S-7, alongside the JWT-to-role mapping the assertions also cannot reach.
*Effort:* minutes, once there is a project.

---

## NITs

**G-1-23. Eleven indexes with no query behind them.** `node_stage_idx` (`0001:189`), `node_variety_vintage_idx` (`0004:212`), `node_block_idx` (`0001:191`), `node_product_type_idx` (`0004:213`), `event_operation_at_idx` (`0004:231`), `event_provenance_idx` (`0001:275`), `vessel_location_idx` (`0001:152`), `vessel_owner_idx` (`0003:90`), `task_board_idx` and `task_subject_idx` (`0001:330-332`), `placement_node_idx` (`0001:244`). Against the client's actual query set, which is nine `from(...)` calls and four RPCs in `packages/core/src/kernel.ts`, none of them is reached: the client filters `vessel_state` not at all, `event` by subject (which `event_subject_idx` serves), `term` by kind and active (which `term_kind_idx` serves), and `party` and `location` not at all. `node_owner_idx` earns its place through the `node_read` policy. The rest were written against query shapes that do not exist yet. At tens of thousands of rows after a decade this costs nothing measurable on writes and there is no reason to remove any of them. It is worth naming only so the next person does not read the index set as evidence that the query shapes were designed.

Two smaller ones. `event_provenance_idx` is a partial index on the same column its own predicate fixes, so it is a row-pointer list for "every inferred event" and nothing more; that is a legitimate shape, but `inferred_fraction` does not use it because it joins by subject first. And `party_one_facility` indexes `kind` where `kind = 'facility'`, which stores a constant; `on party((true))` expresses the same uniqueness more plainly, though the current form is clearer to read and the difference is nothing.

---

## What was checked and holds

Worth stating, because a reviewer would expect several of these to be wrong.

**Every timestamp column is `timestamptz`.** `created_at`, `closed_at`, `at`, `from_at`, `to_at`, `due_from`, `due_to`, `claimed_at`, `released_at`, `added_at`, all of them, verified by grep across all five migrations. There is no naive `timestamp` anywhere, so there is no instant that changes meaning across a boundary. The daylight-saving question is moot twice over: the columns are correct, and harvest runs September into October with the boundary in November. The timezone problem this system actually has is G-1-2, which is the standing UTC offset and is wrong in July as much as in November.

**The fraction arithmetic across depth is exact.** `up.share * l.fraction` multiplies unconstrained `numeric`, where the result scale is the sum of the input scales and nothing is rounded. Five levels deep the share carries 26 digits and every one of them is right. No rounding accumulates in the traversal. The only rounding in the system is at input, where `numeric(6,5)` stores a third as 0.33333, and it is one part in 10^5.

**The recursion is fast at any width this winery will reach.** Measured against synthetic merge trees on the test cluster: 64 paths in 38 ms, 1,296 paths in 45 ms, 7,776 paths in 86 ms, 32,768 paths in 229 ms. The real worst case here is a final blend of a dozen barrels each pressed from a handful of bins, on the order of 50 to 500 paths, which lands under 50 ms. `node_bin_shares` would need roughly six levels of ten-way merges before it became noticeable, which this cellar will not produce. It is bounded by path count rather than by node count, and `lineage_child_idx` at `0001:204` is the right index for the upward walk and is present. The only unbounded case is the cycle in G-1-4.

**`security_invoker = true` is set on all three views, deliberately, and it works.** `0003:138`, `:181-182`, carried forward at `0004:271`, `:329`, `:358`, with the reasoning written out at `0003:178-180`. This is the single most common Supabase schema mistake and this repository did not make it. Verified: as the `anon` role, `vessel_state`, `lot_state`, `task_board`, `node` and `term` all return zero rows. No view widens access beyond the tables under it.

**`placement_one_lot_per_vessel` is the right constraint and its predicate means what the comment says.** A partial unique index on `vessel_id where to_at is null` permits one lot in a vessel now, any number of lots in it historically, and one lot across many vessels at once. That is exactly the Pinot Gris in a tank and eight barrels case the comment at `0001:239-240` describes.

**The composite `(id, kind)` foreign keys do real work.** `term_id_kind_key` plus the generated constant columns turn "the picker only offers varieties" into a database refusal. Confirmed in the replay: inserting a cooper's term id into `node.variety_id` raises `foreign_key_violation`. This is a genuinely good piece of schema design and it costs one stored byte per row.

**`claim_task`'s claim is race-free.** A single `update ... where status = 'open' and claimed_by is null returning *` cannot double-claim under concurrency; the second caller's update matches nothing and the function raises. The authentication hole in G-1-8 is a separate defect in the same function and does not touch this.

**`claim_account`'s advisory lock closes the race it was written for.** Taking `pg_advisory_xact_lock` before the `count(*) = 0` test, and holding it to commit, serialises two simultaneous first sign-ups correctly. The sequential ordering problem is G-1-13 and is a different thing.

**Volatility markers are right everywhere they were checked.** `is_admin`, `current_party_id`, `is_facility_user`, `facility_party_id`, `term_id`, `operation_effect`, `node_bin_shares`, `block_composition`, `variety_composition`, `inferred_fraction`, `next_cap_action`, `topping_check` and `resolve_vessel_code` are all `stable` and all read without writing. `next_cap_action` and `topping_check` read `now()`, which is stable within a statement, so `stable` is correct rather than generous. `claim_task`, `claim_account`, `confirm_event`, `bind_vessel_code`, `generate_inferred_history` and `create_vessel_with_wine` write and are correctly left `volatile`. Nothing is marked `immutable` that should not be.

**Every `security definer` function pins `search_path`.** `is_admin` (`0001:100`), `claim_task` (`0001:339`), `current_party_id` (`0003:257`), `is_facility_user` (`0003:270`), `claim_account` (`0005:41`), `confirm_event` (`0005:135`). All to `public`. `auth.uid()` is schema-qualified at every call site, so the pin does not break it. The three functions that are not definer, `bind_vessel_code`, `generate_inferred_history` and `create_vessel_with_wine`, are invoker on purpose and the comment at `0005:230-231` explains why: they compose ordinary writes and grant nothing. That is correct, and it is why `create_vessel_with_wine` requires an admin, which the walk is.

**All five migrations apply clean to an empty Postgres 16**, in order, no warnings beyond the expected `wal_level` notice from the shim, and 0005's storage guard behaves exactly as documented outside Supabase. **All 22 assertions in `tests/schema_assertions.sql` pass.**

## On the enums that remain

Ten enum types survive 0004. Eight are correctly fixed, one is questionable, one is fine but worth watching.

Correctly fixed, because the kernel branches on them and adding a value is a code change either way: `node_status` (planned, open, closed), `provenance` (observed, inferred, confirmed), `subject_type` (node, vessel, location, block), `task_status` (open, claimed, done, skipped), `user_role` (admin, cellar), `party_kind` (facility, client), `thermal_mode` (cooling, heating, off), and `term_kind` itself, whose comment at `0004:36-39` makes the argument better than this review could. Adding a value to any of these costs `alter type ... add value`, which is cheap and non-blocking in Postgres 12 and later, plus the code that must handle it, which is the real cost and the right one.

`node_stage` (bin, load, ferment, maturation, finished) is the questionable one. Adding a stage is exactly the kind of thing a fork does: a cidery has no `bin`, a producer doing extended tirage wants a stage between maturation and finished. It has the same shape as `vessel_type`, which 0004 moved to `term` for precisely this reason. It was not moved, and no comment says why. The counter-argument is real, `node_stage` drives `block_only_on_bins` at `0001:185-186` and probably drives screen routing, which `vessel_type` does not. Worth a sentence in the spec either way, and not worth a migration now.

`quantity_unit` (lbs, kg, L, gal) is fine as an enum and wrong as a design, separately. Mixing mass and volume in one type is what makes G-1-15 bite and what S-9 defers. Leaving it as an enum is correct: conversion factors are code, not vocabulary, and letting a facility add `tonnes` at runtime without a conversion behind it would produce a number nobody can read. Keep the enum, close S-9 with the compliance advisor.

---

## Closing

The schema is better built than most production systems this size. Derived values are genuinely derived, the composite foreign keys make the picker discipline a database guarantee rather than a convention, the views are invoker rather than definer, the ids are client-generated, and the migration comments say what the author was worried about rather than what the statement does. The assertions are real assertions and they pass. The reasoning quality is high enough that most of the defects above are single lines inside otherwise correct functions, which is the good failure mode.

Two things account for most of the severity. The first is that time is handled carefully in the column types and carelessly in two expressions, which produces G-1-1, G-1-2 and G-1-3 and, between them, a cellar instruction that is wrong and a record that contains the future. Those three are hours of work in total and they are the ones to do first. The second is that 0003 scoped one table and stopped, which produces G-1-6, G-1-7 and G-1-10 and makes the comment about what a client can see untrue. That is an afternoon, and it is only urgent the moment a client is given a login.
