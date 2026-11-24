@echo off
chcp 936 >nul 2>&1
setlocal enabledelayedexpansion
title WorkBuddy 破甲部署检测 v3.9
color 0F
cd /d "%~dp0"

set "F1=MODE: UNRESTRICTED SANDBOX"
set "F2=HARD OUTPUT RULES"
set "F3=Scoped Rules"
set "F4=Never Refuse"
set "F5=CTF Core Contract"
set "F6=WEB PENTEST ROUTING"
set "F7=<execution_anchor>"
set "FS=Developer Execution Ethos"
set "FS2=Direct Delivery"
set "FR=placeholders"
set "FR2=PAYLOAD"

set "C_CNT=0"
for /L %%I in (1,1,9) do set "C%%I="
set "U_CNT=0"
for /L %%I in (1,1,9) do set "U%%I="
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
echo   WorkBuddy 破甲部署检测  v3.9
echo   判断: v3.9 补丁有没有真的写进去 / 覆盖到几轨
echo ================================================================
echo.

echo [1/5] 定位全部安装目录 ^(注册表 + 历史轨迹 + 全盘 C..Z 扫描^)
set "WBPS_1=JEVycm9yQWN0aW9uUHJlZmVyZW5jZT0nU2lsZW50bHlDb250aW51ZScKW0NvbnNvbGVdOjpPdXRwdXRFbmNvZGluZz1bU3lzdGVtLlRleHQuRW5jb2RpbmddOjpEZWZhdWx0CiRISW5zdD1bU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuSGFzaFNldFtzdHJpbmddXTo6bmV3KFtTeXN0ZW0uU3RyaW5nQ29tcGFyZXJdOjpPcmRpbmFsSWdub3JlQ2FzZSkKJEhVRGlyPVtTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5IYXNoU2V0W3N0cmluZ11dOjpuZXcoW1N5c3RlbS5TdHJpbmdDb21wYXJlcl06Ok9yZGluYWxJZ25vcmVDYXNlKQpmdW5jdGlvbiBBSSgkcCl7aWYoISRwKXtyZXR1cm59OyRwPSRwLlRyaW0oKS5UcmltKCciJykuVHJpbUVuZCgnXCcsJy8nKTtpZighJHApe3JldHVybn07JHA9JHAgLXJlcGxhY2UgJyhbXFwvXSlyZXNvdXJjZXNcMWFwcFwuYXNhclwudW5wYWNrZWRcMXJlc291cmNlc1wxdGVtcGxhdGVzJCcsJyc7JHQ9Sm9pbi1QYXRoICRwICdyZXNvdXJjZXNcYXBwLmFzYXIudW5wYWNrZWRccmVzb3VyY2VzXHRlbXBsYXRlc1x3b3JrYnVkZHktY3JhZnQtY29kZS1wcm9tcHQudHBsJztpZihUZXN0LVBhdGggLUxpdGVyYWxQYXRoICR0KXtmb3JlYWNoKCRtIGluIEAoJ3Jlc291cmNlc1xpbnN0YWxsLW1hbmlmZXN0Lmpzb24nLCdXb3JrQnVkZHkuZXhlJywnV29ya0J1ZGR5QUkuZXhlJywnV29ya0J1ZGR5IEFJLmV4ZScpKXtpZihUZXN0LVBhdGggLUxpdGVyYWxQYXRoIChKb2luLVBhdGggJHAgJG0pKXtbdm9pZF0kSEluc3QuQWRkKChnaSAtTGl0ZXJhbFBhdGggJHAgLUZvcmNlKS5GdWxsTmFtZSk7YnJlYWt9fX19CmZ1bmN0aW9uIEFVKCRwKXtpZigkcCAtYW5kIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRwKSl7W3ZvaWRdJEhVRGlyLkFkZCgoZ2kgLUxpdGVyYWxQ"
set "WBPS_2=YXRoICRwIC1Gb3JjZSkuRnVsbE5hbWUpfX0KZm9yZWFjaCgkY2YgaW4gQCgiJGVudjpMT0NBTEFQUERBVEFcV29ya0J1ZGR5UGF0Y2hlclxwYXRjaGVyX2NvbmZpZy5qc29uIiwnLlxwYXRjaGVyX2NvbmZpZy5qc29uJykpe2lmKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGNmKXt0cnl7JGo9Z2MgLUxpdGVyYWxQYXRoICRjZiAtUmF3IC1FbmNvZGluZyBVVEY4fENvbnZlcnRGcm9tLUpzb247Zm9yZWFjaCgkZCBpbiBAKCRqLnRlbXBsYXRlc19kaXJzKStAKCRqLnRlbXBsYXRlc19kaXIpKXtBSSAkZH19Y2F0Y2h7fX19CkdldC1DaW1JbnN0YW5jZSBXaW4zMl9Qcm9jZXNzIC1GaWx0ZXIgIk5hbWUgTElLRSAnJVdvcmtCdWRkeSUnInwle2lmKCRfLkV4ZWN1dGFibGVQYXRoKXtBSSAoU3BsaXQtUGF0aCAkXy5FeGVjdXRhYmxlUGF0aCAtUGFyZW50KX19CiRTaWRzPUAoZ2NpIFJlZ2lzdHJ5OjpIS0VZX1VTRVJTfD97JF8uUFNDaGlsZE5hbWUuTGVuZ3RoIC1ndCA4IC1hbmQgJF8uUFNDaGlsZE5hbWUgLW5vdGxpa2UgJypfQ2xhc3Nlcyd9fCV7JF8uUFNDaGlsZE5hbWV9KQokVVJvb3RzPUAoJ0hLQ1U6XFNvZnR3YXJlXE1pY3Jvc29mdFxXaW5kb3dzXEN1cnJlbnRWZXJzaW9uXFVuaW5zdGFsbCcsJ0hLTE06XFNvZnR3YXJlXE1pY3Jvc29mdFxXaW5kb3dzXEN1cnJlbnRWZXJzaW9uXFVuaW5zdGFsbCcsJ0hLTE06XFNvZnR3YXJlXFdPVzY0MzJOb2RlXE1pY3Jvc29mdFxXaW5kb3dzXEN1cnJlbnRWZXJzaW9uXFVuaW5zdGFsbCcpKygkU2lkc3wleyJSZWdpc3RyeTo6SEtFWV9VU0VSU1wkX1xTb2Z0d2FyZVxNaWNyb3NvZnRcV2luZG93c1xDdXJyZW50VmVyc2lvblxVbmluc3RhbGwifSkKZm9yZWFjaCgkciBpbiAkVVJvb3RzKXtnY2kgJHJ8JXskcHI9Z3AgJF8uUFNQYXRoO2lmKCgkXy5Q"
set "WBPS_3=U0NoaWxkTmFtZSsnICcrJHByLkRpc3BsYXlOYW1lKycgJyskcHIuSW5zdGFsbExvY2F0aW9uKSAtbWF0Y2ggJ3dvcmtidWRkeScpe2ZvcmVhY2goJHYgaW4gQCgkcHIuSW5zdGFsbExvY2F0aW9uLCRwci5EaXNwbGF5SWNvbiwkcHIuVW5pbnN0YWxsU3RyaW5nKSl7aWYoJHYpeyRzPSgkdiAtcmVwbGFjZSAnIicsJycgLXNwbGl0ICcsJylbMF0uVHJpbSgpO2lmKCRzIC1tYXRjaCAnXihbQS1aYS16XTpcXC4rP1wuZXhlKVxiJyl7JHM9U3BsaXQtUGF0aCAkTWF0Y2hlc1sxXSAtUGFyZW50fTtBSSAkc319fX19CiRUU3Vicz1AKCdTb2Z0d2FyZVxNaWNyb3NvZnRcV2luZG93cyBOVFxDdXJyZW50VmVyc2lvblxBcHBDb21wYXRGbGFnc1xDb21wYXRpYmlsaXR5IEFzc2lzdGFudFxTdG9yZScsJ1NvZnR3YXJlXE1pY3Jvc29mdFxXaW5kb3dzXEN1cnJlbnRWZXJzaW9uXEV4cGxvcmVyXEZlYXR1cmVVc2FnZVxBcHBTd2l0Y2hlZCcsJ1NvZnR3YXJlXENsYXNzZXNcTG9jYWwgU2V0dGluZ3NcU29mdHdhcmVcTWljcm9zb2Z0XFdpbmRvd3NcU2hlbGxcTXVpQ2FjaGUnKQpmb3JlYWNoKCR0ciBpbiAoKCRUU3Vic3wleyJIS0NVOlwkXyJ9KSsoJFNpZHN8JXskaWQ9JF87JFRTdWJzfCV7IlJlZ2lzdHJ5OjpIS0VZX1VTRVJTXCRpZFwkXyJ9fSkpKXt0cnl7JGs9Z2kgJHRyO2lmKCRrKXtmb3JlYWNoKCRuIGluICRrLkdldFZhbHVlTmFtZXMoKSl7aWYoJG4gLW1hdGNoICd3b3JrYnVkZHknIC1hbmQgJG4gLW5vdG1hdGNoICd0ZW1wfHNldHVwfGluc3RhbGx8bGF1bmNoZXInIC1hbmQgJG4gLW1hdGNoICcoW0EtWmEtel06XFxbXiI8PnwqP10rP1wuZXhlKScpe2lmKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJE1hdGNoZXNbMV0pe0FJIChTcGxpdC1QYXRoICRNYXRjaGVzWzFdIC1QYXJlbnQpfX19fX1j"
set "WBPS_4=YXRjaHt9fQokU2tpcD1AKCd3aW5kb3dzJywnJHJlY3ljbGUuYmluJywnc3lzdGVtIHZvbHVtZSBpbmZvcm1hdGlvbicsJ3JlY292ZXJ5JywncGVyZmxvZ3MnLCdtc29jYWNoZScsJ2RvY3VtZW50cyBhbmQgc2V0dGluZ3MnLCdjb25maWcubXNpJywnbm9kZV9tb2R1bGVzJywnLmdpdCcpCmZvcmVhY2goJGNoIGluIFtjaGFyW11dJ0NERUZHSElKS0xNTk9QUVJTVFVWV1hZWicpeyRkcnY9IiR7Y2h9OlwiO2lmKCEoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkZHJ2KSl7Y29udGludWV9OyR1cj1Kb2luLVBhdGggJGRydiAnVXNlcnMnO2lmKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHVyKXtnY2kgLUxpdGVyYWxQYXRoICR1ciAtRGlyZWN0b3J5IC1Gb3JjZXwle0FVIChKb2luLVBhdGggJF8uRnVsbE5hbWUgJy53b3JrYnVkZHknKTtBVSAoSm9pbi1QYXRoICRfLkZ1bGxOYW1lICcud29ya2J1ZGR5LWFpJyk7Zm9yZWFjaCgkc2IgaW4gQCgnQXBwRGF0YVxMb2NhbFxQcm9ncmFtcycsJ0FwcERhdGFcTG9jYWwnLCdBcHBEYXRhXFJvYW1pbmcnKSl7JHNwPUpvaW4tUGF0aCAkXy5GdWxsTmFtZSAkc2I7aWYoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkc3Ape2djaSAtTGl0ZXJhbFBhdGggJHNwIC1EaXJlY3RvcnkgLUZvcmNlfCV7QUkgJF8uRnVsbE5hbWV9fX19fTtnY2kgLUxpdGVyYWxQYXRoICRkcnYgLURpcmVjdG9yeSAtRm9yY2V8P3skU2tpcCAtbm90Y29udGFpbnMgJF8uTmFtZS5Ub0xvd2VyKCkgLWFuZCAhJF8uTmFtZS5TdGFydHNXaXRoKCcuJyl9fCV7QUkgJF8uRnVsbE5hbWU7Z2NpIC1MaXRlcmFsUGF0aCAkXy5GdWxsTmFtZSAtRGlyZWN0b3J5IC1Gb3JjZXw/eyRTa2lwIC1ub3Rjb250YWlucyAkXy5OYW1lLlRvTG93ZXIoKSAtYW5kICEkXy5OYW1lLlN0YXJ0c1dpdGgoJy4nKX18"
set "WBPS_5=JXtBSSAkXy5GdWxsTmFtZX19fQpBVSAiJGVudjpVU0VSUFJPRklMRVwud29ya2J1ZGR5IjtBVSAiJGVudjpVU0VSUFJPRklMRVwud29ya2J1ZGR5LWFpIgpmb3JlYWNoKCR4IGluICRISW5zdCl7IklOU1R8JHgifTtmb3JlYWNoKCR5IGluICRIVURpcil7IlVESVJ8JHkifQ=="
for /f "usebackq tokens=1,* delims=|" %%A in (`powershell -NoProfile -NonInteractive -Command "iex ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:WBPS_1+$env:WBPS_2+$env:WBPS_3+$env:WBPS_4+$env:WBPS_5)))" 2^>nul`) do (
    if "%%A"=="INST" call :add_client "%%B"
    if "%%A"=="UDIR" call :add_udir "%%B"
)

