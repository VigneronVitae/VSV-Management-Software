// Row shapes, hand written. The generated types belong here too once a project
// exists to generate them from; until then these are the surface the screens
// actually touch and nothing more.

export type Uuid = string;

export type TermKind =
  | "variety"
  | "cooper"
  | "wood"
  | "vessel_type"
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
  unweighed: number;
};

// --- press -----------------------------------------------------------------

export type PressResult = {
  node_id: Uuid;
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
