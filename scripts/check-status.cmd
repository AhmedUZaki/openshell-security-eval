@echo off
REM Windows entry point for check-status.sh.
REM Read-only: shows whether Docker, Ollama, and the sandboxes are currently
REM running. Double-click this file, or run it from cmd/PowerShell.

cd /d "%~dp0"

where wsl >nul 2>nul
if errorlevel 1 (
  echo WSL was not found. Install WSL ^(Ubuntu^) first: https://learn.microsoft.com/windows/wsl/install
  pause
  exit /b 1
)

wsl bash ./check-status.sh
set "RESULT=%ERRORLEVEL%"

echo.
pause
exit /b %RESULT%
