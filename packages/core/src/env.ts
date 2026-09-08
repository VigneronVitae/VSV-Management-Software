// Vite substitutes these at build time. Declared here rather than pulling in
// vite/client so that core stays buildable by anything, not just by vite.
declare global {
  interface ImportMeta {
    readonly env: Record<string, string | undefined>;
  }
}

export type KernelConfig = {
  url: string;
  anonKey: string;
};

export class MissingConfig extends Error {}

export function readConfig(): KernelConfig {
  const url = import.meta.env.VITE_SUPABASE_URL;
  const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    throw new MissingConfig(
      "Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in apps/web/.env.local. " +
        "See apps/web/.env.example.",
    );
  }
  return { url, anonKey };
}
