# R-4: business rules in the client

**Repository:** github.com/VigneronVitae/VSV-Management-Software
**Date of review:** 2026-09-11
**Reviewer note:** read-only. No patch is proposed anywhere below.

---

## Report header

### 1. Tier

**Tier A.** Full tree on disk at a pinned SHA. Route 1 worked on the first attempt:
`git clone https://github.com/VigneronVitae/VSV-Management-Software` over the sandbox
shell, which has egress through the session's HTTPS proxy. No fallback route was
needed and none was used. Citations below are `path:line` and every line number was
read off `cat -n` of the file on disk.

### 2. Commit

```
$ git rev-parse HEAD
c3eae3c7c262544e4b2e29526b513c964c6852fe
```

This is the baseline commit itself, not a descendant. `main` is at the baseline;
`origin/main` and local `main` agree. The only other remote ref is the stale
`claude/sql-files-to-markdown-i31rob`, which was not read.

### 3. Canaries

| Canary | Present |
|---|---|
| On `main`, not `claude/sql-files-to-markdown-i31rob` | yes, `* main` with `origin/HEAD -> origin/main` |
| Tree is not the LICENSE-only pre-merge `main` | yes, 42 files |
| `supabase/migrations/0005_account_and_walk.sql` | yes, 340 lines |
| `tests/schema_assertions.sql` | yes, 412 lines |
| `packages/cellar/src/walk.ts` | yes, 805 lines |
| `docs/session-reports/2026-09-08-walk.md` | yes |
| 42 tracked files | yes, `git ls-files \| wc -l` = 42 |

### 4. File table

Every file attempted. All whole; nothing truncated, nothing failed.

| Path | State | Lines |
|---|---|---|
| `packages/cellar/src/walk.ts` | whole | 805 |
| `packages/cellar/src/pickers.ts` | whole | 201 |
| `packages/cellar/src/ui.ts` | whole | 141 |
| `packages/cellar/src/scan.ts` | whole | 125 |
| `packages/cellar/src/sticky.ts` | whole | 35 |
| `packages/cellar/src/index.ts` | whole | 3 |
| `packages/core/src/kernel.ts` | whole | 297 |
| `packages/core/src/types.ts` | whole | 125 |
| `packages/core/src/env.ts` | whole | 27 |
| `packages/core/src/index.ts` | whole | 6 |
| `apps/web/src/index.ts` | whole | 27 |
| `supabase/migrations/0001_core_schema.sql` | whole | 370 |
| `supabase/migrations/0002_derived_and_rls.sql` | whole | 334 |
| `supabase/migrations/0003_parties_and_products.sql` | whole | 284 |
| `supabase/migrations/0004_terms_and_effects.sql` | whole | 519 |
| `supabase/migrations/0005_account_and_walk.sql` | whole | 340 |
| `tests/schema_assertions.sql` | whole | 412 |
| `CLAUDE.md` | whole | 130 |
| `packages/cellar/docs/spec.md` | whole | 328 |
| `docs/sorry-ledger.md` | whole | 156 |
| `docs/compost-ledger.md` | whole | 72 |
| `docs/status-ledger.md` | whole | 112 |
| `package.json`, `biome.json`, the three package manifests | whole | small |

Client corpus actually read: 1,465 lines across `packages/cellar/src/` and
`packages/core/src/`, plus the 27-line web shell. The prompt's estimate of roughly
1,800 includes the shell and the manifests.

### 5. One thing the reader must hold while reading this report

**Nothing below was observed at runtime.** `docs/status-ledger.md:47` grades the
backfill screens "In progress: written, typechecked, built, and never run against a
Supabase instance." Every verdict of EXPLOITABLE here means "a concrete path exists
against the tree as it stands, derived by reading," not "someone watched it happen."
Where the distinction changes the confidence in a finding, the finding says so in its
own words. Where a finding cannot be settled without a running instance, a real JWT,
or a camera, it is marked UNVERIFIED and left there.

---

## Findings table

| id | Verdict | One line |
|---|---|---|
| R-4-1 | EXPLOITABLE | The session-defaults module is inert: every pin is on a control that cannot restore, every restore is on a control that cannot be pinned |
| R-4-2 | EXPLOITABLE | The empty-vessel path binds codes outside any transaction, and one rejected code leaves a vessel that can be neither completed nor retried |
| R-4-3 | EXPLOITABLE | The only ownership control in the walk sets the vessel's owner and leaves the wine inside it facility-owned |
| R-4-4 | EXPLOITABLE | `slug()` derives `term.value`, the machine key the database itself looks terms up by, and lives only in the client |
| R-4-5 | EXPLOITABLE | The client reimplements `is_admin()` and drops the `active` conjunct |
| R-4-6 | EXPLOITABLE | Every non-empty and trim rule is client-only; the database accepts `''` for every name it declares `not null` |
| R-4-7 | EXPLOITABLE | A volume of exactly zero litres is rendered as "unrecorded" |
| R-4-8 | EXPLOITABLE | Inline-added terms sort above every seeded term, because the client owns picker ordering and never sets `sort_order` |
| R-4-9 | EXPLOITABLE | A `type="number"` field holding text the browser rejects writes null, silently, with no error anywhere |
| R-4-10 | LATENT | The vessel attribute bag is a client-invented schema that caches term labels beside term ids |
| R-4-11 | LATENT | `facilityParty()` re-derives `facility_party_id()` in TypeScript |
| R-4-12 | LATENT | Lot stage, unit, and history generation carry the same default in both the client and the kernel function |
| R-4-13 | LATENT | The client sets `node.quantity` from the placement volume: a derived value stored, with nothing reconciling the two |
| R-4-14 | LATENT | Lot names are composed by a client rule with no database counterpart |
| R-4-15 | LATENT | The day boundary is the phone's; the kernel's is the server's |
| R-4-16 | LATENT | `addTerm` cannot satisfy `operation_has_an_effect`, so the first operation picker with add-inline breaks |
| R-4-17 | DIVERGENT | `walk.ts:46` says the screen order is the order the schema enforces; the schema enforces one of the three gates |
| R-4-18 | DIVERGENT | `kernel.ts:288` claims the photo bucket is confidential; the storage policy lets every authenticated user read all of it |
| R-4-19 | BY DESIGN | Lots always default to the facility party and no screen can create a client-owned lot |
| R-4-20 | UNVERIFIED | `lot_name ?? "unnamed lot"` turns an RLS refusal into a data state |
| R-4-21 | UNVERIFIED | The six-character password minimum is asserted by the client and configured in GoTrue |
| R-4-22 | UNVERIFIED | The camera decode path has never met a camera |
| R-4-23 | NOT A DEFECT | Six places where the kernel's answer is transported rather than recomputed |

---

## 1. Classification pass

Every branch, comparison, arithmetic operation, validation, sort, filter, default, and
derived display value in the client corpus, classified. A **rule** is anything a second
client written against the same database would have to reproduce to behave the same way.

### `packages/core/src/env.ts` (27 lines)

Transport only. `readConfig` reads two Vite-substituted variables and throws
`MissingConfig` if either is absent (`env.ts:17-22`). No rule.

### `packages/core/src/types.ts` (125 lines)

Presentation and transport, with one exception. The row shapes mirror the views. The
exception is `NodePayload.owner_id` (`types.ts:105`), an optional field the only screen
that builds a `NodePayload` never populates. That absence is R-4-3.

`VesselState` (`types.ts:61-81`) omits `lot_owner_id`, which `vessel_state` does select
(`0004:298`). The client therefore cannot tell facility-owned wine from client-owned
wine even when the view hands it over. Contributes to R-4-3.

### `packages/core/src/kernel.ts` (297 lines)

