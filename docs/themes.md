# Dotgraft Theme

English · [简体中文](zh-CN/themes.md)

Dotgraft ships three built-in themes. All are Ghostty theme files with matching Starship palettes:

| Name | Mode | Ghostty file | Starship palette |
|---|---|---|---|
| **Dotgraft Ink** | Dark, default | `Dotgraft Ink` | `dotgraft_ink` |
| **Dotgraft Paper** | Warm light | `Dotgraft Paper` | `dotgraft_paper` |
| **Dotgraft Porcelain** | Cool light | `Dotgraft Porcelain` | `dotgraft_porcelain` |

Theme files are installed at:

```text
~/.config/ghostty/themes/Dotgraft Ink
~/.config/ghostty/themes/Dotgraft Paper
~/.config/ghostty/themes/Dotgraft Porcelain
```

## Color roles

All three themes share a set of color roles so semantics stay consistent between dark and light modes:

- **Ground**: the base color of the code-reading area
- **Ink**: body text
- **Graft Green**: the brand green, also used for ANSI green and selections
- **Dot**: cursor and focus (amber / copper / blue)
- **Alert / Signal**: errors and information

Ink is the dark theme: dark green ink ground, warm white foreground, amber cursor. Paper is a warm light theme: warm paper ground, ink-green foreground, copper cursor. Porcelain is a cool light theme: cool white ground, blue-black foreground, blue cursor.

All three themes set only color-related configuration. Do not set `theme`, `config-file`, `keybind`, or `background-image` in a theme file.

## Role rules

```text
Ground / Ink / Dot  → ground, body text, cursor
Graft Green         → brand green, also used for ANSI green and selections
Alert / Signal      → errors and information
ANSI hues           → stable across themes; only lightness and chroma are adjusted
Selection           → Graft tint, no additional accent color
```

Paper and Porcelain use the same brand green; red, blue, and other colors keep their respective semantics. The two light themes mainly change the ground, body text, cursor, and neutral colors.

## Base colors and contrast

Contrast is calculated using WCAG relative luminance. The target for text is AA (4.5:1) or better.

### Dotgraft Ink

| Role | Hex | Contrast against background |
|---|---|---:|
| Background | `#121816` | — |
| Foreground | `#D8E3DA` | **13.63** |
| Cursor | `#F2B36B` | **9.79** |
| Selection background | `#345A4A` | 2.32 (against background) |
| Selection foreground | `#F0F7F2` | **7.13** (against selection background) |

### Dotgraft Paper

| Role | Hex | Contrast against background |
|---|---|---:|
| Background | `#F4F1E8` | — |
| Foreground | `#26302B` | **12.07** |
| Cursor | `#8F4A14` | **5.89** |
| Selection background | `#8FBBA1` | 1.90 (against background) |
| Selection foreground | `#1E3A2F` | **5.75** (against selection background) |

### Dotgraft Porcelain

| Role | Hex | Contrast against background |
|---|---|---:|
| Background | `#F2F5F7` | — |
| Foreground | `#1E2A32` | **13.39** |
| Cursor | `#2A648F` | **5.78** |
| Selection background | `#9CC5B2` | 1.74 (against background) |
| Selection foreground | `#17323D` | **7.08** (against selection background) |

## ANSI 16 colors

Paper and Porcelain share the same chromatic ANSI colors; their neutral colors are slightly adjusted to match the temperature of the ground. Ink uses brighter versions from the same hue family.

