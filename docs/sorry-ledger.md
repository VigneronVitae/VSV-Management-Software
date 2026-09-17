---
Type: record
Purpose: "Records every open deferred-verification obligation for the winery app, one entry per gap, as the honest unit of progress."
Depends on: [packages/cellar/docs/spec.md, docs/methodology-lineage.md]
Depended on by: [docs/status-ledger.md, docs/findings-ledger.md, CLAUDE.md, README.md, scripts/verify.sh, scripts/db-restore.sh, docs/record-requirements.md, docs/review/2026-09-14-export-red-team.md, docs/getting-somebody-else-on-it.md]
---

# Sorry Ledger

A named gap is a build artifact. A gap without a record is one you cannot revisit.

S-8 through S-12 are compliance gaps. Every one of them must be confirmed with
the winery's compliance advisor before any schema is built for it. A guessed
tax boundary produces confident wrong numbers on a federal return, which is a
worse outcome than producing none.

## Open

**S-1. The topping lineage threshold is one hundred percent, and nobody chose it.**
Strictly, topping makes every barrel a two-parent node, which produces thousands of
edges and is unusable. Below some percentage the volume and source are recorded
without writing lineage, and above it lineage is written. This entry used to say that
percentage was not chosen. It was, silently: `0004` seeds the `topping` operation with
`"effect": "treatment"`, a treatment writes no lineage by definition, and so no amount
of topping wine ever becomes a parent. The effective threshold is one hundred percent
and it is a consequence of the effect classification rather than a decision about wine.
That is the correction; the gap is unchanged and is now stated accurately. *Resolves
when:* a threshold is chosen deliberately, with the reason recorded, which probably
means topping stops being a single effect and carries a volume fraction above which it
is a transformation. *Load-bearing:* affects whether block composition on a topped
barrel is honest, and the current answer is that it is silently optimistic: a barrel
topped ten times from a different lot still reports as one hundred percent its original
block.

**S-2. Conditional intervals do not fit `offset_rule`.**
Template steps carry an interval from the previous step. "Cold crash until clear" and
"malo until complete" are conditions, not durations. *Resolves when:* either a
condition-based step type is added, or conditional steps are excluded from templates
and created by hand. *Load-bearing:* four of six protocols contain at least one.

**S-4. `event.subject_id` is not a foreign key.**
The cost of one events table across four subject types. A bad subject id fails
silently. *Resolves when:* `doctor` checks it and is run on a schedule. Until then,
every event count is unvalidated.

**S-5. Vessel `type` granularity unverified.**
`barrel` may need to distinguish puncheon from barrique from the acacia pieces.
*Resolves when:* the physical inventory walk in Stage 0 says whether it matters.

**S-6. Wine Meister export path unknown.**
Marketing says export; whether that is automatable or a manual download is unverified.
*Resolves when:* someone tries it. *Consequence if manual:* transcription stays
manual, which the spec already assumes, so this is a possible improvement rather than
a risk.

**S-7. RLS is exercised in Postgres and not through Supabase auth.**
`tests/schema_assertions.sql` now runs the policies with three accounts under the
`authenticated` role: a cellar user is refused locations, vessels and terms and
allowed events, a cellar user linked to no party sees the whole cellar, and a
client login sees its own lots and none of the others. That is the part Postgres
decides, and it holds.
What is still untested is the part Supabase decides: GoTrue issuing a JWT,
PostgREST mapping it to the `authenticated` role and setting the `sub` claim that
`auth.uid()` reads. The assertions set that claim directly, so they prove the
policies and assume the plumbing. *Resolves when:* the walk is run against a real
Supabase instance with two real accounts and the refusals happen there too.
*Until then:* treat the policies as correct and the wiring as unverified.

**S-8. Volume losses are not modeled.**
TTB requires volume to be accounted for, and racking, evaporation, and lees are
where it goes. A lot can currently lose fifty liters between two placements with
nothing in the record saying so. *Resolves when:* the compliance advisor confirms
what has to be recorded and at what granularity. *Load-bearing:* every volume
figure the app can produce is currently unreconciled.

**S-9. Unit conversion has no single home.**
TTB reports in wine gallons; the schema permits litres and gallons per node.
Conversion has to happen in exactly one place, and it currently happens nowhere.
*Resolves when:* one conversion point is chosen and every reporting path is made
to go through it. *Note:* the danger here is not the arithmetic, it is two call
sites rounding differently.

**S-10. Tax class is not represented.**
Class derives from ABV and product type, and a transition across a boundary is
reportable. The class itself should be a function rather than a column, per T0-2,
but the ABV measurement and the transition event both have to be stored and
neither is. *Resolves when:* the compliance advisor confirms which boundaries
apply to this facility, cider and vermouth included.

**S-11. Bond status is not represented.**
Wine sits in bond until removal, and taxpaid removal is the taxable event the
excise return is built from. Nothing in the schema knows which side of that line
a lot is on. *Resolves when:* the compliance advisor confirms which removal
events have to be recorded and what each one carries.

**S-12. The bottling seam is underspecified.**
Bottling converts bulk to case goods and is the point where the object changes
kind. The case goods module does not exist, but the bottling event has to record
enough for one to attach to it later: source lot, volume, case count, SKU, ABV at
bottling, and whether it went taxpaid or stayed in bond. *Resolves when:* those
fields are confirmed and the `bottle` event carries them. *Load-bearing:* bottling
this vintage against an incomplete event means the case goods module has nothing
to hang on, and the bottling already happened by the time anyone notices.

**S-13. Blending trials are not modeled.**
The Chardonnay protocol includes them. A trial is a proposed blend: components and
percentages, not executed, evaluated against tasting notes, and promoted to a real
blend when one is chosen. Orion treats a trial blend as a first-class object.
*Resolves when:* a trial is either modeled as a node that never acquires lineage, or
declared out of scope with a reason. *Load-bearing:* without it the reasoning behind
a blend lives in a notebook. Lineage records the blend that was made and loses every
alternative that was considered and rejected, which is the half that explains it.

**S-14. Activity costing has no input.**
Commercial platforms attach labour and equipment time to operations, which is what
makes cost per case computable at the end. Nothing in the schema records either.
*Resolves when:* volumes reconcile and case goods exist, which is to say S-8 through
S-12 first. Costing built on unreconciled volumes would produce a cost per case that
looks authoritative and is not.

**S-15. An operation whose effect the kernel understands, and whose meaning it does
not, still records.**
This is the intended behaviour and it is the spec's untyped floor applied to
vocabulary. A brewery defines `whirlpool` with effect `treatment`; the kernel
records the event, does the one thing the effect names, and knows nothing else
about it. The same floor covers `setpoint_change`, which the spec is careful to
call a decision rather than an observation and which carries effect
`measurement` here, because the only question effect answers is what happens to
volume and lineage, and for a setpoint the answer is nothing. Named so that it
reads as a choice rather than an oversight. *Resolves when:* some operation needs
behaviour beyond its effect, at which point either the kernel learns that
operation by name or the operation carries more configuration. *Not
load-bearing:* the failure mode is an operation that records and drives nothing,
which is visible rather than silent.

**S-16. `bottle` is filed as a transformation and is not really one.**
It closes a parent and writes lineage, which is why `transformation` is the
closest of the four effects. It also converts bulk to discrete units, which is a
change of kind the other three transformations do not make, and whether that is a
fifth effect is exactly the question S-12 defers. This entry exists so the filing
reads as a placeholder rather than a judgment. *Resolves when:* S-12 is answered
and the case goods seam is specified. *Watch for:* the first thing that branches
on effect and gets bottling wrong, which is the point this stops being harmless.

**S-17. No variety template is seeded, so inferred history generates nothing.**
`generate_inferred_history` returns zero for every variety, because `template` and
`template_step` are empty: the six protocols are transcribed and not encoded. A
lot created by the walk therefore has no history, which is the correct answer for
a variety with no protocol and is, from inside the app, indistinguishable from a
template that exists and failed to match. *Resolves when:* the six protocols are
encoded, at which point the backfill path in build order 1 starts returning
history and this function starts doing its job. *Not load-bearing:* zero is
truthful. The risk is that it gets read as a bug in the generator and someone
goes looking in the wrong place.

**S-18. Creating a vessel already jacketed records no event, though changing it
later does.**
Narrowed by 0007. `update_vessel` compares the thermal triple before and after
and writes a `setpoint_change` against the vessel when it differs, so the half
of this entry that said a jacket could never be turned on, and that turning it
on recorded nothing, is closed. What remains is the create path:
`create_vessel_with_wine` writes the columns and no event, so a tank entered
into the system already cooling has a current setpoint with no recorded author
or time, while the same tank switched to cooling a day later has both. The
inconsistency is the gap, not the missing event on its own. *Resolves when:*
either the create path writes an opening `setpoint_change` too, or a decision is
recorded that a vessel's initial state is part of creating it rather than a
decision about wine. *Not load-bearing:* every change after the first is
recorded, so a history is missing at most its opening entry, and
`effective_temp_c` is correct throughout.

**S-19. `fill_vessel` records wine arriving from nowhere.**
It creates a lot and places it, with no source and no lineage, which is exactly
right for an inventory walk: you are standing at a tank, there is wine in it,
and the app has never heard of that wine. It is exactly wrong for a rack, where
the wine is already a lot in another vessel and the honest record closes one
placement and opens another. Nothing currently stops somebody using this screen
to record a rack, and the result is two lots where there was one, with the
source still showing as full. *Resolves when:* the rack path exists and this
screen says which of the two it is, or refuses the case it is not for.
*Load-bearing:* the failure is silent and it duplicates wine, which is the kind
of wrong that reads as correct until a volume reconciliation disagrees.
*See also:* S-34 and spec section 8.6. The same function is also how wine that
arrived from another facility gets recorded, and there the missing source is not
a rack but a whole history held somewhere else. Full barrels came from Keeler
when crushing started here and entered as lots with no past, which is this entry
read from the arrival side rather than the racking one.

