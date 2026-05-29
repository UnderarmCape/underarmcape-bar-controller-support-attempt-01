# Beyond All Reason (BAR) Xbox Controller Support v0.4.1

Welcome! This package adds fully functional Xbox Controller support directly into Beyond All Reason (BAR) via LuaUI widgets.

## Quick Start Installation

1. **Download and extract** this ZIP archive to a folder on your computer.
2. **Copy the two Lua files** from `luaui/Widgets/` folder:
   * `gui_controller_camera_test.lua`
   * `gui_controller_bindings_ui.lua`
3. **Paste** both files into your BAR widgets directory. The default path is:
   `%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets\`
4. **Start or Restart BAR**.
5. Make sure the widgets are enabled (press `F11` in-game to verify).
6. Open the **Bindings UI** (click the "Bindings" button in the top-right corner of the screen or type `/luaui bar_controller_bindings` in the chat).
7. Go to **Presets** and apply either **Balanced RTS** or **Build-First Commander**!

---

## Alternative Automated Installer
An optional batch file is provided in `optional_installer/install_controller_widgets.bat`.
* This script only copies the two widget files to the default BAR folder.
* It does **NOT** require administrator rights.
* You can open it in Notepad to verify its safety before running.
* **Manual copy is still highly recommended** if you are unsure or run a custom installation path.

---

## Included Documentation
* **`BAR_Xbox_Controller_Support_v0.4.1_INSTALL_GUIDE.md`**: Full instructions with custom path tips and widget loading guides.
* **`BAR_Xbox_Controller_Support_v0.4.1_Milestone_Release_Notes.md`**: Detailed list of features, preset buttons, and known issues.
