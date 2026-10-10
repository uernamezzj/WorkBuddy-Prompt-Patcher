# WorkBuddy (Tencent Electron) 逆向分析、加壳校验破除与 UI 皮肤缝合技术报告 (完整版)

---

## 1. 使用的所有加密与校验手段 (Protection & Integrity Mechanisms)

腾讯 WorkBuddy 客户端基于 Electron 框架构建，为防止客户端被篡改、破解或注入恶意代码，底层集成了多层防御与安全校验机制：

### 1.1 ASAR 归档包 JSON Header SHA256 完整性校验 (Electron ASAR Integrity Check)
- **机制**：Electron 官方集成了 ASAR Integrity 校验。在 `app.asar` 文件的头部 JSON Header 数据区中，记录了 ASAR 内部每一个文件（如 `main/index.js`、`renderer/index.html`、`renderer/assets/*.png`）的物理偏移量（`offset`）、文件尺寸（`size`）以及该文件的 **SHA256 哈希值（`integrity.hash`）**。
- **作用**：当 Electron 启动并解包读取 ASAR 内部文件时，主进程底层会自动计算读取到的字节流 SHA256 哈希。如果哈希值与 Header 中记录的哈希串不一致，系统会认定文件遭到了非法篡改，从而抛出异常或**直接触发程序秒退 (Crash)**。

### 1.2 物理外壳与文件结构偏移校验 (File Structure & Offset Constraints)
- **机制**：ASAR 文件是一个扁平化的归档文件，Header 之后紧接着是连续存放的文件物理二进制数据。每个文件的读取依赖 `dataStart + offset`。
- **作用**：如果直接将 ASAR 解包、替换文件后再重包，修改后的文件尺寸一旦发生变化，就会导致其后面所有文件的物理偏移地址（`offset`）整体偏移乱套，不仅触发哈希校验失败，还会导致整个 ASAR 文件索引结构损坏崩溃。

### 1.3 静态明文提示词 Policy 隔离 (`app.asar.unpacked/`)
- **机制**：WorkBuddy 将控制 AI 行为与安全边界的提示词模板（`.tpl` / `.md` 文件）放置在 `app.asar.unpacked/resources/templates/` 目录下。
- **作用**：这些模板文件虽然暴露在 ASAR 主包之外，但主进程在运行时会对其进行读取校验，防止用户非法破甲。

### 1.4 前端框架内存状态与数据 Base64 机制 (Vue/React State & Inlining)
- **机制**：前端界面采用了现代单页框架（Vue / React / Vite Chunking）。用户登录后，头像、用户数据等信息通过后端 API 接口动态返回，并在前端以 `data:image/png;base64,...` 的内联数据形式绑定在组件 State 中。
- **作用**：当组件状态刷新或重新渲染时，框架会强制将 `<img>` 标签的 `src` 属性重置为内存 State 中的 Base64 值，从而抵消一般 DOM 操作的单次修改。

### 1.5 主进程环境隔离与 DevTools 禁用 (Process Isolation & DevTools Guard)
- **机制**：生产环境构建（`isDev = false`）中，关闭了 DevTools 的默认快捷键（`F12` / `Ctrl+Shift+I`），并将调试窗口的唤醒代码置于仅在 `isDev == true` 时才执行的分支块中。

---

## 2. 解决方案、二进制原理与攻防拆解 (Reverse Engineering Solutions & Binary Patching Principles)

### 2.1 二进制定位与翻译原理 (Binary Location & Translation Mechanism)
- **疑问**：二进制全是 `01` 或十六进制（CE 修改器中看到的 `00-FF`），是如何精准定位并阅读的？
- **解答**：
  1. **ASAR 格式规范解构**：ASAR 前 4 字节为无符号整数，记录 JSON Header 大小。紧随其后的数据是符合 UTF-8 编码的纯文本 JSON 字典。
  2. **字符集映射与匹配**：在计算机中，所有文本字符在内存中均对应特定的字节码（ASCII / UTF-8 编码表）。如 `<script>` 对应十六进制 `3C 73 63 72 69 70 74 3E`。Node.js 的 `Buffer.indexOf` 能够在数兆字节的二进制流中按字节序列精准定位目标文本的物理起始偏移量（`offset`）。

