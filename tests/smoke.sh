#!/usr/bin/env bash
# ==============================================================================
# 冒烟测试
# ==============================================================================
# 验证模板渲染和选配行为。本地和 CI 都能跑：
#   bash tests/smoke.sh
#
# 不会碰你的真实家目录：所有操作都在临时目录里，仓库也是复制一份再用的。
# 不执行 run_onchange 脚本（--exclude=scripts），所以不会真的装包。
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 从 .chezmoi.toml.tmpl 里抄的问题原文，必须逐字一致，否则 init 会转为交互提问
Q_TOOLS='要启用哪些 CLI 工具？（空格勾选，回车确认）'
Q_THEME='Ghostty 主题'
Q_GLASS='启用 macOS 原生毛玻璃效果？（需要 macOS 26 及以上）'

pass_count=0
fail_count=0

step() { printf '\n==> %s\n' "$*"; }
ok() {
  printf '    ✓ %s\n' "$*"
  pass_count=$((pass_count + 1))
}
bad() {
  printf '    ✗ %s\n' "$*" >&2
  fail_count=$((fail_count + 1))
}
die() {
  printf '\n错误: %s\n' "$*" >&2
  exit 1
}

# ------------------------------------------------------------------------------
# 前置检查
# ------------------------------------------------------------------------------
command -v chezmoi > /dev/null 2>&1 || die "找不到 chezmoi。装一下：brew install chezmoi"

GHOSTTY_BIN=''
for candidate in ghostty /Applications/Ghostty.app/Contents/MacOS/ghostty; do
  if command -v "$candidate" > /dev/null 2>&1; then
    GHOSTTY_BIN="$candidate"
    break
  fi
done

if [[ -z "$GHOSTTY_BIN" ]]; then
  printf '    ! 未找到 Ghostty，跳过配置校验和主题名校验\n'
fi

# 复制一份仓库当源目录。chezmoi init 在没有 .git 时会 git init，
# 直接拿真仓库当源会污染它，所以复制。
SRC="$TMP/src"
mkdir -p "$SRC"
(cd "$REPO_DIR" && tar --exclude=.git --exclude=refs -cf - .) | (cd "$SRC" && tar -xf -)

# ------------------------------------------------------------------------------
# 断言工具
# ------------------------------------------------------------------------------
assert_file() {
  if [[ -f "$1" ]]; then ok "存在 $(basename "$1")"; else bad "缺少 $1"; fi
}
assert_no_file() {
  if [[ -e "$1" ]]; then bad "不该存在却存在 $1"; else ok "已移除 $(basename "$1")"; fi
}
assert_contains() {
  if grep -qF -- "$2" "$1" 2> /dev/null; then
    ok "$(basename "$1") 含 $2"
  else
    bad "$(basename "$1") 缺 $2"
  fi
}

# ------------------------------------------------------------------------------
# 跑一个场景
#   $1 场景名  $2 工具选择（/ 分隔，空表示全不选）
#   $3 主题    $4 毛玻璃 true/false
# ------------------------------------------------------------------------------
run_case() {
  local name="$1" tools="$2" theme="$3" glass="$4"
  local localhome
  localhome="$TMP/$name"
  mkdir -p "$localhome"

  # 预置一个带第三方内容的 .zshrc，验证注入不会吃掉它
  cat > "$localhome/.zshrc" << 'SEED'
# THIRD_PARTY_MARKER
export DA="someone-elses-stuff"
SEED

  step "场景: $name"
  HOME="$localhome" chezmoi \
    --source "$SRC" \
    --destination "$localhome" \
    --config "$localhome/chezmoi.toml" \
    --persistent-state "$localhome/state.boltdb" \
    init \
    --promptMultichoice "$Q_TOOLS=$tools" \
    --promptChoice "$Q_THEME=$theme" \
    --promptBool "$Q_GLASS=$glass" > /dev/null

  HOME="$localhome" chezmoi \
    --source "$SRC" \
    --destination "$localhome" \
    --config "$localhome/chezmoi.toml" \
    --persistent-state "$localhome/state.boltdb" \
    apply --exclude=scripts > /dev/null

  local conf_d="$localhome/.config/zsh/conf.d"
  assert_file "$localhome/.config/zsh/init.zsh"
  assert_file "$localhome/.config/starship.toml"
  assert_file "$localhome/.config/ghostty/config"
  assert_file "$localhome/.local/bin/dotgraft"
  assert_file "$conf_d/90-local.zsh"

  # 基础片段永远在
  assert_file "$conf_d/10-history.zsh"
  assert_file "$conf_d/20-completion.zsh"
  assert_file "$conf_d/30-prompt.zsh"
  assert_file "$conf_d/60-plugins.zsh"
  assert_file "$conf_d/99-highlighting.zsh"

  # 可选片段跟着选择走
  case "$tools" in
    *fzf* | *zoxide*) assert_file "$conf_d/40-tools.zsh" ;;
    *) assert_no_file "$conf_d/40-tools.zsh" ;;
  esac
  case "$tools" in
    *yazi*) assert_file "$conf_d/50-functions.zsh" ;;
    *) assert_no_file "$conf_d/50-functions.zsh" ;;
  esac
  case "$tools" in
    *eza* | *bat*) assert_file "$conf_d/70-aliases.zsh" ;;
    *) assert_no_file "$conf_d/70-aliases.zsh" ;;
  esac

  # 主题和毛玻璃
  assert_contains "$localhome/.config/ghostty/config" "theme = $theme"
  if [[ "$glass" == "true" ]]; then
    assert_contains "$localhome/.config/ghostty/config" "background-blur = macos-glass-regular"
  else
    assert_contains "$localhome/.config/ghostty/config" "background-blur = 20"
  fi

  # .zshrc 注入：区块在，原有内容也在，且区块只出现一次
  assert_contains "$localhome/.zshrc" "# >>> dotgraft >>>"
  assert_contains "$localhome/.zshrc" "THIRD_PARTY_MARKER"
  assert_contains "$localhome/.zshrc" 'export DA="someone-elses-stuff"'
  local block_count
  block_count="$(grep -c '^# >>> dotgraft >>>$' "$localhome/.zshrc" || true)"
  if [[ "$block_count" == "1" ]]; then
    ok "dotgraft 区块只出现一次"
  else
    bad "dotgraft 区块出现 $block_count 次"
  fi

  # 脚本可执行
  if [[ -x "$localhome/.local/bin/dotgraft" ]]; then
    ok "dotgraft 有可执行位"
  else
    bad "dotgraft 没有可执行位"
  fi

  # 渲染后的依赖安装脚本必须是合法 sh
  HOME="$localhome" chezmoi \
    --source "$SRC" --config "$localhome/chezmoi.toml" \
    --persistent-state "$localhome/state.boltdb" \
    execute-template < "$SRC/run_onchange_install-packages.sh.tmpl" > "$TMP/$name-install.sh"
  if sh -n "$TMP/$name-install.sh" 2> /dev/null; then
    ok "渲染后的安装脚本是合法 sh"
  else
    bad "渲染后的安装脚本语法有误：$TMP/$name-install.sh"
  fi

  # Ghostty 在的话顺便校验渲染结果（模板必须先渲染，不能直接喂）
  if [[ -n "$GHOSTTY_BIN" ]]; then
    if "$GHOSTTY_BIN" +validate-config --config-file="$localhome/.config/ghostty/config" > /dev/null 2>&1; then
      ok "Ghostty 配置校验通过"
    else
      bad "Ghostty 配置校验失败"
    fi
  fi

}

