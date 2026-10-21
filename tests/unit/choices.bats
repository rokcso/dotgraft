#!/usr/bin/env bats

load helpers

@test "choose_theme selects by number" {
  result="$(printf '2\n' | choose_theme "Catppuccin Mocha" 2> /dev/null)"
  [ "$result" = "Catppuccin Latte" ]
}

@test "choose_theme accepts default" {
  result="$(printf '\n' | choose_theme "GitHub Dark" 2> /dev/null)"
  [ "$result" = "GitHub Dark" ]
}

@test "choose_theme retries invalid input" {
  result="$(printf '9\n3\n' | choose_theme "Catppuccin Mocha" 2> /dev/null)"
  [ "$result" = "Catppuccin Frappe" ]
}

@test "choose_glass selects native" {
  result="$(printf '1\n' | choose_glass "false" 2> /dev/null)"
  [ "$result" = "true" ]
}

@test "choose_glass accepts default" {
  result="$(printf '\n' | choose_glass "false" 2> /dev/null)"
  [ "$result" = "false" ]
}

@test "theme_is_valid checks known themes" {
  run theme_is_valid "TokyoNight"
  [ "$status" -eq 0 ]
  run theme_is_valid "No Such Theme"
  [ "$status" -ne 0 ]
}

@test "init_with_choices passes choices to chezmoi" {
  DOTGRAFT_THEME="GitHub Dark"
  DOTGRAFT_GLASS="false"
  chezmoi_dg() { printf '%s\n' "$@"; }
  run init_with_choices
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ghostty 主题=GitHub Dark"* ]]
  [[ "$output" == *"=false"* ]]
}
