@echo off
setlocal
if exist "G:\Apps\Godot\Godot_v4.6.3-stable_win64_console.exe" set "GODOT_BIN=G:\Apps\Godot\Godot_v4.6.3-stable_win64_console.exe"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0godot\launch.ps1" %*
set "launcher_exit=%errorlevel%"
if not "%launcher_exit%"=="0" if "%~1"=="" pause
exit /b %launcher_exit%
