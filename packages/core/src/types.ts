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

export type EventRow = {
  id: Uuid;
  operation_id: Uuid;
  subject_type: "node" | "vessel" | "location" | "block";
  subject_id: Uuid;
  at: string;
  provenance: Provenance;
  data: Record<string, unknown>;
};