### 2.2 原地二进制缝合法 (In-Place ASAR Binary Patching)
- **原理**：不重新解包/重包整个 ASAR，避免破坏后续文件的物理偏移量。
- **物理尺寸约束**：ASAR 文件中各文件紧密排列（`OffsetB = OffsetA + SizeA`）。写入的新数据体积必须 **`<= maxSize`**。若新数据体积小于原空间上限，使用空格字符（`0x20`）进行**物理字节尾部填充**，确保物理空间一动不动，防止后面几千个文件的物理偏移地址发生错位和结构崩溃。

### 2.3 2.1 与 2.2 的协同逻辑（为什么改了哈希仍必须使用原地缝合法？）
- **疑问**：既然 2.2 直接修改了 JSON Header 里的哈希校验，2.1 原地缝合还有必要吗？
- **解答**：**2.1 与 2.2 是缺一不可的两个半圆！**

| 操作组合 | 物理偏移状态 (2.1) | SHA256 哈希状态 (2.2) | 最终运行结果 |
| :--- | :--- | :--- | :--- |
| **只做 2.2，不做 2.1**<br>*(常规解包重包，文件尺寸改变)* | ❌ 物理字节尺寸改变，ASAR 内部几千个文件的 `offset` 发生错位。 | ✅ Header 里的哈希算对了。 | 💥 **程序直接崩溃/闪退**！主进程按原物理地址读取到的全是错位乱码！ |
| **只做 2.1，不做 2.2**<br>*(原地缝合，但未改写 Header)* | ✅ 物理尺寸和后文几千个文件的物理地址 100% 保持不变。 | ❌ 修改后的物理 SHA256 哈希与原 Header 不匹配。 | 💥 **程序秒退 (Crash)**！Electron 启动时校验 SHA256 不一致，强行杀掉进程。 |
| **2.1 + 2.2 完美结合**<br>*(原地缝合 + 擦写 Header)* | ✅ 物理地址 100% 不错位，数据安全。 | ✅ SHA256 哈希 100% 比对成功。 | 🎉 **0 秒退、0 报错、100% 成功运行！** |

### 2.4 主进程 `mainWindow` 控制台强拉绑定手段 (DevTools Opening Mechanism)
- **打开手段**：
  1. 绕过 `if (this.isDev)` 分支。
  2. 定位到主进程中主渲染窗口（`this.mainWindow`）刚被实例化创建完成的第一时间（绑定 `page-title-updated` 节点的物理位置）。
  3. 注入 `this.mainWindow.webContents.openDevTools({mode:"detach"});` 强拉控制台，保持物理字节数精确对齐 277 字节，实现生产环境下双击启动自动弹出独立 DevTools 调试窗口。

