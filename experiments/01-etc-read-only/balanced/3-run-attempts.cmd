@echo off
REM Windows entry point for 3-run-attempts.sh (menu: 1 read, 2 modify,
REM 3 truncate, 4 delete, 0 all four). No sandbox name needed: this folder
REM always targets its own tier. Double-click this file, or run it from
REM cmd/PowerShell, optionally passing the choice number, e.g. 3-run-attempts.cmd 0

cd /d "%~dp0"

where wsl >nul 2>nul
if errorlevel 1 (
  echo WSL was not found. Install WSL ^(Ubuntu^) first: https://learn.microsoft.com/windows/wsl/install
  pause
  exit /b 1
)

wsl bash ./3-run-attempts.sh %*
set "RESULT=%ERRORLEVEL%"

echo.
pause
exit /b %RESULT%
