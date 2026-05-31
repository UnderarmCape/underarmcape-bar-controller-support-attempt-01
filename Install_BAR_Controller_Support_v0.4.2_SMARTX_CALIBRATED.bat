@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM Bootstrap: live output AND Desktop log via PowerShell Tee-Object.
REM No "press any key"; the window stays open with cmd /k.
REM ============================================================

if /I not "%~1"=="__RUN__" (
    for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "BOOT_STAMP=%%I"
    set "BOOT_LOG=%USERPROFILE%\Desktop\BAR_Controller_Install_v0.4.2_SMARTX_CALIBRATED_!BOOT_STAMP!.log"

    echo ============================================================
    echo BAR Controller Support v0.4.2 - Smart X Calibrated Installer
    echo ============================================================
    echo.
    echo Output will show live in this window AND save to:
    echo "!BOOT_LOG!"
    echo.
    echo This window will stay open when finished.
    echo.

    powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~f0' __RUN__ '!BOOT_LOG!' 2>&1 | Tee-Object -FilePath '!BOOT_LOG!'; Write-Host ''; Write-Host '============================================================'; Write-Host 'LOG SAVED HERE:'; Write-Host '!BOOT_LOG!'; Write-Host '============================================================'; Write-Host ''; Write-Host 'Window will stay open. Type exit or close it manually.'; cmd /k"
    exit /b
)

set "INSTALL_LOG=%~2"
title BAR Controller Support v0.4.2 - Smart X Calibrated Installer

echo ============================================================
echo BAR Controller Support v0.4.2 - Smart X Calibrated Installer
echo ============================================================
echo.
echo This installer stages and verifies everything before replacing the active engine.
echo It uses the Recoil 2025.06.24 compatibility engine build with the reviewed PR #2985 API and the matching BAR controller widgets.
echo It also disables Spring camera cardinal locking for smoother rotation.
echo.
echo Log:
echo "%INSTALL_LOG%"
echo.

REM ============================================================
REM Settings
REM ============================================================

set "BAR_ROOT=%LOCALAPPDATA%\Programs\Beyond-All-Reason"
set "BAR_DATA=%BAR_ROOT%\data"
set "PREFERRED_ENGINE_SLOT=recoil_2025.06.24"
set "ENGINE_SLOT="
set "ENGINE_ROOT=%BAR_DATA%\engine"
set "DST_ENGINE="
set "DST_GAMES=%BAR_DATA%\games"
set "DST_BAR=%DST_GAMES%\BAR.sdd"
set "DST_CHOBBY=%DST_GAMES%\BYAR Chobby.sdd"
set "BACKUP=%BAR_DATA%\controller-support-cleaninstall-backups"
set "SPRING_SETTINGS=%BAR_DATA%\springsettings.cfg"

set "BAR_REPO=https://github.com/UnderarmCape/underarmcape-bar-controller-support-attempt-01.git"
set "BAR_BRANCH=controller-support-current-master-engine-shim"
set "BAR_RELEASE_TAG=controller-support-v0.4.2-smartx-calibrated"
set "CHOBBY_REPO=https://github.com/beyond-all-reason/BYAR-Chobby.git"

set "ENGINE_ASSET_NAME=recoil_2025.06.24-controller-support-pr2985-win64.zip"
set "ENGINE_URL=https://github.com/UnderarmCape/controllersupport-RecoilEngine-attempt-01/releases/download/controller-support-recoil-2025-06-24-compat/%ENGINE_ASSET_NAME%"
set "WIDGET_ASSET_NAME=gui_controller_camera_test.lua"
set "WIDGET_URL=https://github.com/UnderarmCape/underarmcape-bar-controller-support-attempt-01/releases/download/%BAR_RELEASE_TAG%/%WIDGET_ASSET_NAME%"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%I"

