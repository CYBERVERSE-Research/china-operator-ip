---
文档类型: 决策记录
状态: 已批准
负责人: @skylineconnct
最后更新: 2026-10-16
代码基线: fa1927b
验证程度: 已完整生成验证
关联代码: src/delegated.rs (load), src/main.rs (merge_delegated_file), justfile (prepare_apnic, cn, guard)
关联决策: ADR-0001
---

# ADR-0002 cn 合并表改为取 APNIC delegated 统计里的全部 CN 地址

## 背景

ADR-0001 把 `cn` 定义为电信、移动、联通三张表的并集。维护者指出（2026-10-16）
`cnv4` / `cnv6` / `cnv4v6` 要的是**整个中国的 IP**，包含教育网等非三大运营商
网络，要求直接从 APNIC 获取全部 CN 地址发布。

三家并集天然漏掉教育网、科技网、鹏博士等 `publish: false` 的网络——它们在
分类算法里正是被刻意排除的停止边界（`CLAUDE.md` 铁律三）。

## 目标与非目标

- 目标：`cnv4.txt` / `cnv6.txt` / `cnv4v6.txt` = APNIC `delegated-apnic-latest`
  中国家码为 `CN`、类型为 `ipv4` / `ipv6`、状态为 `allocated` 或 `assigned` 的
  全部地址块，合并为最少且互不重叠的 CIDR。
- 非目标：不改三家运营商列表与分类语义，`operators.yaml` 不动。
- 非目标：不含 `HK` / `MO` / `TW` 家码的地址；APNIC 的 `CN` 只覆盖中国大陆。

## 候选方案

| 方案 | 机制 | 覆盖 | 代价 |
|---|---|---|---|
| A. 三家并集（现状） | `--merge-prefix-file` 合并三家 | 漏掉教育网等 | 不满足需求 |
| B. 三家并集 ∪ APNIC CN | 两者合并 | 全；但会混入三大运营商在境外宣告的段 | 语义变成"中国 IP + 运营商海外段"，说不清 |
| C. 仅 APNIC CN | 新增 `--merge-delegated-file` 解析 delegated 统计 | 按 RIR 登记的中国大陆全部地址 | 不反映 BGP 实际宣告 |

## 决策

取 **C**，按维护者"直接从 APNIC 获取"的要求。

- 解析放在分类器里（`src/delegated.rs`），IPv4 记录的地址数不一定是 2 的幂，
  展开成多段 CIDR 后复用 `IpRanges::union` 合并，`cargo test` 可在本地覆盖。
- `just prepare_apnic` 下载后与 APNIC 发布的 `.md5` 比对，不一致直接失败。
- `cn` 不再依赖 `just all` 的结果；文件名不变，下游地址不变。

## 代价与放弃的东西

- `cn` 不再是三家列表的超集：运营商在境外登记、经 BGP 归入三家的段不在 `cn` 里。
- `cn` 反映的是 RIR 登记而不是路由可达性，已分配但未宣告的段也会在表内。
- `guard` 去掉了 ADR-0001 的"`cn` 条目数不多于三家之和"一项，它对新数据源不
  成立；不重叠检查保留。
- 发布流程多依赖一个外部站点 `ftp.apnic.net`。

## 待确认（阻塞项）

无。

## 验证方式

```bash
just check
gh workflow run Release -f dry_run=true --ref feat/cn-from-apnic-delegated
gh run watch   # 日志里应有 "INFO> cn done from APNIC delegated stats"
```

已验证：空跑 run 38848937988 通过，`cn` v4=5497 / v6=2018 条，`guard` 全部通过。

## 回滚

revert 本 ADR 对应的 squash 提交，`cn` 回到 ADR-0001 的三家并集。