| Locator | What it is | Class |
|---|---|---|
| `kernel.ts:24-30` | lazy singleton client | transport |
| `kernel.ts:34-36` | `crypto.randomUUID()` for ids | transport, and the hard rule in `CLAUDE.md:60` |
| `kernel.ts:40-61` | four auth pass-throughs | transport |
| `kernel.ts:69-75` | `Array.isArray(data) ? data[0] : data` | transport, documented at `kernel.ts:63-68` |
| `kernel.ts:77-87` | reads `app_user` including `active` | transport; nothing consumes `active` (R-4-5) |
| `kernel.ts:91-101` | `.eq("active", true)`, `.order("sort_order").order("label")` | **rule** (R-4-8) |
| `kernel.ts:105-118` | `addTerm`: derives `value`, omits `sort_order`, omits `attributes` | **rule** (R-4-4, R-4-8, R-4-16) |
| `kernel.ts:122-130` | `slug()` | **rule** (R-4-4) |
| `kernel.ts:134-143` | `facilityParty()`: `kind='facility' and active` | **rule**, duplicated (R-4-11) |
| `kernel.ts:145-154` | `parties()`: `active`, ordered kind then name | rule (the active filter), presentation (the order) |
| `kernel.ts:190-194` | `vessels()` ordered by name | presentation |
| `kernel.ts:198-203` | `resolveCode` takes `rows[0]` | transport (R-4-23) |
| `kernel.ts:226-241` | `createVesselWithWine` hardcodes `p_generate_history: true` | **rule**, duplicated (R-4-12) |
| `kernel.ts:243-272` | two-query label join, `?? "unknown operation"` | transport; fallback unreachable (R-4-23) |
| `kernel.ts:280` | photo path `${vesselId}/photo.${suffix}` | **rule** (R-4-18) |
| `kernel.ts:282` | content type `file.type \|\| "image/jpeg"` | **rule**, minor (R-4-18) |
| `kernel.ts:291-297` | 600-second signed url | **rule** (R-4-18) |

### `packages/cellar/src/ui.ts` (141 lines)

DOM plumbing, as the shallow pass would say, with two rules hiding in it.

| Locator | What it is | Class |
|---|---|---|
| `ui.ts:8-25` | `el()` attribute setter, skips null/undefined/false | presentation |
| `ui.ts:57-71` | `run()` disables the button while a write is in flight | **rule** (idempotency), backed by the database (R-4-23) |
| `ui.ts:104` | `value: () => input.value.trim()` | **rule** (R-4-6) |
| `ui.ts:107-117` | checkbox `value()` returns `String(checked)` | presentation |
| `ui.ts:89-105` | `type`, `placeholder`, `required` plumbing | presentation; `required` is accepted and never passed by any caller |

`FieldOptions.required` (`ui.ts:78`) is declared and never used by any call site in the
tree. Dead.

### `packages/cellar/src/sticky.ts` (35 lines)

Intended as session defaults. Inert in fact. See R-4-1. `clearAll` (`sticky.ts:32-35`)
is exported and never called.

### `packages/cellar/src/scan.ts` (125 lines)

| Locator | What it is | Class |
|---|---|---|
| `scan.ts:46-47` | `code.trim()`, empty refused | **rule** (R-4-6) |
| `scan.ts:48-51` | in-form duplicate check, case-sensitive | rule, and a strict subset of the database's (R-4-23) |
| `scan.ts:52-64` | collect-or-not branch | presentation |
| `scan.ts:77-93` | camera lifecycle and the failure banner | transport, hardware (R-4-22) |
| `scan.ts:105-110` | Enter key submits | presentation |

### `packages/cellar/src/pickers.ts` (201 lines)

| Locator | What it is | Class |
|---|---|---|
| `pickers.ts:34-44` | pin toggle | intended rule, inert (R-4-1) |
| `pickers.ts:75` | `addTerm(kind, label)` with no attributes | **rule** (R-4-16) |
| `pickers.ts:91-94`, `169-174` | `selectId ?? select.value ?? sticky` | **rule**, broken (R-4-1) |
| `pickers.ts:96-102`, `176-185` | empty-option composition | presentation |
| `pickers.ts:103`, `186` | restore selection if still present | presentation |
| `pickers.ts:104`, `187` | open the add form when the list is empty | presentation, and the C-6 surviving fragment |
| `pickers.ts:107-109`, `190-192` | `remember()` on change | inert (R-4-1) |
| `pickers.ts:147-162` | inline location creation | **rule** (R-4-6, via `addLocation`) |

### `packages/cellar/src/walk.ts` (805 lines)

| Locator | What it is | Class |
|---|---|---|
| `walk.ts:69-80` | the four-gate route | **rule**, stricter than the schema (R-4-17) |
| `walk.ts:104` | "At least six characters" | **rule**, asserted not enforced (R-4-21) |
| `walk.ts:160` | `if (!name.value()) return;` on claim | **rule** (R-4-6) |
| `walk.ts:200` | `user.role !== "admin"` | **rule**, a partial copy of `is_admin()` (R-4-5) |
| `walk.ts:219` | `if (!name.value()) return;` on facility | **rule** (R-4-6) |
| `walk.ts:236` | `kit.filter((v) => !v.is_empty).length` | presentation over a kernel boolean (R-4-23) |
| `walk.ts:281-283` | `is_empty` branch, `lot_name ?? "unnamed lot"`, `current_volume_l ?? "?"` | **rule** (R-4-20); note `??` here and `?` at 713 |
| `walk.ts:287` | `(v.codes ?? []).join(", ") \|\| "no codes"` | presentation |
| `walk.ts:323-325` | location needs a name | **rule** (R-4-6) |
| `walk.ts:330-332` | `kind.value() \|\| null`, `ambient.value() ? Number(...) : null` | **rule** (R-4-9) |
| `walk.ts:385` | owner select offers client parties only | **rule** (R-4-3) |
| `walk.ts:458` | `capacity.value() ? Number(...) : null` | **rule** (R-4-9) |
| `walk.ts:460` | `owner.value \|\| null`, so "" means facility | **rule** (R-4-3) |
| `walk.ts:461-468` | the attribute bag, ids and labels both | **rule** (R-4-10) |
| `walk.ts:471-475` | `ready()`: type and name required | **rule** (R-4-6) |
| `walk.ts:517`, `630` | photo uploaded before the row exists | **rule** (R-4-18) |
| `walk.ts:520` | bind each code in a loop | **rule** (R-4-2) |
| `walk.ts:571` | vintage placeholder is the current year | presentation |
| `walk.ts:592-596` | `autoName()` | **rule** (R-4-14) |
| `walk.ts:621-624` | lot needs a name | **rule** (R-4-6) |
| `walk.ts:636` | `stage: "maturation"` | **rule**, duplicated (R-4-12) |
| `walk.ts:641` | `unit: "L"` | **rule**, duplicated (R-4-12) |
| `walk.ts:642`, `644` | quantity and placement volume from one field | **rule** (R-4-13) |
| `walk.ts:695-698` | zero events means "an honest zero" | presentation, and it cites S-17 correctly |
| `walk.ts:709`, `769` | `[variety, vintage].filter(Boolean).join(" ")` | **rule**, the same composition as `autoName` written twice (R-4-14) |
| `walk.ts:711-714`, `772-777` | `current_volume_l ? ... : "unrecorded"` | **rule** (R-4-7) |
| `walk.ts:717` | `facility_owned ? "Facility" : owner_name` | transport (R-4-23) |
| `walk.ts:733-734` | `new Date(e.at).toLocaleDateString()` | **rule** (R-4-15) |
| `walk.ts:765` | `is_empty ? "empty" : lot_name` | transport, then R-4-20 |

**Count.** Thirty-one items classify as rules. Nine of them have no database
counterpart at all; five are duplicated in both places; the rest are validation that
the database declines to repeat.

---

## 2. Where each rule's counterpart lives

| Rule in the client | Database counterpart |
|---|---|
| `slug()` derives `term.value` | **nowhere.** `term.value` is `text not null` with `unique (kind, value)` (`0004:48,55`). Nothing derives it |
| picker order: `sort_order` then `label` | **nowhere.** `term_kind_idx` (`0004:70`) is shaped the same way; an index is not an ordering rule |
| `addTerm` omits `sort_order` | partial: `sort_order int not null default 0` (`0004:51`) |
| non-empty name, trimmed | **nowhere.** No `check` constraint in any of the five migrations touches string emptiness (verified by grep across all `check (` occurrences) |
| vessel type required | `vessel.type_id uuid not null` plus the composite FK to `term(id, kind)` (`0004:216-219`). Both |
| vessel name unique per type | database only: `vessel_type_name_key` (`0004:222`) |
| owner "" means facility | **duplicated and ambiguous.** `vessel.owner_id` nullable (`0003:88`), `facility_owned = (owner_id is null)` (`0004:280`). Nothing forbids `owner_id = facility_party_id()` |
| stage defaults to maturation | **duplicated.** `coalesce((p_node->>'stage')::node_stage, 'maturation')` (`0005:265`) |
| unit defaults to L | **duplicated.** `coalesce(..., 'L')` (`0005:272`) |
| history is generated | **duplicated.** `p_generate_history boolean default true` (`0005:237`) |
| `node.quantity` = placement volume | **nowhere.** `node.quantity` (`0001:172`) and `placement.volume_l` (`0001:233`) are independent columns |
| lot name composition | **nowhere.** `node.name text not null` (`0001:170`). `spec.md:98` says "autopopulated, editable" and does not say by what |
| the facility is the active facility party | **duplicated.** `facility_party_id()` (`0003:60-66`) is the same query |
| admin means role = admin | **duplicated and narrowed.** `is_admin()` is `role = 'admin' and active` (`0001:95-106`) |
| vessel attribute keys | **nowhere.** `attributes jsonb not null default '{}'` (`0001:144`). `spec.md:118` names the concepts, not the keys |
| photo path and bucket | **partial.** The bucket exists (`0005:315-317`); the path convention does not |
| the day an event happened | **divergent.** `date_trunc('day', now())` in `next_cap_action` (`0004:408`) |
| code trimmed, non-empty | partial: `vessel_code.code text not null unique` (`0003:118`) refuses duplicates, accepts `''` |
| code not already in this form | database is stronger: global unique plus `bind_vessel_code`'s raise (`0003:217-218`) |
| double-submit guard | database is stronger for this path: `unique (type_id, name)` |
| vintage is a number | **nowhere.** `node.vintage int` (`0001:169`) with no range check |
| volume is a number | **nowhere.** `placement.volume_l numeric(10,2)` with no positivity check |
| capacity is a number | **nowhere.** `vessel.capacity_l numeric(10,2)`, same |

