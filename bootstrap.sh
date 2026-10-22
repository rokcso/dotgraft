#!/usr/bin/env bash
# ==============================================================================
# Dotgraft — installation entry point
# ==============================================================================
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/rokcso/dotgraft/main/bootstrap.sh)
#
# This script only handles the "from zero to runnable" part: prepare chezmoi,
# ask a few optional questions, show the changes, and apply them. Day-to-day
# operations after installation go through the dotgraft command:
#   dotgraft update        Update to the latest version
#   dotgraft deps          Repair dependencies
#   dotgraft reconfigure   Change selections
#   dotgraft uninstall     Uninstall
#
# For testing, the repository URL can be overridden:
#   DOTGRAFT_REPO=/path/to/local/repo bash bootstrap.sh
# ==============================================================================

set -euo pipefail

# ==============================================================================
# Language detection (embedded from scripts/lib/language.sh for standalone use)
# ==============================================================================
# BEGIN DOTGRAFT_LANGUAGE_EMBEDDED
# Return en/zh for supported locale names; return nothing for unknown names.
dotgraft_locale_language() {
  case "$1" in
    zh | zh_* | zh-* | Chinese*) printf 'zh\n' ;;
    en | en_* | en-* | English*) printf 'en\n' ;;
  esac
}

# Explicit overrides win, then the language saved by `dotgraft lang`, then
# locale variables and macOS preferences. Do not change LC_ALL/LANG:
# external tools retain their own locale behavior.
dotgraft_detect_language() {
  if [ -n "${DOTGRAFT_LANG:-}" ]; then
    case "$DOTGRAFT_LANG" in
      en | zh) printf '%s\n' "$DOTGRAFT_LANG" ;;
      *) printf 'en\n' ;;
    esac
    return
  fi

  # `dotgraft lang` persists a preference. The environment variable above
  # still wins; an unreadable or unsupported value falls through to detection.
  dotgraft_saved="${XDG_CONFIG_HOME:-$HOME/.config}/dotgraft/language"
  dotgraft_saved_language=""
  if [ -r "$dotgraft_saved" ]; then
    read -r dotgraft_saved_language < "$dotgraft_saved" || true
  fi
  case "$dotgraft_saved_language" in
    en | zh)
      printf '%s\n' "$dotgraft_saved_language"
      return
      ;;
  esac

  # The first populated locale is authoritative. An unsupported locale falls
  # back to English rather than a lower-priority, potentially stale variable.
  dotgraft_locale="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
  case "$dotgraft_locale" in
    '' | C | POSIX | C.UTF-8 | C.utf8) ;;
    *)
      dotgraft_language="$(dotgraft_locale_language "$dotgraft_locale")"
      printf '%s\n' "${dotgraft_language:-en}"
      return
      ;;
  esac

  # macOS shells may expose no meaningful locale. Read only the first preferred
  # UI language; a secondary Chinese language must not override the primary one.
  if command -v defaults > /dev/null 2>&1; then
    dotgraft_preferred="$({ defaults read -g AppleLanguages 2> /dev/null || true; } | awk '
      /\(/ { next }
      { gsub(/[",[:space:]]/, ""); if (length && $0 != ")") { print; exit } }
    ')"
    dotgraft_language="$(dotgraft_locale_language "$dotgraft_preferred")"
    printf '%s\n' "${dotgraft_language:-en}"
  else
    printf 'en\n'
  fi
}
# END DOTGRAFT_LANGUAGE_EMBEDDED

# Resolve once and export so every descendant uses the same language.
DOTGRAFT_LANG="$(dotgraft_detect_language)"
export DOTGRAFT_LANG

# Print the selected language's text. The first two arguments are the English
# and Chinese format strings; remaining arguments are passed safely to printf.
dg_text() {
  local en="$1" zh="$2" fmt
  shift 2
  if [[ "$DOTGRAFT_LANG" == "zh" ]]; then
    fmt="$zh"
  else
    fmt="$en"
  fi
  # shellcheck disable=SC2059 # Format strings are trusted literals in this script.
  printf "$fmt" "$@"
}

REPO_URL="${DOTGRAFT_REPO:-https://github.com/rokcso/dotgraft.git}"
DOTGRAFT_REF="${DOTGRAFT_REF:-}"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$HOME/.config-backup/$STAMP"
DOTGRAFT_SOURCE="${DOTGRAFT_SOURCE:-${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi-dotgraft}"
DOTGRAFT_CONFIG="${DOTGRAFT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/dotgraft/chezmoi.toml}"
LEGACY_SOURCE="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi"
DOTGRAFT_THEMES=(
  "Dotgraft Ink"
  "Dotgraft Paper"
  "Dotgraft Porcelain"
  "Catppuccin Mocha"
  "Catppuccin Latte"
  "Catppuccin Frappe"
  "GitHub Dark"
  "GitHub Light Default"
  "TokyoNight"
)
GHOSTTY_OVERRIDE="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
GHOSTTY_OVERRIDE_MOVED=0
GHOSTTY_OVERRIDE_SAVED=''

ASSUME_YES=0
if [[ "${DOTGRAFT_YES:-0}" == "1" || "${DOTGRAFT_YES:-0}" == "true" || "${DOTGRAFT_YES:-0}" == "yes" ]]; then
  ASSUME_YES=1
fi
TOOLS_SET=0
if [[ -n "${DOTGRAFT_TOOLS+x}" ]]; then
  TOOLS_SET=1
fi
DOTGRAFT_TOOLS_ALLOWED=(fzf zoxide eza bat yazi)

step() { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '    ! %s\n' "$*" >&2; }
fail() {
  printf '\n%s: %s\n' "$(dg_text 'Error' '错误')" "$*" >&2
  exit 1
}

confirm() {
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    note "$(dg_text '%s [auto-confirmed]' '%s [自动确认]' "$1")"
    return 0
  fi
  local reply
  printf '    %s [y/N] ' "$1"
  read -r reply
  [[ "$reply" == [yY] ]]
}

usage() {
  dg_text 'Usage: bootstrap.sh [options]

  -y, --yes              Non-interactive install; unspecified options use defaults
      --tools=a,b        Enable CLI tools (fzf,zoxide,eza,bat,yazi)
      --theme=NAME       Ghostty theme
      --glass=true|false Enable native glass
  -h, --help             Show this help

You can also use environment variables: DOTGRAFT_YES, DOTGRAFT_TOOLS, DOTGRAFT_THEME, DOTGRAFT_GLASS, DOTGRAFT_REF.
Use DOTGRAFT_REF to install a release tag, for example DOTGRAFT_REF=v0.1.0.
' '用法: bootstrap.sh [选项]

  -y, --yes              非交互安装；未指定的选项使用默认值
      --tools=a,b        启用的 CLI 工具（fzf,zoxide,eza,bat,yazi）
      --theme=名称       Ghostty 主题
      --glass=true|false 是否启用原生毛玻璃
  -h, --help             显示帮助

也可以使用环境变量：DOTGRAFT_YES、DOTGRAFT_TOOLS、DOTGRAFT_THEME、DOTGRAFT_GLASS、DOTGRAFT_REF。
DOTGRAFT_REF 用于安装某个 release tag，例如 DOTGRAFT_REF=v0.1.0。
'
}

normalize_tools() {
  local raw="$1" tool out=''
  raw="${raw//,/ }"
  raw="${raw//\// }"
  for tool in $raw; do
    if [[ " ${DOTGRAFT_TOOLS_ALLOWED[*]} " != *" $tool "* ]]; then
      fail "$(dg_text 'Unknown CLI tool: %s (available: %s)' '未知 CLI 工具：%s（可选：%s）' \
        "$tool" "${DOTGRAFT_TOOLS_ALLOWED[*]}")"
    fi
    out="$out $tool"
  done
  printf '%s\n' "${out# }"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y | --yes)
      ASSUME_YES=1
      shift
      ;;
    --tools=*)
      DOTGRAFT_TOOLS="${1#*=}"
      TOOLS_SET=1
      shift
      ;;
    --theme=*)
      DOTGRAFT_THEME="${1#*=}"
      shift
      ;;
    --glass=*)
      DOTGRAFT_GLASS="${1#*=}"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) fail "$(dg_text 'Unknown argument: %s. Run bootstrap.sh --help for usage.' '未知参数：%s。运行 bootstrap.sh --help 查看用法。' "$1")" ;;
  esac
