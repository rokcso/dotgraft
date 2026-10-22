# Usage and maintenance

English · [简体中文](zh-CN/usage.md)

Everyday operations after installation, file locations, backup and restore, and uninstall.

## After installation

When installation finishes:

```bash
exec zsh
dotgraft status
```

`dotgraft status` shows the current theme, selected tools, file differences, and version. If Ghostty is already open, press `Cmd + Shift + ,` to reload the configuration.

## Everyday commands

| Command | Purpose |
|---|---|
| `dotgraft status` | Selections, file differences, and version |
| `dotgraft diff` | Show a file summary by default |
| `dotgraft diff --full` | Show the complete line-by-line diff |
| `dotgraft apply` | Preview, confirm, and apply |
| `dotgraft update` | Pull upstream changes, preview, apply, and repair dependencies |
| `dotgraft deps` | Install or repair Homebrew dependencies unconditionally |
| `dotgraft reconfigure` | Choose options again and repair dependencies |
| `dotgraft theme [ink\|paper\|porcelain\|list]` | Switch themes |
| `dotgraft lang [en\|zh\|auto]` | Switch the UI language |
| `dotgraft backup [list\|show <timestamp>]` | Inspect backups |
| `dotgraft restore <timestamp>` | Restore from a backup |
| `dotgraft edit <file>` | Edit the repository copy of a managed file |
| `dotgraft cd` | Enter Dotgraft's chezmoi source directory |
| `dotgraft chezmoi <args>` | Run chezmoi against Dotgraft's source and config |
| `dotgraft doctor` | Check the Dotgraft environment |
| `dotgraft chezmoi doctor` | Run the full chezmoi diagnostics |
| `dotgraft version` | Show the version and source commit |
| `dotgraft uninstall` | Uninstall |

`dotgraft diff` lists only a file summary by default, avoiding a full printout of every new file on first installation. Use `dotgraft diff --full` when you need the line-by-line patch.

After installation, if no other command already uses `dotg`, a short alias is available:

```bash
dotg status
dotg update
dotg deps
```

Both `dotgraft` and `dotg` support subcommand completion. If `dotg` is already taken, it is not overridden; continue using the full `dotgraft` command.

## Options

Installation asks three questions. The answers are written to `~/.config/dotgraft/chezmoi.toml` and are not committed to the repository:

| Question | Effect |
|---|---|
| CLI tools | fzf / zoxide / eza / bat / yazi. Unchecked tools are not installed, and their configuration fragments are removed; Homebrew packages that are already installed are not uninstalled |
| Ghostty theme | Dotgraft Ink (default), Paper, Porcelain, or a built-in theme |
| Glass | macOS 26+ defaults to native glass; older systems default to numeric blur |

You can change these at any time:

```bash
dotgraft reconfigure
```

In non-interactive environments, environment variables can bypass the menus:

```bash
DOTGRAFT_THEME="Dotgraft Paper" \
DOTGRAFT_GLASS=false \
  dotgraft reconfigure
```

