@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "INSTALLER_NAME=BAR Controller Support v0.4.6 - AIO Clean Install"
set "ENGINE_SLOT=recoil_2025.06.24"
set "SELF_DIR=%~dp0"
if "%SELF_DIR:~-1%"=="\" set "SELF_DIR=%SELF_DIR:~0,-1%"
set "EXTRACTED_PAYLOAD_ROOT=%SELF_DIR%\payload"
set "PAYLOAD_ZIP_PATTERN=BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_*.zip"
set "PAYLOAD_ROOT="
set "PAYLOAD_ENGINE="
set "PAYLOAD_BAR="
set "PAYLOAD_LUA="
set "BAR_FOLDER="
set "BAR_ROOT=%LOCALAPPDATA%\Programs\Beyond-All-Reason"
set "BAR_DATA=%BAR_ROOT%\data"
set "DST_GAMES=%BAR_DATA%\games"
set "DST_BAR=%DST_GAMES%\BAR.sdd"
set "DST_ENGINE_ROOT=%BAR_DATA%\engine"
set "DST_ENGINE=%DST_ENGINE_ROOT%\%ENGINE_SLOT%"
set "SPRING_SETTINGS=%BAR_DATA%\springsettings.cfg"
set "DRY_RUN=0"
set "PAYLOAD_CHECK_ONLY=0"
set "FAIL_MESSAGE="

if /I "%~1"=="--dry-run" set "DRY_RUN=1"
if /I "%~1"=="--payload-check" set "PAYLOAD_CHECK_ONLY=1"
if /I "%~1"=="--help" goto HELP
if /I "%~1"=="/?" goto HELP

call :ResolveDesktop
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%I"
set "LOG_FILE=%DESKTOP%\BAR_Controller_v0.4.6_AIO_CLEAN_INSTALL_%STAMP%.log"
set "STAGE=%TEMP%\BAR_Controller_AIO_Clean_%STAMP%"
set "STAGE_PAYLOAD=%STAGE%\release_payload"
set "STAGE_ENGINE=%STAGE%\engine"
set "STAGE_BAR=%STAGE%\BAR.sdd"
set "BACKUP=%BAR_DATA%\controller-support-v046-aio-clean-backups\%STAMP%"

call :Log "============================================================"
call :Log "%INSTALLER_NAME%"
call :Log "============================================================"
call :Log "Installer folder: %SELF_DIR%"
call :Log "Log file: %LOG_FILE%"
call :Log "Keep this BAT, README, release notes, and both v0.4.6 PAYLOAD ZIPs in the same folder."
call :Log "Do not manually extract the PAYLOAD ZIPs."
call :Log ""

call :ResolvePayloadSource
if errorlevel 1 goto FAIL

call :ValidatePayload
if errorlevel 1 goto FAIL

call :StagePayload
if errorlevel 1 goto FAIL

if "%PAYLOAD_CHECK_ONLY%"=="1" (
    call :Log "Payload check passed. No live BAR install files were touched."
    goto SUCCESS
)

if not exist "%BAR_ROOT%" (
    set "FAIL_MESSAGE=BAR install folder was not found at %BAR_ROOT%. Install BAR normally and launch it once first."
    goto FAIL
)

if "%DRY_RUN%"=="1" (
    call :Log "Dry run passed. Payload extracted and validated."
    call :Log "Live BAR root that would be used: %BAR_ROOT%"
    call :Log "No running processes were closed and no live files were changed."
    goto SUCCESS
)

call :CloseRunningProcesses
if errorlevel 1 goto FAIL

call :PrepareLiveFolders
if errorlevel 1 goto FAIL

call :BackupLiveFolders
if errorlevel 1 goto FAIL

call :InstallStagedPayload
if errorlevel 1 goto FAIL

call :ApplySettings
if errorlevel 1 goto FAIL

call :FinalVerify
if errorlevel 1 goto FAIL

