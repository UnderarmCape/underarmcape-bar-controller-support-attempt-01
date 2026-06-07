# Streamlined Continuation Pack Inventory

## Root Documents

- `START_HERE.md`: entry point and current-version pointer.
- `ACTIVE_CONTINUATION_BIBLE.md`: active source of truth.
- `CURRENT_RELEASE_NOTES.md`: v0.4.6 change summary.
- `INSTALL_AND_TEST.md`: install and priority smoke tests.
- `UPSTREAM_PR_ROADMAP.md`: Recoil, Area Mex, and pregame API roadmap.
- `KNOWN_LIMITATIONS_AND_DEFERRED_WORK.md`: active limitations and safety rules.
- `PACKAGE_INVENTORY.md`: this inventory.

## Active Lua Widgets

- `luaui/Widgets/gui_controller_camera_test.lua`
- `luaui/Widgets/gui_pregameui.lua`
- `luaui/Widgets/cmd_area_mex.lua`
- `luaui/Widgets/gui_controller_bindings_ui.lua`
- `luaui/Widgets/gui_controller_smartx_mouse_audit.lua`

`gui_pregameui.lua` is required for the owner-controlled controller Ready API.
`cmd_area_mex.lua` is required for `WG.controllerAreaMex.issueArea(...)`.

## Release Asset Reference

- `release_assets/BAR_Controller_Support_v0.4.6_AIO_RELEASE_NOTES.md`

## Archive Reference

- `archive_reference/OLD_CONTEXT_NOT_REQUIRED_FOR_NORMAL_CONTINUATION.md`

The streamlined pack intentionally excludes large AIO payload ZIPs and old
conversation/context archives.
