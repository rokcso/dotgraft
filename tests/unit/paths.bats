#!/usr/bin/env bats

load helpers

@test "allowlist accepts dotgraft targets" {
  run is_allowed_target "$HOME/.zshrc"
  [ "$status" -eq 0 ]
  run is_allowed_target "$HOME/.config/ghostty/config"
  [ "$status" -eq 0 ]
  run is_allowed_target "$HOME/.config/starship.toml"
  [ "$status" -eq 0 ]
  run is_allowed_target "$HOME/.local/bin/dotgraft"
  [ "$status" -eq 0 ]
  run is_allowed_target "$HOME/.config/zsh/init.zsh"
  [ "$status" -eq 0 ]
  run is_allowed_target "$HOME/.config/zsh/conf.d/40-tools.zsh"
  [ "$status" -eq 0 ]
  run is_allowed_target "$HOME/.config/zsh/conf.d/80-dotgraft.zsh"
  [ "$status" -eq 0 ]
  run is_allowed_target "$HOME/.config/ghostty/themes/Dotgraft Ink"
  [ "$status" -eq 0 ]
  run is_allowed_target "$HOME/.config/ghostty/themes/Dotgraft Paper"
  [ "$status" -eq 0 ]
}

@test "allowlist rejects other files" {
  run is_allowed_target "$HOME/.private"
  [ "$status" -ne 0 ]
  run is_allowed_target "$HOME/.config/zsh/conf.d/95-custom.zsh"
  [ "$status" -ne 0 ]
  run is_allowed_target "$HOME/.config/foo/bar"
  [ "$status" -ne 0 ]
}

@test "backup_file copies content and layout" {
  src="$HOME/.config/ghostty/config"
  mkdir -p "$(dirname "$src")"
  printf 'theme = Test\n' > "$src"
  run backup_file "$src" "$HOME/backup"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/backup/.config/ghostty/config")" = "theme = Test" ]
}

@test "backup_file supports paths with spaces" {
  src="$HOME/Library/Application Support/foo/config"
  mkdir -p "$(dirname "$src")"
  printf 'x\n' > "$src"
  run backup_file "$src" "$HOME/backup"
  [ "$status" -eq 0 ]
  [ -f "$HOME/backup/Library/Application Support/foo/config" ]
}

@test "backup_file records symlink target" {
  target="$HOME/real-zshrc"
  printf 'export KEEP=1\n' > "$target"
  ln -s "$target" "$HOME/.zshrc"
  run backup_file "$HOME/.zshrc" "$HOME/backup"
  [ "$status" -eq 0 ]
  [ -f "$HOME/backup/.zshrc" ]
  [ -f "$HOME/backup/.zshrc.symlink" ]
  [ "$(cat "$HOME/backup/.zshrc.symlink")" = "$target" ]
  [ -L "$HOME/.zshrc" ]
}

@test "hash_file returns empty for missing file" {
  run hash_file "$HOME/missing"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hash_file returns sha256" {
  printf 'x\n' > "$HOME/file"
  run hash_file "$HOME/file"
  [ "$status" -eq 0 ]
  [ "${#output}" -eq 64 ]
}

@test "can_purge_source accepts only clean dotgraft clone" {
  remote="$HOME/remote.git"
  src="$HOME/src"
  git init --bare --initial-branch=main "$remote" >/dev/null
  git clone "$remote" "$src" >/dev/null 2>&1
  git -C "$src" config user.email test@example.com
  git -C "$src" config user.name test
  printf 'x\n' > "$src/file"
  git -C "$src" add file
  git -C "$src" commit -qm init
  git -C "$src" push -qu origin main
  git -C "$src" remote set-url origin git@github.com:rokcso/dotgraft.git

  DOTGRAFT_SOURCE="$src"
  is_dotgraft_source() { return 0; }

  run can_purge_source
  [ "$status" -eq 0 ]

  touch "$src/untracked"
  run can_purge_source
  [ "$status" -ne 0 ]
  rm "$src/untracked"

  printf 'y\n' >> "$src/file"
  git -C "$src" commit -qam ahead
  run can_purge_source
  [ "$status" -ne 0 ]
  git -C "$src" reset --hard -q origin/main

  git -C "$src" remote set-url origin git@github.com:someone/other.git
  run can_purge_source
  [ "$status" -ne 0 ]
  git -C "$src" remote set-url origin git@github.com:rokcso/dotgraft.git

  git -C "$src" branch --unset-upstream
  run can_purge_source
  [ "$status" -ne 0 ]
}
