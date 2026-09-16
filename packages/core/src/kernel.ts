import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { type Backend, currentBackend, readConfig, setBackend } from "./env.ts";
import type {
  AdditionResult,
  AppUser,
  Attachment,
  BarrelColour,
  BarrelWarning,
  BinFruit,
  BinInventory,
  BinToReturn,
  Block,
  CodePayload,
  ColourConflict,
  Contract,
  CutDrawn,
  DayEntry,
  DayNote,
  EventRow,
  HistoryRow,
  Invite,
  LevelDrawn,
  Location,
  LotAddition,
  LotDetail,
  LotWithoutColour,
  LotWithoutVintage,
  NodePayload,
  PaperRecord,
  Party,
  PastWeighing,
  Pick,
  PickBin,
  PlantingDetail,
  PressDraw,
  PressFinished,
  PressInProgress,
  PressResult,
  PressStarted,
  RoomClimate,
  RunningOperation,
  Sample,
  SampleKind,
  SampleTarget,
  ShoppingItem,
  SubjectNote,
  SupplyCount,
  SupplyForAddition,
  SupplyOnHand,
  Term,
  TermKind,
  ThermalMode,
  ToPropagate,
  TypedFact,
  UnweighedBin,
  Uuid,
  VesselPayload,
  VesselRow,
  VesselState,
  ViewerScope,
  Vineyard,
  WalkResult,
  Watching,
  Weighing,
  WeighingWithoutPhoto,
} from "./types.ts";

// Everything here is a thin pass through to the database. No rule is computed
// on this side of the wire: where a decision has to be made it is made by a
// function in a migration and called from here, per the hard rule in CLAUDE.md.

let client: SupabaseClient | null = null;
// Which stack the cached client is for. Without this, switching into practice
// mode would keep talking to the cellar until a reload, which is the exact
// failure practice mode exists to prevent: a person who believes they are
// somewhere they are not.
let clientFor: Backend | null = null;

export function kernel(): SupabaseClient {
  const backend = currentBackend();
  if (!client || clientFor !== backend) {
    const { url, anonKey } = readConfig();
    client = createClient(url, anonKey);
    clientFor = backend;
  }
  return client;
}

/** Move between the cellar and practice. The session does not travel: logins
 * are per stack, so staying signed in across a switch is not possible and
 * pretending otherwise would leave somebody looking at an empty screen with no
 * idea why. */
export function switchBackend(to: Backend): void {
  setBackend(to);
  client = null;
  clientFor = null;
}

// Ids are generated here so an offline write has identity before the server
// sees it. Never a sequence.
/**
 * A refusal, with the thing that says who refused still attached.
 *
 * Every wrapper below used to end `throw new KernelError(error)`, in thirty
 * four places, which discards the SQLSTATE. That one character of carelessness is
 * why W-8 found three shapes of refusal and no way to tell them apart: P0001 is a
 * sentence the kernel wrote for a person and 42501 is a policy that has none, and
 * downstream of `new Error(message)` they are the same object. The code that
 * needed the discriminator never saw it.
 */
export class KernelError extends Error {
  readonly code: string | undefined;
  readonly details: string | undefined;
  constructor(e: {
    message: string;
    code?: string | undefined;
    details?: string | null | undefined;
  }) {
    super(e.message);
    this.name = "KernelError";
    this.code = e.code;
    this.details = e.details ?? undefined;
  }
}

export function newId(): Uuid {
  return crypto.randomUUID();
}

// --- identity -------------------------------------------------------------

export async function signUp(email: string, password: string): Promise<void> {
  const { error } = await kernel().auth.signUp({ email, password });
  if (error) throw new KernelError(error);
}