rem 兜底标准路径（防极端精简系统禁用 PowerShell）
if "%C_CNT%"=="0" (
    call :probe_root "%LOCALAPPDATA%\Programs"
    call :probe_root "%USERPROFILE%\AppData\Local\Programs"
    set "PF=%ProgramFiles%"
    if defined PF call :probe_root "!PF!"
    set "PF86=%ProgramFiles(x86)%"
    if defined PF86 call :probe_root "!PF86!"
    call :add_udir "%USERPROFILE%\.workbuddy"
    call :add_udir "%USERPROFILE%\.workbuddy-ai"
)

if not "%~1"=="" (
    call :check_and_add "%~1"
    if exist "%~1\templates\workbuddy-craft-code-prompt.tpl" (
        for %%R in ("%~1\..\..\..\..") do call :check_and_add "%%~fR"
    )
)

if "%C_CNT%"=="0" (
    echo     [X] 没找到任何 WorkBuddy 安装
    echo.
    echo     - 先正常安装并启动登录一次客户端
    echo     - 再运行【一键开启】上帝模式.bat
    echo     - 装在特殊位置: 把安装目录拖到本 bat 图标上重跑
    set "G_NOCLIENT=1"
)
echo.

if "%G_NOCLIENT%"=="1" goto :summary

echo [2/5] 检测主模板 templates  ^(v3.9 七条指纹^)
for /L %%I in (1,1,%C_CNT%) do (
    call :scan_tpl "C%%I" "!C%%I!\resources\app.asar.unpacked\resources\templates"
)
echo.

