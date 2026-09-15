// Row shapes, hand written. The generated types belong here too once a project
// exists to generate them from; until then these are the surface the screens
// actually touch and nothing more.

export type Uuid = string;

// The vocabularies `term_kind` registers. Hand-maintained against a registry,
// which is the drift `AR-E7` took out of two enums and left here: `cooper` was
// in this list for a day after `0032` deleted the vocabulary, and `vessel_maker`
// was absent for a day after `0032` created it. TypeScript catches the second
// direction the moment somebody uses the missing name and catches the first
// never. See sorry S-61.
export type TermKind =
  | "variety"
  | "vessel_maker"
  | "wood"
  | "vessel_type"
  | "press_cut"
  | "press_program"
  | "product_type"
  | "material_kind"
  | "operation"
  | "location_kind";

export type Effect = "measurement" | "treatment" | "movement" | "transformation";

export type Term = {
  id: Uuid;
  kind: TermKind;
  value: string;
  label: string;
  active: boolean;
  sort_order: number;
  attributes: Record<string, unknown>;
};

export type Role = "admin" | "cellar";

export type AppUser = {
  id: Uuid;
  name: string;
  role: Role;
  active: boolean;
};

/** What the caller is entitled to see, answered by the kernel rather than worked
 * out here. `sees` is the whole point: an empty result read against it is a
 * complete statement, where an empty result on its own is not. See 0029. */
export type ViewerScope = {
  signed_in: boolean;
  account: boolean;
  role: Role | null;
  party_id: Uuid | null;
  party_name: string | null;
  party_kind: PartyKind | null;
  may_admin: boolean;
  sees: "everything" | "own" | "nothing";
};

export type PartyKind = "facility" | "client";

export type Party = {
  id: Uuid;
  name: string;
  kind: PartyKind;
  app_user_id: Uuid | null;
  active: boolean;
};

export type Location = {
  id: Uuid;
  name: string;
  kind_id: Uuid | null;
  controlled: boolean;
  ambient_c: number | null;
};

export type NodeStage = "bin" | "load" | "ferment" | "maturation" | "finished";

export type Provenance = "observed" | "inferred" | "confirmed";

// Mirrors the thermal_mode enum. A jacket is off, or it is pushing one way.
export type ThermalMode = "cooling" | "heating" | "off";

// The vessel row itself, as opposed to vessel_state, which is what the page
// reads. An edit form wants this one: vessel_state resolves location to a name
// for display and drops the id, which is the thing a picker needs.
export type VesselRow = {
  id: Uuid;
  type_id: Uuid;
  name: string;
  capacity_l: number | null;
  location_id: Uuid | null;
  owner_id: Uuid | null;
  has_glycol: boolean;
  setpoint_c: number | null;
  mode: ThermalMode;
  attributes: Record<string, unknown>;
};

// What the vessel page reads. Mirrors the vessel_state view.
export type VesselState = {
  id: Uuid;
  type_id: Uuid;
  type: string;
  name: string;
  capacity_l: number | null;
  owner_id: Uuid | null;
  owner_name: string | null;
  facility_owned: boolean;
  location_name: string | null;
  effective_temp_c: number | null;
  node_id: Uuid | null;
  lot_name: string | null;
  variety: string | null;
  vintage: number | null;
  product_type: string | null;
  current_volume_l: number | null;
  // When the wine currently in it went in. Null for an empty vessel, which
  // is what puts the empties last when the list is sorted by it.
  filled_at: string | null;
  is_empty: boolean;
  // Whose wine, as opposed to whose vessel. Different questions, and on a
  // custom crush floor they routinely have different answers.
  lot_owner_id: Uuid | null;
  lot_owner_name: string | null;
  lot_facility_owned: boolean;
  codes: string[] | null;
  attributes: Record<string, unknown>;
};

// The payloads create_vessel_with_wine takes. The function reads jsonb, so the
// shape is enforced here on the way in rather than by the signature.
export type VesselPayload = {
  id: Uuid;
  type_id: Uuid;
  name: string;
  capacity_l?: number | null;
  location_id?: Uuid | null;
  owner_id?: Uuid | null;
  // A jacket and what it is doing. Omitting these is the same as an unjacketed
  // vessel, which is what the table's own defaults say.
  has_glycol?: boolean;
  setpoint_c?: number | null;
  mode?: ThermalMode;
  attributes?: Record<string, unknown>;
};

