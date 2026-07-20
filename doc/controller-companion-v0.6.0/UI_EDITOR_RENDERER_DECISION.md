# Controller UI editor renderer decision

Date: 2026-07-20  
Branch: `controller/v0.6.0-ui-qol-overhaul`  
Safety checkpoint: `44cc173a59b95fb88f946ac111338eaa338586a8`

The checkpoint above is the clean, validated v0.6.0 live-deployment baseline. It is the rollback reference for this redesign; no tag was created.

## Scope and invariants

The editor presentation and its input model may change. Shipping-default schema 3, personal overrides, enforced paths, favorites, saved values, presets, themes, recent changes, recovery data, launchers, shortcuts, hint registration, and gameplay behavior must not. The renderer must run as a normal user widget in the installed BAR data directory and remain removable by the existing live rollback process.

## Evidence inspected

### Local and live BAR

- The repository and installed BAR trees contain the normal `LuaUI/Widgets` immediate-mode widget environment, `WG.FlowUI.Draw` drawing helpers, FlowUI/Chili-style textures, fonts, and established widgets such as `gui_options.lua`, `gui_changelog_info.lua`, and `gui_gameinfo.lua`.
- BAR's options widget implements its own mouse handling, slider math, text ownership, filtering, and input consumption. Its `MouseWheel` consumes wheel input while open; it is not a reusable conventional-control framework.
- `LuaUI/barwidgets.lua` gives `widgetHandler.textOwner` first access to `KeyPress`, `KeyRelease`, and `TextInput`. A true return value consumes the event before gameplay action handling. This is the correct mechanism for editor text focus and preventing gameplay leakage.
- Existing scrollable widgets use widget-owned ranges and `gl.Scissor` clipping. The editor can use the same public LuaUI facilities without engine or launcher changes.
- A complete Chili control library is not present in the runtime tree. Chili skin textures alone do not provide windows, scroll panels, focus, edit boxes, or lists.
- `flowui_gl4.lua` is an experimental/test widget rather than a production control toolkit. Its `NewCheckBox` and `NewSelector` methods are empty, while `NewEditBox` and `NewComboBox` are stubs; other layout work is also marked incomplete. It is therefore unsafe to make a user widget depend on it for focus, scrolling, or text input.
- No controller glyph artwork with a sufficiently clear reusable license and the required coverage was found in BAR, the mod, or the companion repository. Controller names in the existing widgets are data/labels, not redistributable glyph assets.
- The installed settings cache and `BYAR.lua` confirm that settings persistence is external to renderer layout. No schema change is needed.

### Official current sources

