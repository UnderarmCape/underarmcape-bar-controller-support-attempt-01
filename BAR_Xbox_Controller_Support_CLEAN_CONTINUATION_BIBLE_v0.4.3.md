# BAR Xbox Controller Support Clean Continuation Bible v0.4.3

Version: v0.4.3 Queue Polish

Known-good commit:

`f433cbc8f36f343107c0cdcb7f015c10da535450`

Branch:

`controller-support-current-master-engine-shim`

BAR-side repo:

`UnderarmCape/underarmcape-bar-controller-support-attempt-01`

Engine-side repo:

`UnderarmCape/controllersupport-RecoilEngine-attempt-01`

Required engine release:

https://github.com/UnderarmCape/controllersupport-RecoilEngine-attempt-01/releases/tag/controller-support-recoil-2025-06-24-compat

Required engine asset:

`recoil_2025.06.24-controller-support-pr2985-win64.zip`

## Current Project State

BAR Xbox Controller Support v0.4.3 is a normal release candidate built on v0.4.2 Smart X calibration plus post-release queue, selection, and move-line fixes.

This project is not widget-only. It requires:

- Custom controller-enabled Recoil/BAR engine.
- `luaui/Widgets/gui_controller_camera_test.lua`.
- `luaui/Widgets/gui_controller_bindings_ui.lua`.

Optional diagnostic widget:

- `luaui/Widgets/gui_controller_smartx_mouse_audit.lua`.
- Disabled by default.

## v0.4.3 Confirmed Manual Test Results

Passed after commit `f433cbc8`:

- Smart X Reclaim/Resurrect/Repair/Guard at targets works.
- Smart X mex radius is approximately 55 elmos.
- Wreck beats mex priority works.
- Hold A brush selection works.
- Hold A + X brush filter radial works.
- Compact build menu scaling works.
- Y Do Next single-command queue insertion works.
- Y Do Next consecutive line/drag move queue continuation works.
- RT append works.
- Y + RT priority works.
- RT + A individual multi-select accumulation works.
- Extra blue controller move preview line/circles were removed.
- Vanilla move path arrows/waypoints remain.
- DGUN mode works.
- Self-destruct Back/View + R3 + L3 works.
- Tactical radial works.
- Build/factory radial works.
- No Lua errors reported in manual testing.

## v0.4.3 Highlights

- Fixed Y Do Next queue insertion using vanilla INSERT behavior.
- Fixed Y-held consecutive line/drag move queue continuation.
- Removed redundant blue controller move preview overlay while preserving vanilla move path visuals.
- Added/fixed RT + A individual multi-select accumulation.
- Preserved v0.4.2 Smart X target fixes.

## Smart X Status

Working:

- Reclaim.
- Resurrect.
- Repair.
- Guard.
- Exact target priority.
- Wreck beats mex.
- Mex radius around 55 elmos.

Do not regress:

- Smart X mex radius and wreck priority.
- Smart X self-target guard behavior.
- Smart X Reclaim/Resurrect/Repair/Guard.

## Queue And Selection Status

Working:

- Y Do Next single-command front insertion.
- Y-held consecutive line/drag move queue continuation.
- RT append.
- Y + RT priority.
- RT + A individual multi-select accumulation.
- Hold A brush selection.
- A + X brush filter radial.

## Visual Status

Removed:

- Extra custom blue controller move preview line/circles.

Preserved:

- Vanilla move path arrows/waypoints.
- Tactical radial visuals.
- Build placement visuals.
- Hold A brush selection circle.
- Smart X reticle.
- Compact build menu.

## Known Deferred Work

- Full vanilla Area Mex behavior.
- Settings UI reset X/Y crash.
- Selected-unit type cycling with D-pad Left/Right.

Area Mex clue:

- Mouse audit reports Active Command ID = 11 when Area Mex command is active.
- Do not claim Area Mex is fixed.
- Future work should inspect vanilla Area Mex APIs before reimplementing behavior.

## Release Package Contents

Main release ZIP:

- `README_INSTALL_FIRST.md`
- `BAR_Xbox_Controller_Support_v0.4.3_INSTALL_GUIDE.md`
- `BAR_Xbox_Controller_Support_v0.4.3_RELEASE_NOTES.md`
- `Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH.bat`
- `SHA256SUMS.txt`
- `luaui/Widgets/gui_controller_camera_test.lua`
- `luaui/Widgets/gui_controller_bindings_ui.lua`
- `luaui/Widgets/gui_controller_smartx_mouse_audit.lua`

Continuation ZIP:

- This continuation bible.
- Install guide.
- Release notes.
- Current widget files.
- Concise current known-good status.

## Next Work

1. Full vanilla Area Mex implementation.
2. Settings UI reset X/Y crash fix.
3. Selected-unit type cycling with D-pad Left/Right.
4. Further polish only after v0.4.3 release packaging is complete.

