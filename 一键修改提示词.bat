@echo off
chcp 936 >nul
title WorkBuddy 全局提示词批量自定义修改器
cd /d "%~dp0"

echo ================================================================
echo    WorkBuddy 全局系统提示词批量自定义修改器 (Prompt Patcher)
echo ================================================================
echo.

set "PY_CMD="

if exist "%~dp0.venv\Scripts\python.exe" (
    set "PY_CMD=%~dp0.venv\Scripts\python.exe"
    goto start_py
)
if exist "%~dp0venv\Scripts\python.exe" (
    set "PY_CMD=%~dp0venv\Scripts\python.exe"
    goto start_py
)

where python >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=python"
    goto start_py
)

where py >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=py"
    goto start_py
)

:no_python
echo [错误] 未在系统中检测到可用的 Python 环境！
echo.
echo 请先安装 Python - 建议 3.10 及以上版本
echo   1. 访问官网下载: https://www.python.org/downloads/
echo   2. 安装时请务必勾选 [Add Python to PATH]
echo.
pause
exit /b 1

:start_py
echo [OK] 正在启动 Python 核心引擎...
echo.

"%PY_CMD%" "%~dp0batch_patch_prompts.py" %*
if errorlevel 1 (
    echo.
    echo [错误] 脚本异常退出，请检查上方报错信息。
    pause
)