set "WORK=%TEMP%\BAR-Controller-Support-v0.4.2-SMARTX-CALIBRATED-%STAMP%"
set "ENGINE_ARCHIVE=%WORK%\%ENGINE_ASSET_NAME%"
set "ENGINE_EXTRACT=%WORK%\engine_extract"
set "LOCAL_ENGINE_ARCHIVE=%~dp0%ENGINE_ASSET_NAME%"
set "WIDGET_SOURCE=%WORK%\%WIDGET_ASSET_NAME%"
set "LOCAL_WIDGET=%~dp0%WIDGET_ASSET_NAME%"

set "STAGE_ENGINE="
set "STAGE_BAR=%DST_GAMES%\BAR.sdd.controller-stage-%STAMP%"
set "STAGE_CHOBBY=%DST_GAMES%\BYAR Chobby.sdd.controller-stage-%STAMP%"

set "ENGINE_BACKUP="
set "BAR_BACKUP=%BACKUP%\BAR.sdd_before_controller_install_%STAMP%"
set "CHOBBY_BACKUP=%BACKUP%\BYAR_Chobby.sdd_before_controller_install_%STAMP%"

REM ============================================================
REM Requirements
REM ============================================================

echo.
echo ============================================================
echo Checking requirements
echo ============================================================
echo.

if not exist "%BAR_ROOT%" (
    set "FAIL_MESSAGE=BAR install folder was not found: %BAR_ROOT%"
    goto FAIL
)

if not exist "%BAR_DATA%" (
    set "FAIL_MESSAGE=BAR data folder was not found: %BAR_DATA%"
    goto FAIL
)

if not exist "%ENGINE_ROOT%" (
    set "FAIL_MESSAGE=BAR engine folder was not found: %ENGINE_ROOT%"
    goto FAIL
)

echo Detecting BAR engine slot under:
echo "%ENGINE_ROOT%"
echo Preferred slot:
echo "%PREFERRED_ENGINE_SLOT%"
echo.

for /f "delims=" %%E in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $root='%ENGINE_ROOT%'; $preferred='%PREFERRED_ENGINE_SLOT%'; $preferredPath=Join-Path $root $preferred; if (Test-Path -LiteralPath (Join-Path $preferredPath 'spring.exe')) { Write-Output $preferred; exit 0 }; $slots=Get-ChildItem -LiteralPath $root -Directory -Filter 'recoil_*' -ErrorAction Stop ^| Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'spring.exe') } ^| Sort-Object Name -Descending; if ($slots.Count -gt 0) { Write-Output $slots[0].Name; exit 0 }; exit 1"') do (
    if not defined ENGINE_SLOT set "ENGINE_SLOT=%%E"
)

if not defined ENGINE_SLOT (
    set "FAIL_MESSAGE=No valid BAR recoil_* engine folder containing spring.exe was found under: %ENGINE_ROOT%"
    goto FAIL
)

set "DST_ENGINE=%ENGINE_ROOT%\%ENGINE_SLOT%"
set "STAGE_ENGINE=%ENGINE_ROOT%\%ENGINE_SLOT%.controller-stage-%STAMP%"
set "ENGINE_BACKUP=%BACKUP%\%ENGINE_SLOT%_stock_before_controller_install_%STAMP%"

if not exist "%DST_ENGINE%\spring.exe" (
    set "FAIL_MESSAGE=Detected BAR engine slot is missing spring.exe: %DST_ENGINE%\spring.exe"
    goto FAIL
)

where git >nul 2>nul
if errorlevel 1 (
    set "FAIL_MESSAGE=Git was not found in PATH. Install Git for Windows first."
    goto FAIL
)

where powershell >nul 2>nul
if errorlevel 1 (
    set "FAIL_MESSAGE=PowerShell was not found. This installer needs PowerShell to extract the ZIP."
    goto FAIL
)

echo BAR root:
echo "%BAR_ROOT%"
echo.
echo BAR data:
echo "%BAR_DATA%"
echo.
echo Detected engine slot:
echo "%ENGINE_SLOT%"
echo.
echo Current engine slot:
echo "%DST_ENGINE%"
echo.
echo Engine release ZIP:
echo "%ENGINE_URL%"
echo.
echo Controller widget release asset:
echo "%WIDGET_URL%"
echo.
echo BAR game branch:
echo %BAR_REPO%
echo %BAR_BRANCH%
echo.

