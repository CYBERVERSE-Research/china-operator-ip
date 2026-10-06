set unstable

default: prepare all stat

# Run every pre-merge check (desensitization review first)
check: sanitize
  #!/usr/bin/env bash
  set -euo pipefail
  cargo fmt --check
  cargo clippy --locked --all-targets -- -D warnings
  cargo test --locked
  ruby tests/operators_test.rb

# Desensitization review for this public repository
sanitize:
  ./scripts/sanitize.sh

# Install or update bgp tooling dependencies
dependency:
  #!/usr/bin/env bash
  set -euo pipefail

  cargo build --release --locked

  if ! bgpkit-broker --version >/dev/null 2>&1; then
    cargo binstall --secure --no-confirm bgpkit-broker@0.7.0
  fi

  target/release/china-operator-ip --version
  bgpkit-broker --version

# Download and normalize latest autnums list
prepare_autnums:
  #!/usr/bin/env bash
  set -euo pipefail

  aria2c -s 4 -x 4 -q -o autnums.html --allow-overwrite=true https://bgp.potaroo.net/cidr/autnums.html
  awk -F'[<>]' '{print $3,$5}' autnums.html | grep '^AS' > asnames.txt
  rm -f autnums.html
  echo "INFO> asnames.txt updated ($(wc -l < asnames.txt) entries)" >&2

# Download the latest RIB snapshot for a collector
prepare_rib collector:
  #!/usr/bin/env bash
  set -euo pipefail

  url="$(bgpkit-broker latest -c "{{collector}}" --json \
    | jq -r '.[] | select(.data_type | contains("rib")) | .url' \
    | head -n 1)"

  if [[ -z "${url}" ]]; then
    echo "Unable to determine {{collector}} RIB download url" >&2
    exit 1
  fi

  if [[ "${url}" =~ (\.gz|\.bz2)$ ]]; then
    suffix="${BASH_REMATCH[1]}"
  else
    echo "Unsupported archive format for {{collector}}: ${url}" >&2
    exit 1
  fi

  outfile="rib-{{collector}}${suffix}"

  rm -f "${outfile}"
  aria2c -s 4 -x 4 -q -o "${outfile}" "${url}"
  stat "${outfile}"
  echo "INFO> ${outfile} ready for BGP classification" >&2

# Download the latest RIB snapshots (rrc00, rrc21, rrc12, route-views6)
[parallel]
prepare_ribs: (prepare_rib "rrc00") (prepare_rib "rrc21") (prepare_rib "rrc12") (prepare_rib "route-views6")

# Prepare data for generation
[parallel]
prepare: prepare_autnums prepare_ribs

# Print raw ASN candidates for OPERATOR based on operators.yaml
get_asn_candidates_raw operator:
  #!/usr/bin/env ruby
  require "yaml"

  cfg, asnames = "operators.yaml", "asnames.txt"
  abort("Missing config: #{cfg}") unless File.file?(cfg)
  abort("Missing asnames.txt. Run 'just prepare_autnums' first.") unless File.file?(asnames) && File.size?(asnames)

  op = YAML.load_file(cfg).fetch("operators").fetch("{{operator}}")
  country = op.fetch("country")
  pattern_re = Regexp.new(op["pattern"].to_s, Regexp::IGNORECASE)

  File.foreach(asnames) do |line|
    line.chomp!
    match = line.match(/^AS(\d+)\b.*,\s*([A-Z]{2})$/)
    asn, line_country = match&.captures
    next unless line_country == country
    next unless pattern_re.match?(line)
    puts asn
  end

# Print static ASN candidates for OPERATOR based on operators.yaml
get_asn_candidates operator:
  #!/usr/bin/env ruby
  require "set"
  require "yaml"

  operator = "{{operator}}"
  cfg = YAML.load_file("operators.yaml").fetch("operators").fetch(operator)
  exclude_asn = cfg.fetch("exclude_asn", []).map(&:to_s).to_set

  candidate_asns = IO.popen(["just", "get_asn_candidates_raw", operator], &:read).split
  abort("Failed to get raw ASN candidates for #{operator}") unless $?.success?

  candidate_asns.each do |asn|
    puts asn unless exclude_asn.include?(asn)
  end

# Print all known operator ASNs used as shared-upstream boundaries
operator_asns:
  #!/usr/bin/env ruby
  require "set"
  require "yaml"

  asns = Set.new
  YAML.load_file("operators.yaml").fetch("operators").each_key do |operator|
    output = IO.popen(["just", "get_asn_candidates", operator], &:read)
    abort("Failed to get operator ASNs for #{operator}") unless $?.success?
    asns.merge(output.split)
  end
  asns.sort_by(&:to_i).each { |asn| puts asn }

# Print the operators that get published IP lists
published_operators:
  #!/usr/bin/env ruby
  require "yaml"

  YAML.load_file("operators.yaml").fetch("operators")
    .select { |_, cfg| cfg.fetch("publish") }
    .keys.sort.each { |operator| puts operator }

