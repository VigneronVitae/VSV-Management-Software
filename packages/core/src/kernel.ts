import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { readConfig } from "./env.ts";
import type {
  AppUser,
  CodePayload,
  EventRow,
  HistoryRow,
  Location,
  NodePayload,
  Party,
  Term,
  TermKind,
  Uuid,
  VesselPayload,
  VesselRow,
  VesselState,
  WalkResult,
} from "./types.ts";

// Everything here is a thin pass through to the database. No rule is computed
// on this side of the wire: where a decision has to be made it is made by a
// function in a migration and called from here, per the hard rule in CLAUDE.md.

let client: SupabaseClient | null = null;

export function kernel(): SupabaseClient {
  if (!client) {
    const { url, anonKey } = readConfig();
    client = createClient(url, anonKey);
  }
  return client;
}

// Ids are generated here so an offline write has identity before the server
// sees it. Never a sequence.
export function newId(): Uuid {
  return crypto.randomUUID();
}

// --- identity -------------------------------------------------------------

export async function signUp(email: string, password: string): Promise<void> {
  const { error } = await kernel().auth.signUp({ email, password });
  if (error) throw new Error(error.message);
}

export async function signIn(email: string, password: string): Promise<void> {
  const { error } = await kernel().auth.signInWithPassword({ email, password });
  if (error) throw new Error(error.message);
}

export async function signOut(): Promise<void> {
  await kernel().auth.signOut();
}

export async function currentSession(): Promise<{
  userId: Uuid;
  email: string;
} | null> {
  const { data } = await kernel().auth.getSession();
  const user = data.session?.user;
  return user ? { userId: user.id, email: user.email ?? "" } : null;
}

// Whether this account is admin is the database's answer, not this client's.
//
// claim_account returns a composite, and PostgREST renders a composite-returning
// function as a bare object while a set-returning one comes back as an array.
// This is the first call a stranger's first run makes, so it accepts either
// rather than betting on which.
export async function claimAccount(name: string): Promise<AppUser> {
  const { data, error } = await kernel().rpc("claim_account", { p_name: name });
  if (error) throw new Error(error.message);
  const row = Array.isArray(data) ? data[0] : data;
  if (!row) throw new Error("claim_account returned nothing");
  return row as AppUser;
}

export async function currentAppUser(): Promise<AppUser | null> {
  const session = await currentSession();
  if (!session) return null;
  const { data, error } = await kernel()
    .from("app_user")
    .select("id, name, role, active")
    .eq("id", session.userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data as AppUser | null;
}

// --- vocabulary -----------------------------------------------------------

export async function terms(kind: TermKind): Promise<Term[]> {
  const { data, error } = await kernel()
    .from("term")
    .select("id, kind, value, label, active, sort_order, attributes")
    .eq("kind", kind)
    .eq("active", true)
    .order("sort_order")
    .order("label");
  if (error) throw new Error(error.message);
  return (data ?? []) as Term[];
}

// Which terms a given field on a given vessel type may offer. The field says
// which vocabulary and which contract; the kernel returns the intersection.
export async function termsForVesselField(
  vesselTypeId: Uuid,
  fieldKey: string,
): Promise<Term[]> {
  const { data, error } = await kernel().rpc("terms_for_vessel_field", {
    p_vessel_type_id: vesselTypeId,
    p_field_key: fieldKey,
  });
  if (error) throw new Error(error.message);
  return (data ?? []) as Term[];
}

// Which makers a vessel type may pick from. "Creator of" is one function with
// two contracts, cooper and manufacturer, and which one a type wants is a fact
// about vocabulary rather than about screens, so the kernel answers it.
export async function makersForVesselType(vesselTypeId: Uuid): Promise<Term[]> {
  const { data, error } = await kernel().rpc("makers_for_vessel_type", {
    p_vessel_type_id: vesselTypeId,
  });
  if (error) throw new Error(error.message);
  return (data ?? []) as Term[];
}

// The add-inline path. A fresh install has no coopers and no locations, so a
// picker without this is a dead end on first run.
export async function addTerm(
  kind: TermKind,
  label: string,
  attributes: Record<string, unknown> = {},
): Promise<Term> {
  const value = slug(label);
  const { data, error } = await kernel()
    .from("term")
    .insert({ id: newId(), kind, value, label, attributes })
    .select("id, kind, value, label, active, sort_order, attributes")
    .single();
  if (error) throw new Error(error.message);
  return data as Term;
}

// A machine key derived from what the person typed. Stable, ascii, and never
// shown: the label is what anybody reads.
export function slug(label: string): string {
  return label
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 60);
}