# ------------------------------------------------------------------------------
# 三个场景
# ------------------------------------------------------------------------------
run_case all "fzf/zoxide/eza/bat/yazi" "Catppuccin Mocha" true
run_case none "" "GitHub Dark" false
run_case partial "eza" "TokyoNight" true

# ------------------------------------------------------------------------------
# 主题选项校验：.chezmoi.toml.tmpl 里列的每个主题名都必须在 Ghostty 里存在
# ------------------------------------------------------------------------------
if [[ -n "$GHOSTTY_BIN" ]]; then
  step "校验选配里的主题名"
  # shellcheck disable=SC2016 # 这里要的是字面量 $theme，不是变量展开
  theme_line="$(sed -n '/\$theme := promptChoice/,/(list/p' "$SRC/.chezmoi.toml.tmpl" | tail -1)"
  if [[ -z "$theme_line" ]]; then
    bad "没能从 .chezmoi.toml.tmpl 提取主题列表"
  else
    while IFS= read -r theme_name; do
      [[ -z "$theme_name" ]] && continue
      printf 'theme = %s\n' "$theme_name" > "$TMP/theme-probe.conf"
      if "$GHOSTTY_BIN" +validate-config --config-file="$TMP/theme-probe.conf" > /dev/null 2>&1; then
        ok "主题 $theme_name 存在"
      else
        bad "主题 $theme_name 在 Ghostty 里不存在"
      fi
    done <<< "$(printf '%s' "$theme_line" | grep -o '\"[^\"]*\"' | tr -d '\"' || true)"
  fi
fi

# ------------------------------------------------------------------------------
# 幂等：同一个 HOME 连跑两次 apply，内容不应变化
# ------------------------------------------------------------------------------
step "场景: 幂等（连续两次 apply）"
idem="$TMP/idem"
mkdir -p "$idem"
HOME="$idem" chezmoi --source "$SRC" --destination "$idem" \
  --config "$idem/chezmoi.toml" --persistent-state "$idem/state.boltdb" \
  init --promptMultichoice "$Q_TOOLS=fzf" --promptChoice "$Q_THEME=Catppuccin Mocha" \
  --promptBool "$Q_GLASS=true" > /dev/null
HOME="$idem" chezmoi --source "$SRC" --destination "$idem" \
  --config "$idem/chezmoi.toml" --persistent-state "$idem/state.boltdb" \
  apply --exclude=scripts > /dev/null
before="$(cat "$idem/.zshrc")"
HOME="$idem" chezmoi --source "$SRC" --destination "$idem" \
  --config "$idem/chezmoi.toml" --persistent-state "$idem/state.boltdb" \
  apply --exclude=scripts > /dev/null
after="$(cat "$idem/.zshrc")"
if [[ "$before" == "$after" ]]; then
  ok "第二次 apply 未改动 .zshrc"
else
  bad "第二次 apply 改动了 .zshrc"
fi

# 仓库自身的文件不该被铺进 $HOME（.chezmoiignore 回归检查）
assert_no_file "$idem/README.md"
assert_no_file "$idem/Brewfile"
assert_no_file "$idem/bootstrap.sh"
assert_no_file "$idem/docs"
assert_no_file "$idem/tests"

# ------------------------------------------------------------------------------
# 结果
# ------------------------------------------------------------------------------
printf '\n========================================\n'
printf ' 通过: %d   失败: %d\n' "$pass_count" "$fail_count"
printf '========================================\n'

[[ "$fail_count" -eq 0 ]] || exit 1
