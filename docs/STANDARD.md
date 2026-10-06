---
文档类型: 文档规范
状态: 已批准
负责人: @skylineconnct
最后更新: 2026-10-06
代码基线: cc80d20
验证程度: 已读代码
关联代码: 无
关联决策: 无
---

# china-operator-ip 文档规范

本仓库的文档由人和 agent 共同读写。规范的唯一目的是：**另一个 agent 不读代码就能知道"这件事的事实写在哪、可信到什么程度"**，并且两个不同的 agent 会把同一条新事实放进同一个文件。

## 一、文件类型与归属

| 类型 | 位置 | 读者 | 回答的问题 |
|------|------|------|-----------|
| 项目铁律 | `CLAUDE.md` | agent（每次会话自动加载） | 不准动什么、改完怎么发布 |
| 开发流程 | `CONTRIBUTING.md` | 人 + agent | 分支、提交、PR、脱敏、发布的硬规则 |
| 对外说明 | `README.md` | 人（第一次接触项目） | 九张表是什么、从哪取 |
| 决策记录 ADR | `docs/adr/ADR-NNNN-*.md` | agent + 人 | 为什么选 A 不选 B，代价是什么 |
| 方案设计 | `docs/design/*.md` | 承接开发的 agent | 要实现什么、配置/输出长什么样 |
| 算法契约 | `docs/algorithm.md` | 改 `src/` 的人 | 分类逐步怎么算，输入输出是什么 |
| 运行手册 | `workflows/*.md` | 值班的人或 agent | 发布怎么跑、出故障怎么查 |
| 任务交接 | `docs/handoff/TASK-NNNN-*.md` | 下一个接手的 agent | 做到哪了、下一步做什么、卡在哪 |

## 二、新事实路由规则（机械判定，按顺序命中即停）

1. 改了会**破坏对外契约**的约束（九张表的文件名、CIDR 行格式、Release 资产集合、`releases/latest/download/` 地址）→ 写 `CLAUDE.md` 的「铁律」，细节另开 `docs/design/`。
2. 改了**分类语义**（归属边界、ASN 匹配规则、前缀合并方式）→ 更新 `docs/algorithm.md`，并在 `tests/operators_test.rb` 补回归断言。
3. 是一次**取舍判断**（选了 A 放弃 B）→ 新建 `docs/adr/ADR-NNNN`，并在 `docs/README.md` 索引加一行。
4. 是**还没实现的设计**（新输出格式、新数据源、新配置项）→ `docs/design/`，状态标 `草案`。
5. 是**发布或排障步骤** → `workflows/`。
6. 是**本次没做完、下一个 agent 要知道的进度** → `docs/handoff/`。
7. 都不像 → 放 `docs/design/`，并在 `docs/README.md` 加索引行。**不要**把内容塞进 `CLAUDE.md`。

`.claude/` **不入库**（本仓库公开，agent 工作流程不对外发布）。所以**不准**把一条
流程只写在 slash command 里——它的权威出处必须落在上表的某个仓库内文件中，
否则换台机器就丢了。

## 三、front-matter

### 3.1 适用范围

front-matter **只用于 `docs/` 下的文件**。

| 位置 | 是否要 front-matter |
|------|-------------------|
| `docs/**/*.md` | **必须有** |
| `workflows/*.md` | **不要**。改为在标题下写一行：`> 最后更新 YYYY-MM-DD ｜ 代码基线 <sha> ｜ 验证程度 <枚举>` |
| `.claude/commands/*.md` | 不入库，但若你在本地自建，**绝对不要**加，见 3.2 |
| `CLAUDE.md` / `README.md` / `CONTRIBUTING.md` | 不要 |

### 3.2 硬规则：slash command 文件的第一行是产品契约

这条针对本地的 `.claude/commands/*.md`（不入库），记在这里是因为踩过一次。

harness 把每个命令文件的**开头文本**当作该 slash command 的描述显示给 agent。所以：

- 第 1 行必须是一句话描述，**不准**在它前面加 front-matter、标题或空行；
- 加了 front-matter 的后果是命令在列表里显示成 `---`，而且**任何地方都不会报错**。

### 3.3 字段

