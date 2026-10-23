# china-operator-ip

依据 BGP 路由数据生成中国三大运营商的 IP 地址列表，并依据 APNIC 登记数据生成全中国 IP 列表。

## 收录范围

| 运营商 | 标识 | IPv4 | IPv6 | IPv4+IPv6 |
|---|---|---|---|---|
| 中国电信 | `ctcc` | `ctcc.txt` | `ctcc6.txt` | `ctcc46.txt` |
| 中国移动 | `cmcc` | `cmcc.txt` | `cmcc6.txt` | `cmcc46.txt` |
| 中国联通 | `unicom` | `unicom.txt` | `unicom6.txt` | `unicom46.txt` |
| 全中国 | `cn` | `cnv4.txt` | `cnv6.txt` | `cnv4v6.txt` |

`cn` 取自 APNIC [delegated 统计](https://ftp.apnic.net/stats/apnic/delegated-apnic-latest)中家码为 `CN` 的全部已分配地址，包含教育网等非三大运营商网络；不含港澳台。重复、嵌套与相邻的段已合并，表内任意两条 CIDR 都不重叠。见 [ADR-0002](docs/adr/ADR-0002-cn-from-apnic-delegated.md)。

> 中国电信的标识在 2026-10 由 `chinanet` 改为 `ctcc`，此后的发布不再包含 `chinanet*.txt`，见 [ADR-0001](docs/adr/ADR-0001-rename-ctcc-and-add-cn-union.md)。
>
> ADR-0003 合入之后的发布中，三家运营商列表互不重叠；此前的发布（含 `v2026.10.22`）两两重叠的 IPv4 地址合计约 213 万个，见 [ADR-0003](docs/adr/ADR-0003-exclusive-operator-lists.md)。

列表为 CIDR 格式，每行一条，IPv4 与 IPv6 各自按地址排序。`stat` 给出每张表覆盖的地址总量，`SHA256SUMS` 给出资产校验值。

三家运营商表互不重叠，但三者合起来不等于 `cn`：运营商表按 BGP 宣告归属，不含教育网、科技网等网络；`cn` 按 APNIC 登记收录全部中国大陆地址。

## 获取数据

GitHub Actions 每三天生成一次，结果发布为 [Release](../../releases) 资产。固定地址始终指向最新一次发布：

```
https://github.com/CYBERVERSE-Research/china-operator-ip/releases/latest/download/ctcc.txt
https://github.com/CYBERVERSE-Research/china-operator-ip/releases/latest/download/ctcc6.txt
https://github.com/CYBERVERSE-Research/china-operator-ip/releases/latest/download/ctcc46.txt
```

把 `ctcc` 换成 `cmcc` 或 `unicom` 即可取其余列表；合并表取 `cnv4.txt`、`cnv6.txt`、`cnv4v6.txt`。生成结果不写入任何分支。

## 使用建议

| 用途 | 取哪张表 | 说明 |
|---|---|---|
| 按运营商分流、策略路由 | `ctcc` / `unicom` / `cmcc` | 三张表互斥，可以分别装进各自的路由表，不会因同一段出现在两张表里而冲突。多线机房的段只在优先级最高的那家表里（电信 > 联通 > 移动），从其它线路也能到达 |
| 判断地址是否属于中国大陆 | `cn` | 不要拿三家表的并集代替，它不含教育网等网络 |
| 统计各运营商地址量 | `stat` | 三家互斥，各项可以直接相加 |

## 分类规则

从每个前缀的 origin ASN 沿观测到的 AS_PATH 共同后缀向上游检查，遇到最近的已知运营商 ASN 后停止归属。因此下游网络的地址会归入其共同上游运营商，而该运营商的上游 transit 不会连带获得这些地址。

`operators.yaml` 中 `publish: false` 的条目（教育网、科技网、鹏博士、谷歌中国）不生成列表，只作为上述停止边界；删除它们会使这些网络经电信、联通转接的地址被错误归入三大运营商列表。

三家列表互不重叠。一段地址若同时归属多家（多线 BGP 机房、云厂商的段常由两家运营商的 ASN 同时宣告），只归入优先级最高的一家：**电信 > 联通 > 移动**（`operators.yaml` 的 `priority`）。只被 1 个 BGP 观测点看到的宣告不参与归属，免得一条只泄漏给个别观测点的路由把地址分给另一家。

`cn` 不使用上述规则。完整规则见 [分类算法](docs/algorithm.md)。

## 本地生成

依赖：[just](https://github.com/casey/just)、[Rust 工具链](https://www.rust-lang.org/tools/install)、[bgpkit-broker](https://github.com/bgpkit/bgpkit-broker) `0.7.0`、[aria2](https://github.com/aria2/aria2)、curl、[Ruby](https://www.ruby-lang.org)、jq。

```sh
just dependency   # 构建分类器并安装 bgpkit-broker
just              # 下载 ASN 名称、APNIC delegated 统计与 RIB 快照 → 生成列表 → 统计
just --list       # 查看所有命令
```

BGP 分类器的 Rust 源码在 `src/`，直接读取本地 `rib-*` 快照；`cn` 由同一程序从本地 `delegated-apnic-latest` 生成（`just prepare_apnic` 下载并校验 MD5）。

## 参与开发

开发流程、提交规范与脱敏要求见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 维护

本项目由 [skylineconnct.io](https://www.skylineconnct.io) 维护。

## License

[MIT License](LICENSE)
