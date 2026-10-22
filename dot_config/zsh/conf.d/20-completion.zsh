# ==============================================================================
# Tab completion
# ==============================================================================
# zsh-completions provides argument completion for many commands (brew install zsh-completions).
# Homebrew tools (gh, chezmoi, kubectl, etc.) also put completions in
# share/zsh/site-functions. Add both to fpath when they exist.
# typeset -U prevents duplicate paths when sourced repeatedly.
typeset -U fpath
for _dotgraft_more_fpath in \
  "$_dotgraft_brew_prefix/share/zsh-completions" \
  "$_dotgraft_brew_prefix/share/zsh/site-functions"; do
  if [[ -n "$_dotgraft_brew_prefix" ]] && [[ -d "$_dotgraft_more_fpath" ]]; then
    fpath=("$_dotgraft_more_fpath" $fpath)
  fi
done
unset _dotgraft_more_fpath

# compinit must run after fpath changes, or new directories are not scanned.
#
# Running compinit again here is intentional: other tools in ~/.zshrc (such as OpenSpec)
# may have called compinit before this block and do not know we add fpath later.
# The duplicate call costs tens of milliseconds and makes zsh-completions effective.
#
# -u: Homebrew directories are mostly root-owned, and zsh rejects such "insecure" dirs,
#     This flag makes compinit accept them anyway.
autoload -Uz compinit && compinit -u

# Show a selection menu; press Tab repeatedly and move through candidates with arrows
zstyle ':completion:*' menu select
# Case-insensitive completion: `cd down` also completes `Downloads`
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Move the cursor to the end after completion; allow completion mid-word.
setopt ALWAYS_TO_END COMPLETE_IN_WORD
