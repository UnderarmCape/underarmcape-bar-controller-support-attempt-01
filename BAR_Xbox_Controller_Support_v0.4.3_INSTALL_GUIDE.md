# BAR Xbox Controller Support v0.4.3 Install Guide

Release: v0.4.3 Queue Polish

## Read This First

BAR Xbox Controller Support v0.4.3 is not widget-only. The Lua widgets require the controller polling API from the custom controller-enabled Recoil/BAR engine.

Required engine release:

- Repo: `UnderarmCape/controllersupport-RecoilEngine-attempt-01`
- Tag: `controller-support-recoil-2025-06-24-compat`
- Asset: `recoil_2025.06.24-controller-support-pr2985-win64.zip`
- Release URL: https://github.com/UnderarmCape/controllersupport-RecoilEngine-attempt-01/releases/tag/controller-support-recoil-2025-06-24-compat

Required widget files:

- `luaui/Widgets/gui_controller_camera_test.lua`
- `luaui/Widgets/gui_controller_bindings_ui.lua`

Optional diagnostic widget:

- `luaui/Widgets/gui_controller_smartx_mouse_audit.lua`
- Disabled by default.
- Enable only for diagnostics with `/luaui enablewidget "Controller SmartX Mouse Audit"`.

## Installation Steps

1. Install or verify the custom controller-enabled engine from the release above.
2. Extract `BAR_Xbox_Controller_Support_v0.4.3_QUEUE_POLISH.zip`.
3. Run `Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH.bat`.
4. Launch BAR and load the local controller-support `BAR.sdd`.
5. Confirm both required widgets load.
6. Apply or reset controller presets if you are upgrading from an older test build.

The v0.4.3 installer backs up existing controller widget files before copying the new ones.

## What The Installer Updates

The installer copies:

- `gui_controller_camera_test.lua`
- `gui_controller_bindings_ui.lua`
- `gui_controller_smartx_mouse_audit.lua`, if present in the package

The installer does not replace the engine. It checks for BAR folders, warns about the engine requirement, and points to the required engine release.

## v0.4.3 Manual Verification

Smart X:

- Con bot over wreck: Reclaim.
- Res bot over wreck: Resurrect.
- Damaged allied target: Repair or Guard.
- Mex near 40 elmos: protected no-Move behavior.
- Mex near 75 elmos: Move allowed.
- Wreck near mex: wreck wins.

Queue controls:

- Queue 4 moves, hold Y, issue new Move: new Move goes next/front and old queue remains.
- Hold Y and draw consecutive move lines: second line continues previous queued path.
- Hold RT and draw move lines: append works.
- Hold Y + RT: Y priority wins.

Selection:

- Hold A brush works.
- A + X brush filter radial works.
- RT + A individual unit add works.

Visuals:

- No extra blue controller move preview line/circles.
- Vanilla move path arrows/waypoints remain.
- Compact build menu scaling works.

Existing controls:

- DGUN.
- Self-destruct Back/View + R3 + L3.
- Tactical radial.
- Build/factory radial.

## Known Deferred Work

- Full vanilla Area Mex behavior.
- Settings UI reset X/Y crash.
- Selected-unit type cycling with D-pad Left/Right.

Do not treat Area Mex as fixed in v0.4.3. The only recorded Area Mex clue is that the mouse audit reports Active Command ID = 11 when Area Mex is active.

