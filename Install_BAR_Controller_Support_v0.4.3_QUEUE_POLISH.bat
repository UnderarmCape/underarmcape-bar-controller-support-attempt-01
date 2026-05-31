@echo off
setlocal EnableExtensions EnableDelayedExpansion

if /I not "%~1"=="__RUN__" (
    for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "BOOT_STAMP=%%I"
    set "BOOT_LOG=%USERPROFILE%\Desktop\BAR_Controller_Install_v0.4.3_QUEUE_POLISH_!BOOT_STAMP!.log"
    echo ============================================================
    echo BAR Xbox Controller Support v0.4.3 - Queue Polish
    echo ============================================================
    echo.
    echo This installer updates the LuaUI controller widgets only.
    echo It DOES NOT install the custom controller-enabled engine.
    echo.
    echo A custom controller-enabled Recoil/BAR engine is required:
    echo https://github.com/UnderarmCape/controllersupport-RecoilEngine-attempt-01/releases/tag/controller-support-recoil-2025-06-24-compat
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~f0' __RUN__ '!BOOT_LOG!' 2>&1 | Tee-Object -FilePath '!BOOT_LOG!'; Write-Host ''; Write-Host '============================================================'; Write-Host 'LOG SAVED HERE:'; Write-Host '!BOOT_LOG!'; Write-Host '============================================================'; Write-Host ''; Write-Host 'Window will stay open. Type exit or close it manually.'; cmd /k"
    exit /b
)

set "INSTALL_LOG=%~2"
title BAR Controller Support v0.4.3 - Queue Polish

echo ============================================================
echo BAR Xbox Controller Support v0.4.3 - Queue Polish
echo ============================================================
echo.
echo IMPORTANT: this is not a widget-only mod.
echo Required engine release:
echo   Repo: UnderarmCape/controllersupport-RecoilEngine-attempt-01
echo   Tag: controller-support-recoil-2025-06-24-compat
echo   Asset: recoil_2025.06.24-controller-support-pr2985-win64.zip
echo   URL: https://github.com/UnderarmCape/controllersupport-RecoilEngine-attempt-01/releases/tag/controller-support-recoil-2025-06-24-compat
echo.
echo This installer copies:
echo   gui_controller_camera_test.lua
echo   gui_controller_bindings_ui.lua
echo   gui_controller_smartx_mouse_audit.lua  ^(optional diagnostic, disabled by default^)
echo.
echo Log:
echo "%INSTALL_LOG%"
echo.

set "BAR_ROOT=%LOCALAPPDATA%\Programs\Beyond-All-Reason"
set "BAR_DATA=%BAR_ROOT%\data"
set "BAR_GAMES=%BAR_DATA%\games"
set "DST_BAR=%BAR_GAMES%\BAR.sdd"
set "DST_WIDGETS=%DST_BAR%\luaui\Widgets"
set "ENGINE_ROOT=%BAR_DATA%\engine"
set "PREFERRED_ENGINE_SLOT=recoil_2025.06.24"
set "PACKAGE_ROOT=%~dp0"
set "PACKAGE_WIDGETS=%PACKAGE_ROOT%luaui\Widgets"
set "BAR_RELEASE_TAG=controller-support-v0.4.3-queue-polish"
set "BAR_RELEASE_BASE=https://github.com/UnderarmCape/underarmcape-bar-controller-support-attempt-01/releases/download/%BAR_RELEASE_TAG%"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%I"

set "BACKUP_ROOT=%BAR_DATA%\controller-support-widget-backups\v0.4.3_QUEUE_POLISH_%STAMP%"
set "WORK=%TEMP%\BAR-Controller-Support-v0.4.3-QUEUE-POLISH-%STAMP%"

echo Checking BAR install folders...
echo.

if not exist "%BAR_ROOT%" (
    set "FAIL_MESSAGE=BAR install folder was not found: %BAR_ROOT%"
    goto FAIL
)

if not exist "%BAR_DATA%" (
    set "FAIL_MESSAGE=BAR data folder was not found: %BAR_DATA%"
    goto FAIL
)

if not exist "%DST_BAR%" (
    set "FAIL_MESSAGE=BAR.sdd was not found: %DST_BAR%"
    goto FAIL
)

if not exist "%DST_WIDGETS%" (
    set "FAIL_MESSAGE=BAR widget folder was not found: %DST_WIDGETS%"
    goto FAIL
)

echo Checking for a recoil_* engine slot...
set "ENGINE_SLOT="
if exist "%ENGINE_ROOT%" (
    for /f "delims=" %%E in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$root='%ENGINE_ROOT%'; $preferred='%PREFERRED_ENGINE_SLOT%'; $preferredPath=Join-Path $root $preferred; if (Test-Path -LiteralPath (Join-Path $preferredPath 'spring.exe')) { Write-Output $preferred; exit 0 }; $slots=Get-ChildItem -LiteralPath $root -Directory -Filter 'recoil_*' -ErrorAction SilentlyContinue ^| Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'spring.exe') } ^| Sort-Object Name -Descending; if ($slots.Count -gt 0) { Write-Output $slots[0].Name }"') do (
        if not defined ENGINE_SLOT set "ENGINE_SLOT=%%E"
    )
)