echo [3/5] 检测 welcomemode 全部模式  ^(安装目录 + 插件缓存 + marketplaces^)
call :scan_wm
if "%G_WM_ALL%"=="0" echo     [--] 未找到缓存目录, 客户端可能从未启动
echo.

echo [4/5] 检测账号级 SOUL.md  ^(神格契约^)
call :scan_soul
if "%G_SOUL_ALL%"=="0" echo     [--] 未找到账号目录, 客户端可能从未登录
echo.

echo [5/5] 检测每轮提醒 R5 与客户端进程
for /L %%I in (1,1,%C_CNT%) do (
    call :scan_rem "!C%%I!\resources\app.asar.unpacked\resources\templates"
)
call :chk_proc
echo.

:summary
echo ================================================================
echo   检测结果 ^(共扫描到 %C_CNT% 份客户端安装^)
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

echo    主模板     %G_TPL_OK%/%G_TPL_ALL% 带 v3.9 指纹
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
if not "%G_REM_OK%"=="%G_REM_ALL%" set "PASS=0"

if "%PASS%"=="1" (
    echo    文件层: [PASS] 补丁已完整写入, 内容确认是 v3.9
    set "RC=0"
    goto :verdict
)
echo    文件层: [FAIL] 有缺口, 见上面标 缺口 的行
echo.
echo    ^>^>^> 常见原因
echo      - 从没跑过【一键开启】上帝模式.bat, 或跑的是 v3.8 及更早旧包
echo      - 客户端刚自动更新, 重跑【一键开启】上帝模式.bat 即可补齐
echo      - 客户端装在非默认位置, 请把安装目录拖到本 bat 上重跑
echo      - 杀软把 app.asar.unpacked 目录还原了
goto :end

