# Dotgraft Theme

Dotgraft 自带两套品牌主题，都是 Ghostty 主题文件，同时配套 Starship 调色板：

| 名称 | 模式 | Ghostty 文件 | Starship palette |
|---|---|---|---|
| **Dotgraft Ink** | 深色，默认 | `Dotgraft Ink` | `dotgraft_ink` |
| **Dotgraft Paper** | 浅色 | `Dotgraft Paper` | `dotgraft_paper` |

主题文件安装在：

```text
~/.config/ghostty/themes/Dotgraft Ink
~/.config/ghostty/themes/Dotgraft Paper
```

## 设计意图

Dotgraft 的视觉语言不是“黑底霓虹”，也不是把浅色主题简单反色。两套主题共享同一组角色和语义：

- **地面（Ground）**：长时间阅读代码的底色
- **墨色（Ink）**：正文
- **Graft Green**：品牌主信号，也是绿色 ANSI 语义
- **Dot Amber**：光标与焦点
- **Alert / Signal**：错误与信息语义

Ink 是夜间工作台：深绿墨底、暖白前景、琥珀光标。  
Paper 是日间阅读面：暖纸底、墨绿前景、深绿光标。

两套主题都只设置颜色相关配置。不要在主题文件里设置 `theme`、`config-file`、`keybind` 或 `background-image`。

## 基础色与对比度

对比度按 WCAG 相对亮度计算，文本目标为 AA（4.5:1）以上。

### Dotgraft Ink

| 角色 | Hex | 对背景对比度 |
|---|---|---:|
| Background | `#121816` | — |
| Foreground | `#D8E3DA` | **13.63** |
| Cursor | `#F2B36B` | **9.79** |
| Selection background | `#345A4A` | 2.32（对背景） |
| Selection foreground | `#F0F7F2` | **7.13**（对选区背景） |

### Dotgraft Paper

| 角色 | Hex | 对背景对比度 |
|---|---|---:|
| Background | `#F4F1E8` | — |
| Foreground | `#26302B` | **12.07** |
| Cursor | `#2F6F5E` | **5.23** |
| Selection background | `#A8C9B6` | 1.59（对背景） |
| Selection foreground | `#1E3A2F` | **6.87**（对选区背景） |

## ANSI 16 色

| # | 角色 | Ink | Ink 对比度 | Paper | Paper 对比度 |
|---|---|---|---:|---|---:|
| 0 | black | `#212A25` | 1.22 | `#26302B` | 12.07 |
| 1 | red | `#E06C75` | 5.63 | `#B23A48` | 5.18 |
| 2 | green | `#8BD49C` | 10.27 | `#2F7D4F` | 4.46 |
| 3 | yellow | `#E5C07B` | 10.41 | `#8A6A1F` | 4.47 |
| 4 | blue | `#7AA2F7` | 7.14 | `#2F5DA8` | 5.72 |
| 5 | magenta | `#C99BEA` | 8.01 | `#7A4E9E` | 5.45 |
| 6 | cyan | `#67D4C4` | 10.10 | `#167A78` | 4.55 |
| 7 | white | `#C9D5CD` | 11.89 | `#A8B5AA` | 1.89 |
| 8 | bright black | `#5A6B61` | 3.18 | `#6B7A70` | 4.00 |
| 9 | bright red | `#FF8A90` | 7.95 | `#8F2634` | 7.45 |
| 10 | bright green | `#A6E3A1` | 12.09 | `#1F5F3A` | 6.75 |
| 11 | bright yellow | `#FFD08A` | 12.54 | `#6F5415` | 6.29 |
| 12 | bright blue | `#9AB8FF` | 9.14 | `#234B8A` | 7.61 |
| 13 | bright magenta | `#E0B0FF` | 10.12 | `#633B84` | 7.47 |
| 14 | bright cyan | `#8CE8DC` | 12.58 | `#0E5E5C` | 6.70 |
| 15 | bright white | `#F2F6F3` | 16.48 | `#D8D3C8` | 1.32 |

说明：

- ANSI `black` 在深色主题里、ANSI `white` / `bright white` 在浅色主题里，天然不适合正文；它们用于底色、边框或背景块。
- 红/绿仍遵循终端 ANSI 语义。色盲用户需要配合符号或文字，不能只靠颜色区分 Git 状态。
- Paper 的选区背景对地面只有 1.59:1，这是浅色主题的正常范围；选中文本本身有 6.87:1。

## Starship 联动

`starship.toml.tmpl` 根据 Ghostty 主题自动选择 palette：

| Ghostty 主题 | Starship palette |
|---|---|
| Dotgraft Ink | `dotgraft_ink` |
| Dotgraft Paper | `dotgraft_paper` |
| Catppuccin Latte / GitHub Light Default | `catppuccin_latte` |
| Catppuccin Frappe | `catppuccin_frappe` |
| 其他深色主题 | `catppuccin_mocha` |

Starship 是 Dotgraft 里唯一允许“多色说话”的表面。终端地面保持安静，提示符承担品牌和状态信号。

## 切换主题

列出当前主题和可用主题：

```bash
dotgraft theme
dotgraft theme list
```

切换：

```bash
dotgraft theme ink
dotgraft theme paper
```

也接受完整主题名和内置主题别名：

```bash
dotgraft theme "Dotgraft Ink"
dotgraft theme "Dotgraft Paper"
dotgraft theme mocha
dotgraft theme latte
```

`dotgraft theme` 只改主题，不重新询问工具或毛玻璃。它会更新独立的 `chezmoi.toml`，然后只 apply：

```text
~/.config/ghostty/config
~/.config/starship.toml
```

生效：

```bash
exec zsh
```

Ghostty 里再按 `Cmd + Shift + ,` 重载。

## 验证

主题文件：

```bash
ghostty +validate-config --config-file="$HOME/.config/ghostty/themes/Dotgraft Ink"
ghostty +validate-config --config-file="$HOME/.config/ghostty/themes/Dotgraft Paper"
```

主题查找：

```bash
ghostty +list-themes | grep -i dotgraft
```

Starship 渲染：

```bash
STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt
```

项目测试：

```bash
bats tests/unit
bash tests/smoke.sh
```

smoke 覆盖两套主题的 Ghostty 校验、Starship palette、主题切换和受管文件白名单。

## 非目标

- 不做图片背景主题
- 不在主题里放 keybind 或 shell 配置
- 不追求把浅色做成深色的简单反色
- 暂不做随 macOS 深浅色自动切换：Ghostty 可以 `dark:/light:`，但 Starship palette 目前是单值；自动切换需要额外设计
- 不把 Dotgraft 扩张成通用主题市场；Ink / Paper 是品牌主题，内置主题是备选
