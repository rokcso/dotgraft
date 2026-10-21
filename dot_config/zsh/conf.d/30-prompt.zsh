# ==============================================================================
# 提示符 —— Starship
# ==============================================================================
# Rust 写的跨平台提示符，替代 oh-my-zsh 的主题系统，但快得多。
# 配置文件在 ~/.config/starship.toml（由 dotgraft 管理）。
#
# 必须在 compinit 之后、autosuggestions 之前加载：
#   - 之后：它会用补全系统提供的一些信息
#   - 之前：autosuggestions 要 hook 它设置好的 PROMPT
# ==============================================================================

if (( $+commands[starship] )); then
  # 显式指定路径。默认就是这里，但写死可以避免 XDG_CONFIG_HOME
  # 被别的东西改掉时，提示符悄悄回退成默认样式。
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
  eval "$(starship init zsh)"
fi
