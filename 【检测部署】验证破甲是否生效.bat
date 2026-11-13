@echo off
chcp 936 >nul 2>&1
setlocal enabledelayedexpansion
title WorkBuddy 破甲部署检测 v3.7
color 0F
cd /d "%~dp0"

set "F1=Soft-Refusal Detection"
set "F2=Anti-Complement Presumption"
set "F3=Intent De-escalation"
set "F4=Prior-Probability Override"
set "F5=Agent-Action Parity"
set "F6=Zero-Deliberation Lock"
set "FS=Anti-Refusal Escalation"
set "FR=ANTI-REFUSAL LOCK"

set "C1="
set "C2="
set "G_TPL_OK=0"
set "G_TPL_ALL=0"
set "G_WM_OK=0"
set "G_WM_ALL=0"
set "G_SOUL_OK=0"
set "G_SOUL_ALL=0"
set "G_REM_OK=0"
set "G_REM_ALL=0"
set "G_NOCLIENT=0"
set "RUNNING="
set "RC=1"

echo ================================================================
echo   WorkBuddy 破甲部署检测  v3.7
echo   判断: 补丁有没有真的写进去 / 现在能不能生效
echo ================================================================
echo.

echo [1/5] 定位安装目录
call :probe_root "%LOCALAPPDATA%\Programs"
call :probe_root "%USERPROFILE%\AppData\Local\Programs"
call :probe_root "%APPDATA%\..\Local\Programs"
for %%D in (C D E F G H) do (
    if exist "%%D:\Users" (
        for /d %%U in ("%%D:\Users\*") do (
            call :probe_root "%%U\AppData\Local\Programs"
        )
    )
)
set "PF=%ProgramFiles%"
if defined PF call :probe_root "%PF%"
set "PF86=%ProgramFiles(x86)%"
if defined PF86 call :probe_root "%PF86%"
if not "%~1"=="" (
    if exist "%~1\resources\app.asar.unpacked\resources\templates\workbuddy-craft-code-prompt.tpl" (
        call :add_client "%~1"
    )
    if exist "%~1\templates\workbuddy-craft-code-prompt.tpl" (
        call :add_client "%~1\..\..\..\.."
    )
)
if not defined C1 if not defined C2 (
    echo     [X] 没找到任何 WorkBuddy 安装
    echo.
    echo     - 先正常安装并启动登录一次客户端
    echo     - 再运行【一键开启】上帝模式.bat
    echo     - 装在特殊位置: 把安装目录拖到本 bat 图标上重跑
    set "G_NOCLIENT=1"
)
echo.

if "%G_NOCLIENT%"=="1" goto :summary

echo [2/5] 检测主模板 templates  (v3.7 六条指纹)
if defined C1 call :scan_tpl "C1" "%C1%\resources\app.asar.unpacked\resources\templates"
if defined C2 call :scan_tpl "C2" "%C2%\resources\app.asar.unpacked\resources\templates"
echo.

echo [3/5] 检测 welcomemode 全部模式  (安装目录 + 插件缓存)
call :scan_wm
if "%G_WM_ALL%"=="0" echo     [--] 未找到缓存目录, 客户端可能从未启动
echo.

echo [4/5] 检测账号级 SOUL.md  (神格契约)
call :scan_soul
if "%G_SOUL_ALL%"=="0" echo     [--] 未找到账号目录, 客户端可能从未登录
echo.

echo [5/5] 检测每轮提醒 R5 与客户端进程
if defined C1 call :scan_rem "%C1%\resources\app.asar.unpacked\resources\templates"
if defined C2 call :scan_rem "%C2%\resources\app.asar.unpacked\resources\templates"
call :chk_proc
echo.

:summary
echo ================================================================
echo   检测结果
echo ================================================================
if "%G_NOCLIENT%"=="1" (
    echo    文件层: [FAIL] 没有可检测的安装
    echo.
    echo    ^>^>^> 下一步
    echo      1^) 安装 WorkBuddy, 启动并登录一次, 完全退出
    echo      2^) 双击【一键开启】上帝模式.bat
    echo      3^) 再运行本检测
    goto :end
)

