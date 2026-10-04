// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The assistant: one question in, an answer and any proposals out,
//           read as the person asking and kept whatever happens."
// Depends on: [supabase/migrations/0170_an_assistant_asks_as_you.sql,
//              supabase/functions/agent/tools.ts,
//              supabase/functions/agent/anthropic.ts,
//              supabase/functions/agent/openai.ts]
// Depended on by: [packages/core/src/index.ts, docs/the-assistant.md]
// ---------------------------------------------------------------------------
//
// Runs in the stack's edge runtime, beside the API it reads from. The keys
// for the providers are in this function's environment on the winery
// computer and nowhere else: a phone sends a question and its own sign-in,
// and gets back words and filled-in forms.
//
// Which providers are offered is whichever have a key and a model set. The
// model names for OpenAI, DeepSeek and Kimi, and where DeepSeek and Kimi are,
// are not written here: they change, and a wrong guess fails at the worst
// moment. They are settings, in `.env.example` beside this file.

import { anthropicSession } from "./anthropic.ts";
import { openaiSession } from "./openai.ts";
import {
  type AgentContract,
  type PriorTurn,
  type Proposal,
  type ReadLog,
  restFor,
  rpc,
  runPropose,
  runRead,
  type Session,
  systemPrompt,
  type ToolResult,
  toolDefs,
} from "./tools.ts";

const env = (k: string) => (Deno.env.get(k) ?? "").trim();

type Provider = {
  key: "anthropic" | "openai" | "deepseek" | "kimi";
  label: string;
  model: string;
  baseURL: string;
  apiKey: string;
};

function providers(): Provider[] {
  const all: Provider[] = [
    {
      key: "anthropic",
      label: "Claude",
      apiKey: env("ANTHROPIC_API_KEY"),
      model: env("AGENT_ANTHROPIC_MODEL") || "claude-opus-5-5",
      baseURL: env("AGENT_ANTHROPIC_BASE_URL"),
    },
    {
      key: "openai",
      label: "ChatGPT",
      apiKey: env("OPENAI_API_KEY"),
      model: env("AGENT_OPENAI_MODEL"),
      baseURL: env("AGENT_OPENAI_BASE_URL") || "https://api.openai.com/v1",
    },
    {
      key: "deepseek",
      label: "DeepSeek",
      apiKey: env("DEEPSEEK_API_KEY"),
      model: env("AGENT_DEEPSEEK_MODEL"),
      baseURL: env("AGENT_DEEPSEEK_BASE_URL"),
    },
    {
      key: "kimi",
      label: "Kimi",
      apiKey: env("KIMI_API_KEY"),
      model: env("AGENT_KIMI_MODEL"),
      baseURL: env("AGENT_KIMI_BASE_URL"),
    },
  ];
  return all.filter((p) => p.apiKey && p.model && (p.key === "anthropic" || p.baseURL));
}

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}

