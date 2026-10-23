#!/usr/bin/env python3
# TEMPORARY: measures --min-origin-peers candidates in a dry run; removed before the PR.
import ipaddress
import itertools
import sys

OPS = ["ctcc", "unicom", "cmcc"]
SAMPLES = ["114.116.1.1", "123.59.1.1", "116.63.130.1"]


def load(path):
    v4, v6 = [], []
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        net = ipaddress.ip_network(line)
        (v6 if net.version == 6 else v4).append((int(net.network_address), int(net.broadcast_address)))
    return sorted(v4), sorted(v6)


def size(ranges):
    return sum(b - a + 1 for a, b in ranges)


def union(*lists):
    out = []
    for a, b in sorted(itertools.chain(*lists)):
        if out and a <= out[-1][1] + 1:
            out[-1] = (out[-1][0], max(out[-1][1], b))
        else:
            out.append((a, b))
    return out


def inter(x, y):
    i = j = 0
    out = []
    while i < len(x) and j < len(y):
        a, b = max(x[i][0], y[j][0]), min(x[i][1], y[j][1])
        if a <= b:
            out.append((a, b))
        if x[i][1] < y[j][1]:
            i += 1
        else:
            j += 1
    return out


def contains(ranges, addr):
    value = int(ipaddress.ip_address(addr))
    return any(a <= value <= b for a, b in ranges)


def main(directory, thresholds):
    base = None
    for n in thresholds:
        lists = {op: load(f"{directory}/{op}-{n}.txt") for op in OPS}
        print(f"=== min-origin-peers {n} ===")
        for fam, unit in [(0, 1), (1, 1 << 80)]:
            name = "v4 addrs" if fam == 0 else "v6 /48s"
            all_ = union(*(lists[op][fam] for op in OPS))
            if base is None:
                base = {}
            base.setdefault(fam, all_)
            lost = size(base[fam]) - size(inter(base[fam], all_))
            print(f"  [{name}] union={size(all_) // unit} lost_vs_n1={lost // unit}")
            for op in OPS:
                r = lists[op][fam]
                print(f"    {op}: cidrs={len(r)} size={size(r) // unit}")
            for p, q in itertools.combinations(OPS, 2):
                x = inter(lists[p][fam], lists[q][fam])
                print(f"    {p}&{q}: ranges={len(x)} size={size(x) // unit}")
            higher = []
            for op in OPS:
                kept = lists[op][fam]
                if higher:
                    removed = size(inter(kept, union(*higher)))
                    print(f"    priority removes from {op}: {removed // unit}")
                higher.append(lists[op][fam])
        for addr in SAMPLES:
            owners = [op for op in OPS if contains(lists[op][0], addr)]
            print(f"  sample {addr}: {owners}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