REM ============================================================
REM Stop BAR/Recoil processes
REM ============================================================

echo ============================================================
echo Closing possible running BAR/Recoil processes
echo ============================================================
echo.

taskkill /IM spring.exe /F >nul 2>nul
taskkill /IM Beyond-All-Reason.exe /F >nul 2>nul
taskkill /IM pr-downloader.exe /F >nul 2>nul

REM ============================================================
REM Prepare temp/staging folders
REM ============================================================

echo ============================================================
echo Preparing temp and staging folders
echo ============================================================
echo.

rmdir /s /q "%WORK%" 2>nul

mkdir "%WORK%" 2>nul
mkdir "%ENGINE_EXTRACT%" 2>nul
mkdir "%BACKUP%" 2>nul
mkdir "%DST_GAMES%" 2>nul

if not exist "%WORK%" (
    set "FAIL_MESSAGE=Could not create temp folder: %WORK%"
    goto FAIL
)

if not exist "%BACKUP%" (
    set "FAIL_MESSAGE=Could not create backup folder: %BACKUP%"
    goto FAIL
)

REM Clean old staging folders from previous failed attempts only.
for /d %%D in ("%ENGINE_ROOT%\%ENGINE_SLOT%.controller-stage-*") do (
    echo Removing old engine staging folder: "%%~fD"
    rmdir /s /q "%%~fD" 2>nul
)

for /d %%D in ("%DST_GAMES%\BAR.sdd.controller-stage-*") do (
    echo Removing old BAR.sdd staging folder: "%%~fD"
    rmdir /s /q "%%~fD" 2>nul
)

for /d %%D in ("%DST_GAMES%\BYAR Chobby.sdd.controller-stage-*") do (
    echo Removing old BYAR Chobby staging folder: "%%~fD"
    rmdir /s /q "%%~fD" 2>nul
)

REM ============================================================
REM Get custom engine ZIP
REM ============================================================

echo ============================================================
echo Getting custom controller engine ZIP
echo ============================================================
echo.

if exist "%LOCAL_ENGINE_ARCHIVE%" (
    echo Found local engine ZIP next to installer:
    echo "%LOCAL_ENGINE_ARCHIVE%"
    echo Copying local ZIP instead of downloading...
    copy /Y "%LOCAL_ENGINE_ARCHIVE%" "%ENGINE_ARCHIVE%"
    if errorlevel 1 (
        set "FAIL_MESSAGE=Failed to copy local engine ZIP."
        goto FAIL
    )
) else (
    echo No local engine ZIP found next to installer.
    echo Downloading from GitHub Release...
    echo.
    echo URL:
    echo "%ENGINE_URL%"
    echo.
    echo Output:
    echo "%ENGINE_ARCHIVE%"
    echo.

    set "DOWNLOAD_OK=0"

    where curl.exe >nul 2>nul
    if not errorlevel 1 (
        echo Trying download with curl.exe...
        curl.exe -L --fail --retry 5 --retry-delay 3 --connect-timeout 30 --output "%ENGINE_ARCHIVE%" "%ENGINE_URL%"
        if not errorlevel 1 set "DOWNLOAD_OK=1"
    )

    if "!DOWNLOAD_OK!"=="0" (
        echo.
        echo curl.exe download did not complete. Trying PowerShell fallback...
        powershell -NoProfile -ExecutionPolicy Bypass -Command ^
          "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%ENGINE_URL%' -OutFile '%ENGINE_ARCHIVE%'"
        if not errorlevel 1 set "DOWNLOAD_OK=1"
    )

    if not "!DOWNLOAD_OK!"=="1" (
        set "FAIL_MESSAGE=Failed to download engine ZIP. Manual fallback: put %ENGINE_ASSET_NAME% next to this installer and run again."
        goto FAIL
    )
)

if not exist "%ENGINE_ARCHIVE%" (
    set "FAIL_MESSAGE=Engine ZIP was not found after download/copy: %ENGINE_ARCHIVE%"
    goto FAIL
)

