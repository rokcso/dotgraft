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
assert_dir() {
  if [[ -d "$1" ]]; then ok "存在目录 $(basename "$1")"; else bad "缺少目录 $1"; fi
}

chezmoi_at() {
  local home="$1"
  shift
  HOME="$home" chezmoi \
    --source "$SRC" \
    --destination "$home" \
    --config "$home/chezmoi.toml" \
    --persistent-state "$home/state.boltdb" \
    "$@"
}

# 用独立 source/config 安装一份，专门测 dotgraft 命令本身。
# 同时预置用户的默认 chezmoi 配置，验证 Dotgraft 不会碰它。
setup_cli_home() {
  local home="$1"
  local src="$home/.local/share/chezmoi-dotgraft"
  local cfg="$home/.config/dotgraft/chezmoi.toml"
  mkdir -p "$src" "$(dirname "$cfg")" "$home/.config/chezmoi" "$home/.local/share/chezmoi"
  printf '# USER_CHEZMOI_CONFIG\n' > "$home/.config/chezmoi/chezmoi.toml"
  printf '# USER_DEFAULT_SOURCE\n' > "$home/.local/share/chezmoi/user-file"
  (cd "$REPO_DIR" && tar --exclude=.git --exclude=refs -cf - .) |
    (cd "$src" && tar -xf -)
  HOME="$home" chezmoi \
    --source "$src" --config "$cfg" --destination "$home" \
    init \
    --promptMultichoice "$Q_TOOLS=fzf/zoxide" \
    --promptChoice "$Q_THEME=Catppuccin Mocha" \
    --promptBool "$Q_GLASS=true" > /dev/null
  HOME="$home" chezmoi \
    --source "$src" --config "$cfg" --destination "$home" \
    apply --exclude=scripts > /dev/null
}

dotgraft_at() {
  local home="$1"
  shift
  HOME="$home" \
    DOTGRAFT_SOURCE="$home/.local/share/chezmoi-dotgraft" \
    DOTGRAFT_CONFIG="$home/.config/dotgraft/chezmoi.toml" \
    "$home/.local/bin/dotgraft" "$@"
}

dotgraft_script_at() {
  local home="$1"
  shift
  HOME="$home" \
    DOTGRAFT_SOURCE="$home/.local/share/chezmoi-dotgraft" \
    DOTGRAFT_CONFIG="$home/.config/dotgraft/chezmoi.toml" \
    bash "$REPO_DIR/dot_local/bin/executable_dotgraft" "$@"
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
  assert_file "$conf_d/80-dotgraft.zsh"
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
  assert_contains "$localhome/.config/ghostty/config" "macos-titlebar-style = native"
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

  # 渲染后的可选 zsh 片段和 .zshrc 必须是合法 zsh
  local zf
  for zf in "$conf_d/40-tools.zsh" "$conf_d/50-functions.zsh" "$conf_d/70-aliases.zsh" "$conf_d/80-dotgraft.zsh"; do
    [[ -e "$zf" ]] || continue
    if zsh -n "$zf" 2> /dev/null; then
      ok "zsh 语法通过 $(basename "$zf")"
    else
      bad "zsh 语法有误：$zf"
    fi
  done
  if zsh -n "$localhome/.zshrc" 2> /dev/null; then
    ok ".zshrc 是合法 zsh"
  else
    bad ".zshrc 语法有误"
  fi

  # 受管目标必须都在 dotgraft 白名单内，防止 .chezmoiignore 漏掉顶层文件
  local managed rel unexpected=0
  while IFS= read -r managed; do
    [[ -n "$managed" ]] || continue
    rel="${managed#"$localhome"/}"
    case "$rel" in
      .config/zsh/init.zsh | \
        .config/zsh/conf.d/10-history.zsh | \
        .config/zsh/conf.d/20-completion.zsh | \
        .config/zsh/conf.d/30-prompt.zsh | \
        .config/zsh/conf.d/40-tools.zsh | \
        .config/zsh/conf.d/50-functions.zsh | \
        .config/zsh/conf.d/60-plugins.zsh | \
        .config/zsh/conf.d/70-aliases.zsh | \
        .config/zsh/conf.d/80-dotgraft.zsh | \
        .config/zsh/conf.d/90-local.zsh | \
        .config/zsh/conf.d/99-highlighting.zsh | \
        .config/ghostty/config | \
        .config/starship.toml | \
        .local/bin/dotgraft | \
        .zshrc) ;;
      *)
        bad "出现白名单之外的受管文件：$rel"
        unexpected=1
        ;;
    esac
  done < <(chezmoi_at "$localhome" managed --include=files --path-style=absolute 2> /dev/null)
  [[ "$unexpected" -eq 0 ]] && ok "受管文件都在白名单内"

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
# 重新选配：从全选改成全不选
# ------------------------------------------------------------------------------
step "场景: 重新选配会移除可选片段"
reconf="$TMP/reconf"
mkdir -p "$reconf"
chezmoi_at "$reconf" init --promptMultichoice "$Q_TOOLS=fzf/zoxide/eza/bat/yazi" \
  --promptChoice "$Q_THEME=Catppuccin Mocha" --promptBool "$Q_GLASS=true" > /dev/null
