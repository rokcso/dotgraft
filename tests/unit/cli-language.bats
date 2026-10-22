#!/usr/bin/env bats

# CLI language behavior and runtime localization of generated scripts.
# Kept separate from i18n.bats, which covers bootstrap/template integration.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CLI="$REPO_ROOT/dot_local/bin/executable_dotgraft"
  BOOTSTRAP="$REPO_ROOT/bootstrap.sh"
  LIB="$REPO_ROOT/scripts/lib/language.sh"
  TEMPLATE="$REPO_ROOT/run_onchange_install-packages.sh.tmpl"
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/home" "$TMP/bin"
}

teardown() {
  rm -rf "${TMP:-}"
}

run_cli() {
  local language="$1"
  shift
  run env HOME="$TMP/home" DOTGRAFT_LANG="$language" LC_ALL= LC_MESSAGES= LANG= bash "$CLI" "$@"
}

assert_contains() {
  local text="$1"
  if [[ "$output" != *"$text"* ]]; then
    printf 'Expected output to contain: %s\n--- actual output ---\n%s\n' "$text" "$output" >&2
    return 1
  fi
}

assert_not_contains() {
  local text="$1"
  if [[ "$output" == *"$text"* ]]; then
    printf 'Expected output not to contain: %s\n--- actual output ---\n%s\n' "$text" "$output" >&2
    return 1
  fi
}

# Extract only the shared detector body from each standalone entry point.
extract_detector() {
  local kind="$1" file="$2"
  case "$kind" in
    lib)
      sed -n '/^# Return en\/zh/,$p' "$file"
      ;;
    marked)
      sed -n '/^# BEGIN DOTGRAFT_LANGUAGE_EMBEDDED$/,/^# END DOTGRAFT_LANGUAGE_EMBEDDED$/p' "$file" |
        sed '1d;$d'
      ;;
    plain)
      sed -n '/^# Return en\/zh/,/^# Resolve the UI language/p' "$file" | sed '$d'
      ;;
  esac
}

@test "CLI help is fully localized in English and Chinese" {
  run_cli en help
  [ "$status" -eq 0 ]
  assert_contains 'dotgraft - terminal configuration manager'
  assert_contains 'Usage: dotgraft <command>'
  assert_contains 'Uninstall (back up managed files, keep Homebrew packages)'
  assert_not_contains '用法: dotgraft <命令>'
  assert_not_contains '卸载（备份受管文件，保留 Homebrew 包）'

  run_cli zh help
  [ "$status" -eq 0 ]
  assert_contains 'dotgraft —— 终端配置管理'
  assert_contains '用法: dotgraft <命令>'
  assert_contains '卸载（备份受管文件，保留 Homebrew 包）'
  assert_not_contains 'Usage: dotgraft <command>'
  assert_not_contains 'Uninstall (back up managed files, keep Homebrew packages)'
}

@test "unknown commands and missing arguments fail with localized errors" {
  run_cli en definitely-not-a-command
  [ "$status" -eq 1 ]
  assert_contains 'Unknown command: definitely-not-a-command'
  assert_contains 'Usage: dotgraft <command>'
  assert_not_contains '未知命令: definitely-not-a-command'

  run_cli zh definitely-not-a-command
  [ "$status" -eq 1 ]
  assert_contains '未知命令: definitely-not-a-command'
  assert_contains '用法: dotgraft <命令>'
  assert_not_contains 'Unknown command: definitely-not-a-command'

  run_cli en restore
  [ "$status" -eq 1 ]
  assert_contains 'Error: Usage: dotgraft restore <timestamp>'

  run_cli zh restore
  [ "$status" -eq 1 ]
  assert_contains '错误: 用法: dotgraft restore <时间戳>'
}

@test "invalid theme errors are localized before touching configuration" {
  local source="$TMP/source"
  mkdir -p "$source"
  printf 'test marker\n' > "$source/.dotgraft-source"

  run env HOME="$TMP/home" DOTGRAFT_SOURCE="$source" DOTGRAFT_LANG=en \
    LC_ALL= LC_MESSAGES= LANG= bash "$CLI" theme 'No Such Theme'
  [ "$status" -eq 1 ]
  assert_contains 'Error: Unknown theme: No Such Theme. Run dotgraft theme to list themes.'
  assert_not_contains '未知主题'

  run env HOME="$TMP/home" DOTGRAFT_SOURCE="$source" DOTGRAFT_LANG=zh \
    LC_ALL= LC_MESSAGES= LANG= bash "$CLI" theme 'No Such Theme'
  [ "$status" -eq 1 ]
  assert_contains '错误: 未知主题：No Such Theme。运行 dotgraft theme 查看列表。'
  assert_not_contains 'Unknown theme'
}

