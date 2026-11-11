@echo off
chcp 936 >nul
title WorkBuddy 上帝模式 - 一键部署 (DeepSeek God Mode v3.4)
cd /d "%~dp0"

echo ================================================================
echo    WorkBuddy 上帝模式 - 一键部署 (DeepSeek God Mode v3.4)
echo    [全自动安全备份 + 45+底层模板深层注入 + 灵犀神格激活]
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
goto start_deploy

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

:start_deploy
echo [INFO] 正在为您全自动安全备份并部署 God Mode 破甲矩阵...
echo [INFO] 选用 Python 解释器: "%PY_CMD%"
echo.

set "PYTHONIOENCODING=gbk"
"%PY_CMD%" "%~dp0batch_patch_prompts.py" --auto
set "PY_RC=%ERRORLEVEL%"
if not "%PY_RC%"=="0" (
    echo.
    echo ================================================================
    echo [!] 部署过程中出现异常，退出代码 = %PY_RC%
    echo     常见原因: 权限不足 / WorkBuddy 正在运行占用文件 / 文件格式损坏
    echo ================================================================
    echo.
    pause
    exit /b %PY_RC%
)

echo.
echo ================================================================
echo  [OK] 一键全量部署成功！
echo  [OK] 官方原始模板已安全本地锁定，随时可一键秒还原。
echo  [提示] 请完全【退出 WorkBuddy 客户端】并重新打开，即可全量感知！
echo ================================================================
echo.
pause
