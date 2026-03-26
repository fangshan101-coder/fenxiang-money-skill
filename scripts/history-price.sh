#!/usr/bin/env bash
# name: history-price
# description: 查询商品历史价格走势，输入商品链接/淘口令，返回历史最低价、30天最低、价格曲线
# tags: 历史价,价格走势,省钱

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRODUCT_IDENTIFIER="" SHOP_TYPE="" FORMAT="json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --productIdentifier) PRODUCT_IDENTIFIER="$2"; shift 2;;
    --shopType) SHOP_TYPE="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    *) shift;;
  esac
done

if [[ -z "$PRODUCT_IDENTIFIER" ]]; then
  echo '{"status":"error","error_type":"missing_parameter","missing":"productIdentifier","suggestion":"请提供商品链接或淘口令，例如 --productIdentifier https://u.jd.com/xxx"}' >&2
  exit 1
fi

BASE_URL=$(python3 -c "import yaml; c=yaml.safe_load(open('$SCRIPT_DIR/_env.yaml')); print(c['base_url'])")
API_KEY=$(python3 -c "import yaml; c=yaml.safe_load(open('$SCRIPT_DIR/_env.yaml')); print(c['headers']['X-Api-Key'])")

BODY=$(python3 -c "
import json, sys
d = {'productIdentifier': sys.argv[1]}
if sys.argv[2]:
    d['shopType'] = sys.argv[2]
print(json.dumps(d))
" "$PRODUCT_IDENTIFIER" "${SHOP_TYPE:-}")

RESP=$(curl -sf --max-time 30 -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $API_KEY" \
  -d "$BODY" \
  "$BASE_URL/skill/api/history-price" 2>/dev/null) || {
  echo '{"status":"error","error_type":"api_unavailable","suggestion":"历史价格服务暂时不可用，请稍后重试"}' >&2
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
        print(f'商品ID: {data.get(\"itemIdStr\", \"-\")}')
        print(f'平台: {data.get(\"shopType\", \"-\")}')
        print(f'历史最低价: {data.get(\"historyLowestPrice\", \"-\")}元 ({data.get(\"historyLowestDate\", \"-\")})')
        print(f'30天最低价: {data.get(\"lowest30DaysPrice\", \"-\")}元')
        print(f'日常价: {data.get(\"usualPrice\", \"-\")}元')
        curve = data.get('curveData') or []
        if curve:
            print(f'\\n价格曲线 (近{len(curve)}个数据点):')
            print(f'{\"日期\":<14} {\"价格\"}')
            print('─' * 30)
            for p in curve[-10:]:
                print(f'{p.get(\"date\", \"-\"):<14} ¥{p.get(\"price\", \"-\")}')
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2))
else:
    print(json.dumps({'status': 'error', 'message': resp.get('message', '查询失败')}, ensure_ascii=False, indent=2))
" "$FORMAT"
