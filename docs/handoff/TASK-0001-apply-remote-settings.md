---
文档类型: 任务交接
状态: 已完成
负责人: @znz9xagcza7NKGby
最后更新: 2026-10-06
代码基线: cc80d20
验证程度: 已在生产验证
关联代码: workflows/branch-protection.md, workflows/release.md
关联决策: 无
---

# TASK-0001 应用 GitHub 端的仓库设置

## 当前状态（一句话）

全部完成并核验：默认分支为 `main` 且受保护、远端只剩一个分支、首个 Release
`v2026.10.06` 已发布且固定下载地址可用。

## 已完成（含核验值）

| 步骤 | 核验结果 |
|------|---------|
| 默认分支改名 `master` → `main` | `default_branch: main`，`master` 已不存在 |
| 合并方式固定 | `allow_squash_merge: true`、`allow_merge_commit: false`、`allow_rebase_merge: false`、`delete_branch_on_merge: true` |
| 首个 PR | [#1](https://github.com/CYBERVERSE-Research/china-operator-ip/pull/1)，CI 两个 job 全绿后 squash 合并为 `cc80d20` |
| `main` 分支保护 | 必需检查 `["sanitize","test"]`、`strict: true`、`enforce_admins: true`、批准数 `0`、`dismiss_stale_reviews: true`、线性历史、禁 force push、禁删除、讨论须解决 |
| 直推 `main` 被拒 | `remote: error: GH006: Protected branch update failed`，提示「Changes must be made through a pull request」与「2 of 2 required status checks are expected」 |
| 分支清理 | 远端 `["main"]` |
| 首个 Release | `v2026.10.06`，标 Latest，11 个资产（九张表 + `stat` + `SHA256SUMS`） |

## 发布流程的实测数据（2026-10-06，run 37416578982）

| 项 | 值 |
|---|---|
| 整个 run | 4.5 分钟 |
| `just dependency` | 1 分 36 秒 |
| `prepare` + `all` + `stat` | 2 分 31 秒 |
| `package` | 1 秒 |
| `gh release create` | 3 秒 |

生成条目数：`chinanet` v4=2823 v6=452、`cmcc` v4=1004 v6=158、`unicom` v4=1734 v6=693。
`just guard` 输出 `guard checks passed (3 operators x 3 lists)`，三张合表行数均等于
对应 v4 + v6。

匿名实测 `releases/latest/download/<name>` 对九张表、`stat`、`SHA256SUMS` 均返回
HTTP 200，`sha256sum -c SHA256SUMS` 十项全部 OK。

此前写在文档里的「一次完整生成约 1 小时」是沿用上游（8 家运营商 + 5 个 RIR 下载）
的估计，与本仓库不符，已按实测改正，`release.yml` 的超时也从 180/90 分钟收紧到
60/30 分钟。

## 不准动的东西

- `LICENSE` 的原始版权声明。MIT 要求保留，脱敏扫描已排除该文件。
- `operators.yaml` 里 `publish: false` 的四个条目。见 `CLAUDE.md` 铁律三。
- 九张表的文件名。下游按 `releases/latest/download/<name>` 取数据。
- `.claude/` 不入库。本仓库公开，agent 工作流程不对外发布，扫描第 9 项会拦住它。

## 后续

下一次定时发布：`0 2 */3 * *`（UTC）。排障判定表见 `workflows/release.md` 四。
