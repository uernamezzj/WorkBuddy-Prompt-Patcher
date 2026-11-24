@echo off
chcp 936 >nul
title WorkBuddy 实时生效检测 (六轨 + 进程层 + 会话层)
cd /d "%~dp0"

echo ================================================================
echo    WorkBuddy 实时生效检测 (六轨文件 + 进程加载 + 会话时间戳)
echo    说明: 专门测试当前部署的文件是否已写入并真正被客户端加载
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
goto run_verify

:try_py
if "%~1"=="" goto :eof
if defined PY_CMD goto :eof
"%~1" -c "import sys" >nul 2>&1
if errorlevel 1 goto :eof
set "PY_CMD=%~1"
goto :eof

:no_python
echo [!] 错误: 未在系统 PATH 中检测到可运行的完整 Python 环境!
echo     请先安装 Python 3.10+ 并勾选 [Add Python to PATH]。
echo     或直接使用无需 Python 的基础检测: 【检测部署】验证破甲是否生效.bat
echo.
pause
exit /b 1

:run_verify
echo [INFO] 选用 Python 解释器: "%PY_CMD%"
echo [INFO] 正在执行六轨文件校验与进程/会话时间戳比对...
echo.

set "PYTHONIOENCODING=gbk"
"%PY_CMD%" "%~dp0batch_patch_prompts.py" --verify --verbose
set "PY_RC=%ERRORLEVEL%"

echo.
echo ================================================================
if "%PY_RC%"=="0" (
    echo  [OK] 文件层六轨全绿!
    echo       请重点确认上方 [A 进程层] 与 [B 会话层] 是否均为 [对勾/就绪]:
    echo         - 若 A 层提示进程启动早于写入: 请彻底退出 WorkBuddy 后重开
    echo         - 若 B 层提示会话早于写入: 请在客户端内新建一个会话
) else (
    echo  [!] 检测未完全通过 (退出码 = %PY_RC%)
    echo      请对照上方矩阵中标记缺失的轨道:
    echo        - 没跑过部署或客户端刚自动更新: 请重新运行【一键开启】上帝模式.bat
    echo        - R4/R6 显示 0/0: 请先正常打开并登录一次 WorkBuddy 客户端
)
echo ================================================================
echo.
pause
exit /b %PY_RC%
