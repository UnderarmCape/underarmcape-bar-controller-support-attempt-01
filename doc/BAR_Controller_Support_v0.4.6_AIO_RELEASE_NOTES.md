# BAR Xbox Controller Support v0.4.6 - AIO Clean Installer

This prerelease is the full v0.4.6 AIO clean installer. It uses the proven
two-payload v0.4.5 installer structure so the controller-enabled engine and
vanilla BAR payload remain below GitHub's per-file upload limit.

## Highlights

- Full controller pregame flow: commander placement and Ready button.
- Controller Mouse Mode with LuaUI clicks.
- Controller Mouse Mode speed presets.
- Mouse edge clamp behavior.
- Pregame camera modifiers.
- Factory insert-to-front modifier using native Alt behavior.
- T2 metal extractor Smart X upgrades.
- T2 geothermal Smart X upgrades.
- Build/factory radial center information with unit description and stats.
- Build placement spacing fixes.
- Build placement slow pan default.
- Dedicated air transport controls from v0.4.5.
- Command Toast feedback.
- Area Mex, Repair, and Reclaim radial improvements.

## What Is Included

- The working controller-enabled Recoil 2025.06.24 engine/base from the
  previous AIO. No new engine was compiled for v0.4.6.
- The official vanilla BAR.sdd payload used by the previous clean AIO.
- Five current v0.4.6 Lua widgets:
  - `gui_controller_camera_test.lua`
  - `gui_pregameui.lua`
  - `cmd_area_mex.lua`
  - `gui_controller_bindings_ui.lua`
  - `gui_controller_smartx_mouse_audit.lua`
- A clean installer BAT that verifies and combines exactly two payload ZIPs.

## Install Instructions

Download these files into the same folder:

1. `Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat`
2. `README_AIO_CLEAN_INSTALL_v0.4.6.txt`
3. `BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_1_OF_2.zip`
4. `BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_2_OF_2.zip`
5. `BAR_Controller_Support_v0.4.6_AIO_RELEASE_NOTES.md`

Do not manually extract either payload ZIP. Run the BAT installer.

Optional validation commands:

```bat
Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat --payload-check
Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat --dry-run
```

## Known Limitations

- Multiplayer remains blocked or limited by the custom engine requirement
  until engine support is upstreamed and adopted.
- Chobby/LuaMenu overlays and native engine UI are not controllable through
  in-game LuaUI click dispatch.
- Multi-unit X freehand drawn-path movement remains disabled and reverted.
- `cmd_area_mex.lua` remains included until BAR PR #7874 or an equivalent API
  is accepted upstream.
- `gui_pregameui.lua` is included because v0.4.6 exposes the small
  `WG.pregameui` controller Ready API.

## Upstream Status

BAR Area Mex Lua API PR:
https://github.com/beyond-all-reason/Beyond-All-Reason/pull/7874

Recoil controller input support remains separate.

## Rollback

The installer backs up the active `BAR.sdd`, local Chobby override if present,
and `recoil_2025.06.24` engine slot under:

`data\controller-support-v046-aio-clean-backups\<timestamp>`

Restore those folders manually or reinstall the previous known-good AIO.

## Manual Test Checklist

- [ ] Installer `--payload-check` passes.
- [ ] Installer performs a clean install without hash or extraction errors.
- [ ] BAR launches in Singleplayer: Beyond All Reason Dev.
- [ ] A/X places the commander during pregame.
- [ ] A/X activates Ready after placement.
- [ ] Mouse Mode toggles with Back + Start.
- [ ] Back tap cycles all Mouse Mode speed presets.
- [ ] Mouse Mode clamps at all four screen edges without camera edge-pan.
- [ ] Pregame LB + right stick rotates and tilts.
- [ ] Pregame LB + LT + right stick Y zooms.
- [ ] Build and factory radials show name, description, and stats.
- [ ] Factory insert-to-front still uses native Alt behavior.
- [ ] T2 metal extractor and geothermal Smart X upgrades still work.
- [ ] Dedicated air transport controls still work.
- [ ] No Lua errors or OpenGL stack errors occur.

## Files Included

- `Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat`
- `README_AIO_CLEAN_INSTALL_v0.4.6.txt`
- `BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_1_OF_2.zip`
- `BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_2_OF_2.zip`
- `BAR_Controller_Support_v0.4.6_AIO_RELEASE_NOTES.md`
- `BAR_Xbox_Controller_Support_AI_Continuation_Pack_v0.4.6_STREAMLINED.zip`
- `PACKAGE_INVENTORY_v0.4.6_AIO.md`

## SHA256 Hashes

- `Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat`  
  `C5771003ED4C1EB2290FF66700FB357959732164907D6D730D3AE27670D1A90A`
- `BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_1_OF_2.zip`  
  `A4B89A6BB336AED6AFA616B67F75E189B6673C4ACD6A5AEA7AE383DB7603A481`
- `BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_2_OF_2.zip`  
  `B98EB75CC714F25B31E18778A502AD3E41CFCF0AAD424A2053CB781636B9172B`

The final hashes for this release-notes file and the continuation pack are
recorded in `PACKAGE_INVENTORY_v0.4.6_AIO.md`. A file cannot contain its own
final hash, and the continuation pack contains a copy of these release notes.