call :Log ""
call :Log "============================================================"
call :Log "Install complete."
call :Log "============================================================"
call :Log "No old backed-up BAR.sdd was installed."
call :Log "No local BYAR Chobby.sdd was installed."
call :Log "No Attempt 02 engine was installed."
call :Log ""
call :Log "Test now:"
call :Log "1. Launch BAR normally."
call :Log "2. Go to Settings ^> Developer."
call :Log "3. Singleplayer: Beyond All Reason Dev."
call :Log "4. Start a local match."
call :Log "5. Watch RTSS."
call :Log "6. Test Xbox controller input."
goto SUCCESS

:HELP
echo %INSTALLER_NAME%
echo.
echo Usage:
echo   %~nx0
echo   %~nx0 --payload-check
echo   %~nx0 --dry-run
echo.
echo --payload-check validates the local AIO payload and staging extraction only.
echo --dry-run validates the payload and BAR root but does not change live files.
exit /b 0

:ResolveDesktop
set "DESKTOP="
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"
if not defined DESKTOP set "DESKTOP=%USERPROFILE%\Desktop"
if not exist "%DESKTOP%" mkdir "%DESKTOP%" >nul 2>&1
if not exist "%DESKTOP%" set "DESKTOP=%SELF_DIR%"
exit /b 0

:Log
set "MSG=%~1"
echo(!MSG!
>> "%LOG_FILE%" echo(!MSG!
exit /b 0

:SetPayloadFolders
set "PAYLOAD_ENGINE=%PAYLOAD_ROOT%\engine"
set "PAYLOAD_BAR=%PAYLOAD_ROOT%\bar_sdd"
set "PAYLOAD_LUA=%PAYLOAD_ROOT%\lua_widgets"
exit /b 0

:ResolvePayloadSource
if exist "%EXTRACTED_PAYLOAD_ROOT%\engine\" if exist "%EXTRACTED_PAYLOAD_ROOT%\bar_sdd\" if exist "%EXTRACTED_PAYLOAD_ROOT%\lua_widgets\" (
    set "PAYLOAD_ROOT=%EXTRACTED_PAYLOAD_ROOT%"
    call :SetPayloadFolders
    call :Log "Using extracted payload folder beside BAT:"
    call :Log "%PAYLOAD_ROOT%"
    exit /b 0
)

set /a PAYLOAD_ARCHIVE_COUNT=0
for %%F in ("%SELF_DIR%\%PAYLOAD_ZIP_PATTERN%") do (
    if exist "%%~fF" set /a PAYLOAD_ARCHIVE_COUNT+=1
)

if "%PAYLOAD_ARCHIVE_COUNT%"=="0" (
    set "FAIL_MESSAGE=Missing payload ZIPs. Download all PAYLOAD ZIP files from the release and place them in the same folder as this BAT."
    exit /b 1
)

call :ValidatePayloadZipSet
if errorlevel 1 exit /b 1

call :Log "Extracting %PAYLOAD_ARCHIVE_COUNT% release PAYLOAD ZIP file(s) into temporary staging..."
mkdir "%STAGE_PAYLOAD%" >nul 2>&1
if not exist "%STAGE_PAYLOAD%\" (
    set "FAIL_MESSAGE=Could not create temporary payload staging folder."
    exit /b 1
)

for %%F in ("%SELF_DIR%\%PAYLOAD_ZIP_PATTERN%") do (
    if exist "%%~fF" (
        call :Log "Extracting %%~nxF"
        set "ZIP_PATH=%%~fF"
        set "DEST_PATH=%STAGE_PAYLOAD%"
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:ZIP_PATH -DestinationPath $env:DEST_PATH -Force"
        if errorlevel 1 (
            set "FAIL_MESSAGE=Failed to extract release PAYLOAD ZIP %%~nxF."
            exit /b 1
        )
    )
)

set "PAYLOAD_ROOT=%STAGE_PAYLOAD%\payload"
call :SetPayloadFolders

