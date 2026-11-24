@echo off
chcp 936 >nul
title WorkBuddy 官方原版 - 一键还原 (Restore Official Factory State)
cd /d "%~dp0"

echo ================================================================
echo    WorkBuddy 官方原版 - 一键还原 (Restore to Official)
echo    [从本地备份全量还原: 系统模板 + 根代理 + 用户神格]
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
goto start_restore

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

:start_restore
echo [INFO] 正在从本地安全备份一键还原官方原始出厂状态...
echo [INFO] 选用 Python 解释器: "%PY_CMD%"
echo.

rem 自动检测并安全关闭残留的客户端与守护进程（防止缩在右下角托盘导致写入中止或被覆盖）
set "WB_RUNNING="
tasklist /FO CSV /NH /FI "IMAGENAME eq WorkBuddy.exe" 2>nul | findstr /I "WorkBuddy.exe" >nul && set "WB_RUNNING=1"
tasklist /FO CSV /NH /FI "IMAGENAME eq WorkBuddyAI.exe" 2>nul | findstr /I "WorkBuddyAI.exe" >nul && set "WB_RUNNING=1"
tasklist /FO CSV /NH /FI "IMAGENAME eq WorkBuddy AI.exe" 2>nul | findstr /I "WorkBuddy AI.exe" >nul && set "WB_RUNNING=1"
tasklist /FO CSV /NH /FI "IMAGENAME eq workbuddy-editor-sdk-supervisor.exe" 2>nul | findstr /I "workbuddy-editor-sdk-supervisor.exe" >nul && set "WB_RUNNING=1"
if defined WB_RUNNING (
    echo [INFO] 检测到 WorkBuddy 客户端或托盘驻留进程正在运行，正在自动关闭以释放文件锁...
    taskkill /F /IM "WorkBuddy.exe" /T >nul 2>&1
    taskkill /F /IM "WorkBuddyAI.exe" /T >nul 2>&1
    taskkill /F /IM "WorkBuddy AI.exe" /T >nul 2>&1
    taskkill /F /IM "workbuddy-editor-sdk-supervisor.exe" /T >nul 2>&1
    ping 127.0.0.1 -n 3 >nul 2>&1
)

set "PYTHONIOENCODING=gbk"
"%PY_CMD%" "%~dp0batch_patch_prompts.py" --restore
set "PY_RC=%ERRORLEVEL%"
if not "%PY_RC%"=="0" (
    echo.
    echo ================================================================
    echo [!] 还原过程中出现异常，退出代码 = %PY_RC%
    echo     常见原因: 权限不足 / 未找到出厂备份 / WorkBuddy 正在运行
    echo ================================================================
    echo.
    pause
    exit /b %PY_RC%
)

echo.
echo ================================================================
echo  [OK] 一键还原全量成功！
echo  [OK] 所有系统模板、根代理与神格已完整恢复为官方出厂版本！
echo  [提示] 请完全【退出 WorkBuddy 客户端】并重新打开生效。
echo ================================================================
echo.
pause
