# X-2: migrations 0021 through 0027

**Tree read:** `github.com/VigneronVitae/VSV-Management-Software`, head `72612e7`, 112 tracked
files, migrations `0001` through `0027`. All four replacement canaries present:
`scripts/mutate.sh`, `tests/shim.sql`, `scripts/verify.sh`, `docs/review/CURRENT-BASELINE.md`.
Cloned over route 1; no fallback needed.

**Executed, not read.** PostgreSQL 17.10, shim applied, all twenty-seven migrations applied
from empty, assertion suite run, mutation harness run, and every finding below probed under
`set local role` as an admin, a cellar user, a custom crush client holding a party row, an
authenticated principal with no `app_user` row, and `anon`. Never as the migration owner.

Independent reproduction of the tree's own numbers: **204 assertions** from empty, and
**198 of 198** scored mutations caught from 219 enumerated, 20 degenerate and 1 inapplicable.
Both match `CURRENT-BASELINE.md` exactly. The instruments are honest about what they measured.

---

## Findings

| Id | Defect | Verdict |
|---|---|---|
| X-2-1 | `validate_vessel_type_fields` permits a field whose `kind` is absent, so 0027's registry lookup never runs | EXPLOITABLE |
| X-2-2 | `terms_for_vessel_field` lost its proof-by-cast in 0027, which is the second such rewrite and the third trap | EXPLOITABLE |
| X-2-3 | `validate_vessel_attributes` validates nothing for a field with no `kind`, so any value enters `vessel.attributes` | EXPLOITABLE |
| X-2-4 | The admin rebind in `bind_vessel_code` leaves a false trace rather than no trace | EXPLOITABLE |
| X-2-5 | `bind_vessel_code`'s idempotent branch reports success for a deactivated code and does not reactivate it | EXPLOITABLE |
| X-2-6 | A field spec the write-time validator accepts can make its vessel type unsaveable, with an error naming neither | EXPLOITABLE |
| X-2-7 | The A25 assertion's population excludes trigger validators, so the class it polices is unpoliced where 0027 worked | DIVERGENT |
| X-2-8 | `config.toml` records 17 as verified-against; `0027` makes 17 a hard floor. Different claims | DIVERGENT |
| X-2-9 | A5's blanket read recurs on both tables this range adds, `subject_resolver` and `term_kind` | LATENT |
| X-2-10 | A14: no eighth invoker write path in this range | NOT A DEFECT |
| X-2-11 | A13: refusals in this range raise for a cellar user and stay silent for a client | NOT A DEFECT |
| X-2-12 | A18, A19: no stored derivation added in this range | NOT A DEFECT |

---

## EXPLOITABLE

**X-2-1. `validate_vessel_type_fields` permits a field whose `kind` is absent, so the registry
lookup 0027 added never runs.**

*Verdict:* EXPLOITABLE.

*Locator:* `supabase/migrations/0027_term_kind_registry.sql`, function
`validate_vessel_type_fields`, the guard `if (f ->> 'kind') not in ('term', 'number', 'text')`.

*What is wrong:* `f ->> 'kind'` is null when the field carries no `kind` key, and
`null not in ('term','number','text')` is null, so the `if` does not fire and the field is
accepted. The next test, `if (f ->> 'kind') = 'term'`, is null for the same reason, so the
whole picker block is skipped, including the registry lookup that is 0027's headline fix. The
author anticipated the missing case and wrote `coalesce(f ->> 'kind', 'nothing')` into the
error message; that coalesce is unreachable, and it is unreachable because of the same
three-valued logic it was written to report on. This is A25's fourth instance.

*How it surfaces:* Probed. `{"fields":[{"key":"maker","kind":null,"term_kind":"nonesuch"}]}`
is accepted. The same field with `"kind":"term"` is refused with `field maker names vocabulary
nonesuch, which does not exist`. The guard exists, works, and is walked around by a null.
`term_admin_write` is `is_admin()`, and the walk's own field editor defaults `kind` to `"text"`
and always writes it, so the path is the table through PostgREST rather than the form: an
admin, a seed script, or any later migration writing a field spec by hand.

*Resolves when:* every `->>` read that decides a branch in a validator is forced to a decision
before it is tested, so that a missing key refuses instead of falling through, and the A25
assertion's population includes functions returning `trigger`.