- [Beyond All Reason game repository](https://github.com/beyond-all-reason/Beyond-All-Reason) confirms that BAR is a LuaUI game running on Recoil and documents the normal Windows data-tree development model.
- [BAR `gui_options.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/gui_options.lua) confirms current custom input/text ownership and immediate-mode UI patterns.
- [BAR `barwidgets.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/barwidgets.lua) confirms input dispatch, text ownership, and event consumption ordering.
- [BAR `gui_flowui.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/gui_flowui.lua) provides reusable visual drawing primitives through `WG.FlowUI.Draw`, not a focusable widget hierarchy.
- [BAR `flowui_gl4.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/flowui_gl4.lua) confirms that the experimental control layer is not complete enough for this editor.
- [Recoil engine repository](https://github.com/beyond-all-reason/RecoilEngine) is the engine source used to cross-check the LuaUI/call-in boundary.
- BAR's `LICENSE.md`, `license_icons.txt`, and `license_bitmaps.txt` were checked before deciding not to copy an existing controller artwork set.

The local BAR checkout matches the relevant official patterns and was used for line-level inspection because it is the exact runtime-adjacent source available to the installation.

## Options evaluated

### 1. Extend the current immediate-mode table

This has the fewest packaging changes and can support wheel input, clipping, and simple scrolling. It becomes fragile when every focusable child, modal, scrollbar, dropdown, search result, and property action is managed as more fields in the already large widget. The existing raw table also encourages per-row controls and a monolithic drawing function. Continuing that structure would preserve the original usability problem and increase the risk of exceeding BAR's practical 60-upvalue limit again.

Decision: reject the table architecture. Retain only the proven direct `gl` rendering boundary and persistence callbacks.

### 2. Adopt an existing BAR-native UI framework

This would be preferable if a complete, user-widget-safe framework with scroll panels, focus, text boxes, dropdowns, sliders, and stable style APIs were bundled. The audit did not find one. Chili is not fully bundled, and the FlowUI GL4 control experiment has critical stubs. Copying a framework into the mod would greatly expand packaging, version skew, and rollback risk.

Decision: reject for v0.6.0. Re-evaluate only if BAR ships and supports a complete framework for ordinary user widgets.

### 3. Modular hybrid

Use BAR-native immediate-mode drawing and optional `WG.FlowUI.Draw` styling for the visible shell, while moving pane layout, focus order, per-pane/per-component scrolling, scrollbars, collapse state, modal trapping, responsive state, and glyph lookup/layout into small pure Lua modules. Keep direct in-game preview outlines and drag/resize handles in the existing widget. Feed property definitions and mutations through adapters so schema and persistence do not move.

Decision: chosen.

## Chosen architecture

The redesigned editor has a compact component browser, a dedicated selected-component preview, and a conventional property inspector. Narrow layouts hide the preview first and can collapse the component browser, leaving a readable inspector.

Two support modules are loaded with `VFS.Include` from `LuaUI/Include`, a normal BAR include location that is not recursively treated as a widget directory:

- `controller_ui_editor_workspace.lua`: pure state/layout/input logic for focus, independent scrolling, visible scrollbars, clipping bounds, responsive panes, collapsible sections, modal/context-menu trapping, and search-to-result focus.
- `controller_glyphs.lua`: binding normalization, licensed atlas metadata, glyph sequences, fallback metadata, and chord measurement.

The main widget remains responsible for settings reads/writes, undo boundaries, direct preview dragging, runtime input call-ins, and drawing through Recoil's `gl` API. Support modules do not own schema-3 data.

The property list is virtualized: only rows intersecting the inspector viewport become hit targets or are drawn. Static grouping and normalized glyph lookup are cached where safe. Clipping is scoped to each pane. There are no timers, animations, periodic logs, or per-frame filesystem operations.

## Input and focus model

- Wheel events are routed by pointer position to the component browser or inspector and are always consumed while over the editor.
- Each pane owns a pixel scroll position, content height, viewport height, and scrollbar geometry. Inspector scroll is remembered per component/tab.
- Tab order is explicit and skips hidden/disabled controls. Up/Down navigate logical rows; Page Up/Down scroll by a viewport; Home/End reach boundaries; focus movement always calls scroll-into-view.
- Search, editable property fields, dropdowns, and the property context menu use a focus owner. Modal state traps navigation and restores the opener when closed.
- While editor text is active, the widget takes `widgetHandler.textOwner`; all editor key events return true so BAR gameplay bindings do not run.

## Glyph assets

Because no suitable licensed set was found, the project will generate an original generic monochrome atlas from repository-owned vector/drawing source. Face-button tint metadata permits a familiar color-friendly mode without using trademarked controller artwork. The asset folder will carry an explicit license/source manifest. Text labels remain the fallback for unknown bindings and tooltips.

## Risks and mitigations

- **Runtime API variance:** use only long-established `gl.Rect`, `gl.Text`, `gl.Texture`, `gl.TexRect`, `gl.Scissor`, widget call-ins, and `VFS.Include`; drawing helpers are optional.
- **Lua function limits:** keep state/functions in modules and validate every changed Lua chunk with `luac -l`; no function may exceed 60 upvalues.
- **Packaging omissions:** deployment and rollback manifests will enumerate the include modules and glyph assets, verify SHA256 at the destination, and remove newly created files during rollback when they did not previously exist.
- **Input leakage:** consume all mouse/key input inside the editor and use BAR text ownership during text entry.
- **Rendering failure:** module load is guarded. If an optional glyph texture cannot load, hints use readable text chips. If the workspace module cannot load, the editor reports the error and can be closed; gameplay UI and saved settings remain intact.
- **Config regression:** no schema/default key is removed or renamed. Existing values continue to resolve through the current merge/migration path.

## Migration and fallback

No saved-settings migration is required. Existing editor window position/size, selected component defaults, component layout, and authoring data remain valid. New runtime-only workspace state starts with bounded scroll/focus defaults and is not written into schema 3.

Rollback uses the existing timestamped deployment backup. It restores every overwritten file and removes newly deployed include/asset files recorded as absent before deployment. The documented `44cc173a59b95fb88f946ac111338eaa338586a8` checkpoint is the source fallback. Public v0.5.1 release assets are outside the deployment map and remain untouched.
