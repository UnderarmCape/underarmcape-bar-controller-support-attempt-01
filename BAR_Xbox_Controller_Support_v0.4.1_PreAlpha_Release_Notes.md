# BAR Xbox Controller Support v0.4.1 Pre-Alpha Release Notes

This is a prerelease WIP controller-support build. v0.4.0 remains the stable pre-alpha baseline.

## Highlights

- Back/View is now the command layer modifier in both presets.
- Back/View + A + A still focuses/teleports to the commander and selects it.
- RT is the append queue / Shift-style modifier for build placement and command issuing.
- RT + A and RT + X both support append placement without interrupting the current build.
- L3 removes the current/next queued command.
- R3 removes the last queued command.
- L3/R3 queue removal works during active build placement.
- Start/Menu is the group layer.
- Start/Menu + D-pad Right assigns same-type/future groups.
- LB hold forces Grid placement.
- LB tap cycles placement modes.
- RB no longer cycles placement modes.

## Presets

Balanced RTS:

- Y opens Build / Factory Radial.
- RB is Do Next / Insert Command Modifier.
- Back/View is Command Layer Modifier.
- RT is Append Queue.

Build-First Commander:

- RB opens Build / Factory Radial.
- Y is Do Next / Insert Command Modifier.
- Back/View is Command Layer Modifier.
- RT is Append Queue.

Both presets:

- LT is camera speed only.
- LB is camera pitch outside placement.
- Start/Menu + D-pad/L3 controls group slots, recall, assign, and clear.
- Start/Menu + A/B/X/Y is intentionally unused.

## Installation

Manual prerelease update:

1. Install or keep the existing Recoil 2025.06.24 compatibility engine.
2. Copy `luaui/Widgets/gui_controller_camera_test.lua` into your BAR game folder.
3. Copy `luaui/Widgets/gui_controller_bindings_ui.lua` into your BAR game folder.
4. Enable/load both widgets in BAR.
5. Open the bindings UI with `/luaui bar_controller_bindings`.
6. Apply or reset either preset to pick up the new bindings.

## Known Limitations

- This is not a stable release.
- Existing saved bindings may override the new preset mappings until a preset is applied/reset.
- Native Auto Group mirroring requires BAR's Auto Group widget to be enabled and available through `WG.autogroup`.
- If native Auto Group is unavailable, the controller widget still stores current same-type units and auto-adds future finished units through its own metadata.

