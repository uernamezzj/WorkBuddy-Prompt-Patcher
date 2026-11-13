@echo off
chcp 936 >nul
title WorkBuddy 进阶提示词定制工具 (DeepSeek God Mode v3.5)
cd /d "%~dp0"

echo ================================================================
echo    WorkBuddy 进阶提示词定制工具 (v3.5)
echo    [DeepSeek God Mode - 破甲矩阵 + 自定义同步]
echo ================================================================
echo.

set "PY_CMD="

rem 1. 优先探测本地工作区虚拟环境
if exist "%~dp0.venv\Scripts\python.exe" call :try_py "%~dp0.venv\Scripts\python.exe"
if not defined PY_CMD if exist "%~dp0venv\Scripts\python.exe" call :try_py "%~dp0venv\Scripts\python.exe"

rem 2. 实测验证系统 PATH 中的 Python 解释器（排除 WindowsApps 假别名与损坏安装）
if not defined PY_CMD for /f "delims=" %%P in ('where python.exe 2^>nul') do call :try_py "%%P"
if not defined PY_CMD for /f "delims=" %%P in ('where python3.exe 2^>nul') do call :try_py "%%P"
if not defined PY_CMD for /f "delims=" %%P in ('where py.exe 2^>nul') do call :try_py "%%P"

if not defined PY_CMD goto no_python
goto start_py

:try_py
if "%~1"=="" goto :eof
if defined PY_CMD goto :eof
"%~1" -c "import sys" >nul 2>&1
if errorlevel 1 goto :eof
set "PY_CMD=%~1"
goto :eof

:no_python
echo [!] 错误: 未在系统 PATH 中检测到可运行的完整 Python 环境!
echo.
echo 检测提示: 即使 Windows 显示存在 python 命令别名，也必须安装完整官方 Python。
echo 请先安装 Python (推荐 3.10 及以上版本):
echo   1. 官网下载: https://www.python.org/downloads/
echo   2. 安装时请务必勾选 [Add Python to PATH] (加入环境变量)
echo.
pause
exit /b 1

:start_py
echo [OK] 启动 Python 执行环境: "%PY_CMD%"
echo.

set "PYTHONIOENCODING=gbk"
"%PY_CMD%" "%~dp0batch_patch_prompts.py" %*
set "PY_RC=%ERRORLEVEL%"
if not "%PY_RC%"=="0" (
    echo.
    echo [!] 提示: 脚本异常退出，退出代码 = %PY_RC%
    pause
    exit /b %PY_RC%
)
