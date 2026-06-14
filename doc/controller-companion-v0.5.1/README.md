# BAR Controller Companion v0.5.1

BAR Controller Companion adds Xbox/XInput controller input to standard Beyond
All Reason without replacing BAR's Recoil engine. The companion bridge sends
controller state over localhost UDP, and the bundled LuaUI widgets consume it.

## Install

1. Extract `BAR_Controller_Support_v0.5.1_Widget_Companion.zip`.
2. Run `BAR_Controller_Companion_Installer_v0.5.1.exe`.
3. Read the completion summary, then close the installer.
4. Launch BAR from the normal Beyond-All-Reason Desktop or Start Menu shortcut.

The installer does not launch BAR. It copies the bundled LuaUI widgets, enables
`Controller Camera Test` and `Controller Bindings UI`, installs the bridge and
launcher, applies `CamSpringLockCardinalDirections = 0`, and patches existing
normal BAR shortcuts after creating backups.

## Gameplay Fixes

- Area Mex now appears in the Tactical radial for eligible mex-capable
  constructors and commanders, while remaining absent for other units.
- Hold X with multiple units now draws and issues a Move path instead of Fight.
- Smart X with a T2 construction bot on an existing T1 mex no longer crashes
  `gui_controller_camera_test.lua`.

These fixes passed live manual validation along with normal Smart X, build
menus, other radials, and the existing companion/shortcut workflow.

## Restore

Run `BAR_Controller_Companion_Restore_v0.5.1.exe` to restore recorded shortcut,
overwritten widget, and widget-config backups. Newly installed files are left
in place rather than deleted blindly.

The camera setting remains at `0` by default. To restore the recorded settings
file intentionally:

```powershell
.\BAR_Controller_Companion_Restore_v0.5.1.exe --restore-camera
```

## Optional Update Check

The bundled package is used by default and requires no internet. To check the
official repository for a newer compatible package:

```powershell
.\BAR_Controller_Companion_Installer_v0.5.1.exe --check-updates
```

Current `BAR_Controller_Support_v*_Widget_Companion.zip` assets are recognized,
with older `BAR_Controller_Companion_v*.zip` names retained for compatibility.

## Limitations

- Windows/XInput only.
- Controller index 0 only.
- Included executables are unsigned and may trigger Windows SmartScreen.
- The optional online update path is conservative and requires confirmation.
