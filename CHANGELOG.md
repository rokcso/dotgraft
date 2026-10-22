# Changelog

## 0.1.0

首个可持续发布版本。

- Ghostty + Starship + zsh 终端配置
- 独立 chezmoi source/config，可与已有 chezmoi 共存
- Dotgraft Ink / Paper / Porcelain 三套品牌主题
- Starship 与主题自动联动
- 备份、恢复、卸载和 Ghostty 覆盖文件处理
- 非交互安装
- 主题契约、对比度和 smoke 测试
- 发布前在 macOS 14 / latest 运行完整 smoke，避免未验证的 tag 直接发布
- release notes 从本文件对应版本段落生成
- 修复 macOS Bash 3.2 下非 zsh `$SHELL` 时 doctor 的变量解析问题
- 修复 Ghostty cask 未加入 PATH 时 doctor 误报