```yaml
---
文档类型: 决策记录 | 方案设计 | 任务交接 | 文档规范 | 文档索引 | 算法契约
状态: 草案 | 已批准 | 已实施 | 已废弃      # 任务交接单用: 待开始 | 进行中 | 已完成 | 已放弃
负责人: @skylineconnct
最后更新: 2026-10-06
代码基线: cc80d20
验证程度: 已读代码 | 已跑测试 | 已完整生成验证
关联代码: src/classifier.rs:57 (build)
关联决策: ADR-0001 | 无
---
```

- `状态` 只能取枚举里的**单个值**，不准在后面加括号补充说明——补充说明写进正文第一行。
- `状态` 变更必须同时改 `最后更新`。
- `代码基线` 是文档里行号的有效期。基线之后 `src/`、`justfile`、`operators.yaml` 有改动，就要么重新核对行号、要么把基线往前推。
- **状态只有两个登记处**：文档自己的 front-matter，和 `docs/README.md` 的索引行。`CLAUDE.md` 和代码注释可以链接文档，但**不准复述它的状态**——否则必然出现两处不一致。

### 3.4 引用格式：`路径:行号 (符号)`

只写行号的引用一定会烂。必须补一个可以 grep 回来的符号：

```
src/classifier.rs:57 (build)
```

核对命令：

```bash
grep -nE '^(pub(\([a-z]+\))? )?(fn|struct|enum|impl|const|static)\b.*\bbuild\b' src/classifier.rs
```

没有唯一符号可用时（例如 `justfile` 里的一段 Ruby、`operators.yaml` 的某个键），引用里附不超过 60 字符的原文片段，用 `grep -nF '<片段>' <路径>` 核对。

**零命中规则**：符号 grep 不到，说明这条引用**已经死了**，不是行号漂移。要重新定位并留一行订正，不准默默改数字。

## 四、可信度标记（强制）

正文里每一条涉及代码或生成结果的断言，必须带下列标记之一：

| 标记 | 含义 | 接手 agent 该怎么做 |
|------|------|--------------------|
| 无标记 + `file:line` | 已在本仓库代码中逐行确认 | 可直接依赖，但仍应核对行号 |
| `【估算】` | 由公式/假设推出，未在真实生成中测量 | 下结论前先量一次 |
| `【待确认】` | 需要用户或仓库管理员权限才能回答 | **阻塞项**，先问，不要替用户假设 |
| `【未验证】` | 设计上应该成立，但没跑过完整生成 | 实现时补 `dry_run` 空跑 |
| `【冻结】` | 改动需要用户显式批准 | 不准改，先问 |
| `【仅本地验证】` | 只在本地跑过，没在 Actions 里跑过 | 合并前补一次 CI 或空跑记录 |

本仓库的特殊约束：**Ruby 与 `just` 配方只能在 CI 验证**的断言一律标 `【未验证】`，直到有一次 run 链接可引用。

## 五、文档类型模板

### 5.1 决策记录 ADR

```markdown
# ADR-NNNN 标题（动词开头，说清决策本身）
## 背景
## 目标与非目标
## 候选方案
（每个方案：机制 / 对分类准确度的影响 / 生成耗时 / 对下游的影响 / 代价）
## 决策
## 代价与放弃的东西
## 待确认（阻塞项）
## 验证方式（可执行的命令，含 dry_run 空跑）
## 回滚
```

### 5.2 方案设计

```markdown
# 标题
## 一、现状量化（带 file:line）
## 二、核心洞察
## 三、方案
## 四、输出契约（文件名、行格式、资产集合）
## 五、配置项（operators.yaml / CLI 参数，含默认值与兼容性）
## 六、灰度与回滚
## 七、验证方式（可执行的命令）
## 八、风险
## 九、待确认
```

### 5.3 任务交接

```markdown
# TASK-NNNN 标题
## 当前状态（一句话）
## 已完成
## 下一步（有序，每步给出要改的文件与验收标准）
## 不准动的东西
## 阻塞项
## 验收命令
```

### 5.4 运行手册

分节 → 可直接粘贴的命令块 → 判定表（条件 → 动作）。参照 `workflows/release.md`。

## 六、书写约定

