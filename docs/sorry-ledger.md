---
Type: record
Purpose: "Records every open deferred-verification obligation for the winery app, one entry per gap, as the honest unit of progress."
Depends on: [packages/cellar/docs/spec.md, docs/methodology-lineage.md]
Depended on by: [docs/status-ledger.md, docs/findings-ledger.md, CLAUDE.md, README.md]
---

# Sorry Ledger

A named gap is a build artifact. A gap without a record is one you cannot revisit.

S-8 through S-12 are compliance gaps. Every one of them must be confirmed with
the winery's compliance advisor before any schema is built for it. A guessed
tax boundary produces confident wrong numbers on a federal return, which is a
worse outcome than producing none.

## Open

**S-1. Topping lineage threshold undecided.**
Strictly, topping makes every barrel a two-parent node, which produces thousands of
edges and is unusable. Below some percentage the volume and source are recorded
without writing lineage. That percentage is not chosen. *Resolves when:* a threshold
is set explicitly, with the reason recorded. *Load-bearing:* affects whether block
composition on a topped barrel is honest.

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


## Discharged

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