| # | Role | Ink | Ink contrast | Paper | Paper contrast | Porcelain | Porcelain contrast |
|---|---|---|---:|---|---:|---|---:|
| 0 | black | `#212A25` | 1.22 | `#26302B` | 12.07 | `#1E2A32` | 13.39 |
| 1 | red | `#E06C75` | 5.63 | `#B23A48` | 5.18 | `#B23A48` | 5.34 |
| 2 | green | `#8BD49C` | 10.27 | `#2C784B` | 4.77 | `#2C784B` | 4.92 |
| 3 | yellow | `#E5C07B` | 10.41 | `#83631A` | 4.94 | `#83631A` | 5.09 |
| 4 | blue | `#7AA2F7` | 7.14 | `#2F5DA8` | 5.72 | `#2F5DA8` | 5.90 |
| 5 | magenta | `#C99BEA` | 8.01 | `#6B5BA8` | 5.04 | `#6B5BA8` | 5.20 |
| 6 | cyan | `#67D4C4` | 10.10 | `#147371` | 5.00 | `#147371` | 5.16 |
| 7 | white | `#C9D5CD` | 11.89 | `#A8B5AA` | 1.89 | `#A9B7C0` | 1.88 |
| 8 | bright black | `#5A6B61` | 3.18 | `#6B7A70` | 4.00 | `#63737D` | 4.48 |
| 9 | bright red | `#FF8A90` | 7.95 | `#8F2634` | 7.45 | `#8F2634` | 7.69 |
| 10 | bright green | `#A6E3A1` | 12.09 | `#1F5F3A` | 6.75 | `#1F5F3A` | 6.96 |
| 11 | bright yellow | `#FFD08A` | 12.54 | `#6F5415` | 6.29 | `#6F5415` | 6.49 |
| 12 | bright blue | `#9AB8FF` | 9.14 | `#234B8A` | 7.61 | `#234B8A` | 7.84 |
| 13 | bright magenta | `#E0B0FF` | 10.12 | `#5A4A98` | 6.48 | `#5A4A98` | 6.69 |
| 14 | bright cyan | `#8CE8DC` | 12.58 | `#0E5E6C` | 6.56 | `#0E5E6C` | 6.76 |
| 15 | bright white | `#F2F6F3` | 16.48 | `#D8D3C8` | 1.32 | `#D7E1E7` | 1.21 |

Notes:

- ANSI `black` in dark themes, and ANSI `white` / `bright white` in light themes, are naturally unsuitable for body text; they are used for ground colors, borders, or background blocks.
- Paper is a warm paper surface, Porcelain a cool porcelain surface; their chromatic ANSI colors are identical, while temperature is expressed through Ground/Ink/Dot.
- Red/green still follow terminal ANSI semantics. Color-blind users need symbols or text as well; Git status must not rely on color alone.
- Both light themes use a Graft tint for selections. Paper's selection is 1.90:1 against its ground, Porcelain's is 1.74:1; selected text is 5.75 / 7.08:1 respectively.

## Starship integration

`starship.toml.tmpl` automatically selects a palette based on the Ghostty theme:

| Ghostty theme | Starship palette |
|---|---|
| Dotgraft Ink | `dotgraft_ink` |
| Dotgraft Paper | `dotgraft_paper` |
| Dotgraft Porcelain | `dotgraft_porcelain` |
| Catppuccin Latte / GitHub Light Default | `catppuccin_latte` |
| Catppuccin Frappe | `catppuccin_frappe` |
| Other dark themes | `catppuccin_mocha` |

Starship's prompt uses multicolor status indicators; the terminal background stays low-contrast so it does not compete with code for attention.

## Switching themes

List the current theme and available themes:

```bash
dotgraft theme
dotgraft theme list
```

Switch:

```bash
dotgraft theme ink
dotgraft theme paper
dotgraft theme porcelain
```

Full theme names and built-in theme aliases are also accepted:

```bash
dotgraft theme "Dotgraft Ink"
dotgraft theme "Dotgraft Paper"
dotgraft theme "Dotgraft Porcelain"
dotgraft theme mocha
dotgraft theme latte
```

`dotgraft theme` changes only the theme; it does not ask about tools or glass again. It updates the separate `chezmoi.toml` and then applies only:

```text
~/.config/ghostty/config
~/.config/starship.toml
```

To apply:

```bash
exec zsh
```

Then press `Cmd + Shift + ,` in Ghostty to reload.

## Validation

Theme files:

```bash
ghostty +validate-config --config-file="$HOME/.config/ghostty/themes/Dotgraft Ink"
ghostty +validate-config --config-file="$HOME/.config/ghostty/themes/Dotgraft Paper"
ghostty +validate-config --config-file="$HOME/.config/ghostty/themes/Dotgraft Porcelain"
```

Theme lookup:

```bash
ghostty +list-themes | grep -i dotgraft
```

Starship rendering:

```bash
STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt
```

Project tests:

```bash
bats tests/unit
bash tests/smoke.sh
python3 tests/theme-contract.py
```

`tests/theme-contract.py` checks role consistency, AA contrast, ANSI hue stability, and Starship palettes. The smoke test covers Ghostty validation for all three themes, Starship palettes, theme switching, and the managed-file allowlist.

## Non-goals

- No image-background themes
- No keybindings or shell configuration inside themes
- Light themes are not inverted versions of dark themes
- No automatic macOS light/dark switching for now: Ghostty supports `dark:/light:`, but the Starship palette is currently a single value
- No general-purpose theme marketplace; Ink / Paper / Porcelain are built-in themes, and other Ghostty themes are available as alternatives