export type NodePayload = {
  id: Uuid;
  stage: NodeStage;
  name: string;
  variety_id?: Uuid | null;
  vintage?: number | null;
  // Exactly one of this and `vintage` says something, per 0049. Omitting both
  // is refused by the kernel rather than stored as a blank. Nothing sets it on
  // a blend: a lot made of two vintages derives it from its parents inside
  // `rack` and `press`, because a client deciding would be a business rule in a
  // screen and the next client would decide differently.
  non_vintage?: boolean;
  product_type_id?: Uuid | null;
  quantity?: number | null;
  unit?: "lbs" | "kg" | "L" | "gal" | null;
  attributes?: Record<string, unknown>;
  owner_id?: Uuid | null;
};

export type CodePayload = { code: string; label?: string | null };

export type WalkResult = {
  vessel_id: Uuid;
  node_id: Uuid;
  placement_id: Uuid;
  events_generated: number;
};

// A lot's history, including what happened to it before it was this lot. A
// forked barrel inherits its parent's events up to the moment it came off, and
// nothing after, so `inherited` is what tells the two apart on the page.
export type HistoryRow = {
  event_id: Uuid;
  node_id: Uuid;
  at: string;
  operation: string;
  label: string;
  provenance: Provenance;
  data: Record<string, unknown>;
  inherited: boolean;
};

export type EventRow = {
  id: Uuid;
  operation_id: Uuid;
  subject_type: "node" | "vessel" | "location" | "block";
  subject_id: Uuid;
  at: string;
  provenance: Provenance;
  data: Record<string, unknown>;
};

// --- intake ----------------------------------------------------------------

// A vineyard block. Where fruit comes from, and the one thing a pick carries
// that nothing else in the tree does.
// Where fruit comes from. A vineyard is named once and pointed at rather than
// typed onto every block, which is half of S-53.
export type Vineyard = {
  id: Uuid;
  name: string;
  location: string | null;
  notes: string | null;
  created_at: string;
};

// What a block and a planting can each carry. The same set on both, because a
// planting that says nothing takes the block's answer. See planting_detail.
export type SiteFields = {
  acres: number | null;
  planted_year: number | null;
  clone: string | null;
  rootstock: string | null;
  spacing: string | null;
  trellis: string | null;
  aspect: string | null;
  elevation: string | null;
  soil: string | null;
};

export type Block = SiteFields & {
  id: Uuid;
  vineyard_id: Uuid | null;
  name: string;
  notes: string | null;
};

// A variety in a block, with the block's answers filled in where it has none of
// its own. `inherited` names which ones were borrowed, because "this planting
// says 2014" and "the block says 2014 and nobody asked this planting" are two
// different facts and a screen that showed them the same would be lying.
export type PlantingDetail = SiteFields & {
  planting_id: Uuid;
  block_id: Uuid;
  block_name: string;
  vineyard_id: Uuid | null;
  vineyard_name: string | null;
  variety_id: Uuid;
  variety: string;
  notes: string | null;
  inherited: string[];
};

// A pick: fruit at `stage = bin`, however many bins it is spread across.
// `quantity` is null until somebody weighs something, which is the state T1-4
// exists to allow and `unweighed_bin` exists to make visible.
export type Pick = {
  id: Uuid;
  name: string;
  stage: string;
  status: string;
  vintage: number | null;
  block_id: Uuid | null;
  variety_id: Uuid | null;
  quantity: number | null;
  unit: string | null;
  created_at: string;
};

// Mirrors the unweighed_bin view. A bin with fruit in it and no live weighing.
export type UnweighedBin = {
  node_id: Uuid;
  pick_name: string;
  vessel_id: Uuid;
  bin_name: string;
  bin_type: string;
  fill_pct: number | null;
  filled_at: string;
};

// What weigh_bins gives back. Every figure that went into the answer, because a
// stored difference whose inputs were thrown away cannot be checked.
export type Weighing = {
  event_id: Uuid;
  gross_lbs: number;
  tare_lbs: number;
  net_lbs: number;
  total_lbs: number;
  // Whether anybody photographed the scale. Said back rather than assumed,
  // because wanting a photograph and requiring one differ in what happens next,
  // not in whether anybody mentions it. See 0042.
  photographed: boolean;
  unweighed: number;
};

