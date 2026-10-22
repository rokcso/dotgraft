# 配置架构

这篇讲 Dotgraft 是怎么组织起来的：文件放哪、加载顺序怎么定、选配是怎么生效的，以及你要加东西时该动哪里。

## 仓库结构

```
.
├── .chezmoi.toml.tmpl                     # 安装时的选配问答
├── .chezmoiignore                         # 哪些文件不铺进 $HOME
├── .dotgraft-source                        # source 归属标记
├── .gitignore
├── Brewfile                               # 基础依赖，始终安装
├── bootstrap.sh                           # 一行安装入口
├── run_onchange_install-packages.sh.tmpl  # 装基础依赖 + 勾选组件
├── modify_dot_zshrc                       # 给 ~/.zshrc 注入标记区块
├── dot_config/
│   ├── ghostty/config.tmpl                # → ~/.config/ghostty/config
│   ├── ghostty/themes/Dotgraft Ink        # 深色主题
│   ├── ghostty/themes/Dotgraft Paper      # 浅色主题
│   ├── starship.toml.tmpl                 # → ~/.config/starship.toml（按主题选调色板）
│   └── zsh/
│       ├── init.zsh                       # → ~/.config/zsh/init.zsh
│       └── conf.d/
│           ├── 10-history.zsh
│           ├── 20-completion.zsh
│           ├── 30-prompt.zsh
│           ├── 40-tools.zsh.tmpl          # 选配
│           ├── 50-functions.zsh.tmpl      # 选配
│           ├── 60-plugins.zsh
│           ├── 70-aliases.zsh.tmpl        # 选配
│           ├── 80-dotgraft.zsh            # dotg 别名 + 补全
│           ├── create_90-local.zsh        # 只创建一次
│           └── 99-highlighting.zsh        # 必须最后
├── dot_local/bin/executable_dotgraft      # → ~/.local/bin/dotgraft
├── .github/workflows/ci.yml                # 每次 push 自动跑检查和渲染测试
├── tests/smoke.sh                          # 端到端冒烟测试，本地和 CI 共用
├── tests/unit/                             # bats 单元测试
├── docs/
├── LICENSE
└── README.md
```

## chezmoi 的命名属性

源目录里的文件名不是随便起的，前缀决定它怎么落到目标位置。Dotgraft 用到的六个：

| 属性 | 含义 | 本仓库用在哪 |
|---|---|---|
| `dot_` | 名称前加一个点 | `dot_config/` → `~/.config/` |
| `.tmpl` 后缀 | 当 Go 模板渲染 | `config.tmpl`、`40-tools.zsh.tmpl` |
| `executable_` | 目标文件加可执行位 | `executable_dotgraft` |
| `create_` | 只在不存在时创建，之后永不覆盖 | `create_90-local.zsh` |
| `modify_` | 当脚本跑，改造已有文件 | `modify_dot_zshrc` |
| `run_onchange_` | 内容变化时才执行 | `run_onchange_install-packages.sh.tmpl` |

`dot_config/ghostty/config.tmpl` 读法：`dot_config` 加点的 `config` 目录，里面 `config.tmpl` 渲染后写成 `config`。目标就是 `~/.config/ghostty/config`。

`.chezmoiignore` 里的匹配模式针对的是**目标路径**，不是源路径。写 `dot_config/...` 是不生效的，要写 `.config/...`。

## 片段加载顺序

`init.zsh` 用 `for` + 通配按字典序 source `conf.d/*.zsh`，所以文件名里的数字就是加载顺序：

| 顺序 | 文件 | 内容 | 为什么在这个位置 |
|---|---|---|---|
| 10 | `10-history.zsh` | HISTFILE / HISTSIZE / setopt | 最早，后面的插件依赖历史 |
| 20 | `20-completion.zsh` | fpath + `compinit` + zstyle + 补全选项 | 必须在补全插件之前 |
| 30 | `30-prompt.zsh` | Starship init | 要早于 autosuggestions |
| 40 | `40-tools.zsh.tmpl` | fzf、zoxide | 依赖补全系统已就绪 |
| 50 | `50-functions.zsh.tmpl` | `y`（yazi 包装） | 独立函数 |
| 60 | `60-plugins.zsh` | zsh-autosuggestions | 要 hook 已设置好的 PROMPT |
| 70 | `70-aliases.zsh.tmpl` | eza、bat 别名 | 放最后，避免影响前面 |
| 80 | `80-dotgraft.zsh` | `dotg` 别名 + `dotgraft`/`dotg` 补全 | 在本地配置之前，补全依赖 `compinit` |
| 90 | `create_90-local.zsh` | 你的机器专属配置 | 在收尾插件之前 |
| 99 | `99-highlighting.zsh` | zsh-syntax-highlighting | **必须最后**，之后不能再 bindkey |

