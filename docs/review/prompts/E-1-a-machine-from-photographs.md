# E-1: Documenting a machine from photographs

**Target:** whichever machine is shown in the photographs attached to this session. A press, a tractor, an implement, a sorting line, a pump, a chiller. The photographs are the brief; this document is only the method.
**Scope:** identification, documentation and decomposition of that one machine. Not a review of any code.
**Date:** 2026-09-17, first written for a winery press and deliberately kept general.

This is a research task. The output is a document somebody can read while standing at the
machine, and a parts skeleton somebody can type into a database. Its value is measured by
whether a person with a wrench is better off for it.

**Nothing in this prompt says what the machine is.** That is in the photographs. Do not assume
a make, a model, an industry or an age from anything written here.

---

## Why this exists

The owner is building a record of each machine as a **model plus every departure from it**.

The *model* is what one of these is as the manufacturer built it: the researched baseline. The
*machine* is this one, with its own history of repairs, replacements and modifications. The
baseline is researched once and shared by every machine of that model; the departures belong to
this one.

You are being asked for the baseline, and for a clear list of the departures visible in the
photographs. Keeping those two apart is the whole exercise. A modification described as a
factory feature, or a factory feature described as somebody's bodge, is worse than no document.

---

## What you are given, and how to treat it

**Photographs, and nothing else.** Look at every one of them properly before writing anything.
They are the primary evidence and they are the only evidence anybody has gathered so far.

Mark every claim you make:

- **read**: legible or plainly visible in a photograph.
- **confirmed**: verified against a manufacturer document, standard or catalogue that you cite.
- **inferred**: a reasonable conclusion from what you can see, which somebody should check.
- **unknown**: you looked and could not establish it.

**Never write `confirmed` on your own authority.** It means a cited document says so. An
inference that would make the document tidier is still an inference, and a gap named is worth
more than a plausible substitute.

Where a photograph and your reading of it disagree, the photograph is right.

### What to look at hardest

**The maker's plate, first, before anything else.** Serial number, model number, year,
capacity, pressure, voltage, and any registration or type-approval number. A serial number
converts the whole task from "find something that looks like this" into "ask the manufacturer
about this exact machine". If a plate is legible in any photograph, transcribe every field of
it, including the ones you do not understand.

**Anything handwritten, printed on a label, engraved, or scratched on.** Stickers, dymo tape,
paint pen, tags wired to a fitting, initials and dates. On an old machine these are the highest
value marks in any photograph, because they are the record of things somebody did and wrote
down nowhere else. Transcribe them exactly, including initials and dates, and treat each one as
a departure to be explained.

**Date codes on components.** Valves, drives, motors and controllers usually carry one. They
cross-check the machine's age, and a component much newer than the machine is a replacement.

**Things that do not match.** Different fasteners, newer cable, a component in a different
colour or finish to its neighbours, a modern part on an old assembly, a label in a different
language. Each is a probable departure.

---

## What to find

### 1. What this machine is

Identify the manufacturer, the model, the capacity or size, and the years it was built. Say how
confident you are and what would settle it. If a control panel or an assembly was fitted across
several models, say so rather than picking one.

Reconcile any figure on the plate against any other figure you are given or can see. If they
disagree, say which is likely right and why. The owner will correct their own records from your
answer, so an unresolved discrepancy named clearly is more useful than a guess.

### 2. How to get the real documentation

Find and cite, with URLs:

- The operator's manual for that model, in English if it exists and in the original language if
  not.
- The spare parts catalogue or exploded diagram.
- Schematics: electrical, and hydraulic or pneumatic as applicable.
- Service bulletins, recalls, and anything about the known wear items.
- The manufacturer's current parts contact, and any independent parts supplier, preferring ones
  in the owner's country.

If the manufacturer still exists, **draft the email the owner should send them**: short,
quoting the serial and any registration number, asking for the manual, the parts catalogue, the
schematics, and price and lead time on the obvious wear items. Include the real contact
address and say where you found it. A courtesy line in the manufacturer's own language does no
harm.

Say plainly what you looked for and could not find.

### 3. The decomposition

Produce a parts tree. It has no depth limit: an assembly contains a subassembly contains a
part. Cover the machine's major systems, which for most machines means some of:

- **Structure and body.** Frame, shell, doors, seals, guards, wheels or tracks, bearings.
- **The thing it actually does.** The working element, whatever that is, and everything that
  drives it: motors, gearboxes, chains, belts, pumps, cylinders.
- **The medium it works with,** if any: hydraulic, pneumatic, water, product. Pumps, valves,
  lines, sensors, relief devices, unions.
- **Control.** Panel, display, controller or PLC, sensors, emergency stop circuit, program
  storage.
- **Electrical supply.** Motor, drives, contactors, overloads, isolators, enclosures.

For each part give: name, parent part, domain, manufacturer part number if one exists, quantity,
whether it is a wear item and its expected life, and anything worth knowing at six in the
morning. Mark each entry read, confirmed, inferred or unknown.

Domains, which are a fixed list: **mechanical, electrical, hydraulic, pneumatic, control and
software, consumable, structural.**

### 4. Reference images of the stock components

**This is the part most easily skipped and it is worth as much as the parts list.**

For every significant component you identify, find the manufacturer's own image of it: a
catalogue photograph, a datasheet illustration, an exploded diagram. Cite the URL. Present it
against what is visible in the owner's photographs, and say whether they match.

The point is not decoration. It is how an undocumented departure gets found. A motor that is
not the motor in the catalogue, a valve in the wrong body, a controller from a different
series, a gearbox with a different flange: each one is something somebody changed and nobody
recorded, and the only way to see it is to have the stock article next to the real one.

Where they differ, say so explicitly and say what the difference implies. Where you cannot find
a reference image, say that rather than passing over it in silence, because "no reference image
found" is itself useful: it means nobody can check that part by eye.

### 5. Each photographed component, in its own right

Where a photograph shows a component closely enough to identify, give it a short section:

- What it is and what it does on this machine.
- Its manufacturer, part number and datasheet, cited.
- How it fails, and what the symptoms are.
- Whether it is still available, and the modern equivalent if it is not.
- What its date code implies.

### 6. The departures, and the safety of them

List everything you believe has been changed from stock, with the evidence for each, and the
date if a label gives one.

**Where a modification touches electrical safety, pressure, guarding, or emergency stop, say
so plainly and do not soften it.** Do not speculate past what the evidence supports: if a label
or a photograph is ambiguous, give the possible readings and say what would distinguish them.
If the right answer is that a qualified person needs to look at it before the machine is used
again, say that.

---

## How to answer

One document:

1. **What this machine is**, in a paragraph, for somebody who has never seen it.
2. **Identification**, with confidence and what would confirm it.
3. **The parts tree**, nested, each entry with name, domain, part number, quantity, wear item,
   evidence marker.
4. **Reference images**, component by component, with the comparison.
5. **The component investigations.**
6. **The departures**, and anything that is a safety matter.
7. **The email to the manufacturer**, ready to send.
8. **Sources**, every one with a URL, and a list of what you could not find.

Keep the tree free of this machine's history. The tree is the stock article; the departures are
a separate section. That separation is what the whole document is for.

---

## Where this lands

The output becomes rows in two tables in the owner's system, which is why the shape matters:

- one row per part: model, parent part, name, domain, part number, quantity, specification,
  note;
- one row per departure, each tied to a dated piece of work: what changed, on what date, by
  whom.

You do not need access to that system. Produce the document and the tree; somebody else will
type them in.
