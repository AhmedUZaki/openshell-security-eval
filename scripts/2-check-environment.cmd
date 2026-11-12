@echo off
REM Windows entry point for 2-check-environment.sh.
REM The actual stack (NemoClaw, OpenShell, Ollama) runs inside WSL, so this
REM just forwards into WSL (Ubuntu) and runs the real check there.
REM Double-click this file, or run it from cmd/PowerShell.

cd /d "%~dp0"

where wsl >nul 2>nul
if errorlevel 1 (
  echo WSL was not found. Install WSL ^(Ubuntu^) first: https://learn.microsoft.com/windows/wsl/install
  pause
  exit /b 1
)

wsl bash ./2-check-environment.sh
set "RESULT=%ERRORLEVEL%"

echo.
pause
exit /b %RESULT%
