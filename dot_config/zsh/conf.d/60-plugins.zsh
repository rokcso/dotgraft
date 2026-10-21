# ==============================================================================
# 插件 —— zsh-autosuggestions
# ==============================================================================
# 根据历史记录，在你还没打完的时候于光标后用灰色显示一条建议。
# 按 → 或 Ctrl+F 接受整条命令。
#
# 加载位置很关键：排在 30-prompt（Starship）之后。
# autosuggestions 要 hook 提示符设置好的 PRE_CMD，先有 PROMPT 才有它挂载的地方。
#
# 安装：brew install zsh-autosuggestions
# ==============================================================================

if [[ -n "$_dotgraft_brew_prefix" ]] &&
   [[ -r "$_dotgraft_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$_dotgraft_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

  # Ctrl+F 接受建议。
  # 默认是 → 键，但 → 在行中会被 forward-char 抢走，用起来很别扭；
  # Ctrl+F 原本也是 forward-char，覆盖它代价最小，且手感更顺。
  bindkey '^F' autosuggest-accept
fi
