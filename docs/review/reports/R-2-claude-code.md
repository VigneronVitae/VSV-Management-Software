# R-2: direction of error on every null

**Commit reviewed:** `c3eae3c7c262544e4b2e29526b513c964c6852fe`, dated 2026-09-08, obtained by
`git clone https://github.com/VigneronVitae/VSV-Management-Software` (route 1, first try).

## Currency checks

| Check | Result |
|---|---|
| Commit | `git rev-parse HEAD` = `c3eae3c7c262544e4b2e29526b513c964c6852fe`. Equal to the baseline, not an ancestor. `merge-base --is-ancestor` confirms. |
| Branch | `main`. `origin/claude/sql-files-to-markdown-i31rob` exists and was not read. |
| LICENSE canary | Not triggered. The tree carries the full work. |
| Content canary | All four present: `supabase/migrations/0005_account_and_walk.sql`, `tests/schema_assertions.sql`, `packages/cellar/src/walk.ts`, `docs/session-reports/2026-09-08-walk.md`. `git ls-files` = 42. |

Every file was read at that SHA from the local clone. Nothing was fetched over raw or the API.

---

## Findings, one line each

| id | verdict | one line |
|---|---|---|
| R-2-1 | EXPLOITABLE | Deactivating a client party grants that client's login read of the entire cellar |
| R-2-2 | EXPLOITABLE | `enable_signup = false` in the repo's own config refuses the acceptance test's first account |
| R-2-3 | EXPLOITABLE | Only `node_read` was narrowed; `placement`, `event` and `lineage` still read blanket-true |
| R-2-4 | EXPLOITABLE | `max_rows = 1000` truncates the vessel list silently and the home screen reports the truncation as a count |
| R-2-5 | EXPLOITABLE | The "keep" pin on every picker is dead code: `select.value` is never nullish |
| R-2-6 | EXPLOITABLE | Every authenticated user can read every vessel photo, two lines under a comment saying why they must not |
| R-2-7 | EXPLOITABLE | An untouched variety picker asserts the first seeded variety onto the lot |
| R-2-8 | EXPLOITABLE | A recorded volume of zero is written as null, and null renders as "unrecorded" |
| R-2-9 | LATENT | `node_bin_shares` has no cycle guard; its sibling traversal has one |
| R-2-10 | LATENT | Composition normalizes over the parents it found, with no residual row |
| R-2-11 | LATENT | `block_composition` inner-joins `block`, dropping every bin with no block |
| R-2-12 | LATENT | Composition computed under RLS normalizes over the visible parents |
| R-2-13 | LATENT | `topping_check` approves everything when the operation carries no predicate |
| R-2-14 | LATENT | `next_cap_action` instructs punchdown for a node that does not exist |
| R-2-15 | LATENT | `per_day` is documented as part of `cap_rule` and is never read |
| R-2-16 | LATENT | `generate_inferred_history` returns zero for three reasons; the client asserts one |
| R-2-17 | LATENT | `offset_from` is never read, and a null `offset_interval` becomes zero |
| R-2-18 | LATENT | Nothing writes `placement.to_at`, so the first placement holds the vessel forever |
| R-2-19 | LATENT | `event.task_id` is a second unconstrained id and S-4 names only `subject_id` |
| R-2-20 | LATENT | T0-4 is enforced on insert only; an admin update writes `confirmed` directly |
| R-2-21 | LATENT | `inferred_fraction` returns 0 for a lot with no events, which reads as fully witnessed |
| R-2-22 | LATENT | A template with a null `variety_id` can be created and never matches anything |
| R-2-23 | LATENT | Add-inline cannot ever create an operation term |
| R-2-24 | LATENT | `slug()` returns the empty string for a label with no ascii |
| R-2-25 | LATENT | `uploadVesselPhoto`'s `?? "jpg"` is unreachable |
| R-2-26 | LATENT | Cellar users are shown admin-only actions and pushed into a form they cannot submit |
| R-2-27 | DIVERGENT | 0005 states the migrations stay applicable to a bare database; 0001 and 0002 make that false |
| R-2-28 | DIVERGENT | `bun run test` is in the definition of done and is not a script |
| R-2-29 | DIVERGENT | CLAUDE.md says five compost entries; there are six, two with no reactivation condition |
| R-2-30 | DIVERGENT | The spec's topping fields and the seeded predicate's fields are different sets |
| R-2-31 | DIVERGENT | An assertion's message claims more than the assertion checks |
| R-2-32 | BY DESIGN | Null compared to null passes `topping_check` |
| R-2-33 | BY DESIGN | Composition of a node with no lineage is empty |
| R-2-34 | BY DESIGN | An empty `app_user` makes the next claimant admin |
| R-2-35 | NOT A DEFECT | The empty anon key in `.env.example` fails loudly at startup |
| R-2-36 | NOT A DEFECT | An unresolvable operation id renders as "unknown operation" |
| R-2-37 | NOT A DEFECT | No facility party is a not-null violation, not a silent null owner |
| R-2-38 | UNVERIFIED | Whether Biome 2.5 accepts `linter.rules.preset` |
| R-2-39 | UNVERIFIED | Whether `foreach` over a null array in `topping_check` is a no-op or a raise |
| R-2-40 | UNVERIFIED | Whether `insert into auth.users (id)` alone satisfies real Supabase |

---

## The direction table

Inflationary and unnamed is the output of this prompt. Those rows are marked **bold**.

