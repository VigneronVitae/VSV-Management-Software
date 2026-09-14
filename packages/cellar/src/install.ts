// Installing the app, from inside the app.
//
// The winemaker asked how to install it and the honest answer was a three-tap
// hunt through Chrome's menu, which is the sort of instruction nobody follows
// twice. Chrome will offer to do it directly, but only through an event it
// fires at the page, and only once the site is installable at all.
//
// So this holds that event when it arrives and hands the home screen a button.
// When the event never comes, the button is still there and says what to do
// instead, because a control that quietly does not appear is indistinguishable
// from a control that is broken.

type InstallPrompt = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

let held: InstallPrompt | null = null;
let workerError: string | null = null;
let listeners: Array<() => void> = [];

/** Running as an installed app rather than in a browser tab. */
export function isInstalled(): boolean {
  try {
    return (
      window.matchMedia("(display-mode: standalone)").matches ||
      // iOS reports it here and nowhere else.
      (navigator as { standalone?: boolean }).standalone === true
    );
  } catch {
    return false;
  }
}

/** Whether Chrome has offered to install, which it only does when it can. */
export function canInstall(): boolean {
  return held !== null;
}

export function onInstallChanged(fn: () => void): void {
  listeners.push(fn);
}

function changed(): void {
  for (const fn of listeners) fn();
}

/**
 * Ask the browser to install. Resolves to what happened, so the caller can say
 * something true rather than assuming it worked: a dismissed prompt and a
 * successful install look identical from here otherwise.
 */
export async function promptInstall(): Promise<
  "accepted" | "dismissed" | "unavailable"
> {
  if (!held) return "unavailable";
  const prompt = held;
  try {
    await prompt.prompt();
    const { outcome } = await prompt.userChoice;
    // A prompt is single use. Holding a spent one would leave a button that
    // does nothing on the second tap.
    held = null;
    changed();
    return outcome;
  } catch {
    held = null;
    changed();
    return "unavailable";
  }
}

/**
 * Called once, before the first screen. The event fires early and only once, so
 * anything that starts listening after the first paint has already missed it.
 */
export function watchForInstall(): void {
  window.addEventListener("beforeinstallprompt", (event) => {
    // Chrome shows its own banner otherwise, which arrives at whatever moment
    // it chooses and covers the screen somebody is working on.
    event.preventDefault();
    held = event as InstallPrompt;
    changed();
  });

  window.addEventListener("appinstalled", () => {
    held = null;
    changed();
  });

  // The worker is what makes the site installable at all, and it is registered
  // here rather than in the shell because this is the module that cares.
  //
  // **The failure is kept, not swallowed.** The first version of this ended in
  // `.catch(() => undefined)`, which meant that when registration failed the
  // install button said "this browser has not offered", blaming the browser for
  // something the app had done. Finding out why cost a round of guessing. A
  // failure here still must not interrupt anybody, because the app runs exactly
  // as it did before without a worker, but it has to be answerable when asked.
  if (!("serviceWorker" in navigator)) {
    workerError = "This browser does not support service workers at all.";
    return;
  }

  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").then(
      () => {
        workerError = null;
        changed();
      },
      (error: unknown) => {
        workerError = (error as Error)?.message ?? "The worker did not register.";
        changed();
      },
    );
  });
}

/**
 * Why the app is not installable, when it is not. Null means the worker
 * registered, or has not been asked yet.
 */
export function installBlockedBecause(): string | null {
  return workerError;
}

/** Test seam: forget everything, so a screen can be built twice in one page. */
export function resetInstallWatchers(): void {
  listeners = [];
}