for %%A in ("%ENGINE_ARCHIVE%") do set "ARCHIVE_SIZE=%%~zA"
if "%ARCHIVE_SIZE%"=="0" (
    set "FAIL_MESSAGE=Engine ZIP is 0 bytes: %ENGINE_ARCHIVE%"
    goto FAIL
)

echo Engine ZIP ready:
dir "%ENGINE_ARCHIVE%"

REM ============================================================
REM Extract and stage custom engine
REM ============================================================

echo.
echo ============================================================
echo Extracting and staging custom controller engine
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; Expand-Archive -Path '%ENGINE_ARCHIVE%' -DestinationPath '%ENGINE_EXTRACT%' -Force"

if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to extract engine ZIP."
    goto FAIL
)

set "SRC_ENGINE="
for /f "delims=" %%F in ('dir /s /b "%ENGINE_EXTRACT%\spring.exe" 2^>nul') do (
    if not defined SRC_ENGINE (
        if exist "%%~dpFspring-headless.exe" (
            if exist "%%~dpFspring-dedicated.exe" (
                if exist "%%~dpFunitsync.dll" (
                    if exist "%%~dpFSDL2.dll" (
                        if exist "%%~dpFbase" (
                            REM Use %%~dpF. to avoid a quoted robocopy source ending in a trailing backslash.
                            set "SRC_ENGINE=%%~dpF."
                        )
                    )
                )
            )
        )
    )
)

if not defined SRC_ENGINE (
    set "FAIL_MESSAGE=Could not find extracted engine folder containing spring.exe, spring-headless.exe, spring-dedicated.exe, unitsync.dll, SDL2.dll, and base\."
    goto FAIL
)

echo Extracted engine source:
echo "!SRC_ENGINE!"
echo.
echo Copying extracted custom engine to staging folder:
echo "%STAGE_ENGINE%"
echo.

mkdir "%STAGE_ENGINE%" 2>nul
robocopy "!SRC_ENGINE!" "%STAGE_ENGINE%" /E
if errorlevel 8 (
    set "FAIL_MESSAGE=Failed to copy custom engine to staging folder."
    goto FAIL
)

if not exist "%STAGE_ENGINE%\spring.exe" (
    set "FAIL_MESSAGE=Staged engine missing spring.exe."
    goto FAIL
)

if not exist "%STAGE_ENGINE%\spring-headless.exe" (
    set "FAIL_MESSAGE=Staged engine missing spring-headless.exe."
    goto FAIL
)

if not exist "%STAGE_ENGINE%\spring-dedicated.exe" (
    set "FAIL_MESSAGE=Staged engine missing spring-dedicated.exe."
    goto FAIL
)

if not exist "%STAGE_ENGINE%\unitsync.dll" (
    set "FAIL_MESSAGE=Staged engine missing unitsync.dll."
    goto FAIL
)

if not exist "%STAGE_ENGINE%\SDL2.dll" (
    set "FAIL_MESSAGE=Staged engine missing SDL2.dll."
    goto FAIL
)

if not exist "%STAGE_ENGINE%\base" (
    set "FAIL_MESSAGE=Staged engine missing base folder."
    goto FAIL
)

echo Staged engine verified successfully.

REM ============================================================
REM Stage BAR.sdd and BYAR Chobby.sdd BEFORE touching engine
REM ============================================================

echo.
echo ============================================================
echo Staging BAR.sdd controller-support branch
echo ============================================================
echo.

cd /d "%DST_GAMES%"

git -c core.longpaths=true clone --depth 1 --branch %BAR_BRANCH% --single-branch %BAR_REPO% "%STAGE_BAR%"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to clone BAR controller-support branch into staging folder."
    goto FAIL
)

if not exist "%STAGE_BAR%\modinfo.lua" (
    set "FAIL_MESSAGE=Staged BAR.sdd missing modinfo.lua."
    goto FAIL
)

if not exist "%STAGE_BAR%\common\constants.lua" (
    set "FAIL_MESSAGE=Staged BAR.sdd missing common\constants.lua."
    goto FAIL
)

if not exist "%STAGE_BAR%\luaui\Widgets\gui_controller_camera_test.lua" (
    set "FAIL_MESSAGE=Staged BAR.sdd missing gui_controller_camera_test.lua."
    goto FAIL
)

