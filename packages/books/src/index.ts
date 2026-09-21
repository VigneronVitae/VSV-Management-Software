// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The books module's public face."
// Depends on: [packages/books/src/books.ts]
// Depended on by: [apps/books/src/index.ts]
// ---------------------------------------------------------------------------
// The books module. Money that has already moved, and what somebody says it
// was for. May import from `core`. May never import from a sibling module.

export { mountBooks } from "./books.ts";
