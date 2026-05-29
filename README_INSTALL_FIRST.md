# STOP: READ THIS FIRST — BAR Xbox Controller Support v0.4.1

> [!IMPORTANT]
> **CRITICAL REQUIREMENT**: This controller support mod **REQUIRES** the custom controller-enabled BAR/Recoil engine.
> Copying only the Lua widget files is **NOT** enough. The widgets rely on new controller-specific APIs exposed by the custom engine build. If you only copy the widgets, they may load but your controller input will not be recognized by the game.

---

## Required Install Order

This release package consists of two essential components that must be installed in order:

### 1. Step 1: Install the Custom Engine
You must install the **Recoil 2025.06.24 compatibility engine** build.
* **How**: Open the folder `required_engine_installer/` and run the script `Install_BAR_Controller_Support_v0.3.7_RECOIL_2025_06_24_COMPAT.bat`.
* *Security Note*: This batch installer does NOT require administrator privileges. You are welcome and encouraged to right-click and select **Edit** to inspect its code in Notepad before running it.

### 2. Step 2: Install the LuaUI Widgets
Once the engine is installed, you must install the controller widgets.
* **How (Manual - Recommended)**: Copy both `.lua` files from the `luaui/Widgets/` directory of this package:
  * `gui_controller_camera_test.lua`
  * `gui_controller_bindings_ui.lua`
  And paste them into your BAR widgets folder:
  `%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets\`
* **How (Automated - Optional)**: Open the folder `optional_widget_installer/` and run `install_widget_files_only.bat`. This script only copies the two widget files and does not modify the engine.

### 3. Step 3: Launch and Configure BAR
* Start or restart Beyond All Reason.
* Ensure both widgets are enabled (press `F11` in-game to open the LuaUI widget list, and check **Controller Camera Test** and **Controller Bindings UI**).
* Click the **Bindings** button in the top-right corner of the screen (or run the chat command `/luaui bar_controller_bindings`) to open the settings interface.
* Go to the **Presets** category and apply either **Balanced RTS** or **Build-First Commander**.

---

## Package Files & Folders

* **`README_INSTALL_FIRST.md`**: (This file) Crucial overview and install order instructions.
* **`BAR_Xbox_Controller_Support_v0.4.1_INSTALL_GUIDE.md`**: Detailed installation guide, path customization, and verification checklist.
* **`BAR_Xbox_Controller_Support_v0.4.1_Milestone_Release_Notes.md`**: Landmark feature highlights, preset button maps, and known issues.
* **`luaui/Widgets/`**: Folder containing the core Lua widgets.
* **`required_engine_installer/`**: Contains the automated installer script for the custom engine.
* **`optional_widget_installer/`**: Contains the optional script to automate copying the widget files.
