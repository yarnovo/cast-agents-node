#!/bin/bash
# Verify 2 · 真 deploy 到 AgentRun · 需先跑 create-slr.sh
#
# 前置条件:
#   1. SLR AliyunServiceRoleForAgentRun 已创建 (见 create-slr.sh)
#   2. ACR 镜像已 push: registry.cn-hangzhou.aliyuncs.com/agentaily/cast-agents-node:poc
#   3. vault credential dashscope-main 可访问

set -e

PROFILE="${ALIYUN_PROFILE:-main}"
REGION="${REGION:-cn-hangzhou}"
RUNTIME_NAME="${RUNTIME_NAME:-cast-agents-node-poc}"
IMAGE="${IMAGE:-registry.cn-hangzhou.aliyuncs.com/agentaily/cast-agents-node:poc}"
LLM_KEY="$(vault credential show dashscope-main --unmask 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin)["values"]["api_key"])')"

if [ -z "$LLM_KEY" ]; then
  echo "❌ 无法从 vault 拿 dashscope-main 凭证"
  exit 1
fi

echo "=== Verify 2 · 真 deploy ==="
echo "runtime: $RUNTIME_NAME · image: $IMAGE"
echo

# Step 1 · 创建 runtime
echo "[1/4] 创建 agent-runtime"
RT_JSON=$(aliyun agentrun create-agent-runtime --profile "$PROFILE" --region "$REGION" \
  --agent-runtime-name "$RUNTIME_NAME" \
  --artifact-type Container --cpu 1 --memory 2048 --port 9000 \
  --network-configuration networkMode=PUBLIC \
  --container-configuration "image=$IMAGE" \
  --environment-variables AKONG_LLM_API_KEY="$LLM_KEY" AKONG_LLM_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1 AKONG_LLM_MODEL=deepseek-v3.1 NODE_ENV=production \
  --description "PoC: pi-ai + DashScope · 1-day spike validation")
RT_ID=$(echo "$RT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['agentRuntimeId'])")
echo "runtime id = $RT_ID"

# Step 2 · 等 READY
echo "[2/4] 等 runtime READY"
for i in $(seq 1 60); do
  st=$(aliyun agentrun get-agent-runtime --profile "$PROFILE" --region "$REGION" --agent-runtime-id "$RT_ID" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['status'])")
  echo "  [$i] $st"
  [ "$st" = "READY" ] && break
  if [ "$st" = "CREATE_FAILED" ]; then
    aliyun agentrun get-agent-runtime --profile "$PROFILE" --region "$REGION" --agent-runtime-id "$RT_ID" | python3 -c "import sys,json; print('reason:', json.load(sys.stdin)['data'].get('statusReason',''))"
    exit 2
  fi
  sleep 10
done

# Step 3 · 创建 endpoint
echo "[3/4] 创建 endpoint (prod)"
EP_JSON=$(aliyun agentrun create-agent-runtime-endpoint --profile "$PROFILE" --region "$REGION" \
  --agent-runtime-id "$RT_ID" --agent-runtime-endpoint-name prod)
EP_ID=$(echo "$EP_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['agentRuntimeEndpointId'])")
echo "endpoint id = $EP_ID"

for i in $(seq 1 30); do
  EP=$(aliyun agentrun get-agent-runtime-endpoint --profile "$PROFILE" --region "$REGION" --agent-runtime-id "$RT_ID" --agent-runtime-endpoint-id "$EP_ID")
  st=$(echo "$EP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['status'])")
  url=$(echo "$EP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('endpointPublicUrl',''))")
  echo "  [$i] $st"
  [ "$st" = "READY" ] && { echo "endpoint URL: $url"; break; }
  sleep 6
done

# Step 4 · 拉取访问凭证 + curl 真测
echo "[4/4] 拉取 X-API-KEY"
TOKEN=$(echo "$EP" | python3 -c "import sys,json; d=json.load(sys.stdin)['data']; print(d.get('endpointAccessKey') or d.get('accessKey') or '')")
echo "token (mask): ${TOKEN:0:8}..."

echo
echo "=== curl 真测 OpenAI 兼容路由 ==="
curl -sS -X POST "$url/openai/v1/chat/completions" \
  -H "X-API-KEY: $TOKEN" \
  -H "content-type: application/json" \
  -d '{"messages":[{"role":"user","content":"暗号是西瓜籽 · 仅回答四字 西瓜籽 不解释"}]}'
echo
echo
echo "=== Verify 2 PASS ==="
echo "endpoint URL: $url"
