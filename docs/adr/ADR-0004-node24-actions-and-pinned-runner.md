---
文档类型: 决策记录
状态: 已批准
负责人: @skylineconnct
最后更新: 2026-10-23
代码基线: 194562c
验证程度: 已完整生成验证
关联代码: .github/workflows/ci.yml, .github/workflows/release.yml
关联决策: 无
---

# ADR-0004 把 Actions 升到 Node 24 版本，并把 runner 固定为 ubuntu-24.04

## 背景

`v2026.10.23` 的 Release run 39969438756 与 PR #5 的 CI run 39969218671 带着两条注记（2026-10-23）：

| 级别 | 内容 |
|---|---|
| warning | `nick-fields/retry@v3` 与 `extractions/setup-just@v3` 内部调用的 `extractions/setup-crate` 仍以 Node.js 20 为目标，被强制跑在 Node.js 24 上 |
| notice | `ubuntu-latest` 从 2026-10-19 起逐步迁到 Ubuntu 26；这两次 run 还在 Ubuntu 24.04.5 上 |

另有一处不是告警但同属 Actions 卫生：Release workflow 用 `cargo-bins/cargo-binstall@main`，
跟随分支而不是版本，而这个 job 持有 `contents: write`，能创建 Release。

## 目标与非目标

- 目标：消除 Node.js 20 告警；Release workflow 不再引用会移动的分支。
- 目标：镜像迁移不在某次定时发布里悄悄改变运行环境。
- 非目标：不改生成、校验、打包的任何逻辑，十二张表的内容与文件名不变。
- 非目标：不改发布节奏（铁律五）。

## 候选方案

| 方案 | 机制 | 代价 |
|---|---|---|
| A. 只升 action 版本，保留 `ubuntu-latest` | 改 `uses:` | 镜像迁到 Ubuntu 26 时，配方依赖的预装 ruby 与 `~/.cargo/bin` 缓存可能失效，失败会出现在定时发布里 |
| B. 升 action 版本，并固定 `ubuntu-24.04` | 另改 `runs-on:` | 将来要主动升级镜像（GitHub 对 24.04 的支持预计到 2029 年【估算】） |
| C. 升 action 版本，保留 `ubuntu-latest`，另加 `ruby/setup-ruby` | 显式装 ruby | 多一个第三方 action；缓存键问题仍在 |

## 决策

取 **B**。

| 位置 | 原来 | 现在 | 依据 |
|---|---|---|---|
| `actions/checkout` | `v6` | `v7` | 最新大版本；v7 只新增阻止 `pull_request_target` / `workflow_run` 检出 fork PR，本仓库不用这两种触发 |
| `actions/cache` | `v5` | `v6` | 最新大版本；只改为 ESM 打包 |
| `extractions/setup-just` | `v3` | `v4` | v4 换用 Node 24 的 `setup-crate` v2.0.0 |
| `nick-fields/retry` | `v3` | `v4` | v4 改为 `node24`，`timeout_minutes` / `max_attempts` / `command` 输入不变 |
| `cargo-bins/cargo-binstall` | `@main`（安装最新版） | `@v1.25.2`，`version: 1.25.2` | 钉到发布已超过两周的版本，同时固定 action 脚本与安装的二进制 |
| `runs-on` | `ubuntu-latest` | `ubuntu-24.04` | 与上次通过的发布环境一致 |

固定镜像的理由：

- `just` 配方全是 Ruby，CI 的 `test` job 与 Release 都直接用镜像预装的 `ruby`，workflow 里没有安装步骤。
- Release 缓存 `~/.cargo/bin` 的键是 `${{ runner.os }}-cargo-bin-…`，Ubuntu 24 与 26 的 `runner.os` 都是 `Linux`，一个镜像上编译的 `bgpkit-broker` 会被另一个镜像恢复使用。

## 代价与放弃的东西

- 要人工跟进镜像升级：换 `ubuntu-26.04` 时同时检查 ruby 是否预装、缓存键是否要带上镜像版本，并改本 ADR。
- `cargo-binstall` 不再自动拿到新版；它只用来安装 `bgpkit-broker`，版本固定反而是想要的。

## 待确认（阻塞项）

无。

## 验证方式

```bash
gh workflow run Release -f dry_run=true --ref ci/node24-actions-pinned-runner
gh run watch
# 通过标准：run 成功；注记里不再有 "Node.js 20 is deprecated"；日志的 Operating System 为 Ubuntu 24.04
```

已验证（提交 `e7aaa49`）：

| run | 结果 | 注记 | 环境 |
|---|---|---|---|
| Release dry run [39971258592](https://github.com/CYBERVERSE-Research/china-operator-ip/actions/runs/39971258592) | 成功，`guard` 通过，三家条目数与 `v2026.10.23` 相同 | 无 | Ubuntu 24.04.5；下载的是 cargo-binstall v1.25.2 |
| CI [39971325345](https://github.com/CYBERVERSE-Research/china-operator-ip/actions/runs/39971325345) | `sanitize`、`test` 均通过 | 无 | Ubuntu 24.04.5 |

`Generate IP lists` 步骤 145 秒（升级前的 run 39969438756 为 156 秒）。

## 回滚

revert 本 ADR 对应的 squash 提交。
