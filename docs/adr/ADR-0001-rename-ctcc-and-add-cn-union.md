---
文档类型: 决策记录
状态: 已批准
负责人: @skylineconnct
最后更新: 2026-10-12
代码基线: 13e9511
验证程度: 已跑测试
关联代码: src/ip.rs (IpRanges::union), src/main.rs (merge_prefix_file), justfile (cn, published_lists, guard)
关联决策: 无
---

# ADR-0001 电信列表改名为 ctcc，并新增三家合并表 cn

## 背景

维护者要求两件事（2026-10-12）：

1. 中国电信的列表标识从 `chinanet` 改为 `ctcc`，与 `cmcc` 的命名风格一致。
2. 新增一张三家合并表 `cn`，输出 `cnv4.txt`、`cnv6.txt`、`cnv4v6.txt`，且合并
   时必须处理重复的段。

两者都改了 `CLAUDE.md` 铁律七的对外契约：Release 资产从 11 个变成 14 个，其中
`chinanet*.txt` 三个文件名消失。

## 目标与非目标

- 目标：`ctcc.txt` / `ctcc6.txt` / `ctcc46.txt` 取代 `chinanet*`；新增
  `cnv4.txt` / `cnv6.txt` / `cnv4v6.txt`，表内**没有任何两条 CIDR 重叠**。
- 非目标：不改分类语义。`operators.yaml` 里电信的 `pattern`（含 `chinanet`
  这个 ASN 名称关键字）与 `exclude_asn` 原样保留，只改键名。`unicom` 不改名。
- 非目标：不保留 `chinanet*` 兼容副本（见「代价」）。

## 候选方案

### 改名

| 方案 | 机制 | 对下游的影响 | 代价 |
|---|---|---|---|
| A. 只改键名 | `operators.yaml` 的 `chinanet:` → `ctcc:` | `releases/latest/download/chinanet*.txt` 从下一次发布起 404 | 破坏兼容 |
| B. 改名并继续发布 `chinanet*` 副本 | `package` 多拷贝三份 | 无破坏 | 资产集合里长期挂着一个旧名字，且要定退役日期 |

### 合并去重

| 方案 | 机制 | 去重程度 | 代价 |
|---|---|---|---|
| a. `sort -u` | 按行去重 | 只去掉逐字相同的行；`1.0.0.0/24` 与 `1.0.0.128/25` 仍然重叠 | 不满足需求 |
| b. Ruby `IPAddr` 合并 | justfile 配方里手写区间合并 | 完整 | 本地装不上 Ruby，只能在 CI 验证；且要自己写 CIDR 化 |
| c. 分类器新增 `--merge-prefix-file` | 复用 `src/ip.rs` 的 `IpRange::simplify` | 完整：重复、嵌套、相邻的段都合并为最少 CIDR | 多一个 CLI 参数 |

## 决策

- 改名取 **A**：维护者的要求是"重命名"，不是"新增别名"。
- 去重取 **c**：`IpRanges::union` 把所有输入前缀加入 `IpRange` 后 `simplify`，
  与分类器输出各家列表时用的是同一套区间代码，`cargo test` 可在本地覆盖。
- `cn` 的成员是 `just published_operators` 的全部输出，不在 `operators.yaml`
  里另设配置项——今后新增 `publish: true` 的运营商会自动并入 `cn`。
- 文件名按维护者指定的 `cnv4` / `cnv6` / `cnv4v6`，**不**沿用 `<op>` / `<op>6` /
  `<op>46` 的格式。为此新增 `just published_lists` 作为"列表名 → 三个文件名"的
  唯一出处，`guard`、`package` 和 Release notes 都从它读。

## 代价与放弃的东西

- 依赖 `releases/latest/download/chinanet*.txt` 的下游会在合并后的第一次发布
  起拿到 404，需要改成 `ctcc*.txt`。旧 Release（如 `v2026.10.06`）里的
  `chinanet*` 资产不受影响。
- `cn` 的条目数**不等于**三家之和：同一前缀多 origin 宣告时会同时出现在多张表
  （README「分类规则」），并且相邻段会被合成更大的 CIDR。`stat` 里 `cnv4` 的
  地址总量 ≤ 三家之和。
- 资产命名出现两种格式，下游要分别记。

## 待确认（阻塞项）

无。

## 验证方式

```bash
just check                                   # 含 IpRanges::union 与 --merge-prefix-file 的单测
gh workflow run Release -f dry_run=true --ref feat/ctcc-and-cn-merged-list
gh run watch                                 # 日志里应有 "INFO> cn done from cmcc+ctcc+unicom"
```

`just guard` 对 `cn` 额外检查两项：`cnv4` / `cnv6` 排序后相邻两条不重叠；条目数
不多于三家对应表之和。【未验证】直到空跑 run 链接贴进 PR。

## 回滚

revert 本 ADR 对应的 squash 提交即可。`cn` 是纯后处理，不进分类器缓存键，回滚
不影响已有缓存。
