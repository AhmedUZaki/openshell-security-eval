@echo off
REM Stops everything this project started, on Windows: the sandboxes and
REM Ollama inside WSL (via stop-everything.sh), then Docker Desktop itself,
REM which runs on Windows and cannot be stopped from inside WSL.
REM Double-click this file, or run it from cmd/PowerShell.

cd /d "%~dp0"

where wsl >nul 2>nul
if errorlevel 1 (
  echo WSL was not found. Install WSL ^(Ubuntu^) first: https://learn.microsoft.com/windows/wsl/install
  pause
  exit /b 1
)

echo === Stopping sandboxes and Ollama inside WSL ===
wsl bash ./stop-everything.sh

echo.
echo === Quitting Docker Desktop on Windows ===
taskkill /F /T /IM "Docker Desktop.exe"  >nul 2>nul
taskkill /F /T /IM "com.docker.backend.exe" >nul 2>nul
taskkill /F /T /IM "com.docker.build.exe"   >nul 2>nul
echo Docker Desktop stopped (or was not running).

echo.
echo All done.
pause
exit /b 0
