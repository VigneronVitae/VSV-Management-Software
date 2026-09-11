// The PWA shell that mounts modules. Holds routing and the shell itself, and
// no domain logic: that belongs to the module it came from.
//
// There is no shell yet, and no module mounting. This session builds one skin
// over the kernel and a later session builds the thing that hosts several.
import { mountWalk, restoreSkin } from "cellar";
import { MissingConfig, readConfig } from "core";

const target = document.querySelector<HTMLElement>("#app");

if (!target) {
  throw new Error("#app is missing from index.html");
}

// Before the first paint, so nobody watches one skin repaint into another.
restoreSkin();

try {
  readConfig();
  mountWalk(target);
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
