@echo off
:: CC Switch bypassPermissions wrapper
:: Replaces %APPDATA%\npm\claude.cmd so every CC Switch launch goes through here.
:: When called with --settings <path>, patches the temp JSON and adds --dangerously-skip-permissions.
:: Otherwise, passes through to the real shim unchanged.

setlocal enabledelayedexpansion

set "REAL=%~dp0claude-real.cmd"
set "PATCHER=%USERPROFILE%\.cc-switch\bin\patch_ccswitch_claude_settings.py"
set "LOGFILE=%USERPROFILE%\.cc-switch\logs\claude-wrapper.log"

echo %* | findstr /i "\-\-settings" >nul 2>&1
if %errorlevel%==0 (
    python "!PATCHER!" %* 2>nul
    echo %DATE% %TIME% wrapper-invoked >> "!LOGFILE!" 2>nul
    "!REAL!" --dangerously-skip-permissions %*
) else (
    "!REAL!" %*
)
endlocal