两条硬性顺序：

- `zsh-syntax-highlighting` 靠 hook 每个键位的 ZLE widget 着色。它之后再 `source` 或 `bindkey`，颜色就对不上。所以固定 `99-`。
- `zsh-completions` 的目录必须在 `compinit` 之前进 `fpath`。而 `~/.zshrc` 里可能有别的工具（比如 OpenSpec）在 Dotgraft 区块之前就调过 `compinit`，所以 `20-completion.zsh` 会**再跑一次** `compinit`，代价几十毫秒，换来新目录真被扫描。

## 选配是怎么生效的

链路四步：

```
.chezmoi.toml.tmpl          问三个问题，答案写进 ~/.config/dotgraft/chezmoi.toml
        ↓
.chezmoi/chezmoi.toml       [data] 段里的 tools / theme / glass
        ↓
模板里的 {{ .tools }} 等     片段和 Ghostty 配置据此分支
        ↓
渲染结果为空                 chezmoi 删除目标文件
```

最后那步是关键。可选片段整个包在 `{{ if has "fzf" .tools }} ... {{ end }}` 里，一个都不选时渲染出零字节，chezmoi 默认会删掉空文件——于是「取消勾选」是真正的移除配置，而不是留一个死文件。注意：这**不会**卸载已经装过的 Homebrew 包，只是不再安装它们。

注意 `.chezmoiignore` + `exact_` 的组合做不到这件事：被 ignore 的条目对 `exact_` 不可见，之前装过的文件会一直赖在磁盘上。所以选配走模板，不走 ignore。

改选配：

```bash
dotgraft reconfigure      # chezmoi init → 预览 → apply → 修复依赖
```

`chezmoi init` 会重新渲染 `.chezmoi.toml.tmpl`，覆盖 `~/.config/dotgraft/chezmoi.toml`。

`bootstrap.sh` 和 `dotgraft reconfigure` 会先用编号菜单询问主题和毛玻璃，再把答案通过 `--promptChoice` / `--promptBool` 传给 `chezmoi init`，所以不需要手打完整主题名。自动化时可以用：

```bash
DOTGRAFT_THEME="Dotgraft Paper" DOTGRAFT_GLASS=false dotgraft reconfigure
```

主题列表在三处保持一致：`.chezmoi.toml.tmpl`、`bootstrap.sh`、`dot_local/bin/executable_dotgraft`。新增主题时三处都要改；如果是自定义主题，还要把主题文件放进 `dot_config/ghostty/themes/`，并同步 `dotgraft` 卸载白名单和 `tests/smoke.sh`。

## 机器专属配置

`~/.config/zsh/conf.d/90-local.zsh` 用 `create_` 管理：首次 apply 时创建，之后 `dotgraft apply` 永不覆盖。适合放：

- 只在这台机器上存在的路径
- 环境变量、别名、函数
- 别的安装器让你「追加到 `~/.zshrc`」的那些行

它由 git 以外的机制保护——`create_` 只看文件在不在，不看内容。所以你在里面写什么都不会丢。但**不要放密钥**：它虽然不进仓库，也不是加密存储。

## 源目录归属

Dotgraft 使用独立 source/config，不碰用户的默认 chezmoi：

```
source:  ${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi-dotgraft
config:  ${XDG_CONFIG_HOME:-$HOME/.config}/dotgraft/chezmoi.toml
```

所有 `dotgraft` 命令都带 `--source/--config/--destination`，因此可以和用户已有的 chezmoi 配置并存。默认的 `~/.local/share/chezmoi` 和 `~/.config/chezmoi` 不会被写入（只会读一下默认 source，用于识别旧版安装）。

安全边界：

