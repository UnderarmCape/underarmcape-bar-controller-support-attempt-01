# BAR Xbox Controller Support v0.4.6 - Current Release

v0.4.6 is the current stable source of truth and supersedes v0.4.5.

## Main Changes

- Added full pregame controller placement and Ready flow.
- Added LuaUI clicking through Controller Mouse Mode.
- Added four Mouse Mode speed presets.
- Added hard screen-edge cursor clamping without recenter or edge-pan.
- Added pregame LB rotate/tilt and LB+LT zoom controls.
- Fixed factory insert-to-front using native Alt behavior.
- Added T2 metal extractor and geothermal Smart X upgrade handling.
- Added build/factory radial title, translated role, and unit statistics.
- Preserved v0.4.5 transport, area-command, placement, and toast polish.

## Required Widgets

- `gui_controller_camera_test.lua`
- `gui_pregameui.lua`
- `cmd_area_mex.lua`
- `gui_controller_bindings_ui.lua`
- `gui_controller_smartx_mouse_audit.lua`

## Engine

The v0.4.6 AIO reuses the tested controller-enabled Recoil engine from the
previous AIO. No new engine was compiled.

## Known Limitations

- Custom engine requirement remains.
- Chobby/LuaMenu and native engine UI are outside LuaUI click dispatch.
- Multi-unit X freehand movement remains disabled.
