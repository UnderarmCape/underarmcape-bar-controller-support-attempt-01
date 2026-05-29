# BAR Xbox Controller Support v0.4.1 Antigravity Handoff

## 1. Current Project State

Current stable baseline:

```text
BAR Xbox Controller Support v0.4.0 pre-alpha
Binding UI Pre-Alpha
Commit: bc4ac238
```

Current WIP development checkpoint:

```text
v0.4.1 WIP — Presets & Stick-Click Controls
Commit: b410ee7a
```

The production controller gameplay widget remains `gui_controller_camera_test.lua`.
The binding editor is `gui_controller_bindings_ui.lua`.

The v0.4.1 WIP adds:
- Left Stick Click (L3) and Right Stick Click (R3) as bindable inputs.
- Split queue removal: L3 = remove current/next, R3 = remove last.
- `insertNextCommandModifier` (Back/View hold) for inserting commands at front of queue.
- A Presets category with `Balanced RTS` and `Build-First Commander` preset maps.
- LT is now **camera pan/zoom speed only** — no longer a queue modifier.

---

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
BAR_Xbox_Controller_Support_v0.4.0_Checkpoint_Binding_UI_PreAlpha.md
BAR_Xbox_Controller_Support_v0.4.1_Checkpoint_Presets_and_Stick_Click.md
BAR_Xbox_Controller_Support_AI_Continuation_Pack_v0.4.1_PRESETS_STICK_CLICK_WIP.zip
```

---

## 3. Commit History / Known Good Commits

v0.4.0 stable baseline (do not overwrite this):

```text
bc4ac238  Set tuned bindings UI layout defaults
```

v0.4.1 WIP commits (on top of v0.4.0 chain):

```text
b410ee7a  Clean up queue preset bindings         ← current WIP HEAD
d1c377f0  Add controller binding presets and stick-click queue controls
```

---

## 4. Binding Definitions Added in v0.4.1

New actions in `gui_controller_camera_test.lua`:

| Action | Label | Default Button | Group |
|---|---|---|---|
| `insertNextCommandModifier` | Do Next / Insert Command Modifier | `back` | Queue |
| `removeQueuedCommand` | Remove Current/Next Queue Item | `leftStickClick` | Queue |
| `removeLastQueuedCommand` | Remove Last Queue Item | `rightStickClick` | Queue |

New button IDs added to the controller button map:

```lua
leftStickClick  = 7   -- L3
rightStickClick = 8   -- R3
```

---

## 5. What Works Now (v0.4.1 WIP)

- Presets category added and shows in the Bindings UI.
- `Balanced RTS` preset applies 35 bindings on confirm.
- `Build-First Commander` preset applies a similar layout with `buildRadial` on RB.
- Preset status tracks `Active` / `Inactive` / `Custom` correctly.
- L3 and R3 are bindable inputs, captured by the rebind system, and shown in display names.
- `insertNextCommandModifier` definition exists with correct label and default.
- LT no longer acts as queue modifier.
- Settings tab opens without crash.
- All 37+ bindings shown in the Bindings UI (including new Queue group).

---

## 6. Known Issues / Open Work

### Critical
- **Build radial action name is unverified**: `buildRadial` in the preset map may not match the actual
  internal action name used by the gameplay widget to open the build menu/radial. The build menu does not
  open from preset application. This needs diagnosis.

### Design
- **`insertNextCommandModifier` on Back/View**: Back/View is also used for `removeQueuedCommand` when not
  held. This creates a potential collision. Consider moving `insertNextCommandModifier` to a different button
  (e.g., LT hold, or a dedicated combo).

### Testing
- **No full in-game test pass done on v0.4.1**: Only partial validation was done. A full manual test session
  is required before v0.4.1 can be promoted to stable.

---

## 7. Guardrails / Do Not Touch

Do not modify:
- Engine files
- Release files / installer files
- The v0.4.0 GitHub release or its zip
- `BAR_Xbox_Controller_Support_v0.4.0_*` checkpoint and handoff docs
- L3 queue removal logic (confirmed working — do not rewrite)
- Queue-removal behavior in `gui_controller_camera_test.lua` unless fixing a diagnosed bug

Do not:
- Re-add LT as a queue modifier
- Move camera pitch off LB unless explicitly requested
- Rewrite the preset apply logic (it works, only preset maps may need updating)

---

## 8. Validation Commands

Run from:

```text
C:/Users/kaili/AppData/Local/Programs/Beyond-All-Reason/data/games/BAR.sdd
```

```powershell
luac -p luaui/Widgets/gui_controller_bindings_ui.lua
luac -p luaui/Widgets/gui_controller_camera_test.lua
git diff --check
git status --short --branch
```

UTF-8 BOM check:

```powershell
$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path 'luaui/Widgets/gui_controller_bindings_ui.lua'))
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { 'BOM present' } else { 'No UTF-8 BOM' }
```

---

## 9. Next Task for Antigravity

### Priority 1: Diagnose Build Radial Action Name

Inspect `gui_controller_camera_test.lua` for the exact action name used to open the build radial or build menu:

- Search for `buildRadial`, `build_radial`, `buildMenu`, or similar.
- Search for the WG API exposure that triggers the build menu to open.
- Find what button/action is checked in the gameplay loop that opens build placement or the build radial UI.
- Report the correct action name to use in the preset maps.

Do NOT change gameplay behavior yet. Only diagnose and report.

### Priority 2: Fix Preset Build Mappings (After Diagnosis)

Once the correct action name is confirmed:
- Update `buildRadial` key in both preset maps to use the correct action name.
- Re-run `luac -p` validation.
- Commit with message: `Fix build radial action name in presets`

### Priority 3: Re-evaluate insertNextCommandModifier Button Assignment

- Evaluate whether Back/View as `insertNextCommandModifier` conflicts with `removeQueuedCommand`.
- If conflicting, propose alternative button assignment.
- Do not change without user approval.

---

## 10. Recommended Next Prompt for Antigravity

```text
You are continuing BAR Xbox Controller Support v0.4.1 WIP.

Repo:
C:/Users/kaili/AppData/Local/Programs/Beyond-All-Reason/data/games/BAR.sdd

Branch:
controller-support-current-master-engine-shim

Current WIP HEAD:
b410ee7a  Clean up queue preset bindings

Allowed files to modify:
- luaui/Widgets/gui_controller_camera_test.lua (diagnosis only first, then minimal fix if needed)
- luaui/Widgets/gui_controller_bindings_ui.lua (preset map fix only)

Do not modify:
- Engine files
- Release files
- Installer files
- Docs
- v0.4.0 stable release
- L3 queue removal logic (confirmed working)
- Camera/gameplay behavior

Current confirmed working:
- Presets category shows in Bindings UI.
- Balanced RTS and Build-First Commander presets apply bindings on confirm.
- L3 (leftStickClick) removes current/next queue item.
- R3 (rightStickClick) removes last queue item.
- LT is camera speed only.
- Settings tab opens without crash.

Known issue to fix:
- Build radial/menu does not open from preset-applied buildRadial binding.
- Need to diagnose the correct action name in gui_controller_camera_test.lua
  for the build menu open action.

Step 1: Inspect gui_controller_camera_test.lua for the correct build menu / build radial action name.
Step 2: Report what you find before making any changes.
Step 3: Only fix the preset maps in gui_controller_bindings_ui.lua once the correct name is confirmed.

Validation after any change:
luac -p luaui/Widgets/gui_controller_bindings_ui.lua
luac -p luaui/Widgets/gui_controller_camera_test.lua
git diff --check
```