**S-20. A field descriptor carries a unit and nothing converts it.**
`unit` on a vessel type's field descriptor is rendered beside the input and
stored nowhere. Two vessels of different types can therefore record oxygen
ingress in different units and compare as if they were the same number, and
nothing notices. The descriptor format reserves `min`, `max` and `required`,
which are enforced, alongside `unit`, which is not, so the shape of the thing
suggests a guarantee it does not make. *Resolves when:* either a unit becomes
part of the stored value rather than a label on the input, or units are
restricted to a fixed list per field kind so two descriptors cannot disagree.
*Load-bearing:* only once a second vessel type records the same quantity, at
which point any total or average across types is silently wrong. Today one type
records each thing, so the failure is latent rather than live.

**S-21. A lot's volume is stored and also derivable, and racking changes both.**
`node.quantity` holds a lot's volume while `placement.volume_l` holds how much of
it is in each vessel, so the same litres are recorded twice. T0-2 says exactly
what happens next: "two sources of truth diverge the first time a volume is
corrected." Racking makes that routine rather than rare, because every transfer
writes both numbers. Deferred deliberately rather than fixed alongside racking,
because making a lot's volume derive from its placements is a change to how
every lot works and would turn one feature into a refactor. *Resolves when:*
either quantity becomes derived for anything past bin stage, where placements
exist and weight no longer applies, or a check keeps the two reconciled and
names which one wins. *Load-bearing:* the divergence is silent, and the number
people read is whichever the screen happened to ask for.

**S-22. A blend across owners keeps one owner_id and the rest is a note.**
`node.owner_id` is a single uuid and RLS scopes a custom crush client's view by
it, so a lot made from two owners' wine cannot record both without either
hiding the wine from a client who part owns it or rewriting how the policy
reads ownership. `rack` gives the new lot to the largest contributor and writes
`mixed_ownership` into its attributes, which is a caption rather than a fact
anything computes from. The winemaker's point stands, that the risk is the
barrels being physically combined and not the app recording it, so this refuses
nothing. *Resolves when:* ownership is derived from lineage the way composition
already is, and the client scoping policy reads the derived answer.
*Load-bearing:* a client querying their own inventory will not see wine they
part own, and the number they do see will be someone else's total.

**S-23. Lees are a quantity on the event and not yet material.**
`rack` records how much lees came across in its data, and the four operations
already include `distribute_lees`, but nothing turns lees into a node. So
racking clean off a barrel leaves solids that the app treats as loss, and lees
kept for distillation or for bâtonnage elsewhere have no identity and no
lineage from the wine they came out of. *Resolves when:* lees become a node
with lineage and a product type, at which point racking clean has two outputs
rather than one and the loss figure stops absorbing them. *Load-bearing:* only
for volume reconciliation and for anything downstream that needs to know where
a lees addition came from. The wine's own record is correct either way.

**S-24. An event recorded before a fork cannot be moved onto the shard.**
`record_event` forks as it records, so an addition to one barrel makes that
barrel its own lot in the same breath. But if somebody records the addition
against the whole lot first and only afterwards realises it went into one
barrel, the event is already written and history is append-only, so it cannot
be re-attached. The correction is a new event saying the first one covered less
than it claimed, which is honest and is also harder to read than the thing
having been right. *Resolves when:* either a correction operation exists whose
meaning is "that event applied only to these vessels", and the history walk
understands it, or the screens make recording against a subset the easy path so
the mistake is rare. *Load-bearing:* the wrong version is silently wrong in
exactly the way forking exists to prevent, and only for events entered before
anyone noticed the divergence.

**S-27. A client with no login cannot set privacy on their own wine.**
`set_lot_hidden` allows the owner and nobody else, and an admin is deliberately
excluded so that an admin cannot quietly unhide a client's lot. The cost is that
a client party with no `app_user_id` attached has no one who can act as it, so
their wine keeps whatever default it inherited and cannot be changed until they
log in. That is the correct failure, since the alternative is an admin deciding
on their behalf, which is the thing the split exists to prevent. It is still a
gap because the winery can create a client party and lots for it long before
that client ever signs in. *Resolves when:* either a client can be sent a
privacy choice to make before they have an account, or an admin may set it once
with the client's instruction recorded against the change. *Not load-bearing:*
the default is the safe direction, so the failure is wine that is more hidden
than the owner might have chosen rather than less.

**S-28. A procedure is a copy of an SOP and nothing reconciles the two.**
`procedure.sop_text` holds what the steps are supposed to mean, typed in
alongside them. The winery's actual SOPs are documents in a folder. So there
are two statements of the same procedure and only one of them is what the
cellar hand reads on the phone. *Resolves when:* either the documents become
the source and a procedure is generated from one, or the procedure becomes the
source and the document is printed from it. *Load-bearing:* the moment somebody
updates the written SOP and not the app, the phone confidently instructs the
old way.

**S-29. Seeded vocabulary gets new ids on every reset, so data does not survive
one.**
Varieties, operations and vessel types are inserted by migrations with
`gen_random_uuid()`, so `chardonnay` is a different uuid after every
`supabase db reset`. A lot backed up before a reset points at a variety that no
longer exists, and the restore fails on the foreign key. It also means the ids
in the local database will not match the ids in the hosted one, so anything
exported from one and loaded into the other breaks the same way. Worked around
for now by not resetting: `bun run db:up` applies pending migrations and leaves
data alone. *Resolves when:* seeded rows carry deterministic ids, derived from
kind and value rather than generated, at which point a backup restores cleanly
and local and hosted agree. *Load-bearing:* it is the difference between a
backup that works and one that only looks like it works.

**S-30. Several writes that look appendable are decided by the kernel, so T1-2's
line is in the wrong place.**
T1-2 said local-first for append-only writes and server-authoritative for mutable
state. The wire session built writes that fit neither description: `rack` reads the
shape of a transfer and decides whether a lot moved or a new one was made, and
`record_event` decides whether recording against some of a lot's vessels forks it.
Both are appends by their effect on the record and neither can be performed without
the kernel, because performing them offline would mean a client reproducing the
decision, which the hard rule forbids. The axiom has been restated; what is not
answered is what the offline client actually does when somebody racks a barrel in a
shed with no signal. *Resolves when:* either those operations queue as intentions that
the kernel resolves on reconnect, and the screen is honest that the outcome is not yet
known, or they are declared online-only and the app says so before the person starts.
*Load-bearing:* it is the difference between an offline mode that works and one that
guesses, and the guess would be about lot identity.

**S-31. The photograph path needs a vision dependency nobody has approved.**
Section 8.5 specifies reading a sheet of handwritten numbers into proposed events at
`inferred`, for a person to confirm. The shape fits the existing verify boundary
exactly and none of it can be built, because it needs an OCR or vision step, which is
a dependency and probably a paid external service, and the standing rule is to consult
before adding either. There is a second question underneath the first: a page of
numbers sent to a third party is a page of a custom crush client's numbers, and the
schema now enforces a privacy those clients chose. *Resolves when:* the dependency
question is put and answered, including whether the step can run locally, and the
client confidentiality question is answered separately rather than assumed.
*Not load-bearing:* manual transcription works and is what happens today. The risk is
building it, finding confirmation is slower than typing, and having paid for a service
to be slower.

**S-32. An imported event has no way to say who observed it.**
Section 8.6 wants a client's record to arrive from another facility intact. `event`
requires an author, `by_user` references `app_user`, and `has_an_author` refuses a row
with neither a user nor a sensor, so there is no way to record that a measurement was
taken by somebody who has no account here. A fourth provenance value does not fix it:
the missing fact is not how confident the reading is, it is who is asserting it, and
provenance answers the first question only. This blocks import and does not block
export. *Resolves when:* an event can name an external observer, most likely a party
reference alongside `by_user` with the author check widened, and provenance gains a
value meaning observed elsewhere and not verified here, or it is decided that an
imported history lands as a single attested document rather than as events.
*Load-bearing:* it is the difference between receiving a client's record and receiving
a picture of it, and the whole argument for the protocol is that it is not a picture.

**S-33. A vessel cannot leave. Nothing models selling, scrapping or lending one.**
`vessel` carries `active` and nothing else about its fate, so a barrel sold to another
facility can only be switched off, which says it stopped being used here and not that
somebody else owns it now. There is no buyer, no date, no price, and no distinction
between sold, scrapped, broken up for a table, and lent out for a vintage. It also
means the takeout in spec section 8.6 has a case it cannot express: the rule there is
that whatever changed hands travels with its identity, and for a sold barrel nothing
records that the hands changed. *Resolves when:* a vessel's departure is an event with
a kind and a counterparty, at which point `active` becomes derived from it rather than
set by hand, and the export can say which barrels went with the sale. *Load-bearing:*
mildly, and in an unexpected place. Fill count and maintenance history are what a used
barrel is priced on, so a facility that cannot hand those over sells a barrel with no
provenance and takes less for it than it is worth.

