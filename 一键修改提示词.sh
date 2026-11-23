#!/bin/bash
# ============================================================
#  WorkBuddy 提示词工具 — Linux 控制面板
#  [1] 一键部署  [2] 一键恢复  [3] 部署自检  [4] 预演（不写盘）
# ============================================================

cd "$(dirname "$0")" || exit 1
export WB_PATCHER_SELF="$(pwd)/$(basename "$0")"
# shellcheck source=linux_common.sh
. "./linux_common.sh" || exit 1

echo "================================================================"
echo "   WorkBuddy 进阶提示词定制工具 (Linux)"
echo "   [God Mode 破甲矩阵 + 自定义同步]"
echo "================================================================"
echo

if ! wb_find_python; then
    echo "[!] 未检测到可运行的 Python 3（Debian/Ubuntu: sudo apt install python3）。"
    wb_pause
    exit 1
fi

echo "  [1] 一键部署（备份 → 六轨注入 → 同步神格）"
echo "  [2] 一键恢复官方原版"
echo "  [3] 部署自检（只读，输出六轨矩阵）"
echo "  [4] 预演模式（完整走流程但不写盘）"
echo "  [0] 退出"
echo
printf "请选择 [0-4]: "
read -r choice

case "$choice" in
    1)
        if wb_client_running; then
            echo "[!] 客户端正在运行，请先完全退出再部署。"
            wb_pause
            exit 2
        fi
        wb_ensure_writable "$@"
        "$PY_CMD" ./batch_patch_prompts.py --auto --require-closed
        ;;
    2)
        wb_ensure_writable "$@"
        "$PY_CMD" ./batch_patch_prompts.py --restore
        ;;
    3)
        "$PY_CMD" ./batch_patch_prompts.py --verify --verbose
        ;;
    4)
        "$PY_CMD" ./batch_patch_prompts.py --dry-run --auto --verbose
        ;;
    0)
        exit 0
        ;;
    *)
        echo "[!] 无效选择。"
        wb_pause
        exit 1
        ;;
esac

PY_RC=$?
echo
echo "（退出码=$PY_RC）"
wb_pause
exit "$PY_RC"
