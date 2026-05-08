/**
 * cast-agents-node · 入口 · Express HTTP server (port 9000) ·
 * AgentRun 高代码模式期望容器监听 0.0.0.0:9000.
 *
 * 路由:
 *   GET  /healthz                 → 健康检查
 *   POST /api/agent/run           → pi 跑一轮 LLM (cast-agents Python 的 /run 等价)
 *   POST /openai/v1/chat/completions  → AgentRun 默认协议 (OpenAI 兼容)
 */

import express from "express";
import { runAgent, runChatCompletion } from "./agent.js";

const app = express();
app.use(express.json({ limit: "4mb" }));

const PORT = Number(process.env.PORT) || 9000;
const HOST = "0.0.0.0";

app.get("/healthz", (_req, res) => {
  res.json({
    ok: true,
    runtime: "node",
    nodeVersion: process.version,
    framework: "pi-ai (earendil-works)",
    model: process.env.AKONG_LLM_MODEL || "deepseek-v3.1",
    baseUrl: process.env.AKONG_LLM_BASE_URL || "https://dashscope.aliyuncs.com/compatible-mode/v1",
  });
});

app.post("/api/agent/run", async (req, res) => {
  try {
    const { messages, systemPrompt } = req.body || {};
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: "messages required" });
    }
    const result = await runAgent({ messages, systemPrompt });
    res.json(result);
  } catch (err) {
    console.error("[/api/agent/run] error:", err);
    res.status(500).json({ error: err.message });
  }
});

// AgentRun 标准协议 (OpenAI 兼容 chat completions)
app.post("/openai/v1/chat/completions", async (req, res) => {
  try {
    const result = await runChatCompletion(req.body || {});
    res.json(result);
  } catch (err) {
    console.error("[/openai/v1/chat/completions] error:", err);
    res.status(500).json({ error: { message: err.message } });
  }
});

app.listen(PORT, HOST, () => {
  console.log(`cast-agents-node listening on http://${HOST}:${PORT}`);
});
