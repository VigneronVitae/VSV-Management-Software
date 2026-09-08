import { BrowserMultiFormatReader } from "@zxing/library";
import { banner, button, el, field, on } from "./ui.ts";

// iOS Safari has no BarcodeDetector, which is the same platform wall that killed
// direct Bluetooth to the meter in compost entry C-1. So the decode happens in
// script rather than in the browser, and it reads both the cooper's linear
// barcode and our own QR sticker, because a barrel carries both.
//
// Manual entry sits beside the camera at all times rather than behind a
// fallback: a phone with a cracked lens in a dark barrel room is not an edge
// case, and typing eleven characters is faster than fighting autofocus.

export type CodeCapture = {
  root: HTMLElement;
  codes: () => { code: string; label: string | null }[];
  stop: () => void;
};

type CaptureOptions = {
  label?: string;
  onCode?: (code: string) => void | Promise<void>;
  collect?: boolean;
};

export function codeCapture(options: CaptureOptions = {}): CodeCapture {
  const collected: { code: string; label: string | null }[] = [];
  const list = el("ul", { class: "code-list" });
  const message = el("div", {});
  const video = el("video", {
    class: "scan-video",
    playsinline: "true",
    hidden: "hidden",
  });

  const manual = field({ label: "Code", placeholder: "Type or scan" });
  const labelField = field({
    label: "Label",
    placeholder: "cooper, our sticker",
    hint: "Optional. Which sticker this is, so the next person knows.",
  });

  let reader: BrowserMultiFormatReader | null = null;
  let running = false;

  async function accept(code: string): Promise<void> {
    const trimmed = code.trim();
    if (!trimmed) return;
    if (collected.some((row) => row.code === trimmed)) {
      message.replaceChildren(banner(`${trimmed} is already on this list`, "note"));
      return;
    }
    if (options.collect !== false) {
      collected.push({ code: trimmed, label: labelField.value() || null });
      list.append(
        el(
          "li",
          { class: "code-row" },
          el("span", { class: "code-value", text: trimmed }),
          el("span", { class: "code-label", text: labelField.value() || "no label" }),
        ),
      );
      message.replaceChildren();
      manual.input.value = "";
    }
    await options.onCode?.(trimmed);
  }

  const addManual = button("Add this code", () => accept(manual.value()), "secondary");

  const camera = button(
    "Scan with camera",
    async () => {
      if (running) {
        stop();
        return;
      }
      try {
        reader = new BrowserMultiFormatReader();
        video.hidden = false;
        running = true;
        await reader.decodeFromVideoDevice(null, video, (result) => {
          if (result) void accept(result.getText());
        });
      } catch (error) {
        running = false;
        video.hidden = true;
        message.replaceChildren(
          banner(
            `Camera unavailable: ${(error as Error).message}. Type the code instead.`,
            "error",
          ),
        );
      }
    },
    "secondary",
  );

  function stop(): void {
    reader?.reset();
    reader = null;
    running = false;
    video.hidden = true;
  }

  on(manual.input, "keydown", (ev) => {
    if ((ev as KeyboardEvent).key === "Enter") {
      ev.preventDefault();
      void accept(manual.value());
    }
  });

  const root = el(
    "div",
    { class: "capture" },
    el("span", { class: "field-label", text: options.label ?? "Codes" }),
    manual.root,
    options.collect === false ? null : labelField.root,
    el("div", { class: "row-actions" }, addManual, camera),
    video,
    list,
    message,
  );

  return { root, codes: () => collected, stop };
}