if not exist "%PAYLOAD_ROOT%\" (
    set "FAIL_MESSAGE=Extracted PAYLOAD ZIPs did not reconstruct a payload folder."
    exit /b 1
)
call :Log "Combined payload root:"
call :Log "%PAYLOAD_ROOT%"
exit /b 0

:ValidatePayloadZipSet
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $dir=$env:SELF_DIR; $pattern=$env:PAYLOAD_ZIP_PATTERN; $files=@(Get-ChildItem -LiteralPath $dir -Filter $pattern -File | Sort-Object Name); if ($files.Count -eq 0) { throw 'Missing payload ZIPs. Download all PAYLOAD ZIP files from the release and place them in the same folder as this BAT.' }; $info=@(); foreach ($f in $files) { if ($f.Name -notmatch 'PAYLOAD_(\d+)_OF_(\d+)\.zip$') { throw ('Invalid PAYLOAD ZIP name: ' + $f.Name) }; $info += [pscustomobject]@{ Index=[int]$matches[1]; Total=[int]$matches[2]; Name=$f.Name; Length=$f.Length } }; $totals=@($info.Total | Sort-Object -Unique); if ($totals.Count -ne 1) { throw 'PAYLOAD ZIP files disagree about the expected payload count.' }; $total=[int]$totals[0]; if ($files.Count -ne $total) { throw ('Partial PAYLOAD ZIP set: expected ' + $total + ' file(s), found ' + $files.Count + '. Download all PAYLOAD ZIP files from the release.') }; for ($i=1; $i -le $total; $i++) { if (-not @($info | Where-Object { $_.Index -eq $i }).Count) { throw ('Missing PAYLOAD ZIP ' + $i + ' of ' + $total + '. Download all PAYLOAD ZIP files from the release.') } }; foreach ($item in $info) { if ($item.Length -ge 2147483648) { throw ('PAYLOAD ZIP exceeds GitHub per-file size limit: ' + $item.Name) } }; Write-Host ('Found complete PAYLOAD ZIP set: ' + $files.Count + ' file(s).')"
if errorlevel 1 (
    set "FAIL_MESSAGE=Invalid or incomplete PAYLOAD ZIP set. Download all PAYLOAD ZIP files from the release and place them in the same folder as this BAT."
    exit /b 1
)

call :Log "Verifying payload ZIP SHA256 hashes..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $dir=$env:SELF_DIR; $p1=Join-Path $dir 'BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_1_OF_2.zip'; $p2=Join-Path $dir 'BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_2_OF_2.zip'; $h1=(Get-FileHash -Algorithm SHA256 -LiteralPath $p1).Hash; $h2=(Get-FileHash -Algorithm SHA256 -LiteralPath $p2).Hash; if ($h1 -ne 'A4B89A6BB336AED6AFA616B67F75E189B6673C4ACD6A5AEA7AE383DB7603A481') { throw ('Hash mismatch for PAYLOAD_1_OF_2.zip. Expected A4B89A6BB336AED6AFA616B67F75E189B6673C4ACD6A5AEA7AE383DB7603A481, got ' + $h1) }; if ($h2 -ne 'B98EB75CC714F25B31E18778A502AD3E41CFCF0AAD424A2053CB781636B9172B') { throw ('Hash mismatch for PAYLOAD_2_OF_2.zip. Expected B98EB75CC714F25B31E18778A502AD3E41CFCF0AAD424A2053CB781636B9172B, got ' + $h2) }; Write-Host 'Payload hashes verified successfully.'"
if errorlevel 1 (
    set "FAIL_MESSAGE=Payload ZIP file hash validation failed. Corrupted or modified files."
    exit /b 1
)
exit /b 0