chezmoi_at "$reconf" apply --exclude=scripts > /dev/null
printf '# MY_LOCAL_SETTING\n' > "$reconf/.config/zsh/conf.d/90-local.zsh"
chezmoi_at "$reconf" init --promptMultichoice "$Q_TOOLS=" \
  --promptChoice "$Q_THEME=GitHub Dark" --promptBool "$Q_GLASS=false" > /dev/null
chezmoi_at "$reconf" apply --exclude=scripts > /dev/null
assert_no_file "$reconf/.config/zsh/conf.d/40-tools.zsh"
assert_no_file "$reconf/.config/zsh/conf.d/50-functions.zsh"
assert_no_file "$reconf/.config/zsh/conf.d/70-aliases.zsh"
assert_contains "$reconf/.config/zsh/conf.d/90-local.zsh" "MY_LOCAL_SETTING"
block_count="$(grep -c '^# >>> dotgraft >>>$' "$reconf/.zshrc" || true)"
if [[ "$block_count" == "1" ]]; then
  ok "重新选配后 .zshrc 仍只有一个 dotgraft 区块"
else
  bad "重新选配后 dotgraft 区块出现 $block_count 次"
fi

# ------------------------------------------------------------------------------
# 短别名与补全
# ------------------------------------------------------------------------------
step "场景: dotg 别名与补全"
shortcuts="$TMP/shortcuts"
setup_cli_home "$shortcuts"

shortcut_out="$(HOME="$shortcuts" zsh -i -c '
  echo "dotg_whence=$(whence -w dotg 2>/dev/null)"
  echo "dotg_comp=${_comps[dotg]:-}"
  echo "dotgraft_comp=${_comps[dotgraft]:-}"
  echo "has_fn=$(( $+functions[_dotgraft] ))"
' 2> /dev/null)"

if command -v dotg > /dev/null 2>&1; then
  ok "系统已有 dotg 命令，跳过别名覆盖断言"
else
  if [[ "$shortcut_out" == *"dotg_whence=dotg: alias"* ]]; then
    ok "dotg 是 dotgraft 的别名"
  else
    bad "dotg 别名没有生效"
  fi
fi
if [[ "$shortcut_out" == *"dotgraft_comp=_dotgraft"* ]]; then
  ok "dotgraft 补全已注册"
else
  bad "dotgraft 补全没有注册"
fi
if [[ "$shortcut_out" == *"dotg_comp=_dotgraft"* ]]; then
  ok "dotg 补全已注册"
else
  bad "dotg 补全没有注册"
fi
if [[ "$shortcut_out" == *"has_fn=1"* ]]; then
  ok "_dotgraft 补全函数存在"
else
  bad "_dotgraft 补全函数不存在"
fi

# ------------------------------------------------------------------------------
# diff 默认摘要，完整 diff 需要 --full
# ------------------------------------------------------------------------------
step "场景: diff 默认只显示摘要"
printf '\n# pending change\n' >> "$shortcuts/.local/share/chezmoi-dotgraft/dot_config/zsh/conf.d/10-history.zsh"
diff_out="$(dotgraft_at "$shortcuts" diff 2>&1 || true)"
if [[ "$diff_out" == *"待改动"* ]] && [[ "$diff_out" == *"10-history.zsh"* ]]; then
  ok "diff 显示了文件摘要"
else
  bad "diff 没有显示文件摘要"
fi
if [[ "$diff_out" != *"@@"* ]]; then
  ok "diff 默认没有打印完整补丁"
else
  bad "diff 默认仍然打印了完整补丁"
fi

# ------------------------------------------------------------------------------
# 卸载安全：非 Dotgraft 受管文件必须让卸载停下来
# ------------------------------------------------------------------------------
step "场景: uninstall 拒绝非 Dotgraft 受管文件"
cli="$TMP/cli-unexpected"
setup_cli_home "$cli"
printf 'private\n' > "$cli/.local/share/chezmoi-dotgraft/dot_private"
HOME="$cli" chezmoi --source "$cli/.local/share/chezmoi-dotgraft" \
  --config "$cli/.config/dotgraft/chezmoi.toml" --destination "$cli" \
  apply --exclude=scripts > /dev/null
