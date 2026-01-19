@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title Singbox Tray
color 0A

REM ========================================================
REM   Path Configuration (Points to the 'core' subfolder)
REM ========================================================
set "CORE_DIR=%~dp0core"
set "VBS_LAUNCHER=%CORE_DIR%\start.vbs"

:MENU
cls
echo =================================================
echo              Singbox Tray - 初始化
echo =================================================
echo.
echo    [1] 设置订阅链接
echo    [2] 创建桌面快捷方式
echo    [3] 添加到开机自启
echo.
echo    [0] 退出
echo.
echo =================================================
set /p choice=请输入选项: 

if "%choice%"=="1" goto SET_URL
if "%choice%"=="2" goto INSTALL_SHORTCUT
if "%choice%"=="3" goto AUTOSTART
if "%choice%"=="0" exit
goto MENU

:SET_URL
cls
echo =================================================
echo                 设置订阅链接
echo =================================================
echo.
echo  请输入您的 Singbox 订阅链接:
echo.
set /p "URL="
if defined URL (
    echo !URL! > "%CORE_DIR%\url.conf"
    echo.
    echo [成功] 订阅链接已保存。
) else (
    echo.
    echo [取消] 未输入链接，操作已取消。
)
pause
goto MENU

:INSTALL_SHORTCUT
cls
echo [信息] 正在创建桌面快捷方式...
set "ICON_PATH=%CORE_DIR%\sing-box.exe"
set "LINK_NAME=Singbox Tray"
REM WorkingDirectory is crucial for the script to find its files
powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut([System.IO.Path]::Combine([Environment]::GetFolderPath('Desktop'), '%LINK_NAME%.lnk')); $s.TargetPath = '%VBS_LAUNCHER%'; $s.WorkingDirectory = '%CORE_DIR%'; $s.IconLocation = '%ICON_PATH%, 0'; $s.Save()"
echo [成功] 快捷方式已创建到桌面。
pause
goto MENU

:AUTOSTART
cls
echo [信息] 正在添加程序到开机启动项...
set "ICON_PATH=%CORE_DIR%\sing-box.exe"
set "STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%STARTUP_DIR%\Singbox_AutoStart.lnk'); $s.TargetPath = '%VBS_LAUNCHER%'; $s.WorkingDirectory = '%CORE_DIR%'; $s.IconLocation = '%ICON_PATH%, 0'; $s.Save()"
echo [成功] 程序已添加到开机启动文件夹。
pause
goto MENU