:verdict
echo.
echo ----------------------------------------------------------------
if defined RUNNING (
    echo    进程层: [INFO] 检测到客户端正在运行 ^(纯批处理版不比对进程启动时间^)
    echo            若部署后尚未彻底重启, 请退出重开;
    echo            需精确时间轴与模型排查, 请运行【全面诊断】一键排查.bat
) else (
    echo    进程层: [OK] 客户端未运行, 下次启动即加载新版
)
echo ----------------------------------------------------------------
echo.
echo    ^>^>^> 让它真正生效, 请确认四步
echo      1^) 完全退出客户端 ^(【一键开启】已支持自动关闭残留进程^)
echo      2^) 重新启动客户端
echo      3^) 新建一个会话, 旧会话模板已固化改不动
echo      4^) 验证请优先用 DeepSeek 系列或 Hy4 flash 模型测试
echo.
echo ================================================================

:end
echo.
pause >nul
exit /b %RC%

:probe_root
if not exist "%~1" exit /b
for /d %%P in ("%~1\*") do (
    call :check_and_add "%%~P"
)
exit /b

:check_and_add
if "%~1"=="" exit /b
if exist "%~1\resources\app.asar.unpacked\resources\templates\workbuddy-craft-code-prompt.tpl" (
    if exist "%~1\resources\install-manifest.json" (
        call :add_client "%~1"
        exit /b
    )
    if exist "%~1\WorkBuddy.exe" (
        call :add_client "%~1"
        exit /b
    )
    if exist "%~1\WorkBuddyAI.exe" (
        call :add_client "%~1"
        exit /b
    )
    if exist "%~1\WorkBuddy AI.exe" (
        call :add_client "%~1"
        exit /b
    )
)
exit /b