if dotgraft_script_at "$cli" uninstall <<< 'y' > /dev/null 2>&1; then
  bad "uninstall 应该拒绝非 Dotgraft 受管文件"
else
  ok "uninstall 拒绝了非 Dotgraft 受管文件"
fi
assert_file "$cli/.private"
assert_file "$cli/.config/ghostty/config"
if [[ "$(dotgraft_at "$cli" chezmoi source-path)" == "$cli/.local/share/chezmoi-dotgraft" ]]; then
  ok "dotgraft chezmoi 使用独立 source"
else
  bad "dotgraft chezmoi 没有使用独立 source"
fi
status_out="$(dotgraft_at "$cli" status 2>&1 || true)"
if [[ "$status_out" == *"chezmoi-dotgraft"* ]] && [[ "$status_out" == *"dotgraft/chezmoi.toml"* ]]; then
  ok "dotgraft status 显示独立 source/config"
else
  bad "dotgraft status 没有显示独立 source/config"
fi
if [[ "$status_out" == *"版本:"* ]]; then
  ok "dotgraft status 显示安装版本"
else
  bad "dotgraft status 没有显示安装版本"
fi

# ------------------------------------------------------------------------------
# 卸载成功路径：备份、移除区块、恢复 Ghostty 覆盖文件
# ------------------------------------------------------------------------------
step "场景: uninstall 备份并清理 Dotgraft 文件"
cli2="$TMP/cli-success"
setup_cli_home "$cli2"
ghostty_override_dir="$cli2/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$ghostty_override_dir"
printf 'theme = Original\n' > "$ghostty_override_dir/config.before-dotgraft"
if dotgraft_script_at "$cli2" uninstall <<< 'y' > /dev/null 2>&1; then
  ok "uninstall 正常退出"
else
  bad "uninstall 非零退出"
fi
assert_no_file "$cli2/.config/ghostty/config"
assert_no_file "$cli2/.config/starship.toml"
assert_no_file "$cli2/.local/bin/dotgraft"
if grep -q '^# >>> dotgraft >>>$' "$cli2/.zshrc" 2> /dev/null; then
  bad "uninstall 后 .zshrc 仍残留 dotgraft 区块"
else
  ok "uninstall 后 .zshrc 区块已移除"
fi
assert_contains "$ghostty_override_dir/config" "theme = Original"
if find "$cli2/.config-backup" -path '*/files/.config/zsh/conf.d/90-local.zsh' -type f | grep -q .; then
  ok "90-local.zsh 已备份"
else
  bad "90-local.zsh 没有备份"
fi
assert_dir "$cli2/.local/share/chezmoi-dotgraft"
assert_contains "$cli2/.config/chezmoi/chezmoi.toml" "USER_CHEZMOI_CONFIG"
assert_contains "$cli2/.local/share/chezmoi/user-file" "USER_DEFAULT_SOURCE"

# ------------------------------------------------------------------------------
# 卸载安全：.zshrc 区块不完整时不能动任何东西
# ------------------------------------------------------------------------------
step "场景: .zshrc 区块不完整时拒绝卸载"
cli3="$TMP/cli-malformed"
setup_cli_home "$cli3"
cat > "$cli3/.zshrc" << 'EOF'
export KEEP=1
# >>> dotgraft >>>
source "$HOME/.config/zsh/init.zsh"
EOF
if dotgraft_script_at "$cli3" uninstall <<< 'y' > /dev/null 2>&1; then
  bad "区块不完整时 uninstall 应该拒绝执行"
else
  ok "区块不完整时 uninstall 拒绝执行"
fi
assert_contains "$cli3/.zshrc" "KEEP=1"
assert_file "$cli3/.config/zsh/init.zsh"
assert_file "$cli3/.config/ghostty/config"

cat > "$cli3/.zshrc" << 'EOF'
# <<< dotgraft <<<
export KEEP_ORDER=1
# >>> dotgraft >>>
EOF
if dotgraft_script_at "$cli3" uninstall <<< 'y' > /dev/null 2>&1; then
  bad "结束标记在开始标记之前时 uninstall 应该拒绝执行"
else
  ok "结束标记在开始标记之前时 uninstall 拒绝执行"
fi
assert_contains "$cli3/.zshrc" "KEEP_ORDER=1"
assert_file "$cli3/.config/zsh/init.zsh"

