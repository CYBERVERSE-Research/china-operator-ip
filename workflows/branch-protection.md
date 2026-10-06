# main 分支保护

> 最后更新 2026-10-06 ｜ 代码基线 0ca1fbb ｜ 验证程度 未在本仓库应用（需要 admin 权限）

本仓库只保留 `main` 一个长期分支，且 `main` 受保护：不得直接推送、不得 force push、不得删除，所有改动经 PR 合入且 CI 必须全绿。

配置需要仓库的 **admin** 权限。下列命令按顺序执行一次即可。

## 一、把默认分支改名为 main

仓库 fork 过来时默认分支是 `master`。改名用 GitHub 的 rename 接口，它会自动把
已有 PR 和下游 fork 的引用迁过去：

```bash
REPO=CYBERVERSE-Research/china-operator-ip

gh api -X POST "repos/${REPO}/branches/master/rename" -f new_name=main
```

本地跟进：

```bash
git branch -m master main 2>/dev/null || true
git fetch origin --prune
git branch -u origin/main main
git remote set-head origin -a
```

## 二、删除多余分支

只保留 `main`。生成结果走 Release，不需要 `ip-lists` 之类的数据分支。

```bash
# 列出所有远端分支，确认除 main 之外该删的
gh api "repos/${REPO}/branches" --jq '.[].name'

# 逐个删除（<branch> 换成实际名字）
git push origin --delete <branch>
```

## 三、配置分支保护

```bash
gh api -X PUT "repos/${REPO}/branches/main/protection" --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["sanitize", "test"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true,
  "block_creations": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON
```

各项的作用：

| 字段 | 值 | 效果 |
|------|-----|------|
| `required_status_checks.contexts` | `sanitize`, `test` | CI 这两个 job 不绿不能合并 |
| `required_status_checks.strict` | `true` | 分支必须先与最新 `main` 同步 |
| `enforce_admins` | `true` | 管理员同样不能绕过，包括直接推送 |
| `required_approving_review_count` | `0` | 强制走 PR，但不要求他人批准（单人维护） |
| `dismiss_stale_reviews` | `true` | 新提交作废既有批准 |
| `required_linear_history` | `true` | 只接受 squash / rebase，拒绝 merge commit |
| `allow_force_pushes` | `false` | 禁止 force push |
| `allow_deletions` | `false` | 禁止删除 `main` |
| `required_conversation_resolution` | `true` | PR 上的讨论必须解决完 |

## 四、把合并方式固定为 squash

```bash
gh api -X PATCH "repos/${REPO}" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true
```

## 五、核验

```bash
# 保护是否生效
gh api "repos/${REPO}/branches/main/protection" --jq '{
  checks: .required_status_checks.contexts,
  strict: .required_status_checks.strict,
  admins: .enforce_admins.enabled,
  reviews: .required_pull_request_reviews.required_approving_review_count,
  linear: .required_linear_history.enabled,
  force_push: .allow_force_pushes.enabled,
  deletions: .allow_deletions.enabled
}'

# 默认分支与分支清单
gh api "repos/${REPO}" --jq '{default_branch, allow_squash_merge, allow_merge_commit, delete_branch_on_merge}'
gh api "repos/${REPO}/branches" --jq '[.[].name]'

# 直接推 main 必须被拒
git push --dry-run origin main
```

期望结果：`checks` 为 `["sanitize","test"]`、`admins` 为 `true`、`force_push` 与
`deletions` 为 `false`、分支清单只有 `["main"]`、最后一条 push 被拒绝。

## 判定表

| 现象 | 原因 | 动作 |
|------|------|------|
| `gh api` 返回 403 | 当前 token 没有 admin 权限 | 换一个有 admin 的账号或 token |
| 返回 404 Branch not found | 还没执行第一步改名 | 先做「一、把默认分支改名为 main」 |
| PR 上 `sanitize` / `test` 一直 pending | job 名与 `contexts` 不一致 | 对照 `.github/workflows/ci.yml` 里的 `name:` |
| 合并按钮灰着且提示 out-of-date | `strict: true` 要求先同步 | 在 PR 上点 Update branch，或本地 rebase 后推 |
