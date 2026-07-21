# BAR Controller Support v0.6.1

Version 0.6.1 is the public radial typography and color-authoring update for BAR Controller Support. It runs on the standard BAR/Recoil engine; no custom engine is required.

## Install

1. Download `BAR_Controller_Support_v0.6.1_Widget_Companion.zip` and its `.sha256` sidecar from the v0.6.1 GitHub release.
2. Verify the ZIP against the sidecar, then extract it.
3. Run `BAR_Controller_Companion_Installer_v0.6.1.exe`.
4. Launch BAR through the normal patched Desktop or Start Menu shortcut.

Windows SmartScreen may warn because these executables are unsigned.

## Upgrade and preservation

The installer upgrades v0.5.1 and v0.6.0 installations in place. Controller bindings, personal radial layouts, custom colors, favorite and recent colors, themes, presets, and profiles are preserved. Missing v0.6.1 role values come from shipping defaults; they do not overwrite valid personal values.

## Restore

Run `BAR_Controller_Companion_Restore_v0.6.1.exe` from the extracted package. The restore tool uses the install transaction and backup created by the installer.

## Integrity

The authoritative final ZIP SHA-256 is printed in the GitHub release notes and in `BAR_Controller_Support_v0.6.1_Widget_Companion.zip.sha256`. `payload-sha256.json` verifies every extracted payload file.