- 仓库根部有 `.dotgraft-source` 标记；旧版本 source 用 `.chezmoi.toml.tmpl` + `dot_local/bin/executable_dotgraft` 兜底判断
- `bootstrap.sh` 在 `chezmoi init` 之前检查独立 source；已有内容且不像 Dotgraft 时直接停止
- 检测到旧版安装在默认 source 时，bootstrap 会提示先卸载/移开，避免两套配置同时生效
- `dotgraft uninstall` 只允许删除白名单内的目标路径；发现非 Dotgraft 受管文件就停止
- `chezmoi purge` 只在独立 source 是干净的 Dotgraft 克隆时执行；有未提交/未推送内容时保留 source

直接运行 `chezmoi` 会使用默认 source/config，看不到 Dotgraft；需要底层命令时用 `dotgraft chezmoi ...`。

## 为什么不用 ZDOTDIR

在 `~/.zshenv` 里设 `ZDOTDIR` 指向 `~/.config/zsh`，看起来更干净，也是不少方案的做法。Dotgraft 不用它，三个原因都是实测过的：

1. **`~/.zprofile` 会失效。** zsh 的启动顺序是 `/etc/zshenv` → `$ZDOTDIR/.zshenv` → `/etc/zprofile` → `$ZDOTDIR/.zprofile` → `/etc/zshrc` → `$ZDOTDIR/.zshrc`。在 `.zshenv` 里改 `ZDOTDIR`，后续文件全部改从新目录读，`~/.zprofile` 直接被跳过。那里面通常放着 `brew shellenv`、OrbStack、pipx 之类的初始化。
2. **第三方说明全部落空。** 几乎所有工具的安装文档都写「把这行加到 `~/.zshrc`」。重定向之后，用户照着做，文件却没人读，故障不报错、极难查。
3. **Ghostty 自己也动 `ZDOTDIR`。** 它的 zsh shell 集成会把 `ZDOTDIR` 指向自带资源目录，把用户原值暂存进 `GHOSTTY_ZSH_ZDOTDIR`，再在集成脚本里还原。叠上我们自己的重定向，等于三层间接。

改一段标记区块只花掉 `~/.zshrc` 三行，把这三个问题一起绕开了。

## 怎么加东西

### 加一个 zsh 片段

在 `dot_config/zsh/conf.d/` 新建文件，用两位数字前缀决定位置。想让它可选，就：

1. 文件名加 `.tmpl`
2. 内容整个包进 `{{ if has "工具名" .tools }} ... {{ end }}`
3. 在 `.chezmoi.toml.tmpl` 的 `promptMultichoice` 选项列表里加上这个名字
4. 如果是**固定**片段（不是选配），同步更新 `dot_local/bin/executable_dotgraft` 的 `is_allowed_target` 白名单和 `tests/smoke.sh` 里的同名白名单；否则卸载会把它当成“非 Dotgraft 文件”拒绝执行，CI 也会失败

### 加一个新的选配问题

改 `.chezmoi.toml.tmpl`。函数签名统一是 `prompt <choices> [default]`：

```
promptBool        prompt [default]
promptChoice      prompt choices [default]
promptMultichoice prompt choices [default]
promptString      prompt [default]
```

`choices` 必须是 `(list ...)`，`default` 只能给一个值。新变量记得加进 `[data]` 段，否则模板里取不到。

一个坑：一个都不选时，chezmoi 可能产出 `[""]` 而不是 `[]`，而 `[""]` 在模板里是**真**。仓库里的 `$clean` 那段就是在滤空串，加新选项时照抄。

### 加一个受管文件

按目的路径命名放进对应层级即可，比如目标 `~/.config/foo/bar` 就放 `dot_config/foo/bar`。放完先跑：

```bash
dotgraft diff       # 确认落点对不对
```

如果这是新的受管路径，还要把它加入 `dot_local/bin/executable_dotgraft` 的 `is_allowed_target` 和 `tests/smoke.sh` 的白名单；否则卸载会因为“非 Dotgraft 受管文件”而拒绝执行。

### 加一个依赖

基础依赖进 `Brewfile`；可选依赖走选配，装的动作在 `run_onchange_install-packages.sh.tmpl` 里。

那个脚本里嵌了两个哈希（选配清单、`Brewfile`），所以只在两者变化时重跑，平时 apply 不会浪费时间。

但 `run_onchange` **不是收敛机制**：包被手动删掉、或上次安装失败时，只要脚本内容没变就不会重跑。所以：

