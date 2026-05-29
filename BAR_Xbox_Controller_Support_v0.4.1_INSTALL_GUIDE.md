# BAR Xbox Controller Support v0.4.1 Install Guide

This guide details the complete installation procedure for the Beyond All Reason (BAR) Xbox Controller Support v0.4.1 milestone build.

---

## 1. What This Is
This package adds modern Xbox controller support to Beyond All Reason. It is comprised of two mandatory parts:
1. **Custom BAR/Recoil Engine**: A specialized engine build containing the necessary C++ APIs to capture raw controller inputs without severe log-spam or detection issues.
2. **LuaUI Widgets**: High-level game code (`gui_controller_camera_test.lua` and `gui_controller_bindings_ui.lua`) which maps inputs to unit commands, camera speeds, placement patterns, presets, and the interactive bindings menu.

---

## 2. Required Components
To play BAR with a controller, you **MUST** install both components in order:
1. **Custom Engine Build**: Installed via the batch file in `required_engine_installer/`.
2. **LuaUI Widget Files**:
   * `gui_controller_camera_test.lua`
   * `gui_controller_bindings_ui.lua`

---

## 3. Installation Step 1: Install the Custom Engine
Before copying the widgets, you must run the safe engine installer.

* **File Location**: `required_engine_installer/Install_BAR_Controller_Support_v0.3.7_RECOIL_2025_06_24_COMPAT.bat`
* **What it does**:
  1. Stops any active `spring.exe` or BAR client processes.
  2. Automatically downloads the verified custom win64 engine ZIP containing the PR #2985 controller API.
  3. Safely backs up your existing stock engine files to `C:\Users\<username>\AppData\Local\Programs\Beyond-All-Reason\data\controller-support-cleaninstall-backups\`.
  4. Swaps the custom engine files into your active BAR engine slot.
  5. Configures standard developer settings (`devmode.txt`) to allow custom widget execution.
  6. Modifies `springsettings.cfg` to set `CamSpringLockCardinalDirections = 0` for ultra-smooth 360-degree analog camera rotations.
  7. Clears state caches to prevent conflicts.
* **Security & Transparency**: The script runs entirely in user-space and does **NOT** require administrative rights. You are encouraged to right-click the `.bat` file and choose **Edit** to inspect its code.
* **How to Run**: Simply double-click the script and follow the on-screen instructions.

---

## 4. Installation Step 2: Install the Widget Files
Once the engine installation finishes successfully, you can copy the game widgets.

### Method A: Manual Installation (Recommended)
1. Navigate to the `luaui/Widgets/` folder inside this extracted package.
2. Copy the two files:
   * `gui_controller_camera_test.lua`
   * `gui_controller_bindings_ui.lua`
3. Paste both files into your active BAR folder:
   ```text
   %LOCALAPPDATA%\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets\
   ```
   *(If your Beyond All Reason is installed in a custom location, locate the `BAR.sdd` folder, open `luaui\Widgets\`, and paste the files there).*

### Method B: Optional Widget Installer
* Double-click `optional_widget_installer/install_widget_files_only.bat`.
* This copies the two files to your default `%LOCALAPPDATA%` path automatically. It does not touch engine files.

---

## 5. Installation Step 3: Launch and Configure BAR
1. Plug in your USB Xbox controller.
2. Launch Beyond All Reason.
3. Open the LuaUI widget menu in-game by pressing **F11** or running the chat command `/luaui`.
4. Verify that **Controller Camera Test** and **Controller Bindings UI** widgets are checked and active.
5. Click the interactive **Bindings** button in the top-right corner of the screen (or run `/luaui bar_controller_bindings` in the chat console).
6. Select the **Presets** category at the top and apply either:
   * **Balanced RTS**
   * **Build-First Commander**

---

## 6. Quick Verification Checklist
Once loaded into a local Skirmish match, verify the following inputs:
- [ ] **Controller Input**: Moving the left analog stick rotates and pans the camera smoothly.
- [ ] **Bindings UI**: Clicking the top-right **Bindings** button opens the graphical overlay.
- [ ] **Preset Applied**: Pressing A/Enter on either preset maps all buttons instantly.
- [ ] **Radial Menu**: Pressing **Y** (Balanced RTS) or **RB** (Build-First Commander) opens the build radial layout.
- [ ] **Queuing (RT)**: Holding **RT** during construction placement appends builds to the order queue.
- [ ] **Grid Lock (LB)**: Holding **LB** during placement locks coordinates to the grid.
- [ ] **Queue Clearing**: Tapping **L3** clears current/next command; tapping **R3** clears the last command.

---

## 7. Known Limitation
* **Commander Focus Utility**: The shortcut `Back/View + A + A` (used to instantly select and focus your Commander unit) is currently ignored or unreliable in the gameplay input shim. This is a documented limitation and will be fixed in a future hotfix update.
