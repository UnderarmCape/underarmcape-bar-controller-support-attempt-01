# BAR Xbox Controller Support v0.4.2 — Install Guide

> [!IMPORTANT]
> **This mod requires a custom controller-enabled engine.** You MUST run the installer first. The standard BAR engine does not support Xbox controller input.

---

## Requirements

* **Windows 10 or later**
* **Beyond All Reason installed** at the default path:
  `%LOCALAPPDATA%\Programs\Beyond-All-Reason\`
* **Git for Windows** installed (installer uses `git clone`)
* **Internet connection** (installer downloads the engine ZIP and clones the BAR branch)
* **USB Xbox controller** (Bluetooth may also work)

---

## Step 1: Run the Installer

Open the `required_engine_installer/` folder in this package and double-click:

```
Install_BAR_Controller_Support_v0.4.2_SMARTX_CALIBRATED.bat
```

The installer will:
1. Detect your active BAR engine slot (prefers `recoil_2025.06.24`)
2. Download the custom controller-enabled engine ZIP from GitHub
3. Back up your current stock engine, `BAR.sdd`, and `BYAR Chobby.sdd`
4. Clone the `controller-support-current-master-engine-shim` branch into `BAR.sdd`
5. Install the downloaded `gui_controller_camera_test.lua` widget asset (from v0.4.2 release)
6. Swap the custom controller engine into the active engine slot
7. Enable BAR dev mode and disable Spring camera cardinal locking
8. Clear stale cache files

> [!NOTE]
> A timestamped log file will be saved to your Desktop automatically. Keep it if anything goes wrong.

---

## Step 2: Verify Installation Succeeded

After the installer completes, check the terminal output for:

```
INSTALL COMPLETE
```

And at the bottom, confirm:
- `BAR.sdd branch: controller-support-current-master-engine-shim`
- Recent commits include `v0.4.2` calibration and cleanup entries
- `CamSpringLockCardinalDirections = 0` appears in the settings output

If you see `INSTALL FAILED`, check the error message. The installer is designed not to delete your stock engine — the backup folder path is printed in the failure output.

---

## Step 3: Launch BAR

1. Launch Beyond All Reason normally.
2. Go to **Settings > Developer**.
3. Set **Singleplayer** to: **Beyond All Reason Dev**.
4. Plug in your Xbox controller (USB recommended).
5. Click **Skirmish**, configure a local match, and start.

---

## Step 4: Configure Your Controller Preset

After the match loads, the controller bindings UI will appear. Select your preset:

* **Balanced RTS** — Y = Do Next, RB = Build Radial, X = Smart Context Command
* **Build-First Commander** — Y = Do Next, RB = Build Radial, X = Smart Context Command

Both presets use the same Smart X calibration from v0.4.2.

---

## Installed Widget Files

The installer clones the full `controller-support-current-master-engine-shim` branch, which includes:

| File | Purpose |
|---|---|
| `gui_controller_camera_test.lua` | Main controller logic, Smart X, Hold A brush, Y Do Next |
| `gui_controller_bindings_ui.lua` | Bindings/settings UI widget |
| `gui_controller_smartx_mouse_audit.lua` | Diagnostic widget — **disabled by default** |

---

## Optional: Smart X Mouse Audit Widget

This debugging widget shows hover target info, mex distance, and links mouse clicks to observed commands. It is **disabled by default** to avoid affecting normal gameplay.

Enable only if you are debugging Smart X targeting behavior:

```
/luaui enablewidget "Controller SmartX Mouse Audit"
```

To disable again:

```
/luaui disablewidget "Controller SmartX Mouse Audit"
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Installer fails with "Git not found" | Install [Git for Windows](https://git-scm.com/download/win) and retry |
| Installer fails to download engine ZIP | Put `recoil_2025.06.24-controller-support-pr2985-win64.zip` next to the BAT and retry |
| Installer fails to download widget | Put `gui_controller_camera_test.lua` next to the BAT and retry |
| Controller not detected in-game | Ensure controller is plugged in before launching BAR; check infolog.txt for `ControllerInput` |
| Lua widget errors on load | Check infolog.txt for errors; try `/luaui reload` in game chat |
| Smart X not working | Confirm `gui_controller_camera_test.lua` is on the `controller-support-current-master-engine-shim` branch (v0.4.2 commit or later) |

---

## Backup and Restore

The installer creates backups in:
```
%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\controller-support-cleaninstall-backups\
```

To restore your original BAR install, simply:
1. Rename/delete the current `BAR.sdd`, `BYAR Chobby.sdd`, and the active engine folder
2. Move the backed-up versions back into place

The backup folder name includes a timestamp so you can identify which backup corresponds to which install.

---

## Version History

| Version | Notable Changes |
|---|---|
| v0.4.2 | Smart X calibration: 55 elmo mex radius, exact-target priority, Resurrect=125 |
| v0.4.1 | Hold A brush selection, A+X filter radial, Y Do Next queue preservation |
| v0.4.0 | Binding presets system (Balanced RTS, Build-First Commander) |
| v0.3.8 | Queue fix, binding UI prototype |
| v0.3.7 | Recoil 2025.06.24 compatibility engine |
