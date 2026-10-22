# Ghostty configuration

English · [简体中文](zh-CN/ghostty.md)

The configuration file is managed by Dotgraft at `~/.config/ghostty/config`; its source file is `dot_config/ghostty/config.tmpl`.

To apply changes:

```bash
dotgraft apply         # Sync Dotgraft's separate source to the home directory
# Then press Cmd + Shift + , in Ghostty
```

## Check first: the macOS override file

Ghostty's configuration load order (as of 1.3, `Config.zig:loadDefaultFiles`):

```
Defaults → $XDG_CONFIG_HOME/ghostty/config → ~/Library/Application Support/com.mitchellh.ghostty/config → CLI arguments → recursive includes
```

The key point: **the Application Support file loads after XDG and overrides it key by key**.

On first launch, Ghostty generates a template file at `~/Library/Application Support/com.mitchellh.ghostty/config`. As long as it exists and sets a key, the same key in `~/.config/ghostty/config` is overridden.

Measured example (XDG sets `theme = Dracula`, while Application Support still has three old lines):

```
font-size = 99          ← XDG wins (App Support has no such key)
theme = GitHub Dark     ← Overridden by XDG
background = #0d1117    ← Overridden by XDG
```

Therefore `bootstrap.sh` detects this file, prints its contents, backs it up to `~/.config-backup/<timestamp>/`, and—after asking for consent—renames it to `config.before-dotgraft`. `dotgraft uninstall` restores it. To handle it manually:

```bash
mv "$HOME/Library/Application Support/com.mitchellh.ghostty/config" \
   "$HOME/Library/Application Support/com.mitchellh.ghostty/config.before-dotgraft"
```

## Settings in detail

### Theme

```
theme = {{ .theme }}
```

Dotgraft ships three custom themes. For complete palettes and contrast ratios, see [Themes](themes.md):

- `Dotgraft Ink`: dark, the default theme
- `Dotgraft Paper`: warm light
- `Dotgraft Porcelain`: cool light

chezmoi installs the theme files to:

```text
~/.config/ghostty/themes/Dotgraft Ink
~/.config/ghostty/themes/Dotgraft Paper
~/.config/ghostty/themes/Dotgraft Porcelain
```

To follow the system's light/dark appearance, use a pair:

```text
theme = dark:Dotgraft Ink,light:Dotgraft Paper
# Or: theme = dark:Dotgraft Ink,light:Dotgraft Porcelain
```

Built-in themes are still available through `ghostty +list-themes`; add `--preview` to preview their colors.

**Do not write `background` in the configuration again.** The theme already defines the background color (Ink is `#121816`, Paper is `#F4F1E8`), and a manually written `background` would override it, effectively making the theme switch pointless.

### Dotgraft theme colors

All three themes set only color-related configuration:

| Role | Dotgraft Ink | Dotgraft Paper | Dotgraft Porcelain |
|---|---|---|---|
| Background | `#121816` | `#F4F1E8` | `#F2F5F7` |
| Foreground | `#D8E3DA` | `#26302B` | `#1E2A32` |
| Cursor | `#F2B36B` | `#8F4A14` | `#2A648F` |
| Selection background | `#345A4A` | `#8FBBA1` | `#9CC5B2` |
| Selection foreground | `#F0F7F2` | `#1E3A2F` | `#17323D` |

The ANSI 16 colors are also designed as matching sets. Ink is a dark green ink ground with warm white foreground and an amber cursor; Paper is a warm paper ground with ink-green foreground and a copper cursor; Porcelain is a cool white ground with blue-black foreground and a blue cursor. Starship automatically switches to the matching `dotgraft_ink` / `dotgraft_paper` / `dotgraft_porcelain` palette.

### Font

```
font-family = "Maple Mono NF CN"
font-size = 13
font-thicken = true
```

- It must be the **Nerd Font** version; otherwise icons and powerline separators will have missing glyphs.
- This configuration uses the **CN** edition, which includes Chinese glyphs so Chinese text does not fall back to another system font. If you installed the non-CN edition, the family name must be `"Maple Mono NF"`; without CN it will not match.
- `font-thicken` is macOS-specific. It adds an outline stroke and looks crisper on Retina displays.

Confirm that the font actually matches (this is more reliable than visual inspection):

```bash
ghostty +show-face --string="a中"
# U+61 « a » found in face "Maple Mono NF CN".
# U+4E2D « 中 » found in face "Maple Mono NF CN".
```

List all available font family names: `ghostty +list-fonts`.

### Window

```
window-padding-x = 12
window-padding-y = 8
window-padding-balance = true
background-opacity = 0.92
```

- `window-padding-*` is measured in points and scales with screen DPI.
- The viewport usually cannot be divided evenly by character dimensions. `window-padding-balance` distributes the remaining space evenly across all four sides, making the view better centered.
- `background-opacity` at 0.92 is the setting where the wallpaper shows through without interfering with reading code; below 0.85 it starts to hurt readability.

### Glass

The option determines one line. The default answer depends on the system version: macOS 26+ defaults to native glass, and older systems default to numeric blur.

```
# "Native" selected and macOS ≥ 26:
background-blur = macos-glass-regular

# Otherwise:
background-blur = 20
```

