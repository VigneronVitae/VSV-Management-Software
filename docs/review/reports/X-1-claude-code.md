# X-1: the instrument

**Target:** github.com/VigneronVitae/VSV-Management-Software, head `72612e7`, 112 tracked
files, migrations `0001` through `0027`. Clone route 1 succeeded on the first attempt.
**Date:** 2026-09-12
**Question answered:** whether `tests/schema_assertions.sql`, `scripts/mutate.sh`,
`scripts/verify.sh` and `scripts/green.sh` measure what they claim.

---

## How this was run, and what that costs

The instruments were not read. They were built and executed. A Postgres 16 cluster was
started, `tests/shim.sql` and all 27 migrations applied from empty, and the mutation harness
ported by replacing `docker exec "$CONTAINER" psql` with `psql`. Nothing else in
`scripts/mutate.sh` was changed for the baseline run.

**One local change was required and it is worth stating plainly.** Migration `0027` uses
`alter table ... alter column ... set expression as`, which is PostgreSQL 17 syntax, and the
pgdg host is blocked by this session's egress policy. `set expression` was emulated in place
by altering the column type and substituting the stored `pg_attrdef` node, which preserves
every `attnum`. That matters: `0027`'s own comment records that dropping and re-adding those
nine columns silently rebound `vessel_state`.

The evidence that the substitution is faithful is that the numbers reproduce exactly. A run
of the unmodified harness on this base produced **204 assertions from empty, 219 mutations
enumerated, 198 of 198 scored mutations caught, 21 excluded as 20 degenerate and 1
inapplicable**. `CURRENT-BASELINE.md` states 204 and 27, and the session report states 198
of 198 from 219 with 21 excluded. Every figure matched on the first run, on a different
engine and a different Postgres major version. The reproducibility claim in the session
report holds.

What could not be run: the assertion suite against a copy of the live cellar (there is no
cellar here, so the 206 figure is UNVERIFIED), `bun run green` through its real Docker path,
and anything touching Supabase's JWT to role mapping, which remains S-7.

---

## Findings

| id | verdict | one line |
|---|---|---|
| X-1-1 | EXPLOITABLE | 86 of the 198 caught mutations are caught only by a pinned catalog snapshot whose failure message tells the reader to update it; the behavioural score is 112 of 198 |
| X-1-2 | EXPLOITABLE | The eight enumeration queries in `mutate.sh` discard stderr, so a broken one deletes its whole class from the run and the harness prints a clean 100 percent |
| X-1-3 | EXPLOITABLE | `green.sh` gates 4 and 5 decide by an anchored grep rather than the exit status, so an assertion run that never happened reports `ok` |
| X-1-4 | EXPLOITABLE | The A25 allow-list entry is dead: removing it changes nothing, because `0027` blinded the assertion that was supposed to depend on it |
| X-1-5 | EXPLOITABLE | Three of nine function-body substitutions chosen independently survive the suite, against ten of ten on the author's own list |
| X-1-6 | EXPLOITABLE | One assertion catches its own failure raise and can never fail, and it is the one whose comment claims it would have caught a silent `0027` |
| X-1-7 | EXPLOITABLE | A `logic` substitution whose target string no longer occurs is dropped at enumeration and reported as nothing, against a comment that says it reports as not applicable |
| X-1-8 | EXPLOITABLE | A lost database connection during an assertion run is recorded as `caught`, so a harness that cannot reach Postgres scores 100 percent |
| X-1-9 | DIVERGENT | The constraint inventory assertion pins `c=21 f=44 p=23 u=14` and prints `18 check, 40 foreign key, 22 primary key, 14 unique` on every green run |
| X-1-10 | DIVERGENT | A partial run of `mutate.sh` prints output indistinguishable in shape from a full run, which is exactly how the 20 against 21 exclusion error happened |
| X-1-11 | LATENT | `verify.sh` section 1 has no blindness guard, and a tracked file with no typed header is exempt from the dependency graph entirely |
| X-1-12 | LATENT | The A25 candidate grid gives a text column two values, so every enum to registry conversion narrows what that assertion can see |
| X-1-13 | LATENT | `green.sh` step 5 masks a total `pg_dump` failure, reporting `cellar copied, 0 tables` |
| X-1-14 | LATENT | `mutate.sh` discards the exit status of every `drop database` and `create database` |
| X-1-15 | LATENT | Four of 198 catches are the suite tripping over its own fixture, with a message naming the fixture rather than the defect |
| X-1-16 | LATENT | The A25 constraint assertion silently skips a check constraint that references no column, without naming it unevaluable |
| X-1-17 | BY DESIGN | `green.sh` exits before gates 1 to 3 when the container is unreachable, so `verify`, `typecheck` and `lint` cannot run in a clean clone |
| X-1-18 | DIVERGENT | The assertion counts stated in `CURRENT-BASELINE.md` are not checked by `verify.sh`, unlike the file and migration counts beside them |
| X-1-19 | NOT A DEFECT | 18 of 19 checks in `verify.sh` fail when their claim is falsified; the nineteenth has nothing on this tree to break |
| X-1-20 | NOT A DEFECT | 255 of 256 `FAIL` raises in the assertion suite are fatal when forced, so exactly one assertion is inert |
| X-1-21 | NOT A DEFECT | Nothing other than the one filed entry belongs on the A25 allow-list |
| X-1-22 | NOT A DEFECT | The degeneracy fingerprint, its emptiness guard, the base64 transport and the 204 against 206 storage gap all work as described |
| X-1-23 | UNVERIFIED | The 206 figure, the real Docker path through `green.sh`, and S-7 |

