跑合并前的全部本地检查：脱敏审查、格式、clippy、单元测试、配方语法、运营商分类测试。

## 执行

```bash
cd "$(git rev-parse --show-toplevel)"
just check
```

等价于 CI 的 `sanitize` 与 `test` 两个 job。顺序固定，脱敏审查排在最前面。

## 失败时

| 失败项 | 动作 |
|--------|------|
| `scripts/sanitize.sh` 有输出 | 走 `/sanitize` 的处理流程，不要跳过 |
| `cargo fmt --check` | 跑 `cargo fmt` 修掉 |
| `cargo clippy` | 按提示改。CI 用 `-D warnings`，告警等于失败 |
| `cargo test` | 看失败断言。改了 `src/` 的分类逻辑就要同步更新测试与 `docs/algorithm.md` |
| `scripts/check-ruby-recipes.py` | `justfile` 里某个 ruby 配方有语法错误，报错里带配方名和行号 |
| `ruby tests/operators_test.rb` | 改了 `operators.yaml` 的匹配规则或 `publish` 标记时会失败；确认改动是故意的，再更新测试里的期望值 |

## 注意

本仓库的 `justfile` 配方和 `tests/operators_test.rb` 都用 Ruby，且会递归调用 `just`。本地没有 `ruby` 或 `just` 时这两项跑不了——不要因此改测试，改为在 PR 上依赖 CI，并把结论标 `【未验证】`。配方语法检查在缺 ruby 时会跳过并告警，别把那条告警当成通过。

完整生成（约 1 小时，需要网络）不在 `just check` 范围内，见 `/gen`。
