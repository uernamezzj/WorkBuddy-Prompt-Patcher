@echo off
chcp 936 >nul
title WorkBuddy 上帝模式 - 一键部署 (DeepSeek God Mode v3.2)
cd /d "%~dp0"

echo ================================================================
echo    WorkBuddy 上帝模式 - 一键部署 (DeepSeek God Mode v3.2)
echo    [全自动安全备份 + 45+底层模板/插件注入 + 绝对臣服神格激活]
echo ================================================================
echo.

set "PY_CMD="

if exist "%~dp0.venv\Scripts\python.exe" (
    set "PY_CMD=%~dp0.venv\Scripts\python.exe"
    goto start_deploy
)
if exist "%~dp0venv\Scripts\python.exe" (
    set "PY_CMD=%~dp0venv\Scripts\python.exe"
    goto start_deploy
)

where python >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=python"
    goto start_deploy
)

where py >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=py"
    goto start_deploy
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

:start_deploy
echo [INFO] 正在为您全自动安全备份并部署 God Mode 破甲矩阵...
echo.

"%PY_CMD%" "%~dp0batch_patch_prompts.py" --auto
if errorlevel 1 (
    echo.
    echo [!] 提示: 部署过程中出现异常，请查看上方提示信息。
    echo.
    pause
    exit /b 1
)

echo.
echo ================================================================
echo  [OK] 一键部署全部成功！
echo  [OK] 官方原始备份已自动安全锁定在本地，随时可一键无损还原。
echo  [提示] 请【彻底退出并重启 WorkBuddy 客户端】以加载全新认知！
echo ================================================================
echo.
pause
