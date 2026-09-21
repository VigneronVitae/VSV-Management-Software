// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The cellar module's public face. Design lives in docs/spec.md
//           alongside this file."
// Depends on: [packages/cellar/src/ui.ts, packages/cellar/docs/spec.md,
//              supabase/migrations/0139_a_gas_is_a_term.sql,
//              supabase/migrations/0140_wine_can_go_on_the_ground.sql,
//              supabase/migrations/0141_a_volume_says_whether_it_was_measured.sql]
// Depended on by: [apps/web/src/index.ts]
// ---------------------------------------------------------------------------
// The cellar module. Design lives in docs/spec.md alongside this file.
// May import from `core`. May never import from a sibling module.

export { watchForInstall } from "./install.ts";
export { restoreSkin } from "./skins.ts";
export { mountWalk } from "./walk.ts";
