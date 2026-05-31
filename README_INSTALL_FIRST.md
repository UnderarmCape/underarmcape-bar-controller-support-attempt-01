# STOP: READ THIS FIRST - BAR Xbox Controller Support v0.4.3

This is the v0.4.3 Queue Polish release for BAR Xbox Controller Support.

Important: this is not a widget-only mod.

You need both:

- The custom controller-enabled Recoil/BAR engine.
- The LuaUI controller widgets included in this package.

Required engine release:

- Repo: UnderarmCape/controllersupport-RecoilEngine-attempt-01
- Tag: controller-support-recoil-2025-06-24-compat
- Asset: recoil_2025.06.24-controller-support-pr2985-win64.zip
- URL: https://github.com/UnderarmCape/controllersupport-RecoilEngine-attempt-01/releases/tag/controller-support-recoil-2025-06-24-compat

Required widgets:

- luaui/Widgets/gui_controller_camera_test.lua
- luaui/Widgets/gui_controller_bindings_ui.lua

Optional diagnostic widget:

- luaui/Widgets/gui_controller_smartx_mouse_audit.lua
- Disabled by default.
- Enable only when debugging Smart X behavior:

```text
/luaui enablewidget "Controller SmartX Mouse Audit"
```

## Quick Install

1. Install the custom controller-enabled engine above if you have not already done so.
2. Extract this v0.4.3 release ZIP.
3. Run:

```text
Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH.bat
```

The installer backs up your existing controller widgets and copies the v0.4.3 widgets into your active local `BAR.sdd`.

## v0.4.3 Highlights

- Built on v0.4.2 Smart X calibration.
- Fixed Y Do Next queue insertion using vanilla INSERT behavior.
- Fixed Y-held consecutive line/drag move queue continuation.
- Removed redundant blue controller move preview overlay while preserving vanilla move path visuals.
- Added/fixed RT + A individual multi-select accumulation.
- Preserved Smart X Reclaim, Resurrect, Repair, Guard, mex-radius, exact-target, and wreck-priority fixes.
- Hold A brush selection remains working.
- Compact build menu scaling remains working.

## Known Deferred Work

- Full vanilla Area Mex behavior.
- Settings UI reset X/Y crash.
- Selected-unit type cycling with D-pad Left/Right.
- Area Mex clue: mouse audit reports Active Command ID = 11 when Area Mex command is active.
