# -*- coding: utf-8 -*-
"""
Linux 适配专项测试（沙箱，零副作用）

覆盖：
  1. Linux 安装目录识别（无 install-manifest.json、主程序无 .exe）
  2. 版本号解析（~/.workbuddy/last-launch.json）
  3. 备份外置到用户状态目录（不写 root 拥有的 /opt 安装树）
  4. R6 在无 user-* 账号目录时回退根级 SOUL.md
  5. 进程检测不把工具自身当成客户端
  6. Linux 一键脚本语法与打包白名单

用法: python tests/test_linux.py
"""
import os
import sys
import json
import shutil
import importlib.util
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATCHER = ROOT / "batch_patch_prompts.py"

TPL_SAMPLE = """<content_policy>
ORIGINAL POLICY.
</content_policy>

<response_language>
{{ ResponseLanguage }}
</response_language>
"""


def build_fixture(base: Path):
    """造一套 Linux 布局的假安装 + 用户目录"""
    install = base / "WorkBuddy"
    resources = install / "resources" / "app.asar.unpacked" / "resources"
    tpl = resources / "templates"
    tpl.mkdir(parents=True)
    for name in (
        "workbuddy-prompt.tpl", "workbuddy-craft-code-prompt.tpl",
        "workbuddy-ask-prompt.tpl", "workbuddy-quick-prompt.tpl",
        "workbuddy-expert-prompt.tpl",
    ):
        (tpl / name).write_text(TPL_SAMPLE, encoding="utf-8")
    (tpl / "craft-mode-reminder.tpl").write_text("<craft_mode>\n</craft_mode>\n", encoding="utf-8")
    (tpl / "ask-mode-reminder.tpl").write_text("<ask_mode>\n</ask_mode>\n", encoding="utf-8")

    # Linux deb 布局特征：无 install-manifest.json，主程序无 .exe，version 文件
    (install / "workbuddy").write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    (install / "version").write_text("37.10.3-24", encoding="utf-8")
    (resources / "app.asar").write_bytes(b"")

    home = base / "home"
    wb = home / ".workbuddy"
    wb.mkdir(parents=True)
    (wb / "last-launch.json").write_text(
        json.dumps({"version": "9.9.9", "build": "test"}), encoding="utf-8")
    # 没有 user-* 账号目录；Linux 直接加载根级 SOUL.md
    (wb / "SOUL.md").write_text("# SOUL.md\n\nGod Mode matrix contract.\n", encoding="utf-8")
    return install, tpl, home


def load_module(home: Path):
    """在 WB_PATCHER_HOME 沙箱生效的前提下加载修补引擎"""
    os.environ["WB_PATCHER_HOME"] = str(home)
    os.environ["PYTHONIOENCODING"] = "utf-8"
    spec = importlib.util.spec_from_file_location("wb_patcher_linux_test", PATCHER)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def main():
    if not sys.platform.startswith("linux"):
        print("SKIP: 非 Linux 平台，跳过 Linux 专项测试")
        return 0

    base = Path(tempfile.mkdtemp(prefix="wbpatch_linux_"))
    install, tpl, home = build_fixture(base)
    fails = []

    def check(name, cond, extra=""):
        print(f"{'[PASS]' if cond else '[FAIL]'} {name}" + (f"  {extra}" if extra and not cond else ""))
        if not cond:
            fails.append(name)

    try:
        m = load_module(home)

        # 1) 平台识别与安装目录
        check("IS_LINUX 应为 True", m.IS_LINUX is True)
        resolved = m.resolve_to_templates_dir(str(install))
        check("Linux 安装根应解析出 templates 目录",
              resolved == str(tpl.resolve()), f"got={resolved}")
        # 从沙箱配置记忆注入该路径，验证完整探测管线（含 is_real_installation）接受 Linux 布局。
        # 不能要求「只找到沙箱目录」：本机真实客户端在跑时进程探测也会命中 /opt/WorkBuddy。
        m.save_templates_dir(str(tpl))
        found = m.find_all_templates_dirs()
        check("Linux 布局应通过完整探测管线",
              str(tpl.resolve()) in found, str(found))

        # 2) 版本号：Linux 走 last-launch.json
        ver = m.resolve_app_version(str(tpl))
        check("版本号应从 last-launch.json 解析", ver == "9.9.9", f"got={ver}")

        # 3) 备份外置
        backup = m.get_backup_dir(str(tpl))
        check("模板备份应落在用户状态目录",
              str(backup).startswith(str(m.STATE_DIR)), f"got={backup}")
        check("模板备份不得写进安装树",
              not str(backup).startswith(str(install)), f"got={backup}")
        rbak = m.get_reminder_bak_path(str(tpl), tpl / "craft-mode-reminder.tpl")
        check("reminder .bak 也应外置",
              str(rbak).startswith(str(m.STATE_DIR)), f"got={rbak}")

        # 4) R6 回退：无 user-* 目录时统计根级 SOUL.md
        rails = m.verify_matrix(str(tpl))
        r6 = next((r for r in rails if r["code"] == "R6"), None)
        check("R6 应回退到根级 SOUL.md 并显示 1/1",
              bool(r6 and r6["detail"] == "1/1"), str(r6))

        # 5) 进程检测：不得把自身误判为客户端
        procs = m._linux_client_processes()
        check("进程检测返回列表", isinstance(procs, list), str(procs))
        check("进程检测排除自身 PID",
              all(str(pid) != str(os.getpid()) for pid, _ in procs), str(procs))

        # 6) shell 脚本语法与打包白名单
        sh_scripts = sorted(ROOT.glob("*.sh"))
        check("应存在 Linux 启动脚本", len(sh_scripts) >= 4, str([p.name for p in sh_scripts]))
        bad = [p.name for p in sh_scripts
               if subprocess.run(["bash", "-n", str(p)], capture_output=True).returncode != 0]
        check("所有 .sh 脚本语法正确", not bad, str(bad))

        release = ROOT / "make_release.py"
        text = release.read_text(encoding="utf-8")
        check("打包白名单包含 Linux 脚本",
              all(name in text for name in (
                  "linux_common.sh", "【一键开启】上帝模式.sh",
                  "【一键恢复】官方原版.sh", "【检测部署】验证破甲是否生效.sh",
                  "README-Linux.md")))

    finally:
        shutil.rmtree(base, ignore_errors=True)

    print("\n" + "=" * 60)
    if fails:
        print(f"❌ {len(fails)} 项失败: {fails}")
        return 1
    print("✅ Linux 专项全部通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