# Generate the IPv4, IPv6 and IPv4+IPv6 lists for a single operator
gen operator:
  #!/usr/bin/env ruby
  require "fileutils"
  require "yaml"

  operator = "{{operator}}"
  cfg = YAML.load_file("operators.yaml").fetch("operators").fetch(operator)
  abort("#{operator} is a classification boundary only and has no list") unless cfg.fetch("publish")

  FileUtils.mkdir_p("result")
  out, v4, v6 = %W[result/#{operator}46.txt result/#{operator}.txt result/#{operator}6.txt]

  ribs = Dir["rib-*.{gz,bz2}"].sort
  abort("No rib-*.gz or rib-*.bz2 files found. Run 'just prepare_ribs' first.") if ribs.empty?

  operator_asns = IO.popen(["just", "operator_asns"], &:read)
  abort("Failed to get operator ASNs") unless $?.success?
  operator_asn_path = "result/.operator-asns.txt"
  File.write(operator_asn_path, operator_asns)

  classifier = [
    "target/release/china-operator-ip",
    "--ignore-private-asn",
    "--cache",
    "--operator-asn-file", operator_asn_path,
  ]
  classifier += ribs.flat_map { |r| ["--mrt-file", r] }

  warn "INFO> #{operator} start"
  asns = IO.popen(["just", "get_asn_candidates", operator], &:read)
  abort("Failed to get ASN list for #{operator}") unless $?.success?
  abort("Failed to run BGP classifier for #{operator}") unless system(*classifier, *asns.split, out: out)

  v6_lines, v4_lines = File.readlines(out).partition { |line| line.include?(":") }
  File.write(v4, v4_lines.join)
  File.write(v6, v6_lines.join)
  warn "INFO> #{operator} done (v4=#{v4_lines.length} v6=#{v6_lines.length})"

# Generate the lists for every published operator
all:
  #!/usr/bin/env ruby
  operators = IO.popen(["just", "published_operators"], &:read).split
  abort("Failed to read published operators") unless $?.success?

  operators.each do |operator|
    exit($?.exitstatus || 1) unless system("just", "gen", operator)
  end

# Validate the generated lists before they are published
guard:
  #!/usr/bin/env ruby
  require "ipaddr"

  # 下限只用于拦截"分类器产出为空"这类整体失败，不用于跟踪真实前缀数量的波动。
  min_v4, min_v6 = 500, 50
  operators = IO.popen(["just", "published_operators"], &:read).split
  abort("Failed to read published operators") unless $?.success?

  failures = []
  operators.each do |operator|
    v4, v6, both = %W[result/#{operator}.txt result/#{operator}6.txt result/#{operator}46.txt]
    missing = [v4, v6, both].reject { |f| File.file?(f) }
    unless missing.empty?
      failures << "#{operator}: missing #{missing.join(", ")}"
      next
    end

    v4_lines = File.readlines(v4).map(&:strip).reject(&:empty?)
    v6_lines = File.readlines(v6).map(&:strip).reject(&:empty?)
    both_lines = File.readlines(both).map(&:strip).reject(&:empty?)

    failures << "#{v4}: #{v4_lines.length} prefixes < #{min_v4}" if v4_lines.length < min_v4
    failures << "#{v6}: #{v6_lines.length} prefixes < #{min_v6}" if v6_lines.length < min_v6
    if both_lines.length != v4_lines.length + v6_lines.length
      failures << "#{both}: #{both_lines.length} lines != #{v4_lines.length} + #{v6_lines.length}"
    end

    {v4 => Socket::AF_INET, v6 => Socket::AF_INET6}.each do |file, family|
      lines = file == v4 ? v4_lines : v6_lines
      bad = lines.reject do |line|
        IPAddr.new(line).family == family
      rescue StandardError
        false
      end
      failures << "#{file}: #{bad.length} malformed prefixes (first: #{bad.first})" unless bad.empty?
    end
  end

  unless failures.empty?
    failures.each { |f| warn "ERROR> #{f}" }
    exit 1
  end
  warn "INFO> guard checks passed (#{operators.length} operators x 3 lists)"

# Summarize total IPv4/IPv6 address space per operator
stat:
  #!/usr/bin/env ruby
  dir = "result"
  files = Dir.exist?(dir) ? Dir.glob("#{dir}/*.txt").sort : []
  files.reject! { |p| p.end_with?("46.txt") }
  abort("result/*.txt files missing") if files.empty?

  report = files.map do |p|
    base = p.end_with?("6.txt") ? 48 : 32
    total = File.foreach(p).sum do |line|
      match = %r{/(\d+)}.match(line)
      next 0 unless match
      prefix_len = match[1].to_i
      prefix_len <= base ? (1 << (base - prefix_len)) : 0
    end
    "#{File.basename(p, ".txt")}\n#{total}"
  end.join("\n\n") + "\n"

  print report
  File.write("#{dir}/stat", report)

# Collect the release assets into dist/ with checksums
package: guard
  #!/usr/bin/env ruby
  require "digest"
  require "fileutils"

  operators = IO.popen(["just", "published_operators"], &:read).split
  abort("Failed to read published operators") unless $?.success?

  FileUtils.rm_rf("dist")
  FileUtils.mkdir_p("dist")

  assets = operators.flat_map { |op| %W[#{op}.txt #{op}6.txt #{op}46.txt] }
  assets << "stat" if File.file?("result/stat")
  assets.each { |f| FileUtils.cp("result/#{f}", "dist/#{f}") }

  File.write("dist/SHA256SUMS", assets.sort.map { |f|
    "#{Digest::SHA256.file("dist/#{f}").hexdigest}  #{f}\n"
  }.join)

  warn "INFO> dist/ ready (#{assets.length} assets)"
