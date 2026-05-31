# BAR Xbox Controller Support v0.4.2 — Smart X Calibrated

This is a milestone release for the community-driven Beyond All Reason (BAR) Xbox Controller Support project.

> [!IMPORTANT]
> **CRITICAL ENGINE REQUIREMENT**: This controller support mod **REQUIRES** a custom controller-enabled BAR/Recoil engine compatibility layer build to function. The LuaUI widgets alone are **NOT** sufficient; they rely on controller-specific C++ APIs introduced in the custom engine. If you do not install the compatibility engine first using the automated installer inside this package, your controller inputs will not be recognized.

---

## 1. Release Classification

* **Milestone Release**: This is a normal public GitHub release, representing the current best, most advanced, and feature-rich build of the controller widgets and presets.
* **Active WIP**: Although this is the best public build, it is still a community work-in-progress. Expect some rough edges.
* **Earlier Baselines**: The **v0.4.1** and **v0.4.0** stable releases remain fully preserved on the GitHub releases page.

---

## 2. What's New in v0.4.2

### Smart X Calibration Fixes

This release fixes several Smart X (`smartAction`) targeting accuracy issues that were identified using the new SmartX Mouse Audit diagnostic widget:

| Issue | Root Cause | Fix |
|---|---|---|
| Oversized mex no-Move blocking radius | `snap-build` radius (160 elmos) was reused for mex context-checking | Corrected to 55 elmo context radius matching vanilla mouse behavior |
| Exact wreck/unit/building targets ignored near mex spots | Mex context check ran before exact-target evaluation | Reordered: exact targets now evaluated first, mex check only as fallback |
| Wrong Resurrect command ID | `"restore"` keyword matched terrain command (110) before Resurrect (125) | Corrected Resurrect command keywords and descriptor lookup to use cmdID 125 |

### Conservative Code Cleanup

* Removed permanently-dead legacy settings UI code block (`LEGACY_CONTROLLER_SETTINGS_UI_ENABLED = false`) — 25 lines of unreachable code eliminated without any behavioral change.

### New Diagnostic Tool (Disabled by Default)

* **SmartX Mouse Audit Widget** (`gui_controller_smartx_mouse_audit.lua`) — a read-only diagnostic overlay for observing vanilla mouse smart/context behavior. Useful for future calibration comparison. **Disabled by default.** Enable only when debugging:
  ```
  /luaui enablewidget "Controller SmartX Mouse Audit"
  ```

---

## 3. Target Installation Order (Summary)

This release package contains both the required widgets and the installer for the custom engine compatibility build:

1. **Engine**: Open the `required_engine_installer/` folder and run `Install_BAR_Controller_Support_v0.4.2_SMARTX_CALIBRATED.bat` to automatically download the compiled custom engine, back up active stock files, configure devmode, and disable cardinal camera locks.
2. **Widgets**: The installer clones the `controller-support-current-master-engine-shim` branch directly, which includes all three controller widgets:
   - `gui_controller_camera_test.lua` — main controller logic
   - `gui_controller_bindings_ui.lua` — bindings/settings UI
   - `gui_controller_smartx_mouse_audit.lua` — diagnostic widget (disabled by default)
3. **Launch BAR**: Select **Settings > Developer**, choose **Beyond All Reason Dev** in the Singleplayer dropdown, and configure your presets!

---

## 4. Feature Highlights

* **Smart X Context Commands**: Controller right-stick cursor + X button issues smart context commands — Reclaim, Resurrect, Repair, Guard, Build Mex — with calibrated targeting matching vanilla mouse behavior.
* **Smart X No-Move Guard**: Prevents accidental Move orders over protected smart targets (wrecks, mex spots, damaged allied units/buildings).
* **Binding Presets System**: Includes `Balanced RTS` and `Build-First Commander` preset configurations.
* **Build / Factory Radial Menu**: Map unit and structure factory blueprints onto a convenient visual radial menu.
* **Shift-Style Command Queuing (RT)**: Holding **RT** appends commands to queue end.
* **Do Next / Insert Front Command (Y or RB)**: Prepend urgent commands to the front of the queue with queue preservation.
* **Hold A Live Brush Selection**: Hold **A** to accumulate mobile units in a live radius brush. Units are added as the brush touches them.
* **A + X Selection Filter Radial**: While holding **A**, press **X** to open a filter radial (All Mobile / Combat / Builders / Air).
* **RT + A & RT + X Append Placement**: Queue multiple building placements without interrupting production.
* **Grid Placement Lock (LB)**: Holding **LB** during placement locks coordinates to the grid.
* **LB Tap Placement Pattern Cycle**: Tapping **LB** cycles through layout patterns.
* **Split Queue Removal (L3 / R3)**:
  * **Left Stick Click (L3)**: Deletes the current/next queued command.
  * **Right Stick Click (R3)**: Deletes the last queued command.