---

### EXPLOITABLE

**X-1-1. The mutation score is dominated by three pinned catalog snapshots, and their failure message invites their own removal.**
*Verdict:* EXPLOITABLE.
*Locator:* `tests/schema_assertions.sql`, the blocks raising `FAIL: there are % policies in public and this suite was written against %`, `FAIL: the set of wide-open policies changed`, and `FAIL: the constraint inventory changed`.
*What is wrong:* Each of these compares the catalog against a string written into the file. Disabling all three and re-running the unmodified harness drops the score from 198 of 198 to **112 of 198**. Per class: `policy` falls from 59 to 17, `weaken` from 39 to 6, `unique` from 16 to 5. `check`, `loosen`, `trigger`, `rls` and `logic` stay at 100 percent. So 86 mutations, 43 percent of the score, are caught by nothing that exercises the schema. The `weaken` class in particular exists, in the harness's own words, to catch "a policy that is still there and has stopped refusing anything", and 33 of its 39 catches are a string comparison noticing that the wide-open list grew by one name.
*How it surfaces:* Concretely, twice, demonstrated. Weaken `node_admin_update` to `using (true) with check (true)`. The suite fails with `FAIL: the set of wide-open policies changed`, which instructs the reader to update the list. Add `node.node_admin_update` to the pinned list, which is the one line the message asks for, and the suite passes at the full 204 assertions with every authenticated role able to update every lot. Separately: drop `vessel_code_code_key`, change `u=14` to `u=13` in the pinned inventory, and the suite passes at 204 while two vessels accept the same QR code, verified by inserting them.
*Resolves when:* Each of the 86 has a behavioural assertion that exercises the object, so the pinned snapshot becomes a second opinion rather than the only one. Short of that, when the three census assertions are excluded from the score `mutate.sh` reports, so the number stops absorbing their reach.

**X-1-2. A broken enumeration query removes its entire mutation class and the harness reports a clean score.**
*Verdict:* EXPLOITABLE.
*Locator:* `scripts/mutate.sh`, the function `q()` and the eight `q "$BASE" "..." >> "$muts"` calls.
*What is wrong:* `q()` ends in `2>/dev/null`, and its output is appended to the mutation file. A query that errors contributes zero lines, silently. The summary loop then does `[ "$s" -eq 0 ] && continue`, so a class that enumerated nothing is not even printed as a zero row. This is precisely the `tgenabled` shape the fingerprint guard was added to fix, still present in the place it does more damage, because the fix was applied only to `fingerprint()`.
*How it surfaces:* Sabotaging the trigger enumeration exactly as `tgenabled` broke the fingerprint, by concatenating a `"char"` catalog column without a cast, produced: `210 mutations enumerated`, a class table with no `trigger` row, and `189 of 189 scored mutations caught (100%)`. No warning anywhere. The only signal is that 210 is not 219, and nothing compares it to anything. The same shape is one keystroke away in live code: `pg_attribute.attgenerated` is also `"char"`, and I hit the identical `operator is not unique: text || "char"` error writing an ad hoc query against this schema during this review.
*Resolves when:* `q()` stops discarding stderr and the script aborts on a non-zero psql status, and each of the eight classes asserts a non-zero row count, the way `fingerprint()` already asserts a non-empty result.

