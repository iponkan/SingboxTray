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

:CHECK_FILES
if not exist "%CORE_DIR%\sing-box.exe" (
    cls
    color 0C
    echo ========================================================
    echo  [错误] 文件缺失！
    echo ========================================================
    echo.
    echo  找不到: "%CORE_DIR%\sing-box.exe"
    echo.
    echo  请先将 "sing-box.exe" 和 "windows.json"
    echo  这两个文件放入 "%CORE_DIR%" 文件夹中。
    echo.
    echo  按任意键打开该文件夹...
    pause >nul
    explorer "%CORE_DIR%"
    goto MENU
)

:MENU
cls
echo =================================================
echo                 Singbox Tray
echo =================================================
echo.
echo    [1] 启动 Singbox 托盘程序
echo        ^> 会在后台运行，并在右下角显示图标。
echo.
echo    [2] 创建桌面快捷方式
echo    [3] 添加到开机自启
echo    [4] 打开 Core 文件夹 (管理 sing-box.exe)
echo.
echo    [0] 退出
echo.
echo =================================================
set /p choice=请输入选项: 

if "%choice%"=="1" goto START_TRAY
if "%choice%"=="2" goto INSTALL_SHORTCUT
if "%choice%"=="3" goto AUTOSTART
if "%choice%"=="4" goto OPEN_FOLDER
if "%choice%"=="0" exit
goto MENU

:START_TRAY
echo.
echo [信息] 正在启动 Singbox 托盘程序...
start "" "%VBS_LAUNCHER%"
echo [成功] 程序已在后台启动。请检查系统托盘区域。
timeout /t 3 >nul
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

:OPEN_FOLDER
echo.
echo [信息] 正在打开 Core 文件夹...
explorer "%CORE_DIR%"
goto MENU
