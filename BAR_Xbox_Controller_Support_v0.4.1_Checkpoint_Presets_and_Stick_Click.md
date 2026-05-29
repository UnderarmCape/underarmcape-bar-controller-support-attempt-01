# BAR Xbox Controller Support v0.4.1 WIP Checkpoint — Presets & Stick-Click Controls

This checkpoint documents the in-progress v0.4.1 work for Beyond All Reason (BAR) Xbox Controller Support,
building directly on top of the stable v0.4.0 pre-alpha Binding UI release.

---

## 1. Release Status

| Field | Value |
|---|---|
| Version | v0.4.1 WIP Pre-Release |
| Based On | v0.4.0 pre-alpha (commit `bc4ac238`) |
| WIP HEAD | `b410ee7a` |
| Branch | `controller-support-current-master-engine-shim` |
| Status | **In Progress — Not Stable** |

> [!WARNING]
> This is a **WIP pre-release only**. The stable v0.4.0 pre-alpha release is preserved at commit `bc4ac238`.
> Do not overwrite the v0.4.0 GitHub release or tag with v0.4.1 WIP assets.

---

## 2. What Changed Since v0.4.0

### 2.1 New Binding Definitions

Three new input actions were added to the binding definition table in `gui_controller_camera_test.lua`:

| Action Name | Label | Default | Group |
|---|---|---|---|
| `insertNextCommandModifier` | Do Next / Insert Command Modifier | `back` | Queue |
| `removeQueuedCommand` | Remove Current/Next Queue Item | `leftStickClick` | Queue |
| `removeLastQueuedCommand` | Remove Last Queue Item | `rightStickClick` | Queue |

> [!NOTE]
> `insertNextCommandModifier` replaces the former `queueModifier` action. The old `queueModifier` binding
> behavior (LT as queue toggle) has been removed. LT is now exclusively the camera pan/zoom speed modifier.

### 2.2 Left Stick Click / Right Stick Click Support

- `leftStickClick` (controller button ID 7) and `rightStickClick` (button ID 8) are now recognized as bindable inputs.
- Both appear in the input name display table and are captured by the binding UI capture system.
- They are included in the bindable button enumeration list used for conflict detection and rebinding.

### 2.3 Queue Control Redesign

| Behavior | v0.4.0 | v0.4.1 WIP |
|---|---|---|
| Remove current/next queue item | Back/View tap | Left Stick Click (L3) |
| Remove last queue item | LT + Back/View | Right Stick Click (R3) |
| Insert command at front of queue | — | Back/View hold (`insertNextCommandModifier`) |
| LT role | Pan/zoom speed + queue modifier layer | **Camera pan/zoom speed only** |
| LB role | Camera pitch modifier | Camera pitch modifier (unchanged) |

### 2.4 Binding Presets System

A new **Presets** category has been added to the Bindings UI. Two presets are defined:

#### Balanced RTS Preset

Full mapping applied when this preset is activated:

| Action | Button |
|---|---|
| cancel | B |
| buildRadial | Y |
| commandLayer | RT |
| insertNextCommandModifier | Back/View |
| controlGroupModifier | RB |
| pitchModifier | LB |
| removeQueuedCommand | Left Stick Click |
| removeLastQueuedCommand | Right Stick Click |
| radialSelect | A |
| radialCancel | B |
| radialQuick | X |
| radialClose | Y |
| radialPrevPage | LB |
| radialNextPage | RB |
| place | A |
| placeStay | X |
| cancelPlacement | B |
| rotateBuildingLeft | D-pad Left |
| rotateBuildingRight | D-pad Right |
| spacingUp | D-pad Up |
| spacingDown | D-pad Down |
| patternPrev | LB |
| patternNext | RB |
| tacticalSelect | A |
| tacticalCancel | B |
| tacticalClose | Y |
| commandUp | D-pad Up |
| commandDown | D-pad Down |
| commandLeft | D-pad Left |
| commandRight | D-pad Right |
| idlePrev | D-pad Left |
| idleNext | D-pad Right |
| groupSlotUp | D-pad Up |
| groupSlotDown | D-pad Down |
| groupRecallOrAssign | D-pad Left |
| groupClear | B |

#### Build-First Commander Preset

Same as Balanced RTS with the following differences:

