# BAR Controller Support v0.6.0 — UI Authoring Suite

A complete controller UI customization and authoring milestone with a standalone companion—no custom engine required.

## Highlights

- Restored polished Build, Factory, Tactical, and Selection radial presentation.
- Restored Controller Groups/hot-slot visual hierarchy and production behavior.
- Full modal Controller UI Authoring editor with mouse and keyboard input, gameplay-input blocking, search, favorites, themes, presets, saved values, undo, and recovery.
- Movable Bindings and UI Layout launchers without changing the full Controller Bindings window.
- Live production previews for hints, radials, and hot slots through the same shared renderers used in game.
- Original controller glyph atlas with corrected square D-pad destination geometry.
- Clean glyph-and-text hint defaults: no chip fill, no giant panel, readable glyph/text shadows, and no TAP labels.
- Two hold treatments: bold configurable HOLD and an outlined hold-glyph treatment.
- Optional independent text/glyph glow and per-label text backgrounds.
- Reliable Wrap, Clip, Marquee, and Ping Pong long-text modes.
- Unit hot-slot orientation, grid, dimensions, count, role, theme, scrolling, and auto-collapse controls.
- Developer shipping-default workflow, startup defaults synchronization, downgrade protection, and update checking.
- Correct elevated-terrain build placement and Build-First Commander fresh-install preset.
- Retains v0.5.1 Area Mex, Hold-X Move path, T2 mex-upgrade, and Smart X fixes plus camera, Mouse Mode, and pregame controls.

## Installation and upgrade

Download and extract the v0.6.0 ZIP, run `BAR_Controller_Companion_Installer_v0.6.0.exe`, and launch BAR from the normal patched shortcut. SmartScreen may warn because the executables are unsigned. No custom Recoil engine is installed or required.

Upgrading from v0.5.1 preserves valid bindings and personal controller UI state. Restore with `BAR_Controller_Companion_Restore_v0.6.0.exe`.

## Known limitations

- Executables are not code-signed.
- Mouse Mode has no appearance properties in the v0.6.0 authoring editor; its existing gameplay behavior and bindings remain available.
- Preview data for production components is synthetic, while layout/drawing is the same production renderer.

## Integrity

Use the published `.sha256` sidecar for the final ZIP. The extracted package also contains `payload-sha256.json` for every internal payload.