// A lot that predates 0049 and says neither a year nor NV. `suggested_year` is
// read off the lot's own name and is a suggestion for a person to accept or
// reject, never a value anything writes on their behalf.
export type LotWithoutVintage = {
  id: Uuid;
  name: string;
  stage: string;
  status: string;
  created_at: string;
  year_in_the_name: boolean;
  suggested_year: string | null;
};

// --- a press in progress ---------------------------------------------------

// A press somebody started and has not finished. The one thing in this system
// that is deliberately unfinished for hours, which is why it has a list of its
// own: "you can pop off to other vessels and stuff and pop back in".
export type PressInProgress = {
  node_id: Uuid;
  name: string;
  started_at: string;
  press_vessel_id: Uuid | null;
  press_name: string | null;
  lbs_in: number;
  cuts: number;
  litres_so_far: number;
};

// One draw off a press, as it reads back. A press recorded in four goes over
// three hours has a shape that its total does not show.
export type PressDraw = {
  event_id: Uuid;
  load_id: Uuid;
  cut_id: Uuid;
  cut_name: string;
  cut_label: string | null;
  at: string;
  volume_l: number;
  vessel_id: Uuid | null;
  vessel_name: string | null;
  note: string | null;
  by_name: string | null;
  // Marked rather than dropped: a corrected number is part of what happened.
  superseded: boolean;
};

export type PressStarted = {
  node_id: Uuid;
  event_id: Uuid;
  stage: string;
  cut_stage: string;
  lbs_in: number;
  bins_emptied: number;
  unweighed_left: number;
};

export type CutDrawn = {
  cut_id: Uuid;
  event_id: Uuid;
  cut: string;
  volume_l: number;
  cut_total: number;
  in_vessel: number;
  over_capacity: boolean;
  load_total: number;
};

// What `draw_to_level` gives back: everything a draw does, plus where the
// vessel was and where it is now, so the screen can say what it worked out
// rather than just that it worked.
export type LevelDrawn = CutDrawn & {
  was_at: number;
  now_at: number;
};

export type PressFinished = {
  node_id: Uuid;
  event_id: Uuid;
  lbs_in: number;
  litres_out: number;
  cuts: number;
  yield_l_per_ton: number | null;
};

// --- additions -------------------------------------------------------------

// A supply flagged as going into wine. Matched on the registry value in the
// kernel rather than on the label here, so renaming the sort cannot silently
// empty the picker.
export type SupplyForAddition = {
  supply_id: Uuid;
  name: string;
  unit: string;
  on_hand: number;
  counted_at: string | null;
  supplier: string | null;
};

// What `add_to_wine` gives back. The volume and the rate are derived from the
// placements as they stood at the time, said back rather than stored.
export type AdditionResult = {
  event_id: Uuid;
  node_id: Uuid;
  lot_name: string;
  what: string;
  amount: number;
  unit: string;
  volume_l: number;
  per_litre: number | null;
  // Whether the inventory moved with it. False when the units differ, which is
  // S-63 and is said out loud rather than papered over with a guessed factor.
  shelf_moved: boolean;
  shelf_note: string | null;
};

export type LotAddition = {
  event_id: Uuid;
  node_id: Uuid;
  lot_name: string;
  at: string;
  what: string;
  supply_id: Uuid | null;
  amount: number;
  unit: string;
  note: string | null;
  vessels: string[];
  volume_l: number | null;
  per_litre: number | null;
  took_from_the_shelf: boolean;
};

// Something somebody said about anything, at any time. Never evidence: a note
// changes no quantity, clears no worklist and satisfies no form. See 0062.
export type SubjectNote = {
  id: Uuid;
  subject_type: string;
  subject_id: Uuid;
  about_event: Uuid | null;
  body: string;
  at: string;
  edited_at: string | null;
  by_name: string | null;
  by_user: Uuid | null;
};

// --- photographs -----------------------------------------------------------