---

**X-2-2. `terms_for_vessel_field` lost its proof-by-cast in 0027. This is the third trap, and
it is the same class 0027 documented catching once.**

*Verdict:* EXPLOITABLE.

*Locator:* `supabase/migrations/0027_term_kind_registry.sql`, function
`terms_for_vessel_field`, the line `and t.kind = (spec.f ->> 'term_kind')::text`.

*What is wrong:* 0027 contains a long comment identifying "the one place in this migration
where a blind substitution would have been a silent defect", and it is right about
`validate_vessel_type_fields`, where it replaced the enum cast with a registry lookup. There
were two places. Fourteen lines above that comment, the same `::term_kind` was rewritten to
`::text` in `terms_for_vessel_field` with no comment at all, and `::text` on a text value
always succeeds. That cast was the second line of defence: it is what turned a vessel type
naming a vocabulary that does not exist into a loud failure at the moment somebody opened the
form.

*How it surfaces:* Probed on both sides, against two databases built from the same tree. At
`0026`, `terms_for_vessel_field` on a field naming `nonesuch` raises `invalid input value for
enum term_kind: "nonesuch"` (22P02). At `0027` the identical call returns zero rows and no
message. Combined with X-2-1, a bad vocabulary that the front validator no longer catches is
now silent end to end: the picker renders empty, and an empty picker is indistinguishable from
a vocabulary nobody has added terms to yet. The two defects are individually narrow and
together remove every signal.

*Resolves when:* the registry lookup that replaced the cast in the validator also replaces it
here, so that a field naming an unregistered vocabulary is refused at both the write and the
read, or `terms_for_vessel_field` raises on a `term_kind` absent from `term_kind`.

---

**X-2-3. `validate_vessel_attributes` validates nothing at all for a field with no `kind`.**

*Verdict:* EXPLOITABLE.

*Locator:* `supabase/migrations/0011_vessel_type_fields.sql`, function
`validate_vessel_attributes`, the `if (f ->> 'kind') = 'number' ... elsif (f ->> 'kind') =
'term'` dispatch, reached through `vessel_attributes_guard`.

*What is wrong:* the runtime half of the pair has the same shape as X-2-1 and the same cause.
Both comparisons are null for a field carrying no `kind`, so neither branch runs, and the only
test that survives is `required`. A picker field becomes a free-text field with no list behind
it. The write-time validator is what is supposed to make this unreachable, and X-2-1 is why it
is not.

*How it surfaces:* Probed. Against a vessel type whose `maker` field names `term_kind:
"nonesuch"` and carries no `kind`, `validate_vessel_attributes` accepted
`{"maker":"utterly arbitrary text"}`, and the vessel then inserted carrying it. The stored
attribute looks like a term reference to every reader and is a free string.

*Resolves when:* the dispatch treats an unrecognised or absent `kind` as a refusal rather than
as a fall-through, which is the same repair as X-2-1 and should land in the same commit.

---

**X-2-4. The admin rebind path leaves a false trace, which is worse than the no trace S-43
records.**

*Verdict:* EXPLOITABLE.

*Locator:* `supabase/migrations/0025_bind_an_unbound_code.sql`, function `bind_vessel_code`,
the `update vessel_code set vessel_id = p_vessel_id, label = coalesce(p_label, label)` branch.

*What is wrong:* S-43 says the permitted path leaves no trace, and the row is in worse
condition than that. `vessel_code` has `added_at` and no `added_by`, and the rebind updates
neither. So after an admin moves a sticker, the row carries the timestamp of the original
bind, presented as though it described the current binding, and `label` silently carries over
from the vessel the sticker used to be on. A record that answers nothing is honest. This one
answers a question it was not asked, with the wrong answer, which is exactly A17's class: a
correct-looking screen producing a record that cannot say who did it.

*How it surfaces:* Probed. `STICKER-1` bound to Barrel One at `22:16:18.377242+00` with label
`Barrel One`, then rebound by an admin to Barrel Two. The resulting row reads
`vessel_id = Barrel Two, added_at = 22:16:18.377242+00, label = 'Barrel One'`, and zero events
were written. At the stated scale, fifty vessels and five to ten users, the label is what a
person reads off the sticker, so the two disagree in the barrel room and nothing in the
database prefers one.

