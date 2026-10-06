查看发布状态，或手动触发一次发布/空跑。日常发布由 cron 自动完成，不需要人工介入。

## 查看状态

```bash
cd "$(git rev-parse --show-toplevel)"
gh release list --limit 5
gh run list --workflow Release --limit 5
```

## 手动触发

```bash
# 补发一次（走 main 的最新提交）
gh workflow run Release

# 空跑：完整生成 + guard，但不创建 Release
gh workflow run Release -f dry_run=true --ref <分支名>

gh run watch
```

改动 `operators.yaml`、`justfile` 的生成/校验配方或 `src/` 的分类逻辑时，**合并前必须空跑一次**，并把 run 链接贴进 PR 描述。CI 不跑完整生成，证明不了生成结果正确。

## 规则

| 项 | 值 |
|---|---|
| 自动触发 | cron `0 2 */3 * *`（UTC），这是本仓库唯一的定时任务 |
| Tag | `vYYYY.MM.DD`，同日重复发布追加 `-HHMM` |
| 资产 | 九张 `.txt` + `stat` + `SHA256SUMS` |
| 写回分支 | 没有。结果只经 Release 发布 |

不准手动上传资产，也不准手动改已发布 Release 的资产——下游按 `releases/latest/download/<name>` 取数据，手改会造成与 `SHA256SUMS` 不一致。

## 排障

判定表见 `workflows/release.md` §四。
