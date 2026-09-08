import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { readConfig } from "./env.ts";
import type {
  AppUser,
  CodePayload,
  EventRow,
  Location,
  NodePayload,
  Party,
  Term,
  TermKind,
  Uuid,
  VesselPayload,
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

function unwrap<T>(result: { data: T | null; error: { message: string } | null }): T {
  if (result.error) throw new Error(result.error.message);
  if (result.data === null) throw new Error("no data returned");
  return result.data;
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
export async function claimAccount(name: string): Promise<AppUser> {
  return unwrap(await kernel().rpc("claim_account", { p_name: name }).single());
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
