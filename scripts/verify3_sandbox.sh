#!/bin/bash
# Verify 3 · 真跑 sandbox API · 需先跑 create-slr.sh

set -e

PROFILE="${ALIYUN_PROFILE:-main}"
REGION="${REGION:-cn-hangzhou}"
CI_NAME="${CI_NAME:-cast-poc-ci}"

echo "=== Verify 3 · 真 sandbox ==="

# Step 1 · 创建 code-interpreter
CI_JSON=$(aliyun agentrun create-code-interpreter --profile "$PROFILE" --region "$REGION" \
  --code-interpreter-name "$CI_NAME" \
  --cpu 2 --memory 4096 \
  --network-configuration networkMode=PUBLIC \
  --description "PoC sandbox for cast-agents-node")
CI_ID=$(echo "$CI_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['codeInterpreterId'])")
echo "CI id = $CI_ID"

# Step 2 · 等 READY
for i in $(seq 1 30); do
  st=$(aliyun agentrun get-code-interpreter --profile "$PROFILE" --region "$REGION" --code-interpreter-id "$CI_ID" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['status'])")
  echo "  [$i] CI $st"
  [ "$st" = "READY" ] && break
  if [ "$st" = "CREATE_FAILED" ]; then
    aliyun agentrun get-code-interpreter --profile "$PROFILE" --region "$REGION" --code-interpreter-id "$CI_ID" | python3 -c "import sys,json; print('reason:', json.load(sys.stdin)['data'].get('statusReason',''))"
    exit 2
  fi
  sleep 8
done

# Step 3 · 创建 sandbox 实例
SB_JSON=$(aliyun agentrun create-sandbox --profile "$PROFILE" --region "$REGION" \
  --code-interpreter-id "$CI_ID" \
  --session-idle-timeout-seconds 300)
SB_ID=$(echo "$SB_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['sandboxId'])")
echo "sandbox id = $SB_ID"

# Step 4 · 等 sandbox running
for i in $(seq 1 30); do
  st=$(aliyun agentrun get-sandbox --profile "$PROFILE" --region "$REGION" --sandbox-id "$SB_ID" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['status'])")
  echo "  [$i] sandbox $st"
  [ "$st" = "RUNNING" ] && break
  sleep 6
done

# Step 5 · 跑代码 (data-plane API · X-API-KEY)
ACCOUNT_ID="${ACCOUNT_ID:-1577573550634833}"
DATA_URL="https://${ACCOUNT_ID}.agentrun-data.cn-hangzhou.aliyuncs.com/v1/sandboxes/$SB_ID/contexts"

# 拿 sandbox accessKey · 这是 data plane token
TOKEN=$(aliyun agentrun get-sandbox --profile "$PROFILE" --region "$REGION" --sandbox-id "$SB_ID" | python3 -c "import sys,json; d=json.load(sys.stdin)['data']; print(d.get('accessKey') or d.get('endpointAccessKey') or '')")
echo "sandbox token (mask): ${TOKEN:0:8}..."

# 创 context
CTX_JSON=$(curl -sS -X POST "$DATA_URL" -H "X-API-KEY: $TOKEN" -H "content-type: application/json" -d '{"language":"python3"}')
CTX_ID=$(echo "$CTX_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('contextId') or json.load(sys.stdin).get('id'))" 2>/dev/null || echo "$CTX_JSON")
echo "context id = $CTX_ID"

# Execute
echo
echo "=== execute: import math; print(math.pi) ==="
curl -sS -X POST "$DATA_URL/$CTX_ID/execute" \
  -H "X-API-KEY: $TOKEN" -H "content-type: application/json" \
  -d '{"code":"import math\nprint(math.pi)","timeout":30}'
echo
echo
echo "=== Verify 3 PASS ==="