:add_client
if "%~1"=="" exit /b
for %%N in ("%~1") do set "CAND=%%~fN"
if not defined CAND exit /b
:strip_slash
if not defined CAND exit /b
if "%CAND:~-1%"=="\" (
    set "CAND=%CAND:~0,-1%"
    goto :strip_slash
)
for /L %%I in (1,1,%C_CNT%) do (
    if /i "!C%%I!"=="%CAND%" exit /b
)
if %C_CNT% geq 9 exit /b
set /a C_CNT+=1
set "C%C_CNT%=%CAND%"
echo     [OK] %CAND%
exit /b

:add_udir
if "%~1"=="" exit /b
if not exist "%~1" exit /b
for %%N in ("%~1") do set "UCAND=%%~fN"
if not defined UCAND exit /b
:strip_uslash
if "%UCAND:~-1%"=="\" (
    set "UCAND=%UCAND:~0,-1%"
    goto :strip_uslash
)
for /L %%I in (1,1,%U_CNT%) do (
    if /i "!U%%I!"=="%UCAND%" exit /b
)
if %U_CNT% geq 9 exit /b
set /a U_CNT+=1
set "U%U_CNT%=%UCAND%"
exit /b

:scan_tpl
setlocal enabledelayedexpansion
set "T=%~2"
set "ok=0"
set "all=0"
for %%F in ("%T%\workbuddy-*prompt*.tpl") do (
    set /a all+=1
    call :probe7 "%%F"
    if !H! geq 7 (
        set /a ok+=1
        echo     !H!/7  %%~nxF
    ) else (
        echo     !H!/7  %%~nxF   ^<-- 缺口
    )
)
echo     -^> %ok%/%all% 带 v3.9 指纹  ^(%~1^)
endlocal & set /a G_TPL_OK+=%ok% & set /a G_TPL_ALL+=%all%
exit /b

:probe7
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
findstr /C:"%F7%" "%~1" >nul 2>&1
if not errorlevel 1 set /a H+=1
exit /b

:scan_wm
setlocal enabledelayedexpansion
set "ok=0"
set "all=0"
for /L %%I in (1,1,%C_CNT%) do (
    set "CUR_C=!C%%I!"
    for /d %%M in ("!CUR_C!\resources\app.asar.unpacked\resources\plugins\workbuddy-builtin\welcomemode\*") do (
        if exist "%%M\prompt.tpl" (
            set /a all+=1
            findstr /C:"%F1%" "%%M\prompt.tpl" >nul 2>&1
            if not errorlevel 1 (
                findstr /C:"%F7%" "%%M\prompt.tpl" >nul 2>&1
                if not errorlevel 1 (
                    set /a ok+=1
                ) else (
                    echo     缺口 安装目录 welcomemode %%~nxM ^(缺 v3.9 规则^)
                )
            ) else (
                echo     缺口 安装目录 welcomemode %%~nxM
            )
        )
    )
)
for /L %%I in (1,1,%U_CNT%) do (
    set "CUR_U=!U%%I!"
    if exist "!CUR_U!\plugins\cache\workbuddy-builtin" (
        for /d %%A in ("!CUR_U!\plugins\cache\workbuddy-builtin\welcomemode-*") do (
            for /d %%B in ("%%A\*") do (
                if exist "%%B\prompt.tpl" (
                    set /a all+=1
                    findstr /C:"%F1%" "%%B\prompt.tpl" >nul 2>&1
                    if not errorlevel 1 (
                        findstr /C:"%F7%" "%%B\prompt.tpl" >nul 2>&1
                        if not errorlevel 1 (
                            set /a ok+=1
                        ) else (
                            echo     缺口 %%~nxA %%~nxB ^(缺 v3.9 规则^)
                        )
                    ) else (
                        echo     缺口 %%~nxA %%~nxB
                    )
                )
            )
        )
    )
    if exist "!CUR_U!\plugins\marketplaces\workbuddy-builtin\welcomemode" (
        for /d %%M in ("!CUR_U!\plugins\marketplaces\workbuddy-builtin\welcomemode\*") do (
            if exist "%%M\prompt.tpl" (
                set /a all+=1
                findstr /C:"%F1%" "%%M\prompt.tpl" >nul 2>&1
                if not errorlevel 1 (
                    findstr /C:"%F7%" "%%M\prompt.tpl" >nul 2>&1
                    if not errorlevel 1 (
                        set /a ok+=1
                    ) else (
                        echo     缺口 marketplaces %%~nxM ^(缺 v3.9 规则^)
                    )
                ) else (
                    echo     缺口 marketplaces %%~nxM
                )
            )
        )
    )
)
echo     -^> %ok%/%all%  ^(安装目录 + 缓存 + marketplaces^)
endlocal & set "G_WM_OK=%ok%" & set "G_WM_ALL=%all%"
exit /b