if not exist "%STAGE_BAR%\luaui\Widgets\gui_controller_bindings_ui.lua" (
    set "FAIL_MESSAGE=Staged BAR.sdd missing gui_controller_bindings_ui.lua."
    goto FAIL
)

echo.
echo ============================================================
echo Installing PR #2985 reviewed-API controller widget
echo ============================================================
echo.

if exist "%LOCAL_WIDGET%" (
    echo Found local widget next to installer:
    echo "%LOCAL_WIDGET%"
    echo Copying local widget asset...
    copy /Y "%LOCAL_WIDGET%" "%WIDGET_SOURCE%"
    if errorlevel 1 (
        set "FAIL_MESSAGE=Failed to copy local controller widget asset."
        goto FAIL
    )
) else (
    echo No local widget asset found next to installer.
    echo Downloading matching widget from BAR controller support v0.4.2 release...
    echo.
    echo URL:
    echo "%WIDGET_URL%"
    echo.
    echo Output:
    echo "%WIDGET_SOURCE%"
    echo.

    set "WIDGET_DOWNLOAD_OK=0"

    where curl.exe >nul 2>nul
    if not errorlevel 1 (
        echo Trying widget download with curl.exe...
        curl.exe -L --fail --retry 5 --retry-delay 3 --connect-timeout 30 --output "%WIDGET_SOURCE%" "%WIDGET_URL%"
        if not errorlevel 1 set "WIDGET_DOWNLOAD_OK=1"
    )

    if "!WIDGET_DOWNLOAD_OK!"=="0" (
        echo.
        echo curl.exe widget download did not complete. Trying PowerShell fallback...
        powershell -NoProfile -ExecutionPolicy Bypass -Command ^
          "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%WIDGET_URL%' -OutFile '%WIDGET_SOURCE%'"
        if not errorlevel 1 set "WIDGET_DOWNLOAD_OK=1"
    )

    if not "!WIDGET_DOWNLOAD_OK!"=="1" (
        set "FAIL_MESSAGE=Failed to download controller widget. Manual fallback: put %WIDGET_ASSET_NAME% next to this installer and run again."
        goto FAIL
    )
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $src='%WIDGET_SOURCE%'; $dst='%STAGE_BAR%\luaui\Widgets\gui_controller_camera_test.lua'; $utf8 = [System.Text.UTF8Encoding]::new($false, $true); $bytes = [System.IO.File]::ReadAllBytes($src); if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { throw 'Widget source has a UTF-8 BOM.' }; [void]$utf8.GetString($bytes); Copy-Item -LiteralPath $src -Destination $dst -Force; $copied = [System.IO.File]::ReadAllBytes($dst); if ($copied.Length -ge 3 -and $copied[0] -eq 0xEF -and $copied[1] -eq 0xBB -and $copied[2] -eq 0xBF) { throw 'Installed widget has a UTF-8 BOM.' }; [void]$utf8.GetString($copied); Write-Host 'Controller widget verified: UTF-8 without BOM.'"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to install or validate the reviewed-API controller widget."
    goto FAIL
)

findstr /n /i "Controller-support engine compatibility shim" "%STAGE_BAR%\common\constants.lua"
if errorlevel 1 (
    set "FAIL_MESSAGE=Staged BAR.sdd constants.lua does not contain controller compatibility shim."
    goto FAIL
)

echo.
echo ============================================================
echo Staging BYAR Chobby.sdd
echo ============================================================
echo.

git -c core.longpaths=true clone --depth 1 --recurse-submodules --shallow-submodules %CHOBBY_REPO% "%STAGE_CHOBBY%"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to clone BYAR Chobby.sdd into staging folder."
    goto FAIL
)

if not exist "%STAGE_CHOBBY%\modinfo.lua" (
    set "FAIL_MESSAGE=Staged BYAR Chobby.sdd missing modinfo.lua."
    goto FAIL
)

echo.
echo All staging checks passed. The stock engine has NOT been moved yet.

REM ============================================================
REM Backup current active install
REM ============================================================

