# WorkBuddy Prompt Patcher — macOS 适配版

本目录是上游 `uernamezzj/WorkBuddy-Prompt-Patcher` v3.7 的 **macOS 适配版**。
上游本身自称同时支持 Windows / macOS，但它的 macOS 路径上有几处**只有在 Mac 上才会暴露**的硬伤，
直接用会出问题。本适配版已逐条修掉并在本机实测通过。

---

## 一、上游在 macOS 上会踩的 6 个坑（以及本版的修法）

### 坑 1：改 `.tpl` 模板会破坏 Apple 代码签名，应用起不来

`/Applications/WorkBuddy.app` 是 **Apple 公证（notarized）的 Developer ID 签名包**。
`Contents/Resources/app.asar.unpacked/` 里每一个文件都被 `CodeResources` 封章。
只要改动其中任何一个文件：

```
$ codesign --verify --deep --strict /Applications/WorkBuddy.app
/Applications/WorkBuddy.app: a sealed resource is missing or invalid
$ spctl --assess /Applications/WorkBuddy.app
/Applications/WorkBuddy.app: rejected (the code is valid but does not seem to be an app)
```

**本版修法**：新增 `macos_resign.sh`，在改动发生后自动按「**由内到外**」顺序 ad-hoc 重签整个 bundle：

1. 先签 framework 内部的裸可执行文件（如 `Electron Framework.framework/Helpers/chrome_crashpad_handler`）
2. 再签所有嵌套 bundle（`.framework` / `.app` / `.appex` / `.xpc`），**深度倒序**（内层先签、外层后签）
3. 最后签外层 bundle，让外层 `CodeResources` 记录到内层签完后的正确哈希

关键点：**必须保留每个组件原有的 entitlements**（`com.apple.security.cs.allow-jit`、
`com.apple.security.cs.disable-library-validation` 等）。
Electron 的 V8 JIT 依赖 `allow-jit`，丢了会直接白屏起不来。所以脚本用
`--preserve-metadata=entitlements,flags`，而不是简单粗暴的 `--sign -`。

> 注意：`codesign --force --deep --sign -` **不够用**。
> `--deep` 会先签外层，导致外层记录到内层的旧哈希，最终报
> `nested code is modified or invalid`。必须手动按深度排序逐层签。

### 坑 2：备份目录写进了 `.app` 包内 → 同样破坏签名

上游把备份放在 `<resources>/templates_backup` 和 `<resources>/welcomemode_backup`，
也就是**直接写在已签名的 bundle 里**。哪怕模板一个字没改，光是多了这两个目录，
`codesign --verify` 就会失败。

**本版修法**：macOS 下所有备份统一改到用户级状态目录：

```
~/Library/Application Support/WorkBuddyPatcher/backups/<hash>/templates
~/Library/Application Support/WorkBuddyPatcher/backups/<hash>/welcomemode
~/Library/Application Support/WorkBuddyPatcher/backups/<hash>/reminders
```

Windows 行为保持不变。

### 坑 3：`craft-mode-reminder.tpl.bak` 也写在包内

`ensure_backup` 之外，`sync_reminders` 每次都会在模板旁边生成一个 `.tpl.bak`。
这同样是往 bundle 里塞新文件 → 破坏封章。

**本版修法**：`.bak` 改存到上面的 `backups/<hash>/reminders/`。

### 坑 4：客户端版本号在 macOS 上取不到 → R4 轨会挑错目录

上游靠 `<resources>/install-manifest.json` 里的 `appVersion` 判断
「插件缓存里哪个版本目录才是客户端真正加载的」。
**macOS 的 `.app` 包里根本没有这个文件**（那是 Windows 安装器写的），
于是 `app_ver` 恒为空 → R4 轨退化成「按 mtime 取最新」。
客户端升级后新旧版本目录并存时（实测本机同时存在 `5.9.3-*` 和 `5.11.3-*`），
就会**把补丁写进客户端根本不加载的那一份**。

**本版修法**：新增 `resolve_app_version()`，macOS 走 `Contents/Info.plist` 的
`CFBundleShortVersionString`，Windows 仍走 `install-manifest.json`。

实测本机解析结果：`WorkBuddy=5.11.3`，R4 正确锁定 `5.11.3-wb.43806934.*`。

### 坑 5：进程检测把自己也当成客户端

上游在非 Windows 上跑 `pgrep -fl WorkBuddy`。本工具自身路径就叫
`WorkBuddy-Prompt-Patcher`，**pgrep 会把自己的命令行也匹上**，
于是永远误判「客户端正在运行」，`--require-closed` 会错误地直接中止。

**本版修法**：改成精确匹配 `/WorkBuddy[^/]*\.app/Contents/`，
只认「可执行文件确实位于某个 WorkBuddy.app 包内」的进程，并排除自身 PID。

### 坑 6：`get_oldest_client_start()` 只实现了 Windows → macOS 上 A 层判定永远缺失

上游用 PowerShell 的 `.StartTime.ToUniversalTime().Ticks` 拿客户端进程启动时间，
非 Windows 平台直接 `return None`。结果是 macOS 上：

