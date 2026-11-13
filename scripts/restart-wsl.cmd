@echo off
REM Fully restarts WSL (shuts down the WSL VM and lets Windows start it fresh
REM on the next command). Use this when a sandbox command hangs with no
REM output at all, or "nemoclaw doctor" reports it cannot reach the gateway,
REM and fix-network-error.cmd did not help. A full WSL restart clears that
REM kind of stuck state the same way it was clean right after a reboot.
REM
REM This resets ALL of WSL, not just this project -- any other WSL terminal
REM or distro you have running will also stop. Double-click this file, or
REM run it from cmd/PowerShell. Must run on Windows directly (not from
REM inside a WSL shell).

echo This will shut down WSL completely (every distro, not just this project).
echo Save any work open in other WSL terminals before continuing.
echo.
pause

echo.
echo Shutting down WSL...
wsl --shutdown

echo Waiting a moment for it to fully stop...
timeout /t 5 /nobreak >nul

echo.
echo Starting WSL back up...
wsl -e true
if errorlevel 1 (
  echo.
  echo Could not start WSL. Make sure Docker Desktop is running, then try again.
  pause
  exit /b 1
)

echo.
echo WSL is back up. Checking project status...
cd /d "%~dp0"
wsl bash ./check-status.sh

echo.
echo If Docker or a sandbox still shows as not running, give Docker Desktop a
echo few more seconds to reconnect, then run check-status.cmd again.
echo You can now re-run whatever you were trying before this failed.
pause
