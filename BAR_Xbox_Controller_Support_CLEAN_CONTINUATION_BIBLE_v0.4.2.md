# BAR Xbox Controller Support — Clean Continuation Bible v0.4.2

**For AI Assistants and Future Contributors**

This document is the authoritative handoff briefing for the BAR Xbox Controller Support project at v0.4.2. Read this entire file before making any changes. Do not modify engine files. Do not implement Area Mex full vanilla behavior. Preserve all working features.

---

## 1. Project Overview

This is a community-driven project adding Xbox controller support to **Beyond All Reason (BAR)**, a real-time strategy game built on the Spring/Recoil engine. The project consists of:

1. **Custom Recoil Engine** (`recoil_2025.06.24-controller-support-pr2985-win64.zip`): A custom-compiled engine build that exposes controller C++ APIs (PR #2985) not present in the stock engine. This engine is hosted separately at: `https://github.com/UnderarmCape/controllersupport-RecoilEngine-attempt-01`

2. **LuaUI Widgets** (in this repository): Three Lua widgets that read controller input from the engine API and implement all gameplay behaviors.

### Repository
- **URL**: `https://github.com/UnderarmCape/underarmcape-bar-controller-support-attempt-01`
- **Active Branch**: `controller-support-current-master-engine-shim`
- **Latest Release Tag**: `controller-support-v0.4.2-smartx-calibrated`

---

## 2. Widget Architecture

### `luaui/Widgets/gui_controller_camera_test.lua` — Main Controller Widget

This is the primary widget (~11,700 lines). It handles all controller input processing, camera control, and gameplay command issuing.

**Key global state tables:**
- `ControllerCameraTestSettings` — all user-configurable settings (deadzone, sensitivity, hold times, etc.)
- `ControllerCameraTestBindings` — button-to-action binding map
- `ControllerCameraTestDragCommand` — drag/placement command state
- `ControllerCameraTestAreaSelect` — Hold A brush selection state
- `ControllerCameraTestBuildMenu` — build/factory radial state
- `ControllerCameraTestTacticalMenu` — tactical command radial state
- `ControllerCameraTestControlGroups` — control group state
- `ControllerCameraTestSettingsUI` — legacy settings UI state (still used for `SettingsUI.open` checks throughout)

**Key Smart X functions:**
- `ControllerCameraTestTrySmartAssistedCommand(wx, wy, wz)` — entry point for Smart X press
- `ControllerCameraTestFindAssistedSmartTarget(wx, wy, wz, selectedUnits)` — finds the best smart target
- `ControllerCameraTestClassifySmartTarget(target)` — classifies a target into command type
- `attemptContextCommand(wx, wy, wz)` — issues the command or triggers no-Move guard

**Key Hold A functions:**
- `ControllerCameraTestUpdateAreaSelect(dt)` — updates live brush selection
- `ControllerCameraTestDrawAreaSelect()` — draws the 3D ground ring highlight
- `ControllerCameraTestCancelAreaSelect(reason)` — cancels selection

**Key Y Do Next functions:**
- `ControllerCameraTestIsQueueFrontModifierActive()` — returns true when Y is held
- `ControllerCameraTestIsQueueModifierActive()` — returns true when RT is held
- `issueOrderToSelection(cmdID, params, opts)` — wraps command with `{"alt","shift"}` when Y held

### `luaui/Widgets/gui_controller_bindings_ui.lua` — Bindings UI Widget

The separate settings/presets UI widget. Communicates with the main widget via `WG.BARControllerBindingsUI`. Provides:
- Preset selection (Balanced RTS, Build-First Commander)
- Individual binding remapping
- Settings adjustment UI

### `luaui/Widgets/gui_controller_smartx_mouse_audit.lua` — SmartX Mouse Audit Widget

**DISABLED BY DEFAULT** (`enabled = false` in `GetInfo()`).

A read-only diagnostic overlay that observes vanilla mouse smart/context behavior. Used to calibrate Smart X against baseline mouse behavior. Features:
- Hover target type/name display
- Mouse world position
- Nearest mex spot distance (via `WG.resource_spot_finder`)
- Click-to-UnitCommand linking
- HUD overlay in top-right corner

Enable manually only when debugging:
```
/luaui enablewidget "Controller SmartX Mouse Audit"
```

---

## 3. Smart X Calibration — v0.4.2 Findings

This section documents the exact calibration results from the v0.4.2 work.

### Mex No-Move Radius

**Correct threshold: 55 elmos** (matching vanilla mouse behavior).

The original code used the `snap-build` radius (~160 elmos) for mex context-checking, causing an oversized deadzone. The fix was to use a 55-elmo context radius for the mex no-Move guard.

```lua
-- Correct mex no-move guard radius (55 elmos)
local MEX_CONTEXT_RADIUS = 55
```

### Exact Target Priority

Exact unit/feature/wreck targets must be evaluated **before** the nearby mex spot check. The ordering in `attemptContextCommand` must be:
1. Exact unit/feature under cursor → wins immediately
2. Nearby mex spot check (within 55 elmos) → no-Move guard or build mex
3. Fallback → Move

### Resurrect Command ID

- **Wrong**: `110` (Restore / terrain restore command) — matched because `"restore"` keyword was in the resurrect keyword list
- **Correct**: `125` (Resurrect) — use `Spring.FindUnitCmdDesc` with `"resurrect"` to get cmdID 125

**Key pattern** for finding resurrect command:
```lua
local function findCommandByKeyword(unitID, keyword)
    local cmds = Spring.GetUnitCmdDescs(unitID)
    if not cmds then return nil end
    for _, cmd in ipairs(cmds) do
        local name = (cmd.name or ""):lower()
        if name:find(keyword, 1, true) and not name:find("restore", 1, true) then
            return cmd.id
        end
    end
    return nil
end
```

### Reference Command IDs (v0.4.2 Baseline)

| Command | cmdID | Notes |
|---|---|---|
| Move | 10 | Standard move |
| Attack | 20 | |
| Guard | 25 | |
| Patrol | 30 | |
| Repair | 40 | |
| Reclaim | 90 | Wrecks/features/units |
| Resurrect | 125 | Wrecked units (not terrain restore!) |
| Build Mex (armmex) | -149 | Negative cmdID, unit-type specific |

---

## 4. Current Feature Status

### Confirmed Working (v0.4.2)

| Feature | Status | Notes |
|---|---|---|
| Smart X — Reclaim | ✅ Working | Con bot over wreck |
| Smart X — Resurrect | ✅ Working | Res bot over wreck, cmdID 125 |
| Smart X — Repair/Guard | ✅ Working | Damaged allied unit/building |
| Smart X — Build Mex | ✅ Working | Empty mex spot |
| Smart X — Mex no-Move radius | ✅ Calibrated | 55 elmo context radius |
| Smart X — Exact target priority | ✅ Fixed | Wreck beats nearby mex |
| Smart X — No-Move guard | ✅ Working | Protects mex/wreck/feature targets |
| Hold A area brush selection | ✅ Working | Accumulates mobile units |
| A + X filter radial | ✅ Working | All Mobile / Combat / Builders / Air |
| Y Do Next queue preservation | ✅ Working | `{"alt","shift"}` options |
| Compact build menu scaling | ✅ Working | Scale setting affects build menu |
| Build/factory radial (RB or Y) | ✅ Working | Per preset |
| Tactical radial | ✅ Working | |
| DGUN mode | ✅ Working | |
| Self-destruct | ✅ Working | Back/View + R3 + L3 |
| Camera move/rotate/zoom | ✅ Working | |
| Queue removal (L3/R3) | ✅ Working | |
| Control groups | ✅ Working | |

### Deferred / Known Issues

| Feature | Status | Notes |
|---|---|---|
| Area Mex full vanilla behavior | ⏸️ Deferred | Do NOT implement in next pass |
| Settings UI X/Y crash | ⏸️ Deferred | Non-blocker, defer unless trivially safe |
| Commander focus (Back/View + A + A) | ⚠️ Unreliable | Input shim issue, documented limitation |

---

## 5. Safety Rules for Future Contributors

> [!CAUTION]
> **Do NOT modify engine files.** The custom engine (`spring.exe` and related DLLs) must not be altered. Only LuaUI widgets should be changed.

> [!WARNING]
> **Do NOT implement Area Mex full vanilla behavior** until explicitly requested. Smart X handles individual mex spot building correctly. Full area mex is complex and could regress existing behavior.

> [!WARNING]
> **Do NOT perform broad rewrites.** Any cleanup must be provably safe. The `ControllerCameraTestSettingsUI` table is actively used throughout even though the legacy settings UI code was removed. Do not remove this table.

> [!NOTE]
> The `gui_controller_smartx_mouse_audit.lua` widget **must remain disabled by default** (`enabled = false` in `GetInfo()`). Never change this to `true`.

---

## 6. Architecture Notes

### WG Communication Pattern

The widgets communicate via the `WG` global table:

```lua
-- From gui_controller_bindings_ui.lua:
WG.BARControllerBindingsUI = {
    Toggle = function() ... end,
    Open = function() ... end,
    Close = function() ... end,
}

-- From gui_controller_camera_test.lua calls:
ControllerCameraTestToggleSettingsUI()  -- delegates to WG.BARControllerBindingsUI
```

### resource_spot_finder Integration

The SmartX Mouse Audit widget uses `WG.resource_spot_finder` for mex spot distance:

```lua
local rsf = WG.resource_spot_finder
if rsf and rsf.GetClosestMexSpot then
    local mx, mz, _ = rsf.GetClosestMexSpot(wx, wz)
    -- mx, mz are the closest mex spot world coordinates
end
```

The main widget does its own mex spot lookup using `api_resource_spot_builder` or the snap-build API.

### `safeCall` Pattern in Audit Widget

The audit widget uses `safeCall` wrappers to prevent runtime crashes:

```lua
local function safeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        Spring.Echo("[SmartXMouseAudit] Error: " .. tostring(result))
        return nil
    end
    return result
end
```

---

## 7. Git History Reference

| Commit | Description |
|---|---|
| `93b9d172` | Calibrate Smart X targeting against mouse audit |
| `1a48e78d` | Fix Smart X mouse audit widget runtime crash |
| `7942ebea` | Add Smart X mouse behavior audit widget |
| `9b83b1f2` | Fix Y insert queue preservation and brush selection |
| `d6f7e360` | Fix Y insert modifier and add live brush selection radial |
| `afd87548` | Fix Do Next insert modifier and bind it to LB |
| `e1155eb0` | Fix compact build menu scale on active gridmenu widget |
| `dfcf75c9` | Replace build menu MaxPosY override with compact scale API |

---

## 8. Recommended Next Work Items

In priority order (for the next AI continuation session):

1. **Manual test verification pass** — The user needs to run the v0.4.2 manual test checklist to confirm all features work in-game. No known regressions expected.

2. **Commander focus fix** — `Back/View + A + A` shortcut is unreliable due to input shim behavior. Investigate if the double-tap timing can be reliably detected.

3. **Settings UI X/Y crash** — Investigate and fix the crash that occurs in the settings UI reset path when X/Y are held. Only fix if trivially safe (nil guard).

4. **Area Mex full vanilla behavior** — Not yet implemented. When requested, implement full area mex drag placement matching vanilla mouse behavior. Requires careful integration with `api_resource_spot_builder`.

5. **Smart X further calibration** — If new issues are found during manual testing, use the SmartX Mouse Audit widget to gather baseline data before patching.

---

## 9. Manual Test Checklist (v0.4.2)

Run after installing v0.4.2 to verify all features:

**A. Launch BAR with custom controller-enabled engine.**

**B. Confirm widgets load** (check infolog.txt — no Lua errors):
- Controller Camera Test widget
- Controller Bindings UI widget

**C. Controller basics:**
- Camera move/rotate/zoom
- Build/factory radial
- Tactical radial
- DGUN mode
- Self-destruct (Back/View + R3 + L3)

**D. Smart X:**
- Con bot over wreck → Reclaim (cmdID 90)
- Res bot over wreck → Resurrect (cmdID 125)
- Damaged allied unit/building → Repair/Guard
- Built mex at ~40 elmos → No-Move guard active
- Built mex at ~75 elmos → Normal Move allowed
- Wreck exactly on mex spot → Wreck wins

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

*Generated: v0.4.2 SMARTX_CALIBRATED release*
*Branch: controller-support-current-master-engine-shim*
*Latest commit at generation: 93b9d172 (Calibrate Smart X targeting against mouse audit)*
