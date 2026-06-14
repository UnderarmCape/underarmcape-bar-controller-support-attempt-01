# BAR Controller Support v0.5.0 — Widget + Companion Release

This is the first easy-install Widget + Companion release of BAR Controller Support.

This release does **not** require a custom Recoil engine. It installs the Lua controller widgets and a local Windows companion bridge that sends controller state to BAR over localhost.

## What this release does

- Installs the BAR controller Lua widgets.
- Installs `BARControllerBridge.exe`.
- Installs `BARControllerLauncher.exe`.
- Patches the normal BAR Desktop and Start Menu shortcuts so the bridge starts first, then BAR launches normally.
- Enables the required controller widgets automatically:
  - Controller Camera Test
  - Controller Bindings UI
- Sets `CamSpringLockCardinalDirections = 0` to prevent 90-degree camera rotation snapping.
- Includes a Restore EXE to restore shortcuts/widgets if needed.
- Does not modify BAR.exe.
- Does not require a custom Recoil engine.

## Install

1. Download `BAR_Controller_Support_v0.5.0_Widget_Companion.zip`.
2. Extract the ZIP.
3. Run `BAR_Controller_Companion_Installer_v0.5.0.exe`.
4. Launch BAR from the normal Desktop or Start Menu shortcut.
5. Start a match. Controller support should work without opening F11.

## Restore / Uninstall

Run:

`BAR_Controller_Companion_Restore_v0.5.0.exe`

This restores patched BAR shortcuts and backed-up widget files where backups exist.

## Checksum

SHA256:

`584f20ad10afdfbb35ccab247b69f0173c72ea6a7388ba01c3597cd0cef7213e`

Checksum file:

`BAR_Controller_Support_v0.5.0_Widget_Companion.zip.sha256`

## Windows SmartScreen note

The included EXEs are currently unsigned, so Windows SmartScreen may show a warning on first launch.

## Known tracked issues

These are known controller gameplay issues and were deliberately not fixed in this release pass:

- Tactical radial is missing Area Mex for builders/constructors/commanders.
- With multiple units selected, hold X + drag path currently fires Fight instead of Move.
- With a T2 construction bot selected, using Smart X on an existing built T1 mex to upgrade it to T2 can crash `gui_controller_camera_test.lua`.

These are planned for the next gameplay bugfix pass.