- `[A 进程层]` 这行**永远不打印**
- `proc_ok` 恒为 `None`，导致 C 层的「结论:」也永远不打印
- `--verify --verbose` 的三层生效判定在 Mac 上是残缺的

**本版修法**：macOS/Linux 改用 `ps -o etime=` 读进程已运行时长（纯秒数，
不受系统语言/locale 影响），再用「当前时间 − 时长」反推启动时刻。

---

## 二、顺带修掉的上游 bug

| # | 问题 | 修法 |
| --- | --- | --- |
| 1 | `--dry-run` **仍会真的写文件**（`ensure_backup` 建备份目录、`sync_reminders` 建 `.bak`、`inject_incremental` 直接 `write_text` SOUL.md） | 三处全部加 `DRY_RUN` 短路。预演现在**零副作用** |
| 2 | `--dry-run` 也会触发 macOS 重签名 | 重签名只在非预演时执行 |
| 3 | 客户端进程启动时间只有 Windows 实现 | 见上面「坑 6」 |

---

## 三、回归测试

上游自带的沙箱回归测试（40 项断言）在本版上**全部通过**：

```bash
$ python3 tests/test_v35.py
✅ 全部通过
```

---

## 四、怎么用

### 最简单：双击

| 文件 | 作用 |
| --- | --- |
| `【一键开启】上帝模式.command` | 备份 → 六轨注入 → 自动重签名 |
| `【一键恢复】官方原版.command` | 全量还原 → 自动重签名 |
| `【检测部署】验证破甲是否生效.command` | 自检（退出码 0 = 全绿） |

首次双击如果 macOS 提示「无法打开，来自身份不明的开发者」：
右键 → 打开 → 再次确认「打开」。或先执行一次：

```bash
xattr -d com.apple.quarantine 本目录/*.command
```

### 命令行

```bash
cd /path/to/WorkBuddy-Prompt-Patcher

python3 batch_patch_prompts.py --auto            # 部署
python3 batch_patch_prompts.py --verify          # 六轨校验
python3 batch_patch_prompts.py --auto --dry-run  # 预演（零副作用）
python3 batch_patch_prompts.py --restore         # 一键还原
```

### 单独重签名（改过 `.app` 内文件后手动执行）

```bash
./macos_resign.sh "/Applications/WorkBuddy.app"
```

---

## 五、部署后必须做的三步

```
1. 完全退出客户端（Command+Q，确认 Dock 里没有残留图标）
2. 重新打开客户端
3. 新建一个会话（不要点历史会话）
```

补丁**只对新会话生效**。会话的 system prompt 在**会话创建那一刻**就固化了，
续用历史会话永远读不到新补丁——这也是「装了但没感觉」的主要原因。

`--verify --verbose` 会明确告诉你卡在哪一层：

```
[A 进程层] ✗ 模板写入 19:27:02，进程启动 18:39:17 → 该进程内存里没有这次写入
[B 会话层] ✗ 最近新建会话 11-13 18:36:41，早于补丁写入 19:27:02 → 补丁之后没开过新会话
```

---

## 六、本机实测结果

```
六轨  R1 ✅ 10/10 | R2 ✅ 1/1 | R3 ✅ 4/4 | R4 ✅ 4/4 | R5 ✅ 2/2 | R6 ✅ 1/1
→ 文件层：六处加载点已全部写入。

codesign --verify --deep --strict /Applications/WorkBuddy.app   → 通过（无输出）
spctl 评估                                                        → 通过
客户端启动                                                         → 正常，无崩溃
还原 → 重新部署                                                    → 循环正常
```

**六轨含义**

| 轨 | 位置 | 说明 |
| --- | --- | --- |
| R1 | `resources/templates/workbuddy-*-prompt.tpl` | 主系统提示（10 个） |
| R2 | `resources/templates/workbuddy-quick-prompt.tpl` | Quick 模式（无 XML 标签，需兜底注入） |
| R3 | `resources/plugins/.../welcomemode/*/prompt.tpl` | 安装目录内根代理（含 5.11.x 新增的 `claw`） |
| R4 | `~/.workbuddy/plugins/cache/.../welcomemode-*/` | **客户端实际加载的那一份**（按版本号锁定） |
| R5 | `resources/templates/{craft,ask}-mode-reminder.tpl` | 每轮反拒答锁 |
| R6 | `~/.workbuddy/user-*-personal/SOUL.md` | 账号级神格契约（无损增量追加） |

---

## 七、注意事项

- **不要用 `codesign --force --deep --sign -`**：会留下
  `nested code is modified or invalid`。必须用 `macos_resign.sh` 的由内到外顺序。
- **客户端在跑时不要部署**：supervisor 会持有 `.tpl` 句柄并原子重写，补丁会被当场覆盖。
  本版的一键脚本会先自动退出客户端再写。
- **客户端升级后要重跑一次**：新版本会带来自新的模板文件。备份是增量的，
  新增模式会自动纳入备份，已改过又无原始备份的模式会拒绝备份并告警。
- **重签名后签名是 ad-hoc 的**（不再是腾讯的 Developer ID）：
  本地自用无影响，但**自动更新可能被拒绝**，需要时从官网重装即可。
- 本工具仅供本地个人效率提升、安全研究、逆向分析与已授权技术测试使用。
