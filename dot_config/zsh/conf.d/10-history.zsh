# ==============================================================================
# History
# ==============================================================================
# Set HISTFILE explicitly so history stays put even if ZDOTDIR changes later.
# The /etc/zshrc default is ${ZDOTDIR:-$HOME}/.zsh_history, the same path.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

# Record each command start time so `history -i` can show timestamps
setopt EXTENDED_HISTORY
# Share history across terminals and write immediately so windows do not overwrite each other
setopt SHARE_HISTORY
# Keep only the newest copy of repeated commands
setopt HIST_IGNORE_ALL_DUPS
# Prefixing a command with a space keeps it out of history, useful for pasted secrets
setopt HIST_IGNORE_SPACE

# Optional: echo history expansion (!!, !$) before running it. Safer but adds a keypress.
# setopt HIST_VERIFY
