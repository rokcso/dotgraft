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
#   dotgraft reconfigure   改选配
#   dotgraft uninstall     卸载
#
# 测试时可以覆盖仓库地址：
#   DOTGRAFT_REPO=/path/to/local/repo bash bootstrap.sh
# ==============================================================================

set -eu

REPO_URL="${DOTGRAFT_REPO:-https://github.com/rokcso/dotgraft.git}"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$HOME/.config-backup/$STAMP"
GHOSTTY_OVERRIDE="$HOME/Library/Application Support/com.mitchellh.ghostty/config"

step() { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
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
      4. 落盘，并安装 Homebrew 依赖

    会碰到的位置：
      ~/.zshrc                          末尾插入一小段标记区块
      ~/.config/zsh/                    zsh 配置
      ~/.config/ghostty/config          终端配置
      ~/.config/starship.toml           提示符配置
      ~/.local/bin/dotgraft             dotgraft 命令
      ~/.config/chezmoi/chezmoi.toml    你的选配答案（不进仓库）

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

# ==============================================================================
# macOS 上 Ghostty 的覆盖文件
# ==============================================================================
# Ghostty 会先读 ~/.config/ghostty/config，再读 Application Support 里的那份，
# 后者逐键覆盖前者。不处理掉它，主题和字体会被静默顶掉。
if [[ -s "$GHOSTTY_OVERRIDE" ]]; then
  step "发现 macOS 上的 Ghostty 覆盖配置"
  note "$GHOSTTY_OVERRIDE"
  printf '\n'
  sed 's/^/      | /' "$GHOSTTY_OVERRIDE"
  printf '\n'
  note "这份文件会在 dotgraft 的配置之后加载，逐条覆盖主题和字体。"
  if confirm "备份并移开它？"; then
    mkdir -p "$BACKUP_DIR"
    cp "$GHOSTTY_OVERRIDE" "$BACKUP_DIR/ghostty-config.macos-override"
    mv "$GHOSTTY_OVERRIDE" "$GHOSTTY_OVERRIDE.before-dotgraft"
    note "已备份到 $BACKUP_DIR/ghostty-config.macos-override"
  else
    note "保留不动。注意：Ghostty 的主题和字体可能不会变成你选的样子。"
  fi
fi

# ==============================================================================
# 选配问答 + 拉取配置
# ==============================================================================
step "选择要启用的组件"
note "（下面三个问题由 chezmoi 提问，答案只保存在本机）"
printf '\n'

chezmoi init "$REPO_URL"

# ==============================================================================
# 预览
# ==============================================================================
step "将要发生的改动"

diff_output="$(chezmoi diff --no-pager 2>&1 || true)"
if [[ -z "$diff_output" ]]; then
  note "没有待应用的改动，已经是最新的。"
else
  printf '%s\n\n' "$diff_output"
  confirm "应用以上改动？" || {
    printf '\n已取消，未改动任何文件。\n'
    exit 0
  }
fi

# ==============================================================================
# 落盘
# ==============================================================================
step "应用配置"
chezmoi apply

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
      dotgraft reconfigure   改选配（重新问那三个问题）
      dotgraft uninstall     卸载

DONE

if [[ -d "$BACKUP_DIR" ]]; then
  printf '    本次备份：%s\n\n' "$BACKUP_DIR"
fi