:ValidatePayload
call :Log "Validating local AIO payload..."
if not exist "%PAYLOAD_ENGINE%\" (
    set "FAIL_MESSAGE=Missing payload folder: payload\engine"
    exit /b 1
)
if not exist "%PAYLOAD_BAR%\" (
    set "FAIL_MESSAGE=Missing payload folder: payload\bar_sdd"
    exit /b 1
)
if not exist "%PAYLOAD_LUA%\" (
    set "FAIL_MESSAGE=Missing payload folder: payload\lua_widgets"
    exit /b 1
)

set /a ENGINE_ZIP_COUNT=0
set "ENGINE_ZIP="
for %%F in ("%PAYLOAD_ENGINE%\*.zip") do (
    if exist "%%~fF" (
        set /a ENGINE_ZIP_COUNT+=1
        set "ENGINE_ZIP=%%~fF"
    )
)
if not "%ENGINE_ZIP_COUNT%"=="1" (
    set "FAIL_MESSAGE=Expected exactly one engine ZIP in payload\engine, found %ENGINE_ZIP_COUNT%."
    exit /b 1
)

set /a BAR_ZIP_COUNT=0
set "BAR_ZIP="
set "BAR_FOLDER="
for %%F in ("%PAYLOAD_BAR%\*.zip") do (
    if exist "%%~fF" (
        set /a BAR_ZIP_COUNT+=1
        set "BAR_ZIP=%%~fF"
    )
)
if "%BAR_ZIP_COUNT%"=="0" (
    if exist "%PAYLOAD_BAR%\BAR.sdd\modinfo.lua" if exist "%PAYLOAD_BAR%\BAR.sdd\luaui\" set "BAR_FOLDER=%PAYLOAD_BAR%\BAR.sdd"
    if not defined BAR_FOLDER if exist "%PAYLOAD_BAR%\modinfo.lua" if exist "%PAYLOAD_BAR%\luaui\" set "BAR_FOLDER=%PAYLOAD_BAR%"
)
if "%BAR_ZIP_COUNT%"=="0" if not defined BAR_FOLDER (
    set "FAIL_MESSAGE=Expected one BAR.sdd ZIP or a reconstructed BAR.sdd folder in payload\bar_sdd."
    exit /b 1
)
if %BAR_ZIP_COUNT% GTR 1 (
    set "FAIL_MESSAGE=Expected at most one BAR.sdd ZIP in payload\bar_sdd, found %BAR_ZIP_COUNT%."
    exit /b 1
)

set /a LUA_COUNT=0
for %%F in ("%PAYLOAD_LUA%\*.lua") do (
    if exist "%%~fF" set /a LUA_COUNT+=1
)
if "%LUA_COUNT%"=="0" (
    set "FAIL_MESSAGE=Expected at least one Lua widget in payload\lua_widgets."
    exit /b 1
)
for %%F in ("cmd_area_mex.lua" "gui_controller_bindings_ui.lua" "gui_controller_camera_test.lua" "gui_controller_smartx_mouse_audit.lua" "gui_pregameui.lua") do (
    if not exist "%PAYLOAD_LUA%\%%~F" (
        set "FAIL_MESSAGE=Missing required v0.4.6 Lua widget: payload\lua_widgets\%%~F"
        exit /b 1
    )
)

call :Log "Engine payload ZIP: %ENGINE_ZIP%"
if defined BAR_ZIP call :Log "BAR.sdd payload ZIP: %BAR_ZIP%"
if defined BAR_FOLDER call :Log "BAR.sdd payload folder: %BAR_FOLDER%"
call :Log "Lua widget count: %LUA_COUNT%"
exit /b 0

:StagePayload
call :Log "Staging payload under %STAGE% ..."
if exist "%STAGE_ENGINE%" rmdir /s /q "%STAGE_ENGINE%" >nul 2>&1
if exist "%STAGE_BAR%" rmdir /s /q "%STAGE_BAR%" >nul 2>&1
mkdir "%STAGE_ENGINE%" >nul 2>&1
mkdir "%STAGE_BAR%" >nul 2>&1
if not exist "%STAGE_ENGINE%\" (
    set "FAIL_MESSAGE=Could not create staging engine folder."
    exit /b 1
)
if not exist "%STAGE_BAR%\" (
    set "FAIL_MESSAGE=Could not create staging BAR.sdd folder."
    exit /b 1
)

