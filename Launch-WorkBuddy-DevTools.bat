@echo off
chcp 936 >nul
title Launch WorkBuddy with DevTools

set "WB_EXE=%LOCALAPPDATA%\Programs\WorkBuddy\WorkBuddy.exe"
if exist "%WB_EXE%" goto launch

for %%D in (C D E F G) do (
    if exist "%%D:\Users\%USERNAME%\AppData\Local\Programs\WorkBuddy\WorkBuddy.exe" (
        set "WB_EXE=%%D:\Users\%USERNAME%\AppData\Local\Programs\WorkBuddy\WorkBuddy.exe"
        goto launch
    )
    if exist "%%D:\Program Files\WorkBuddy\WorkBuddy.exe" (
        set "WB_EXE=%%D:\Program Files\WorkBuddy\WorkBuddy.exe"
        goto launch
    )
)

echo [错误] 未能找到 WorkBuddy.exe，请确认安装路径。
pause
exit /b 1

:launch
echo 正在启动 WorkBuddy 并开启 DevTools 开发者工具...
start "" "%WB_EXE%" --remote-debugging-port=9222 --auto-open-devtools-for-tabs
