# ==============================================================================
# 语法高亮 —— 必须是最后一个被加载的片段
# ==============================================================================
# 文件名用 99 前缀，保证排在所有片段（含你自己的 90-local.zsh）之后。
# 它靠 hook 每个键位的 ZLE widget 来着色，如果之后再 source 别的东西、
# 或者之后再 bindkey，颜色就会对不上。
#
# 安装：brew install zsh-syntax-highlighting
# ==============================================================================

if [[ -n "$_dotgraft_brew_prefix" ]] &&
   [[ -r "$_dotgraft_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$_dotgraft_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
