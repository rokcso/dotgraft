# ==============================================================================
# Tab 补全
# ==============================================================================
# zsh-completions 提供大量命令的参数补全（brew install zsh-completions）。
# Homebrew 安装的工具（gh、chezmoi、kubectl 等）还会把补全放到
# share/zsh/site-functions。两个目录都存在时都加入 fpath。
# typeset -U 避免重复 source 时堆积重复路径。
typeset -U fpath
for _dotgraft_more_fpath in \
  "$_dotgraft_brew_prefix/share/zsh-completions" \
  "$_dotgraft_brew_prefix/share/zsh/site-functions"; do
  if [[ -n "$_dotgraft_brew_prefix" ]] && [[ -d "$_dotgraft_more_fpath" ]]; then
    fpath=("$_dotgraft_more_fpath" $fpath)
  fi
done
unset _dotgraft_more_fpath

# compinit 必须在 fpath 改完之后跑，否则新加的目录不会被扫描。
#
# 这里会再跑一次 compinit 是故意的：~/.zshrc 里可能有别的工具（例如 OpenSpec）
# 在本区块之前就已经调用过 compinit，而它们不知道我们后面又加了 fpath。
# 重复调用的代价是几十毫秒，换来的是 zsh-completions 真的生效。
#
# -u：Homebrew 的目录大多是 root 所有，zsh 默认会拒绝使用这种"不安全"目录，
#     这个参数让 compinit 照常接受。
autoload -Uz compinit && compinit -u

# Tab 补全时显示可选菜单，连续按 Tab 可以用方向键在候选里移动
zstyle ':completion:*' menu select
# 补全大小写不敏感：输入 `cd down` 也能补出 `Downloads`
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# 补全完成后把光标移到词尾；允许在单词中间开始补全。
setopt ALWAYS_TO_END COMPLETE_IN_WORD
