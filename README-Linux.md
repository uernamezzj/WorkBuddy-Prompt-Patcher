# WorkBuddy Prompt Patcher — Linux 适配版

本目录是上游 `uernamezzj/WorkBuddy-Prompt-Patcher` v3.7 的 **Linux 适配版**。
上游自称支持 Windows / macOS，但把 Linux 一律当成 Windows 的 `else` 分支处理。
在真实 Linux 客户端（deb 安装、版本 5.6.2）上实测有 6 处必然失效，本版已逐条修掉，
并用本机安装布局做了只读验证。

---

## 一、上游在 Linux 上会踩的 6 个坑（以及本版的修法）

### 坑 1：找不到安装目录

上游只在 Windows 注册表、`%LOCALAPPDATA%`、`Program Files` 和 macOS `/Applications/*.app`
里找模板。Linux 客户端实际装在：

```
/opt/WorkBuddy/resources/app.asar.unpacked/resources/templates/
```

**本版修法**：新增 Linux 探测分支，覆盖 `/opt/*WorkBuddy*`、
`/usr/share|lib/*workbuddy*`、`~/.local/share/*WorkBuddy*`、AppImage 的
`squashfs-root` / `.mount_*`，以及 `.desktop` 入口的 `Exec=` 反解；
同时支持从运行中客户端的 `/proc/<pid>/exe` 反推安装根。

### 坑 2：「真实安装校验」把 Linux 安装判成假目录

上游判定真实安装的证据是 `.app/Contents/`、`install-manifest.json` 或
`app.asar + WorkBuddy.exe`。Linux 版三者都没有：主程序叫 `workbuddy`（无 `.exe`），
也没有 Windows 安装器写的清单文件。即使手动指定路径也会被 `rejected`。

**本版修法**：新增判据「同层同时存在 `workbuddy` 可执行文件与 `version` 文件」，
并把 `workbuddy` / `workbuddy-ai` / `codebuddy` 纳入主程序白名单。

### 坑 3：版本号取不到 → R4 轨挑错插件缓存目录

R4 必须按客户端版本号锁定 `plugins/cache/workbuddy-builtin/welcomemode-*/\<版本\>-wb.*
那条真正被加载的目录。上游读 `install-manifest.json` 的 `appVersion`，Linux 没有；
拿不到就退化成「按 mtime 取最新」，客户端升级后会把补丁写进旧版本目录。

**本版修法**：Linux 改读用户目录下的 `last-launch.json`（实测 `{"version":"5.6.2"}`），
并增加从缓存目录名 `\<版本\>-wb.*` 反推的通用兜底。

### 坑 4：`/opt/WorkBuddy` 是 root:root 755，普通用户改不动

模板文件属主为 root，普通用户无写权限。即使探测正确，`write_text` 也会失败。

**本版修法**：

- 一键脚本检测目录不可写时自动通过 `sudo -E` 提权重跑一次（用标记位防死循环）；
- 提权后 Python 侧通过 `SUDO_USER` 找回真实用户的 HOME，避免把 SOUL.md
  写进 `/root/.workbuddy` 这种「文件全绿但用户根本加载不到」的假成功；
- 备份统一外置到 `$XDG_STATE_HOME/workbuddy-patcher/`，不污染系统目录。

### 坑 5：进程检测把工具自己当成客户端

上游在非 Windows 上用 `pgrep -fl WorkBuddy` 模糊匹配。本工具目录名就叫
`WorkBuddy-Prompt-Patcher`，会被自己命中，于是 `--require-closed` 永远中止。

**本版修法**：改用 `/proc/<pid>/exe` 精确判定，只认真实可执行文件名为
`workbuddy` / `workbuddy-ai` / `codebuddy` 的进程，并排除自身 PID 与父进程。
A 层判定（`get_oldest_client_start`）由此在 Linux 上也能拿到 PID 与启动时长。

### 坑 6：R6 神格轨恒定 0/0

上游刻意排除根级 `~/.workbuddy/SOUL.md`（因为 Windows/macOS 上它由账号目录加载），
只统计 `user-*-personal/`。Linux 桌面版本机**没有任何 `user-*` 目录**，
SOUL.md 直接放在 `~/.workbuddy/` 根下并被会话加载 —— 于是 R6 永远 0/0。

**本版修法**：Linux 下若未发现账号目录，自动回退统计根级 `SOUL.md`。

---

## 二、怎么用

### 图形界面双击

| 文件 | 作用 |
| :--- | :--- |
| `【一键开启】上帝模式.sh` | 探测安装 → 请求 sudo → 备份 → 六轨注入 → 同步神格 |
| `【一键恢复】官方原版.sh` | 从备份全量还原 → 重启生效 |
| `【检测部署】验证破甲是否生效.sh` | 只读自检，输出六轨矩阵（退出码 0 = 全绿） |
| `一键修改提示词.sh` | 文本菜单：部署 / 恢复 / 自检 / 预演 |

首次使用先赋予执行权限：

```bash
chmod +x *.sh
```

若文件管理器双击只是用文本编辑器打开，在文件管理器的「文件关联/行为」里
把 `.sh` 设为「运行」或「在终端中执行」；也可以直接在终端 `./【一键开启】上帝模式.sh`。

> 脚本会先检查客户端是否在运行；在运行会直接退出（退出码 2），
> 这是防止 supervisor 原子重写覆盖补丁，不是脚本坏了。

### 命令行

```bash
cd /path/to/WorkBuddy-Prompt-Patcher

