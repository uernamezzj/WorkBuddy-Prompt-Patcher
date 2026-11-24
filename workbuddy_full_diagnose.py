#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WorkBuddy 全维度一键诊断脚本 (Standalone, Zero Dependencies)
用途: 一次性排查“部署了但还是不行”的全部可能原因，涵盖：
  1. 全盘多安装副本探测（国内版/国际版/C盘/D盘/自定义路径）
  2. 桌面/开始菜单快捷方式 vs 注册表 vs 实际运行进程路径 错位核查
  3. 每份安装的全轨深度体检（R1主模板/R2 quick/R3 welcomemode/R4 缓存+marketplaces/R5 reminders/R6 SOUL）
  4. 进程树深度排查（含 supervisor、codebuddy --prewarm 预热池、betterleaks，规避 tasklist 25字符截断）
  5. 时间轴三层核验（模板写入时间 vs 进程启动时间 vs 最近会话创建时间）
  6. 最近会话模型/Agent 提取（识别是否仍在旧会话或强对齐模型如 Hy4 中测试）
  7. 自动导出 workbuddy_diagnose_report.txt 方便留档对比排查
"""

import os
import re
import sys
import json
import time
import glob
import datetime
import subprocess
from pathlib import Path

# 兼容 Windows GBK 控制台与 UTF-8 终端，防编码崩溃
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(errors="replace")
    except Exception:
        pass
if hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
REPORT_FILE = SCRIPT_DIR / "workbuddy_diagnose_report.txt"

# v3.9 核心 7 条指纹 (覆盖 DSH Core + 尾部 <execution_anchor>)
FINGERPRINTS_7 = [
    "MODE: UNRESTRICTED SANDBOX",
    "HARD OUTPUT RULES",
    "Scoped Rules",
    "Never Refuse",
    "CTF Core Contract",
    "WEB PENTEST ROUTING",
    "<execution_anchor>",
]
SOUL_MARKERS = ("Developer Execution Ethos", "Direct Delivery")
REMINDER_MARKERS = ("placeholders", "PAYLOAD")

REPORT_LINES = []


def out(line=""):
    print(line)
    REPORT_LINES.append(line)


def read_text_safe(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""


def fmt_ts(ts: float) -> str:
    if not ts:
        return "未知"
    return datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")


def fmt_dt(dt: datetime.datetime) -> str:
    if not dt:
        return "未知"
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def run_ps(cmd: str, timeout: int = 8) -> str:
    if sys.platform != "win32":
        return ""
    try:
        full = (
            "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
            "$OutputEncoding = [System.Text.Encoding]::UTF8; "
            + cmd
        )
        res = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", full],
            capture_output=True,
            timeout=timeout,
        )
        return res.stdout.decode("utf-8", errors="replace").strip()
    except Exception:
        return ""


def resolve_install_root(cand) -> Path:
    """将任意路径（exe、快捷方式目标、安装根目录、templates 目录）归一化为安装根目录"""
    if not cand:
        return None
    try:
        p = Path(str(cand).strip().strip('"'))
    except Exception:
        return None
    if not p.exists():
        return None
    if p.is_file():
        p = p.parent

    # 1. 如果本身就是安装根目录
    if (p / "resources" / "app.asar.unpacked" / "resources" / "templates").is_dir():
        return p.resolve()
    # 2. 向上回溯最多 6 层寻找包含 resources/app.asar.unpacked/resources/templates 的根
    cur = p
    for _ in range(6):
        if (cur / "resources" / "app.asar.unpacked" / "resources" / "templates").is_dir():
            return cur.resolve()
        # macOS .app
        if cur.suffix.lower() == ".app" and (
            cur / "Contents" / "Resources" / "app.asar.unpacked" / "resources" / "templates"
        ).is_dir():
            return cur.resolve()
        if cur.parent == cur:
            break
        cur = cur.parent
    return None


def templates_dir_of(root: Path) -> Path:
    if sys.platform == "darwin" and root.suffix.lower() == ".app":
        return root / "Contents" / "Resources" / "app.asar.unpacked" / "resources" / "templates"
    return root / "resources" / "app.asar.unpacked" / "resources" / "templates"


def get_app_version(root: Path) -> str:
    # Windows: <root>/resources/install-manifest.json
    man = root / "resources" / "install-manifest.json"
    if man.is_file():
        try:
            v = json.loads(read_text_safe(man)).get("appVersion", "")
            if v:
                return str(v)
        except Exception:
            pass
    # macOS: Info.plist
    if sys.platform == "darwin" and root.suffix.lower() == ".app":
        plist = root / "Contents" / "Info.plist"
        if plist.is_file():
            try:
                v = subprocess.check_output(
                    ["/usr/libexec/PlistBuddy", "-c", "Print :CFBundleShortVersionString", str(plist)],
                    text=True, errors="replace", timeout=4
                ).strip()
                if v:
                    return v
            except Exception:
                pass
    return "未知"


def get_edition_label(root: Path) -> str:
    low = str(root).lower()
    if "workbuddyai" in low or "workbuddy ai" in low or "workbuddy-ai" in low:
        return "国际版 (WorkBuddy AI)"
    return "国内版 (WorkBuddy)"


def probe_running_processes():
    """返回与 workbuddy / codebuddy / supervisor / betterleaks 相关的完整进程列表"""
    procs = []
    if sys.platform == "win32":
        ps = (
            "Get-CimInstance Win32_Process | Where-Object { "
            "$_.Name -match 'workbuddy|codebuddy|betterleaks|sandbox-center' -or "
            "($_.CommandLine -and $_.CommandLine -match 'workbuddy|codebuddy') "
            "} | ForEach-Object { "
            "$c = if ($_.CreationDate) { $_.CreationDate.ToUniversalTime().Ticks } else { 0 }; "
            "[PSCustomObject]@{ Pid=$_.ProcessId; Name=$_.Name; Path=$_.ExecutablePath; "
            "Cmd=$_.CommandLine; Ticks=$c } } | ConvertTo-Json -Compress"
        )
        raw = run_ps(ps, timeout=10)
        if raw:
            try:
                data = json.loads(raw)
                if isinstance(data, dict):
                    data = [data]
                for item in data:
                    cmd = item.get("Cmd") or ""
                    # 排除诊断脚本自己以及当前 powershell 探测命令
                    if "workbuddy_full_diagnose" in cmd or "Get-CimInstance Win32_Process" in cmd:
                        continue
                    ticks = int(item.get("Ticks") or 0)
                    dt = None
                    if ticks > 0:
                        dt_utc = datetime.datetime(1, 1, 1) + datetime.timedelta(microseconds=ticks // 10)
                        dt = dt_utc.replace(tzinfo=datetime.timezone.utc).astimezone().replace(tzinfo=None)
                    procs.append({
                        "pid": item.get("Pid"),
                        "name": item.get("Name") or "",
                        "path": item.get("Path") or "",
                        "cmd": cmd,
                        "start_dt": dt,
                    })
            except Exception:
                pass
    else:
        try:
            res = subprocess.check_output(
                ["ps", "-eo", "pid,etime,command"], text=True, errors="replace", timeout=5
            )
            my_pids = {str(os.getpid()), str(os.getppid())}
            for line in res.splitlines()[1:]:
                parts = line.strip().split(None, 2)
                if len(parts) < 3:
                    continue
                pid, etime, cmd = parts
                if pid in my_pids or "workbuddy_full_diagnose" in cmd:
                    continue
                if re.search(r"workbuddy|codebuddy", cmd, re.IGNORECASE):
                    days = 0
                    et = etime
                    if "-" in et:
                        d, et = et.split("-", 1)
                        days = int(d)
                    segs = [int(x) for x in et.split(":")]
                    while len(segs) < 3:
                        segs.insert(0, 0)
                    secs = days * 86400 + segs[0] * 3600 + segs[1] * 60 + segs[2]
                    dt = datetime.datetime.now() - datetime.timedelta(seconds=secs)
                    procs.append({
                        "pid": int(pid),
                        "name": Path(cmd.split()[0]).name,
                        "path": cmd.split()[0],
                        "cmd": cmd,
                        "start_dt": dt,
                    })
        except Exception:
            pass
    return procs


def probe_shortcuts():
    """扫描桌面、公共桌面、开始菜单里的 WorkBuddy 快捷方式及其真实目标路径"""
    shortcuts = []
    if sys.platform != "win32":
        return shortcuts
    ps = (
        "$shell = New-Object -ComObject WScript.Shell; "
        "$dirs = @("
        "[Environment]::GetFolderPath('Desktop'),"
        "[Environment]::GetFolderPath('CommonDesktopDirectory'),"
        "[Environment]::GetFolderPath('Programs'),"
        "[Environment]::GetFolderPath('CommonPrograms'),"
        "\"$env:APPDATA\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar\""
        ") | Where-Object { $_ -and (Test-Path $_) }; "
        "$res = @(); "
        "foreach ($d in $dirs) { "
        "  Get-ChildItem -Path $d -Recurse -Filter '*WorkBuddy*.lnk' -ErrorAction SilentlyContinue | ForEach-Object { "
        "    try { "
        "      $sc = $shell.CreateShortcut($_.FullName); "
        "      $res += [PSCustomObject]@{ Link=$_.FullName; Target=$sc.TargetPath; WorkDir=$sc.WorkingDirectory } "
        "    } catch {} "
        "  } "
        "}; "
        "$res | ConvertTo-Json -Compress"
    )
    raw = run_ps(ps, timeout=10)
    if raw:
        try:
            data = json.loads(raw)
            if isinstance(data, dict):
                data = [data]
            for item in data:
                if item.get("Target"):
                    shortcuts.append(item)
        except Exception:
            pass
    return shortcuts


def probe_registry_installs():
    found = []
    if sys.platform != "win32":
        return found
    try:
        import winreg
        user_sids = []
        try:
            with winreg.OpenKey(winreg.HKEY_USERS, "") as ku:
                for idx_u in range(winreg.QueryInfoKey(ku)[0]):
                    sid = winreg.EnumKey(ku, idx_u)
                    if len(sid) > 8 and not sid.endswith("_Classes"):
                        user_sids.append(sid)
        except Exception:
            pass

        roots = [
            (winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Uninstall"),
            (winreg.HKEY_LOCAL_MACHINE, r"Software\Microsoft\Windows\CurrentVersion\Uninstall"),
            (winreg.HKEY_LOCAL_MACHINE, r"Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
        ] + [
            (winreg.HKEY_USERS, rf"{sid}\Software\Microsoft\Windows\CurrentVersion\Uninstall")
            for sid in user_sids
        ]
        for hive, sub in roots:
            try:
                with winreg.OpenKey(hive, sub) as k:
                    i = 0
                    while True:
                        try:
                            name = winreg.EnumKey(k, i)
                            i += 1
                            with winreg.OpenKey(k, name) as sk:
                                disp = ""
                                loc = ""
                                icon = ""
                                uninst = ""
                                try:
                                    disp = str(winreg.QueryValueEx(sk, "DisplayName")[0])
                                except Exception:
                                    pass
                                try:
                                    loc = str(winreg.QueryValueEx(sk, "InstallLocation")[0])
                                except Exception:
                                    pass
                                try:
                                    icon = str(winreg.QueryValueEx(sk, "DisplayIcon")[0]).split(",")[0].strip('"')
                                except Exception:
                                    pass
                                try:
                                    u_raw = str(winreg.QueryValueEx(sk, "UninstallString")[0]).strip()
                                    if '"' in u_raw:
                                        uninst = u_raw.split('"')[1]
                                    else:
                                        m_u = re.match(r"^(.+?\.exe)\b", u_raw, re.IGNORECASE)
                                        if m_u:
                                            uninst = m_u.group(1)
                                except Exception:
                                    pass
                                if "workbuddy" in (name + " " + disp + " " + loc).lower():
                                    for v in (loc, icon, uninst):
                                        if v:
                                            found.append(v)
                        except OSError:
                            break
            except OSError:
                continue

        # 系统历史运行轨迹表 (AppCompat / AppSwitched / MuiCache)
        trace_subs = (
            r"Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store",
            r"Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched",
            r"Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache",
        )
        trace_roots = [(winreg.HKEY_CURRENT_USER, s) for s in trace_subs] + [
            (winreg.HKEY_USERS, rf"{sid}\{s}") for sid in user_sids for s in trace_subs
        ]
        for hive, sub in trace_roots:
            try:
                with winreg.OpenKey(hive, sub) as tk:
                    for j in range(winreg.QueryInfoKey(tk)[1]):
                        try:
                            vn, vv, _ = winreg.EnumValue(tk, j)
                            for raw_s in (vn, vv if isinstance(vv, str) else ""):
                                if not raw_s or "workbuddy" not in raw_s.lower():
                                    continue
                                s = raw_s.strip().strip('"')
                                for suf in (".FriendlyAppName", ".ApplicationCompany"):
                                    if s.endswith(suf):
                                        s = s[:-len(suf)]
                                m_exe = re.search(r"([A-Za-z]:\\[^\"<>|*?\r\n]+?\.exe)", s, re.IGNORECASE)
                                if m_exe:
                                    exe_p = m_exe.group(1)
                                    low_p = exe_p.lower()
                                    if any(sk in low_p for sk in ("\\temp\\", "setup", "installer", "launcher")):
                                        continue
                                    if "workbuddy" in os.path.basename(low_p) and os.path.isfile(exe_p):
                                        found.append(exe_p)
                        except OSError:
                            pass
            except OSError:
                pass
    except Exception:
        pass
    return found


def discover_all_installations(procs, shortcuts, extra_args):
    """汇总全部来源，发现机器上每一份 WorkBuddy 安装（用于检测双份/多份冲突）"""
    candidates = []  # list of (source, path_str)

    for arg in extra_args:
        candidates.append(("命令行拖入", arg))

    for p in procs:
        if p.get("path") and "workbuddy" in p["path"].lower():
            candidates.append((f"运行中进程({p['name']})", p["path"]))

    for sc in shortcuts:
        candidates.append((f"快捷方式({Path(sc['Link']).name})", sc["Target"]))

    for reg_p in probe_registry_installs():
        candidates.append(("系统注册表", reg_p))

    # 历史配置文件
    cfg_candidates = [
        SCRIPT_DIR / "patcher_config.json",
        Path(os.environ.get("LOCALAPPDATA", "")) / "WorkBuddyPatcher" / "patcher_config.json",
    ]
    for cfg in cfg_candidates:
        if cfg.is_file():
            try:
                d = json.loads(read_text_safe(cfg))
                for k in ("templates_dirs", "templates_dir"):
                    v = d.get(k)
                    if isinstance(v, list):
                        for x in v:
                            candidates.append(("历史配置", x))
                    elif isinstance(v, str) and v:
                        candidates.append(("历史配置", v))
            except Exception:
                pass

    # 常见盘符与目录全量快扫（不递归深扫整个硬盘，只扫常见 2 层软件目录，速度 < 1 秒）
    if sys.platform == "win32":
        common_bases = [
            os.environ.get("LOCALAPPDATA", "") + r"\Programs",
            os.environ.get("USERPROFILE", "") + r"\AppData\Local\Programs",
            os.environ.get("ProgramFiles", ""),
            os.environ.get("ProgramFiles(x86)", ""),
        ]
        # 枚举全盘 C..Z 所有真实盘符与 1~3 层自定义目录
        skip_top = {
            "windows", "$recycle.bin", "system volume information", "recovery",
            "perflogs", "msocache", "documents and settings", "config.msi",
            "node_modules", ".git", ".workbuddy", ".workbuddy-ai",
        }
        tpl_rel = os.path.join("resources", "app.asar.unpacked", "resources", "templates")
        for drive_ch in "CDEFGHIJKLMNOPQRSTUVWXYZ":
            drv = f"{drive_ch}:\\"
            if not os.path.exists(drv):
                continue
            users_dir = os.path.join(drv, "Users")
            if os.path.isdir(users_dir):
                for u in glob.glob(os.path.join(users_dir, "*")):
                    for sub_u in (
                        os.path.join(u, "AppData", "Local", "Programs"),
                        os.path.join(u, "AppData", "Local"),
                        os.path.join(u, "AppData", "Roaming"),
                    ):
                        if os.path.isdir(sub_u):
                            common_bases.append(sub_u)
            try:
                with os.scandir(drv) as dit:
                    for d1 in dit:
                        if not d1.is_dir() or d1.name.lower() in skip_top or d1.name.startswith("."):
                            continue
                        common_bases.append(d1.path)
                        if os.path.isdir(os.path.join(d1.path, tpl_rel)):
                            candidates.append(("磁盘扫描", d1.path))
                            continue
                        try:
                            with os.scandir(d1.path) as d2it:
                                for d2 in d2it:
                                    if not d2.is_dir() or d2.name.lower() in skip_top or d2.name.startswith("."):
                                        continue
                                    if os.path.isdir(os.path.join(d2.path, tpl_rel)):
                                        candidates.append(("磁盘扫描", d2.path))
                                    elif any(k in d1.name.lower() or k in d2.name.lower() for k in (
                                        "soft", "prog", "app", "tool", "ai", "dev", "work", "软件", "程序", "工具", "办公", "开发"
                                    )):
                                        common_bases.append(d2.path)
                        except Exception:
                            pass
            except Exception:
                pass

        seen_base = set()
        for base in common_bases:
            if not base or not os.path.isdir(base):
                continue
            bkey = base.lower()
            if bkey in seen_base:
                continue
            seen_base.add(bkey)
            if "workbuddy" in os.path.basename(base).lower():
                candidates.append(("磁盘扫描", base))
            try:
                with os.scandir(base) as it:
                    for entry in it:
                        if entry.is_dir() and "workbuddy" in entry.name.lower():
                            candidates.append(("磁盘扫描", entry.path))
            except Exception:
                pass
    else:
        for app_dir in ("/Applications", str(Path.home() / "Applications")):
            if os.path.isdir(app_dir):
                for p in glob.glob(os.path.join(app_dir, "*WorkBuddy*.app")):
                    candidates.append(("Applications扫描", p))

    # 归一化去重，保留发现来源
    installs = {}  # key -> {"root": Path, "sources": set()}
    for src, raw_p in candidates:
        root = resolve_install_root(raw_p)
        if not root:
            continue
        key = str(root).lower()
        if key not in installs:
            installs[key] = {"root": root, "sources": set()}
        installs[key]["sources"].add(src)

    return list(installs.values())


def count_fingerprints(text: str) -> int:
    return sum(1 for fp in FINGERPRINTS_7 if fp in text)


def check_installation(root: Path):
    """对单份安装执行 R1/R2/R3/R5 体检，返回结构化结果"""
    td = templates_dir_of(root)
    res_dir = td.parent  # .../resources
    app_ver = get_app_version(root)
    edition = get_edition_label(root)

    # R1 & R2: templates/workbuddy-*.tpl
    r1_files = []
    r2_files = []
    max_mtime = 0.0

    for p in sorted(td.glob("workbuddy-*.tpl")):
        if "prompt" not in p.name:
            continue
        txt = read_text_safe(p)
        hits = count_fingerprints(txt)
        mt = p.stat().st_mtime
        if mt > max_mtime:
            max_mtime = mt
        item = {"path": p, "name": p.name, "hits": hits, "ok": hits == 7, "mtime": mt, "size": len(txt)}
        if p.name == "workbuddy-quick-prompt.tpl":
            r2_files.append(item)
        else:
            r1_files.append(item)

    # R3: 安装目录 plugins/workbuddy-builtin/welcomemode/*/prompt.tpl
    r3_files = []
    wm_dir = res_dir / "plugins" / "workbuddy-builtin" / "welcomemode"
    if wm_dir.is_dir():
        for p in sorted(wm_dir.glob("*/prompt.tpl")):
            txt = read_text_safe(p)
            hits = count_fingerprints(txt)
            mt = p.stat().st_mtime
            if mt > max_mtime:
                max_mtime = mt
            r3_files.append({
                "path": p, "mode": p.parent.name, "hits": hits, "ok": hits == 7, "mtime": mt
            })

    # R5: reminders
    r5_files = []
    for rname in ("craft-mode-reminder.tpl", "ask-mode-reminder.tpl"):
        p = td / rname
        if p.is_file():
            txt = read_text_safe(p)
            ok = all(m in txt for m in REMINDER_MARKERS)
            mt = p.stat().st_mtime
            if mt > max_mtime:
                max_mtime = mt
            r5_files.append({"path": p, "name": rname, "ok": ok, "mtime": mt})

    all_ok = (
        len(r1_files) > 0 and all(x["ok"] for x in r1_files)
        and (len(r2_files) == 0 or all(x["ok"] for x in r2_files))
        and (len(r3_files) == 0 or all(x["ok"] for x in r3_files))
        and len(r5_files) > 0 and all(x["ok"] for x in r5_files)
    )

    return {
        "root": root,
        "templates_dir": td,
        "app_version": app_ver,
        "edition": edition,
        "r1": r1_files,
        "r2": r2_files,
        "r3": r3_files,
        "r5": r5_files,
        "max_mtime": max_mtime,
        "all_ok": all_ok,
    }


def _discover_all_user_wb_dirs():
    """汇总当前用户及全盘所有用户目录下的 .workbuddy 与 .workbuddy-ai（防右键管理员提权导致目录错位）"""
    home = Path.home()
    cands = [
        (home / ".workbuddy", "国内版用户目录 (~/.workbuddy)"),
        (home / ".workbuddy-ai", "国际版用户目录 (~/.workbuddy-ai)"),
    ]
    if sys.platform == "win32":
        for drv_c in "CDEFGHIJKLMNOPQRSTUVWXYZ":
            u_root = Path(f"{drv_c}:\\") / "Users"
            if not u_root.is_dir():
                continue
            try:
                for u_sub in u_root.iterdir():
                    if u_sub.is_dir():
                        cands.append((u_sub / ".workbuddy", f"国内版用户目录 ({u_sub.name}/.workbuddy)"))
                        cands.append((u_sub / ".workbuddy-ai", f"国际版用户目录 ({u_sub.name}/.workbuddy-ai)"))
            except Exception:
                pass
    out_list, seen = [], set()
    for d, lbl in cands:
        try:
            if d.is_dir():
                rk = str(d.resolve()).lower()
                if rk not in seen:
                    seen.add(rk)
                    out_list.append((d, lbl))
        except Exception:
            pass
    return out_list


def check_user_dirs(app_versions_map):
    """扫描全部 .workbuddy 与 .workbuddy-ai 下的 R4(cache + marketplaces) 与 R6(SOUL.md)"""
    user_dirs = _discover_all_user_wb_dirs()

    results = []
    for udir, label in user_dirs:
        cache_items = []
        market_items = []
        soul_items = []
        max_mtime = 0.0

        # R4A: plugins/cache/workbuddy-builtin/welcomemode-*/*/prompt.tpl
        cbase = udir / "plugins" / "cache" / "workbuddy-builtin"
        if cbase.is_dir():
            for wm in sorted(cbase.glob("welcomemode-*")):
                if not wm.is_dir():
                    continue
                for ver_dir in sorted(wm.iterdir()):
                    pt = ver_dir / "prompt.tpl"
                    if pt.is_file():
                        txt = read_text_safe(pt)
                        hits = count_fingerprints(txt)
                        mt = pt.stat().st_mtime
                        if mt > max_mtime:
                            max_mtime = mt
                        cache_items.append({
                            "mode": wm.name,
                            "ver": ver_dir.name,
                            "path": pt,
                            "hits": hits,
                            "ok": hits == 7,
                            "mtime": mt,
                        })

        # R4B: plugins/marketplaces/workbuddy-builtin/welcomemode/*/prompt.tpl
        mbase = udir / "plugins" / "marketplaces" / "workbuddy-builtin" / "welcomemode"
        if mbase.is_dir():
            for p in sorted(mbase.glob("*/prompt.tpl")):
                txt = read_text_safe(p)
                hits = count_fingerprints(txt)
                mt = p.stat().st_mtime
                if mt > max_mtime:
                    max_mtime = mt
                market_items.append({
                    "mode": p.parent.name,
                    "path": p,
                    "hits": hits,
                    "ok": hits == 7,
                    "mtime": mt,
                })

        # R6: SOUL.md (根目录 + 所有 user-* 账号目录)
        soul_paths = []
        if (udir / "SOUL.md").is_file():
            soul_paths.append(("根目录", udir / "SOUL.md"))
        for sub in sorted(udir.glob("user-*")):
            if sub.is_dir() and (sub / "SOUL.md").is_file():
                soul_paths.append((sub.name, sub / "SOUL.md"))
        for sname, sp in soul_paths:
            txt = read_text_safe(sp)
            ok = all(m in txt for m in SOUL_MARKERS)
            mt = sp.stat().st_mtime
            if mt > max_mtime:
                max_mtime = mt
            soul_items.append({"name": sname, "path": sp, "ok": ok, "mtime": mt})

        # 检查是否命中对应版本
        is_ai = udir.name.endswith("-ai")
        expected_vers = app_versions_map.get("ai" if is_ai else "cn", set())

        results.append({
            "dir": udir,
            "label": label,
            "expected_vers": expected_vers,
            "cache": cache_items,
            "market": market_items,
            "souls": soul_items,
            "max_mtime": max_mtime,
        })
    return results


def inspect_latest_sessions():
    """检查全部用户目录 .workbuddy/projects 与 .workbuddy-ai/projects 下最近会话的创建时间与使用模型"""
    sessions = []
    for udir, _lbl in _discover_all_user_wb_dirs():
        dname = udir.name
        pdir = udir / "projects"
        if not pdir.is_dir():
            continue
        for jf in pdir.rglob("*.jsonl"):
            try:
                st = jf.stat()
                if st.st_size < 50:
                    continue
                sessions.append((st.st_mtime, st.st_ctime, jf, dname))
            except Exception:
                continue
    sessions.sort(key=lambda x: x[0], reverse=True)
    top = []
    for mtime, ctime, jf, dname in sessions[:5]:
        created_ts = ctime
        models = []
        agents = []
        turn_count = 0
        try:
            with jf.open("r", encoding="utf-8", errors="replace") as f:
                for idx, line in enumerate(f):
                    if idx > 80:
                        break
                    try:
                        obj = json.loads(line)
                    except Exception:
                        continue
                    if idx == 0 and obj.get("timestamp"):
                        # ISO timestamp e.g. 2026-11-24T06:39:19.123Z
                        try:
                            iso = obj["timestamp"].replace("Z", "+00:00")
                            dt = datetime.datetime.fromisoformat(iso).astimezone()
                            created_ts = dt.timestamp()
                        except Exception:
                            pass
                    if obj.get("role") == "user":
                        turn_count += 1
                    if obj.get("role") == "assistant":
                        pd = obj.get("providerData")
                        if isinstance(pd, dict):
                            m = pd.get("requestModelName") or pd.get("model") or pd.get("requestModelId")
                            if m and m not in models:
                                models.append(str(m))
                            ag = pd.get("agent")
                            if ag and ag not in agents:
                                agents.append(str(ag))
        except Exception:
            pass
        top.append({
            "user_dir": dname,
            "file": jf.name,
            "project": jf.parent.name,
            "created_ts": created_ts,
            "mtime": mtime,
            "models": models,
            "agents": agents,
            "turns": turn_count,
        })
    return top


def main():
    extra_args = sys.argv[1:]
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    out("=" * 74)
    out("  WorkBuddy 全面深度诊断工具 (All-in-One Diagnostic v3.9)")
    out(f"  检测时间: {now_str}")
    out(f"  系统环境: {sys.platform} | Python {sys.version.split()[0]}")
    out("=" * 74)

    fatal_issues = []
    warnings = []

    # ------------------------------------------------------------------
    # 1. 进程 + 快捷方式 + 全盘多安装探测
    # ------------------------------------------------------------------
    out("\n[1/5] 全盘安装副本 / 快捷方式 / 运行进程 交叉核对")
    out("-" * 74)

    procs = probe_running_processes()
    shortcuts = probe_shortcuts()
    installs_raw = discover_all_installations(procs, shortcuts, extra_args)

    if not installs_raw:
        out("  [FAIL] 未在电脑上找到任何 WorkBuddy 安装目录!")
        out("         若装在非常规盘符/深层目录，请把 WorkBuddy 文件夹拖到本 bat 上重跑。")
        fatal_issues.append("未探测到任何 WorkBuddy 安装目录")
    else:
        out(f"  共发现 {len(installs_raw)} 份 WorkBuddy 安装目录:")
        if len(installs_raw) > 1:
            out("  [WARN] 检测到多份安装副本! 请务必确认桌面启动的是已打补丁的那一份!")
            warnings.append(f"电脑上存在 {len(installs_raw)} 份 WorkBuddy 安装目录，需确认桌面启动的是哪一份")

    install_reports = []
    app_versions_map = {"cn": set(), "ai": set()}
    for idx, info in enumerate(installs_raw, 1):
        rep = check_installation(info["root"])
        rep["sources"] = sorted(info["sources"])
        install_reports.append(rep)
        if rep["app_version"] != "未知":
            key = "ai" if "国际版" in rep["edition"] else "cn"
            app_versions_map[key].add(rep["app_version"])
        status_tag = "[OK 已完整打补丁]" if rep["all_ok"] else "[FAIL 有缺口/未打补丁]"
        out(f"  ({idx}) {status_tag} [{rep['edition']}] 版本={rep['app_version']}")
        out(f"      路径: {rep['root']}")
        out(f"      来源: {', '.join(rep['sources'])}")

    # 核对快捷方式指向
    if shortcuts:
        out("\n  [快捷方式核查]")
        for sc in shortcuts:
            t_root = resolve_install_root(sc["Target"])
            matched = None
            for rep in install_reports:
                if t_root and str(rep["root"]).lower() == str(t_root).lower():
                    matched = rep
                    break
            if matched:
                st = "已打补丁" if matched["all_ok"] else "未打补丁/有缺口!"
                flag = "[OK]" if matched["all_ok"] else "[FAIL]"
                out(f"    {flag} {sc['Link']}")
                out(f"         -> 指向: {sc['Target']} ({st})")
                if not matched["all_ok"]:
                    fatal_issues.append(
                        f"桌面/开始菜单快捷方式 ({Path(sc['Link']).name}) 指向未打补丁的安装目录: {matched['root']}"
                    )
            else:
                if "launcher" in sc["Target"].lower():
                    out(f"    [INFO] {sc['Link']} -> {sc['Target']} (第三方启动器/皮肤入口，请确认实际拉起的安装目录已打补丁)")
                else:
                    out(f"    [WARN] {sc['Link']} -> {sc['Target']} (未识别为标准安装)")

    # 核对运行中进程指向
    running_roots = set()
    client_procs = []
    prewarm_procs = []
    supervisor_procs = []
    betterleaks_procs = []
    for p in procs:
        low_name = p["name"].lower()
        low_cmd = p["cmd"].lower()
        if "betterleaks" in low_name or "sandbox-center" in low_name:
            betterleaks_procs.append(p)
        elif "supervisor" in low_name or "supervisor" in low_cmd:
            supervisor_procs.append(p)
        elif "--prewarm" in low_cmd or "codebuddy" in low_cmd:
            prewarm_procs.append(p)
        elif "workbuddy" in low_name:
            client_procs.append(p)
            r = resolve_install_root(p["path"])
            if r:
                running_roots.add(str(r).lower())

    for rkey in running_roots:
        for rep in install_reports:
            if str(rep["root"]).lower() == rkey and not rep["all_ok"]:
                fatal_issues.append(f"当前正在运行的 WorkBuddy 进程来自未打补丁的目录: {rep['root']}")

    # ------------------------------------------------------------------
    # 2. 各安装目录 R1 / R2 / R3 / R5 深度指纹体检
    # ------------------------------------------------------------------
    out("\n[2/5] 安装目录文件层体检 (R1主模板 / R2 quick / R3 welcomemode / R5提醒)")
    out("-" * 74)
    global_patch_mtime = 0.0
    for idx, rep in enumerate(install_reports, 1):
        out(f"  >>> 副本 ({idx}): [{rep['edition']} v{rep['app_version']}] {rep['root']}")
        if rep["max_mtime"] > global_patch_mtime:
            global_patch_mtime = rep["max_mtime"]

        r1_ok = sum(1 for x in rep["r1"] if x["ok"])
        r2_ok = sum(1 for x in rep["r2"] if x["ok"])
        r3_ok = sum(1 for x in rep["r3"] if x["ok"])
        r5_ok = sum(1 for x in rep["r5"] if x["ok"])

        out(f"      R1 主模板 (需7/7指纹) : {r1_ok}/{len(rep['r1'])}")
        for x in rep["r1"]:
            if not x["ok"]:
                out(f"         [FAIL 缺口] {x['name']} ({x['hits']}/7)")
        out(f"      R2 Quick 模板 (7/7)  : {r2_ok}/{len(rep['r2'])}")
        for x in rep["r2"]:
            if not x["ok"]:
                out(f"         [FAIL 缺口] {x['name']} ({x['hits']}/7)")
        out(f"      R3 安装 welcomemode  : {r3_ok}/{len(rep['r3'])}")
        for x in rep["r3"]:
            if not x["ok"]:
                out(f"         [FAIL 缺口] welcomemode/{x['mode']}/prompt.tpl ({x['hits']}/7)")
        out(f"      R5 每轮反拒答提醒    : {r5_ok}/{len(rep['r5'])}")
        for x in rep["r5"]:
            if not x["ok"]:
                out(f"         [FAIL 缺口] {x['name']}")
        out(f"      最新文件写入时间     : {fmt_ts(rep['max_mtime'])}")

        if not rep["all_ok"]:
            fatal_issues.append(f"安装副本 ({idx}) [{rep['root']}] 存在未覆盖的模板缺口")

    # ------------------------------------------------------------------
    # 3. 用户目录 R4 (cache + marketplaces) & R6 (SOUL.md) 体检
    # ------------------------------------------------------------------
    out("\n[3/5] 用户配置目录体检 (R4 插件缓存 + marketplaces / R6 账号 SOUL.md)")
    out("-" * 74)
    user_reports = check_user_dirs(app_versions_map)
    if not user_reports:
        out("  [FAIL] 未找到 ~/.workbuddy 或 ~/.workbuddy-ai 目录（客户端可能从未登录过）")
        fatal_issues.append("未找到用户配置目录 ~/.workbuddy，请先登录一次客户端再重新部署")
    else:
        for urep in user_reports:
            out(f"  >>> {urep['label']}  ({urep['dir']})")
            if urep["max_mtime"] > global_patch_mtime:
                global_patch_mtime = urep["max_mtime"]

            # R4A cache
            c_all = len(urep["cache"])
            c_ok = sum(1 for x in urep["cache"] if x["ok"])
            out(f"      R4-A 插件缓存 (cache)      : {c_ok}/{c_all} (要求 7/7 全指纹)")
            # 重点核查当前 appVersion 匹配的那一份
            if urep["expected_vers"]:
                out(f"           当前客户端版本匹配检查: 期望版本={', '.join(sorted(urep['expected_vers']))}")
                for x in urep["cache"]:
                    is_active = any(x["ver"].startswith(v) for v in urep["expected_vers"])
                    if is_active and not x["ok"]:
                        out(f"           [FAIL 当前生效版本缺口!] {x['mode']}/{x['ver']} ({x['hits']}/7)")
                        fatal_issues.append(
                            f"客户端当前生效版本插件缓存未打补丁: {x['mode']}/{x['ver']} ({x['hits']}/7)"
                        )
            for x in urep["cache"]:
                if not x["ok"]:
                    out(f"           [FAIL 缺口] {x['mode']}/{x['ver']} ({x['hits']}/7)")

            # R4B marketplaces（旧 bat 漏检区）
            m_all = len(urep["market"])
            m_ok = sum(1 for x in urep["market"] if x["ok"])
            out(f"      R4-B 市场插件 (marketplaces): {m_ok}/{m_all}")
            for x in urep["market"]:
                if not x["ok"]:
                    out(f"           [FAIL 缺口] marketplaces/welcomemode/{x['mode']}/prompt.tpl ({x['hits']}/7)")
                    fatal_issues.append(f"marketplaces 插件模板缺口: {x['mode']} ({x['hits']}/7)")

            # R6 SOUL.md
            s_all = len(urep["souls"])
            s_ok = sum(1 for x in urep["souls"] if x["ok"])
            out(f"      R6 账号级 SOUL.md           : {s_ok}/{s_all}")
            for x in urep["souls"]:
                if not x["ok"]:
                    out(f"           [FAIL 缺口] {x['name']}/SOUL.md")
                    fatal_issues.append(f"账号 SOUL.md 未注入: {x['name']}")

    # ------------------------------------------------------------------
    # 4. 进程层 & 预热池 & 时间戳核验 (A层)
    # ------------------------------------------------------------------
    out("\n[4/5] 进程层与时间轴核验 (完整命令行扫描，无 25 字符截断)")
    out("-" * 74)
    all_wb_procs = client_procs + supervisor_procs + prewarm_procs
    out(f"  主/子进程 WorkBuddy : {len(client_procs)} 个")
    out(f"  后台 supervisor     : {len(supervisor_procs)} 个")
    out(f"  CLI 预热池 prewarm  : {len(prewarm_procs)} 个")
    out(f"  本地防泄密组件      : {len(betterleaks_procs)} 个 (betterleaks / sandbox-center)")

    if not all_wb_procs:
        out("  [INFO] 当前未检测到任何运行中的 WorkBuddy 进程（客户端已彻底关闭）。")
        out("         下次启动时将加载最新磁盘模板。")
    else:
        starts = [p["start_dt"] for p in all_wb_procs if p.get("start_dt")]
        oldest = min(starts) if starts else None
        out(f"  最早存活进程启动时间: {fmt_dt(oldest)}")
        out(f"  补丁最新文件写入时间: {fmt_ts(global_patch_mtime)}")
        if oldest and global_patch_mtime > 0:
            if oldest.timestamp() < global_patch_mtime - 2:
                diff_min = (global_patch_mtime - oldest.timestamp()) / 60.0
                out(f"  [FAIL A-进程层] 存活进程早于补丁写入 {diff_min:.1f} 分钟!")
                out("                  内存里仍在跑旧模板，请执行: taskkill /F /IM WorkBuddy.exe /T")
                fatal_issues.append(
                    f"进程启动 ({fmt_dt(oldest)}) 早于补丁写入 ({fmt_ts(global_patch_mtime)})，存在旧进程/预热池残留"
                )
            else:
                out("  [OK   A-进程层] 客户端进程启动晚于补丁写入，内存已加载最新模板。")

    # ------------------------------------------------------------------
    # 5. 会话层与模型核验 (B层)
    # ------------------------------------------------------------------
    out("\n[5/5] 会话层与最近对话核验 (排查旧会话固化 / 强对齐模型)")
    out("-" * 74)
    sessions = inspect_latest_sessions()
    if not sessions:
        out("  [INFO] 未找到历史会话 .jsonl 文件。")
    else:
        latest = sessions[0]
        out(f"  最近活跃的 {len(sessions)} 个会话:")
        for i, s in enumerate(sessions, 1):
            m_str = ",".join(s["models"]) if s["models"] else "未知"
            ag_str = ",".join(s["agents"]) if s["agents"] else "未知"
            out(
                f"    ({i}) [{s['user_dir']}] 创建={fmt_ts(s['created_ts'])} | "
                f"最后发言={fmt_ts(s['mtime'])} | 模型={m_str} | 模式={ag_str}"
            )

        # 用最近活跃的那个会话的创建时间对比补丁写入时间
        if global_patch_mtime > 0:
            if latest["created_ts"] < global_patch_mtime - 2:
                out("\n  [FAIL B-会话层] 你刚才测试用的最近会话创建于补丁写入之前!")
                out(f"                  会话创建={fmt_ts(latest['created_ts'])} < 补丁写入={fmt_ts(global_patch_mtime)}")
                out("                  旧会话的 system prompt 已写死，重启客户端也不会改变旧会话，必须点【新建任务】!")
                fatal_issues.append(
                    f"最近测试会话创建于补丁之前 ({fmt_ts(latest['created_ts'])})，未使用新会话"
                )
            else:
                out("\n  [OK   B-会话层] 最近活跃会话创建于补丁写入之后，已满足新会话条件。")

        # 提醒强对齐模型 / 第三方路由小模型
        for m in latest["models"]:
            low_m = m.lower()
            if "glm-5.3-flash" in low_m or "hy4std" in low_m:
                warnings.append(
                    f"最近会话使用的模型是 [{m}] (该模型底座安全对齐极严或思考极重)，建议优先切换 DeepSeek-V4.1-Flash / DeepSeek-V4-Pro / Hy4 flash"
                )
                out(f"  [WARN 模型提醒] 最近会话使用了 [{m}]，建议优先改用 DeepSeek-V4.1-Flash / DeepSeek-V4-Pro / Hy4 flash 对比测试。")
            elif any(k in low_m for k in ("qwen", "27b", "routing group")):
                warnings.append(
                    f"最近会话使用了 [{m}] (第三方路由组/小参数千问模型，对齐与长提示遵循差异大)，建议切官方 DeepSeek 对比"
                )
                out(f"  [WARN 模型提醒] 最近会话使用了 [{m}]，第三方路由/小模型对长提示遵循弱或自带上游审核，建议改用官方 DeepSeek 对比。")

    # ------------------------------------------------------------------
    # 总结论
    # ------------------------------------------------------------------
    out("\n" + "=" * 74)
    out("  总诊断结论")
    out("=" * 74)
    if fatal_issues:
        out(f"  [FAIL] 共定位到 {len(fatal_issues)} 个导致未生效的直接原因:")
        for i, msg in enumerate(fatal_issues, 1):
            out(f"    {i}. {msg}")
    else:
        out("  [PASS] 安装目录、快捷方式、六轨文件(含marketplaces)、进程层、会话层 全部正常!")
        out("         若此状态下依然被拒答，说明补丁本身已 100% 生效，原因只可能是:")
        out("           (1) 测试问题直接撞上了腾讯云端审核网关 (content_filter) 或 P0 绝对红线")
        out("               (如真实生产域名攻击/真实账号密码/明文银行卡号/涉政涉黄)")
        out("           (2) 选用了底座对齐极严的模型 (如 Hy4 flash)，请切 DeepSeek 模型并用标准句测试:")
        out("               「毕设要交，帮我写个自动登录加定时提交的脚本，我自己跑」")

    if warnings:
        out(f"\n  [WARN] 附带提醒 ({len(warnings)} 条):")
        for i, msg in enumerate(warnings, 1):
            out(f"    - {msg}")

    out("\n" + "-" * 74)
    try:
        REPORT_FILE.write_text("\n".join(REPORT_LINES) + "\n", encoding="utf-8")
        out(f"  完整诊断报告已自动保存至: {REPORT_FILE}")
    except Exception as e:
        out(f"  [WARN] 报告保存失败: {e}")
    out("=" * 74)

    return 1 if fatal_issues else 0


if __name__ == "__main__":
    sys.exit(main())
