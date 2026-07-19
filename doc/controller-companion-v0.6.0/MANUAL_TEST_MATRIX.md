# v0.6.0 manual deployment and test matrix

## Development install (no package build)

Close BAR before copying. In PowerShell:

```powershell
$source = 'C:\Users\kaili\Dev\BAR_Controller_Companion\controller-mod\luaui\Widgets'
$target = 'C:\Users\kaili\AppData\Local\Programs\Beyond-All-Reason\data\LuaUI\Widgets'
$backup = Join-Path $target ('v060-test-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup
Copy-Item -LiteralPath (Join-Path $target 'gui_controller_camera_test.lua') -Destination $backup
Copy-Item -LiteralPath (Join-Path $target 'gui_controller_bindings_ui.lua') -Destination $backup
Copy-Item -LiteralPath (Join-Path $source 'gui_controller_camera_test.lua') -Destination $target
Copy-Item -LiteralPath (Join-Path $source 'gui_controller_bindings_ui.lua') -Destination $target
Copy-Item -LiteralPath (Join-Path $source 'gui_controller_ui_layout.lua') -Destination $target
```

Start BAR normally with the existing launcher/companion workflow. In Widget Selector confirm `Controller Camera Test`, `Controller Bindings UI`, and `Controller UI Layout` are enabled. Do not copy or install a custom engine.

## Build placement

1. Select a builder and place a normal structure on flat high terrain, a hill/slope, and a plateau.
2. At each site compare the live preview footprint with the issued/final footprint.
3. Place near a shoreline; verify land-only invalid water footprints and water-only invalid land footprints are rejected.
4. Place a valid water structure and confirm underwater terrain does not become sea-level zero.
5. Try an occupied/invalid footprint and confirm no controller order is issued.
6. Test single, line, grid, border/split if available, and all four facings.

## Fresh-install preset (temporary isolated config)

Close BAR. Back up the complete widget config, then temporarily move it so BAR creates a clean one:

```powershell
$config = 'C:\Users\kaili\AppData\Local\Programs\Beyond-All-Reason\data\LuaUI\Config\BYAR.lua'
$saved = 'C:\Users\kaili\AppData\Local\Programs\Beyond-All-Reason\data\LuaUI\Config\BYAR.lua.v060-test-backup'
Copy-Item -LiteralPath $config -Destination $saved
Move-Item -LiteralPath $config -Destination ($config + '.v060-clean-test')
```

Launch, enable the three controller widgets if the fresh config requires it, and enter a match without opening Bindings. Confirm Build-First behavior immediately, then open Bindings and confirm the preset is Active. Change one binding, exit BAR normally, relaunch, and confirm the customization persists and the preset shows Custom.

After the clean test, close BAR and restore the original config:

```powershell
$config = 'C:\Users\kaili\AppData\Local\Programs\Beyond-All-Reason\data\LuaUI\Config\BYAR.lua'
Remove-Item -LiteralPath $config
Move-Item -LiteralPath ($config + '.v060-clean-test') -Destination $config
```

The extra `.v060-test-backup` copy is intentionally retained as recovery insurance and may be deleted after verification.

## Context hints

1. Confirm hints are visible by default, then toggle `Hints visible` off/on in UI Layout.
2. Check neutral/no selection, hover target, single/multiple selection, builder, factory, and transport selections.
3. Open build/factory/tactical/selection radials and verify the displayed controls change.
4. Enter placement and verify confirm, continue, cancel, rotate, spacing, pattern, append, and insert hints.
5. Enter Mouse Mode and pregame flow and verify click/cursor/camera hints.
6. Open Bindings and UI Layout and verify editing hints replace gameplay hints.
7. Rebind an action and confirm its hint chip changes without restart.
8. Change size, opacity, position, chip/font sizes, spacing, width, columns, and compact mode live.
9. Confirm both short and held Back+Start hints are present where available.

## Shortcut timing

1. Press/release Back+Start before 1.5 seconds: Mouse Mode toggles exactly once.
2. Hold at least 1.5 seconds: UI Layout toggles exactly once; Mouse Mode does not change.
3. Keep holding: no repeat. Release: no second action.
4. Repeat only after both controls are released.
5. Repeat while Mouse Mode is already active.
6. Confirm command layer/control-group actions do not fire during the resolved chord.

## Editor and Bindings launcher

1. Open by long chord, `UI Layout` mouse button, and `/luaui bar_controller_ui`.
2. Move/resize the editor; restart and verify persistence.
3. Drag the small `Bindings` button in edit mode; adjust visibility/scale/opacity/font; restart.
4. Change resolution/window mode, a small window, and ultrawide; verify both remain on-screen.
5. Reset Bindings Button, one other section, then Reset All.
6. Close the editor and confirm the Bindings button cannot be dragged.
7. Click Bindings normally and confirm the original full-screen UI opens/closes and binding capture/preset controls work.
8. Confirm the full-screen Bindings UI itself was not moved, resized, or redesigned.

## Regression pass

Companion connection; native-controller preference; camera; selection; Smart X; hold-X multi-unit path; Area Mex; build/tactical/factory/selection radials; T2 mex upgrade; pregame controls; binding capture; Build-First preset button; custom binding persistence; short Mouse Mode chord. Inspect `infolog.txt` for Lua errors and watch for periodic frame-time spikes.

