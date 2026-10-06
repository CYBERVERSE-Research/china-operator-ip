# china-operator-ip — Claude Code Project Context

## 这个项目做什么

读取 BGP RIB 快照，按 AS_PATH 把 IPv4/IPv6 前缀归属到中国三大运营商，输出九张
CIDR 列表（电信、移动、联通 × IPv4 / IPv6 / IPv4+IPv6）。结果由 GitHub Actions
每三天发布为 Release 资产，**不写回任何分支**。

项目由 <https://www.skylineconnct.io> 维护，fork 自他人的公开项目，当前仓库是
公开仓库。

## 每次开始工作之前

```sh
just sanitize      # 脱敏审查，有输出先处理，不准带着命中项开始写代码
```

这是铁律一，没有例外。规则全文见 `CONTRIBUTING.md` §五。

## 按这个顺序读懂项目

1. **`README.md`** —— 对外说明：九张表是什么、从哪取、分类规则一句话。
2. **`CONTRIBUTING.md`** —— 开发流程：PR-only、提交规范、脱敏要求、发布方式。
3. **`operators.yaml`** —— 运营商定义。`publish: true` 的三家生成列表，
   `publish: false` 的四家只作分类边界。改这个文件前先读下面的铁律三。
4. **`docs/algorithm.md`** —— 分类算法逐步说明，`src/` 的行为契约。
5. **`justfile`** —— 数据准备、生成、校验、打包的全部流程。
6. **`src/classifier.rs`** + **`src/asn.rs`** —— 归属算法本体。
7. **`docs/README.md`** —— 文档索引。做任何不是一行修正的改动前先读它；
   新事实该放哪由 `docs/STANDARD.md` 判定。

## 仓库结构

```
china-operator-ip/
├── CLAUDE.md                   ← 本文件
├── README.md                   ← 对外说明
├── CONTRIBUTING.md             ← 开发流程（PR-only、提交规范、脱敏、发布）
├── operators.yaml              ← 运营商定义与分类边界
├── justfile                    ← prepare / all / guard / stat / package / check / sanitize
├── Cargo.toml / Cargo.lock
├── src/                        ← BGP 分类器（Rust）
│   ├── main.rs                 ← CLI 参数
│   ├── classifier.rs           ← 归属算法
│   ├── asn.rs                  ← ASN 集合、国家数据、上游判定
│   ├── ip.rs                   ← 前缀区间与 CIDR 化
│   └── cache.rs                ← 分类结果缓存
├── scripts/
│   ├── sanitize.sh             ← 脱敏扫描器（无输出 = 通过）
│   ├── sanitize-denylist.txt   ← 禁止出现的标识
│   ├── sanitize-allowlist.txt  ← 带理由的豁免
│   └── check-ruby-recipes.py   ← 对 justfile 里的 ruby 配方跑 ruby -c
├── tests/operators_test.rb     ← 运营商匹配规则与发布集合的回归测试
├── docs/
│   ├── STANDARD.md             ← 文档规范
│   ├── README.md               ← 文档索引
│   └── algorithm.md            ← 分类算法
├── workflows/
│   ├── release.md              ← 发布流程与排障
│   └── branch-protection.md    ← main 分支保护配置与核验
└── .github/
    ├── workflows/ci.yml        ← PR 门禁：sanitize + test
    ├── workflows/release.yml   ← 每三天发布一次
    ├── pull_request_template.md
    └── CODEOWNERS
```

## 铁律

1. **动手前先 `just sanitize`**。这是公开仓库，命中项先清掉再写代码。
2. **不直接推 `main`，也不自己合并 PR**。一切改动走 PR，CI 的 `sanitize` 与
   `test` 必须绿，然后**由仓库所有者在 GitHub web 上手动点击 Squash and merge**。
   你的流程止于 `gh pr create`——不准执行 `gh pr merge`，不准用 API 合并。
   只保留 `main` 一个长期分支。
3. **`operators.yaml` 里 `publish: false` 的条目不准删**。归属算法从 origin 向
   上游走共同路径后缀，遇到最近的已知运营商 ASN 后停止；教育网、科技网、鹏博士、
   谷歌中国正是这些停止边界。删掉它们，这些网络经电信/联通转接的地址会被归入
   三大运营商列表。`tests/operators_test.rb` 对此有回归断言。
