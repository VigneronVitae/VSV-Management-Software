// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The stores shell. Mounts one module and holds no domain logic."
// Depends on: [packages/inventory/src/index.ts]
// Depended on by: [docs/status-ledger.md]
// ---------------------------------------------------------------------------
import { MissingConfig, readConfig } from "core";
import { mountInventory } from "inventory";

const target = document.querySelector<HTMLElement>("#app");

if (!target) {
  throw new Error("#app is missing from index.html");
}

try {
  readConfig();
  mountInventory(target);
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
