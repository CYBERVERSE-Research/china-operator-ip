#!/usr/bin/env bash
# 公开仓库脱敏审查：扫描所有被 git 跟踪的文本文件。
# 无输出且退出码 0 = 通过；任何输出都是必须处理的命中项。
#
# 豁免写在 scripts/sanitize-allowlist.txt，格式见该文件头部。
# 禁用标识写在 scripts/sanitize-denylist.txt。
set -uo pipefail

cd "$(dirname "$0")/.."

allowlist=scripts/sanitize-allowlist.txt
denylist=scripts/sanitize-denylist.txt
hits=0

# 已跟踪 + 未跟踪但未被 .gitignore 排除的文件。只扫已跟踪文件会漏掉
# 本次新建、还没 git add 的文件——那恰恰是最容易带进凭据的地方。
files() {
  git ls-files -z --cached --others --exclude-standard | sort -zu | while IFS= read -r -d '' f; do
    case "$f" in
      scripts/sanitize.sh|scripts/sanitize-allowlist.txt|scripts/sanitize-denylist.txt) continue ;;
      LICENSE) continue ;;   # MIT 要求保留原始版权声明，见 CLAUDE.md 铁律六
    esac
    [ -f "$f" ] || continue
    grep -Iq . "$f" 2>/dev/null && printf '%s\n' "$f"
  done
}

# 取出适用于某个检查项的豁免片段：全局豁免（无 :: 前缀）+ 该检查项专属豁免
exemptions() {
  local label=$1
  [ -s "$allowlist" ] || return 0
  grep -v '^[[:space:]]*#' "$allowlist" | grep -v '^[[:space:]]*$' \
    | sed -n "s/^${label}:://p; /::/!p"
}

report() {
  local label=$1 out=$2
  [ -n "$out" ] || return 0
  printf '\n[%s]\n%s\n' "$label" "$out"
  hits=1
}

scan() {
  local label=$1 pattern=$2 ignore_case=${3:-} out ex
  out=$(files | tr '\n' '\0' | xargs -0 -r grep -nHIE ${ignore_case:+-i} -- "$pattern" 2>/dev/null)
  ex=$(exemptions "$label")
  [ -n "$ex" ] && out=$(printf '%s\n' "$out" | grep -vFf <(printf '%s\n' "$ex"))
  report "$label" "$out"
}

# 1. 凭据与密钥
scan '凭据密钥' '(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]{10,})'
scan '硬编码口令' '(password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}' i

# 2. 邮箱地址
scan '邮箱地址' '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

# 3. 开发机绝对路径
scan '本地路径' '(/home/[A-Za-z0-9._-]+|/root/|/Users/[A-Za-z0-9._-]+|C:\\\\Users\\\\)'

# 4. 内网地址与内部主机名（公网 CIDR 是本项目的数据内容，不在此列）
scan '内网地址' '(\b(10\.[0-9]{1,3}|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}\b|\b127\.0\.0\.1\b|localhost:[0-9]+|\.internal\b|\.local\b|\.lan\b)'

# 5. 显式禁用标识（上游个人身份、历史域名、已下线镜像等）
if [ -s "$denylist" ]; then
  terms=$(grep -v '^[[:space:]]*#' "$denylist" | grep -v '^[[:space:]]*$' | paste -sd'|' -)
  [ -n "$terms" ] && scan '禁用标识' "($terms)" i
fi

# 6. 生成产物不得入库
report '生成产物被跟踪' "$(git ls-files | grep -E '^(result/|dist/|analysis/)|^(asnames\.txt|autnums\.html)$|^rib[-0-9]|^delegated-|(^|/)__pycache__/|\.pyc$' || true)"

[ "$hits" -eq 0 ] && echo "INFO> 脱敏审查通过" >&2
exit "$hits"
