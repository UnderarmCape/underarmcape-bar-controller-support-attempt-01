# BAR Controller Support v0.6.0

BAR Controller Support v0.6.0 is a complete controller UI customization and authoring milestone with a standalone Windows companion. It uses normal BAR and does not require a custom Recoil engine.

## Install

1. Extract `BAR_Controller_Support_v0.6.0_Widget_Companion.zip`.
2. Run `BAR_Controller_Companion_Installer_v0.6.0.exe`.
3. Launch BAR from the normal patched Desktop or Start Menu shortcut.
4. Windows SmartScreen may warn because the executable is currently unsigned.

The installer enables Controller Camera Test, Controller Bindings UI, and Controller UI Layout; installs the shared renderer/glyph/default payload; installs the bridge and launcher; preserves the original BAR shortcut target; and sets `CamSpringLockCardinalDirections = 0`.

Quick-tap the live tactical modifier (LB by default) to select visible Combat units. Hold it for 0.20 seconds for tactical chords without changing selection on release. Hold the modifier and LT to choose Combat, Builders, Air, or Last Selected with the left stick; release LT to confirm or press the bound cancel action to close safely.

Upgrades from v0.5.1 preserve valid controller bindings, personal UI settings, favorites, themes, profiles, presets, saved values, recovery drafts, launcher configuration, shortcuts, unrelated widgets, and existing backups.

## Restore

Run `BAR_Controller_Companion_Restore_v0.6.0.exe`. By default it restores recorded shortcuts, widgets, Include modules, glyph/default payloads, and widget configuration while leaving the recommended camera setting at zero. Add `--restore-camera` from a command prompt only when you explicitly want the original camera settings file restored.

## Integrity

Verify the ZIP with the adjacent `BAR_Controller_Support_v0.6.0_Widget_Companion.zip.sha256` file. `payload-sha256.json` records the size and SHA-256 of every payload file inside the extracted package.
