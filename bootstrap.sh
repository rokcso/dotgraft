#!/usr/bin/env bash
# ==============================================================================
# Dotgraft —— 安装入口
# ==============================================================================
# 用法：
#   bash <(curl -fsSL https://raw.githubusercontent.com/rokcso/dotgraft/main/bootstrap.sh)
#
# 这个脚本只负责「从零到能跑」：准备 chezmoi、问几个选配问题、
# 展示改动、落盘。装好之后日常操作交给 dotgraft 命令：
#   dotgraft update        更新到最新
#   dotgraft deps          修复依赖
#   dotgraft reconfigure   改选配
#   dotgraft uninstall     卸载
#
# 测试时可以覆盖仓库地址：
#   DOTGRAFT_REPO=/path/to/local/repo bash bootstrap.sh
# ==============================================================================

set -euo pipefail

REPO_URL="${DOTGRAFT_REPO:-https://github.com/rokcso/dotgraft.git}"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$HOME/.config-backup/$STAMP"
GHOSTTY_OVERRIDE="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
GHOSTTY_OVERRIDE_MOVED=0
GHOSTTY_OVERRIDE_SAVED=''

step() { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '    ! %s\n' "$*" >&2; }
fail() {
  printf '\n错误: %s\n' "$*" >&2
  exit 1
}

confirm() {
  local reply
  printf '    %s [y/N] ' "$1"
  read -r reply
  [[ "$reply" == [yY] ]]
}

# 安装中途失败/被 Ctrl-C 时，把已经移开的 Ghostty 覆盖文件放回去。
# apply 成功后会手动把 GHOSTTY_OVERRIDE_MOVED 置 0。
cleanup() {
  local status=$?
  if [[ "$GHOSTTY_OVERRIDE_MOVED" -eq 1 ]]; then
    if [[ -n "$GHOSTTY_OVERRIDE_SAVED" && -e "$GHOSTTY_OVERRIDE_SAVED" ]]; then
      mv "$GHOSTTY_OVERRIDE_SAVED" "$GHOSTTY_OVERRIDE" 2> /dev/null || true
      printf '\n    安装未完成，已恢复 Ghostty 覆盖配置。\n' >&2
    fi
  fi
  return "$status"
}
trap cleanup EXIT

# ==============================================================================
# 环境检查
# ==============================================================================
step "检查环境"

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "目前只支持 macOS。Ghostty 的安装方式、字体路径和几个配置项在 Linux 上都不同，而这个仓库没有 Linux 环境可验证，所以没有贸然声明支持。如果你的机器是 Linux，欢迎到 issues 说明发行版和遇到的问题：https://github.com/rokcso/dotgraft/issues"
fi
note "macOS ✓"

command -v brew > /dev/null 2>&1 || fail "未找到 Homebrew。请先安装：https://brew.sh"
note "Homebrew ✓ ($(brew --prefix))"

command -v git > /dev/null 2>&1 || fail "未找到 git。请先运行：xcode-select --install"
note "git ✓"

# ==============================================================================
# 说明将要做什么
# ==============================================================================
cat << 'PLAN'

    这次安装会做四件事：

      1. 安装 chezmoi（如果还没有）
      2. 问三个选配问题：要哪些 CLI 工具、Ghostty 主题、是否用原生毛玻璃
      3. 展示所有将被改动的文件 diff，让你确认
      4. 备份已有配置，然后落盘，并安装 Homebrew 依赖

    会碰到的位置：
      ~/.zshrc                          末尾插入一小段标记区块
      ~/.config/zsh/                    zsh 配置
      ~/.config/ghostty/config          终端配置
      ~/.config/starship.toml           提示符配置
      ~/.local/bin/dotgraft             dotgraft 命令
      ~/.config/chezmoi/chezmoi.toml    你的选配答案（不进仓库）
      ~/.local/share/chezmoi            chezmoi 源目录
      ~/.config-backup/<时间戳>/        已有配置的备份

    不会碰 ~/.zprofile 和 ~/.zshenv，不用 sudo，不修改 /etc。
PLAN

confirm "继续？" || {
  printf '\n已取消。\n'
  exit 0
}

