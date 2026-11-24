#!/bin/bash
# ============================================================
#  WorkBuddy 官方原版 — Linux 一键恢复
#  从本地备份全量还原：系统模板 + 插件根代理 + 用户神格契约
# ============================================================

cd "$(dirname "$0")" || exit 1
export WB_PATCHER_SELF="$(pwd)/$(basename "$0")"
# shellcheck source=linux_common.sh
. "./linux_common.sh" || exit 1

echo "================================================================"
echo "   WorkBuddy 官方原版 — 一键恢复 (Linux)"
echo "   [从本地备份全量还原: 系统模板 + 插件 + 用户配置]"
echo "================================================================"
echo

if ! wb_find_python; then
    echo "[!] 未检测到可运行的 Python 3（Debian/Ubuntu: sudo apt install python3）。"
    wb_pause
    exit 1
fi

wb_ensure_writable "$@"

echo "[INFO] 正在从本地安全备份还原官方原始出厂状态..."
echo
"$PY_CMD" ./batch_patch_prompts.py --restore
PY_RC=$?

if [ "$PY_RC" -ne 0 ]; then
    echo
    echo "[!] 还原过程出现异常（退出码=$PY_RC），请查看上方提示。"
    wb_pause
    exit "$PY_RC"
fi

echo
echo "================================================================"
echo " [OK] 一键还原全部成功！"
echo " [OK] 系统模板、插件及用户配置已恢复为官方原版。"
echo " [提示] 请完全退出客户端并重新打开以生效。"
echo "================================================================"
wb_pause
exit 0
