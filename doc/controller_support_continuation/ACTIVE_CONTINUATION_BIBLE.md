# Active AI Continuation Bible - BAR Xbox Controller Support

This document is the active source of truth and handoff document for the development of Xbox Controller Support for Beyond All Reason (BAR).

---

## 1. Current Stable Version
- **Version**: v0.4.5 Incremental Update (Lua-only)
- **Engine Dependency**: Requires v0.4.3 AIO clean installer or a controller-enabled custom Recoil engine.

---

## 2. Current GitHub Release Links
- **GitHub Repository**: https://github.com/UnderarmCape/underarmcape-bar-controller-support-attempt-01
- **Release Page**: https://github.com/UnderarmCape/underarmcape-bar-controller-support-attempt-01/releases/tag/controller-support-v0.4.5-incremental-transport-polish

---

## 3. Required Files and Why They Exist
The continuation pack contains the following core files in `luaui/Widgets/`:
- **`gui_controller_camera_test.lua`**: The main controller support widget. It handles input bindings, joystick translation, radial menus, and context-sensitive action dispatching.
- **`cmd_area_mex.lua`**: Modified vanilla BAR widget. It acts as an API bridge for controller-driven Area Metal Extractors, exposing `WG.controllerAreaMex.issueArea(x, y, z, radius, opts)`.
- **`gui_controller_bindings_ui.lua`**: Renders the in-game Controller Bindings configuration overlay/UI.
- **`gui_controller_smartx_mouse_audit.lua`**: A diagnostic auditing widget used to trace vanilla context commands and assist with controller input debugging.

---

## 4. Current Controller Feature Set
The v0.4.5 release supports a robust controller-native gameplay profile:
- **Dedicated Air Transport Controls**: Bypasses normal Smart X logic when air transports are exclusively selected:
  - **X Tap over allied unit**: Issues `LOAD UNIT` (CMD 75) + `LOAD UNIT` toast.
  - **X Tap over ground**: Issues `MOVE` (CMD 10) + `MOVE` toast.
  - **LB + X**: Issues deliberate `LOAD UNIT` if pointing at a pickup-capable allied unit, or fails safely (triggers `NO LOAD TARGET` toast; no move/guard fallback).
  - **LB + Hold X**: Starts `Load Area` auto-anchored radial command + `LOAD AREA` toast.
  - **LB + A**: Issues Unload point command if cargo is present + `UNLOAD` toast; empty transport fails safely (triggers `NO CARGO` / `NO UNLOAD` toast).
  - **LB + Hold A**: Starts `Unload Area` auto-anchored radial command + `UNLOAD AREA` toast.
- **Builder Area Commands**:
  - **Builder LB + A**: Repair Area auto-anchor radial.
  - **Builder LB + X**: Reclaim Area auto-anchor radial.
- **Build Placement Polish**:
  - Slow/Full panning toggle for build placement.
  - Removed `[X] Stay` option from build placement UI.
- **Command Toast Feedback**: Visual feedback toasts appear once per action without frame-level spamming.
- **Affordability Adjustments**: Unaffordable build items are kept readable, and flickering is reduced via caching.
- **Removed Unit Highlight**: Gated the redundant extra green selected-unit highlight circle drawn by the controller widget, leaving only the native white/colored BAR selection shapes.
- **Other Controls**:
  - **LB + Hold B**: Wait.
  - **Combat LB + X**: Attack target/ground.
  - **D-pad Down**: Select commander.
  - **A Double-Tap**: Select same unit type on screen.
  - **Build/Factory B/X**: Correct queue removal.
  - **Balanced RTS**: Preset has been completely removed.

---

## 5. Current Binding Map
- **Left Stick**: Pan camera
- **Right Stick**: Rotate and pitch camera / resize command radius
- **D-pad Down**: Select Commander
- **A**: Confirm / Select / Double-tap for same unit selection
- **B**: Cancel / Stop / Wait (Hold)
- **X (smartAction)**: Context-sensitive actions (Smart X)
- **LB**: Hotkey modifier
- **RT**: Queue/append modifier (Shift equivalent)
- **LT**: Queue-front modifier (Ctrl/Insert equivalent)

---

## 6. Current Install/Test Procedure
Install folder:
`C:\Users\kaili\AppData\Local\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets`

1. Run the v0.4.3 AIO installer first to set up the custom engine.
2. Extract the widgets from the `BAR_Controller_Support_v0.4.5_INCREMENTAL_LUA_WIDGETS.zip` package.
3. Copy the files into the install folder, overwriting matching files.
4. Launch BAR and test in **Singleplayer -> Beyond All Reason Dev**.

---

## 7. Known Deferred Work
- **Multi-Unit X Drawn-Path Movement**: Reverted because the experimental implementation caused loading failures. It must only be re-attempted on separate experimental branches.
- **Upstream Integration**: Merging the `cmd_area_mex.lua` API bridge directly into vanilla BAR to remove the need for shipping a modified version.

---

## 8. Hard Safety Rules for Future AI
- **Do not reimplement Area Mex internals** inside `gui_controller_camera_test.lua`. Always route via `WG.controllerAreaMex.issueArea(...)`.
- **Do not reintroduce multi-unit X drawn-path movement** into the stable branch.
- **Do not edit engine files** for Lua-only releases.
- **Do not modify installer BAT files** unless explicitly tasked.
- **Do not push to official upstream BAR** or RecoilEngine remotes.
- **Do not overwrite v0.4.3/v0.4.4/v0.4.5 release assets**.

---

## 9. Upstream PR Roadmap Summary
1. **Recoil Engine PR**: Upstream native controller input APIs to standard Recoil engine.
2. **BAR Lua PR**: Merge the `WG.controllerAreaMex.issueArea(...)` hook into vanilla `cmd_area_mex.lua`.
3. **Future BAR UI PRs**: Introduce formal controller command metadata and command libraries.

---

## 10. Next Recommended Work
- Create a clean PR for the `cmd_area_mex.lua` bridge into the main BAR repository.
- Investigate clean custom-formation hooks inside vanilla to see if multi-unit path movement can be implemented cleanly on a separate experimental branch.