**Rules with no counterpart: nine.** Slug derivation, picker ordering, name
non-emptiness and trimming, the quantity-equals-volume convention, lot naming, the
attribute bag's key schema, the photo path convention, the meaning of a day, and
every numeric range.

**Rules duplicated in both places: five.** Stage, unit, history generation, the
facility lookup, and admin status. Per the prompt these are the worse finding, and
one of the five has already drifted: R-4-5.

---

## 3. The second-client test

A second client, written from `packages/cellar/docs/spec.md` and the five migrations
alone, with no sight of `packages/cellar/src/`. What it gets wrong, by screen, by
value, by divergence.

**Screen: any picker with an add-inline path. Value: `term.value`.**
The second client writes "Tempranillo" and derives `tempranillo`, or `Tempranillo`, or
`tempranillo-1`, or nothing at all if it assumes the database generates it. The schema
demands only that `(kind, value)` be unique. A client that lowercases and hyphenates
produces `pinot-noir` beside the seeded `pinot_noir`, and the pickers in both clients
then show two Pinot Noirs whose lots never join. Worse, the accent handling is
load-bearing: this client normalizes NFD and strips combining marks, so
`Grüner Veltliner` becomes `gruner_veltliner` and matches the seed at `0004:105`. A
second client that skips the normalize step produces `gr_ner_veltliner`, which is a
distinct term, which is a distinct variety, which is a distinct template match in
`generate_inferred_history` (`0005:193`). The divergence is silent and it is at the
level of the object model.

**Screen: home, vessel list. Value: the sort order of every picker.**
The second client orders by `label`. This one orders by `sort_order`, then `label`,
and writes every new term at `sort_order` 0. Riesling is 10. So on this client, every
term a person added during the walk sits above every seeded variety; on the second
client it sits alphabetically among them. Two people at two phones read the same list
in two orders, which is precisely the failure T1-1 exists to prevent, arriving from
the direction T1-1 does not look.

**Screen: vessel and wine. Value: `node.name`.**
This client composes `variety label + " " + vintage` and stops writing once the person
touches the field (`walk.ts:593`). The second client writes `2024 Chardonnay`, or
`Chardonnay 2024 B23`, or leaves it to the person. Lot name is the string on the
chalk mark and the string in every report that groups by lot. Nothing reconciles the
two conventions and no constraint notices.

**Screen: vessel and wine. Value: `node.quantity`.**
This client writes the placement volume into `node.quantity` as well
(`walk.ts:642,644`). The second client reads `spec.md:99`, "weight at bin stage,
volume after," and might reasonably write nothing at maturation, since the volume is
already on the placement. `lot_state` then reports `quantity` null and
`total_volume_l` 220 for one lot and 220 for both on another, and any report that
picks one column is wrong for half the cellar.

**Screen: vessel and wine. Value: `vessel.attributes`.**
This client writes six keys: `cooper`, `cooper_label`, `wood`, `wood_label`,
`fill_count`, `toast` (`walk.ts:461-468`). `spec.md:118` names "cooper, wood, fill
count, toast" in prose. A second client writes `cooper_id`, or nests them under
`barrel`, or writes the cooper's label alone because that is what a person reads. The
column is `jsonb` and refuses none of it. No query in the tree reads any of these
keys, so the divergence surfaces the first time one is written.

**Screen: vessel and wine. Value: ownership.**
The second client reads `0003:80-81`, sees `node.owner_id not null default
facility_party_id()`, sees `vessel.owner_id` nullable at `0003:88`, and has no way to
know that this client treats an empty owner select as facility and never sets the
node's owner at all. If the second client sets `node.owner_id` from the same control,
the two clients produce different owners for identical user input, and `node_read`
(`0003:282-283`) then shows different cellars to the same client login depending on
which phone recorded the barrel.

**Screen: the result screen and the scan screen. Value: volume.**
This client prints "unrecorded" when `current_volume_l` is 0 (`walk.ts:713`,
`walk.ts:774`) and "0" when it is 0 on the home list (`walk.ts:283`). The second
client prints "0 L" everywhere. Same row, three renderings, two of them in this
client alone.

**Screen: any event list. Value: the date.**
`toLocaleDateString()` renders in the viewer's timezone. `next_cap_action` counts by
`date_trunc('day', now())` in the server's. A second client that formats server-side,
or in a fixed winery timezone, disagrees with this one about which day a 11pm
punchdown belongs to, and the cap sequence is computed from that count (`0004:402-410`).

**What was checked and found clean.** The second client cannot get `is_empty`,
`effective_temp_c`, `facility_owned`, `codes`, `type` label, `variety` label, or
`product_type` label wrong, because all seven are columns of `vessel_state` and this
client reads them rather than recomputing them. It cannot get code resolution wrong,
because `resolve_vessel_code` is the only path. It cannot get admin assignment wrong,
because `claim_account` decides and the client says so on screen (`walk.ts:153-155`).
It cannot get atomicity wrong on the wine path, because `create_vessel_with_wine` is
one transaction. Those are real and they are the reason this is not a worse report.

**This is not a null result and it should not be read as one.** The prompt warns that a
clean answer to question 3 is more likely an audit failure than a property of the code.
The audit found eight concrete divergences. The reason the number is not higher is that
most of the app does not exist: intake, press, topping mode, cap management and the
board are all "Specified" in `docs/status-ledger.md`. The client surface that could hold
rules is currently four screens. The rules-per-screen density is the number to watch,
and it is already high enough that the decay `CLAUDE.md:62-66` predicts is visible at
the first commit rather than the tenth.

---

## 4. The inverse direction

The prompt names five decisions to check. Each, with what the client does.

**Admin status.** `is_admin()` (`0001:95-106`) is `role = 'admin' and active`. The
client checks `user.role !== "admin"` (`walk.ts:200`) and ignores `active`, which it
fetched (`kernel.ts:81`). This is a live divergence, not a stylistic one. See R-4-5.

**Topping compatibility.** `topping_check` (`0004:422-502`) reads its match fields from
the operation's `predicate` attribute, which is the configurable form introduced in
0004. The client never calls it, and topping mode is not built. **No client-side copy
exists.** Clean.

**Template matching.** `generate_inferred_history` (`0005:191-195`) selects the oldest
active template whose `variety_id` matches the node's. The client's only involvement is
passing `p_generate_history: true` (`kernel.ts:237`), which duplicates the function's
own default rather than the matching rule. The matching itself is entirely kernel-side.
Clean, with a small duplicated default logged as R-4-12.

**Vessel occupancy.** `placement_one_lot_per_vessel` (`0001:241-242`) is the rule;
`is_empty` (`0004:301`) is its read surface. The client reads `is_empty` twice
(`walk.ts:236`, `walk.ts:281`) and computes it never. It also never attempts a
placement into a vessel that might be occupied, because the only placement it writes is
into a vessel it created in the same transaction. Clean.

**Code resolution.** `resolve_vessel_code` (`0004:317-326`) joins `vessel_code` to
`vessel_state` on an active code. `vessel_code.code` is unique table-wide (`0003:118`),
so the set is at most one row and the client's `rows[0] ?? null` (`kernel.ts:202`)
cannot pick wrong. Clean.