**X-1-3. `green.sh` decides whether the assertion suite passed by grepping its log, and a run that never happened passes.**
*Verdict:* EXPLOITABLE.
*Locator:* `scripts/green.sh`, steps 4 and 5, `grep -qE '^(ERROR|FATAL)'` on `/tmp/green-assert-scratch.log` and `/tmp/green-assert-copy.log`.
*What is wrong:* `psql_` sets `ON_ERROR_STOP=1` and its exit status is never read. The gate is the grep. Server errors do appear unprefixed when psql reads a stdin redirect, so the grep works for a failing assertion. It does not work for psql's own client-side failures, which are written as `psql: error: ... FATAL: ...` with the FATAL mid-line, so the anchor misses them. `mutate.sh` gets this right and uses the exit status; the gate that decides whether a phase may be committed uses the unreliable signal.
*How it surfaces:* Running step 5's code verbatim against a database that does not exist prints `ok    0 assertions pass against a copy of the cellar` and does not increment `fails`. The one downstream cross-check, the scratch against copy reconciliation, is guarded by `[ "$copy_n" -gt 0 ]`, so it is skipped in exactly this case. Any connection loss, stopped container, missing role or unreadable input file between the copy and the assertion run therefore yields GREEN. The same thing happened by accident during this review: a run with the working directory wrong printed `ok     assertions pass against a copy of the cellar` with an empty count, having never opened the file.
*Resolves when:* Both steps test `psql_`'s exit status, and the reconciliation runs whenever either count is zero rather than being skipped then.

**X-1-4. The A25 allow-list has one entry, and removing it changes nothing.**
*Verdict:* EXPLOITABLE.
*Locator:* `tests/schema_assertions.sql`, the `allowed text[]` array in the block ending `test_ok('no check constraint permits on unknown, except the one instance on the allow-list')`; the entry is `term.operation_has_an_effect`.
*What is wrong:* Replacing that entry with a name that matches nothing leaves the suite green at 204. The assertion no longer detects A24 at all, so the allow-list is recording an exemption from a check that has stopped being made. The cause is `0027`. `term.kind` was the enum `term_kind`, and for an enum column the assertion generates every label, including `'operation'`. `0027` made the column `text`, and for text it generates `''`, `'x'` and null. Since `'operation'` is never among the candidates, the disjunct `kind <> 'operation'` is always true and the predicate never answers null. Evaluated over the suite's own grid the constraint answers `false`; over a grid that adds the literal appearing in the constraint's own text it answers `true`.
*How it surfaces:* Silently, already. `docs/findings-ledger.md` says of A25 that "a derived assertion now enumerates the population from the catalog and searches it, and as of `0025` there is no fourth". The qualifier is load-bearing and nothing carries it forward: the search that found no fourth instance can no longer see the third. `CURRENT-BASELINE.md` states that the assertion "is written so that fixing it fails that assertion, which puts the fix and the assertion in one commit". Fixing A24 today would fail nothing, and the allow-list entry would remain forever.
*Resolves when:* The candidate generator seeds a text column with the string literals appearing in that constraint's own expression, and the allow-list entry is proven live by a test that fails when it is removed.

