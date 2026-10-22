# Configuration architecture

English · [简体中文](zh-CN/configuration.md)

This guide explains how Dotgraft is organized: where files live, how load order is determined, how options take effect, and where to make changes when adding something. For everyday operations, see [Usage and maintenance](usage.md).

## Repository layout

```
.
├── .chezmoi.toml.tmpl                     # Installation option prompts
├── .chezmoiignore                         # Files that must not be deployed to $HOME
├── .dotgraft-source                       # Source ownership marker
├── .gitignore
├── Brewfile                               # Base dependencies, always installed
├── VERSION                                # Version number
├── CHANGELOG.md                           # Change history
├── bootstrap.sh                           # One-line installation entry point
├── run_onchange_install-packages.sh.tmpl  # Installs base dependencies + selected components
├── modify_dot_zshrc                       # Injects the marked block into ~/.zshrc
├── dot_config/
│   ├── ghostty/config.tmpl                # → ~/.config/ghostty/config
│   ├── ghostty/themes/Dotgraft Ink        # Dark theme
│   ├── ghostty/themes/Dotgraft Paper      # Light theme
│   ├── starship.toml.tmpl                 # → ~/.config/starship.toml (palette selected by theme)
│   └── zsh/
│       ├── init.zsh                       # → ~/.config/zsh/init.zsh
│       └── conf.d/
│           ├── 10-history.zsh
│           ├── 20-completion.zsh
│           ├── 30-prompt.zsh
│           ├── 40-tools.zsh.tmpl          # Optional
│           ├── 50-functions.zsh.tmpl      # Optional
│           ├── 60-plugins.zsh
│           ├── 70-aliases.zsh.tmpl        # Optional
│           ├── 80-dotgraft.zsh            # dotg alias + completion
│           ├── create_90-local.zsh        # Created once
│           └── 99-highlighting.zsh        # Must be last
├── dot_local/bin/executable_dotgraft      # → ~/.local/bin/dotgraft
├── .github/workflows/ci.yml                # Runs checks and render tests on every push
├── .github/workflows/release.yml           # Tag releases: macOS gate, packaging, release notes
├── tests/smoke.sh                          # End-to-end smoke test shared by local and CI
├── tests/unit/                             # bats unit tests
├── scripts/release-notes.py                # Extracts release notes from CHANGELOG
├── docs/
├── LICENSE
└── README.md
```

## chezmoi naming attributes

File names in the source directory are not arbitrary: prefixes determine how each file is mapped to its target location. Dotgraft uses six of them:

| Attribute | Meaning | Used in this repository |
|---|---|---|
| `dot_` | Add a dot before the name | `dot_config/` → `~/.config/` |
| `.tmpl` suffix | Render as a Go template | `config.tmpl`, `40-tools.zsh.tmpl` |
| `executable_` | Add the executable bit to the target file | `executable_dotgraft` |
| `create_` | Create only if missing; never overwrite afterward | `create_90-local.zsh` |
| `modify_` | Run as a script to modify an existing file | `modify_dot_zshrc` |
| `run_onchange_` | Run only when the contents change | `run_onchange_install-packages.sh.tmpl` |

Read `dot_config/ghostty/config.tmpl` as: the dotted `config` directory under `dot_config`, containing `config.tmpl`, which renders to a file named `config`. The target is `~/.config/ghostty/config`.

Patterns in `.chezmoiignore` match **target paths**, not source paths. Writing `dot_config/...` has no effect; write `.config/...` instead.

## Fragment load order

`init.zsh` uses a `for` loop plus a glob to source `conf.d/*.zsh` in lexicographic order, so the number in each file name is its load order:

