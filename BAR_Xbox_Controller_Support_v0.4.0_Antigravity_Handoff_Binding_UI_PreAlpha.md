# BAR Xbox Controller Support v0.4.0 Antigravity Handoff

## 1. Current Project State

Current production baseline:

```text
BAR Xbox Controller Support v0.3.7
Recoil 2025.06.24 Compatibility
```

Current development checkpoint:

```text
v0.4.0 pre-alpha in-game binding editor
```

The production controller gameplay widget remains `gui_controller_camera_test.lua`. The new binding editor has been added as a separate LuaUI widget, `gui_controller_bindings_ui.lua`, and uses the stable `WG.BARControllerSupport` API exposed by the gameplay widget. The binding editor is functional enough for pre-alpha testing, but it needs a layout/layering polish pass before release packaging.

## 2. Important Paths

Production repo:

```text
C:/Users/kaili/AppData/Local/Programs/Beyond-All-Reason/data/games/BAR.sdd
```

Production branch:

```text
controller-support-current-master-engine-shim
```

Important files:

```text
luaui/Widgets/gui_controller_camera_test.lua
luaui/Widgets/gui_controller_bindings_ui.lua
BAR_Xbox_Controller_Support_v0.3.8_Checkpoint_Queue_Fix_and_Binding_UI_Prototype.md
BAR_Xbox_Controller_Support_AI_Continuation_Pack_v0.3.8_QUEUE_FIX_BINDING_UI_PROTOTYPE.zip
```

Browser prototype source, if available:

```text
C:/Users/kaili/Dev/BAR_Controller_Bindings_UI_Prototype/
```

## 3. Commit History / Known Good Commits

Queue-removal working fix:

```text
fe61330f8ffc1c08b779a1573f27e445827f1520
```

v0.3.8 checkpoint/docs:

```text
a19b050b
```

Pre-alpha in-game binding editor:

```text
d0a466f8fae79d91f7246597c2138fff594df568
```

## 4. What Works Now

Current manual test results for `gui_controller_bindings_ui.lua`:

- UI opens with `/luaui bar_controller_bindings`: pass.
- Gameplay inputs are blocked while the binding editor is open: pass.
- Category navigation with D-pad/arrow keys: pass.
- Camera Pitch Modifier highlights only LB, not face-button B: pass.
- Zoom Camera highlights Right Stick Y, not face-button Y: pass.
- Rebind one harmless action: pass.
- Reset that action: pass.
- Close with B/Escape and controller gameplay resumes: pass.

Important behavior preserved:

- `gui_controller_camera_test.lua` gameplay logic was not rewritten for the binding editor.
- The binding editor calls `WG.BARControllerSupport.SetBindingUIOpen(true)` while open.
- The binding editor calls `WG.BARControllerSupport.SetBindingUIOpen(false)` when closed or shut down.
- Highlighting uses exact canonical control IDs, not substring matching.

## 5. Current UI Overlap Problem

The binding UI works, but the visual layout is overlapped by other BAR UI:

- Minimap overlaps the left side.
- Top HUD/menu elements overlap the top area.
- A layout/layering polish pass is needed next.

The next pass should focus only on `gui_controller_bindings_ui.lua`.

## 6. Next Antigravity Task

Recommended next task:

```text
Single-file UI polish only: luaui/Widgets/gui_controller_bindings_ui.lua
```

Specific requested changes:

1. Increase `widget:GetInfo().layer` for `gui_controller_bindings_ui.lua`, ideally to a very high value like `1000000`.
2. Add a safe-area layout mode to avoid minimap/top HUD even if layer ordering does not fully solve it.
3. Add constants:

```lua
USE_SAFE_AREA_LAYOUT = true
SAFE_LEFT_MARGIN = 285
SAFE_TOP_MARGIN = 80
SAFE_RIGHT_MARGIN = 20
SAFE_BOTTOM_MARGIN = 40
```

4. Draw the editor inside:

```lua
x1 = SAFE_LEFT_MARGIN
y1 = SAFE_BOTTOM_MARGIN
x2 = viewSizeX - SAFE_RIGHT_MARGIN
y2 = viewSizeY - SAFE_TOP_MARGIN
```

