---
文档类型: 决策记录
状态: 已批准
负责人: @skylineconnct
最后更新: 2026-10-24
代码基线: 6747eb0
验证程度: 已完整生成验证
关联代码: .github/workflows/ci.yml, .github/workflows/release.yml
关联决策: ADR-0004
---

# ADR-0005 把 runner 升到 ubuntu-26.04，并让缓存键区分镜像

> 取代 [ADR-0004](ADR-0004-node24-actions-and-pinned-runner.md) 里「runner 固定为
> `ubuntu-24.04`」一项。固定镜像、不用 `ubuntu-latest` 的理由与 action 版本表仍按 ADR-0004。

## 背景

维护者要求把 runner 升到 Ubuntu 26（2026-10-24）。ADR-0004 固定 24.04 时留了两件换镜像前要查的事：
ruby 是否预装，缓存键是否要带上镜像。

两个镜像的差异（actions/runner-images 的 `Ubuntu2404-Readme.md` 与 `Ubuntu2604-Readme.md`，两者都是 20261012 批次）：

| 工具 | `ubuntu-24.04` | `ubuntu-26.04` | 本仓库用在哪 |
|---|---|---|---|
| OS | 24.04.5 LTS | 26.04.1 LTS | — |
| Ruby | 3.2.3 | 3.3.8 | `justfile` 的 Ruby 配方、`tests/operators_test.rb` |
| Rust / Cargo | 1.99.0 | 1.99.0 | 构建分类器、`cargo fmt` / `clippy` / `test` |
| aria2 | 1.37.0 | 1.37.0 | 下载 RIB、autnums、APNIC delegated |
| glibc | 2.39 | 2.43【估算】（按 `locales` 包版本推断） | `~/.cargo/bin` 与 `target/` 里的二进制 |

缓存键原来只有 `runner.os`：Release 的 `${{ runner.os }}-cargo-bin-…`、CI 的 `${{ runner.os }}-cargo-…`。
两个镜像的 `runner.os` 都是 `Linux`，所以换镜像后的第一次 run 会恢复另一个镜像上装好的 `bgpkit-broker`、
`cargo-binstall` 与编译产物。24 → 26 方向 glibc 向后兼容，多半能跑【估算】；回滚 26 → 24 时，在 glibc 2.43
上链接的二进制可能在 2.39 上起不来。

## 目标与非目标

- 目标：CI 与 Release 都跑在 `ubuntu-26.04`。
- 目标：缓存只在同一镜像内复用，升级和回滚都不恢复别的镜像的产物。
- 非目标：不改 action 版本（ADR-0004 的版本表不变）。
- 非目标：不改生成、校验、打包逻辑，十二张表的内容与文件名不变；不改发布节奏（铁律五）。

## 候选方案

| 方案 | 机制 | 代价 |
|---|---|---|
| A. 只改 `runs-on` | 三处 `ubuntu-24.04` → `ubuntu-26.04` | 缓存跨镜像恢复，回滚时可能拿到起不来的二进制 |
| B. 改 `runs-on`，缓存键加 `ImageOS` | 新增一步把镜像设置的 `ImageOS` 环境变量写进 step output，键里引用它 | 每个用缓存的 job 多一个步骤 |
| C. 改 `runs-on`，缓存键里写死 `ubuntu-26.04` | 键与 `runs-on` 各写一遍 | 改了一处忘了另一处，就回到方案 A 的问题 |
| D. 改回 `ubuntu-latest` | 让 GitHub 决定何时迁移 | ADR-0004 否掉的方案，迁移会落在某次定时发布里 |

## 决策

取 **B**。

| 位置 | 原来 | 现在 |
|---|---|---|
| `runs-on`（CI 的 `sanitize`、`test`，Release 的 `release`） | `ubuntu-24.04` | `ubuntu-26.04` |
| 新步骤 `Identify runner image`（CI `test`、Release） | — | `ImageOS` 写进 `steps.image.outputs.os`，变量缺失时直接失败；顺带打印镜像版本、`ruby` 与 `cargo` 版本 |
| Release 缓存键 | `${{ runner.os }}-cargo-bin-…` | `${{ runner.os }}-${{ steps.image.outputs.os }}-cargo-bin-…` |
| CI 缓存键 | `${{ runner.os }}-cargo-…` | `${{ runner.os }}-${{ steps.image.outputs.os }}-cargo-…` |

`restore-keys` 同样带上 `ImageOS`，前缀匹配也不会跨镜像。

不用 `ImageVersion`：它每周随镜像更新变化，带上它等于每周清一次缓存。workflow 的 `env` 上下文读不到
runner 的环境变量，所以要用一个步骤转成 output。

变量缺失时让步骤失败，而不是退回到不带镜像的键：静默退回，就会重新出现跨镜像恢复缓存的问题。

## 代价与放弃的东西

- 镜像里的 Ruby 从 3.2 升到 3.3。配方与测试由 CI 的 `ruby -c` 和 `operators_test.rb` 覆盖，完整生成由 dry run 覆盖。
- 换镜像后第一次 run 没有缓存：Release 要重新下载 `bgpkit-broker`，CI 要从头编译依赖。
- `ImageOS` 是 GitHub 托管镜像设置的环境变量，不是 workflow context。哪天镜像不再设置它，用缓存的 job 会在
  `Identify runner image` 步骤失败，排障见 `workflows/release.md` 四。
- 26.04 镜像刚发布不久，可能有镜像自身的问题。回滚只改 `runs-on`，缓存键会自动分开。

## 待确认（阻塞项）

无。

## 验证方式

```bash
gh workflow run Release -f dry_run=true --ref ci/ubuntu-26-runner
gh workflow run Release -f dry_run=true --ref main   # 对照组：同一时段、ubuntu-24.04
gh run watch
# 通过标准：两次 run 都成功；26.04 那次日志里 ImageOS 为 ubuntu26、OS 为 Ubuntu 26.04，缓存键带 ubuntu26；
# 两次用的是同一批 RIB 时，release notes 里的条目数逐项相同
```

切换前已删掉仓库全部 6 条 Actions 缓存（2026-10-24，共 614 MiB），其中 3 条属于已删除的 PR #5 分支与
`refs/pull/5/merge`。新键下的第一次 run 是冷启动。

结果见下表。

## 回滚

revert 本 ADR 对应的 squash 提交。键里带着 `ImageOS`，回到 24.04 后不会恢复 26.04 上的缓存。