**X-1-5. Three of nine independently chosen function-body substitutions survive.**
*Verdict:* EXPLOITABLE.
*Locator:* `scripts/mutate.sh`, the `logic` class `values` list.
*What is wrong:* The class is ten hand-chosen substitutions across 50 functions in `public`, and it scores 10 of 10. Nine substitutions chosen here, by the same method and applied through the same code path, score 6 of 9. The three survivors, each leaving the suite green at all 204 assertions:
`claim_task`, replacing `and status = 'open'` with `and status is not null`, so a task already claimed by somebody else can be taken from them.
`validate_vessel_attributes`, replacing `if coalesce((f ->> 'required')::boolean, false) then` with `if false then`, so a vessel type's required fields stop being required.
`finish_run`, deleting `if v_id is null then raise exception 'no such run'; end if;`, so finishing a run that does not exist writes an event against a null vessel.
The six that were caught were caught properly and by name, including a privacy substitution in `visible_node` and a fork substitution in `record_event`.
*How it surfaces:* Silently, never, in the sense that matters: nothing goes wrong until somebody makes one of these edits, and the gate says green when they do. The point is the calibration. 198 of 198 is read as a statement about the kernel, and on an independent sample of the procedural surface the suite scores 67 percent.
*Resolves when:* The `logic` class is enumerated rather than listed, for instance one substitution per `if` condition in every function body, so it grows with the schema the way the other seven classes do.

**X-1-6. One assertion catches its own failure raise and can never fail.**
*Verdict:* EXPLOITABLE.
*Locator:* `tests/schema_assertions.sql`, the block ending `test_ok('a vessel type field naming a vocabulary that does not exist is still refused')`.
*What is wrong:* The shape is `begin; insert ...; raise exception 'FAIL: ...'; exception when raise_exception then perform test_ok(...); end;`. `raise exception` with a bare message raises SQLSTATE P0001, which is `raise_exception`, which is what the handler catches. The handler was chosen to match `validate_vessel_type_fields`, which refuses in the same way, and it catches the assertion's own alarm along with it. Forcing the failure path by injecting a raise at the top of the guarded block leaves the suite green at 204, which is the proof. Every one of the other 255 `FAIL` raises in the file is fatal when forced.
*How it surfaces:* Silently, never, because the property is covered by a live assertion 2,680 lines earlier, `FAIL: a picker naming no real vocabulary was accepted`, which does fire when the validator is neutered. The consequence is the comment. The paragraph above this block says it is "the assertion that would have caught the silent version" of `0027`'s cast rewrite. It would not have. The next person to change the validator and see this line print `ok` will have learned nothing.
*Resolves when:* The handler is narrowed, or the failure path re-raises when `sqlerrm` starts with `FAIL`. And the same audit is run on the other twelve `when raise_exception` handlers in the file, all of which are currently fatal only because their guarded statement raises before the alarm is reached.

**X-1-7. A `logic` substitution whose target string has gone is dropped at enumeration and reported as nothing.**
*Verdict:* EXPLOITABLE.
*Locator:* `scripts/mutate.sh`, the `logic` query's `where position(m.find in pg_get_functiondef(p.oid)) > 0 and m.find <> m.repl`.
*What is wrong:* The comment directly above says "A substitution whose target string is gone reports as not applicable, which is also how this list tells you a function has changed shape." It does not. The `where` clause removes it before it becomes a mutation, so it is absent from `total`, absent from the inapplicable list, and absent from the summary.
*How it surfaces:* Changing one `find` string to one that no longer occurs takes the class from `10 mutations enumerated, 10 of 10 caught` to `9 mutations enumerated, 9 of 9 caught`, and both runs end with `Nothing was excluded: every enumerated mutation was applied and changed something`. This is the live risk in the class the harness itself describes as hand-maintained: refactoring any of the twelve named function bodies silently shrinks the only class that tests procedural logic, while the percentage stays at 100. The second half of the same clause, `m.find <> m.repl`, removes the two entries labelled "no-op probe, kept to show a substitution that changes nothing is caught by nothing", so the degeneracy detector is never exercised on this class either.
*Resolves when:* The join is left outer and a substitution that matches nothing is emitted as a mutation that will fail to apply, or is counted and named separately.

