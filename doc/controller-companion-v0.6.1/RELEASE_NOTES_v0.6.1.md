# BAR Controller Support v0.6.1 — Radial Typography & Color Controls

A public radial typography and color-authoring update for BAR Controller Support.

## Highlights

- Independent category-label, center-title, and center-description typography.
- Independent metal and energy cost fonts, colors, icon sizes, and spacing.
- Readable yellow shipped energy-cost default and a distinct metal color.
- Role-specific metadata, footer, page, slot-number, unavailable, and selected-state styling.
- Global radial styling with explicit Build, Factory, Tactical, Selection, and Visible Selection Filter overrides.
- Compact HSV/alpha sliders, exact value fields, 20 clickable named swatches, copy/paste, favorite colors, and recent colors.
- Production-renderer previews for economy, combat, queue, expensive-unit, tactical, selection, visible-filter, long-description, resource-color, and inheritance contexts.
- Restored polished radial appearance and every v0.6.0 controller/UI correction.
- Stabilized contextual hints, corrected LB tactical layer, LB+LT visible-selection filtering, Combat default, and Last Selected restoration.

## Installation

1. Download `BAR_Controller_Support_v0.6.1_Widget_Companion.zip` and its `.sha256` sidecar.
2. Verify the checksum and extract the ZIP.
3. Run `BAR_Controller_Companion_Installer_v0.6.1.exe`.
4. Launch BAR through the normally patched Desktop or Start Menu shortcut.

Windows SmartScreen may warn because the executables are unsigned. The package uses BAR's standard Recoil engine and does not install or require a custom engine.

## Upgrade

The v0.6.1 installer preserves bindings, personal layouts, colors, favorites, themes, presets, and profiles. The legacy `fontScale` remains a multiplier over all semantic radial roles, so an existing accessibility/font preference keeps its effect.

## Restore and integrity

Use `BAR_Controller_Companion_Restore_v0.6.1.exe` to roll back the installed transaction. Verify the public ZIP with the release `.sha256` asset and verify extracted files with `payload-sha256.json`.