call :ExpandZip "%ENGINE_ZIP%" "%STAGE_ENGINE%"
if errorlevel 1 exit /b 1
call :FlattenEngine
if errorlevel 1 exit /b 1
if not exist "%STAGE_ENGINE%\spring.exe" (
    set "FAIL_MESSAGE=Engine extraction did not contain spring.exe."
    exit /b 1
)

if defined BAR_ZIP (
    call :ExpandZip "%BAR_ZIP%" "%STAGE_BAR%"
    if errorlevel 1 exit /b 1
    call :FlattenBar
    if errorlevel 1 exit /b 1
) else (
    call :CopyBarFolderToStage
    if errorlevel 1 exit /b 1
)
if not exist "%STAGE_BAR%\modinfo.lua" (
    set "FAIL_MESSAGE=BAR.sdd extraction did not contain modinfo.lua."
    exit /b 1
)
if not exist "%STAGE_BAR%\luaui\" (
    set "FAIL_MESSAGE=BAR.sdd extraction did not contain luaui."
    exit /b 1
)

mkdir "%STAGE_BAR%\luaui\Widgets" >nul 2>&1
for %%F in ("%PAYLOAD_LUA%\*.lua") do (
    if exist "%%~fF" (
        copy /y "%%~fF" "%STAGE_BAR%\luaui\Widgets\" >nul
        if errorlevel 1 (
            set "FAIL_MESSAGE=Failed to copy Lua widget %%~nxF into staged BAR.sdd."
            exit /b 1
        )
    )
)

for %%F in ("%PAYLOAD_LUA%\*.lua") do (
    if exist "%%~fF" (
        if not exist "%STAGE_BAR%\luaui\Widgets\%%~nxF" (
            set "FAIL_MESSAGE=Staged BAR.sdd is missing copied Lua widget %%~nxF."
            exit /b 1
        )
    )
)

call :Log "Payload staging and verification passed."
exit /b 0

:CopyBarFolderToStage
if not defined BAR_FOLDER (
    set "FAIL_MESSAGE=BAR.sdd folder payload was not defined."
    exit /b 1
)
set "SRC_BAR_FOLDER=%BAR_FOLDER%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Get-ChildItem -LiteralPath $env:SRC_BAR_FOLDER -Force | Copy-Item -Destination $env:STAGE_BAR -Recurse -Force"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to copy reconstructed BAR.sdd folder into staging."
    exit /b 1
)
exit /b 0

:ExpandZip
set "ZIP_TO_EXPAND=%~1"
set "ZIP_DEST=%~2"
set "ZIP_PATH=%ZIP_TO_EXPAND%"
set "DEST_PATH=%ZIP_DEST%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:ZIP_PATH -DestinationPath $env:DEST_PATH -Force"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to extract ZIP: %ZIP_TO_EXPAND%"
    exit /b 1
)
exit /b 0

:FlattenEngine
if exist "%STAGE_ENGINE%\spring.exe" exit /b 0
set /a NESTED_ENGINE_COUNT=0
set "NESTED_ENGINE="
for /d %%D in ("%STAGE_ENGINE%\*") do (
    if exist "%%~fD\spring.exe" (
        set /a NESTED_ENGINE_COUNT+=1
        set "NESTED_ENGINE=%%~fD"
    )
)
if not "%NESTED_ENGINE_COUNT%"=="1" (
    set "FAIL_MESSAGE=Engine ZIP must contain spring.exe at the root or in exactly one nested top-level folder."
    exit /b 1
)
call :MoveContentsUp "%NESTED_ENGINE%" "%STAGE_ENGINE%"
exit /b %ERRORLEVEL%

