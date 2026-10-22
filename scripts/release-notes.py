#!/usr/bin/env python3
"""Extract a version section from CHANGELOG.md for GitHub Release notes."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    version = sys.argv[1] if len(sys.argv) > 1 else (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    if version.startswith("v"):
        version = version[1:]

    changelog = ROOT / "CHANGELOG.md"
    if not changelog.is_file():
        print("找不到 CHANGELOG.md", file=sys.stderr)
        return 1

    lines = changelog.read_text(encoding="utf-8").splitlines()
    start = next(
        (i for i, line in enumerate(lines) if re.fullmatch(rf"##\s+{re.escape(version)}\s*", line)),
        None,
    )
    if start is None:
        print(f"CHANGELOG.md 中找不到版本 {version}", file=sys.stderr)
        return 1

    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].startswith("## "):
            end = i
            break

    section = "\n".join(lines[start:end]).strip()
    if not section:
        print(f"CHANGELOG.md 中版本 {version} 的段落为空", file=sys.stderr)
        return 1

    print(section)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
