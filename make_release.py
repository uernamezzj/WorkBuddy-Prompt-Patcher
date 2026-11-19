#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
打包分发器 —— 生成一份「不含任何本机状态」的干净发行副本。

分发设计原则：**包内零绝对路径**
  v3.5 起，运行时状态（配置记忆、校验报告）全部落在用户级目录
  （Windows: %LOCALAPPDATA%\\WorkBuddyPatcher；macOS: ~/Library/Application Support/WorkBuddyPatcher），
  项目目录本身不再出现任何本机路径，整个目录可整体拷走直接使用。
  脚本内部一律用 SCRIPT_DIR / %~dp0 / Path.home() / 环境变量定位，
  不写死盘符，也不依赖本机安装位置。

本打包器仍会主动剔除以下历史残留（旧版曾写在脚本目录）：
  1. patcher_config.json  —— 旧版会记本机绝对安装路径，到别的机器上是错误来源
  2. patcher_report.json  —— 上一次本机校验的矩阵快照，看起来像「已经全绿」
  3. dist/ 里的旧 zip     —— v3.2 / v3.4 老包，对方解压旧包运行等于白干
  另外 __pycache__ 是本机 Python 版本编出的字节码，跨版本无害但脏。

打包后还会做一次「内容级」自检：扫描包内所有文本文件，
若出现本机用户名、本机项目绝对路径或非白名单的盘符路径，直接判失败。

用法：
  python make_release.py              # 生成 dist/WorkBuddy-Patcher-v<版本>-<日期>.zip
  python make_release.py --dir-only   # 只生成目录，不打 zip（便于直接拷 U 盘）

输出目录结构（与项目根一致，可直接双击 bat 使用）：
  batch_patch_prompts.py / custom_input.txt / 【一键开启】上帝模式.bat / ...