**S-34. Which bonded premises holds a lot is not represented, and it is not the same
question as who owns it.**
`party` answers who owns a lot or a vessel. Nothing answers which bond it sits in,
because the schema assumes one facility and the spec preamble defers a facility-level
`org_id` until a second exists. Custom crush is the arrangement where those come apart,
and this winery has already crossed the line: full barrels came from Keeler when
crushing started here, with the same owner before and after. No sale, and still a
transfer in bond, which is a formal transaction between bonded premises that moves tax
liability. The app cannot say a lot was at another premises until a date, so it arrives
with no past and its lineage stops at the winery door.

The operational half is what this entry is about and is buildable: where a lot was,
whose premises, and when it moved. The reportable half is S-11's and belongs to the
compliance advisor, per the standing rule at the top of this file. They are not the
same work and answering the second without the first is impossible, because a report
cannot be built on a record that begins at the door. *Resolves when:* premises is a
fact about a lot over time, most likely the same shape as `placement` but naming a
party rather than a vessel, so arriving and departing are one operation seen from two
ends. That is also what the deferred `org_id` is for, so the two should be designed
together. *Load-bearing:* the crossing has already happened once and is unrecorded.

**S-35. A sealed history needs a key holder, and both candidates are wrong.**
Spec section 8.6 specifies selling a barrel with its history encrypted under a key
belonging to whoever owns that history, so the record travels now and opens later if
the owner agrees. The mechanism is sound and the custody is not decided. If the
application holds a client's key then the application can open the record, an admin
with database access can open it, and the seal is decoration on top of the redaction
that was already there. If the client holds the key then losing it destroys their own
history permanently, which is a worse outcome than the disclosure being prevented, and
a winery is not a place where people keep track of key material. Splitting it so that
neither party alone can open it answers both and introduces a third question, which is
who runs the recovery when a client dissolves and somebody still needs the record for a
federal return. *Resolves when:* somebody actually needs a sealed history, at which
point the condition under which it opens is known and the holder follows from it, rather
than being chosen in advance for a case nobody has met. *Not load-bearing:* the cheap
half of the same idea is in the spec and covers what a barrel buyer actually asks, which
is whether the barrel is sound rather than whose wine made it unsound. A buyer reading a
complete list of event kinds against opaque tokens derives that without a key.

**S-36. The column allow-list guards the direct table surface and trusts every
security definer function to guard itself.**
`0021` lets cellar staff update `node`, `placement` and the thermal triple on
`vessel`, and a trigger refuses any other column in words. The trigger exempts a
caller whose `current_user` is not `authenticated` or `anon`, because a security
definer kernel function runs as its owner and has already decided who may call
it, and because `set_lot_hidden` legitimately writes `node.hidden` on behalf of a
client who is not staff. The exemption is correct for the two definer functions
that exist and is unchecked for every one written after it: a new definer function
that updates a protected column inherits a bypass nobody granted it deliberately.
*Resolves when:* either `verify.sh` lists every security definer function and what
it writes, so adding one is a visible decision, or the allow-list moves into the
functions and the trigger is dropped. *Load-bearing:* it is the boundary that keeps
`owner_id` and `hidden` out of a cellar hand's reach, and those are the contract
and confidentiality fields.

**S-37. A refusal on these tables is a message for staff and silence for everyone
else.**
The trigger raises, so a cellar user who touches a protected column is told which
column and why. A client login fails the policy's `using` clause instead, the row
never reaches the trigger, and the update is a zero-row no-op reported as success.
That is the general defect the review corpus converges on, filed there as A13, and
`0021` improves it for one principal on three tables rather than answering it.
*Resolves when:* the class is answered, which means deciding how PostgREST should
report an RLS denial to a phone and making every write path agree. *Load-bearing:*
a client correcting their own record and being told it worked is the same failure
as a cellar user racking into a silent no-op, one principal further out.


**S-38. No test covers a line of TypeScript.**
`bun run test` is in the definition of done in CLAUDE.md and was not a script, so for
eight sessions it silently ran `/usr/bin/test` with no arguments and exited zero. Seven
of the thirteen review reports found it. It is now a script that says what is missing
and exits non-zero, which is the same shape as `doctor` and S-4: a command that exists
and cannot pass is honest, and a command that does not exist and appears to pass is not.
What is actually missing is any coverage of the client. The kernel is covered by 117
assertions; `walk.ts`, `kernel.ts`, `pickers.ts` and `scan.ts` are covered by nothing,
and the review corpus found nineteen client defects that no test would have caught
because there are none. *Resolves when:* either a test runner is chosen and the first
client test exists, which needs a dependency and therefore a conversation, or the
definition of done drops the line and says the client is checked by hand. *Load-bearing:*
the client is where every defect a person actually meets lives, and it is the half with
no failing test waiting for it.


**S-39. No sensor can write an event, because nothing authenticates a sensor.**
`event_insert` used to accept any row whose `by_sensor` was not null, which meant a
string in that column was sufficient to unbind the author check: a person could write
an event naming somebody else in `by_user`, or name themselves as a thermometer. That
was A3 in the findings ledger and 0022 closes it by requiring an event written through
the `authenticated` role to name the caller and nothing else. The cost is that the
sensor half of `has_an_author` is now unreachable. A real sensor path needs an identity
for the sensor, which is a row rather than a free string, and a role that is not a
person's. *Resolves when:* a sensor exists, at which point it gets a registry row and
writes through `service_role` or through a function that checks the registry, and the
policy gains a branch that names that mechanism rather than trusting a column.
*Not load-bearing:* nothing in the cellar is a sensor yet, and the room thermometer the
spec mentions is read by a person off a display.

**S-40. A vessel photo's visibility follows the vessel and not the lot that was in it.**
0022 closes the vessel-photos bucket to facility users, which fixes the case where every
login could read every photo. What it cannot do is let a client see a photo of their own
wine, because a photo is stored at `<vessel_id>/photo.<ext>` and carries no record of
what was in the vessel when it was taken. Deriving the owner from the current placement
would show a barrel's old photograph to whoever holds it now and hide it from the person
whose wine it actually shows, which is worse than refusing both. *Resolves when:* a
photo is an event on a vessel with a timestamp, at which point what was in the vessel at
that moment is a query rather than a guess, and the same change is what lets a photo be
evidence for a reading under spec 8.5. *Load-bearing:* it is the reason a client sees no
photographs at all, which is a feature nobody has yet asked for and a limitation worth
knowing before somebody does.


**S-41. The resolver registry executes an expression it stores as text.**
`subject_resolver.name_expression` holds a SQL fragment, `name` for a vessel or
`vineyard || ' ' || name` for a block, and `resolve_subject_name` interpolates it into a
dynamic query. The relation name is quoted as an identifier; an expression cannot be,
because it is an expression. Writing the registry is admin only and the function is
`security invoker`, so the fragment runs with the caller's own rights and this is not a
privilege escalation: an admin who can write that row can already run the same SQL
directly. It is still an execution surface that did not exist before, and it is the kind
that gets wider when somebody later makes the function `security definer` for a good
reason. *Resolves when:* either the expression is narrowed to a list of column names that
can be quoted, which costs the `vineyard || ' ' || name` case and every other composite
label, or the registry becomes a set of typed columns rather than a fragment. *Not
load-bearing:* nothing escalates today, and the note exists so the next person changing
that function's rights knows what they are widening.

**S-42. Resolving a subject is one query per row.**
`resolve_subject_name` runs a dynamic statement per call, so a board of fifty tasks is
fifty extra queries. That is the trade `AR-I3` takes deliberately at ten users, and it is
the reason the registry is a table and a parse step rather than a service. It stops being
free at a size this winery is not. *Resolves when:* the board is slow enough to measure,
at which point the answer is probably a lateral join against a per-type view rather than a
function call, which is the same shape `task_board` uses after phase 4. *Not
load-bearing:* fifty tasks is the whole cellar.


**S-43. Rebinding a sticker leaves no trace.**
`0025` lets an admin move a code from one vessel to another, because a sticker does come
off one barrel and go onto the next and somebody has to be able to say so. Nothing
records that it happened. Every scan of that code after the rebind resolves to the new
barrel and every scan before it resolved to the old one, and the record does not contain
the moment the meaning changed. That is ledger A17's class, where one button press put a
lot under the wrong owner and the screen reported success. The refusal path is loud and
names the vessel; the permitted path is silent. *Resolves when:* there is an operation
term for it and the rebind writes an event against both vessels, which is a vocabulary row
and three lines, and was left out here only because W-3's scope is assertions rather than
the event model. *Load-bearing:* a sticker that moves without a record is the one way a
barrel's history can be reattributed with nothing to read afterwards.


**S-44. A vessel a viewer may not see into reports as empty rather than as occupied.**
AR-E10 rules that redaction is row-level, so 0028 scopes `placement_read` and a custom
crush client no longer receives placement rows for wine that is not theirs. `vessel_state`
derives `is_empty` from `p.node_id is null`, and a placement filtered away by row level
security is indistinguishable from a placement that does not exist, so a barrel full of
somebody else's Pinot now tells that client it is empty. **This is a falsehood traded for a
leak and it is deliberately the narrower error**: the previous behaviour disclosed the lot
id and the volume, and this one asserts an availability that is wrong. Two clients asked to
fill the same barrel is a worse outcome than either for whoever is holding the hose.
*Resolves when:* AR-E11 is built, which answers availability as a boolean over the
exclusivity mechanism rather than by the absence of a row, and which is unbuilt because the
magnitude case is unresolved: whether availability carries remaining capacity, which is a
number about somebody else's wine and therefore the same question one level down.
*Load-bearing:* yes, and it is the only thing 0028 made worse. Anything that shows a client
a vessel list is showing them something false until AR-E11 exists.