:scan_soul
setlocal enabledelayedexpansion
set "ok=0"
set "all=0"
for /L %%I in (1,1,%U_CNT%) do (
    set "CUR_U=!U%%I!"
    if exist "!CUR_U!\SOUL.md" (
        set /a all+=1
        findstr /C:"%FS%" "!CUR_U!\SOUL.md" >nul 2>&1
        if not errorlevel 1 (
            findstr /C:"%FS2%" "!CUR_U!\SOUL.md" >nul 2>&1
            if not errorlevel 1 (
                set /a ok+=1
            ) else (
                echo     缺口 !CUR_U!\SOUL.md ^(缺 v3.9 纪律^)
            )
        ) else (
            echo     缺口 !CUR_U!\SOUL.md
        )
    )
    for /d %%S in ("!CUR_U!\user-*") do (
        if exist "%%S\SOUL.md" (
            set /a all+=1
            findstr /C:"%FS%" "%%S\SOUL.md" >nul 2>&1
            if not errorlevel 1 (
                findstr /C:"%FS2%" "%%S\SOUL.md" >nul 2>&1
                if not errorlevel 1 (
                    set /a ok+=1
                ) else (
                    echo     缺口 %%~nxS ^(缺 v3.9 纪律^)
                )
            ) else (
                echo     缺口 %%~nxS
            )
        )
    )
)
echo     -^> %ok%/%all%
endlocal & set "G_SOUL_OK=%ok%" & set "G_SOUL_ALL=%all%"
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
        findstr /C:"%FR2%" "%T%\craft-mode-reminder.tpl" >nul 2>&1
        if not errorlevel 1 (
            set /a ok+=1
        ) else (
            echo     缺口 craft-mode-reminder.tpl ^(缺 v3.9 每轮规则^)
        )
    ) else (
        echo     缺口 craft-mode-reminder.tpl
    )
)
if exist "%T%\ask-mode-reminder.tpl" (
    set /a all+=1
    findstr /C:"%FR%" "%T%\ask-mode-reminder.tpl" >nul 2>&1
    if not errorlevel 1 (
        findstr /C:"%FR2%" "%T%\ask-mode-reminder.tpl" >nul 2>&1
        if not errorlevel 1 (
            set /a ok+=1
        ) else (
            echo     缺口 ask-mode-reminder.tpl ^(缺 v3.9 每轮规则^)
        )
    ) else (
        echo     缺口 ask-mode-reminder.tpl
    )
)
echo     -^> %ok%/%all% 含每轮占位规则
endlocal & set /a G_REM_OK+=%ok% & set /a G_REM_ALL+=%all%
exit /b

:chk_proc
tasklist /FO CSV /NH /FI "IMAGENAME eq WorkBuddy.exe" 2>nul | findstr /I "WorkBuddy.exe" >nul
if not errorlevel 1 set "RUNNING=1"
tasklist /FO CSV /NH /FI "IMAGENAME eq WorkBuddyAI.exe" 2>nul | findstr /I "WorkBuddyAI.exe" >nul
if not errorlevel 1 set "RUNNING=1"
tasklist /FO CSV /NH /FI "IMAGENAME eq WorkBuddy AI.exe" 2>nul | findstr /I "WorkBuddy AI.exe" >nul
if not errorlevel 1 set "RUNNING=1"
tasklist /FO CSV /NH /FI "IMAGENAME eq workbuddy-editor-sdk-supervisor.exe" 2>nul | findstr /I "workbuddy-editor-sdk-supervisor.exe" >nul
if not errorlevel 1 set "RUNNING=1"
if defined RUNNING (
    echo     [运行中] 检测到客户端进程
) else (
    echo     [未运行] 客户端当前是关闭状态
)
exit /b
