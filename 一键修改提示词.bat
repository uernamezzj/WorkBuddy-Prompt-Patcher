@echo off
chcp 936 >nul
title WorkBuddy 全局提示词批量自定义修改器
cd /d "%~dp0"

echo ================================================================
echo    WorkBuddy 全局系统提示词批量自定义修改器 (Prompt Patcher)
echo ================================================================
echo 正在启动 Python 核心引擎...
echo.

python batch_patch_prompts.py %*
if errorlevel 1 (
    echo.
    echo [错误] 脚本异常退出，请检查是否已安装 Python 环境。
    pause
)
