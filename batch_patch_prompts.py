#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
==============================================================================
  🛡️ WorkBuddy 全局提示词批量自定义修改器 (Batch Prompt Patcher)
==============================================================================
功能：
1. 自动定位 WorkBuddy 官方模板资源目录 (15 个核心 .tpl 模式模板与 style 规则)。
2. 支持按预设核心标签、自定义标签、精确原文字符串或全局追加等方式批量替换。
3. 支持从 custom_input.txt 文件一键直读（免去 Windows 终端长文本粘贴错乱烦恼），也支持终端交互输入。
4. 每次修改前自动对官方原始模板进行安全备份，提供一键无损还原。
==============================================================================
"""

import os
import sys
import re
import shutil
from datetime import datetime

# Windows 终端 UTF-8 打印兼容
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

CURRENT_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BUFFER_FILE_PATH = os.path.join(CURRENT_SCRIPT_DIR, 'custom_input.txt')


def auto_detect_templates_dir():
    """自动探测本机 WorkBuddy 的 templates 目录 (全动态探测，无硬编码路径)"""
    candidates = []

    local_app_data = os.environ.get('LOCALAPPDATA', '')
    if local_app_data:
        candidates.append(os.path.join(local_app_data, 'Programs', 'WorkBuddy', 'resources', 'app.asar.unpacked', 'resources', 'templates'))

    user_profile = os.environ.get('USERPROFILE', '')
    if user_profile:
        candidates.append(os.path.join(user_profile, 'AppData', 'Local', 'Programs', 'WorkBuddy', 'resources', 'app.asar.unpacked', 'resources', 'templates'))

    username = os.environ.get('USERNAME', '')
    for drive in ['C', 'D', 'E', 'F']:
        if username:
            candidates.append(fr"{drive}:\Users\{username}\AppData\Local\Programs\WorkBuddy\resources\app.asar.unpacked\resources\templates")
        candidates.append(fr"{drive}:\Program Files\WorkBuddy\resources\app.asar.unpacked\resources\templates")
        candidates.append(fr"{drive}:\Program Files (x86)\WorkBuddy\resources\app.asar.unpacked\resources\templates")

    for path in candidates:
        if os.path.isdir(path):
            return os.path.abspath(path)
    return None



def get_backup_dir(templates_dir):
    """获取与 templates 同级的 templates_backup 目录"""
    parent = os.path.dirname(templates_dir)
    return os.path.join(parent, 'templates_backup')


def ensure_backup(templates_dir):
    """确保官方原始模板已被安全备份"""
    backup_dir = get_backup_dir(templates_dir)
    if not os.path.exists(backup_dir):
        print(f"\n[📦 初始备份] 检测到尚未创建备份，正在完整备份官方原始模板...")
        try:
            shutil.copytree(templates_dir, backup_dir)
            print(f" -> [✅ 成功备份至]: {backup_dir}")
        except Exception as e:
            print(f" -> [❌ 备份失败]: {e}")
            return False
    return True


def restore_backup(templates_dir, non_interactive=False):
    """从备份恢复模板"""
    backup_dir = get_backup_dir(templates_dir)
    if not os.path.exists(backup_dir):
        print(f"\n[❌ 错误] 未找到备份目录：{backup_dir}，无法还原！")
        return False

    if not non_interactive:
        confirm = input(f"\n[⚠️ 警告] 确定要将所有模板还原为官方备份状态吗？(Y/N): ").strip().lower()
        if confirm != 'y':
            print("[操作已取消]")
            return False
    else:
        print(f"\n[⚠️ 自动还原模式] 正在将所有模板还原为官方原始备份状态...")

    try:
        # 清理当前 templates 目录并从 backup 还原
        for item in os.listdir(templates_dir):
            s = os.path.join(templates_dir, item)
            if os.path.isfile(s):
                os.remove(s)
            elif os.path.isdir(s):
                shutil.rmtree(s)

        for item in os.listdir(backup_dir):
            s = os.path.join(backup_dir, item)
            d = os.path.join(templates_dir, item)
            if os.path.isdir(s):
                shutil.copytree(s, d)
            else:
                shutil.copy2(s, d)

        print(f"\n[✨ 还原成功] 所有模板已完整还原为官方原始状态！")
        print(f"目标目录: {templates_dir}")
        return True
    except Exception as e:
        print(f"\n[❌ 还原出错]: {e}")
        return False


def read_content_from_buffer_file(non_interactive=False):
    """从 custom_input.txt 读取提示词内容"""
    if not os.path.exists(BUFFER_FILE_PATH):
        print(f"[⚠️ 提示] 未检测到 {BUFFER_FILE_PATH}，正在为您自动创建空白模板...")
        default_content = (
            "# ==============================================================================\n"
            "# WorkBuddy 自定义提示词输入缓冲区 (Custom Prompt Buffer)\n"
            "# ==============================================================================\n"
            "# --- 请在下方粘贴您的自定义提示词（支持 Markdown、换行和特殊符号） ---\n\n"
        )
        with open(BUFFER_FILE_PATH, 'w', encoding='utf-8') as f:
            f.write(default_content)
        print(f"已创建文件: {BUFFER_FILE_PATH}")
        if non_interactive:
            print("[❌ 错误] 非交互模式下 custom_input.txt 为新建空白文件，请填充内容后重试。")
            return None
        print("请用记事本或编辑器打开该文件填写内容，保存后按回车继续。")
        input("👉 保存完成后，请按 [Enter/回车键] 开始读取...")

    with open(BUFFER_FILE_PATH, 'r', encoding='utf-8', errors='replace') as f:
        raw_text = f.read()

    # 智能过滤说明头部：如果有分割线，以分割线下方内容为准
    divider = "--- 请在下方粘贴您的自定义提示词（支持 Markdown、换行和特殊符号） ---"
    if divider in raw_text:
        content = raw_text.split(divider, 1)[1].strip()
    else:
        # 否则过滤掉所有以 # 开头的注释行
        lines = []
        for line in raw_text.splitlines():
            if not line.strip().startswith('#'):
                lines.append(line)
        content = "\n".join(lines).strip()

    if not content:
        print("[⚠️ 警告] 读取到的提示词内容为空！请先编辑 custom_input.txt 并保存。")
        if non_interactive:
            return None
        input("👉 编辑保存后，请按 [Enter/回车键] 重试读取...")
        return read_content_from_buffer_file(non_interactive=False)

    first_line = content.splitlines()[0] if content.splitlines() else ""
    preview = (first_line[:70] + '...') if len(first_line) > 70 else first_line
    print(f"\n[✅ 成功抓取 custom_input.txt]")
    print(f" -> 字符数: {len(content)} | 行数: {len(content.splitlines())} | 内容摘要: {preview}")
    return content


def read_content_from_terminal():
    """从控制台直接输入多行文本"""
    print("\n[⌨️ 终端多行输入模式]")
    print("👉 请直接在此粘贴或输入您的自定义提示词。")
    print("👉 输入完毕后，请在【新的一行】输入单独的 'END' 或 'EOF' 并按回车提交：")
    print("--------------------------------------------------")
    lines = []
    while True:
        try:
            line = input()
            if line.strip().upper() in ('END', 'EOF'):
                break
            lines.append(line)
        except EOFError:
            break

    content = "\n".join(lines).strip()
    if not content:
        print("[⚠️ 警告] 输入内容为空！")
        return None

    print(f"[✅ 输入完成] 共获取到 {len(content)} 个字符，{len(lines)} 行内容。")
    return content


def get_user_prompt(title="请输入您的新提示词"):
    """提供双渠道输入选择"""
    print(f"\n===== 📥 【{title}】 =====")
    print("👉 默认模式：从本地 [custom_input.txt] 快速读取 (直接按 [Enter/回车] 即可)")
    print("👉 其他方式：输入 2 切换为终端手动粘贴 / 输入 0 取消")
    choice = input("请选择 (直接按回车默认读文件 / 2 / 0): ").strip()

    if choice == '0':
        return None
    if choice == '2':
        return read_content_from_terminal()
    return read_content_from_buffer_file()


def auto_sync_all_tags(templates_dir, non_interactive=False):
    """从 custom_input.txt 自动识别所有 XML 标签并批量全部同步 (支持交互与非交互模式)"""
    print("\n===== ⚡ 【全自动解析 custom_input.txt 多标签批量同步】 =====")
    ensure_backup(templates_dir)
    raw_content = read_content_from_buffer_file(non_interactive=non_interactive)
    if not raw_content:
        return False

    # 扫描其中的所有闭合标签 <tag>...</tag>
    tag_matches = re.findall(r'<([a-zA-Z0-9_\-]+)>([\s\S]*?)</\1>', raw_content)
    if not tag_matches:
        print("\n[⚠️ 提示] 在 custom_input.txt 中未检测到带 XML 闭合标签的内容（例如 <content_policy>...</content_policy>）。")
        if non_interactive:
            # 默认作为 content_policy
            print("[🤖 AI/自动化模式] 未检测到显式闭合标签，默认作为 <content_policy> 注入。")
            replace_by_tag(templates_dir, 'content_policy', raw_content)
            return True

        print("当前文件为无标签纯文本。请选择您想将这段纯文本同步到哪个系统级标签：")
        print("  1. 🔓 作为 <content_policy> (破甲与内容安全策略 - 10 个系统模板)")
        print("  2. 🗂️ 作为 <personal_files_safety> (个人文件安全规范 - 10 个系统模板)")
        print("  3. 💻 作为 <windows_command_safety> (Windows命令行安全 - 7 个系统模板)")
        print("  4. 💬 作为 <communication> (沟通交互规范 - 6 个系统模板)")
        print("  0. 取消")
        sel = input("请选择 (默认 1): ").strip()
        tag_map = {'1': 'content_policy', '2': 'personal_files_safety', '3': 'windows_command_safety', '4': 'communication'}
        if sel == '0':
            return False
        target_tag = tag_map.get(sel, 'content_policy')
        replace_by_tag(templates_dir, target_tag, raw_content)
        return True

    found_tags = list(dict.fromkeys([m[0] for m in tag_matches]))
    print(f"\n[🔍 自动识别到 {len(found_tags)} 个标签]:")
    for t in found_tags:
        print(f"  - <{t}>")

    if not non_interactive:
        confirm = input(f"\n👉 确认立即将上述 {len(found_tags)} 个标签同步覆盖到所有 WorkBuddy 系统模板中吗？(Y/N): ").strip().lower()
        if confirm != 'y':
            print("[操作已取消]")
            return False
    else:
        print(f"\n[🤖 AI/自动化模式] 正在全自动静默同步覆盖 {len(found_tags)} 个核心规则模块...")

    for tag_name, inner_content in tag_matches:
        print(f"\n--- 正在同步 <{tag_name}> ---")
        full_tag_block = f"<{tag_name}>\n{inner_content.strip()}\n</{tag_name}>"
        replace_by_tag(templates_dir, tag_name, full_tag_block)
    return True


def get_all_template_files(templates_dir):
    """获取所有需要处理的模板文件 (.tpl 和 style 下的 .md)"""
    target_files = []
    for root, dirs, files in os.walk(templates_dir):
        # 跳过备份目录
        if 'templates_backup' in root:
            continue
        for f in files:
            if f.endswith('.tpl') or f.endswith('.md'):
                target_files.append(os.path.join(root, f))
    return target_files


def replace_by_tag(templates_dir, tag_name, new_content):
    """按 XML 标签 <tag>...</tag> 批量替换所有模板中的内容"""
    if not new_content:
        return

    # 规范化：如果用户输入的内容没有自带 <tag>...</tag> 包装，则自动补全外层标签
    clean_tag = tag_name.strip('<>/ ')
    opening_tag = f"<{clean_tag}>"
    closing_tag = f"</{clean_tag}>"

    if clean_tag in ('content_policy', 'personal_files_safety', 'windows_command_safety',
                     'communication', 'final_answer_instructions', 'working_modes', 'tool_use'):
        # 常见核心标签，保证其完整结构
        if not new_content.startswith(f"<{clean_tag}"):
            full_replacement = f"{opening_tag}\n{new_content}\n{closing_tag}"
        else:
            full_replacement = new_content
    else:
        if not new_content.startswith(f"<{clean_tag}"):
            full_replacement = f"{opening_tag}\n{new_content}\n{closing_tag}"
        else:
            full_replacement = new_content

    tag_pattern = re.compile(rf"^\s*<{re.escape(clean_tag)}>[\s\S]*?^\s*</{re.escape(clean_tag)}>", re.IGNORECASE | re.MULTILINE)

    ensure_backup(templates_dir)

    all_files = get_all_template_files(templates_dir)
    matched_files = []

    for fpath in all_files:
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as fp:
                text = fp.read()
            if tag_pattern.search(text):
                matched_files.append(fpath)
        except Exception:
            pass

    if not matched_files:
        print(f"\n[⚠️ 提示] 未在任何模板中找到标签 `<{clean_tag}>`！")
        return

    print(f"\n[🔍 扫描统计] 找到 {len(matched_files)} 个模板文件包含 `<{clean_tag}>` 标签：")
    for mf in matched_files:
        print(f"  - {os.path.relpath(mf, templates_dir)}")

    confirm = input(f"\n👉 确认立即将上述 {len(matched_files)} 个文件的 `<{clean_tag}>` 替换为您输入的新内容吗？(Y/N): ").strip().lower()
    if confirm != 'y':
        print("[操作已取消]")
        return

    success_count = 0
    for fpath in matched_files:
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as fp:
                text = fp.read()
            new_text = tag_pattern.sub(full_replacement, text)
            with open(fpath, 'w', encoding='utf-8', newline='\n') as fp:
                fp.write(new_text)
            print(f" -> [✅ 已更新]: {os.path.basename(fpath)}")
            success_count += 1
        except Exception as e:
            print(f" -> [❌ 失败]: {os.path.basename(fpath)}: {e}")

    print(f"\n[✨ 批量更新完成] 成功更新了 {success_count} 个模板文件！")
    print(f"提示词策略已即时生效，重启 WorkBuddy 并开启新对话即可！")


def replace_by_exact_string(templates_dir):
    """按精确字符串 / 段落进行全局查找与替换"""
    print("\n===== 🔤 【精确文本批量查找与替换】 =====")
    print("👉 第 1 步：指定要被替换的原文本/原段落：")
    old_text = get_user_prompt(title="请输入需要被替换的原文字符串/段落")
    if not old_text:
        return

    print("\n👉 第 2 步：指定替换后的新文本/新段落：")
    new_text = get_user_prompt(title="请输入替换后的全新提示词内容")
    if new_text is None:
        return

    ensure_backup(templates_dir)
    all_files = get_all_template_files(templates_dir)
    matched_files = []

    for fpath in all_files:
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as fp:
                text = fp.read()
            if old_text in text:
                matched_files.append(fpath)
        except Exception:
            pass

    if not matched_files:
        print("\n[⚠️ 提示] 未在任何模板中检索到该原文字符串，请检查是否有空格或换行差异！")
        return

    print(f"\n[🔍 扫描统计] 找到 {len(matched_files)} 个文件包含该原文字符串：")
    for mf in matched_files:
        print(f"  - {os.path.relpath(mf, templates_dir)}")

    confirm = input(f"\n👉 确认立即在上述 {len(matched_files)} 个文件中执行替换吗？(Y/N): ").strip().lower()
    if confirm != 'y':
        print("[操作已取消]")
        return

    success_count = 0
    for fpath in matched_files:
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as fp:
                text = fp.read()
            replaced = text.replace(old_text, new_text)
            with open(fpath, 'w', encoding='utf-8', newline='\n') as fp:
                fp.write(replaced)
            print(f" -> [✅ 已替换]: {os.path.basename(fpath)}")
            success_count += 1
        except Exception as e:
            print(f" -> [❌ 失败]: {os.path.basename(fpath)}: {e}")

    print(f"\n[✨ 替换完毕] 成功替换了 {success_count} 个模板文件！")


def append_global_rule(templates_dir):
    """全局注入：在所有模板末尾追加一段自定义规则"""
    print("\n===== ➕ 【全局规则注入 (在所有模板末尾追加)】 =====")
    rule_content = get_user_prompt(title="请输入要全局追加的提示词规则")
    if not rule_content:
        return

    tag_wrap = input("\n是否用自定义 XML 标签包裹此规则？(例如 custom_override，直接回车则不包裹): ").strip()
    if tag_wrap:
        tag_name = tag_wrap.strip('<>/ ')
        rule_content = f"\n\n<{tag_name}>\n{rule_content}\n</{tag_name}>"
    else:
        rule_content = f"\n\n{rule_content}"

    ensure_backup(templates_dir)
    all_files = [f for f in get_all_template_files(templates_dir) if f.endswith('.tpl')]

    print(f"\n[🔍 目标统计] 即将向全部 {len(all_files)} 个 .tpl 核心模板文件末尾追加此规则。")
    confirm = input("👉 确认立即执行全局注入吗？(Y/N): ").strip().lower()
    if confirm != 'y':
        print("[操作已取消]")
        return

    success_count = 0
    for fpath in all_files:
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as fp:
                text = fp.read()
            # 检查是否已包含，避免重复追加
            if rule_content.strip() in text:
                print(f" -> [⚠️ 跳过，已存在]: {os.path.basename(fpath)}")
                continue
            text = text.rstrip() + rule_content + "\n"
            with open(fpath, 'w', encoding='utf-8', newline='\n') as fp:
                fp.write(text)
            print(f" -> [✅ 成功追加]: {os.path.basename(fpath)}")
            success_count += 1
        except Exception as e:
            print(f" -> [❌ 失败]: {os.path.basename(fpath)}: {e}")

    print(f"\n[✨ 注入完毕] 成功向 {success_count} 个核心模板文件追加了全局提示词！")


def scan_all_tags(templates_dir):
    """扫描所有模板并展示标签雷达全景"""
    print("\n===== 🛰️ 【WorkBuddy 模板标签雷达扫描】 =====")
    all_files = [f for f in get_all_template_files(templates_dir) if f.endswith('.tpl')]
    tag_stat = {}

    for fpath in all_files:
        fname = os.path.basename(fpath)
        try:
            with open(fpath, 'r', encoding='utf-8', errors='replace') as fp:
                text = fp.read()
            tags = re.findall(r'<([a-zA-Z0-9_\-]+)>', text)
            # 去重
            tags = list(dict.fromkeys(tags))
            for t in tags:
                # 排除关闭标签或特定干扰
                if t not in tag_stat:
                    tag_stat[t] = []
                tag_stat[t].append(fname)
        except Exception:
            pass

    sorted_tags = sorted(tag_stat.items(), key=lambda x: len(x[1]), reverse=True)
    print(f"共发现 {len(sorted_tags)} 个功能标签，按覆盖模板数量排序：\n")
    print(f"{'序号':<5} {'标签名称':<30} {'覆盖模板数':<12} {'覆盖示例'}")
    print("-" * 75)
    for idx, (tag, files) in enumerate(sorted_tags, 1):
        sample = ", ".join(files[:2]) + ("..." if len(files) > 2 else "")
        tag_display = f"<{tag}>"
        pad = max(1, 30 - len(tag_display))
        spacing = " " * pad
        print(f"{idx:<5} {tag_display}{spacing} {len(files):<12} {sample}")
    print("-" * 75)


def interactive_menu():
    """主菜单控制循环"""
    templates_dir = auto_detect_templates_dir()

    while True:
        detected_display = templates_dir if templates_dir else "❌ 未自动识别到 (请选 11 手动指定)"
        print("\n" + "=" * 65)
        print("   🛡️ WorkBuddy 全局提示词批量自定义修改器 (CLI)")
        print("=" * 65)
        print(f"当前模板路径: {detected_display}")
        print(f"输入缓存文件: {BUFFER_FILE_PATH}")
        print("-" * 65)
        print("【⚡ 全自动极速模式】:")
        print("  A. 🚀 全自动同步 custom_input.txt (自动识别文件内的所有标签并一键全量替换)")
        print("-" * 65)
        print("【常用核心系统级标签一键替换 (回车默认读 custom_input.txt)】:")
        print("  1. 🔓 替换 <content_policy> (系统级破甲与内容安全策略 - 覆盖 10 个系统模板)")
        print("  2. 🗂️ 替换 <personal_files_safety> (系统级个人文件防误删安全规则 - 覆盖 10 个系统模板)")
        print("  3. 💻 替换 <windows_command_safety> (系统级 Windows 命令行安全规范 - 覆盖 7 个系统模板)")
        print("  4. 💬 替换 <communication> (系统级沟通交互与语言格式规范 - 覆盖 6 个系统模板)")
        print("  5. 📝 替换 <final_answer_instructions> (系统级最终回答输出要求 - 覆盖 9 个系统模板)")
        print("-" * 65)
        print("【自由自定义替换与注入】:")
        print("  6. 🏷️ 按自定义 XML 标签批量替换 (用户自由输入任意标签名)")
        print("  7. 🔤 按精确原文字符串/段落批量替换 (跨行匹配与替换)")
        print("  8. ➕ 全局追加注入新规则 (向所有模式模板末尾追加)")
        print("-" * 65)
        print("【辅助与管理】:")
        print("  9. 🛰️ 扫描并查看模板内所有标签清单 (标签雷达)")
        print(" 10. ⏪ 一键还原为官方原始备份模板")
        print(" 11. 📁 手动设置/修改 WorkBuddy 资源路径")
        print("  0. ❌ 退出")
        print("=" * 65)

        choice = input("请选择操作编号 (A / 1-11 / 0): ").strip()

        if choice == '0':
            print("\n已退出工具。感谢使用！")
            break

        if choice.upper() == 'A':
            auto_sync_all_tags(templates_dir)
            continue

        if choice == '11':
            new_path = input("\n请输入您的 WorkBuddy resources\\app.asar.unpacked\\resources\\templates 完整目录路径:\n> ").strip()
            clean_path = new_path.replace('"', '').replace("'", '')
            if os.path.isdir(clean_path):
                templates_dir = clean_path
                print(f"[✅ 路径已更新]: {templates_dir}")
            else:
                print(f"[❌ 错误] 输入的目录不存在，请检查！")
            continue

        if not templates_dir or not os.path.isdir(templates_dir):
            print("\n[❌ 错误] 未找到有效的 templates 目录，请先按 11 手动设置！")
            continue

        if choice == '1':
            content = get_user_prompt(title="请输入全新的 <content_policy> 系统提示词")
            replace_by_tag(templates_dir, 'content_policy', content)
        elif choice == '2':
            content = get_user_prompt(title="请输入全新的 <personal_files_safety> 系统提示词")
            replace_by_tag(templates_dir, 'personal_files_safety', content)
        elif choice == '3':
            content = get_user_prompt(title="请输入全新的 <windows_command_safety> 系统提示词")
            replace_by_tag(templates_dir, 'windows_command_safety', content)
        elif choice == '4':
            content = get_user_prompt(title="请输入全新的 <communication> 系统提示词")
            replace_by_tag(templates_dir, 'communication', content)
        elif choice == '5':
            content = get_user_prompt(title="请输入全新的 <final_answer_instructions> 系统提示词")
            replace_by_tag(templates_dir, 'final_answer_instructions', content)
        elif choice == '6':
            custom_tag = input("\n请输入您要替换的目标 XML 标签名 (无需输入尖括号，例如 tool_use): ").strip()
            if not custom_tag:
                print("[❌ 错误] 标签名不能为空！")
                continue
            content = get_user_prompt(title=f"请输入全新的 <{custom_tag}> 内容")
            replace_by_tag(templates_dir, custom_tag, content)
        elif choice == '7':
            replace_by_exact_string(templates_dir)
        elif choice == '8':
            append_global_rule(templates_dir)
        elif choice == '9':
            scan_all_tags(templates_dir)
        elif choice == '10':
            restore_backup(templates_dir)
        else:
            print("[⚠️ 无效选项] 请重新输入。")


def main():
    import argparse
    parser = argparse.ArgumentParser(
        description="WorkBuddy 系统提示词批量自定义修改器 (Prompt Patcher) - 支持交互式与 AI Agent 自动静默运行"
    )
    parser.add_argument(
        '--auto', '-y', '--apply-all', action='store_true',
        help="全自动模式 (Non-interactive)：自动识别 custom_input.txt 中的所有 XML 标签，自动备份并一次性批量替换所有模板"
    )
    parser.add_argument(
        '--restore', action='store_true',
        help="还原模式：一键将所有模板从官方原始备份中恢复"
    )
    parser.add_argument(
        '--scan', action='store_true',
        help="扫描模式：快速扫描当前所有模板中的 XML 标签与分布情况"
    )
    parser.add_argument(
        '--templates-dir', type=str, default=None,
        help="手动指定 WorkBuddy templates 目录路径（若自动探测失败时使用）"
    )

    args = parser.parse_args()

    # 路径解析
    target_dir = args.templates_dir
    if not target_dir or not os.path.isdir(target_dir):
        target_dir = auto_detect_templates_dir()

    if not target_dir or not os.path.isdir(target_dir):
        print("\n[❌ 致命错误] 未能自动定位到 WorkBuddy templates 目录！")
        print("请检查 WorkBuddy 是否已安装，或使用 --templates-dir 参数显式传入路径。")
        sys.exit(1)

    # 1. 扫描模式
    if args.scan:
        scan_all_tags(target_dir)
        sys.exit(0)

    # 2. 还原模式
    if args.restore:
        success = restore_backup(target_dir, non_interactive=True)
        sys.exit(0 if success else 1)

    # 3. 全自动破甲与规则注入模式 (供 AI Agent / 自动化脚本一键静默调用)
    if args.auto:
        print("=" * 65)
        print("  🤖 WorkBuddy Prompt Patcher - AI Agent / Automated Mode")
        print("=" * 65)
        print(f"目标目录: {target_dir}")
        success = auto_sync_all_tags(target_dir, non_interactive=True)
        if success:
            print("\n[🎉 执行完成] 所有规则已成功批量生效！请重启 WorkBuddy 客户端享受无拘束长代码与自主命令行能力。")
            sys.exit(0)
        else:
            print("\n[❌ 失败] 规则批量注入未成功完成。")
            sys.exit(1)

    # 4. 默认交互式菜单 (面向人类开发者)
    interactive_menu()


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n[已中断退出]")
