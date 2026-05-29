# BAR Xbox Controller Support v0.4.1 Complete Install Guide

This guide details the complete installation procedure for the Beyond All Reason (BAR) Xbox Controller Support v0.4.1 milestone build.

---

## 1. What This Is
This package adds Xbox controller support to Beyond All Reason (BAR). It is comprised of two mandatory components:
1. **Custom Recoil Engine & Files**: A specialized Windows 64-bit engine build containing the custom C++ input APIs required to capture controller button presses and joystick motions natively without severe input-grabbing or log-spam issues.
2. **v0.4.1 LuaUI Widgets**: The user-space widgets (`gui_controller_camera_test.lua` and `gui_controller_bindings_ui.lua`) which map inputs to construction placements, Shift-style queuing, binding presets, and camera adjustments.

---

## 2. Complete Path Specifications
The automated installation script utilizes the default Beyond All Reason paths on Windows:
* **BAR Root Folder**: `%LOCALAPPDATA%\Programs\Beyond-All-Reason`
* **BAR Data Folder**: `%LOCALAPPDATA%\Programs\Beyond-All-Reason\data`
* **Preferred Engine Slot**: `recoil_2025.06.24`
* **Engine Root Folder**: `%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\engine`
* **Active BAR Game Folder**: `%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\games\BAR.sdd`
* **Active BYAR Chobby Folder**: `%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\games\BYAR Chobby.sdd`
* **Clean Backup Folder**: `%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\controller-support-cleaninstall-backups`

---

## 3. Installation Step 1: Install the Custom Engine Compatibility Build

The custom engine is installed using the batch installer:
`required_engine_installer/Install_BAR_Controller_Support_v0.3.7_RECOIL_2025_06_24_COMPAT.bat`

### What the Batch Installer Script Does:
1. **Process Safety**: Safely terminates any active, running BAR and Recoil processes to prevent file lock errors (`spring.exe`, `Beyond-All-Reason.exe`, `pr-downloader.exe`).
2. **Engine Download**: Automatically checks for a local copy of the custom engine archive `recoil_2025.06.24-controller-support-pr2985-win64.zip`. If it is not found next to the batch file, the script downloads it directly from the secure release repository:
   * **Engine URL**: `https://github.com/UnderarmCape/controllersupport-RecoilEngine-attempt-01/releases/download/controller-support-recoil-2025-06-24-compat/recoil_2025.06.24-controller-support-pr2985-win64.zip`
3. **Extraction & Verification**: Extracts the ZIP and validates that all critical engine binaries are present and uncorrupted:
   * `spring.exe`
   * `spring-headless.exe`
   * `spring-dedicated.exe`
   * `unitsync.dll`
   * `SDL2.dll`
   * `base\` folder
4. **Git Repository Cloning**:
   * Clones the controller-support `BAR.sdd` repo (branch `controller-support-current-master-engine-shim`) from `https://github.com/UnderarmCape/underarmcape-bar-controller-support-attempt-01.git`.
   * Clones the `BYAR-Chobby` menu repository from `https://github.com/beyond-all-reason/BYAR-Chobby.git`.
5. **System Backups**: Moves your current active stock engine slot, `BAR.sdd` directory, and `BYAR Chobby.sdd` directory to the clean backup folder (`%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\controller-support-cleaninstall-backups\<timestamp>\`) before touching any active files.
6. **Active Engine Slot Replacement**: Safely moves the custom controller-enabled engine slot into place.
7. **Developer Configuration**: Creates an empty file named `devmode.txt` under `data/` to authorize execution of untracked dev widgets.
8. **Camera Tuning**: Sets `CamSpringLockCardinalDirections = 0` in `%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\springsettings.cfg`. This disables Spring's default cardinal camera locking, enabling fluid 360-degree analog stick panning and rotation.
9. **Obsolete State Cleared**: Deletes old data directories (`cache`, `fontcache`, `ArchiveCache*.lua`, `infolog.txt`) to avoid rendering conflicts.
10. **Developer UI Resolution**: Renames stale folders and files (e.g. `LuaUI`, `LuaMenu`, `chobby_config.json`) so the newly cloned development UI loads cleanly on first boot.

### How to Run the Engine Installer:
1. Open the extracted folder.
2. Go to `required_engine_installer/`.
3. Double-click `Install_BAR_Controller_Support_v0.3.7_RECOIL_2025_06_24_COMPAT.bat`.
4. Wait for it to report **INSTALL COMPLETE** and press any key to close the window.

---

## 4. Installation Step 2: Copy the v0.4.1 Widget Files (Critical Update)

> [!WARNING]
> **Why this step is mandatory**: The automated engine installer (from the v0.3.7 baseline) downloads compatible repository packages which may contain older widgets. To upgrade to the latest v0.4.1 milestone controls, you must copy the new widget files contained in this package *after* running the engine installer.

### Manual Widget Overwrite Instructions:
1. Open the `luaui/Widgets/` directory inside this package.
2. Select and copy these two files:
   * `gui_controller_camera_test.lua`
   * `gui_controller_bindings_ui.lua`
3. Paste both files into your active widgets directory:
   ```text
   %LOCALAPPDATA%\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets\
   ```
4. **When prompted by Windows, choose "Replace the files in the destination"** to overwrite the old widget files with the new v0.4.1 milestone builds.

---

## 5. Installation Step 3: Launch Beyond All Reason
1. Connect your Xbox controller via USB.
2. Launch Beyond All Reason.
3. In the main menu, navigate to **Settings > Developer**.
4. Set the **Singleplayer** dropdown option to **Beyond All Reason Dev** (this tells the launcher to run the local `BAR.sdd` development files instead of standard production packages).
5. Set up a local Skirmish match.
6. Once the map loads, verify that the widgets are active. You can press **F11** to view the LuaUI widget menu and verify **Controller Camera Test** and **Controller Bindings UI** are checked/enabled.
7. Click the interactive **Bindings** button in the top-right corner of the screen (or run the chat command `/luaui bar_controller_bindings`) to open the settings interface.
8. Go to **Presets** and apply either **Balanced RTS** or **Build-First Commander**.

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