| Absence | Where it reads | Direction | Named |
|---|---|---|---|
| **no `party` row for a login** | `is_facility_user()` 0003:272-276 | **inflationary: absence grants the whole cellar** | **no** |
| **inactive `party` row for a login** | same `coalesce`, via `active` | **inflationary: deactivation escalates** | **no** |
| **rows past 1000** | `vessels()` kernel.ts:190, walk.ts:236 | **inflationary: a truncated list is counted as the cellar** | **no** |
| **`node.block_id` null on a bin** | `block_composition` 0002:53-57 | **inflationary: the bin vanishes and the rest normalizes** | **no** |
| **a missing `lineage` edge** | `node_bin_shares` 0002:34-45 | **inflationary: shares sum below 1 and are returned as the composition** | **no** (S-1 and S-3 are adjacent, neither is this) |
| **an RLS-invisible parent** | `node_bin_shares`, invoker rights | **inflationary: hidden reads as absent** | **no** |
| **`predicate` absent on an operation term** | `topping_check` 0004:442-447, 491 | **inflationary: approves unconditionally** | **no** |
| **`cap_rule` absent, or its `sequence` key absent** | `next_cap_action` 0004:391-400 | **inflationary: instructs punchdown** | **no** |
| **a node id that resolves to nothing** | `next_cap_action` 0004:391 | **inflationary: instructs punchdown for a lot that is not there** | **no** |
| **`template_step.offset_interval` null** | `generate_inferred_history` 0005:206 | **inflationary: a definite timestamp from an absent interval** | **no** |
| **`vessel.setpoint_c` null while jacketed and running** | `vessel_state.effective_temp_c` 0004:287-290 | **inflationary: reports the room as the vessel temperature** | **no** |
| **`placement.volume_l` null among several** | `lot_state.total_volume_l` 0004:346 | **inflationary: a partial sum presented as the total** | **no** (S-8 is losses, not nulls) |
| **no events on a node** | `inferred_fraction` 0002:85-88 | **inflationary: 0 reads as fully witnessed** | **no** |
| **an unselected picker with no empty option** | walk.ts:638, pickers.ts:95-105 | **inflationary: absence of a choice becomes an assertion** | **no** |
| **a volume entered as 0** | walk.ts:642-644 | **inflationary: a known zero becomes an unknown** | **no** |
| **`node.variety_id` null** | `generate_inferred_history` 0005:187 into walk.ts:695 | **inflationary: the client names a cause that is not the cause** | partial (S-17 names two of three) |
| `placement.to_at` null | `placement_one_lot_per_vessel` 0001:241, `vessel_state` | inflationary: absence asserts ongoing occupancy | semantics at spec:120, consequence no |
| `node.variety_id` null | `variety_composition` 0004:265 left join | deflationary: an explicit null-variety row | no, and it is correct |
| `location.ambient_c` null | `effective_temp_c` | deflationary | no |
| `vessel.owner_id` null | `facility_owned` 0004:280 | deflationary by definition | yes, 0003:85-86 |
| no facility party | `facility_party_id()` as a default | deflationary: not-null violation | yes, 0003:76-79 |
| empty `term` | `terms()` kernel.ts:100, picker 0-row branch | deflationary: the picker says so and opens add-inline | yes, C-6 |
| empty `template` | `generate_inferred_history` returns 0 | deflationary: zero is truthful | yes, S-17 |
| an operation the kernel does not know | effect-only dispatch | deflationary: records and drives nothing | yes, S-15 |
| empty `app_user` | `claim_account` 0005:61 | inflationary and intended: first claimant is admin | yes, 0005:56-58 |
| both sides null in a predicate field | `topping_check` 0004:491-492 | inflationary and intended | yes, 0004:448-450 |
| no lineage at all | `block_composition` returns no rows | deflationary | yes, spec untyped floor |
| missing config env vars | `readConfig` env.ts:145 | deflationary: throws at startup | yes |
| unresolvable operation id | `nodeEvents` kernel.ts:270 | deflationary: "unknown operation" | no, and it is correct |
| empty `party`, `location`, `vessel`, `block`, `task`, `lineage`, `vessel_code`, `task_claim_log` | first-run screens | deflationary: the walk is ordered by what the schema refuses | yes, walk.ts:43-49 |

---

## EXPLOITABLE

**R-2-1. Deactivating a client party grants that client's login read of the entire cellar.**
*Verdict:* EXPLOITABLE.
*Locator:* `supabase/migrations/0003_parties_and_products.sql:265-276`, `:282-283`.
*What is wrong:* `is_facility_user()` is `is_admin() or coalesce((select kind = 'facility' from party where app_user_id = auth.uid() and active), true)`. The `coalesce` turns "no matching party row" into full facility standing. `active` is inside the subquery, so setting `party.active = false` removes the row from the subquery and the absence resolves to `true`. The comment above it names one intended case, the intern with no party at all; it does not name the case where a party row exists and is switched off. Deactivation should narrow standing and instead removes the narrowing.
*How it surfaces:* a custom crush client finishes their vintage, an admin unticks `active` on their party, and the next time that client signs in `node_read` admits every lot in the cellar including both labels and the other client's. Nothing logs it and the screen looks normal. The same coalesce means a departed employee whose `app_user.active` is cleared still reads everything, because `app_user.active` is consulted only by `is_admin()`.
*Resolves when:* absence of a party row and presence of an inactive one are distinguished at the point standing is computed, and `tests/schema_assertions.sql` exercises a deactivated client.
*Load-bearing:* yes. Ownership is stated at `0003:20-29` as the thing that drives what a client is permitted to see, and this is the one function that decides it.

**R-2-2. `enable_signup = false` in the repository's own config refuses the acceptance test.**
*Verdict:* EXPLOITABLE.
*Locator:* `supabase/config.toml:49` and `:52`, against `packages/cellar/src/walk.ts:43-45` and `:127-134`.
*What is wrong:* the walk's stated acceptance test is a stranger's first run from an empty database and a fresh account. `claim_account` makes the first account admin, and the only client path to an account is `signUp` at `kernel.ts:40-43`. Both `[auth] enable_signup` and `[auth.email] enable_signup` are false, so GoTrue refuses the sign-up, `app_user` stays empty, `is_admin()` is false for everyone, and the facility party can never be created. The config comment at `:47-48` argues the case for closing signup and does not notice that it closes the bootstrap with it.
*How it surfaces:* `supabase start`, open the app, tap "Create an account", get "Signups not allowed for this instance". The message points at the instance, so the first place anyone looks is the hosted project rather than `supabase/config.toml` in this repo. The walk session report lists sign-up as unproven at `docs/session-reports/2026-09-08-walk.md:144` and worries about email confirmation, not about this.
*Resolves when:* either the first run is bootstrapped by something other than self-service sign-up, or signup is open for the duration of the claim and the config says which.
*Load-bearing:* yes. It is the first screen of the only built path.