5. Keep fullscreen mode available by changing `USE_SAFE_AREA_LAYOUT` to false.
6. Move the close button inside the binding editor safe panel.
7. Make tabs fit inside the safe width, wrapping or shrinking if needed.
8. Preserve all currently working behavior.

## 7. Guardrails / Do Not Touch

Do not modify:

- `gui_controller_camera_test.lua`
- engine files
- release files
- installer files
- prototype repo
- gameplay logic
- binding behavior

Do not rewrite the binding editor. This is a polish pass, not an architecture pass.

## 8. Validation Commands

Run from:

```text
C:/Users/kaili/AppData/Local/Programs/Beyond-All-Reason/data/games/BAR.sdd
```

Commands:

```powershell
luac -p luaui/Widgets/gui_controller_bindings_ui.lua
luac -p luaui/Widgets/gui_controller_camera_test.lua
git diff --check
git status --short --branch
```

Also check UTF-8 BOM status for touched files:

```powershell
$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path 'luaui/Widgets/gui_controller_bindings_ui.lua'))
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { 'BOM present' } else { 'No UTF-8 BOM' }
```

## 9. Manual Test Checklist

1. Launch BAR.
2. Ensure `gui_controller_camera_test.lua` is enabled.
3. Enable/load `gui_controller_bindings_ui.lua`.
4. Open the binding UI with `/luaui bar_controller_bindings`.
5. Verify gameplay inputs are blocked while the UI is open.
6. Verify the UI is not overlapped by minimap or top HUD after the safe-area polish.
7. Navigate categories with D-pad and arrow keys.
8. Select `Camera -> Camera Pitch Modifier`.
9. Confirm only LB highlights, not face-button B.
10. Select `Zoom Camera`.
11. Confirm Right Stick Y does not highlight face-button Y.
12. Rebind one harmless action.
13. Reset that action.
14. Close with B/Escape.
15. Verify controller gameplay resumes.

## 10. Recommended Next Prompt for Antigravity

```text
You are continuing BAR Xbox Controller Support v0.4.0 pre-alpha.

Only edit:
luaui/Widgets/gui_controller_bindings_ui.lua

Do not edit:
gui_controller_camera_test.lua
engine files
installer files
release files
prototype repo
gameplay logic
binding behavior

Goal:
Perform a single-file UI layout/layering polish pass for the in-game controller binding editor.

Current status:
- The binding UI opens with /luaui bar_controller_bindings.
- Gameplay inputs are blocked while open.
- D-pad/keyboard category navigation works.
- Rebind/reset works.
- Camera Pitch Modifier highlights only LB.
- Zoom Camera highlights Right Stick Y without highlighting face-button Y.
- Closing resumes controller gameplay.

Current problem:
The UI is overlapped by BAR UI:
- minimap overlaps the left side
- top HUD/menu overlaps the top area

Required changes:
1. Increase widget:GetInfo().layer to a very high value, ideally 1000000.
2. Add safe-area layout constants:
   USE_SAFE_AREA_LAYOUT = true
   SAFE_LEFT_MARGIN = 285
   SAFE_TOP_MARGIN = 80
   SAFE_RIGHT_MARGIN = 20
   SAFE_BOTTOM_MARGIN = 40
3. Draw the editor inside:
   x1 = SAFE_LEFT_MARGIN
   y1 = SAFE_BOTTOM_MARGIN
   x2 = viewSizeX - SAFE_RIGHT_MARGIN
   y2 = viewSizeY - SAFE_TOP_MARGIN
4. Keep fullscreen available by setting USE_SAFE_AREA_LAYOUT to false.
5. Move close button inside the safe panel.
6. Make tabs fit inside the safe width by wrapping or shrinking if needed.
7. Preserve all existing behavior.

Validation:
luac -p luaui/Widgets/gui_controller_bindings_ui.lua
luac -p luaui/Widgets/gui_controller_camera_test.lua
git diff --check
check no UTF-8 BOM

Commit message:
Polish controller bindings UI safe-area layout
```
