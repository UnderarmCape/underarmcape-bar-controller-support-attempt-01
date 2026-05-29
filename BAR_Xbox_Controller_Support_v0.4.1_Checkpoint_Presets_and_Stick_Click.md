# BAR Xbox Controller Support v0.4.1 Pre-Alpha Checkpoint

This checkpoint documents the current v0.4.1 prerelease state for Beyond All Reason Xbox Controller Support.
v0.4.0 remains the stable pre-alpha baseline. v0.4.1 is a WIP prerelease for testing the new presets, queue controls, command layer, and group layer behavior.

## Release Status

| Field | Value |
|---|---|
| Version | v0.4.1 Pre-Alpha |
| Stable baseline | v0.4.0 binding UI pre-alpha |
| Branch | `controller-support-current-master-engine-shim` |
| Latest code commit | `9a2c36eb` |
| Status | Prerelease WIP, not stable |

Do not overwrite the v0.4.0 stable release or tag with v0.4.1 assets.

## Main Files

| File | Purpose |
|---|---|
| `luaui/Widgets/gui_controller_camera_test.lua` | Gameplay input, camera, placement, queue, command, group, and controller API bridge |
| `luaui/Widgets/gui_controller_bindings_ui.lua` | In-game bindings/settings UI, presets, descriptions, and rebinding surface |

## Current Preset Maps

### Balanced RTS

| Control | Behavior |
|---|---|
| A | Select / Confirm |
| B | Cancel / Clear |
| X | Move / Smart Move |
| Y | Build / Factory Radial |
| Back/View hold | Command Layer Modifier |
| Back/View + A + A | Commander focus/select utility |
| LT | Camera speed modifier only |
| LB | Camera pitch modifier; placement LB tap cycles pattern, LB hold forces Grid |
| RT | Append Queue / Shift-style modifier |
| RB | Do Next / Insert Command Modifier |
| L3 | Remove current/next queued command |
| R3 | Remove last queued command |
| D-pad Left/Right | Previous/next idle unit |
| Start/Menu + D-pad Up/Down | Next/previous group slot |
| Start/Menu + D-pad Left | Recall current group slot |
| Start/Menu + D-pad Right | Assign same-type/future units to current group slot |
| Start/Menu + L3 | Clear current group slot |

### Build-First Commander

| Control | Behavior |
|---|---|
| A | Select / Confirm |
| B | Cancel / Clear |
| X | Move / Smart Move |
| RB | Build / Factory Radial |
| Back/View hold | Command Layer Modifier |
| Back/View + A + A | Commander focus/select utility |
| LT | Camera speed modifier only |
| LB | Camera pitch modifier; placement LB tap cycles pattern, LB hold forces Grid |
| RT | Append Queue / Shift-style modifier |
| Y | Do Next / Insert Command Modifier |
| L3 | Remove current/next queued command |
| R3 | Remove last queued command |
| D-pad Left/Right | Previous/next idle unit |
| Start/Menu + D-pad Up/Down | Next/previous group slot |
| Start/Menu + D-pad Left | Recall current group slot |
| Start/Menu + D-pad Right | Assign same-type/future units to current group slot |
| Start/Menu + L3 | Clear current group slot |

Start/Menu is not paired with A/B/X/Y. Back/View may pair with A because it uses left thumb plus right thumb.

## Behavior Changes Since v0.4.0

- Added bindable L3/R3 inputs.
- Split queue removal:
  - L3 removes the current/next queued command.
  - R3 removes the last queued command.
- Added `appendQueueModifier`:
  - Default preset binding: RT.
  - Uses Shift-style queue options.
  - Appends builds/commands to the end of the queue.
  - Does not interrupt the currently building item.
- Added `insertNextCommandModifier`:
  - Balanced RTS: RB.
  - Build-First Commander: Y.
  - Uses insert/front behavior.
- Moved command layer to Back/View in both presets.
- Preserved Back/View + double-tap A commander utility by handling it inside the command-layer A path.
- Moved group layer to Start/Menu + D-pad/L3.
- Restored group assignment to same-type/future behavior instead of current-selection-only behavior.
- Placement polish:
  - RT + A appends and keeps placement active, matching RT + X.
  - L3/R3 queue removal works during active placement.
  - RB does not cycle placement patterns.
  - LB hold forces Grid.
  - LB tap cycles placement patterns.