**R-2-3. Only `node_read` was narrowed. `placement`, `event` and `lineage` still read blanket-true.**
*Verdict:* EXPLOITABLE.
*Locator:* `0002_derived_and_rls.sql:262-272` creates `%I_read ... using (true)` for twelve tables. `0003_parties_and_products.sql:280` drops exactly one of them.
*What is wrong:* the client-scoping policy hides the `node` row and nothing else. A client login still selects every row of `placement` (node_id, vessel_id, volume, from_at), every row of `event` (subject_id, operation, `at`, and the whole `data` jsonb carrying brix, pH, TA, dose and material), and every row of `lineage`. `vessel_state` is `security_invoker`, so for a lot the client may not see the node columns come back null while `p.node_id`, `current_volume_l` and `filled_at` come back populated: the view reports an occupied vessel with an unnameable lot rather than hiding it. The comment at `0003:278-279` says "A client sees their own lots and is not told how many others exist."
*How it surfaces:* silently, never, from inside the app. Over PostgREST it is one `GET /rest/v1/event?select=*` with a client's token.
*Resolves when:* the read policies on `placement`, `event` and `lineage` are joined to `node` the way `node_read` is, and an assertion counts client-visible rows in each of the three rather than in `node` alone.
*Load-bearing:* yes. S-7 at `docs/sorry-ledger.md:56-59` reports this half as holding, and the status ledger grades RLS "In progress" on that basis.

**R-2-4. `max_rows = 1000` truncates the vessel list silently, and the home screen reports the truncation as a count.**
*Verdict:* EXPLOITABLE.
*Locator:* `supabase/config.toml:12`; `packages/core/src/kernel.ts:190-194`; `packages/cellar/src/walk.ts:235-247`.
*What is wrong:* `vessels()` is `from("vessel_state").select("*").order("name")` with no range and no count. PostgREST caps the response at `max_rows` and returns 200. `homeScreen` then renders `summaryRow("Vessels", String(kit.length))` and `"Vessels with wine in them"` from the truncated array. A thousand barrels is a mid-size barrel program, and the barrel room is exactly what this walk exists to inventory.
*How it surfaces:* the cellar count stops rising at 1000 and the list stops at the barrel whose name sorts 1000th. There is no error and no marker. The person walking the cellar concludes the last few hours of scanning did not save.
*Resolves when:* the read is paged or ranged, and the summary distinguishes "the rows I hold" from "the rows that exist".
*Load-bearing:* yes for the walk, which is the one thing graded past Specified in Stage 1.

**R-2-5. The "keep" pin on every picker is dead code.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/cellar/src/pickers.ts:91-94` and `:172-174`; `sticky.ts:215-221`.
*What is wrong:* `const wanted = selectId ?? select.value ?? (options.stickyKey ? stickyValue(options.stickyKey) : "")`. `HTMLSelectElement.value` is typed `string` and is `""` when nothing is selected, never `null` or `undefined`, so `??` always takes it and the sticky branch is unreachable. On a freshly built select `wanted` is `""`, the guard `if (wanted && ...)` is false, and nothing is preselected. `remember()` still writes the map, `pinToggle` still ticks, and the value is never read back. TypeScript 5.9 does not flag this: the 5.6 unreachable-`??` check is syntactic and a property access typed `string` is not one of the forms it catches, so `bun run typecheck` is clean and the report's claim that it is clean is accurate.
*How it surfaces:* someone ticks "keep" on Type, Cooper, Wood and Location before starting a rack of fifty identical barrels, and every barrel after the first comes up unset anyway. The four `field()`-backed pins (capacity, fill count, toast, vintage) work, because those read `stickyValue()` directly at construction, so the failure looks like a partial one and reads as flakiness rather than as a bug.
*Resolves when:* the fallback chain tests `select.value` for emptiness rather than for nullishness.
*Load-bearing:* no in the schema sense, yes for the thing the walk is timed against. `sticky.ts:205-206` puts the whole justification on fifty vessels being an hour of work.

**R-2-6. Every authenticated user can read every vessel photo.**
*Verdict:* EXPLOITABLE.
*Locator:* `0005_account_and_walk.sql:314` (the comment), `:325-327` (the policy).
*What is wrong:* the comment reads "Private. A photo of a barrel shows a chalk mark with a client's lot on it." The policy immediately under it is `for select to authenticated using (bucket_id = 'vessel-photos')`, which is every signed-in account including a custom crush client's login. The bucket is private in the sense that it is not world-readable over a public URL, and that is the only sense. `vessel_photos_insert` is the same shape, so any authenticated account can also write objects into it at any path.
*How it surfaces:* silently, never, unless someone lists the bucket. The chalk mark names the other client's lot.
*Resolves when:* the select policy joins the object path back to a vessel and applies the same ownership test `node_read` applies, and an assertion exercises it.
*Load-bearing:* yes, on the same axiom R-2-1 and R-2-3 sit on.

**R-2-7. An untouched variety picker asserts the first seeded variety onto the lot.**
*Verdict:* EXPLOITABLE.
*Locator:* `pickers.ts:95-105` (no empty option unless `allowEmpty`), `walk.ts:566` (variety picker, no `allowEmpty`), `walk.ts:471-475` (`ready()` checks type and name only), `walk.ts:638`.
*What is wrong:* a `<select>` with no placeholder option selects its first option. `0004:101-107` seeds six varieties ordered by `sort_order`, so the variety picker opens on Riesling and `variety.value()` returns Riesling's id whether or not anyone looked at it. `form.ready()` validates the vessel type and the vessel name and does not validate variety or product type. Absence of a choice is written to `node.variety_id` as a choice.
*How it surfaces:* partially visible. `autoName()` at `walk.ts:592-596` builds the lot name from `variety.label()`, so the name field shows "Riesling 2024" and an attentive person catches it. An inattentive one, or one who typed a lot name first and thereby set `dataset.touched`, does not: the name stays theirs and the variety is silently Riesling. It then selects which template `generate_inferred_history` matches at `0005:191-195`, so the wrong variety generates the wrong inferred history.
*Resolves when:* a picker whose value is required opens on no selection, and `ready()` covers every field the payload sends.
*Load-bearing:* yes. Variety drives composition, templates and labelling.

**R-2-8. A recorded volume of zero is written as null, and null renders as "unrecorded".**
*Verdict:* EXPLOITABLE.
*Locator:* `walk.ts:642`, `:644`, `:458`, `:466`, and the render at `:713` and `:283`, `:773-776`.
*What is wrong:* `volume.value() ? Number(volume.value()) : null` is a truthiness test on the string. `"0"` is truthy, so a typed zero survives; but the field is `type: "number"` and an empty field also yields `""`, so the two cases are only distinguished by the person having typed something. The harder half is the render: `vessel?.current_volume_l ? \`${...} L\` : "unrecorded"` treats a stored `0` as absent, so a vessel legitimately recorded as drained displays identically to one nobody measured. Same pattern on `capacity_l` and `fill_count`, where a new barrel's fill count of 0 becomes null.
*How it surfaces:* a drained tank on the vessel page reads "unrecorded" instead of "0 L", and there is no way from the screen to tell which vessels were measured.
*Resolves when:* the null test is `=== null` or `Number.isFinite`, not truthiness, on both the write and the render.
*Load-bearing:* yes for S-8. Every volume figure the app produces is already unreconciled; this makes measured-zero and never-measured indistinguishable at the source.