4. **生成结果与凭据都不入库**。`result/`、`dist/`、`rib-*`、`asnames.txt` 全在
   `.gitignore` 里，脱敏扫描第 6 项也会拦住它们。结果只经 Release 发布。
   `.gitignore` 的「凭据」段**不准删条目**——扫描第 8 项逐条核对它还在不在，
   第 7 项盯着 `git add -f` 绕过的情况。凭据只放仓库外，不进文件也不进提交信息。
5. **只有一个定时任务**：`Release` workflow 的 `0 2 */3 * *`。不准再加别的
   schedule；要周期性动作先在 PR 里说明理由。
6. **`LICENSE` 的原始版权声明不准动**。MIT 许可证要求保留，脱敏扫描已排除该
   文件。改 fork 归属时改 `Cargo.toml`、`README.md`，不要改 `LICENSE`。
7. **九张表的文件名是对外契约**：`<operator>.txt` / `<operator>6.txt` /
   `<operator>46.txt`，加上 `stat` 与 `SHA256SUMS`。下游按
   `releases/latest/download/<name>` 取数据，改名就是破坏兼容性。
8. **改生成流程要先空跑**。动到 `operators.yaml`、`justfile` 的生成/校验配方或
   `src/` 的分类逻辑时，CI 的快速检查证明不了生成结果正确。CI 不跑完整生成不是
   因为慢（实测 4.5 分钟），是因为它依赖从外部归档站下载数 GB 的 RIB 快照。
   合并前跑 `gh workflow run Release -f dry_run=true --ref <分支>`，把 run 链接
   贴进 PR。
9. **先记录决策再实现**。改动分类语义、发布节奏、输出文件集合，先按
   `docs/STANDARD.md` 写 ADR 或方案设计，再动代码。不准把设计细节堆进本文件
   ——只留规则加一行指针。

## 本地自检

```sh
just sanitize   # 脱敏审查
just check      # 脱敏 + cargo fmt --check + clippy -D warnings + cargo test
                # + justfile ruby 配方语法检查 + ruby 运营商测试
```

`just check` 与 CI 的两个 job 等价。完整生成（需要网络，要下载 4 份 RIB 快照；
Actions 上实测 4.5 分钟）：

```sh
just            # prepare → all → stat
just guard      # 校验九张表
just package    # 汇总到 dist/ 并生成 SHA256SUMS
```

## 已知坑

- **`just` 配方里的 Ruby 会递归调用 `just`**。`gen` 调 `operator_asns` 和
  `get_asn_candidates`，后者又调 `get_asn_candidates_raw`。所以 `just` 必须在
  `PATH` 里，`tests/operators_test.rb` 在临时目录里跑也依赖这一点。
- **`just gen <边界运营商>` 会直接失败**，这是故意的，见铁律三。
- **`cron: '0 2 */3 * *'` 不是严格的 72 小时**。`*/3` 按"日"推进，月末到下月
  1 日的间隔可能是 1~3 天。需要严格等间隔要换成另一种实现，先写 ADR。
- **`guard` 的下限只用于拦截整体失败**（分类器产出为空），不是用来跟踪真实前缀
  数量波动的。前缀数正常浮动不要去调下限，先查生成日志。
- **`guard`、`package`、`stat`、`all` 四个配方不在 `operators_test.rb` 的执行
  路径上**，语法错误本来要等一小时的发布任务才暴露。`scripts/check-ruby-recipes.py`
  对所有 ruby 配方跑 `ruby -c` 把这个缺口堵住；本机没有 ruby 时它会跳过并告警，
  在 CI（`CI` 环境变量存在）里找不到 ruby 则直接失败。

## 自动化

| 名字 | 触发 | 做什么 |
|------|------|--------|
| `CI` | PR → `main`、push → `main` | `sanitize` 与 `test` 两个 job，PR 门禁 |
| `Release` | cron `0 2 */3 * *`、手动 | 完整生成 → `guard` → `package` → 创建 Release |

`Release` 手动触发支持 `dry_run=true`：完整生成并校验，但不创建 Release。

## Agent 本地配置

`.claude/` **不入库**（在 `.gitignore` 里，脱敏扫描第 9 项也会拦住它被跟踪）。
本仓库公开，agent 的工作流程不对外发布。

所以别指望克隆下来就有 slash command。每条流程的权威出处都在仓库里：

| 要做的事 | 看 |
|---|---|
| 脱敏审查与命中项处理 | `CONTRIBUTING.md` 五 |
| 合并前自检 | 本文件「本地自检」 |
| 本地完整生成 | `workflows/release.md` 五 |
| 发布状态与手动触发 | `workflows/release.md` 三 |
| 开 PR 的完整顺序 | `CONTRIBUTING.md` 二 |