**X-1-8. A lost database connection is recorded as a caught mutation.**
*Verdict:* EXPLOITABLE.
*Locator:* `scripts/mutate.sh`, the `if psql ... < tests/schema_assertions.sql; then survivors else caught` decision.
*What is wrong:* Caught is defined as the suite exiting non-zero, and psql exits non-zero when it cannot connect, when the role is missing, when the database was dropped, or when the disk is full, exactly as it does when an assertion fails. A harness that loses Postgres halfway through reports every remaining mutation as caught and ends at 100 percent.
*How it surfaces:* Running the decision verbatim against a database that does not exist records `caught`. The base and work databases are created and dropped by `adm`, which discards its own status (X-1-14), so the harness has no independent check that the database it is testing against is the one it built.
*Resolves when:* The decision distinguishes a suite that failed from a suite that did not run, for instance by requiring that the log contains at least one `ok` notice before a non-zero exit is scored as caught.

---

### DIVERGENT

**X-1-9. The constraint inventory assertion prints three wrong numbers on every green run.**
*Verdict:* DIVERGENT.
*Locator:* `tests/schema_assertions.sql`, `test_ok('the constraint inventory is what this suite was written against: 18 check, 40 foreign key, 22 primary key, 14 unique')`, four lines below `want := 'c=21 f=44 p=23 u=14'`.
*What is wrong:* The tree has 21 check, 44 foreign key, 23 primary key and 14 unique constraints, which is what the assertion pins and compares. Three of the four numbers in the success message are the pre-`0026` values. The comment above the pinned string records the migrations that changed them; the message beside it was not updated.
*How it surfaces:* On every passing run, 204 times a session. `verify.sh` section 4 checks counts stated in prose and does not reach inside a SQL string, so nothing catches it. Neither the number nor its staleness is load-bearing, but the whole design of this file is that a number written into a sentence is derived and compared, and here is one that rotted in the one place the derivation was not applied.
*Resolves when:* The message is built from `have` rather than typed.

**X-1-10. A partial run of the harness is indistinguishable in shape from a full one.**
*Verdict:* DIVERGENT.
*Locator:* `scripts/mutate.sh`, `ONLY="${1:-}"` and the `[ -n "$ONLY" ] && grep` filter.
*What is wrong:* `bash scripts/mutate.sh weaken` produces the same header, the same class table, the same "no survivors" line, the same exclusion listing and the same closing sentence as a full run. The argument is echoed nowhere. The run states what it excluded and does not state what it covered.
*How it surfaces:* Reproducibly, and it has. A `weaken`-only run here printed `NOT A BARE SCORE: 20 excluded, 20 degenerate and 0 inapplicable`; the full run prints `21 excluded, 20 degenerate and 1 inapplicable`. That is exactly the 20 against 21 discrepancy `modularization-progress.md` corrects, and its signature. The one inapplicable mutation lives in the `unique` class, so any single-class run other than `unique` will report 20.
*Resolves when:* The output names its own scope on the first line and in the closing sentence, so a filtered number cannot be quoted as a full one.

**X-1-18. The assertion counts in `CURRENT-BASELINE.md` are not checked, unlike the counts beside them.**
*Verdict:* DIVERGENT.
*Locator:* `docs/review/CURRENT-BASELINE.md`, the row `Assertions | 204 from an empty database, 206 against a copy of the cellar`, against `scripts/verify.sh` section 4.
*What is wrong:* The file says of the row above it that "The file and migration counts above are derived rather than typed, and `scripts/verify.sh` checks them against the tree on every run." That is true of the file and migration counts, which I broke and watched fail. It is not true of the assertion counts in the next row, which no check reads. Both happen to be right; 204 is confirmed here.
*How it surfaces:* The next migration that adds or removes an assertion. Nothing will notice, and the baseline file is described in its own text as the first thing a reviewer will trust.
*Resolves when:* `green.sh` already computes both numbers. Comparing them to the file is three lines in the place that already has them.

---

### LATENT