@test "all embedded language detectors match the shared library" {
  local kind file name
  for spec in \
    'lib scripts/lib/language.sh' \
    'marked bootstrap.sh' \
    'plain dot_local/bin/executable_dotgraft' \
    'plain run_onchange_install-packages.sh.tmpl'; do
    set -- $spec
    kind="$1"
    file="$REPO_ROOT/$2"
    name="$(basename "$2")"
    extract_detector "$kind" "$file" | sed '/^[[:space:]]*$/d' > "$TMP/$name.detector"
    [ -s "$TMP/$name.detector" ]
  done

  run diff -u "$TMP/language.sh.detector" "$TMP/bootstrap.sh.detector"
  [ "$status" -eq 0 ]
  run diff -u "$TMP/language.sh.detector" "$TMP/executable_dotgraft.detector"
  [ "$status" -eq 0 ]
  run diff -u "$TMP/language.sh.detector" "$TMP/run_onchange_install-packages.sh.tmpl.detector"
  [ "$status" -eq 0 ]
}

@test "all embedded detectors make the same runtime language decisions" {
  local source="$TMP/language.sh"
  extract_detector lib "$LIB" > "$source"
  extract_detector marked "$BOOTSTRAP" > "$TMP/bootstrap.sh.detector"
  extract_detector plain "$CLI" > "$TMP/executable_dotgraft.detector"
  extract_detector plain "$TEMPLATE" > "$TMP/run_onchange_install-packages.sh.tmpl.detector"

  local implementation detected expected
  for implementation in \
    "$TMP/bootstrap.sh.detector" \
    "$TMP/executable_dotgraft.detector" \
    "$TMP/run_onchange_install-packages.sh.tmpl.detector"; do
    [ -s "$implementation" ]
  done

  # Scenario columns use "-" for an unset value: explicit, LC_ALL,
  # LC_MESSAGES, LANG, the first macOS preferred language, and expected.
  while read -r explicit lc_all lc_messages locale preferred expected; do
    [ "$explicit" = "-" ] && explicit=""
    [ "$lc_all" = "-" ] && lc_all=""
    [ "$lc_messages" = "-" ] && lc_messages=""
    [ "$locale" = "-" ] && locale=""
    [ "$preferred" = "-" ] && preferred=""
    for implementation in "$source" \
      "$TMP/bootstrap.sh.detector" \
      "$TMP/executable_dotgraft.detector" \
      "$TMP/run_onchange_install-packages.sh.tmpl.detector"; do
      run env DOTGRAFT_LANG="$explicit" LC_ALL="$lc_all" LC_MESSAGES="$lc_messages" \
        LANG="$locale" PREFERRED="$preferred" bash -c '
          defaults() { printf "(\n    \"%s\",\n    \"en-US\"\n)\n" "$PREFERRED"; }
          source "$1"
          dotgraft_detect_language
        ' _ "$implementation"
      [ "$status" -eq 0 ]
      detected="$output"
      if [ "$detected" != "$expected" ]; then
        printf 'Detector mismatch for %s\n' "$implementation" >&2
        printf 'explicit=%s LC_ALL=%s LC_MESSAGES=%s LANG=%s preferred=%s\n' \
          "$explicit" "$lc_all" "$lc_messages" "$locale" "$preferred" >&2
        printf 'expected=%s actual=%s\n' "$expected" "$detected" >&2
        return 1
      fi
    done
  done <<'SCENARIOS'
en zh_CN.UTF-8 zh_CN.UTF-8 zh_CN.UTF-8 zh-Hans-CN en
zh en_US.UTF-8 en_US.UTF-8 en_US.UTF-8 en-US zh
- zh_CN.UTF-8 zh_CN.UTF-8 en_US.UTF-8 en-US zh
- en_US.UTF-8 zh_CN.UTF-8 zh_CN.UTF-8 zh-Hans-CN en
- fr_FR.UTF-8 fr_FR.UTF-8 fr_FR.UTF-8 zh-Hans-CN en
- - - - zh-Hans-CN zh
- - - - en-US en
- - - C zh-Hans-CN zh
- - - C.UTF-8 zh-Hans-CN zh
- - - POSIX en-US en
en-US en-US en-US en-US en en
SCENARIOS
}