:FlattenBar
if exist "%STAGE_BAR%\modinfo.lua" if exist "%STAGE_BAR%\luaui\" exit /b 0
set /a NESTED_BAR_COUNT=0
set "NESTED_BAR="
for /d %%D in ("%STAGE_BAR%\*") do (
    if exist "%%~fD\modinfo.lua" if exist "%%~fD\luaui\" (
        set /a NESTED_BAR_COUNT+=1
        set "NESTED_BAR=%%~fD"
    )
)
if not "%NESTED_BAR_COUNT%"=="1" (
    set "FAIL_MESSAGE=BAR.sdd ZIP must contain modinfo.lua and luaui at the root or in exactly one nested top-level folder."
    exit /b 1
)
call :MoveContentsUp "%NESTED_BAR%" "%STAGE_BAR%"
exit /b %ERRORLEVEL%

:MoveContentsUp
set "MOVE_SRC=%~1"
set "MOVE_DST=%~2"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $src=$env:MOVE_SRC; $dst=$env:MOVE_DST; Get-ChildItem -LiteralPath $src -Force | Move-Item -Destination $dst -Force; Remove-Item -LiteralPath $src -Force"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to flatten nested ZIP folder."
    exit /b 1
)
exit /b 0

:CloseRunningProcesses
call :Log "Closing BAR-related processes if they are running..."
for %%P in ("Beyond-All-Reason.exe" "spring.exe" "pr-downloader.exe") do (
    taskkill /IM %%~P /T /F >nul 2>&1
)
exit /b 0

:PrepareLiveFolders
mkdir "%BAR_DATA%" >nul 2>&1
mkdir "%DST_GAMES%" >nul 2>&1
mkdir "%DST_ENGINE_ROOT%" >nul 2>&1
mkdir "%BACKUP%" >nul 2>&1
if not exist "%DST_GAMES%\" (
    set "FAIL_MESSAGE=Could not create BAR games folder: %DST_GAMES%"
    exit /b 1
)
if not exist "%DST_ENGINE_ROOT%\" (
    set "FAIL_MESSAGE=Could not create BAR engine folder: %DST_ENGINE_ROOT%"
    exit /b 1
)
if not exist "%BACKUP%\" (
    set "FAIL_MESSAGE=Could not create backup folder: %BACKUP%"
    exit /b 1
)
exit /b 0

:BackupLiveFolders
call :Log "Backing up existing live folders before replacement..."
if exist "%DST_BAR%\" (
    call :MoveDir "%DST_BAR%" "%BACKUP%\BAR.sdd"
    if errorlevel 1 exit /b 1
)
if exist "%DST_ENGINE%\" (
    call :MoveDir "%DST_ENGINE%" "%BACKUP%\%ENGINE_SLOT%"
    if errorlevel 1 exit /b 1
)
for /d %%D in ("%DST_GAMES%\BYAR Chobby.sdd" "%DST_GAMES%\BYAR-Chobby.sdd") do (
    if exist "%%~fD" (
        call :MoveDir "%%~fD" "%BACKUP%\%%~nD_disabled"
        if errorlevel 1 exit /b 1
    )
)
exit /b 0

:MoveDir
set "MOVE_FROM=%~1"
set "MOVE_TO=%~2"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Move-Item -LiteralPath $env:MOVE_FROM -Destination $env:MOVE_TO -Force"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to move %MOVE_FROM% to %MOVE_TO%."
    exit /b 1
)
exit /b 0

:InstallStagedPayload
call :Log "Installing staged BAR.sdd and engine..."
mkdir "%DST_BAR%" >nul 2>&1
mkdir "%DST_ENGINE%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Get-ChildItem -LiteralPath $env:STAGE_BAR -Force | Copy-Item -Destination $env:DST_BAR -Recurse -Force; Get-ChildItem -LiteralPath $env:STAGE_ENGINE -Force | Copy-Item -Destination $env:DST_ENGINE -Recurse -Force"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to copy staged payload into live BAR install."
    exit /b 1
)
exit /b 0

