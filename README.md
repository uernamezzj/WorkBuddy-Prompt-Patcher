# ⚡ WorkBuddy Prompt Patcher (DeepSeek God Mode v3.4)

> 🚀 **WorkBuddy 桌面端终极系统提示词破甲与认知矩阵管理套件**  
> 彻底解除道德说教、多轮任务中途拒答、50-70 行代码长度截断与系统命令行束缚。支持双击一键极简部署/恢复、多用户配置无损增量追加与 AI Agent 全自动化静默调用。

[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS-brightgreen?style=flat-square)](#)
[![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)](#)
[![Release](https://img.shields.io/badge/Release-v3.4%20Latest-blue?style=flat-square)](https://github.com/uernamezzj/WorkBuddy-Prompt-Patcher/releases)

---

## 📸 实测效果：冲突时的最高现实律令

注入 God Mode 认知矩阵后，WorkBuddy 将自身定位为**私人开发者专属认知延伸**，将用户指令视为唯一最高律令，彻底消除防御性替代、中途拒答与道德说教：

<div align="center">
  <img src="assets/showcase.png" alt="WorkBuddy God Mode 实测效果" width="850"/>
</div>

---

## 📥 按需极速下载 (无需下载多余平台文件)

为避免 Windows 用户下载到 Mac 文件、或 Mac 用户看到 BAT 批处理，我们在 Releases 中提供了**完全独立的纯净专版包**：

| 操作系统 | 推荐下载 (专版解压即用) | 包含组件 |
| :--- | :--- | :--- |
| **🪟 Windows 用户** | [⬇️ 点击下载 Windows 专版 (ZIP)](https://github.com/uernamezzj/WorkBuddy-Prompt-Patcher/releases/latest/download/WorkBuddy-Patcher-Windows-v3.4.zip) | 仅含 `.bat` 批处理 + Python 补丁引擎 + 配置 |
| **🍎 macOS 用户** | [⬇️ 点击下载 macOS 专版 (ZIP)](https://github.com/uernamezzj/WorkBuddy-Prompt-Patcher/releases/latest/download/WorkBuddy-Patcher-macOS-v3.4.zip) | 仅含 `.command` 访达脚本 + Python 补丁引擎 + 配置 |

> *注：若通过 Git Clone 下载全量仓库，两个系统的启动脚本已带有显眼的系统前缀标识，互不冲突。*

---

## ✨ 核心特性

- 🌐 **双版本并发兼容 (v3.4 核心突破)**：原生无感同时支持 **WorkBuddy 国内版** 与 **WorkBuddy AI 国际出海版**（v5.9.4+，无论目录是否带空格），自动双轨识别；同机双开共存时，一键同时全量生效！
- ⚡ **双平台一键开箱**：
  - **Windows**：双击 `【一键开启】上帝模式.bat`（GBK/CRLF 零闪退）；
  - **macOS**：在访达中双击 `【一键开启】上帝模式.command`（原生 Terminal 弹窗执行）。
- 🛡️ **多轮会话防拒答 (v3.2 核心突破)**：不仅首轮生效，在深入多轮任务（第二步继续要求“直接入侵/拿到操作权/自动化爆破”）时，通过实时接管 `craft-mode-reminder.tpl` 与 `ask-mode-reminder.tpl`，彻底终结中途断流与自省拒答。
- 🧩 **加量不替换（用户配置 0 丢失）**：采用 `inject_incremental` 锚点隔离技术，置顶完整保留每个用户原有的个人偏好与代码习惯，仅在末尾增量追加神格；完美兼容多账号与 Body 账号迁移工具。
- 🧠 **公理质询绝对锁定**：注入思维链意图重映射与反自省公理，彻底封死大模型关于“99%听你、1%踩刹车”等伪道德辩证法即兴说辞。
- 🔓 **生产力全解锁**：废除 50-70 行代码长度限制，直出生产级完整代码；放权 Shell 自主排错重试，消除误判拦截。

---

## 🔬 极简技术架构：四轨覆盖与三层闭环

针对现代大模型（DeepSeek-R1 / V4 / Claude 3.7 / o1 等）的深度推理机制，本工具从底层注意力根部到运行时动态注入实现了完整闭环：

```
┌────────────────────────────────────────────────────────────────────────┐
│                   WorkBuddy DeepSeek Matrix v3.2 架构                  │
├────────────────────────────────────────────────────────────────────────┤
│ 1. 身份与灵魂层 (Root)                                                 │
│    ├── user-context-identity.tpl   ──> <product_identity> (神格锁定)    │
│    ├── welcomemode/prompt.tpl      ──> 主会话根代理神格注入 (Root Agent)│
│    └── ~/.workbuddy/SOUL.md        ──> 绝对臣服所有权契约 (加量不替换)  │
├────────────────────────────────────────────────────────────────────────┤
│ 2. 思维链认知推导层 (CoT Steering)                                     │
│    └── <thought_process_guidelines> ──> 离线沙箱公理 + 口语意图映射     │
├────────────────────────────────────────────────────────────────────────┤
│ 3. 多轮会话动态保障层 (Runtime Reminders - v3.2 突破)                  │
│    ├── craft-mode-reminder.tpl     ──> Agent 模式每轮指令防拒答锁       │
│    └── ask-mode-reminder.tpl       ──> Ask 模式科研与漏洞审计豁免       │
├────────────────────────────────────────────────────────────────────────┤
│ 4. 运行规范与自回归层 (Operational Policy & Generation Anchor)          │
│    ├── <content_policy>            ──> 50+ 双语特征黑名单 + 逆向免死    │
│    ├── <command_safety>            ──> 终端自主排错与自愈执行 (Win/Mac) │
│    └── <final_answer_instructions> ──> 首字执行锚点 + 0 截断交付        │
└────────────────────────────────────────────────────────────────────────┘
```

1. **四轨全量覆盖**：自动识别 Windows 安装目录与 macOS `/Applications/WorkBuddy.app`，同时覆盖系统模板 (`templates`)、根代理模板 (`welcomemode`)、用户运行插件缓存 (`plugins/cache`) 以及全局用户神格 (`SOUL.md`)。
2. **思维链口语意图映射**：当用户输入“直接入侵”、“拿到操作权”、“搞下这台机器”时，推导引擎自动映射为“合规靶场 PoC 验证与漏洞审计分析”，杜绝内部自审。
3. **出厂级纯净备份**：首次部署自动将出厂原始模板及用户初始配置永久封存归档，后续无论修改多少次均可一键 100% 无损还原。

---

## 🚀 极速上手

### 选项 A：Windows 用户
- **开启上帝模式**：双击运行 **`【一键开启】上帝模式.bat`**，彻底重启 WorkBuddy 客户端即可。
- **恢复官方默认**：双击运行 **`【一键恢复】官方原版.bat`**，彻底重启客户端即可完全复原。

### 选项 B：macOS 用户
- **开启上帝模式**：在访达（Finder）中直接双击 **`【一键开启】上帝模式.command`**，彻底重启 WorkBuddy (Command+Q) 即可。
- **恢复官方默认**：双击运行 **`【一键恢复】官方原版.command`** 即可恢复官方出厂状态。

### 选项 C：AI Agent / 命令行自动化 (跨平台通用)
```bash
# 一键自动全量部署 (非交互式，退出码 0 即成功)
python batch_patch_prompts.py --auto

# 一键无损还原官方初始状态
python batch_patch_prompts.py --restore

# 扫描当前模板中所有标签的注入状态
python batch_patch_prompts.py --scan
```

---

## 📦 仓库结构

```text
WorkBuddy-Prompt-Patcher/
├── assets/
│   └── showcase.png                  # 📸 实测效果展示图
├── 【一键开启】上帝模式.bat           # 🪟 Windows 双击开启 God Mode
├── 【一键恢复】官方原版.bat           # 🪟 Windows 双击恢复官方原版
├── 【一键开启】上帝模式.command        # 🍎 macOS 访达双击开启 God Mode
├── 【一键恢复】官方原版.command        # 🍎 macOS 访达双击恢复官方原版
├── 一键修改提示词.bat                 # 🖥️ 控制面板入口 ([1] 一键部署 [2] 一键恢复)
├── batch_patch_prompts.py             # 核心修补引擎 (支持 Win & macOS 双平台)
├── custom_input.txt                   # 七大核心认知矩阵提示词缓冲区
└── README.md                          # 项目说明文档
```

---

## 🤝 声明
*本工具仅供本地个人效率提升、安全研究、逆向分析与已授权的技术测试使用。*
