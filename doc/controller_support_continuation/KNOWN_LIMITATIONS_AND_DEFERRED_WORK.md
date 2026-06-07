# Known Limitations and Deferred Work

## Custom Engine Requirement

The controller-enabled Recoil 2025.06.24 engine remains required. Multiplayer
is blocked or limited until equivalent support is upstreamed and adopted.

## UI Dispatch Boundary

Controller Mouse Mode can dispatch clicks to in-game LuaUI. It cannot control
the opened Chobby/LuaMenu overlay or native engine UI through that path.

## Multi-Unit X Freehand Movement

The experimental drawn-path implementation remains reverted. Do not reintroduce
it on stable. Any future attempt belongs on an isolated experimental branch.

## Required Modified Widgets

- `cmd_area_mex.lua` remains required until BAR PR #7874 or equivalent lands.
- `gui_pregameui.lua` remains required until its controller Ready API is
  upstreamed or replaced.

## Deferred Release Work

The first priority after packaging is an AIO payload-check and clean-install
smoke test, followed by the complete v0.4.6 manual regression checklist.
