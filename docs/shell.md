# Shell 层

zsh 部分由 `~/.zshrc` 里的一小段区块引导：

```zsh
# >>> dotgraft >>>
# 由 dotgraft 管理，请勿手动编辑本区块
# 机器本地配置请写到 ~/.config/zsh/conf.d/90-local.zsh
source "$HOME/.config/zsh/init.zsh"
# <<< dotgraft <<<
```

`init.zsh` 做三件事：把 `~/.local/bin` 放进 `PATH`、准备 Homebrew 前缀变量、按序 source `conf.d/*.zsh`。

片段清单和加载顺序见[配置架构](configuration.md#片段加载顺序)。

## Starship（提示符）

`~/.config/starship.toml` 是 Starship 官方 `catppuccin-powerline` 预设的原样副本，只改了一处：

```
[line_break]
disabled = false
```

默认是 `true`，也就是提示符独占一行、输入和它挤在一起。改成 `false` 后彩虹条占第一行、输入符号落到第二行，输入时永远有整行可用。

配色梯度：`red → peach → yellow → green → sapphire → lavender`，每个色块对应一类信息：用户 → 路径 → Git → 语言版本。

换调色板改文件里的 `palette`，可选 `catppuccin_mocha` / `catppuccin_frappe` / `catppuccin_macchiato` / `catppuccin_latte`。

### 同步上游预设

预设内部有大量隐式依赖，**不要逐行手改**。要升级就整份替换：

```bash
starship preset catppuccin-powerline -o /tmp/new.toml
cp /tmp/new.toml dot_config/starship.toml
# 然后把 line_break 那一处改回 false，并更新文件头的版本号
```

文件头记录了所依据的上游版本（当前 1.27.0）。写版本号的目的是下次同步时知道从哪跳过来。

## 三个插件

都不是框架，是三个独立的小插件。oh-my-zsh 的问题在于框架本身每次启动都要加载一堆东西，而我们只需要这几个功能。

### zsh-autosuggestions

输入时在光标后用灰色显示一条历史建议，按 `→` 或 `Ctrl+F` 接受。

Dotgraft 把接受键改成了 `Ctrl+F`：默认的 `→` 在行中间会被 `forward-char` 抢走，很别扭；`Ctrl+F` 原本也是 `forward-char`，覆盖它代价最小。

### zsh-syntax-highlighting

边输入边着色：命令存在 → 绿色，不存在 → 红色，字符串高亮，路径存在 → 下划线。不用等回车才发现 `command not found`。

它靠 hook 每个键位的 ZLE widget 工作，**必须最后加载**，所以固定是 `99-highlighting.zsh`。放在 `90-local.zsh` 之后，意味着你本地加的东西也有高亮。

### zsh-completions

扩展几百个命令的参数补全（git、docker、brew、kubectl 等）。

它在 `20-completion.zsh` 里做两件事：把目录加进 `fpath`，然后跑 `compinit`。

注意这里会**再跑一次** `compinit`，即使是重复调用。原因是 `~/.zshrc` 里可能有别的工具（比如 OpenSpec）在本区块之前就调用过，它们不知道我们后面又加了 `fpath`。重复调用的代价是几十毫秒，换来新目录真被扫描。

配合两行 zstyle：`menu select` 让 Tab 候选可上下移动，`matcher-list` 让补全大小写不敏感（`cd down` 能补出 `Downloads`）。

`compinit -u` 里的 `-u` 是必要的：Homebrew 目录大多 root 所有，zsh 默认会拒绝使用这种「不安全」目录。

## 五个 CLI 工具

都是选配，没勾就不装、对应片段也不下发。

| 工具 | 用法 | 说明 |
|---|---|---|
| **fzf** | `Ctrl+R` 搜历史，`Ctrl+T` 搜文件，`**<Tab>` 补全 | 比如 `cd **<Tab>` 弹目录列表，`kill **<Tab>` 列进程 |
| **zoxide** | `z foo` 跳到常去的目录，`zi foo` 交互式选择 | 按访问频率和时间排序，数据自动衰减 |
| **eza** | `ls` / `ll` / `lt` | 图标、颜色、目录优先 |
| **bat** | `cat` | 语法高亮 |
| **yazi** | `y` | 文件管理器，退出后自动 cd |

fzf 的初始化有个细节：

```zsh
_dotgraft_fzf_init="$(fzf --zsh 2>/dev/null)"
[[ -n "$_dotgraft_fzf_init" ]] && eval "$_dotgraft_fzf_init"
```

`--zsh` 是 fzf 0.48 之后的新接口，老版本会直接报错。先取一次输出、拿得到才 eval，避免在不支持的版本上往当前 shell 里灌错误。

### zoxide 的一个注意点

**不要写 `alias cd="z"`。** zoxide 靠 hook `cd` 来记录访问，一旦把 `cd` 换成 `z`，它就记不到新目录，数据库会停止更新。直接用 `z` 就好。

## 别名与函数

### eza

```
ls  →  eza --icons --group-directories-first
ll  →  eza -l --icons --sort=name
lt  →  eza --tree --icons --level=2
```

### bat

```
cat  →  bat --paging=never --style=plain
```

`--paging=never` 让行为和 `cat` 完全一致，不会卡在分页器里；`--style=plain` 去掉行号和网格，只留语法高亮。

**副作用**：从此 `cat` 不再是 `cat`。脚本里要读原始内容必须用 `command cat`。`50-functions.zsh` 里的 `y` 函数就是这么写的——它要读一个临时文件，`bat` 的分页和格式化会出乱子。

### y 函数

```zsh
function y() {
  local tmp cwd
  tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp" 2>/dev/null)" &&
     [[ -n "$cwd" ]] && [[ "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
```

yazi 支持 `--cwd-file`，退出时把最后的目录写进指定文件，再读回来 `cd`。这样 `y` 退出后 shell 停在浏览到的目录，省掉一步 `cd`。

两处刻意写法：`command cat` 绕开上面的 `cat → bat` 别名，`builtin cd` 绕开任何人可能定义的 `cd` 别名或函数。

## 历史记录

```
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY      # 记录开始时间，history -i 可看
setopt SHARE_HISTORY         # 多窗口共享，且立即写盘
setopt HIST_IGNORE_ALL_DUPS  # 重复命令只留最新
setopt HIST_IGNORE_SPACE     # 命令前加空格则不记录
```

`HISTFILE` 显式写死，是为了即使将来 `ZDOTDIR` 有变化，历史也不会换地方。macOS 的 `/etc/zshrc` 默认是 `${ZDOTDIR:-$HOME}/.zsh_history`，也就是同一路径。

`HIST_IGNORE_SPACE` 用来处理临时粘贴的敏感内容：命令前敲一个空格就不会进历史。

## 快捷键

| 快捷键 | 作用 |
|---|---|
| `Ctrl+F` | 接受 autosuggestions 的建议 |
| `Ctrl+R` | fzf 模糊搜索历史命令 |
| `Ctrl+T` | fzf 模糊搜索文件 |
| `Tab` | 补全，连按可在候选列表里移动 |
| `**<Tab>` | 触发 fzf 补全 |

Ghostty 自身的窗口操作见 [Ghostty 文档](ghostty.md#快捷键)。

## 加自己的东西

写在 `~/.config/zsh/conf.d/90-local.zsh`。它用 `create_` 管理：只在不存在时创建，之后 `dotgraft apply` 不会覆盖。

不要在 `~/.zshrc` 的 dotgraft 区块里写任何东西——`dotgraft update` 会重写那个区块。

想在仓库里长期维护，就按[配置架构](configuration.md#怎么加东西)的说明新增片段。
