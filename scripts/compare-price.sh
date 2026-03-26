#!/usr/bin/env bash
# name: compare-price
# description: 跨平台比价，输入商品链接/淘口令，返回全网最低价 TOP3
# tags: 比价,省钱,全网最低

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
  "$BASE_URL/skill/api/compare-price" 2>/dev/null) || {
  echo '{"status":"error","error_type":"api_unavailable","suggestion":"比价服务暂时不可用，请稍后重试"}' >&2
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
        total = data.get('totalCount', 0)
        print(f'比价商品总数: {total}')
        items = data.get('topLowestItems') or []
        if items:
            print(f'全网最低价 TOP{len(items)}:')
            print(f'{\"平台\":<8} {\"店铺\":<20} {\"价格\":<10} {\"标签\"}')
            print('─' * 60)
            for item in items:
                shop = item.get('shopName', '')[:18]
                price = item.get('price', '-')
                badge = item.get('badge', '')
                shop_type = item.get('shopType', '')
                print(f'{shop_type:<8} {shop:<20} ¥{price:<9} {badge}')
        else:
            print('暂无跨平台比价数据')
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2))
else:
    print(json.dumps({'status': 'error', 'message': resp.get('message', '比价失败')}, ensure_ascii=False, indent=2))
" "$FORMAT"