---

## LATENT

**R-2-9. `node_bin_shares` has no cycle guard and its sibling traversal has one.**
*Verdict:* LATENT.
*Locator:* `0002:34-40` (`union all`, no `cycle` clause, no depth bound) against `0002:80-84` (`union`).
*What is wrong:* the composition traversal recurses through `lineage` with `union all`, which does not deduplicate, so a cycle never terminates. Fractions shrink but the recursion does not stop. `inferred_fraction` two functions later walks the same edges with `union`, which does. Nothing in the schema prevents a cycle: `no_self_parent` at `0001:201` blocks the length-1 case only, and `lineage_closes_parent` closing both nodes does not stop the second insert.
*How it surfaces:* the specific change that reaches it is any write path for `lineage`, which is the press and blend screens, both graded Specified. Two inserts in the wrong order, or a correction entered backwards, and `block_composition` on anything downstream hangs until `statement_timeout`.
*Resolves when:* the traversal carries a `cycle` clause or a depth bound, or an insert-time check refuses an edge whose child is already an ancestor of its parent.
*Load-bearing:* yes, at the moment lineage becomes writable.

**R-2-10. Composition normalizes over the parents it found, with no residual row.**
*Verdict:* LATENT.
*Locator:* `0002:29-46`, `:48-59`; `0004:257-268`.
*What is wrong:* `node_bin_shares` sums whatever paths exist. It never asserts that the shares of a node sum to 1 and never reports the shortfall. `lineage.fraction` is constrained per-edge to `(0,1]` at `0001:198` and there is no constraint across the edges of one child. A lot assembled from three parents where one edge was not written returns two rows summing to, say, 0.7, and the caller receives them as the composition. This is the specific shape the prompt names: found rather than exist.
*How it surfaces:* silently, never, from inside the app: no client calls it. Over PostgREST it is a callable RPC today. The reader that reaches it is the TTB and labelling path, which is the one where a percentage that sums to 0.7 gets rendered as a percentage.
*Resolves when:* the function returns the residual as a row, or a caller-visible total, so that "30% of this barrel is unaccounted for" is representable.
*Load-bearing:* yes. `0002:27-28` states the function answers the labelling question.

**R-2-11. `block_composition` inner-joins `block`, dropping every bin with no block.**
*Verdict:* LATENT.
*Locator:* `0002:53-57` (`join block b on b.id = n.block_id`) against `0004:265` (`left join term t on t.id = n.variety_id`).
*What is wrong:* `node.block_id` is nullable at `0001:168` and nothing requires it on a bin: `block_only_on_bins` constrains where it may appear, not whether it must. A bin with no block is dropped from the join entirely, so a blend that is half Perlstaad and half an unblocked bin returns one row at 0.5 and no indication that the other half exists. 0004 recreated `variety_composition` with a left join precisely so an unknown variety returns a row instead of vanishing. `block_composition` was never touched and still vanishes.
*How it surfaces:* silently, never, today. The asymmetry between the two functions is the tell: one was fixed, the sibling was not, and there is no note saying the difference is deliberate.
*Resolves when:* the join is outer and a null block is an explicit row, matching what 0004 did to its sibling.
*Load-bearing:* yes, same path as R-2-10.

**R-2-12. Composition computed under RLS normalizes over the visible parents.**
*Verdict:* LATENT.
*Locator:* `0002:29-46` (plain `stable`, not `security definer`), against `0003:282-283`.
*What is wrong:* `node_bin_shares` runs with the caller's rights, so the recursive join to `node` is filtered by `node_read`. A client calling `block_composition` on their own blend that draws on facility-owned bins gets shares over the subset they may see. The number is smaller than the truth and is shaped exactly like a complete answer. The absence caused by a policy is indistinguishable from the absence caused by a missing edge, which is R-2-10 again with an authorization cause.
*How it surfaces:* the specific change that reaches it is any screen that shows composition to a client party.
*Resolves when:* the function is `security definer` with its own explicit scoping, or the caller is told the traversal was filtered.
*Load-bearing:* yes, once a client-facing screen exists.

**R-2-13. `topping_check` approves everything when the operation carries no predicate.**
*Verdict:* LATENT.
*Locator:* `0004:442-447`, `:491-498`.
*What is wrong:* `fields` is read from `t.attributes -> 'predicate' -> 'match'`. `array(...)` over an empty jsonb path yields `'{}'`, so the `coalesce` around it never fires and `fields` is the empty array. The `foreach` then runs zero times and the function returns `true, 'ok'`. Every seeded operation except `topping` has no `predicate` key at all, so `topping_check(src, vessel, term_id('operation','rack'))` approves any pour into any occupied vessel. A fork that defines its own topping-shaped operation and forgets the predicate gets unconditional approval rather than a refusal or an error. The absence of a rule reads as a rule that permits.
*How it surfaces:* the specific change that reaches it is topping mode, graded Specified, calling the function with an operation id that is not the seeded `topping`. The test at `tests/schema_assertions.sql:204-218` only ever edits the predicate's contents, never removes it.
*Resolves when:* a missing predicate is a distinct answer from a satisfied one, refused or raised rather than approved.
*Load-bearing:* yes. Spec section 5 puts the whole value of topping mode on checking before pouring rather than after.

