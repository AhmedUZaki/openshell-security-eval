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

if not "%RESULT%"=="0" (
  echo.
  echo This did not finish cleanly ^(exit code %RESULT%^).
  echo If an attempt hung with no output, or you saw "network connection
  echo error" / "(the agent made no tool calls)" for every attempt, WSL's
  echo connection to Docker/NemoClaw may be stuck.
  choice /c YN /n /m "Restart WSL now, then try again yourself? [Y/N] "
  if errorlevel 2 goto :done
  if errorlevel 1 call "%~dp0..\..\..\scripts\restart-wsl.cmd"
)

:done
echo.
pause
exit /b %RESULT%
