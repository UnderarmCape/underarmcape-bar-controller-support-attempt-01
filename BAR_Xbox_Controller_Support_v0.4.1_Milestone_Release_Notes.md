# BAR Xbox Controller Support v0.4.1 Milestone Build

Welcome to the **v0.4.1 Milestone Build** of Beyond All Reason (BAR) Xbox Controller Support!

This is a major milestone release for the community controller-support widget package. It introduces high-quality preset layouts, native build radial menus, Shift-like command queuing, grid-placement modes, independent command queue clearing via stick clicks, and advanced unit group controls.

---

## 1. Release Status & Goals
* **Milestone Classification**: This is a **normal public GitHub release**, not a prerelease.
* **WIP / Active Development**: While this is the best, most stable, and feature-rich public release of the controller widget, it is still an active community work-in-progress. Expect some rough edges.
* **Upgrade Path**: If you prefer a simpler baseline, **v0.4.0** remains fully available on the releases page.

---

## 2. Key Feature Highlights

* **Binding Presets System**: Apply standard layouts in one click without manually assigning dozens of inputs. Includes safety confirmation modals and live "Active / Inactive / Custom" status tracking.
* **Build / Factory Radial Menu Integration**: Fully interactive build menus mapping factory blueprints onto a convenient radial layout.
* **Shift-Style Command Queuing (RT)**: Holding **RT** acts like holding the keyboard's **Shift** key, allowing you to queue up multiple move, attack, patrol, or build commands.
* **Do Next / Insert Front Command (RB or Y)**: Allows inserting commands at the *front* of the queue instead of appending them.
* **Grid Placement Override (LB)**: Holding **LB** during unit/building placement forces **Grid Mode** for perfectly aligned layouts.
* **Placement Pattern Cycle (LB Tap)**: Tapping **LB** during placement cycles through custom placement patterns. **RB** is reserved exclusively to prevent accidental pattern cycling.
* **Independent Queue Removal (L3 / R3)**:
  * **Left Stick Click (L3)**: Instantly deletes the current/next queued command.
  * **Right Stick Click (R3)**: Deletes the last queued command.
  * *Both stick clicks remain fully functional during active building placement!*
* **Group Layer Management (Start/Menu)**: Switch to the Group layer to assign or recall unit groups.
* **Command Layer (Back/View)**: Switch to the Command layer for quick tactical commands.
* **Same-Type / Future Unit Grouping**: Smart assignment behaviors for matching unit types and production queues.

---

## 3. Preset Layout Configurations

### Balanced RTS Preset
Designed for players who want standard RTS button structures, with the **Y** button opening the Build Menu.

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
Optimized for high-speed base expansion and construction, placing the Build Menu on the highly accessible **RB** bumper.

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

## 4. Known Issues (v0.4.1)
* **Commander Focus Shortcut**: The standard `Back/View + A + A` shortcut (used to focus/select the Commander) is currently ignored or unreliable in the gameplay input shim.
  * *Note: The primary Command Layer features and D-pad menus mapped to `Back/View` continue to function perfectly.*
  * This is a known limitation that will be addressed in a future hotfix.

---

## 5. Installation Instructions

### Recommended Manual Installation:
1. **Download** the zip package: `BAR_Xbox_Controller_Support_v0.4.1_MILESTONE.zip`.
2. **Extract** the files to a folder.
3. Copy the two files from the `luaui/Widgets/` directory:
   * `gui_controller_camera_test.lua`
   * `gui_controller_bindings_ui.lua`
4. Paste both files into your BAR directory:
   ```text
   %LOCALAPPDATA%\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets\
   ```
5. Launch BAR, press `F11` in-game to make sure **Controller Camera Test** and **Controller Bindings UI** widgets are enabled.
6. Open the **Bindings UI** (click the "Bindings" button in the top-right corner) and apply either the `Balanced RTS` or `Build-First Commander` preset!

### Optional Automated Installer:
* A simple script `optional_installer/install_controller_widgets.bat` is provided in the ZIP.
* Double-click it to copy the widgets to the default install path automatically.
* No administrator rights are required. You can inspect it in Notepad before running.
