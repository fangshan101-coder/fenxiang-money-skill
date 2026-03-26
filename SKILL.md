---
name: fenxiang-money-skill
description: >
  将商品链接或淘口令转为带优惠券的推广链接，跨平台比价（淘宝/天猫/京东/拼多多/抖音/唯品会/美团），
  查询历史价格走势并给出购买建议。当用户发来商品链接、淘口令，或提到"转链"、"比价"、"历史价"、
  "全网最低价"、"有没有优惠券"、"值不值得买"、"价格走势"、"优惠"、"便宜"、"划算"、"打折"、
  "降价"、"满减"、"省钱"、"买不买"、"该不该入手"时使用。
  不适用于：快递查询、汇率换算、天气查询、闲鱼二手交易等非购物比价场景。
version: 2.0.0
allowed-tools: Bash({baseDir}/scripts/run.sh:*),Read({baseDir}/**)
---

# 省钱购物助手

一次接口调用，同时获取商品信息 + 比价 + 历史价格，帮用户快速决策。

## 接口说明

所有接口通过 `bash {baseDir}/scripts/run.sh call <接口名> [参数]` 调用。

### convert（核心接口，一次返回全部数据）

```bash
bash {baseDir}/scripts/run.sh call convert --tpwd "<链接或口令>"
```

**参数**：

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `--tpwd` | 是 | — | 商品链接或淘口令 |

**返回字段**（JSON）：

| 字段 | 说明 | 示例 |
|------|------|------|
| `itemTitle` | 商品标题 | `"金龙鱼高筋麦芯小麦粉1kg"` |
| `itemPrice` | 原价（元） | `"7.35元"` |
| `finalPrice` | 到手价（元） | `"6.34元"` |
| `couponAmount` | 优惠券金额 | `"1.00元"` |
| `savingMoney` | 省钱金额 | `"1.01元"` |
| `totalComm` | 佣金 | `"0.04元"` |
| `shopType` | 平台（中文） | `"天猫"` |
| `shopName` | 店铺名 | `"淘宝农场"` |
| `itemPicUrl` | 商品图片 | URL |
| `tToken` | 淘口令 | `"￥ HU591 ZPZh5bOSLP0￥"` |
| `clickUrl` | 购买链接 | URL |
| `countrySubsidyFlag` | 国补标记 | `"无国补"` 或 `"有国补"` |
| `promotionTagList` | 促销标签 | `["淘金币频道抵扣1%起"]` |
| `comparePriceData` | **比价数据**（默认返回） | 见下方 |
| `historyPriceData` | **历史价数据**（默认返回） | 见下方 |

**`comparePriceData` 结构**（与单独比价接口返回结构一致）：

```json
{
  "totalCount": 2,
  "floorPriceItem": { "shopType": "淘宝", "shopName": "xxx", "price": "4290.59", "badge": "全网最低", ... },
  "topLowestItems": [ ... ],
  "compareViewUrl": "https://..."
}
```

**`historyPriceData` 结构**（与单独历史价接口返回结构一致）：

```json
{
  "historyLowestPrice": "6.47",
  "historyLowestDate": "2026-02-28 00:02:23",
  "lowest30DaysPrice": "6.47",
  "usualPrice": "6.47",
  "shopType": "天猫",
  "curveData": [ { "date": "2026-03-09", "price": "6.47" }, ... ]
}
```

> `includeComparePrice` 和 `includeHistoryPrice` 服务端默认 `true`，无需传参即返回比价和历史价。
> 若某项查询失败，对应字段不存在（不影响主数据）。

### compare-price（单独比价，仅在用户明确要求比价时使用）

```bash
bash {baseDir}/scripts/run.sh call compare-price --productIdentifier "<链接或口令>"
```

### history-price（单独历史价，仅在用户明确要求历史价时使用）

```bash
bash {baseDir}/scripts/run.sh call history-price --productIdentifier "<链接或口令>"
```

## 路由决策

| 用户意图 | 调用方式 |
|----------|----------|
| 发了链接/口令，没说别的 | `convert`（一次拿全部） |
| "值不值得买"、"该不该入手" | `convert`（一次拿全部） |
| 明确只说"转链"、"优惠券" | `convert`（一次拿全部，多余数据忽略即可） |
| 明确只说"比价"、"哪家便宜" | `compare-price` |
| 明确只说"历史价"、"价格走势" | `convert`（需要到手价做对比） |

**核心原则**：90% 的场景只需调 1 次 `convert`。

## 输出模板

收到接口数据后，按以下模板**直接渲染输出**，不要自行组织语言。

### 购买卡片

```
![{itemTitle}]({itemPicUrl})

### {itemTitle}

| 项目 | 详情 |
|------|------|
| 原价 | ~~¥{itemPrice}~~ |
| 到手价 | **¥{finalPrice}** |
| 优惠券 | 满减 ¥{couponAmount} |
| 省 | ¥{savingMoney} |
| 佣金 | ¥{totalComm} |
| 平台 | {shopType} · {shopName} |

👉 复制口令打开：`{tToken}`
[点击购买]({clickUrl})
```

规则：`tToken` 不存在时只显示 `[点击购买]({clickUrl})`；`countrySubsidyFlag` 不是"无国补"时追加 🏷️ 支持国家补贴；`promotionTagList` 非空时追加标签。

### 购买建议（基于 historyPriceData）

先计算：
- 价格位置 = (到手价 - 历史最低价) / (日常价 - 历史最低价)，日常价 = 历史最低价时为 0

判断规则（命中即停）：

| 条件 | 输出 |
|------|------|
| 到手价 < 历史最低价 且差额 ≥ ¥20 或 ≥ 5% | 🟢 **比历史最低还便宜 ¥X，强烈推荐入手！** |
| 到手价 < 历史最低价 | 🟢 **略低于历史最低，适合入手** |
| 日常价与历史最低差 < 3% 且到手价在日常价 ±3% | 🟡 **价格长期稳定在 ¥X，需要就买** |
| 到手价 ≤ 历史最低 × 1.03 | 🟢 **历史最低附近，适合入手** |
| 位置 ≤ 0.3 | 🟢 **接近历史低点，适合入手** |
| 位置 0.3~0.7 | 🟡 **价格适中**（距大促 ≤ 30天提示等等） |
| 位置 > 0.7 | 🔴 **高于日常，建议等降价** |

大促日历：年货节(1月)、38节(3月)、618(6月)、双11(11月)、双12(12月)

```
### 💰 购买建议：{结论}

{详情}

| 指标 | 价格 | 备注 |
|------|------|------|
| 到手价 | ¥{finalPrice} | 含券 |
| 历史最低 | ¥{historyLowestPrice} | {historyLowestDate} |
| 30天最低 | ¥{lowest30DaysPrice} | — |
| 日常价 | ¥{usualPrice} | — |

| 日期 | 价格 | 趋势 |
|------|------|------|
| {date} | ¥{price} | {🟢降/🔴涨/➡️平} |
```

### 比价结论（基于 comparePriceData）

若 `comparePriceData` 不存在或 `topLowestItems` 为空 → 输出"暂无跨平台比价数据"。

```
### 💰 比价结论：{结论}

| 平台 | 店铺 | 价格 | 标签 |
|------|------|------|------|
| {shopType} | {shopName} | **¥{price}** | {badge 或 —} |
```

## 完整输出示例

<example>
用户：帮我看看这个 https://e.tb.cn/h.xxx

助手：

正在查询商品信息...

[调用 convert --tpwd "https://e.tb.cn/h.xxx"]

[拿到返回 JSON 后，一次性渲染以下全部内容]

![金龙鱼高筋麦芯小麦粉1kg](https://img.alicdn.com/xxx.jpg)

### 金龙鱼高筋麦芯小麦粉1kg

| 项目 | 详情 |
|------|------|
| 原价 | ~~¥7.35~~ |
| 到手价 | **¥6.34** |
| 优惠券 | 满减 ¥0.00 |
| 省 | ¥0.13 |
| 佣金 | ¥0.04 |
| 平台 | 天猫 · 淘宝农场 |

🏷️ 淘金币频道抵扣1%起

👉 复制口令打开：`￥ HU591 ZPZh5bOSLP0￥`
[点击购买](https://s.click.taobao.com/xxx)

---

### 💰 购买建议：🟡 价格长期稳定在 ¥6.47 左右，需要就买

该商品价格波动极小，不存在更低的入手时机。

| 指标 | 价格 | 备注 |
|------|------|------|
| 到手价 | ¥6.34 | 含券 |
| 历史最低 | ¥6.47 | 2026-02-28 |
| 30天最低 | ¥6.47 | — |
| 日常价 | ¥6.47 | — |

| 日期 | 价格 | 趋势 |
|------|------|------|
| 2026-03-09 | ¥6.47 | ➡️ |
| 2026-03-17 | ¥6.62 | 🔴 |
| 2026-03-19 | ¥6.47 | 🟢 |
| 2026-03-22 | ¥6.62 | 🔴 |
| 2026-03-25 | ¥6.47 | 🟢 |

---

暂无跨平台比价数据，该商品可能仅在天猫有售。
</example>

<example>
用户：帮我看看值不值得买
助手：请发一下商品链接或淘口令，我来帮你查～
</example>

## 错误处理

| 现象 | 用户可见提示 |
|------|-------------|
| `missing_parameter` | 请发一下商品链接或淘口令 |
| `errorMessage: "未找到相关商品"` | 没找到商品信息，请检查链接 |
| `topLowestItems: null` | 暂无比价数据 |
| `historyPriceData` 不存在 | 暂无历史价格数据 |
| `api_unavailable` | 服务暂时不可用，请稍后再试 |

## 环境依赖

- Python 3 + pyyaml（`pip3 install pyyaml`）
- curl
- API 配置在 `{baseDir}/scripts/_env.yaml`
