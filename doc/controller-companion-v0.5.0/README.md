# BAR Controller Companion v0.5.0

BAR Controller Companion adds Xbox/XInput controller input to standard Beyond
All Reason without replacing BAR's Recoil engine. The companion bridge sends
controller state over localhost UDP, and the bundled LuaUI widgets consume it.

## Install

1. Extract `BAR_Controller_Support_v0.5.0_Widget_Companion.zip`.
2. Run `BAR_Controller_Companion_Installer_v0.5.0.exe`.
3. Read the completion summary, then close the installer.
4. Launch BAR from the normal Beyond-All-Reason Desktop or Start Menu shortcut.

The installer does not launch BAR. It:

- copies the six bundled LuaUI widgets into BAR's user widget directory;
- enables exactly `Controller Camera Test` and `Controller Bindings UI`;
- installs `BARControllerBridge.exe` and `BARControllerLauncher.exe`;
- sets `CamSpringLockCardinalDirections = 0`;
- backs up files it overwrites and records install state;
- backs up and patches existing normal BAR shortcuts.

If the camera setting changed, fully restart BAR. Reloading LuaUI is not enough.
After installation, controller support should work without opening F11.

The launcher starts the bridge minimized when needed, reuses an existing bridge
process, launches the original BAR target with its original arguments and
working directory, then exits. It does not modify `Beyond-All-Reason.exe` and
does not add Windows startup behavior.

## Restore

Run `BAR_Controller_Companion_Restore_v0.5.0.exe` to restore recorded shortcut,
overwritten widget, and widget-config backups. Newly installed files are left in
place rather than deleted blindly.

The camera setting remains at `0` by default. Advanced users can intentionally
restore the recorded pre-install settings file from a console:

```powershell
.\BAR_Controller_Companion_Restore_v0.5.0.exe --restore-camera
```

Restart BAR after restoring the camera settings backup.

## Optional Update Check

The bundled package is always used by default and installation requires no
internet. An optional conservative update check is available:

```powershell
.\BAR_Controller_Companion_Installer_v0.5.0.exe --check-updates
```

Only a newer `BAR_Controller_Support_v*_Widget_Companion.zip` release asset
from the official repository is considered under the current naming scheme.
Older internal asset names remain accepted for backward compatibility.
Downloading requires an explicit Yes response, and the downloaded manifest and
expected package files must validate. Failure falls back to the bundled package.

## Manual Bridge Use

The bridge normally prints only startup information and controller state
changes:

```powershell
.\companion\BARControllerBridge.exe
```

Use `--verbose` to add packet-rate diagnostics. Stop it with Ctrl+C. Only one
bridge instance runs at a time.

## PowerShell Tools

The legacy scripts under `tools\dev-scripts` remain as development and
troubleshooting references. Normal users should use the installer and restore
executables.

## Known Gameplay Issues

These tracked gameplay bugs are not fixed in v0.5.0:

- Area Mex is missing from the tactical radial for builders and commanders.
- Hold X plus drag with multiple units selected sends Fight instead of Move.
- Smart X with a T2 construction bot on a completed T1 mex can crash
  `gui_controller_camera_test.lua`.

## Limitations

- Windows/XInput only.
- Controller index 0 only.
- XInput does not expose the Guide button.
- No controller vibration/output.
