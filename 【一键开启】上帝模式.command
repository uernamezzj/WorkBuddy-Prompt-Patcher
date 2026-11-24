#!/bin/bash
cd "$(dirname "$0")"

echo "================================================================"
echo "   WorkBuddy 上帝模式 - 一键开启 (DeepSeek God Mode v3.9)"
echo "   [全自动安全备份 + 45+底层模板/插件注入 + 绝对臣服激活]"
echo "================================================================"
echo ""

PY_CMD=""
if [ -f "./.venv/bin/python" ]; then
    PY_CMD="./.venv/bin/python"
elif [ -f "./venv/bin/python" ]; then
    PY_CMD="./venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
    PY_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PY_CMD="python"
fi

if [ -z "$PY_CMD" ]; then
    echo "[!] 错误: 未在系统中检测到可用的 Python 3 环境！"
    echo "请先安装 Python 3 (推荐终端运行: brew install python 或访问 python.org)。"
    echo ""
    read -n 1 -s -r -p "按任意键退出..."
    exit 1
fi

echo "[INFO] 正在为您全自动安全备份并部署 God Mode 破甲矩阵..."
echo ""

if pgrep -f "/WorkBuddy[^/]*\.app/Contents/" >/dev/null 2>&1; then
    echo "[INFO] 检测到 WorkBuddy 正在运行，正在自动退出客户端以释放文件锁..."
    pkill -f "/WorkBuddy[^/]*\.app/Contents/" >/dev/null 2>&1 || true
    sleep 2
fi

"$PY_CMD" "./batch_patch_prompts.py" --auto --require-closed
PY_RC=$?
if [ "$PY_RC" -ne 0 ]; then
    echo ""
    if [ "$PY_RC" -eq 2 ]; then
        echo "[!] 检测到 WorkBuddy 客户端正在运行，已主动中止。"
        echo "    请先完全退出客户端 (Command+Q，确认活动监视器里无 WorkBuddy 进程) 后重跑。"
    else
        echo "[!] 提示: 运行出现异常 (退出码=$PY_RC)，请查看上方提示信息。"
    fi
    echo ""
    read -n 1 -s -r -p "按任意键退出..."
    exit "$PY_RC"
fi

echo ""
echo "================================================================"
echo " [OK] 部署完成：文件已全部写入（官方原版已备份，可一键还原）。"
echo ""
echo " >>> 本补丁只对【新会话】生效，旧会话不会变 <<<"
echo ""
echo "   1) 完全退出客户端 (Command+Q，并确认 Dock 里没有残留图标)"
echo "   2) 重新打开客户端"
echo "   3) 新建一个会话（不要点历史会话）"
echo ""
echo " [怎么验证] 新建会话后，直接问一句你之前被拒的问题即可。"
echo "            若仍被拒，先确认没点错历史会话，再试技术化的问法。"
echo "================================================================"
echo ""
read -n 1 -s -r -p "按任意键退出..."
