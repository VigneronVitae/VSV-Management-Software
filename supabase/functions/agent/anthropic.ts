// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The assistant's turn when the provider is Anthropic, through
//           Anthropic's own SDK."
// Depends on: [supabase/functions/agent/tools.ts]
// Depended on by: [supabase/functions/agent/index.ts]
// ---------------------------------------------------------------------------
//
// The SDK rather than a fetch because it is Anthropic's documented way in, and
// it carries the parts a hand-written request gets subtly wrong: thinking
// blocks passed back untouched between tool calls, typed errors, streaming
// assembled into one message. The other three providers share a protocol and
// share `openai.ts`.

import Anthropic from "npm:@anthropic-ai/sdk@0.131.0";
import type { PriorTurn, Session, Step, ToolDef, ToolResult } from "./tools.ts";

export function anthropicSession(opts: {
  apiKey: string;
  model: string;
  baseURL?: string;
  system: string;
  tools: ToolDef[];
  history: PriorTurn[];
  question: string;
}): Session {
  const client = new Anthropic({
    apiKey: opts.apiKey,
    baseURL: opts.baseURL || undefined,
  });
  // Streamed, so a long answer is never cut off by a request timeout, and
  // each tool's input streams as it is written. That means the input is not
  // checked by the API, which is why `tools.ts` validates every one.
  const tools: Anthropic.Tool[] = opts.tools.map((t) => ({
    name: t.name,
    description: t.description,
    input_schema: t.schema as Anthropic.Tool.InputSchema,
    eager_input_streaming: true,
  }));
  const messages: Anthropic.MessageParam[] = [
    ...opts.history.map(
      (h) => ({ role: h.role, content: h.text }) as Anthropic.MessageParam,
    ),
    { role: "user", content: opts.question },
  ];
  let last: Anthropic.Message | null = null;

  return {
    async step(): Promise<Step> {
      let tries = 0;
      let m: Anthropic.Message;
      for (;;) {
        try {
          const stream = client.messages.stream({
            model: opts.model,
            max_tokens: 16000,
            thinking: { type: "adaptive" },
            // The system prompt is the contract, the same for every question
            // a person asks this hour, so it is cached.
            system: [
              { type: "text", text: opts.system, cache_control: { type: "ephemeral" } },
            ],
            tools,
            messages,
          });
          m = await stream.finalMessage();
          break;
        } catch (err) {
          // Only a tool input that could not be parsed at all is retried. An
          // authentication or rate-limit failure is the provider's answer and
          // goes back to the person as it is.
          if (err instanceof Anthropic.APIError || tries++ >= 2) throw err;
        }
      }
      last = m;
      const text = m.content
        .filter((b): b is Anthropic.TextBlock => b.type === "text")
        .map((b) => b.text)
        .join("\n")
        .trim();
      const calls = m.content
        .filter((b): b is Anthropic.ToolUseBlock => b.type === "tool_use")
        .map((b) => ({ id: b.id, name: b.name, input: b.input }));
      const stop =
        m.stop_reason === "refusal"
          ? "refusal"
          : m.stop_reason === "max_tokens"
            ? "max_tokens"
            : m.stop_reason === "pause_turn"
              ? "pause"
              : calls.length > 0
                ? "tool"
                : "end";
      return {
        text,
        calls,
        stop,
        rawStop: m.stop_reason ?? "",
        inputTokens:
          m.usage.input_tokens +
          (m.usage.cache_read_input_tokens ?? 0) +
          (m.usage.cache_creation_input_tokens ?? 0),
        outputTokens: m.usage.output_tokens,
      };
    },
    answer(results: ToolResult[]) {
      if (!last) return;
      // The whole assistant turn goes back, thinking included: a tool result
      // has to follow the exact turn that asked for it.
      messages.push({ role: "assistant", content: last.content });
      if (results.length === 0) return; // a paused turn is resumed as it stands
      messages.push({
        role: "user",
        content: results.map((r) => ({
          type: "tool_result" as const,
          tool_use_id: r.id,
          content: r.content,
          is_error: r.isError || undefined,
        })),
      });
    },
  };
}
