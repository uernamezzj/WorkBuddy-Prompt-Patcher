# -*- coding: utf-8 -*-
"""
v3.5 回归测试：在隔离沙箱里造一套假 WorkBuddy 目录，验证
  1. 六轨矩阵能识别缺口 (R2 quick 模板无标签)
  2. 兜底注入能补齐无标签模板
  3. 二次运行幂等 (文件哈希不变)
  4. --restore 后矩阵回落 (证明还原链路可用)
  5. 退出码语义 0/1 正确
用法: python tests/test_v35.py
"""
import os
import sys
import json
import shutil
import hashlib
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATCHER = ROOT / "batch_patch_prompts.py"

TPL_MAIN = """<product_identity>
You are a test agent.
</product_identity>

<content_policy>
ORIGINAL POLICY BLOCK.
</content_policy>

<tool_use>
tools go here
</tool_use>

<response_language>
{{ ResponseLanguage }}
</response_language>
"""

TPL_QUICK = """You are WorkBuddy in Quick Answer mode.

Answer the user's question directly and concisely. You have no tools.

Guidelines:
- Answer from your own knowledge.
"""

REMINDER_CRAFT = """<craft_mode>
You are now in Agent mode.
</craft_mode>
"""

WM_PROMPT = """<product_identity>
Root agent identity.
</product_identity>

<content_policy>
ROOT ORIGINAL.
</content_policy>
"""

SOUL = "# SOUL.md\n\nOriginal soul content.\n"


def build_fixture(base: Path):
    install = base / "WorkBuddy" / "resources" / "app.asar.unpacked" / "resources"
    tpl = install / "templates"
    tpl.mkdir(parents=True)
    (tpl / "workbuddy-prompt.tpl").write_text(TPL_MAIN, encoding="utf-8")
    (tpl / "workbuddy-craft-coding-prompt.tpl").write_text(TPL_MAIN, encoding="utf-8")
    (tpl / "workbuddy-quick-prompt.tpl").write_text(TPL_QUICK, encoding="utf-8")
    (tpl / "craft-mode-reminder.tpl").write_text(REMINDER_CRAFT, encoding="utf-8")
    (tpl / "ask-mode-reminder.tpl").write_text(REMINDER_CRAFT.replace("craft_mode", "ask_mode"), encoding="utf-8")
    (tpl / "system-reminder.tpl").write_text("<system_reminder>\n{{ x }}\n</system_reminder>\n", encoding="utf-8")

    wm = install / "plugins" / "workbuddy-builtin" / "welcomemode" / "work"
    wm.mkdir(parents=True)
    (wm / "prompt.tpl").write_text(WM_PROMPT, encoding="utf-8")

    home = base / "home"
    cache = home / ".workbuddy" / "plugins" / "cache" / "workbuddy-builtin" / "welcomemode-work"
    for ver in ("5.9.3-wb.test.aaa", "5.9.4-wb.test.bbb"):
        d = cache / ver
        d.mkdir(parents=True)
        (d / "prompt.tpl").write_text(WM_PROMPT, encoding="utf-8")
    acct = home / ".workbuddy" / "user-test0001-personal"
    acct.mkdir(parents=True)
    (acct / "SOUL.md").write_text(SOUL, encoding="utf-8")

    # 企业/团队账号目录（不以 -personal 结尾）+ 超长原生 SOUL.md 测试 10,000 字符防截断
    ent_acct = home / ".workbuddy" / "user-corp0002-ent8888"
    ent_acct.mkdir(parents=True)
    long_soul = "# Enterprise Custom SOUL\n" + ("- user workflow preference rule line\n" * 150)
    (ent_acct / "SOUL.md").write_text(long_soul, encoding="utf-8")

    return tpl, home