**R-2-14. `next_cap_action` instructs punchdown for a node that does not exist.**
*Verdict:* LATENT.
*Locator:* `0004:391-400`.
*What is wrong:* `select attributes -> 'cap_rule' into rule from node where id = p_node_id` leaves `rule` null when the select matches no row, which is the same state as a node that exists and has no `cap_rule`, which is the same state as a `cap_rule` whose `sequence` key is misspelled (`array()` over the missing path yields `'{}'` and `array_length` yields null). All three collapse to `seq := array['punchdown']` and the function returns the punchdown term. Three distinct absences, one confident instruction.
*How it surfaces:* the specific change that reaches it is cap management mode. Scan a barcode that resolves to nothing, or to a white lot in a tank with no cap, and the app says punchdown. `0002:175-177` states this is the first place the app directs rather than records.
*Resolves when:* a nonexistent node raises, a node with no rule returns no row, and a malformed rule raises, so that the three are separable.
*Load-bearing:* yes, by the spec's own framing of the mode.

**R-2-15. `per_day` is documented as part of `cap_rule` and is never read.**
*Verdict:* LATENT.
*Locator:* `0002:178-179` documents `{"cap_rule": {"sequence": [...], "per_day": 2}}`; `0004:380-417` reads `sequence` and nothing else.
*What is wrong:* `done_today` counts every punchdown and pumpover since midnight and indexes into the sequence modulo its length. Nothing compares the count to `per_day`, so the function never answers "done for today" and keeps cycling the sequence indefinitely.
*How it surfaces:* cap management mode directs a fourth punchdown on a lot configured for two a day, and the count of directed operations exceeds what the protocol says. The count also includes events stamped `inferred`, so a generated history can satisfy today's quota.
*Resolves when:* either `per_day` is read and the function can return no row, or `per_day` is removed from the documented shape.
*Load-bearing:* yes for the mode, no for the schema.

**R-2-16. `generate_inferred_history` returns zero for three reasons and the client asserts one.**
*Verdict:* LATENT.
*Locator:* `0005:187-189` (null variety), `:197-199` (no template), `:203-215` (a template with no steps); `walk.ts:695-698`; `docs/sorry-ledger.md:143-152`.
*What is wrong:* the function returns the integer 0 for a node with no variety, for a variety with no active template, and for a matched template that has no `template_step` rows. The result screen renders `generated === 0` as "No template exists for this variety yet, so no history was generated. That is an honest zero rather than a failure: see sorry S-17." S-17 itself is careful and names two of the three: it says zero is indistinguishable from a template that exists and failed to match. Neither S-17 nor the client names the third, and the client picks one of the three and states it as fact.
*How it surfaces:* the moment the six protocols are encoded. Someone seeds a template, forgets the steps or misspells the variety, walks a barrel, and the screen tells them the thing they just built does not exist. The assertion at `tests/schema_assertions.sql:273-277` reproduces the same conflation: it asserts 0 and labels it "with no template for the variety, no history is invented".
*Resolves when:* the function returns which of the three it did, or the screen stops naming a cause it cannot know.
*Load-bearing:* yes. S-17 itself says the risk is that zero gets read as a generator bug and someone looks in the wrong place; this is the inverse, a generator bug read as an honest zero.

**R-2-17. `offset_from` is never read, and a null `offset_interval` becomes zero.**
*Verdict:* LATENT.
*Locator:* `0001:296-298` defines `offset_from text not null default 'previous'` with the comment "interval from the previous step, or from stage entry"; `0005:206` is `at_time := at_time + coalesce(step.offset_interval, interval '0')`.
*What is wrong:* the generator accumulates from the previous step unconditionally. A step carrying `offset_from = 'stage_entry'` is silently treated as `'previous'`, and the column is a free-text field with no check constraint, so any value at all is accepted and ignored. Separately, a step with a null `offset_interval` lands at the same instant as its predecessor: the absence of a duration is written as a duration of zero, producing a definite timestamp from no information. S-2 at `sorry-ledger.md:26-30` names conditional intervals and does not name either of these.
*How it surfaces:* the moment templates are encoded. Two generated events share a timestamp, and `next_cap_action`'s `done_today` counts both.
*Resolves when:* `offset_from` is either read or removed, and a step with no interval is refused rather than defaulted.
*Load-bearing:* no. Inferred history is stamped `inferred` and grounds nothing, which is the floor working.

**R-2-18. Nothing writes `placement.to_at`, so the first placement holds the vessel forever.**
*Verdict:* LATENT.
*Locator:* `0001:233` (`to_at timestamptz` nullable), `:241-242` (`unique index ... where to_at is null`), `0005:277-278`; no `update placement` anywhere in the tree.
*What is wrong:* null `to_at` means currently placed, which the spec states at line 120. The partial unique index then permits exactly one open placement per vessel. No migration and no client code ever sets `to_at`, so once `create_vessel_with_wine` writes a placement, that vessel cannot receive another one. The absence of an end time is an assertion of ongoing occupancy that nothing can retract.
*How it surfaces:* the specific change that reaches it is the rack or press screen. The insert fails on `placement_one_lot_per_vessel` with a unique violation naming an index, which reads as a duplicate-barrel error rather than as "the previous lot was never emptied out".
*Resolves when:* a movement path closes the outgoing placement in the same transaction as it opens the incoming one.
*Load-bearing:* yes for Stage 1 press, which is the screen the build order says must be solid before harvest.

