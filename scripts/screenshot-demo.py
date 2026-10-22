#!/usr/bin/env python3
"""Render a screenshot using real Starship, eza, bat and Git output."""

import os
from pathlib import Path
import shutil
import re
import sys
import subprocess
import tempfile


def main():
    required = ("git", "starship", "eza", "bat")
    missing = [name for name in required if not shutil.which(name)]
    if missing:
        raise SystemExit("缺少工具：" + ", ".join(missing) + "。请先安装后重试。")

    env = {key: value for key, value in os.environ.items()
           if not key.startswith("GIT_")}
    env.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1",
               TERM="xterm-256color", COLORTERM="truecolor", STARSHIP_SHELL="unknown")

    with tempfile.TemporaryDirectory(prefix="dotgraft-screenshot-") as temp:
        root = Path(temp)
        workspace = root / "demo"
        (workspace / "src").mkdir(parents=True)
        (workspace / "docs").mkdir()
        (workspace / "README.md").write_text("# Hello terminal\n", encoding="utf-8")
        source = workspace / "src" / "hello.py"
        source.write_text(
            '# 中文与 English · A small greeting\n'
            'def greet(name: str) -> str:\n'
            '    return f"Hello, {name}!"\n'
            '\n'
            'print(greet("world"))\n', encoding="utf-8")

        def run(*command, capture=False):
            return subprocess.run(command, cwd=workspace, env=env, check=True,
                                  stdout=subprocess.PIPE if capture else None,
                                  text=True)

        run("git", "init", "-q", "--initial-branch=main", "--template=")
        run("git", "add", ".")
        run("git", "-c", "user.name=Demo", "-c", "user.email=demo@example.invalid",
            "-c", "commit.gpgsign=false", "commit", "-qm", "Add greeting")
        source.write_text(source.read_text(encoding="utf-8").replace(
            'greet("world")', 'greet("终端")'), encoding="utf-8")

        # Use the installed palette with a compact, privacy-safe screenshot layout.
        config_path = Path(os.environ.get(
            "STARSHIP_CONFIG", str(Path.home() / ".config/starship.toml")))
        if not config_path.is_file():
            raise SystemExit(f"找不到 Starship 配置：{config_path}")
        config = config_path.read_text(encoding="utf-8")
        palette = re.search(r"(?m)^palette\s*=\s*['\"]([^'\"]+)['\"]", config)
        palettes = re.search(r"(?m)^\[palettes\.", config)
        if not palette or not palettes:
            raise SystemExit("Starship 配置缺少 palette 或 palettes，请先应用 Dotgraft 配置。")
        preview_config = root / "starship.toml"
        preview_config.write_text(
            f"palette = '{palette.group(1)}'\n"
            "format = '[](red)[ dotgraft ](fg:crust bg:red)[](fg:red bg:peach)$directory[](fg:peach bg:yellow)$git_branch$git_status[](fg:yellow bg:green)[ ✓ ](fg:crust bg:green)[](green)$line_break$character'\n"
            "add_newline = false\n"
            "[directory]\nformat = '[ $path ](fg:crust bg:peach)'\n"
            "truncate_to_repo = true\n"
            "[git_branch]\nformat = '[ $symbol$branch ](fg:crust bg:yellow)'\n"
            "[git_status]\nformat = '[ $all_status$ahead_behind ](fg:crust bg:yellow)'\n"
            "[character]\nsuccess_symbol = '[ ❯](green)'\n"
            + config[palettes.start():], encoding="utf-8")
        env["PWD"] = str(workspace)
        env["STARSHIP_CONFIG"] = str(preview_config)
        env["STARSHIP_CACHE"] = str(root / "cache")

        print("\033[2J\033[H", end="", flush=True)
        print("  DOTGRAFT  ·  Ghostty + Starship + zsh\n", flush=True)

        def show(label, *command):
            prompt = run("starship", "prompt", "--status=0",
                         "--path", str(workspace), "--logical-path", str(workspace),
                         capture=True).stdout
            print(prompt + label, flush=True)
            run(*command)
            print(flush=True)

        show("eza --tree --icons", "eza", "--tree", "--icons=always", "--color=always", ".")
        show("bat src/hello.py", "bat", "--paging=never", "--style=plain",
             "--color=always", "src/hello.py")
        show("git diff --unified=0", "git", "--no-pager", "diff", "--color=always",
             "--no-ext-diff", "--unified=0")
        if sys.stdin.isatty() and sys.stdout.isatty():
            try:
                input()
            except (EOFError, KeyboardInterrupt):
                print()


if __name__ == "__main__":
    main()