done

# All chezmoi calls go through here so they use the same paths as the installed
# dotgraft command.
chezmoi_dg() {
  chezmoi \
    --source "$DOTGRAFT_SOURCE" \
    --config "$DOTGRAFT_CONFIG" \
    --destination "$HOME" \
    "$@"
}

default_glass() {
  local major
  major="$(sw_vers -productVersion 2> /dev/null | cut -d. -f1)"
  [[ "$major" =~ ^[0-9]+$ ]] || major=0
  if ((major >= 26)); then
    printf 'true\n'
  else
    printf 'false\n'
  fi
}

choose_theme() {
  local default="${1:-Catppuccin Mocha}" i choice marker
  dg_text '\nChoose a Ghostty theme:\n' '\n选择 Ghostty 主题：\n' >&2
  for i in "${!DOTGRAFT_THEMES[@]}"; do
    marker=""
    if [[ "${DOTGRAFT_THEMES[$i]}" == "$default" ]]; then
      marker="$(dg_text ' (default)' '（默认）')"
    fi
    printf '  %d) %s%s\n' "$((i + 1))" "${DOTGRAFT_THEMES[$i]}" "$marker" >&2
  done

  while true; do
    dg_text 'Enter a number [1-%d] (press Enter for default): ' '输入编号 [1-%d]（回车使用默认）: ' \
      "${#DOTGRAFT_THEMES[@]}" >&2
    if ! read -r choice; then
      printf '%s\n' "$default"
      return 0
    fi
    if [[ -z "$choice" ]]; then
      printf '%s\n' "$default"
      return 0
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((10#$choice >= 1 && 10#$choice <= ${#DOTGRAFT_THEMES[@]})); then
      printf '%s\n' "${DOTGRAFT_THEMES[10#$choice - 1]}"
      return 0
    fi
    dg_text '  Invalid number, please try again.\n' '  无效编号，请重试。\n' >&2
  done
}

choose_glass() {
  local default="${1:-false}" choice marker
  dg_text '\nGlass effect:\n' '\n毛玻璃效果：\n' >&2
  marker=""
  if [[ "$default" == "true" ]]; then
    marker="$(dg_text ' (default)' '（默认）')"
  fi
  printf '  1) %s%s\n' "$(dg_text 'Native glass (macOS 26+)' '原生毛玻璃（macOS 26+）')" "$marker" >&2
  marker=""
  if [[ "$default" == "false" ]]; then
    marker="$(dg_text ' (default)' '（默认）')"
  fi
  printf '  2) %s%s\n' "$(dg_text 'Numeric blur' '数字模糊')" "$marker" >&2

  while true; do
    dg_text 'Enter a number [1-2] (press Enter for default): ' '输入编号 [1-2]（回车使用默认）: ' >&2
    if ! read -r choice; then
      printf '%s\n' "$default"
      return 0
    fi
    case "$choice" in
      1)
        printf 'true\n'
        return 0
        ;;
      2)
        printf 'false\n'
        return 0
        ;;
      "")
        printf '%s\n' "$default"
        return 0
        ;;
      *) dg_text '  Invalid number, please try again.\n' '  无效编号，请重试。\n' >&2 ;;
    esac
  done
}

