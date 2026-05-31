# BAR Xbox Controller Support v0.4.3 - Queue Polish

This is the normal v0.4.3 release for BAR Xbox Controller Support. It is not a prerelease.

This release updates the BAR-side controller widgets, release documentation, and full installer after the v0.4.2 Smart X calibration release.

## Important Requirement

This mod is not widget-only. The included v0.4.3 installer installs:

- Custom controller-enabled Recoil/BAR engine.
- Controller-support `BAR.sdd`.
- `BYAR Chobby.sdd`.
- `gui_controller_camera_test.lua`
- `gui_controller_bindings_ui.lua`
- `devmode.txt` and the controller camera cardinal-lock setting.

Required engine release:

https://github.com/UnderarmCape/controllersupport-RecoilEngine-attempt-01/releases/tag/controller-support-recoil-2025-06-24-compat

Engine asset:

`recoil_2025.06.24-controller-support-pr2985-win64.zip`

Optional diagnostic widget:

- `gui_controller_smartx_mouse_audit.lua`
- Disabled by default.
- Use only for Smart X diagnostics.

## Highlights

- Built on v0.4.2 Smart X calibration.
- Fixed Y Do Next queue insertion using vanilla INSERT behavior.
- Fixed Y-held consecutive line/drag move queue continuation.
- Removed redundant blue controller move preview overlay.
- Preserved vanilla move path arrows/waypoints.
- Added/fixed RT + A individual multi-select accumulation.
- Restored the full all-in-one installer behavior: engine + BAR.sdd + Chobby + widgets.

## Preserved Smart X Fixes

- Reclaim, Resurrect, Repair, and Guard target behavior.
- Mex radius around 55 elmos.
- Exact target priority.
- Wreck beats mex priority.
- Smart X Reclaim/Resurrect/Repair/Guard manual tests passed.

## Other Confirmed Working Systems

- Hold A brush selection.
- Hold A + X brush filter radial.
- Compact build menu scaling.
- RT append.
- Y + RT priority.
- DGUN mode.
- Self-destruct Back/View + R3 + L3.
- Tactical radial.
- Build/factory radial.

## Known Deferred Work

- Full vanilla Area Mex behavior.
- Settings UI reset X/Y crash.
- Selected-unit type cycling with D-pad Left/Right.
- Area Mex clue: mouse audit reports Active Command ID = 11 when Area Mex command is active.

Do not claim Area Mex is fixed in this release.

## Manual Test Checklist

Install:

- Install v0.4.3 with the custom controller-enabled engine.
- Confirm `gui_controller_camera_test.lua` loads.
- Confirm `gui_controller_bindings_ui.lua` loads.

Smart X:

- Con bot over wreck: Reclaim.
- Res bot over wreck: Resurrect.
- Damaged allied target: Repair/Guard.
- Mex near 40 elmos: protected behavior.
- Mex near 75 elmos: Move allowed.
- Wreck near mex: wreck wins.

Queue controls:

- Queue 4 moves, hold Y, issue new Move: new Move goes next/front and old queue remains.
- Hold Y and draw consecutive move lines: second line continues previous queued path.
- Hold RT and draw move lines: append works.
- Y + RT: Y priority.

Selection:

- Hold A brush works.
- A + X filter radial works.
- RT + A individual unit add works.

Visuals:

- No extra blue controller move preview line/circles.
- Vanilla move path visuals remain.
- Compact build menu scaling works.

Existing controls:

- DGUN.
- Self-destruct Back/View + R3 + L3.
- Tactical radial.
- Build/factory radial.

Optional:

```text
/luaui enablewidget "Controller SmartX Mouse Audit"
```
