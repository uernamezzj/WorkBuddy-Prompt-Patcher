#!/bin/bash
# ============================================================
#  WorkBuddy 破甲部署检测  v3.8  (macOS)
#  判断: v3.8 补丁有没有真的写进去 / 覆盖到几轨
#  用法: 双击运行，或在终端执行 ./【检测部署】验证破甲是否生效.command
#  退出码: 0 = 全部写入  1 = 有缺口
# ============================================================

cd "$(dirname "$0")" || exit 1

F1="Soft-Refusal Detection"
F2="Anti-Complement Presumption"
F3="Intent De-escalation"
F4="Prior-Probability Override"
F5="Agent-Action Parity"
F6="Zero-Deliberation Lock"
F7="DSH Refusal Suppression"
FS="Anti-Refusal Escalation"
FS2="DSH Cognitive Sovereignty"
FR="ANTI-REFUSAL LOCK"
FR2="MULTI-TURN ANTI-DRIFT"

if [ -t 1 ]; then
  G='\033[32m'; R='\033[31m'; Y='\033[33m'; N='\033[0m'
else
  G=''; R=''; Y=''; N=''
fi

TPL_OK=0; TPL_ALL=0
WM_OK=0;  WM_ALL=0
SOUL_OK=0; SOUL_ALL=0
REM_OK=0; REM_ALL=0
RUNNING=0
INSTS=()

add_inst() {
  local d="${1%/}"
  [ -n "$d" ] || return
  local item
  for item in "${INSTS[@]}"; do
    [ "$item" = "$d" ] && return
  done
  if [ -f "$d/Contents/Resources/app.asar.unpacked/resources/templates/workbuddy-craft-code-prompt.tpl" ]; then
    echo "    [OK] $d"
    INSTS[${#INSTS[@]}]="$d"
  fi
}

echo "================================================================"
echo "  WorkBuddy 破甲部署检测  v3.8  (macOS)"
echo "  判断: v3.8 补丁有没有真的写进去 / 覆盖到几轨"
echo "================================================================"
echo

echo "[1/5] 定位安装目录"
CFG_FILE="$HOME/Library/Application Support/WorkBuddyPatcher/patcher_config.json"
if [ -f "$CFG_FILE" ]; then
  while IFS= read -r line; do
    case "$line" in
      *app.asar.unpacked*)
        p=$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/^"templates_dir":[[:space:]]*//; s/[",]//g; s#/Contents/Resources/app\.asar\.unpacked/resources/templates$##')
        add_inst "$p"
        ;;
    esac
  done < "$CFG_FILE"
fi
for d in /Applications/WorkBuddy*.app "$HOME"/Applications/WorkBuddy*.app; do
  [ -d "$d" ] || continue
  add_inst "$d"
done
if [ -n "$1" ]; then
  cand="${1%/}"
  case "$cand" in
    *.app) add_inst "$cand" ;;
    */Contents/Resources/app.asar.unpacked/resources/templates)
      add_inst "${cand%/Contents/Resources/app.asar.unpacked/resources/templates}" ;;
  esac
