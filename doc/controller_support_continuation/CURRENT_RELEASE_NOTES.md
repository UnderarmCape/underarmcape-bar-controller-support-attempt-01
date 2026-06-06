# BAR Xbox Controller Support v0.4.5 - Release Notes

This release is a Lua-only incremental update focusing on polishing air transport controls, hotkey handling, and visual refinements.

## What Changed
- **Dedicated Air Transport Controls**: Activating air transports now switches to a dedicated profile. Tapping X loads units when hovering over allied units, or moves the transport on empty ground (blocking the old buggy Guard fall-through).
- **LB Combinations**:
  - LB + X Load Unit / LB + Hold X Load Area (auto-anchored).
  - LB + A Unload / LB + Hold A Unload Area (auto-anchored).
- **Visual Cleanup**:
  - Removed the redundant green ground selection circle drawn by the controller widget, restoring the default BAR unit selection shapes.
  - Caching build menu affordability to reduce flickers.
  - Readability improvements for unaffordable build items.
- **Placement & Commands**:
  - Removed `[X] Stay` from build placement.
  - Added build placement slow/full pan toggle.
  - Auto-anchor support for Builder area commands (Repair Area LB+A, Reclaim Area LB+X).

## Files Included
- `README_v0.4.5_INCREMENTAL_LUA_WIDGETS.txt`
- `luaui/Widgets/gui_controller_camera_test.lua`
- `luaui/Widgets/cmd_area_mex.lua`
- `luaui/Widgets/gui_controller_bindings_ui.lua`
- `luaui/Widgets/gui_controller_smartx_mouse_audit.lua`

## Install Instructions
Requires:
- v0.4.3 AIO / controller-enabled engine first

1. Install v0.4.3 AIO first.
2. Extract `BAR_Controller_Support_v0.4.5_INCREMENTAL_LUA_WIDGETS.zip`.
3. Copy `luaui\Widgets\*.lua` into:
   `C:\Users\kaili\AppData\Local\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets`
4. Overwrite matching files.
5. Test in Singleplayer: Beyond All Reason Dev.

## Known Limitations
- Multi-unit X drawn-path movement is reverted due to widget loading crashes.
- Custom Recoil engine is required.

## Rollback
Restore your previous Lua widgets or reinstall the v0.4.3 AIO clean package.
