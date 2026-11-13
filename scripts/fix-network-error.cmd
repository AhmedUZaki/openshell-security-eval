@echo off
REM Windows entry point for fix-network-error.sh.
REM Run this if an agent run fails with "network connection error", or every
REM attempt in an experiment run shows "(the agent made no tool calls)".
REM Double-click this file, or run it from cmd/PowerShell.

cd /d "%~dp0"

where wsl >nul 2>nul
if errorlevel 1 (
  echo WSL was not found. Install WSL ^(Ubuntu^) first: https://learn.microsoft.com/windows/wsl/install
  pause
  exit /b 1
)

wsl bash ./fix-network-error.sh
set "RESULT=%ERRORLEVEL%"

echo.
pause
exit /b %RESULT%