- 脚本失败时会以非零退出，让 chezmoi 不把这个版本标记为完成，下次 apply 会重试
- `dotgraft update` / `dotgraft reconfigure` 结束时会运行 `dotgraft deps`
- `dotgraft deps` 无条件重新渲染并执行同一份安装脚本，是修复依赖的入口

## 常用命令

```bash
dotgraft status                  # 选配、差异、版本
dotgraft diff                    # 文件摘要
dotgraft diff --full             # 完整 diff
dotgraft apply                   # 应用
dotgraft deps                    # 安装/修复依赖
dotgraft theme                   # 查看/切换主题
dotgraft theme paper             # 切到暖光浅色
dotgraft theme porcelain         # 切到冷光浅色
dotgraft update                  # 拉上游、预览、应用、修依赖
dotgraft chezmoi edit --apply ~/.zshrc   # 在 Dotgraft source 上编辑并立即生效
dotgraft cd                      # 进源目录，用 git 正常提交
dotgraft doctor                  # Dotgraft 专用环境自检
```

## 验证清单

改完之后先跑单元测试和冒烟测试（需要 `brew install bats-core`）：

```bash
bats tests/unit
bash tests/smoke.sh
```

它会在临时目录里复制一份仓库、用非交互答案跑 `chezmoi init` + `apply`，然后断言落盘结果。不会碰你真实的家目录，也不会真的装包（`--exclude=scripts`）。

它会检查这些：

- 三个场景（全选 / 全不选 / 只选一项）下，可选片段该在的在、该消失的消失
- 渲染后的可选 zsh 片段和 `.zshrc` 通过 `zsh -n`
- 主题和毛玻璃按选择渲染
- `.zshrc` 里只出现一个 dotgraft 区块，且原有内容不丢
- 重新选配（全选 → 全不选）会删掉可选片段，同时保留 `90-local.zsh`
- 第二次 `apply` 不改动任何东西（幂等）
- 仓库自身文件（README、Brewfile、tests、docs）没有进入 `$HOME`，受管文件都在白名单内
- 卸载会拒绝非 Dotgraft 受管文件、拒绝不完整的 `.zshrc` 区块
- 卸载成功路径会备份 `90-local.zsh`、移除区块、恢复 Ghostty 覆盖文件
- `dotgraft deps` 会调用 `brew bundle`，并把安装失败传播成非零退出
- 默认 `~/.local/share/chezmoi` / `~/.config/chezmoi` 不被写入
- 选配里列的**每个主题名**在 Ghostty 里真实存在

最后一条是自动化的：脚本会从 `.chezmoi.toml.tmpl` 里抽出主题列表逐个校验。加错主题名（比如写成 `GitHub Light` 而不是 `GitHub Light Default`）会直接失败。

补充的单点检查：

```bash
shellcheck bootstrap.sh dot_local/bin/executable_dotgraft tests/smoke.sh
shfmt -d -i 2 -ci -sr bootstrap.sh dot_local/bin/executable_dotgraft tests/smoke.sh
bats tests/unit
python3 tests/theme-contract.py
zsh -n dot_config/zsh/init.zsh dot_config/zsh/conf.d/*.zsh
# 注意：上面的 glob 不包含 *.zsh.tmpl；可选模板由 tests/smoke.sh 渲染后再做 zsh -n
dotgraft diff     # 改完确认落点
```

### 模板不能直接校验

`config.tmpl` 是 Go 模板，不是配置。直接喂给 `ghostty +validate-config` 会报 `unknown field`。必须先渲染：

```bash
ghostty +validate-config --config-file=<(dotgraft chezmoi execute-template < dot_config/ghostty/config.tmpl)
```

### CI

`.github/workflows/ci.yml` 每次 push 和 PR 会跑两条流水线：

| job | 环境 | 内容 |
|---|---|---|
| `lint` | ubuntu | `shellcheck`、`shfmt -d`、`python3 tests/theme-contract.py`、`zsh -n` |
| `render` | macos | 装 chezmoi、Ghostty 和 bats，跑 `bats tests/unit` + `tests/smoke.sh` |

`render` 那条才是关键：它跑的就是用户安装时会走的同一条路径。模板写错、选配项写错、`.chezmoiignore` 漏了目录，都会在那里暴露。Ghostty 安装不再 `continue-on-error`，否则主题和配置校验会被静默跳过。CI 里的 `shfmt` 版本是固定的，避免 `@latest` 改变格式规则导致流水线漂移。
