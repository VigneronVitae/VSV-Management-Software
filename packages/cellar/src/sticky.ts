// A sticky value per field, remembering what was entered last this session.
// In memory only: nothing is persisted, and a reload starts clean.
//
// Fifty vessels is an hour of work, not a day, so this is as clever as session
// defaults get. Anything more would be a preferences system nobody asked for.

const values = new Map<string, string>();
const pinned = new Set<string>();

export function isPinned(key: string): boolean {
  return pinned.has(key);
}

export function stickyValue(key: string): string {
  return pinned.has(key) ? (values.get(key) ?? "") : "";
}

export function remember(key: string, value: string): void {
  if (pinned.has(key)) values.set(key, value);
}

export function setPinned(key: string, value: boolean, current: string): void {
  if (value) {
    pinned.add(key);
    values.set(key, current);
  } else {
    pinned.delete(key);
    values.delete(key);
  }
}

export function clearAll(): void {
  values.clear();
  pinned.clear();
}
