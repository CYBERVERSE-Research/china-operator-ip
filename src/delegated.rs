use ipnet::{IpNet, Ipv4Subnets, Ipv6Net};
use std::io::{self, BufRead};
use std::net::{Ipv4Addr, Ipv6Addr};

/// Prefixes that an RIR delegated-stats file lists for `country`.
///
/// Only `ipv4` / `ipv6` records with status `allocated` or `assigned` count; the
/// version line, summary lines and comments are skipped. An IPv4 record gives a
/// start address and an address count that need not be a power of two, so it can
/// expand into several CIDRs. An IPv6 record gives a prefix length directly.
pub(crate) fn load(reader: impl BufRead, country: &str) -> io::Result<Vec<IpNet>> {
    let mut prefixes = Vec::new();
    for line in reader.lines() {
        let line = line?;
        let fields: Vec<&str> = line.trim().split('|').collect();
        if line.starts_with('#') || fields.len() < 7 || fields[1] != country {
            continue;
        }
        if !matches!(fields[6], "allocated" | "assigned") {
            continue;
        }
        match fields[2] {
            "ipv4" => {
                let start: Ipv4Addr = fields[3].parse().map_err(|err| invalid(&line, err))?;
                let count: u32 = fields[4].parse().map_err(|err| invalid(&line, err))?;
                let end = count
                    .checked_sub(1)
                    .and_then(|span| u32::from(start).checked_add(span))
                    .ok_or_else(|| invalid(&line, "address count out of range"))?;
                prefixes.extend(Ipv4Subnets::new(start, Ipv4Addr::from(end), 0).map(IpNet::V4));
            }
            "ipv6" => {
                let start: Ipv6Addr = fields[3].parse().map_err(|err| invalid(&line, err))?;
                let len: u8 = fields[4].parse().map_err(|err| invalid(&line, err))?;
                let net = Ipv6Net::new(start, len).map_err(|err| invalid(&line, err))?;
                prefixes.push(IpNet::V6(net.trunc()));
            }
            _ => {}
        }
    }
    Ok(prefixes)
}

fn invalid(line: &str, err: impl std::fmt::Display) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, format!("{line}: {err}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ip::IpRanges;

    const SAMPLE: &str = "\
2|apnic|20261016|80000|19830613|20261015|+1000
apnic|*|asn|*|10000|summary
apnic|*|ipv4|*|50000|summary
# comment
apnic|CN|ipv4|1.0.1.0|256|20110414|allocated
apnic|CN|ipv4|1.0.2.0|512|20110414|allocated
apnic|CN|ipv4|1.0.32.0|768|20110414|assigned
apnic|JP|ipv4|1.0.16.0|4096|20110412|allocated
apnic|CN|ipv4|1.0.8.0|2048|20110412|reserved
apnic|CN|asn|4134|1|20020801|allocated
apnic|CN|ipv6|2001:250::|35|20000426|allocated
apnic|CN|ipv6|2001:250:2000::|35|20000426|assigned
apnic|HK|ipv6|2001:c00::|23|20000101|allocated
";

    #[test]
    fn keeps_only_the_countrys_allocated_and_assigned_blocks() {
        let prefixes = load(SAMPLE.as_bytes(), "CN").unwrap();
        assert_eq!(
            IpRanges::union(&prefixes).lines(),
            [
                "1.0.1.0/24",
                "1.0.2.0/23",
                "1.0.32.0/23",
                "1.0.34.0/24",
                "2001:250::/34",
            ]
        );
    }

    #[test]
    fn rejects_malformed_records() {
        for line in [
            "apnic|CN|ipv4|1.0.1|256|20110414|allocated",
            "apnic|CN|ipv4|1.0.1.0|0|20110414|allocated",
            "apnic|CN|ipv4|255.255.255.0|512|20110414|allocated",
            "apnic|CN|ipv6|2001:250::|129|20000426|allocated",
        ] {
            assert!(load(line.as_bytes(), "CN").is_err(), "{line}");
        }
    }
}
