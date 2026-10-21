# Dotgraft

> 把终端嫁接任何一台机器上。

Dotgraft 是一套由 [chezmoi](https://www.chezmoi.io) 管理的 macOS 终端配置：**Ghostty + Starship + zsh**。仓库就是实际运行的配置本体，既是作者自己几台机器的同步源，也是别人的一条安装命令。

Created by rokcso · 源码与反馈：<https://github.com/rokcso/dotgraft>

## 设计取向

多数「终端一键配置」脚本把文件复制到位、往 `~/.zshrc` 追加一段，只能成功一次：仓库和机器从此各走各的，更新到不了你手上，也撤不干净。

Dotgraft 换了个前提——**配置是声明式的，机器是收敛出来的**：

- **幂等**：`chezmoi apply` 跑一百次结果一样
- **可预览**：`dotgraft diff` 先看再改
- **可更新**：`dotgraft update` 把上游拉进正在用的配置
- **可共处**：只维护 `~/.zshrc` 里的一小段标记区块，其余字节不动
- **可选配**：组件在安装时勾选，取消勾选会被真正移除
- **可撤销**：`dotgraft uninstall` 让 shell 回到安装前

## 快速开始

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rokcso/dotgraft/main/bootstrap.sh)
```

脚本会检查环境、安装 chezmoi、问你几个选配问题、展示完整 diff，确认后才落盘。

已经在用 chezmoi：

```bash
chezmoi init --apply rokcso/dotgraft
```

> 这条路径**只拉配置**，不会装 chezmoi、不会预览 diff，也不会处理 macOS 上的 Ghostty 覆盖文件。依赖会在 `apply` 过程中由 `run_onchange` 脚本补装，但覆盖文件得你自己移开，否则主题静默不生效。手动处理见 [Ghostty 文档](docs/ghostty.md#先看这个macos-上有个会覆盖你的文件)。

## 选配

安装时问三个问题，答案存在 `~/.config/chezmoi/chezmoi.toml`，**不进仓库**：

| 问题 | 作用 |
|---|---|
| 要启用哪些 CLI 工具（多选） | fzf / zoxide / eza / bat / yazi。没勾的不安装，对应配置片段也会被删除 |
| Ghostty 主题 | 写进 Ghostty 配置 |
| 是否用原生毛玻璃 | `macos-glass-regular`（需 macOS 26+）或数字模糊半径 |

随时可以改：

```bash
dotgraft reconfigure
```

## 命令

安装后 `dotgraft` 在 `PATH` 里：

| 命令 | 作用 |
|---|---|
| `dotgraft status` | 当前选配、文件差异、版本 |
| `dotgraft diff` | 预览改动 |
| `dotgraft apply` | 预览、确认、应用 |
| `dotgraft update` | 拉取上游并应用，依赖有变化会重装 |
| `dotgraft reconfigure` | 重新选配 |
| `dotgraft edit <文件>` | 编辑受管文件的仓库副本 |
| `dotgraft cd` | 进入 chezmoi 源目录 |
| `dotgraft doctor` | 环境自检 |
| `dotgraft uninstall` | 卸载 |

底层 `chezmoi` 命令同样可用。

## 会改动哪些文件

七处，不多不少。不用 `sudo`，不动 `/etc`，**`~/.zprofile` 和 `~/.zshenv` 永不修改**。

| 路径 | 内容 | 方式 |
|---|---|---|
| `~/.zshrc` | 末尾一小段标记区块 | 原地编辑，只动区块 |
| `~/.config/zsh/` | zsh 配置 | 完全接管 |
| `~/.config/zsh/conf.d/90-local.zsh` | 你的机器专属配置 | 只创建一次 |
| `~/.config/ghostty/config` | Ghostty 配置 | 完全接管，走模板 |
| `~/.config/starship.toml` | Starship 配置 | 完全接管 |
| `~/.local/bin/dotgraft` | 命令本体 | 完全接管 |
| `~/.config/chezmoi/chezmoi.toml` | 选配答案 | 本机生成，不进仓库 |

## 卸载

```bash
dotgraft uninstall
```

会备份 `90-local.zsh` 和 `~/.zshrc`，删除全部受管文件，剥掉 `~/.zshrc` 里的标记区块，清理空目录，最后清掉 chezmoi 自身状态。**不会**卸载 Homebrew 包。

注意 `chezmoi purge` 单独跑是不够的——它按设计会保留所有目标文件。

## 文档

| 文档 | 内容 |
|---|---|
| [配置架构](docs/configuration.md) | 仓库结构、chezmoi 属性、片段加载顺序、怎么加新片段和新的选配项 |
| [Ghostty](docs/ghostty.md) | 每一项配置的解释、macOS 覆盖文件陷阱、主题与快捷键、验证命令 |
| [Shell](docs/shell.md) | Starship、三个插件、五个 CLI 工具、别名与函数 |
| [排错](docs/troubleshooting.md) | 装了没效果、补全不生效、字体缺图标、卸载不干净等 |

## 环境要求

- macOS 13 及以上（Apple Silicon / Intel 均可，路径由 `brew --prefix` 解析）
- [Homebrew](https://brew.sh)
- [Ghostty](https://ghostty.org) 1.3 及以上
- 首次安装需要网络

## 状态

已实现：安装、更新、卸载、选配、CI（shellcheck / shfmt / zsh -n / 渲染后校验 Ghostty 配置）。验证环境：Ghostty 1.3.1 · Starship 1.27.0 · zsh 5.9 · chezmoi 2.73 · macOS 27。

尚未支持：Linux。Ghostty 的安装方式、字体路径和几个配置项在 Linux 上都不同，而本仓库没有 Linux 环境可验证。欢迎到 [issues](https://github.com/rokcso/dotgraft/issues) 说明发行版。

## 致谢

[Ghostty](https://ghostty.org) · [Starship](https://starship.rs)（`catppuccin-powerline` 预设）· [chezmoi](https://www.chezmoi.io) · [Maple Mono NF](https://github.com/subframe7536/maple-font) · [Catppuccin](https://github.com/catppuccin/catppuccin) · [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) / [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) / [zsh-completions](https://github.com/zsh-users/zsh-completions)

## 许可

[MIT](./LICENSE)
