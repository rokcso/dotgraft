# 使用与维护

[English](../usage.md) · 简体中文

安装之后的日常操作、文件落点、备份恢复和卸载。

## 安装后

安装完成后：

```bash
exec zsh
dotgraft status
```

`dotgraft status` 会显示当前主题、工具选配、文件差异和版本。如果 Ghostty 已经打开，按 `Cmd + Shift + ,` 重载配置。

## 日常命令

| 命令 | 作用 |
|---|---|
| `dotgraft status` | 选配、文件差异、版本 |
| `dotgraft diff` | 默认显示文件摘要 |
| `dotgraft diff --full` | 完整逐行 diff |
| `dotgraft apply` | 预览、确认、应用 |
| `dotgraft update` | 拉取上游、预览、应用，并修复依赖 |
| `dotgraft deps` | 无条件安装/修复 Homebrew 依赖 |
| `dotgraft reconfigure` | 重新选配，并修复依赖 |
| `dotgraft theme [ink\|paper\|porcelain\|list]` | 切换主题 |
| `dotgraft backup [list\|show <时间戳>]` | 查看备份 |
| `dotgraft restore <时间戳>` | 从备份恢复 |
| `dotgraft edit <文件>` | 编辑受管文件的仓库副本 |
| `dotgraft cd` | 进入 Dotgraft 的 chezmoi 源目录 |
| `dotgraft chezmoi <args>` | 在 Dotgraft 的 source/config 上执行 chezmoi |
| `dotgraft doctor` | Dotgraft 环境自检 |
| `dotgraft chezmoi doctor` | 完整 chezmoi 诊断 |
| `dotgraft version` | 版本和 source commit |
| `dotgraft uninstall` | 卸载 |

`dotgraft diff` 默认只列文件摘要，避免首次安装时打印整份新文件。需要逐行补丁时用 `dotgraft diff --full`。

安装后如果 `dotg` 没有被其他命令占用，会得到一个短别名：

```bash
dotg status
dotg update
dotg deps
```

`dotgraft` 和 `dotg` 都支持子命令补全。`dotg` 已被占用时不会覆盖，继续用完整的 `dotgraft`。

## 选配

安装时会问三项，答案写在 `~/.config/dotgraft/chezmoi.toml`，不进仓库：

| 问题 | 作用 |
|---|---|
| CLI 工具 | fzf / zoxide / eza / bat / yazi。没勾选的不安装，对应配置片段也会删除；已安装的 Homebrew 包不会卸载 |
| Ghostty 主题 | Dotgraft Ink（默认）、Paper、Porcelain，或内置主题 |
| 毛玻璃 | macOS 26+ 默认原生玻璃，更旧的系统默认数字模糊 |

随时可以改：

```bash
dotgraft reconfigure
```

非交互环境可以用环境变量跳过菜单：

```bash
DOTGRAFT_THEME="Dotgraft Paper" \
DOTGRAFT_GLASS=false \
  dotgraft reconfigure
```

