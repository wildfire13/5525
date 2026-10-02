@echo off
setlocal
cd /d "%~dp0"
set "PYTHONUTF8=1"
where node >nul 2>nul
if errorlevel 1 goto missing_node
node -e "process.exit(Number(process.versions.node.split('.')[0]) >= 22 ? 0 : 1)" >nul 2>nul
if errorlevel 1 goto old_node
if defined NATIVE5525_PYTHON goto probe_override
:probe_standard
py -3 "%~dp0native\tk_bootstrap.py" >nul 2>nul
if not errorlevel 1 goto run_py
python "%~dp0native\tk_bootstrap.py" >nul 2>nul
if not errorlevel 1 goto run_python
set "NATIVE5525_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if exist "%NATIVE5525_PYTHON%" goto probe_runtime
:missing_python
echo [5525] Python 3 with working Tkinter was not found.
echo Install or select Python 3 with Tcl/Tk support, then try again.
echo Nothing was installed or changed by this launcher.
goto error
:probe_override
if not exist "%NATIVE5525_PYTHON%" goto invalid_override
"%NATIVE5525_PYTHON%" "%~dp0native\tk_bootstrap.py" >nul 2>nul
if not errorlevel 1 goto run_explicit
:invalid_override
echo [5525] NATIVE5525_PYTHON must be the full path to a working Python 3 with Tk.
goto error
:probe_runtime
"%NATIVE5525_PYTHON%" "%~dp0native\tk_bootstrap.py" >nul 2>nul
if errorlevel 1 goto missing_python
:run_explicit
"%NATIVE5525_PYTHON%" "%~dp0native\journey_app.py"
goto finished
:run_py
py -3 "%~dp0native\journey_app.py"
goto finished
:run_python
python "%~dp0native\journey_app.py"
goto finished
:missing_node
echo [5525] Node.js was not found on PATH. Node.js 22 or newer is required.
goto error
:old_node
echo [5525] Node.js 22 or newer is required, or Node.js could not start.
goto error
:finished
if not errorlevel 1 exit /b 0
echo [5525] The application stopped with an error. See the message above.
:error
pause
exit /b 1
