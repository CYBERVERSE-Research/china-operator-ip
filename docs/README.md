---
文档类型: 文档索引
状态: 已批准
负责人: @skylineconnct
最后更新: 2026-10-06
代码基线: 0ca1fbb
验证程度: 已读代码
关联代码: 无
关联决策: 无
---

# china-operator-ip 文档索引

接手开发前按此顺序读：`CLAUDE.md` → `CONTRIBUTING.md` → `README.md` → 本索引 → 相关 ADR → 相关方案设计。

## 写新文档前先读

- [文档规范 STANDARD.md](STANDARD.md) — front-matter、可信度标记、各类型模板、新事实该放哪的路由规则

## 算法契约

| 文档 | 状态 | 一句话 |
|------|------|-------|
| [分类算法](algorithm.md) | 已实施 | 八个步骤的逐步说明；改 `src/` 或 `operators.yaml` 的归属语义前先看这里 |

## 决策记录（ADR）

目前没有 ADR。第一条按 [STANDARD.md §5.1](STANDARD.md) 的模板建到 `docs/adr/ADR-0001-*.md`，并在此表加一行。

| 编号 | 标题 | 状态 |
|------|------|------|
| — | — | — |

## 方案设计

目前没有未实现的设计文档。新建到 `docs/design/`，并在此表加一行。

| 文档 | 状态 | 一句话 |
|------|------|-------|
| — | — | — |

## 任务交接

目前没有在途任务。新建到 `docs/handoff/TASK-NNNN-*.md`，并在此表加一行。

| 编号 | 标题 | 状态 |
|------|------|------|
| — | — | — |

## 其它文档在哪

| 想找 | 看 |
|------|-----|
| 不准动什么 | `../CLAUDE.md` 的「铁律」 |
| 分支、提交、PR、脱敏、发布的硬规则 | `../CONTRIBUTING.md` |
| 九张表是什么、从哪取 | `../README.md` |
| 发布怎么跑、出故障怎么查 | `../workflows/release.md` |
| `main` 分支保护怎么配、怎么核验 | `../workflows/branch-protection.md` |
| `/sanitize` `/check` `/gen` `/release` `/pr` 的执行步骤 | `../.claude/commands/` |
| 运营商匹配规则的回归断言 | `../tests/operators_test.rb` |
