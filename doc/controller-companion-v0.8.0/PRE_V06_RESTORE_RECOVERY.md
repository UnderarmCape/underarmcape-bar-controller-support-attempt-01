# Pre-v0.6 restore recovery point

## Immutable recovery reference

- Branch at start: `controller/v0.8.0-native-ui-integration-test`
- Starting commit: `c5c07603e3d6560ad057e35a021d0f5ffc8b1643`
- Remote at preflight: `origin/controller/v0.8.0-native-ui-integration-test` at the same commit
- Worktree at preflight: clean
- Public stable release remains `controller-support-v0.7.0-disassemble-mode`; this restoration creates no tag or public release.

The starting commit is the authoritative recovery point for the superseded hybrid/native targeting experiment. Git history is the recovery mechanism; no duplicate copy of that implementation is kept in active Lua folders.

## Historical decision

Selected behavioral source: tag `controller-support-v0.6.1-radial-typography`, commit `d345fd1ee790e4ff392f020b82d8aa3b52db0edf`.

This is the latest tagged, packaged, committed controller runtime before the broad v0.8 vanilla-widget targeting overhaul. It contains the v0.6 direct controller-owned tactical staging, point dispatch, two-press area gesture, double-tap selection, and idle navigation, plus the final v0.6.1 input/radial stability changes. Its `cmd_area_mex.lua` blob (`55e9824b037a3f302095ca1606fd274033a45df0`) is identical to the v0.6.0 and v0.5.0 release blobs and exposes the proven `WG.controllerAreaMex.issueArea(...)` route.

| Behavior | v0.5 | v0.6.0 | v0.6.1 | Current at recovery commit | Selected source |
|---|---|---|---|---|---|
| Point tactical shortcuts | direct reticle order | direct reticle order | direct reticle order | routed through native descriptor/target sessions | v0.6.1 |
| Tactical radial point placement | staged controller reticle | staged controller reticle | staged controller reticle with latest v0.6 input stability | hybrid descriptor capture | v0.6.1 |
| Area Mex | direct `issueArea` | same helper blob | same helper blob | completed-shape/native-owner broker | v0.6.1 camera gesture + current compatible helper |
| Area reclaim | controller anchor/radius/direct order | controller anchor/radius/direct order | controller anchor/radius/direct order | hybrid owner/finalizer broker | v0.6.1 |
| Double-tap A | visible same-type | visible same-type | visible same-type | removed while repairing accidental expansion | v0.6.1, isolated into a focused state helper |
| Idle previous/next | controller-owned scan | controller-owned scan | controller-owned scan and camera focus | controller-owned selection fed by current ZZZ list, with changed traversal | v0.6.1 traversal using the current read-only ZZZ snapshot |

Only compatibility adaptations for current descriptor names, command IDs, controller cursor data, native radial models, Disassemble state, and package paths are allowed. Current compact page packing, native Build Menu cells, selected-border scaling, glyphs, native groups, panel visibility, state cycling, Smart X, Hold-X, Distributed Grid, and user-authored settings remain active.

## Expected implementation surface

The restoration is expected to affect these active files and responsibilities:

- `luaui/Widgets/gui_controller_camera_test.lua`
  - `ControllerCameraTestStageTacticalCommand`
  - `ControllerCameraTestHandleStagedTacticalCommandInput`
  - `ControllerCameraTestExecuteTacticalCommand`
  - LB shortcut dispatch
  - controller A tap/hold arbitration
  - idle traversal
  - Disassemble area confirmation
  - protected Self Destruct entry
- `luaui/Include/controller_native_radial_adapter.lua`: retain current native descriptor/radial data while mapping it to restored v0.6 command kinds.
- `luaui/Include/controller_ui_shared_renderers.lua`: mixed-heading suppression and inner-circle page indicator.
- focused new `luaui/Include` helpers for selection taps or restored targeting state where extraction provides Lua upvalue headroom.
- current BAR native overrides only where an obsolete controller target-owner hook must be made inactive or a completed controller area helper must remain directly callable.
- `tools/controller-companion/Program.cs` and a focused console-presentation helper for bridge-only visual output.
- validation, deployment/package manifests, release scripts, and v0.8 restoration documentation.

The exact final changed-file list is recorded by the restoration commits and deployment/package manifests.

## Inspect the recovery implementation

```powershell
git show --stat c5c07603e3d6560ad057e35a021d0f5ffc8b1643
git show c5c07603e3d6560ad057e35a021d0f5ffc8b1643:luaui/Widgets/gui_controller_camera_test.lua
git diff c5c07603e3d6560ad057e35a021d0f5ffc8b1643..HEAD -- luaui native-overrides tools/controller-companion
```

## Restore individual files

Use a new branch or a clean worktree. These commands copy one file from the recovery commit without rewriting history:

```powershell
git restore --source=c5c07603e3d6560ad057e35a021d0f5ffc8b1643 -- luaui/Widgets/gui_controller_camera_test.lua
git restore --source=c5c07603e3d6560ad057e35a021d0f5ffc8b1643 -- luaui/Include/controller_native_targeting.lua
git restore --source=c5c07603e3d6560ad057e35a021d0f5ffc8b1643 -- luaui/Include/controller_native_command_owner.lua
git restore --source=c5c07603e3d6560ad057e35a021d0f5ffc8b1643 -- native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua
```

Commit any intentional restoration normally. Do not force-push or reset the experimental branch.

## Create a temporary recovery branch

```powershell
git switch -c recovery/v0.8-pre-v06-restore c5c07603e3d6560ad057e35a021d0f5ffc8b1643
```

Alternatively, inspect it without moving the active branch:

```powershell
git worktree add ..\BAR_Controller_Companion-pre-v06 c5c07603e3d6560ad057e35a021d0f5ffc8b1643
```

## Why the targeting experiment is replaced

Repeated native mouse-owner, owner-session, and hybrid completed-shape adapters did not make Fight, Patrol, Attack, Area Mex, Smart Area Reclaim, area Reclaim, or Disassemble radius reliable in live controller use. They also introduced competing A/X consumers and command ownership spread across the camera, Order Menu, and command-specific widgets. The restore returns gesture and input ownership to the proven v0.6 controller path while retaining the current native command data and visual integrations.