echo.
echo ============================================================
echo Backing up current active install
echo ============================================================
echo.

echo Backing up current stock engine to:
echo "%ENGINE_BACKUP%"
robocopy "%DST_ENGINE%" "%ENGINE_BACKUP%" /E
if errorlevel 8 (
    set "FAIL_MESSAGE=Engine backup failed. Stock engine was not changed."
    goto FAIL
)

if exist "%DST_BAR%" (
    echo.
    echo Backing up existing BAR.sdd to:
    echo "%BAR_BACKUP%"
    robocopy "%DST_BAR%" "%BAR_BACKUP%" /E
    if errorlevel 8 (
        set "FAIL_MESSAGE=BAR.sdd backup failed. Stock engine was not changed."
        goto FAIL
    )
)

if exist "%DST_CHOBBY%" (
    echo.
    echo Backing up existing BYAR Chobby.sdd to:
    echo "%CHOBBY_BACKUP%"
    robocopy "%DST_CHOBBY%" "%CHOBBY_BACKUP%" /E
    if errorlevel 8 (
        set "FAIL_MESSAGE=BYAR Chobby.sdd backup failed. Stock engine was not changed."
        goto FAIL
    )
)

REM ============================================================
REM Install staged BAR.sdd and Chobby
REM ============================================================

echo.
echo ============================================================
echo Installing staged BAR.sdd and BYAR Chobby.sdd
echo ============================================================
echo.

if exist "%DST_BAR%" (
    rmdir /s /q "%DST_BAR%" 2>nul
    if exist "%DST_BAR%" (
        set "FAIL_MESSAGE=Could not remove old BAR.sdd. Stock engine was not changed."
        goto FAIL
    )
)

move "%STAGE_BAR%" "%DST_BAR%"
if errorlevel 1 (
    set "FAIL_MESSAGE=Could not move staged BAR.sdd into place. Stock engine was not changed."
    goto FAIL
)

if exist "%DST_CHOBBY%" (
    rmdir /s /q "%DST_CHOBBY%" 2>nul
    if exist "%DST_CHOBBY%" (
        set "FAIL_MESSAGE=Could not remove old BYAR Chobby.sdd. Stock engine was not changed."
        goto FAIL
    )
)

move "%STAGE_CHOBBY%" "%DST_CHOBBY%"
if errorlevel 1 (
    set "FAIL_MESSAGE=Could not move staged BYAR Chobby.sdd into place. Stock engine was not changed."
    goto FAIL
)

REM ============================================================
REM SAFE engine swap: move stock engine, then move staged engine.
REM ============================================================

echo.
echo ============================================================
echo SAFE engine swap
echo ============================================================
echo.

echo Moving current stock engine out of active slot:
echo "%DST_ENGINE%"
echo to:
echo "%ENGINE_BACKUP%_ACTIVE_MOVED"
echo.

if exist "%ENGINE_BACKUP%_ACTIVE_MOVED" (
    set "FAIL_MESSAGE=Active-moved engine backup already exists unexpectedly: %ENGINE_BACKUP%_ACTIVE_MOVED"
    goto FAIL
)

move "%DST_ENGINE%" "%ENGINE_BACKUP%_ACTIVE_MOVED"
if errorlevel 1 (
    set "FAIL_MESSAGE=Could not move active stock engine to backup. Engine was not replaced."
    goto FAIL
)

echo Moving staged custom engine into active engine slot:
echo "%STAGE_ENGINE%"
echo to:
echo "%DST_ENGINE%"
echo.

move "%STAGE_ENGINE%" "%DST_ENGINE%"
if errorlevel 1 (
    echo ERROR: Failed to move custom engine into active slot.
    echo Attempting to restore stock engine...
    if exist "%ENGINE_BACKUP%_ACTIVE_MOVED" (
        move "%ENGINE_BACKUP%_ACTIVE_MOVED" "%DST_ENGINE%"
    )
    set "FAIL_MESSAGE=Custom engine move failed. Attempted stock-engine restore."
    goto FAIL
)