// --- parties and places ---------------------------------------------------

export async function facilityParty(): Promise<Party | null> {
  const { data, error } = await kernel()
    .from("party")
    .select("id, name, kind, app_user_id, active")
    .eq("kind", "facility")
    .eq("active", true)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data as Party | null;
}

export async function parties(): Promise<Party[]> {
  const { data, error } = await kernel()
    .from("party")
    .select("id, name, kind, app_user_id, active")
    .eq("active", true)
    .order("kind")
    .order("name");
  if (error) throw new Error(error.message);
  return (data ?? []) as Party[];
}

export async function addParty(
  name: string,
  kind: "facility" | "client",
): Promise<Party> {
  const { data, error } = await kernel()
    .from("party")
    .insert({ id: newId(), name, kind })
    .select("id, name, kind, app_user_id, active")
    .single();
  if (error) throw new Error(error.message);
  return data as Party;
}

// Every account, so an admin can attach one to a client party. That link is
// what makes a custom crush client's login mean anything: node_read scopes a
// client to owner_id = current_party_id(), and current_party_id() is this.
export async function appUsers(): Promise<AppUser[]> {
  const { data, error } = await kernel()
    .from("app_user")
    .select("id, name, role, active")
    .eq("active", true)
    .order("name");
  if (error) throw new Error(error.message);
  return (data ?? []) as AppUser[];
}

// Null unlinks. One login resolves to at most one party, enforced by a unique
// index, so handing a login to a second client fails rather than quietly
// widening what the first one can see.
export async function setPartyLogin(
  partyId: Uuid,
  appUserId: Uuid | null,
): Promise<void> {
  const { error } = await kernel()
    .from("party")
    .update({ app_user_id: appUserId })
    .eq("id", partyId);
  if (error) throw new Error(error.message);
}

export async function locations(): Promise<Location[]> {
  const { data, error } = await kernel()
    .from("location")
    .select("id, name, kind_id, controlled, ambient_c")
    .order("name");
  if (error) throw new Error(error.message);
  return (data ?? []) as Location[];
}

export async function addLocation(row: Omit<Location, "id">): Promise<Location> {
  const { data, error } = await kernel()
    .from("location")
    .insert({ id: newId(), ...row })
    .select("id, name, kind_id, controlled, ambient_c")
    .single();
  if (error) throw new Error(error.message);
  return data as Location;
}

// --- vessel types, and notes about them ------------------------------------

// Writing this is admin work, enforced by the term policy rather than by the
// screen. The descriptor shape is checked by a trigger, so a malformed field
// list is refused here rather than breaking every vessel form later.
export async function setVesselTypeFields(
  vesselTypeId: Uuid,
  fields: Array<Record<string, unknown>>,
): Promise<void> {
  const { data, error } = await kernel()
    .from("term")
    .select("attributes")
    .eq("id", vesselTypeId)
    .single();
  if (error) throw new Error(error.message);
  const attributes = {
    ...((data as { attributes: Record<string, unknown> }).attributes ?? {}),
    fields,
  };
  const { error: writeError } = await kernel()
    .from("term")
    .update({ attributes })
    .eq("id", vesselTypeId);
  if (writeError) throw new Error(writeError.message);
}

export type VesselTypeNote = {
  id: Uuid;
  vessel_type_id: Uuid;
  body: string;
  created_by: Uuid | null;
  created_at: string;
  resolved_at: string | null;
};

export async function vesselTypeNotes(vesselTypeId: Uuid): Promise<VesselTypeNote[]> {
  const { data, error } = await kernel()
    .from("vessel_type_note")
    .select("id, vessel_type_id, body, created_by, created_at, resolved_at")
    .eq("vessel_type_id", vesselTypeId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);
  return (data ?? []) as VesselTypeNote[];
}

// Anyone signed in may leave one. That is the point: the person who finds the
// gap is rarely the person allowed to close it.
export async function addVesselTypeNote(
  vesselTypeId: Uuid,
  body: string,
): Promise<void> {
  const session = await currentSession();
  const { error } = await kernel()
    .from("vessel_type_note")
    .insert({
      id: newId(),
      vessel_type_id: vesselTypeId,
      body,
      created_by: session?.userId ?? null,
    });
  if (error) throw new Error(error.message);
}

