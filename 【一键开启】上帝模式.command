#!/bin/bash
cd "$(dirname "$0")"

echo "================================================================"
echo "   WorkBuddy 上帝模式 - 一键开启 (DeepSeek God Mode v3.4)"
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

"$PY_CMD" "./batch_patch_prompts.py" --auto
if [ $? -ne 0 ]; then
    echo ""
    echo "[!] 提示: 运行出现异常，请查看上方提示信息。"
    echo ""
    read -n 1 -s -r -p "按任意键退出..."
    exit 1
fi

echo ""
echo "================================================================"
echo " [OK] 一键部署全部成功！"
echo " [OK] 官方原始副本已全自动安全备份，随时可一键还原！"
echo " [提示] 请【完全退出 WorkBuddy 客户端】(Command+Q) 并重新打开以生效！"
echo "================================================================"
echo ""
read -n 1 -s -r -p "按任意键退出..."
