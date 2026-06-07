# Active Continuation Bible - BAR Xbox Controller Support

This is the active source of truth for continuing BAR Xbox Controller Support.

## Current Stable Version

- Version: v0.4.6 Skirmish Readiness
- Branch: `controller/v0.4.6-skirmish-readiness`
- AIO tag: `controller-support-v0.4.6-aio-skirmish-readiness`
- Engine dependency: controller-enabled Recoil 2025.06.24 from the prior AIO
- v0.4.5 AIO status: superseded by the v0.4.6 AIO

No engine code was changed or compiled for v0.4.6.

## Required Active Lua Files

All five files are required in `luaui/Widgets`:

- `gui_controller_camera_test.lua`: main controller logic, camera controls,
  radials, bindings, selection, command routing, Mouse Mode, and feedback.
- `gui_pregameui.lua`: exposes the small `WG.pregameui` owner API used for
  controller-safe Ready/Lock activation. Do not remove it until that API is
  upstreamed or replaced.
- `cmd_area_mex.lua`: exposes
  `WG.controllerAreaMex.issueArea(x, y, z, radius, opts)`. Do not remove it
  until the Area Mex API is upstreamed.
- `gui_controller_bindings_ui.lua`: controller bindings overlay.
- `gui_controller_smartx_mouse_audit.lua`: Smart X targeting diagnostic.

## v0.4.6 Feature Set

- Pregame right stick cursor.
- A/X commander placement and Ready activation.
- Controller Mouse Mode with LuaUI click routing.
- Back + Start Mouse Mode toggle.
- Back tap cycles SLOW, DEFAULT, MEDIUM, and FAST cursor presets.
- Mouse Mode cursor clamps at screen edges without recenter or camera edge-pan.
- Pregame LB + right stick camera rotation and tilt.
- Pregame LB + LT + right stick Y camera zoom.
- Build and factory radial center information with translated role text and
  UnitDef/WeaponDef stats.
- Factory insert-to-front using the native build command with Alt behavior.
- T2 metal extractor and geothermal Smart X upgrades.
- Build spacing memory and slow-pan placement default.
- Dedicated air transport load/unload controls from v0.4.5.
- Builder Repair/Reclaim area auto-anchor controls.
- Command Toast feedback.
- Area Mex controller radial.
- D-pad Down commander selection and A double-tap same-type selection.

## Stable Binding Summary

- Left Stick: camera pan
- Right Stick: gameplay camera or contextual radius control
- Pregame Right Stick: cursor
- Pregame LB + Right Stick: rotate/tilt
- Pregame LB + LT + Right Stick Y: zoom
- A: select/confirm/place
- B: cancel/stop/wait context
- X: Smart X context action
- LB: camera/hotkey modifier
- RT: queue/append modifier
- LT: queue-front/insert modifier
- Back + Start: Mouse Mode toggle
- Back tap in Mouse Mode: cursor speed cycle

## Hard Safety Rules

- Do not reimplement Area Mex internals in the controller widget. Route through
  `WG.controllerAreaMex.issueArea(...)`.
- Do not remove `cmd_area_mex.lua` until the upstream API is accepted.
- Do not remove `gui_pregameui.lua` until its owner API is upstreamed or
  replaced.
- Do not reintroduce multi-unit X freehand/drawn-path movement on stable.
- Do not alter factory insert without a dedicated regression task.
- Do not alter T2 mex/geo Smart X without a dedicated regression task.
- Do not edit or rebuild the engine for Lua-only releases.
- Do not push to official BAR or Recoil remotes.
- Do not overwrite old release assets.

## Known Limitations

- The custom controller-enabled engine remains required.
- Multiplayer remains limited until engine support is upstreamed and adopted.
- In-game LuaUI click dispatch cannot control Chobby/LuaMenu overlays or native
  engine UI.
- Multi-unit X freehand movement remains disabled.

## Upstream Status

BAR Area Mex API PR:
https://github.com/beyond-all-reason/Beyond-All-Reason/pull/7874

Recoil controller input support remains separate.

## Recommended Next Work

1. Complete AIO `--payload-check` and clean-install smoke tests.
2. Run the v0.4.6 manual regression checklist.
3. Continue upstream API work without removing local compatibility files until
   upstream adoption is confirmed.
