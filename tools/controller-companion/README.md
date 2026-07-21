# BAR Controller Companion v0.6.1 development

The source projects report v0.6.1 for the radial typography and color-authoring release. Public packaging is produced only by the frozen-runtime v0.6.1 release workflow.

## v0.6 defaults and update commands

The bridge performs a short, fail-soft background check for controller UI defaults and public application releases. It never applies a release at startup. Manual commands are:

```text
BARControllerBridge check
BARControllerBridge defaults
BARControllerBridge update
BARControllerBridge status
BARControllerBridge reload
BARControllerBridge help
```

Defaults are checked for schema, compatibility, SHA-256, ranges, and known UI/action/category IDs, then handed to LuaUI through `LuaUI/Config/BARControllerSupport`. A newer pair backs up the previous known-good revision and older remote data cannot downgrade the cache. Application packages require user approval and a GitHub asset digest or `.sha256` sidecar. `update --yes` approves download only; `update --yes --apply` also approves launching the verified installer.

BAR Controller Companion adds Xbox/XInput controller input to vanilla BAR
without replacing Recoil or injecting into the game. The bridge sends physical
controller state over localhost UDP. LuaUI adapts that state to the same table
shape used by the older native controller API.

The native `Spring.GetAvailableControllers` and `Spring.GetControllerState`
backend remains preferred whenever the engine provides it.

## Recommended installation

Extract the release package and run:

```text
BAR_Controller_Companion_Installer_v0.5.1.exe
```

The local bundled package is always the default and does not require internet.
To optionally check the official repository for a newer compatible
`BAR_Controller_Support_v*_Widget_Companion.zip` release:

```powershell
.\BAR_Controller_Companion_Installer_v0.5.1.exe --check-updates
```

The prompt defaults to No. A downloaded package is used only after the user
accepts and its `manifest.json` and required files validate. Any online failure
falls back to the bundled package.

The installer:

- copies six LuaUI widgets into the normal BAR data directory;
- backs up widgets it overwrites;
- installs `BARControllerBridge.exe` and `BARControllerLauncher.exe` under
  `%LOCALAPPDATA%\Programs\BARControllerCompanion`;
- safely sets `CamSpringLockCardinalDirections = 0`;
- backs up and retargets the existing desktop and Start Menu BAR shortcuts;
- records the original BAR target, arguments, working directory, and icon in
  `launcher-config.json`;
- does not launch BAR or add Windows startup behavior.

Running the installer again is supported. Existing original backups and launch
metadata are reused rather than stacking shortcut patches.

## Normal shortcut workflow

After installation, use the normal `Beyond-All-Reason` desktop or Start Menu
shortcut.

`BARControllerLauncher.exe`:

1. checks whether `BARControllerBridge.exe` is already running;
2. starts it minimized if needed;
3. waits briefly;
4. launches the original BAR shortcut target with its original arguments and
   working directory;
5. exits.

The launcher does not alter or replace `Beyond-All-Reason.exe`. Errors are
written to `%LOCALAPPDATA%\Programs\BARControllerCompanion\launcher.log` and
shown in a message box.

## Manual bridge use

The published bridge can also be run directly:

```powershell
.\BARControllerBridge.exe
```

Optional development arguments:

```powershell
.\BARControllerBridge.exe --port 28777 --rate 120
```

Stop it with Ctrl+C. Only one bridge instance runs at a time.

The UDP protocol is:

```text
BARCTRL1|sequence|connected|lx|ly|rx|ry|lt|rt|buttons
```

- Sticks use signed SDL-style `-32768..32767` values.
- Triggers use `0..32767`.
- `buttons` is a 21-character SDL-order `0`/`1` string.
- XInput does not expose Guide, so SDL button 5 remains released.

## Camera setting

On startup, the bridge verifies:

```text
CamSpringLockCardinalDirections = 0
```

An explicitly supplied settings path is honored first. Otherwise it looks for
the workspace `BAR_DATA_PATH.txt` when available, then a path file beside the
bridge, and finally falls back to
`%LOCALAPPDATA%\Programs\Beyond-All-Reason\data\springsettings.cfg`.

If the line is missing or has another value, the settings file is backed up
beside the original before only that setting is changed. An already-correct file
is not rewritten.

BAR must be restarted after this setting changes. LuaUI reload/reset is not
enough. The setting is not restored when a controller disconnects or when the
bridge exits.

## LuaUI feedback

When the companion backend is required and fresh packets are not arriving, the
controller widget displays:

```text
Controller Companion Not Running
Start BARControllerBridge.exe, then return to BAR.
```

When packets resume after a missing or stale state, it briefly displays:

```text
Controller Companion Connected
```

These messages are transition/rate limited and are never shown when the native
Spring controller API is active.

## Restore

Run `BAR_Controller_Companion_Restore_v0.5.1.exe` to restore recorded Desktop
and Start Menu shortcuts, overwritten Lua widgets, and the widget config.

The camera setting remains at `0` by default. To intentionally restore the
recorded pre-install `springsettings.cfg` backup:

```powershell
& "$env:LOCALAPPDATA\Programs\BARControllerCompanion\BAR_Controller_Companion_Restore_v0.5.1.exe" --restore-camera
```

Restore does not blindly delete companion files or user-created widgets.
Legacy PowerShell scripts remain under `tools\dev-scripts` for development and
troubleshooting only.

## Manual BAR results

The UDP bridge baseline was manually verified on vanilla BAR for v0.5.0 and
preserved for v0.5.1:

- controller detection and companion backend selection;
- left-stick camera pan;
- right-stick and trigger camera behavior;
- A/select and X Smart Action;
- build menu and radial operation;
- Ctrl+C neutralization/release in BAR;
- bridge restart and reconnect without restarting BAR.

## v0.5.1 gameplay fixes

- Area Mex appears in the Tactical radial for eligible mex-capable
  builders/constructors/commanders.
- Hold X plus drag with multiple selected units issues Move instead of Fight.
- Smart X with a T2 construction bot on a completed T1 mex no longer crashes
  `gui_controller_camera_test.lua`.

These fixes passed live manual testing while the v0.5.0 companion, launcher,
installer, shortcut, and camera-setting workflow remained unchanged.

## Current limitations

- Windows/XInput only.
- Controller index 0 only.
- No controller output or vibration.
- Guide is unavailable through `XInputGetState`.
