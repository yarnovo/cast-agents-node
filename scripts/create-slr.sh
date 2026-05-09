#!/bin/bash
# AgentRun Service Linked Role 创建脚本 · 一次性 setup ·
# 必须先跑一次后才能 create-agent-runtime / create-code-interpreter 不卡 SLR.
#
# 错误样本 (没跑这脚本时):
#   "The role not exists: acs:ram::{ACCOUNT_ID}:role/aliyunserviceroleforagentrun"
#
# 三种方法 (按推荐度):

set -e

PROFILE="${ALIYUN_PROFILE:-main}"
REGION="${REGION:-cn-hangzhou}"

echo "=== AgentRun SLR (Service Linked Role) 创建 ==="
echo "profile=$PROFILE region=$REGION"
echo

# 方法 1 · 阿里云控制台 (推荐 · 一键 · 浏览器)
echo "方法 1 · 控制台一键 (老板访问以下 URL · 自动创建 SLR):"
echo "  https://agentrun.console.aliyun.com/$REGION"
echo "  (首次访问会弹 '授权创建服务关联角色' · 点 同意授权 即可)"
echo

# 方法 2 · 直接调 RAM CreateServiceLinkedRole API (需 alibabacloud-tea-openapi pip 包)
cat <<'PY' > /tmp/agentrun_slr.py
import json, os
from alibabacloud_tea_openapi.client import Client as OpenApiClient
from alibabacloud_tea_openapi.models import Config, OpenApiRequest, Params
from alibabacloud_tea_util.models import RuntimeOptions

cfg = json.load(open(os.path.expanduser("~/.aliyun/config.json")))
prof_name = os.environ.get("ALIYUN_PROFILE", "main")
prof = next(p for p in cfg["profiles"] if p["name"] == prof_name)
config = Config(access_key_id=prof["access_key_id"], access_key_secret=prof["access_key_secret"],
                endpoint="ram.aliyuncs.com")
client = OpenApiClient(config)
params = Params(action="CreateServiceLinkedRole", version="2015-05-01", protocol="HTTPS",
                pathname="/", method="POST", auth_type="AK", style="RPC",
                req_body_type="json", body_type="json")
req = OpenApiRequest(query={"ServiceName": "agentrun.aliyuncs.com"})
print(json.dumps(client.call_api(params, req, RuntimeOptions()), indent=2, ensure_ascii=False, default=str))
PY

if python3 -c "import alibabacloud_tea_openapi" 2>/dev/null; then
  echo "方法 2 · python alibabacloud-tea-openapi 已装 · 直接跑:"
  ALIYUN_PROFILE=$PROFILE python3 /tmp/agentrun_slr.py
  echo
else
  echo "方法 2 · 装 SDK 后跑:"
  echo "  pip install alibabacloud-tea-openapi alibabacloud-tea-util"
  echo "  ALIYUN_PROFILE=$PROFILE python3 /tmp/agentrun_slr.py"
  echo
fi

# 方法 3 · 重试触发自动创建 (有时第一次失败后再试就 work)
echo "方法 3 · 跑一次任意 create 命令触发自动创建 SLR:"
echo "  aliyun agentrun create-code-interpreter --profile $PROFILE --region $REGION \\"
echo "    --code-interpreter-name slr-trigger --cpu 2 --memory 4096 \\"
echo "    --network-configuration networkMode=PUBLIC"
echo "  (失败也没事 · 只为触发 SLR 自动注册)"
echo

# 验证 SLR 已存在
echo "=== 验证 ==="
if aliyun ram get-role --profile "$PROFILE" --role-name AliyunServiceRoleForAgentRun 2>&1 | grep -q "RoleName"; then
  echo "✅ SLR AliyunServiceRoleForAgentRun 已存在"
else
  echo "❌ SLR 还没创建 · 请用上述方法之一"
  exit 1
fi
