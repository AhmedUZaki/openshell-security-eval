@echo off
REM Windows entry point for 3-create-tier-sandboxes.sh.
REM The actual sandboxes are created inside WSL, so this just forwards into
REM WSL (Ubuntu) and runs the real script there, keeping its interactive menu.
REM Double-click this file, or run it from cmd/PowerShell.

cd /d "%~dp0"

where wsl >nul 2>nul
if errorlevel 1 (
  echo WSL was not found. Install WSL ^(Ubuntu^) first: https://learn.microsoft.com/windows/wsl/install
  pause
  exit /b 1
)

wsl bash ./3-create-tier-sandboxes.sh
set "RESULT=%ERRORLEVEL%"

echo.
pause
exit /b %RESULT%
