---
文档类型: 任务交接
状态: 进行中
负责人: @znz9xagcza7NKGby
最后更新: 2026-10-06
代码基线: 3d4db00
验证程度: 已读代码
关联代码: workflows/branch-protection.md
关联决策: 无
---

# TASK-0001 应用 GitHub 端的仓库设置

## 当前状态（一句话）

仓库内的全部改动已完成并提交在 `chore/repo-standards` 分支；需要 admin 权限的
GitHub 端设置（默认分支改名、分支保护、推分支开 PR）全部未完成，缺凭据。

## 已完成

| 项 | 落点 |
|---|---|
| 脱敏审查工具与规则 | `scripts/sanitize.sh`、`scripts/sanitize-{deny,allow}list.txt` |
| justfile ruby 配方语法检查 | `scripts/check-ruby-recipes.py`，接进 `just check` 与 CI |
| 只发布三家运营商，各三张表 | `operators.yaml`、`justfile` |
| 边界运营商保留为分类边界 | `operators.yaml` 的 `publish: false`，断言在 `tests/operators_test.rb` |
| 每三天发 Release，不写回分支 | `.github/workflows/release.yml` |
| PR 门禁 | `.github/workflows/ci.yml` 的 `sanitize` 与 `test` |
| 删掉每日定时与 ip-lists 分支上传 | 原 `.github/workflows/build.yml` 已删除 |
| 开发流程与铁律 | `CONTRIBUTING.md`、`CLAUDE.md` |
| 文档规范与索引 | `docs/STANDARD.md`、`docs/README.md` |
| 运行手册 | `workflows/release.md`、`workflows/branch-protection.md` |
| Agent 命令 | `.claude/commands/` 五条 |
| 脱敏改写与维护方变更 | `README.md`、`Cargo.toml`、`.github/ISSUE_TEMPLATE/` |
| 本地分支改名 | `master` → `main`（本地） |

## 阻塞项

【待确认】当前会话的 GitHub 凭据属于账号 `Wujiuuu`，对
`CYBERVERSE-Research/china-operator-ip` 只有 `pull` 权限。已实测：

| 操作 | 结果 |
|---|---|
| `git push` | `403 Permission to ... denied to Wujiuuu` |
| `POST /branches/master/rename` | `403 Must have admin access to rename the default branch` |
| 读取分支保护 | `404`（尚未配置过） |

本地 `git config user.name` / `user.email` 已按用户指定的值设好（存在
`.git/config`，不入库——公开仓库不写邮箱，见 `CONTRIBUTING.md` §五）。但提交署名
不提供推送凭据，所以上面三项仍然失败。

解除方式二选一：

```bash
# A. 以有 admin 权限的账号登录（交互式，需要人工操作）
gh auth login
gh auth setup-git

# B. 给现有账号加写权限
#    在 GitHub 上把 Wujiuuu 加为该仓库的 admin
```

## 下一步（有序）

| # | 做什么 | 验收标准 |
|---|-------|---------|
| 1 | 换成有 admin 权限的凭据 | `gh api repos/CYBERVERSE-Research/china-operator-ip --jq .permissions.admin` 为 `true` |
| 2 | 默认分支改名 `master` → `main` | `gh api repos/... --jq .default_branch` 为 `main` |
| 3 | 固定 squash 合并并开启合并后删分支 | `allow_merge_commit` 为 `false`，`delete_branch_on_merge` 为 `true` |
| 4 | 推 `chore/repo-standards` 并开 PR | PR 上 `sanitize` 与 `test` 两个检查出现并通过 |
| 5 | 合并 PR（squash） | `main` 上有本次全部改动 |
| 6 | 配置 `main` 分支保护 | `git push --dry-run origin main` 被拒 |
| 7 | 清理多余远端分支 | `gh api repos/.../branches --jq '[.[].name]'` 只有 `["main"]` |
| 8 | 空跑一次 Release 验证生成流程 | `gh workflow run Release -f dry_run=true` 跑通，`just guard` 过 |
| 9 | 等第一次定时发布，或手动发一次 | `releases/latest/download/chinanet.txt` 可下载 |

第 2、3、6、7 步的逐条命令与核验命令见 `workflows/branch-protection.md`。
第 8、9 步见 `workflows/release.md`。

**注意第 6 步必须在第 5 步之后**：先配保护再合并，PR 会因为 `main` 不接受任何
推送而卡住（`enforce_admins: true` 对管理员同样生效）。

## 不准动的东西

- `LICENSE` 的原始版权声明。MIT 要求保留，脱敏扫描已排除该文件。
- `operators.yaml` 里 `publish: false` 的四个条目。见 `CLAUDE.md` 铁律三。
- 九张表的文件名。下游按 `releases/latest/download/<name>` 取数据。

## 验收命令

```bash
REPO=CYBERVERSE-Research/china-operator-ip
gh api "repos/${REPO}" --jq '{default_branch, allow_squash_merge, allow_merge_commit, delete_branch_on_merge}'
gh api "repos/${REPO}/branches" --jq '[.[].name]'
gh api "repos/${REPO}/branches/main/protection" --jq '{
  checks: .required_status_checks.contexts,
  admins: .enforce_admins.enabled,
  force_push: .allow_force_pushes.enabled,
  deletions: .allow_deletions.enabled
}'
git push --dry-run origin main   # 必须被拒
```
