#!/usr/bin/env bats

load helpers

@test "missing zshrc is ok" {
  run zshrc_block_ok
  [ "$status" -eq 0 ]
}

@test "no markers is ok" {
  printf 'export KEEP=1\n' > "$HOME/.zshrc"
  run zshrc_block_ok
  [ "$status" -eq 0 ]
}

@test "complete block passes" {
  cat > "$HOME/.zshrc" <<'ZSH'
export BEFORE=1
# >>> dotgraft >>>
source "$HOME/.config/zsh/init.zsh"
# <<< dotgraft <<<
export AFTER=1
ZSH
  run zshrc_block_ok
  [ "$status" -eq 0 ]
}

@test "multiple complete blocks pass" {
  cat > "$HOME/.zshrc" <<'ZSH'
# >>> dotgraft >>>
# <<< dotgraft <<<
# >>> dotgraft >>>
# <<< dotgraft <<<
ZSH
  run zshrc_block_ok
  [ "$status" -eq 0 ]
}

@test "missing end marker is rejected" {
  printf '# >>> dotgraft >>>\nsource x\n' > "$HOME/.zshrc"
  run zshrc_block_ok
  [ "$status" -ne 0 ]
}

@test "end before start is rejected" {
  printf '# <<< dotgraft <<<\nexport KEEP=1\n# >>> dotgraft >>>\n' > "$HOME/.zshrc"
  run zshrc_block_ok
  [ "$status" -ne 0 ]
}

@test "marker with trailing space is rejected" {
  printf '# >>> dotgraft >>> \n# <<< dotgraft <<<\n' > "$HOME/.zshrc"
  run zshrc_block_ok
  [ "$status" -ne 0 ]
}

@test "CRLF markers are rejected" {
  printf '# >>> dotgraft >>>\r\n# <<< dotgraft <<<\r\n' > "$HOME/.zshrc"
  run zshrc_block_ok
  [ "$status" -ne 0 ]
}

@test "strip keeps surrounding content" {
  cat > "$HOME/.zshrc" <<'ZSH'
export BEFORE=1

# >>> dotgraft >>>
source "$HOME/.config/zsh/init.zsh"
# <<< dotgraft <<<

export AFTER=1
ZSH
  run strip_zshrc_block
  [ "$status" -eq 0 ]
  run cat "$HOME/.zshrc"
  [[ "$output" == *"export BEFORE=1"* ]]
  [[ "$output" == *"export AFTER=1"* ]]
  [[ "$output" != *"dotgraft"* ]]
}

@test "strip follows zshrc symlink and keeps it" {
  target="$HOME/.zshrc.real"
  cat > "$target" <<'ZSH'
export BEFORE=1
# >>> dotgraft >>>
source "$HOME/.config/zsh/init.zsh"
# <<< dotgraft <<<
export AFTER=1
ZSH
  ln -s ".zshrc.real" "$HOME/.zshrc"
  run strip_zshrc_block
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
  [ "$(readlink "$HOME/.zshrc")" = ".zshrc.real" ]
  run grep -q 'dotgraft' "$target"
  [ "$status" -ne 0 ]
  run grep -q 'export AFTER=1' "$target"
  [ "$status" -eq 0 ]
}

@test "strip removes multiple blocks" {
  cat > "$HOME/.zshrc" <<'ZSH'
export BEFORE=1
# >>> dotgraft >>>
# <<< dotgraft <<<
export MIDDLE=1
# >>> dotgraft >>>
# <<< dotgraft <<<
export AFTER=1
ZSH
  run strip_zshrc_block
  [ "$status" -eq 0 ]
  run cat "$HOME/.zshrc"
  [[ "$output" == *"MIDDLE=1"* ]]
  [[ "$output" != *"dotgraft"* ]]
}

@test "strip leaves file without markers unchanged" {
  printf 'export KEEP=1\n' > "$HOME/.zshrc"
  before="$(cat "$HOME/.zshrc")"
  run strip_zshrc_block
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.zshrc")" = "$before" ]
}