**S-45. Column privileges cannot express who may write which column, so nothing checks the answer twice.**
`cellar_writable_columns` is a `before update` trigger carrying its allow-list in its own
trigger arguments, and `0030` reads that list back so the client can ask which fields to
render as inputs. That is one mechanism and it cannot drift. The obvious alternative,
`grant update (has_glycol, setpoint_c, mode)`, **cannot express this rule at all**: grants are
per database role and admin and cellar are both `authenticated` here, with the distinction
living in a row in `app_user`. Today `information_schema.column_privileges` reports every
column of `vessel` as updatable by `authenticated` and by `anon`, which is true of the grants
and false of the system, so anything that trusted that view would be wrong. *Resolves when:*
either two database roles exist with a mapping from `app_user.role` onto them, at which point
grants become expressive and there are two mechanisms to keep in step rather than one, or
somebody decides the trigger is the only enforcement and this entry records that the grant
route was considered and refused. **The second is the current position** and this is filed so
that the next person to notice the grants are wide open finds the reasoning rather than
repeating it. *Load-bearing:* no. It is load-bearing only for whoever reads
`column_privileges` and believes it.


**S-46. A template may declare it applies to a vocabulary nothing generates from, and nothing says so.**
`0031` makes the scheduling block generic per AR-E6: a template names `applies_to_kind` and
`applies_to_id` against any registered vocabulary rather than a variety specifically, which is
what takes the last winemaking edge out of core. The cost is that the pairing of a kind to a
generator is now a convention rather than a constraint. `generate_inferred_history` reads
templates whose kind is `variety`; a template written against `vessel_type`, intending a
maintenance schedule, is accepted by the database, is correct, and does nothing, because the
generator that would read it has not been written. **That is the same shape as a refusal that
returns success**, which is this project's standing failure mode, arriving in a place where the
silence is about a feature rather than about a permission. *Resolves when:* either a registry
pairs a vocabulary kind with the generator that consumes it, which is the AR-B contract register
one level down and should not be invented ahead of it, or a check reports templates whose kind
no generator reads, which is a `doctor` check and therefore S-4. *Load-bearing:* not yet. It
becomes load-bearing the first time somebody writes a maintenance template and waits for tasks.


**S-47. The app is installable and still cannot start without the network.**
`0033`'s client half gives the walk a manifest, icons and a place per screen, which is what
makes a phone treat it as an application and what makes a restart land where you were. It
does not add a service worker, so the boot itself is still a network boot: `index.ts` reads
its config, asks the kernel for a session, and shows an error if either is unreachable. In a
barrel room with no signal the app therefore opens to a failure rather than to the screen you
left, which is precisely the case the offline story exists for. **The route is remembered and
cannot be used**, which is a worse shape than not remembering it, because the app now knows
what you wanted and still says no. *Resolves when:* a service worker caches the shell and the
kernel client falls back to a queued write, which is the offline path in spec.md §7 and is a
session of its own rather than a line here. *Load-bearing:* yes, and known to be: B15 is
scored MAJOR in the findings ledger and this closes the installability half of it only.

**S-48. Only the vessel forms keep a draft, and the others look the same to a person.**
Android discards a backgrounded tab under memory pressure, so leaving the app to take a photo
and coming back is a restart. `0033` keeps a draft for everything built on `vesselFields`,
which covers registering a vessel, registering a vessel with wine, editing one and filling
one, because that is the case the winemaker hit and the case with the most typing in it. The
rack screen, the locations screen, the clients screen and the vessel type editor keep nothing,
and a person cannot tell from looking which sort of screen they are on. **A feature that works
on four screens out of eight is trusted on all eight**, which makes the loss worse than it was
when nothing was kept, because nothing is at least consistent. *Resolves when:* either the
draft store is attached to the remaining forms, which is mechanical once each grows a
serialisable read, or the seam moves into `ui.ts` so that a form gets a draft by being a form.
*Load-bearing:* during harvest, yes. A rack recorded halfway and lost is a transfer that has
already physically happened with no record of it.


**S-49. Fruit weight is pounds because a constant says so, not because anybody chose it per winery.**
`0033` records every pick in `lbs` and the winemaker asked for a setting. `node.unit` is
already per row, so the schema is not what is missing: what is missing is a facility level
default and a screen to set it, and building a settings system the night before the first pick
would be the generalisation `CLAUDE.md` forbids on a worked case. The number is stored with its
unit beside it, so nothing here is ambiguous and nothing has to be reinterpreted later.
*Resolves when:* there is a second winery, or a scale that reads kilograms, whichever comes
first, at which point the default belongs with the other facility settings rather than in a
function body. *Load-bearing:* no, while there is one winery and one scale.

**S-50. Forking a pick would produce a weight of zero, so it is refused instead.**
`fork_lot` computes the child's quantity as the sum of `placement.volume_l` across the vessels
being split off. A pick deliberately stores nothing there: one measured weight lives on the
node and the bins carry no per bin number, because a scale reading covering three bins does not
contain three weights. So forking a bin stage lot would hand the child a quantity of zero and
close nothing, which is a wrong number rather than a missing one. `0033` makes that case raise.
**The refusal is the honest half of a feature that is not built:** the winemaker asked for one
measured record now with the option to split later, and later is not tonight. *Resolves when:*
`fork_lot` learns that a bin stage parent divides its quantity across the bins being separated
and writes the pieces as `inferred`, which is the moment the estimate is created and the only
moment it is honest to create it. *Load-bearing:* the first time a pick has to be separated bin
by bin, which is the first time one bin of a pick goes somewhere the others do not.

**S-51. Only an administrator can create a block, so intake can stall on a vineyard nobody entered.**
A pick carries a `block_id` and `block` has admin write. If fruit arrives from a block that is
not in the database and the person at the scale is a cellar hand, they cannot enter the pick,
and T1-4 says the bin that was never weighed cannot be recovered. Loosening the policy is a
decision about who may define the facility's own vocabulary and was not made tonight, so the
screen offers the inline create and a cellar hand gets a legible refusal rather than a dead
form. *Resolves when:* the winemaker says whether a cellar hand may add a block, which is one
sentence and changes one policy. *Load-bearing:* yes, during harvest, and the workaround is
that he is reachable by phone.


**S-53. A grower is a string in two places and nothing joins them.**
`block.vineyard` says where fruit came from and `vessel.attributes.on_loan_from` says whose bin
it arrived in, and both are free text because a vineyard you buy fruit from is not a party at
this winery: making one a `party` to borrow its bins would put a row in the table `node_read`
scopes lot visibility by, in order to record a fact about a plastic box. **That decision is
right and its cost is that "Pearlstaad" typed twice is two unrelated strings.** Nothing reports
how many of their bins are out, nothing catches "Pearlstaad" against "Pearlstadt", and the two
fields cannot be joined to ask which grower's fruit is still in which grower's bins.
*Resolves when:* either a `grower` party kind exists with no login and no lot visibility, which
is the honest version and is a schema decision rather than a harvest one, or a vineyard becomes
a registered vocabulary the way `0027` made every other list a row, at which point both fields
point at the same term. *Load-bearing:* not for one delivery. It becomes load-bearing the first
time somebody has to answer "whose bins do we still have", which is the question the returning
of them turns on.


**S-54. An export is not a restore, and a file called an export looks like one.**
`0037` gives anybody a copy of everything they may read, as one document, which is what makes
the harvest survive the one desktop the database is on. What it does not give them is a way to
put it back. Restoring means re-inserting through the API in dependency order against a database
whose migrations have already seeded vocabulary with different ids, which is S-29 one level up:
there, a reset reissues variety ids and orphans the lots pointing at them, and here the same
mismatch arrives between two different installations. **The file is a faithful record and not a
restore point, and nothing in its name says so**, which is the gap: somebody holding it will
reasonably believe they are covered. *Resolves when:* either an importer exists that matches rows
by natural key rather than by id, which is the real fix and is a session of its own, or the file
carries a header saying in words what it can and cannot do, which is an hour and is most of the
protection. *Load-bearing:* yes, and immediately. The export exists because the desktop is a
single point of failure, and the moment it is needed is the moment nobody can ask a question
about it.


**S-55. Acres and elevation are numbers with no unit recorded beside them.**
`0039` stores a block's size as `acres` and leaves elevation, spacing and the rest as free text.
Acres because this is Oregon and that is what the winemaker would type; free text for the others
because guessing feet against metres nine times over would have been nine guesses. **The
consequence is that `acres` is a column whose name is its unit**, which works exactly as long as
nobody hands this to a winery that thinks in hectares, and then it is a silent factor of 2.47
rather than an error. Same shape as S-49, one table over. *Resolves when:* the facility has a
unit setting and these become a magnitude and a unit, which is one decision covering weight,
area and temperature together rather than three. *Load-bearing:* no, for one winery in Oregon.
It becomes load-bearing on the first import from a vineyard module that reports hectares.


**S-56. A bin's fill percentage is per bin in the schema and per action in the app.**
`placement.fill_pct` is a column on the placement, so the database already says how full each
individual bin was. What the app does not do is ask: `add_bin_to_pick` takes one percentage and
`add_bins_to_pick` hands that same number to every bin in the call, so three bins registered
together are recorded as equally full whether they are or not. **And nothing can correct it
afterwards**, which is the worse half: a bin entered at 100 that was half full stays at 100 for
the life of the record. Named by the winemaker during the first pick, who added that the day's
bins were all full so it did not bite. *Resolves when:* the bulk call takes a percentage per bin
rather than one for the set, and the pick screen lists the bins already on it with their own
editable figure, which is also where a bin added in a hurry gets corrected. *Load-bearing:* not
for a pick where every bin is full, which is the normal case. It becomes load-bearing the first
time a part-full bin is weighed together with full ones, because the fill percentages are what
a later session would divide a shared scale reading by, and three numbers that all say 100
divide it evenly and wrongly. That is the estimate S-50 is waiting on.


