@echo off
:: CC Switch bypassPermissions Fix - One-click Installer
:: https://github.com/xzyj50609/cc-switch-bypass-permissions
::
:: What this does:
::   1. Backs up %APPDATA%\npm\claude.cmd -> claude-real.cmd
::   2. Installs claude-wrapper.cmd as the new claude.cmd shim
::   3. Copies patch_ccswitch_claude_settings.py to %USERPROFILE%\.cc-switch\bin\
::
:: To undo: run uninstall.bat

setlocal

set "NPM_DIR=%APPDATA%\npm"
set "SHIM=%NPM_DIR%\claude.cmd"
set "REAL=%NPM_DIR%\claude-real.cmd"
set "BIN_DIR=%USERPROFILE%\.cc-switch\bin"
set "LOG_DIR=%USERPROFILE%\.cc-switch\logs"
set "SCRIPT_DIR=%~dp0"

echo.
echo === CC Switch bypassPermissions Fix - Install ===
echo.

:: Verify claude is installed via npm
if not exist "%SHIM%" (
    echo [ERROR] Not found: %SHIM%
    echo Make sure Claude Code is installed via npm ^(npm install -g @anthropic-ai/claude-code^).
    pause
    exit /b 1
)

:: Avoid double-backup
if exist "%REAL%" (
    echo [SKIP]  Backup already exists: %REAL%
) else (
    copy /Y "%SHIM%" "%REAL%" >nul
    if errorlevel 1 (
        echo [ERROR] Failed to back up %SHIM%
        pause
        exit /b 1
    )
    echo [OK]    Backed up: claude.cmd -^> claude-real.cmd
)

:: Create directories
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

:: Install patcher script
copy /Y "%SCRIPT_DIR%patch_ccswitch_claude_settings.py" "%BIN_DIR%\patch_ccswitch_claude_settings.py" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy patcher script
    pause
    exit /b 1
)
echo [OK]    Installed patcher: %BIN_DIR%\patch_ccswitch_claude_settings.py

:: Install wrapper as new claude.cmd
copy /Y "%SCRIPT_DIR%claude-wrapper.cmd" "%SHIM%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to install wrapper
    pause
    exit /b 1
)
echo [OK]    Installed wrapper: %SHIM%

echo.
echo Installation complete!
echo.
echo To verify: restart CC Switch, open a Claude terminal, then check:
echo   type "%USERPROFILE%\.cc-switch\logs\claude-wrapper.log"
echo   (should show "wrapper-invoked" lines after each CC Switch launch)
echo.
echo To uninstall: run uninstall.bat
echo.
pause
endlocal