| Order | File | Contents | Why it is here |
|---|---|---|---|
| 10 | `10-history.zsh` | HISTFILE / HISTSIZE / setopt | Earliest; later plugins depend on history |
| 20 | `20-completion.zsh` | fpath + `compinit` + zstyle + completion options | Must come before completion plugins |
| 30 | `30-prompt.zsh` | Starship init | Must come before autosuggestions |
| 40 | `40-tools.zsh.tmpl` | fzf, zoxide | Depends on the completion system being ready |
| 50 | `50-functions.zsh.tmpl` | `y` (yazi wrapper) | Standalone function |
| 60 | `60-plugins.zsh` | zsh-autosuggestions | Must hook an already configured PROMPT |
| 70 | `70-aliases.zsh.tmpl` | eza, bat aliases | Placed last so it does not affect earlier fragments |
| 80 | `80-dotgraft.zsh` | `dotg` alias + `dotgraft`/`dotg` completion | Before local configuration; completion depends on `compinit` |
| 90 | `create_90-local.zsh` | Your machine-specific configuration | Before the final plugins |
| 99 | `99-highlighting.zsh` | zsh-syntax-highlighting | **Must be last**; no `bindkey` after it |

Two hard ordering rules:

- `zsh-syntax-highlighting` colors input by hooking the ZLE widget for every key. If you `source` or `bindkey` after it, colors will not match. It is therefore fixed at `99-`.
- The `zsh-completions` directories must enter `fpath` before `compinit`. However, other tools in `~/.zshrc` (such as OpenSpec) may already have called `compinit` before the Dotgraft block, so `20-completion.zsh` runs `compinit` **again**. The cost is a few tens of milliseconds, and the new directories are actually scanned.

## How choices take effect

The chain has four steps:

```
.chezmoi.toml.tmpl          Ask three questions; write answers to ~/.config/dotgraft/chezmoi.toml
        ↓
.chezmoi/chezmoi.toml       tools / theme / glass in the [data] section
        ↓
{{ .tools }} in templates   Fragments and Ghostty configuration branch on these
        ↓
Empty render result         chezmoi deletes the target file
```

The last step is key. Optional fragments are wrapped entirely in `{{ if has "fzf" .tools }} ... {{ end }}`. When none are selected, they render to zero bytes, and chezmoi deletes empty files by default. Thus "unchecking" genuinely removes configuration rather than leaving a dead file behind. Note that this does **not** uninstall Homebrew packages that were already installed; it only stops installing them.

A combination of `.chezmoiignore` and `exact_` cannot do this: ignored entries are invisible to `exact_`, so files installed previously would remain on disk indefinitely. That is why options use templates rather than ignore rules.

Changing options:

```bash
dotgraft reconfigure      # chezmoi init → preview → apply → repair dependencies
```

`chezmoi init` re-renders `.chezmoi.toml.tmpl` and overwrites `~/.config/dotgraft/chezmoi.toml`.

`bootstrap.sh` and `dotgraft reconfigure` first ask for the theme and glass using numbered menus, then pass the answers to `chezmoi init` through `--promptChoice` / `--promptBool`, so you do not need to type full theme names. For automation, use:

```bash
DOTGRAFT_THEME="Dotgraft Paper" DOTGRAFT_GLASS=false dotgraft reconfigure
```

The theme list is kept in sync in three places: `.chezmoi.toml.tmpl`, `bootstrap.sh`, and `dot_local/bin/executable_dotgraft`. When adding a theme, update all three. For a custom theme, also place the theme file in `dot_config/ghostty/themes/` and update the `dotgraft` uninstall allowlist and `tests/smoke.sh`.

## Machine-specific configuration

`~/.config/zsh/conf.d/90-local.zsh` is managed with `create_`: it is created on the first apply and `dotgraft apply` never overwrites it afterward. It is a good place for:

- Paths that exist only on this machine
- Environment variables, aliases, and functions
- Lines that other installers tell you to "append to `~/.zshrc`"

It is protected outside of git: `create_` only checks whether the file exists, not what it contains. Whatever you write there will not be lost. However, **do not put secrets in it**: it is not committed, but it is not encrypted storage either.

## Source ownership

Dotgraft uses a separate source and config and does not touch the user's default chezmoi setup:

```
source:  ${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi-dotgraft
config:  ${XDG_CONFIG_HOME:-$HOME/.config}/dotgraft/chezmoi.toml
```

Every `dotgraft` command passes `--source/--config/--destination`, so it can coexist with an existing chezmoi configuration. The default `~/.local/share/chezmoi` and `~/.config/chezmoi` are not written to (the default source is only read to detect an older installation).

Safety boundaries:

