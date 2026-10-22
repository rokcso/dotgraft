# ==============================================================================
# dotgraft 短别名与补全
# ==============================================================================
# 正式命令仍然是 dotgraft；dotg 只是交互式别名。
# 如果系统里已经有 dotg（命令、别名或函数），保留用户的，不覆盖。
if ! whence -w dotg > /dev/null 2>&1; then
  alias dotg='dotgraft'
  _dotgraft_dotg_alias=1
fi

# 子命令补全：dotgraft <Tab> / dotg <Tab>
_dotgraft() {
  local -a commands
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
          local -a themes
          themes=(
            'ink:Dotgraft Ink'
            'paper:Dotgraft Paper'
            'list:列出可用主题'
            'Dotgraft Ink:深色品牌主题'
            'Dotgraft Paper:浅色品牌主题'
            'Catppuccin Mocha:Catppuccin Mocha'
            'Catppuccin Latte:Catppuccin Latte'
            'Catppuccin Frappe:Catppuccin Frappe'
            'GitHub Dark:GitHub Dark'
            'GitHub Light Default:GitHub Light Default'
            'TokyoNight:TokyoNight'
          )
          _describe -t themes 'theme' themes
          ;;
        chezmoi)
          # 交给 chezmoi 自己的补全更合适；这里不强行接管
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