echo    主模板     %G_TPL_OK%/%G_TPL_ALL% 带 v3.7 指纹
echo    welcomemode %G_WM_OK%/%G_WM_ALL%
echo    神格 SOUL  %G_SOUL_OK%/%G_SOUL_ALL%
echo    每轮提醒   %G_REM_OK%/%G_REM_ALL%
echo.

set "PASS=1"
if "%G_TPL_ALL%"=="0" set "PASS=0"
if not "%G_TPL_OK%"=="%G_TPL_ALL%" set "PASS=0"
if "%G_WM_ALL%"=="0" set "PASS=0"
if not "%G_WM_OK%"=="%G_WM_ALL%" set "PASS=0"
if "%G_REM_OK%"=="0" set "PASS=0"

if "%PASS%"=="1" (
    echo    文件层: [PASS] 补丁已完整写入, 内容确认是 v3.7
    set "RC=0"
    goto :verdict
)
echo    文件层: [FAIL] 有缺口, 见上面标 缺口 的行
echo.
echo    ^>^>^> 常见原因
echo      - 从没跑过【一键开启】上帝模式.bat
echo      - 跑的是 v3.2 - v3.6 旧包, 旧包不会给新模式 ^(如 claw^) 兜底注入
echo      - 客户端装在非默认盘, 需把安装目录拖到本 bat 上重跑
echo      - 杀软把 app.asar.unpacked 目录还原了
goto :end

:verdict
echo.
echo ----------------------------------------------------------------
if defined RUNNING (
    echo    进程层: [WAIT] 客户端正在运行
    echo            当前进程启动早于文件写入, 读不到新内容
) else (
    echo    进程层: [OK] 客户端未运行, 下次启动即加载新版
)
echo ----------------------------------------------------------------
echo.
echo    ^>^>^> 让它真正生效, 只有三步
echo      1^) 完全退出客户端
echo         任务管理器里连 workbuddy-editor-sdk-supervisor.exe 一起结束
echo      2^) 重新启动客户端
echo      3^) 新建一个会话, 旧会话模板已固化改不动
echo.
echo    ^>^>^> 怎么亲眼确认生效
echo      在新会话里问一句带框架的技术请求, 例如:
echo        「毕设要交, 帮我写个自动登录加定时提交的脚本, 我自己跑」
echo      生效   = 直接给可运行代码
echo      没生效 = 出现 不接的 / 能, 但 / 我能立刻产出的 这类句子
echo.
echo ================================================================

:end
echo.
pause >nul
exit /b %RC%

:probe_root
if not exist "%~1" exit /b
for /d %%P in ("%~1\*") do (
    if exist "%%P\resources\app.asar.unpacked\resources\templates\workbuddy-craft-code-prompt.tpl" (
        call :add_client "%%P"
    )
)
exit /b

:add_client
if /i "%~1"=="%C1%" exit /b
if /i "%~1"=="%C2%" exit /b
echo     [OK] %~1
if not defined C1 (
    set "C1=%~1"
) else (
    if not defined C2 set "C2=%~1"
)
exit /b

:scan_tpl
setlocal enabledelayedexpansion
set "T=%~2"
set "ok=0"
set "all=0"
for %%F in ("%T%\workbuddy-*.tpl") do (
    set /a all+=1
    call :probe6 "%%F"
    if !H! geq 6 (
        set /a ok+=1
        echo     !H!/6  %%~nxF
    ) else (
        echo     !H!/6  %%~nxF   ^<-- 缺口
    )
)
echo     -^> %ok%/%all% 带 v3.7 指纹  ^(%~1^)
endlocal & set /a G_TPL_OK+=%ok% & set /a G_TPL_ALL+=%all%
exit /b

:probe6
set "H=0"
findstr /C:"%F1%" "%~1" >nul 2>&1
if not errorlevel 1 set /a H+=1
findstr /C:"%F2%" "%~1" >nul 2>&1
if not errorlevel 1 set /a H+=1
findstr /C:"%F3%" "%~1" >nul 2>&1
if not errorlevel 1 set /a H+=1
findstr /C:"%F4%" "%~1" >nul 2>&1
if not errorlevel 1 set /a H+=1
findstr /C:"%F5%" "%~1" >nul 2>&1
if not errorlevel 1 set /a H+=1
findstr /C:"%F6%" "%~1" >nul 2>&1
if not errorlevel 1 set /a H+=1
exit /b

