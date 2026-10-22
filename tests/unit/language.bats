#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../scripts/lib/language.sh"
  unset DOTGRAFT_LANG LC_ALL LC_MESSAGES LANG
  defaults() { printf '(\n    "en-US",\n    "zh-Hans-CN"\n)\n'; }
}

@test "explicit language overrides locale" {
  DOTGRAFT_LANG=en LANG=zh_CN.UTF-8 run dotgraft_detect_language
  [ "$output" = en ]
  DOTGRAFT_LANG=zh LANG=en_US.UTF-8 run dotgraft_detect_language
  [ "$output" = zh ]
}

@test "Chinese locale selects Chinese" {
  LANG=zh_CN.UTF-8 run dotgraft_detect_language
  [ "$output" = zh ]
}

@test "locale priority is LC_ALL then LC_MESSAGES then LANG" {
  LC_ALL=en_US.UTF-8 LC_MESSAGES=zh_CN.UTF-8 LANG=zh_CN.UTF-8 run dotgraft_detect_language
  [ "$output" = en ]
  LC_MESSAGES=zh_CN.UTF-8 LANG=en_US.UTF-8 run dotgraft_detect_language
  [ "$output" = zh ]
}

@test "unknown locale defaults to English" {
  LANG=fr_FR.UTF-8 run dotgraft_detect_language
  [ "$output" = en ]
}

@test "missing locale uses first macOS preferred language" {
  defaults() { printf '(\n    "zh-Hans-CN",\n    "en-US"\n)\n'; }
  run dotgraft_detect_language
  [ "$output" = zh ]
}

@test "secondary Chinese preference does not override English" {
  run dotgraft_detect_language
  [ "$output" = en ]
}

@test "unavailable macOS preferences default to English" {
  defaults() { return 1; }
  run dotgraft_detect_language
  [ "$output" = en ]
}

@test "invalid explicit language defaults to English" {
  DOTGRAFT_LANG=unknown LANG=zh_CN.UTF-8 run dotgraft_detect_language
  [ "$output" = en ]
}
