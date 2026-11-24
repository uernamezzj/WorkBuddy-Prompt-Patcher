#!/bin/bash
# ============================================================
#  WorkBuddy Prompt Patcher — Linux 公共函数库
#  由各 .sh 启动脚本 source，不单独执行。
# ============================================================

# 仅在非交互终端等待，双击场景（无 TTY）直接退出，避免卡死
wb_pause() {
    if [ -t 0 ]; then
        printf '\n按回车键退出...'
        read -r _wb_dummy || true
    fi
}

wb_find_python() {
    PY_CMD=""
    local c
    for c in "./.venv/bin/python3" "./.venv/bin/python" "./venv/bin/python3" "./venv/bin/python"; do
        if [ -x "$c" ] && "$c" -c 'import sys' >/dev/null 2>&1; then
            PY_CMD="$c"
            return 0
        fi
    done
    for c in python3 python; do
        if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys' >/dev/null 2>&1; then
            PY_CMD="$c"
            return 0
        fi
    done
    return 1
}

# 让 Python 引擎自己报告 templates 目录，避免 shell 侧重复实现探测逻辑
wb_detect_templates_dir() {
    "$PY_CMD" -c 'import batch_patch_prompts as b; d = b.auto_detect_templates_dir(); print(d or "")' 2>/dev/null
}

# /opt/WorkBuddy 属 root:root，普通用户不可写。需要时自动 sudo 重跑一次。
# WB_PATCHER_ELEVATED 防止提权后再次进入本函数造成死循环。
wb_ensure_writable() {
    [ "${WB_PATCHER_ELEVATED:-0}" = "1" ] && return 0

    local td
    td=$(wb_detect_templates_dir)
    if [ -z "$td" ] || [ -w "$td" ]; then
        return 0
    fi

    echo "[权限] 客户端安装目录不可写：$td"
    echo "       Linux 客户端通常装在 /opt/WorkBuddy（root 所有），"
    echo "       需要管理员权限才能修改系统模板，即将请求 sudo 授权。"
    echo

    if ! command -v sudo >/dev/null 2>&1; then
        echo "[!] 系统未安装 sudo，请以 root 身份手动运行本脚本："
        echo "    sudo -E bash \"${WB_PATCHER_SELF:-$0}\""
        wb_pause
        exit 1
    fi

    export WB_PATCHER_ELEVATED=1
    exec sudo -E env WB_PATCHER_ELEVATED=1 \
        WB_PATCHER_SELF="${WB_PATCHER_SELF:-$0}" \
        bash "${WB_PATCHER_SELF:-$0}" "$@"
}

# 客户端是否在运行（精确匹配 /proc/<pid>/exe，不匹本工具自身）
wb_client_running() {
    "$PY_CMD" -c 'import batch_patch_prompts as b; raise SystemExit(0 if b.detect_running_clients() else 1)' 2>/dev/null
}