- 正文中文，标识符/路径/CIDR/配置键一律英文原样，不翻译。
- 引用代码一律 `src/classifier.rs:57 (build)` 形式，可点击。
- 代码里反向引用文档：`# 见 docs/algorithm.md#processing-steps`。
- 表格优先于长段落；判定逻辑一律写成「条件 → 动作」表。
- 冻结代码在文档和代码注释里都标 `【冻结】`，并写明解冻条件（用户显式批准）。
- 文档不复制代码实现，只写契约和意图；实现细节以代码为准。
- 推翻已发布的结论时，留一行订正并把旧说法 `grep -rn` 一遍，所有副本在同一个提交里改掉：
  `（订正 YYYY-MM-DD：原说法「X」与代码不符 → 现为「Y」，依据 path:line (Symbol)）`

## 七、自检（提交文档前跑一遍）

```bash
cd "$(git rev-parse --show-toplevel)"

# 0. 脱敏审查优先
just sanitize

# 1. 每个 docs/ 文档都要有可解析的代码基线，且基线之后分类相关文件不应有改动
find docs -name '*.md' -print | while read -r f; do
  b=$(awk '/^---$/{n++; next} n==1 && /^代码基线:/{print $2; exit}' "$f")
  [ -n "$b" ] || { echo "缺少代码基线 -> $f"; continue; }
  git rev-parse --verify -q "$b" >/dev/null || { echo "基线无效 $b -> $f"; continue; }
  git diff --quiet "$b"..HEAD -- src/ justfile operators.yaml || echo "基线已过期($b) -> $f"
done

# 2. 所有 path:line 引用都必须指向非空、非孤立大括号的行
python3 - <<'PY'
import io,re,glob,os
pat=re.compile(r'((?:(?:src|scripts|tests)/)?[A-Za-z0-9_./-]+\.(?:rs|rb|sh|ya?ml)):(\d+)')
roots=['','src/','scripts/','tests/','.github/workflows/']
def resolve(rel):
    for r in roots:
        if os.path.exists(r+rel): return r+rel
    return None
targets=glob.glob('docs/**/*.md',recursive=True)+glob.glob('workflows/*.md')+['CLAUDE.md','README.md','CONTRIBUTING.md']
for f in targets:
    if not os.path.exists(f): continue
    for m in pat.finditer(io.open(f,encoding='utf-8').read()):
        rel,ln=m.group(1),int(m.group(2))
        p=resolve(rel)
        if p is None: continue          # 外部仓库的引用，不检查
        lines=io.open(p,encoding='utf-8').read().splitlines()
        t=lines[ln-1].strip() if ln<=len(lines) else '<越界>'
        if not t or t in ('}','{'): print('可疑引用',f,'->',rel+':'+str(ln),repr(t))
PY

# 3. 带 (符号) 注解的引用：该行附近必须真的出现这个符号
python3 - <<'PY'
import io,re,glob,os
pat=re.compile(r'((?:src|scripts|tests)/[A-Za-z0-9_./-]+\.(?:rs|rb|sh)):(\d+)\s*\(([^)]{1,60})\)')
targets=glob.glob('docs/**/*.md',recursive=True)+glob.glob('workflows/*.md')+['CLAUDE.md','README.md','CONTRIBUTING.md']
for f in targets:
    if not os.path.exists(f): continue
    for m in pat.finditer(io.open(f,encoding='utf-8').read()):
        p,ln,sym=m.group(1),int(m.group(2)),m.group(3)
        if not os.path.exists(p): continue
        lines=io.open(p,encoding='utf-8').read().splitlines()
        ident=[i for i in re.findall(r'[A-Za-z_][A-Za-z0-9_]*',sym) if len(i)>3]
        if not ident or ln>len(lines): continue
        if not any(i in '\n'.join(lines[max(0,ln-2):ln+1]) for i in ident):
            print('引用与符号不符',f,p+':'+str(ln),sym,'->',lines[ln-1].strip()[:60])
PY

# 4. 本地 slash command（若存在，不入库）第一行不准是 front-matter
[ -d .claude/commands ] && head -1 .claude/commands/*.md | grep -n '^---$' \
  && echo "致命：命令文件被加了 front-matter"
```

第 1、2、3、4 条为空输出才算通过。
