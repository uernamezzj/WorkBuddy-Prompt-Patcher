@echo off
chcp 936 >nul
title WorkBuddy Prompt Patcher - 生成干净发行包
cd /d "%~dp0"

REM ================== 可配置项 ==================
REM 使用的 Python 命令（若用虚拟环境请改成 .venv\Scripts\python.exe）
set "PY_CMD=python"
REM 1 = 只生成目录（不打包 zip）；0 = 同时打包 zip
set "DIR_ONLY=0"
REM ===============================================

echo ================================================================
echo    生成干净发行包
echo    排除: patcher_config.json / patcher_report.json / __pycache__ / dist / .git
echo ================================================================
echo.

"%PY_CMD%" -c "import sys" >nul 2>&1
if errorlevel 1 (
    echo [!] 未找到可用的 Python，请先安装 Python 3.8+ 并勾选 Add to PATH
    echo.
    pause
    exit /b 1
)

if "%DIR_ONLY%"=="1" (
    "%PY_CMD%" "%~dp0make_release.py" --dir-only
) else (
    "%PY_CMD%" "%~dp0make_release.py"
)
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
    echo [!] 打包失败，请查看上方输出，退出代码 = %RC%
    pause
    exit /b %RC%
)

echo ================================================================
echo  [OK] 干净包已生成于 %~dp0dist
echo  [说明] 把 zip 或同名目录拷到目标机器，解压后双击
echo         【一键开启】上帝模式.bat 即可，无需其他配置。
echo ================================================================
echo.
pause
