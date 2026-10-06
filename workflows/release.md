# 发布流程

> 最后更新 2026-10-06 ｜ 代码基线 0ca1fbb ｜ 验证程度 已读代码，未在 Actions 跑过

九张 IP 列表由 `.github/workflows/release.yml` 每三天生成并发布为 Release 资产。
**不手动发版，也不把结果写回任何分支。**

## 一、自动发布

| 项 | 值 |
|---|---|
| 触发 | cron `0 2 */3 * *`（UTC） |
| 耗时 | 约 1 小时，job 超时 180 分钟 |
| 重试 | 生成步骤最多 3 次，每次 90 分钟 |
| Tag | `vYYYY.MM.DD`，同日重复发布追加 `-HHMM` |
| 资产 | 九张 `.txt` + `stat` + `SHA256SUMS` |
| 标记 | `--latest`，所以 `releases/latest/download/<name>` 始终指向最新一次 |

`*/3` 按"日"推进（1、4、7…28、31），月末到下月 1 日的间隔可能是 1~3 天。需要严格
72 小时等间隔要换实现，先写 ADR。

## 二、步骤做了什么

```
checkout → binstall + just → 缓存 ~/.cargo/bin → 确认 aria2
  → just dependency      构建分类器，装 bgpkit-broker 0.7.0
  → just                 prepare（autnums + 4 份 RIB）→ all（三家 × 三张表）→ stat
  → just package         guard 校验 → 汇总到 dist/ → 生成 SHA256SUMS
  → 解析 tag → 生成 release notes → gh release create
```

`just guard` 的校验项：三张表都存在、IPv4 条数 ≥ 500、IPv6 条数 ≥ 50、`46` 表行数
等于 v4 + v6、每行都是对应地址族的合法 CIDR。任一项不过就终止，不会发布。

## 三、手动触发

```bash
# 正常补发一次
gh workflow run Release

# 空跑：完整生成 + guard，但不创建 Release（改生成流程时合并前必做）
gh workflow run Release -f dry_run=true --ref <分支名>

gh run watch
```

## 四、排障判定表

| 现象 | 原因 | 动作 |
|------|------|------|
| `No rib-*.gz or rib-*.bz2 files found` | RIB 下载全失败 | 看 `prepare_rib` 日志；collector 临时不可用就重跑 |
| `Unable to determine <collector> RIB download url` | bgpkit-broker 查不到该 collector 的最新 RIB | 等一轮重跑；持续失败就换 collector，改 `justfile` 的 `prepare_ribs` |
| `Missing asnames.txt` | `bgp.potaroo.net` 拉不到 autnums | 重跑；持续失败要换 ASN 名称数据源，先写 ADR |
| `guard` 报 `< 500` / `< 50` | 分类器产出异常少，通常是 RIB 不完整 | **不要调下限**。先看 `just all` 日志里每家的 `v4=/v6=` 计数 |
| `guard` 报 `malformed prefixes` | 分类器输出了非法 CIDR | 是 `src/` 的 bug，开 issue，不要跳过校验发布 |
| `guard` 报 `46 lines !=` | v4/v6 拆分与合表不一致 | 看 `justfile` 的 `gen` 配方拆分逻辑 |
| `gh release create` 403 | workflow 缺 `contents: write` | 检查 `release.yml` 的 `permissions` |
| tag 已存在 | 同日重复发布 | 正常，会自动退化成 `vYYYY.MM.DD-HHMM` |
| 发布成功但资产少于 11 个 | `package` 漏了文件 | 对照 `just published_operators` 的输出与 `dist/` |

## 五、本地复现一次完整生成

```bash
just dependency
just              # prepare → all → stat，约 1 小时，需要网络
just guard
just package
ls -l dist/
```

`dist/` 和 `result/` 都在 `.gitignore` 里，不会被提交。
