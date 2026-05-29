@echo off
setlocal EnableExtensions EnableDelayedExpansion
title BAR Xbox Controller Support Widget Installer

echo ============================================================
echo BAR Xbox Controller Support v0.4.1 Widget Installer
echo ============================================================
echo.
echo This script will copy the two required controller LuaUI widgets
echo into your Beyond All Reason widgets folder.
echo.
echo [Note] This script does NOT require administrator privileges.
echo You can inspect this file in Notepad at any time to verify it.
echo.

REM 1. Define Target Widgets Directory
set "TARGET_DIR=%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets"

echo Target path:
echo "%TARGET_DIR%"
echo.

REM 2. Verify Target Directory Exists
if not exist "%TARGET_DIR%" (
    echo [ERROR] Target widgets folder was not found at the default location:
    echo "%TARGET_DIR%"
    echo.
    echo Please make sure Beyond All Reason is installed.
    echo If your game is installed in a custom directory, please copy the two
    echo widget Lua files manually to your custom BAR.sdd\luaui\Widgets\ folder.
    goto END
)

REM 3. Locate Widget Sources relative to this script
REM Script is in optional_installer/, so source is in ..\luaui\Widgets\
set "SRC_TEST_1=%~dp0..\luaui\Widgets\gui_controller_camera_test.lua"
set "SRC_BIND_1=%~dp0..\luaui\Widgets\gui_controller_bindings_ui.lua"

REM Fallback if run from root directory
set "SRC_TEST_2=%~dp0luaui\Widgets\gui_controller_camera_test.lua"
set "SRC_BIND_2=%~dp0luaui\Widgets\gui_controller_bindings_ui.lua"

set "SRC_TEST="
set "SRC_BIND="

if exist "%SRC_TEST_1%" (
    set "SRC_TEST=%SRC_TEST_1%"
    set "SRC_BIND=%SRC_BIND_1%"
) else if exist "%SRC_TEST_2%" (
    set "SRC_TEST=%SRC_TEST_2%"
    set "SRC_BIND=%SRC_BIND_2%"
)

if not defined SRC_TEST (
    echo [ERROR] Widget source files were not found in the package!
    echo Checked:
    echo   "%SRC_TEST_1%"
    echo   "%SRC_TEST_2%"
    echo.
    echo Please ensure you extracted the entire ZIP before running this installer.
    goto END
)

REM 4. Perform Copy
echo Copying widgets:
echo   Source: "%SRC_TEST%"
echo   Source: "%SRC_BIND%"
echo.

copy /Y "%SRC_TEST%" "%TARGET_DIR%\" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy gui_controller_camera_test.lua to target folder.
    goto END
)

copy /Y "%SRC_BIND%" "%TARGET_DIR%\" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy gui_controller_bindings_ui.lua to target folder.
    goto END
)

echo ============================================================
echo SUCCESS: Controller widgets copied successfully!
echo ============================================================
echo.
echo Next steps:
echo   1. Connect your Xbox controller.
echo   2. Launch Beyond All Reason.
echo   3. Press F11 in-game to verify "Controller Camera Test" and "Controller Bindings UI" widgets are enabled.
echo   4. Click the "Bindings" button in the top-right corner to select a preset.
echo.

:END
echo Press any key to exit this installer...
pause >nul
exit /b 0