// A question that needs more reading than this is a question to ask in parts.
const MOST_STEPS = 12;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "Ask with POST." });
  const authorization = req.headers.get("authorization") ?? "";
  if (!/^Bearer\s+\S+/.test(authorization))
    return reply(401, { error: "Sign in first." });

  const rest = restFor(
    env("SUPABASE_URL"),
    env("SUPABASE_ANON_KEY") || env("SUPABASE_PUBLISHABLE_KEY"),
    authorization,
  );
  const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;

  // What may this person ask, and of whom. No question is sent anywhere.
  if (body.op === "providers") {
    let may = false;
    try {
      may = await rpc<boolean>(rest, "may", { p_key: "agent.ask" });
    } catch (e) {
      return reply(401, { error: (e as Error).message });
    }
    return reply(200, {
      may,
      providers: may
        ? providers().map((p) => ({ key: p.key, label: p.label, model: p.model }))
        : [],
    });
  }

  const question = typeof body.question === "string" ? body.question.trim() : "";
  if (!question) return reply(400, { error: "Ask something." });
  const offered = providers();
  const provider =
    offered.find((p) => p.key === body.provider) ??
    offered.find((p) => p.key === env("AGENT_PROVIDER")) ??
    offered[0];
  if (!provider) {
    return reply(503, {
      error:
        "No assistant is set up on the winery computer yet: no provider has both a key and a model.",
    });
  }
  const history: PriorTurn[] = (
    Array.isArray(body.history) ? (body.history as unknown[]) : []
  )
    .filter((h): h is PriorTurn => {
      const t = h as Partial<PriorTurn> | null;
      return (
        (t?.role === "user" || t?.role === "assistant") &&
        typeof t?.text === "string" &&
        t.text.trim() !== ""
      );
    })
    .slice(-12)
    .map((h) => ({ role: h.role, text: h.text }));

  // The contract refuses anybody who may not ask, in a sentence.
  let contract: AgentContract;
  try {
    contract = await rpc<AgentContract>(rest, "agent_contract", {});
  } catch (e) {
    return reply(403, { error: (e as Error).message });
  }

  const turnId = crypto.randomUUID();
  const reads: ReadLog[] = [];
  const proposals: Proposal[] = [];
  let answer = "";
  let stopReason = "";
  let failure: string | null = null;
  let inputTokens = 0;
  let outputTokens = 0;

  try {
    const system = systemPrompt(contract);
    const tools = toolDefs(contract);
    const session: Session =
      provider.key === "anthropic"
        ? anthropicSession({
            apiKey: provider.apiKey,
            model: provider.model,
            baseURL: provider.baseURL,
            system,
            tools,
            history,
            question,
          })
        : openaiSession({
            apiKey: provider.apiKey,
            model: provider.model,
            baseURL: provider.baseURL,
            system,
            tools,
            history,
            question,
          });

    for (let n = 0; ; n++) {
      if (n >= MOST_STEPS) {
        failure = `Stopped after ${MOST_STEPS} rounds of reading without an answer. Ask it in smaller parts.`;
        break;
      }
      const step = await session.step();
      inputTokens += step.inputTokens;
      outputTokens += step.outputTokens;
      stopReason = step.rawStop;
      if (step.text) answer = step.text;
      if (step.stop === "refusal") {
        // A refusal can cut a tool call off part way; none of it is run.
        failure = "The provider declined to answer this one.";
        break;
      }
      if (step.stop === "max_tokens") {
        failure = "The answer ran longer than the provider allows and was cut off.";
        break;
      }
      if (step.stop === "pause") {
        session.answer([]);
        continue;
      }
      if (step.stop === "end") break;

      const results: ToolResult[] = [];
      for (const call of step.calls) {
        try {
          if (call.name === "read") {
            const { content, log } = await runRead(rest, contract, call.input);
            reads.push(log);
            results.push({ id: call.id, content, isError: false });
          } else if (call.name === "propose") {
            const p = await runPropose(rest, contract, call.input);
            proposals.push(p);
            results.push({
              id: call.id,
              content: `Proposed as number ${proposals.length}: ${p.label}. It is in front of the person now with Confirm and Not this. It has not been recorded.`,
              isError: false,
            });
          } else {
            results.push({
              id: call.id,
              content: `There is no tool called ${call.name}. Use read or propose.`,
              isError: true,
            });
          }
        } catch (e) {
          results.push({ id: call.id, content: (e as Error).message, isError: true });
        }
      }
      session.answer(results);
    }
  } catch (e) {
    failure = `The provider could not be reached or refused the request: ${(e as Error).message}`;
  }

  if (!answer && !failure && proposals.length === 0) {
    failure = "The assistant finished without saying anything.";
  }

  try {
    await rpc(rest, "record_agent_turn", {
      p_id: turnId,
      p_provider: provider.key,
      p_model: provider.model,
      p_question: question,
      p_answer: answer || null,
      p_stop_reason: stopReason || null,
      p_reads: reads,
      p_proposals: proposals,
      p_input_tokens: inputTokens,
      p_output_tokens: outputTokens,
      p_failure: failure,
    });
  } catch (e) {
    // A13. An answer that could not be kept is not handed over as if it had
    // been: the proposals in it could not be confirmed against a record.
    return reply(500, {
      error: `The answer could not be kept, so it is not shown: ${(e as Error).message}`,
    });
  }

  return reply(200, {
    turn_id: turnId,
    provider: provider.key,
    model: provider.model,
    answer,
    failure,
    proposals,
    reads: reads.length,
  });
});
