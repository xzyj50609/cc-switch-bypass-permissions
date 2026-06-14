@echo off
:: CC Switch bypassPermissions Fix - Uninstaller
:: Restores the original npm claude.cmd shim from the backup.

setlocal

set "NPM_DIR=%APPDATA%\npm"
set "SHIM=%NPM_DIR%\claude.cmd"
set "REAL=%NPM_DIR%\claude-real.cmd"

echo.
echo === CC Switch bypassPermissions Fix - Uninstall ===
echo.

if not exist "%REAL%" (
    echo [ERROR] Backup not found: %REAL%
    echo Cannot restore. If you installed this fix, the backup should be at that path.
    pause
    exit /b 1
)

copy /Y "%REAL%" "%SHIM%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to restore %SHIM%
    pause
    exit /b 1
)
echo [OK] Restored original: %REAL% -^> %SHIM%

echo.
echo Uninstalled. The wrapper and patcher scripts remain in:
echo   %USERPROFILE%\.cc-switch\bin\
echo You can delete them manually if no longer needed.
echo.
pause
endlocal