*Resolves when:* the rebind writes its own provenance, either by refreshing `added_at` and
recording the actor, or by closing the old binding with `active = false` and inserting a new
row so that the history is two rows rather than one mutated one.

---

**X-2-5. `bind_vessel_code`'s idempotent branch reports success for a deactivated code and
does not reactivate it.**

*Verdict:* EXPLOITABLE.

*Locator:* `supabase/migrations/0025_bind_an_unbound_code.sql`, function `bind_vessel_code`,
the branch `if existing.vessel_id = p_vessel_id then return existing;`.

*What is wrong:* the branch returns the existing row without consulting `active`.
`resolve_vessel_code` joins `on c.code = p_code and c.active`, so a deactivated code resolves
to nothing. A cellar hand scanning a barrel that will not resolve, and re-binding the sticker
to fix it, gets the success payload back and changes nothing. This is A13's class arriving
through a return value rather than through a zero-row match, which is the same place B2 found
it: a refusal indistinguishable from success, reached without row level security being
involved at all.

*How it surfaces:* Probed. Bound `ST-2` to Barrel One, set `active = false`, re-bound `ST-2`
to Barrel One as a cellar user. The function returned the row with `active = f` and no error;
`resolve_vessel_code('ST-2')` returned nothing, both before and after. The suite's assertion
`rebinding a code the vessel already carries is not an error and adds nothing` exercises this
branch only against an active code, which is why the case looks covered.

*Resolves when:* the idempotent branch either reactivates the row or refuses, and the
assertion that covers it is extended to a deactivated code so the two answers are
distinguishable.

---

**X-2-6. A field spec the write-time validator accepts can make every vessel of its type
unsaveable, with an error naming neither the field nor the type.**

*Verdict:* EXPLOITABLE.

*Locator:* `validate_vessel_attributes`, `coalesce((f ->> 'required')::boolean, false)`,
against `validate_vessel_type_fields`, which checks `key`, `kind`, `term_kind`, `min` and
`max` and never checks `required`.

*What is wrong:* `required` is cast to boolean at read time and validated nowhere at write
time. Postgres accepts `yes`, `t`, `on` and `1`, so most values survive; anything else raises
`invalid input syntax for type boolean` from inside the guard, with no field name and no
vessel type in the message.

*How it surfaces:* Probed. A vessel type carrying `{"key":"maker","kind":"text","required":
"maybe"}` is accepted. A vessel of that type saves normally while the field is filled in, and
fails with `invalid input syntax for type boolean: "maybe"` (22P02) the first time somebody
leaves it blank. The failure is therefore latent in the type until a particular person leaves
a particular box empty, and the message points at neither.

*Resolves when:* `validate_vessel_type_fields` checks `required` against the same set the
runtime will cast it to, so a spec the runtime cannot execute cannot be stored.

---

## DIVERGENT

**X-2-7. The A25 assertion's population is check constraints and boolean functions, so the
class is unpoliced in the one layer 0027 rewrote.**

*Verdict:* DIVERGENT.

*Locator:* `tests/schema_assertions.sql`, the block headed `nothing in the fixed layer permits
on unknown`, against `docs/review/CURRENT-BASELINE.md`, section "The A25 allow-list", and
ledger entry A25.

*What is wrong:* the two halves of the assertion enumerate `pg_constraint` where `contype =
'c'`, and `pg_proc` where `pg_get_function_result(p.oid) = 'boolean'`.
`validate_vessel_type_fields` returns `trigger` and `validate_vessel_attributes` returns
`void`, so both sit outside both halves. The ledger says of A25 that "a derived assertion now
enumerates the population from the catalog and searches it, and as of `0025` there is no
fourth". That sentence is true of the population it enumerates and is read as a statement
about the class. X-2-1 is a fourth instance and the instrument cannot see it. The mutation
harness does not close the gap either: its `logic` class is ten hand-chosen substitutions and
none of the three functions carrying X-2-1 through X-2-3 is among them, which is the sampling
caveat `CURRENT-BASELINE.md` already states, landing on exactly the code 0027 rewrote most
heavily.

*How it surfaces:* silently, never. The suite passes, the harness reports 198 of 198, and both
numbers are accurate about what they measured.

