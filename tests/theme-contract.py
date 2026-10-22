#!/usr/bin/env python3
"""Dotgraft theme contract check.

Theme files are the source of truth; this script checks the rules that make
Ink, Paper and Porcelain instances of one system rather than three unrelated
palettes.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEME_DIR = ROOT / "dot_config" / "ghostty" / "themes"
STARSHIP = ROOT / "dot_config" / "starship.toml.tmpl"

THEMES = ("Dotgraft Ink", "Dotgraft Paper", "Dotgraft Porcelain")
PALETTES = {
    "Dotgraft Ink": "dotgraft_ink",
    "Dotgraft Paper": "dotgraft_paper",
    "Dotgraft Porcelain": "dotgraft_porcelain",
}
CHROMATIC_ANSI = (1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14)
STARSHIP_BLOCK_COLORS = ("red", "peach", "yellow", "green", "sapphire", "lavender")
EXPECTED_ROLES = {
    "Dotgraft Ink": {
        "graft": "#8BD49C", "dot": "#F2B36B", "selection": "#345A4A",
        "alert": "#E06C75", "signal": "#7AA2F7",
    },
    "Dotgraft Paper": {
        "graft": "#2C784B", "dot": "#8F4A14", "selection": "#8FBBA1",
        "alert": "#B23A48", "signal": "#2F5DA8",
    },
    "Dotgraft Porcelain": {
        "graft": "#2C784B", "dot": "#2A648F", "selection": "#9CC5B2",
        "alert": "#B23A48", "signal": "#2F5DA8",
    },
}
STARSHIP_REQUIRED = {
    "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow",
    "green", "teal", "sky", "sapphire", "blue", "lavender", "text", "subtext1",
    "subtext0", "overlay2", "overlay1", "overlay0", "surface2", "surface1",
    "surface0", "base", "mantle", "crust",
}

errors: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def normalize_hex(value: str) -> str:
    value = value.strip().strip('"').strip("'")
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        raise ValueError(f"invalid hex color: {value!r}")
    return value.upper()


def parse_theme(path: Path) -> tuple[dict[str, str], dict[int, str]]:
    values: dict[str, str] = {}
    palette: dict[int, str] = {}
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if key == "palette":
            index, color = value.split("=", 1)
            palette[int(index)] = normalize_hex(color)
        else:
            values[key] = normalize_hex(value)
    return values, palette


def srgb_channel(channel: int) -> float:
    value = channel / 255.0
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def luminance(color: str) -> float:
    color = color.lstrip("#")
    r, g, b = (int(color[i:i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * srgb_channel(r) + 0.7152 * srgb_channel(g) + 0.0722 * srgb_channel(b)


def contrast(a: str, b: str) -> float:
    high, low = sorted((luminance(a), luminance(b)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def parse_starship(path: Path) -> dict[str, dict[str, str]]:
    palettes: dict[str, dict[str, str]] = {}
    current: str | None = None
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[palettes.") and line.endswith("]"):
            name = line[len("[palettes."):-1]
            current = name if name.startswith("dotgraft_") else None
            if current:
                palettes[current] = {}
            continue
        if current and line.startswith("[") and line.endswith("]"):
            current = None
            continue
        if current and "=" in line:
            key, value = line.split("=", 1)
            palettes[current][key.strip()] = normalize_hex(value)
    return palettes


def check_theme(name: str, values: dict[str, str], palette: dict[int, str]) -> None:
    required = (
        "background", "foreground", "cursor-color", "cursor-text",
        "selection-background", "selection-foreground",
    )
    for key in required:
        if key not in values:
            fail(f"{name}: missing {key}")
    if sorted(palette) != list(range(16)):
        fail(f"{name}: palette must contain exactly 0..15")

    if errors:
        return

    bg = values["background"]
    fg = values["foreground"]
    cursor = values["cursor-color"]
    sel_bg = values["selection-background"]
    sel_fg = values["selection-foreground"]

    if contrast(fg, bg) < 7:
        fail(f"{name}: foreground/background contrast {contrast(fg, bg):.2f} < 7")
    if contrast(cursor, bg) < 4.5:
        fail(f"{name}: cursor/background contrast {contrast(cursor, bg):.2f} < 4.5")
    if contrast(sel_fg, sel_bg) < 4.5:
        fail(f"{name}: selection text/fill contrast {contrast(sel_fg, sel_bg):.2f} < 4.5")

    roles = EXPECTED_ROLES[name]
    if palette[2] != roles["graft"]:
        fail(f"{name}: Graft (ANSI 2) {palette[2]} != {roles['graft']}")
    if cursor != roles["dot"]:
        fail(f"{name}: Dot/cursor {cursor} != {roles['dot']}")
    if sel_bg != roles["selection"]:
        fail(f"{name}: Selection {sel_bg} != {roles['selection']}")
    if palette[1] != roles["alert"]:
        fail(f"{name}: Alert (ANSI 1) {palette[1]} != {roles['alert']}")
    if palette[4] != roles["signal"]:
        fail(f"{name}: Signal (ANSI 4) {palette[4]} != {roles['signal']}")

    # Neutral ANSI 0/7/8/15 are allowed to be low-contrast by design; the
    # chromatic ANSI roles must remain readable against the ground.
    for index in CHROMATIC_ANSI:
        ratio = contrast(palette[index], bg)
        if ratio < 4.5:
            fail(f"{name}: ANSI {index} {palette[index]} contrast {ratio:.2f} < 4.5")


def main() -> int:
    parsed: dict[str, tuple[dict[str, str], dict[int, str]]] = {}
    for name in THEMES:
        path = THEME_DIR / name
        if not path.is_file():
            fail(f"missing theme file: {path}")
            continue
        try:
            parsed[name] = parse_theme(path)
        except ValueError as exc:
            fail(f"{name}: {exc}")

    for name, (values, palette) in parsed.items():
        check_theme(name, values, palette)

    # Paper and Porcelain must share the same chromatic ANSI hues.
    if "Dotgraft Paper" in parsed and "Dotgraft Porcelain" in parsed:
        paper = parsed["Dotgraft Paper"][1]
        porcelain = parsed["Dotgraft Porcelain"][1]
        for index in CHROMATIC_ANSI:
            if paper[index] != porcelain[index]:
                fail(
                    "light themes drift on ANSI "
                    f"{index}: Paper {paper[index]} != Porcelain {porcelain[index]}"
                )

    if errors:
        for message in errors:
            print(f"FAIL: {message}", file=sys.stderr)
        return 1

    if not STARSHIP.is_file():
        print(f"FAIL: missing Starship template: {STARSHIP}", file=sys.stderr)
        return 1

    try:
        starship = parse_starship(STARSHIP)
    except ValueError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1

    for theme_name, palette_name in PALETTES.items():
        palette = starship.get(palette_name)
        if palette is None:
            fail(f"missing Starship palette: {palette_name}")
            continue
        missing = STARSHIP_REQUIRED - set(palette)
        if missing:
            fail(f"{palette_name}: missing keys: {', '.join(sorted(missing))}")

        _theme_values, ansi = parsed[theme_name]
        expected = {
            "red": ansi[1],
            "green": ansi[2],
            "yellow": ansi[3],
            "blue": ansi[4],
            "mauve": ansi[5],
            "sapphire": ansi[4],
        }
        for key, color in expected.items():
            if palette.get(key) != color:
                fail(
                    f"{palette_name}: {key} {palette.get(key)} != theme ANSI "
                    f"{color}"
                )

        # Starship powerline blocks use crust as text color.
        for key in STARSHIP_BLOCK_COLORS:
            color = palette.get(key)
            if color and contrast(palette["crust"], color) < 4.5:
                fail(
                    f"{palette_name}: block {key} {color} has "
                    f"contrast {contrast(palette['crust'], color):.2f} with crust < 4.5"
                )

    if errors:
        for message in errors:
            print(f"FAIL: {message}", file=sys.stderr)
        return 1

    print(
        "Theme contract OK: 3 themes, stable ANSI hues, Graft/Alert/Signal roles, "
        "AA text/cursor/selection, Starship palettes."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
