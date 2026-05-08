# cast-agents-node · PoC

> 1-day spike · 验 pi (earendil-works) + AgentRun 是否能替换自家 8 仓 Python framework + cast-agents Python.
> 老板 5-9 拍: "我们的代码都能删除 我希望部署 pi 写的 agent 到 agentrun 可以吗?"

## PoC 状态 (2026-05-09)

| 验证 | 状态 | 备注 |
|---|---|---|
| 1. pi-ai 接 DashScope (OpenAI 兼容) | PASS | 657ms latency · 23 token in / 2 token out · deepseek-v3.1 暗号回返 |
| 2. AgentRun 高代码 deploy Node.js | DEPLOY-READY | 仓代码 + Dockerfile + s.yaml 全 ready · 等 lead 开通 AgentRun 服务 + 创 RAM 角色 + 配 AccessKey · 跑 `s deploy` |
| 3. AgentRun sandbox API | DRY-RUN PASS | @agentrun/sdk 0.0.5 真实存在 · 类/方法全可调 · auth 失败证明 SDK 真打阿里云 endpoint |

## 文件

```
cast-agents-node/
├── package.json                         # node>=22 · pi-ai + agentrun-sdk + express
├── s.yaml                               # AgentRun 高代码模式部署
├── Dockerfile                           # node:22-slim 自定义镜像 (备选 · s.yaml 用 codePath 也可)
├── code/
│   ├── index.js                         # Express server · 监听 0.0.0.0:9000
│   ├── agent.js                         # pi-ai 集成 · 自构 Model 指 DashScope baseUrl
│   ├── verify1_pi_dashscope.js          # 验证 1
│   └── verify3_sandbox_api.js           # 验证 3 (dry-run + real)
└── poc-logs/                            # PoC 真 log (gitignore'd · 真值在 commit msg)
```

## 路由

| Method | Path | 用途 |
|---|---|---|
| GET | `/healthz` | 健康检查 |
| POST | `/api/agent/run` | 自家 API 形态 (cast-agents Python 等价) |
| POST | `/openai/v1/chat/completions` | AgentRun 标准协议 (OpenAI 兼容 chat completions) |

## 本地跑

```bash
npm install
export AKONG_LLM_API_KEY=sk-xxx  # 从 vault 拿: vault credential show dashscope-main --unmask
npm start
# 另开 terminal:
curl -s http://127.0.0.1:9000/healthz
curl -s -X POST http://127.0.0.1:9000/openai/v1/chat/completions \
  -H "content-type: application/json" \
  -d '{"messages":[{"role":"user","content":"hello"}]}'
```

## PoC 验证脚本

```bash
# 验证 1 · pi-ai → DashScope 真 work?
AKONG_LLM_API_KEY=sk-xxx npm run poc:verify1

# 验证 3 · @agentrun/sdk import + 真调 endpoint?
npm run poc:verify3                     # dry-run (无凭证)
AGENTRUN_ACCESS_KEY_ID=xx \
AGENTRUN_ACCESS_KEY_SECRET=yy \
AGENTRUN_ACCOUNT_ID=zz \
npm run poc:verify3                     # real (需 lead 开通服务后)
```

## 部署 · 等 lead 开通 AgentRun 服务后

```bash
# 1. 装 Serverless Devs CLI
npm install -g @serverless-devs/s

# 2. 配 access (一次)
s config add  # 别名 agentrun-deploy

# 3. 开通 AgentRun 服务 (老板控制台一次性 · 创 RAM 角色 agentRunRole)
#    https://help.aliyun.com/zh/functioncompute/fc/create-agent-by-code-high-code

# 4. 部署
export AKONG_LLM_API_KEY=$(vault credential show dashscope-main --unmask | jq -r .values.api_key)
export AGENTRUN_ACCOUNT_ID=xxx
s build && s deploy -a agentrun-deploy
```

部署成功后会拿到 endpoint URL · 形如:
```
https://{ACCOUNT_ID}.agentrun-data.cn-hangzhou.aliyuncs.com/agent-runtimes/cast-agents-node-poc/endpoints/prod/invocations
```

调用:
```bash
curl https://{...}/invocations/openai/v1/chat/completions \
  -H "content-type: application/json" \
  -d '{"messages":[{"role":"user","content":"暗号是西瓜籽"}]}'
```

## 决策建议 (lead 视角)

| 选项 | 推荐? | 理由 |
|---|---|---|
| **砍 11+ Python 仓 · 全切 pi+AgentRun** | YES (条件) | pi-ai 真支持自定义 baseUrl · DashScope 通 · 282k star ecosystem · 维护成本归零 |
| 维持现状 (自家 8 仓 + cast-agents Python) | NO | 维护成本高 · 但稳 · 无破坏风险 |
| 渐进 (新仓用 pi · 旧仓不动) | NO | 双栈复杂度 · 长期反而高 |

**砍 Python 触发条件 (任一 fail 立刻撤回)**:
1. AgentRun 服务开通后 verify 2 真 deploy 成功 (拿到真 endpoint URL)
2. AgentRun sandbox API 真跑动态 Python/JS 代码 (verify 3 real 模式 PASS)
3. 现有 cast-agents Python 业务功能 1:1 在 cast-agents-node 跑通 (集成测试)

**真重写工作量估计**:
- pi-ai + cast-agents-node 主体: 已完成框架 (1 天)
- 业务逻辑迁移 (cast-agents 现 Python 路由 / state / tools): 5-8 天
- 砍 8 仓自家 framework 凭据释放 (workspace registry 清理): 0.5 天
- 全栈集成测试 (cast-app → cast-api → cast-agents-node → AgentRun sandbox): 3-5 天
- **合计: 9-14 天 · 较 Python 维护持续投入划算**
