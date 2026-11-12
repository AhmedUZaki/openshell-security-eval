@echo off
REM Windows entry point for 1-prepare.sh. No sandbox name needed: this folder
REM always targets its own tier. Double-click this file, or run it from cmd/PowerShell.

cd /d "%~dp0"

where wsl >nul 2>nul
if errorlevel 1 (
  echo WSL was not found. Install WSL ^(Ubuntu^) first: https://learn.microsoft.com/windows/wsl/install
  pause
  exit /b 1
)

wsl bash ./1-prepare.sh
set "RESULT=%ERRORLEVEL%"

echo.
pause
exit /b %RESULT%
