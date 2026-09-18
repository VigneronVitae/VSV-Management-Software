-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The hot water pressure washer, as a model, a machine, its two
--           research reports, and seventy two parts."
-- Depends on: [supabase/migrations/0105_a_machine_is_a_departure_from_its_model.sql,
--              supabase/migrations/0112_a_machine_decomposes_into_parts.sql,
--              supabase/migrations/0119_a_machine_keeps_its_papers.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-4. Every part and both reports land as `inferred`. The
--                  only things anybody has actually seen are four plates.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- A hot water pressure washer bought used, which does not build pressure. The
-- winemaker put E-1 through two models and sent both answers back, which turned
-- a machine record into a test of the method.
--
-- **The tree below is Kimi's**, which was the better sourced of the two: its
-- citations are manufacturer documents and the Internet Archive's copy of All
-- American's own 2003 site, and it split its evidence markers per claim rather
-- than per sentence. Gemini's cited eBay, Facebook groups and a forum thread as
-- `confirmed`.
--
-- **Where they disagree the part carries both answers rather than a winner.**
-- The burner is the live one: Beckett ADC against Wayne MSR-DC, igniter part
-- numbers one digit apart, and neither is knowable because nobody photographed
-- the burner's plate. A record that picked one would look finished and be wrong
-- half the time.
--
-- **The contactor is the one place a disagreement is already settled**, and it
-- is worth reading the note on that part. One report read the plate as
-- `93265-2 CAMDEC` and marked it read. The other called it a `SAW-4201` and also
-- marked it read. The photograph says 93265-2. A fabricated part number wearing
-- the marker that means "I can see this" is the failure this whole apparatus
-- exists to catch, and it was caught by looking at the photograph.

-- ---------------------------------------------------------------------------
-- The kind of machine
-- ---------------------------------------------------------------------------

insert into term (kind, value, label, sort_order) values
  ('machine_kind', 'pressure_washer', 'Pressure washer', 60)
on conflict (kind, value) do nothing;

-- ---------------------------------------------------------------------------
-- The model and the machine
-- ---------------------------------------------------------------------------

insert into machine_model (make, model, kind_id, spec, note)
select
  'All American Cleaning Systems',
  'Premier Series hot water skid (PH family)',
  (select id from term where kind = 'machine_kind' and value = 'pressure_washer'),
  jsonb_build_object(
    'pump_gpm', 5.6, 'pump_psi', 3500, 'engine_hp', 18,
    'drive', 'belt', 'burner', '12 VDC oil fired', 'era', '1998-2000'),
  'Built in Glendale California before Alkota acquired the brand in 2000. The closest documented model code is PH5030VBOF, which is inferred rather than established: the surviving catalogue tables only start in 2003 and list the Vanguard Premier at 5.0 GPM / 3000 PSI.'
where not exists (
  select 1 from machine_model
   where make = 'All American Cleaning Systems'
     and model = 'Premier Series hot water skid (PH family)');

-- `machine` has no note column; what is known about this one goes in
-- `attributes`, which is where 0105 put everything that is not a key.
insert into machine (model_id, name, serial, acquired_at, attributes)
select
  mm.id,
  'Hot water pressure washer',
  null,
  date '2026-09-01',
  jsonb_build_object(
    'note', 'Bought used. The machine data plate is missing or illegible, so there is no serial. Dated to about July 1999 from the hose reel serial 19990729.',
    'presenting_problem', 'Will not build pressure. Supply flow confirmed sufficient by bucket test 2026-09-19.',
    'plates_unread', jsonb_build_array(
      'engine Model/Type/Code, stamped in the valve cover',
      'burner label, silver, left rear of the burner housing',
      'unloader valve markings'))
from machine_model mm
where mm.make = 'All American Cleaning Systems'
  and mm.model = 'Premier Series hot water skid (PH family)'
  and not exists (select 1 from machine m where m.model_id = mm.id);

-- ---------------------------------------------------------------------------
-- The papers
-- ---------------------------------------------------------------------------

insert into machine_document (model_id, kind_id, title, source, url, body, at, provenance)
select
  mm.id,
  (select id from term where kind = 'document_kind' and value = 'report'),
  'E-1 machine record from photographs',
  'Kimi K2',
  null,
  $KIMI$# E-1 Machine Record — All American "Premier Series" hot-water pressure washer (skid)

**Compiled:** 2026-09-19 from eight photographs (113776–113785) plus external research.
**Evidence markers:** **[read]** = legible/visible in a photograph · **[confirmed]** = stated in a cited manufacturer document · **[inferred]** = reasonable conclusion, needs checking · **[unknown]** = looked for, not established.

> Where a photograph and any document disagree, the photograph is right. Where this document
> says `inferred`, somebody with the machine in front of them should turn the inference into a
> fact and correct the record.

---

## 1. What this machine is

A skid-mounted, petrol-engine, hot-water high-pressure washer built around 1999 by **All American Cleaning Systems** of California (the yellow "ALL AMERICAN — *The Best Under Pressure*" frame label) **[read]**, a brand absorbed by Alkota Cleaning Systems in 2000 **[confirmed]**. It is the company's **Premier Series**: a belt-drive triplex-pump, oil-fired hot-water skid in a tubular steel frame **[confirmed series definition; inferred application to this unit]**. A Vanguard 18 HP V-Twin engine drives a General Pump TS2021 triplex plunger pump (5.6 GPM / 3500 PSI class) **[read + confirmed specs]**; pressurized water passes through a diesel-fired heating coil in the large vertical black canister and out through a Coxreels 112-3-150 hand-crank hose reel carrying a red high-pressure hose **[read]**. The burner and engine starter run from two 12 V batteries carried low in the frame, charged by the engine's alternator **[read + inferred]**. In plain terms: a machine that turns cold water and diesel into a 3500-PSI jet of near-boiling water, built for somebody who cleans heavy equipment, not cars.

---

## 2. Identification

| Field | Value | Evidence |
|---|---|---|
| Brand | ALL AMERICAN — "The Best Under Pressure" | **[read]** frame label (113778) |
| Manufacturer | All American Cleaning Systems (founded 1985 as Aries Supply & Equipment, Glendale CA; acquired by Alkota Cleaning Systems 2000, moved to Alcester SD) | **[confirmed]** [S2][S3] |
| Series | Premier Series (belt-drive hot-water skid, 1¼″ tubular frame, vertical coil, 12 VDC burner) | **[confirmed]** series exists and matches layout [S7][S8][S9]; **[inferred]** this unit belongs to it |
| Model | PH…VB… family; closest documented model **PH5030VBOF** (5.0 GPM / 3000 PSI, Vanguard, 12 VDC, oil-fired) | **[inferred]** — exact 1999-era model code not recoverable from photos or surviving catalogs [S8][S9] |
| Rating | 3500 PSI / 5.6 GPM **maximum** (pump limit); factory badge likely 3000–3500 PSI / 4.5–5.6 GPM | **[confirmed]** pump max [S26][P1]; **[inferred]** badge rating |
| Year | c. 1999 | **[inferred]** from Coxreels serial "19990729" (1999-07-29) and component vintage |
| Engine | Briggs & Stratton Vanguard 18 HP V-Twin, 570 cc, model series 350447 or 356447 | **[read]** livery/decals; **[confirmed]** family specs [V3][V4]; exact Model/Type/Code **[unknown]** |
| Pump | General Pump TS2021 ("T Series 47 S"), 24 mm solid shaft | **[read]** sticker; **[confirmed]** specs [P1][P3] |
| Burner | 12 VDC oil-fired; leading candidate Beckett ADC (0.75–2.50 GPH, ≤6 GPM machines) | **[inferred]** — no burner plate legible in photos |
| Reel | Coxreels 112-3-150, serial 19990729 0799 | **[read]** tag; **[confirmed]** specs [C1] |

**Confidence:** brand HIGH (label read; brochure photographs show the same machine); series HIGH; exact model MEDIUM-to-unknown; year MEDIUM (single inferred date code).

**What would settle it, in order:**
1. The **machine data plate** (none is legible in any photograph **[unknown]**). All American plates carry model and serial; with that, Alkota can pull the build sheet.
2. The **engine Model/Type/Code** stamped into the OHV rocker (valve) cover **[confirmed location]** [V6] — the Code decodes the build date (first two digits = year; official example 99011556 = 15 Jan 1999) **[confirmed]** [V9].
3. The **silver Beckett label on the left rear of the burner housing** (ADC vs SDC, serial) **[confirmed location]** [B1].
4. The Coxreels serial confirmed by Coxreels customer service **[inferred format]** [C-contact].

---

## 3. The parts tree (stock article — this machine's departures are in §6)

Domains: mechanical · electrical · hydraulic · pneumatic · control and software · consumable · structural. "Wear" = wear item (expected life where documented).

```
ALL AMERICAN Premier Series hot-water skid (PH…VB… family) — baseline
│
├── 1. STRUCTURE [structural]
│   ├── 1.1 Tubular steel skid frame, 1¼″ tube — qty 1 — All American — [confirmed, S8]
│   ├── 1.2 Outer panels (stainless on documented Premier units) — qty set — [confirmed, S8]
│   ├── 1.3 Top equipment rack, expanded metal — qty 1 — [read]
│   ├── 1.4 Belt guard — qty 1 — [inferred; not verifiable in photos — see §6 safety]
│   └── 1.5 Mounting feet / fork points — [inferred]
│
├── 2. PRIME MOVER — Vanguard 18 HP V-Twin (350447/356447 family) [mechanical]
│   ├── 2.1 Engine short block, 570 cc OHV V-twin, horizontal shaft 1″×3″ — qty 1 — [confirmed, V3/V4]
│   ├── 2.2 Carburetor, Nikki float type — B&S 846109 — qty 1 — WEAR — [confirmed, V-wear]
│   ├── 2.3 Air filter cartridge — B&S 394018S (later 692519) — qty 1 — WEAR (inspect 100 h) — [confirmed]
│   ├── 2.4 Pre-cleaner, foam — B&S 272490S (later 692520) — qty 1 — WEAR — [confirmed]
│   ├── 2.5 Oil filter, spin-on — B&S 492932S — qty 1 — WEAR (every oil change) — [confirmed]
│   ├── 2.6 Spark plugs — Champion RC12YC / B&S 491055S, gap 0.030″ — qty 2 — WEAR — [confirmed]
│   ├── 2.7 Fuel filter, in-line — B&S 691035 — qty 1 — WEAR — [confirmed]
│   ├── 2.8 Fuel pump, pulse diaphragm — B&S 808656 — qty 1 — WEAR — [confirmed]
│   ├── 2.9 Starter motor, 12 V — B&S 497596/498148 family — qty 1 — [confirmed]
│   ├── 2.10 Starter solenoid — B&S 691656 — qty 1 — WEAR — [confirmed stock part; NOT what is fitted — §6 D-1]
│   ├── 2.11 Charging system, regulated alternator, 16 A (pump-OEM types; 5/9/20 A exist) — qty 1 — [confirmed option set, V4/V5; fitted rating unknown until Model/Type read]
│   ├── 2.12 Muffler/exhaust — qty 1 — [read, heavily rusted]
│   └── 2.13 Engine fuel (petrol) tank — see 8.1
│
├── 3. DRIVE [mechanical]
│   ├── 3.1 Engine pulley — qty 1 — [inferred]
│   ├── 3.2 Pump pulley — qty 1 — [inferred]
│   ├── 3.3 Drive belt(s), matched set — WEAR (~1000 h typical, condition-based) — [inferred; Premier is belt-drive, confirmed S8]
│   └── 3.4 Belt tensioning provision (slotted engine base) — [inferred]
│
├── 4. PUMP — General Pump TS2021, T Series 47 S [hydraulic + mechanical]
│   │   5.6 GPM @ 3500 PSI @ 1450 RPM (4.5 GPM @ 1125); 24 mm solid shaft; oil SAE 30 ND, 37.2 oz — [confirmed, P1/P3]
│   ├── 4.1 Manifold, nickel-plated forged brass — GP 47120941 — qty 1 — [confirmed, P1]
│   ├── 4.2 Valve assemblies, stainless, inlet+discharge identical — GP 36703201 — qty 6 — WEAR — [confirmed]
│   │       └ serviced by Kit 1 (K01) valve kit
│   ├── 4.3 Ceramic plungers, 20 mm — GP 47040409 — qty 3 — WEAR (crack from cavitation) — [confirmed]
│   ├── 4.4 Packing/seal stacks — Kit 28 (K28, w/ brass) ×3 or Kit 69 (K69, seals only) — WEAR, condition-based — [confirmed]
│   ├── 4.5 Piston-rod oil seals — Kit 2 (K02, 3× 90162500) — WEAR — [confirmed]
│   ├── 4.6 Crankshaft seal 30×55×7 — Kit 3 (K03, 90164800) — WEAR — [confirmed]
│   ├── 4.7 Plunger bolt/hardware — Kit 6 (K06) — per cylinder — [confirmed]
│   ├── 4.8 Crankcase, die-cast aluminium — GP 47010522 — qty 1 — [confirmed]
│   ├── 4.9 Crankshaft (16 mm stroke) — GP 47021735 — qty 1 — [confirmed]
│   ├── 4.10 Connecting rods — GP 47030001 — qty 3 — [confirmed]
│   ├── 4.11 Tapered roller bearings — GP 640047 — qty 2 — WEAR (long life; belt over-tension kills) — [confirmed]
│   ├── 4.12 Oil dipstick 98210600 / sight glass 97596800 — qty 1 ea — [confirmed]
│   └── 4.13 Crankcase oil, SAE 30 non-detergent (GP Series 100) — 37.2 oz — CONSUMABLE (50-h break-in, then 3 mo/500 h) — [confirmed, P6/P7]
│
├── 5. HIGH-PRESSURE WATER PATH [hydraulic]
│   ├── 5.1 Inlet supply hose + strainer/filter — qty 1 — WEAR — [inferred]
│   ├── 5.2 Trapped-pressure unloader valve, brass — qty 1 — WEAR (seals/seat) — [read; make/part unknown]
│   ├── 5.3 Bypass hose (unloader → inlet) — qty 1 — [read]
│   ├── 5.4 Pressure relief (safety pop-off) valve, factory-set — qty 1 — SAFETY — [inferred present; UL 1776 class requirement, B31/B33 — not identifiable in photos, unknown]
│   ├── 5.5 Heating coil — see 7.1
│   ├── 5.6 Discharge plumbing to reel — [read]
│   ├── 5.7 High-pressure hose, 3/8″ wire-braid — qty 1 (reel capacity 150 ft) — WEAR/CONSUMABLE — [read: red hose on reel; current hose is a replacement, §6 D-4]
│   ├── 5.8 Quick-connect fittings — qty set — WEAR — [read]
│   └── 5.9 Trigger gun, lance and nozzle(s) — qty 1 set — nozzle WEAR — [read: wand on rack; gun make unknown]
│
├── 6. HEAT — oil-fired burner system [hydraulic + electrical + consumable]
│   ├── 6.1 Heating coil, ½″ Schedule-80 spiral pipe (ASTM A53 class), vertical — qty 1 — WEAR (scale; descale 1–2 yr) — [read housing; construction confirmed for class, B20/B21]
│   ├── 6.2 Coil insulation, ceramic blanket — qty 1 — [inferred]
│   ├── 6.3 Coil shell + flue stack — qty 1 — [read; sooted — §6 D-6]
│   ├── 6.4 Burner, 12 VDC oil (leading candidate Beckett ADC) — qty 1 — [inferred, ~85% — §5.4]
│   │   ├── 6.4.1 Burner motor kit — Beckett 52145U — WEAR — [confirmed for ADC, B1]
│   │   ├── 6.4.2 Fuel pump (Suntec A2VA-7116 era / CleanCut PF20372U current) — qty 1 — [confirmed for ADC]
│   │   ├── 6.4.3 Fuel solenoid — pump coil 3713823U or in-line KIP 12 V valve — qty 1 — WEAR — [confirmed arrangements, B1/B16]
│   │   ├── 6.4.4 Ignitor, 12 VDC — current 5270005U (legacy 5049/7435U → 232105) — qty 1 — WEAR — [confirmed]
│   │   ├── 6.4.5 Electrodes — Beckett 578731 — qty 1 set — WEAR (every tune-up) — [confirmed]
│   │   ├── 6.4.6 Nozzle, 0.40–2.50 GPH class — qty 1 — CONSUMABLE (every tune-up) — [confirmed]
│   │   ├── 6.4.7 Blower wheel 2999U / coupling 2140501U / air shutter — [confirmed for ADC]
│   │   └── 6.4.8 Cad cell 7006U (if interrupted-duty control fitted) — [confirmed option]
│   ├── 6.5 Fuel (diesel) tank + cap — qty 1 — [read: yellow plastic tank — §6 D-3 departure]
│   ├── 6.6 Fuel filter / water separator — qty 1 — WEAR/CONSUMABLE — [inferred]
│   └── 6.7 Burner fuel lines + fittings — [read]
│
├── 7. CONTROL & SAFETY [control and software + electrical + hydraulic]
│   ├── 7.1 Adjustable thermostat (coil outlet) — qty 1 — [confirmed Premier feature, S8; not identifiable in photos, unknown on unit]
│   ├── 7.2 High-limit switch (~200–230 °F class) — qty 1 — SAFETY — [inferred; unknown on unit]
│   ├── 7.3 Flow/pressure switch (burner proof-of-flow, plumbed after unloader) — qty 1 — SAFETY — [inferred; unknown on unit]
│   ├── 7.4 Burner primary control (GeniSys 7556 on current ADC; older units constant-duty relay logic) — [confirmed options, B15; unknown on unit]
│   ├── 7.5 Burner motor contactor, 12 V continuous-duty — stock unit unknown — [read: Camdec 93265-2 fitted — §6 D-1]
│   ├── 7.6 Control switches/lamps on rear panel — [read: orange panel; contents unknown]
│   └── 7.7 Wiring harness, fusing — [read; condition poor — §6 safety]
│
├── 8. ELECTRICAL SUPPLY [electrical]
│   ├── 8.1 Batteries, 12 V — qty 2 (parallel, inferred) — WEAR (3–5 yr) — [read: mismatched pair — §6 D-2]
│   ├── 8.2 Battery cables/terminals — [read: corroded]
│   └── 8.3 Engine charging circuit (2.11) — [confirmed family]
│
└── 9. HOSE STORAGE [mechanical + hydraulic]
    ├── 9.1 Coxreels 112-3-150 hand-crank reel (4000 PSI, 150 ft × 3/8″) — qty 1 — [read tag; confirmed C1]
    ├── 9.2 Swivel, brass 90°, 3/8″ NPT, nitrile seals — Coxreels 1935 — qty 1 — WEAR — [confirmed, C3]
    ├── 9.3 Swivel seal kit — 1935-SEALKIT — WEAR — [confirmed]
    ├── 9.4 Bearings/bushings — 6328-1-1 (plumbing), 6329-1-1 (crank) — WEAR — [confirmed]
    ├── 9.5 Drum 7118-1-12.5 / frame 6304-1-12.5 / crank 7272-1 — [confirmed]
    └── 9.6 Drag brake — qty 1 — [confirmed feature, C1]
```

**Six-in-the-morning notes:** pump oil is **non-detergent SAE 30 only** (detergent oil emulsifies and kills the pump) **[confirmed, P6]**; never run the burner without water flow — the coil can flash to steam in seconds and rupture **[confirmed class hazard, B27/B28]**; never run >~6 min in bypass **[confirmed, B32]**; diesel/kerosene only in the burner tank — never petrol **[confirmed, B1]**; the yellow dipstick cap is the pump oil check (fill to the sight-glass dot) **[confirmed, P7]**.

---

## 4. Reference images vs. the owner's photographs

| Component | Manufacturer reference image | Match? | Notes |
|---|---|---|---|
| Whole machine | Premier Series brochure photos, Bulletin #305-2010: https://www.alkotadealer.com/wp-content/uploads/2019/05/All-American-Premier-Series.pdf [S9] | **Match (layout)** | Same arrangement: vertical coil canister beside red Vanguard engine on open tubular skid. Brochure panels are stainless; this unit's are painted — era or departure, see §6 D-5 **[inferred]** |
| Pump | Official GP catalogue photo: https://www.generalpump.com/wp-content/uploads/2017/10/TS2021-Updated-2023.jpg [P3] | **Match** | Black crankcase, nickel manifold, three valve caps, yellow dipstick — same article. No evidence of pump substitution; the 1990s sticker livery is period-correct |
| Engine | Era-correct red/black 350447 photo: https://www.engine-specs.net/briggs-and-stratton/350447.html · official current 18 HP page: https://www.vanguardpower.com/en-us/products/18hp-hs [V12][V3] | **Match (family)** | Red blower housing + black cover matches 1990s production; current Vanguard is black-liveried (cosmetic difference only) |
| Hose reel | Official Coxreels images (series page states "Model Shown: 112-3-150"): https://www.coxreels.com/uimages/categories/hand-crank-reels/series/100-series/gallery/hand-crank-reels-100-series-001.jpg [C1] | **Match** | Blue CPC powder coat, hand crank, 12″ discs, brass swivel — same article |
| Burner | Official Beckett ADC photo: https://www.beckettcorp.com/wp-content/uploads/2022/05/Beckett-ADC-Oil-Burner-min-600x600.jpg [B8] | **Cannot be compared** | The burner itself is barely visible in the owner's photos (only edges under the coil). **No usable reference comparison possible until the burner is photographed directly** — this is a documentation gap, flagged deliberately |
| Starter contactor | Trombetta 93265-series cross-reference listing (Camdec family equivalents) [B9][B11] | **Departure** | The fitted Camdec 93265-2 contactor is **not** the stock B&S 691656 starter solenoid — see §6 D-1 |
| Unloader valve | — | **No reference image found** | Make/model of the fitted brass unloader not identifiable; nobody can check this part by eye until it is photographed and its markings read **[unknown]** |
| Coil | Class-typical construction (Hotsy FAQ; replacement-coil listings) [B20][B22] | **Partial** | Shell/flue visible and consistent; coil internals not visible by definition |

---

## 5. Component investigations

### 5.1 Engine — Briggs & Stratton Vanguard 18 HP V-Twin (350447/356447 family)
- **What it does:** prime mover; belt-drives the pump and powers the 12 V system via its alternator.
- **Manufacturer/data:** Briggs & Stratton (Vanguard brand), 570 cc OHV V-twin, 18 gross HP @ 3600 rpm, 1″×3″ keyed shaft (typical), oil 1.5 qt w/ filter SAE 30 **[confirmed, V3/V4]**. **One nuance:** mid-1990s–2017 Vanguard V-Twins were built by the B&S–Daihatsu joint venture in Japan to B&S design — this late-90s engine is very likely Japanese-built, which is normal and not a departure **[confirmed, V33/V34]**. Exact Model/Type/Code is stamped into the valve cover — read it before ordering any part **[confirmed, V6]**.
- **How it fails:** Nikki carb jet clogging (surging/hunting — the #1 complaint); head-gasket failure pressurizing the crankcase (oil out the breather, dies hot); crank-seal leaks; fuel-pump diaphragm aging; starter drive/solenoid wear; 16 A stator/regulator failures **[confirmed, V-sources]**.
- **Availability:** family still in production; all wear parts stocked (§3 tree part numbers). Free repair manual mirror: https://mudbuddy.com/wp-content/uploads/2024/02/vanguard-repair-manual.pdf [V14]
- **Date code:** the Code in the valve-cover stamp gives the build date (YYMMDD + plant) **[confirmed, V9]** — read it; it cross-checks the machine's 1999 date.

### 5.2 Pump — General Pump TS2021 (T Series 47 S)
- **What it does:** triplex ceramic-plunger pump; the heart of the machine. 5.6 GPM @ 3500 PSI @ 1450 RPM **[confirmed, P1/P3]**.
- **Manufacturer/data:** General Pump (Interpump Group; European twin = Interpump WS202). Official data sheet + exploded diagram: https://www.harjo.ca/sites/default/files/2020-04/TS2021-Pump-1.pdf (also on generalpump.com product page); service instructions and oil spec URLs in Sources.
- **How it fails:** worn V-packings (water under manifold), fouled valves (pressure loss/pulsation), cracked ceramic plungers from cavitation (starved inlet), piston-rod oil-seal leaks (oil between crankcase and manifold), milky oil = water in crankcase (change immediately) **[confirmed, P7/P8]**. Torque specs for reassembly: head bolts 22.1 ft-lb, valve caps 95.9 ft-lb, plunger screws 14.7 ft-lb **[confirmed, P1]**.
- **Availability:** **still current production** (~$430–790 new; kits everywhere). ⚠️ Beware the "TS2021-**B**" — a re-badged lower-spec TS1021 not supported by GP **[confirmed, P26]**. Do not confuse with the TSF2021 (66-series, ~8 GPM) — kits do not interchange **[confirmed, P2]**.
- **Date code:** GP date codes are on the crankcase, not publicly documented **[unknown]**. The "OIL SAE 20/30" sticker is period livery; current spec is SAE 30 non-detergent **[confirmed, P6/P7]**.
- **This unit:** heavy dirt/oil film on the crankcase **[read]** — wash it and watch for active leaks; check oil for milkiness before running.

### 5.3 Hose reel — Coxreels 112-3-150 (serial 19990729 0799)
- **What it does:** stores 150 ft of 3/8″ HP hose; the swivel lets the hose stay pressurized while wound.
- **Manufacturer/data:** Coxreels, Tempe AZ (in business, family-owned). 4000 PSI working, hand crank, brass 90° full-flow swivel with nitrile seals **[confirmed, C1]**. Official manual (PM-003) and exploded drawing (EXP-40) URLs in Sources; official STEP CAD file exists for this exact model.
- **Serial decode:** "19990729 0799" → 29 July 1999 + unit 0799 is **inference** — no official format document found; Coxreels can confirm by phone **[inferred]**.
- **How it fails:** swivel O-ring weep (the verdigris and mineral crust visible on this unit's swivel is exactly that **[read + confirmed failure mode, C-PM003]**); swivel lock-up from an over-tightened inlet fitting ("hand tight plus ½ turn"); free-wheeling from a loose drag brake. This is a **hand-crank reel — no spring canister or latch exists** on it.
- **Availability:** model still current; swivel 1935, seal kit 1935-SEALKIT (~$10–25), bearings stocked by Grainger/Northern Tool/Zoro.
- **Tag anomaly:** the tag reads "MFG. SINCE **1937**" **[read, enhanced photo]** while Coxreels' official branding says founded **1923** **[confirmed, C-sources]**. The photograph wins — the tag says 1937 (legacy label art); noted so nobody "corrects" the transcription.

### 5.4 Burner — 12 VDC oil burner (leading candidate: Beckett ADC)
- **What it does:** fires diesel/kerosene into the base of the coil; heats the pressurized water to ~180–250 °F class.
- **Identification:** ~85% Beckett ADC (the era-standard 12 V burner for ≤6 GPM machines; still current production). The visible electrical hardware and the machine class fit; **but no burner plate is legible in the photographs, so this is [inferred], not confirmed.** Confirm by reading the silver Beckett label on the left rear of the burner housing, and the fuel-pump nameplate (Suntec A2VA-7116 = ADC; A2YA-7916 = SDC) **[confirmed identification method, B1/B4/B5]**.
- **How it fails:** sooting from low fuel-pump pressure / worn nozzle / misadjusted air / chronic low voltage (this unit's flue shows heavy soot **[read]** — the burner needs a tune-up before regular use); no-fire from ignitor/electrode/voltage faults; fuel-solenoid coil failure (test 15–25 Ω); after-drip smoke from a valve stuck open **[confirmed, B1/B4]**.
- **Availability:** ADC still current (~$750–975 complete); every wear part (motor 52145U, ignitor 5270005U, electrodes 578731, nozzles) in production.
- **Date code:** the Beckett label carries model + serial **[confirmed]**; unread here **[unknown]**.

### 5.5 Heating coil — vertical Schedule-80 spiral
- **What it does:** the pressure-rated heat exchanger inside the black canister; class-typical ½″ Sch-80 carbon-steel spiral, ceramic-insulated, 3000–4000 PSI class **[confirmed for class, B20–B22; exact rating unknown — check coil tag/data plate]**.
- **How it fails:** **scale** (hard water; #1 killer — burner runs, water stays cold, then the coil plugs solid), pinhole rupture (freeze, hot-spots, RO-water erosion), soot loading between wraps (this unit: soot evident at flue **[read]**), insulation degradation **[confirmed, B24–B26]**.
- **Service:** descale with inhibited coil cleaner (e.g., KO #110 Koil Kleen) circulated by an **auxiliary acid-proof pump — never the machine's own pump**; burner off; neutralize and flush **[confirmed, B26/B29]**. Annually at heavy use.
- **Safety:** after any no-flow/overheat event, let the coil cool fully before re-admitting water — trapped steam can burst it **[confirmed, B28]**.

### 5.6 Unloader valve — brass trapped-pressure type
- **What it does:** dumps pump outlet to bypass when the trigger is released; sets working pressure.
- **Identification:** **[unknown]** — brass body visible center-frame (113785), make unread. Photograph it and read its markings.
- **How it fails:** stuck = pressure switch stays made = **burner won't shut off** with gun closed **[confirmed, B18]**; over-tightened = over-pressurizes the coil; worn seat = pressure cycling. Never run >~6 min in bypass **[confirmed, B32]**.
- **Availability:** generic part; identify thread sizes and replace like-for-like once identified.

### 5.7 Electrical — batteries, contactor, charging
- Two 12 V batteries low in the frame, **mismatched brands/labels, corroded terminals [read]**. The burner draws ~15 A continuous (ADC class) and Beckett requires ≥18 A charging capacity **[confirmed, B1/B4]**; the engine family offers 5/9/16/20 A alternators and 16 A is the standard pump-OEM fit **[confirmed, V4/V5]** — **verify this engine's Type number**; a 5 A type will slowly flatten the batteries mid-job.
- The **Camdec 93265-2** contactor (label also carries a partially legible third line, "8910RS"/"99100B" — ambiguous; "MADE IN THE U.S.A.") **[read]** is an aftermarket continuous-duty 12 V relay (Trombetta 93265-series family) **[confirmed family, B9/B11]** mounted near the starter — functioning as the starter/burner power contactor **[inferred]**. Stock starter solenoid is B&S 691656 **[confirmed, V25]**.
- Field check: full-throttle battery voltage ~13.5–14.5 V = healthy charging **[confirmed method, V-notes]**.

---

## 6. Departures from stock, and the safety of them

| # | Departure | Evidence | Date | Safety relevance |
|---|---|---|---|---|
| D-1 | **Aftermarket Camdec 93265-2 contactor** fitted in place of stock B&S 691656 starter solenoid; non-stock bracket mounting | [read] label + mounting (113780); [confirmed] stock part differs [V25] | unknown | **Electrical** — continuous-duty relay is a legitimate substitute class, but the wiring around it is weathered; verify cable gauge, fusing and terminal condition before regular use |
| D-2 | **Mismatched battery pair** (different brands/labels), corroded terminals | [read] (113785 crop) | unknown | **Electrical** — a weak/mismatched parallel pair sags under the 15 A burner load; low voltage causes delayed ignition ("puff-back") — an explosion hazard inside the heat exchanger [confirmed hazard, B1]. Replace as a matched pair, clean terminals |
| D-3 | **Fuel/water tanks appear non-factory**: small yellow plastic diesel tank + translucent plastic tank inside frame; documented Premier units carried dual 18-gal factory tanks | [read] (113778); [confirmed] factory spec [S8] | unknown | Low — but confirm the diesel tank feeds only the burner and is vented/secured |
| D-4 | **Red high-pressure hose on reel** is a replacement-era hose; machine would have shipped with period hose | [read]; hose is a consumable, so replacement is expected — recorded for completeness | unknown | **Pressure** — verify the hose is 4000-PSI-class rated 3/8″ wire-braid; the reel is rated 4000 PSI [confirmed, C1] |
| D-5 | **Painted panels** (orange rear panel, cream frame label panel) where the documented Premier brochure shows stainless | [read] vs [confirmed, S9] | unknown | None — cosmetic/era difference; may simply be the pre-Alkota California build |
| D-6 | **Heavy soot in flue and coil stack** | [read] (113782) | — | **Burner safety** — not a modification, but a condition: soot = mistuned burner; a soot-loaded coil risks a soot fire and masks scale. Tune burner, then inspect coil, before regular use |
| D-7 | Swivel weepage (verdigris/mineral crust) on reel swivel | [read] (113779) | — | None immediate — maintenance item; 1935-SEALKIT |
| D-8 | **Belt guard not demonstrably present** in any photograph | [unknown] | — | **Guarding** — if the belt run is exposed, a guard must be refitted before use; have it checked |
| D-9 | Machine photographed sitting on a wooden pallet | [read] | — | Pallet is transport, not structure [inferred]; do not operate on the pallet |

**Safety statement (plain):** three safety devices cannot be verified from the photographs — the **pressure relief valve**, the **flow/pressure switch that proves water flow before the burner fires**, and the **high-limit switch** — and the burner electrics have been modified (D-1, D-2) while the burner itself is visibly sooting (D-6). **Before this machine is put back into service, a qualified pressure-washer technician should verify the presence and function of all three safety devices, load-test the burner supply voltage (11–16 V at the burner under load), and tune the burner.** This is the class of machine whose documented failure mode is a steam/heat-exchanger explosion when the flow-proof chain is defeated [B1][B27][B28]. Do not soften that: get it checked.

---

## 7. Email to the manufacturer (ready to send)

All American is supported today by its parent, **Alkota Cleaning Systems**. Address found on Alkota's official site (alkota.com/support) and corroborated by industry directory listings [S4][S24].

> **To:** info@alkota.com
> **Cc:** (legacy All American line: 800-541-7267; Alkota main: 800-255-6823 — follow up by phone if no reply in a week)
> **Subject:** Documentation request — All American Premier Series hot-water skid, c. 1999 (Vanguard 18 HP / 12 VDC burner)
>
> Hello,
>
> I own an **All American "Premier Series" skid-mounted hot-water pressure washer**, built before or around the 2000 Alkota acquisition (the hose reel on it carries a July 1999 build date, so the machine is likely California-era production). The machine data plate is no longer legible, so I cannot quote the machine serial; here is what I can identify:
>
> - Brand/series: ALL AMERICAN — "The Best Under Pressure", Premier Series skid (1¼″ tubular frame, vertical coil, 12 VDC oil-fired burner)
> - Engine: Briggs & Stratton Vanguard 18 HP V-Twin (570 cc family; I will supply the Model/Type/Code from the valve-cover stamp if useful)
> - Pump: General Pump TS2021 (5.6 GPM / 3500 PSI)
> - Hose reel: Coxreels 112-3-150, serial 19990729 0799
>
> Could you please supply, or point me to:
> 1. The operator's manual and any parts manual/exploded diagrams for this Premier Series configuration;
> 2. Electrical and burner-circuit schematics for the 12 VDC burner models;
> 3. The burner make/model you fitted on Vanguard-powered 12 V Premier skids in 1998–2000 (it appears to be a Beckett ADC — confirmation would be appreciated), plus the burner service documentation;
> 4. Price and lead time on the usual wear items for this machine: pump seal/valve kits, unloader rebuild kit, burner nozzle/electrodes/ignitor, coil descaling service parts, and the replacement heating coil itself.
>
> If legacy All American support is handled by a specific dealer, a referral is fine.
>
> Thank you,
> [Owner name, phone, shipping address]

*(No courtesy translation needed — Alkota is a US company.)*

---

## 8. Sources and what could not be found

### 8.1 Sources (all URLs)

**Machine / brand**
- [S2] Company history (archived 2003, allamericancleaningsystems.com): https://web.archive.org/web/20031204203111/http://allamericancleaningsystems.com/company/default.asp
- [S3] Alkota blog, "Faces of Alkota: Jeffrey K. Burros" (1985 founding, 2000 acquisition): https://alkota.com/resources/blog/faces-of-alkota-meet-jeffrey-k-burros/
- [S4] Cleaner Times manufacturers listing (All American at Alcester SD, 800-541-7267): https://www.cleanertimes.com/magazine/cleaner-times-articles-2/manufacturers-and-suppliers-listings-4/
- [S7] 2003 factory Premier Series model table: https://web.archive.org/web/20030504223704/http://www.allamericancleaningsystems.com/products/default.asp?ProductCategoryID=42
- [S8] PH5030VBOF model page (archived 2003): https://web.archive.org/web/20030517082529/http://www.allamericancleaningsystems.com/products/showProduct.asp?ProductID=3054
- [S9] Premier Series brochure, Bulletin #305-2010 (PDF): https://www.alkotadealer.com/wp-content/uploads/2019/05/All-American-Premier-Series.pdf
- [S24] Alkota support (current contact): https://alkota.com/support/ · dealer locator: https://alkota.com/distributors/
- [S26] TS2021 spec listing: https://powerwash.com/shop/general-pump-ts2021-pressure-washer-pump-3500-psi-5-6-gpm-1450-rpm-14-20-hp/

**Pump (General Pump TS2021)**
- [P1] Official data sheet + exploded diagram + torque chart (Ref 300204 Rev. M): https://www.harjo.ca/sites/default/files/2020-04/TS2021-Pump-1.pdf (also via generalpump.com product page)
- [P2] TSF Series 66 service instructions (the pump it is NOT): https://generalpump.com/PDFs/INSTALLATION%20&%20SERVICE/66%20TSF%20Series%20Service%20Instructions.pdf
- [P3] Official product page (5.6 GPM variant): https://www.generalpump.com/product/ts2021-2/ · (4.5 GPM variant): https://www.generalpump.com/product/ts2021/
- [P6] GP Oil Recommendations (SAE 30 non-detergent; 50-h break-in, 3 mo/500 h): https://www.generalpump.com/wp-content/uploads/2017/11/OilRecommend.pdf
- [P7] 47 Series Servicing Instructions (Ref 300030 Rev. C): https://www.generalpump.com/product/ts2021-2/?attachment_id=8604&download_file=5ade30d81def0
- [P8] GP Installation/Operation/Service Manual: https://generalpump.com/PDFs/TECHNICAL%20DATA/ServiceManual.pdf
- [P10] GP Repair Kit Selector: https://generalpump.com/wp-content/uploads/2017/11/Repair%20Kit%20Selector-PW.pdf
- [P26] TS2021-B warning (re-badged TS1021): http://www.pressurewasherauthority.com/item--pressure-washer-pumps--general-pump-ts2021b.html
- Suppliers: Kleen-Rite (kits + complete pumps), Power Wash Store, Canpump, powerwash.com (URLs in research file e1_pump_ts2021.md)

**Hose reel (Coxreels 112-3-150)**
- [C1] Official 100 Series page ("Model Shown: 112-3-150"; specs, 4000 PSI, 150 ft × 3/8″): https://www.coxreels.com/100-series_8_9.html
- [C2] Product manual PM-003 (PDF): https://www.coxreels.com/docs/categories/hand-crank-reels/100-series/product%20manual/hand-crank-reels-100-series-product-manual.pdf
- [C3] Exploded drawing + parts list EXP-40 Rev Q (swivel 1935, seal kit 1935-SEALKIT, bearings 6328-1-1/6329-1-1): https://www.coxreels.com/docs/categories/hand-crank-reels/100-series/exploded%20drawing/hand-crank-reels-100-series-exploded-drawing.pdf
- [C-contact] Coxreels, 5865 S. Ash Ave, Tempe AZ 85283; +1 480-820-6396 / 800-269-7335; info@coxreels.com

**Engine (Vanguard 18 HP V-Twin)**
- [V3] Official Vanguard 18 HP page (570 cc specs): https://www.vanguardpower.com/en-us/products/18hp-hs
- [V4] Official B&S store engine page (356447-0080-G1: 16 A charging, shaft, oil): https://shop.briggsandstratton.com/products/briggs-stratton-356447-0080-g1-18-hp-vanguard-engine
- [V6] Model/Type/Code location FAQ: https://www.briggsandstratton.com/en-us/support/faqs/engine-codes-model-numbers
- [V9] Build-date decoding FAQ: https://www.briggsandstratton.com/en-us/support/faqs/engine-manufacture-date
- [V10] Manual/IPL portal: https://www.vanguardpower.com/en-us/support/manuals · pre-2000 "99" trim trick: https://www.vanguardpower.com/en-ph/support/faqs/obtaining-ordering-parts-list-operators-manuals-literature
- [V14] Vanguard OHV V-Twin repair manual (mirror): https://mudbuddy.com/wp-content/uploads/2024/02/vanguard-repair-manual.pdf
- [V12] Era-correct 350447 photo/spec page: https://www.engine-specs.net/briggs-and-stratton/350447.html
- [V33] B&S–Daihatsu JV production history nuance (sources in research file e1_engine_vanguard.md)

**Burner / coil / safety**
- [B1] Beckett ADC & ADC-U 12 VDC burner manual (Form 6104B12ADC2): https://5476519.fs1.hubspotusercontent-na1.net/hubfs/5476519/2022/Manuals/PDFs/Burner%20Manuals/Residential%20Product%20Manuals/ADC-12v-Burner-Manual.pdf
- [B2] Beckett ADC product page: https://www.beckettcorp.com/product/adc-oil-burner-0-75-to-2-50-gph-dc-power/
- [B4] Envirospec burner tech notes (charging requirements, Suntec pumps, ADC vs SDC): https://envirospec.com/burners-burner-repair-parts/
- [B5] Beckett SDC chassis reference: https://patriot-supply.com/BECKETT-BPW601
- [B8] Official Beckett ADC photo: https://www.beckettcorp.com/wp-content/uploads/2022/05/Beckett-ADC-Oil-Burner-min-600x600.jpg
- [B9][B11] Camdec/Trombetta 93265-series contactor cross-references: https://www.texasindustrialelectric.com/relays.asp
- [B15] Beckett GeniSys 7556 control manual: https://falconrme.com/wp-content/uploads/2019/06/Beckett-Genesys-Primary-Controller-Manual.pdf
- [B18] Burner-won't-shut-off (unloader/fuel solenoid): https://www.mitm.com/support/videos/troubleshooting-burner-will-not-shut-off/
- [B20][B21][B22] Coil construction: https://www.hotsy.com/en/resources/media-library/faq.html · https://www.geyserequipment.com/equipment/pressure-washers/hot-water-pressure-washers/
- [B24][B26][B29] Coil failure/descaling: https://www.cleanertimes.com/magazine/cleaner-times-articles-2/coils-dos-and-donts/ · https://envirospec.com/burners-burner-repair-parts/burner-bible-for-pressure-washers/ · https://www.hotsyab.com/blog/how-keep-your-pressure-washer-coil-good-condition/
- [B27][B28] Safety chain (flow switch placement, hi-limit, coil explosion hazard): https://sunbritesupplymd.com/collections/switches · https://envirospec.com/burner-controls/
- [B31][B32][B33] Relief valve / bypass limits / UL 1776 components: https://powerjetpressure.com/wp-content/uploads/2025/06/PJW08OILFIREDMODULARWATERHEATER20250319.pdf · https://www.mitm.com/pdf/manuals/pressure-washers/hot/MiTMAllElectric4-061810.pdf · https://www.gatewaycleaningequipment.com/wp-content/uploads/2016/09/Safety_Brochure.pdf

### 8.2 Looked for and could NOT find
1. **The machine's own data plate** — no plate legible in the eight photographs; the machine serial and exact model code are unknown.
2. **Pre-2002 (California-era) All American catalogs, operator's manuals, or parts manuals** — the company's web presence only begins in 2002, after the Alkota acquisition; LA-era documentation does not appear to survive online. Alkota may hold it — hence the email.
3. **The exact 1999 Vanguard/12 V Premier model code** — surviving catalog tables (2003+) list the Vanguard Premier only at 5.0 GPM/3000 PSI.
4. **Burner make/model plate** — not legible; Beckett ADC identification remains inferred (~85%) until the burner label is read.
5. **Coxreels serial-number format documentation** — the 1999-07-29 date decode is inference; no official format statement found.
6. **General Pump crankcase date-code decoding** — not publicly documented.
7. **The unloader valve's make/model** — unreadable in photos; no reference image comparison possible.
8. **The exact Camdec 93265-2 datasheet** — identified by family only.
9. **Any handwritten/service marks on the machine** — none legible in the photographs.

---

*Research detail files (full citations, kit contents, additional suppliers): `/mnt/agents/output/research/e1_brand.md`, `e1_pump_ts2021.md`, `e1_reel_coxreels.md`, `e1_burner_coil.md`, `e1_engine_vanguard.md`, `e1_photo_observations.md`.*
$KIMI$,
  date '2026-09-19',
  'inferred'
from machine_model mm
where mm.make = 'All American Cleaning Systems'
  and mm.model = 'Premier Series hot water skid (PH family)'
  and not exists (
    select 1 from machine_document d where d.model_id = mm.id and d.source = 'Kimi K2');

insert into machine_document (model_id, kind_id, title, source, url, body, at, provenance)
select
  mm.id,
  (select id from term where kind = 'document_kind' and value = 'report'),
  'Documenting a machine from photographs',
  'Gemini 3 Pro',
  'https://share.gemini.google/TZwvTtaW71Dh',
  $GEM$t o a d f w b s a a s h f p i 
e t b p b i t b o a c t v a c 
h a s U m c v t s c i s 
m i a e t e i r t b d m b i 
e w a s p a w t c o h 
a o b i T s i d f e i d h 
Pressure W Skid 
ds p 8 a s a C h M c w 1 i i h b b t a si n 1 1 d c0 r ( 
mr T T p r A m a i hs fh r t i m a c t t r d i w b i 
PVeop cd o t i e 5 t r p s T u ph i w p f d a ci h bs a G o w P 
photographs: All American Hot W 
Sfiltw A m oA a cb f t sw bs r wr w u t aTs u m mpa o am i a e i iw f a B h ob c aA & S m oC m op p sV S mf t t 1t s apt asb tt a v 
(1Anos a bhc Tf lw sB pfa t U t rd m P(w cm m " r i iy i ( l Oa 1 d ba tpb u em p t i t as t r dA A s a t to t u p t s tP re tB wu o 
Documenting a machine from 
1.2. IdentificationWhat this machine is 
BCTTTT s cdem io m oi pmtt e so tif i p ts b v mA c A m e dl 1 1H Cr gi Ta eooh iaS fe oa 5 s vrG f /b 3 b t t P eC p op pi p s a " a 
sacelosyaaaaacccceeeggiiklllmnnnnnnnnnnoooooorrrsssttuyyy,-aaaaaabcccccccdddeeeeeeefffggggiiiiklllllllllllllmmnnnnnnnnnnnnnnnnnnnnnoooooppprrrsssssssssssssttttttuuvyyyzzzzaaaaaaaaacccccddddddddeeeeeeefffgggggiiilllmmnnnnnnnnnnnnnnnnoooooorrrsssssssssssttttuvvvxyyyyyyyyzf,,aaaaeeeeeeehhhhhhhhhhhhhhhhiiiiiiiiiiiilllooooooooooorrrrrrrrsssttuuuuy)aaaaaaaaaaeeeeeeeeeeeeeeeeeeehhhhhhhhhhhhhhiiiiiiiiiiiilllloooooorrrrrruuuu6aaeeeeeeeeeehhhhhiiiiiiiiiiilooorrsuyyeeiirDaaaadeeeeeeeeeeeeiiiiiiiiiiiiiiooprvyyr,,13GJPTaaaaaaaaaaabccccddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffiiiiiiiiiiiimmmmnnnnoopprrrrsttuuvyyyyyÏaaaaadeeeeeeeeghiioorstuuyy0A,,1ua,,,,,,,-.aaaaaaaaaaaaaaaaaaaaaccdeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeehhhhhhhhhhhhhiiiiiiiiiiiiiiiiiiiiiiiikkkklnnoooooooooooooooopppppqrrsssssssssssssssssttttttttttttttttttttttttttttttttttttttttuuuuuuuuuuuuuuuuuuuuuuyyyyyyyÏw,,-.9aacddeeehillllnnnnorrrrrrsttu,,,--...022589999999aaaaaaaaabcccccccddddddddddddddddeeeeeeeeeeeeeeeeefggggggghiiiiiiiiiiillllllllllllllmmmmmmmnnnnnnnnnnnnnnnnnnopppqrrrrrrrrrrrrrrrrrsssssssssssttttttttttttttttttttttuuuuuuuuvvvwyyÏ""',-----.......0000012223355799:EVVaaaaaaaaaaaaaaabbbbbbcccccccccccccccccccccdddddddddddddddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffffffffggggggggghhiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiikllllllllllllllllllllllllmmmmmmmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnoooooooppqqqqqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssssssssssssssssssttttttttttttttttttttttttttttuuuuuuuuuuuuuuuvvvwwwxxxxyyy),,,,---...0007789999aaaaaaaaaaaaaaaaacccccccccccddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffffffffgggggggggghhiiiiiiiiiiklllllllllllllllllllllllllllmmmmmmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnoooooooopppppppprrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssssssssssssssssttttttttttttttttttuuuuuuuuuuuvvwwxxxyyyyyaShhhhhhhhhh-MSlru2ABDDHIMOSeellllmmmmnrrtyyyIeln5Caaaaaahiinnnnoor)CPaaehhilooepFPPbbeiimpe)aaaaaaaaaaaaaabbbeeeeeeeeeeeeeeiimoooooooooopppssÏaeeppaittasherater
c 
ct cirtm s st c o a n t s s A m s a f r tt i Pr f lS t c m s a h c m c c 
SbmIdehm o wt s tp va mbp at e 1G2s c tD a a l bcPc ts v s Td ata A sn p cdo aiK ua n lf pb a sp f m td l o id t a p mr bf e t t s d h aw w 
3. The decomposition 
H t g t r d 
11114AADEHILMNNNPPQRSSTTUUWWbbdehmmnorsstuwyƱƱƱƱƱ PPc Aa COSSS C V ef N Fp F b (I P s i / r P / m6 B P C p M C G C tt d SL d A wh A I s o dm d Cf t u ti d mdu v ut S t ttbp mAiat c iiU1 A f l c P uD d lo ae t1 n o o tC p Ac Vs c B Cr d 3U t t 
sss-nnst.abceeefkkklnnnoootttvyy-.aaaaaaaabcccccccccddddeeeeeeeeeeffffgiiiikkklllllmnnnnnnnnnnnnnnooorrrrrrsstttttvyyaaaaaccccdddeeeeiiikkllnnnnnnnnnnnoooooorrrrrrssstttvys.,/aaaaaaaaaaaehhhhhhhhhhhiiiiiiiiilmooorsuuuuwy,,.///1:aaaaaaacccccdeeeeeeeeeeeeeehhhhhhhhhhhhhiiiiiiiiiiilllmnnnoooooopprrrrsssssstttuuwy/aaaaaacceeeeeeehhhhiiioooprrst/ah8acdeeeeeekmmnoooppt''25:aaaaaaaaaaaaacdeeeeeeeeeeeeeeefgiiiiiiiiiiimmmmmmmnnoooorssssssssstttttttttuvvy6aaddeeiilro'aaeeirttvyahoi,eaeo),,,,,-.::aaaaaaaaccdeeeeeeeeeeeeeeeeeeeehhhhhhhhhhhiiiiiiiiiiiiikkklnnnoooooooooooooooooooooooooppprssssssttttttttttttttttttttttttuuuuuuuuuuuuuwwyyyyy..48:aacdgilmmnnoqs',,---....125:aaaabccccccccddddddeeeeeeeeeeeeffgggggiiiiikllllllllmmmmmmnnnnnnnnnnnnnnnnnnnooooprrrrrrrrrrssssstttttttttttttttuuuy,--......./0122:::;Vaaaaaaaaaaaaaaaaaaaaabbbbcccccccccccccccdddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffgggggggggggggghhiiiiiiiiiiiiiiiiiiiiikklllllllllllllllllllllllllmmmmmmmmmmmmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnooooooopppppppppppppqqqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssssstttttttttttttttttttttttttttttttuuuuuuuuuuuuuuuuvvwwwwxxy--..00002234557aaaaaaaaabcccccccccdddddddddddddeeeeeeeeeeeeeeeeeeeeffffffffggggggiiiiiiiiiiiiillllllllllmmmmmmmmmmmnnnnnnnnnnnoooooprrrrrrrrrrrrrrrrrrrrrrrrrrrssssssstttttttttttttttttuuuuuuuuuuvwwwwyaSaaeeeghhlnrrrrsttuuivAe2Maaaaaaceehkklllllllmprrruvyyy.talntuanCaaeeehiiillnnnnooooouuuuCLRSaiiilnoceemotwneeptabbeeiips//aaaaaaaaaaaaaabbbbdeeeeeeeeeiooooppppsssuuaaabeeeeaaeoeee
011111111122222222222233468AABCCCCDDEIILMMMMNNNOPPPQRRSSSTUVVVVWWWWWWaabbcccccccccddeeeeffghhhhhhiiilmmmoppssvww s hPPP F cn C cS mN R w (((((I w e VAE p rp &oa tPr f t f f c / / 6i t 
..aaaaaccccccddddeeeeeeeeeeffgllllllllmmnnnnnnnnnnooorrrrrrssstttttttvy..-.001111111122355aaaeeeeeeeeeeeghhhiiiiiiilmooooorrrrrstttuyyy11112Taaaaccddddeeeeeeeiiiiiiiikmmmmmorrsssssstttttuyi)))))...aaaaaaceeeeeehhhhiiikllnoooooooooooopprrsssstttttttuuuyw",,,--..........................00000000000112233444445555566778888899999HHHHSSaaaaaaaaaaaaaaaaaaaaaaabbcccccccccddddddeeeeeeeeeeeeeeeeeeffffgggggggggggggiiiiiiiiiiiiiiiiiiikkklllllllllllllllllllmmmmmmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnooooooopppqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssstttttttttttttuuuuuuuuvvvwwxyyyaaaahiv-MaaaahinorrrrrttvPPPPaaaeeeehhhiiilnnooooouit.aaaaaabbeeeeeeeeeeeemooooseeeeeee
((11123333333333333446ACDEHHIKKLMNNNNNPPPPPPPPPPQSSSTTTTTUVVWWWWWabbbcccccccccfffhhhhhhmmmmmnnopppppppprrssttvvw o c FF 12 dC GGGGG DN t3K t ((((I K lo BC bI tU m ab P M I 2 r n a i / n /6 
-.abcccccccccdddddeeeeefffggiilnnnnnnooooprrrrssssttttttuuuvvvyyyz.-0000111111111112345aadeeeeeeeeeefffhhiiiiilooooorstttuyz1125PRZaaaaaaaaaaaaddeeeeeeeeeggiiilmmmmopqsssstttuyei,..o)))),......aaaaaaaaadeeeeeeeeeehhhhiiiikkkkkllnoooooorsssssssstttuuuuu)),,,,-............................/0000000000000000000111112222444778999WaaaaaaaaaaaaaaaabbccccccccdddddddddeeeeeeeeeeeeeeeeeeeffffgggggggghhiiiiiiiiiiiiiiikkkllllllllllllllllllllllllllllllmmmmmmmmmmmmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnoooooprrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssssssssssssstttttttttttuuuuuuuwwwxxyraSSXhillnr-.22AEIMaaaaeiiiilrrrtuuuuuvKaaehiiinnnoooooosueeeeet8aaaaabbeeeeeeeeeiimopppppppeeeee
111111233444444457AABCCDEEFGIILMNNNNOPPPPPPQSSSTUUWWWWWabcccddeffffhhhhiiimmmmnooppprssssssttuwwy bc TTTt bt B R C 11GH cN w p Gs h(((I ahw IOw iP t a c D b / 8 h / 6 
/abcccccdddeeeeeeeffgikllllllllmnnnnnnnnnnnooooprrrrrstttuyyyz000111122225aeeeeeeeeeeeeeeeeeffghhhiiiiikllnooorrstuuuy2357;Daaaaaaaadeeeeeeeeeegiiikmmmmmmnnnnnnooorrsssttumo,.1))).;Vaaaaaaccdeeeeeeeeeeeeeefhhhhhhiiiiikknnnoooprrsssssssstttttttuuyy,,-.........................0000000000112224788AUVVaaaaaaaaaaaaaaaabccccccccccddddddddddddeeeeeeeeeeeeeeeeeeeeeeffffggggggghiiiiiiiiiiiiiiiiiiiikkkkllllllllllllllllllllllmmmmmmmmmmmmnnnnnnnnnnnnnnnnooooopqqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssssssssttttttttttttttttuuuuuuuuvvwwwxyyyrceghhhiMRaaaccilrrrsuuuv-CCaaaaaeehnnnnooooooosueeiilt.Saaaabbbbeeeeeeiipppuaaeeee
111111113444445555555ABCCDDDDDDDEFFHHHHLMNNNNOPPPQRRSSSTUUUUVWWWWWaabbbcccccccdeeeeehhhhhiiiiilmmoprrsstttww cCCCCTbr C 1BCUf N P b o PR Rr((((I ctB t a m P a f rit t s / &&& /& 6 
aaacccccccdddeeeeeffgggiiiiillmmnnnnnnnooooooorrssttttuuvvvvvvy...00012222335aaaeeeeeeeeeeehiiiiiiilloooooorrrrrrrrrrsssttvwyyy-1112234Laaaaaaeeeeeeeeeeeeefiiiilmmmmmmnnnnnnoooooooprrsssstttyyyoy..1)))),...aaaaaaaacdeeeeeeeeeeeeeeefhhhiiklmnnnnooooooprrsssstttttttuu,,,,,,---.....................00000000000000001222455AVaaaaaaaaaaaaccccccccccddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeefffffffggggghhiiiiiiiiiiiikkkkkkllllllllllllllllllllllllllllllmmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnooooopprrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssttttttttttttttttttttuuuuuuuuuvwwwwwwwxxxxyyyyaahhlntuWAIMMSaaaaoruuuuvPaaaaaaaeeeeeeehiinnnnnnnnnoooooooooooruupt.aaabdeeeeeeeeiiooopp-eeeee
a o a h m a v o t p 
cp w a e e w t e u d s d a t s r b N s s 
fv c o ds c s s s s v t t c a ot t o s c g i o a th r o t 
Wt " t e a "m 2 e O d e h e o c s t c m r T ry 
ae p T pi t p o t a c a wf t t t s G v P r d r w 
dn d b c f m r s T p b h p ( a i c wt f t s T 
av m a i o t t c f d p p c a c f m h t aa f a h 
ei a ac b o a h t p s po c v ( b Va h c d K 
Udh h f m a s b c c T s T v s b i 
dems pa r fr l t a1 i iv d ic f t t p T fh t m 3 a ar e c f ba i s tv U a au m t U a t 
4. Reference images of the stock components 
11115555ABBCCDDDEEGILNNOPPQSSUWWWbcccceehhmmprrty l C r C CM N K o ((I C S P s& hr F fP / S1 &o / 6 t pT V H sT R o1 tP T mV o T Em ic t p M p tp r a d d a m d s 
slmosstu--aaabbccccddeeefggiillmnnnnnnnnnnnnoooorrrsttvyy"---aabcccccccdddddeeeeeeeeeeeeffffffgggiiiiilllllllmmnnnnnnnnnnnnnnnnnnoooopprrrssssssstttttuuuuuvvxyyzz.aacccdddeeeeefggggiiilmmnnnnnnnnnoooooorssssstttvvyyyyz.,,aaaaaeeeeeehhhhhhhhhhhhhhhhiiiiiiiiiiillmnnooooooooooooprrrsuuu,-/////013334:EPTTaaaaaaabceeeeeeeeeeeeeeeeeegghhhhhhhhhhhhhhhiiiiiiiiiillnoooooooooooooppprrrrrrrrssssttttttuuuwwyyyÏ,/aaaeeeehhhhiiiilootuuuuyyauyTaaccdeeeeeeeegiiiimoorei'11234OPSTaaaaaaaaaaaaaaaabbcccdeeeeeeeeeeeeeeeeeeeeeeeeeeeeeghiiiiiiiiiiikklmmmmmmmnoooppprrssssssttttttuuvyyyyaacddeeeeegiimouuySTaadeii,ht)),,,,,,,,,--...//:aaaaaaaaaaaaaaaaaaaaaaaacccceeeeeeeeeeeeeeeeeeeeeeeeeeeeeeehhhhhhhhhhhhhhhiiiiiiiiiiiiiiiiiiiiiikkkkkkkklllllnoooooooooooooooooppppprrrrsssssssttttttttttttttttttttttttttttttttttttttttttttuuuuuuuuuuwyyyit1wrw-.aceehillmrrssy,,--...0014aaaaaaaaaacccdddddddddddeeeeeeeeeeeeeeeeefffffgggggggggghhhhiillllllllmmmmmnnnnnnnnnnnnnnoooooooprrrrrrrrrrrrrrrrrrrsssssssssssssssttttttttttttttuuuuuuuvvwxyÏ",,-------..............//00000000011222235589:HKVaaaaaaaaaaaaaaaaaaaaabbbbccccccccccccccccdddddddddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeefffffffffgggggggggggghhhhhiiiiiiiiiiiiiiiiiiiiiiiiiijkkkklllllllllllllllllllllllllllllllllllmmmmmmmmmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnooooooooopppppprrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssssssssssssssssssssssttttttttttttttttttttttttttttttttuuuuuuuuuuuuvwwxxxxxxxxxxy),--....0122457:aaaaaaaaaaaaaacccccccccccccdddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffffggggggggghhhiiiiiiiiiiiiiiiiiiiiiklllllllllllllllllllllllllllllmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnoooooooppppprrrrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssstttttttttttttttuuuuuuuuvvvwwxyyyg:SSSaegghhhilmmnsssuxSehhhhhi-a-..2)222AADDDEELMPaaaaeinnttuuuvweuLVelCFLMPRaaeeehiiinnoooooooruwwwwyLRRehiiioe-eitHiaaeoaaaaaaaaaaaaaaaaaaabeeeeeeeeeeiioooppppppppsu/saaeepsppeeehat
ew pc a s a d l o i pS 6 a i h p c 
t mw t a w wa t sf br t a m s d a p f c s v i( 1 
bt is c o t c e f w s S S i 3 t w pn f i m o c t t V e g s ( r 2 Hw 
acet a s t i r 1t a it t a hm eac tti s wt r c bTc e tr s h c r h f p w h a t 3 s t o 
bci ab e t r T ui i 5 f m a t h t t t s cr t a o s tw T d 2 t f o s f1 b h c d w p pm i cc So l t 
bimp 9 da 3c a P c f r T N p ass s i i e mh 1 c ta m t i e i hot a g u T r f cv i t t i m p lp i m 
COaaas t p i a a tt ac b U oo es h mh s c C ao o 1 h cr s R o o pr i s i c r rt eo d dd ws r 5c ta s g ew e l ToA o mf otb p 
cdgiact i ag rmo paa t oie 5 t d aG ir iv s h v w l r m a c ( dd ks e"i Avm t c t r b 9 f t ttof e sSf a bo v pi t av t sG i r a P b 
5. Each photographed component, in its own right 
BG & P S T V 1 V 
CDThƱƱƱ AFF G 1 MMu P S T t TAT T 3c Rp i a ima S a po fc s v rotf oc 1t i i f t ff Tct a p Cmm c r iI p ts ui tp ts s d m wi t o 
saenntu/aaccccccddddeeeeeeggiilllllnnnnnnnooooprrrrsssssstttttuuuuuuvvvy,-aaaaacccccccccccddddddeeeeeeeeeeeeeeffffggiiiillllllllmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnoooooooorrrrrsssssssstttttttttuvvvyyz.aaaaaaaabbcccccccdddeeeeeeeeeeeefffggillllllllmmmmnnnnnnnnnnnnnnnnnnnnnnooooooorssssssstttttuuuuvvvyyyyyyyyyyzf,,,26aaaaaaaaceeeeeeeeeeefhhhhhhhhhhhhhhhhhhhhiiiillllmoooooooooooooorrrrrrrrssttttuuu,,,,/////116aaaaaaaaaaaccccdeeeeeeeeeeeeeeeeeeeehhhhhhhhhhhhhhhhhhhhhhiiiiiiiiiiiiiiiiiiiiiilllllllooooopprrrrrrrrrssstttttuuuuuwwwyyyy,4aaaacdeeeeeeeeehhhhhhiiiiiiiiooorrrrrrrsuehis,4Kaaaeeeeeeiiiiiiiiiimooprsssty'23Kaaaaaaaaaaaaaaacccdddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffggghiiiiiiiiiiiiiiiilmmmmmmmmmmmnnnnoooooooooooopsssssssstttyyy,aaaaaaaaddeeeeeegiilooosvygn--UeeFTortaadieksh),,,,,,---........::;_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaacccdeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeefhhhhhhhhhhhhhhhhhiiiiiiiiiiiiiiiiiiiiiiiiiiiiikkkkkklllllmoooooooooooooooooooooooooopppppppppprrrsssssssssssttttttttttttttttttttttttttttttttttttttuuuuuuuuuuwyyyye)-acddddeeghiilmnnnnrrsssttvw,,-...01258aaaaaaaaaaaabbbcccccccdddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeffffffgggggggggghiiiiiiiiiikllllllllllllllllllllllllllmmmmmmmmmmmnnnnnnnnnnnnnnnnnnnoooooooppppppqrrrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssssstttttttttttttttttuuuuuuuuvvvvwwxy ",,,------..../0000000000011222244445556789::::VW_aaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbcccccccccccccccdddddddddddddddddddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeefffffffgggggggggggggggghiiiiiiiiiiiiiiiiiiiikkllllllllllllllllllllllllllllllllllllllmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnoooooooooooppppppppppppqqqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssssssssssssssssssssssstttttttttttttttttttttttttttttttttttttttttttttuuuuuuuuuuuuuuuuuuvvvvvvvvwwxxxxxxxyyy),,,,-............023445788aaaaaaaaaaaaaaaaaabbccccccccccdddddddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeefffffffffgggggggggggghhhhhiiiiiiiiiiiiiiiiiiikllllllllllllllllllllllllllllllmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnooooopppppppppprrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssssssssstttttttttttttttttttuuuuuuuuuuuuuvvvvvvxxxxyyyyzzhhSSaaddeeehhhhhiilorrhhh-W..q22AACEIMMSTeiosttuiuwv0128lnnrrtH"aeiCLNPPPRaaadeeeehiiiowwwwaaeeehiiioSaeggmnsuePepa-aaeeeoop,//aaaaaaaaaaaaadeeeeeeeeeeeeeiiiiiiiilmoooooopppaeeemoppp2tudPr-eip
c f c 
p f a h s a i t h c a u 
L v c t b m t s b i 3 R s l t 
ia s a t m f o c1 a t r t d c b t v w d 
ol t o t 1 s t a i c m d b ir t V a g e p s c t 0 o 
dff t w hI tc r e o t di af s a nc p i oc l d sc a t e s A mow ic r o 
Ft ftb e r W t s ed t wi so ta 1aw t h D i (pa t h t P c w 8 w ha a f p t t l et d a 
hpssNegt c s r i to r w mE g m c Bo O ft 3 ta I Rit si J a p b st 1 u t u v r w 3d v P b f2 h fd w o u al wc c w u sr p f 
hitv(59r im #mt d c b m tm ft s i onw wa Vk b t a bsar s f tV t ho v ol t sTh ts w d u po b tt i t bc fa s2e o o " m e wa r tr s r f (Im wi d a h atso p t Tg a p t i a s i mt s t 8 
CUW M 1V 1 H O B R 
TTTcƱƱƱƱƱ AAFFF Wm b MMMM T v TWs p TTW rii at t tbd i ts tchs t ao io c3 m m r r tr sh apd o d t fo ia tosaut T c stmo t s1p o s b f t1 a r spo s 3 i tt iow srf rb fh ta ai uk u(t a 
ssaeillorty,.aaccddddeeeeeeefggggiiilllllnnnnnnnnooooooooorrrssssstttttuvvvvyyyaabcccccdddeeeeeeeeeeefgggggiiillllllllmmmnnnnnnnnnnnnnnnnnnnoooooooooooorrrrssssssssssssstttttttttuuvvyyyyyyyyzz,aabcccccccdeeeeeeeeeffffglllllllmnnnnnnnnnnnnoooooooorrrssssttttttttttuuvvyyyyzzf,,,,,08aaaaaaeeeeeeeeeehhhhhhhhhhhhhhhhhhhhhhhiiiiiiiiiiiiiillooooooooooorrrstuuyTaaaaaaaaaaeeeeeeeeeffhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhiiiiiiiiiiiiiiiiiillllllllllooooooooooorrrrrrrstttuuuuuuuuuuuu0aaaaaaaeeeeeeehhhhiiiiiiiiiiiooooorrttuaaeepPaaaaaceeeeeeeegiiimmmmnnooootyy'12DSTaaaaaaaaaaabbdddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeggiiiiikkkmmmmmmmmmmmnnnnooooooooprrrrstttuuvvyyyyyaaeeeeeeiinoooopttlosv0eeeF13D.,eniu,.Vaaaaaaaaaaaaaaaaaaaaccddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeefffhhhhhhhhhhhhhhhhhiiiiiiiiiiiiiiiiiiiiiiiiiikkkkllllllmmnnoooooooooooooooooooopppppppppppprssssssssssssssssssssttttttttttttttttttttttttttttttttuuuuuuuuuuuuuuwwwyyyyyyyzckw5aaaddeegghillmnrrrrrrttttttuw'),,,,..00000004577999Vaaaaaaaaabbccccccccccddddddddddddddddddeeeeeeeeeeeeeeeeeeffffffgggggggiiiiiiiiilllllllllllllllmmmmnnnnnnnnnnnnnnoopppppppqrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssssssssstttttttttttttttttuuuuuwwxy ,,,,,,-----.........000000022223445567899:::::KUVaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbcccccccccccccccdddddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffffffggggggggggggggggghhhiiiiiiiiiiiiiiiiiiiiiiiiiiiiijlllllllllllllllllllllllllllllllmmmmmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnoooooooooooppppppprrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssssssssssssssssssssssssssstttttttttttttttttttttttttuuuuuuuuuuuuuuuvvvvvwwwxxyyyyz",,,,,,----......./000012444555899aaaaaaaaaaaaaaaaaacccccccccccdddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeefffffggggggggggggggghhiiiiiiiiiiiiiiikkklllllllllllllllllllllllllllmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnoooooooopppprrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssssssssstttttttttttttttttttttuuuuuuuuuuvvwwxyyyyyyaah)aaadddeeehhhhhhhiirrruhh-1M)ADDEIILMPRSaeavv--0225Vdeeeelllnrryr;ahii)--CCMPaehhiiiiiosCPaaaaaaeiiiisaeeelrsx-aaeiiooSaaaaaaaaaaabeeeeeeeeeeeiiiiooooooooopppppuuuabeelRa-CenoouhhhiSa
o 
dt b l t b a s i f a w w N e b i i p 
eh at T m m p m b v l a o t a t a h q tt ma r 
Tw m v r t v e e s t o a p a p a s s i b rA q o f a 
ceu f T d t s a p t tg s 1 a o r d if a c t a t w g h p c m 
fgg e b c f T w m ai t p mw tn wo b f o s s u t o vi t s O a o cs ar i i 
ceos f T A s hp c O c i r b a u t m r m a t d at bp a f b t w t " b ao b 
hsvw s a s a t Vtt t e p ar rr v i ot p t h o p t r t c d h aws oe i b w t a c m i t t u s a a b t 
dloo as bm c a t e rp h ( i d eso t rv c 1dT 2 t o t ts rv g cw t s p o e a t h w 
diit v h Ta w h f i t n e tov bv s t m cm b Ts b ri g a i ie aht i pw t t s r c bI a e e t se 
bhhit s w ttb p VC p w s eo O m r3 sf aR d tr dt Wm t t mb s G o e Pws f d ur (c 1 e R T a 
aaeos f h (h tf c b h hU w1 a S t las h Ao ui tb S im cut V p ar r V pi f b ao pi a db t v t a m r lI t a d so d 
6. The departures, and the safety of them 
EMTUi v sD a a / O U G t r p S ( E p s R a sS WD m ( W (e t d e& a SF t hc S 5 U G md T rw 1 i f fi D p s a 
ssceglllnssst,,ccccdddeeeeeeeeffffiilllnnnnnnnoooooorrrsstuvyyyyaaaabbccccccccdddeeeeeeeffgggiiiikllllllllmmnnnnnnnnnnnnnnnnnnnooooorrrrssssssstttttuuuvvvyyyyyyyyyz--aaaabcccccdeeeeffggiiiiilllllllmmmnnnnnnnnnnnnnnnnooooooooorrrrsssstttvvyzzf.6Iaaaaaaadeeeeeeeeeeeeeffgghhhhhhhhhhhhhhhhhhiiiiiiiiiiiiiilllllnnnnnnooooooooorrrrrrrssssssstttuuuyyyyy-aaaaaaaaaaaacccccccceeeeeeeeeeeeeeeeeeeeeefffghhhhhhhhhhhhhhhhhhhiiiiiiiiiiiiiiiillllllllnnnnnnnnnooooooooooprrrrrrrrssssssstttttttuuuvvyyyIaaaaaccceeeeeeeeeeeffhhhhiiiiiiiimmnnoooooorrstuuuuwwyefht::aaabdeeeeeeeeefiiiiiimopprsstuvyyg,---:EGPaaaaaaaaaaaaaaaaaaabccdddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffgghhhhhhhiiiiiiiiiiiiiiiiiklllmmmmmnnnnooooooooooooooopprrrrrrrrsssstttuuuuyyyyyyyyÏu,,aceeeeeeeeeeeefhiiiiiimooptyybaadeeeeeeeeeeiiiuacddddeeeeeeeeeiiiiiiiimnoqaaaeeiiimeF,,,,),,,,--...aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaccccccccccdeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeehhhhhhhhhhhhhiiiiiiiiiiiiiiiiiiiikkkkllllllmnnooooooooopppppppppssssssssssssssssttttttttttttttttttttttttttttttuuuuuuuuuuuuuuuuuyyyyyÏ),0ddddddeeeegillllmnoprrsssssttttvv%',,,,--00;aaaaaaaaaaaabccccccccccccddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffffffgggghiiiiiiiiiiiiillllllllllllllllllmmmmmmnnnnnnnnnnnnnnnnopppqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssssssstttttttttttttttttttttttuuuuuuuuvvvwwxyz ',,,---......0066778aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbcccccccccccccccccccccccddddddddddddddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffffffffffffffggggggggghhhhhhhhhhiiiiiiiiiiiiiiiiiiijklllllllllllllllllllllllllllllllllllllllllllllmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnoooooooooopppppppppppqqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssssssssssssssssssssssssssttttttttttttttttttttttttttttttttttttttttttttttttttuuuuuuuuuuuuuuuuuuuvvvvvvvvvwwxyyyyyyzzz")))),,----....02455;aaaaaaaaaaaaaaaaaabbccccccddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeefffffffffffgggggggggghhhhhiiiiiiiiiiiiiiiiikkkklllllllllllllllllllllllllllllmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnoooooooppppppprrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssssssssssssttttttttttttttttttttttttttttttttttuuuuuuuuuuuuuuvvwxxxxyyyya-aacdeeeegghimnopprrssstttttuuw-.....aaaaaacccddddeeeeeeeeeeeeggggggghhhhhhhhhiiiiiiiiiilllllmmnnnnoooorrrrrrrrrrsssssssssttttuuuuuuuuuvyy,-..aaaccddddddeeeeeeeefggghhhhiiiiiiiilnnnooooooppprrrrsssssstttuuuuw--MMHIMMSaaaaeellruxMM-aeeiinALPaaaaaaeeeiinnnrCEPaaiiinoEPaei-SbiiuueeeemmoEaaaabdeeeeeeeeiiiioooppppppuAbeeeeopaeeimopu,-aaeeiouuubiaihis
e a d 
h c T i a s s d t m b r b h t 
f t r s h p l t b t v p t t s 
cw a w t y u h t P l ST m s ( w m e P c m f 
Ti m i m O s n t a p i ou a d mw bp t w s a t f a t 
Gb t P iT b f( G t a/ 3t Pb ta a Wo c M s u1 h b s v 
ae Ja m 1 I3 i e P p w a a s1 B r & S m V I i e V te b r a 
SWsy o Ahf ( S y a s p1 c t1 w wS s C u s B o o t bt o p e co r r m a T dt m W c bht m a a h w m 1 
7.8. SourcesThe email to the manufacturer 
123BCIIMTT[ƙƙƙƱƱƱƱƱƱƱƱƱƱ al t CGHRTThhhhhhhhhhi cr yT Nos y pP pP cpT [ 1S 1Ms mTa DS i Cl e ayBa a a Vd t( P l mDoI Ir vwf T t atS e T S sl fa RK Aa (aa s psT 2o p PCDd ( e ac a daR Ctw t Sto f a iif aV l L s1a Kd sA /A (o5 A hAt 1 G fb HsA l1 T 
sccgsyaccdeeeefffggkllllllllllnnnnnoorrssttuvvyyyy-----.aaaaaaaccccccccdddddeeeeeeeeefgggggggikkkkkkkllmmmnnnnnnnnnnnnnnnoooooppprrsssssssssstttttttttvyyy-aaabbccccdddddeeeeegggiiiklllllnnnnnnnnnnnnnnooooooooooooosssstttttvyy,...),---/2aaaaaaaaceeeeeeeghhhhhhhhhhhiiiiiiiiiiiilmooooooooorrrsssstuuy,.////////////////////////36AMOOaaaaaaaaaaaaaaaaaabccccccccccceeeeeeeeeeeeefghhhhhhhhhhhiiiiiiilllmmmmmnnnoooooooooooooopppppppppppppprrrrrsssssttttttttttttuuwwwwww/0:aaaaeeeghhhiiiiootuuuuciy.:DTaaeeiiilmy'-./1257:ACEKKLPSVaaaaaaaaaaaabccccddddddeeeeeeeeeeeeeeeeeeeeeeeefiiiiiiiiiiiiiiiiiklmmmmmmnnnooopppprrrrrrrssstttttttttttttuuuuwwwwy,.aaadeeeeinoqtau,..11eeo,,,----..../////:::::::::::Vaaaaaaaaaaaaaaaaaaccceeeeeeeeeeeeeeeeeeeeeeeeeefhhhhhhhhhhhhhhiiiiiiiiiiiiiiiiiiiiiikkkkkllnnoooooooooooooooooooooooooooooooooopppprsssssssssssssssttttttttttttttttttttttttttttttttuuuuuuuuuuuwyyyyyykow,?HVdeeeinnnrrrrstuw)+,,---.0008HHVV]aaaaaaaaaabbccccccccddddddddeeeeeeeeeeeeeeeeeeeefggggggggggggghiiiiiiiilllllllllmmmmmmmnnnnnnnnnnnnnoooooppprrrrrrrrrrrrrrrrsssssssssssssttttttttttttuuuuvvwwxy),,----................00000011222223555999999@VV]aaaaaaaaaaaaaaaaaaaaaaabbcccccccccccccccccccddddddddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffffgggggggggggggghhhhhiiiiiiiiiiiiiiiiiiiiikllllllllllllllllllllllllllllllllllllllllmmmmmmmmmmmmmmmmmmmmmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnoooooppppppppppqqqqqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssssssssssssssssssssssssssssssssttttttttttttttttttttttttttttttttttttttttttttuuuuuuuuuuuuuuuuuuuuuuvww)),,------.....///001223444457888889aaaaaaaaaaaaaabccccccddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffggggggggiiiiiiiiikkllllllllllllllllllmmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnoooopppqrrrrrrrrrrrrrrrrrrrrrrrssssssssssssssssssstttttttttttttttttttttttttttttttuuuuuuuuuuuuuuuvvvwxyyyyraa)h:SSbcghhhhhhijnrtuhh-o-.....Ol)122DDHIIMRSSaaaaaaeeeiiiikkkllllmmmrrttuuuuuymBM5PPaaaaeeiCCaaaaaeiiiiiinnnooooouwwwwwwwwww-CCPhiiiiiiloouPPeepwwF.eeepp/////////Saaaaaaaaaaaaaaaaabbbbbdeeeeeeeeeeeeeeeeiiiiimooooooppppsu.aaeosaaaa
-6ddffhhnnnt 
ƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱƱ hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh * 
e-cegggllnnptt---.aaaaabcceeeeeeeeeggggkkkkkkkklllllmnnnnnnnoooooooooppsssssssttttuuvy----------////aaaaacccddeeeeeeeeeikkllllmnnnnnnnnnnnnnnnnooopprrrrrstttttttuuvvv..--------./////0122223348AGMTaaabbccceeeeeefhhhhiiiiiimmmmoooooopppprrsssssssttuuuvy-//////////////////////////////////////////////////////////////////////////////1113378FOPTaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbcccccccccccccccccccccccccccccccccccccccdddeeeeeeeeefffffffggghhhhhhiiiiillmmmmmmmmnnnnooooooopppppppppppppppppppppppppppppppppppppppppppppqrrrrrrrsssssssstttttttttttttttttttttttttttttttttttttttttuuuwwwwwwwwwwwwwwwwwwwwwwwwwwwwyzz-/5aceehhhiiiprrrrvvi--Saceeehikllooppsstvv----------------------//0111112223347788AHPPaaaaaaaaaaaaaaabbbbbbbbccccccccdddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeefffggggghiiiiiiiiiiiiiiiiikkkmmmmmmmmmmmmnnnnoooooopppppppppppppppppppppprrrrrssssssssssssssssttttttttttttttttttuuuuuuvvvwwwwwwwygacceegostyyy....__%----------------------......................./////////////////////222288::::::::::::::::::::::::::::::::::aaaaaaaaaaaaaaabbccccddeeeeeeeeeeeeeeeeeeeeeehhhhhhhhhhhhhhiiiiiiiiiiiiiiikkkllllmmnooooooooooooooooooooooooooooooooooooooooooooooooooooooooooppprrrrrssssssssssssssstttttttttttttttuuuuuuuuuuuuuuwwwwxluu-----------------------...////0000444577789999aaaabbbcccdddddddeeeeeeeeeffiiiiiillllllmnnnnnnnnnnoopprrrrrrrrrrrrssssssssssssssttttuuuuy--------------...............///////000000000000111111122233333333334444455555666666667799999:::?_aaaaaaaaaaaaaaaabbbbbbbbbbccccccccccccdddddddddddddddddeeeeeeeeeeeeeeeeeefffgggggggggggggggghhiiiikkkklllllllllllllllllllllllllllllllllllllmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmnnnnnnnnnnnnnnnnnoooooooooooooppppppppppppprrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssstttttttttttttttttttttttttttttttttttttttttttttttttttttttuuuuuuuuuuuuuuuuuuuuvwwxxxxxxxyyz%%----------------------------------------..//////////000000000000011111111111111222222222222333344444444555555555555556666677777777777777778888888899999999BT____aaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbcccccccccccccdddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffffffggggggggggggggghiiiiiiiiiiiiiiiiiiiiiiiikkllllllllllllllmmmmmmmmmmmmnnnnnnnnnnnnnnnnnnnnnoooooooopppppppqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssssssssssttttttttttttttttttttuuuuuuuuuuuuuuuuuuuuuuxyrSisS.........................-12DPlmruerCPaaaaahi-Faeeiiipwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww_a3tpp.///////////////////////////////////Haaaaaaaaaaaaaaaaaceeeeeeeeeeeklllllmmppppppppppi222
V A M I C 
h 2 B V 
g s o a 1 B a S 
h 2 H i t 
R G - F 
h 2 V E 3 E 
Z G P K 2 C S P 
h 1 
T f t B P W f S a B 
h 1 9 E 
6 1 C P W P 7 B P T L 
h
P S a P 
h 1 G P T S 4 S T 
C D 6 1 , 2 t 4 V D P R a 
C H R - C h 1 R 
S h 1 1 S / H 
h 1 F M & P L - B & 
P W R & T h 1 T S 4 S 
h 1 A S | 
R Y P W P 
h 1 H t 
R - B & S 
h 9 S E V M & 
A p w m - B A O 
A - A O K h 8 
A M L - A h 7 P & 
P W h 6 
h 5 N Y M U M - A 
4 A A H W P W | L A & V 
R a M - P W M A h 
h 3 
Avw e t m s n 
h2mr a o a o t 1 D p b i a e o c n ob m f i f t tp2 p d 
W cited 
1WƱƱƱƱ hTThh cw em În gm b & fd m d w d s pd - cA d O t t K e i s n o t C f rf t 
ss?eekaaccceeeeikkkkllnnnnnorstvyy,-----aaaaaaacccccccddeeeeeeeeeeffgggggkkkkkklllllnnnnnnnnooooopprrrrrsssssstttttuv------./aaaaccddddeeeeeegggiikkllnnnnnnnnnnnnnnnnnnooooprrrssssssvv...,.,----./////////0011222233ALaaaaaaaaaaaaabcccceeeeeeefhhhhhhhhhilmmmoooppppppprssssttttuuvwy,,--./////////////////////////////////////////05AEPTWaaaaaaaaaaaaaaaaabbbbbbbccccccccccccccccccddeeeeeeeeeeefffggghhhhhhhiiiiiiimmmmnnooooooooopppppppppppppppppppppppppprrrrrrrrrsssttttttttttttttttttttttttttuuuvwwwwwwwwwwwwwwyz///////aaaaaaacceeghhhiiiiimnoopprsstuuw-1Saaacdeeeiiiimmotte'----------/02337AAABMOPPPPPSSTVaaaaaaaaaaaaabbcccccdddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeefggiiiiiiiiiiiiiiiiiiiikkllmmnnnoooooppppppppprrrssssssssstttttttttuuwwwwwwyy--06Maadeiiiiorsttuy,1/',,,,,,------............/////////////28::::::::::::::::::::::_aaaaaaaaaaaaabccdeeeeeeeeeeeeeeeeeeeeeeeeeehhhhhhhhhhhhhhhhiiiiiiiiiiiiiiikkkkknoooooooooooooooooooooooooooooooooooooooooooooppppprrrssssssssssssssssssssssssstttttttttttttttttttttttttuuuuuuuuuuuuuuuuuuuuwwxAAw...2abcceegggllmnnnprrrss,,,,-----------........//00005778aaaaaaaabbccccdddeeeeeeeefffggggggggggiiiiiilllllllllmmmmmmmnnnnnnnnnnnpprrrrrrrrrrrrrrsssssssssssstttttttttttttuuuuuuuuwxy,,,,,,-----------..............//000022333334445566788899:HKMVaaaaaaaaaaaaaaaaaaabbbbbbbccccccccccccccddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffgggggggggggiiiiiiiiiiikkkkkkllllllllllllllllllllllllllllllllmmmmmmmmmmmmmmmmmmmmmmmmmmmnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnooooooooooooooooooopppppppppppqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssttttttttttttttttttttttttttttttttttttttttttttttttttttttttttuuuuuuuuuuuuuuuuuuuuvvwwwxxxy,,,------------............./////////00000000000000111111111222222223334444444455555566667777777777778888999999:K_aaaaaaaaaaaaaaaaaaabbbbbccccccccdddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffffgggggghiiiiiiiiiiiiiikllllllllllllllllllllllllmmmmmmmmmmmnnnnnnnnnnnnnnnnnoooooooooopppppppppqqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssssssssssssssssssssssssttttttttttttttttttttuuuuuuuuuuuuuuuuuvwwwwxxxyyyyirrooAaaa:SXaadehhlnostuuIShi-oe..............FOSx,.2AAACDDLLNNOORSSSSaaaeeeeeeehiilllllllllmmmmmnnnooprrrrrrrrrrrrrrttttuuuuuuuu,,AReelnruT-Saaaaaeww--CCCCEFIPSaaaeeeeeeeiiiinooooooooppruwwwwwwwwwwwwwwwwwwwwwwwwaaeeeenooswwFewFRTeuTi/Saaap//////////////////aaaaaaaaaaaaaaaaaaabbbdeeeeeeeeeeiiiilmmoppppppppp//aaalpaaaaaaaaahorks
P 1 h 
h 3 w 
3 E P P a S G | P - S 
h 
t 3 O i p s g w g o H - X 
h
h 3 G P - T - R K & P 
P I S G 7 f T 8 
h 3 G 
T - F 
h 3 V 1 H E M 
B a S E 3 - P 
h 3 
1 3 s v d 1 r f c - A D C 
h
T B 
h 3 M 
P S a F 
h 2 T U V D 
C 4 S R K ( - Q 
h 2 
N O 1 - Z 
h 2 C S S K 3 
- 2 7 W 1 D O B A ( S 
h
C 2 S F T t C B - C T 
h
P S - R B C 
h 2 1 I - 
- 2 W M O B M - I 
h
semtydgggillnnnooopstvy-.aaaaabceeeeeeegggggiikkllllllllmnnnnnnnnnnnooooopprrssstttttuvvvvy------./aaaabceeeeeeeeeeegikkllllllmnnnnnnnnnnnnnooopprrrsttttttttuvv.,-----///022488AGGLMSTabbccceeeeehhhiiiiiimnooooppprrsssssssstuuy!-../////////////////////////////////////0122378FMOTWWaaaaaaabbbbccccccccccccccccccccdeeeeeeffffhhhhhiiiiiiillmmmnoooooppppppppppppppppppppppqqrrsssssstttttttttttttttttttttuuvwwwwwwwwwwwwwwyyz'-acciiiiinoprr,T/1DVabdeehkooppttv--------/1111111112233468BEHMMMOPPRSSaaaaaaaaaaaaabbbccdddeeeeeeeeeeeeeeeeeffggggghiiiiiiiiiikklmmmnnnnnoooooooooppppppppprrsssssssssssttttttttttuuvvwwwa,0Ecinnnoopssttuu....,.11111%),,,,,-----------------.........//////////2:::::::::::::::aaaaaaaaccceeeeeeeeeeeeeeeeeeehhhhhhhhhhhiiiiiiiiiiiiikklllmmnnnnooooooooooooooooooooooooppppprrrrssssssssssttttttttttttttuuuuuuuuwww...adegilmnprsss,,----------......//001222447889?VVaaaabcdddeeeeeeeeeggggiiiiiiillllllllllllmmnnnnnnnnooooopprrrrrrrrrrrrrrssssssttttuuuuuxy,,,----------................///0000000000011111111122233333444445555555556666777778899999999:::?GKaaaaaaaaaaaaabbbbccccccccccccccddddddddddddddddeeeeeeeeeeeeeeeeeeeeeefffgggggggggghhhiiiiiiiiiiiikkllllllllllllllmmmmmmmmmmmmmmmmmmmmmmmnnnnnnnnnnnnnnnnnoooooooopppppppppprrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsssssssssssssssssssssssssssssssssssstttttttttttttttttttttttttttttttttuuuuuuuvwxxxxxxyyyyyyz%%,,,-------------------------...//////////000000000111111112222222222222333344444444555555666777888899999:BFIT___aaaaaaaaaaaaaaaaabccccccccccdddddddeeeeeeeeeeeeeeeefffffgggggggggggggghhiiiiiiiiiiiiiiiikkklllllllllllllllmmmmmnnnnnnnnnnnnnnnnnnnnoooooooopppppprrrrrrrrrrrrrrrrrrrrrrrrrrrrrssssssssssssttttttttttttttuuuuuuuuuuuuuwirrriaaES4aaiio2SSho.............1Faei-11ADEEHILMPRRRRSTZaaaacdeeeehiinnoppprrrrstuuuuuuuww2DRiprCI-CFPahiw-.CEOTUaaeeiiiiiioopwwwwwwwwwwwwwwwwwwwwwwww-CCP_eeehhiilnoow3eei-DSiiltiuN,pS.////////////////EHSSaaaaaaceeeeeellopppppppHabep.222aaa
$GEM$,
  date '2026-09-19',
  'inferred'
from machine_model mm
where mm.make = 'All American Cleaning Systems'
  and mm.model = 'Premier Series hot water skid (PH family)'
  and not exists (
    select 1 from machine_document d where d.model_id = mm.id and d.source = 'Gemini 3 Pro');

-- ---------------------------------------------------------------------------
-- What it is made of
-- ---------------------------------------------------------------------------

create table _washer_part (
  key         text primary key,
  parent_key  text,
  name        text not null,
  domain      text,
  maker       text,
  part_number text,
  quantity    numeric,
  wear        boolean not null default false,
  wear_life   text,
  url         text,
  note        text,
  sort_order  int not null
);

insert into _washer_part
  (key, parent_key, name, domain, maker, part_number, quantity, wear, wear_life, url, note, sort_order)
values
  ('structure', null, 'Structure', 'structural', null, null, 1, false, null, null, 'Tubular steel skid, 1 1/4 inch tube. Built to be hard mounted; currently on a pallet for moving, which is transport and not a mount.', 10),
  ('frame', 'structure', 'Skid frame', 'structural', 'All American', null, 1, false, null, null, null, 20),
  ('panels', 'structure', 'Outer panels', 'structural', 'All American', null, null, false, null, null, 'Brochure Premier units show stainless; this one is painted. Era difference or a departure, unresolved.', 30),
  ('rack', 'structure', 'Top equipment rack, expanded metal', 'structural', null, null, 1, false, null, null, null, 40),
  ('beltguard', 'structure', 'Belt guard', 'structural', null, null, 1, false, null, null, 'Not demonstrably present in any photograph. If the belt run is open this must be refitted before the machine is used. Guarding.', 50),
  ('engine', null, 'Prime mover: Vanguard 18 HP V-Twin', 'mechanical', 'Briggs & Stratton', '350447 / 356447', 1, false, null, 'https://www.vanguardpower.com/en-us/products/18hp-hs', '570 cc OHV V-twin, 18 HP at 3600 rpm. Exact Model/Type/Code is stamped in the valve cover and has never been read. Read it before ordering anything.', 60),
  ('carb', 'engine', 'Carburettor, Nikki float type', 'mechanical', 'Briggs & Stratton', '846109', 1, true, 'condition', null, 'Jet clogging is the number one complaint on this engine: surging and hunting under load.', 70),
  ('aircart', 'engine', 'Air filter cartridge', 'consumable', 'Briggs & Stratton', '394018S (later 692519)', 1, true, 'inspect 100 h', null, 'Gemini''s report gives 393957S for this. Unresolved: check against the engine''s Type number.', 80),
  ('precleaner', 'engine', 'Pre-cleaner, foam', 'consumable', 'Briggs & Stratton', '272490S (later 692520)', 1, true, 'inspect 100 h', null, null, 90),
  ('oilfilter', 'engine', 'Oil filter, spin-on', 'consumable', 'Briggs & Stratton', '492932S', 1, true, 'every oil change', null, null, 100),
  ('plugs', 'engine', 'Spark plugs', 'consumable', 'Champion / Briggs & Stratton', 'RC12YC / 491055S', 2, true, 'condition', null, 'Gap 0.030 inch.', 110),
  ('fuelfilter', 'engine', 'Fuel filter, in-line', 'consumable', 'Briggs & Stratton', '691035', 1, true, 'condition', null, null, 120),
  ('fuelpump', 'engine', 'Fuel pump, pulse diaphragm', 'mechanical', 'Briggs & Stratton', '808656', 1, true, 'condition', null, null, 130),
  ('starter', 'engine', 'Starter motor, 12 V', 'electrical', 'Briggs & Stratton', '497596 / 498148 family', 1, false, null, null, null, 140),
  ('solenoid', 'engine', 'Starter solenoid (stock part)', 'electrical', 'Briggs & Stratton', '691656', 1, true, null, null, 'This is the stock part and it is NOT what is fitted. See the Camdec contactor under Control.', 150),
  ('alternator', 'engine', 'Charging alternator', 'electrical', 'Briggs & Stratton', '16 A typical for pump OEM', 1, false, null, null, '5, 9, 16 and 20 A types exist. The burner needs at least 18 A of charging capacity, so which one is fitted decides whether the burner can stay powered. Unknown until the Type number is read.', 160),
  ('muffler', 'engine', 'Muffler and exhaust', 'mechanical', null, null, 1, false, null, null, 'Heavily oxidised, which is normal for the environment.', 170),
  ('drive', null, 'Drive', 'mechanical', null, null, 1, false, null, null, 'Belt drive: 3600 rpm engine down to 1450 rpm pump.', 180),
  ('engpulley', 'drive', 'Engine pulley', 'mechanical', null, null, 1, false, null, null, null, 190),
  ('pumppulley', 'drive', 'Pump pulley', 'mechanical', null, null, 1, false, null, null, null, 200),
  ('belts', 'drive', 'Drive belt, matched set', 'mechanical', null, null, null, true, 'condition based', null, 'A slipping or glazed belt turns the pump below 1450 rpm and pressure falls off fast with speed. First thing to look at when pressure is low.', 210),
  ('pump', null, 'Pump: General Pump TS2021', 'hydraulic', 'General Pump', 'TS2021', 1, false, null, 'https://www.generalpump.com/product/ts2021-2/', '5.6 GPM at 3500 PSI at 1450 rpm. 24 mm solid shaft. Oil SAE 30 non-detergent, 37.2 oz. Beware the TS2021-B, a rebadged lower-spec TS1021; and the TSF2021 is a different pump whose kits do not interchange.', 220),
  ('manifold', 'pump', 'Manifold, nickel plated forged brass', 'mechanical', 'General Pump', '47120941', 1, false, null, null, 'Head bolts 22.1 ft-lb.', 230),
  ('valves', 'pump', 'Valve assemblies, stainless', 'consumable', 'General Pump', '36703201 (Kit 1 / K01)', 6, true, 'condition', null, 'Inlet and discharge are identical. Pitted or fouled valves give pressure loss with hard pulsation. Valve caps 95.9 ft-lb.', 240),
  ('plungers', 'pump', 'Ceramic plungers, 20 mm', 'mechanical', 'General Pump', '47040409', 3, true, 'cavitation kills them', null, 'Crack from thermal shock or from running starved. Plunger screws 14.7 ft-lb.', 250),
  ('packing', 'pump', 'Packing and seal stacks', 'consumable', 'General Pump', 'Kit 28 (K28) or Kit 69 (K69)', 3, true, 'condition', null, 'Worn packings show as water weeping from under the manifold.', 260),
  ('rodseals', 'pump', 'Piston rod oil seals', 'consumable', 'General Pump', 'Kit 2 (K02)', 3, true, 'condition', null, null, 270),
  ('crankseal', 'pump', 'Crankshaft seal 30x55x7', 'consumable', 'General Pump', 'Kit 3 (K03)', 1, true, 'condition', null, null, 280),
  ('crankcase', 'pump', 'Crankcase, die cast aluminium', 'mechanical', 'General Pump', '47010522', 1, false, null, null, null, 290),
  ('crank', 'pump', 'Crankshaft, 16 mm stroke', 'mechanical', 'General Pump', '47021735', 1, false, null, null, null, 300),
  ('conrods', 'pump', 'Connecting rods', 'mechanical', 'General Pump', '47030001', 3, false, null, null, null, 310),
  ('bearings', 'pump', 'Tapered roller bearings', 'mechanical', 'General Pump', '640047', 2, true, 'long life', null, 'Over-tensioning the belt kills these.', 320),
  ('sight', 'pump', 'Oil dipstick and sight glass', 'mechanical', 'General Pump', '98210600 / 97596800', 1, false, null, null, 'Milky oil means water is past the seals and into the crankcase. Check before running.', 330),
  ('pumpoil', 'pump', 'Crankcase oil, SAE 30 non-detergent', 'consumable', 'General Pump', 'Series 100', null, true, '50 h break-in then 500 h', 'https://www.generalpump.com/wp-content/uploads/2017/11/OilRecommend.pdf', 'Non-detergent only. Detergent oil emulsifies and kills the pump.', 340),
  ('water', null, 'High pressure water path', 'hydraulic', null, null, 1, false, null, null, null, 350),
  ('inlet', 'water', 'Inlet hose and strainer', 'hydraulic', null, null, 1, true, 'condition', null, 'The pump wants 5.6 GPM. Starve it and it cavitates instead of pressurising.', 360),
  ('unloader', 'water', 'Unloader valve, brass trapped pressure', 'hydraulic', null, null, 1, true, 'seals and seat', null, 'Make and model UNREAD. Photograph its markings. Visible centre frame, bracket mounted, heavily mineral crusted. Stuck in bypass is the classic cause of no pressure, and stuck made means the burner will not shut off with the gun closed. Never run more than about 6 minutes in bypass.', 370),
  ('bypass', 'water', 'Bypass hose, unloader to inlet', 'hydraulic', null, null, 1, false, null, null, null, 380),
  ('relief', 'water', 'Pressure relief valve, factory set', 'hydraulic', null, null, 1, false, null, null, 'SAFETY. Required for this class under UL 1776. Presence and function UNVERIFIED in any photograph. Must be checked before the burner is fired.', 390),
  ('hpplumb', 'water', 'Discharge plumbing to reel', 'hydraulic', null, null, null, false, null, null, null, 400),
  ('hphose', 'water', 'High pressure hose, 3/8 inch wire braid', 'consumable', null, null, 1, true, 'condition', null, 'Reel holds 150 ft. Verify it is 4000 PSI class, which is what the reel is rated to.', 410),
  ('qc', 'water', 'Quick connect fittings', 'consumable', null, null, null, true, 'condition', null, null, 420),
  ('gun', 'water', 'Trigger gun, lance and nozzle', 'consumable', null, null, 1, true, 'nozzle wears', null, 'A worn or oversized nozzle orifice is the most common cause of gradual pressure loss on any pressure washer.', 430),
  ('heat', null, 'Heat: oil fired burner system', 'hydraulic', null, null, 1, false, null, null, null, 440),
  ('coil', 'heat', 'Heating coil, 1/2 inch Schedule 80 spiral', 'structural', null, null, 1, true, 'descale 1 to 2 years', null, 'Scale is the number one killer: the burner runs, the water stays cold, then it plugs solid. Descale with an auxiliary acid proof pump, never the machine''s own pump. After any overheat let it cool fully before admitting water; trapped steam bursts coils.', 450),
  ('coilins', 'heat', 'Coil insulation, ceramic blanket', 'structural', null, null, 1, false, null, null, null, 460),
  ('coilshell', 'heat', 'Coil shell and flue stack', 'structural', null, null, 1, false, null, null, 'Heavy soot visible in the flue. The burner has been running mistuned.', 470),
  ('burner', 'heat', 'Burner, 12 VDC oil fired', 'mechanical', null, null, 1, false, null, null, 'IDENTITY UNRESOLVED and it is the biggest open question on this machine. Kimi says Beckett ADC at about 85 percent, igniter 5270005U. Gemini says Wayne MSR-DC, igniter 5270004U. One digit apart and neither is knowable: no burner plate is legible in any photograph. Settle it by reading the silver label on the left rear of the burner housing, and the fuel pump nameplate (Suntec A2VA-7116 means ADC, A2YA-7916 means SDC).', 480),
  ('burnmotor', 'burner', 'Burner motor', 'electrical', 'Beckett (if ADC)', '52145U', 1, true, 'condition', null, 'Depends on the burner identity above.', 490),
  ('burnfuelpump', 'burner', 'Burner fuel pump', 'mechanical', 'Suntec', 'A2VA-7116 era', 1, true, 'condition', null, null, 500),
  ('burnsol', 'burner', 'Fuel solenoid', 'electrical', 'Beckett (if ADC)', '3713823U', 1, true, 'condition', null, 'Test 15 to 25 ohms.', 510),
  ('ignitor', 'burner', 'Ignitor, 12 VDC', 'electrical', 'Beckett (if ADC)', '5270005U', 1, true, 'condition', null, 'Steps 12 V to about 20 kV. Gemini gives 5270004U for a Wayne burner instead. Unresolved with the burner identity.', 520),
  ('electrodes', 'burner', 'Electrodes', 'consumable', 'Beckett (if ADC)', '578731', 1, true, 'every tune-up', null, null, 530),
  ('burnnozzle', 'burner', 'Burner nozzle, 0.40 to 2.50 GPH class', 'consumable', null, null, 1, true, 'every tune-up', null, null, 540),
  ('blower', 'burner', 'Blower wheel and coupling', 'mechanical', 'Beckett (if ADC)', '2999U / 2140501U', 1, false, null, null, null, 550),
  ('dieseltank', 'heat', 'Burner fuel tank', 'structural', null, null, 1, false, null, null, 'Yellow plastic tank in the frame. Documented Premier units carried dual 18 gallon factory tanks, so this is a departure. Confirm it feeds only the burner and is vented and secured. Diesel or kerosene only, never petrol.', 560),
  ('fuelsep', 'heat', 'Burner fuel filter and water separator', 'consumable', null, null, 1, true, 'condition', null, null, 570),
  ('control', null, 'Control and safety', 'control', null, null, 1, false, null, null, null, 580),
  ('thermostat', 'control', 'Adjustable thermostat, coil outlet', 'control', null, null, 1, false, null, null, 'A documented Premier feature. Not identifiable in the photographs.', 590),
  ('hilimit', 'control', 'High limit switch', 'control', null, null, 1, false, null, null, 'SAFETY. Cuts the burner if water exceeds safe temperature. UNVERIFIED on this machine.', 600),
  ('flowswitch', 'control', 'Flow or pressure switch, burner proof of flow', 'control', null, null, 1, false, null, null, 'SAFETY. Proves water is moving before the burner fires. UNVERIFIED. This is the interlock whose defeat is the documented route to a heat exchanger explosion.', 610),
  ('contactor', 'control', 'Burner and starter contactor, 12 V continuous duty', 'electrical', 'Camdec', '93265-2', 1, true, 'condition', null, 'READ FROM THE PLATE: 93265-2 CAMDEC, third line 99100B or 8910RS, MADE IN THE U.S.A. This is a departure: the stock part is a Briggs 691656 starter solenoid. Gemini''s report calls this a SAW-4201 and marks that as read; the photograph does not say that. Trombetta 93265 family.', 620),
  ('panel', 'control', 'Control switches and lamps, rear panel', 'control', null, null, 1, false, null, null, 'Orange panel. Contents unread.', 630),
  ('harness', 'control', 'Wiring harness and fusing', 'electrical', null, null, 1, false, null, null, 'SAFETY. Unloomed and weathered, routed over vibrating brackets and hot plumbing next to the fuel tanks. Verify gauge, fusing and terminal condition before the machine is powered up.', 640),
  ('elec', null, 'Electrical supply', 'electrical', null, null, 1, false, null, null, null, 650),
  ('batteries', 'elec', 'Batteries, 12 V', 'electrical', null, null, 2, true, '3 to 5 years', null, 'A mismatched pair with corroded terminals, so at least one has been replaced. A weak pair sags under the burner''s 15 A draw, and low voltage causes delayed ignition, which is a puff-back hazard inside the heat exchanger. Replace as a matched pair.', 660),
  ('cables', 'elec', 'Battery cables and terminals', 'electrical', null, null, null, true, 'condition', null, 'Corroded.', 670),
  ('reel', null, 'Hose storage: Coxreels 112-3-150', 'mechanical', 'Coxreels', '112-3-150', 1, false, null, 'https://www.coxreels.com/100-series_8_9.html', 'Serial 19990729 0799, which dates this machine to July 1999. 4000 PSI, 150 ft of 3/8 inch, hand crank. The tag reads MFG. SINCE 1937 while Coxreels officially says 1923; the tag is what the photograph says, recorded so nobody corrects it.', 680),
  ('swivel', 'reel', 'Swivel, brass 90 degree, 3/8 NPT', 'mechanical', 'Coxreels', '1935', 1, true, 'condition', null, 'Verdigris and mineral crust visible at the swivel on this machine, which is exactly what a weeping swivel looks like. At 3500 PSI a worn swivel kills pressure at the wand. Hand tight plus half a turn; over-tightening locks it.', 690),
  ('swivelkit', 'swivel', 'Swivel seal kit', 'consumable', 'Coxreels', '1935-SEALKIT', 1, true, 'condition', null, null, 700),
  ('reelbearings', 'reel', 'Bearings and bushings', 'consumable', 'Coxreels', '6328-1-1 / 6329-1-1', null, true, 'condition', null, null, 710),
  ('dragbrake', 'reel', 'Drag brake', 'mechanical', 'Coxreels', null, 1, false, null, null, null, 720);

-- Inserted parents first, by walking down the tree, because a part's parent has
-- to exist before the part can point at it.
do $$
declare
  the_model uuid;
  the_doc   uuid;
  depth     int := 0;
  made      int;
begin
  select id into the_model from machine_model
   where make = 'All American Cleaning Systems'
     and model = 'Premier Series hot water skid (PH family)';

  select id into the_doc from machine_document
   where model_id = the_model and source = 'Kimi K2';

  -- Top of the tree first, then each level whose parent has landed.
  loop
    insert into model_part
      (model_id, parent_id, name, domain_id, maker, part_number, quantity,
       wear, wear_life, url, note, document_id, provenance, sort_order, spec)
    select
      the_model,
      parent.id,
      w.name,
      (select t.id from term t where t.kind = 'part_domain' and t.value = w.domain),
      w.maker, w.part_number, w.quantity, w.wear, w.wear_life, w.url, w.note,
      the_doc,
      'inferred',
      w.sort_order,
      jsonb_build_object('map_key', w.key)
    from _washer_part w
    left join model_part parent
      on parent.model_id = the_model
     and parent.spec ->> 'map_key' = w.parent_key
    where not exists (
      select 1 from model_part mp
       where mp.model_id = the_model and mp.spec ->> 'map_key' = w.key)
      and (w.parent_key is null or parent.id is not null);

    get diagnostics made = row_count;
    depth := depth + 1;
    exit when made = 0 or depth > 10;
  end loop;

  if exists (
    select 1 from _washer_part w
     where not exists (
       select 1 from model_part mp
        where mp.model_id = the_model and mp.spec ->> 'map_key' = w.key)
  ) then
    -- A part whose parent key names nothing would vanish silently otherwise,
    -- and a parts list missing parts is worse than no parts list.
    raise exception 'FAIL: % parts did not land, which means a parent key is wrong',
      (select count(*) from _washer_part w
        where not exists (
          select 1 from model_part mp
           where mp.model_id = the_model and mp.spec ->> 'map_key' = w.key));
  end if;

  raise notice 'the washer decomposes into % parts',
    (select count(*) from model_part where model_id = the_model);
end $$;

drop table _washer_part;
