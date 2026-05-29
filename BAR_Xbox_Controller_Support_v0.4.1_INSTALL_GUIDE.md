# BAR Xbox Controller Support v0.4.1 Install Guide

This guide describes how to install and activate the Xbox Controller Support widget package for Beyond All Reason (BAR).

---

## 1. What This Mod Is
* **LuaUI Widget Layer**: This is a pure LuaUI widget-based Xbox/controller support layer.
* **No Engine Modification Required**: This milestone release package runs on the standard, stock Beyond All Reason client/engine. It does **NOT** require replacing your Recoil engine files or running modified client executables.
* **Key Features**: Adds mouse-free in-game Controller Bindings & Settings UI, pre-tuned presets, responsive build placement controls, split queue management (L3/R3), D-pad layout controls, and group assignment mechanics.

---

## 2. Required Files
To run this controller support system, you only need two Lua widget files:
1. `gui_controller_camera_test.lua` (the core gameplay and input-grabbing engine)
2. `gui_controller_bindings_ui.lua` (the interactive in-game settings and bindings menu)

---

## 3. Recommended Installation Method (Manual Copy)
This is the safest and recommended way to install the controller support widgets. No administrative privileges or script executions are required.

### Step-by-Step Manual Installation:
1. **Download** the release ZIP: `BAR_Xbox_Controller_Support_v0.4.1_MILESTONE.zip`.
2. **Extract** the ZIP archive to a folder on your computer.
3. **Open** the extracted folder and navigate to the `luaui/Widgets/` directory.
4. **Copy** both Lua files:
   * `gui_controller_camera_test.lua`
   * `gui_controller_bindings_ui.lua`
5. **Paste** both files into your BAR widgets directory. The default path on Windows is:
   ```text
   %LOCALAPPDATA%\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets\
   ```
   *Tip: You can copy that path, press `Win + R` on your keyboard, paste it into the Run dialog, and press Enter to open the folder instantly!*
6. **Start or Restart** Beyond All Reason.
7. **Enable the Widget**: If the widgets are not automatically active in-game, open the LuaUI widget menu (press `F11` in-game, or run the chat command `/luaui` or `/luaui selector`), find **Controller Camera Test** and **Controller Bindings UI**, and make sure they are checked/enabled.
8. **Open Bindings UI**: Open the controller editor by clicking the **Bindings** button in the top-right corner of the screen, or by typing `/luaui bar_controller_bindings` in the chat window.
9. **Apply a Preset**: Select the **Presets** category at the top of the bindings UI, and apply either:
   * **Balanced RTS**
   * **Build-First Commander**
10. **Test Inputs**: Plug in your USB Xbox controller and start playing!

---

## 4. Optional Automated Installation (Batch File)
For convenience, a simple Windows command script is included in the release ZIP.

* **File Name**: `optional_installer/install_controller_widgets.bat`
* **Safe to Use**: This batch script does **NOT** require Administrator privileges. It only performs a simple file copy from the ZIP directory to the default BAR widgets path.
* **Security & Transparency**: You are encouraged to right-click the `.bat` file and select **Edit** to inspect its code in Notepad before running it. It is entirely transparent and performs no background actions.

### Running the Batch Installer:
1. Extract the `BAR_Xbox_Controller_Support_v0.4.1_MILESTONE.zip`.
2. Open the `optional_installer` folder.
3. Double-click `install_controller_widgets.bat`.
4. Read the success report in the terminal window, press any key to close the window, and launch BAR.