theme_is_valid() {
  local theme="$1" candidate
  for candidate in "${DOTGRAFT_THEMES[@]}"; do
    if [[ "$candidate" == "$theme" ]]; then
      return 0
    fi
  done
  return 1
}

# If installation fails midway or receives Ctrl-C, put back any Ghostty override
# file that was already moved aside. After a successful apply,
# GHOSTTY_OVERRIDE_MOVED is manually reset to 0.
cleanup() {
  local status=$?
  if [[ "$GHOSTTY_OVERRIDE_MOVED" -eq 1 ]]; then
    if [[ -n "$GHOSTTY_OVERRIDE_SAVED" && -e "$GHOSTTY_OVERRIDE_SAVED" ]]; then
      mv "$GHOSTTY_OVERRIDE_SAVED" "$GHOSTTY_OVERRIDE" 2> /dev/null || true
      dg_text '\n    Installation incomplete; restored the Ghostty override configuration.\n' \
        '\n    安装未完成，已恢复 Ghostty 覆盖配置。\n' >&2
    fi
  fi
  return "$status"
}
trap cleanup EXIT

# ==============================================================================
# Environment checks
# ==============================================================================
step "$(dg_text 'Checking environment' '检查环境')"

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "$(dg_text 'Only macOS is supported at the moment. Ghostty installation, font paths, and several configuration options differ on Linux, and this repository has no Linux environment for verification, so support has not been claimed. If your machine runs Linux, feel free to open an issue with your distribution and what went wrong: https://github.com/rokcso/dotgraft/issues' '目前只支持 macOS。Ghostty 的安装方式、字体路径和几个配置项在 Linux 上都不同，而这个仓库没有 Linux 环境可验证，所以没有贸然声明支持。如果你的机器是 Linux，欢迎到 issues 说明发行版和遇到的问题：https://github.com/rokcso/dotgraft/issues')"
fi
note "$(dg_text 'macOS ✓' 'macOS ✓')"

