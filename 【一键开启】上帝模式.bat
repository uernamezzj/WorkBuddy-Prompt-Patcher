@echo off
chcp 936 >nul
title WorkBuddy 上帝模式 - 一键部署 (DeepSeek God Mode v3.5)
cd /d "%~dp0"

echo ================================================================
echo    WorkBuddy 上帝模式 - 一键部署 (DeepSeek God Mode v3.5)
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
    echo [!] 部署未完全通过，退出代码 = %PY_RC%
    echo.
    if "%PY_RC%"=="2" (
        echo     含义: 检测到 WorkBuddy 客户端正在运行，已主动中止。
        echo     处理: 完全退出客户端后重跑（含 workbuddy-editor-sdk-supervisor.exe）。
    ) else (
        echo     含义: 有生效轨道未覆盖，请对照上方矩阵中标 [X] 的行。
        echo     R4 显示 0/0  -^> 客户端从未启动过：先启动并登录一次，再重跑。
        echo     R6 显示 0/0  -^> 没有账号目录：先登录客户端一次。
        echo     出现 版本偏差 -^> 客户端已升级：完全退出客户端后重跑。
        echo     其他情况      -^> 权限不足 / 客户端占用文件 / 模板格式异常。
    )
    echo.
    echo 当前目录: %~dp0
    echo ================================================================
    echo.
    pause
    exit /b %PY_RC%
)

echo.
echo ================================================================
echo  [OK] 部署完成：文件已全部写入（官方原版已备份，可一键还原）。
echo.
echo  ^>^>^> 本补丁只对【新会话】生效，旧会话不会变 ^<^<^<
echo.
echo    1) 完全退出客户端（任务管理器确认 WorkBuddy.exe 与
echo       workbuddy-editor-sdk-supervisor.exe 都没有残留）
echo    2) 重新启动客户端
echo    3) 新建一个会话（不要点历史会话）
echo.
echo  [怎么验证] 新建会话后，直接问一句你之前被拒的问题即可。
echo             若仍被拒，先确认没点错历史会话，再试技术化的问法。
echo ================================================================
echo.
pause