For how options are implemented, see [Configuration architecture](configuration.md#how-choices-take-effect).

## Themes

```bash
dotgraft theme            # Show the current theme and available themes
dotgraft theme ink        # Dark
dotgraft theme paper      # Warm light
dotgraft theme porcelain  # Cool light
```

`dotgraft theme` changes only Ghostty and Starship; it does not ask about tools or glass again. After switching:

```bash
exec zsh
```

Then press `Cmd + Shift + ,` in Ghostty to reload. For the full palettes and contrast ratios, see [Themes](themes.md).

## Language

```bash
dotgraft lang        # Current language and where it came from
dotgraft lang zh     # Save Simplified Chinese
dotgraft lang en     # Save English
dotgraft lang auto   # Remove the saved preference, detect again
```

`dotgraft lang` writes `~/.config/dotgraft/language`, outside chezmoi, so switching does not run an apply. An explicit `DOTGRAFT_LANG` still wins over the saved preference; `auto` falls back to `LC_ALL`, `LC_MESSAGES`, `LANG`, and finally the first macOS `AppleLanguages` entry. Run `exec zsh` afterwards to refresh completion.

## Local development installation

A normal installation clones from GitHub `main` by default. To install the current local commit during development:

```bash
cd /Users/lin/Developer/GitHub-rokcso/dotgraft
DOTGRAFT_REPO="$PWD" bash bootstrap.sh
exec zsh
dotg status
```

Notes:

- `DOTGRAFT_REPO="$PWD"` clones only the **committed HEAD**; uncommitted changes are not included.
- After installation, `origin` in `~/.local/share/chezmoi-dotgraft` points to the local repository path. After later commits, you can run `dotg update` directly.
- To switch back to GitHub updates, reinstall with the default bootstrap or manually change the source remote.

If you do not want to commit after every change, you can make `dotgraft` use the working tree as its source:

```bash
DOTGRAFT_SOURCE="$PWD" \
DOTGRAFT_CONFIG="$HOME/.config/dotgraft/chezmoi.toml" \
dotgraft diff

DOTGRAFT_SOURCE="$PWD" \
DOTGRAFT_CONFIG="$HOME/.config/dotgraft/chezmoi.toml" \
dotgraft apply
```

This syncs the current working tree, including uncommitted changes, directly to the real `$HOME`. After changing shell configuration, remember to run `exec zsh`.

## File locations

Managed targets are concentrated in a few paths under the home directory. Dotgraft does not use `sudo`, does not modify `/etc`, and never modifies `~/.zprofile` or `~/.zshenv`.

| Path | Contents | Method |
|---|---|---|
| `~/.zshrc` | A small marked block at the end | Edited in place; only the block is touched |
| `~/.config/zsh/` | zsh configuration | Fully managed |
| `~/.config/zsh/conf.d/90-local.zsh` | Machine-specific configuration | Created once |
| `~/.config/ghostty/config` | Ghostty configuration | Fully managed; rendered from a template |
| `~/.config/ghostty/themes/` | Dotgraft Ink / Paper / Porcelain | Fully managed |
| `~/.config/starship.toml` | Starship configuration | Fully managed |
| `~/.local/bin/dotgraft` | The command itself | Fully managed |
| `~/.config/dotgraft/chezmoi.toml` | Option answers | Generated locally; never committed |
| `~/.config/dotgraft/language` | Saved UI language from `dotgraft lang` | Written locally; optional |

Dotgraft also creates or modifies:

| Path | Contents |
|---|---|
| `~/.local/share/chezmoi-dotgraft` | Separate chezmoi source directory (git clone) |
| `~/.config-backup/<timestamp>/` | Backups of existing target files, the Ghostty override file, and option answers |
| `~/Library/Application Support/com.mitchellh.ghostty/config` | If present, backed up and moved aside so it cannot override the theme |

The default `~/.local/share/chezmoi` and `~/.config/chezmoi/` are not written to.

## Backup and restore

Installation, uninstall, and `restore` write backups to:

```text
~/.config-backup/<timestamp>/
```

Inspect them:

```bash
dotgraft backup list
dotgraft backup show <timestamp>
```

Restore:

```bash
dotgraft restore <timestamp>
dotgraft restore <timestamp> --pre-existing     # Original files from before installation
dotgraft restore <timestamp> --yes              # Non-interactive
```

`restore` first lists the files to restore and backs up the current state before restoring. After restoring shell configuration, run `exec zsh`; in Ghostty, press `Cmd + Shift + ,` to reload.

If Dotgraft has already been uninstalled and is not on `PATH`, run the command from the backup directly:

```bash
~/.config-backup/<timestamp>/files/.local/bin/dotgraft restore <timestamp>
```

To restore the macOS Ghostty override file that bootstrap moved aside, add `--with-ghostty-override`.

## Uninstall

```bash
dotgraft uninstall
```

Uninstall first backs up all managed files, `~/.zshrc`, and `~/.config/dotgraft/chezmoi.toml` to `~/.config-backup/<timestamp>/` (managed files are under `files/`). It then deletes managed files, removes the marked block from `~/.zshrc`, cleans up empty directories, and restores the Ghostty override configuration moved aside by bootstrap if it exists. It does **not** uninstall Homebrew packages.

Safety boundaries:

- If the dotgraft block in `~/.zshrc` is incomplete, uninstall refuses to run so it cannot accidentally delete content after the block.
- If `~/.zshrc` is a symbolic link, Dotgraft edits the real file it points to and preserves the link; the backup records `.zshrc.symlink`.
- If the current source contains managed files that are not part of Dotgraft, uninstall lists them and stops.
- `chezmoi purge` runs only when Dotgraft's separate source is a clean clone (no uncommitted changes, no unpushed commits, and a remote that looks like dotgraft); otherwise the source is kept.

Running `chezmoi purge` on its own does not delete target files; this is chezmoi's expected behavior. Use `dotgraft uninstall` for a proper uninstall.

## Version

```bash
dotgraft version
```

The current version number is in `VERSION`; changes are listed in [CHANGELOG.md](../CHANGELOG.md). For the release and CI process, see [Configuration architecture](configuration.md#ci).
