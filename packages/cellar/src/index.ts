// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The cellar module's public face. Design lives in docs/spec.md
//           alongside this file."
// Depends on: [packages/cellar/src/ui.ts, packages/cellar/docs/spec.md]
// Depended on by: [apps/web/src/index.ts]
// ---------------------------------------------------------------------------
// The cellar module. Design lives in docs/spec.md alongside this file.
// May import from `core`. May never import from a sibling module.

export { watchForInstall } from "./install.ts";
export { restoreSkin } from "./skins.ts";
export { mountWalk } from "./walk.ts";