| Action | Balanced RTS | Build-First Commander |
|---|---|---|
| buildRadial | Y | **RB** |
| controlGroupModifier | RB | *(unset — removed to avoid RB conflict)* |
| radialClose | Y | **RB** |

### 2.5 Preset UI Behavior

- Presets appear as a top-level category in the Bindings UI (above all other categories).
- Selecting a preset and pressing **A/Enter** or clicking triggers a confirmation modal.
- Confirming applies all bindings in the preset map via `SetBinding`.
- The active preset name is tracked in `ControllerBindingsUI.currentPreset`.
- If any individual binding is changed after preset application, the status resets to `"Custom"`.
- Each preset's detail view shows the full mapping table and the current active/inactive status.

---

## 3. Known Issues / Open Work

> [!CAUTION]
> The following items are **not yet resolved** in this WIP state:

1. **Build menu not opening from presets**: The `buildRadial` action name may not match the correct internal
   command. The build radial/menu open action name needs to be diagnosed from the gameplay widget.
2. **`insertNextCommandModifier` / Do Next behavior**: The Back/View hold behavior for prepending commands
   to the front of the order queue is wired but not fully validated in-game for all order types.
3. **No stable in-game manual test pass**: v0.4.1 has not yet received a full manual test session.

---

## 4. Commit History (v0.4.1 WIP)

```text
b410ee7a  Clean up queue preset bindings
d1c377f0  Add controller binding presets and stick-click queue controls
```

These build on top of the v0.4.0 chain:

```text
bc4ac238  Set tuned bindings UI layout defaults        ← v0.4.0 pre-alpha stable
04551703  Add adjustable bindings UI layout settings safely with guarded scoping
3bf76d67  Revert "Add adjustable bindings UI layout settings"
9a9aaae5  Add adjustable bindings UI layout settings   ← (bad commit, reverted)
69ce2a3d  Widen bindings UI and show all binding definitions
40123b3d  Move controller settings into new bindings UI
```

---

## 5. Files Modified

| File | Role | Changes |
|---|---|---|
| `luaui/Widgets/gui_controller_bindings_ui.lua` | Bindings / Settings UI | Added Presets category, preset maps, preset detail view, modal confirm, preset status tracking |
| `luaui/Widgets/gui_controller_camera_test.lua` | Gameplay / Input Engine | Added L3/R3 button IDs, new binding definitions, queue split logic, `insertNextCommandModifier` wiring |

---

## 6. Validation

```powershell
luac -p luaui/Widgets/gui_controller_bindings_ui.lua
luac -p luaui/Widgets/gui_controller_camera_test.lua
git diff --check
```

All three pass clean as of HEAD `b410ee7a`.

---

## 7. Next Steps

Before this can be promoted to a stable v0.4.1 release, the following must be completed:

1. Diagnose and fix the correct internal action name for opening the build radial/menu.
2. Update preset maps if `buildRadial` action name is incorrect.
3. Move `insertNextCommandModifier` from Back/View to a less collision-prone button if needed.
4. Run a full in-game manual test session against the checklist below.
5. Confirm L3 removes current/next queue item.
6. Confirm R3 removes last queue item.
7. Confirm Back/View hold correctly inserts command at front of queue.
8. Confirm applying presets works with the confirmation modal.
9. Confirm preset status displays correctly (Active / Inactive / Custom).

---

## 8. Manual Test Checklist (v0.4.1 Target)

- [ ] UI opens with `/luaui bar_controller_bindings`
- [ ] Presets category is listed first in the category list
- [ ] `Balanced RTS` preset shows correct mapping table in detail view
- [ ] `Build-First Commander` preset shows correct mapping table in detail view
- [ ] Applying a preset triggers confirmation modal
- [ ] Confirming applies all bindings and shows toast
- [ ] Active preset status shows "Active" for the applied preset
- [ ] Changing a binding resets status to "Custom"
- [ ] Left Stick Click (L3) removes current/next queue item in gameplay
- [ ] Right Stick Click (R3) removes last queue item in gameplay
- [ ] Back/View hold triggers Do Next / Insert Command Modifier
- [ ] LT no longer acts as a queue modifier
- [ ] LB still acts as camera pitch modifier
- [ ] Build radial/menu opens correctly from the bound button
- [ ] Settings tab opens without crash
- [ ] Closing UI resumes gameplay inputs
