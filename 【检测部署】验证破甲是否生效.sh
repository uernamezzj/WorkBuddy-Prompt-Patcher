#!/bin/bash
# ============================================================
#  WorkBuddy 破甲部署检测 (Linux)
#  退出码: 0 = 六轨全绿  1 = 有缺口
#  只读校验，不需要 sudo。
# ============================================================

cd "$(dirname "$0")" || exit 1
export WB_PATCHER_SELF="$(pwd)/$(basename "$0")"
# shellcheck source=linux_common.sh
. "./linux_common.sh" || exit 1

echo "================================================================"
echo "   WorkBuddy 破甲部署检测 (Linux)"
echo "   判断: 补丁有没有真的写进去 / 现在能不能生效"
echo "================================================================"
echo

if ! wb_find_python; then
    echo "[!] 未检测到可运行的 Python 3（Debian/Ubuntu: sudo apt install python3）。"
    wb_pause
    exit 1
fi

"$PY_CMD" ./batch_patch_prompts.py --verify --verbose
PY_RC=$?

echo
echo "================================================================"
if [ "$PY_RC" -eq 0 ]; then
    echo "   文件层: [PASS] 六轨加载点均已写入补丁。"
else
    echo "   文件层: [FAIL] 存在缺口，见上方六轨矩阵。"
    echo
    echo "   >>> 常见原因"
    echo "     - 还没跑过【一键开启】上帝模式.sh"
    echo "     - 客户端安装目录无写权限，需用 sudo 重跑"
    echo "     - 客户端从未启动登录过，插件缓存未解包（R4 为 0/0）"
    echo "     - 客户端刚升级，新版本模板尚未部署"
fi
echo
echo "   >>> 让它真正生效，只有三步"
echo "     1) 完全退出客户端（确认无 workbuddy 残留进程）"
echo "     2) 重新启动客户端"
echo "     3) 新建一个会话 —— 旧会话的 system prompt 已固化，改不动"
echo "================================================================"
wb_pause
exit "$PY_RC"