*Resolves when:* the boolean half of the assertion is widened to functions returning `trigger`
and `void`, exercised by calling them against a generated population of candidate `jsonb`
payloads rather than against null arguments, and the ledger's A25 entry states the population
it is scoped to.

---

**X-2-8. `config.toml` records 17 as what the migrations are verified against; `0027` makes 17
a hard floor. Those are different claims and only the weaker one is written down.**

*Verdict:* DIVERGENT.

*Locator:* `supabase/migrations/0027_term_kind_registry.sql`, `alter table ... alter column
... set expression as`, against `supabase/config.toml`, the comment above `major_version = 17`.

*What is wrong:* `ALTER COLUMN ... SET EXPRESSION` is PostgreSQL 17 syntax. `0027` depends on
it for the whole of its stated trap avoidance, because altering the generated columns in place
is what keeps their ordinal positions and therefore keeps `vessel_state`'s positional alias
list valid. The tree records 17 as the version it was verified against, which reads as a
verification note; ledger entry C4 records that "15 and 17 pass" the CLI's config validation,
which invites 15. Nothing says 17 is the minimum.

*How it surfaces:* Probed. On PostgreSQL 16.13 the first twenty-six migrations apply clean and
`0027` fails at `syntax error at or near "expression"`. The failure is clean: the statement is
one `do` block, so it rolls back whole, and the database is left at `0026` with the type, the
four views and all fifty functions intact. Loud and recoverable, which is the good half.

*Resolves when:* the floor is stated where somebody will read it before running the
migrations, and `scripts/green.sh` or the shim refuses a server below 17 rather than letting
`0027` be the thing that discovers it.

---

## LATENT

**X-2-9. A5's blanket read recurs on both tables this range adds.**

*Verdict:* LATENT. Stretching the word: the mechanism is live and probed, and only the
consequence is out of reach. Regrade it upward the moment the second paragraph below is true.

*Locator:* `subject_resolver_read` in `0023_subject_resolver.sql` and `term_kind_read` in
`0027_term_kind_registry.sql`, both `for select to authenticated using (true)`.

*What is wrong:* A5 was filed against thirteen tables carrying `using (true)`, A23 recorded
the habit recurring on `vessel_type_note` seven migrations later, and this range adds two more
tables with the same default. The mutation harness makes the census cheap to read: its
degenerate list, the mutations that changed nothing because the policy was already `true`, now
runs to twenty `weaken` entries, and `subject_resolver_read` and `term_kind_read` are two of
them. A policy that cannot be weakened is a policy that is not refusing anything.

*How it surfaces:* Probed. A custom crush client reads all four `subject_resolver` rows,
including `block: vineyard || ' ' || name`, and all eight `term_kind` rows. What that
discloses today is module topology, that a vineyard module exists and how it renders a block,
which is close to nothing. It stops being close to nothing when a module registers a resolver
whose `relation` or `name_expression` names client-specific data, which is the intended growth
path of the registry and the thing phase 8's manifest is for. `anon` sees neither table,
because both policies are `to authenticated`.

*Resolves when:* a new table's read policy has to name a predicate, by convention or by an
assertion that fails on a `using (true)` select policy outside a stated allow-list, so that
the next registry does not arrive with the same default.

---

## NOT A DEFECT

**X-2-10. A14: there is no eighth invoker write path in this range.** Thirteen invoker
functions in the tree write rows. Of those, only `bind_vessel_code` is touched by `0021`
through `0027`, and `0025` gives it the insert policy it needs. Probed as all five principals:
the cellar hand binds, the client and the unclaimed principal are refused by
`vessel_code_cellar_insert`, `anon` is refused, and every refusal raises `42501`.

**X-2-11. A13: the range's own refusals raise for a cellar user and stay silent for a client.**
Probed per principal against a clean starting row for each. A cellar user changing
`node.owner_id` or `node.hidden` gets `a cellar user may not change node.owner_id; ask an
administrator` (42501); the permitted columns update one row. A client and an unclaimed
principal get zero rows and no message for the same statements, and cannot read the row either.
That is the state the ledger already describes, that `0021` improves A13 for one principal on
three tables rather than answering it. `0021`'s column allow-list is the strongest work in this
range and it does what it says.

