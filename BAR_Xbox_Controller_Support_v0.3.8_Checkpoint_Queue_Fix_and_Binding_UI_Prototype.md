# BAR Xbox Controller Support v0.3.8 Checkpoint

## v0.3.8 Checkpoint - Queue Removal Fix + Binding UI Prototype

### Current State Summary

- Current production baseline is BAR Xbox Controller Support v0.3.7 for Recoil 2025.06.24 compatibility.
- Queue-removal behavior is now working in the production LuaUI widget.
- A standalone browser prototype for the future binding UI exists and is committed locally.
- The actual in-game LuaUI binding editor has not been ported yet.

### Production Widget Changes

File:

```text
luaui/Widgets/gui_controller_camera_test.lua
```

Commit:

```text
fe61330f8ffc1c08b779a1573f27e445827f1520
```

Summary:

- Added and kept the `removeQueuedCommand` controller binding.
- Default binding: `Back/View`.
- `Back/View` removes the selected unit's current or next queued command.
- `LT + Back/View` removes the selected unit's last queued command.
- The final implementation directly manipulates selected unit command queues instead of relying on `Spring.SendCommands`.
- The direct queue-removal helper was modeled after BAR's `cmd_commandq_manager.lua` behavior.
- Preserved `Back/View + double-tap A` Commander focus behavior.
- Added queue-removal debug fields for selected unit count, active modifier, path chosen, queue sizes, removed command tags, and no-command cases.

### Browser Prototype Changes

Folder:

```text
C:/Users/kaili/Dev/BAR_Controller_Bindings_UI_Prototype/
```

Commits:

```text
6ca7c08 Add browser prototype for controller binding UI
4f5e5014b5fd34929d26082d68b6e21e3e559a30 Fix prototype binding highlights and add camera pitch binding
```

Summary:

- Standalone live-preview binding UI.
- Dark Steam-Input-inspired design without Steam branding or assets.
- Category tabs.
- Controller overview.
- Action list.
- Details panel.
- Rebind capture modal.
- Conflict modal.
- Canonical `controlId` highlighting and conflict detection.
- `Right Stick Y` no longer highlights face-button `Y`.
- `LB` no longer highlights face-button `B`.
- Added `Camera Pitch Modifier` bound to `LB`.
- Rebind capture updates both display binding and canonical `controlId`.
- No BAR LuaUI integration yet.

### Validation Results

Production widget:

- `luac -p luaui/Widgets/gui_controller_camera_test.lua` passed.
- `git diff --check -- luaui/Widgets/gui_controller_camera_test.lua` passed.
- File was checked as UTF-8 without BOM.

Browser prototype:

- `node --check src/main.js` passed.
- `node --check src/bindingsManifest.js` passed.
- `node build.mjs` passed.
- Browser smoke test passed.

### Manual Test Results

Production queue-removal test:

- Selected a constructor.
- Queued: `Move -> Move -> Build Windmill -> Move`.
- `Back/View` removed the current or next queued command.
- `LT + Back/View` removed the last queued command.
- Multi-command queue behavior matched the intended v0.3.7 fix.

Prototype visual checks:

- `Zoom Camera` highlights `Right Stick` / `Right Stick Y`, not face-button `Y`.
- `Camera Pitch Modifier` highlights only `LB`, not face-button `B`.
- `Select / Confirm` highlights only `A`.
- `Cancel / Clear` highlights only `B`.

### Next Roadmap

1. Finish prototype manifest coverage against real Lua binding definitions.
2. Freeze the browser prototype layout.
3. Create a separate in-game LuaUI file:

```text
gui_controller_bindings_ui.lua
```

4. Use the stable API exposed by:

```text
WG.BARControllerSupport
```

5. Do not duplicate gameplay logic in the future binding UI widget.
6. Block gameplay input while the binding UI is open.
7. Port the browser layout into LuaUI drawing primitives.
8. Test save, load, reset, and conflict behavior in-game.
9. Package the future full binding editor as v0.4.0.
10. Create a new continuation ZIP:

```text
BAR_Xbox_Controller_Support_AI_Continuation_Pack_v0.3.8_QUEUE_FIX_BINDING_UI_PROTOTYPE.zip
```

### Continuation Notes

- v0.3.7 remains the current production-compatible release for Recoil 2025.06.24.
- v0.3.8 is a checkpoint label for the queue-removal fix plus the binding UI prototype work.
- The browser prototype is not yet shipped as an in-game widget.
- The next major milestone should be the in-game `gui_controller_bindings_ui.lua` port.
