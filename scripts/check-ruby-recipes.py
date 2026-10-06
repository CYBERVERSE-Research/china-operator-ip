#!/usr/bin/env python3
"""对 justfile 里每个 `#!/usr/bin/env ruby` 配方跑一次 `ruby -c`。

tests/operators_test.rb 只会真正执行 get_asn_candidates*、operator_asns、
published_operators 和 gen 的 publish 守卫；guard、package、stat、all 的语法
错误否则要等一小时的完整发布任务才暴露。这个检查两秒就能查出来。
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RECIPE = re.compile(r"^(?!\s)(?!#)(?P<name>[A-Za-z_][A-Za-z0-9_-]*)(?P<params>[^:=]*):(?![=])")
PARAM = re.compile(r"\{\{\s*[^}]+\s*\}\}")


def ruby_recipes(text):
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        match = RECIPE.match(lines[i])
        if not match:
            i += 1
            continue
        name = match.group("name")
        body, i = [], i + 1
        while i < len(lines) and (lines[i].startswith((" ", "\t")) or not lines[i].strip()):
            body.append(lines[i])
            i += 1
        while body and not body[-1].strip():
            body.pop()
        if body and body[0].strip() == "#!/usr/bin/env ruby":
            # 去掉统一缩进，并把 just 的 {{param}} 换成一个合法的 Ruby 字面量占位
            indent = len(body[0]) - len(body[0].lstrip())
            source = "\n".join(line[indent:] if len(line) > indent else line for line in body[1:])
            yield name, PARAM.sub("placeholder", source)


def main():
    if shutil.which("ruby") is None:
        # CI 里 ruby 必须存在；本机缺 ruby 时跳过而不是伪装成通过。
        if os.environ.get("CI"):
            print("ERROR> CI 环境里找不到 ruby", file=sys.stderr)
            return 1
        print("WARNING> 本机没有 ruby，跳过配方语法检查（CI 会跑）", file=sys.stderr)
        return 0

    root = Path(__file__).resolve().parent.parent
    recipes = list(ruby_recipes((root / "justfile").read_text(encoding="utf-8")))
    if not recipes:
        print("ERROR> justfile 里没找到任何 ruby 配方，提取逻辑可能已经失效", file=sys.stderr)
        return 1

    failures = []
    for name, source in recipes:
        with tempfile.NamedTemporaryFile("w", suffix=".rb", encoding="utf-8") as handle:
            handle.write(source)
            handle.flush()
            result = subprocess.run(
                ["ruby", "-c", handle.name], capture_output=True, text=True
            )
        if result.returncode != 0:
            failures.append(f"{name}: {result.stdout.strip()} {result.stderr.strip()}")

    for failure in failures:
        print(f"ERROR> {failure}", file=sys.stderr)
    if failures:
        return 1
    print(f"INFO> {len(recipes)} 个 ruby 配方语法检查通过", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
