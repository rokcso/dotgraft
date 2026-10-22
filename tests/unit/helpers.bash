# Shared initialization for all bats tests.
# Source only, do not execute: executable_dotgraft has a BASH_SOURCE guard.

setup() {
  ORIG_HOME="$HOME"
  HOME="$(mktemp -d)"
  export HOME
  export DOTGRAFT_SOURCE="$HOME/.local/share/chezmoi-dotgraft"
  export DOTGRAFT_CONFIG="$HOME/.config/dotgraft/chezmoi.toml"
  source "$BATS_TEST_DIRNAME/../../dot_local/bin/executable_dotgraft"
}

teardown() {
  rm -rf "$HOME"
  HOME="$ORIG_HOME"
  export HOME
}