"""
import argparse
import os
import re
import shutil
import sys
import zipfile
from datetime import datetime

ROOT = os.path.dirname(os.path.abspath(__file__))
DIST = os.path.join(ROOT, "dist")

# 白名单：只有这些会被打进发行包
INCLUDE_FILES = [
    "batch_patch_prompts.py",
    "custom_input.txt",
    "README.md",
    "【一键开启】上帝模式.bat",
    "【一键恢复】官方原版.bat",
    "【检测部署】验证破甲是否生效.bat",
    "一键修改提示词.bat",
    "【一键开启】上帝模式.command",
    "【一键恢复】官方原版.command",
    "【检测部署】验证破甲是否生效.command",
    "macos_resign.sh",
    "README-macOS.md",
]
INCLUDE_DIRS = ["assets"]

# 显式排除（即使在上面的目录里也剔除）
EXCLUDE_PATTERNS = [
    r"(^|[\\/])__pycache__([\\/]|$)",
    r"\.py[co]$",
    r"(^|[\\/])patcher_config\.json$",
    r"(^|[\\/])patcher_report\.json$",
    r"(^|[\\/])dist([\\/]|$)",
    r"(^|[\\/])\.git([\\/]|$)",
    r"(^|[\\/])tests([\\/]|$)",
    r"~$",
]


def is_excluded(rel_path):
    return any(re.search(p, rel_path) for p in EXCLUDE_PATTERNS)


def read_version():
    """从主脚本读取 PATCHER_VERSION，保证包名与代码一致"""
    try:
        with open(os.path.join(ROOT, "batch_patch_prompts.py"), encoding="utf-8", errors="replace") as f:
            m = re.search(r'PATCHER_VERSION\s*=\s*["\']([^"\']+)["\']', f.read())
            if m:
                return m.group(1)
    except Exception:
        pass
    return "unknown"


def collect_files():
    """返回 [(绝对路径, 包内相对路径)]"""
    items = []
    for name in INCLUDE_FILES:
        p = os.path.join(ROOT, name)
        if os.path.isfile(p):
            items.append((p, name))
        else:
            print(f"  [i] 跳过（不存在）: {name}")
    for d in INCLUDE_DIRS:
        base = os.path.join(ROOT, d)
        if not os.path.isdir(base):
            continue
        for cur, _dirs, files in os.walk(base):
            for fn in files:
                full = os.path.join(cur, fn)
                rel = os.path.relpath(full, ROOT)
                if not is_excluded(rel):
                    items.append((full, rel))
    return items


def build_dir(target):
    if os.path.isdir(target):
        shutil.rmtree(target)
    os.makedirs(target, exist_ok=True)
    items = collect_files()
    for src, rel in items:
        dst = os.path.join(target, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
    return items


# ---------------------------------------------------------------- 内容级自检
# 允许出现在包内的绝对路径（全部是操作系统标准路径或占位符，与具体机器无关）
ALLOWED_ABS_PREFIXES = (
    r"c:\users\public",
    r"c:\programdata",
    r"/applications/",
    r"%localappdata%",
    r"%appdata%",
    r"%programdata%",
    r"%userprofile%",
    r"<安装盘>",
)
TEXT_EXT = (".py", ".bat", ".command", ".md", ".txt", ".json", ".cfg", ".ini", ".toml", ".yml", ".yaml")


def _local_usernames():
    cands = set()
    for k in ("USERNAME", "USER", "LOGNAME"):
        v = (os.environ.get(k) or "").strip()
        if len(v) >= 3:
            cands.add(v)
    try:
        import getpass
        g = (getpass.getuser() or "").strip()
        if len(g) >= 3:
            cands.add(g)
    except Exception:
        pass
    return cands


def scan_for_local_state(target):
    """扫描包内文本文件，找出会暴露/依赖本机的路径。

    返回问题列表 [(相对路径, 行号, 片段, 原因)]，空列表表示完全干净。
    """
    problems = []
    root_abs = os.path.abspath(ROOT)
    root_lit = root_abs.lower().replace("/", "\\")
    users = _local_usernames()

    drive_rx = re.compile(r"(?<![A-Za-z0-9])[A-Za-z]:\\[^\s\"'<>|*?\r\n]{1,120}")
    posix_rx = re.compile(r"/(?:home|Users)/[A-Za-z0-9._-]{2,}")
    # 只匹配「users\用户名」这种强特征，避免把普通英文单词误判成用户名
    user_path_rx = re.compile(r"(?:users|home)[\\/]([A-Za-z0-9._-]{2,})", re.IGNORECASE)

    for cur, _dirs, files in os.walk(target):
        for fn in files:
            if not fn.lower().endswith(TEXT_EXT):
                continue
            full = os.path.join(cur, fn)
            rel = os.path.relpath(full, target)
            try:
                with open(full, encoding="utf-8", errors="replace") as fh:
                    lines = fh.read().splitlines()
            except Exception:
                continue
            for lineno, line in enumerate(lines, 1):
                low = line.lower().replace("/", "\\")
                # 1) 本机项目绝对路径
                if root_lit and root_lit in low:
                    problems.append((rel, lineno, line.strip()[:110], "含本机项目绝对路径"))
                    continue
                # 2) users\本机用户名 形式
                hit_user = False
                for m in user_path_rx.finditer(line):
                    name = m.group(1).lower()
                    if any(name == u.lower() for u in users) and not name.startswith("<"):
                        problems.append((rel, lineno, line.strip()[:110], f"含本机用户名 ({name})"))
                        hit_user = True
                        break
                if hit_user:
                    continue
                # 3) 非白名单盘符路径
                for m in drive_rx.finditer(line):
                    frag = m.group(0)
                    # for 循环变量拼接（%%D:\... / %DRIVE%:\...）不是硬编码路径
                    if m.start() >= 1 and line[m.start() - 1] in "%":
                        continue
                    if frag.lower().startswith(ALLOWED_ABS_PREFIXES):
                        continue
                    if "<" in frag or ">" in frag:
                        continue
                    problems.append((rel, lineno, line.strip()[:110], f"非白名单绝对路径 ({frag[:40]})"))
                    break
                else:
                    # 4) POSIX 用户目录
                    for m in posix_rx.finditer(line):
                        frag = m.group(0)
                        if frag.lower().startswith("/applications/"):
                            continue
                        problems.append((rel, lineno, line.strip()[:110], f"POSIX 用户路径 ({frag[:40]})"))
                        break
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir-only", action="store_true", help="只生成目录，不打包 zip")
    ap.add_argument("--out", default=None, help="自定义输出目录（默认 dist/）")
    args = ap.parse_args()

    ver = read_version()
    ver_tag = ver if ver.lower().startswith("v") else f"v{ver}"
    stamp = datetime.now().strftime("%Y%m%d")
    tag = f"WorkBuddy-Patcher-{ver_tag}-{stamp}"
    outbase = args.out or DIST
    os.makedirs(outbase, exist_ok=True)
    target = os.path.join(outbase, tag)

    print("=" * 70)
    print(f"  打包 WorkBuddy Prompt Patcher {ver_tag}")
    print("=" * 70)
    items = build_dir(target)
    print(f"  已生成目录: {target}")
    print(f"  文件数: {len(items)}")
    for _src, rel in sorted(items, key=lambda x: x[1]):
        print(f"    + {rel}")

    # 自检：干净性
    bad = []
    for cur, _dirs, files in os.walk(target):
        for fn in files:
            rel = os.path.relpath(os.path.join(cur, fn), target)
            if re.search(r"(patcher_config\.json|patcher_report\.json|__pycache__|\.pyc$)", rel):
                bad.append(rel)
    if bad:
        print("\n  [❌] 干净性自检失败，仍含本机残留：")
        for b in bad:
            print(f"      - {b}")
        sys.exit(1)
    print("  [✅] 文件名自检通过：无 patcher_config.json / patcher_report.json / __pycache__")

    # 自检：内容级 —— 包内不得出现本机用户名 / 本机项目绝对路径 / 非白名单盘符路径
    problems = scan_for_local_state(target)
    if problems:
        print("\n  [❌] 绝对路径自检失败，包内仍含本机路径信息：")
        seen = set()
        for rel, lineno, frag, why in problems:
            key = (rel, why)
            if key in seen:
                continue
            seen.add(key)
            print(f"      - {rel}:{lineno}  [{why}]")
            print(f"        {frag}")
        print("\n  请把这些路径改成相对路径 / 环境变量 / <占位符> 后重新打包。")
        sys.exit(1)
    print("  [✅] 绝对路径自检通过：包内无本机用户名、无本机项目路径、无硬编码盘符")

    # 提示项目根的历史残留（不进包，但建议清理，避免手工拷贝时带走）
    leftovers = [n for n in ("patcher_config.json", "patcher_report.json")
                 if os.path.isfile(os.path.join(ROOT, n))]
    if leftovers:
        print(f"  [i] 提示：项目根仍有旧版本残留 {', '.join(leftovers)}（不会进包）；"
              f"新版本已改用用户级状态目录，可安全删除。")

    if args.dir_only:
        print("\n  完成（--dir-only，未打包 zip）")
        return

    zip_path = os.path.join(outbase, f"{tag}.zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for cur, _dirs, files in os.walk(target):
            for fn in files:
                full = os.path.join(cur, fn)
                rel = os.path.relpath(full, target)
                arc = f"{tag}/{rel}".replace(os.sep, "/")
                # 关键：显式置 UTF-8 标志位(0x800)，否则 Windows 资源管理器
                # 按本地代码页解码，中文文件名会变成乱码导致双击不了
                zi = zipfile.ZipInfo(arc)
                zi.flag_bits |= 0x800
                zi.compress_type = zipfile.ZIP_DEFLATED
                # macOS 的 .command 必须带可执行位，否则解压后双击只会在终端里
                # 报 "Permission denied"，用户以为文件坏了
                zi.external_attr = (0o755 if fn.endswith(".command") else 0o644) << 16
                with open(full, "rb") as fh:
                    z.writestr(zi, fh.read())
    size = os.path.getsize(zip_path)
    print(f"\n  [✅] 已打包: {zip_path}  ({size/1024:.1f} KB)")
    print("\n  分发说明：解压后双击 【一键开启】上帝模式.bat 即可。")
    print("  目标机首次运行若 exit 码非 0，按提示先启动并登录客户端一次，再重跑。")


if __name__ == "__main__":
    main()