:ApplySettings
call :Log "Creating/updating devmode.txt..."
echo devmode enabled by BAR Controller Support v0.4.6 AIO Clean Install> "%BAR_DATA%\devmode.txt"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to create devmode.txt."
    exit /b 1
)

call :Log "Setting CamSpringLockCardinalDirections = 0 in %SPRING_SETTINGS% ..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $path=$env:SPRING_SETTINGS; $line='CamSpringLockCardinalDirections = 0'; if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType File -Path $path -Force | Out-Null }; $lines=@(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue); $found=$false; $out=foreach ($l in $lines) { if ($l -match '^\s*CamSpringLockCardinalDirections\s*=') { $found=$true; $line } else { $l } }; if (-not $found) { $out += $line }; Set-Content -LiteralPath $path -Value $out -Encoding ASCII"
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to set CamSpringLockCardinalDirections = 0."
    exit /b 1
)

rmdir /s /q "%BAR_DATA%\cache" >nul 2>&1
rmdir /s /q "%BAR_DATA%\fontcache" >nul 2>&1
del /q "%BAR_DATA%\ArchiveCache*.lua" >nul 2>&1
del /q "%BAR_DATA%\infolog.txt" >nul 2>&1
exit /b 0

:FinalVerify
call :Log "Running final verification..."
if not exist "%DST_BAR%\modinfo.lua" (
    set "FAIL_MESSAGE=Final verify failed: missing data\games\BAR.sdd\modinfo.lua."
    exit /b 1
)
if not exist "%DST_BAR%\luaui\Widgets\" (
    set "FAIL_MESSAGE=Final verify failed: missing BAR.sdd\luaui\Widgets."
    exit /b 1
)
for %%F in ("%PAYLOAD_LUA%\*.lua") do (
    if exist "%%~fF" (
        if not exist "%DST_BAR%\luaui\Widgets\%%~nxF" (
            set "FAIL_MESSAGE=Final verify failed: missing copied Lua widget %%~nxF."
            exit /b 1
        )
    )
)
for %%F in ("cmd_area_mex.lua" "gui_controller_bindings_ui.lua" "gui_controller_camera_test.lua" "gui_controller_smartx_mouse_audit.lua" "gui_pregameui.lua") do (
    if not exist "%DST_BAR%\luaui\Widgets\%%~F" (
        set "FAIL_MESSAGE=Final verify failed: missing required v0.4.6 Lua widget %%~F."
        exit /b 1
    )
)
if not exist "%DST_ENGINE%\spring.exe" (
    set "FAIL_MESSAGE=Final verify failed: missing data\engine\%ENGINE_SLOT%\spring.exe."
    exit /b 1
)
if exist "%DST_GAMES%\BYAR Chobby.sdd\" (
    set "FAIL_MESSAGE=Final verify failed: data\games\BYAR Chobby.sdd is still active."
    exit /b 1
)
if exist "%DST_GAMES%\BYAR-Chobby.sdd\" (
    set "FAIL_MESSAGE=Final verify failed: data\games\BYAR-Chobby.sdd is still active."
    exit /b 1
)
if not exist "%BAR_DATA%\devmode.txt" (
    set "FAIL_MESSAGE=Final verify failed: missing data\devmode.txt."
    exit /b 1
)
exit /b 0

:SUCCESS
if exist "%STAGE%" rmdir /s /q "%STAGE%" >nul 2>&1
call :Log ""
call :Log "Success."
exit /b 0

:FAIL
echo.
if not defined FAIL_MESSAGE set "FAIL_MESSAGE=Installer failed."
call :Log "ERROR: %FAIL_MESSAGE%"
call :Log "No success was claimed. Review the log above."
if exist "%STAGE%" call :Log "Staging folder left for inspection: %STAGE%"
exit /b 1
