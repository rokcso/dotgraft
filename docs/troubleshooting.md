# Troubleshooting

English · [简体中文](zh-CN/troubleshooting.md)

Find your symptom below. First confirm the current state:

```bash
dotgraft status
dotgraft doctor
dotgraft diff
```

`doctor` checks Dotgraft's own environment; when you need the full chezmoi diagnostics, use `dotgraft chezmoi doctor`.

## Installed, but Ghostty's theme/font did not change

**Most likely cause**: the override file on macOS is still present.

```
~/Library/Application Support/com.mitchellh.ghostty/config
```

It loads **after** `~/.config/ghostty/config` and overrides it key by key. Check:

```bash
ghostty +show-config | grep -E '^(theme|font-family|background) '
```

If the displayed theme is not the one you selected, this file is overriding it. bootstrap backs it up to `~/.config-backup/<timestamp>/` and renames it to `config.before-dotgraft`; `dotgraft uninstall` restores it.

If you declined to move it at the time, handle it manually:

```bash
mv "$HOME/Library/Application Support/com.mitchellh.ghostty/config" \
   "$HOME/Library/Application Support/com.mitchellh.ghostty/config.before-dotgraft"
```

Then press `Cmd + Shift + ,` to reload.

For details, see the [Ghostty documentation](ghostty.md#check-first-the-macos-override-file).

## Changed configuration but nothing took effect

Ghostty does not reload automatically. Press `Cmd + Shift + ,`.

zsh configuration requires a **new shell**—`init.zsh` is sourced only when a new process starts. The simplest way:

```bash
exec zsh
```

If you changed a file under `conf.d/`, first confirm it has been deployed to the home directory:

```bash
dotgraft diff      # Output means it has not been applied yet
```

## The prompt is not the rainbow bar

Check in order:

```bash
command -v starship                      # Is it installed?
ls -l ~/.config/starship.toml            # Is the configuration present?
starship --version
```

If all three are present, check whether `~/.zshrc` contains the dotgraft block:

```bash
grep -A3 '>>> dotgraft >>>' ~/.zshrc
```

If it is missing, installation did not finish; run `dotgraft apply`. If it reports missing dependencies, then run `dotgraft deps`.

Another possibility: another tool sets `PROMPT` **after** the dotgraft block and overrides it. Check the content after the dotgraft block in `~/.zshrc`.

## Completion does not work / compinit reports insecure directories

`compinit` errors are usually permission issues. Most Homebrew directories are owned by root, and zsh considers them "insecure" and refuses to load them.

Dotgraft already uses `compinit -u` to accept such directories. If warnings remain, they most likely come from another tool in `~/.zshrc` calling `compinit` itself:

```bash
grep -n compinit ~/.zshrc
```

To rebuild `zcompdump`:

```bash
rm -f ~/.zcompdump* && exec zsh
```

## Tab completion cannot find a newly installed command

The completion cache is stale:

```bash
rm -f ~/.zcompdump* && exec zsh
```

## Font icons appear as boxes / Chinese uses another font

Confirm that the font actually matches:

```bash
ghostty +show-face --string="a中"
```

Expected output looks like:

```
U+61 « a » found in face "Maple Mono NF CN".
U+4E2D « 中 » found in face "Maple Mono NF CN".
```

If it reports not found, or Chinese matches another font:

1. The font is not installed → `brew install --cask font-maple-mono-nf-cn`
2. The family name is wrong → `ghostty +list-fonts | grep -i maple` to see the exact name. The CN edition must be written as `"Maple Mono NF CN"`; without CN it will not match.

## `brew bundle` reports a font conflict

```
Error: font-maple-mono-nf-cn: It seems the existing Font is different from the one being installed.
```

The cause is that you previously installed Maple Mono manually (for example, by downloading a TTF from GitHub and dragging it into Font Book), and the cask tried to "adopt" a file with the same name but different binary contents, then refused.

Dotgraft's installation script already handles this: if it detects a **Maple ... CN** font in `~/Library/Fonts` or `/Library/Fonts`, it skips installation. Previously it matched only `maple`, which incorrectly treated non-CN editions as already installed; now it recognizes only the CN edition. If you run `brew bundle` manually elsewhere and hit this, you can ignore it—the font is already present.

## `dotgraft: command not found`

It is installed at `~/.local/bin/dotgraft`, and that directory must be on `PATH`. `init.zsh` adds it, but only if the dotgraft block exists in `~/.zshrc`.

Temporary workaround:

```bash
~/.local/bin/dotgraft status
```

## Files remain after `chezmoi purge`

This is the expected behavior of `chezmoi purge`. Its documentation says it "deletes chezmoi's configuration, state, and source directory, **but preserves the target state**".

Use `dotgraft uninstall` for a proper uninstall; it cleans up target files itself. To do it manually:

```bash
chezmoi managed --include=files --path-style=absolute
```

The listed paths are the ones to delete (except `~/.zshrc`, where only the block is removed). `dotgraft uninstall` now checks the allowlist and the `.zshrc` block integrity before backing up and deleting; if it refuses to run, follow the error message rather than forcing deletion.

## Shell errors after uninstall

Most likely there are leftover lines of unknown origin in `~/.zshrc`. Check:

```bash
grep -n 'dotgraft\|\.config/zsh' ~/.zshrc
```

`dotgraft uninstall` backs up `~/.zshrc` to `~/.config-backup/<timestamp>/files/.zshrc`, so you can compare directly:

```bash
diff ~/.config-backup/<timestamp>/files/.zshrc ~/.zshrc
```

## zsh startup is slow

Measure first:

```bash
time zsh -i -c exit
```

Common causes:

- **Repeated `compinit`**. Dotgraft runs it once (see [Configuration architecture](configuration.md#fragment-load-order)); if another tool in `~/.zshrc` also runs it, the cost adds up. Use `zprof` to locate it:

  ```zsh
  # Temporarily add this at the very top of ~/.zshrc
  zmodload zsh/zprof
  # Add this at the end
  zprof
  ```

- **Plugins loaded repeatedly**. Check whether something else in `~/.zshrc` also `source`s autosuggestions or syntax-highlighting.

## Changed options but files were not deleted

Confirm that you are using the template path. Only fragments with a `.tmpl` suffix are deleted by chezmoi when they render empty. A plain `.zsh` file continues to exist even if it is not wrapped in `{{ if }}`.

Also, entries in `.chezmoiignore` are invisible to `exact_`, so ignore rules cannot reclaim files that were already deployed when used for options. Dotgraft uses templates instead of ignore specifically to avoid this.

Apply again:

```bash
dotgraft reconfigure
```

## Dependencies were not installed / `brew install` failed

`run_onchange` runs only when the script contents change, so "it failed last time, this apply will retry automatically" does not hold. Dotgraft has a separate dependency entry point:

```bash
dotgraft deps
```

It unconditionally re-renders and runs `run_onchange_install-packages.sh.tmpl`, and exits non-zero on failure. `dotgraft update` and `dotgraft reconfigure` call it automatically when they finish.

## bootstrap says the source directory does not look like Dotgraft

Dotgraft uses a separate source:

```
~/.local/share/chezmoi-dotgraft
```

When the source already contains content, `chezmoi init` **does not clone**; it continues using the existing source. To avoid applying someone else's dotfiles as Dotgraft, bootstrap stops immediately. Follow the prompt to back up and move Dotgraft's source aside:

```bash
mv "$HOME/.local/share/chezmoi-dotgraft" "$HOME/.local/share/chezmoi-dotgraft.before-dotgraft.$(date +%Y%m%d_%H%M%S)"
```

If the prompt refers to an older default source, first use the old version's `dotgraft uninstall`, or move `~/.local/share/chezmoi` aside. Your own default chezmoi source/config is not changed by a new installation.

## Running `chezmoi` directly does not show Dotgraft

This is expected with a separate source. Use:

```bash
dotgraft chezmoi status
dotgraft chezmoi diff
dotgraft cd
```

When you need low-level commands, always go through `dotgraft chezmoi ...`.

## Uninstall is refused

Two common causes:

1. **The current source contains managed files that are not Dotgraft's.** The script lists the paths and stops. Back up/move those files first, or give them a separate source.
2. **The dotgraft block in `~/.zshrc` is incomplete.** If there is a start marker but no end marker, stripping it directly would accidentally delete content after it, so the script stops. Add the end marker manually:

   ```zsh
   # <<< dotgraft <<<
   ```

   If the file is already damaged, restore it from `~/.config-backup/<timestamp>/files/.zshrc` and try again.

   If `~/.zshrc` is a symbolic link, uninstall preserves the link and modifies only the real file it points to; the backup records the original target in `.zshrc.symlink`.

## The source directory remains after uninstall

This is a safety design. `dotgraft uninstall` runs `chezmoi purge` only when Dotgraft's separate source is a clean clone (no uncommitted changes, no unpushed commits, and a remote that looks like dotgraft). Otherwise it keeps the source so it cannot delete private files you added to the same repository.

Once you have confirmed it is safe, you can manually clean up Dotgraft's own source/config:

```bash
dotgraft chezmoi purge --force
```

## Update asks you to reconfigure

`dotgraft update` first runs `git pull`, then checks whether `.chezmoi.toml.tmpl` changed. If it did, it runs `chezmoi init` again so template rendering does not fail after upstream adds a new data key. Answer the prompts as they appear.

## `dotg` is unavailable / completion does not work

First confirm it is not just "the new configuration has not loaded yet":

```bash
exec zsh
whence -w dotg
```

Expected:

```text
dotg: alias
```

Then confirm completion registration:

```bash
print ${_comps[dotg]}
print ${_comps[dotgraft]}
```

Both are expected to be `_dotgraft`. If `dotg` is already a system command, `80-dotgraft.zsh` preserves it and does not override it with an alias; in that case, continue using the full `dotgraft`.

If `dotg` does not exist at all, check the installed source version:

```bash
dotgraft status
```

Look at the `Version:` line. Older installations may not have the `dotg` alias; run `dotgraft update` first, or reinstall the latest version. During development, use:

```bash
DOTGRAFT_REPO="$PWD" bash bootstrap.sh
exec zsh
```

`DOTGRAFT_REPO="$PWD"` clones only the committed HEAD; uncommitted changes require the `DOTGRAFT_SOURCE="$PWD" ... dotgraft apply` approach described in the documentation.

## Ghostty says it cannot find Dotgraft Ink / Paper / Porcelain

Theme files should be at:

```text
~/.config/ghostty/themes/Dotgraft Ink
~/.config/ghostty/themes/Dotgraft Paper
~/.config/ghostty/themes/Dotgraft Porcelain
```

First confirm the configuration has been applied:

```bash
dotgraft apply
ls ~/.config/ghostty/themes/
ghostty +list-themes | grep -i dotgraft
```

If the theme files exist but Ghostty still cannot find them, press `Cmd + Shift + ,` to reload the configuration, or check that the name in `theme =` exactly matches the file name (case-sensitive).

## `dotgraft diff` output is too long

By default, `dotgraft diff` shows only the `chezmoi status` file summary, which is suitable for confirming "which files will change". On first installation all targets are new files, and a full diff would print the entire `starship.toml` and `dotgraft` script, so it is hidden by default.

To see the line-by-line patch:

```bash
dotgraft diff --full
```

bootstrap also shows only the summary on first installation, avoiding a screen full of new file contents.

## How to restore a backup

```bash
dotgraft backup list
dotgraft backup show <timestamp>
dotgraft restore <timestamp>
```

If the command is no longer on `PATH` after uninstall, run the dotgraft command inside the backup:

```bash
~/.config-backup/<timestamp>/files/.local/bin/dotgraft restore <timestamp>
```

`restore` backs up the current state before restoring; `--pre-existing` restores the original files from before installation, and `--with-ghostty-override` restores the macOS Ghostty override configuration.

## What are age / 1Password / Bitwarden in `dotgraft doctor`?

`dotgraft doctor` now checks only Dotgraft's own environment: macOS, shell, Homebrew, chezmoi, the separate source/config, the `.zshrc` block, managed files, selected tools, Starship, Ghostty, fonts, and the Ghostty override file.

If you want to see chezmoi's full diagnostics (including optional integrations such as age, 1Password, Bitwarden, pass, and vault), use:

```bash
dotgraft chezmoi doctor
```

Those `info` lines only mean "an optional integration is not configured"; they do not mean the Dotgraft installation failed.

## Need more information

```bash
dotgraft status        # Options, differences, version
dotgraft doctor        # Dotgraft-specific environment check
dotgraft chezmoi doctor # Full chezmoi environment check
ghostty +show-config   # Ghostty's final merged configuration
ghostty +version
```

When opening an issue, paste the output of the commands above; it saves a lot of back-and-forth.
