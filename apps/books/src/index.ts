// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The books shell. Mounts one module and holds no domain logic."
// Depends on: [packages/books/src/index.ts]
// Depended on by: [docs/status-ledger.md]
// ---------------------------------------------------------------------------
// The books shell. Mounts one module and holds no domain logic, the same way
// the cellar, shop and vineyard shells do.

import { mountBooks } from "books";
import { MissingConfig, readConfig } from "core";

const target = document.querySelector<HTMLElement>("#app");

if (!target) {
  throw new Error("#app is missing from index.html");
}

try {
  readConfig();
  mountBooks(target);
} catch (error) {
  const message =
    error instanceof MissingConfig
      ? error.message
      : `Could not start: ${(error as Error).message}`;
  const p = document.createElement("p");
  p.className = "banner banner-error";
  p.textContent = message;
  target.append(p);
}
