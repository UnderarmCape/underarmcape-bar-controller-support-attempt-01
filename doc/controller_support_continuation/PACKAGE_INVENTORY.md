# Package Inventory

This document inventories every file included in the streamlined continuation pack and describes its purpose.

---

## Root Level
- **`START_HERE.md`**: Introduction file directing developers to the active source of truth.
- **`ACTIVE_CONTINUATION_BIBLE.md`**: Main active handoff document describing features, bindings, safety rules, and future roadmaps.
- **`CURRENT_RELEASE_NOTES.md`**: User-facing release notes detailing recent changes and files.
- **`INSTALL_AND_TEST.md`**: Setup guide and basic manual testing checklist.
- **`UPSTREAM_PR_ROADMAP.md`**: Plan for integrating controller features into main BAR and Recoil repositories.
- **`KNOWN_LIMITATIONS_AND_DEFERRED_WORK.md`**: List of features deferred or requiring separate experimental branches.
- **`PACKAGE_INVENTORY.md`**: This file.

---

## Directory: `luaui/Widgets`
- **`gui_controller_camera_test.lua`**
  - *Status*: Main active controller widget. Implements input capture, camera tracking, and hotkeys.
- **`gui_controller_bindings_ui.lua`**
  - *Status*: Renders the in-game controller bindings display.
- **`gui_controller_smartx_mouse_audit.lua`**
  - *Status*: Debug widget for auditing mouse commands to assist controller X debugging.
- **`cmd_area_mex.lua`**
  - *Status*: Required modified BAR widget for controller Area Mex API bridge.
  - *Future*: Should be upstreamed to the BAR game repository.

---

## Directory: `release_assets`
- **`BAR_Controller_Support_v0.4.5_INCREMENTAL_LUA_WIDGETS.zip`**
  - *Status*: Clean release archive containing the 4 widgets and README for direct installation.
- **`BAR_Controller_Support_v0.4.5_INCREMENTAL_LUA_RELEASE_NOTES.md`**
  - *Status*: Original release notes published with the v0.4.5 pre-release.

---

## Directory: `archive_reference`
- **`OLD_CONTEXT_NOT_REQUIRED_FOR_NORMAL_CONTINUATION.md`**
  - *Status*: Warning doc directing developers to ignore older archives during normal continuation.