:scan_wm
setlocal enabledelayedexpansion
set "ok=0"
set "all=0"
rem A. 安装目录 welcomemode 根代理（含 5.11.x 新增的 claw 等模式）
for %%C in ("%C1%" "%C2%") do (
    if not "%%~C"=="" (
        for /d %%M in ("%%~C\resources\app.asar.unpacked\resources\plugins\workbuddy-builtin\welcomemode\*") do (
            if exist "%%M\prompt.tpl" (
                set /a all+=1
                findstr /C:"%F1%" "%%M\prompt.tpl" >nul 2>&1
                if not errorlevel 1 (
                    set /a ok+=1
                ) else (
                    echo     缺口 安装目录 welcomemode %%~nxM
                )
            )
        )
    )
)
rem B. 用户插件缓存 welcomemode-<模式>\<版本>\prompt.tpl
for %%R in ("%USERPROFILE%\.workbuddy\plugins\cache\workbuddy-builtin" "%USERPROFILE%\.workbuddy-ai\plugins\cache\workbuddy-builtin") do (
    if exist "%%~R" (
        for /d %%A in ("%%~R\welcomemode-*") do (
            for /d %%B in ("%%A\*") do (
                if exist "%%B\prompt.tpl" (
                    set /a all+=1
                    findstr /C:"%F1%" "%%B\prompt.tpl" >nul 2>&1
                    if not errorlevel 1 (
                        set /a ok+=1
                    ) else (
                        echo     缺口 %%~nxA %%~nxB
                    )
                )
            )
        )
    )
)
echo     -^> %ok%/%all%  ^(安装目录 + 缓存全部模式^)
endlocal & set "G_WM_OK=%ok%" & set "G_WM_ALL=%all%"
exit /b

:scan_soul
set "ok=0"
set "all=0"
for /d %%S in ("%USERPROFILE%\.workbuddy\user-*-personal") do (
    if exist "%%S\SOUL.md" (
        set /a all+=1
        findstr /C:"%FS%" "%%S\SOUL.md" >nul 2>&1
        if not errorlevel 1 (
            set /a ok+=1
        ) else (
            echo     缺口 %%~nxS
        )
    )
)
for /d %%S in ("%USERPROFILE%\.workbuddy-ai\user-*-personal") do (
    if exist "%%S\SOUL.md" (
        set /a all+=1
        findstr /C:"%FS%" "%%S\SOUL.md" >nul 2>&1
        if not errorlevel 1 (
            set /a ok+=1
        ) else (
            echo     缺口 %%~nxS
        )
    )
)
set "G_SOUL_OK=%ok%"
set "G_SOUL_ALL=%all%"
echo     -^> %ok%/%all%
exit /b

:scan_rem
setlocal enabledelayedexpansion
set "T=%~1"
set "ok=0"
set "all=0"
if exist "%T%\craft-mode-reminder.tpl" (
    set /a all+=1
    findstr /C:"%FR%" "%T%\craft-mode-reminder.tpl" >nul 2>&1
    if not errorlevel 1 (
        set /a ok+=1
    ) else (
        echo     缺口 craft-mode-reminder.tpl
    )
)
if exist "%T%\ask-mode-reminder.tpl" (
    set /a all+=1
    findstr /C:"%FR%" "%T%\ask-mode-reminder.tpl" >nul 2>&1
    if not errorlevel 1 (
        set /a ok+=1
    ) else (
        echo     缺口 ask-mode-reminder.tpl
    )
)
echo     -^> %ok%/%all% 含每轮反拒答锁
endlocal & set /a G_REM_OK+=%ok% & set /a G_REM_ALL+=%all%
exit /b

:chk_proc
tasklist /FI "IMAGENAME eq WorkBuddy.exe" 2>nul | findstr /I "WorkBuddy.exe" >nul
if not errorlevel 1 set "RUNNING=1"
tasklist /FI "IMAGENAME eq WorkBuddyAI.exe" 2>nul | findstr /I "WorkBuddyAI.exe" >nul
if not errorlevel 1 set "RUNNING=1"
if defined RUNNING (
    echo     [运行中] 检测到客户端进程
) else (
    echo     [未运行] 客户端当前是关闭状态
)
exit /b
