@echo off
chcp 936 >nul
title WorkBuddy 全面深度诊断 v3.9 (排查多份安装 / 快捷方式 / 六轨 / 进程 / 会话)
cd /d "%~dp0"

echo ==========================================================================
echo   WorkBuddy 全面深度诊断工具 v3.9
echo   一次性排查: 多份安装冲突 / 快捷方式错位 / 六轨+marketplaces /
echo               进程与prewarm残留 / 新旧会话时间戳 / 使用的模型
echo   提示: 若装在极偏僻目录，可直接把 WorkBuddy 文件夹拖到本 bat 图标上运行
echo ==========================================================================
echo.

set "PY_CMD="

rem 1. 优先探测本地虚拟环境
if exist "%~dp0.venv\Scripts\python.exe" call :try_py "%~dp0.venv\Scripts\python.exe"
if not defined PY_CMD if exist "%~dp0venv\Scripts\python.exe" call :try_py "%~dp0venv\Scripts\python.exe"

rem 2. 逐个实测 PATH 中的 Python（排除 WindowsApps 假别名与损坏安装）
if not defined PY_CMD for /f "delims=" %%P in ('where python.exe 2^>nul') do call :try_py "%%P"
if not defined PY_CMD for /f "delims=" %%P in ('where python3.exe 2^>nul') do call :try_py "%%P"
if not defined PY_CMD for /f "delims=" %%P in ('where py.exe 2^>nul') do call :try_py "%%P"

if not defined PY_CMD goto no_python
goto run_diag

:try_py
if "%~1"=="" goto :eof
if defined PY_CMD goto :eof
"%~1" -c "import sys" >nul 2>&1
if errorlevel 1 goto :eof
set "PY_CMD=%~1"
goto :eof

:no_python
echo [!] 错误: 未在系统 PATH 中检测到可运行的完整 Python 环境!
echo     请确保已安装 Python 3.8+ 并勾选 [Add Python to PATH]。
echo     官网: https://www.python.org/downloads/
echo.
pause
exit /b 1

:run_diag
if not exist "%~dp0workbuddy_full_diagnose.py" (
    echo [!] 错误: 同目录下缺少 workbuddy_full_diagnose.py!
    echo     请把本 .bat 与 workbuddy_full_diagnose.py 放在同一个文件夹里再运行。
    echo.
    pause
    exit /b 1
)

echo [INFO] Python 解释器: "%PY_CMD%"
echo [INFO] 正在全盘扫描并生成诊断报告，请稍候 3~5 秒...
echo.

set "PYTHONIOENCODING=gbk"
"%PY_CMD%" "%~dp0workbuddy_full_diagnose.py" %*
set "DIAG_RC=%ERRORLEVEL%"

echo.
echo [提示] 完整诊断文本已保存在同目录: workbuddy_diagnose_report.txt
echo.
pause
exit /b %DIAG_RC%
