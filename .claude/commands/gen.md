本地完整生成一次九张 IP 列表，并执行发布前校验。约 1 小时，需要网络。

## 前置

```bash
cd "$(git rev-parse --show-toplevel)"
just dependency      # 构建分类器 + 安装 bgpkit-broker 0.7.0
```

需要 `just`、Rust 工具链、`aria2c`、`jq`、`ruby` 都在 `PATH` 里。

## 执行

```bash
just                 # prepare（autnums + 4 份 RIB）→ all（三家 × 三张表）→ stat
just guard           # 发布前校验
just package         # 汇总到 dist/ 并生成 SHA256SUMS
ls -l dist/
```

只生成一家：

```bash
just gen chinanet    # 或 cmcc / unicom
```

`just gen` 对 `publish: false` 的运营商会直接失败，这是故意的——它们只作分类边界，见 `CLAUDE.md` 铁律三。

## 预期产物

`result/` 下每家三个文件：`<op>.txt`（IPv4）、`<op>6.txt`（IPv6）、`<op>46.txt`（合表），加上 `stat`。`package` 把它们复制到 `dist/` 并加 `SHA256SUMS`。

`result/`、`dist/`、`rib-*`、`asnames.txt` 全在 `.gitignore` 里，**不准提交**。

## 失败排查

判定表见 `workflows/release.md` §四。`guard` 报条数低于下限时不要去调下限，先看 `just all` 日志里每家的 `v4=/v6=` 计数。