**One the prompt does not name, and should.** The facility party. `facility_party_id()`
(`0003:60-66`) is `select id from party where kind = 'facility' and active`.
`facilityParty()` (`kernel.ts:134-143`) is the same query in PostgREST. Two
implementations of one rule, agreeing today. R-4-11.

---

## 5. Field validation

For each constraint the client enforces: does the database refuse the same value?

| Field | Client enforcement | Database refuses it? |
|---|---|---|
| vessel type | `ready()` requires non-empty (`walk.ts:472`) | **yes.** `not null` plus composite FK to `term(id,'vessel_type')` |
| vessel name, present | `ready()` (`walk.ts:473`) | **no.** `name text not null` accepts `''` |
| vessel name, trimmed | `field().value()` trims (`ui.ts:104`) | **no.** `" B23 "` and `"B23"` are two vessels under `unique (type_id, name)` |
| vessel name, unique per type | none | **yes**, and the person sees a raw Postgres error |
| capacity, numeric | browser sanitizes `type="number"` | **partially.** `numeric(10,2)` refuses non-numeric and overflow past 99,999,999.99 |
| capacity, positive | none | **no.** A capacity of −228 is accepted by both sides |
| location name, present | `walk.ts:323` and `pickers.ts:149` | **no.** `not null unique` accepts `''`, once |
| ambient temperature, range | none | **partially.** `numeric(5,2)` caps at ±999.99, which is not a temperature check |
| lot name, present | `walk.ts:621` | **no.** `node.name not null` accepts `''` |
| vintage, range | none. Placeholder only (`walk.ts:571`) | **no.** `vintage int` accepts 3, 20245, −1 |
| volume, positive | none | **no.** No check on `placement.volume_l` |
| fill count | none | **no.** Free jsonb |
| toast | none | **no.** Free jsonb |
| code, present and trimmed | `scan.ts:46-47` | **no.** `code text not null unique` accepts `''` |
| code, not duplicated in form | `scan.ts:48` | **yes**, and more strictly: global unique plus `bind_vessel_code`'s raise |
| owner is a client party | select offers client parties only (`walk.ts:385`) | **no.** `vessel.owner_id` references `party(id)`, facility included |
| password ≥ 6 characters | hint text only (`walk.ts:104`), no `minlength`, no check | GoTrue, not this schema. See R-4-21 |
| email format | `type="email"` (`walk.ts:97`) | **inert in the client.** There is no `<form>` and the button is `type="button"` (`ui.ts:48`), so no constraint validation ever runs. GoTrue refuses malformed addresses on the round trip |
| double submit | button disabled in flight (`ui.ts:57-71`) | **yes** for these two screens: `unique (type_id, name)` refuses the second vessel |

**Six rows where the answer is a flat no on a value a person can type.** Vessel name,
location name, lot name, and code all accept the empty string in the database, and in
every case the *only* thing standing between a user and an unnamed row is a
three-line check in a click handler. `tests/schema_assertions.sql` has 31 assertions
and none of them tries an empty name.

---

## 6. Smallest mechanical check per finding

Named, not written.

| Finding | Check |
|---|---|
| R-4-1 | A unit test asserting `stickyValue(k)` is non-empty after `setPinned(k, true, "x")` for every key the two modules actually use; equivalently, a grep asserting the set of `stickyKey:` literals and the set of `stickyValue("...")` literals are the same set |
| R-4-2 | A grep forbidding `await` inside a `for` loop that follows an `await` on a write, in `packages/cellar/src/`. Cheaper: a lint rule banning any call to `bindCode` outside `kernel.ts` |
| R-4-3 | A schema assertion: insert a vessel with `owner_id` set and a node in it with the default owner, and assert the pair is refused or flagged. Failing that, a `doctor` check for `vessel.owner_id is not null and node.owner_id = facility_party_id()` |
| R-4-4 | A schema assertion that `term.value` equals a database-side `slug(label)` for every row, which requires moving `slug` into SQL. The check and the fix are the same move |
| R-4-5 | A grep forbidding `role ===` and `role !==` anywhere in `packages/cellar/src/`; role comparisons belong behind one `isAdmin()` in `core` that mirrors `is_admin()` |
| R-4-6 | A schema assertion per named column: `insert ... values ('')` must raise. Four assertions |
| R-4-7 | A lint rule forbidding a bare numeric field of `VesselState` in a ternary condition; `?? ` is the only correct operator on a nullable number |
| R-4-8 | A schema assertion that `sort_order` is distinct within each `kind`, or a `doctor` check for terms at `sort_order` 0 alongside seeded terms |
| R-4-9 | A lint rule forbidding `Number(x.value())` guarded by the truthiness of `x.value()`; the guard belongs on `input.validity.valid` |
| R-4-10 | A schema assertion that no `vessel.attributes` key ends in `_label`. Blunt, and it catches exactly this class |
| R-4-11 | A grep forbidding `.eq("kind", "facility")` outside a call to an RPC; `facility_party_id()` should be exposed as one |
| R-4-12 | A grep for the literals `"maturation"`, `"L"`, and `p_generate_history` in `packages/`. Each should appear zero times in the client |
| R-4-13 | A `doctor` check: for any node with exactly one open placement, `quantity` and `volume_l` agree or `quantity` is null |
| R-4-14 | An import restriction: nothing in `cellar` may compose `node.name`. The check is a grep for assignment to `lotName.input.value` |
| R-4-15 | A grep forbidding `toLocaleDateString`, `toLocaleString`, and `new Date(` on any value that came off the wire |
| R-4-16 | A type-level check: make `addTerm`'s signature require `attributes` when `kind` is `"operation"`. TypeScript already has the discriminated union for it |
| R-4-17 | None mechanical. The comment is the defect and a human reads it |
| R-4-18 | A schema assertion that `storage.objects` select policy for `vessel-photos` is not `using (bucket_id = ...)` alone |
| R-4-19 | Already discharged by the screen text; a `doctor` count of nodes by owner would make the consequence visible |
| R-4-20 | A `doctor` check for placements whose node is unreadable to the current role, run as each of the three account kinds `tests/schema_assertions.sql` already builds |
| R-4-21 | None mechanical from inside this repo. The GoTrue setting is not in the tree |
| R-4-22 | None mechanical. A camera, a barrel, and a person |

**The two checks that would catch the most.** First: a grep over
`packages/cellar/src/` and `packages/core/src/` for every string literal that also
appears in `supabase/migrations/`, failing on any match not inside a
`kernel().rpc(...)` call or a column list. That one check catches R-4-4, R-4-11 and
R-4-12 at once, and it is the mechanical form of the rule in `CLAUDE.md:62-66`. Second:
a schema assertion file section titled "values the client refuses and the database
does not," seeded with the six rows from section 5. That one catches R-4-6 permanently
and makes the gap visible to whoever writes the next screen.

**Note on where these checks would run.** `CLAUDE.md:86` names `bun run test` in the
definition of done. `package.json` has no `test` script. `CLAUDE.md:71-75` says lint
will enforce the module import restriction; `biome.json` enables the recommended
preset and nothing else, which has no such rule. Every check proposed above currently
has nowhere to live, which is its own finding and is logged as the last line of R-4-17.

---

## Findings

### EXPLOITABLE

