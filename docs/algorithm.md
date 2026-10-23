---
文档类型: 算法契约
状态: 已实施
负责人: @skylineconnct
最后更新: 2026-10-23
代码基线: 41c5840
验证程度: 已跑测试
关联代码: src/classifier.rs, src/asn.rs, src/ip.rs
关联决策: ADR-0003
---

## Algorithm Overview

> 生成流程（`just gen`）只使用 `--ignore-private-asn`、`--cache`、
> `--operator-asn-file`、`--min-origin-peers` 和 `--higher-priority-asn-file`。
> 步骤 3、7、9 描述的 `--trusted-cn-transit-file`、
> `--exclude-foreign-upstream-only`、`--fallback-prefix-file` 仍是分类器支持的
> CLI 能力，但当前没有运营商配置会触发它们。

The built-in BGP classifier reads one or more MRT/RIB files and classifies IPv4/IPv6 prefixes by origin and shared upstream ASNs, then outputs the ranges for the ASNs provided on the command line.

- Inputs: MRT file paths (`--mrt-file`), target ASNs (positional), `--ignore-private-asn`, `--origin-only`, `--cache`, operator ASN boundaries (`--operator-asn-file`, shared-upstream mode only), a per-origin visibility threshold (`--min-origin-peers`, default 1), ASNs whose space outranks the result (`--higher-priority-asn-file`), an optional low-priority CIDR fallback list (`--fallback-prefix-file`), an optional foreign-upstream filter (`--exclude-foreign-upstream-only` + `--asn-country-file`), and an optional trusted-CN-transit filter (`--trusted-cn-transit-file` + `--asn-country-file`, requires `--origin-only`).
- Output: Simplified, sorted list of CIDR prefixes (v4 then v6) for the requested ASNs.

## Processing Steps

1) **Parse MRT files (parallel)**
   Each MRT file is parsed with `BgpkitParser`, keeping only ANNOUNCE records. For every prefix the code collects:
   - Origin ASNs (skipping private ASNs when requested).
   - AS path (truncated to last 4 hops).
   - Split points: prefix network address and the next address after the broadcast. These points mark boundaries for later interval construction.
   Results are stored separately for v4 and v6:
   - `announced_*`: every non-default announced prefix, collected before origin, private-ASN, country, or transit filtering. IPv4/IPv6 default routes are excluded because they do not establish a globally routed address assignment.
   - `prefix_map_*`: longest-prefix-match map of prefix → set of origin ASNs.
   - `common_suffixes`: prefix → origin ASN → longest common suffix of the observed paths (at most 4 ASNs). Each new path reduces this suffix; individual paths are not retained.
   - `peers`: (prefix, origin ASN) → number of RIB peers that see the prefix originated by that ASN. A RIB dump lists all entries of a prefix together, so a peer is counted once per prefix and origin even when it repeats with ADD-PATH.
   - `direct_upstreams`: origin ASN → set of observed direct upstream ASNs.
   - `split_points_*`: ordered set of addresses that delimit intervals.

2) **Merge per-file data**
   Parsed structures are merged across files. Per-file common suffixes are combined by taking their common suffix again, and peer counts are summed; operator attribution happens only after all files are merged. Split points are deduped and sorted (via `BTreeSet`).

3) **Optional trusted-CN-transit filtering**
   With `--origin-only`, inspect every observed AS path from the origin side. An origin ASN is retained, along with all of its prefixes, when at least one path has a contiguous CN suffix containing an ASN from `--trusted-cn-transit-file`. Inspection stops at the first non-CN or unknown ASN, so a trusted CN network beyond foreign transit does not make the origin domestic. The CLI rejects this filter without `--origin-only` because shared-upstream attribution is a different mode.

4) **Drop barely seen origins**

   An origin of a prefix takes part in attribution only when at least `--min-origin-peers` peers, summed over all RIB files, see that prefix originated by it. The others are removed from the prefix and from its common suffixes before step 5. A prefix left with no origin is removed entirely, so the covering announcement owns its space again; this differs from step 3, where an emptied prefix keeps blocking its aggregate because its origin was seen but rejected. The default of 1 keeps every observed origin. `just gen` passes `min_origin_peers` from the top of the `justfile`; see [ADR-0003](adr/ADR-0003-exclusive-operator-lists.md) for how the value was measured.