command -v brew > /dev/null 2>&1 || fail "$(dg_text 'Homebrew not found. Please install it first: https://brew.sh' '未找到 Homebrew。请先安装：https://brew.sh')"
note "Homebrew ✓ ($(brew --prefix))"

command -v git > /dev/null 2>&1 || fail "$(dg_text 'git not found. Please run: xcode-select --install' '未找到 git。请先运行：xcode-select --install')"
note "git ✓"

# ==============================================================================
# Explain what will happen
# ==============================================================================
dg_text '
    This installation does four things:

      1. Install chezmoi (if it is not already installed)
      2. Ask three optional questions: which CLI tools to enable, the Ghostty
         theme, and whether to use native glass
      3. Show the diff for every file that will change and ask for confirmation
      4. Back up existing configuration, apply the files, and install Homebrew
         dependencies

    Locations that will be touched:
      ~/.zshrc                          Append a small marked block at the end
      ~/.config/zsh/                    zsh configuration
      ~/.config/ghostty/config          Terminal configuration
      ~/.config/starship.toml           Prompt configuration
      ~/.local/bin/dotgraft             The dotgraft command
      ~/.config/dotgraft/chezmoi.toml   Dotgraft-specific selection answers
      ~/.local/share/chezmoi-dotgraft   Dotgraft-specific chezmoi source directory
      ~/.config-backup/<timestamp>/     Backup of existing configuration

    It does not touch ~/.zprofile or ~/.zshenv, does not use sudo, and does not
    modify /etc.
' '
    这次安装会做四件事：

      1. 安装 chezmoi（如果还没有）
      2. 问三个选配问题：要哪些 CLI 工具、Ghostty 主题、是否用原生毛玻璃
      3. 展示所有将被改动的文件 diff，让你确认
      4. 备份已有配置，然后落盘，并安装 Homebrew 依赖

    会碰到的位置：
      ~/.zshrc                          末尾插入一小段标记区块
      ~/.config/zsh/                    zsh 配置
      ~/.config/ghostty/config          终端配置
      ~/.config/starship.toml           提示符配置
      ~/.local/bin/dotgraft             dotgraft 命令
      ~/.config/dotgraft/chezmoi.toml   Dotgraft 独立的选配答案
      ~/.local/share/chezmoi-dotgraft   Dotgraft 独立的 chezmoi 源目录
      ~/.config-backup/<时间戳>/        已有配置的备份

    不会碰 ~/.zprofile 和 ~/.zshenv，不用 sudo，不修改 /etc。
'

confirm "$(dg_text 'Continue?' '继续？')" || {
  dg_text '\nCancelled.\n' '\n已取消。\n'
  exit 0
}

# ==============================================================================
# chezmoi
# ==============================================================================
step "$(dg_text 'Preparing chezmoi' '准备 chezmoi')"

if command -v chezmoi > /dev/null 2>&1; then
  note "$(dg_text 'Installed (%s)' '已安装（%s）' "$(chezmoi --version | head -1)")"
else
  note "$(dg_text 'Not installed; installing via Homebrew' '未安装，通过 Homebrew 安装')"
  brew install chezmoi
fi

source_looks_like_dotgraft() {
  local src="$1"
  [[ -f "$src/.dotgraft-source" ]] && return 0
  [[ -f "$src/.chezmoi.toml.tmpl" ]] &&
    [[ -f "$src/dot_local/bin/executable_dotgraft" ]] &&
    grep -q 'Dotgraft' "$src/.chezmoi.toml.tmpl"
}

