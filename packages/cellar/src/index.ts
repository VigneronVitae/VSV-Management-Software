// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The cellar module's public face. Design lives in docs/spec.md
//           alongside this file."
// Depends on: [packages/cellar/src/ui.ts, packages/cellar/docs/spec.md,
//              packages/cellar/src/xlsx.ts,
//              supabase/migrations/0139_a_gas_is_a_term.sql,
//              supabase/migrations/0140_wine_can_go_on_the_ground.sql,
//              supabase/migrations/0141_a_volume_says_whether_it_was_measured.sql,
//              supabase/migrations/0142_a_dump_says_why.sql,
//              supabase/migrations/0143_a_record_can_say_when.sql,
//              supabase/migrations/0146_harvest_weights.sql,
//              supabase/migrations/0148_reds_go_into_fermenters.sql,
//              supabase/migrations/0150_off_the_skins.sql,
//              supabase/migrations/0152_who_may_do_what.sql,
//             packages/core/src/index.ts]
// Depended on by: [apps/web/src/index.ts]
// ---------------------------------------------------------------------------
// The cellar module. Design lives in docs/spec.md alongside this file.
// May import from `core`. May never import from a sibling module.

export { watchForInstall } from "./install.ts";
export { restoreSkin } from "./skins.ts";
export { mountWalk } from "./walk.ts";