**X-1-11. `verify.sh` has no blindness guard on the header graph, and a file with no header is exempt from it.**
*Verdict:* LATENT.
*Locator:* `scripts/verify.sh` section 1, `grep -q 'Depends on:' "$f" 2>/dev/null || continue`.
*What is wrong:* Two gaps, one shape. Section 3 guards every id list with `[ -z "$sorries" ] && fail "... this check is blind"`. Section 1 has no equivalent: if no file were detected as headered, `$headered` and `$edges` would both be empty, every loop over them would run zero times, and the section would print `ok 0 headered files, 0 edges, every one bidirectional and resolving`. Separately, CLAUDE.md says "Every document carries a typed header", and section 1 only examines files that already have one, so omitting the header is a complete exemption from the graph, the orphan check and the bidirectionality check.
*How it surfaces:* Adding a tracked `.sql` file containing only `select 1;` leaves `verify.sh` green, once the tracked-file count in the baseline file is updated to match, which the failure message asks for anyway. Reaching the first gap needs the header field itself to be renamed or reformatted tree-wide, which is why this is LATENT rather than EXPLOITABLE.
*Resolves when:* Section 1 fails when `$headered` is empty, and the presence of a header on every `.md`, `.sql` and `.sh` outside the corpus is itself a check.

**X-1-12. The A25 candidate grid gives a text column two values, so every registry conversion narrows it.**
*Verdict:* LATENT.
*Locator:* `tests/schema_assertions.sql`, the `elsif col.atttypid in ('text'::regtype, ...) then cand_arr := array[quote_literal(''), quote_literal('x')]` branch.
*What is wrong:* An enum column is exercised against every label. A text column is exercised against `''`, `'x'` and null. A predicate that compares a text column to a domain literal is therefore never evaluated at the point where it can answer null. X-1-4 is the first instance. Evaluating all 21 check constraints over both grids, the suite's grid and one enriched with the literals in each constraint's own expression, finds one disagreement today, and it is `term.operation_has_an_effect`.
*How it surfaces:* On the next conversion of this kind. `0026` and `0027` are described as the pattern for future module extraction, and each one that moves an enum into a registry converts more columns to text and further narrows this assertion, without changing its output.
*Resolves when:* The generator seeds a text column from the literals in the constraint expression, or from the registry table the column references.

**X-1-13. `green.sh` masks a complete `pg_dump` failure.**
*Verdict:* LATENT.
*Locator:* `scripts/green.sh` step 5, `docker exec "$CONTAINER" sh -c "pg_dump -U postgres -d $CELLAR | psql -U postgres -q -d $COPY"`.
*What is wrong:* `set -o pipefail` is set in `green.sh` and does not reach the child `sh -c`, so the pipeline's status is psql's, and psql exits 0 on empty input. Verified: `sh -c "pg_dump -d no_such_db | psql -d postgres"` exits 0 with the FATAL only on stderr.
*How it surfaces:* The step reports `ok    cellar copied, 0 tables`. It is currently caught one step later, because the assertion suite against an empty database raises a server error that the anchored grep does catch. That mitigation is the same grep X-1-3 shows to be unreliable, so the two together are reachable.
*Resolves when:* The copy step checks the table count it already computes, rather than printing it.

**X-1-14. `mutate.sh` discards the status of every database create and drop.**
*Verdict:* LATENT.
*Locator:* `scripts/mutate.sh`, `adm(){ ... >/dev/null 2>&1; }` and the `adm "drop database if exists $WORK;" ; adm "create database $WORK template $BASE;"` pair inside the loop.
*What is wrong:* If the drop fails, which it does whenever a connection is still open on `$WORK`, the create also fails and the iteration mutates a database that still carries the previous mutation. The fingerprint comparison still moves, so the mutation is scored, against a schema carrying two defects.
*How it surfaces:* Serial operation does not leave connections open, so this needs a concurrent psql, an autovacuum worker holding the database, or a second harness run. Name the change that reaches it: running two `mutate.sh` invocations at once, which nothing forbids and which a reviewer comparing classes would naturally do.
*Resolves when:* `adm` returns its status and the loop aborts on a failed create, the way the fingerprint guard aborts.

**X-1-15. Four catches are the suite tripping over its own fixture.**
*Verdict:* LATENT.
*Locator:* `scripts/mutate.sh`, the caught branch; the four are `loosen subject_resolver.subject_type_is_a_bare_name`, `policy event.event_insert`, `policy term.term_read` and `policy vessel_type_note.vessel_type_note_insert`.
*What is wrong:* These four exit non-zero with `update or delete on table "subject_resolver" violates foreign key constraint`, `null value in column "operation_id" of relation "event" violates not-null constraint` and two `new row violates row-level security policy`. No assertion raised. The mutation broke a fixture the suite needed, and the failure names the fixture. They are scored as caught because caught means non-zero.
*How it surfaces:* Four of 198 is small and each of the four does correspond to a real defect. The class is the problem: the message sends the next person to `event.operation_id` when what changed was the `term_read` policy. Widen the mutation set and this grows.
*Resolves when:* The harness records whether the log contains a `FAIL:` line and reports fixture breakage as its own column.

