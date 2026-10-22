# ==============================================================================
# Dotgraft - zsh entry point
# ==============================================================================
# The dotgraft block at the end of ~/.zshrc sources this file:
#
#   # >>> dotgraft >>>
#   source "$HOME/.config/zsh/init.zsh"
#   # <<< dotgraft <<<
#
# Responsibility: set shared variables, then load conf.d/ fragments in filename order.
# Load order is lexicographic, controlled by two-digit prefixes; 99 comes last.
# ==============================================================================

DOTGRAFT_ZSH_DIR="${HOME}/.config/zsh"

# Put ~/.local/bin first in PATH. The dotgraft command itself lives here,
# Without this, `dotgraft update` / `dotgraft uninstall` cannot find the command.
# typeset -U deduplicates so repeated source calls do not pile up PATH entries.
typeset -U path
if [[ -d "$HOME/.local/bin" ]]; then
  path=("$HOME/.local/bin" $path)
fi

# Homebrew prefix. On macOS, Apple Silicon uses /opt/homebrew and Intel uses /usr/local,
# so do not hardcode it: prefer HOMEBREW_PREFIX from brew shellenv,
# otherwise ask brew, otherwise leave it empty (fragments then skip automatically).
_dotgraft_brew_prefix="${HOMEBREW_PREFIX:-}"
if [[ -z "$_dotgraft_brew_prefix" ]] && (( $+commands[brew] )); then
  _dotgraft_brew_prefix="${$(brew --prefix 2>/dev/null):-}"
fi

# (N) is the zsh nullglob qualifier: no error when the directory is missing or empty.
for _dotgraft_fragment in "$DOTGRAFT_ZSH_DIR"/conf.d/*.zsh(N); do
  source "$_dotgraft_fragment"
done

unset _dotgraft_fragment _dotgraft_brew_prefix