**S-57. The winery's timezone is a constant in a function.**
`day_log` decides which day an event belongs to by converting its timestamp into
`America/Los_Angeles`, because the database thinks in UTC and an afternoon pressing in Oregon
would otherwise land on tomorrow. A daily log on the wrong day is worse than no daily log, so
the conversion is right and the constant is the problem: it is correct for this winery and
silently wrong for any other, in a way that shows up as events drifting a day rather than as an
error. Same family as S-49 and S-55, and the same fix: a facility knows where it is.
*Resolves when:* the facility carries a timezone alongside its weight and area units, which is
one decision covering all three rather than three. *Load-bearing:* no, for one winery in Oregon.

**S-58. Nothing checks that the photograph is of this weighing.**
`0042` lets a weighing carry a path to a photograph of the scale, which turns a typed number
into evidence of a number. What it does not do is verify any relationship between the two: the
path is whatever the client uploaded and said, so a photograph of yesterday's display, of a
different scale, or of nothing at all is accepted and looks exactly like a good one. **The value
of the feature is entirely in the discipline of the person holding the phone**, which is worth
saying out loud because a photograph carries an air of proof that this one has not earned.
*Resolves when:* either the upload is bound to the event at the point the kernel writes it,
rather than being a string handed in, or a reading is transcribed from the image and compared
with what was typed, which is the version that would actually catch a mistyped weight and is a
long way off. *Load-bearing:* no. It is weaker evidence than it appears, and that is all.


**S-59. Retiring a form does not forgive its backlog, and nothing can.**
`0043` gives a physical document a span: obligations exist for measurements that happened while
the form was being kept. Retiring it stops new ones, which is right. What it deliberately does
not do is clear the ones already outstanding, because a weighing that should have gone on
September's weight sheet still should have, and a system that made that disappear when somebody
stopped using the form would be a system for hiding exactly the thing this list exists to show.
**The cost is that there is no way to say "we abandoned this form mid-season and those twenty
entries are not going to happen"**, so the list can carry work nobody intends to do, and a list
that is permanently non-empty stops being read. That is the failure mode of every queue.
*Resolves when:* somebody can close an outstanding obligation with a reason rather than by
ticking it as done, which is a different verb and wants its own row, because "written on the
form" and "we decided not to" must not look the same. *Load-bearing:* not yet. It becomes
load-bearing the first time a form is abandoned rather than kept to the end of a vintage.


**S-60. A plan is not connected to the work that fulfils it.**
`0044` plans processing as tasks: bins, a day, an operation, changeable because a plan is an
intention rather than an observation. What nothing does is notice when the intention happens.
Pressing the bins a plan names leaves the tasks open, so the plan has to be closed by hand and
a board full of things that were done a week ago is a board nobody reads. **Deriving it is
tempting and wrong in the obvious form**: "the bins are empty so the plan is done" would also
fire when somebody emptied them for a different reason, and would report work as complete that
nobody did. *Resolves when:* the press and destem paths accept the plan they are fulfilling, so
the task closes because the work names it rather than because the world happens to look right
afterwards. That is a parameter on two functions and a picker on two screens. *Load-bearing:*
the first week anybody plans more than they do in a day.


**S-61. The client's list of vocabularies is hand-maintained against a registry and nothing checks it.**
`0027` made every vocabulary a row in `term_kind` so that adding one stopped being a migration
against generated columns. The client still carries the same list as a TypeScript union, written
by hand, and the two drifted the day `0032` deleted `cooper` and created `vessel_maker`: the
union kept a vocabulary that no longer existed and lacked one that did, for a day, unnoticed.
**The two directions fail differently and only one of them is caught.** A missing kind is a
compile error the first time somebody names it, which is how this was found. A kind that no
longer exists compiles forever and fails at runtime as a query returning nothing, which is the
A13 shape: an empty picker and a vocabulary nobody deleted look identical. *Resolves when:*
either the union is generated from `term_kind`, or a gate compares the two and fails, which is
one query and one grep and belongs in `green` beside the checks that already compare the tree
against the database. *Load-bearing:* the next time a vocabulary is renamed or retired.


**S-62. A cut is named and its position in the run is not.**
`0045` records which cut a lot is, from a vocabulary: free run, press, hard press. What it does
not record is the order they came off, or the pressure each was taken at, and the vocabulary's
sort order is a display preference rather than a fact about a particular press. Two cuts called
`press` off one run, which is ordinary, are indistinguishable from each other. **So the record can
say what a lot is and not when in the run it was taken**, and for a press where somebody pulled
four fractions that is most of what they would want to know later. *Resolves when:* a cut carries
its sequence within its own press, which is a small column and a decision about whether pressure
or time or simply order is the thing worth recording, and that is a question for the person
running the press. *Load-bearing:* the first time more than two fractions come off one run.


**S-63. A supply has a unit and nothing converts between units.**
`0046` records what one of a supply is, as free text: g, kg, L, mL, each. What it does not do is
convert, so a supply bought in kilograms and used in grams is two numbers that cannot be added,
and `supply_on_hand` will cheerfully sum them into nonsense if somebody records a delivery in one
and a scoop in the other. **The unit is recorded rather than enforced**, which means the figure is
only as good as everybody using the same word every time. *Resolves when:* a supply names a unit
from a registered vocabulary with a conversion factor to a base, which is the same decision as
S-49 and S-55 and should be made once for weight, volume, area and count together rather than
four times. *Load-bearing:* the first delivery recorded in a different unit from the uses, which
will not announce itself.

**S-64. Nothing consumes a supply automatically.**
On hand falls when somebody records that it fell. There is no path from an addition or a press
or a procedure run to the supply it used, so every scoop has to be entered twice: once as what
was done to the wine and once as what left the shelf. **Nobody does a thing twice during
harvest**, so the honest prediction is that uses will go unrecorded and the counts will carry the
correction. That is survivable because `0046` was built for it: a count resets the derivation and
the gap it reveals is kept rather than smoothed. But the gap will be large, and a large gap is a
number nobody trusts. *Resolves when:* the additions work lands and an addition names the supply
it drew from, which writes the movement as a consequence rather than as a second chore. That is
the winemaker's item 4 and this is the argument for it. *Load-bearing:* yes, immediately, in the
sense that the inventory's accuracy is bounded by discipline rather than by the schema.

**S-65. A photograph is facility-only, including a photograph of a client's own fruit.**
`0047` reads attachments with `is_facility_user()`, so a custom crush client can see their lot,
its weight and its lineage, and cannot see the picture of the scale that weight was read from.
That is the wrong way round: the photograph is the part of the record that is worth anything to
somebody who was not standing there. It is not an exposure, it is a withholding, which is why it
ships this way rather than the other: a read policy that is too narrow annoys somebody, and one
that is too wide shows one client another client's fruit. *Resolves when:* an attachment's
audience is derived from its subject the way `node_read` already derives a lot's, so a photograph
of a node is visible to exactly whoever may see that node. The work is one policy and a test that
two clients cannot see each other's photographs. *Load-bearing:* no. Nothing is lost and nobody
is shown anything they should not be; the client portal is simply thinner than it should be.


**S-66. What is in one bin is not always a number anybody measured.**
`placement` carries `volume_l` and `fill_pct` and no general quantity, so asking "how many pounds
are in PB2" cannot be answered from the placement. Raised from outside, reading the export, as the
one architectural change to make before harvest gets complicated. **The column is the wrong fix
and the problem is real.** A scale reading is of whatever went on the scale: three bins weighed
together produce one net weight and no per-bin figure, and writing `quantity` on each placement
would mean inventing three numbers nobody measured and then having them add up, which is exactly
the fabricated precision T0-2 exists to refuse. It looks derivable today only because the first
pick happened to be weighed one bin at a time. *Resolves when:* a view answers the question at the
resolution it was actually measured at, naming the reading rather than the bin, and says "these
three bins weighed 2,332 lbs together" where that is what happened. *Load-bearing:* not yet. It
bites the first time somebody puts two bins on the scale at once and then wants one of them.

**S-67. A vessel with no owner is read as the winery's and nothing says so.**
Six of eight vessels carry `owner_id` null, including the picking bins and three tanks. Null is
being used to mean "ours", which leaves no way to say "we do not know whose this is", and the two
are different facts in a barn holding two custom crush clients' barrels. Raised from outside,
reading the export. *Resolves when:* either the facility party is written on the vessels that
belong to it and null goes back to meaning unknown, or the schema says in a comment and a
constraint that null means the facility. The first is better and is a data change rather than a
migration, which is the winemaker's to make. *Load-bearing:* no, while every unowned vessel really
is the winery's. It becomes load-bearing the first time a vessel arrives whose owner is genuinely
unknown, because there is then nothing to write.

**S-68. The export carries the paths of photographs and not the photographs.**
`export_cellar` writes every row of every table, and a vessel's photograph is a path into a
private storage bucket rather than an image. So an export restored into an empty system has the
name of every photograph and none of them. This is a narrower thing than S-29, which is about the
vocabulary ids a restore reissues; this one is about bytes that were never in the file. Raised
from outside, reading the export, and correctly: if the button means "I can rebuild this winery
after the server burns down", it does not mean that yet. *Resolves when:* the export is a zip of
the json plus the bucket, or the button says plainly that photographs are not in it. The second is
an hour and is honest; the first is right. *Load-bearing:* yes the day somebody relies on it, and
the failure is silent until then, which is the worst shape.

