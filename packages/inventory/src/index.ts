// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The inventory module's public face."
// Depends on: [packages/inventory/src/inventory.ts]
// Depended on by: [apps/inventory/src/index.ts]
// ---------------------------------------------------------------------------
// The inventory module. Things we have, where they live, and what each place is
// for. May import from `core`. May never import from a sibling module.

export { mountInventory } from "./inventory.ts";