**R-2-19. `event.task_id` is a second unconstrained id and S-4 names only `subject_id`.**
*Verdict:* LATENT.
*Locator:* `0001:263` (`task_id uuid`, no `references`); `sorry-ledger.md:39-42`; `package.json:15`.
*What is wrong:* `task_id` has no foreign key and, unlike `subject_id`, no stated reason for not having one. `task` exists in the same migration and a plain FK is available. S-4 accepts the cost of polymorphism for `subject_id` and makes `doctor` the compensating control; the `doctor` stub names `subject_id` alone, so nothing is even planned to check `task_id`.
*How it surfaces:* silently, never. A task-completion event pointing at a deleted or mistyped task id reads as a completed task with no task.
*Resolves when:* either the FK is added, or `task_id` joins S-4 and `doctor`'s scope.
*Load-bearing:* no today. `task_id` is written by nothing yet.

**R-2-20. T0-4 is enforced on insert only.**
*Verdict:* LATENT.
*Locator:* `0005:119-125` (two `before insert` triggers), `0005:131-155` (`confirm_event`), `0002:293-295` (`event_admin_update`), `0002:305-308` (`node_admin_update`).
*What is wrong:* `refuse_self_granted_standing` fires on insert. `confirm_event` is the intended verifier path and restricts the transition to `inferred -> confirmed`. But `event_admin_update` lets an admin write `provenance = 'confirmed'` with a plain `UPDATE`, skipping both the trigger and the inferred-only rule, so an `observed` event can be promoted to `confirmed` and a `confirmed` one can be written without any confirming act. `node.provenance` has no verifier function at all and the same admin update path reaches it. The migration header claims T0-4 is enforced "at the write path"; insert is one of two.
*How it surfaces:* an admin correcting a row in Studio, which CLAUDE.md:67-70 already forbids for schema and does not forbid for data.
*Resolves when:* a `before update` trigger constrains the provenance transition the way `confirm_event` does.
*Load-bearing:* yes. T0-4 is the axiom the whole provenance scheme rests on and `0005:101-104` argues that a discipline is not a boundary.

**R-2-21. `inferred_fraction` returns 0 for a lot with no events, which reads as fully witnessed.**
*Verdict:* LATENT.
*Locator:* `0002:85-91`.
*What is wrong:* `coalesce(count(*) filter (where provenance = 'inferred') / nullif(count(*), 0), 0)`. The `nullif` correctly refuses to divide by zero and the `coalesce` then turns "no events at all" into 0.0. On the scale this function defines, 0 is the best possible answer: none of this was invented. A backfilled barrel with no history returns the same 0 as a barrel every step of which was witnessed. The absence inflates confidence.
*How it surfaces:* the reader is the provenance audit view, Stage 3, graded Specified, described in the status ledger as "What fraction of a number was never witnessed". Every lot the walk creates has no events, so on the first run every lot reports perfect provenance.
*Resolves when:* no events returns null or a distinguishable sentinel rather than zero.
*Load-bearing:* yes for the audit view, which exists to make exactly this distinction.

**R-2-22. A template with a null `variety_id` never matches anything.**
*Verdict:* LATENT.
*Locator:* `0005:88-92` (`variety_id` nullable, no check), `0005:191-195` (`where t.active and t.variety_id = n.variety_id`).
*What is wrong:* `template.variety_id` is nullable and `template_variety_name_key` is `unique (variety_id, name)`, so a variety-less template is insertable. The match is an equality, and `null = <uuid>` is null, so such a template is unreachable by construction. The generator returns 0 and the screen says no template exists, which is true in the sense that matters and false in the sense the person meant.
*How it surfaces:* an admin building an all-varieties baseline protocol gets zero events and no error.
*Resolves when:* `variety_id` is not null, or a null variety is defined as a fallback match.
*Load-bearing:* no. It costs the template, nothing else.

**R-2-23. Add-inline cannot ever create an operation term.**
*Verdict:* LATENT.
*Locator:* `0004:60-64` (`operation_has_an_effect`), `packages/core/src/kernel.ts:105-118` (`attributes` defaults to `{}`), `pickers.ts:71-82` (calls `addTerm(kind, label)` with two arguments).
*What is wrong:* the check requires `attributes ->> 'effect'` to be one of four values whenever `kind = 'operation'`. Every add-inline path calls `addTerm` without attributes, so the insert fails the check. C-6 at `compost-ledger.md:52-64` kills the term configuration screens on the grounds that "add-inline on every picker" covers the case that blocks a fresh install, and names operations in the list of things those screens would have managed.
*How it surfaces:* the specific change that reaches it is any picker over `kind = 'operation'`. There is none today, so the failure is a raw check-violation message on a screen that does not exist yet.
*Resolves when:* either an effect picker sits inside the add-inline form for operations, or C-6's reactivation condition is met.
*Load-bearing:* no today. It is the one vocabulary kind the surviving fragment of C-6 cannot reach.

**R-2-24. `slug()` returns the empty string for a label with no ascii.**
*Verdict:* LATENT.
*Locator:* `kernel.ts:122-130`, against `0004:55` (`unique (kind, value)`).
*What is wrong:* the slug strips combining marks, lowercases, and replaces every non `[a-z0-9]` run with `_`, then trims leading and trailing underscores. A label with no latin characters reduces to `""`. The term inserts with an empty machine key, and the second such label in the same kind collides on the unique constraint. The absence of anything transliterable produces a valid-looking row rather than a refusal, and then aliases every other untransliterable label to it.
*How it surfaces:* a fork in a non-latin script, or a cooper whose name is written in one. The error surfaced to the user is the raw Postgres duplicate-key text, via `pickers.ts:80`.
*Resolves when:* an empty slug falls back to something derived from the id, or is refused with a message about the label.
*Load-bearing:* no for this winery. Yes for the stated intent at CLAUDE.md:20-22 of handing this to other winemakers.

**R-2-25. `uploadVesselPhoto`'s `?? "jpg"` is unreachable.**
*Verdict:* LATENT.
*Locator:* `kernel.ts:279-280`.
*What is wrong:* `file.name.split(".").pop()?.toLowerCase() ?? "jpg"`. `String.split` never returns an empty array, so `pop()` never returns `undefined` and the `?? "jpg"` never fires. For a file with no dot, `pop()` returns the whole filename, so a camera capture named `IMG_0042` produces the object path `<uuid>/photo.img_0042`. The intended default for a missing extension is written and cannot run.
*How it surfaces:* photos land at paths whose extension is a filename. `vesselPhotoUrl` still signs them and the browser still renders by content type, so the only visible symptom is unreadable object names, until something keys off the extension.
*Resolves when:* the extension is taken only when `name.includes(".")`, or derived from `file.type`.
*Load-bearing:* no.

