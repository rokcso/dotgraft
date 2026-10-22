# Dotgraft Theme

[English](../themes.md) · 简体中文

Dotgraft 自带三套内置主题，都是 Ghostty 主题文件，同时配套 Starship 调色板：

| 名称 | 模式 | Ghostty 文件 | Starship palette |
|---|---|---|---|
| **Dotgraft Ink** | 深色，默认 | `Dotgraft Ink` | `dotgraft_ink` |
| **Dotgraft Paper** | 浅色暖光 | `Dotgraft Paper` | `dotgraft_paper` |
| **Dotgraft Porcelain** | 浅色冷光 | `Dotgraft Porcelain` | `dotgraft_porcelain` |

主题文件安装在：

```text
~/.config/ghostty/themes/Dotgraft Ink
~/.config/ghostty/themes/Dotgraft Paper
~/.config/ghostty/themes/Dotgraft Porcelain
```

## 颜色角色

三套主题共用一组颜色角色，方便在深色和浅色之间保持一致的语义：

- **Ground**：代码阅读区的底色
- **Ink**：正文
- **Graft Green**：品牌绿，同时用于绿色 ANSI 和选区
- **Dot**：光标与焦点（琥珀 / 铜 / 蓝）
- **Alert / Signal**：错误与信息

Ink 是深色主题：深绿墨底、暖白前景、琥珀光标。Paper 是暖光浅色：暖纸底、墨绿前景、铜色光标。Porcelain 是冷光浅色：冷白底、蓝黑前景、蓝色光标。

三套主题只设置颜色相关配置。不要在主题文件里设置 `theme`、`config-file`、`keybind` 或 `background-image`。

## 角色规则

```text
Ground / Ink / Dot  → 底色、正文、光标
Graft Green         → 品牌绿，也用于绿色 ANSI 和选区
Alert / Signal      → 错误和信息
ANSI 色相           → 跨主题保持稳定，只调整明度和彩度
Selection           → Graft tint，不引入额外的强调色
```

Paper 和 Porcelain 使用同一个品牌绿；红色、蓝色等保持各自的语义。两套浅色主题主要改变底色、正文、光标和中性色。

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
| Cursor | `#8F4A14` | **5.89** |
| Selection background | `#8FBBA1` | 1.90（对背景） |
| Selection foreground | `#1E3A2F` | **5.75**（对选区背景） |

### Dotgraft Porcelain

| 角色 | Hex | 对背景对比度 |
|---|---|---:|
| Background | `#F2F5F7` | — |
| Foreground | `#1E2A32` | **13.39** |
| Cursor | `#2A648F` | **5.78** |
| Selection background | `#9CC5B2` | 1.74（对背景） |
| Selection foreground | `#17323D` | **7.08**（对选区背景） |

## ANSI 16 色

Paper 和 Porcelain 共用同一组 chromatic ANSI 色；中性色随地面温度微调。Ink 使用同一色相家族的亮色版本。

| # | 角色 | Ink | Ink 对比度 | Paper | Paper 对比度 | Porcelain | Porcelain 对比度 |
|---|---|---|---:|---|---:|---|---:|
| 0 | black | `#212A25` | 1.22 | `#26302B` | 12.07 | `#1E2A32` | 13.39 |
| 1 | red | `#E06C75` | 5.63 | `#B23A48` | 5.18 | `#B23A48` | 5.34 |
| 2 | green | `#8BD49C` | 10.27 | `#2C784B` | 4.77 | `#2C784B` | 4.92 |
| 3 | yellow | `#E5C07B` | 10.41 | `#83631A` | 4.94 | `#83631A` | 5.09 |
| 4 | blue | `#7AA2F7` | 7.14 | `#2F5DA8` | 5.72 | `#2F5DA8` | 5.90 |
| 5 | magenta | `#C99BEA` | 8.01 | `#6B5BA8` | 5.04 | `#6B5BA8` | 5.20 |
| 6 | cyan | `#67D4C4` | 10.10 | `#147371` | 5.00 | `#147371` | 5.16 |
| 7 | white | `#C9D5CD` | 11.89 | `#A8B5AA` | 1.89 | `#A9B7C0` | 1.88 |
| 8 | bright black | `#5A6B61` | 3.18 | `#6B7A70` | 4.00 | `#63737D` | 4.48 |
| 9 | bright red | `#FF8A90` | 7.95 | `#8F2634` | 7.45 | `#8F2634` | 7.69 |
| 10 | bright green | `#A6E3A1` | 12.09 | `#1F5F3A` | 6.75 | `#1F5F3A` | 6.96 |
| 11 | bright yellow | `#FFD08A` | 12.54 | `#6F5415` | 6.29 | `#6F5415` | 6.49 |
| 12 | bright blue | `#9AB8FF` | 9.14 | `#234B8A` | 7.61 | `#234B8A` | 7.84 |
| 13 | bright magenta | `#E0B0FF` | 10.12 | `#5A4A98` | 6.48 | `#5A4A98` | 6.69 |
| 14 | bright cyan | `#8CE8DC` | 12.58 | `#0E5E6C` | 6.56 | `#0E5E6C` | 6.76 |
| 15 | bright white | `#F2F6F3` | 16.48 | `#D8D3C8` | 1.32 | `#D7E1E7` | 1.21 |

说明：

- ANSI `black` 在深色主题里、ANSI `white` / `bright white` 在浅色主题里，天然不适合正文；它们用于底色、边框或背景块。
- Paper 是暖光纸面，Porcelain 是冷光瓷面；两者的 chromatic ANSI 色相同，温度由 Ground/Ink/Dot 表达。
- 红/绿仍遵循终端 ANSI 语义。色盲用户需要配合符号或文字，不能只靠颜色区分 Git 状态。
- 两套浅色主题的选区都使用 Graft tint；Paper 的选区对地面 1.90:1，Porcelain 为 1.74:1，选中文本分别为 5.75 / 7.08:1。

## Starship 联动

`starship.toml.tmpl` 根据 Ghostty 主题自动选择 palette：

| Ghostty 主题 | Starship palette |
|---|---|
| Dotgraft Ink | `dotgraft_ink` |
| Dotgraft Paper | `dotgraft_paper` |
| Dotgraft Porcelain | `dotgraft_porcelain` |
| Catppuccin Latte / GitHub Light Default | `catppuccin_latte` |
| Catppuccin Frappe | `catppuccin_frappe` |
| 其他深色主题 | `catppuccin_mocha` |

Starship 的提示符使用多色显示状态；终端背景保持低对比，避免和代码抢注意力。

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
dotgraft theme porcelain
```

也接受完整主题名和内置主题别名：

```bash
dotgraft theme "Dotgraft Ink"
dotgraft theme "Dotgraft Paper"
dotgraft theme "Dotgraft Porcelain"
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
ghostty +validate-config --config-file="$HOME/.config/ghostty/themes/Dotgraft Porcelain"
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
python3 tests/theme-contract.py
```

`tests/theme-contract.py` 检查角色一致性、AA 对比度、ANSI 色相稳定和 Starship palette。smoke 覆盖三套主题的 Ghostty 校验、Starship palette、主题切换和受管文件白名单。

## 非目标

- 不做图片背景主题
- 不在主题里放 keybind 或 shell 配置
- 不把浅色主题做成深色主题的反色版本
- 暂不随 macOS 深浅色自动切换：Ghostty 支持 `dark:/light:`，但 Starship palette 目前是单值
- 不做通用主题市场；Ink / Paper / Porcelain 是内置主题，其他 Ghostty 主题作为备选
