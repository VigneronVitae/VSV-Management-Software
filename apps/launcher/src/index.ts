// The front door. Lists what this winery has and lets somebody open it.
//
// "Could we have /cellar/ be the cellar one and the root be the chooser that you
// pick cellar/shop/inventory/marketing/get new modules/etc?"
//
// Holds no domain logic and almost no knowledge: the list comes from the module
// registry in the kernel, which has carried a module column on every readable
// and capability since 0027 and until now was read by nothing. What each module
// is, and where it lives, are rows. This file draws them.

import { el, MissingConfig, modules, readConfig } from "core";

const target = document.querySelector<HTMLElement>("#app");
if (!target) throw new Error("#app is missing from index.html");

// **The old service worker has to go before anything else happens.**
//
// The cellar app used to live here at the root, and its service worker is
// registered with scope "/". It has a fetch handler that serves a cached shell
// for navigations, which means it would answer for this page too and hand back a
// cellar that no longer lives here. Somebody with the app already installed
// would open the front door and get a stale cellar, with no way to tell why.
//
// So: unregister anything scoped here, and empty its caches. The cellar's own
// worker re-registers itself under /cellar/ when that app next opens, which is
// where its scope belongs now.
async function retireTheOldWorker(): Promise<void> {
  if (!("serviceWorker" in navigator)) return;
  try {
    const registrations = await navigator.serviceWorker.getRegistrations();
    for (const reg of registrations) {
      // Only the ones that would answer for this page. A worker registered under
      // /cellar/ or /shop/ is that app's business.
      const scope = new URL(reg.scope).pathname;
      if (scope === "/") await reg.unregister();
    }
    if ("caches" in window) {
      for (const key of await caches.keys()) await caches.delete(key);
    }
  } catch {
    // Not being able to tidy up is not a reason to refuse to draw the page.
  }
}

function card(
  label: string,
  note: string,
  path: string | null,
  counts: string,
): HTMLElement {
  const body = el(
    "div",
    { class: "row-main" },
    el("span", { class: "row-title", text: label }),
    el("span", { class: "row-note", text: note }),
    el("span", { class: "field-hint", text: counts }),
  );

  if (!path) {
    // Not a link, and it says why rather than looking broken. S-94 is the risk
    // this takes: a list with dead entries is a list people stop reading.
    return el("div", { class: "row module-shut" }, body);
  }
  const a = el("a", { class: "row module-open", href: path });
  a.append(body);
  return a;
}

async function draw(): Promise<void> {
  if (!target) return;
  target.replaceChildren(
    el(
      "section",
      { class: "screen" },
      el("h1", { text: "Vitae Springs" }),
      el("p", { class: "lede", text: "Loading." }),
    ),
  );

  try {
    const all = await modules();
    const open = all.filter((m) => m.openable);
    const shut = all.filter((m) => !m.openable);

    // A chooser with nothing on it reads as an app with nothing in it, and the
    // first time this ran that is exactly what it was: the list was readable
    // only to a signed-in person and the front door draws before anybody is.
    // 0110 fixed the policy; this is what stops the same shape being silent if
    // it ever happens again.
    if (all.length === 0) {
      target.replaceChildren(
        el(
          "section",
          { class: "screen" },
          el("h1", { text: "Vitae Springs" }),
          el("p", {
            class: "banner banner-error",
            text:
              "Nothing came back when asking what this winery has. That is a fault " +
              "here rather than an empty winery: the kernel is reachable and the " +
              "list of modules is not.",
          }),
        ),
      );
      return;
    }

    target.replaceChildren(
      el(
        "section",
        { class: "screen" },
        el("h1", { text: "Vitae Springs" }),
        el("p", { class: "lede", text: "Pick what you are doing." }),
        el(
          "div",
          { class: "rows" },
          ...open.map((m) =>
            card(
              m.label,
              m.note,
              m.path,
              `${m.capabilities} things you can do, ${m.readables} things you can look at`,
            ),
          ),
        ),
        shut.length > 0
          ? el("h2", { class: "section-head", text: "Not built yet" })
          : el("span", {}),
        shut.length > 0
          ? el(
              "div",
              { class: "rows" },
              ...shut.map((m) =>
                card(
                  m.label,
                  m.note,
                  null,
                  m.capabilities + m.readables === 0
                    ? "nothing in the kernel yet"
                    : `${m.capabilities} things you can do, ${m.readables} to look at, and no screens`,
                ),
              ),
            )
          : el("span", {}),
      ),
    );
  } catch (error) {
    target.replaceChildren(
      el(
        "section",
        { class: "screen" },
        el("h1", { text: "Vitae Springs" }),
        el("p", {
          class: "banner banner-error",
          text: `Could not read the modules: ${(error as Error).message}`,
        }),
      ),
    );
  }
}

void (async () => {
  await retireTheOldWorker();
  try {
    readConfig();
    await draw();
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
})();
