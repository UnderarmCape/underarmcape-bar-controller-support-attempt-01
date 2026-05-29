# BAR Xbox Controller Support v0.4.1 Antigravity Handoff

## 1. Current Project State

Stable baseline:

```text
BAR Xbox Controller Support v0.4.0 pre-alpha
Do not overwrite or retag as v0.4.1.
```

Current WIP prerelease:

```text
BAR Xbox Controller Support v0.4.1 pre-alpha
Branch: controller-support-current-master-engine-shim
Latest code commit: 9a2c36eb
```

The production gameplay widget is:

```text
luaui/Widgets/gui_controller_camera_test.lua
```

The in-game bindings/settings UI is:

```text
luaui/Widgets/gui_controller_bindings_ui.lua
```

## 2. What Works Now

Reported live/manual test state before this handoff:

- RT + A placement works and continues placement.
- RT + X placement still works.
- RT append placement does not interrupt the current build item.
- L3/R3 queue removal works during active placement.
- L3/R3 queue removal works outside placement.
- Back/View + A + A focuses/teleports to the commander and selects it.
- Build-First Commander: RB opens build/factory radial.
- Balanced RTS: Y opens build/factory radial.
- RB no longer cycles placement modes.
- LB hold forces Grid placement.
- LB tap cycles placement modes.
- Build-First Commander: Y works as Do Next / Insert.
- Balanced RTS: RB works as Do Next / Insert.
- LT remains camera speed only.
- LB remains camera pitch outside placement.

## 3. Latest v0.4.1 Changes

### Back/View Command Layer

Both presets now map:

```text
commandLayer = Back/View
```

Back/View command-layer coexistence is handled by a small command-layer A double-tap path:

- Back/View hold opens command layer.
- Back/View + A first tap arms commander utility timing.
- Back/View + A + A focuses/selects the commander.
- Other command-layer inputs such as Back/View + B/X/Y/D-pad continue through the command layer and do not trigger commander utility.

### Start/Menu Group Layer

Start/Menu is the group layer. Start/Menu + A/B/X/Y is intentionally not used.

```text
Start/Menu + D-pad Up    = Next group slot
Start/Menu + D-pad Down  = Previous group slot
Start/Menu + D-pad Left  = Recall current group slot
Start/Menu + D-pad Right = Assign same-type/future units to current group slot
Start/Menu + L3          = Clear current group slot
```

### Same-Type / Future Group Assignment

Start/Menu + D-pad Right now uses same-type group assignment:

- Selected unit definitions are preferred.
- All current owned units of the selected type(s) are assigned.
- Future finished units of those type(s) are auto-added through controller-widget metadata.
- If BAR's `WG.autogroup.addCurrentSelectionToAutogroup` exists, the assignment is mirrored into BAR's native Auto Group widget.
- Native Auto Group mirroring is skipped when the source is reticle/idle instead of selection to avoid assigning a mismatched selected type.

## 4. Current Presets

### Balanced RTS

```text
A    = Select / Confirm
B    = Cancel / Clear
X    = Move / Smart Move
Y    = Build / Factory Radial
Back = Command Layer Modifier
Back + A + A = Commander focus/select
LT   = Camera speed modifier only
LB   = Camera pitch; placement LB tap pattern / hold Grid
RT   = Append Queue / Shift-style queue
RB   = Do Next / Insert Command Modifier
L3   = Remove current/next queue item
R3   = Remove last queue item
D-pad Left/Right = Previous/next idle unit
Start + D-pad/L3 = Group layer
```

### Build-First Commander

```text
A    = Select / Confirm
B    = Cancel / Clear
X    = Move / Smart Move
RB   = Build / Factory Radial
Back = Command Layer Modifier
Back + A + A = Commander focus/select
LT   = Camera speed modifier only
LB   = Camera pitch; placement LB tap pattern / hold Grid
RT   = Append Queue / Shift-style queue
Y    = Do Next / Insert Command Modifier
L3   = Remove current/next queue item
R3   = Remove last queue item
D-pad Left/Right = Previous/next idle unit
Start + D-pad/L3 = Group layer
```

## 5. Guardrails

Do not modify:

- Recoil engine files
- Installer files unless explicitly asked
- v0.4.0 release files/assets
- Stable v0.4.0 docs
- `common/constants.lua`

Do not:

- Reassign LT as a queue modifier.
- Re-enable RB placement cycling.
- Use Start/Menu + A/B/X/Y for group controls.
- Rewrite the gameplay controller widget.
- Duplicate gameplay logic in the bindings UI.

## 6. Validation Commands

Run from:

```text
C:/Users/kaili/AppData/Local/Programs/Beyond-All-Reason/data/games/BAR.sdd
```

```powershell
luac -p luaui/Widgets/gui_controller_bindings_ui.lua luaui/Widgets/gui_controller_camera_test.lua
git diff --check -- luaui/Widgets/gui_controller_bindings_ui.lua luaui/Widgets/gui_controller_camera_test.lua
git status --short --branch
```

UTF-8 BOM check:

```powershell
$files = @('luaui/Widgets/gui_controller_bindings_ui.lua','luaui/Widgets/gui_controller_camera_test.lua')
foreach ($file in $files) {
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $file))
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    "$file BOM=$hasBom"
}
```

## 7. Manual Test Checklist

1. Apply Build-First Commander preset.
2. Select constructor.
3. Press RB. Expected: build/factory radial opens.
4. Select Windmill.
5. Hold RT + A to place multiple windmills. Expected: append placement continues and does not interrupt current build.
6. Hold RT + X during placement. Expected: append placement still works.
7. During placement, press L3. Expected: remove current/next queue item.
8. During placement, press R3. Expected: remove last queue item.
9. Hold LB during placement. Expected: Grid placement forced.
10. Tap LB during placement. Expected: placement pattern cycles.
11. Confirm RB does not cycle placement pattern.
12. Hold Back/View and use command layer behavior. Expected: command layer works.
13. Back/View + A + A. Expected: commander is focused/teleported to and selected.
14. Start/Menu + D-pad Up/Down. Expected: group slot changes.
15. Start/Menu + D-pad Left. Expected: current group recalled.
16. Start/Menu + D-pad Right on a selected unit type, such as Tick. Expected: all current same-type units are assigned and future units are auto-added if supported.
17. Start/Menu + L3. Expected: current group cleared.
18. Apply Balanced RTS preset.
19. Press Y with constructor selected. Expected: build/factory radial opens.
20. Confirm RT append, RB insert, LB grid/pattern, L3/R3 removal, and Back/View command layer still work.
21. Close UI and confirm gameplay resumes.

## 8. Recommended Next Work

1. Publish v0.4.1 as a prerelease only, not stable.
2. Ask testers to apply/reset presets after installing.
3. Collect live feedback on Back/View command layer ergonomics.
4. Verify same-type/future group assignment with `Auto Group` enabled and disabled.
5. Keep v0.4.0 available as the stable pre-alpha fallback.