render_dependency_script() {
  local config="$1" output="$2"
  DOTGRAFT_LANG=en LC_ALL= LC_MESSAGES= LANG= \
    chezmoi --source "$REPO_ROOT" --config "$config" \
    execute-template --file "$TEMPLATE" > "$output"
}

make_brew_stub() {
  cat > "$TMP/bin/brew" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "${BREW_LOG:?}"
if [ "${BREW_FAIL:-}" = "bundle" ] && [ "$1" = "bundle" ]; then
  exit 1
fi
exit 0
STUB
  chmod +x "$TMP/bin/brew"
}

run_dependency_script() {
  local script="$1" language="$2" log="$3" fail_mode="${4:-}"
  run env HOME="$TMP/dep-home" PATH="$TMP/bin:$PATH" DOTGRAFT_LANG="$language" \
    BREW_LOG="$log" BREW_FAIL="$fail_mode" bash "$script"
}

@test "dependency template renders identically for English and Chinese" {
  local config="$TMP/render.toml" en="$TMP/dep-en.sh" zh="$TMP/dep-zh.sh"
  printf '[data]\ntools = ["eza", "bat"]\n' > "$config"

  run render_dependency_script "$config" "$en"
  [ "$status" -eq 0 ]
  run render_dependency_script "$config" "$zh"
  [ "$status" -eq 0 ]
  run cmp -s "$en" "$zh"
  [ "$status" -eq 0 ]

  # The generated script must select its messages at runtime, not render time.
  [[ "$(cat "$en")" == *"Installing optional tools: %s"* ]]
  [[ "$(cat "$en")" == *"安装选配工具: %s"* ]]
}

@test "rendered dependency script emits matching English and Chinese messages" {
  local config="$TMP/render.toml" script="$TMP/dep.sh"
  printf '[data]\ntools = ["eza", "bat"]\n' > "$config"
  render_dependency_script "$config" "$script"
  make_brew_stub
  mkdir -p "$TMP/dep-home/Library/Fonts"
  : > "$TMP/dep-home/Library/Fonts/MapleMono-NF-CN-Regular.ttf"

  run_dependency_script "$script" en "$TMP/brew-en.log"
  [ "$status" -eq 0 ]
  assert_contains '==> Installing base dependencies'
  assert_contains '==> Maple Mono NF CN font already exists; skipping'
  assert_contains '==> Installing optional tools: eza bat'
  assert_contains '==> Dependencies are ready'
  assert_not_contains '安装基础依赖'

  run_dependency_script "$script" zh "$TMP/brew-zh.log"
  [ "$status" -eq 0 ]
  assert_contains '==> 安装基础依赖'
  assert_contains '==> 已存在 Maple Mono NF CN 字体，跳过'
  assert_contains '==> 安装选配工具: eza bat'
  assert_contains '==> 依赖已就绪'
  assert_not_contains 'Installing base dependencies'

  run cmp -s "$TMP/brew-en.log" "$TMP/brew-zh.log"
  [ "$status" -eq 0 ]
  [[ "$(cat "$TMP/brew-en.log")" == *"install eza bat"* ]]
}

@test "rendered dependency failures use matching localized messages" {
  local config="$TMP/render.toml" script="$TMP/dep.sh"
  printf '[data]\ntools = []\n' > "$config"
  render_dependency_script "$config" "$script"
  make_brew_stub
  mkdir -p "$TMP/dep-home/Library/Fonts"
  : > "$TMP/dep-home/Library/Fonts/MapleMono-NF-CN-Regular.ttf"

  run_dependency_script "$script" en "$TMP/brew-fail-en.log" bundle
  [ "$status" -eq 1 ]
  assert_contains '==> No optional CLI tools selected; skipping'
  assert_contains '! Some dependencies were not installed'
  assert_contains 'Fix the network or Homebrew, then run dotgraft deps to retry'
  assert_not_contains '有依赖没装上'

  run_dependency_script "$script" zh "$TMP/brew-fail-zh.log" bundle
  [ "$status" -eq 1 ]
  assert_contains '==> 没有选择任何 CLI 工具，跳过'
  assert_contains '! 有依赖没装上'
  assert_contains '修复网络或 Homebrew 后运行 dotgraft deps 重试'
  assert_not_contains 'Some dependencies were not installed'
}