**S-69. The rule that a lot says its vintage is enforced for new rows and not for old ones.**
`0049` requires every lot to carry either a year or an explicit non-vintage, closing the third
state, which was "nobody said". The constraint is added `not valid`, so rows that predate it are
grandfathered: one lot in the cellar, `2024 Eola Springs`, has no vintage today. That is deliberate
and it is not free. **A constraint that is not valid does not say what its name says.** Anybody
reading the schema sees a rule the data does not yet obey, and the only thing standing between the
two is somebody clearing a list. The alternative was to guess 2024 from the lot's own name and
write it, which is inventing a fact about somebody's wine from a string, and that is worse.
*Resolves when:* every grandfathered lot has been given a vintage on the screen `0049` adds, and a
later migration runs `alter table node validate constraint node_says_its_vintage`. The assertion
suite should then check that the constraint is valid rather than merely present. *Load-bearing:*
no, in the sense that nothing breaks. Yes, in the sense that a vintage report is wrong by exactly
the lots on that list and says nothing about it.

**S-71. There are two ways to record a press and only one of them is the real one.**
`0052` makes a press what it is, a process that starts, is drawn off repeatedly over some hours,
and finishes. The winemaker's words: "I wanted to start a press but I can't know how many liters
until after I've pressed", and "you might update the liters multiple times, or after different
pressures". The one-shot `press` from `0034` and `0045` is still there and still works, because
replacing it on the morning of a real press is not a thing to do to somebody. **So the same event
can be recorded two ways and they produce different lineage depth**: the one-shot makes each cut a
direct child of the picks, and the process makes a load between them, which is truer and is one
more generation for anything that walks the graph. Nothing reconciles them, and a season with both
in it is a season where "what is this made of" has two shapes of answer. *Resolves when:* `press`
is reimplemented as `start_press` plus its cuts plus `finish_press` in one transaction, so that the
one-shot is literally the process done all at once and there is one code path under both. The
assertions for `0045` should then pass unchanged except for the extra generation, and that
difference is the thing to look at carefully. *Load-bearing:* yes, quietly, from the first press
recorded the old way after this ships. The longer both exist the more the reconciliation costs.

**S-72. The contract declares shape and says nothing about sequence.**
`0057` declares what a periphery may read, what it may write, and what each write asks for,
checked against the catalog so it cannot drift. It does not say that a press must be started
before it can be drawn from, or that drawing must happen before finishing. A periphery built from
the declaration alone can therefore offer `finish_press` for a press that has had nothing drawn
off it, and find out it was wrong from a refusal. **That is not a disaster and it is not nothing.**
The refusal is a sentence written for a person, so the periphery recovers; but a text or audio
interface that offers three impossible things and one possible one is a bad interface, and the
knowledge that would fix it is currently only in `walk.ts`, which is the thing AR-Q8 is trying to
empty. *Resolves when:* a capability can name what must be true before it applies, most likely as
a readable that must be non-empty, so "finish a press" is offered exactly when a press is in
progress. That is a small addition and it is deliberately not in the first cut: guessing the shape
of a precondition language before a second periphery has asked for one is the same mistake this
whole entry exists inside. *Load-bearing:* no, while a periphery can afford to try and be told no.
Yes the moment somebody wants a periphery that never offers an action that cannot work, which is
exactly what an audio one would need.

**S-73. There are now three note tables and `0062` did not remove the other two.**
`day_note` belongs to a date, `vessel_type_note` belongs to a vessel type and carries a
resolve, and `0062` adds `note`, which belongs to any subject the resolver knows and
therefore to both of those. **Inventing a note table per subject is what `0062` exists to
stop, and it ships alongside the two it was meant to replace.** That is deliberate and it is
not free: the daily log and the vessel type screens work and it is harvest, so rewriting
them onto the general table is a change with no upside this week and a real chance of
breaking two screens somebody is using. *Resolves when:* `day_note` becomes a note on a
subject type of `day`, which the resolver would have to learn, and `vessel_type_note`
becomes a note on a `vessel_type` with its resolve kept as the one thing the general table
does not have. Both are migrations plus a screen each. *Load-bearing:* no, while somebody
knows which of the three to read. Yes for anybody writing a fourth client, who will find
three shapes of the same idea and no statement of which is current.

**S-74. A typed fact has a kind and nothing yet reads one.**
`0064` lets a note carry a registered kind and a value, which is what turns prose into
something reportable. **What it does not do is report.** `typed_fact` exists and one screen
writes into it; no screen reads it, nothing on Alexis's four forms is filled from it, and the
only seeded kind is fruit condition. So the mechanism that was built to cover four forms at
once currently covers one field on one of them. *Resolves when:* a screen lists what has been
typed about a lot, and the paper forms in `0043` are satisfied from typed facts rather than
from their own machinery. *Load-bearing:* no, and this is the entry most at risk of reading
as done: the migration is the hard half and the visible half is missing, which is exactly the
shape that gets a green tick in a status ledger and disappoints somebody in March.

**S-75. Nothing checks a typed value against the unit its kind declares.**
A fact kind may declare a unit, and `0064` stores it on the term and checks nothing with it.
A Brix of 220 and a Brix of 22 are both numbers. This is S-63's family, one table over: the
same missing answer about what a unit is and what may be compared to what. *Resolves when:*
S-63 is answered for weight, volume, area and count, and a fact kind's unit joins that
answer rather than getting its own. *Load-bearing:* no, while a person types every value and
would notice. Yes the first time a value arrives from anywhere but a person's hands.

**S-76. A sample is of a place, and "the Pinot Gris" is not a place.**
The winemaker asked for samples assigned to "vineyards and blocks and varieties". The first
two are subjects and the third is not: a variety is a `term`, a word, and sampling a word is
not a thing. `0067` reads "a variety" as "a variety in a block", which is a `planting` and
is a real row, and registers that. **That covers what somebody standing in a vineyard means
and does not cover what somebody at a desk might mean**, which is "every Pinot Gris we have,
across four blocks and two vineyards". That second thing is a query over plantings rather
than a subject, and answering it by registering `variety` as a subject would make a sample
of a word possible, which is worse than the gap. *Resolves when:* somebody wants a reading
that spans blocks, at which point the question is what it averages and by what weight, and
that is a report with a decision in it rather than a missing subject type. *Load-bearing:*
no. It is a shape of question nobody has asked, recorded so that the absence is deliberate
rather than an oversight.

**S-77. This stack is signed with Supabase's published demo keys.**
The anon key in use carries `iss: supabase-demo` and the JWT secret is
`super-secret-jwt-token-with-at-least-32-characters-long`, both of which appear in Supabase's
own public documentation because they are the defaults every local stack starts with.
**Anybody who can reach this API can mint a `service_role` token and read and write
everything, row level security included**, without needing a password or an account. Today
that is bounded by Tailscale: the API is reachable only from the winemaker's own tailnet, and
the keys are therefore not the control, the network is. *Resolves when:* the cellar moves to
a project with generated keys, or this stack's `jwt_secret` and keys are rotated in
`config.toml` and every client updated. *Load-bearing:* not today, and **absolutely** the
moment anything makes this reachable from the internet, which is exactly what the intern
question asks for. Nothing about this app may be exposed publicly until this entry is
discharged.

**S-79. The mutation ratchet has been red for eleven sessions and nothing said so.**
`scripts/ratchet.sh` was run tonight, cleanly, for the first time since W-10 re-cut its
baseline after `0028` and `0031`. It fails four gates. 186 refusal sites are neither
behaviourally covered nor filed unreachable, and three declarative classes are above their
baseline: `check` at 13 uncovered against 0, `unique` at 14 against 10, `policy` at 63
against 32.
**Almost none of it is tonight's.** The uncovered sites sit in `press` (25), `start_press`
(18), `weigh_bins` (16), `draw_cut` (13), `add_to_wine` (12) and twenty six other functions,
every one of them written in the eleven sessions since the baseline was cut. The
declarative classes grew the same way: the schema went from 59 policies to 98 and from 22
check constraints to 39, and a gate phrased as "no class may hold more uncovered mutations
than it did" cannot survive a schema that doubled.
**Why nobody noticed.** `green.sh` checks that `refusal-sites.tsv` still matches the
schema and tells you to run the ratchet before landing. Every session since regenerated the
inventory, which is the cheap half, and none ran the ratchet, which is the half that takes
thirty five minutes. A gate that is not in the gate is a suggestion.
*Resolves when:* each uncovered site is either covered by an assertion naming the specific
refusal or filed in `refusal-dispositions.tsv` with why it is unreachable, and the
declarative baseline is re-cut afterwards rather than before. Re-cutting first would record
the drift as the new floor, which is the one thing a ratchet must never do.
*Load-bearing:* not for correctness today, and yes for the claim this repo makes about
itself. The suite's own note says an assertion that catches any error covers the function
and no site in it, and 186 sites is the size of the gap between what the assertions are
believed to check and what they check. **`claim_account` was two of those 186 tonight, found
by this run and fixed before landing, which is the argument for the whole apparatus.**

**S-80. Only barrels have a colour, and oak is not the only thing that stains.**
`barrel_colour` derives from placements into vessels whose type is `barrel`, and nothing
else. Concrete, amphora and any other porous vessel this winery buys later would stain the
same way and would read as having no colour at all, which is worse than reading `unknown`:
they are not in the view, so they are not on any list. Stainless genuinely cannot stain and
is correctly absent.
It is scoped this way because the winemaker asked for barrels, the cellar has four of them
and no concrete, and generalising a rule used in one place to vessels that do not exist here
is a guess dressed as foresight. *Resolves when:* this winery has a porous vessel that is not
a barrel, at which point the fix is a `porous` attribute on the `vessel_type` vocabulary and
one changed join, because the rule already lives on a registry row rather than in a function.
*Load-bearing:* no, and it becomes load-bearing the day a concrete egg arrives, silently.