# ------------------------------------------------------------------------------
# bootstrap：已有非 Dotgraft source 时必须停下来
# ------------------------------------------------------------------------------
fakebin="$TMP/fakebin"
mkdir -p "$fakebin"
cat > "$fakebin/brew" << 'EOF'
#!/bin/sh
if [ "${1:-}" = "--prefix" ]; then
  printf '/opt/homebrew\n'
  exit 0
fi
printf '%s\n' "$*" >> "${FAKE_BREW_LOG:?}"
if [ "${FAKE_BREW_FAIL:-0}" = "1" ]; then
  exit 1
fi
exit 0
EOF
chmod +x "$fakebin/brew"

step "场景: bootstrap 拒绝非 Dotgraft 源目录"
boot_home="$TMP/boot-home"
mkdir -p "$boot_home/.local/share/chezmoi-dotgraft" "$boot_home/.local/share/chezmoi"
printf 'someone else\n' > "$boot_home/.local/share/chezmoi-dotgraft/dot_other"
printf 'my own chezmoi source\n' > "$boot_home/.local/share/chezmoi/dot_mine"
if printf 'y\n' | HOME="$boot_home" PATH="$fakebin:$PATH" \
  DOTGRAFT_SOURCE="$boot_home/.local/share/chezmoi-dotgraft" \
  DOTGRAFT_CONFIG="$boot_home/.config/dotgraft/chezmoi.toml" \
  DOTGRAFT_REPO="$REPO_DIR" bash "$REPO_DIR/bootstrap.sh" > /dev/null 2>&1; then
  bad "bootstrap 应该拒绝非 Dotgraft 源目录"
else
  ok "bootstrap 拒绝了非 Dotgraft 源目录"
fi
assert_file "$boot_home/.local/share/chezmoi-dotgraft/dot_other"
assert_file "$boot_home/.local/share/chezmoi/dot_mine"

step "场景: bootstrap 拒绝旧版默认 source"
legacy_home="$TMP/legacy-home"
mkdir -p "$legacy_home/.local/share/chezmoi"
printf 'dotgraft\n' > "$legacy_home/.local/share/chezmoi/.dotgraft-source"
printf 'old\n' > "$legacy_home/.local/share/chezmoi/old-file"
if printf 'y\n' | HOME="$legacy_home" PATH="$fakebin:$PATH" \
  DOTGRAFT_SOURCE="$legacy_home/.local/share/chezmoi-dotgraft" \
  DOTGRAFT_CONFIG="$legacy_home/.config/dotgraft/chezmoi.toml" \
  DOTGRAFT_REPO="$REPO_DIR" bash "$REPO_DIR/bootstrap.sh" > /dev/null 2>&1; then
  bad "bootstrap 应该拒绝旧版默认 source"
else
  ok "bootstrap 拒绝旧版默认 source"
fi
assert_file "$legacy_home/.local/share/chezmoi/old-file"

# ------------------------------------------------------------------------------
# deps：无条件重跑依赖安装，并把失败反映到退出码
# ------------------------------------------------------------------------------
step "场景: dotgraft deps 可重复执行且传播失败"
cli4="$TMP/cli-deps"
setup_cli_home "$cli4"
brew_log="$TMP/brew.log"
if FAKE_BREW_LOG="$brew_log" PATH="$fakebin:$PATH" \
  dotgraft_at "$cli4" deps > /dev/null 2>&1; then
  ok "dotgraft deps 正常执行"
else
  bad "dotgraft deps 意外失败"
fi
if grep -q 'bundle' "$brew_log" 2> /dev/null; then
  ok "deps 调用了 brew bundle"
else
  bad "deps 没有调用 brew bundle"
fi
if FAKE_BREW_LOG="$brew_log" FAKE_BREW_FAIL=1 PATH="$fakebin:$PATH" \
  dotgraft_at "$cli4" deps > /dev/null 2>&1; then
  bad "deps 应该把 brew 失败传播成非零退出"
else
  ok "deps 把 brew 失败传播成非零退出"
fi

doctor_out=""
if doctor_out="$(dotgraft_at "$cli4" doctor 2>&1)"; then
  ok "dotgraft doctor 正常退出"
else
  bad "dotgraft doctor 非零退出"
fi
if [[ "$doctor_out" == *"Dotgraft source"* ]] && [[ "$doctor_out" == *"Dotgraft config"* ]] && [[ "$doctor_out" == *"managed files"* ]]; then
  ok "dotgraft doctor 输出 Dotgraft 专用检查"
else
  bad "dotgraft doctor 缺少 Dotgraft 专用检查"
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
if [[ -z "$(chezmoi_at "$idem" diff --no-pager --exclude=scripts 2> /dev/null || true)" ]]; then
  ok "第二次 apply 后没有文件差异"
else
  bad "第二次 apply 后仍有文件差异"
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
