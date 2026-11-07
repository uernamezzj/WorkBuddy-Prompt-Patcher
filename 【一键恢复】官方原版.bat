@echo off
chcp 936 >nul
title WorkBuddy 官方原版 - 一键恢复 (Restore Official Factory State)
cd /d "%~dp0"

echo ================================================================
echo    WorkBuddy 官方原版 - 一键恢复 (Restore to Official)
echo    [从本地官方备份中无损全量还原: 系统模板 + 插件缓存 + 神格]
echo ================================================================
echo.

set "PY_CMD="

if exist "%~dp0.venv\Scripts\python.exe" (
    set "PY_CMD=%~dp0.venv\Scripts\python.exe"
    goto start_restore
)
if exist "%~dp0venv\Scripts\python.exe" (
    set "PY_CMD=%~dp0venv\Scripts\python.exe"
    goto start_restore
)

where python >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=python"
    goto start_restore
)

where py >nul 2>&1
if not errorlevel 1 (
    set "PY_CMD=py"
    goto start_restore
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

:start_restore
echo [INFO] 正在从本地安全备份中一键还原官方原始出厂状态...
echo.

"%PY_CMD%" "%~dp0batch_patch_prompts.py" --restore
if errorlevel 1 (
    echo.
    echo [!] 提示: 还原过程中出现异常，请查看上方提示信息。
    echo.
    pause
    exit /b 1
)

echo.
echo ================================================================
echo  [OK] 一键还原全部成功！
echo  [OK] 所有系统模板、插件缓存与用户神格已全部无损恢复为官方原版！
echo  [提示] 请【彻底退出并重启 WorkBuddy 客户端】生效。
echo ================================================================
echo.
pause