选配的实现方式见 [配置架构](configuration.md#选配是怎么生效的)。

## 主题

```bash
dotgraft theme            # 查看当前主题和可选主题
dotgraft theme ink        # 深色
dotgraft theme paper      # 暖光浅色
dotgraft theme porcelain  # 冷光浅色
```

`dotgraft theme` 只修改 Ghostty 和 Starship，不重新询问工具或毛玻璃。切换后：

```bash
exec zsh
```

再在 Ghostty 里按 `Cmd + Shift + ,` 重载。完整色板和对比度见 [Themes](themes.md)。

## 本地开发安装

正式安装默认从 GitHub `main` clone。开发时想安装本地当前提交：

```bash
cd /Users/lin/Developer/GitHub-rokcso/dotgraft
DOTGRAFT_REPO="$PWD" bash bootstrap.sh
exec zsh
dotg status
```

注意：

- `DOTGRAFT_REPO="$PWD"` 只会 clone **已经 commit 的 HEAD**，不会带上未提交改动。
- 安装后，`~/.local/share/chezmoi-dotgraft` 的 `origin` 是本地仓库路径，后续 commit 后可以直接 `dotg update`。
- 想改回从 GitHub 更新，重新用默认 bootstrap 安装，或手动修改 source 的 remote。

不想每改一次就 commit，可以直接让 `dotgraft` 使用工作区作为 source：

```bash
DOTGRAFT_SOURCE="$PWD" \
DOTGRAFT_CONFIG="$HOME/.config/dotgraft/chezmoi.toml" \
dotgraft diff

DOTGRAFT_SOURCE="$PWD" \
DOTGRAFT_CONFIG="$HOME/.config/dotgraft/chezmoi.toml" \
dotgraft apply
```

这会用当前工作区（包括未提交改动）直接同步到真实 `$HOME`。改 shell 配置后记得 `exec zsh`。

## 文件落点

受管目标集中在家目录的几处路径。不用 `sudo`，不动 `/etc`，`~/.zprofile` 和 `~/.zshenv` 永不修改。

| 路径 | 内容 | 方式 |
|---|---|---|
| `~/.zshrc` | 末尾一小段标记区块 | 原地编辑，只动区块 |
| `~/.config/zsh/` | zsh 配置 | 完全接管 |
| `~/.config/zsh/conf.d/90-local.zsh` | 机器专属配置 | 只创建一次 |
| `~/.config/ghostty/config` | Ghostty 配置 | 完全接管，走模板 |
| `~/.config/ghostty/themes/` | Dotgraft Ink / Paper / Porcelain | 完全接管 |
| `~/.config/starship.toml` | Starship 配置 | 完全接管 |
| `~/.local/bin/dotgraft` | 命令本体 | 完全接管 |
| `~/.config/dotgraft/chezmoi.toml` | 选配答案 | 本机生成，不进仓库 |

此外会创建或修改：

| 路径 | 内容 |
|---|---|
| `~/.local/share/chezmoi-dotgraft` | 独立 chezmoi 源目录（git clone） |
| `~/.config-backup/<时间戳>/` | 已有目标文件、Ghostty 覆盖文件和选配答案的备份 |
| `~/Library/Application Support/com.mitchellh.ghostty/config` | 如果存在，会备份并移开，避免覆盖主题 |

默认的 `~/.local/share/chezmoi` 和 `~/.config/chezmoi/` 不会被写入。

## 备份与恢复

安装、卸载和 `restore` 会把备份写到：

```text
~/.config-backup/<时间戳>/
```

查看：

```bash
dotgraft backup list
dotgraft backup show <时间戳>
```

恢复：

```bash
dotgraft restore <时间戳>
dotgraft restore <时间戳> --pre-existing     # 安装前的原始文件
dotgraft restore <时间戳> --yes              # 非交互
```

`restore` 会先列出待恢复文件，并在恢复前把当前状态再备份一份。恢复 shell 配置后执行 `exec zsh`，Ghostty 按 `Cmd + Shift + ,` 重载。

如果已经卸载、`dotgraft` 不在 `PATH` 里，可以直接运行备份中的命令：

```bash
~/.config-backup/<时间戳>/files/.local/bin/dotgraft restore <时间戳>
```

需要恢复 bootstrap 移开的 macOS Ghostty 覆盖文件时，加 `--with-ghostty-override`。

## 卸载

```bash
dotgraft uninstall
```

卸载会先把所有受管文件、`~/.zshrc`、`~/.config/dotgraft/chezmoi.toml` 备份到 `~/.config-backup/<时间戳>/`（受管文件在 `files/` 下），然后删除受管文件、移除 `~/.zshrc` 里的标记区块、清理空目录，并在存在时恢复 bootstrap 移开的 Ghostty 覆盖配置。**不会**卸载 Homebrew 包。

安全边界：

- `~/.zshrc` 里的 dotgraft 区块不完整时，卸载会拒绝执行，避免误删后面的内容。
- `~/.zshrc` 是软链接时，会编辑它指向的真实文件并保留链接；备份里会记录 `.zshrc.symlink`。
- 当前 source 里混有 Dotgraft 之外的受管文件时，卸载会列出并停止。
- 只有当 Dotgraft 的独立 source 是干净克隆（无未提交改动、无未推送提交、remote 像 dotgraft）时，才会执行 `chezmoi purge`；否则保留 source。

`chezmoi purge` 单独运行不会删除目标文件，这是 chezmoi 的预期行为。正确卸载用 `dotgraft uninstall`。

## 版本

```bash
dotgraft version
```

当前版本号见 `VERSION`，变更见 [CHANGELOG.md](../../CHANGELOG.md)。发布和 CI 流程见 [配置架构](configuration.md#ci)。