**X-1-16. The A25 constraint assertion skips a constraint with no referenced column without naming it.**
*Verdict:* LATENT.
*Locator:* `tests/schema_assertions.sql`, `if froms = '' then continue; end if;` in the A25 constraint block.
*What is wrong:* There are two ways to reach `froms = ''`. One sets `unevaluable` first and is reported. The other is a constraint whose `conkey` is empty, where the column loop never runs, and that path `continue`s in silence. A check constraint referencing no column is exactly what the `loosen` class creates.
*How it surfaces:* Not on this tree; all 21 check constraints reference at least one column. It becomes reachable the moment a `check (true)` placeholder is committed, which is a normal thing to do while moving a constraint between migrations.
*Resolves when:* The empty-`conkey` path appends to `unevaluable` like the other one.

---

### BY DESIGN

**X-1-17. `bun run green` cannot run its first three gates in a clean clone.**
*Verdict:* BY DESIGN, and worth restating anyway.
*Locator:* `scripts/green.sh`, `if ! docker exec "$CONTAINER" true 2>/dev/null; then ... exit 2; fi`, above step 1.
*What is wrong:* Nothing, as written. The check is deliberate and its message is good. But `verify`, `typecheck` and `lint` need no database, and the guard sits above them, so a clean clone with no stack running gets `exit 2` and three gates that could have run did not. Confirmed by running it here: `FAIL cannot reach the database container`, exit 2, nothing else attempted.
*How it surfaces:* Every reviewer or CI runner without the Supabase stack, which is the situation this prompt describes.
*Resolves when:* The guard moves below step 2 and the three database gates fail individually. The answer to the prompt's question is otherwise yes: all six gates run, each failure increments `fails`, and `fails` decides the exit code. I confirmed this by running a locally transported copy end to end, watching gate 1 pass, gates 3 and 4 pass at 27 of 27 and 204, and the scratch against copy reconciliation fire correctly when the two counts did not differ by the expected storage skip.

---

### NOT A DEFECT

**X-1-19. `verify.sh`'s checks fire.** Nineteen sabotages, one per distinct claim: an edge naming a path that does not exist, a one-directional edge in each direction, a headered file nothing points at, an em dash in a tracked file, an em dash in a commit subject, a reference to a non-existent `S-`, `C-` and `AR-` id, a compost entry losing its `Reactivate if:` line, the sorry ledger's id format changing, the tracked file count and the migration count and the compost count each made wrong, the definition of done naming a missing script and a missing path, the status ledger contradicting itself, and a second module package importing from a sibling. Eighteen produced a `FAIL` naming the thing broken. The nineteenth, the check that a row graded `Deferred` names a compost entry, could not be tested because `docs/status-ledger.md` currently has zero `Deferred` rows, so that check runs over an empty set and contributes to a green section that claims "every Deferred row says how". Unlike the module import rule three sections later, which says out loud that it holds vacuously, this one does not. That is a one-line omission, not a defect in the check.

**X-1-20. The suite is one assertion away from having no inert assertions.** There are 206 `test_ok` call sites; 204 fire against an empty database and 2 are inside the storage-guarded blocks, which matches the stated 204 against 206 gap exactly. Of the 256 `FAIL` raises, each was forced by injecting a raise at the top of its own guarded block and re-running: 255 took the suite down, one did not, and that one is X-1-6. This is a good result and was not the expected one.

**X-1-21. Nothing else belongs on the A25 allow-list.** All 21 check constraints were evaluated over a grid enriched with the string literals in their own expressions. Exactly one answers null for a row the table could hold, and it is the one on the list. The allow-list is the right length. Its entry is dead for the reason in X-1-4, which is a different problem from having the wrong entries.