5) **Add shared upstream ASNs**

   Unless `--origin-only` is set, the algorithm uses the accumulated longest common suffix for each prefix and origin (capped to 4 ASNs, after removing consecutive duplicates). It walks this suffix from the origin toward upstream, adding ASNs to the prefix map, and stops after the first ASN in `--operator-asn-file`. This retains downstream customer coverage while preventing one operator's transit provider from also receiving its space. For example, with AS4134 and AS4538 in the operator set, a common suffix `4134 4538 24489` attributes space to AS24489 and CERNET AS4538, but not China Telecom AS4134. Divergent upstreams outside the common suffix receive no attribution.

   `just operator_asns` derives this boundary set from the ASN candidates of **every** entry in `operators.yaml`, including the `publish: false` ones that get no list of their own. `just gen` supplies it for operator generation and saves it as `result/.operator-asns.txt` for audit. The set is independent of the requested target ASNs: stopping only at the requested operator would still misclassify another operator's space, and dropping the `publish: false` entries would attribute their space to whichever ISP carries their transit. Direct CLI calls without this file retain unrestricted common-suffix attribution.

   Each origin of a multi-origin prefix is processed independently, so one interval can still belong to the ASNs of several operators. Step 8 resolves this for the published lists.

   （订正 2026-10-23：原说法「No operator priority or arbitrary deduplication is applied」随 ADR-0003 失效 → 现为第 8 步按 `operators.yaml` 的 `priority` 只保留一家，依据 src/classifier.rs:25 (result)）

6) **Build ASN → IP ranges**
   Consecutive split points define half-open intervals `[start, end)`. For each interval, a /32 (v4) or /128 (v6) lookup finds the longest covering prefix and its ASNs. Each ASN receives the interval, converted to a minimal set of CIDRs by the generic address-family implementation. The per-AS ranges are stored as `IpRange` structures to allow merging.

7) **Optional foreign-upstream filtering**
   When `--exclude-foreign-upstream-only <COUNTRY>` is enabled, the classifier loads ASN → country data from `--asn-country-file` and removes any requested ASN whose observed direct upstream ASNs are all known and all outside `<COUNTRY>`. A hidden debug flag can print this matched ASN list directly.

8) **Remove the space of higher-priority operators**
   Every range attributed to an ASN in `--higher-priority-asn-file` is subtracted from the selected result: `result = classified(targets) − classified(higher-priority)`. `just outranking_asns <operator>` writes this file from the `priority` list in `operators.yaml` (电信 > 联通 > 移动): the ASN candidates of every published operator ranked above the requested one. An interval attributed to both a China Telecom and a China Unicom ASN, typically a multi-homed IDC prefix announced by both, therefore appears only in `ctcc`. `just guard` fails the release if any two operator lists still overlap.

9) **Apply registration fallbacks**
   Each CIDR from `--fallback-prefix-file` contributes only its difference from the complete observed announcement set. This gives BGP higher priority than fallback data: `result = classified ∪ (fallback − announced)`. Any announcement, regardless of ASN or classification, blocks fallback coverage for that space.

10) **Finalize result**
   For the remaining requested ASNs, the collected ranges and unannounced fallbacks are merged and simplified, then emitted in sorted order (v4 then v6).

## Caching

When `--cache` is enabled, the computed ASN→range maps, complete observed announcement sets, and origin→direct-upstream map are serialized to a bincode file keyed by input file list, `ignore_private_asn`, `origin_only`, `min_origin_peers`, the trusted-transit policy fingerprint, and the sorted operator ASN set fingerprint. The fallback and higher-priority files are read after cache loading and therefore do not affect the key, so the three operators of one release share a single classification. Subsequent runs reuse the cache when the key matches.

## Modules

- `src/main.rs`: Parses CLI options, selects cache use and prints the final result.
- `src/classifier.rs`: Parses MRT files and exposes the completed classification through `Classification`.
- `src/ip.rs`: Owns dual-stack state and the generic address-family implementation for interval slicing, longest-prefix lookup and fallback subtraction.
- `src/asn.rs`: Defines the `Asn` domain type, AS-path operations, domestic policy and country/upstream classification.
- `src/cache.rs`: Owns cache keys, format versioning and bincode persistence.
