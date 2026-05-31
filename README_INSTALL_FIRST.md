# STOP: READ THIS FIRST — BAR Xbox Controller Support v0.4.2

> [!IMPORTANT]
> **CRITICAL ENGINE REQUIREMENT**: This controller support mod **REQUIRES** a custom controller-enabled BAR/Recoil engine build to capture inputs.
> The automated installer handles everything — it downloads the engine, clones the correct game branch, and configures dev mode. You do not need to manually copy widget files.

---

## What This Mod Consists Of

This milestone release package contains two parts:
1. **Custom Recoil Engine & Game Files**: Installed automatically by the installer `required_engine_installer/Install_BAR_Controller_Support_v0.4.2_SMARTX_CALIBRATED.bat`.
2. **v0.4.2 LuaUI Widgets**: Included automatically via the `controller-support-current-master-engine-shim` branch clone performed by the installer.

---

## Target Installation Flow (Quick Guide)

Follow these exact steps in order to install the mod successfully:

### Step 1: Run the Custom Engine Installer
1. Open the folder `required_engine_installer/`.
2. Run `Install_BAR_Controller_Support_v0.4.2_SMARTX_CALIBRATED.bat` by double-clicking it.
3. The script will automatically:
   - Download the custom controller engine ZIP (`recoil_2025.06.24-controller-support-pr2985-win64.zip`) from GitHub
   - Back up your current game and engine
   - Clone the `controller-support-current-master-engine-shim` branch as the new `BAR.sdd`
   - Install the v0.4.2 `gui_controller_camera_test.lua` widget from this release
   - Configure developer mode and disable Spring camera cardinal locking
   - Clear obsolete caches
4. Wait for the terminal to display **INSTALL COMPLETE**.

### Step 2: Launch and Configure BAR
1. Plug in your USB Xbox controller.
2. Launch Beyond All Reason.
3. In the main menu, go to **Settings > Developer**.
4. Set **Singleplayer** to **Beyond All Reason Dev** (this loads the local dev folder containing your custom controller files).
5. Start a local Skirmish match.
6. The controller bindings UI should appear — go to **Presets** and apply either **Balanced RTS** or **Build-First Commander**!

---

## Included Folders & Files

* **`README_INSTALL_FIRST.md`**: (This file) Essential overview and installation order instructions.
* **`BAR_Xbox_Controller_Support_v0.4.2_INSTALL_GUIDE.md`**: Detailed technical installation guide, widget descriptions, and troubleshooting.
* **`BAR_Xbox_Controller_Support_v0.4.2_RELEASE_NOTES.md`**: Features log, Smart X v0.4.2 calibration changes, preset button maps, and known issues.
* **`required_engine_installer/`**: Script to download and install the custom controller-enabled engine.

---

## v0.4.2 Smart X Calibration Summary

| Scenario | Expected Behavior |
|---|---|
| Con bot over wreck | Reclaim (cmdID 90) |
| Res bot over wreck | Resurrect (cmdID 125) |
| Reticle within ~55 elmos of built mex | No-Move guard |
| Reticle over wreck near mex spot | Wreck wins |
| Open ground | Move (cmdID 10) |

---

## Optional: Smart X Mouse Audit Widget

A debugging widget that shows hover targets and command links. **Disabled by default.**
Enable only if debugging Smart X behavior:
```
/luaui enablewidget "Controller SmartX Mouse Audit"
```