**X-1-22. Four things that work and were checked.** The degeneracy fingerprint detects all 20 already-wide-open policies and names them. Its emptiness guard aborts as documented. The base64 transport carries all ten multi-line function mutations, which the comment says failed silently before it existed. And the 204 against 206 gap is exactly the two storage-guarded blocks, derived rather than pinned, which `green.sh` checks on every run and which fired correctly here when my synthetic cellar did not have a storage schema either.

---

### UNVERIFIED

**X-1-23.** Three things were not checkable here. The 206 figure needs a cellar to copy. The real `green.sh` path needs a Docker daemon, which this session does not have, so what was tested is a transport-swapped copy with the same control flow. And S-7, the GoTrue to PostgREST mapping, is untouched by anything in this repository, as `CURRENT-BASELINE.md` already says. What would check the first two is one run of `bun run green` and `bash scripts/mutate.sh` on a machine with the stack up, which should reproduce 204, 206 and 198 of 198; the first and third did reproduce here.

---

## The counts the prompt asked for

| | |
|---|---|
| Assertion call sites in the file | 206 |
| Assertions that fire from an empty database | 204 |
| Assertions that are inert, meaning they cannot fail | 1 |
| `FAIL` raises proven fatal when forced | 255 of 256 |
| Catches whose message does not name what was broken | 84 of 198 |
| Reported mutation score | 198 of 198, 100 percent |
| Score with the three pinned catalog snapshots disabled | 112 of 198, 56 percent |
| Independent function-body substitutions caught | 6 of 9, against 10 of 10 on the author's own list |
| Fail-open paths found | 11 |

The 84 breaks down as 48 caught by the policy count, which names a number and not a policy;
32 by the constraint inventory, which names four totals and not a constraint; and 4 by the
suite breaking its own fixture. The 34 caught by the wide-open policy assertion are not
counted here, because that one prints both lists and the reader can diff them.

The eleven fail-open paths are X-1-2, X-1-3, X-1-7, X-1-8, X-1-13, X-1-14 and X-1-16, plus
four inside `mutate.sh` and `verify.sh` that are named within those findings: the summary
loop that omits a zero-row class entirely, the `m.find <> m.repl` filter that removes both
no-op probes so the degeneracy detector is never exercised on the `logic` class, the absent
blindness guard in `verify.sh` section 1, and the `Deferred` check that runs over an empty
set.

## Predictions that turned out false

Five, and they are the reason the confirmed ones are worth anything.

I expected `green.sh`'s `grep -E '^(ERROR|FATAL)'` to be broken outright, because psql
prefixes script errors with `psql:file:line:`. It does that for `-f`, and not for a stdin
redirect, which is what both `green.sh` and `mutate.sh` use. The grep works for server
errors. The narrower defect in X-1-3 is real but it is not the one I went looking for.

I expected the two `exception when others` handlers to be the inert assertions. Both are
legitimate inner handlers around an `execute`, collecting what could not be evaluated. The
one inert assertion has a `when raise_exception` handler, which I had listed as the less
likely shape.

I expected dropping a unique constraint to be caught behaviourally in most cases. Eleven of
sixteen are caught only by the pinned inventory.

I expected the `weaken` reconstruction to inject a defect by dropping `as restrictive`. It
would, and there are zero restrictive policies in `public`, so it injects nothing today.

I expected the A25 constraint assertion's silent skip path to be reachable now. It is not;
all 21 constraints reference a column.

## What this adds up to

The instruments are better than the corpus that preceded them and the one number they are
quoted by is not sound. The suite is nearly free of inert assertions, one in 206, which is a
better result than three earlier hollow greens would predict. `verify.sh` does what it says.
The harness's refusal to print a bare percentage is real and it worked: every claim it makes
about what it excluded was reproducible here on the first run.

What it does not say is what it covered. 198 of 198 is a measurement of a suite in which 86
of those catches come from three strings pinned into the file, each of which fails with a
message inviting the reader to update it, and updating it is a one-line diff that a reviewer
will read as bookkeeping. The instruments measure that the catalog has not changed. They
measure much less often that the schema still refuses what it is supposed to refuse. That
distinction is the one the eighth class was built to expose for function bodies, and it turns
out to apply to more than half the declarative surface as well.
