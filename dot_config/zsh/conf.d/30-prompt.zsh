# ==============================================================================
# Prompt - Starship
# ==============================================================================
# A cross-platform prompt written in Rust; much faster than oh-my-zsh themes.
# The config lives at ~/.config/starship.toml (managed by dotgraft).
#
# Must load after compinit and before autosuggestions:
#   - After: it consumes information provided by the completion system
#   - Before: autosuggestions must hook the PROMPT it sets
# ==============================================================================

if (( $+commands[starship] )); then
  # Set the path explicitly. This is the default, but pinning it avoids a silent
  # is changed elsewhere, the prompt does not silently fall back to its default style.
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
  eval "$(starship init zsh)"
fi