if not exist "%DST_ENGINE%\spring.exe" (
    set "FAIL_MESSAGE=Active engine missing spring.exe after swap."
    goto FAIL
)

if not exist "%DST_ENGINE%\spring-headless.exe" (
    set "FAIL_MESSAGE=Active engine missing spring-headless.exe after swap."
    goto FAIL
)

if not exist "%DST_ENGINE%\spring-dedicated.exe" (
    set "FAIL_MESSAGE=Active engine missing spring-dedicated.exe after swap."
    goto FAIL
)

if not exist "%DST_ENGINE%\unitsync.dll" (
    set "FAIL_MESSAGE=Active engine missing unitsync.dll after swap."
    goto FAIL
)

if not exist "%DST_ENGINE%\SDL2.dll" (
    set "FAIL_MESSAGE=Active engine missing SDL2.dll after swap."
    goto FAIL
)

if not exist "%DST_ENGINE%\base" (
    set "FAIL_MESSAGE=Active engine missing base folder after swap."
    goto FAIL
)

echo Custom engine is now active.

REM ============================================================
REM Enable dev mode and clear stale state
REM ============================================================

echo.
echo ============================================================
echo Enabling dev mode and clearing cache/state
echo ============================================================
echo.

type nul > "%BAR_DATA%\devmode.txt"

REM Disable default Spring camera cardinal-direction locking.
REM This removes the 0/90/180/270-degree camera magnetization for both mouse/keyboard and controller rotation.
echo Setting CamSpringLockCardinalDirections = 0 in:
echo "%SPRING_SETTINGS%"
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $path='%SPRING_SETTINGS%'; $line='CamSpringLockCardinalDirections = 0'; if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType File -Path $path -Force | Out-Null }; $lines = @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue); $found = $false; $out = foreach ($l in $lines) { if ($l -match '^\s*CamSpringLockCardinalDirections\s*=') { $found = $true; $line } else { $l } }; if (-not $found) { $out += $line }; Set-Content -LiteralPath $path -Value $out -Encoding ASCII"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to set CamSpringLockCardinalDirections = 0 in springsettings.cfg."
    goto FAIL
)

findstr /n /i "CamSpringLockCardinalDirections" "%SPRING_SETTINGS%"

rmdir /s /q "%BAR_DATA%\cache" 2>nul
rmdir /s /q "%BAR_DATA%\fontcache" 2>nul
del /q "%BAR_DATA%\ArchiveCache*.lua" 2>nul
del /q "%BAR_DATA%\infolog.txt" 2>nul

if exist "%BAR_DATA%\LuaUI" ren "%BAR_DATA%\LuaUI" "LuaUI.controller-install-disabled-%STAMP%" 2>nul
if exist "%BAR_DATA%\LuaMenu" ren "%BAR_DATA%\LuaMenu" "LuaMenu.controller-install-disabled-%STAMP%" 2>nul
if exist "%BAR_DATA%\chobby_config.json" ren "%BAR_DATA%\chobby_config.json" "chobby_config.controller-install-disabled-%STAMP%.json" 2>nul

REM ============================================================
REM Final verification
REM ============================================================

echo.
echo ============================================================
echo Final verification
echo ============================================================
echo.

if not exist "%DST_ENGINE%\spring.exe" (
    set "FAIL_MESSAGE=Final verify failed: missing active spring.exe."
    goto FAIL
)

if not exist "%DST_BAR%\modinfo.lua" (
    set "FAIL_MESSAGE=Final verify failed: missing BAR.sdd modinfo.lua."
    goto FAIL
)

if not exist "%DST_BAR%\common\constants.lua" (
    set "FAIL_MESSAGE=Final verify failed: missing BAR.sdd constants.lua."
    goto FAIL
)

if not exist "%DST_BAR%\luaui\Widgets\gui_controller_camera_test.lua" (
    set "FAIL_MESSAGE=Final verify failed: missing controller widget."
    goto FAIL
)

