// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The vineyard module's public face."
// Depends on: [packages/vineyard/src/vineyard.ts,
//              supabase/migrations/0164_a_claim_says_where_it_came_from.sql,
//              supabase/migrations/0165_what_each_row_is_said_to_be.sql]
// Depended on by: [apps/vineyard/src/index.ts]
// ---------------------------------------------------------------------------
// The vineyard module. Blocks, rows, and the vine standing in each position.
// May import from `core`. May never import from a sibling module.

export { mountVineyard } from "./vineyard.ts";
