# BAR Controller Support v0.7.0 — Disassemble Mode & Streamlined Runtime

This is the recommended stable public release.

## Highlights

- Persistent Disassemble Mode with a one-second LB+RB charge and 20-second unused-mode timeout.
- Actual reclaim-capable unit capture, continuous validity checks, and a separate friendly target-marking set.
- RT+A adds or removes an individual friendly unit or structure without disturbing the rest of the live selection.
- Friendly unit and structure area marking, plus deterministic same-type area reclaim with modal A/X confirmation and B cancellation.
- LB+B cancels active reclaim targeting and stops only the captured reclaimers.
- LB+RB now coexists with the visible-selection filter radial; flicking before the charge completes opens the radial, and directional choices remain latched through neutral.
- Useful build-availability messages, metal/energy/health icons, corrected stat spacing, and obsolete internal footer hints removed.
- Controller UI Layout is removed from normal gameplay runtime. The lean runtime preserves the exact v0.6.1 hint appearance and Bindings button placement; the authoring widget remains available manually through F11.

## Installation

1. Download `BAR_Controller_Support_v0.7.0_Widget_Companion.zip` and its `.sha256` sidecar.
2. Verify and extract the ZIP.
3. Run `BAR_Controller_Companion_Installer_v0.7.0.exe`.
4. Launch BAR using the normal patched Desktop or Start Menu shortcut.

Windows SmartScreen may warn because the executables are unsigned. No custom Recoil engine is required.

## Upgrade

Upgrading from v0.6.1 preserves bindings, hint appearance, the Bindings button position, radial styles, themes, presets, profiles, favorites, and other personal settings. Controller UI Layout is disabled during normal gameplay but remains packaged as an optional F11 authoring widget.

## Integrity

SHA-256: `__FINAL_ZIP_SHA256__`
