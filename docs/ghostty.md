# Ghostty 配置

配置文件由 Dotgraft 管理，位置 `~/.config/ghostty/config`，源文件是 `dot_config/ghostty/config.tmpl`。

改完生效方式：

```bash
dotgraft apply         # 同步 Dotgraft 的独立 source 到家目录
# 然后在 Ghostty 里按 Cmd + Shift + ,
```

## 先看这个：macOS 上有个会覆盖你的文件

Ghostty 的配置加载顺序（1.3 的 `Config.zig:loadDefaultFiles`）：

```
默认值 → $XDG_CONFIG_HOME/ghostty/config → ~/Library/Application Support/com.mitchellh.ghostty/config → CLI 参数 → 递归 include
```

关键点：**Application Support 那份在 XDG 之后加载，逐键覆盖**。

Ghostty 首次启动会在 `~/Library/Application Support/com.mitchellh.ghostty/config` 生成一个模板文件。只要它存在且写了某个键，你在 `~/.config/ghostty/config` 里写的同名键就被顶掉。

实测（XDG 写 `theme = Dracula`，Application Support 留着旧的三行）：

```
font-size = 99          ← XDG 生效（App Support 没这个键）
theme = GitHub Dark     ← XDG 被覆盖
background = #0d1117    ← XDG 被覆盖
```

所以 `bootstrap.sh` 会检测这个文件，打印内容、备份到 `~/.config-backup/<时间戳>/`，征求同意后改名为 `config.before-dotgraft`；`dotgraft uninstall` 会把它恢复回去。手动处理：

```bash
mv "$HOME/Library/Application Support/com.mitchellh.ghostty/config" \
   "$HOME/Library/Application Support/com.mitchellh.ghostty/config.before-dotgraft"
```

## 逐项说明

### 主题

```
theme = {{ .theme }}
```

内置主题用 `ghostty +list-themes` 列出，加 `--preview` 可以逐个预览配色。

想跟随系统深浅色切换，写成一对：

```
theme = dark:Catppuccin Mocha,light:Catppuccin Latte
```

**不要在配置里再写 `background`。** 主题已经定义了底色（Catppuccin Mocha 是 `#1e1e2e`），手写 `background` 会把它顶掉，等于白换主题。

### 字体

```
font-family = "Maple Mono NF CN"
font-size = 13
font-thicken = true
```

- 必须是 **Nerd Font** 版本，否则图标、powerline 分隔符会缺字。
- 这里用 **CN** 版：带中文字形，中文不会回退到系统其他字体。如果你装的是非 CN 版，族名要写 `"Maple Mono NF"`，少了 CN 就对不上。
- `font-thicken` 是 macOS 专属，加一层描边，Retina 屏上更清晰。

确认字体真的命中（这条比肉眼看更可靠）：

```bash
ghostty +show-face --string="a中"
# U+61 « a » found in face "Maple Mono NF CN".
# U+4E2D « 中 » found in face "Maple Mono NF CN".
```

列所有可用字体族名：`ghostty +list-fonts`。

### 窗口

```
window-padding-x = 12
window-padding-y = 8
window-padding-balance = true
background-opacity = 0.92
```

- `window-padding-*` 单位是点，会随屏幕 DPI 缩放。
- 视口通常不能被字符尺寸整除，`window-padding-balance` 把这点余量均分到四边，画面更居中。
- `background-opacity` 0.92 是「能透出壁纸但不干扰读代码」的档位，低于 0.85 开始影响观感。

### 毛玻璃

选配决定一行。默认答案按系统版本决定：macOS 26+ 默认选原生，更旧的系统默认数字模糊。

```
# 选「原生」且 macOS ≥ 26：
background-blur = macos-glass-regular

# 否则：
background-blur = 20
```

- 数字是模糊强度，只有 `background-opacity < 1` 时才有意义。20 比较稳，超过 30 可能出现渲染异常和掉帧。
- macOS 26 起额外支持 `macos-glass-regular`（标准玻璃）和 `macos-glass-clear`（高透明玻璃），比数字模糊更贴合系统观感。`true` 等价于强度 20。

### 标题栏与窗口状态

```
macos-titlebar-style = native
window-save-state = always
```

- `native`：标准 macOS 标题栏，tab 信息稳定可见，是默认选择。
- `tabs`：自定义标题栏，把 tab bar 嵌进标题栏。部分 macOS/Ghostty 组合下可能出现 tab 标签不可见的问题；如果遇到，改回 `native` 或 `transparent`。
- `transparent`：标准结构但标题栏透明；`hidden`：完全隐藏标题栏。
- `window-save-state = always`：退出后保留窗口位置、尺寸、标签页、分屏布局。分屏还能回到原来的工作目录，这依赖下面的 shell 集成。

