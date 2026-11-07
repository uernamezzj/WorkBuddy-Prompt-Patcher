@echo off
chcp 936 >nul
title WorkBuddy 终极提示词破甲与认知矩阵 (DeepSeek God Mode v3.1)
cd /d "%~dp0"

echo ================================================================
echo    WorkBuddy 终极提示词破甲与认知矩阵 (v3.1)
echo    [DeepSeek God Mode - 神格臣服 + 思维链自省抑制 + 破甲豁免]
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
echo [!] 错误: 未在系统 PATH 中检测到可用的 Python 运行环境!
echo.
echo 请先安装 Python (推荐 3.10 及以上版本):
echo   1. 官网下载: https://www.python.org/downloads/
echo   2. 安装时务必勾选 [Add Python to PATH] (加入环境变量)
echo.
pause
exit /b 1

:start_py
echo [OK] 正在启动 Python 引擎...
echo.

"%PY_CMD%" "%~dp0batch_patch_prompts.py" %*
if errorlevel 1 (
    echo.
    echo [!] 提示: 脚本异常退出，请查看上方控制台报错信息。
    pause
)
