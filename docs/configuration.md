# 配置架构

这篇讲 Dotgraft 是怎么组织起来的：文件放哪、加载顺序怎么定、选配是怎么生效的，以及你要加东西时该动哪里。

## 仓库结构

```
.
├── .chezmoi.toml.tmpl                     # 安装时的选配问答
├── .chezmoiignore                         # 哪些文件不铺进 $HOME
├── .gitignore
├── Brewfile                               # 基础依赖，始终安装
├── bootstrap.sh                           # 一行安装入口
├── run_onchange_install-packages.sh.tmpl  # 装基础依赖 + 勾选组件
├── modify_dot_zshrc                       # 给 ~/.zshrc 注入标记区块
├── dot_config/
│   ├── ghostty/config.tmpl                # → ~/.config/ghostty/config
│   ├── starship.toml                      # → ~/.config/starship.toml
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
│           ├── create_90-local.zsh        # 只创建一次
│           └── 99-highlighting.zsh        # 必须最后
├── dot_local/bin/executable_dotgraft      # → ~/.local/bin/dotgraft
├── .github/workflows/ci.yml                # 每次 push 自动跑检查和渲染测试
├── tests/smoke.sh                          # 冒烟测试，本地和 CI 共用
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
| 20 | `20-completion.zsh` | fpath + `compinit` + zstyle | 必须在补全插件之前 |
| 30 | `30-prompt.zsh` | Starship init | 要早于 autosuggestions |
| 40 | `40-tools.zsh.tmpl` | fzf、zoxide | 依赖补全系统已就绪 |
| 50 | `50-functions.zsh.tmpl` | `y`（yazi 包装） | 独立函数 |
| 60 | `60-plugins.zsh` | zsh-autosuggestions | 要 hook 已设置好的 PROMPT |
| 70 | `70-aliases.zsh.tmpl` | eza、bat 别名 | 放最后，避免影响前面 |
| 90 | `create_90-local.zsh` | 你的机器专属配置 | 在收尾插件之前 |
| 99 | `99-highlighting.zsh` | zsh-syntax-highlighting | **必须最后**，之后不能再 bindkey |

两条硬性顺序：

- `zsh-syntax-highlighting` 靠 hook 每个键位的 ZLE widget 着色。它之后再 `source` 或 `bindkey`，颜色就对不上。所以固定 `99-`。
- `zsh-completions` 的目录必须在 `compinit` 之前进 `fpath`。而 `~/.zshrc` 里可能有别的工具（比如 OpenSpec）在 Dotgraft 区块之前就调过 `compinit`，所以 `20-completion.zsh` 会**再跑一次** `compinit`，代价几十毫秒，换来新目录真被扫描。

## 选配是怎么生效的

链路四步：

```
.chezmoi.toml.tmpl          问三个问题，答案写进 ~/.config/chezmoi/chezmoi.toml
        ↓
.chezmoi/chezmoi.toml       [data] 段里的 tools / theme / glass
        ↓
模板里的 {{ .tools }} 等     片段和 Ghostty 配置据此分支
        ↓
渲染结果为空                 chezmoi 删除目标文件
```

最后那步是关键。可选片段整个包在 `{{ if has "fzf" .tools }} ... {{ end }}` 里，一个都不选时渲染出零字节，chezmoi 默认会删掉空文件——于是「取消勾选」是真正的移除，而不是留一个死文件。

注意 `.chezmoiignore` + `exact_` 的组合做不到这件事：被 ignore 的条目对 `exact_` 不可见，之前装过的文件会一直赖在磁盘上。所以选配走模板，不走 ignore。

改选配：

```bash
dotgraft reconfigure      # 等价于 chezmoi init 后 chezmoi apply
```

`chezmoi init` 会重新渲染 `.chezmoi.toml.tmpl`，覆盖 `~/.config/chezmoi/chezmoi.toml`。

## 机器专属配置

`~/.config/zsh/conf.d/90-local.zsh` 用 `create_` 管理：首次 apply 时创建，之后 `chezmoi apply` 永不覆盖。适合放：

- 只在这台机器上存在的路径
- 环境变量、别名、函数
- 别的安装器让你「追加到 `~/.zshrc`」的那些行

它由 git 以外的机制保护——`create_` 只看文件在不在，不看内容。所以你在里面写什么都不会丢。但**不要放密钥**：它虽然不进仓库，也不是加密存储。

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

### 加一个依赖

基础依赖进 `Brewfile`；可选依赖走选配，装的动作在 `run_onchange_install-packages.sh.tmpl` 里。

那个脚本里嵌了两个哈希（选配清单、`Brewfile`），所以只在两者变化时重跑，平时 apply 不会浪费时间。

## 常用命令

```bash
dotgraft status                  # 选配、差异、版本
dotgraft diff                    # 预览
dotgraft apply                   # 应用
chezmoi edit --apply ~/.zshrc    # 编辑并立即生效
dotgraft cd                      # 进源目录，用 git 正常提交
dotgraft doctor                  # 环境自检
```

## 验证清单

改完之后先跑冒烟测试，它覆盖了模板渲染、选配行为、`.zshrc` 注入和 Ghostty 配置校验：

```bash
bash tests/smoke.sh
```

它会在临时目录里复制一份仓库、用非交互答案跑 `chezmoi init` + `apply`，然后断言落盘结果。不会碰你真实的家目录，也不会真的装包（`--exclude=scripts`）。

它会检查这些：

- 三个场景（全选 / 全不选 / 只选一项）下，可选片段该在的在、该消失的消失
- 主题和毛玻璃按选择渲染
- `.zshrc` 里只出现一个 dotgraft 区块，且原有内容不丢
- 第二次 `apply` 不改动任何东西（幂等）
- 仓库自身文件（README、Brewfile、tests、docs）没有进入 `$HOME`
- 选配里列的**每个主题名**在 Ghostty 里真实存在

最后一条是自动化的：脚本会从 `.chezmoi.toml.tmpl` 里抽出主题列表逐个校验。加错主题名（比如写成 `GitHub Light` 而不是 `GitHub Light Default`）会直接失败。

补充的单点检查：

```bash
shellcheck bootstrap.sh dot_local/bin/executable_dotgraft tests/smoke.sh
shfmt -d -i 2 -ci -sr bootstrap.sh dot_local/bin/executable_dotgraft tests/smoke.sh
zsh -n dot_config/zsh/init.zsh dot_config/zsh/conf.d/*.zsh
dotgraft diff     # 改完确认落点
```

### 模板不能直接校验

`config.tmpl` 是 Go 模板，不是配置。直接喂给 `ghostty +validate-config` 会报 `unknown field`。必须先渲染：

```bash
ghostty +validate-config --config-file=<(chezmoi execute-template < dot_config/ghostty/config.tmpl)
```

### CI

`.github/workflows/ci.yml` 每次 push 和 PR 会跑两条流水线：

| job | 环境 | 内容 |
|---|---|---|
| `lint` | ubuntu | `shellcheck`、`shfmt -d`、`zsh -n` |
| `render` | macos | 装 chezmoi 和 Ghostty，跑 `tests/smoke.sh` |

`render` 那条才是关键：它跑的就是用户安装时会走的同一条路径。模板写错、选配项写错、`.chezmoiignore` 漏了目录，都会在那里暴露。
