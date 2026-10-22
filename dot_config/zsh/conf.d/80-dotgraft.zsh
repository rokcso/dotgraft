# ==============================================================================
# dotgraft short alias and completion
# ==============================================================================
# The real command remains dotgraft; dotg is only an interactive alias.
# If dotg already exists (command, alias, or function), keep the user version.
if ! whence -w dotg > /dev/null 2>&1; then
  alias dotg='dotgraft'
  _dotgraft_dotg_alias=1
fi

# Embedded copy of scripts/lib/language.sh so completions can choose their UI
# language at runtime. Compatible with POSIX sh and macOS Bash 3.2.

# Return en/zh for supported locale names; return nothing for unknown names.
dotgraft_locale_language() {
  case "$1" in
    zh | zh_* | zh-* | Chinese*) printf 'zh\n' ;;
    en | en_* | en-* | English*) printf 'en\n' ;;
  esac
}

# Explicit overrides win, followed by locale variables and macOS preferences.
# Do not change LC_ALL/LANG: external tools retain their own locale behavior.
dotgraft_detect_language() {
  if [ -n "${DOTGRAFT_LANG:-}" ]; then
    case "$DOTGRAFT_LANG" in
      en | zh) printf '%s\n' "$DOTGRAFT_LANG" ;;
      *) printf 'en\n' ;;
    esac
    return
  fi

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

# Resolve the completion language when this file is sourced.
_dotgraft_ui_lang="$(dotgraft_detect_language)"

# Subcommand completion: dotgraft <Tab> / dotg <Tab>
_dotgraft() {
  local -a commands themes

  if [[ "$_dotgraft_ui_lang" == "zh" ]]; then
    commands=(
      'status:显示当前配置、选配和文件差异'
      'diff:预览文件改动'
      'apply:预览并应用改动'
      'update:拉取上游、预览并应用'
      'deps:安装/修复 Homebrew 依赖'
      'theme:切换 Ghostty + Starship 主题'
      'reconfigure:重新选择组件'
      'edit:编辑受管文件的仓库副本'
      'cd:进入 Dotgraft 的 chezmoi source'
      'chezmoi:透传 chezmoi 子命令'
      'doctor:环境自检'
      'uninstall:卸载'
      'help:显示帮助'
    )
  else
    commands=(
      'status:Show current options, file differences, and version'
      'diff:Preview file changes'
      'apply:Preview and apply changes'
      'update:Pull upstream, then preview and apply'
      'deps:Install/repair Homebrew dependencies'
      'theme:Switch Ghostty + Starship theme'
      'reconfigure:Choose components again'
      'edit:Edit the repository copy of a managed file'
      'cd:Enter the Dotgraft chezmoi source'
      'chezmoi:Pass through chezmoi subcommands'
      'doctor:Check the environment'
      'uninstall:Uninstall'
      'help:Show help'
    )
  fi

  _arguments -C \
    '1:command:->command' \
    '*::arg:->args'

  case "$state" in
    command)
      _describe -t commands 'dotgraft command' commands
      ;;
    args)
      case "$words[2]" in
        edit)
          _files
          ;;
        theme)
          if [[ "$_dotgraft_ui_lang" == "zh" ]]; then
            themes=(
              'ink:Dotgraft Ink'
              'paper:Dotgraft Paper'
              'porcelain:Dotgraft Porcelain'
              'list:列出可用主题'
              'Dotgraft Ink:深色品牌主题'
              'Dotgraft Paper:浅色暖光品牌主题'
              'Dotgraft Porcelain:浅色冷光品牌主题'
              'Catppuccin Mocha:Catppuccin Mocha'
              'Catppuccin Latte:Catppuccin Latte'
              'Catppuccin Frappe:Catppuccin Frappe'
              'GitHub Dark:GitHub Dark'
              'GitHub Light Default:GitHub Light Default'
              'TokyoNight:TokyoNight'
            )
          else
            themes=(
              'ink:Dotgraft Ink'
              'paper:Dotgraft Paper'
              'porcelain:Dotgraft Porcelain'
              'list:List available themes'
              'Dotgraft Ink:Dark brand theme'
              'Dotgraft Paper:Warm light brand theme'
              'Dotgraft Porcelain:Cool light brand theme'
              'Catppuccin Mocha:Catppuccin Mocha'
              'Catppuccin Latte:Catppuccin Latte'
              'Catppuccin Frappe:Catppuccin Frappe'
              'GitHub Dark:GitHub Dark'
              'GitHub Light Default:GitHub Light Default'
              'TokyoNight:TokyoNight'
            )
          fi
          _describe -t themes 'theme' themes
          ;;
        chezmoi)
          # Let chezmoi handle its own completion; do not override it here
          ;;
      esac
      ;;
  esac
}

if (( $+functions[compdef] )); then
  compdef _dotgraft dotgraft
  if [[ -n "${_dotgraft_dotg_alias:-}" ]]; then
    compdef _dotgraft dotg
  fi
fi

unset _dotgraft_dotg_alias
