# BAR Controller Support v0.5.1 — Widget + Companion Gameplay Fixes

This release updates the Widget + Companion package with gameplay fixes on top
of v0.5.0.

This package still does **not** require a custom Recoil engine. It installs the
Lua controller widgets and a local Windows companion bridge that sends
controller state to BAR over localhost.

## Fixes in v0.5.1

- Fixed Tactical radial Area Mex visibility for eligible
  builders/constructors/commanders.
- Fixed Hold X + multi-unit drag path issuing Fight instead of Move.
- Fixed Smart X with a T2 construction bot on an existing T1 mex crashing
  `gui_controller_camera_test.lua`.

## What the package includes

- BAR controller Lua widgets.
- `BARControllerBridge.exe`.
- `BARControllerLauncher.exe`.
- EXE installer.
- EXE restore tool.
- Shortcut patching so the normal BAR Desktop and Start Menu shortcuts start
  the bridge first, then launch BAR.
- Auto-enabling of required controller widgets:
  - Controller Camera Test
  - Controller Bindings UI
- `CamSpringLockCardinalDirections = 0` enforcement to prevent 90-degree camera
  rotation snapping.
- Restore support for patched shortcuts/widgets.
- No BAR.exe modification.
- No custom Recoil engine requirement.

## Install

1. Download `BAR_Controller_Support_v0.5.1_Widget_Companion.zip`.
2. Extract the ZIP.
3. Run `BAR_Controller_Companion_Installer_v0.5.1.exe`.
4. Launch BAR from the normal Desktop or Start Menu shortcut.
5. Start a match. Controller support should work without opening F11.

## Restore / Uninstall

Run:

`BAR_Controller_Companion_Restore_v0.5.1.exe`

This restores patched BAR shortcuts and backed-up widget files where backups
exist.

## Checksum

SHA256:

`4ef74e85ce729d1bcd89681dedb02787b163a0f8c472fa50fa047aa848dcf3d3`

Checksum file:

`BAR_Controller_Support_v0.5.1_Widget_Companion.zip.sha256`

## Windows SmartScreen note

The included EXEs are currently unsigned, so Windows SmartScreen may show a
warning on first launch.

## Notes

v0.5.1 is a gameplay-fix release based on the v0.5.0 Widget + Companion
release.