**S-81. Correcting whose wine a lot is does not carry its children.**
`set_lot_owner` changes the lot it is given and counts, without changing, every descendant
still filed under the old party. A pick corrected before it is pressed needs nothing else; a
lot corrected after it has been pressed, racked and blended leaves children carrying the
party they copied at the moment they were created.
It is counted rather than cascaded because **a child legitimately belonging to somebody else
is not a defect**: fruit sold mid-process, a client buying a share of a press, and a lot
blended from two parties all produce exactly that shape, and a cascade would quietly rewrite
those. *Resolves when:* somebody has to correct a lot that already has children, at which
point the question is whether the answer is a cascade, a prompt listing the descendants, or a
refusal telling them to correct each one. *Load-bearing:* not today, and it becomes so the
first time a correction arrives late rather than within the hour.

**S-82. A client's own bins cannot be recorded from the bin screen.**
`add_bins_to_pick` takes `p_owner_id` and the screen that calls it never passes one: it
sends `on_loan_from` or nothing. So a bin belonging to a custom crush client, as against one
on loan from a grower, can only be given its owner by editing the vessel afterwards.
The two are genuinely different and the schema already knows it. A client is a party, so
their equipment gets an `owner_id` and the privacy model applies to it. A grower is not a
party, which is why `0036` made the lender free text rather than inventing one. The screen
offers only the second. *Resolves when:* a client brings their own bins, at which point the
bin screen needs the same party picker the vessel form already has, and the two controls
need to read as one question with two answers rather than two questions.
*Load-bearing:* no. Both custom crush clients currently use this winery's bins, and the
vessel edit screen can set an owner today.

**S-83. A sample's kind follows the lot's stage now, not its stage on the day.**
`sample.kind` reads juice or wine off `node.stage`, and a node has one stage: the one it is
at today. A ferment sampled in September and racked to barrel in November is a lot at
`maturation`, so every sample ever taken of it reads `wine`, including the ones taken while
it was bubbling.
The lot it was taken from is exact, because `placement` records the window and the view uses
it. What is approximate is only juice against wine, and it is approximate in one direction:
samples migrate from juice to wine as the lot matures, never back.
**For the purpose it was built for this is right rather than wrong.** The filter exists so
that during harvest the ferments being sampled weekly are not buried under two vintages of
barrel wine, and a lot that has gone to barrel has stopped being a ferment. It goes wrong
when somebody reads the history of a finished lot and finds its ferment samples filed under
wine. *Resolves when:* somebody needs that history, at which point the answer is stage
history on the node rather than a category on the sample, since nothing else in the schema
can say what a lot was on a given day either. *Load-bearing:* no, and it is worth knowing
before anybody builds a ripening curve off these rows.

**S-84. An estimate in the bins and a weighing of the pick sit side by side, unreconciled.**
`bin_fruit` says what somebody thought was in each bin. `weigh_bins` records what the scale
said for a set of bins together, and the lot's `quantity` comes from that. Nothing compares
them, so a pick estimated at eight bins of 850 and weighed at 5,100 pounds reports both
figures and says nothing about the 1,700 pound gap.
The gap is the useful number. It is how you learn that your bins run light, that somebody
counted a bin twice, or that fruit went somewhere between the vineyard and the scale.
*Resolves when:* somebody wants it, at which point it is a view comparing the estimate
against the weighing per pick and a threshold worth flagging, and the threshold is a
winemaking judgement rather than an arithmetic one. *Load-bearing:* no. The weighing is
authoritative and the estimate never overwrites it, which is the failure that would matter.

**S-85. A part-pressed pick's weighed quantity still describes the whole pick.**
`weigh_bins` puts the scale's figure on the pick, and `0090` lets some of that pick go into a
press while the rest stays in bins. The pick's `quantity` still says what the whole pick
weighed, which is correct as history and is not what is left.
What is left is derivable and is not derived anywhere: it is the sum of `bin_fruit` over the
pick's remaining open placements, which are estimates, against a weighed total that is not.
Mixing a weighed number and an estimate to report a remainder would produce a figure that
looks measured and is not. *Resolves when:* somebody needs to know what is still on the pad
in pounds rather than in bins, at which point the honest answer is probably to report it as
"three bins, about 2,100 lb by estimate" and never as a single number.
*Load-bearing:* no, and it is the reason the press screen counts bins rather than pounds
when it says what is left.

**S-86. An applied import cannot be undone as a batch.**
`0094` brings records in as proposed capability calls that somebody confirms one at a time,
and each applied step records what it returned. What it does not have is a way to put a batch
back: three hundred rows applied against the wrong vintage would have to be undone the way
anything else is undone here, which is a correction per row, and for events that means a new
event rather than a deletion.
This is the append-only rule meeting a bulk operation, and it is not obviously wrong: an
import that could be rolled back would be the one write path in this app that can erase
history. *Resolves when:* somebody actually does a bad import, at which point the question is
whether the answer is a reversal capability, a practice-first rule that makes it not matter,
or a batch that stays open until every step is confirmed. **The practice stack already makes
this survivable** and is the reason it is filed rather than built: import there, look at it,
throw the stack away. *Load-bearing:* not while every import is rehearsed in practice first,
and immediately if anybody imports straight into the cellar.

**S-88. A machine being asked to cool is not a machine that is cooling.**
`0100` derives `running` on a glycol machine from the jackets hooked to it, which is right in the
sense that it cannot go stale and wrong in the sense that nothing in this app has ever touched the
machine. A unit switched off at the wall, low on glycol, or with a tripped compressor reads as
cooling for as long as a tank on it is set to cooling, and the screen will say so confidently.
That is the honest limit of a schema whose only sensor is a person, and it matters most in exactly
the case the feature was asked for: the machine is struggling and somebody wants to know why.
*Resolves when:* either somebody records the machine's own state as a told fact with a time on it,
which is a second thing to maintain and was deliberately not built, or a probe reports its supply
temperature, at which point `running` becomes measured and the derived version becomes the
expectation to compare it against, which is the shape `0096` already uses for yield.
*Load-bearing:* no while two machines sit in one room and a person can hear them, and immediately
if this app is ever used to decide that a tank is fine unattended.

**S-89. A note about wording points at a screen, not at the words.**
`0101` makes every screen a row so a note can be about one, which answers "notes point to
actual objects" for the case the winemaker named. What it does not do is make the words
themselves objects. A note reading "the button here should say Save rather than Record" is
filed against the screen, and somebody reading it later has to find the button by looking.
The alternative is a row per label, which is a content management system for an app whose
words are currently readable in one file, and it would put a round trip in front of every
string a screen draws. *Resolves when:* either the wording notes pile up enough that finding
the label becomes the slow part, at which point the answer is probably that a note carries the
exact text it is about as a quote rather than that every label becomes a row, or the app
acquires a second language, at which point the labels have to move into the database anyway
and this stops being a choice. *Load-bearing:* no, and the first few dozen wording notes are
the evidence that decides it.

**S-90. A corrected draw does not shrink the tank it was blended into.**
`0102` lets a cut be drawn into a tank that already holds wine, and the tank's lot grows by the
volume that arrived. Everywhere else in the press, quantities are recomputed from the draws that
have not been superseded, so a corrected draw lands without anybody working out what the old one
contributed. The blend path adds instead: the resident lot's volume and the lineage shares are
incremented by what arrived, because the resident lot's own starting volume is not derivable from
the press events and subtracting it would mean guessing. So superseding a draw that went into an
occupied tank leaves that tank reading high, and the lineage shares reading off by the same
amount. *Resolves when:* the resident lot's volume before the press touched it is written down at
the moment of the first blend, at which point the whole thing recomputes the way every other
quantity here does. That is a small change and it is not being made mid harvest, because the code
being changed is the code juice is running through tonight. *Load-bearing:* yes if a draw into a
shared tank is corrected, which is the ordinary way a mistyped volume is fixed, and the symptom is
a tank that reads fuller than it is rather than anything silent.

**S-91. Machines have a history and no schedule.**
`0105` records what was done to a machine and when, which is what the winemaker asked for:
"lineage of equipment including maintenance", not a maintenance planner. So there are no due
dates, no service intervals, no hour meter rolling over into a reminder, and nothing anywhere
says the tractor is overdue.
That is a real gap and it is deliberate rather than forgotten. A due date nobody set produces a
screen full of red, and a screen full of red is one people stop reading, which costs more than
having no reminders at all. The honest version needs somebody to say what the interval actually
is for each machine, and that is a conversation with a person who owns the equipment rather than
a schema decision. *Resolves when:* somebody asks the app when the press was last serviced and
is annoyed that it cannot also say when it is next due, at which point the interval is a field on
the model, the last service is already recorded here, and the arithmetic is one line.
*Load-bearing:* no. Nothing depends on it and nothing claims otherwise.

