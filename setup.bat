@echo off
setlocal enabledelayedexpansion

echo === claude-memory-sync setup (Windows) ===
echo.

where git >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: git is required
    exit /b 1
)

set SYNC_DIR=%USERPROFILE%\claude-memory

if "%~1"=="" (
    set /p REPO_URL="Your claude-memory repo URL (e.g. git@github.com:you/claude-memory.git): "
) else (
    set REPO_URL=%~1
)

if "%REPO_URL%"=="" (
    echo Error: repo URL is required
    exit /b 1
)

if exist "%SYNC_DIR%\.git" (
    echo Repo already exists, pulling latest...
    cd /d "%SYNC_DIR%" && git pull --rebase
) else (
    echo Cloning repo...
    git clone "%REPO_URL%" "%SYNC_DIR%"
)

:: Find memory path
set MEMORY_PATH=
for /d %%d in ("%USERPROFILE%\.claude\projects\*") do (
    if exist "%%d\memory" (
        set MEMORY_PATH=%%d\memory
        goto :found
    )
)

echo No Claude Code memory directory found.
echo Run Claude Code at least once, then re-run this script.
exit /b 1

:found
echo Found memory at: %MEMORY_PATH%

:: Check if already a symlink
fsutil reparsepoint query "%MEMORY_PATH%" >nul 2>nul
if %errorlevel% equ 0 (
    echo Already symlinked. Skipping.
    goto :hooks
)

:: Move or copy memory
if exist "%SYNC_DIR%\memory" (
    echo Memory found in repo. Backing up local memory...
    rename "%MEMORY_PATH%" memory.bak
) else (
    echo Moving local memory to repo...
    xcopy /E /I /Y "%MEMORY_PATH%" "%SYNC_DIR%\memory"
    rmdir /S /Q "%MEMORY_PATH%"
    cd /d "%SYNC_DIR%" && git add -A && git commit -m "Initial memory sync" && git push -u origin main
)

:: Create symlink (requires admin)
mklink /D "%MEMORY_PATH%" "%SYNC_DIR%\memory"
if %errorlevel% neq 0 (
    echo.
    echo ERROR: symlink failed. Run this script as Administrator.
    echo Right-click Command Prompt ^> Run as administrator
    exit /b 1
)

:hooks
:: Copy PowerShell scripts
if not exist "%SYNC_DIR%\bin" mkdir "%SYNC_DIR%\bin"
copy /Y "%~dp0sync-pull.ps1" "%SYNC_DIR%\bin\sync-pull.ps1"
copy /Y "%~dp0sync-push.ps1" "%SYNC_DIR%\bin\sync-push.ps1"

echo.
echo === Setup complete ===
echo.
echo Add these hooks to %%USERPROFILE%%\.claude\settings.json:
echo.
echo "hooks": {
echo   "SessionStart": [
echo     { "matcher": "", "hooks": [{ "type": "command", "command": "powershell -ExecutionPolicy Bypass -File %%USERPROFILE%%\\claude-memory\\bin\\sync-pull.ps1" }] }
echo   ],
echo   "Stop": [
echo     { "matcher": "", "hooks": [{ "type": "command", "command": "powershell -ExecutionPolicy Bypass -File %%USERPROFILE%%\\claude-memory\\bin\\sync-push.ps1" }] }
echo   ]
echo }
