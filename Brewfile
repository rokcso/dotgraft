# ==============================================================================
# Dotgraft - base dependency manifest (always installed)
# ==============================================================================
# Install: brew bundle --file=Brewfile
# Usually run automatically by chezmoi apply via run_onchange_install-packages.sh.
#
# Only include things the configuration cannot run without.
#
# Optional components are selected at install time instead (change with dotgraft reconfigure):
#   fzf / zoxide / eza / bat / yazi
#
# Fonts are not here either: the font cask tries to "adopt" an existing ttf,
# and anyone who installed the font manually will likely hit "existing Font is different".
# Instead run_onchange_install-packages.sh detects the font and installs only when missing.
# ==============================================================================

# ------------------------------------------------------------------------------
# Terminal
# ------------------------------------------------------------------------------
cask "ghostty"

# ------------------------------------------------------------------------------
# Prompt
# ------------------------------------------------------------------------------
brew "starship"

# ------------------------------------------------------------------------------
# zsh plugins
# ------------------------------------------------------------------------------
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"
brew "zsh-completions"