- The repository root contains a `.dotgraft-source` marker; older sources are identified using `.chezmoi.toml.tmpl` + `dot_local/bin/executable_dotgraft` as a fallback
- `bootstrap.sh` checks the separate source before `chezmoi init`; if it already contains content and does not look like Dotgraft, bootstrap stops immediately
- If an older installation is detected in the default source, bootstrap asks you to uninstall or move it first, so two configurations do not take effect at the same time
- `dotgraft uninstall` only deletes target paths on its allowlist; if it finds managed files that are not Dotgraft's, it stops
- `chezmoi purge` runs only when the separate source is a clean Dotgraft clone; if there are uncommitted or unpushed changes, the source is kept

Running `chezmoi` directly uses the default source/config and will not see Dotgraft. When you need low-level commands, use `dotgraft chezmoi ...`.

## Why not ZDOTDIR

Setting `ZDOTDIR` to `~/.config/zsh` in `~/.zshenv` looks cleaner and is used by many setups. Dotgraft does not use it, for three reasons that have all been tested in practice:

1. **`~/.zprofile` stops working.** zsh's startup order is `/etc/zshenv` → `$ZDOTDIR/.zshenv` → `/etc/zprofile` → `$ZDOTDIR/.zprofile` → `/etc/zshrc` → `$ZDOTDIR/.zshrc`. Changing `ZDOTDIR` inside `.zshenv` makes all subsequent files load from the new directory, so `~/.zprofile` is skipped entirely. That file commonly contains initialization for `brew shellenv`, OrbStack, pipx, and similar tools.
2. **Third-party instructions all miss the mark.** Nearly every tool's installation docs say "add this line to `~/.zshrc`". After redirecting it, users follow those instructions but nothing reads the file. The failure is silent and extremely hard to diagnose.
3. **Ghostty also manipulates `ZDOTDIR`.** Its zsh shell integration points `ZDOTDIR` at its bundled resource directory, temporarily saves the user's original value in `GHOSTTY_ZSH_ZDOTDIR`, and restores it inside the integration script. Stacking our own redirect on top would mean three layers of indirection.

A marked block costs only three lines in `~/.zshrc` and avoids all three problems.

## Adding things

### Add a zsh fragment

Create a file in `dot_config/zsh/conf.d/` and use a two-digit numeric prefix to set its position. To make it optional:

1. Add a `.tmpl` suffix to the file name
2. Wrap the entire contents in `{{ if has "tool-name" .tools }} ... {{ end }}`
3. Add the name to the `promptMultichoice` option list in `.chezmoi.toml.tmpl`
4. If it is a **fixed** fragment (not optional), also update the `is_allowed_target` allowlist in `dot_local/bin/executable_dotgraft` and the matching allowlist in `tests/smoke.sh`; otherwise uninstall will treat it as a "non-Dotgraft file" and refuse to run, and CI will fail

### Add a new option question

Edit `.chezmoi.toml.tmpl`. The function signatures all follow `prompt <choices> [default]`:

```
promptBool        prompt [default]
promptChoice      prompt choices [default]
promptMultichoice prompt choices [default]
promptString      prompt [default]
```

`choices` must be `(list ...)`, and `default` can only be a single value. Remember to add new variables to the `[data]` section; otherwise templates cannot access them.

One pitfall: when nothing is selected, chezmoi may produce `[""]` instead of `[]`, and `[""]` is **truthy** in templates. The `$clean` block in this repository filters out empty strings; copy that pattern when adding a new option.

### Add a managed file

Name it according to its destination path and place it in the corresponding level. For example, for the target `~/.config/foo/bar`, place it at `dot_config/foo/bar`. After adding it, run:

```bash
dotgraft diff       # Confirm the destination is correct
```

If this is a new managed path, also add it to the `is_allowed_target` allowlist in `dot_local/bin/executable_dotgraft` and to the allowlist in `tests/smoke.sh`; otherwise uninstall will refuse to run because of a "non-Dotgraft managed file".

### Add a dependency

Put base dependencies in `Brewfile`; put optional dependencies behind options, with installation handled in `run_onchange_install-packages.sh.tmpl`.

That script embeds two hashes (the option list and `Brewfile`), so it reruns only when either changes; ordinary applies do not waste time.