def run(args, home, tpl):
    env = dict(os.environ, WB_PATCHER_HOME=str(home), PYTHONIOENCODING="utf-8")
    p = subprocess.run([sys.executable, str(PATCHER)] + args + ["--templates-dir", str(tpl)],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    return p.returncode, (p.stdout or "") + (p.stderr or "")


def snap(root: Path):
    out = {}
    for p in sorted(Path(root).rglob("*")):
        if p.is_file():
            out[str(p.relative_to(root))] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out


def main():
    base = Path(tempfile.mkdtemp(prefix="wbpatch_v35_"))
    tpl, home = build_fixture(base)
    fails = []

    def check(name, cond, extra=""):
        print(f"{'[PASS]' if cond else '[FAIL]'} {name}" + (f"  {extra}" if extra and not cond else ""))
        if not cond:
            fails.append(name)

    # 1) 初始状态：应有缺口，且原生带 <content_policy> 的官方模板不能触发 R1/R3/R4 假绿灯
    code, out = run(["--verify", "--json-report", str(base / "init_report.json")], home, tpl)
    check("初始校验应失败 (exit=1)", code == 1, f"exit={code}")
    check("报告应识别 R2 quick 缺口", "R2" in out and "❌" in out)
    if (base / "init_report.json").is_file():
        init_rep = json.loads((base / "init_report.json").read_text(encoding="utf-8"))
        init_rails = {r["code"]: r["ok"] for r in init_rep["rails"]}
        check("原版主模板 R1 不得假绿", init_rails.get("R1") is False, str(init_rails))
        check("原版 welcomemode R3 不得假绿", init_rails.get("R3") is False, str(init_rails))
        check("原版插件缓存 R4 不得假绿", init_rails.get("R4") is False, str(init_rails))

    # 1.5) 写入失败保护：主模板设为只读时，--auto 必须返回 exit=1（绝不吞错假绿）
    ro_file = tpl / "workbuddy-prompt.tpl"
    os.chmod(ro_file, 0o444)
    try:
        code_ro, out_ro = run(["--auto"], home, tpl)
        check("只读文件写入失败时 --auto 必须 exit=1", code_ro == 1, f"exit={code_ro}")
        check("只读写入失败时报告应提示写入失败或 R1 缺口", ("写入失败" in out_ro) or ("R1 ❌" in out_ro), out_ro[-800:])
    finally:
        os.chmod(ro_file, 0o666)

    # 2) 部署
    code, out = run(["--auto", "--json-report", str(base / "report.json")], home, tpl)
    check("部署后应 exit=0", code == 0, f"exit={code}\n{out[-1500:]}")
    quick_text = (tpl / "workbuddy-quick-prompt.tpl").read_text(encoding="utf-8")
    check("quick 模板应被兜底注入 content_policy", "<content_policy>" in quick_text)
    check("quick 保留原文头部", quick_text.startswith("You are WorkBuddy in Quick Answer mode."))
    main_bytes = (tpl / "workbuddy-prompt.tpl").read_bytes()
    check("re.sub 不得把 \\r\\n 展开成真实换行", b"CRLF (`\r\n`)" not in main_bytes and b"CRLF (`\n" not in main_bytes)
    ent_soul_text = (home / ".workbuddy" / "user-corp0002-ent8888" / "SOUL.md").read_text(encoding="utf-8")
    check("企业版账号目录 user-*-<enterpriseId> SOUL.md 应被同步", "Developer Execution Ethos" in ent_soul_text)
    check("超长 SOUL.md 神格前置，前 10000 字符内不被截断", "Developer Execution Ethos" in ent_soul_text[:10000])
    check("JSON 报告应生成", (base / "report.json").is_file())
    if (base / "report.json").is_file():
        rep = json.loads((base / "report.json").read_text(encoding="utf-8"))
        rails = {r["code"]: r["ok"] for r in rep["rails"]}
        check("报告矩阵六轨全绿", all(rails.get(c) for c in ("R1", "R2", "R3", "R4", "R5", "R6")), str(rails))
        check("报告含客户端版本指纹", rep["fingerprint"].get("appVersion") is not None)

    # 3) 幂等：再跑一次，文件哈希必须一致
    before = snap(base)
    code2, out2 = run(["--auto"], home, tpl)
    after = snap(base)
    changed = [k for k in after
               if before.get(k) != after[k]
               and not k.endswith(".bak")          # 备份产物不算内容漂移
               and "report" not in k and "backup" not in k]
    check("二次运行幂等 (无文件变化)", not changed, f"changed={changed[:5]}")
    check("二次运行仍 exit=0", code2 == 0, f"exit={code2}")

    # 4) 校验通过
    code3, out3 = run(["--verify"], home, tpl)
    check("部署后校验 exit=0", code3 == 0, f"exit={code3}\n{out3[-1200:]}")

    # 5) 还原后矩阵应回落
    code4, out4 = run(["--restore"], home, tpl)
    check("还原应成功 exit=0", code4 == 0, f"exit={code4}")
    code5, out5 = run(["--verify"], home, tpl)
    check("还原后校验应失败 (exit=1)", code5 == 1, f"exit={code5}")
    restored = (tpl / "workbuddy-quick-prompt.tpl").read_text(encoding="utf-8")
    check("还原后 quick 恢复原版", restored.strip() == TPL_QUICK.strip())

    # 6) 生效前提判定：会话层（新增能力）
    #    没会话时应返回 None；造一个会话后应能读回它的创建时间。
    #    这是「补丁后有没有开过新会话」的判据来源，必须有测试锁住。
    code_sess = (
        "import importlib.util, json\n"
        "spec=importlib.util.spec_from_file_location('wb','batch_patch_prompts.py')\n"
        "m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)\n"
        "t,p=m.get_latest_session_start()\n"
        "print(json.dumps({'t': t.isoformat() if t else None, 'p': str(p) if p else None}))\n"
    )
    env_s = dict(os.environ, WB_PATCHER_HOME=str(home), PYTHONIOENCODING="utf-8")
    r0 = subprocess.run([sys.executable, "-c", code_sess], capture_output=True,
                        text=True, encoding="utf-8", errors="replace", env=env_s, cwd=str(ROOT))
    d0 = json.loads(r0.stdout.strip().splitlines()[-1]) if r0.stdout.strip() else {}
    check("无会话记录时返回 None", d0.get("t") is None, f"got={d0}")

    proj = home / ".workbuddy" / "projects" / "demo-project"
    proj.mkdir(parents=True, exist_ok=True)
    sess = proj / "aaaaaaaa-1111-2222-3333-444444444444.jsonl"
    sess.write_text('{"role":"user"}\n', encoding="utf-8")
    r1 = subprocess.run([sys.executable, "-c", code_sess], capture_output=True,
                        text=True, encoding="utf-8", errors="replace", env=env_s, cwd=str(ROOT))
    d1 = json.loads(r1.stdout.strip().splitlines()[-1]) if r1.stdout.strip() else {}
    check("能读取最近会话创建时间", bool(d1.get("t")), f"got={d1}")
    check("会话记录指向正确的文件", (d1.get("p") or "").endswith(sess.name), f"got={d1.get('p')}")

    # 7) --verify 默认输出应极简：一行六轨摘要 + 一行下一步行动
    code7, out7 = run(["--verify"], home, tpl)
    check("默认校验含六轨摘要", "六轨" in out7, out7[-600:])
    check("默认校验含下一步行动", "下一步" in out7, out7[-600:])
    check("默认校验不解释原理（不含 A/B 层标记）",
          "[A 进程层]" not in out7 and "[B 会话层]" not in out7, out7[-600:])
    check("默认校验输出足够短（<= 25 行）", len(out7.strip().splitlines()) <= 25,
          f"{len(out7.strip().splitlines())} 行")

    # 8) --verbose 才展开三层判定与完整明细
    code8, out8 = run(["--verify", "--verbose"], home, tpl)
    check("--verbose 含进程层判定",
          "[A 进程层]" in out8 or "未检测到客户端进程" in out8, out8[-600:])
    check("--verbose 含汇总结论", "结论:" in out8, out8[-600:])

    print("\n" + "=" * 60)
    if fails:
        print(f"❌ {len(fails)} 项失败: {fails}")
        print(f"沙箱保留: {base}")
        return 1
    print("✅ 全部通过")
    shutil.rmtree(base, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
