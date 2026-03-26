#!/usr/bin/env bash
# name: convert
# description: 商品转链，输入商品链接/淘口令，返回商品信息、到手价、优惠券、推广链接等

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TPWD="" FORMAT="json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tpwd) TPWD="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    *) shift;;
  esac
done

if [[ -z "$TPWD" ]]; then
  echo '{"status":"error","error_type":"missing_parameter","missing":"tpwd","suggestion":"请提供商品链接或淘口令，例如 --tpwd https://u.jd.com/xxx"}' >&2
  exit 1
fi

# 读取环境配置
BASE_URL=$(python3 -c "import yaml; c=yaml.safe_load(open('$SCRIPT_DIR/_env.yaml')); print(c['base_url'])")
API_KEY=$(python3 -c "import yaml; c=yaml.safe_load(open('$SCRIPT_DIR/_env.yaml')); print(c['headers']['X-Api-Key'])")

BODY=$(python3 -c "import json,sys; print(json.dumps({'tpwd': sys.argv[1]}))" "$TPWD")

RESP=$(curl -sf --max-time 30 -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $API_KEY" \
  -d "$BODY" \
  "$BASE_URL/skill/api/convert" 2>/dev/null) || {
  echo '{"status":"error","error_type":"api_unavailable","suggestion":"转链服务暂时不可用，请稍后重试"}' >&2
  exit 1
}

export _RESP="$RESP"
python3 -c "
import json, os, sys

resp = json.loads(os.environ['_RESP'])
fmt = sys.argv[1]
data = resp.get('data', resp)

if resp.get('code') == 200 and data:
    if fmt == 'table':
        for k, v in data.items():
            if v is not None and v != '' and v != False:
                print(f'{k}: {v}')
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2))
else:
    msg = resp.get('message', '转链失败')
    err = data.get('errorMessage', msg) if isinstance(data, dict) else msg
    print(json.dumps({'status': 'error', 'message': err, 'suggestion': '请检查链接是否正确'}, ensure_ascii=False, indent=2))
" "$FORMAT"