**R-2-26. Cellar users are shown admin-only actions and pushed into a form they cannot submit.**
*Verdict:* LATENT.
*Locator:* `walk.ts:248-253` (home buttons, no role test), `0002:278-285` (`vessel`, `location`, `term` are admin-write), `pickers.ts:104` (`if (rows.length === 0) toggle(true)`), `0004:513-516`.
*What is wrong:* `facilityScreen` is the one place the client checks `user.role`, at `walk.ts:200`. Everything after it offers every action to everyone. A cellar user tapping "Add a vessel and put wine in it" fills in ten fields, uploads a photo, and gets a raw RLS refusal on the first insert. Worse, an empty picker auto-opens its add-inline form, so the client actively directs a cellar user into an insert `term_admin_write` will refuse. The migration comment at `0004:513-516` reasons that add-inline needing an admin is fine "which the walk is", and the client does not encode that.
*How it surfaces:* the first time a second account walks the cellar. The photo is uploaded before the insert is attempted, at `walk.ts:517` and `:630`, so a failed save leaves an orphaned object in the bucket.
*Resolves when:* the home screen gates admin-only actions the way the facility screen does, and explains the wall rather than only failing at it.
*Load-bearing:* no for data integrity, the transaction rolls back. Yes for the stranger's first run, which is the stated acceptance test.

---

## DIVERGENT

**R-2-27. 0005 states the migrations stay applicable to a bare database; 0001 and 0002 make that false.**
*Verdict:* DIVERGENT.
*Locator:* `0005:302-306` against `0001:88` and `0002:332-334`.
*What is wrong:* the storage block is guarded on the `storage` schema existing, and the stated reason is that "these migrations have to stay applicable to a bare database for anyone verifying them without Docker". Two earlier and unguarded dependencies contradict it: `app_user.id` references `auth.users(id)` at `0001:88`, and `0002` adds three tables to the `supabase_realtime` publication. On a bare Postgres, 0001 fails at the first table and 0002 would fail at the last statement. The walk session report at line 94 says the verification ran against "a scratch Postgres 16 with a minimal Supabase auth shim", which is the accurate description and is not what 0005 claims.
*How it surfaces:* someone takes 0005's comment at face value, runs the migrations against a bare Postgres to check them, and fails at `0001:88` with nothing telling them a shim is expected.
*Resolves when:* either the same guard shape covers the realtime block and the auth dependency is stated as a prerequisite, or the comment says "a Postgres with an auth shim" instead of "a bare database".
*Load-bearing:* no for the code. Yes for the claim, which is the review target rule 2 names.

**R-2-28. `bun run test` is in the definition of done and is not a script.**
*Verdict:* DIVERGENT.
*Locator:* `CLAUDE.md:89` against `package.json:10-19`.
*What is wrong:* the definition-of-done block lists `bun run test` between `lint` and `doctor`. `package.json` has `typecheck`, `lint`, `format`, `db:reset`, `db:test`, `doctor`, `dev`, `build`, and no `test`. The nearest thing is `db:test`, which is the schema assertions and is already covered by the `psql` line above it. `doctor` in the same block is honest about being unimplemented and exits 1 with a pointer to S-4; `test` is not, so it reads as a check that exists.
*How it surfaces:* anyone running the block gets "script not found" and has to guess whether that is the point.
*Resolves when:* the line names `db:test`, or a `test` script exists, or the line is removed.
*Load-bearing:* no.

**R-2-29. CLAUDE.md says five compost entries; there are six.**
*Verdict:* DIVERGENT.
*Locator:* `CLAUDE.md:54-55` against `docs/compost-ledger.md:13,24,35,43,52,66`.
*What is wrong:* "Check the compost ledger before proposing an approach. Five entries, each with a reactivation condition." There are six, C-1 through C-6, with C-6 filed out of order between C-4 and C-5. Two of the six carry no reactivation condition: C-4 has a surviving fragment and no reactivate line, C-5 has neither. So both halves of the sentence are wrong.
*How it surfaces:* an agent counts five, finds six, and cannot tell which is the one CLAUDE.md did not mean.
*Resolves when:* the count follows the ledger, or the ledger stops being counted in a second place.
*Load-bearing:* no, and it is the cheapest possible check on the convention at `CLAUDE.md:112-115` that both directions of a dependency stay accurate.

**R-2-30. The spec's topping fields and the seeded predicate's fields are different sets.**
*Verdict:* DIVERGENT.
*Locator:* `packages/cellar/docs/spec.md:191-193` ("Variety, color, and vintage compatibility is checked") against `0004:149-152` (`{"match": ["variety", "vintage", "product_type"]}`).
*What is wrong:* the spec names three fields and the predicate names three fields and only two of them are the same. `color` does not exist anywhere in the schema; `product_type` is wine, cider, vermouth, other, which is a different axis. Which of the two is wrong is a domain question: a rosé and a red of the same variety and vintage are compatible under the predicate and not under the spec.
*How it surfaces:* topping mode approves a pour the spec says it should refuse, or the reverse, depending on which document the reviewer read.
*Resolves when:* the winemaker says whether colour is a separable attribute of a lot. It is the kind of question `CLAUDE.md:123-127` says to ask rather than answer.
*Load-bearing:* yes if colour is real, because the check runs at the one moment it can still prevent the mistake.

**R-2-31. An assertion's message claims more than the assertion checks.**
*Verdict:* DIVERGENT.
*Locator:* `tests/schema_assertions.sql:382-384`.
*What is wrong:* `select count(*) into n from node; if n = 0 then raise ...; end if; perform test_ok('a cellar user linked to no party sees the whole cellar')`. The check is `n <> 0`, which proves the user sees at least one node, not every node. The client-scoping assertion twenty lines later does compare `visible` against `total` and is the shape this one should have. The report at `docs/session-reports/2026-09-08-walk.md:118` repeats the message as a verified fact.
*How it surfaces:* a future narrowing of `node_read` that accidentally scopes the intern would leave this assertion green.
*Resolves when:* the assertion compares against the unfiltered count, as its neighbour does.
*Load-bearing:* no today. It is one of the 28 the status ledger grades "Built and verified".