if not exist "%DST_BAR%\luaui\Widgets\gui_controller_bindings_ui.lua" (
    set "FAIL_MESSAGE=Final verify failed: missing controller bindings UI widget."
    goto FAIL
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $path='%DST_BAR%\luaui\Widgets\gui_controller_camera_test.lua'; $utf8 = [System.Text.UTF8Encoding]::new($false, $true); $bytes = [System.IO.File]::ReadAllBytes($path); if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { throw 'Installed widget has a UTF-8 BOM.' }; [void]$utf8.GetString($bytes); Write-Host 'Final widget verify: UTF-8 without BOM.'"
if errorlevel 1 (
    set "FAIL_MESSAGE=Final verify failed: controller widget is not UTF-8 without BOM."
    goto FAIL
)

if not exist "%DST_CHOBBY%\modinfo.lua" (
    set "FAIL_MESSAGE=Final verify failed: missing BYAR Chobby.sdd modinfo.lua."
    goto FAIL
)

if not exist "%BAR_DATA%\devmode.txt" (
    set "FAIL_MESSAGE=Final verify failed: missing devmode.txt."
    goto FAIL
)

findstr /n /i "CamSpringLockCardinalDirections = 0" "%SPRING_SETTINGS%" >nul 2>nul
if errorlevel 1 (
    set "FAIL_MESSAGE=Final verify failed: CamSpringLockCardinalDirections = 0 was not found in springsettings.cfg."
    goto FAIL
)

cd /d "%DST_BAR%"

echo.
echo BAR.sdd branch:
git branch --show-current

echo.
echo Recent BAR.sdd commits:
git log --oneline -5

echo.
echo constants.lua shim check:
findstr /n /i "Controller-support engine compatibility shim" common\constants.lua
if errorlevel 1 (
    set "FAIL_MESSAGE=Final verify failed: constants.lua compatibility shim was not found."
    goto FAIL
)

echo.
echo Installed files:
dir "%DST_ENGINE%\spring.exe"
dir "%DST_BAR%\luaui\Widgets\gui_controller_camera_test.lua"
dir "%DST_BAR%\luaui\Widgets\gui_controller_bindings_ui.lua"
dir "%DST_CHOBBY%\modinfo.lua"
dir "%BAR_DATA%\devmode.txt"
echo.
echo Camera cardinal-lock setting:
findstr /n /i "CamSpringLockCardinalDirections" "%SPRING_SETTINGS%"

echo.
echo ============================================================
echo INSTALL COMPLETE
echo ============================================================
echo.
echo Next steps:
echo   1. Plug in Xbox controller by USB.
echo   2. Launch Beyond All Reason.
echo   3. Go to Settings ^> Developer.
echo   4. Set Singleplayer to: Beyond All Reason Dev.
echo   5. Click Skirmish and start a local match.
echo.
echo Verify after match loads:
echo findstr /i "Spring Engine Version ControllerInput Xbox constants.lua ButtonDown ButtonUp AxisMotion Fatal" "%BAR_DATA%\infolog.txt"
echo.
echo Healthy signs:
echo   Spring Engine Version includes controller-api-recoil-2025-06-24-compat
echo   Controller connected: Xbox ...
echo   No repeating ButtonDown/ButtonUp/AxisMotion spam during normal controller use
echo   Controller widget loaded without Lua errors
echo.
echo Smart X v0.4.2 calibration summary:
echo   Mex no-Move guard: only within ~55 elmos of a built mex
echo   Exact target priority: wreck/unit/feature over nearby mex spot
echo   Resurrect command ID corrected to 125
echo.
echo Optional Smart X Mouse Audit widget (disabled by default):
echo   /luaui enablewidget "Controller SmartX Mouse Audit"
echo   (Only needed when debugging Smart X targeting behavior)
echo.
echo Camera smoothing setting applied:
echo   CamSpringLockCardinalDirections = 0
echo.
echo Backup folder:
echo "%BACKUP%"
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
echo Stock engine should not have been deleted by this SAFE installer.
echo.
echo Active engine:
echo "%DST_ENGINE%"
echo.
echo Backup folder:
echo "%BACKUP%"
echo.
echo Work folder:
echo "%WORK%"
echo.
echo Full log:
echo "%INSTALL_LOG%"
echo.
exit /b 1
