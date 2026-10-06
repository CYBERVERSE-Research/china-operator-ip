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
    # 跳过符号链接：链接目标若被跟踪，自己会被扫到，否则同一行重复上报
    [ -f "$f" ] && [ ! -L "$f" ] || continue
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

# 1. 凭据与密钥：具体的 token 形状
scan '凭据密钥' '(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|PuTTY-User-Key-File|xox[baprs]-[A-Za-z0-9-]{10,}|sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|sk_(live|test)_[A-Za-z0-9]{16,}|AIza[0-9A-Za-z_-]{35}|npm_[A-Za-z0-9]{36}|pypi-[A-Za-z0-9_-]{16,}|hf_[A-Za-z0-9]{30,}|glpat-[A-Za-z0-9_-]{20,}|dop_v1_[a-f0-9]{64}|eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.)'

# 1b. URL 里内嵌的用户名:口令。~/.git-credentials 正是这个形状，
#     一旦被粘进文档或脚本，token 就随提交公开了。
scan 'URL 内嵌凭据' '[a-z][a-z0-9+.-]*://[A-Za-z0-9._%+-]+:[^/[:space:]@"'"'"']{6,}@'
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

# 7. 凭据类文件不得被跟踪（.gitignore 挡不住 git add -f）
report '凭据文件被跟踪' "$(git ls-files | grep -iE '(^|/)(\.env($|\.)|\.envrc$|\.netrc|\.npmrc$|\.git-credentials$|hosts\.yml$|credentials($|\.)|secrets?($|[._])|id_(rsa|ecdsa|ed25519)|\.(pem|key|p12|pfx|jks|keystore|token)$)' || true)"

# 8. .gitignore 必须保留凭据防护段。少一条就等于给一类凭据开了口子，
#    而这种缺失不会有任何其它地方报错。
missing=$(for pat in '.env' '.env.*' '.envrc' '.netrc' '.npmrc' '*.pem' '*.key' '*.p12' '*.pfx' \
                     '*.jks' '*.keystore' 'id_rsa*' 'id_ecdsa*' 'id_ed25519*' '*.gpg' '*.asc' \
                     'secrets.*' '.secrets/' 'credentials' 'credentials.*' '.aws/' '.ssh/' \
                     '.git-credentials' 'hosts.yml' '*.token' '.claude/'; do
  grep -qxF -- "$pat" .gitignore || printf '%s\n' "缺少 .gitignore 规则: $pat"
done)
report 'gitignore 凭据防护' "$missing"

# 9. agent 本地配置不得入库。本仓库公开，agent 的工作流程不对外发布，
#    而 .gitignore 挡不住 git add -f。规则出处：CONTRIBUTING.md 五。
report 'agent 配置被跟踪' "$(git ls-files | grep -E '^\.claude/' || true)"

[ "$hits" -eq 0 ] && echo "INFO> 脱敏审查通过" >&2
exit "$hits"
