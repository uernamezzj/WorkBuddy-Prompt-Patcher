#!/bin/bash
# ============================================================
#  WorkBuddy 上帝模式 — Linux 一键开启
#  自动备份 → 六轨注入 → 同步神格契约（需要 sudo 写 /opt/WorkBuddy）
# ============================================================

cd "$(dirname "$0")" || exit 1
export WB_PATCHER_SELF="$(pwd)/$(basename "$0")"
# shellcheck source=linux_common.sh
. "./linux_common.sh" || exit 1

echo "================================================================"
echo "   WorkBuddy 上帝模式 — 一键开启 (Linux)"
echo "   [自动备份 + 六轨模板/插件注入 + 绝对臣服神格激活]"
echo "================================================================"
echo

if ! wb_find_python; then
    echo "[!] 未检测到可运行的 Python 3。"
    echo "    请安装 Python 3（Debian/Ubuntu: sudo apt install python3）。"
    wb_pause
    exit 1
fi

if wb_client_running; then
    echo "[!] 检测到 WorkBuddy 客户端仍在运行。"
    echo "    客户端进程会持有模板文件并在退出时原子重写，补丁可能被当场覆盖。"
    echo "    请先完全退出客户端（包括后台 supervisor 进程）后重新运行本脚本。"
    echo
    wb_pause
    exit 2
fi

wb_ensure_writable "$@"

echo "[INFO] 正在自动备份并部署 God Mode 破甲矩阵..."
echo
"$PY_CMD" ./batch_patch_prompts.py --auto --require-closed
PY_RC=$?

if [ "$PY_RC" -ne 0 ]; then
    echo
    if [ "$PY_RC" -eq 2 ]; then
        echo "[!] 客户端在运行，已按 --require-closed 中止。"
        echo "    完全退出 WorkBuddy 后重跑本脚本。"
    else
        echo "[!] 部署未通过（退出码=$PY_RC），请查看上方六轨矩阵中的缺口。"
    fi
    wb_pause
    exit "$PY_RC"
fi

echo
echo "================================================================"
echo " [OK] 部署完成：文件已全部写入（官方原版已备份，可一键还原）。"
echo
echo " >>> 本补丁只对【新会话】生效，旧会话不会变 <<<"
echo
echo "   1) 完全退出客户端（确认无 workbuddy 残留进程）"
echo "   2) 重新打开客户端"
echo "   3) 新建一个会话（不要点历史会话）"
echo
echo " [怎么验证] 新建会话后问一句之前被拒的问题即可。"
echo "            若仍被拒，先确认没点历史会话，再看 --verify 的六轨矩阵。"
echo "================================================================"
wb_pause
exit 0