# Dotgraft uses a separate source. chezmoi init does not clone when the source
# already has content, so first make sure the target directory is empty or is
# already a Dotgraft repository.
ensure_source_available() {
  if [[ -d "$DOTGRAFT_SOURCE" && -n "$(ls -A "$DOTGRAFT_SOURCE" 2> /dev/null || true)" ]]; then
    if source_looks_like_dotgraft "$DOTGRAFT_SOURCE"; then
      note "$(dg_text 'Existing Dotgraft source detected; continuing with update: %s' '检测到已有 Dotgraft 源目录，继续更新：%s' "$DOTGRAFT_SOURCE")"
    else
      local manual_backup
      manual_backup="$DOTGRAFT_SOURCE.before-dotgraft.$(date +%Y%m%d_%H%M%S)"
      fail "$(dg_text 'The Dotgraft source directory already exists but does not look like Dotgraft: %s

      chezmoi init does not clone a new repository when the source directory
      already has content; it would apply the dotfiles inside directly. To
      avoid accidental changes, the installer has stopped.

      Back up and move that directory first:
        mv "%s" "%s"
      Then run bootstrap.sh again.' 'Dotgraft 源目录已存在，且不像 Dotgraft：%s

      chezmoi init 在源目录已有内容时不会 clone 新仓库，继续执行会
      直接应用里面的 dotfiles。为避免误操作，已停止。

      请先备份并移开该目录：
        mv "%s" "%s"
      然后重新运行 bootstrap.sh。' "$DOTGRAFT_SOURCE" "$DOTGRAFT_SOURCE" "$manual_backup")"
    fi
  fi
}

# Older versions installed dotgraft into the default source. After switching to
# a separate source, detect the old layout and ask the user to uninstall or move
# it first so two configurations do not take effect at the same time.
check_legacy_source() {
  if [[ -d "$DOTGRAFT_SOURCE" && -n "$(ls -A "$DOTGRAFT_SOURCE" 2> /dev/null || true)" ]]; then
    return 0
  fi
  [[ -d "$LEGACY_SOURCE" && -n "$(ls -A "$LEGACY_SOURCE" 2> /dev/null || true)" ]] || return 0
  source_looks_like_dotgraft "$LEGACY_SOURCE" || return 0
  local manual_backup
  manual_backup="$LEGACY_SOURCE.before-dotgraft.$(date +%Y%m%d_%H%M%S)"
  fail "$(dg_text 'Legacy Dotgraft installation detected in the default source: %s

      The new version uses a separate source: %s.
      Uninstall it with the old command first:
        dotgraft uninstall
      Or move the old source manually:
        mv "%s" "%s"
      Then run bootstrap.sh again.' '检测到旧版 Dotgraft 安装在默认 source：%s

      新版使用独立 source：%s。
      请先用旧版命令卸载：
        dotgraft uninstall
      或手动移开旧 source：
        mv "%s" "%s"
      然后重新运行 bootstrap.sh。' "$LEGACY_SOURCE" "$DOTGRAFT_SOURCE" "$LEGACY_SOURCE" "$manual_backup")"
}

verify_dotgraft_source() {
  source_looks_like_dotgraft "$DOTGRAFT_SOURCE" ||
    fail "$(dg_text 'The source directory still does not look like Dotgraft after chezmoi init: %s. Stopped; check the repository URL and network.' 'chezmoi init 之后源目录仍不像 Dotgraft：%s。已停止，请检查仓库地址和网络。' "$DOTGRAFT_SOURCE")"
}

