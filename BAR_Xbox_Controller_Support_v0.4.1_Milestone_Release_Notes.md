# BAR Xbox Controller Support v0.4.1 Milestone Build

This is a major milestone release for the community-driven Beyond All Reason (BAR) Xbox Controller Support project.

> [!IMPORTANT]
> **CRITICAL REQUIREMENT**: This controller support mod **REQUIRES** the custom controller-enabled BAR/Recoil engine compatibility layer. The LuaUI widgets alone are **NOT** sufficient; they rely on controller-specific C++ APIs introduced in the custom engine. If you do not install the compatibility engine, your controller will not be detected.

---

## 1. Release Classification
* **Milestone Release**: This is a normal public GitHub release, representing the current best, most advanced, and feature-rich build of the controller widgets and presets.
* **Active WIP**: Although this is the best public build, it is still a community work-in-progress. Expect some rough edges.
* **Earlier Baselines**: The **v0.4.0** stable release remains fully preserved on the GitHub releases page.

---

## 2. Feature Highlights

* **Binding Presets System**: Includes the `Balanced RTS` and `Build-First Commander` preset configurations to allow one-click bindings setup, with modal confirmation and live preset status tracking.
* **Build / Factory Radial Menu**: Map unit and structure factory blueprints onto a convenient, visual radial menu.
* **Shift-Style Command Queuing (RT)**: Holding **RT** mimics the keyboard's **Shift** key, appending move, build, or attack commands to the end of your order queue.
* **Do Next / Insert Front Command (RB or Y)**: Prepend urgent commands to the front of the queue.
* **RT + A & RT + X Append Placement**: Allows you to queue up multiple building placements cleanly without interrupting active production.
* **Grid Placement Lock (LB)**: Holding **LB** during placement locks coordinates to the grid.
* **LB Tap Placement Pattern Cycle**: Tapping **LB** during placement cycles through layout patterns. **RB** is reserved to prevent accidental pattern cycling.
* **Split Queue Removal (L3 / R3)**:
  * **Left Stick Click (L3)**: Deletes the current/next queued command.
  * **Right Stick Click (R3)**: Deletes the last queued command.
  * *Queue removal functions perfectly even during active construction placement!*
* **Command Layer (Back/View)**: Toggles the command HUD and quick tactical overlays.
* **Group Layer (Start/Menu)**: Switch to the Group layer to assign or recall unit groups.
* **Same-Type / Future Unit Auto-Grouping**: Automatically adds matching unit types and production queues to custom controller group slots.
* **Full Settings and Safe-Area UI**: Expanded Deadzone/Sensitivity configuration ranges up to `20,000` with customizable screen margin safe areas.

---

## 3. Preset Mappings Overview

### Balanced RTS Preset
* **A** = Select / Confirm / Place
* **B** = Cancel / Clear / Deselect
* **X** = Move / Smart Move
* **Y** = Build / Factory Radial Menu
* **RB** = Do Next / Insert Front Command Modifier
* **RT** = Append Queue (Shift-style Queue)
* **LT** = Camera Speed Modifier
* **LB** = Camera Pitch (outside placement) / Grid & pattern controls (during placement)
* **Back/View** = Command Layer Modifier
* **Start/Menu** = Group Layer Modifier
* **Left Stick Click (L3)** = Remove Current/Next Queue Item
* **Right Stick Click (R3)** = Remove Last Queue Item

### Build-First Commander Preset
* **A** = Select / Confirm / Place
* **B** = Cancel / Clear / Deselect
* **X** = Move / Smart Move
* **RB** = Build / Factory Radial Menu
* **Y** = Do Next / Insert Front Command Modifier
* **RT** = Append Queue (Shift-style Queue)
* **LT** = Camera Speed Modifier
* **LB** = Camera Pitch (outside placement) / Grid & pattern controls (during placement)
* **Back/View** = Command Layer Modifier
* **Start/Menu** = Group Layer Modifier
* **Left Stick Click (L3)** = Remove Current/Next Queue Item
* **Right Stick Click (R3)** = Remove Last Queue Item

---

## 4. Documented Known Issue
* **Commander Focus Utility**: The `Back/View + A + A` shortcut (focus/select Commander) is currently unreliable or ignored by the gameplay input shim. This is a documented limitation and will be fixed in a later release. All other features on the Back/View command layer function properly.

---

## 5. Installation Summary
1. **Engine**: Run the batch installer in `required_engine_installer/` to download and swap the Recoil 2025.06.24 compatibility engine.
2. **Widgets**: Copy the two Lua files from `luaui/Widgets/` to `%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets\` (or use the script in `optional_widget_installer/`).
3. **BAR**: Launch BAR, verify widgets are active, and apply a preset!