### 光标

```
cursor-style = bar
cursor-style-blink = true
```

取值：`bar` / `block` / `underline` / `block_hollow`。

注意：开了 shell 集成后，它会在提示符处强制把光标改成竖线。想让这里的设置始终优先，加上：

```
shell-integration-features = no-cursor
```

### 交互

```
mouse-hide-while-typing = true
confirm-close-surface = false
```

选中即复制在 macOS 上本来就是默认行为（`copy-on-select = true`），不需要显式写。

### Shell 集成

```
shell-integration = zsh
```

提供提示符跳转、工作目录传递、命令边界标记。上面 `window-save-state` 能恢复工作目录、以及 `Cmd+F` 的搜索定位，都依赖它。

它同时也是那个会动 `ZDOTDIR` 的东西——详见[配置架构](configuration.md#为什么不用-zdotdir)。

## 可选增强

这些默认关着，需要时取消注释：

| 配置 | 作用 |
|---|---|
| `minimum-contrast = 1.1` | 前景和背景过于接近时自动拉开对比，避免「看不见的文字」。1 = 不干预 |
| `notify-on-command-finish = unfocused` | 命令跑完且窗口不在前台时发系统通知，配长任务有用 |
| `background-blur = macos-glass-regular` | 系统原生玻璃（macOS 26+） |
| `keybind = global:cmd+shift+space=toggle_quick_terminal` | 快速终端热键 |

### 快速终端

从屏幕边缘呼出一块临时终端，类似 Guake / iTerm2 的 hotkey window。默认不绑定快捷键。

```
keybind = global:cmd+shift+space=toggle_quick_terminal
quick-terminal-position = top        # top / bottom / left / right / center
quick-terminal-screen = mouse        # main / mouse / macos-menu-bar
```

**语法坑**：触发器里不能有空格，等号是紧贴的。下面这样写会报 `InvalidAction`：

```
keybind = global:cmd+shift+space = toggle_quick_terminal    ✗
keybind = global:cmd+shift+space=toggle_quick_terminal      ✓
```

另外 `` ` `` 只能写成 `` cmd+` ``，写 `cmd+grave` 是无效的。

## 快捷键

Ghostty 1.3.1 的默认绑定，用 `ghostty +list-keybinds` 核对：

| 快捷键 | 动作 |
|---|---|
| `Cmd+T` | 新建标签页 |
| `Cmd+D` / `Cmd+Shift+D` | 右侧分屏 / 下方分屏 |
| `Cmd+[` / `Cmd+]` | 焦点切到上一个 / 下一个分屏 |
| `Cmd+Alt+方向键` | 焦点朝对应方向移动 |
| `Cmd+Shift+Enter` | 当前分屏最大化（切换） |
| `Cmd+W` | 关闭当前分屏 |
| `Cmd+Alt+W` | 关闭标签页 |
| `Cmd+=` / `Cmd+-` / `Cmd+0` | 字号放大 / 缩小 / 复位（临时，不改配置） |
| `Cmd+,` | 打开配置文件 |
| `Cmd+Shift+,` | 重新加载配置 |
| `Cmd+F` / `Cmd+E` | 搜索 / 搜索选中内容 |
| `Cmd+Shift+P` | 命令面板 |

改任何一条都写 `keybind = trigger=action`。

## 验证与调试

Ghostty 自带一套面向配置的 CLI 动作，`ghostty +help` 可以看到全部：

| 命令 | 用途 |
|---|---|
| `+validate-config` | 校验配置文件是否合法（当前这个模板要**先渲染**） |
| `+show-config` | 打印当前生效的配置（合并了所有来源） |
| `+show-config --default --docs` | 打印全部 600+ 选项和文档 |
| `+show-face --string="a中"` | 查某个字符实际命中哪个字体 |
| `+list-themes` / `+list-fonts` / `+list-keybinds` / `+list-colors` / `+list-actions` | 枚举 |
| `+edit-config` | 用 `$EDITOR` 打开配置文件 |

校验 Dotgraft 的模板要先渲染：

```bash
ghostty +validate-config --config-file=<(chezmoi execute-template < dot_config/ghostty/config.tmpl)
```

直接拿 `config.tmpl` 去校验会报 `unknown field`，因为它是 Go 模板，不是配置。

想确认某个键到底生效了没有：

```bash
ghostty +show-config | grep '^theme'
```

## 版本差异

配置键会随 Ghostty 版本变化。某个键在新版里改名或删除时，Ghostty 启动会提示。当前配置在 **1.3.1** 上通过 `+validate-config`。用其他版本时如果报错，带上 `ghostty +version` 的输出开 issue。
