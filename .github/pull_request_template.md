## 这个 PR 做了什么

<!-- 一句话说清改动本身，不要复述 diff -->

## 为什么

<!-- 动机。修正错误分类的，写清错在哪、依据是什么 -->

## 自检

- [ ] `just sanitize` 无输出（动手之前跑过一次，提交之前再跑一次）
- [ ] `just check` 全绿
- [ ] 改动涉及 `operators.yaml` / `justfile` 生成配方 / `src/` 分类逻辑时，已跑
      `gh workflow run Release -f dry_run=true --ref <本分支>`，run 链接：<!-- 贴这里 -->
- [ ] 改动涉及分类语义时，`tests/operators_test.rb` 已补回归断言
- [ ] 新事实已按 `docs/STANDARD.md` 的路由规则落到对应文件，`docs/README.md` 索引已更新

## 对外契约

- [ ] 没有改动九张表的文件名、CIDR 行格式或 Release 资产集合
- [ ] 如果改了，已在 `CLAUDE.md` 铁律七说明，并写了 ADR
