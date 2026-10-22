# ==============================================================================
# Syntax highlighting - must be the last fragment loaded
# ==============================================================================
# The 99 prefix keeps it after every fragment, including your 90-local.zsh.
# It colors by hooking every key via ZLE widgets; sourcing anything later
# or bind keys afterwards, colors will no longer line up.
#
# Install: brew install zsh-syntax-highlighting
# ==============================================================================

if [[ -n "$_dotgraft_brew_prefix" ]] &&
   [[ -r "$_dotgraft_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$_dotgraft_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