export async function resolveVesselTypeNote(noteId: Uuid): Promise<void> {
  const session = await currentSession();
  const { error } = await kernel()
    .from("vessel_type_note")
    .update({
      resolved_at: new Date().toISOString(),
      resolved_by: session?.userId ?? null,
    })
    .eq("id", noteId);
  if (error) throw new Error(error.message);
}

// --- vessels --------------------------------------------------------------

export async function vessels(): Promise<VesselState[]> {
  const { data, error } = await kernel().from("vessel_state").select("*").order("name");
  if (error) throw new Error(error.message);
  return (data ?? []) as VesselState[];
}

// Scanning is a read. A code already bound answers with its vessel rather than
// failing, because mid-walk people scan things twice.
export async function resolveCode(code: string): Promise<VesselState | null> {
  const { data, error } = await kernel().rpc("resolve_vessel_code", { p_code: code });
  if (error) throw new Error(error.message);
  const rows = (data ?? []) as VesselState[];
  return rows[0] ?? null;
}

export async function bindCode(
  vesselId: Uuid,
  code: string,
  label: string | null,
): Promise<void> {
  const { error } = await kernel().rpc("bind_vessel_code", {
    p_vessel_id: vesselId,
    p_code: code,
    p_label: label,
    p_id: newId(),
  });
  if (error) throw new Error(error.message);
}

export async function addVessel(vessel: VesselPayload): Promise<void> {
  const { error } = await kernel().from("vessel").insert(vessel);
  if (error) throw new Error(error.message);
}

// Wine into a vessel that already exists. The inventory case: a new lot with no
// source. Moving a lot the app already knows about is a rack and is not this.
export async function fillVessel(args: {
  vesselId: Uuid;
  node: NodePayload;
  volumeL: number | null;
}): Promise<WalkResult> {
  const { data, error } = await kernel().rpc("fill_vessel", {
    p_vessel_id: args.vesselId,
    p_node: args.node,
    p_volume_l: args.volumeL,
    p_generate_history: true,
  });
  if (error) throw new Error(error.message);
  return data as WalkResult;
}

export async function vesselById(vesselId: Uuid): Promise<VesselRow> {
  const { data, error } = await kernel()
    .from("vessel")
    .select(
      "id,type_id,name,capacity_l,location_id,owner_id,has_glycol,setpoint_c,mode,attributes",
    )
    .eq("id", vesselId)
    .single();
  if (error) throw new Error(error.message);
  return data as VesselRow;
}

// Through the kernel rather than a PATCH, because a change to the thermal
// columns has to write a setpoint_change event and deciding that here would
// put the rule in a client. A key left out of the patch is left alone.
export async function updateVessel(
  vesselId: Uuid,
  patch: Partial<Omit<VesselPayload, "id">>,
): Promise<{ thermal_change: boolean }> {
  const { data, error } = await kernel().rpc("update_vessel", {
    p_vessel_id: vesselId,
    p_patch: patch,
  });
  if (error) throw new Error(error.message);
  return data as { thermal_change: boolean };
}

// Vessel, lot, placement and codes in one transaction, then whatever history
// the variety template implies. One call because four calls half-succeed.
export async function createVesselWithWine(args: {
  vessel: VesselPayload;
  node: NodePayload;
  volumeL: number | null;
  codes: CodePayload[];
}): Promise<WalkResult> {
  const { data, error } = await kernel().rpc("create_vessel_with_wine", {
    p_vessel: args.vessel,
    p_node: args.node,
    p_volume_l: args.volumeL,
    p_codes: args.codes,
    p_generate_history: true,
  });
  if (error) throw new Error(error.message);
  return data as WalkResult;
}

export type RackLeg = { vessel_id: Uuid; volume_l: number };

export type RackPlan = {
  kind: "move" | "blend";
  node_id: Uuid | null;
  parents: Array<{
    node_id: Uuid;
    name: string;
    owner_id: Uuid | null;
    volume_l: number;
  }>;
  out_l: number;
  in_l: number;
  loss_l: number;
  overfill: Array<{
    vessel_id: Uuid;
    name: string;
    capacity_l: number;
    would_hold: number;
  }>;
  mixed_owners: boolean;
};