## Same-Type / Future Group Assignment

Start/Menu + D-pad Right now uses the controller widget's same-type group assignment path:

- Selected unit definitions are preferred as the source.
- All currently owned units of those unit types are stored in the controller group.
- The group stores auto-add metadata so future finished units of those types are added to the controller group.
- If BAR's `WG.autogroup.addCurrentSelectionToAutogroup` API is available, the assignment is also mirrored to BAR's native Auto Group widget.
- If no selection exists, the controller widget can fall back to reticle/idle source for internal grouping; native Auto Group mirroring is skipped in that fallback case to avoid assigning the wrong selected type.

## Known Limitations

- v0.4.1 is still a prerelease WIP.
- Users may need to apply or reset a preset to pick up new bindings.
- Native BAR Auto Group mirroring depends on the `Auto Group` widget being enabled and available as `WG.autogroup`.
- The command-layer debug labels are now generic "Layer" labels, but some internal drag labels still use historical RT strings.
- Full broad public testing is still pending.

## Validation

Validation run after the latest code patch:

```powershell
luac -p luaui/Widgets/gui_controller_bindings_ui.lua luaui/Widgets/gui_controller_camera_test.lua
git diff --check -- luaui/Widgets/gui_controller_bindings_ui.lua luaui/Widgets/gui_controller_camera_test.lua
```

Both commands passed. UTF-8 BOM checks passed for both Lua files.

## Live Manual Test Results Reported Before This Checkpoint

- RT + A placement works.
- RT + X placement still works.
- RT append placement does not interrupt the current build item.
- L3/R3 queue removal during placement works.
- L3/R3 queue removal outside placement works.
- Back/View + A + A commander focus/select behavior works.
- Build-First Commander: RB opens build/factory radial.
- Balanced RTS: Y opens build/factory radial.
- RB no longer cycles placement modes.
- LB hold forces Grid placement.
- LB tap cycles placement modes.
- Build-First Commander: Y works as Do Next / Insert.
- Balanced RTS: RB works as Do Next / Insert.
- LT remains camera speed only.
- LB remains camera pitch outside placement.

## Installation / Update Notes

For a manual update:

1. Install the Recoil 2025.06.24 compatibility engine from the existing v0.3.7 engine release if it is not already installed.
2. Copy `luaui/Widgets/gui_controller_camera_test.lua` into the BAR game folder.
3. Copy `luaui/Widgets/gui_controller_bindings_ui.lua` into the BAR game folder.
4. In BAR, enable/load both widgets.
5. Open the bindings UI with `/luaui bar_controller_bindings`.
6. Apply either `Balanced RTS` or `Build-First Commander`.
7. If old bindings are persisted, reset/apply the preset again.

## Manual Test Checklist

1. Apply Build-First Commander preset.
2. Select constructor.
3. Press RB. Expected: build/factory radial opens.
4. Select Windmill.
5. Hold RT + A to place multiple windmills. Expected: append placement continues and does not interrupt current build.
6. Hold RT + X during placement. Expected: append placement still works.
7. During placement, press L3. Expected: remove current/next queue item.
8. During placement, press R3. Expected: remove last queue item.
9. Hold LB during placement. Expected: Grid placement forced.
10. Tap LB during placement. Expected: placement pattern cycles.
11. Confirm RB does not cycle placement pattern.
12. Hold Back/View and use command layer behavior. Expected: command layer works.
13. Back/View + A + A. Expected: commander is focused/teleported to and selected.
14. Start/Menu + D-pad Up/Down. Expected: group slot changes.
15. Start/Menu + D-pad Left. Expected: current group recalled.
16. Start/Menu + D-pad Right on a selected unit type, such as Tick. Expected: all current same-type units are assigned and future units are auto-added if supported.
17. Start/Menu + L3. Expected: current group cleared.
18. Apply Balanced RTS preset.
19. Press Y with constructor selected. Expected: build/factory radial opens.
20. Confirm RT append, RB insert, LB grid/pattern, L3/R3 removal, and Back/View command layer still work.
21. Close UI and confirm gameplay resumes.
