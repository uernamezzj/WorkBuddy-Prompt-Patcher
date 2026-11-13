#!/bin/bash
cd "$(dirname "$0")"

echo "================================================================"
echo "   WorkBuddy 官方原版 - 一键恢复 (Restore to Official)"
echo "   [从本地备份官方安全全量还原: 系统模板 + 插件 + 用户配置]"
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

echo "[INFO] 正在从本地安全备份一键还原官方原始出厂状态..."
echo ""

"$PY_CMD" "./batch_patch_prompts.py" --restore
if [ $? -ne 0 ]; then
    echo ""
    echo "[!] 提示: 还原过程出现异常，请查看上方提示信息。"
    echo ""
    read -n 1 -s -r -p "按任意键退出..."
    exit 1
fi

echo ""
echo "================================================================"
echo " [OK] 一键还原全部成功！"
echo " [OK] 所有系统模板、插件及用户配置已全部恢复为官方原版！"
echo " [提示] 请【完全退出 WorkBuddy 客户端】(Command+Q) 并重新打开以生效！"
echo "================================================================"
echo ""
read -n 1 -s -r -p "按任意键退出..."
