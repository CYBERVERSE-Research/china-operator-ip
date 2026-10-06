按本仓库流程开一个 Pull Request：脱敏、自检、提交、推分支、建 PR。

## 前置检查

```bash
cd "$(git rev-parse --show-toplevel)"
git branch --show-current
```

当前在 `main` 上则**停下**——本仓库禁止直接改 `main`。先切分支：

```bash
git switch main && git pull --ff-only
git switch -c <type>/<简短描述>
```

`type` 取 `feat` / `fix` / `refactor` / `docs` / `ci` / `chore` 之一。

## 合并前自检

```bash
just check
```

全绿才继续。失败处理见 `/check`。

改动涉及 `operators.yaml`、`justfile` 生成配方或 `src/` 分类逻辑时，额外空跑一次并记下 run 链接：

```bash
gh workflow run Release -f dry_run=true --ref "$(git branch --show-current)"
gh run watch
```

## 提交与推送

```bash
git add -A
git commit -m "<type>: <一句话说明>"
git push -u origin HEAD
```

提交信息首行祈使句，不超过 72 字符，不加句号。正文说明"为什么"，不复述 diff。

## 建 PR

```bash
gh pr create --base main --fill
```

然后按 `.github/pull_request_template.md` 逐条勾选，把空跑 run 链接填进去。

## 合并——不是你的事

**不准执行 `gh pr merge`，也不准用 API 合并。** 合并由仓库所有者在 GitHub web
界面上手动点击 Squash and merge。

开完 PR 就停下，把这些交给用户：

- PR 链接
- `gh pr checks <号>` 的结果
- 还需要人工确认的点（例如空跑 run 链接、对外契约是否变化）

然后等。不要问"要我合并吗"——答案已经是否。

（合并方式在仓库设置里已固定为 squash：`allow_merge_commit` 与
`allow_rebase_merge` 都是 `false`，且 `main` 要求线性历史。）