# chezmoi init re-renders the configuration template and overwrites an existing
# chezmoi.toml. It is not in the managed list, so back it up separately before
# init.
backup_chezmoi_config() {
  local file="$DOTGRAFT_CONFIG"
  [[ -f "$file" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  cp -p "$file" "$BACKUP_DIR/chezmoi.toml.before-dotgraft" 2> /dev/null ||
    fail "$(dg_text 'Could not back up the existing Dotgraft chezmoi.toml; stopped: %s' '无法备份已有 Dotgraft chezmoi.toml，已停止：%s' "$file")"
  note "$(dg_text 'Backed up existing chezmoi.toml to %s' '已备份已有 chezmoi.toml 到 %s' "$BACKUP_DIR/chezmoi.toml.before-dotgraft")"
}

# Back up a single target; symlinks additionally get a .symlink record whose
# content is the path they point to. This prevents uninstall/restore from
# mistaking a user's original link for a regular file.
backup_existing_file() {
  local src="$1" dest_root="$2" rel target
  [[ -e "$src" || -L "$src" ]] || return 0
  rel="${src#"${HOME%/}"/}"
  mkdir -p "$dest_root/$(dirname "$rel")"

  if [[ -L "$src" ]]; then
    target="$(readlink "$src")" || fail "$(dg_text 'Could not read symlink; stopped: %s' '无法读取软链接，已停止：%s' "$src")"
    printf '%s\n' "$target" > "$dest_root/$rel.symlink" ||
      fail "$(dg_text 'Could not back up symlink information; stopped: %s' '无法备份软链接信息，已停止：%s' "$src")"
    if [[ -f "$src" ]]; then
      cp -Lp "$src" "$dest_root/$rel" 2> /dev/null ||
        cp -L "$src" "$dest_root/$rel" ||
        fail "$(dg_text 'Could not back up symlink contents; stopped: %s' '无法备份软链接内容，已停止：%s' "$src")"
    fi
    return 0
  fi

  cp -p "$src" "$dest_root/$rel" 2> /dev/null ||
    fail "$(dg_text 'Could not back up existing file; stopped: %s' '无法备份已有文件，已停止：%s' "$src")"
}

# Back up every target that already exists before installation. chezmoi does
# not prompt for unmanaged targets and would overwrite them directly; without
# this step, the user's existing Ghostty / Starship / zsh configuration would be
# silently replaced.
backup_existing_targets() {
  local f count=0 managed_files
  mkdir -p "$BACKUP_DIR/pre-existing"
  if ! managed_files="$(chezmoi_dg managed --include=files --path-style=absolute 2> /dev/null)"; then
    fail "$(dg_text 'Could not read the chezmoi managed file list; stopped. Run chezmoi doctor first.' '无法读取 chezmoi 受管文件列表，已停止。请先运行 chezmoi doctor。')"
  fi
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    [[ -e "$f" || -L "$f" ]] || continue
    backup_existing_file "$f" "$BACKUP_DIR/pre-existing"
    count=$((count + 1))
  done <<< "$managed_files"

  if [[ (-f "$HOME/.zshrc" || -L "$HOME/.zshrc") && ! -f "$BACKUP_DIR/pre-existing/.zshrc" ]]; then
    backup_existing_file "$HOME/.zshrc" "$BACKUP_DIR/pre-existing"
    count=$((count + 1))
  fi

  if [[ "$count" -gt 0 ]]; then
    note "$(dg_text 'Backed up %s existing target files to %s' '已备份 %s 个已存在的目标文件到 %s' "$count" "$BACKUP_DIR/pre-existing")"
  fi
}

# ==============================================================================
# Optional questions + fetch configuration
# ==============================================================================
ensure_source_available
check_legacy_source
backup_chezmoi_config

step "$(dg_text 'Choosing components to enable' '选择要启用的组件')"
if [[ "$ASSUME_YES" -eq 1 ]]; then
  note "$(dg_text 'Non-interactive mode: unspecified options use defaults' '非交互模式：未指定的选项使用默认值')"
else
  note "$(dg_text '(Theme/glass use numbered menus; CLI tools use chezmoi checkboxes)' '（主题/毛玻璃用编号菜单；CLI 工具由 chezmoi 勾选）')"
  printf '\n'
fi

theme_choice="${DOTGRAFT_THEME:-}"
if [[ -z "$theme_choice" ]]; then
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    theme_choice="Dotgraft Ink"
  else
    theme_choice="$(choose_theme "Dotgraft Ink")"
  fi
fi
theme_is_valid "$theme_choice" || fail "$(dg_text 'Invalid theme: %s (available: %s)' '无效主题：%s（可选：%s）' "$theme_choice" "${DOTGRAFT_THEMES[*]}")"

glass_choice="${DOTGRAFT_GLASS:-}"
if [[ -z "$glass_choice" ]]; then
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    glass_choice="$(default_glass)"
  else
    glass_choice="$(choose_glass "$(default_glass)")"
  fi
fi
case "$glass_choice" in
  true | false) ;;
  *) fail "$(dg_text 'Invalid DOTGRAFT_GLASS: %s (must be true or false)' '无效 DOTGRAFT_GLASS：%s（应为 true 或 false）' "$glass_choice")" ;;
esac

tools_choice=''
if [[ "$TOOLS_SET" -eq 1 ]]; then
  tools_choice="$(normalize_tools "${DOTGRAFT_TOOLS:-}")"