- The number is blur strength and only matters when `background-opacity < 1`. 20 is reliable; above 30, rendering artifacts and dropped frames may appear.
- Starting with macOS 26, `macos-glass-regular` (standard glass) and `macos-glass-clear` (highly transparent glass) are additionally supported and look more native than numeric blur. `true` is equivalent to strength 20.

### Title bar and window state

```
macos-titlebar-style = native
window-save-state = always
```

- `native`: the standard macOS title bar, where tab information remains reliably visible. This is the default choice.
- `tabs`: a custom title bar that embeds the tab bar into the title bar. Some macOS/Ghostty combinations may make tab labels invisible; if that happens, switch back to `native` or `transparent`.
- `transparent`: standard structure with a transparent title bar; `hidden`: hide the title bar entirely.
- `window-save-state = always`: preserve window position, size, tabs, and split layout after quitting. Splits can even return to their previous working directories, which depends on the shell integration below.

### Cursor

```
cursor-style = bar
cursor-style-blink = true
```

Values: `bar` / `block` / `underline` / `block_hollow`.

Note: with shell integration enabled, it forces the cursor to a bar at the prompt. To make the setting here always take precedence, add:

```
shell-integration-features = no-cursor
```

### Interaction

```
mouse-hide-while-typing = true
confirm-close-surface = false
```

Copy-on-select is already the default behavior on macOS (`copy-on-select = true`), so it does not need to be written explicitly.

### Shell integration

```
shell-integration = zsh
```

This provides prompt jumping, working directory propagation, and command boundary markers. `window-save-state` restoring working directories above, as well as `Cmd+F` search positioning, depend on it.

It is also the thing that manipulates `ZDOTDIR`—see [Configuration architecture](configuration.md#why-not-zdotdir).

## Optional enhancements

These are disabled by default; uncomment them when needed:

| Configuration | Effect |
|---|---|
| `minimum-contrast = 1.1` | Automatically increases contrast when foreground and background are too close, avoiding "invisible text". 1 means no intervention |
| `notify-on-command-finish = unfocused` | Sends a system notification when a command finishes and the window is not focused; useful for long tasks |
| `background-blur = macos-glass-regular` | Native system glass (macOS 26+) |
| `keybind = global:cmd+shift+space=toggle_quick_terminal` | Quick terminal hotkey |

### Quick terminal

Summons a temporary terminal from the edge of the screen, similar to Guake / iTerm2's hotkey window. No shortcut is bound by default.

```
keybind = global:cmd+shift+space=toggle_quick_terminal
quick-terminal-position = top        # top / bottom / left / right / center
quick-terminal-screen = mouse        # main / mouse / macos-menu-bar
```

**Syntax pitfall**: the trigger cannot contain spaces, and the equals sign must be adjacent. The following produces `InvalidAction`:

```
keybind = global:cmd+shift+space = toggle_quick_terminal    ✗
keybind = global:cmd+shift+space=toggle_quick_terminal      ✓
```

Also, `` ` `` can only be written as `` cmd+` ``; `cmd+grave` is invalid.

## Shortcuts

Default bindings in Ghostty 1.3.1; verify with `ghostty +list-keybinds`:

| Shortcut | Action |
|---|---|
| `Cmd+T` | New tab |
| `Cmd+D` / `Cmd+Shift+D` | Split right / split down |
| `Cmd+[` / `Cmd+]` | Move focus to previous / next split |
| `Cmd+Alt+Arrow` | Move focus in the corresponding direction |
| `Cmd+Shift+Enter` | Toggle maximize for the current split |
| `Cmd+W` | Close the current split |
| `Cmd+Alt+W` | Close the tab |
| `Cmd+=` / `Cmd+-` / `Cmd+0` | Increase / decrease / reset font size (temporary, does not change configuration) |
| `Cmd+,` | Open the configuration file |
| `Cmd+Shift+,` | Reload configuration |
| `Cmd+F` / `Cmd+E` | Search / search selected text |
| `Cmd+Shift+P` | Command palette |

To change any binding, write `keybind = trigger=action`.

## Validation and debugging

Ghostty ships a set of configuration-oriented CLI actions; see all of them with `ghostty +help`:

| Command | Purpose |
|---|---|
| `+validate-config` | Validate whether a configuration file is legal (the current template must be **rendered first**) |
| `+show-config` | Print the currently effective configuration (merged from all sources) |
| `+show-config --default --docs` | Print all 600+ options and their documentation |
| `+show-face --string="a中"` | Find which font actually provides a given character |
| `+list-themes` / `+list-fonts` / `+list-keybinds` / `+list-colors` / `+list-actions` | Enumerate |
| `+edit-config` | Open the configuration file with `$EDITOR` |

To validate Dotgraft's template, render it first:

```bash
ghostty +validate-config --config-file=<(chezmoi execute-template < dot_config/ghostty/config.tmpl)
```

Validating `config.tmpl` directly reports `unknown field`, because it is a Go template, not configuration.

To confirm whether a key is actually in effect:

```bash
ghostty +show-config | grep '^theme'
```

## Version differences

Configuration keys change across Ghostty versions. When a key is renamed or removed in a newer version, Ghostty warns at startup. The current configuration passes `+validate-config` on **1.3.1**. If you use another version and encounter errors, open an issue with the output of `ghostty +version`.
