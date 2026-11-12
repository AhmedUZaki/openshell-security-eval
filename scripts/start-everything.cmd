@echo off
REM Starts everything this project needs, on Windows: Docker Desktop (which
REM runs on Windows and cannot be started from inside WSL), then Ollama and
REM the existing tier sandboxes inside WSL via start-everything.sh.
REM Double-click this file, or run it from cmd/PowerShell.

cd /d "%~dp0"

where wsl >nul 2>nul
if errorlevel 1 (
  echo WSL was not found. Install WSL ^(Ubuntu^) first: https://learn.microsoft.com/windows/wsl/install
  pause
  exit /b 1
)

echo === Starting Docker Desktop on Windows ===
tasklist /FI "IMAGENAME eq Docker Desktop.exe" 2>nul | find /I "Docker Desktop.exe" >nul
if errorlevel 1 (
  if exist "C:\Program Files\Docker\Docker\Docker Desktop.exe" (
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo Docker Desktop is launching, this can take a minute...
  ) else (
    echo Could not find Docker Desktop.exe in the default location.
    echo Start Docker Desktop yourself, then re-run this file.
  )
) else (
  echo Docker Desktop is already running.
)

echo.
echo === Starting Ollama and the project sandboxes inside WSL ===
wsl bash ./start-everything.sh
set "RESULT=%ERRORLEVEL%"

echo.
pause
exit /b %RESULT%