// A photograph of anything the subject resolver knows about. See migration
// 0047: `about_event` is set when the photograph is evidence for one particular
// thing that happened, such as the reading on a scale, and null when it is
// simply a picture of the subject.
export type Attachment = {
  id: Uuid;
  subject_type: string;
  subject_id: Uuid;
  about_event: Uuid | null;
  path: string;
  caption: string | null;
  by_user: Uuid | null;
  at: string;
  created_at: string;
};

// A live weighing carrying no photograph. Weaker evidence rather than
// unfinished work, which is why nothing counts this anywhere that nags.
export type WeighingWithoutPhoto = {
  event_id: Uuid;
  node_id: Uuid;
  pick_name: string;
  at: string;
  net_lbs: number | null;
};

// One weighing of a pick, as it is read back rather than as it was returned.
// `weigh_bins` answers the caller who made it; this is how the same reading
// looks to somebody arriving that evening with three photographs and no memory
// of which was which.
export type PastWeighing = {
  event_id: Uuid;
  at: string;
  gross_lbs: number | null;
  tare_lbs: number | null;
  net_lbs: number | null;
  bins: string[];
  note: string | null;
  superseded: boolean;
  photos: number;
};

// --- press -----------------------------------------------------------------

export type PressResult = {
  node_id: Uuid;
  // One lot per cut. The first is also `node_id`, so a press with no cuts reads
  // the same as it did before 0045.
  cuts: Uuid[];
  stage: string;
  lbs_in: number;
  litres_out: number;
  yield_l_per_ton: number | null;
  bins_emptied: number;
  // Not fatal and not silent: the press went ahead with containers on the pick
  // that never reached a scale, and somebody should know.
  unweighed_left: number;
  event_id: Uuid;
};

export type BinToReturn = {
  vessel_id: Uuid;
  bin_name: string;
  bin_type: string;
  owner_id: Uuid | null;
  owed_to: string | null;
  location_id: Uuid | null;
};

// --- the day ---------------------------------------------------------------

// One thing that happened, derived from the record rather than written down a
// second time. `kind` says which sort: an event, or a lot coming into being.
export type DayEntry = {
  at: string;
  kind: string;
  headline: string;
  subject: string;
  detail: Record<string, unknown> | null;
  provenance: string;
};

// What somebody wrote about a day. Private notes are their author's alone; the
// rest are the facility's board and are hidden from clients by policy.
export type DayNote = {
  id: Uuid;
  on_date: string;
  body: string;
  private: boolean;
  author_id: Uuid | null;
  created_at: string;
};

// --- what is owed to paper -------------------------------------------------

// A physical document this winery keeps, and the span over which it kept it.
// Retired rather than deleted: a form kept in September is still what was
// required in September.
export type PaperRecord = {
  id: Uuid;
  name: string;
  notes: string | null;
  effective_from: string;
  retired_at: string | null;
  created_at: string;
};

// One measurement, owed to one document. A weighing due on two sheets is two of
// these, because doing one of them is not doing both.
export type ToPropagate = {
  event_id: Uuid;
  paper_record_id: Uuid;
  paper_record: string;
  at: string;
  operation: string;
  subject: string;
  data: Record<string, unknown> | null;
  provenance: string;
};

// --- the stores ------------------------------------------------------------

// What is on a shelf, worked out from what came in and went out since the last
// time somebody counted. Derived on every read: see 0046.
export type SupplyOnHand = {
  supply_id: Uuid;
  name: string;
  // What sort of thing it is, as labels. Several, or none: a hose head is
  // neither infrastructure nor consumable and a category would force a choice.
  kinds: string[];
  unit: string;
  reorder_level: number | null;
  supplier: string | null;
  retired_at: string | null;
  counted_at: string | null;
  on_hand: number;
  // Broken and not yet repaired or thrown out. Separate from on hand, because
  // six of which two are broken is four to anybody reaching for one.
  broken: number;
};

// A list somebody keeps, prompted by the derivation rather than filled by it.
export type ShoppingItem = {
  id: Uuid;
  supply_id: Uuid | null;
  what: string;
  quantity: string | null;
  note: string | null;
  added_by: Uuid | null;
  bought_at: string | null;
  created_at: string;
};

// What a count found, and what the movements had said. The difference is a
// measurement of how much use goes unrecorded.
export type SupplyCount = {
  supply_id: Uuid;
  name: string;
  counted: number;
  expected: number;
  difference: number;
  unit: string;
};
