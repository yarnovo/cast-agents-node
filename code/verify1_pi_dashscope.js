/**
 * PoC Verify 1 · pi-ai (earendil-works) 接 DashScope (OpenAI 兼容) 真 work?
 *
 * 关键: pi-ai 是否支持自定义 baseUrl (DashScope: https://dashscope.aliyuncs.com/compatible-mode/v1)
 *      还是只 hardcode anthropic / openai 官方域名.
 *
 * 验证方式: 构造自定义 Model 对象 (api: "openai-completions" + baseUrl 指 DashScope) ·
 *           调 complete() · 收到非空 reply · 含暗号"西瓜籽" = 通过.
 */

import { complete } from "@earendil-works/pi-ai";

const apiKey = process.env.AKONG_LLM_API_KEY;
const baseUrl = process.env.AKONG_LLM_BASE_URL || "https://dashscope.aliyuncs.com/compatible-mode/v1";
const modelId = process.env.AKONG_LLM_MODEL || "deepseek-v3.1";

if (!apiKey) {
  console.error("[FAIL] AKONG_LLM_API_KEY 未设置");
  process.exit(1);
}

console.log("=== Verify 1: pi-ai + DashScope (OpenAI compatible) ===");
console.log("baseUrl:", baseUrl);
console.log("model:", modelId);
console.log("apiKey:", apiKey.slice(0, 8) + "...(masked)");
console.log();

// 自构 Model · 不用 getModel() 内置注册表 (DashScope 不在内置)
const model = {
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

const context = {
  systemPrompt: "你是测试机器人 · 严格按用户指令执行.",
  messages: [
    {
      role: "user",
      content: [
        {
          type: "text",
          text: "暗号是西瓜籽 · 请仅回答四个字 西瓜籽 · 不加任何其他字符 · 不解释",
        },
      ],
    },
  ],
};

const t0 = Date.now();
try {
  const result = await complete(model, context, {
    apiKey,
    maxTokens: 200,
    temperature: 0,
  });

  const elapsed = Date.now() - t0;
  console.log("[OK] response received in", elapsed, "ms");
  console.log("stopReason:", result.stopReason);
  console.log("usage:", JSON.stringify(result.usage));
  console.log();
  console.log("--- raw content ---");
  console.log(JSON.stringify(result.content, null, 2));
  console.log();

  const textPieces = (result.content || [])
    .filter((c) => c.type === "text")
    .map((c) => c.text)
    .join("");
  console.log("--- extracted text ---");
  console.log(textPieces);

  if (textPieces.includes("西瓜籽")) {
    console.log("\n[PASS] Verify 1 PASSED · pi-ai → DashScope → deepseek-v3.1 真 work · 暗号回返");
    process.exit(0);
  } else {
    console.log("\n[FAIL] Verify 1 FAIL · LLM 回了但不含暗号 · 可能模型/prompt 问题");
    process.exit(2);
  }
} catch (err) {
  console.error("[FAIL] Verify 1 ERROR ·", err.message);
  if (err.cause) console.error("  cause:", err.cause);
  if (err.status) console.error("  status:", err.status);
  console.error(err.stack);
  process.exit(3);
}
