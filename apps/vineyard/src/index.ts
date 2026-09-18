// The vineyard shell. Mounts one module and holds no domain logic, the same way
// the cellar and shop shells do.
import { MissingConfig, readConfig } from "core";
import { mountVineyard } from "vineyard";

const target = document.querySelector<HTMLElement>("#app");

if (!target) {
  throw new Error("#app is missing from index.html");
}

try {
  readConfig();
  mountVineyard(target);
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