**R-4-1. The session-defaults module is inert: every pin is on a control that cannot restore, and every restore is on a control that cannot be pinned.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/cellar/src/sticky.ts:10-30`; `packages/cellar/src/pickers.ts:56`, `91-94`, `169-174`; `packages/cellar/src/walk.ts:363`, `372`, `377`, `401`, `406`, `412`, `417`, `566`, `570`, `575`; `packages/cellar/src/walk.ts:256`.
*What is wrong:* Two independent faults compose into total inertness. The pin checkbox is rendered only by `shell()` for pickers carrying a `stickyKey` (`pickers.ts:56`), so the only keys that can ever reach `setPinned` are `vessel_type`, `location`, `cooper`, `wood`, `variety` and `product_type`; the only keys read back through `stickyValue` at a field are `capacity`, `fill_count`, `toast` and `vintage`. The two sets do not intersect. Separately, the pickers' own restore path is `selectId ?? select.value ?? stickyValue(key)` (`pickers.ts:93`, `171`), and `HTMLSelectElement.value` is the empty string rather than null or undefined when the element has no options, so `??` never reaches its third operand. `remember()` writes only when the key is pinned (`sticky.ts:19`), so the four text keys are never stored either. The whole module is a no-op and `clearAll` is exported and uncalled.
*How it surfaces:* The person adds barrel B23, pins "keep" on Type and Cooper, presses Save, then "Add another". Type resets to the first option in the list and Cooper to none, with both pin boxes still visibly checked. `walk.ts:256` has already told them "the first one is the longest; the rest remember your answers." Fifty barrels later this is the difference between an hour of work and an afternoon, which is exactly the claim `sticky.ts:4-5` makes for the design.
*Resolves when:* the set of keys passed as `stickyKey` and the set passed to `stickyValue` are the same set, and the picker restore chain uses an operator that treats the empty string as absent.
*Load-bearing:* yes. It is the only concession the walk makes to fifty repetitions, it is promised on screen, and it does nothing.

**R-4-2. The empty-vessel path binds codes outside any transaction, and one rejected code leaves a vessel that can be neither completed nor retried.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/cellar/src/walk.ts:512-526`, in particular `519-520`; contrast `supabase/migrations/0005_account_and_walk.sql:225-228` and `280-283`.
*What is wrong:* `vesselScreen`'s save handler calls `addVessel` (one REST insert), then loops `bindOne` over the captured codes (one RPC each), with no transaction around them. `bind_vessel_code` raises `unique_violation` when the code belongs to a different vessel (`0003:217-218`), which is correct behaviour and the whole point of the function. The client catches it into a banner, by which time the vessel row is committed and an arbitrary prefix of the codes is bound. The wine path does not have this problem: `create_vessel_with_wine` does the same four writes in one function and the comment at `0005:225-228` says precisely why. The empty-vessel path reimplements that guarantee in the client and gets it wrong.
*How it surfaces:* Someone peels a sticker off barrel 23, sticks it on barrel 40, and scans both the cooper's barcode and that sticker while adding barrel 40. Save. The vessel is created, the cooper's code binds, the moved sticker raises, the banner says "code X is already bound to vessel Y". Pressing Save again calls `newId()` afresh (`walk.ts:513`) and fails on `unique (type_id, name)`. Pressing Back loses the remaining codes. The vessel now exists with a partial code set and the screen offers no way to finish it. `capture.stop()` is also skipped on this path, so the camera keeps running.
*Resolves when:* the empty-vessel path goes through one kernel function the way the wine path does, or the code binds precede the vessel insert in a way that cannot half-commit.
*Load-bearing:* yes. Stage 0 is an inventory walk and code binding is the thing it is walking around doing.

**R-4-3. The only ownership control in the walk sets the vessel's owner and leaves the wine inside it facility-owned.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/cellar/src/walk.ts:381-397` and `460`; `packages/cellar/src/walk.ts:634-643`; `packages/core/src/types.ts:105`; `supabase/migrations/0005_account_and_walk.sql:274`; `supabase/migrations/0003_parties_and_products.sql:282-283`.
*What is wrong:* `vesselFields` renders an Owner select listing every client party (`walk.ts:385`) and writes the choice to `vessel.owner_id`. The node payload built at `walk.ts:634-643` has no `owner_id` key, so `create_vessel_with_wine` coalesces to `facility_party_id()` (`0005:274`). `NodePayload.owner_id` exists in the type (`types.ts:105`) and no caller sets it. A barrel recorded as belonging to Amica Luna therefore holds wine the database records as belonging to Vitae Springs. The two facts are on adjacent rows written by one button press.
*How it surfaces:* Amica Luna's login reads `node_read` (`0003:282-283`), which returns lots where `owner_id = current_party_id()`. Their wine is owned by the facility, so they see none of it, while `vessel_read` is still blanket `using (true)` from `0002:270` and shows them every barrel in the building. The mistake is invisible from inside the walk, because the result screen prints ownership from `facility_owned`, which is the *vessel's* (`walk.ts:717`). Ownership drives TTB reporting and cost allocation (`0003:21-23`), so the number that is wrong is a federal one.
*Resolves when:* the owner control writes both rows, or the screen states that the control is about equipment and offers a separate lot-owner control, or `create_vessel_with_wine` refuses a client-owned vessel holding a facility-owned lot.
*Load-bearing:* yes. Custom crush is the reason migration 0003 exists and this is the only screen that can express it.

**R-4-4. `slug()` derives `term.value`, the machine key the database itself looks terms up by, and lives only in the client.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/core/src/kernel.ts:120-130`, called from `kernel.ts:112`; `packages/cellar/src/pickers.ts:75`; `supabase/migrations/0004_terms_and_effects.sql:48`, `55`, `74-80`, `407`, `440`.
*What is wrong:* `term.value` is not a cosmetic key. `term_id(kind, value)` (`0004:74-80`) resolves it, `next_cap_action` compares `o.value in ('punchdown','pumpover')` (`0004:407`), `topping_check` defaults its operation to `term_id('operation','topping')` (`0004:440`), and `create_vessel_with_wine` defaults a product type by `term_id('product_type','wine')` (`0005:270`). The rule that turns a typed label into that key is eight chained string operations in TypeScript: NFD normalize, strip combining marks, lowercase, collapse non-alphanumerics to underscore, trim underscores, truncate at 60. Nothing in the database derives or validates it. The truncation is its own hazard: two labels differing only past character 60 collide against `unique (kind, value)` and the second insert fails with a raw Postgres message.
*How it surfaces:* Two ways, and the first needs only this client. A person adds "Pinot noir" inline because the list looked empty; the slug is `pinot_noir`, which collides with the seed at `0004:107`, and the banner at `pickers.ts:80` shows "duplicate key value violates unique constraint term_kind_value_key" to someone standing in a barrel room. The second way is the second client, described in section 3: any client that skips the NFD normalize writes `gr_ner_veltliner` for Grüner Veltliner and creates a variety whose templates never match.
*Resolves when:* the derivation is a database function and `addTerm` sends only the label, or `term.value` carries a check constraint that a client-computed value must satisfy.
*Load-bearing:* yes. `term.value` is the join key between the free tier and the fixed tier, and `0004:36-39` says that split is the point of the migration.

**R-4-5. The client reimplements `is_admin()` and drops the `active` conjunct.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/cellar/src/walk.ts:200`; `packages/core/src/kernel.ts:77-87`, in particular the select at `81`; `supabase/migrations/0001_core_schema.sql:95-106`.
*What is wrong:* `is_admin()` is `role = 'admin' and active`. The client asks `user.role !== "admin"` and routes on the answer. `currentAppUser` fetches `active` and no code path reads it. A deactivated admin is admin to the client and not to any policy. The same omission runs one level up: `route()` (`walk.ts:69-80`) admits any user with an `app_user` row, active or not, so a deactivated cellar user reaches the home screen, the vessel list, and every form on it.
*How it surfaces:* An intern leaves at the end of harvest and someone sets `active = false`, which is the only deactivation mechanism the schema offers. That account still signs in, still sees every vessel and lot in the cellar through the blanket read policies at `0002:270`, and still gets the full set of Add buttons. Pressing one produces an RLS refusal rendered as a raw Postgres error. For a deactivated *admin* on a fresh instance the path is sharper: they are shown "Name the facility", type a name, press the button, and get refused by `party_admin_write` (`0003:239-241`) with no explanation, because the screen that knows how to explain the wall (`walk.ts:201-209`) is the one the role check just skipped.
*Resolves when:* the client's admin test and `is_admin()` are one expression, and `route()` treats an inactive `app_user` as a gate rather than a pass.
*Load-bearing:* yes. It is one of the four decisions `CLAUDE.md` moved into the kernel, and the copy has already lost half of it.

