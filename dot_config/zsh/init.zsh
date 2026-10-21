# ==============================================================================
# Dotgraft — zsh 入口
# ==============================================================================
# 这个文件由 ~/.zshrc 末尾的 dotgraft 区块 source 进来：
#
#   # >>> dotgraft >>>
#   source "$HOME/.config/zsh/init.zsh"
#   # <<< dotgraft <<<
#
# 职责：准备好公共变量，然后按文件名顺序加载 conf.d/ 下的片段。
# 加载顺序就是文件名的字典序，所以用两位数字前缀控制，99 是收尾。
# ==============================================================================

DOTGRAFT_ZSH_DIR="${HOME}/.config/zsh"

# ~/.local/bin 放到 PATH 前面。dotgraft 命令行工具自身就装在这里，
# 少了这一段 `dotgraft update` / `dotgraft uninstall` 会找不到命令。
# typeset -U 让数组去重，重复 source 也不会在 PATH 里堆一串。
typeset -U path
if [[ -d "$HOME/.local/bin" ]]; then
  path=("$HOME/.local/bin" $path)
fi

# Homebrew 前缀。macOS 上 Apple Silicon 是 /opt/homebrew，Intel 是 /usr/local，
# 所以不硬编码：优先用 brew shellenv 已经导出的 HOMEBREW_PREFIX，
# 没有才去问 brew，再没有就留空（下面所有片段都会因此自动跳过）。
_dotgraft_brew_prefix="${HOMEBREW_PREFIX:-}"
if [[ -z "$_dotgraft_brew_prefix" ]] && (( $+commands[brew] )); then
  _dotgraft_brew_prefix="${$(brew --prefix 2>/dev/null):-}"
fi

# (N) 是 zsh 的 nullglob 限定符：目录不存在或为空时不报错。
for _dotgraft_fragment in "$DOTGRAFT_ZSH_DIR"/conf.d/*.zsh(N); do
  source "$_dotgraft_fragment"
done

unset _dotgraft_fragment _dotgraft_brew_prefix
