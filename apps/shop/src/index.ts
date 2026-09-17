// The shop shell. Mounts one module and holds no domain logic, the same way the
// cellar shell does.
//
// This is the second periphery, and the winemaker's reason for wanting it is
// that two peripheries find problems one does not: a single client can lean on
// knowledge it never wrote down, and the second one cannot.
import { MissingConfig, readConfig } from "core";
import { mountShop } from "shop";

const target = document.querySelector<HTMLElement>("#app");

if (!target) {
  throw new Error("#app is missing from index.html");
}

try {
  readConfig();
  mountShop(target);
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