**S-93. The shop app loses your place when the phone discards the tab.**
The cellar learned this the hard way: a phone discards a backgrounded tab under memory pressure,
so leaving the app to take a photograph and coming back is a cold start rather than a switch. The
winemaker found it halfway through registering a tank, needing the photograph that was the reason
to leave. `places.ts` answered it by putting the place in the URL, so a restart lands where you
were, and drafts answered the typing.
The shop periphery has neither. Its screens are reached by calling a function from a closure on
the screen before, which is exactly the shape the cellar had before it was fixed, and it is the
same phone. Matt recording a repair, stopping to photograph a part number, and coming back to the
machine list with his typing gone is the specific failure, and it will happen the first week he
uses it. *Resolves when:* the shop gets the same treatment, which is a hash router over the
`ShopPlace` union already written in `packages/shop/src/places.ts` plus the draft store the cellar
uses. The union exists because this was foreseen while building it, not afterwards.
*Load-bearing:* yes, as soon as anybody uses the shop app for anything longer than one screen.

**S-93. The shop app loses your place when the phone discards the tab.**
The cellar learned this the hard way: a phone discards a backgrounded tab under memory pressure,
so leaving the app to take a photograph and coming back is a cold start rather than a switch. The
winemaker found it halfway through registering a tank, needing the photograph that was the reason
to leave. `places.ts` answered it by putting the place in the URL, so a restart lands where you
were, and drafts answered the typing.
The shop periphery has neither. Its screens are reached by calling a function from a closure on
the screen before, which is exactly the shape the cellar had before it was fixed, and it is the
same phone. Matt recording a repair, stopping to photograph a part number, and coming back to the
machine list with his typing gone is the specific failure, and it will happen the first week he
uses it. *Resolves when:* the shop gets the same treatment, which is a hash router over the
`ShopPlace` union already written in `packages/shop/src/places.ts` plus the draft store the cellar
uses. The union exists because this was foreseen while building it, not afterwards.
*Load-bearing:* yes, as soon as anybody uses the shop app for anything longer than one screen.

**S-92. A machine model with no machine cannot be chosen.**
`0106` registers `shop.machines` and `shop.machine_history` as readables and nothing for models on
their own. The add-a-machine screen therefore builds its model list from the machines that already
exist, taking each one's model, which means a model you have just registered and not yet used is
missing from the list the moment you need it. Registering a model and then a machine of that model
is the ordinary first thing anybody does, so this is wrong on the first run.
It is small and it is not a schema problem: `machine_model` is a table with rows in it, and the
gap is that no readable names it. *Resolves when:* somebody adds `shop.models` to the readable
registry, at which point the screen reads the list directly and this paragraph goes away.
*Load-bearing:* yes for the first machine anybody registers, and the workaround is to register the
machine first and the model after, which is backwards.

**S-94. The front door lists modules nobody can get.**
`0109` lists every module including the ones with no periphery, on the argument that "started and
not finished" is truer than showing nothing. Stores, Vineyards and Marketing therefore appear on
the chooser as things that cannot be opened, and Marketing in particular has not a single row in
the kernel behind it: it is there because the winemaker named it.
The risk is the ordinary one for a list of things that do not work yet. A person who taps three
dead entries learns to stop reading the list, and by the time Stores is real they have stopped
looking. *Resolves when:* either those modules get peripheries, at which point the problem solves
itself, or somebody notices they are being ignored and the honest answer becomes hiding them
behind something that has to be opened on purpose. The evidence for which is whether anybody ever
asks about a module they saw greyed out. *Load-bearing:* no, and the counts beside each one are
there so that a dead entry at least says how much of it exists.

**S-95. A parts decomposition with no way to put one in.**
`0112` builds the tree, the domains and the derivation, and registers both readables, and
there is no capability and no screen for any of it. A model's parts can only be entered by
writing SQL, which means the researched baseline for the press, the thing the whole structure
exists to hold, cannot be entered by the person who did the research.
This is the same order of work the shop module itself followed, kernel first and screens
after, and it was defensible there because the kernel was small. Here the entering is the
hard part: a press decomposes into a tree somebody has to sit and type, probably from a parts
manual, probably over an evening. *Resolves when:* `add_model_part` and `change_machine_part`
exist as capabilities and the shop app can draw and edit a tree, which is a bigger screen
than anything in that app so far. Until then this schema holds nothing.
*Load-bearing:* yes, in the sense that the feature does not exist for a user until it is
closed. Nothing else depends on it.

## Discharged
**S-92. A machine model with no machine could not be chosen.** *Discharged by `0108`.*
`0106` registered two readables and forgot the obvious third, so the add-a-machine screen built
its model list out of the machines that already had one. Register a model and then a machine of
it, which is the first thing anybody does, and the model was missing at exactly that moment.
`machine_model_detail` lists models whether or not anybody owns one, and carries a count of how
many machines are of it so a model with none reads as newly registered rather than as an error.
The screen reads it, and `shop.register_machine` now names it as the source for its model field
instead of pointing at the machine list as a stand-in.

**S-87. Five bins carried the wrong naming convention.** *Discharged 2026-09-17.*
PB4 through PB8 were Pearlstad's, sitting in the middle of a series that was otherwise this
winery's, and `0098` set the convention for a borrowed stack without applying it to them: they were
in a press log and being read off by hand all day, and a bin called one thing in the app and another
in the yard is worse than a bin with an unhelpful name.
The winemaker asked for the rename the morning he was about to register new bins, which is exactly
the day it mattered and a day when all five were empty and off the press. They are PEAR1 to PEAR5,
each carrying a note recording what it used to be called, because somebody had been reading PB4 off
the side of one all week and may have written that on paper. PB4 is free again and is where the next
stack of this winery's own bins will start.

**S-78. Anybody who can sign up becomes staff.** *Discharged by `0068`.*
`enable_signup = true`, and `claim_account` gave any authenticated identity that had not
claimed one a `cellar` role, which `is_facility_user()` treats as somebody who works here.
That was right for a winery handing a phone to a new intern on a private network, and it was
open registration the moment the sign-up page became reachable by strangers. It was the
survivor of S-25, which closed the narrower hole of an unlinked client account and left the
wider one because the wider one was not reachable.
`0068` makes claiming require an invite: six characters an administrator creates and reads
out, good for a week and usable once, stamped with who used it rather than deleted. The first
claim on a fresh install still needs none, because there is nobody to issue one and that claim
is what creates the person who issues the rest.
**`enable_signup` stays true on purpose.** A stranger may still create an auth identity, and
an identity with no `app_user` row is nobody: it reads nothing, writes nothing, and every
policy in the schema is a row level test against a row it does not have. Turning signup off
would mean an administrator creating accounts in Supabase's dashboard, which is a second
admission path nothing in this repo asserts.
**S-77 is not discharged and is the one that matters.** Rotated keys with open registration
would have been a locked door beside an open window; this is the window shut and the door
still standing open. Nothing may be exposed publicly until S-77 is answered.

**S-52. A press recorded no cuts.** *Discharged by `0045`.*
The entry said that pressing free run and hard press separately recorded shares proportional to
fruit weight, which is arithmetically sound and factually wrong, because the shares say the hard
press is a proportional slice of every bin and say nothing about it being the hard press.
**The resolution was not to change the arithmetic.** Proportional by fruit weight is correct: a
hard press is made of the same fruit as the free run and in the same ratios. What was missing was
that the cut is a fact about the lot and there was nowhere to put it. `0045` makes each cut its
own child carrying its own name, from a registered `press_cut` vocabulary so that free run typed
three ways is not three cuts, and every child of one press draws the same share from every parent.
What remains is narrower and is filed as S-58's neighbour, S-62.


**S-25. An account belonging to no party is staff, so a client who signs up
before being linked sees the whole cellar.**
`is_facility_user()` coalesces a missing party row to true, which is right for a
cellar hand: they have no party and must still see the cellar. It is wrong for
the gap between a custom crush client creating an account and an admin attaching
it to their party. In that window they are an ordinary facility user and can
read every lot, including other clients'. Nothing warns anybody, and the failure
is invisible from both sides: the client sees more than they should and the
admin sees nothing unusual. *Resolves when:* either an account carries an
intent, so an unlinked one that was created as a client defaults to seeing
nothing, or linking happens as part of inviting them rather than afterwards.
*Load-bearing:* it is a confidentiality boundary between two clients who are
already real, and the exposure lasts exactly as long as somebody forgets.
*Discharged 2026-09-11 by `0022_admission_and_authorship.sql`.* `is_facility_user()` now
requires an active `app_user` row and refuses any login linked to a client party whether
that party is active or not. An authenticated identity that has never claimed an account
is no longer a facility user, so the window this entry describes is closed at the
database rather than in the walk. The intern case it was protecting survives untouched:
no party row at all is still staff.


**S-26. `vessel_state` did not obey row level security.** *Found and closed
2026-09-10, in `0017_vessel_state_rls.sql`.* A view runs with its owner's rights
unless it is created `security_invoker`, and this one was not, while `lot_state`
and `task_board` were. So `node_read`, correct since 0003, did nothing on the
view every screen actually reads. Measured before the fix, acting as a client
with one lot: one row through `node`, one through `lot_state`, two through
`vessel_state`, including another party's lot by name. Both custom crush clients
could read the whole cellar from the vessel list. Recorded here rather than only
in a commit because the lesson outlives the bug: every assertion in this repo
queried tables, and the screens query views, so nothing noticed for eight
sessions. There is now a check that every view in `public` is `security_invoker`.

**S-3. Partial consumption of a parent is unhandled.** *Discharged 2026-09-09 by
the winemaker's rule, in `0013_close_on_empty.sql`.* Taking part of a lot leaves
the rest of that lot, open, at a reduced volume: 228 L off a 2000 L lot leaves
1772 L. A lot closes when it is empty and not when it first feeds something, so
`lineage_closes_parent` is gone and lineage goes back to recording only where
material came from. The old rule was also written into spec.md, which has been
corrected rather than left disagreeing with the schema.
