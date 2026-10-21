# 所有 bats 测试共用的初始化。
# 只 source 不是执行：executable_dotgraft 底部有 BASH_SOURCE 守卫。

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
