# 排错

按症状找。

## 装完了，但 Ghostty 的主题/字体没变

**最可能的原因**：macOS 上还有那份会覆盖的配置文件。

```
~/Library/Application Support/com.mitchellh.ghostty/config
```

它在 `~/.config/ghostty/config` **之后**加载，逐键覆盖。确认：

```bash
ghostty +show-config | grep -E '^(theme|font-family|background) '
```

如果显示的主题不是你选的，就是这个文件在压。bootstrap 会把它备份到 `~/.config-backup/<时间戳>/`，并改名为 `config.before-dotgraft`；`dotgraft uninstall` 会把它恢复回去。

如果你当时拒绝了移开它，可以手动处理：

```bash
mv "$HOME/Library/Application Support/com.mitchellh.ghostty/config" \
   "$HOME/Library/Application Support/com.mitchellh.ghostty/config.before-dotgraft"
```

然后 `Cmd + Shift + ,` 重载。

细节见 [Ghostty 文档](ghostty.md#先看这个macos-上有个会覆盖你的文件)。

## 改了配置但没生效

Ghostty 不会自动重载。按 `Cmd + Shift + ,`。

zsh 配置则要**新开一个 shell**——`init.zsh` 只在新进程启动时 source。最省事的写法：

```bash
exec zsh
```

如果改的是 `conf.d/` 里的文件，先确认已经落到家目录：

```bash
dotgraft diff      # 有输出说明还没 apply
```

## 提示符不是彩虹条

按顺序查：

```bash
command -v starship                      # 有没有装
ls -l ~/.config/starship.toml            # 配置在不在
starship --version
```

三者都在的话，看 `~/.zshrc` 里有没有 dotgraft 区块：

```bash
grep -A3 '>>> dotgraft >>>' ~/.zshrc
```

没有就说明安装没走完，跑 `dotgraft apply`。如果报依赖缺失，再跑 `dotgraft deps`。

还有一种情况：别的工具在 dotgraft 区块**之后**又设置了 `PROMPT`，把它覆盖了。检查 `~/.zshrc` 里 dotgraft 区块之后的内容。

## 补全没生效 / compinit 报 insecure directories

`compinit` 的报错通常是权限问题。Homebrew 目录大多 root 所有，zsh 会认为「不安全」并拒绝加载。

Dotgraft 已经用 `compinit -u` 接受这类目录。如果还有警告，多半来自 `~/.zshrc` 里别的工具自己调的 `compinit`：

```bash
grep -n compinit ~/.zshrc
```

想把 `zcompdump` 重建：

```bash
rm -f ~/.zcompdump* && exec zsh
```

## Tab 补全找不到新装的命令

补全缓存过期了：

```bash
rm -f ~/.zcompdump* && exec zsh
```

## 字体图标显示成方块 / 中文是别的字体

确认字体真的命中：

```bash
ghostty +show-face --string="a中"
```

期望输出形如：

```
U+61 « a » found in face "Maple Mono NF CN".
U+4E2D « 中 » found in face "Maple Mono NF CN".
```

如果报找不到，或者中文命中的是别的字体：

1. 字体没装 → `brew install --cask font-maple-mono-nf-cn`
2. 族名写错 → `ghostty +list-fonts | grep -i maple` 看准确名称。CN 版必须写 `"Maple Mono NF CN"`，少了 CN 对不上。

## `brew bundle` 报字体冲突

```
Error: font-maple-mono-nf-cn: It seems the existing Font is different from the one being installed.
```

原因是你之前手动装过 Maple Mono（比如从 GitHub 下 ttf 拖进字体册），cask 想「采纳」同名但二进制不同的文件，拒绝了。

Dotgraft 的安装脚本已经处理：检测到 `~/Library/Fonts` 或 `/Library/Fonts` 里有 **Maple ... CN** 的字体就跳过。以前只匹配 `maple`，会把非 CN 版误判成已安装；现在只认 CN 版。如果你在别处手动跑 `brew bundle` 撞到，忽略即可——字体已经在了。

## `dotgraft: command not found`

它装在 `~/.local/bin/dotgraft`，这个目录要进 `PATH`。`init.zsh` 会加，但前提是 dotgraft 区块在 `~/.zshrc` 里。

临时用：

```bash
~/.local/bin/dotgraft status
```

## `chezmoi purge` 之后文件还在

这是设计如此，不是 bug。`chezmoi purge` 的说明是「删除 chezmoi 的配置、状态和源目录，**但保留目标状态**」。

正确卸载用 `dotgraft uninstall`，它会自己清理目标文件。手动的话：

```bash
chezmoi managed --include=files --path-style=absolute
```

列出来的就是需要删的路径（`~/.zshrc` 除外，它只删区块）。`dotgraft uninstall` 现在会先检查白名单和 `.zshrc` 区块完整性，再备份和删除；如果它拒绝执行，先按错误提示处理，不要强行删。

## 卸载后 shell 报错

多半是 `~/.zshrc` 里还留着来源不明的行。检查：

```bash
grep -n 'dotgraft\|\.config/zsh' ~/.zshrc
```

`dotgraft uninstall` 会把 `~/.zshrc` 备份到 `~/.config-backup/<时间戳>/files/.zshrc`，可以直接比对：

```bash
diff ~/.config-backup/<时间戳>/files/.zshrc ~/.zshrc
```

## zsh 启动变慢

先量：

```bash
time zsh -i -c exit
```

常见原因：

- **重复 `compinit`**。Dotgraft 会跑一次（见[配置架构](configuration.md#片段加载顺序)），如果 `~/.zshrc` 里还有别的工具也跑，累计会慢。用 `zprof` 定位：

  ```zsh
  # 临时在 ~/.zshrc 最前面加一行
  zmodload zsh/zprof
  # 末尾加一行
  zprof
  ```

- **插件重复加载**。检查 `~/.zshrc` 里有没有别处又 `source` 了 autosuggestions 或 syntax-highlighting。

## 选配改了但文件没删掉

确认你走的是模板路径。只有 `.tmpl` 后缀的片段才会在渲染为空时被 chezmoi 删除。普通 `.zsh` 文件即使没有被 `{{ if }}` 包起来，也会一直存在。

另外，`.chezmoiignore` 的条目对 `exact_` 是不可见的，所以用 ignore 做选配回收不了已下发的文件。Dotgraft 用模板而不是 ignore，就是为了避开这点。

重新应用一次：

```bash
dotgraft reconfigure
```

## 依赖没装上 / `brew install` 失败

`run_onchange` 只在脚本内容变化时执行，所以“上次失败、这次 apply 会自动重试”是不成立的。Dotgraft 用独立的依赖入口：

```bash
dotgraft deps
```

它无条件重新渲染并执行 `run_onchange_install-packages.sh.tmpl`，失败会以非零退出。`dotgraft update` 和 `dotgraft reconfigure` 结束时会自动调用它。

## bootstrap 说源目录不像 Dotgraft

Dotgraft 使用独立 source：

```
~/.local/share/chezmoi-dotgraft
```

`chezmoi init` 在 source 已有内容时**不会 clone**，而是沿用现有 source。为避免把别的 dotfiles 当成 Dotgraft 应用，bootstrap 会直接停止。按提示备份并移开 Dotgraft 的 source：

```bash
mv "$HOME/.local/share/chezmoi-dotgraft" "$HOME/.local/share/chezmoi-dotgraft.before-dotgraft.$(date +%Y%m%d_%H%M%S)"
```

如果提示的是旧版默认 source，请先用旧版 `dotgraft uninstall`，或移开 `~/.local/share/chezmoi`。你自己的默认 chezmoi source/config 不会被新安装改动。

## 直接跑 `chezmoi` 看不到 Dotgraft

这是独立 source 的预期行为。用：

```bash
dotgraft chezmoi status
dotgraft chezmoi diff
dotgraft cd
```

需要底层命令时统一走 `dotgraft chezmoi ...`。

## 卸载被拒绝

两种常见原因：

1. **当前 source 里混有 Dotgraft 之外的受管文件。** 脚本会列出路径并停止。先备份/移走这些文件，或给它们换一个独立 source。
2. **`~/.zshrc` 的 dotgraft 区块不完整。** 只有开始标记、没有结束标记时，直接剥离会误删后面的内容，所以脚本选择停止。手动补齐结束标记：

   ```zsh
   # <<< dotgraft <<<
   ```

   如果文件已经损坏，先从 `~/.config-backup/<时间戳>/files/.zshrc` 恢复，再重试。

## 卸载后 source 目录还在

这是安全设计。只有当 Dotgraft 的独立 source 是干净克隆（无未提交改动、无未推送提交、remote 像 dotgraft）时，`dotgraft uninstall` 才会执行 `chezmoi purge`。否则会保留 source，避免删掉你加在同一仓库里的私有文件。

确认无误后可以手动清理 Dotgraft 自己的 source/config：

```bash
dotgraft chezmoi purge --force
```

## 更新时要求重新选配

`dotgraft update` 先 `git pull`，再检查 `.chezmoi.toml.tmpl` 是否变化。变化时会重新运行 `chezmoi init`，避免上游新增 data key 后模板渲染失败。按提示回答即可。

## `dotgraft diff` 输出太长

`dotgraft diff` 默认只显示 `chezmoi status` 的文件摘要，适合确认“会改哪些文件”。首次安装时所有目标都是新文件，完整 diff 会把整份 `starship.toml`、`dotgraft` 脚本打印出来，所以默认不显示。

要看逐行补丁：

```bash
dotgraft diff --full
```

bootstrap 首次安装也只显示摘要，避免一屏都是新增文件内容。

## `dotgraft doctor` 里的 age / 1Password / Bitwarden 是什么

`dotgraft doctor` 现在只检查 Dotgraft 自己的环境：macOS、Shell、Homebrew、chezmoi、独立 source/config、`.zshrc` 区块、受管文件、选配工具、Starship、Ghostty、字体和 Ghostty 覆盖文件。

如果你要看 chezmoi 的完整诊断（包括 age、1Password、Bitwarden、pass、vault 等可选集成），用：

```bash
dotgraft chezmoi doctor
```

那些 `info` 行只表示“没有配置某个可选集成”，不是 Dotgraft 安装失败。

## 需要更多信息

```bash
dotgraft status        # 选配、差异、版本
dotgraft doctor        # Dotgraft 专用环境自检
dotgraft chezmoi doctor # 完整的 chezmoi 环境自检
ghostty +show-config   # Ghostty 合并后的最终配置
ghostty +version
```

提 issue 时把上面几条的输出贴上来，能省很多来回。
