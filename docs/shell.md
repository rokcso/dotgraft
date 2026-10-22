# Shell layer

English · [简体中文](zh-CN/shell.md)

The zsh portion is bootstrapped by a small block in `~/.zshrc`:

```zsh
# >>> dotgraft >>>
# Managed by dotgraft. Do not edit this block manually.
# Put machine-local configuration in ~/.config/zsh/conf.d/90-local.zsh
source "$HOME/.config/zsh/init.zsh"
# <<< dotgraft <<<
```

`init.zsh` does three things: adds `~/.local/bin` to `PATH`, prepares Homebrew prefix variables, and sources `conf.d/*.zsh` in order.

For the fragment list and load order, see [Configuration architecture](configuration.md#fragment-load-order).

## Starship (prompt)

`~/.config/starship.toml` is Starship's official `catppuccin-powerline` preset, with two Dotgraft palettes and theme integration added.

The key change that is retained:

```
[line_break]
disabled = false
```

The default is `true`, which means the prompt occupies its own line and input is squeezed onto it. Setting it to `false` puts the rainbow bar on the first line and the input symbol on the second, so there is always a full line available while typing.

Color gradient: `red → peach → yellow → green → sapphire → lavender`; each colored block corresponds to a category of information: user → path → Git → language version.

`starship.toml.tmpl` automatically selects a palette based on the Ghostty theme:

| Ghostty theme | Starship palette |
|---|---|
| `Dotgraft Ink` | `dotgraft_ink` |
| `Dotgraft Paper` | `dotgraft_paper` |
| `Dotgraft Porcelain` | `dotgraft_porcelain` |
| `Catppuccin Latte` / `GitHub Light Default` | `catppuccin_latte` |
| `Catppuccin Frappe` | `catppuccin_frappe` |
| Other dark themes | `catppuccin_mocha` |

You can also change `palette` manually; the available Dotgraft palettes are `dotgraft_ink` / `dotgraft_paper` / `dotgraft_porcelain`.

### Syncing the upstream preset

The preset has many implicit internal dependencies. **Do not edit it line by line.** To upgrade, replace the whole file:

```bash
starship preset catppuccin-powerline -o /tmp/new.toml
# Do not overwrite directly: compare first, then merge upstream changes into dot_config/starship.toml.tmpl
```

When merging, retain:

- `line_break.disabled = false`
- The conditional palette block at the top
- `palettes.dotgraft_ink` / `palettes.dotgraft_paper` / `palettes.dotgraft_porcelain`

The file header records the upstream version it is based on (currently 1.27.0). Recording the version makes it clear where to jump from during the next sync.

## Three plugins

Three independent plugins, with no framework. Only the needed features are loaded, reducing startup overhead.

### zsh-autosuggestions

While typing, a history suggestion appears in gray after the cursor. Press `→` or `Ctrl+F` to accept it.

Dotgraft changes the accept key to `Ctrl+F`: the default `→` is captured by `forward-char` in the middle of a line, which is awkward; `Ctrl+F` was originally `forward-char` too, so overriding it has the lowest cost.

### zsh-syntax-highlighting

Colors input as you type: existing commands → green, nonexistent commands → red, strings highlighted, existing paths → underlined. You do not have to wait for Enter to discover `command not found`.

It works by hooking the ZLE widget for every key press and **must load last**, so it is always `99-highlighting.zsh`. Being after `90-local.zsh` means anything you add locally is also highlighted.

### zsh-completions

Extends argument completion for hundreds of commands (git, docker, brew, kubectl, and others).

`20-completion.zsh` adds two directories to `fpath`:

```text
$HOMEBREW_PREFIX/share/zsh-completions
$HOMEBREW_PREFIX/share/zsh/site-functions
```

The first comes from `zsh-completions`; the second is where Homebrew tools (`gh`, `chezmoi`, `kubectl`, etc.) install their completions. After adding them, it runs `compinit`.

Note that this runs `compinit` **again**, even if it was already called. The reason is that other tools in `~/.zshrc` (such as OpenSpec) may have called it before this block and did not know we would add `fpath` later. The cost of a repeated call is a few tens of milliseconds, and the new directories are actually scanned.

Two zstyle lines work with it: `menu select` lets you move up and down through Tab candidates, and `matcher-list` makes completion case-insensitive (`cd down` can complete to `Downloads`).

Two completion options are also enabled:

- `ALWAYS_TO_END`: move the cursor to the end of the word after completing
- `COMPLETE_IN_WORD`: allow completion to start in the middle of a word

The `-u` in `compinit -u` is necessary: most Homebrew directories are owned by root, and zsh refuses to use such "insecure" directories by default.

## Five CLI tools

All are optional. If not selected, they are not installed and their fragments are not deployed.

| Tool | Usage | Notes |
|---|---|---|
| **fzf** | `Ctrl+R` searches history, `Ctrl+T` searches files, `**<Tab>` completes | For example, `cd **<Tab>` shows a directory list, `kill **<Tab>` lists processes |
| **zoxide** | `z foo` jumps to frequently used directories, `zi foo` selects interactively | Ranks by visit frequency and recency, with automatic data decay |
| **eza** | `ls` / `ll` / `lt` | Icons, colors, directories first |
| **bat** | `cat` | Syntax highlighting |
| **yazi** | `y` | File manager that changes directory automatically on exit |

fzf initialization has one detail:

```zsh
_dotgraft_fzf_init="$(fzf --zsh 2>/dev/null)"
[[ -n "$_dotgraft_fzf_init" ]] && eval "$_dotgraft_fzf_init"
```

`--zsh` is the new interface added after fzf 0.48; older versions error immediately. The script captures the output once and evals only if it is non-empty, avoiding dumping errors into the current shell on unsupported versions.

### One caveat for zoxide

**Do not write `alias cd="z"`.** zoxide hooks `cd` to record visits. Once `cd` is replaced with `z`, it can no longer record new directories and the database stops updating. Just use `z` directly.

## Aliases and functions

### eza

```
ls  →  eza --icons --group-directories-first
ll  →  eza -l --icons --sort=name
lt  →  eza --tree --icons --level=2
```

### bat

```
cat  →  bat --paging=never --style=plain
```

`--paging=never` makes behavior identical to `cat`, with no getting stuck in a pager; `--style=plain` removes line numbers and the grid, leaving only syntax highlighting.

**Side effect**: from then on, `cat` is no longer `cat`. Scripts that need to read raw content must use `command cat`. The `y` function in `50-functions.zsh` is written this way—it needs to read a temporary file, and `bat`'s paging and formatting would cause problems.

### The y function

```zsh
function y() {
  local tmp cwd
  tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp" 2>/dev/null)" &&
     [[ -n "$cwd" ]] && [[ "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
```

yazi supports `--cwd-file`, writing the final directory to the specified file on exit; the function reads it back and runs `cd`. This way, after `y` exits, the shell stays in the directory you navigated to, saving a `cd` step.

Two deliberate choices: `command cat` bypasses the `cat → bat` alias above, and `builtin cd` bypasses any `cd` alias or function someone might define.

## History

```
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY      # Record start time; view with history -i
setopt SHARE_HISTORY         # Share across windows and write immediately
setopt HIST_IGNORE_ALL_DUPS  # Keep only the latest duplicate command
setopt HIST_IGNORE_SPACE     # Do not record commands prefixed with a space
```

`HISTFILE` is set explicitly so history stays in the same place even if `ZDOTDIR` changes in the future. macOS's `/etc/zshrc` defaults to `${ZDOTDIR:-$HOME}/.zsh_history`, which is the same path.

`HIST_IGNORE_SPACE` handles sensitive content pasted temporarily: prefix a command with a space and it will not enter history.

## Short alias and completion

The official command is `dotgraft`. `80-dotgraft.zsh` adds the alias when `dotg` is **not already taken**:

```zsh
alias dotg='dotgraft'
```

It checks with `whence -w dotg`, which examines commands, aliases, and functions together; if the user already has `dotg`, it is not overridden.

Completion is registered for both names:

```bash
dotgraft <Tab>
dotg <Tab>
```

Subcommands include `status` / `diff` / `apply` / `update` / `deps` / `theme` / `backup` / `restore` / `reconfigure` / `edit` / `cd` / `chezmoi` / `doctor` / `version` / `uninstall` / `help`. `edit` continues to use zsh's file completion for target paths.

If completion does not work, first confirm that `20-completion.zsh` has already run `compinit`:

```bash
whence -w _dotgraft
print ${_comps[dotgraft]}
print ${_comps[dotg]}
```

Both are expected to point to `_dotgraft`.

## Shortcuts

| Shortcut | Effect |
|---|---|
| `Ctrl+F` | Accept an autosuggestions suggestion |
| `Ctrl+R` | Fuzzy-search history with fzf |
| `Ctrl+T` | Fuzzy-search files with fzf |
| `Tab` | Complete; press repeatedly to move through the candidate list |
| `**<Tab>` | Trigger fzf completion |

For Ghostty's own window operations, see the [Ghostty documentation](ghostty.md#shortcuts).

## Adding your own configuration

Put it in `~/.config/zsh/conf.d/90-local.zsh`. It is managed with `create_`: it is created only when missing, and later `dotgraft apply` runs do not overwrite it.

Do not write anything inside the dotgraft block in `~/.zshrc`—`dotgraft update` rewrites that block.

To maintain something in the repository long-term, add a fragment as described in [Configuration architecture](configuration.md#adding-things).