if defined ENGINE_SLOT (
    echo Detected engine slot:
    echo   %ENGINE_SLOT%
    echo.
) else (
    echo WARNING: no recoil_* engine slot with spring.exe was detected under:
    echo   %ENGINE_ROOT%
    echo.
    echo The widgets will still be copied, but controller input requires the custom controller-enabled engine.
    echo.
)

mkdir "%WORK%" 2>nul
mkdir "%BACKUP_ROOT%" 2>nul

if not exist "%WORK%" (
    set "FAIL_MESSAGE=Could not create temp folder: %WORK%"
    goto FAIL
)

if not exist "%BACKUP_ROOT%" (
    set "FAIL_MESSAGE=Could not create backup folder: %BACKUP_ROOT%"
    goto FAIL
)

call :InstallWidget "gui_controller_camera_test.lua" required
if errorlevel 1 goto FAIL

call :InstallWidget "gui_controller_bindings_ui.lua" required
if errorlevel 1 goto FAIL

call :InstallWidget "gui_controller_smartx_mouse_audit.lua" optional
if errorlevel 1 goto FAIL

echo.
echo ============================================================
echo INSTALL COMPLETE
echo ============================================================
echo.
echo Backups were saved to:
echo "%BACKUP_ROOT%"
echo.
echo Next steps:
echo   1. Confirm the custom controller-enabled engine is installed.
echo   2. Launch BAR.
echo   3. Load your local controller-support BAR.sdd.
echo   4. Confirm these widgets are enabled/loaded:
echo      - Controller Camera Test
echo      - Controller Bindings UI
echo.
echo Optional diagnostic widget:
echo   /luaui enablewidget "Controller SmartX Mouse Audit"
echo.
exit /b 0

:InstallWidget
set "WIDGET_NAME=%~1"
set "WIDGET_REQUIRED=%~2"
set "SRC_WIDGET="
set "DST_WIDGET=%DST_WIDGETS%\%WIDGET_NAME%"
set "WORK_WIDGET=%WORK%\%WIDGET_NAME%"

if exist "%PACKAGE_WIDGETS%\%WIDGET_NAME%" set "SRC_WIDGET=%PACKAGE_WIDGETS%\%WIDGET_NAME%"
if not defined SRC_WIDGET if exist "%PACKAGE_ROOT%%WIDGET_NAME%" set "SRC_WIDGET=%PACKAGE_ROOT%%WIDGET_NAME%"

if not defined SRC_WIDGET (
    if /I "%WIDGET_REQUIRED%"=="optional" (
        echo Optional widget not found in package, skipping:
        echo   %WIDGET_NAME%
        echo.
        exit /b 0
    )

    echo Required widget not found in package:
    echo   %WIDGET_NAME%
    echo Trying release download fallback...
    echo.

    set "DOWNLOAD_OK=0"
    where curl.exe >nul 2>nul
    if not errorlevel 1 (
        curl.exe -L --fail --retry 3 --retry-delay 2 --connect-timeout 20 --output "%WORK_WIDGET%" "%BAR_RELEASE_BASE%/%WIDGET_NAME%"
        if not errorlevel 1 set "DOWNLOAD_OK=1"
    )

    if "!DOWNLOAD_OK!"=="0" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%BAR_RELEASE_BASE%/%WIDGET_NAME%' -OutFile '%WORK_WIDGET%'"
        if not errorlevel 1 set "DOWNLOAD_OK=1"
    )

    if not "!DOWNLOAD_OK!"=="1" (
        set "FAIL_MESSAGE=Could not find or download required widget: %WIDGET_NAME%"
        exit /b 1
    )

    set "SRC_WIDGET=%WORK_WIDGET%"
)

echo Installing widget:
echo   %WIDGET_NAME%
echo Source:
echo   !SRC_WIDGET!
echo Destination:
echo   %DST_WIDGET%
echo.

if exist "%DST_WIDGET%" (
    copy /Y "%DST_WIDGET%" "%BACKUP_ROOT%\%WIDGET_NAME%.before_v0.4.3" >nul
    if errorlevel 1 (
        set "FAIL_MESSAGE=Failed to back up existing widget: %WIDGET_NAME%"
        exit /b 1
    )
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $src='!SRC_WIDGET!'; $dst='%DST_WIDGET%'; $utf8=[System.Text.UTF8Encoding]::new($false,$true); $bytes=[System.IO.File]::ReadAllBytes($src); if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { throw 'Source has UTF-8 BOM: %WIDGET_NAME%' }; [void]$utf8.GetString($bytes); Copy-Item -LiteralPath $src -Destination $dst -Force; $copied=[System.IO.File]::ReadAllBytes($dst); if ($copied.Length -ge 3 -and $copied[0] -eq 0xEF -and $copied[1] -eq 0xBB -and $copied[2] -eq 0xBF) { throw 'Installed file has UTF-8 BOM: %WIDGET_NAME%' }; [void]$utf8.GetString($copied)"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to validate/copy widget: %WIDGET_NAME%"
    exit /b 1
)

echo Installed OK:
echo   %WIDGET_NAME%
echo.
exit /b 0

:FAIL
echo.
echo ============================================================
echo INSTALL FAILED
echo ============================================================
echo.
echo !FAIL_MESSAGE!
echo.
echo Log:
echo "%INSTALL_LOG%"
echo.
echo Backup folder:
echo "%BACKUP_ROOT%"
echo.
exit /b 1

