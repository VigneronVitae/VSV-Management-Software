// ---------------------------------------------------------------------------
// Type: source
// Purpose: "Core's public face. Everything a second module would also need
//           belongs here; anything only one module needs does not."
// Depends on: [packages/core/src/env.ts, packages/core/src/where.ts,
//              packages/core/src/ui.ts, packages/core/src/xlsx.ts,
//              supabase/functions/agent/index.ts]
// Depended on by: [packages/cellar/src/index.ts]
// ---------------------------------------------------------------------------
// Shared across modules: kernel access, auth, and the row shapes the screens
// touch. Anything a second module would also need belongs here; anything only
// one module needs does not.
export * from "./env.ts";
export * from "./kernel.ts";
export * from "./types.ts";
// The DOM primitives, here since the shop module needed them too. See ui.ts.
export * from "./ui.ts";
export * from "./where.ts";
// The spreadsheet writer, here since the vineyard needed it too. See xlsx.ts.
export * from "./xlsx.ts";
