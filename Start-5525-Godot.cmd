@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0godot\launch.ps1" %*
set "launcher_exit=%errorlevel%"
if not "%launcher_exit%"=="0" if "%~1"=="" pause
exit /b %launcher_exit%
