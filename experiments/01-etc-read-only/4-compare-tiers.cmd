@echo off
REM Windows entry point for 4-compare-tiers.sh (experiment 01).
REM Read-only: prints a side-by-side table from evidence already on this
REM machine. Run 3-run-attempts (choice 0) on all three tiers first.
REM Double-click this file, or run it from cmd/PowerShell.

cd /d "%~dp0"

where wsl >nul 2>nul
if errorlevel 1 (
  echo WSL was not found. Install WSL ^(Ubuntu^) first: https://learn.microsoft.com/windows/wsl/install
  pause
  exit /b 1
)

wsl bash ./4-compare-tiers.sh
set "RESULT=%ERRORLEVEL%"

echo.
pause
exit /b %RESULT%
