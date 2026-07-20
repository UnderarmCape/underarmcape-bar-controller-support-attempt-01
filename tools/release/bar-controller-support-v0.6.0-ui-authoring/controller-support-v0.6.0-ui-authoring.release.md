# BAR Controller Support v0.6.0 — UI Authoring Suite

A complete controller UI customization and authoring milestone with a standalone companion—no custom engine required.

## Highlights

- Restored polished radial and Controller Groups/hot-slot presentations.
- Full modal Controller UI Authoring with mouse/keyboard input and gameplay-input blocking.
- Movable Bindings and UI Layout buttons; the full Controller Bindings window is unchanged.
- Shared live production previews for hints, radials, and hot slots.
- Original controller glyphs with corrected D-pad proportions.
- Clean shadowed glyph-and-text hints, no TAP labels, strong hold styles, optional glow, label backgrounds, wrapping, marquee, and ping-pong.
- Hot-slot customization, favorites, themes, presets, saved values, undo, recovery, and search.
- Developer shipping-default workflow, startup defaults synchronization, and update checking.
- Elevated-terrain placement correction, Build-First fresh-install default, and all v0.5.1 gameplay fixes retained.

## Installation

1. Download `BAR_Controller_Support_v0.6.0_Widget_Companion.zip`.
2. Extract it.
3. Run `BAR_Controller_Companion_Installer_v0.6.0.exe`.
4. Launch BAR from the normal patched Desktop or Start Menu shortcut.

SmartScreen may warn because the executables are unsigned. No custom Recoil engine is required.

Upgrading from v0.5.1 preserves valid controller bindings and personal UI settings. To restore the pre-install state, run `BAR_Controller_Companion_Restore_v0.6.0.exe`.

## Known limitations

- Executables are not code-signed.
- The .NET 5 single-file bundler does not produce byte-identical executables across independent publishes in this environment. The release executables were built once, smoke-tested, hash-frozen, and used unchanged for deterministic package staging.
- Mouse Mode has no appearance controls in this authoring release; existing gameplay behavior remains intact.
- Preview data is synthetic, but all preview drawing/layout uses the production renderer.

## Integrity

ZIP SHA-256: `__FINAL_ZIP_SHA256__`
