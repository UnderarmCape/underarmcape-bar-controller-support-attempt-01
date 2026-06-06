# BAR Xbox Controller Support v0.4.5 - Transport and Hotkey Polish

This is a Lua-only incremental update.
This is NOT a full AIO installer.
This does NOT include engine files.
This does NOT replace the v0.4.3 AIO installer.

## Highlights
- **Dedicated air transport controls**: Select air transports to activate dedicated command routing.
- **Improved Smart X on air transports**: 
  - X tap over pickup-capable allied unit loads instead of guarding.
  - X tap over ground moves the transport.
  - Intercepts early to avoid falling through to generic Guard/Assist.
- **LB hotkey combination polish**:
  - LB + X Load Unit.
  - LB + Hold X Load Area (auto-anchor center immediately, enter radius-resize phase).
  - LB + A Unload.
  - LB + Hold A Unload Area (auto-anchor center immediately, enter radius-resize phase).
- **Command Toast feedback polish**: Clean visual toasts trigger once per action without spam.
- **Builder area command auto-anchors**:
  - Builder LB + A Repair Area auto-anchor.
  - Builder LB + X Reclaim Area auto-anchor.
- **Build placement updates**:
  - Build placement slow/full pan toggle.
  - Removed `[X] Stay` from the placement UI.
- **Affordability visual tweaks**:
  - Unaffordable build items remain readable.
  - Reduced affordability caching flicker.
- **Cleaned selection rendering**:
  - Removed the redundant extra green selected-unit highlight circle drawn by the controller widget, preserving the native BAR white/colored selection shapes.

## Install Instructions
Requires:
- v0.4.3 AIO / controller-enabled engine first

1. Install v0.4.3 AIO first if not already installed.
2. Extract the ZIP package `BAR_Controller_Support_v0.4.5_INCREMENTAL_LUA_WIDGETS.zip`.
3. Copy the included `luaui\Widgets\*.lua` files into:
   `C:\Users\kaili\AppData\Local\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets`
4. Overwrite matching files.
5. Launch BAR and test in Singleplayer: Beyond All Reason Dev.

## Files Included
- `README_v0.4.5_INCREMENTAL_LUA_WIDGETS.txt`
- `luaui/Widgets/gui_controller_camera_test.lua`
- `luaui/Widgets/cmd_area_mex.lua`
- `luaui/Widgets/gui_controller_bindings_ui.lua`
- `luaui/Widgets/gui_controller_smartx_mouse_audit.lua`

## Manual Test Checklist
- **Execution & Loading**:
  - Widget loads correctly.
  - No Lua errors or OpenGL stack errors.
- **Air Transports X / LB / A**:
  - X tap over allied unit loads unit; X tap over ground moves transport.
  - LB + X over allied unit loads unit; LB + X over ground fails safely (NO LOAD TARGET toast).
  - LB + Hold X opens Load Area auto-anchored (confirms radius with A/X, cancels with B).
  - LB + A unloads unit at ground point if cargo is present; empty transport shows fail toast.
  - LB + Hold A opens Unload Area auto-anchored (confirms radius with A/X, cancels with B).
- **Highlights & Outlines**:
  - Green controller selection circles are gone.
  - Normal BAR outlines/selection outlines remain.
- **Regressions**:
  - Builder area commands (Repair Area LB+A, Reclaim Area LB+X) work.
  - Build menu X queue removal, pan toggle, and Wait hold commands work.

## Known Limitations
- Multi-unit X drawn-path movement is disabled/reverted for now because the experimental implementation caused the widget to fail loading.
- This still requires the controller-enabled custom Recoil engine until native engine support is merged.

## Rollback Instructions
Reinstall v0.4.4 incremental Lua widgets, rerun the v0.3/v0.4.3 AIO clean installer, or restore previous Lua widget files.
