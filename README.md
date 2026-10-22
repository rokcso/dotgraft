# Dotgraft

English · [简体中文](README.zh-CN.md)

A macOS terminal setup for **Ghostty + Starship + zsh**, managed with [chezmoi](https://www.chezmoi.io). Preview configuration changes before applying them, keep them in version control, and back up files before uninstalling.

![Dotgraft running in Ghostty](docs/images/dotgraft-preview.webp)

Ink (left), Paper (center), and Porcelain (right). The screenshot uses a simplified demonstration prompt.

## Install

Requires macOS 13 or later, Homebrew, and an internet connection. The configuration targets Ghostty 1.3 or later. Native glass requires macOS 26; older systems use numeric blur. Linux is not supported.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rokcso/dotgraft/main/bootstrap.sh)
```

The installer checks the environment, installs chezmoi, asks which tools and appearance settings to use, and shows a file-change summary before asking for confirmation.

<details>
<summary>Install a release or run unattended</summary>

Pin the installation to a release:

```bash
DOTGRAFT_REF=v0.1.0 \
  bash <(curl -fsSL https://raw.githubusercontent.com/rokcso/dotgraft/v0.1.0/bootstrap.sh)
```

A tagged installation does not automatically advance to another release with `dotgraft update`.

For unattended installation:

```bash
DOTGRAFT_YES=1 \
DOTGRAFT_TOOLS="fzf,zoxide,eza,bat,yazi" \
DOTGRAFT_THEME="Dotgraft Ink" \
DOTGRAFT_GLASS=true \
  bash <(curl -fsSL https://raw.githubusercontent.com/rokcso/dotgraft/main/bootstrap.sh)
```

A local copy of the installer also accepts arguments:

```bash
bash bootstrap.sh --yes --tools=fzf,zoxide --theme="Dotgraft Paper" --glass=false
```

</details>

After installation, run `exec zsh`. In Ghostty, press `Cmd+Shift+,` to reload the configuration.

## Everyday commands

| Command | Purpose |
|---|---|
| `dotgraft status` | Show selections, file changes, and version |
| `dotgraft diff [--full]` | Preview a summary or the full patch |
| `dotgraft apply` | Preview, confirm, and apply configuration |
| `dotgraft update` | Pull upstream changes, apply them, and repair dependencies |
| `dotgraft reconfigure` | Choose tools and appearance settings again |
| `dotgraft theme paper` | Switch Ghostty and Starship to Paper |
| `dotgraft backup list` | List backups |
| `dotgraft restore <timestamp>` | Restore a backup |
| `dotgraft doctor` | Check the Dotgraft environment |
| `dotgraft uninstall` | Back up and remove managed configuration |

The `dotg` alias is available when no existing command, function, or alias uses that name.

## Themes and tools

Three matching Ghostty and Starship themes are included:

- **Dotgraft Ink** — dark, the default
- **Dotgraft Paper** — warm light
- **Dotgraft Porcelain** — cool light

Run `dotgraft theme` to list themes, or `dotgraft theme ink`, `paper`, or `porcelain` to switch.

Optional tools are **fzf**, **zoxide**, **eza**, **bat**, and **yazi**. Deselecting a tool removes its optional configuration, not its installed Homebrew package.

## What changes

Dotgraft adds a marked block to `~/.zshrc` and manages its own zsh configuration, Ghostty configuration and themes, Starship configuration, and `~/.local/bin/dotgraft`. Put machine-specific shell settings in `~/.config/zsh/conf.d/90-local.zsh`; subsequent applies leave that file alone.

It uses a separate chezmoi source and configuration:

```text
~/.local/share/chezmoi-dotgraft
~/.config/dotgraft/chezmoi.toml
```

The default chezmoi source/configuration, `~/.zprofile`, and `~/.zshenv` are not modified. Existing target files are backed up during installation; uninstall also backs up files before removing them. Backups live under `~/.config-backup/`.

Separate source directories do not prevent conflicts if another configuration manager owns the same target files. Review the installation summary first.

## Documentation

The detailed guides below are currently in Chinese; English versions are being prepared.

| Guide | Contents |
|---|---|
| [Usage and maintenance](docs/usage.md) | Commands, backup, restore, uninstall, and local development |
| [Configuration architecture](docs/configuration.md) | Source layout, templates, loading order, and tests |
| [Ghostty](docs/ghostty.md) | Configuration, macOS overrides, shortcuts, and validation |
| [Themes](docs/themes.md) | Palettes, contrast, and Starship integration |
| [Shell](docs/shell.md) | Prompt, plugins, tools, aliases, and completion |
| [Troubleshooting](docs/troubleshooting.md) | Common problems and diagnostics |
| [Changelog](CHANGELOG.md) | Release history |

CI checks shell syntax and formatting, theme contracts, unit tests, and smoke tests on macOS 14 and macOS latest. Release publishing also requires the macOS tests to pass.

## Credits

[Ghostty](https://ghostty.org) · [Starship](https://starship.rs) · [chezmoi](https://www.chezmoi.io) · [Maple Mono](https://github.com/subframe7536/maple-font) · [Catppuccin](https://github.com/catppuccin/catppuccin) · [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) · [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) · [zsh-completions](https://github.com/zsh-users/zsh-completions)

Created by [rokcso](https://github.com/rokcso). [MIT license](LICENSE).