However, `run_onchange` is **not a convergence mechanism**: if a package is removed manually, or a previous installation failed, it will not rerun as long as the script contents are unchanged. Therefore:

- When the script fails, it exits non-zero so chezmoi does not mark that version as complete; the next apply retries
- `dotgraft update` / `dotgraft reconfigure` run `dotgraft deps` when they finish
- `dotgraft deps` unconditionally re-renders and runs the same installation script, and is the entry point for repairing dependencies

## Verification checklist

After making changes, run the unit tests and smoke test first (requires `brew install bats-core`):

```bash
bats tests/unit
bash tests/smoke.sh
```

The smoke test copies the repository to a temporary directory, runs `chezmoi init` + `apply` with non-interactive answers, and then asserts the on-disk results. It does not touch your real home directory and does not actually install packages (`--exclude=scripts`).

It checks:

- In three scenarios (all selected / none selected / only one selected), optional fragments that should exist exist, and those that should disappear disappear
- The rendered optional zsh fragments and `.zshrc` pass `zsh -n`
- The theme and glass render according to the selections
- Exactly one dotgraft block appears in `.zshrc`, and existing content is not lost
- Reconfiguring (all selected → none selected) deletes optional fragments while keeping `90-local.zsh`
- A second `apply` changes nothing (idempotence)
- Repository files (README, Brewfile, tests, docs) do not enter `$HOME`, and all managed files are on the allowlist
- Uninstall refuses non-Dotgraft managed files and refuses an incomplete `.zshrc` block
- The successful uninstall path backs up `90-local.zsh`, removes the block, and restores the Ghostty override file
- `dotgraft deps` calls `brew bundle` and propagates installation failures as a non-zero exit
- The default `~/.local/share/chezmoi` / `~/.config/chezmoi` are not written to
- **Every theme name** listed in the options actually exists in Ghostty

The last item is automated: the script extracts the theme list from `.chezmoi.toml.tmpl` and validates each entry. Adding a wrong theme name (for example, `GitHub Light` instead of `GitHub Light Default`) fails immediately.

Additional individual checks:

```bash
shellcheck bootstrap.sh dot_local/bin/executable_dotgraft tests/smoke.sh
shfmt -d -i 2 -ci -sr bootstrap.sh dot_local/bin/executable_dotgraft tests/smoke.sh
bats tests/unit
python3 tests/theme-contract.py
zsh -n dot_config/zsh/init.zsh dot_config/zsh/conf.d/*.zsh
# Note: the glob above does not include *.zsh.tmpl; optional templates are rendered by tests/smoke.sh before zsh -n
dotgraft diff     # Confirm destinations after changes
```

### Templates cannot be validated directly

`config.tmpl` is a Go template, not configuration. Feeding it directly to `ghostty +validate-config` reports `unknown field`. Render it first:

```bash
ghostty +validate-config --config-file=<(dotgraft chezmoi execute-template < dot_config/ghostty/config.tmpl)
```

### CI

`.github/workflows/ci.yml` runs on every push and pull request:

| Job | Environment | Contents |
|---|---|---|
| `lint` | ubuntu | `shellcheck`, `shfmt -d`, `python3 tests/theme-contract.py`, `zsh -n` |
| `render` | macOS 14 / latest | Installs chezmoi, Ghostty, and bats; runs `bats tests/unit` + `tests/smoke.sh` |

`render` is the critical job: it follows the same path as a user installation. Template mistakes, option errors, and directories missing from `.chezmoiignore` all surface here. The Ghostty installation must not use `continue-on-error`, or theme and configuration validation would be skipped silently. The `shfmt` version in CI is pinned so the pipeline does not drift when `@latest` changes formatting rules.

### Release

`.github/workflows/release.yml` runs on tag pushes:

| Job | Environment | Contents |
|---|---|---|
| `validate` | macOS 14 / latest | Runs `bats tests/unit` and `tests/smoke.sh` |
| `release` | ubuntu | Validates `VERSION` and the theme contract, packages a tarball + `SHA256SUMS`, generates release notes from `CHANGELOG.md`, and creates a GitHub Release |

`release` depends on `validate`. If the macOS tests fail, no release is created.
