# ==============================================================================
# Plugin - zsh-autosuggestions
# ==============================================================================
# Show a gray suggestion after the cursor based on history before you finish typing.
# Accept the whole command with the right arrow or Ctrl+F.
#
# Load order matters: this runs after 30-prompt (Starship).
# autosuggestions hooks PRE_CMD set by the prompt; PROMPT must exist first.
#
# Install: brew install zsh-autosuggestions
# ==============================================================================

if [[ -n "$_dotgraft_brew_prefix" ]] &&
   [[ -r "$_dotgraft_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$_dotgraft_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

  # Accept suggestions with Ctrl+F.
  # The default is the right arrow, but forward-char steals it mid-line, which is awkward;
  # Ctrl+F was also forward-char; overriding it costs the least and feels smoother.
  bindkey '^F' autosuggest-accept
fi
