# v0.5.0 Companion Bridge Pass 1 Test Notes

## Manual vanilla BAR result

Kailil reported the companion UDP bridge worked flawlessly on vanilla BAR.

Passed:

1. Controller detected by the bridge.
2. BAR debug panel selected the companion UDP backend.
3. Left stick panned the camera.
4. Right stick and trigger camera behavior worked.
5. A/select worked.
6. X Smart Action worked.
7. Build menu opened.
8. Radials generally worked.
9. Ctrl+C neutralized/released input in BAR.
10. Restarting the bridge reconnected without restarting BAR.

## Pass 1 implementation

- Bridge output renamed to `BARControllerBridge.exe`.
- Bridge enforces `CamSpringLockCardinalDirections = 0` before polling.
- Camera settings changes are backup-aware and preserve unrelated lines.
- Bridge reports already-correct, added, changed, missing, and failed states.
- Bridge uses a named mutex to prevent duplicate instances.
- Added `BARControllerLauncher.exe`.
- Launcher starts the bridge minimized, avoids duplicates, launches the original
  BAR target/arguments/working directory, logs errors, and exits.
- Added companion-missing and companion-connected LuaUI overlays.
- Added local-first installer, optional conservative GitHub update check,
  manifest validation, shortcut backup/patching, install state, and idempotency.
- Added shortcut/widget/camera restore workflow.
- Added native public installer and restore executables.
- Installer now enables exactly `Controller Camera Test` and
  `Controller Bindings UI` in `LuaUI/Config/BYAR.lua`.
- Restore now restores the recorded widget config and overwritten widget
  backups by default; camera restore remains opt-in.
- Bridge logging is quiet by default, with packet-rate output behind
  `--verbose`.
- Added package staging script and versioned package directory.

## Files changed or added

- `BAR_DATA_PATH.txt`
- `Stage_BAR_Controller_Companion_v0.5.0.ps1`
- `companion/BarControllerCompanion.csproj`
- `companion/CameraSettings.cs`
- `companion/Program.cs`
- `companion/Launcher/BARControllerLauncher.csproj`
- `companion/Launcher/Program.cs`
- `companion/Installer/BARControllerCompanionInstaller.csproj`
- `companion/Installer/Program.cs`
- `companion/Restore/BARControllerCompanionRestore.csproj`
- `companion/Restore/Program.cs`
- `companion/Shared/InstallModels.cs`
- `companion/Shared/ReleaseOperations.cs`
- `companion/README.md`
- `docs/README.md`
- `docs/RELEASE_NOTES_v0.5.0.md`
- `docs/PACKAGE_INVENTORY_v0.5.0.md`
- `controller-mod/luaui/Widgets/controller_socket_bridge.lua`
- `controller-mod/luaui/Widgets/gui_controller_camera_test.lua`
- `packaging/Install_BAR_Controller_Companion_v0.5.0.ps1`
- `packaging/Restore_BAR_Controller_Companion_v0.5.0.ps1`
- `packaging/manifest.json`
- `test-output/v0.5.0-companion-bridge-poc.md`

The package staging directory also contains copied, unchanged supporting widgets:

- `gui_pregameui.lua`
- `cmd_area_mex.lua`
- `gui_controller_bindings_ui.lua`
- `gui_controller_smartx_mouse_audit.lua`

## Automated validation

- All four .NET projects build in Release with zero warnings/errors.
- Bridge, launcher, installer, and restore publish as self-contained single-file
  `win-x64` executables.
- Lua syntax validation passes for the socket bridge and controller widget.
- Lua syntax validation passes for all six staged widget files.
- PowerShell parser validation passes for the dev install/restore, staging, and
  isolated release-tool test scripts.
- Camera settings smoke tests cover missing-line add, existing-line change,
  already-correct no-op, timestamped backup, unrelated-line preservation, CRLF
  preservation, and the required BAR-restart notice when a matching process is
  running.
- UDP/parser tests cover malformed packets, sequence handling, restart,
  disconnect, staleness, and neutralization.
- Captured quiet bridge output contains startup/status lines and no packet-rate
  line. Captured `--verbose` output reports packet rate.
- The final published bridge emitted 26 valid packets in 1.4 seconds at a
  configured 20 Hz; its measured report was 21.0 packets/second.
- Isolated installer test covers:
  - bundled local installation;
  - six-widget copy;
  - existing widget backup;
  - byte-for-byte preservation of all unrelated `BYAR.lua` content;
  - exact enabling of `Controller Camera Test` and
    `Controller Bindings UI`;
  - widget config backup and restore;
  - camera setting change and backup;
  - shortcut metadata capture and patch;
  - second-run idempotency;
  - shortcut restore;
  - automatic overwritten-widget restore;
  - leaving newly installed widgets in place;
  - leaving the camera setting at `0` during default restore;
  - optional camera settings restore.
- Isolated launcher test confirms:
  - the launcher can start the bridge before a UDP listener exists;
  - original arguments and working directory are used;
  - an already-running bridge is reused;
  - no duplicate bridge process is created;
  - launcher exits successfully after starting the target.

## Safety checks

- BAR was not launched by automated validation.
- The live BAR settings, widgets, executable, and shortcuts were not modified.
- No custom Recoil engine was built or installed.
- No Windows startup entry was added.
- Nothing was pushed or published.
- The final package folder, versioned zip, and matching SHA256 checksum were
  generated.
- Final public release naming:
  - title: `BAR Controller Support v0.5.0 — Widget + Companion Release`;
  - tag: `controller-support-v0.5.0-widget-companion`;
  - asset: `BAR_Controller_Support_v0.5.0_Widget_Companion.zip`;
  - checksum: `BAR_Controller_Support_v0.5.0_Widget_Companion.zip.sha256`.

## Tracked gameplay issues not fixed

1. Area Mex is missing from the tactical radial for
   builders/constructors/commanders.
2. Hold X plus drag with multiple selected units sends Fight instead of Move.
3. Smart X with a T2 construction bot on a completed T1 mex can crash
   `gui_controller_camera_test.lua`.

These are deliberately outside Pass 1.
