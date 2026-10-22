#!/usr/bin/env bats

load helpers

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/release-notes.py"

@test "release notes extract a version section" {
  run python3 "$SCRIPT" v0.1.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"## 0.1.0"* ]]
  [[ "$output" == *"首个可持续发布版本。"* ]]
}

@test "release notes reject an unknown version" {
  run python3 "$SCRIPT" v9.9.9
  [ "$status" -ne 0 ]
  [[ "$output" == *"找不到版本"* ]]
}
