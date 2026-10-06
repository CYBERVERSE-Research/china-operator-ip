# 开发流程

本仓库是公开仓库。下列规则是机械判定的，不留"视情况而定"的余地。

## 一、铁律

1. **`main` 受保护，任何人不得直接推送**，包括仓库管理员和自动化。所有改动经 Pull Request 合入。
2. **不得对 `main` 执行 force push 或删除**。
3. **只保留 `main` 一个长期分支**。生成结果通过 Release 发布，不写回任何分支。
4. **每次动手改之前先跑脱敏审查**：`just sanitize`。有输出就先处理，不准带着命中项开始写代码。
5. **PR 必须通过 CI 的 `sanitize` 与 `test` 两个检查**，且至少一位 reviewer 批准后才能合并。
6. **合并方式固定为 squash**，合并后删除源分支。

分支保护的具体配置与核验命令见 [workflows/branch-protection.md](workflows/branch-protection.md)。

## 二、一次改动的完整顺序

```sh
# 1. 脱敏审查（在动手之前）
just sanitize

# 2. 从最新 main 切分支
git switch main && git pull --ff-only
git switch -c <type>/<简短描述>

# 3. 改代码，改文档

# 4. 本地自检：脱敏 + 格式 + clippy + 单元测试 + 运营商分类测试
just check

# 5. 提交并推送分支
git commit -m "<type>: <一句话说明>"
git push -u origin HEAD

# 6. 开 PR
gh pr create --base main --fill
```

CI 全绿、review 通过后：

```sh
gh pr merge --squash --delete-branch
```

## 三、分支与提交命名

分支名 `<type>/<简短描述>`，`type` 取下表之一。

| type | 用于 |
|------|------|
| `feat` | 新增能力 |
| `fix` | 修正错误行为或错误分类 |
| `refactor` | 不改变外部行为的重构 |
| `docs` | 只改文档 |
| `ci` | 只改 GitHub Actions 或脚本 |
| `chore` | 依赖升级、配置整理 |

提交信息首行 `<type>: <一句话说明>`，用祈使句，不超过 72 字符，不加句号。正文说明"为什么"，不复述 diff。

## 四、改动生成流程时的额外要求

改到 `operators.yaml`、`justfile` 的生成/校验配方或 `src/` 的分类逻辑时，CI 的快速检查不足以证明生成结果正确（CI 不跑完整生成，一次完整生成约 1 小时）。合并前必须额外做一次空跑：

```sh
gh workflow run Release -f dry_run=true --ref <你的分支>
gh run watch
```

空跑会完整下载数据、生成九张表并执行 `just guard`，但不会创建 Release。把 run 链接贴进 PR 描述。

## 五、脱敏要求

本仓库从他人项目 fork 而来，且对外公开。以下内容一律不得入库：

| 不得出现 | 说明 |
|---|---|
| 任何邮箱地址 | 例外只有 `noreply@github.com`，豁免写在 allowlist |
| 任何凭据 | token、API key、私钥、密码 |
| 开发机绝对路径 | `/home/...`、`/root/...`、`/Users/...` |
| 内网地址与内部主机名 | RFC1918 地址、`127.0.0.1`、`*.internal`、`*.local` |
| 上游个人身份与其私有域名、镜像 | 清单见 `scripts/sanitize-denylist.txt` |
| 生成产物 | `result/`、`dist/`、`rib-*`、`asnames.txt` 等 |

`LICENSE` 中的原始版权声明**必须保留**——MIT 许可证要求如此，扫描脚本已将其排除。

扫描器：`scripts/sanitize.sh`，无输出即通过。新增豁免要写在 `scripts/sanitize-allowlist.txt` 并注明理由；不准为了让检查通过而随手添加片段。

## 六、发布

不手动发版。`Release` workflow 每三天自动生成并发布一次（cron `0 2 */3 * *`）。需要补发时手动触发同一 workflow。细节与排障见 [workflows/release.md](workflows/release.md)。

## 七、文档

新事实该写进哪个文件、front-matter 怎么填、断言要带什么可信度标记，一律按 [docs/STANDARD.md](docs/STANDARD.md)。文档索引是 [docs/README.md](docs/README.md)。