// What this transfer would do, without doing it. The same function the write
// uses, so the screen never has to work out move versus blend for itself.
export async function rackPlan(
  sources: RackLeg[],
  destinations: RackLeg[],
): Promise<RackPlan> {
  const { data, error } = await kernel().rpc("rack_plan", {
    p_sources: sources,
    p_destinations: destinations,
  });
  if (error) throw new Error(error.message);
  return data as RackPlan;
}

export async function rackTransfer(args: {
  sources: RackLeg[];
  destinations: RackLeg[];
  data?: Record<string, unknown>;
  allowOverfill?: boolean;
  node?: Record<string, unknown>;
}): Promise<RackPlan & { node_id: Uuid; event_id: Uuid }> {
  const { data, error } = await kernel().rpc("rack", {
    p_sources: args.sources,
    p_destinations: args.destinations,
    p_data: args.data ?? {},
    p_allow_overfill: args.allowOverfill ?? false,
    p_node: args.node ?? {},
  });
  if (error) throw new Error(error.message);
  return data as RackPlan & { node_id: Uuid; event_id: Uuid };
}

// A lot's own events plus everything its ancestors did before it came off
// them. Reading `event` directly would show a freshly forked barrel as having
// no history at all, which reads as "nothing has ever been done to this".
export async function nodeHistory(nodeId: Uuid): Promise<HistoryRow[]> {
  const { data, error } = await kernel().rpc("node_history", { p_node_id: nodeId });
  if (error) throw new Error(error.message);
  return (data ?? []) as HistoryRow[];
}

// Records against a lot, or against some of its vessels. A strict subset forks
// those vessels off first, because otherwise the record claims the addition
// reached wine it never touched. The kernel decides that, not this.
export async function recordEvent(args: {
  nodeId: Uuid;
  operation: string;
  data?: Record<string, unknown>;
  vesselIds?: Uuid[];
}): Promise<{ event_id: Uuid; node_id: Uuid; forked: boolean }> {
  const { data, error } = await kernel().rpc("record_event", {
    p_node_id: args.nodeId,
    p_operation: args.operation,
    p_data: args.data ?? {},
    p_vessel_ids: args.vesselIds ?? null,
  });
  if (error) throw new Error(error.message);
  return data as { event_id: Uuid; node_id: Uuid; forked: boolean };
}

export async function nodeEvents(
  nodeId: Uuid,
): Promise<(EventRow & { label: string })[]> {
  const { data, error } = await kernel()
    .from("event")
    .select("id, operation_id, subject_type, subject_id, at, provenance, data")
    .eq("subject_type", "node")
    .eq("subject_id", nodeId)
    .order("at");
  if (error) throw new Error(error.message);

  const events = (data ?? []) as EventRow[];
  if (events.length === 0) return [];

  // Two queries rather than an embed. event.operation_id references term on a
  // composite key (id, kind), and PostgREST's relation detection across one of
  // those is not something to depend on from a barrel room.
  const ids = [...new Set(events.map((e) => e.operation_id))];
  const { data: ops, error: opError } = await kernel()
    .from("term")
    .select("id, label")
    .in("id", ids);
  if (opError) throw new Error(opError.message);

  const labels = new Map((ops ?? []).map((o) => [o.id as Uuid, o.label as string]));
  return events.map((e) => ({
    ...e,
    label: labels.get(e.operation_id) ?? "unknown operation",
  }));
}

// --- photos ---------------------------------------------------------------

const PHOTO_BUCKET = "vessel-photos";

export async function uploadVesselPhoto(vesselId: Uuid, file: File): Promise<string> {
  const suffix = file.name.split(".").pop()?.toLowerCase() ?? "jpg";
  const path = `${vesselId}/photo.${suffix}`;
  const { error } = await kernel()
    .storage.from(PHOTO_BUCKET)
    .upload(path, file, { upsert: true, contentType: file.type || "image/jpeg" });
  if (error) throw new Error(error.message);
  return path;
}

// The bucket is private, so a photo is shown through a short lived signed url
// rather than a public one. A barrel photo shows a chalk mark with a client's
// lot on it.
export async function vesselPhotoUrl(path: string): Promise<string | null> {
  const { data, error } = await kernel()
    .storage.from(PHOTO_BUCKET)
    .createSignedUrl(path, 60 * 10);
  if (error) return null;
  return data?.signedUrl ?? null;
}
