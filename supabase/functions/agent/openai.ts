// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The assistant's turn when the provider speaks the chat completions
//           protocol: OpenAI, DeepSeek and Kimi, one adapter for the three."
// Depends on: [supabase/functions/agent/tools.ts]
// Depended on by: [supabase/functions/agent/index.ts]
// ---------------------------------------------------------------------------
//
// A fetch rather than a client library: the three differ only in where they
// are and what the model is called, both of which come from the winery
// computer's settings and are not written here. Nothing is guessed about any
// of them beyond the protocol they say they speak.
//
// No output limit is sent. OpenAI's newer models refuse `max_tokens` and want
// `max_completion_tokens`, which the others do not know, and each provider's
// own default is long enough for an answer about a cellar.

import type { PriorTurn, Session, Step, ToolDef, ToolResult } from "./tools.ts";

type Message =
  | { role: "system" | "user"; content: string }
  | { role: "assistant"; content: string | null; tool_calls?: ToolCall[] }
  | { role: "tool"; tool_call_id: string; content: string };

type ToolCall = {
  id: string;
  type: "function";
  function: { name: string; arguments: string };
};

export function openaiSession(opts: {
  apiKey: string;
  model: string;
  baseURL: string;
  system: string;
  tools: ToolDef[];
  history: PriorTurn[];
  question: string;
}): Session {
  const tools = opts.tools.map((t) => ({
    type: "function",
    function: { name: t.name, description: t.description, parameters: t.schema },
  }));
  const messages: Message[] = [
    { role: "system", content: opts.system },
    ...opts.history.map((h) => ({ role: h.role, content: h.text }) as Message),
    { role: "user", content: opts.question },
  ];
  let last: { content: string | null; tool_calls?: ToolCall[] } | null = null;

  return {
    async step(): Promise<Step> {
      const res = await fetch(`${opts.baseURL.replace(/\/+$/, "")}/chat/completions`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${opts.apiKey}`,
        },
        body: JSON.stringify({ model: opts.model, messages, tools }),
      });
      const body = await res.json().catch(() => null);
      if (!res.ok) {
        const said = body?.error?.message ?? body?.message ?? res.statusText;
        throw new Error(`the provider refused the request (${res.status}): ${said}`);
      }
      const choice = body?.choices?.[0];
      if (!choice?.message) throw new Error("the provider answered with nothing in it");
      // Only the standard fields go back. DeepSeek's reasoning text, for one,
      // is refused if it is sent back in.
      last = {
        content: choice.message.content ?? null,
        tool_calls: choice.message.tool_calls,
      };
      const calls = (last.tool_calls ?? []).map((c) => {
        let input: unknown;
        try {
          input = JSON.parse(c.function.arguments || "{}");
        } catch {
          // Not JSON at all. The validator refuses it and the model is told,
          // with what it wrote, so it can try again.
          input = { INVALID_JSON: c.function.arguments };
        }
        return { id: c.id, name: c.function.name, input };
      });
      const finish = String(choice.finish_reason ?? "");
      const stop =
        finish === "content_filter"
          ? "refusal"
          : finish === "length"
            ? "max_tokens"
            : calls.length > 0
              ? "tool"
              : "end";
      return {
        text: (last.content ?? "").trim(),
        calls,
        stop,
        rawStop: finish,
        inputTokens: body?.usage?.prompt_tokens ?? 0,
        outputTokens: body?.usage?.completion_tokens ?? 0,
      };
    },
    answer(results: ToolResult[]) {
      if (!last) return;
      messages.push({
        role: "assistant",
        content: last.content,
        tool_calls: last.tool_calls,
      });
      for (const r of results) {
        messages.push({ role: "tool", tool_call_id: r.id, content: r.content });
      }
    },
  };
}
