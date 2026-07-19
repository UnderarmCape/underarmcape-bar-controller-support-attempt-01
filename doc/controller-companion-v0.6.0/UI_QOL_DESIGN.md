# Controller UI/QOL v0.6.0 design

## Ownership

`gui_controller_ui_layout.lua` is the sole persistent owner of controller UI layout settings. It publishes `WG.ControllerUISettings` with validated getters/setters, effective resolution scale, component reset, reset-all, component bounds, editor control, and legacy launcher migration. Schema version 2 uses a 1920×1080 reference resolution.

`gui_controller_camera_test.lua` remains the gameplay/binding owner. It publishes live binding, preset, binding-revision, context-snapshot, shortcut, and layout-editor-blocking APIs through `WG.BARControllerSupport`.

`gui_controller_bindings_ui.lua` still owns and draws the existing full-screen bindings UI without changing its geometry. Only its small `Bindings` launcher consumes shared component bounds, scale, opacity, font scale, visibility, and normalized position.

## Scaling and positions

Automatic scale is `min(viewWidth / 1920, viewHeight / 1080)`, clamped to 0.62–1.60. Effective component scale is automatic scale × global user scale × component scale. Radials additionally apply the shared all-radials multiplier. Normalized bottom-left X/Y positions are converted from the current viewport on each draw and clamped by the safe margin. No scaled value is written back as a new base value, avoiding cumulative drift.

## Converted components

- Context hints: visibility, normalized position, scale, opacity, font/chip size, spacing, padding, wrapping width, columns, background/text/border opacity, transition setting, compact mode.
- Bindings launcher: visibility, normalized position, scale, opacity, font scale, live drag in edit mode.
- Build/factory/tactical/selection radials: global/per-radial resolution-aware size multipliers.
- Reticle: resolution-aware component scale and visibility.
- Layout editor and its mouse launcher: normalized persistent layout.

Settings models are also present for notifications, pregame prompts, and instructional UI. Their scale/opacity controls are preserved for incremental conversion, but those legacy draw paths are not all transformed in this milestone because forcing a global GL transform around heterogeneous overlays would risk gameplay regressions.

## Input ownership

While the editor is open, gameplay sees `SetLayoutEditorOpen(true)` and exits controller gameplay processing after updating button edges. The editor consumes mouse/keyboard input and supports controller B to close, LB/RB section navigation, D-pad row navigation, and D-pad adjustment.

The physical Back/View + Start/Menu shortcut is separate from rebindable gameplay actions. It is exposed through the shortcut resolver so hints do not independently invent button text.