# ==============================================================================
# chezmoi
# ==============================================================================
step "准备 chezmoi"

if command -v chezmoi > /dev/null 2>&1; then
  note "已安装（$(chezmoi --version | head -1)）"
else
  note "未安装，通过 Homebrew 安装"
  brew install chezmoi
fi

source_looks_like_dotgraft() {
  local src="$1"
  [[ -f "$src/.dotgraft-source" ]] && return 0
  [[ -f "$src/.chezmoi.toml.tmpl" ]] &&
    [[ -f "$src/dot_local/bin/executable_dotgraft" ]] &&
    grep -q 'Dotgraft' "$src/.chezmoi.toml.tmpl"
}

# 如果默认 source 已经有内容，chezmoi init 不会 clone 传入的 repo，
# 而是直接沿用现有 source。那样用户会以为装了 dotgraft，实际却在
# apply 自己的旧 dotfiles。这里必须在 init 之前拦住。
ensure_source_available() {
  local src
  src="$(chezmoi source-path 2> /dev/null || true)"
  [[ -n "$src" ]] || fail "无法确定 chezmoi 源目录"

  if [[ -d "$src" && -n "$(ls -A "$src" 2> /dev/null || true)" ]]; then
    if source_looks_like_dotgraft "$src"; then
      note "检测到已有 Dotgraft 源目录，继续更新：$src"
    else
      fail "chezmoi 源目录已存在，且不像 Dotgraft：$src

      chezmoi init 在源目录已有内容时不会 clone 新仓库，继续执行会
      直接应用你原来的 dotfiles。为避免误操作，已停止。

      请先备份并移开该目录，或把 DOTGRAFT_REPO 指向你想要的位置：
        mv \"$src\" \"$src.before-dotgraft.$(date +%Y%m%d_%H%M%S)\"
      然后重新运行 bootstrap.sh。"
    fi
  fi
}

verify_dotgraft_source() {
  local src
  src="$(chezmoi source-path)"
  source_looks_like_dotgraft "$src" ||
    fail "chezmoi init 之后源目录仍不像 Dotgraft：$src。已停止，请检查仓库地址和网络。"
}