* **Command Layer (Back/View)**: Toggles the command HUD and quick tactical overlays.
* **Group Layer (Start/Menu)**: Switch to the Group layer to assign or recall unit groups.

---

## 5. Preset Mappings Overview

### Balanced RTS Preset
* **A** = Select / Confirm / Place
* **B** = Cancel / Clear / Deselect
* **X** = Move / Smart Context Command
* **Y** = Do Next / Insert Front Command Modifier
* **RB** = Build / Factory Radial Menu
* **RT** = Append Queue (Shift-style Queue)
* **LT** = Camera Speed Modifier
* **LB** = Camera Pitch / Grid & pattern controls (during placement)
* **Back/View** = Command Layer Modifier
* **Start/Menu** = Group Layer Modifier
* **Left Stick Click (L3)** = Remove Current/Next Queue Item
* **Right Stick Click (R3)** = Remove Last Queue Item

### Build-First Commander Preset
* **A** = Select / Confirm / Place
* **B** = Cancel / Clear / Deselect
* **X** = Move / Smart Context Command
* **RB** = Build / Factory Radial Menu
* **Y** = Do Next / Insert Front Command Modifier
* **RT** = Append Queue (Shift-style Queue)
* **LT** = Camera Speed Modifier
* **LB** = Camera Pitch / Grid & pattern controls (during placement)
* **Back/View** = Command Layer Modifier
* **Start/Menu** = Group Layer Modifier
* **Left Stick Click (L3)** = Remove Current/Next Queue Item
* **Right Stick Click (R3)** = Remove Last Queue Item

---

## 6. Smart X Behavior Reference (v0.4.2)

| Scenario | Expected Behavior |
|---|---|
| Con bot reticle over wreck | Reclaim (cmdID 90) |
| Res bot reticle over wreck | Resurrect (cmdID 125) |
| Reticle over damaged allied unit/building | Repair (cmdID 40) or Guard (cmdID 25) |
| Reticle over empty mex spot | Build Mex (negative cmdID) |
| Reticle within ~55 elmos of built mex | No-Move guard (protected) |
| Reticle over wreck that is near a mex spot | Wreck target wins over mex |
| Reticle over open ground, no nearby targets | Move (cmdID 10) |

---

## 7. Manual Test Checklist (For User — Not Yet Verified)

> [!NOTE]
> The following checklist has **NOT been verified** by the release packager. The user should run this after installing v0.4.2.

**A. Launch BAR with custom controller-enabled engine.**

**B. Confirm widgets load** (no Lua errors in infolog):
- `gui_controller_camera_test.lua`
- `gui_controller_bindings_ui.lua`

**C. Controller basics:**
- Camera move/rotate/zoom
- Build/factory radial
- Tactical radial
- DGUN mode
- Self-destruct (Back/View + R3 + L3)

**D. Smart X:**
- Con bot over wreck → Reclaim
- Res bot over wreck → Resurrect
- Damaged allied unit/building → Repair/Guard as appropriate
- Built mex at ~40 elmos → No-Move guard active
- Built mex at ~75 elmos → Normal Move allowed
- Wreck exactly on mex spot → Wreck wins, not mex

**E. Y Do Next:**
- Queue 4 moves
- Hold Y + issue new move → new move executes next, old queue remains

**F. Hold A brush:**
- Brush selects mobile units as touched
- A + X filter radial works (All Mobile / Combat / Builders / Air)

**G. Compact build menu:**
- Scale setting changes build menu size

**H. Optional SmartX Mouse Audit (debugging only):**
```
/luaui enablewidget "Controller SmartX Mouse Audit"
```

---

## 8. Documented Known Issues

* **Commander Focus Utility**: The `Back/View + A + A` shortcut (focus/select Commander) is currently unreliable. This is a documented limitation for a future release.
* **Settings UI X/Y Crash**: In certain edge cases the settings UI reset may crash. This is a known non-blocker deferred to a future release.
* **Area Mex**: Full vanilla Area Mex behavior is deferred. Smart X handles individual mex spot building correctly.
