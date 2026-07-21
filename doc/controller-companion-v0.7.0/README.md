# BAR Controller Support v0.7.0

Version 0.7.0 adds persistent friendly-unit Disassemble Mode and moves gameplay UI settings into a lean runtime independent of the optional authoring widget. It uses BAR's standard Recoil engine.

## Install

1. Download the v0.7.0 ZIP and `.sha256` sidecar.
2. Verify the sidecar, then extract the ZIP.
3. Run `BAR_Controller_Companion_Installer_v0.7.0.exe`.
4. Launch BAR through the patched Desktop or Start Menu shortcut.

The executables are unsigned, so Windows SmartScreen may warn.

## Upgrade and preservation

The installer supports public v0.6.1, v0.6.0, and v0.5.1 installations. It preserves bindings, cached defaults, launcher configuration, hint appearance, exact Bindings button coordinates, radial styles, colors, favorites, themes, presets, profiles, recovery drafts, and the complete saved Controller UI Layout authoring table. That table is copied to Controller UI Runtime only when runtime data does not already exist, so repeat installs are non-destructive.

Controller UI Layout is installed but set to widget order `0`. It no longer owns normal gameplay call-ins or shows a floating launcher. Enable it manually through BAR's F11 widget selector when authoring is needed.

## Restore and integrity

Run `BAR_Controller_Companion_Restore_v0.7.0.exe` to restore the recorded install transaction. The `.sha256` sidecar verifies the ZIP; `payload-sha256.json` verifies every extracted file.