# chezmoi init 会重新渲染配置模板，覆盖已有的 chezmoi.toml。
# 它不在 managed 列表里，所以要在 init 之前单独备份。
backup_chezmoi_config() {
  local file="$HOME/.config/chezmoi/chezmoi.toml"
  [[ -f "$file" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  cp -p "$file" "$BACKUP_DIR/chezmoi.toml.before-dotgraft" 2> /dev/null ||
    fail "无法备份已有 chezmoi.toml，已停止：$file"
  note "已备份已有 chezmoi.toml 到 $BACKUP_DIR/chezmoi.toml.before-dotgraft"
}

# 备份所有“安装前已经存在”的目标文件。
# chezmoi 对未受管目标不会提示，会直接覆盖；没有这一步，
# 用户原来的 Ghostty / Starship / zsh 配置会被静默替换。
backup_existing_targets() {
  local f rel count=0 managed_files
  mkdir -p "$BACKUP_DIR/pre-existing"
  if ! managed_files="$(chezmoi managed --include=files --path-style=absolute 2> /dev/null)"; then
    fail "无法读取 chezmoi 受管文件列表，已停止。请先运行 chezmoi doctor。"
  fi
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    [[ -e "$f" ]] || continue
    rel="${f#"${HOME%/}"/}"
    mkdir -p "$BACKUP_DIR/pre-existing/$(dirname "$rel")"
    cp -p "$f" "$BACKUP_DIR/pre-existing/$rel" 2> /dev/null ||
      fail "无法备份已有文件，已停止：$f"
    count=$((count + 1))
  done <<< "$managed_files"

  if [[ -f "$HOME/.zshrc" && ! -f "$BACKUP_DIR/pre-existing/.zshrc" ]]; then
    cp -p "$HOME/.zshrc" "$BACKUP_DIR/pre-existing/.zshrc" 2> /dev/null ||
      fail "无法备份 ~/.zshrc，已停止"
    count=$((count + 1))
  fi

  if [[ "$count" -gt 0 ]]; then
    note "已备份 $count 个已存在的目标文件到 $BACKUP_DIR/pre-existing"
  fi
}

# ==============================================================================
# 选配问答 + 拉取配置
# ==============================================================================
ensure_source_available
backup_chezmoi_config

step "选择要启用的组件"
note "（下面几个问题由 chezmoi 提问，答案只保存在本机）"
printf '\n'

chezmoi init "$REPO_URL"
verify_dotgraft_source

# ==============================================================================
# 预览
# ==============================================================================
step "将要发生的改动"

diff_output="$(chezmoi diff --no-pager --exclude=scripts 2>&1 || true)"
if [[ -z "$diff_output" ]]; then
  note "没有待应用的改动，已经是最新的。"
else
  printf '%s\n\n' "$diff_output"
  confirm "应用以上改动？" || {
    printf '\n已取消，未应用配置。\n'
    exit 0
  }
fi

# ==============================================================================
# 备份已有配置
# ==============================================================================
step "备份已有配置"
backup_existing_targets

# ==============================================================================
# macOS 上 Ghostty 的覆盖文件
# ==============================================================================
# Ghostty 会先读 ~/.config/ghostty/config，再读 Application Support 里的那份，
# 后者逐键覆盖前者。不处理掉它，主题和字体会被静默顶掉。
# 放在用户确认 apply 之后再移，避免“取消安装却已经改了系统”。
if [[ -s "$GHOSTTY_OVERRIDE" ]]; then
  step "发现 macOS 上的 Ghostty 覆盖配置"
  note "$GHOSTTY_OVERRIDE"
  printf '\n'
  sed 's/^/      | /' "$GHOSTTY_OVERRIDE"
  printf '\n'
  note "这份文件会在 dotgraft 的配置之后加载，逐条覆盖主题和字体。"
  if confirm "备份并移开它？"; then
    mkdir -p "$BACKUP_DIR"
    cp -p "$GHOSTTY_OVERRIDE" "$BACKUP_DIR/ghostty-config.macos-override" ||
      fail "无法备份 $GHOSTTY_OVERRIDE"

    if [[ -e "$GHOSTTY_OVERRIDE.before-dotgraft" ]]; then
      # 已经有一份更早的原配置，不要覆盖它；把当前这份放到本次备份里。
      GHOSTTY_OVERRIDE_SAVED="$BACKUP_DIR/ghostty-config.replaced"
      mv "$GHOSTTY_OVERRIDE" "$GHOSTTY_OVERRIDE_SAVED"
      note "保留已有 .before-dotgraft，当前文件备份到 $GHOSTTY_OVERRIDE_SAVED"
    else
      GHOSTTY_OVERRIDE_SAVED="$GHOSTTY_OVERRIDE.before-dotgraft"
      mv "$GHOSTTY_OVERRIDE" "$GHOSTTY_OVERRIDE_SAVED"
      note "已备份到 $BACKUP_DIR/ghostty-config.macos-override"
    fi
    GHOSTTY_OVERRIDE_MOVED=1
  else
    note "保留不动。注意：Ghostty 的主题和字体可能不会变成你选的样子。"
  fi
fi

# ==============================================================================
# 落盘
# ==============================================================================
step "应用配置"
chezmoi apply
# apply 成功后再失败（例如后面的提示）不应该恢复覆盖文件。
GHOSTTY_OVERRIDE_MOVED=0

# ==============================================================================
# 完成
# ==============================================================================
cat << 'DONE'

==> 完成

    下一步：

      1. 开一个新的终端窗口（或执行 `exec zsh`）让 zsh 配置生效
      2. 如果 Ghostty 正在运行，按 Cmd+Shift+, 重新加载配置

    之后常用的命令：

      dotgraft status        看看现在是什么状态
      dotgraft diff          改完配置先预览
      dotgraft update        拉取上游更新
      dotgraft deps          修复没装上的依赖
      dotgraft reconfigure   改选配（重新问那几个问题）
      dotgraft uninstall     卸载

DONE

if [[ -d "$BACKUP_DIR" ]]; then
  printf '    本次备份：%s\n\n' "$BACKUP_DIR"
fi