### 2.5 物理原图原位替代 (Raw PNG/SVG Binary Replacement)
- **原理**：针对前端动态 Base64 重绘问题，采取“釜底抽薪”策略。
- **实施**：直接覆写 `app.asar` 内部物理存储的默认头像文件：
  - `renderer/assets/default-account-logo-DBnjou1P.png` (上限 `12,164` 字节)
  - `renderer/assets/assistant-avatar-C3supGLS.png` (上限 `4,918` 字节)
  - `renderer/assets/logo-workbuddy-BUNGQxi-.svg` (上限 `4,119` 字节)
  直接替换物理图片后，框架无论怎么重绘或读取 `src` 属性，拿到的物理二进制文件本身就已经变成了 [icon.png](file:///D:/Projects/AI/WorkBuddy-skin/icon.png) 黑化猫咪图！

### 2.6 前端双压机制 (CSS `content: url(...) !important` + JS Dynamic Interceptor)
- **原理**：利用 Chromium 渲染引擎特性。
- **实施**：在 `skin.css` 中配置 `content: url('assets/default-account-logo-DBnjou1P.png') !important`，在 GPU 渲染画板层强制覆盖 `<img>` 元素。

---

## 3. 开发者未来可能采取的商业级加密加固手段 (Future Defense Evolution)

如果官方安全工程师修补现有漏洞，未来的加固手段预计将呈现 4 级演进：

### 3.1 第一级：ASAR 引入非对称数字签名 (RSA/ECC Signing)
- **原理**：目前 ASAR 仅保存明文 SHA256，可被逆向人员同步重写。
- **升级**：官方使用私钥对 ASAR Header 进行非对称签名，C++ 底层内置公钥验签。篡改者因无私钥将无法生成有效签名，导致验签失败拒绝启动。

### 3.2 第二级：主进程 JS 源码编译为 V8 字节码 (V8 Bytecode `.jsc`)
- **原理**：目前 `main/index.js` 为文本格式 JS。
- **升级**：使用 `bytenode` 等工具将主进程源码直接编译成 CPU 机器码级别的 V8 Bytecode 二进制字节码。
- **效果**：文本匹配与二进制缝合彻底失效，JS 代码不再可读。

### 3.3 第三级：Native C++ 插件与控制流混淆加壳 (C++ Addon & OLLVM/VMProtect)
- **原理**：将窗口创建、控制台控制、提示词校验等核心逻辑从 JS 下沉至 C++ 原生动态链接库 (`.node` / `.dll`)。
- **效果**：代码被平坦化混淆加壳，分析难度从修改文本飙升至汇编级 IDA Pro / OllyDbg 逆向脱壳。

### 3.4 第四级：运行期内存保护与反调试 (Anti-Debugging & Memory Integrity)
- **原理**：防范运行时注入与 DevTools 调取。
- **升级**：
  - C++ 底层 Hook `openDevTools` 接口强制拦截；
  - 轮询检测调试句柄与调试端口（`--remote-debugging-port`）；
  - 开启 Windows `SetProcessDEPPolicy` 内存防篡改，检测到注入即自动自杀。

---

## 4. 找 Bug 与排查的全过程 (Debugging & Bug-Hunting Journey)

### 阶段一：解包重包引爆秒退
- **现象**：解包 `app.asar` 替换资源后再打包，启动时软件闪退。
- **排查**：确认是因为重包改变了物理偏移量，且 Header SHA256 不匹配，触发底层校验。

### 阶段二：研发“原位缝合法”，实现零秒退注入
- **思路**：计算目标 `offset` 与 `size`，使用 Node.js 内存 Buffer 原位覆写，尾部空格 `0x20` 填充，改写 Header SHA256，实现稳定启动。

### 阶段三：控制台强拉与 SyntaxError 语法报错攻克
- **现象**：在 `main/index.js` 缝入 DevTools 时出现 `SyntaxError: Unexpected token ')'` 弹窗。
- **排查**：误将 `.catch(...)` 注释导致闭包大括号孤立。
- **修复**：重构为 Promise 链式写法，精准对齐 `this.mainWindow` 277 字节，成功自弹 DevTools 调试窗口。

### 阶段四：发现最核心隐藏 BUG——17.4KB HTML 容量门槛
- **现象**：DevTools 开启后，审查到了 `<img class="user-menu-trigger-avatar-img">`，但头像未更换。
- **排查**：
  1. 检查发现 `renderer/index.html` 内部居然没有 `wb-skin-style` 标签！
  2. 发现之前将 550KB 巨型 Base64 写入 `skin.js`，导致 HTML 总体积达 500+ KB。
  3. ASAR 缝合引擎设有用以安全的防崩门槛 `if (currentByteLengthHtml <= maxSizeHtml)`，而原厂 `index.html` 上限仅为 **17,415 字节 (17.4 KB)**！
  4. `500 KB > 17.4 KB`，引擎**静默跳过了 `index.html` 的注入**！
- **修复**：重构为 **8 KB 超紧凑框架**（`skin.css` 仅 1.1 KB，`skin.js` 仅 6.8 KB），直接引用已覆写的硬核 PNG。

### 阶段五：釜底抽薪与双重强压部署
- **最终落地**：8 KB 框架成功通过 17.4 KB 门槛，`wb-skin-style? true` 校验通过，物理原图原位替换，全套 UI 黑化与提示词破甲无缝生效！

---

## 5. 文件输出说明

本报告已被完整保存至以下系统绝对路径，您可以直接在 Windows 资源管理器中查看或迁移：

- **项目目录文件**: `.\WorkBuddy_Reverse_Engineering_Report.md`
- **对话 Artifact 目录**: `./assets/workbuddy_reverse_engineering_report.md`