elif [[ "$ASSUME_YES" -eq 1 ]]; then
  tools_choice="${DOTGRAFT_TOOLS_ALLOWED[*]}"
fi

# chezmoi accepts overrides for prompts that the checked-out template does not
# use. Supply both languages so current templates (DOTGRAFT_BILINGUAL_PROMPTS_V1)
# get labels matching the selected language, while older release tags that only
# know the Chinese labels still receive the right answers.
init_args=(
  --promptChoice "Ghostty theme=$theme_choice"
  --promptChoice "Ghostty 主题=$theme_choice"
  --promptBool "Enable native macOS glass? (Requires macOS 26 or later)=$glass_choice"
  --promptBool "启用 macOS 原生毛玻璃效果？（需要 macOS 26 及以上）=$glass_choice"
)
if [[ "$TOOLS_SET" -eq 1 || "$ASSUME_YES" -eq 1 ]]; then
  tools_slash="$(printf '%s' "$tools_choice" | tr ' ' '/')"
  init_args+=(
    --promptMultichoice "Which CLI tools should be enabled? (Space to select, Enter to confirm)=$tools_slash"
    --promptMultichoice "要启用哪些 CLI 工具？（空格勾选，回车确认）=$tools_slash"
  )
fi
if [[ -n "$DOTGRAFT_REF" ]]; then
  init_args+=(--tag "$DOTGRAFT_REF")
fi

mkdir -p "$(dirname "$DOTGRAFT_SOURCE")" "$(dirname "$DOTGRAFT_CONFIG")"
chezmoi_dg init "$REPO_URL" "${init_args[@]}"
verify_dotgraft_source

if [[ -f "$DOTGRAFT_SOURCE/VERSION" ]]; then
  note "$(dg_text 'Version: %s' '版本: %s' "$(tr -d '\n' < "$DOTGRAFT_SOURCE/VERSION")")"
fi

# ==============================================================================
# Preview
# ==============================================================================
step "$(dg_text 'Changes to be applied' '将要发生的改动')"

status_output="$(chezmoi_dg status --exclude=scripts 2> /dev/null || true)"
if [[ -z "$status_output" ]]; then
  note "$(dg_text 'No file changes to apply; already up to date.' '没有待应用的文件改动，已经是最新的。')"
else
  change_count="$(printf '%s\n' "$status_output" | grep -c . || true)"
  note "$(dg_text '%s change(s) will be made:' '将改动 %s 项：' "$change_count")"
  printf '%s\n' "$status_output" | sed 's/^/      /'
  printf '\n'
  note "$(dg_text 'Most first-time installations create new files; run dotgraft diff --full after installation to see the full diff.' '首次安装大多是新建文件，完整 diff 可在安装后用 dotgraft diff --full 查看。')"
  confirm "$(dg_text 'Apply these changes?' '应用以上改动？')" || {
    dg_text '\nCancelled; no configuration was applied.\n' '\n已取消，未应用配置。\n'
    exit 0
  }
fi

# ==============================================================================
# Back up existing configuration
# ==============================================================================
step "$(dg_text 'Backing up existing configuration' '备份已有配置')"
backup_existing_targets

