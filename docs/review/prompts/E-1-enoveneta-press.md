# E-1: The Enoveneta membrane press, from photographs to a parts skeleton

**Target:** one machine at Vitae Springs, a pneumatic membrane press by Enoveneta, referred to in the app as "1.2T Membrane Press".
**Scope:** identification and documentation of this press and the components photographed on it. Not a review of any code.
**Date:** 2026-09-17
**Wanted by:** the winemaker, so that the shop module has a researched baseline to record departures from.

This is a research task, not an engineering review. The output is a document somebody can
read at the machine and a parts skeleton somebody can type into a database. Its value is
measured by whether a person standing at this press with a wrench is better off for it.

---

## Why this exists

The winery is building a record of each machine as a **model plus every departure from it**.
The model is what one of these is as the manufacturer built it; the machine is this one, with
its own history. What is wanted from you is the model half, researched properly, so that the
departures already visible on this press have something to be departures *from*.

The structure it has to land in is a tree of parts, each classified by domain (mechanical,
electrical, hydraulic, pneumatic, control and software, consumable, structural), each with a
part number where one exists, a quantity, and free-form specification. The tree has no depth
limit: a press contains a hydraulic system, which contains a pump, which contains a seal kit.

---

## The evidence, and how far to trust it

Six photographs were taken on 2026-09-17. They are not attached to this file. They are at
`C:\Users\Randy\.claude\uploads\d6a38a2d-4674-4fda-be24-1420b81eb15a\` on the winery desktop,
named `7c596789`, `ab4b8075`, `7b609e07`, `6f21133f`, `25adcc69`, `8bb04794`, each
`-image.jpg`. **Attach them to your session if you can.** What follows is a transcription made
from them, and a transcription is not the photograph.

Everything below is marked either **read** (legible in a photograph) or **inferred** (a
reasonable reading that you should confirm or correct). Carry that distinction into your
output. Do not upgrade an inference to a fact because it would make the document tidier.

### The press and its control panel

- **Read.** Maker plate on the panel: `ENOVENETA`, and beneath it `TECNOLOGIE ENOLOGICHE`.
- **Read, and not evidence about the machine.** The screen shows a program table headed
  `PROGRAM  CHARDONNAY*1`. **This program was written by the winery, not by Enoveneta.** It is
  one of their own press curves, entered into the panel by a person, and it says nothing about
  what model this is or how it was configured when it arrived. Use it only as proof of what the
  panel can store and how a program is shaped. Do not use its pressures or times to identify
  anything, and do not describe them as factory settings. Its columns are:
  `STEP`, `PRESSURE mBar`, `REVS. Nr`, `REP. Nr`, `TIME sec`, and ten rows:

  | Step | Pressure mBar | Revs | Reps | Time s |
  |---|---|---|---|---|
  | 01 | 0200 | 00 | 01 | 300 |
  | 02 | 0400 | 00 | 01 | 300 |
  | 03 | 0600 | 00 | 01 | 300 |
  | 04 | 0800 | 10 | 01 | (obscured) |
  | 05 | 0400 | 00 | 01 | 300 |
  | 06 | 0600 | 00 | 01 | 300 |
  | 07 | 0800 | 00 | 01 | 200 |
  | 08 | 1000 | 00 | 01 | 200 |
  | 09 | 1200 | 05 | 01 | 300 |
  | 10 | 0600 | 00 | 01 | 300 |

  Step 05 is highlighted. `TIMER 248` at the left. `STATUS PRESSURE mBar 370` along the
  bottom. A loop indicator reading `01` at the lower left of the table.
- **Read.** Controls: an orange twist-release `EMERGENCY` stop, a red `RESTORE` button, an
  unlabelled white button with a lightning-bolt-and-arrow symbol, three drum-rotation buttons
  with circular arrow icons, a drum-lowering icon, a cycle icon, `F1`, a numeric keypad with
  letters (1, 2 ABC, 3 DEF and so on), `ESC`, `ENTER`, a `SERVICE` key marked with a spanner,
  a backspace arrow, four screen-navigation keys, and `START` (green), `STOP` (red), `PAUSE`
  (yellow).
- **Inferred.** The pressure figures are membrane inflation pressure in millibar; `REVS` is
  drum rotations performed at that step; `REP` is repetitions of the step.
- **Consequence worth stating.** Because the program is theirs rather than the manufacturer's,
  it exists in exactly one place: a controller built in or before the late 1990s. The
  photograph is currently its only backup. How to export, copy or transcribe a program is
  therefore a more valuable answer than it looks.

### The pneumatic directional valve

- **Read.** Red label: `ARBEITSDRUCK VAK-16 BAR`, `10/99`, and the part number
  `I34SA4002000020`. A pneumatic schematic symbol is printed at the left of the label, with
  `12` and `14` marked at its ends.
- **Read.** The valve body is teal or pale green; the visible brand lettering ends in
  `MATICS`. A solenoid coil is fitted at one end with a grey DIN-43650-style plug and a yellow
  indicator LED. Three galvanised pipes enter from above through an elbow manifold.
- **Inferred.** `ARBEITSDRUCK` is German for working pressure, so `VAK-16 BAR` reads as vacuum
  to 16 bar. The `12`/`14` marking and the symbol suggest a five-port, two-position valve with
  two pilots. The part number format and the brand fragment suggest **Numatics**, possibly the
  Mark 3 series, but this is the least certain identification in this document and the one
  most worth confirming.

### The drum-head fitting

- **Read.** A brass or bronze valve body is threaded into a flanged port in the drum head. A
  braided reinforced hose arrives at it, secured with a worm-drive clamp. A small galvanised
  elbow leaves it downward into a chromed fitting, then into a two-port manifold from which
  two cream-coloured plastic tubes run away, retained by a bent-wire spring clip. One tube is
  printed `MADE IN ITALY`.
- **Read.** Significant rust staining around the flange and along the drum seam. A roller
  chain runs past below.
- **Inferred.** This is the rotary union or air valve assembly at the drum axis, through which
  the membrane is inflated and vented, with the two small tubes as pilot lines.

### The variable frequency drives

- **Read.** Two drives, brand `MOLLOM`. Both displays show `60.00` on the upper line and
  `0.00` on the lower. Indicator row: `RUN`, `REV`, `LO/RE`, `TUNE/TC`, `Hz`, `A`, `V`, with
  `LO/RE`, `TUNE/TC` and `Hz` lit. Keys: `PRG`, `ENTER`, `RUN` (green), `MF.K`, up and down
  arrows, `SHIFT`, `STOP/RST` (red), and a rotary potentiometer. A warning triangle and a
  ten-minute discharge-wait symbol on the lower case.
- **Read, and the most important line in this document.** A printed label on the first drive:

  > `FOR 3 PHASE POWER ONLY`
  > `OUTPUT (UVW) MOVED TO`
  > `INPUT (RST) KF ON 10/7/23`

- **Read.** The second drive is wired with black `SOUTHWIRE` 12 AWG three-conductor cable, red
  wire nuts, a green earth, and a cream cable.
- **Inferred.** The two drives are the three-phase conversion the winemaker described. The
  label records a non-standard rewire: a VFD's output terminals are normally `U`, `V`, `W` and
  its supply terminals `R`, `S`, `T`, and this says those were swapped by somebody with the
  initials KF on 7 October 2023.

---

## What to find

### 1. Which press this is

Identify the Enoveneta model. The winery calls it a 1.2 tonne membrane press. Enoveneta's
range, current and discontinued, includes closed and open pneumatic presses under several
series names. Say which model this control panel and drum belong to, what capacity it is
actually rated at, and roughly what years it was built. If the panel was fitted to more than
one model, say so rather than guessing.

### 2. The documentation

Find and cite, with URLs:

- The operator's manual for that model, in English if it exists and Italian if it does not.
- The spare parts catalogue or exploded diagram.
- The pneumatic circuit diagram.
- The electrical schematic and wiring diagram.
- Any service bulletin, and anything about membrane replacement in particular.
- Enoveneta's current parts contact, and any independent supplier of parts for these presses
  in the United States, Oregon specifically if such a thing exists.

Say plainly what you could not find. A gap named is worth more than a plausible substitute.

### 3. The decomposition

Produce the parts tree. Cover at least:

- **The drum and press body.** Shell, heads, the drum bearings, the drive ring or sprocket,
  the roller chain, the drive motor and gearbox, the juice tray or pan, the drainage channels
  or internal drain members, the doors and their seals.
- **The membrane and its air path.** The membrane itself with its part number and material,
  the rotary union, the directional valve, the blower or compressor, pressure sensors, relief
  valves, the pilot lines.
- **The control system.** The panel, its display, the controller or PLC behind it, the
  keypad, the emergency stop circuit, the position or rotation sensors, the program storage.
- **The electrical supply.** The motor, its contactors, overloads, the drives, the isolator.

For each part give: a name, its parent part, its domain, a manufacturer part number if one
exists, a quantity, whether it is a wear item and if so its expected life, and anything about
it worth knowing at 6am. Mark each entry read, inferred, or not found.

### 4. The three components photographed

Treat these as sub-investigations and give each a short section:

- **The directional valve.** Confirm or correct the manufacturer. Find the datasheet for
  `I34SA4002000020`. What is its function on a membrane press, what does it fail like, is it
  still available, and what is the modern equivalent if it is not. It is dated 10/99: say what
  that implies for availability.
- **The control panel.** Find the programming reference. What do `REVS` and `REP` do
  mechanically, what does `SERVICE` expose, and what is `TIMER 248` counting. Then the
  question that matters most: **how a program is created, edited, copied and, above all, got
  off the machine.** The winery writes its own programs and at least one of them exists
  nowhere but in this panel. Is there a serial port, a memory card, a backup menu, a service
  tool, a documented way to read the stored programs out? If the answer is that there is none,
  say so plainly, because that makes transcribing them by hand the only option and somebody
  should know that before the panel dies.
  Do not analyse the winery's own pressure curve or offer opinions about it. That is
  winemaking, it is theirs, and it is not what this document is for.
- **The MOLLOM drives.** Identify the actual model and find its manual. Then address the
  rewire label directly and carefully: what would moving the output terminals to the input
  mean on a drive of this type, under what circumstance would somebody do it, what does it
  imply about how this press is now powered, and what should somebody know before working on
  it. **Flag anything about it that is a safety matter.** Do not soften this section and do not
  speculate beyond what the label supports; if the label is ambiguous, say what the possible
  readings are and what evidence would distinguish them.

---

## How to answer

Write one document. Structure it as:

1. **What this machine is**, in a paragraph, for somebody who has never seen it.
2. **Identification**, with your confidence and what would confirm it.
3. **The parts tree**, as a nested list, each entry carrying name, domain, part number,
   quantity, wear item, and evidence marker.
4. **The three component investigations.**
5. **What to do about the drives**, if anything.
6. **Sources**, every one with a URL, and a list of what you looked for and could not find.

### Two rules about certainty

**Mark every claim.** `read` for something legible in a photograph, `confirmed` for something
you verified against a manufacturer document you cite, `inferred` for a reasonable conclusion,
`unknown` for a gap. The winery's own convention is that an agent writes `inferred` and never
`confirmed` on its own authority; an entry is `confirmed` only when a cited document says so.

**Distinguish the model from this one.** The parts tree describes a stock machine as
Enoveneta built it. The two drives, the rewire, the rust, and the `CHARDONNAY*1` program are
facts about this particular press and belong in a separate short section, not in the tree. The
program especially: it was written by the winemaker, and mistaking a user-entered press curve
for a manufacturer default would be the single most misleading error this document could
make.
Keeping those apart is the whole point of the exercise: the tree is the baseline, and this
press is the baseline plus what has happened to it.

---

## Where this lands

The output becomes rows in two tables in the winery's own system, which is why the shape
matters:

- `model_part` for the tree: model, parent part, name, domain, part number, quantity, spec,
  note.
- `machine_part_change` for the departures, each tied to a dated piece of work: the drives
  were added, on 2023-10-07, by KF.

Nothing about this prompt assumes the researcher has access to that system. Produce the
document and the tree; somebody else will type them in.
