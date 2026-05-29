# STOP: READ THIS FIRST — BAR Xbox Controller Support v0.4.1

> [!IMPORTANT]
> **CRITICAL ENGINE REQUIREMENT**: This controller support mod **REQUIRES** a custom controller-enabled BAR/Recoil engine build to capture inputs.
> Copying only the Lua widget files is **NOT** enough. You must run the custom engine installer first, and then copy these v0.4.1 widget files over the installation!

---

## What This Mod Consists Of

This milestone release package contains two parts:
1. **Custom Recoil Engine & Game Files**: Captured, compiled, and configured using the automated installer `required_engine_installer/Install_BAR_Controller_Support_v0.3.7_RECOIL_2025_06_24_COMPAT.bat`.
2. **v0.4.1 LuaUI Widgets**: The updated high-quality bindings, presets, build placement shims, and queue controls contained in `luaui/Widgets/`.

---

## Target Installation Flow (Quick Guide)

Follow these exact steps in order to install the mod successfully:

### Step 1: Run the Custom Engine Installer
1. Open the folder `required_engine_installer/`.
2. Run `Install_BAR_Controller_Support_v0.3.7_RECOIL_2025_06_24_COMPAT.bat` by double-clicking it.
3. The script will automatically download the custom controller engine ZIP (`recoil_2025.06.24-controller-support-pr2985-win64.zip`) from GitHub, back up your current game and engine, stage the compatible versions of `BAR.sdd` and `BYAR Chobby.sdd`, configure developer mode, and clear obsolete caches.
4. Wait for the terminal to display **INSTALL COMPLETE** and press any key to close the script window.

### Step 2: Copy the v0.4.1 Widget Files (Critical Update)
The engine installer script downloads a baseline package that may contain older widgets. To upgrade to the latest v0.4.1 features:
1. Open the `luaui/Widgets/` directory in this package.
2. Copy these two files:
   * `gui_controller_camera_test.lua`
   * `gui_controller_bindings_ui.lua`
3. Paste both files into your active BAR games folder:
   ```text
   %LOCALAPPDATA%\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets\
   ```
4. **Choose "Replace the files in the destination"** when Windows asks if you want to overwrite existing files.

### Step 3: Launch and Configure BAR
1. Plug in your USB Xbox controller.
2. Launch Beyond All Reason.
3. In the main menu, go to **Settings > Developer**.
4. Set **Singleplayer** to **Beyond All Reason Dev** (this loads the local dev folder containing your custom controller files).
5. Start a local Skirmish match.
6. Press **F11** to open the LuaUI widget selector and verify that **Controller Camera Test** and **Controller Bindings UI** are enabled.
7. Click the **Bindings** button in the top-right corner of the screen (or run `/luaui bar_controller_bindings` in the chat console) to open the bindings menu.
8. Go to **Presets** and apply either **Balanced RTS** or **Build-First Commander**!

---

## Included Folders & Files

* **`README_INSTALL_FIRST.md`**: (This file) Essential overview and installation order instructions.
* **`BAR_Xbox_Controller_Support_v0.4.1_INSTALL_GUIDE.md`**: Detailed technical installation guide, path lists, batch behaviors, and troubleshooting.
* **`BAR_Xbox_Controller_Support_v0.4.1_Milestone_Release_Notes.md`**: Features log, preset button maps, and known issues.
* **`luaui/Widgets/`**: Updated v0.4.1 Lua widgets.
* **`required_engine_installer/`**: Script to download and install the custom controller-enabled engine.
* **`optional_widget_installer/`**: Optional script to copy only the widget files (Step 2).