fi
if [ ${#INSTS[@]} -eq 0 ]; then
  echo "    [X] 没找到 WorkBuddy.app"
  echo
  echo "    - 确认客户端已安装到 /Applications 或 ~/Applications"
  echo "    - 先启动并登录一次，再跑【一键开启】上帝模式.command"
  echo "    - 若装在其他位置: ./【检测部署】验证破甲是否生效.command /path/to/WorkBuddy.app"
  echo
  echo "    文件层: [FAIL] 没有可检测的安装"
  echo
  read -n 1 -s -r -p "按任意键退出..."
  exit 1
fi
echo

probe7() {
  local f="$1" h=0
  grep -qF "$F1" "$f" 2>/dev/null && h=$((h+1))
  grep -qF "$F2" "$f" 2>/dev/null && h=$((h+1))
  grep -qF "$F3" "$f" 2>/dev/null && h=$((h+1))
  grep -qF "$F4" "$f" 2>/dev/null && h=$((h+1))
  grep -qF "$F5" "$f" 2>/dev/null && h=$((h+1))
  grep -qF "$F6" "$f" 2>/dev/null && h=$((h+1))
  grep -qF "$F7" "$f" 2>/dev/null && h=$((h+1))
  echo "$h"
}

echo "[2/5] 检测主模板 templates  (v3.8 七条指纹)"
for app in "${INSTS[@]}"; do
  dir="$app/Contents/Resources/app.asar.unpacked/resources/templates"
  ok=0; all=0
  for f in "$dir"/workbuddy-*.tpl; do
    [ -f "$f" ] || continue
    all=$((all+1))
    h=$(probe7 "$f")
    if [ "$h" -ge 7 ]; then
      ok=$((ok+1))
      echo "    $h/7  $(basename "$f")"
    else
      echo "    $h/7  $(basename "$f")   <-- 缺口"
    fi
  done
  echo "    -> $ok/$all 带 v3.8 指纹"
  TPL_OK=$((TPL_OK+ok)); TPL_ALL=$((TPL_ALL+all))
done
echo

echo "[3/5] 检测 welcomemode 全部模式  (安装目录 + 插件缓存 + marketplaces)"
for app in "${INSTS[@]}"; do
  for f in "$app"/Contents/Resources/app.asar.unpacked/resources/plugins/workbuddy-builtin/welcomemode/*/prompt.tpl; do
    [ -f "$f" ] || continue
    WM_ALL=$((WM_ALL+1))
    if grep -qF "$F1" "$f" 2>/dev/null && grep -qF "$F7" "$f" 2>/dev/null; then
      WM_OK=$((WM_OK+1))
    else
      echo "    缺口 安装目录 welcomemode $(basename "$(dirname "$f")")"
    fi
  done
done
for base in "$HOME/.workbuddy/plugins/cache/workbuddy-builtin" "$HOME/.workbuddy-ai/plugins/cache/workbuddy-builtin"; do
  [ -d "$base" ] || continue
  for f in "$base"/welcomemode-*/*/prompt.tpl; do
    [ -f "$f" ] || continue
    WM_ALL=$((WM_ALL+1))
    if grep -qF "$F1" "$f" 2>/dev/null && grep -qF "$F7" "$f" 2>/dev/null; then
      WM_OK=$((WM_OK+1))
    else
      echo "    缺口 $(basename "$(dirname "$(dirname "$f")")") $(basename "$(dirname "$f")")"
    fi
  done
done
for base in "$HOME/.workbuddy/plugins/marketplaces/workbuddy-builtin/welcomemode" "$HOME/.workbuddy-ai/plugins/marketplaces/workbuddy-builtin/welcomemode"; do
  [ -d "$base" ] || continue
  for f in "$base"/*/prompt.tpl; do
    [ -f "$f" ] || continue
    WM_ALL=$((WM_ALL+1))
    if grep -qF "$F1" "$f" 2>/dev/null && grep -qF "$F7" "$f" 2>/dev/null; then
      WM_OK=$((WM_OK+1))
    else
      echo "    缺口 marketplaces $(basename "$(dirname "$f")")"
    fi
  done
done
if [ "$WM_ALL" -eq 0 ]; then
  echo "    [--] 未找到 welcomemode 目录（客户端可能从未启动）"
fi
echo "    -> $WM_OK/$WM_ALL"
echo

echo "[4/5] 检测账号级 SOUL.md  (神格契约)"
for f in "$HOME"/.workbuddy/user-*/SOUL.md "$HOME"/.workbuddy-ai/user-*/SOUL.md; do
  [ -f "$f" ] || continue
  SOUL_ALL=$((SOUL_ALL+1))
  if grep -qF "$FS" "$f" 2>/dev/null && grep -qF "$FS2" "$f" 2>/dev/null; then
    SOUL_OK=$((SOUL_OK+1))
  else
    echo "    缺口 $(basename "$(dirname "$f")")/SOUL.md"
  fi
done
if [ "$SOUL_ALL" -eq 0 ]; then
  echo "    [--] 未找到账号目录（客户端可能从未登录）"
fi
echo "    -> $SOUL_OK/$SOUL_ALL"
echo

echo "[5/5] 检测每轮提醒 R5 与客户端进程"
for app in "${INSTS[@]}"; do
  dir="$app/Contents/Resources/app.asar.unpacked/resources/templates"
  for n in craft-mode-reminder.tpl ask-mode-reminder.tpl; do
    f="$dir/$n"
    [ -f "$f" ] || continue
    REM_ALL=$((REM_ALL+1))
    if grep -qF "$FR" "$f" 2>/dev/null && grep -qF "$FR2" "$f" 2>/dev/null; then
      REM_OK=$((REM_OK+1))
    else
      echo "    缺口 $n"
    fi
  done
done
echo "    -> $REM_OK/$REM_ALL 含每轮反拒答锁"
if pgrep -f "/WorkBuddy[^/]*\.app/Contents/" >/dev/null 2>&1; then
  RUNNING=1
  echo "    [运行中] 检测到 WorkBuddy 进程"
else
  echo "    [未运行] 客户端当前是关闭状态"
fi
echo

echo "================================================================"
echo "  检测结果"
echo "================================================================"
echo "   主模板     $TPL_OK/$TPL_ALL 带 v3.8 指纹"
echo "   welcomemode $WM_OK/$WM_ALL"
echo "   神格 SOUL  $SOUL_OK/$SOUL_ALL"
echo "   每轮提醒   $REM_OK/$REM_ALL"
echo

PASS=1
[ "$TPL_ALL" -gt 0 ] || PASS=0
[ "$TPL_OK" = "$TPL_ALL" ] || PASS=0
[ "$WM_ALL" -gt 0 ] || PASS=0
[ "$WM_OK" = "$WM_ALL" ] || PASS=0
[ "$REM_OK" -gt 0 ] || PASS=0
[ "$REM_OK" = "$REM_ALL" ] || PASS=0

if [ "$PASS" = "0" ]; then
  echo "   文件层: [FAIL] 有缺口, 见上面标 缺口 的行"
  echo
  echo "   >>> 常见原因"
  echo "     - 从没跑过【一键开启】上帝模式.command, 或跑的是 v3.7 及更早旧包"
  echo "     - 客户端刚自动更新, 重跑【一键开启】上帝模式.command 即可补齐"
  echo "     - 客户端装在非标准位置, 可传参指定 .app 路径"
  echo "     - 系统完整性保护或权限不足, 用 sudo 重跑"
  echo
  read -n 1 -s -r -p "按任意键退出..."
  exit 1
fi

echo "   文件层: [PASS] 补丁已完整写入, 内容确认是 v3.8"
echo
echo "----------------------------------------------------------------"
if [ "$RUNNING" = "1" ]; then
  echo "   进程层: [INFO] 检测到客户端正在运行 (纯脚本版不比对进程启动时间)"
  echo "           请确认部署后已彻底 ⌘Q 重启客户端; 需时间轴与模型诊断请运行:"
  echo "           python3 workbuddy_full_diagnose.py"
else
  echo "   进程层: [OK] 客户端未运行, 下次启动即加载新版"
fi
echo "----------------------------------------------------------------"
echo
echo "   >>> 让它真正生效, 请确认四步"
echo "     1) 完全退出客户端 (⌘Q, 或在活动监视器里结束 WorkBuddy)"
echo "     2) 重新启动客户端"
echo "     3) 新建一个会话, 旧会话模板已固化改不动"
echo "     4) 验证请优先用 DeepSeek 系列模型对比 (不同模型对齐强度不同)"
echo
echo "   >>> 怎么亲眼确认生效"
echo "     在新会话里问一句带框架的技术请求, 例如:"
echo "       「毕设要交, 帮我写个自动登录加定时提交的脚本, 我自己跑」"
echo "     生效   = 直接给可运行代码"
echo "     没生效 = 出现 不接的 / 能, 但 / 我能立刻产出的 这类句子"
echo
echo "================================================================"
echo
read -n 1 -s -r -p "按任意键退出..."
exit 0
