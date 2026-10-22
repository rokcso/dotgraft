# Dotgraft

> 把终端嫁接任何一台机器上。

Dotgraft 是一套由 [chezmoi](https://www.chezmoi.io) 管理的 macOS 终端配置：**Ghostty + Starship + zsh**。仓库就是实际运行的配置本体，既是作者自己几台机器的同步源，也是别人的一条安装命令。

Created by rokcso · 源码与反馈：<https://github.com/rokcso/dotgraft>

## 设计取向

多数「终端一键配置」脚本把文件复制到位、往 `~/.zshrc` 追加一段，只能成功一次：仓库和机器从此各走各的，更新到不了你手上，也撤不干净。

Dotgraft 换了个前提——**配置是声明式的，机器是收敛出来的**：

- **幂等**：`dotgraft apply`（底层 `chezmoi apply`）跑一百次结果一样
- **可预览**：`dotgraft diff` 先看再改
- **可更新**：`dotgraft update` 拉取上游、预览、应用，并修复依赖
- **可共处**：只维护 `~/.zshrc` 里的一小段标记区块，其余字节不动
- **可选配**：组件在安装时勾选；取消勾选会删除对应配置片段（**不会**自动卸载 Homebrew 包）
- **可撤销**：`dotgraft uninstall` 会先备份受管文件和已有配置，再删除；能恢复 bootstrap 移开的 Ghostty 覆盖配置

## 快速开始

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rokcso/dotgraft/main/bootstrap.sh)
```

脚本会检查环境、安装 chezmoi、问你几个选配问题、展示完整 diff，确认后才落盘。

安装固定 release 版本：

```bash
DOTGRAFT_REF=v0.1.0 \
  bash <(curl -fsSL https://raw.githubusercontent.com/rokcso/dotgraft/v0.1.0/bootstrap.sh)
```

`DOTGRAFT_REF` 会让 `chezmoi init` checkout 对应的 tag；release 安装的 source 是固定 tag，日常 `dotgraft update` 不会自动跨版本更新。

非交互安装（CI / 新机器 / 自动化）：

```bash
DOTGRAFT_YES=1 \
DOTGRAFT_TOOLS="fzf,zoxide,eza,bat,yazi" \
DOTGRAFT_THEME="Dotgraft Ink" \
DOTGRAFT_GLASS=true \
  bash <(curl -fsSL https://raw.githubusercontent.com/rokcso/dotgraft/main/bootstrap.sh)
```

也可以传参：`bootstrap.sh --yes --tools=fzf,zoxide --theme="Dotgraft Paper" --glass=false`。

Dotgraft 使用**独立 source/config**，不会占用默认的 `~/.local/share/chezmoi`，也不会改你的 `~/.config/chezmoi`：

```
source:  ${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi-dotgraft
config:  ${XDG_CONFIG_HOME:-$HOME/.config}/dotgraft/chezmoi.toml
```

已经在用 chezmoi 也可以直接装，两边互不影响。手动等价命令：

```bash
chezmoi \
  --source "${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi-dotgraft" \
  --config "${XDG_CONFIG_HOME:-$HOME/.config}/dotgraft/chezmoi.toml" \
  --destination "$HOME" \
  init --apply rokcso/dotgraft
```

> 这条手动路径**只拉配置**，不会装 chezmoi、不会预览 diff，也不会处理 macOS 上的 Ghostty 覆盖文件。依赖会在 `apply` 过程中由 `run_onchange` 脚本补装；如果补装失败，再运行 `dotgraft deps`。日常建议直接用 bootstrap。

## 本地开发安装

正式安装默认从 GitHub `main` clone。开发时想安装**本地当前提交**：

```bash
cd /Users/lin/Developer/GitHub-rokcso/dotgraft
DOTGRAFT_REPO="$PWD" bash bootstrap.sh
exec zsh
dotg status
```

注意：

- `DOTGRAFT_REPO="$PWD"` 只会 clone **已经 commit 的 HEAD**，不会带上未提交的工作区改动。
- 这样安装后，`~/.local/share/chezmoi-dotgraft` 的 `origin` 是本地仓库路径，后续 commit 后可以直接 `dotg update` 从本地拉取。
- 如果之后希望改回从 GitHub 更新，重新用默认 bootstrap 安装，或手动把 source 的 remote 改回 GitHub。

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

## 选配

安装时会问三项，答案存在 `~/.config/dotgraft/chezmoi.toml`，**不进仓库**：

- **CLI 工具**：chezmoi 的勾选列表，空格选择、回车确认
- **Ghostty 主题**：编号菜单，默认 `Dotgraft Ink`；浅色可选 `Dotgraft Paper` 或 `Dotgraft Porcelain`
- **毛玻璃**：编号菜单，输入 `1`（原生）或 `2`（数字模糊）

| 问题 | 作用 |
|---|---|
| 要启用哪些 CLI 工具（多选） | fzf / zoxide / eza / bat / yazi。没勾的不安装，对应配置片段也会被删除；已经装过的 Homebrew 包不会卸载 |
| Ghostty 主题 | `Dotgraft Ink`（深色，默认）/ `Dotgraft Paper`（浅色暖光）/ `Dotgraft Porcelain`（浅色冷光）/ 内置主题 |
| 是否用原生毛玻璃 | 默认值按 macOS 版本决定：macOS 26+ 默认开启（`macos-glass-regular`），更旧的系统默认数字模糊 |

非交互环境可用 `DOTGRAFT_THEME` 和 `DOTGRAFT_GLASS` 跳过菜单：

```bash
DOTGRAFT_THEME="Dotgraft Paper" DOTGRAFT_GLASS=false bash bootstrap.sh
```

随时可以改：

```bash
dotgraft reconfigure
```

## 命令

安装后 `dotgraft` 在 `PATH` 里：

| 命令 | 作用 |
|---|---|
| `dotgraft status` | 当前选配、文件差异、版本 |
| `dotgraft diff [--full]` | 默认显示文件摘要；`--full` 查看完整 diff |
| `dotgraft apply` | 预览、确认、应用 |
| `dotgraft update` | 拉取上游、预览、应用，并运行 `dotgraft deps` |
| `dotgraft deps` | 无条件安装/修复 Homebrew 依赖（不受 `run_onchange` 缓存影响） |
| `dotgraft theme [ink\|paper\|porcelain\|list]` | 只切换 Ghostty + Starship 主题，不重新询问工具 |
| `dotgraft backup [list\|show <时间戳>]` | 查看已有备份 |
| `dotgraft restore <时间戳>` | 从备份恢复；恢复前会再备份当前状态 |
| `dotgraft reconfigure` | 重新选配，并修复依赖 |
| `dotgraft edit <文件>` | 编辑受管文件的仓库副本 |
| `dotgraft cd` | 进入 Dotgraft 的 chezmoi 源目录 |
| `dotgraft chezmoi <args>` | 在 Dotgraft 的 source/config 上执行 chezmoi 子命令 |
| `dotgraft doctor` | Dotgraft 专用环境自检；完整 chezmoi 诊断用 `dotgraft chezmoi doctor` |
| `dotgraft version` | 显示版本和 source commit |
| `dotgraft uninstall` | 卸载 |

直接运行 `chezmoi` 会使用你自己的默认 source/config，不会看到 Dotgraft；需要底层命令时用 `dotgraft chezmoi ...`。

`dotgraft diff` 默认只列文件摘要，避免首次安装时把整份新文件打印出来；要看逐行补丁用 `dotgraft diff --full`。

Starship 会根据 Ghostty 主题自动选择调色板：Dotgraft Ink 用 `dotgraft_ink`，Dotgraft Paper 用 `dotgraft_paper`，Dotgraft Porcelain 用 `dotgraft_porcelain`，内置浅色主题使用 `catppuccin_latte`。

如果系统里没有现成的 `dotg` 命令，安装后会自动得到一个短别名：

```bash
dotg status
dotg update
dotg deps
```

`dotgraft` 和 `dotg` 都支持子命令补全：

```bash
dotgraft <Tab>
dotg <Tab>
```

如果 `dotg` 已经被别的命令占用，Dotgraft 不会覆盖它，继续使用完整的 `dotgraft`。

## 主题

内置三套品牌主题：

- **Dotgraft Ink**：深色，默认
- **Dotgraft Paper**：浅色，暖光纸面
- **Dotgraft Porcelain**：浅色，冷光瓷面

```bash
dotgraft theme            # 查看当前主题和可选主题
dotgraft theme ink        # 切到深色
dotgraft theme paper      # 切到暖光浅色
dotgraft theme porcelain  # 切到冷光浅色
```

`dotgraft theme` 只改主题，不重新询问 CLI 工具或毛玻璃。切换后：

```bash
exec zsh
```

Ghostty 里再按 `Cmd + Shift + ,` 重载。完整配色、对比度和 Starship 联动见 [Themes](docs/themes.md)。

## 版本与发布

当前版本见 `VERSION`，变更见 [CHANGELOG.md](CHANGELOG.md)。

```bash
dotgraft version
```

Release tag 使用 `vX.Y.Z`，GitHub Actions 会：

- 校验 tag 与 `VERSION` 一致
- 运行主题契约检查
- 打包源码 tarball 和 bootstrap
- 生成 `SHA256SUMS`
- 发布 GitHub Release

## 会改动哪些文件

受管目标集中在家目录的几处路径，另有 chezmoi 源目录、备份目录和 Ghostty 覆盖文件。不用 `sudo`，不动 `/etc`，**`~/.zprofile` 和 `~/.zshenv` 永不修改**。

| 路径 | 内容 | 方式 |
|---|---|---|
| `~/.zshrc` | 末尾一小段标记区块 | 原地编辑，只动区块 |
| `~/.config/zsh/` | zsh 配置 | 完全接管 |
| `~/.config/zsh/conf.d/90-local.zsh` | 你的机器专属配置 | 只创建一次 |
| `~/.config/ghostty/config` | Ghostty 配置 | 完全接管，走模板 |
| `~/.config/ghostty/themes/` | Dotgraft Ink / Paper / Porcelain 主题 | 完全接管 |
| `~/.config/starship.toml` | Starship 配置 | 完全接管 |
| `~/.local/bin/dotgraft` | 命令本体 | 完全接管 |
| `~/.config/dotgraft/chezmoi.toml` | Dotgraft 独立的选配答案 | 本机生成，不进仓库 |

此外会创建/修改：

| 路径 | 内容 |
|---|---|
| `~/.local/share/chezmoi-dotgraft` | Dotgraft 独立的 chezmoi 源目录（git clone） |
| `~/.config-backup/<时间戳>/` | 已有目标文件、Ghostty 覆盖文件和选配答案的备份 |
| `~/Library/Application Support/com.mitchellh.ghostty/config` | 如果存在，会备份并移开，避免覆盖主题 |

默认的 `~/.local/share/chezmoi` 和 `~/.config/chezmoi/` **不会被写入**。

## 卸载

```bash
dotgraft uninstall
```

会先把所有受管文件、`~/.zshrc`、`~/.config/dotgraft/chezmoi.toml` 备份到 `~/.config-backup/<时间戳>/`（受管文件在 `files/` 下），然后删除受管文件、剥掉 `~/.zshrc` 里的标记区块、清理空目录，并在存在时恢复 bootstrap 移开的 Ghostty 覆盖配置。**不会**卸载 Homebrew 包。

安全边界：

- 如果 `~/.zshrc` 里的 dotgraft 区块不完整，卸载会直接拒绝，避免误删后面的内容。
- 如果 `~/.zshrc` 是软链接，卸载会编辑它指向的真实文件并保留链接；备份里会额外记录 `.zshrc.symlink`。
- 如果当前 chezmoi source 里混有 Dotgraft 之外的受管文件，卸载会列出它们并停止；请先手动处理。
- 只有当 Dotgraft 的独立 source 是干净克隆（无未提交改动、无未推送提交、remote 像 dotgraft）时才会执行 `chezmoi purge`；否则保留 source，并提示你手动确认。

注意 `chezmoi purge` 单独跑是不够的——它按设计会保留所有目标文件。

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
dotgraft restore <时间戳> --pre-existing   # 安装前的原始文件
dotgraft restore <时间戳> --yes            # 非交互
```

`restore` 会先列出要恢复的文件，并在恢复前把当前状态再备份一份。
恢复 shell 配置后执行 `exec zsh`，Ghostty 按 `Cmd + Shift + ,` 重载。

如果已经卸载、`dotgraft` 命令不在 PATH 里，可以直接运行备份中的命令：

```bash
~/.config-backup/<时间戳>/files/.local/bin/dotgraft restore <时间戳>
```

需要恢复 bootstrap 移开的 macOS Ghostty 覆盖文件时，加 `--with-ghostty-override`。

## 文档

| 文档 | 内容 |
|---|---|
| [配置架构](docs/configuration.md) | 仓库结构、chezmoi 属性、片段加载顺序、怎么加新片段和新的选配项 |
| [Ghostty](docs/ghostty.md) | 每一项配置的解释、macOS 覆盖文件陷阱、主题与快捷键、验证命令 |
| [Themes](docs/themes.md) | Dotgraft Ink / Paper / Porcelain 的品牌主题、色板、对比度和切换方式 |
| [Changelog](CHANGELOG.md) | 版本变更记录 |
| [Shell](docs/shell.md) | Starship、三个插件、五个 CLI 工具、别名与函数 |
| [排错](docs/troubleshooting.md) | 装了没效果、补全不生效、字体缺图标、卸载不干净等 |

## 环境要求

- macOS 13 及以上（Apple Silicon / Intel 均可，路径由 `brew --prefix` 解析）
- [Homebrew](https://brew.sh)
- [Ghostty](https://ghostty.org) 1.3 及以上
- 原生毛玻璃需要 macOS 26 及以上；更旧的系统默认使用数字模糊
- 首次安装需要网络

## 状态

已实现：安装、更新、卸载、选配、依赖修复、独立 chezmoi source、CI（shellcheck / shfmt / zsh -n / bats 单元测试 / 渲染后校验 Ghostty 配置）。冒烟测试覆盖安装、重新选配、卸载安全边界、`.zshrc` 损坏状态和依赖失败传播；bats 覆盖路径白名单、区块解析、备份和 purge 判定。验证环境：Ghostty 1.3.1 · Starship 1.27.0 · zsh 5.9 · chezmoi 2.73 · macOS 27。

尚未支持：Linux。Ghostty 的安装方式、字体路径和几个配置项在 Linux 上都不同，而本仓库没有 Linux 环境可验证。欢迎到 [issues](https://github.com/rokcso/dotgraft/issues) 说明发行版。

## 致谢

[Ghostty](https://ghostty.org) · [Starship](https://starship.rs)（`catppuccin-powerline` 预设）· [chezmoi](https://www.chezmoi.io) · [Maple Mono NF](https://github.com/subframe7536/maple-font) · [Catppuccin](https://github.com/catppuccin/catppuccin) · [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) / [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) / [zsh-completions](https://github.com/zsh-users/zsh-completions)

## 许可

[MIT](./LICENSE)
