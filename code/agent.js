/**
 * pi-ai 集成 · 自构 Model 指 DashScope (OpenAI 兼容) ·
 * 暴露两个函数:
 *   - runAgent({messages, systemPrompt})         · 自家 API 形态
 *   - runChatCompletion(openaiBody)              · OpenAI 兼容 (AgentRun 协议)
 */

import { complete } from "@earendil-works/pi-ai";

const apiKey = process.env.AKONG_LLM_API_KEY;
const baseUrl =
  process.env.AKONG_LLM_BASE_URL ||
  "https://dashscope.aliyuncs.com/compatible-mode/v1";
const defaultModelId = process.env.AKONG_LLM_MODEL || "deepseek-v3.1";

if (!apiKey) {
  console.warn(
    "[agent] WARN AKONG_LLM_API_KEY not set · LLM calls will fail at runtime",
  );
}

function buildModel(modelId = defaultModelId) {
  return {
    id: modelId,
    name: modelId,
    api: "openai-completions",
    provider: "dashscope-custom",
    baseUrl,
    reasoning: false,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 128000,
    maxTokens: 4096,
  };
}

function toPiMessages(openaiMessages) {
  return openaiMessages.map((m) => {
    if (m.role === "system") return null; // 提取到 systemPrompt
    if (m.role === "user") {
      return {
        role: "user",
        content: [{ type: "text", text: String(m.content ?? "") }],
      };
    }
    if (m.role === "assistant") {
      return {
        role: "assistant",
        content: [{ type: "text", text: String(m.content ?? "") }],
        stopReason: "stop",
        usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
      };
    }
    return null;
  }).filter(Boolean);
}

export async function runAgent({ messages, systemPrompt, modelId }) {
  const model = buildModel(modelId);
  const piMessages = (messages || []).map((m) => ({
    role: m.role,
    content: [{ type: "text", text: String(m.content ?? "") }],
  }));
  const result = await complete(
    model,
    { systemPrompt, messages: piMessages },
    { apiKey, maxTokens: 1024, temperature: 0.2 },
  );
  const text = (result.content || [])
    .filter((c) => c.type === "text")
    .map((c) => c.text)
    .join("");
  return {
    text,
    stopReason: result.stopReason,
    usage: result.usage,
  };
}

export async function runChatCompletion(body) {
  const { messages = [], model: modelId, max_tokens, temperature } = body;
  const systemPrompt = (messages.find((m) => m.role === "system") || {}).content;
  const piMessages = toPiMessages(messages);

  const model = buildModel(modelId || defaultModelId);
  const result = await complete(
    model,
    { systemPrompt, messages: piMessages },
    {
      apiKey,
      maxTokens: max_tokens || 1024,
      temperature: temperature ?? 0.2,
    },
  );
  const text = (result.content || [])
    .filter((c) => c.type === "text")
    .map((c) => c.text)
    .join("");

  return {
    id: `chatcmpl-${Date.now()}`,
    object: "chat.completion",
    created: Math.floor(Date.now() / 1000),
    model: model.id,
    choices: [
      {
        index: 0,
        message: { role: "assistant", content: text },
        finish_reason: result.stopReason || "stop",
      },
    ],
    usage: {
      prompt_tokens: result.usage?.input ?? 0,
      completion_tokens: result.usage?.output ?? 0,
      total_tokens: result.usage?.totalTokens ?? 0,
    },
  };
}
