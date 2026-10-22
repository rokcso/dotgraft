#!/usr/bin/env bats

# Bilingual prompt integration: bootstrap <-> .chezmoi.toml.tmpl.
# These tests avoid the network by initializing chezmoi from a temporary copy of
# this repository. Both English and Chinese prompt overrides are always passed;
# chezmoi must ignore the labels that the checked-out template does not use.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  BOOTSTRAP="$REPO_ROOT/bootstrap.sh"
  TMP="$(mktemp -d)"
  SRC="$TMP/src"
  mkdir -p "$SRC"
  (cd "$REPO_ROOT" && tar --exclude=.git --exclude=refs -cf - .) | (cd "$SRC" && tar -xf -)
}

teardown() {
  rm -rf "$TMP"
}

assert_contains() {
  local file="$1" text="$2"
  if ! grep -qF -- "$text" "$file"; then
    printf 'Expected %s to contain: %s\n' "$file" "$text" >&2
    if [[ -f "$file" ]]; then
      printf '%s\n' '--- actual content ---' >&2
      cat "$file" >&2
    fi
    return 1
  fi
}

init_template() {
  local home="$1" language="$2"
  shift 2
  mkdir -p "$home"
  env HOME="$home" DOTGRAFT_LANG="$language" LC_ALL= LC_MESSAGES= LANG= \
    chezmoi \
    --source "$SRC" \
    --destination "$home" \
    --config "$home/chezmoi.toml" \
    --persistent-state "$home/state.boltdb" \
    init "$@"
}

# Both language variants are supplied with different values. The selected
# template label decides which set wins.
both_prompt_args=(
  --promptMultichoice "Which CLI tools should be enabled? (Space to select, Enter to confirm)=eza"
  --promptMultichoice "要启用哪些 CLI 工具？（空格勾选，回车确认）=fzf"
  --promptChoice "Ghostty theme=TokyoNight"
  --promptChoice "Ghostty 主题=Catppuccin Mocha"
  --promptBool "Enable native macOS glass? (Requires macOS 26 or later)=true"
  --promptBool "启用 macOS 原生毛玻璃效果？（需要 macOS 26 及以上）=false"
)

@test "English template uses English prompt values" {
  local home="$TMP/en"
  run init_template "$home" en "${both_prompt_args[@]}"
  [ "$status" -eq 0 ]
  assert_contains "$home/chezmoi.toml" 'tools = ["eza"]'
  assert_contains "$home/chezmoi.toml" 'theme = "TokyoNight"'
  assert_contains "$home/chezmoi.toml" 'glass = true'
}

@test "Chinese template uses Chinese prompt values" {
  local home="$TMP/zh"
  run init_template "$home" zh "${both_prompt_args[@]}"
  [ "$status" -eq 0 ]
  assert_contains "$home/chezmoi.toml" 'tools = ["fzf"]'
  assert_contains "$home/chezmoi.toml" 'theme = "Catppuccin Mocha"'
  assert_contains "$home/chezmoi.toml" 'glass = false'
}

@test "both-language overrides keep old Chinese-only templates working" {
  local home="$TMP/old"
  cat > "$SRC/.chezmoi.toml.tmpl" <<'OLD_TEMPLATE'
{{- $tools := promptMultichoice
      "要启用哪些 CLI 工具？（空格勾选，回车确认）"
      (list "fzf" "zoxide" "eza" "bat" "yazi")
      (list "fzf" "zoxide" "eza" "bat" "yazi") -}}
{{- $clean := list -}}
{{- range $tools -}}
{{-   if ne . "" -}}
{{-     $clean = append $clean . -}}
{{-   end -}}
{{- end -}}
{{- $theme := promptChoice
      "Ghostty 主题"
      (list "Dotgraft Ink" "Dotgraft Paper" "Dotgraft Porcelain" "Catppuccin Mocha" "GitHub Dark" "TokyoNight")
      "Dotgraft Ink" -}}
{{- $macos_major := index (splitList "." (output "sw_vers" "-productVersion")) 0 | atoi -}}
{{- $glass := promptBool
      "启用 macOS 原生毛玻璃效果？（需要 macOS 26 及以上）"
      (ge $macos_major 26) -}}
[data]
  tools = {{ $clean | toJson }}
  theme = {{ $theme | quote }}
  glass = {{ $glass }}
OLD_TEMPLATE

  # Simulate installing an older release tag with a new bootstrap. English is
  # selected for UI text, but the old template only knows the Chinese prompts.
  run init_template "$home" en "${both_prompt_args[@]}"
  [ "$status" -eq 0 ]
  assert_contains "$home/chezmoi.toml" 'tools = ["fzf"]'
  assert_contains "$home/chezmoi.toml" 'theme = "Catppuccin Mocha"'
  assert_contains "$home/chezmoi.toml" 'glass = false'
}

@test "bootstrap supplies both English and Chinese prompt labels" {
  local label
  # shellcheck disable=SC2016 # These are literal source strings, not expansions.
  for label in \
    'Ghostty theme=$theme_choice' \
    'Ghostty 主题=$theme_choice' \
    'Enable native macOS glass? (Requires macOS 26 or later)=$glass_choice' \
    '启用 macOS 原生毛玻璃效果？（需要 macOS 26 及以上）=$glass_choice' \
    'Which CLI tools should be enabled? (Space to select, Enter to confirm)=$tools_slash' \
    '要启用哪些 CLI 工具？（空格勾选，回车确认）=$tools_slash'; do
    assert_contains "$BOOTSTRAP" "$label"
  done
}

@test "bootstrap help works in English" {
  run env DOTGRAFT_LANG=en LC_ALL= LC_MESSAGES= LANG= bash "$BOOTSTRAP" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: bootstrap.sh [options]"* ]]
  [[ "$output" == *"--theme=NAME"* ]]
  [[ "$output" != *"用法: bootstrap.sh [选项]"* ]]
}

@test "bootstrap help works in Chinese" {
  run env DOTGRAFT_LANG=zh LC_ALL= LC_MESSAGES= LANG= bash "$BOOTSTRAP" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"用法: bootstrap.sh [选项]"* ]]
  [[ "$output" == *"--theme=名称"* ]]
  [[ "$output" != *"Usage: bootstrap.sh [options]"* ]]
}

@test "embedded detector survives failing defaults under strict shell flags" {
  local detector
  detector="$(sed -n '/^# BEGIN DOTGRAFT_LANGUAGE_EMBEDDED$/,/^# END DOTGRAFT_LANGUAGE_EMBEDDED$/p' "$BOOTSTRAP" | sed '1d;$d')"
  [ -n "$detector" ]

  # XDG_CONFIG_HOME is isolated: a saved `dotgraft lang` preference must not
  # decide this test, which is about the failing-defaults fallback.
  # shellcheck disable=SC2016 # DETECTOR is evaluated inside the child shell.
  run env DETECTOR="$detector" XDG_CONFIG_HOME="$TMP/xdg" bash -c '
    set -euo pipefail
    defaults() { return 1; }
    eval "$DETECTOR"
    unset DOTGRAFT_LANG LC_ALL LC_MESSAGES LANG
    language="$(dotgraft_detect_language)"
    printf "%s\n" "$language"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "en" ]
}