python3 batch_patch_prompts.py --auto --dry-run --verbose  # 预演：零写盘
sudo -E python3 batch_patch_prompts.py --auto              # 正式部署
python3 batch_patch_prompts.py --verify --verbose          # 六轨校验（只读）
sudo -E python3 batch_patch_prompts.py --restore           # 一键还原
```

`sudo -E` 用于保留环境变量；即使忘了 `-E`，脚本也会通过 `SUDO_USER` 找回真实用户目录。

### 单独指定安装路径

```bash
sudo -E python3 batch_patch_prompts.py --templates-dir /opt/WorkBuddy --auto
```

---

## 三、部署后必须做的三步

```
1. 完全退出客户端（确认没有 workbuddy 残留进程，含 supervisor）
2. 重新打开客户端
3. 新建一个会话（不要点历史会话）
```

补丁**只对新会话生效**：会话的 system prompt 在创建那一刻就固化了，
续用历史会话永远读不到新补丁。

`--verify --verbose` 的三层判定在 Linux 上同样可用：

```
[A 进程层] 模板写入时间 vs 进程启动时间（ps -o etime=，不受 locale 影响）
[B 会话层] 模板写入时间 vs 最近会话 transcript 创建时间
[C 结论]   两层都过 → 只剩请求形态与模型对齐原因
```

---

## 四、本机实测结果（只读验证）

```
安装目录探测 = /opt/WorkBuddy/resources/app.asar.unpacked/resources/templates
客户端版本   = 5.6.2   （来源 ~/.workbuddy/last-launch.json）
进程检测     = 精确命中 /opt/WorkBuddy/workbuddy，未匹到本工具
备份目录     = $XDG_STATE_HOME/workbuddy-patcher/backups/<hash>/templates
版本指纹     = installDir=/opt/WorkBuddy，welcomemode 三轨均为 5.6.2-wb.*
```

> 上表为探测与路径解析验证。正式部署会修改本机客户端模板，需在退出客户端后自行执行一键脚本。

---

## 五、注意事项

- **不要直接在客户端运行时部署**：supervisor 会持有 `.tpl` 并原子重写，补丁会被覆盖。
- **客户端升级后要重跑一次**：新版本带来新模板；备份是增量的，新模式自动纳入。
- **Linux 没有签名封章问题**：`macos_resign.sh` 只在 macOS 调用，Linux 无需重签名。
- **sudo 的 HOME 陷阱已处理**：提权时脚本按 `SUDO_USER` 定位真实用户目录，不会写进 `/root`。
- 本工具仅供本地个人效率提升、安全研究、逆向分析与已授权技术测试使用。