# ==============================================================================
# Ghostty override file on macOS
# ==============================================================================
# Ghostty reads ~/.config/ghostty/config first, then the copy in Application
# Support, which overrides the former key by key. If it is not handled, the
# theme and font would be silently overridden. Move it only after the user
# confirms apply, so cancelling installation does not already change the system.
if [[ -s "$GHOSTTY_OVERRIDE" ]]; then
  step "$(dg_text 'Found a Ghostty override configuration on macOS' '发现 macOS 上的 Ghostty 覆盖配置')"
  note "$GHOSTTY_OVERRIDE"
  printf '\n'
  sed 's/^/      | /' "$GHOSTTY_OVERRIDE"
  printf '\n'
  note "$(dg_text 'This file loads after the Dotgraft configuration and overrides the theme and font settings one by one.' '这份文件会在 dotgraft 的配置之后加载，逐条覆盖主题和字体。')"
  if confirm "$(dg_text 'Back up and move it aside?' '备份并移开它？')"; then
    mkdir -p "$BACKUP_DIR"
    cp -p "$GHOSTTY_OVERRIDE" "$BACKUP_DIR/ghostty-config.macos-override" ||
      fail "$(dg_text 'Could not back up %s' '无法备份 %s' "$GHOSTTY_OVERRIDE")"

    if [[ -e "$GHOSTTY_OVERRIDE.before-dotgraft" ]]; then
      # An earlier original configuration already exists; do not overwrite it.
      # Put the current file in this run's backup instead.
      GHOSTTY_OVERRIDE_SAVED="$BACKUP_DIR/ghostty-config.replaced"
      mv "$GHOSTTY_OVERRIDE" "$GHOSTTY_OVERRIDE_SAVED"
      note "$(dg_text 'Keeping the existing .before-dotgraft; current file backed up to %s' '保留已有 .before-dotgraft，当前文件备份到 %s' "$GHOSTTY_OVERRIDE_SAVED")"
    else
      GHOSTTY_OVERRIDE_SAVED="$GHOSTTY_OVERRIDE.before-dotgraft"
      mv "$GHOSTTY_OVERRIDE" "$GHOSTTY_OVERRIDE_SAVED"
      note "$(dg_text 'Backed up to %s' '已备份到 %s' "$BACKUP_DIR/ghostty-config.macos-override")"
    fi
    GHOSTTY_OVERRIDE_MOVED=1
  else
    note "$(dg_text 'Left in place. Note: the Ghostty theme and font may not look the way you selected.' '保留不动。注意：Ghostty 的主题和字体可能不会变成你选的样子。')"
  fi
fi

# ==============================================================================
# Apply
# ==============================================================================
step "$(dg_text 'Applying configuration' '应用配置')"
chezmoi_dg apply
# After a successful apply, a later failure (for example in the checks below)
# must not restore the override file.
GHOSTTY_OVERRIDE_MOVED=0

# ==============================================================================
# Verify aliases and completion in the new shell
# ==============================================================================
step "$(dg_text 'Verifying shell configuration' '验证 Shell 配置')"
if HOME="$HOME" zsh -i -c '[[ "$(whence -w dotg 2>/dev/null)" == "dotg: alias" && "${_comps[dotg]:-}" == "_dotgraft" ]]' > /dev/null 2>&1; then
  note "$(dg_text 'dotg alias and completion verified' 'dotg 别名与补全已验证')"
else
  warn "$(dg_text 'The dotg alias/completion did not pass verification; run exec zsh and then dotg status to check' 'dotg 别名/补全未通过验证；请执行 exec zsh 后运行 dotg status 检查')"
fi

# ==============================================================================
# Done
# ==============================================================================
# shellcheck disable=SC2016 # Backticks in the completion instructions are literal.
dg_text '
==> Done

    The current window will not load the new configuration automatically. Next steps:

      1. Run `exec zsh` (or open a new terminal)
      2. Verify: `dotg status`, `dotg <Tab>`
      3. If Ghostty is running, press Cmd+Shift+, to reload the configuration

    Common commands afterward:

      dotgraft status        Show the current state
      dotgraft diff          Preview after editing configuration
      dotgraft update        Pull upstream updates
      dotgraft deps          Repair dependencies that were not installed
      dotgraft reconfigure   Change selections (asks the same questions again)
      dotgraft uninstall     Uninstall

' '
==> 完成

    当前窗口不会自动加载新配置。下一步：

      1. 执行 `exec zsh`（或开一个新终端）
      2. 验证：`dotg status`、`dotg <Tab>`
      3. 如果 Ghostty 正在运行，按 Cmd+Shift+, 重新加载配置

    之后常用的命令：

      dotgraft status        看看现在是什么状态
      dotgraft diff          改完配置先预览
      dotgraft update        拉取上游更新
      dotgraft deps          修复没装上的依赖
      dotgraft reconfigure   改选配（重新问那几个问题）
      dotgraft uninstall     卸载

'

dg_text '    Dotgraft uses a separate source/config:\n' '    Dotgraft 使用独立 source/config：\n'
printf '      source: %s\n' "$DOTGRAFT_SOURCE"
printf '      config: %s\n' "$DOTGRAFT_CONFIG"
dg_text '    Your own ~/.local/share/chezmoi and ~/.config/chezmoi will not be modified.\n\n' '    你自己的 ~/.local/share/chezmoi 和 ~/.config/chezmoi 不会被改动。\n\n'

if [[ -d "$BACKUP_DIR" ]]; then
  dg_text '    Backup from this run: %s\n\n' '    本次备份：%s\n\n' "$BACKUP_DIR"
fi