**R-4-6. Every non-empty and trim rule is client-only; the database accepts `''` for every name it declares `not null`.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/cellar/src/ui.ts:104`; `packages/cellar/src/walk.ts:160`, `219`, `323-325`, `472-473`, `621-624`; `packages/cellar/src/pickers.ts:73`, `149`; `packages/cellar/src/scan.ts:46-47`; against `supabase/migrations/0001_core_schema.sql:114`, `133`, `170`; `0003:42`, `118`; `0004:49-50`.
*What is wrong:* Six values are guarded in click handlers and by `field().value()`'s trim, and not one of them is guarded in the schema. Grepping every `check (` in all five migrations returns eleven constraints and none of them mentions `length`, `trim`, or an empty-string comparison. `not null` does not refuse `''`. `unique` does not either, except the second time. So the tree's position is that "a vessel needs a name" is enforced by a three-line branch in a button handler, which is the exact shape `CLAUDE.md:62-66` names as the rule that decays first.
*How it surfaces:* Silently, from this client, because the handlers hold. Loudly from anywhere else: a second client, a Supabase Studio row, a seed script, or a future bulk import writes `name = ''` and the database takes it. `vessel_state` then returns a vessel with an empty name, `vesselList` renders `" (Barrel)"` (`walk.ts:278`), and `unique (type_id, name)` has been silently spent on the empty string for that type.
*Resolves when:* each of the six columns carries a check that a trimmed value is non-empty, and `tests/schema_assertions.sql` tries each one.
*Load-bearing:* yes. T1-1 (`spec.md:61-62`) is about data staying usable, and an unnamed row is the limiting case of unusable.

**R-4-7. A volume of exactly zero litres is rendered as "unrecorded".**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/cellar/src/walk.ts:711-714` and `772-777`; contrast `packages/cellar/src/walk.ts:283`.
*What is wrong:* Both summary rows test `vessel?.current_volume_l` for truthiness and print "unrecorded" when it is falsy. `current_volume_l` is `placement.volume_l`, a nullable `numeric(10,2)` that PostgREST renders as a JSON number, so 0 is falsy and indistinguishable from null at that branch. Null means nobody measured; 0 means somebody measured and wrote zero. The home list, forty lines away, uses `?? "?"` (`walk.ts:283`) and gets it right, so the same value reads two ways in one app.
*How it surfaces:* The person types 0 into "Volume in the vessel, litres" for a barrel that is racked out but not yet cleaned, presses the button, and the confirmation screen says "unrecorded". They type it again. It still says unrecorded. The record is correct and the screen denies it, which is the failure most likely to end in someone writing a second placement. Scanning that barrel later (`walk.ts:774`) says the same thing.
*Resolves when:* both sites use a null test rather than a truthiness test.
*Load-bearing:* no in the sense that the row is correct; yes in the sense that S-8 makes volume reconciliation the open compliance question and a screen that cannot show zero is a screen that cannot show a loss.
*One caveat, stated:* that PostgREST serializes `numeric` as a JSON number rather than a string is read off the contract, not off a running instance. If it were serialized as `"0.00"` the branch would be truthy and this finding collapses to a style note. A single round trip against a real instance settles it.

**R-4-8. Inline-added terms sort above every seeded term, because the client owns picker ordering and never sets `sort_order`.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/core/src/kernel.ts:91-101` (the order clause at `99-100`) and `105-118` (the insert at `112`); `supabase/migrations/0004_terms_and_effects.sql:51`, `101-119`.
*What is wrong:* `terms()` orders by `sort_order` then `label`. That ordering exists nowhere in the database; `term_kind_idx` (`0004:70`) is shaped the same way, but an index is a performance structure and not a contract. `addTerm` inserts without `sort_order`, taking the column default of 0, while every seeded term is 10 through 60. Every term a person creates therefore sorts above every term the migration seeded, in every picker, permanently.
*How it surfaces:* A person adds "Pinot Noir " with a trailing space, or "pinot noir" in lowercase, or a genuinely new variety, during the walk. It lands at the top of the variety list, above Riesling. At 6am the next person opens the picker and takes the first plausible thing they see, which is now a term created by accident rather than the seeded one. C-6 (`compost-ledger.md:52-64`) killed the configuration screens on the grounds that add-inline covers the case; add-inline covers the case and puts its output in the most prominent position in the list, which C-6 did not consider.
*Resolves when:* `addTerm` assigns a `sort_order` past the seeded range, or the ordering rule moves into a view the client reads.
*Load-bearing:* yes. T1-1 is that people pick from a list; which end of the list a thing is on is the whole ergonomics of a picker.

**R-4-9. A `type="number"` field holding text the browser rejects writes null, silently, with no error anywhere.**
*Verdict:* EXPLOITABLE.
*Locator:* `packages/cellar/src/walk.ts:332`, `458`, `466`, `639`, `642`, `644`; `packages/cellar/src/pickers.ts:154`; `packages/cellar/src/ui.ts:89-105`.
*What is wrong:* Six numeric fields are read as `x.value() ? Number(x.value()) : null`. A `type="number"` input whose contents the browser cannot parse reports `value` as the empty string, so the guard takes the null branch. There is no `<form>` anywhere in the tree and the buttons are `type="button"` (`ui.ts:48`), so constraint validation never runs and `:invalid` styling never appears. `ready()` (`walk.ts:471-475`) checks type and name and nothing numeric. The database has no range constraint on any of the six.
*How it surfaces:* Someone enters the vintage as "20 24", or types into the capacity field with a glove on and produces "2 28". The browser silently refuses to hold the value, the field goes blank or stays visually populated depending on the platform, the guard writes null, and the barrel is created with no vintage and no capacity. `autoName()` (`walk.ts:594`) then names the lot "Chardonnay" with no year, which is the string that goes on the chalk mark. Nothing anywhere reports a problem.
*Resolves when:* the guard tests `input.validity.valid` rather than the emptiness of a sanitized string, or the numeric columns carry ranges the database can refuse against.
*Load-bearing:* yes for vintage, which is half the identity of a lot and has no constraint on either side of the wire.

### LATENT

**R-4-10. The vessel attribute bag is a client-invented schema that caches term labels beside term ids.**
*Verdict:* LATENT.
*Locator:* `packages/cellar/src/walk.ts:461-468`; `supabase/migrations/0001_core_schema.sql:142-144`; `packages/cellar/docs/spec.md:118`; `CLAUDE.md:49-51`.
*What is wrong:* Six keys are written into `vessel.attributes`, and two of them, `cooper_label` and `wood_label`, store the `term.label` whose `term.id` sits in the adjacent key. That is a derived value stored, which `CLAUDE.md:49-51` forbids and C-3 (`compost-ledger.md:35-41`) killed in its other form. The key names themselves have no counterpart: `0001:142-143` describes the bag in a comment, `spec.md:118` names the concepts in prose, and nothing declares the spelling. No query in the tree reads any of the six.
*How it surfaces:* Silently, until a term is relabelled, at which point every vessel created before the change carries the old label and every one after carries the new, with no marker saying which. Nothing in the tree can relabel a term today, because C-6 deferred the configuration screens, so reaching this needs a hand-written `update term set label = ...`.
*Resolves when:* the label keys are dropped and the labels are joined from `term` on read, or the bag's shape is declared somewhere a second client can read it.
*Load-bearing:* no today. It becomes load-bearing the moment anything queries by cooper, because half the corpus will answer by id and half by a stale string.

**R-4-11. `facilityParty()` re-derives `facility_party_id()` in TypeScript.**
*Verdict:* LATENT.
*Locator:* `packages/core/src/kernel.ts:134-143`; `supabase/migrations/0003_parties_and_products.sql:60-66`.
*What is wrong:* The database defines the facility as the active party of kind facility, in a stable SQL function used as the default for `node.owner_id` (`0003:81`) and inside `create_vessel_with_wine` (`0005:274`). The client defines it again as a PostgREST filter on the same two columns with `.maybeSingle()`. Both are correct and they agree exactly, which is what makes this the duplication class rather than the divergence class.
*How it surfaces:* Not at all, today. It reaches the surface the first time the definition changes: a second facility, an `org_id` (deferred in `spec.md:27-30`), or a decision that an inactive facility should still resolve for historical lots. Any of those edits `0003:60-66` and leaves `kernel.ts:134-143` answering the old question, and `.maybeSingle()` will start throwing when `party_one_facility` (`0003:57-58`) stops guaranteeing one row.
*Resolves when:* the client calls `facility_party_id()` through an RPC rather than restating it.
*Load-bearing:* no. It is a correct duplicate of a correct function, logged because the prompt is right that duplicates are the worse finding and because this one sits directly under the gate at `walk.ts:77`.

**R-4-12. Lot stage, unit, and history generation carry the same default in both the client and the kernel function.**
*Verdict:* LATENT.
*Locator:* `packages/cellar/src/walk.ts:636`, `641`; `packages/core/src/kernel.ts:237`; `supabase/migrations/0005_account_and_walk.sql:265`, `272`, `237`.
*What is wrong:* `create_vessel_with_wine` coalesces stage to `'maturation'`, unit to `'L'`, and takes `p_generate_history boolean default true`. The client sends all three explicitly with the same values. Three rules, each written twice, each currently agreeing. `spec.md:105-108` is explicit that a backfilled lot entering at maturation is the designed case, so both copies are faithful to the spec; that is not the same as there being one of them.
*How it surfaces:* Silently, on the first divergence. The likeliest is the intake screen, build order 2 (`spec.md:250-251`), which creates nodes at stage `bin` with unit `lbs`. If it reuses `createVesselWithWine` the kernel's coalesce is the safety net and the client's explicit `"maturation"` defeats it.
*Resolves when:* the client stops sending values the function already defaults, or the function stops defaulting values the client always sends. Either, not both.
*Load-bearing:* no. Logged because it is three instances of the named decay in twelve lines of one file.

**R-4-13. The client sets `node.quantity` from the placement volume: a derived value stored, with nothing reconciling the two.**
*Verdict:* LATENT.
*Locator:* `packages/cellar/src/walk.ts:642` and `644`; `supabase/migrations/0001_core_schema.sql:172-173` and `233`; `supabase/migrations/0004_terms_and_effects.sql:341-346`.
*What is wrong:* One field feeds two columns in two tables. At creation there is exactly one placement, so `node.quantity` equals the sum of the lot's open placement volumes by construction, which makes it derivable, which makes storing it the thing T0-2 (`spec.md:47-49`) refuses and C-3 (`compost-ledger.md:35-41`) killed in its other form. `lot_state` already surfaces both numbers side by side, `n.quantity` at `0004:341` and `sum(p.volume_l)` at `0004:346`, and nothing compares them.
*How it surfaces:* The first rack. A lot moves from one barrel into two, the client of the day writes two placements, and `node.quantity` still holds the number from creation. `lot_state` then reports `quantity` 220 and `total_volume_l` 218, and the report that picks the first column is wrong. S-8 (`sorry-ledger.md:67-72`) names volume reconciliation as already unreconciled; this adds a second unreconciled number to the same lot.
*Resolves when:* `node.quantity` is left null after the bin stage, or a `doctor` check asserts the two agree wherever both are present.
*Load-bearing:* yes, prospectively. Every volume figure the app can produce runs through one of these two columns.

**R-4-14. Lot names are composed by a client rule with no database counterpart.**
*Verdict:* LATENT.
*Locator:* `packages/cellar/src/walk.ts:592-596`, `597-600`; and the same composition written a second time at `walk.ts:709` and a third at `walk.ts:769`.
*What is wrong:* The lot name is `variety label + " " + vintage`, filtered for empties, and the rule stops applying once the field carries `data-touched` (`walk.ts:593`). `spec.md:98` says `name` is "autopopulated, editable" without saying from what. `node.name` is `text not null` and nothing derives it. The same two-part composition then appears twice more as a display value on the result and scan screens, so the tree contains three independent copies of one naming rule.
*How it surfaces:* A second client names the lot differently and the two conventions sit in one `node` table with nothing to sort them by. Inside this client it surfaces more subtly: the display composition at `walk.ts:709` reads the *stored* variety and vintage, so a lot whose name was hand-edited shows one string in the title area and another in the Wine row of the same summary, with no indication that they were ever meant to agree.
*Resolves when:* the composition happens in one place, ideally a generated column or a view, and the display reads it rather than rebuilding it.
*Load-bearing:* no. It is the string on the chalk mark and not a number anyone reports.

**R-4-15. The day boundary is the phone's; the kernel's is the server's.**
*Verdict:* LATENT.
*Locator:* `packages/cellar/src/walk.ts:733-734`; `supabase/migrations/0004_terms_and_effects.sql:402-410`, in particular `408`; `supabase/migrations/0001_core_schema.sql:25-27`.
*What is wrong:* Event dates are rendered with `new Date(e.at).toLocaleDateString()`, which resolves in the viewing device's timezone. `next_cap_action` counts today's punchdowns and pumpovers with `e.at >= date_trunc('day', now())`, which resolves in the database's. Two definitions of "today" for one timestamp. `0001:25-27` says the winery is one timezone and nobody should have to think about it, which is a claim about the data and not about the render.
*How it surfaces:* Not yet, because S-17 (`sorry-ledger.md:143-152`) means no events are generated and the event list on the result screen is always empty. It reaches the surface the moment a template is seeded: an inferred step timestamped 23:30 local shows as the next day on a phone set to UTC, which is the default on a device that has never been configured. It reaches it harder when cap management mode (`spec.md:199-202`) is built, since the sequence position is computed from a count over a server-defined day and shown against client-defined dates.
*Resolves when:* the timezone the winery operates in is named in one place and both the render and `date_trunc` use it.
*Load-bearing:* yes, prospectively. Cap management is the first screen that directs rather than records, and it directs off this count.

**R-4-16. `addTerm` cannot satisfy `operation_has_an_effect`, so the first operation picker with add-inline breaks.**
*Verdict:* LATENT.
*Locator:* `packages/core/src/kernel.ts:105-118`, the insert at `112`; `packages/cellar/src/pickers.ts:75`; `supabase/migrations/0004_terms_and_effects.sql:57-64`.
*What is wrong:* `addTerm` defaults `attributes` to `{}` and `termPicker`'s save handler calls it with two arguments (`pickers.ts:75`), never passing attributes. The `operation_has_an_effect` check refuses any `kind = 'operation'` row whose attributes lack one of the four effect values. Today every `termPicker` call site uses `vessel_type`, `location_kind`, `variety`, `cooper`, `wood` or `product_type`, so the path is unreachable.
*How it surfaces:* The first screen that offers `termPicker("operation", ...)`, which build order 4 (`spec.md:253`) implies and which C-6's surviving fragment (`compost-ledger.md:60-61`) promises for every picker. The person types a new operation name, presses "Save and select", and gets "new row for relation term violates check constraint operation_has_an_effect" in a banner. The add-inline path is the specific thing C-6 kept, and it is broken for the one kind where the fixed tier has something to say.
*Resolves when:* `addTerm`'s signature requires attributes for the operation kind, which TypeScript's discriminated unions already express, or the operation picker carries an effect control.
*Load-bearing:* no today, and it becomes load-bearing at exactly the moment C-6's justification is tested.

### DIVERGENT

**R-4-17. `walk.ts:46` says the screen order is the order the schema enforces; the schema enforces one of the three gates.**
*Verdict:* DIVERGENT.
*Locator:* `packages/cellar/src/walk.ts:43-49` against `packages/cellar/src/walk.ts:69-80`; `supabase/migrations/0003_parties_and_products.sql:76-79`; `supabase/migrations/0001_core_schema.sql:112-118`, `130-150`.
*What is wrong:* The comment asserts "no app_user until an account is claimed, no node until a facility party exists, no placement until there is a vessel to place into." The middle clause is exactly right and `0003:76-79` says so: `node.owner_id` is not-null defaulting to `facility_party_id()`, so with no facility the default is null and the insert fails. The first and third are true of any schema with a foreign key. What the comment implies and the schema does not say is that *nothing* can be created before a facility exists: `location` and `vessel` have no such dependency, and an admin could perfectly well add both. `route()` (`walk.ts:77-78`) nonetheless blocks the entire home screen on `facilityParty()` returning null, which is a client rule stricter than the schema, presented in a comment as though it were the schema's.
*How it surfaces:* Not as a failure. It surfaces as a reader trusting the comment, concluding the gate is free, and removing it during a refactor, at which point the second and third screens stop working for reasons the comment said were structural.
*Resolves when:* the comment separates what the schema refuses from what the walk chooses to refuse, or the choice moves into the schema.
*Load-bearing:* no. Logged because `CLAUDE.md:117-119` makes a specific claim about what comments in this repository are for, and this is a comment that names an axiom it does not hold.
*Related, and logged here rather than as its own row:* `CLAUDE.md:86` names `bun run test` in the definition of done and `package.json` has no `test` script; `CLAUDE.md:71-75` says lint will enforce the module import restriction and `biome.json` enables only the recommended preset, which has no such rule. Every mechanical check proposed in section 6 currently has nowhere to run.

**R-4-18. `kernel.ts:288` claims the photo bucket is confidential; the storage policy lets every authenticated user read all of it.**
*Verdict:* DIVERGENT.
*Locator:* `packages/core/src/kernel.ts:288-297`; `supabase/migrations/0005_account_and_walk.sql:314-328`, in particular `325-326`.
*What is wrong:* The comment says the bucket is private and photos are served through a short-lived signed url "because a barrel photo shows a chalk mark with a client's lot on it." The bucket is indeed created non-public (`0005:316`). The select policy is `using (bucket_id = 'vessel-photos')` with no owner predicate, so every authenticated principal, including a custom crush client's login, can read every object in it. The signed url adds expiry, not scoping. `node_read` (`0003:282-283`) was written specifically so a client sees their own lots and no others; the photo of the barrel holding someone else's lot is outside that policy.
*How it surfaces:* A client login enumerates or guesses object paths, which are `${vesselId}/photo.${suffix}` (`kernel.ts:280`) and therefore derivable from any vessel id, and every vessel id is readable because `vessel_read` is still blanket from `0002:270`. The insert policy (`0005:336-337`) is equally open, so the same login can also overwrite them, since `upsert: true` is used on write (`kernel.ts:282`).
*Resolves when:* the storage policies carry an ownership predicate, or the comment stops claiming a property the policy does not provide.
*Load-bearing:* yes. It is a confidentiality claim about custom crush data, which is the thing migration 0003 exists to get right.
*Two smaller things in the same function, logged here:* the photo is uploaded before the vessel row is inserted (`walk.ts:517`, `630`), so a failed insert or an RLS refusal leaves an orphan object keyed to a vessel that never existed; and the suffix is taken from the uploaded filename, so uploading a `.png` then a `.jpg` for one vessel leaves two objects with `attributes.photo_path` naming only the second.

### BY DESIGN

**R-4-19. Lots always default to the facility party and no screen can create a client-owned lot.**
*Verdict:* BY DESIGN.
*Locator:* named at `packages/cellar/src/walk.ts:193-197` and `supabase/migrations/0003_parties_and_products.sql:72-79`.
*What is wrong:* Nothing, as stated. `walk.ts:194-197` tells the person on screen that "Lots default to this one. Client parties come later, when there is wine to attach them to," and `0003:72-79` explains why the column is not-null with that default. The deliberateness is documented in both places, which is what BY DESIGN requires.
*How it surfaces:* It does not, on its own terms. What does surface is R-4-3, which is the *vessel* owner control creating an expectation this default then quietly declines to honour. That interaction is named nowhere and is filed separately.
*Resolves when:* it does not need to. This row exists so that a later reader does not report the default as a defect.
*Load-bearing:* no.

### UNVERIFIED

**R-4-20. `lot_name ?? "unnamed lot"` turns an RLS refusal into a data state.**
*Verdict:* UNVERIFIED.
*Locator:* `packages/cellar/src/walk.ts:281-283`; `supabase/migrations/0002_derived_and_rls.sql:262-272`; `supabase/migrations/0003_parties_and_products.sql:280-283`; `supabase/migrations/0004_terms_and_effects.sql:270-271`.
*What is confirmed by reading:* `node.name` is `text not null`, so within this client a vessel with `is_empty` false always has a non-null `lot_name`, and the `?? "unnamed lot"` branch is unreachable through ordinary data. It is reachable only when the view returns a row whose placement is visible and whose node is not. `vessel_state` is `security_invoker` (`0004:271`), `vessel` and `placement` keep the blanket read policies from `0002:270`, and `node_read` was narrowed to owner scope by `0003:280-283`. So a client-party login should see the vessel, see the placement, and not see the node, which makes `p.node_id` non-null, `is_empty` false, and every `n.*` column null.
*What cannot be checked here:* whether that is what actually happens. It depends on PostgREST mapping a GoTrue JWT to the `authenticated` role and setting the `sub` claim `auth.uid()` reads, which is precisely the half S-7 (`sorry-ledger.md:54-65`) says is untested. `tests/schema_assertions.sql` sets the claim directly and therefore proves the policies while assuming the plumbing.
*How it would surface if confirmed:* a custom crush client opens the app and sees every barrel in the cellar, each labelled "unnamed lot" with its volume. The client-side coalescing is what makes that read as data rather than as a refusal.
*Resolves when:* the walk is run against a real Supabase instance with a client-party account and the vessel list is read; that is the same experiment S-7 already names.
*Load-bearing:* yes if confirmed. It is a cross-client disclosure in the one area migration 0003 was written to control.

**R-4-21. The six-character password minimum is asserted by the client and configured in GoTrue.**
*Verdict:* UNVERIFIED.
*Locator:* `packages/cellar/src/walk.ts:100-105`, the hint at `104`.
*What is wrong, or may be:* The field carries the hint "At least six characters" and no `minlength`, no validation call, and no check before `signUp` (`walk.ts:130`). The minimum lives in the Supabase project's auth settings, which are not in this tree; `supabase/config.toml` was read and does not set one. So the client states a rule it does not enforce and cannot see.
*What would check it:* creating an account with a five-character password against the real instance and reading what GoTrue returns. The answer is one round trip and it is not available from here.
*How it surfaces if the instance disagrees:* the person is told six and refused at eight, or told six and accepted at four. Either way the text on the screen is the only statement of the rule anyone has.
*Resolves when:* the minimum is read from the instance or the hint is removed.
*Load-bearing:* no.

**R-4-22. The camera decode path has never met a camera.**
*Verdict:* UNVERIFIED.
*Locator:* `packages/cellar/src/scan.ts:70-103`; `docs/status-ledger.md:50`.
*What is wrong, or may be:* `decodeFromVideoDevice(null, video, callback)` is called with a null device id, which delegates the choice to the browser. On a phone with front and rear cameras the browser's default is not reliably the rear one, and the `capture: "environment"` hint at `walk.ts:425` applies to the file input, not to this path. Whether zxing's multi-format reader decodes a cooper's linear barcode off a curved barrel head under barn light is likewise not a reading question. The callback fires per frame and `accept()` dedupes (`scan.ts:48`), so repeated decodes of one code are handled; a misdecode is not.
*What would check it:* a phone, a barrel, and the two sticker types named at `0003:111-114`.
*How it surfaces:* on the walk, which is the stated acceptance test (`walk.ts:43-45`) and has not been run.
*Resolves when:* someone scans a real barrel. The manual-entry path beside the camera (`scan.ts:9-11`) is the reason this is not a blocker.
*Load-bearing:* no. Manual entry is deliberately not a fallback.

### NOT A DEFECT

**R-4-23. Six places where the kernel's answer is transported rather than recomputed.**
*Verdict:* NOT A DEFECT.
*Locator and check, one line each:*
- `walk.ts:717` reads `facility_owned` from `vessel_state` (`0004:280`) rather than testing `owner_id` for null. Correct.
- `walk.ts:236`, `281`, `765` read `is_empty` (`0004:301`) rather than deriving occupancy from placements. Correct, and it is one of the four decisions `CLAUDE.md` moved down.
- `kernel.ts:202` takes `rows[0]` from `resolve_vessel_code`, which is single-valued because `vessel_code.code` is unique table-wide (`0003:118`). Cannot pick wrong.
- `scan.ts:48` dedupes codes within the form; the database enforces the same rule globally and more strictly via `bind_vessel_code`'s raise (`0003:217-218`). A strict subset, which is the right direction.
- `ui.ts:57-71` disables a button in flight; `unique (type_id, name)` (`0004:222`) refuses the duplicate anyway on both vessel screens. Belt and braces, with the braces in the database.
- `kernel.ts:272`'s `?? "unknown operation"` is unreachable: `event.operation_id` carries a composite foreign key to `term(id, kind)` (`0004:227-228`) and `term_read` is blanket (`0004:510-511`).
*What is wrong:* nothing. These are the shape the hard rule asks for and they are the reason the report is this length rather than twice it.
*Load-bearing:* not applicable.

---

## Closing

The sound part, in one line: every decision `vessel_state` already answers, the client
reads rather than recomputes, and the one genuinely atomic write path goes through one
kernel function that says in its own comment why it exists.

The rest is the answer to the prompt's question. Nine rules in the client have no
database counterpart and five are duplicated on both sides of the wire, of which one
has already drifted. The decay `CLAUDE.md:62-66` predicts is not a future risk in this
tree; it is present at the first commit that contains a client, in the two places the
rule said it would appear first, which are a three-line validation in a click handler
and a string transformation that was easier to write in TypeScript than to call over
the wire. The load-bearing ones are R-4-3, which makes the custom crush data model
silently wrong in the only screen that can express it, R-4-4, which puts the join key
between the fixed and free tiers in the client, and R-4-5, which is a copy of a kernel
decision that has already lost a conjunct.

Two of the nine EXPLOITABLE findings are dead code rather than wrong code: R-4-1 is a
module that does nothing while the screen says it does something. That is worth
separating from the others, because it costs a person's afternoon rather than the
record's integrity, and because it is the finding most likely to be caught on the first
real run.

Nothing here was run. The three UNVERIFIED rows are the ones that need a real instance,
a real token, or a camera, and one of them, R-4-20, would be the most serious finding in
the report if it confirms.