**X-2-12. A18 and A19: this range adds no stored derivation.** The nine generated columns
`0027` moves are recomputed by the server on every write, and the two registries store
declarations rather than derived values. Nothing here stores a computed number with nothing
recomputing it.

**The three traps in the conversion, checked directly.** All nine generated columns survived
`0027` with `attgenerated = 's'` and their original `attnum`, so nothing moved to the end of a
table. The one positional alias list in the tree, `visible_node(id, stage, status, vintage,
block_id, name, quantity, unit, attributes, provenance, closed_at, created_at, created_by,
owner_id, variety_id, variety_kind, product_type_id, product_kind, hidden)` inside
`vessel_state`, still matches `node`'s live column order position for position. `0027`'s
stated avoidance of both traps holds. The third one is X-2-2, and it is the same class as the
second, one function away from where the migration went looking.

---

## Predictions that turned out false

Three, and the first two are the reason the probes were worth running.

**`bind_vessel_code` could be blinded by row level security.** The function is invoker and
opens with `select * into existing from vessel_code where code = p_code`. If a cellar hand
could not see a bound row, `found` would be false, the admin-only rebind check would be
skipped, and the insert would either fail confusingly or create a second binding for the same
code. Dead on both halves: `vessel_code_read` is `using (true)` so the select always finds it,
and `code` carries a unique constraint so a duplicate could not land regardless. The blanket
read I would otherwise file under A5 is what makes the rebind guard sound, which is an
uncomfortable thing to have to write down.

**A cellar user could change `node.owner_id`.** My first probe said one row updated, which
would have been the range's worst finding, since `0021`'s own comment names `owner_id` as the
column a cellar user must not be able to move. The probe was contaminated: it iterated
principals in one transaction, the admin iteration had already set `owner_id` to the target
value, and the cellar iteration therefore changed nothing, so `cellar_writable_columns` saw no
changed column and did not fire. Re-probed with a clean starting row per principal, the cellar
user is refused loudly. The allow-list works. A probe that runs its principals in sequence
against shared state is measuring the previous principal.

**`0027` might have lost the generated property on the nine columns.** `alter column ... type
text` followed by `set expression` looked like it could drop and re-derive rather than alter in
place, which would have moved columns to the end of the table and, worse, made
`cellar_writable_columns` see a changed generated column on every update and refuse every
rack. Dead: all nine are still `attgenerated = 's'` at their original positions.

---

## Unverified

**S-7 is untouched and everything above assumes the plumbing.** Every probe here ran against
`tests/shim.sql`, which stands up `auth.uid()` and the three PostgREST roles and does not
reproduce GoTrue minting a JWT or PostgREST mapping it to a role. Nothing in this report is
evidence about that half. The shim's deliberate omission of the `storage` schema means the
two vessel-photo assertions reported themselves unrun here as designed, which is the whole of
the difference between 204 and 206.

**S-41 was not probed.** `subject_resolver.name_expression` is interpolated into dynamic SQL
unquoted and by necessity, since it is an expression rather than an identifier. Writing it
requires `is_admin()` on both the table and `register_subject_resolver`, so it is not an
escalation from below, and `resolve_subject_name` is invoker so the expression runs with the
reader's own rights rather than the author's. What I did not check is whether a registered
expression can have effects at all, given that `resolve_subject_name` is declared `stable` and
PostgreSQL does not enforce that over `execute`. Checking it needs a decision about whether an
admin planting a side-effecting expression is in the threat model, which is the winemaker's
call rather than mine.

---

## What is sound

`0021` is the strongest migration in the range: the column allow-list refuses in words, it
defaults new columns to protected rather than to writable, and it is the one place in this
tree where a cellar user's refusal is visible to the cellar user. `0025` implements the A22
ruling exactly as ruled and every half of it raises rather than matching zero rows. `0026`'s
deflation to null is deliberate, documented and asserted. The instruments reproduce their own
numbers from a clean clone on a different engine, which is what `CURRENT-BASELINE.md` was
written to make possible, and it worked.

The pattern in the six exploitable findings is one thing, not six. Five of them are a
predicate that cannot determine an answer permitting instead of refusing, or a proof that
stopped proving when its type stopped being closed. Both enum conversions did what they set
out to do. What neither did was ask which other predicates were resting on the closed type
without saying so, and the instrument built to answer exactly that question does not look at
the layer where the answers are.
