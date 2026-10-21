# ==============================================================================
# 历史记录
# ==============================================================================
# 显式写 HISTFILE，是为了即使将来 ZDOTDIR 有变化，历史也不会换地方。
# /etc/zshrc 里默认是 ${ZDOTDIR:-$HOME}/.zsh_history，也就是同一个路径。
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

# 记录每条命令的开始时间，`history -i` 可以按时间查看
setopt EXTENDED_HISTORY
# 多个终端共享历史，并且立即写盘，避免两个窗口互相覆盖
setopt SHARE_HISTORY
# 重复命令只保留最新一条
setopt HIST_IGNORE_ALL_DUPS
# 命令前加一个空格就不写进历史，用来处理临时粘贴的敏感内容
setopt HIST_IGNORE_SPACE

# 可选：历史展开（!!、!$）先回显再执行。更安全，但会让 !! 多按一次回车。
# setopt HIST_VERIFY