export async function signIn(email: string, password: string): Promise<void> {
  const { error } = await kernel().auth.signInWithPassword({ email, password });
  if (error) throw new KernelError(error);
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
export async function claimAccount(
  name: string,
  invite?: string | null,
): Promise<AppUser> {
  const { data, error } = await kernel().rpc("claim_account", {
    p_name: name,
    p_invite: invite ?? null,
  });
  if (error) throw new KernelError(error);
  const row = Array.isArray(data) ? data[0] : data;
  if (!row) throw new Error("claim_account returned nothing");
  return row as AppUser;
}

/** The caller's standing, from the kernel. Never cached across a sign-in: it is
 * the answer to "what am I", and the one thing that changes when that changes. */
export async function viewerScope(): Promise<ViewerScope> {
  const { data, error } = await kernel().rpc("viewer_scope");
  if (error) throw new KernelError(error);
  const row = Array.isArray(data) ? data[0] : data;
  // A caller with no session still gets a shape rather than a null, so that every
  // reader downstream has a scope to render against and none of them has to ask
  // whether it exists.
  return (row ?? {
    signed_in: false,
    account: false,
    role: null,
    party_id: null,
    party_name: null,
    party_kind: null,
    may_admin: false,
    sees: "nothing",
  }) as ViewerScope;
}

/** Which columns of a table this caller may write, from the trigger that
 * enforces it. See 0030: hardcoding the list is R-4, and column privileges
 * cannot express the rule because admin and cellar are the same database role. */
export async function writableColumns(table: string): Promise<string[]> {
  const { data, error } = await kernel().rpc("writable_columns", {
    p_table: table,
  });
  if (error) throw new KernelError(error);
  return (data ?? []) as string[];
}

/** An invite is permission to become somebody this winery trusts, and only an
 * administrator issues one. See 0068 and S-78. */
export async function makeInvite(
  role: "admin" | "cellar" = "cellar",
  note?: string | null,
): Promise<{ code: string; role: string; expires_at: string }> {
  const { data, error } = await kernel().rpc("make_invite", {
    p_role: role,
    p_note: note ?? null,
  });
  if (error) throw new KernelError(error);
  return data as { code: string; role: string; expires_at: string };
}

export async function invites(): Promise<Invite[]> {
  const { data, error } = await kernel()
    .from("invite")
    .select("code,role,note,created_at,used_by,used_at,expires_at")
    .order("created_at", { ascending: false });
  if (error) throw new KernelError(error);
  return (data ?? []) as Invite[];
}

export async function withdrawInvite(code: string): Promise<void> {
  const { error } = await kernel().from("invite").delete().eq("code", code);
  if (error) throw new KernelError(error);
}

export async function currentAppUser(): Promise<AppUser | null> {
  const session = await currentSession();
  if (!session) return null;
  const { data, error } = await kernel()
    .from("app_user")
    .select("id, name, role, active")
    .eq("id", session.userId)
    .maybeSingle();
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
  return (data ?? []) as Term[];
}

// Which makers a vessel type may pick from. "Creator of" is one function with
// two contracts, cooper and manufacturer, and which one a type wants is a fact
// about vocabulary rather than about screens, so the kernel answers it.
export async function makersForVesselType(vesselTypeId: Uuid): Promise<Term[]> {
  const { data, error } = await kernel().rpc("makers_for_vessel_type", {
    p_vessel_type_id: vesselTypeId,
  });
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
  return data as Party | null;
}

export async function parties(): Promise<Party[]> {
  const { data, error } = await kernel()
    .from("party")
    .select("id, name, kind, app_user_id, active")
    .eq("active", true)
    .order("kind")
    .order("name");
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
}

export async function locations(): Promise<Location[]> {
  const { data, error } = await kernel()
    .from("location")
    .select("id, name, kind_id, controlled, ambient_c")
    .order("name");
  if (error) throw new KernelError(error);
  return (data ?? []) as Location[];
}

export async function addLocation(row: Omit<Location, "id">): Promise<Location> {
  const { data, error } = await kernel()
    .from("location")
    .insert({ id: newId(), ...row })
    .select("id, name, kind_id, controlled, ambient_c")
    .single();
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
  const attributes = {
    ...((data as { attributes: Record<string, unknown> }).attributes ?? {}),
    fields,
  };
  const { error: writeError } = await kernel()
    .from("term")
    .update({ attributes })
    .eq("id", vesselTypeId);
  // Was `new Error(writeError.message)`, which threw away the SQLSTATE and with
  // it the difference between a refusal and a failure. See W-9 and refusal.ts.
  if (writeError) throw new KernelError(writeError);
}

// Whether this vessel type is a picking bin, and what one weighs empty. Both
// live on the type rather than on each vessel, because every bin of a type
// weighs the same: slotted and unslotted are different types, which is the
// granularity the winemaker described. See 0033.
//
// The tare is deliberately allowed to be null. A type flagged as a bin with no
// tare yet is a real state, and `bin_tare_lbs` refuses at the scale rather than
// treating a missing tare as zero, which would make every pick read heavy by the
// weight of its own containers.
export async function setVesselTypeBin(
  vesselTypeId: Uuid,
  bin: { intakeBin: boolean; tareLbs: number | null },
): Promise<void> {
  const { data, error } = await kernel()
    .from("term")
    .select("attributes")
    .eq("id", vesselTypeId)
    .single();
  if (error) throw new KernelError(error);
  const attributes: Record<string, unknown> = {
    ...((data as { attributes: Record<string, unknown> }).attributes ?? {}),
  };
  if (bin.intakeBin) attributes.intake_bin = true;
  else delete attributes.intake_bin;
  if (bin.tareLbs === null) delete attributes.tare_lbs;
  else attributes.tare_lbs = bin.tareLbs;

  const { error: writeError } = await kernel()
    .from("term")
    .update({ attributes })
    .eq("id", vesselTypeId);
  if (writeError) throw new KernelError(writeError);
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
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
}

// --- vessels --------------------------------------------------------------

export async function vessels(): Promise<VesselState[]> {
  const { data, error } = await kernel().from("vessel_state").select("*").order("name");
  if (error) throw new KernelError(error);
  return (data ?? []) as VesselState[];
}

// One vessel, with what is in it. `vessels()` answers this too and fetches the
// whole cellar to do it, which is right for a list and wrong for a tap.
export async function vesselStateById(id: Uuid): Promise<VesselState | null> {
  const { data, error } = await kernel()
    .from("vessel_state")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (error) throw new KernelError(error);
  return (data ?? null) as VesselState | null;
}

// Scanning is a read. A code already bound answers with its vessel rather than
// failing, because mid-walk people scan things twice.
export async function resolveCode(code: string): Promise<VesselState | null> {
  const { data, error } = await kernel().rpc("resolve_vessel_code", { p_code: code });
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
}

export async function addVessel(vessel: VesselPayload): Promise<void> {
  const { error } = await kernel().from("vessel").insert(vessel);
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
  return data as WalkResult;
}

// Asking for a vessel that might not be there. `single()` treats no rows as an
// error, which is right for a caller that already knows the vessel exists and
// wrong for the one that is resolving a link somebody could have typed: the
// error it produces is PostgREST's "cannot coerce the result to a single JSON
// object", which is a sentence about a serialiser, shown to a person who
// followed a stale link. `maybeSingle()` makes absence an answer.
//
// **Absent and forbidden are the same answer here and that is deliberate.** A
// row this sign-in may not read is not in the result either way, and the whole
// point of the row-level policy is that a reader cannot tell the difference.
// What the caller may say is that it is not there to open.
export async function vesselByIdOrNull(vesselId: Uuid): Promise<VesselRow | null> {
  const { data, error } = await kernel()
    .from("vessel")
    .select(
      "id,type_id,name,capacity_l,location_id,owner_id,has_glycol,setpoint_c,mode,attributes",
    )
    .eq("id", vesselId)
    .maybeSingle();
  if (error) throw new KernelError(error);
  return (data as VesselRow | null) ?? null;
}

export async function vesselById(vesselId: Uuid): Promise<VesselRow> {
  const { data, error } = await kernel()
    .from("vessel")
    .select(
      "id,type_id,name,capacity_l,location_id,owner_id,has_glycol,setpoint_c,mode,attributes",
    )
    .eq("id", vesselId)
    .single();
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
  return data as RackPlan & { node_id: Uuid; event_id: Uuid };
}

// A lot's own events plus everything its ancestors did before it came off
// them. Reading `event` directly would show a freshly forked barrel as having
// no history at all, which reads as "nothing has ever been done to this".
export async function nodeHistory(nodeId: Uuid): Promise<HistoryRow[]> {
  const { data, error } = await kernel().rpc("node_history", { p_node_id: nodeId });
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);
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
  if (error) throw new KernelError(error);

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
  if (error) throw new KernelError(error);
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

// Every photograph in this system lives in the same bucket, which is named
// `vessel-photos` because in 0005 vessels were the only thing anybody
// photographed. The name is now wrong and renaming it would orphan every path
// already stored, so it stays and this is the general way to read one.
export const photoUrl = vesselPhotoUrl;

// Uploads a photograph without attaching it to anything. Two steps rather than
// one, because the file goes to storage and the record goes to the database,
// and a phone in a barn loses signal between them often enough that the error
// has to be able to say which half failed.
//
// The path carries the subject and a timestamp so that two photographs of the
// same thing do not overwrite one another. That is the whole of what was wrong
// with `uploadVesselPhoto`, which writes `<id>/photo.<ext>` and so has only ever
// been able to hold one.
export async function uploadPhoto(
  subjectType: string,
  subjectId: Uuid,
  file: File,
): Promise<string> {
  const suffix = file.name.split(".").pop()?.toLowerCase() ?? "jpg";
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const path = `${subjectType}/${subjectId}/${stamp}.${suffix}`;
  const { error } = await kernel()
    .storage.from(PHOTO_BUCKET)
    .upload(path, file, { upsert: false, contentType: file.type || "image/jpeg" });
  if (error) throw new KernelError(error);
  return path;
}

// `takenAt` is when the photograph was taken, which during harvest is hours
// before it is attached. Passing it is how the morning survives.
export async function attachPhoto(args: {
  subjectType: string;
  subjectId: Uuid;
  path: string;
  caption?: string | null;
  aboutEvent?: Uuid | null;
  takenAt?: string | null;
}): Promise<{ id: Uuid; already: boolean }> {
  const { data, error } = await kernel().rpc("attach_photo", {
    p_subject_type: args.subjectType,
    p_subject_id: args.subjectId,
    p_path: args.path,
    p_caption: args.caption ?? null,
    p_about_event: args.aboutEvent ?? null,
    p_taken_at: args.takenAt ?? null,
  });
  if (error) throw new KernelError(error);
  return data as { id: Uuid; already: boolean };
}

// Upload and attach as one call, for the ordinary case where both happen at
// once. The two halves stay separately callable because a retry after a lost
// connection needs to redo one of them and not the other.
export async function addPhoto(args: {
  subjectType: string;
  subjectId: Uuid;
  file: File;
  caption?: string | null;
  aboutEvent?: Uuid | null;
  takenAt?: string | null;
}): Promise<{ id: Uuid; already: boolean; path: string }> {
  const path = await uploadPhoto(args.subjectType, args.subjectId, args.file);
  const out = await attachPhoto({ ...args, path });
  return { ...out, path };
}

/** The whole contract in one call. Written for a second periphery and useful
 * to this one: anything that needs a list of what can be done should read it
 * here rather than keeping its own. */
export async function contract(): Promise<Contract> {
  const { data, error } = await kernel().rpc("contract");
  if (error) throw new KernelError(error);
  return data as Contract;
}

// --- sampling --------------------------------------------------------------

export async function samples(
  subjectType?: string,
  subjectId?: Uuid,
  kinds?: SampleKind[],
): Promise<Sample[]> {
  let q = kernel()
    .from("sample")
    .select(
      "event_id,subject_type,subject_id,of_what,at,note,by_name,readings,kind,node_id,lot_name,vintage,non_vintage,variety,lot_owner_id,lot_owner_name",
    );
  if (subjectType) q = q.eq("subject_type", subjectType);
  if (subjectId) q = q.eq("subject_id", subjectId);
  // Filtered in the database rather than after the fact. The winemaker's reason
  // for the filter is that two vintages of barrel wine bury the ferments, and
  // fetching them all to throw them away on the phone is the same problem with
  // a longer wait in front of it.
  if (kinds && kinds.length > 0) q = q.in("kind", kinds);
  const { data, error } = await q.order("at", { ascending: false });
  if (error) throw new KernelError(error);
  return (data ?? []) as Sample[];
}

// What can be sampled, with the same kind on it. One read where the client used
// to make four and invent the groupings itself.
export async function sampleTargets(): Promise<SampleTarget[]> {
  const { data, error } = await kernel()
    .from("sample_target")
    .select("kind,subject_type,subject_id,label,detail,grouping,sort_order")
    .order("sort_order")
    .order("label");
  if (error) throw new KernelError(error);
  return (data ?? []) as SampleTarget[];
}

/** Records the act. The readings are typed onto the event afterwards, which is
 * why the event id comes back. */
export async function takeSample(args: {
  subjectType: string;
  subjectId: Uuid;
  at?: string | null;
  note?: string | null;
}): Promise<{ event_id: Uuid; subject_type: string; subject_id: Uuid; of: string }> {
  const { data, error } = await kernel().rpc("take_sample", {
    p_subject_type: args.subjectType,
    p_subject_id: args.subjectId,
    p_at: args.at ?? null,
    p_note: args.note ?? null,
  });
  if (error) throw new KernelError(error);
  return data as {
    event_id: Uuid;
    subject_type: string;
    subject_id: Uuid;
    of: string;
  };
}

// --- notes -----------------------------------------------------------------

export async function notesFor(
  subjectType: string,
  subjectId: Uuid,
): Promise<SubjectNote[]> {
  const { data, error } = await kernel()
    .from("subject_note")
    .select("id,subject_type,subject_id,about_event,body,at,edited_at,by_name,by_user")
    .eq("subject_type", subjectType)
    .eq("subject_id", subjectId)
    .order("at", { ascending: false });
  if (error) throw new KernelError(error);
  return (data ?? []) as SubjectNote[];
}

export async function typedFacts(
  subjectType?: string,
  subjectId?: Uuid,
): Promise<TypedFact[]> {
  let q = kernel()
    .from("typed_fact")
    .select(
      "note_id,subject_type,subject_id,about_event,kind,kind_label,unit,value_num,value_text,value,body,provenance,at,by_name",
    );
  if (subjectType) q = q.eq("subject_type", subjectType);
  if (subjectId) q = q.eq("subject_id", subjectId);
  const { data, error } = await q.order("at", { ascending: false });
  if (error) throw new KernelError(error);
  return (data ?? []) as TypedFact[];
}

/** Give a note a kind and a value. The words stay. */
export async function typeNote(args: {
  noteId: Uuid;
  kind: string;
  valueNum?: number | null;
  valueText?: string | null;
}): Promise<{ id: Uuid; kind: string; label: string; value: string }> {
  const { data, error } = await kernel().rpc("type_note", {
    p_note_id: args.noteId,
    p_kind: args.kind,
    p_value_num: args.valueNum ?? null,
    p_value_text: args.valueText ?? null,
  });
  if (error) throw new KernelError(error);
  return data as { id: Uuid; kind: string; label: string; value: string };
}

/** Somebody checked it. T0-4: only a person does this, and who is recorded. */
export async function confirmNote(
  noteId: Uuid,
): Promise<{ id: Uuid; provenance: string; already: boolean }> {
  const { data, error } = await kernel().rpc("confirm_note", { p_note_id: noteId });
  if (error) throw new KernelError(error);
  return data as { id: Uuid; provenance: string; already: boolean };
}

export async function addNote(args: {
  subjectType: string;
  subjectId: Uuid;
  body: string;
  aboutEvent?: Uuid | null;
  at?: string | null;
}): Promise<{ id: Uuid; at: string }> {
  const { data, error } = await kernel().rpc("add_note", {
    p_subject_type: args.subjectType,
    p_subject_id: args.subjectId,
    p_body: args.body,
    p_about_event: args.aboutEvent ?? null,
    p_at: args.at ?? null,
  });
  if (error) throw new KernelError(error);
  return data as { id: Uuid; at: string };
}

/** The words can be corrected by whoever wrote them. Where it is filed cannot
 * move: the kernel refuses that, and refiling is writing a new one. */
export async function rewordNote(id: Uuid, body: string): Promise<void> {
  const { error } = await kernel().from("note").update({ body }).eq("id", id);
  if (error) throw new KernelError(error);
}

export async function attachmentsFor(
  subjectType: string,
  subjectId: Uuid,
): Promise<Attachment[]> {
  const { data, error } = await kernel()
    .from("attachment")
    .select("id,subject_type,subject_id,about_event,path,caption,by_user,at,created_at")
    .eq("subject_type", subjectType)
    .eq("subject_id", subjectId)
    .order("at", { ascending: false });
  if (error) throw new KernelError(error);
  return (data ?? []) as Attachment[];
}

// A caption can be corrected by whoever wrote it. Nothing else about a
// photograph can move; the kernel refuses that rather than this.
export async function captionPhoto(id: Uuid, caption: string): Promise<void> {
  const { error } = await kernel()
    .from("attachment")
    .update({ caption: caption.trim() === "" ? null : caption.trim() })
    .eq("id", id);
  if (error) throw new KernelError(error);
}

export async function weighingsWithoutPhoto(): Promise<WeighingWithoutPhoto[]> {
  const { data, error } = await kernel()
    .from("weighing_without_photo")
    .select("event_id,node_id,pick_name,at,net_lbs")
    .order("at", { ascending: false });
  if (error) throw new KernelError(error);
  return (data ?? []) as WeighingWithoutPhoto[];
}

// Which reading is live is the kernel's answer, computed by the `pick_weighing`
// view, because a screen working it out from a list of events would be a client
// encoding a kernel rule and the next client would encode it differently.
export async function pickWeighings(nodeId: Uuid): Promise<PastWeighing[]> {
  const { data, error } = await kernel()
    .from("pick_weighing")
    .select("event_id,at,gross_lbs,tare_lbs,net_lbs,bins,note,superseded,photos")
    .eq("node_id", nodeId)
    .order("at");
  if (error) throw new KernelError(error);
  return (data ?? []) as PastWeighing[];
}

// --- intake ----------------------------------------------------------------

// Build order 2, and the one where a missed record cannot be reconstructed. See
// migration 0033 for why a pick is one node and a weighing is an event.

export async function vineyards(): Promise<Vineyard[]> {
  const { data, error } = await kernel()
    .from("vineyard")
    .select("id,name,location,notes,created_at")
    .order("name");
  if (error) throw new KernelError(error);
  return (data ?? []) as Vineyard[];
}

export async function addVineyard(v: {
  id: Uuid;
  name: string;
  location?: string | null;
  notes?: string | null;
}): Promise<void> {
  const { error } = await kernel().from("vineyard").insert(v);
  if (error) throw new KernelError(error);
}

export async function updateVineyard(
  id: Uuid,
  patch: Partial<Omit<Vineyard, "id" | "created_at">>,
): Promise<void> {
  const { error } = await kernel().from("vineyard").update(patch).eq("id", id);
  if (error) throw new KernelError(error);
}

export async function blocks(): Promise<Block[]> {
  const { data, error } = await kernel()
    .from("block")
    .select(
      "id,vineyard_id,name,notes,acres,planted_year,clone,rootstock,spacing,trellis,aspect,elevation,soil",
    )
    .order("name");
  if (error) throw new KernelError(error);
  return (data ?? []) as Block[];
}

export async function updateBlock(
  id: Uuid,
  patch: Partial<Omit<Block, "id">>,
): Promise<void> {
  const { error } = await kernel().from("block").update(patch).eq("id", id);
  if (error) throw new KernelError(error);
}

// A variety in a block, with the block's answers where it has none of its own.
export async function plantings(blockId?: Uuid): Promise<PlantingDetail[]> {
  let q = kernel()
    .from("planting_detail")
    .select(
      "planting_id,block_id,block_name,vineyard_id,vineyard_name,variety_id,variety,notes,inherited,acres,planted_year,clone,rootstock,spacing,trellis,aspect,elevation,soil",
    );
  if (blockId) q = q.eq("block_id", blockId);
  const { data, error } = await q.order("block_name").order("variety");
  if (error) throw new KernelError(error);
  return (data ?? []) as PlantingDetail[];
}

export async function addPlanting(p: {
  id: Uuid;
  block_id: Uuid;
  variety_id: Uuid;
}): Promise<void> {
  const { error } = await kernel().from("planting").insert(p);
  if (error) throw new KernelError(error);
}

export async function updatePlanting(
  id: Uuid,
  patch: Record<string, unknown>,
): Promise<void> {
  const { error } = await kernel().from("planting").update(patch).eq("id", id);
  if (error) throw new KernelError(error);
}

export async function removePlanting(id: Uuid): Promise<void> {
  const { error } = await kernel().from("planting").delete().eq("id", id);
  if (error) throw new KernelError(error);
}

// S-51: block carries an admin-write policy, so a cellar hand gets a refusal
// here rather than a row. The refusal is legible, which is the most this can do
// until somebody decides who may name a vineyard.
export async function addBlock(block: {
  id: Uuid;
  vineyard_id: Uuid;
  name: string;
}): Promise<void> {
  const { error } = await kernel().from("block").insert(block);
  if (error) throw new KernelError(error);
}

// Picks that are still open: fruit at bin stage that has not been pressed away.
export async function openPicks(): Promise<Pick[]> {
  // `open_pick` rather than `node` with three filters. What counts as an open
  // pick is a rule, and it was in this function until 0057 asked what relation
  // the contract's `cellar.open_picks` names and the answer was "nothing, the
  // client works it out". See 0058 and R-4.
  const { data, error } = await kernel()
    .from("open_pick")
    .select("id,name,stage,status,vintage,block_id,variety_id,quantity,unit,created_at")
    .order("created_at", { ascending: false });
  if (error) throw new KernelError(error);
  return (data ?? []) as Pick[];
}

// --- a press as a process ---------------------------------------------------

// Three calls where there used to be one, because a press takes hours and
// nobody knows the litres before they have pressed. See migration 0052.

export async function pressesInProgress(): Promise<PressInProgress[]> {
  const { data, error } = await kernel()
    .from("press_in_progress")
    .select(
      "node_id,name,started_at,press_vessel_id,press_name,lbs_in,cuts,litres_so_far",
    )
    .order("started_at");
  if (error) throw new KernelError(error);
  return (data ?? []) as PressInProgress[];
}

// Every draw, or every draw off one press. Newest is not assumed: the caller
// orders it, because the log layout wants newest first and a report wants the
// morning in the order it happened.
export async function pressDraws(loadId?: Uuid): Promise<PressDraw[]> {
  let q = kernel()
    .from("press_draw")
    .select(
      "event_id,load_id,cut_id,cut_name,cut_label,at,volume_l,vessel_id,vessel_name,note,by_name,superseded",
    );
  if (loadId) q = q.eq("load_id", loadId);
  const { data, error } = await q.order("at");
  if (error) throw new KernelError(error);
  return (data ?? []) as PressDraw[];
}

export async function startPress(args: {
  // 0090. Vessels, not lots: a press is loaded from bins, and the lots are read
  // off them. The kernel's parameter was renamed so every caller had to be
  // revisited, and this one was missed, because an rpc argument is a string and
  // nothing typechecks it.
  vesselIds: Uuid[];
  pressVesselId: Uuid;
  node?: Record<string, unknown>;
  detail?: Record<string, unknown>;
}): Promise<PressStarted> {
  const { data, error } = await kernel().rpc("start_press", {
    p_vessel_ids: args.vesselIds,
    p_press_vessel_id: args.pressVesselId,
    p_node: args.node ?? {},
    p_detail: args.detail ?? {},
  });
  if (error) throw new KernelError(error);
  return data as PressStarted;
}

// Repeatable, deliberately. Drawing the same cut into the same vessel again is
// that cut getting bigger, which is what "update the liters multiple times"
// means.
export async function drawCut(args: {
  loadId: Uuid;
  vesselId: Uuid;
  volumeL: number;
  cutId?: Uuid | null;
  name?: string | null;
  note?: string | null;
}): Promise<CutDrawn> {
  const { data, error } = await kernel().rpc("draw_cut", {
    p_load_id: args.loadId,
    p_vessel_id: args.vesselId,
    p_volume_l: args.volumeL,
    p_cut_id: args.cutId ?? null,
    p_name: args.name ?? null,
    p_note: args.note ?? null,
  });
  if (error) throw new KernelError(error);
  return data as CutDrawn;
}

// The other way of working. `drawCut` asks what came off since last time, which
// is subtraction in somebody's head against a number they last saw an hour ago.
// This asks what the receiving tank reads now, which is one number read off a
// gauge in front of them. The subtraction happens in the kernel, because two
// clients doing it slightly differently would disagree about how much wine
// exists.
export async function drawToLevel(args: {
  loadId: Uuid;
  vesselId: Uuid;
  levelL: number;
  cutId?: Uuid | null;
  note?: string | null;
}): Promise<LevelDrawn> {
  const { data, error } = await kernel().rpc("draw_to_level", {
    p_load_id: args.loadId,
    p_vessel_id: args.vesselId,
    p_level_l: args.levelL,
    p_cut_id: args.cutId ?? null,
    p_note: args.note ?? null,
  });
  if (error) throw new KernelError(error);
  return data as LevelDrawn;
}

export async function finishPress(
  loadId: Uuid,
  detail?: Record<string, unknown>,
): Promise<PressFinished> {
  const { data, error } = await kernel().rpc("finish_press", {
    p_load_id: loadId,
    p_detail: detail ?? {},
  });
  if (error) throw new KernelError(error);
  return data as PressFinished;
}

// --- additions -------------------------------------------------------------

export async function suppliesForAddition(): Promise<SupplyForAddition[]> {
  const { data, error } = await kernel()
    .from("supply_for_addition")
    .select("supply_id,name,unit,on_hand,counted_at,supplier")
    .order("name");
  if (error) throw new KernelError(error);
  return (data ?? []) as SupplyForAddition[];
}

// Vessels rather than a lot, because an addition is made to what is in front of
// somebody. A lot spread across three barrels and dosed in one of them is not
// an addition to the other two, and the kernel refuses vessels holding
// different wine rather than averaging across them.
export async function addToWine(args: {
  vesselIds: Uuid[];
  amount: number;
  unit: string;
  supplyId?: Uuid | null;
  what?: string | null;
  at?: string | null;
  note?: string | null;
}): Promise<AdditionResult> {
  const { data, error } = await kernel().rpc("add_to_wine", {
    p_vessel_ids: args.vesselIds,
    p_amount: args.amount,
    p_unit: args.unit,
    p_supply_id: args.supplyId ?? null,
    p_what: args.what ?? null,
    p_at: args.at ?? null,
    p_note: args.note ?? null,
  });
  if (error) throw new KernelError(error);
  return data as AdditionResult;
}

export async function lotAdditions(nodeId?: Uuid): Promise<LotAddition[]> {
  let q = kernel()
    .from("lot_addition")
    .select(
      "event_id,node_id,lot_name,at,what,supply_id,amount,unit,note,vessels,volume_l,per_litre,took_from_the_shelf",
    );
  if (nodeId) q = q.eq("node_id", nodeId);
  const { data, error } = await q.order("at", { ascending: false });
  if (error) throw new KernelError(error);
  return (data ?? []) as LotAddition[];
}

// --- vintages --------------------------------------------------------------

// Lots that say neither a year nor NV. Only rows older than 0049 can be here,
// because the constraint refuses any new one.
export async function lotsWithoutVintage(): Promise<LotWithoutVintage[]> {
  const { data, error } = await kernel()
    .from("lot_without_vintage")
    .select("id,name,stage,status,created_at,year_in_the_name,suggested_year")
    .order("created_at");
  if (error) throw new KernelError(error);
  return (data ?? []) as LotWithoutVintage[];
}

// The one blessed way to answer. The check constraint is the guarantee and this
// is the voice: a constraint name arriving in front of somebody at a press is
// not a refusal anybody can act on.
export async function setVintage(
  nodeId: Uuid,
  vintage: number | null,
  nonVintage: boolean,
): Promise<{ id: Uuid; vintage: number | null; non_vintage: boolean; left: number }> {
  const { data, error } = await kernel().rpc("set_vintage", {
    p_node_id: nodeId,
    p_vintage: vintage,
    p_non_vintage: nonVintage,
  });
  if (error) throw new KernelError(error);
  return data as {
    id: Uuid;
    vintage: number | null;
    non_vintage: boolean;
    left: number;
  };
}

// Any pick, open or closed. `openPicks` is the work list and correctly hides a
// pick that has been pressed; a photograph of that pick's scale is still worth
// attaching the week after, which is why this does not filter on status.
export async function pickById(id: Uuid): Promise<Pick | null> {
  const { data, error } = await kernel()
    .from("node")
    .select("id,name,stage,status,vintage,block_id,variety_id,quantity,unit,created_at")
    .eq("id", id)
    .maybeSingle();
  if (error) throw new KernelError(error);
  return (data ?? null) as Pick | null;
}

// One tap in a vineyard. Safe to repeat: the pick id is generated here, so a
// phone that is unsure whether the call landed can send it again and find the
// bin already recorded rather than creating a second pick.
export async function addBinToPick(args: {
  pick: {
    id: Uuid;
    block_id?: Uuid | null;
    variety_id?: Uuid | null;
    vintage?: number | null;
    name?: string | null;
    owner_id?: Uuid | null;
  };
  vesselId: Uuid;
  // One of the two, never both: the kernel refuses a bin that says pounds and
  // says how full, because one of them would be a guess written next to a
  // figure somebody actually gave.
  // At most one of the three: the fruit, the scale reading with the bin on it,
  // or how full. 923 on a pallet scale is the bin as well as the fruit, and the
  // kernel refuses a row that says two of them.
  fillPct: number | null;
  netLbs?: number | null;
  grossLbs?: number | null;
}): Promise<{ node_id: Uuid; placement_id: Uuid; bins: number; unweighed: number }> {
  const { data, error } = await kernel().rpc("add_bin_to_pick", {
    p_pick: args.pick,
    p_vessel_id: args.vesselId,
    p_fill_pct: args.fillPct,
    p_net_lbs: args.netLbs ?? null,
    p_gross_lbs: args.grossLbs ?? null,
  });
  if (error) throw new KernelError(error);
  return data as { node_id: Uuid; placement_id: Uuid; bins: number; unweighed: number };
}

// One scale reading, however many bins were on it. `supersedes` is how a
// misread number is corrected: the kernel writes a new event naming the old one
// and recomputes the total, so nothing is edited and nothing double counts.
export async function weighBins(args: {
  nodeId: Uuid;
  vesselIds: Uuid[];
  grossLbs: number;
  note?: string | null;
  supersedes?: Uuid | null;
  // Wanted, not required. `0042` put this in the kernel and nothing passed it
  // for two days, which is how a photograph nobody could upload became three
  // photographs sitting on a phone.
  photoPath?: string | null;
}): Promise<Weighing> {
  const { data, error } = await kernel().rpc("weigh_bins", {
    p_node_id: args.nodeId,
    p_vessel_ids: args.vesselIds,
    p_gross_lbs: args.grossLbs,
    p_note: args.note ?? null,
    p_supersedes: args.supersedes ?? null,
    p_photo_path: args.photoPath ?? null,
  });
  if (error) throw new KernelError(error);
  return data as Weighing;
}

// The list that has to be empty before a pick is finished. Whole-cellar by
// default, because "is anything out there unweighed" is the question somebody
// asks at the end of the day without knowing which pick to look at.
export async function unweighedBins(nodeId?: Uuid): Promise<UnweighedBin[]> {
  let q = kernel()
    .from("unweighed_bin")
    .select("node_id,pick_name,vessel_id,bin_name,bin_type,fill_pct,filled_at");
  if (nodeId) q = q.eq("node_id", nodeId);
  const { data, error } = await q.order("filled_at");
  if (error) throw new KernelError(error);
  return (data ?? []) as UnweighedBin[];
}

// --- press -----------------------------------------------------------------

// Build order 3: where lots acquire their identity. See migration 0034. The
// stage the child lands at is the kernel's answer, not a choice here: fruit in
// bins presses to a ferment, a ferment presses to maturation.
export async function press(args: {
  sources: Array<{ node_id: Uuid; weight_lbs?: number | null }>;
  // One entry per cut. A press with nothing to say about cuts is a single entry
  // with no cut_id, which is what this did before 0045.
  cuts: Array<{
    cut_id?: Uuid | null;
    name?: string | null;
    destinations: Array<{ vessel_id: Uuid; volume_l: number }>;
  }>;
  node?: { name?: string | null; attributes?: Record<string, unknown> };
  // program, whole_cluster_pct, skin_contact_start, skin_contact_end,
  // temperature_c, note. All optional: a press nobody timed is still a press.
  detail?: Record<string, unknown>;
}): Promise<PressResult> {
  const { data, error } = await kernel().rpc("press", {
    p_sources: args.sources,
    p_cuts: args.cuts,
    p_node: args.node ?? {},
    p_detail: args.detail ?? {},
  });
  if (error) throw new KernelError(error);
  return data as PressResult;
}

// Borrowed bins with nothing in them. Empty is not the same as available.
export async function binsToReturn(): Promise<BinToReturn[]> {
  const { data, error } = await kernel()
    .from("bin_to_return")
    .select("vessel_id,bin_name,bin_type,owner_id,owed_to,location_id")
    .order("bin_name");
  if (error) throw new KernelError(error);
  return (data ?? []) as BinToReturn[];
}

// Bins arrive by the stack. Registering three and putting them on the same pick
// is one call, atomic, and the numbering is the kernel's rule rather than a
// client's guess: see 0035.
export async function addBinsToPick(args: {
  pick: Record<string, unknown>;
  vesselIds?: Uuid[];
  newCount?: number;
  newTypeId?: Uuid;
  namePrefix?: string;
  fillPct: number | null;
  // Whose bins. A party where the owner has standing here, a name where the
  // grower is somebody you only buy fruit from. The kernel refuses both at
  // once, because they are two different situations. See 0036.
  ownerId?: Uuid | null;
  onLoanFrom?: string | null;
  netLbs?: number | null;
  grossLbs?: number | null;
}): Promise<{ node_id: Uuid; registered: string[]; bins: number; unweighed: number }> {
  const { data, error } = await kernel().rpc("add_bins_to_pick", {
    p_pick: args.pick,
    p_vessel_ids: args.vesselIds ?? null,
    p_new_count: args.newCount ?? 0,
    p_new_type_id: args.newTypeId ?? null,
    p_name_prefix: args.namePrefix ?? null,
    p_fill_pct: args.fillPct,
    p_owner_id: args.ownerId ?? null,
    p_on_loan_from: args.onLoanFrom ?? null,
    p_net_lbs: args.netLbs ?? null,
    p_gross_lbs: args.grossLbs ?? null,
  });
  if (error) throw new KernelError(error);
  return data as {
    node_id: Uuid;
    registered: string[];
    bins: number;
    unweighed: number;
  };
}

// --- export ----------------------------------------------------------------

// Everything the caller may read, as one document. Runs as the caller, so row
// level security applies: two people get two different files and both are
// correct. Not a backup, which is pg_dump and lives in scripts/. See 0037 and
// sorry S-54.
export type CellarExport = {
  exported_at: string;
  by: Uuid | null;
  rows: number;
  table_count: number;
  tables: Record<string, unknown[]>;
};

export async function exportCellar(): Promise<CellarExport> {
  const { data, error } = await kernel().rpc("export_cellar");
  if (error) throw new KernelError(error);
  return data as CellarExport;
}

// --- cancelling a pick -----------------------------------------------------

// The fruit did not come, or the wrong block was tapped. Frees the bins, takes
// the pick off the list, and keeps every weighing, because a weighing is an
// observation and observations are not unmade. See 0038.
export async function cancelPick(
  nodeId: Uuid,
  reason?: string | null,
): Promise<{ node_id: Uuid; bins_freed: number; weighings_kept: number }> {
  const { data, error } = await kernel().rpc("cancel_pick", {
    p_node_id: nodeId,
    p_reason: reason ?? null,
  });
  if (error) throw new KernelError(error);
  return data as { node_id: Uuid; bins_freed: number; weighings_kept: number };
}

// Narrow on purpose: a cancelled pick, nothing weighed into it, nothing
// descending from it. Such a row holds no observation, which is the only
// condition under which deleting it destroys no record. Administrators only.
export async function removePick(nodeId: Uuid): Promise<void> {
  const { error } = await kernel().rpc("remove_pick", { p_node_id: nodeId });
  if (error) throw new KernelError(error);
}

// --- the day ---------------------------------------------------------------

// What happened on a day, asked rather than stored. Runs as the caller, so two
// people get two different days and both are correct. See 0041.
export async function dayLog(on?: string): Promise<DayEntry[]> {
  const { data, error } = await kernel().rpc("day_log", { p_on: on ?? null });
  if (error) throw new KernelError(error);
  return (data ?? []) as DayEntry[];
}

export async function dayNotes(on: string): Promise<DayNote[]> {
  const { data, error } = await kernel()
    .from("day_note")
    .select("id,on_date,body,private,author_id,created_at")
    .eq("on_date", on)
    .order("created_at");
  if (error) throw new KernelError(error);
  return (data ?? []) as DayNote[];
}

// The author is written here rather than defaulted in the database, because the
// insert policy requires it to be the caller: a note nobody signed is a note
// nobody can be asked about.
export async function addDayNote(note: {
  id: Uuid;
  on_date: string;
  body: string;
  private: boolean;
  author_id: Uuid;
}): Promise<void> {
  const { error } = await kernel().from("day_note").insert(note);
  if (error) throw new KernelError(error);
}

export async function removeDayNote(id: Uuid): Promise<void> {
  const { error } = await kernel().from("day_note").delete().eq("id", id);
  if (error) throw new KernelError(error);
}

// --- what is owed to paper -------------------------------------------------

// See migration 0043. The queue is derived, so it cannot be forgotten to update
// and cannot disagree with what has actually been written down.

export async function paperRecords(): Promise<PaperRecord[]> {
  const { data, error } = await kernel()
    .from("paper_record")
    .select("id,name,notes,effective_from,retired_at,created_at")
    .order("name");
  if (error) throw new KernelError(error);
  return (data ?? []) as PaperRecord[];
}

export async function addPaperRecord(record: {
  id: Uuid;
  name: string;
  notes?: string | null;
}): Promise<void> {
  const { error } = await kernel().from("paper_record").insert(record);
  if (error) throw new KernelError(error);
}

// Retired, never deleted, which is why this sets a date rather than removing a
// row: the obligations it created while it was being kept are still real.
export async function retirePaperRecord(id: Uuid, retired: boolean): Promise<void> {
  const { error } = await kernel()
    .from("paper_record")
    .update({ retired_at: retired ? new Date().toISOString() : null })
    .eq("id", id);
  if (error) throw new KernelError(error);
}

export async function paperRecordOperations(id: Uuid): Promise<Uuid[]> {
  const { data, error } = await kernel()
    .from("paper_record_operation")
    .select("operation_id")
    .eq("paper_record_id", id);
  if (error) throw new KernelError(error);
  return ((data ?? []) as Array<{ operation_id: Uuid }>).map((r) => r.operation_id);
}

// Replaces the list rather than diffing it, because the list is short and a
// diff is a second opinion about what the caller meant.
export async function setPaperRecordOperations(
  id: Uuid,
  operationIds: Uuid[],
): Promise<void> {
  const { error } = await kernel()
    .from("paper_record_operation")
    .delete()
    .eq("paper_record_id", id);
  if (error) throw new KernelError(error);
  if (operationIds.length === 0) return;
  const { error: writeError } = await kernel()
    .from("paper_record_operation")
    .insert(
      operationIds.map((operation_id) => ({ paper_record_id: id, operation_id })),
    );
  if (writeError) throw new KernelError(writeError);
}

export async function toPropagate(): Promise<ToPropagate[]> {
  const { data, error } = await kernel()
    .from("measurement_to_propagate")
    .select(
      "event_id,paper_record_id,paper_record,at,operation,subject,data,provenance",
    )
    .order("at");
  if (error) throw new KernelError(error);
  return (data ?? []) as ToPropagate[];
}

// Somebody wrote it on the form. The author is written here rather than
// defaulted, because the insert policy requires it to be the caller: a tick
// nobody signed is a tick nobody can be asked about.
export async function markPropagated(args: {
  eventId: Uuid;
  paperRecordId: Uuid;
  writtenBy: Uuid;
}): Promise<void> {
  const { error } = await kernel().from("propagation").insert({
    event_id: args.eventId,
    paper_record_id: args.paperRecordId,
    written_by: args.writtenBy,
  });
  if (error) throw new KernelError(error);
}

// What a maker builds. 0032 made this a set so somebody who builds both barrels
// and tanks is entered once and flagged twice, and then nothing could set it:
// the only way to create a maker was the inline add on a vessel form, which
// stamps whichever kind that form happens to be. This is the missing half.
//
// A maker written before 0032 carries a single `contract` string. Writing the
// set removes it rather than leaving both, because two ways of saying the same
// thing is how they come to disagree.
export async function setMakerMakes(makerId: Uuid, makes: string[]): Promise<void> {
  const { data, error } = await kernel()
    .from("term")
    .select("attributes")
    .eq("id", makerId)
    .single();
  if (error) throw new KernelError(error);
  const attributes: Record<string, unknown> = {
    ...((data as { attributes: Record<string, unknown> }).attributes ?? {}),
  };
  attributes.makes = makes;
  delete attributes.contract;
  const { error: writeError } = await kernel()
    .from("term")
    .update({ attributes })
    .eq("id", makerId);
  if (writeError) throw new KernelError(writeError);
}

// --- the stores ------------------------------------------------------------

export async function suppliesOnHand(): Promise<SupplyOnHand[]> {
  const { data, error } = await kernel()
    .from("supply_on_hand")
    .select(
      "supply_id,name,kinds,unit,reorder_level,supplier,retired_at,counted_at,on_hand,broken",
    )
    .order("name");
  if (error) throw new KernelError(error);
  return (data ?? []) as SupplyOnHand[];
}

// A suggestion, not the list. Under the level somebody set, and not already on
// the shopping list, because a prompt that keeps prompting becomes noise.
export async function suppliesBelowLevel(): Promise<SupplyOnHand[]> {
  const { data, error } = await kernel()
    .from("supply_below_level")
    .select(
      "supply_id,name,kinds,unit,reorder_level,supplier,retired_at,counted_at,on_hand,broken",
    )
    .order("name");
  if (error) throw new KernelError(error);
  return (data ?? []) as SupplyOnHand[];
}

export async function addSupply(supply: {
  id: Uuid;
  name: string;
  unit: string;
  reorder_level?: number | null;
  supplier?: string | null;
}): Promise<void> {
  const { error } = await kernel().from("supply").insert(supply);
  if (error) throw new KernelError(error);
}

export async function updateSupply(
  id: Uuid,
  patch: { reorder_level?: number | null; supplier?: string | null; unit?: string },
): Promise<void> {
  const { error } = await kernel().from("supply").update(patch).eq("id", id);
  if (error) throw new KernelError(error);
}

// Received, used or discarded. A count goes through `countSupply` instead,
// because a count has to read what was expected before it writes.
export async function moveSupply(args: {
  supplyId: Uuid;
  kind: "received" | "used" | "discarded" | "broken" | "repaired";
  quantity: number;
  note?: string | null;
  byUser: Uuid;
}): Promise<void> {
  const { error } = await kernel()
    .from("supply_movement")
    .insert({
      supply_id: args.supplyId,
      kind: args.kind,
      quantity: args.quantity,
      note: args.note ?? null,
      by_user: args.byUser,
    });
  if (error) throw new KernelError(error);
}

// Returns what was found beside what was expected, so the screen can show the
// gap rather than quietly absorbing it.
export async function countSupply(
  supplyId: Uuid,
  counted: number,
  note?: string | null,
): Promise<SupplyCount> {
  const { data, error } = await kernel().rpc("count_supply", {
    p_supply_id: supplyId,
    p_counted: counted,
    p_note: note ?? null,
  });
  if (error) throw new KernelError(error);
  return data as SupplyCount;
}

export async function shoppingList(): Promise<ShoppingItem[]> {
  const { data, error } = await kernel()
    .from("shopping_item")
    .select("id,supply_id,what,quantity,note,added_by,bought_at,created_at")
    .is("bought_at", null)
    .order("created_at");
  if (error) throw new KernelError(error);
  return (data ?? []) as ShoppingItem[];
}

export async function addShoppingItem(item: {
  id: Uuid;
  what: string;
  supply_id?: Uuid | null;
  quantity?: string | null;
  added_by: Uuid;
}): Promise<void> {
  const { error } = await kernel().from("shopping_item").insert(item);
  if (error) throw new KernelError(error);
}

// Ticked off rather than deleted, so what was bought and when is still a record.
export async function markBought(id: Uuid): Promise<void> {
  const { error } = await kernel()
    .from("shopping_item")
    .update({ bought_at: new Date().toISOString() })
    .eq("id", id);
  if (error) throw new KernelError(error);
}

export async function removeShoppingItem(id: Uuid): Promise<void> {
  const { error } = await kernel().from("shopping_item").delete().eq("id", id);
  if (error) throw new KernelError(error);
}

// What sort of thing a supply is. Flags rather than a category, because the
// hose head is neither infrastructure nor consumable and a single category
// forces a wrong answer for exactly the things nobody anticipated. See 0046.
export async function supplyKinds(supplyId: Uuid): Promise<Uuid[]> {
  const { data, error } = await kernel()
    .from("supply_material_kind")
    .select("kind_id")
    .eq("supply_id", supplyId);
  if (error) throw new KernelError(error);
  return ((data ?? []) as Array<{ kind_id: Uuid }>).map((r) => r.kind_id);
}

// Replaces the set rather than diffing it. The list is short and a diff is a
// second opinion about what the caller meant.
export async function setSupplyKinds(supplyId: Uuid, kindIds: Uuid[]): Promise<void> {
  const { error } = await kernel()
    .from("supply_material_kind")
    .delete()
    .eq("supply_id", supplyId);
  if (error) throw new KernelError(error);
  if (kindIds.length === 0) return;
  const { error: writeError } = await kernel()
    .from("supply_material_kind")
    .insert(kindIds.map((kind_id) => ({ supply_id: supplyId, kind_id })));
  if (writeError) throw new KernelError(writeError);
}

// The vocabulary itself, which the winemaker asked to be editable: the category
// somebody needs is the one nobody wrote down in advance. Adding one already
// exists as `addTerm`, which the pickers use.
export async function renameTerm(id: Uuid, label: string): Promise<void> {
  const { error } = await kernel().from("term").update({ label }).eq("id", id);
  if (error) throw new KernelError(error);
}

// Retired rather than deleted, so a supply that was flagged with it keeps
// meaning what it meant.
export async function retireTerm(id: Uuid, active: boolean): Promise<void> {
  const { error } = await kernel().from("term").update({ active }).eq("id", id);
  if (error) throw new KernelError(error);
}

// --- colour ----------------------------------------------------------------

// "Obviously this is something we are missing in the wine type, which should be
// red/orange/rose/white." It is the fact a barrel's own colour is derived from,
// and no other field in the schema can answer it: five of six varieties here are
// white and Pinot Noir is made as a red, a rose and a blanc de noir.
export async function lotsWithoutColour(): Promise<LotWithoutColour[]> {
  const { data, error } = await kernel()
    .from("lot_without_colour")
    .select("id,name,stage,status,created_at,variety,likely")
    .order("created_at", { ascending: false });
  if (error) throw new KernelError(error);
  return (data ?? []) as LotWithoutColour[];
}

export async function setColour(
  nodeId: Uuid,
  colour: string,
): Promise<{ id: Uuid; colour: string; left: number }> {
  const { data, error } = await kernel().rpc("set_colour", {
    p_node_id: nodeId,
    p_colour: colour,
  });
  if (error) throw new KernelError(error);
  return data as { id: Uuid; colour: string; left: number };
}

export async function barrelColours(): Promise<BarrelColour[]> {
  const { data, error } = await kernel()
    .from("barrel_colour")
    .select(
      "id,name,colour,went_red_with,went_red_at,reconditioned_at,location_id,active",
    )
    .order("name");
  if (error) throw new KernelError(error);
  return (data ?? []) as BarrelColour[];
}

export async function colourConflicts(): Promise<ColourConflict[]> {
  const { data, error } = await kernel()
    .from("white_in_a_red_barrel")
    .select(
      "vessel_id,vessel,node_id,lot,lot_colour,went_red_with,went_red_at,filled_at",
    );
  if (error) throw new KernelError(error);
  return (data ?? []) as ColourConflict[];
}

// Asked before a fill, and answered by the kernel rather than worked out here.
// A client that decided this for itself would be a second implementation of the
// rule, and the two would disagree the first time somebody added a colour.
export async function barrelWarning(
  vesselId: Uuid,
  nodeId: Uuid,
): Promise<BarrelWarning> {
  const { data, error } = await kernel().rpc("barrel_warning", {
    p_vessel_id: vesselId,
    p_node_id: nodeId,
  });
  if (error) throw new KernelError(error);
  return (data ?? { warn: false }) as BarrelWarning;
}

// "It also belongs on the barrel, like for the red and white neutral barrels we
// purchase." A barrel bought used has no placements here and would otherwise
// read white, which is the one answer that could ruin a wine. Everything after
// the declaration still derives.
export async function declareBarrelColour(
  vesselId: Uuid,
  colour: "red" | "white",
  note: string | null,
): Promise<{ event: Uuid; vessel: Uuid; colour: string }> {
  const { data, error } = await kernel().rpc("declare_barrel_colour", {
    p_vessel_id: vesselId,
    p_colour: colour,
    p_note: note,
  });
  if (error) throw new KernelError(error);
  return data as { event: Uuid; vessel: Uuid; colour: string };
}

// A barrel that has held red is white again only because somebody shaved it,
// retoasted it or deep cleaned it, so the method is required and the kernel
// refuses without one.
export async function reconditionBarrel(
  vesselId: Uuid,
  method: string,
  note: string | null,
): Promise<{ event: Uuid; vessel: Uuid; method: string }> {
  const { data, error } = await kernel().rpc("recondition_barrel", {
    p_vessel_id: vesselId,
    p_method: method,
    p_note: note,
  });
  if (error) throw new KernelError(error);
  return data as { event: Uuid; vessel: Uuid; method: string };
}

// "I also need a way to edit (add/append only is fine) wine in vessels, like to
// add the color." One read rather than four, because a screen assembling a lot
// out of pieces is how two clients end up disagreeing about what a lot is.
export async function lotDetail(nodeId: Uuid): Promise<LotDetail[]> {
  const { data, error } = await kernel()
    .from("lot_detail")
    // One literal, deliberately: the client library derives the row type from
    // the text of this string, and a concatenation is opaque to it.
    .select(
      "id,name,stage,status,vintage,non_vintage,variety,product_type,colour,colour_label,colour_told,owner_id,owner_name,provenance,created_at,vessel_id,vessel,volume_l,filled_at",
    )
    .eq("id", nodeId);
  if (error) throw new KernelError(error);
  return (data ?? []) as LotDetail[];
}

// --- how a room is held ----------------------------------------------------

export async function rooms(): Promise<RoomClimate[]> {
  const { data, error } = await kernel()
    .from("room_climate")
    .select("id,name,kind,controlled,mode,ambient_c,vessels")
    .order("name");
  if (error) throw new KernelError(error);
  return (data ?? []) as RoomClimate[];
}

// Saying which way a room is held also says it is held, which is why this is one
// call and not an update to two columns from a screen.
export async function setRoomClimate(
  locationId: Uuid,
  mode: ThermalMode,
  ambientC: number | null,
): Promise<{ id: Uuid; mode: string; ambient_c: number | null }> {
  const { data, error } = await kernel().rpc("set_room_climate", {
    p_location_id: locationId,
    p_mode: mode,
    p_ambient_c: ambientC,
  });
  if (error) throw new KernelError(error);
  return data as { id: Uuid; mode: string; ambient_c: number | null };
}

// --- picking bins, as a stack ----------------------------------------------

export async function binInventory(): Promise<BinInventory[]> {
  const { data, error } = await kernel()
    .from("bin_inventory")
    .select("type_id,bin_type,whose,borrowed,bins,in_use,empty,capacity_l")
    .order("bin_type");
  if (error) throw new KernelError(error);
  return (data ?? []) as BinInventory[];
}

// "I'd rather just inventory and add as they don't really differ." A count and
// a prefix: the type, the capacity and the numbering all come from the stack
// that is already there.
export async function registerBins(args: {
  count: number;
  prefix?: string | null;
  onLoanFrom?: string | null;
  typeId?: Uuid | null;
}): Promise<{ registered: string[]; count: number; from: string; to: string }> {
  const { data, error } = await kernel().rpc("register_bins", {
    p_count: args.count,
    p_type_id: args.typeId ?? null,
    p_name_prefix: args.prefix ?? null,
    p_owner_id: null,
    p_on_loan_from: args.onLoanFrom ?? null,
  });
  if (error) throw new KernelError(error);
  return data as {
    registered: string[];
    count: number;
    from: string;
    to: string;
  };
}

// What is in each bin that has fruit in it, in whichever unit somebody wants.
// The conversion lives in the kernel: a client doing it would be a second
// opinion about what a full bin holds.
export async function binFruit(nodeId?: Uuid): Promise<BinFruit[]> {
  let q = kernel()
    .from("bin_fruit")
    .select(
      "placement_id,vessel_id,bin,node_id,pick,from_at,said_net,said_gross,said_pct,full_lbs,tare_lbs,lbs,gross,pct_full,tons,said_as,weighed_at",
    );
  if (nodeId) q = q.eq("node_id", nodeId);
  const { data, error } = await q.order("bin");
  if (error) throw new KernelError(error);
  return (data ?? []) as BinFruit[];
}

// "I'd love to be able to select 6 barrels to move to a new room, or put the 5
// picking bins in the south bay, without doing it individually." One call, one
// event per vessel, and the whole batch fails rather than part of it: six
// selected and five moved is a state nobody asked for and nobody would notice.
export async function moveVessels(
  vesselIds: Uuid[],
  locationId: Uuid,
): Promise<{ moved: number; location_id: Uuid; location: string }> {
  const { data, error } = await kernel().rpc("move_vessels", {
    p_vessel_ids: vesselIds,
    p_location_id: locationId,
  });
  if (error) throw new KernelError(error);
  return data as { moved: number; location_id: Uuid; location: string };
}

// One bin, corrected. The batch figure goes into every bin that went out
// together, which is right until somebody walks the row and sees the last one
// is half empty.
export async function setBinFruit(
  vesselId: Uuid,
  args: { netLbs?: number | null; grossLbs?: number | null; pct?: number | null },
): Promise<{
  vessel: Uuid;
  bin: string;
  lbs: number | null;
  gross: number | null;
  tare: number | null;
  tons: number | null;
}> {
  const { data, error } = await kernel().rpc("set_bin_fruit", {
    p_vessel_id: vesselId,
    p_net_lbs: args.netLbs ?? null,
    p_fill_pct: args.pct ?? null,
    p_gross_lbs: args.grossLbs ?? null,
  });
  if (error) throw new KernelError(error);
  return data as {
    vessel: Uuid;
    bin: string;
    lbs: number | null;
    gross: number | null;
    tare: number | null;
    tons: number | null;
  };
}

// The bins still holding fruit, by pick. What the press screen offers once
// somebody has chosen a pick: "click the Pearlstaad pick, then that brings up
// the 5 bins so I can select from them into the press".
export async function pickBins(nodeId?: Uuid): Promise<PickBin[]> {
  let q = kernel()
    .from("pick_bin")
    .select(
      "node_id,pick,status,vessel_id,bin,lbs,gross,tare_lbs,tons,said_as,pct_full,from_at",
    );
  if (nodeId) q = q.eq("node_id", nodeId);
  const { data, error } = await q.order("bin");
  if (error) throw new KernelError(error);
  return (data ?? []) as PickBin[];
}

// "A tab called running operations that has open things: press going, pick
// going, etc." One read, because the alternative is the five badges it replaces.
export async function running(): Promise<RunningOperation[]> {
  const { data, error } = await kernel()
    .from("running_operation")
    .select("kind,heading,what,detail,since,subject_type,subject_id")
    .order("since");
  if (error) throw new KernelError(error);
  return (data ?? []) as RunningOperation[];
}

// --- the hot list ----------------------------------------------------------

export async function watching(): Promise<Watching[]> {
  const { data, error } = await kernel()
    .from("watching")
    .select("subject_type,subject_id,what,expect,unit,note,since,by_name,so_far")
    .order("since", { ascending: false });
  if (error) throw new KernelError(error);
  return (data ?? []) as Watching[];
}

// "I imagine by the time it's finished it'll be more like 450 liters." A number
// he already has and the app had nowhere to put. Appended, so changing your
// mind is a second statement rather than an edit to the first.
export async function watchSubject(args: {
  subjectType: string;
  subjectId: Uuid;
  expect?: number | null;
  unit?: string | null;
  note?: string | null;
}): Promise<{ event: Uuid; what: string; expect: number | null }> {
  const { data, error } = await kernel().rpc("watch_subject", {
    p_subject_type: args.subjectType,
    p_subject_id: args.subjectId,
    p_expect: args.expect ?? null,
    p_unit: args.unit ?? null,
    p_note: args.note ?? null,
  });
  if (error) throw new KernelError(error);
  return data as { event: Uuid; what: string; expect: number | null };
}

export async function unwatchSubject(
  subjectType: string,
  subjectId: Uuid,
): Promise<{ event: Uuid; watching: boolean }> {
  const { data, error } = await kernel().rpc("unwatch_subject", {
    p_subject_type: subjectType,
    p_subject_id: subjectId,
  });
  if (error) throw new KernelError(error);
  return data as { event: Uuid; watching: boolean };
}