---

## BY DESIGN

**R-2-32. Null compared to null passes `topping_check`.** Named at `0004:448-450`: "A predicate naming a field that is absent here compares null to null and passes, which is the untyped floor behaving as designed." Two lots with no variety top into each other. The comment is accurate and the locator is where the prompt asks it to be. Worth one line of caution: `jsonb_build_object` renders a SQL null as JSON `null`, so the comparison is `'null'::jsonb is distinct from 'null'::jsonb`, which is false for a different reason than the comment implies. The outcome is the one the comment describes.

**R-2-33. Composition of a node with no lineage is empty.** Named at `packages/cellar/docs/spec.md:105-108`: a backfilled lot "grounds nothing about its own history until lineage is supplied. This is the untyped floor: nothing is refused, and what is missing costs exactly the capability it supports." Every lot the walk creates is in this state and `block_composition` on it returns no rows. Deflationary and named. R-2-10 is the case this does not cover: partial lineage, where the answer is non-empty and wrong.

**R-2-34. An empty `app_user` makes the next claimant admin.** Named at `0005:56-58`, including the race and why the advisory lock closes it. Inflationary by intent, and the only alternative is a bootstrap outside the app. Worth recording that the same property applies after the fact: if every `app_user` row is deleted, the next claim is admin again.

**R-2-35. S-15 and S-17 hold as written.** An unknown operation records and drives nothing (`tests/schema_assertions.sql:180-189` asserts it). No seeded template means zero generated events, and zero is truthful. Both are deflationary and both are named. S-17's own text anticipates two of the three ways the zero arises; see R-2-16 for the third.

---

## NOT A DEFECT

**R-2-36. The empty anon key in `.env.example` fails loudly at startup.** `apps/web/.env.example:4` ships `VITE_SUPABASE_ANON_KEY=` with no value, and `readConfig` at `env.ts:145` tests `!anonKey`, so a verbatim copy throws `MissingConfig` with the filename and the example to look at, before anything renders. `apps/web/src/index.ts:143-154` renders that message rather than a blank page. Checked, and it holds.

**R-2-37. An unresolvable operation id renders as "unknown operation".** `kernel.ts:270`, `labels.get(e.operation_id) ?? "unknown operation"`. The absence is shown as an absence rather than dropping the row or blanking the label. Checked, and it holds.

**R-2-38. No facility party is a not-null violation, not a silent null owner.** `0003:80-81` makes `node.owner_id` not null with a default that resolves to null when no facility party exists, so the insert is refused. Asserted at `tests/schema_assertions.sql:77-84`. The reasoning is recorded at `0003:72-79` and again at `docs/session-reports/2026-09-08-scaffold.md:39-43`. One consequence worth stating and not a defect in this tree: because the default is evaluated for existing rows, `0003` can only be applied while `node` is empty, which `0004:30` states as the standing condition for the whole sequence.

---

## UNVERIFIED

**R-2-39. Whether Biome 2.5 accepts `linter.rules.preset`.**
*Locator:* `biome.json:17-22`.
The config sets `"rules": { "preset": "recommended" }`. The key Biome documents for this is `recommended`, a boolean. If `preset` is not a key in the 2.5.12 schema the file points at, Biome either errors on the unknown key or ignores it and falls back to its default rule set, which is `recommended` anyway, so lint would pass either way and the file would be saying nothing. Outbound fetch of `https://biomejs.dev/schemas/2.5.12/schema.json` is refused by this environment's proxy and `@biomejs/biome` is not installed in the clone.
*What would check it:* `bun install && bunx biome check --verbose .` in the repo, and reading whether the run reports an unknown configuration key.

**R-2-40. Whether `foreach` over a null array raises in `topping_check`.**
*Locator:* `0004:442-447`, `:491`.
If `term_id('operation','topping')` resolves to nothing, because a fork renamed or removed the seeded row, the `select ... into fields` matches no row and leaves `fields` null rather than `'{}'`. Whether `foreach f in array fields` over a null then iterates zero times, which returns `true, 'ok'` and makes R-2-13 strictly worse, or raises, decides the direction of that particular null. I did not execute it and will not guess.
*What would check it:* `do $$ declare a text[] := null; f text; begin foreach f in array a loop raise notice '%', f; end loop; raise notice 'survived'; end $$;` on Postgres 16.

**R-2-41. Whether `insert into auth.users (id)` alone satisfies a real Supabase instance.**
*Locator:* `tests/schema_assertions.sql:111-114`.
The assertions insert three auth users with nothing but an id. The walk report at line 94 says the run used "a minimal Supabase auth shim", so what passed is the shim's `auth.users`, not GoTrue's. If the real table has not-null columns without defaults, the assertion file does not run against a real instance and the 28 passing assertions are 28 assertions against a stand-in.
*What would check it:* `supabase db reset && bun run db:test` against a started local stack, which is the acceptance criterion the walk report at line 135-136 already lists as still outstanding.

Everything else the environment blocks is already named by the repository and is not re-listed here: `supabase db reset` unrun, PostgREST wire formats for `claim_account` and `create_vessel_with_wine`, GoTrue issuing a token, the storage bucket and its policies, and the camera. `docs/session-reports/2026-09-08-walk.md:130-152` is accurate about all of them.

---

## What is sound

The provenance boundary is real: `refuse_self_granted_standing` on insert plus `confirm_event`'s inferred-only transition is a genuine boundary rather than a client discipline, and the composite `(id, kind)` foreign keys make "the picker only offers varieties" into something the database refuses. The `term` migration's split between a fixed kind enum and free values within a kind is the right cut and the reasoning at `0004:19-30` is the reasoning. The compost and sorry ledgers are unusually honest documents, and the walk session report's "what could not be exercised" table is the part of this repository that most deserves to be copied elsewhere.

The findings above concentrate in two places, and both are places the repository's own documents say it has covered: the direction of error on an absent authorization row, and the direction of error on an absent lineage edge.
