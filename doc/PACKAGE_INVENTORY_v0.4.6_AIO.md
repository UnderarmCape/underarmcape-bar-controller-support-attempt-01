# BAR Xbox Controller Support v0.4.6 AIO Package Inventory

## Release Layout

This release intentionally uses exactly two payload ZIPs. There is no giant
single AIO ZIP.

All seven release assets must remain separate:

| Asset | Size | Purpose |
| --- | ---: | --- |
| `Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat` | 20,875 bytes | Verifies, stages, backs up, and installs both payloads. |
| `README_AIO_CLEAN_INSTALL_v0.4.6.txt` | 2,940 bytes | End-user download and install instructions. |
| `BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_1_OF_2.zip` | 2,015,364,370 bytes | Official vanilla BAR.sdd archive and release manifest. |
| `BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_2_OF_2.zip` | 612,877,675 bytes | Controller-enabled engine, five v0.4.6 Lua widgets, and release manifest. |
| `BAR_Controller_Support_v0.4.6_AIO_RELEASE_NOTES.md` | 4,885 bytes | User-facing changes, limitations, install steps, and tests. |
| `BAR_Xbox_Controller_Support_AI_Continuation_Pack_v0.4.6_STREAMLINED.zip` | 137,878 bytes | Streamlined developer/AI handoff without large binaries. |
| `PACKAGE_INVENTORY_v0.4.6_AIO.md` | This file | Authoritative asset and payload inventory. |

## Payload 1 Contents

- `payload/bar_sdd/BAR_sdd_official_c79bc770f577_clean.zip`
- `payload/release-payload-manifest.json`

The embedded vanilla BAR archive is byte-for-byte identical to the v0.4.5 AIO
source. Its SHA256 is:

`0D147EEACC2D90FF2D5E83F568A1CAE6A11FD2168638D4E47768E3C52EFD5F29`

## Payload 2 Contents

- `payload/engine/recoil_2025.06.24-controller-support-pr2985-win64.zip`
- `payload/lua_widgets/cmd_area_mex.lua`
- `payload/lua_widgets/gui_controller_bindings_ui.lua`
- `payload/lua_widgets/gui_controller_camera_test.lua`
- `payload/lua_widgets/gui_controller_smartx_mouse_audit.lua`
- `payload/lua_widgets/gui_pregameui.lua`
- `payload/release-payload-manifest.json`

The embedded engine archive is byte-for-byte identical to the v0.4.5 AIO
source. Its SHA256 is:

`A6A0686270152943B6967B7ADE01D379E83DD0C3596A8F9E6A882898A764EB64`

No engine code was modified or compiled for v0.4.6.

## Required Lua Files

- `gui_controller_camera_test.lua`: main v0.4.6 controller implementation.
- `gui_pregameui.lua`: required owner-controlled `WG.pregameui` Ready API.
- `cmd_area_mex.lua`: required `WG.controllerAreaMex.issueArea(...)` bridge
  until BAR PR #7874 or equivalent is adopted.
- `gui_controller_bindings_ui.lua`: controller bindings interface.
- `gui_controller_smartx_mouse_audit.lua`: Smart X targeting diagnostic.

The installer explicitly validates all five files before staging and after
installation.

## Streamlined Continuation Pack

The continuation pack contains:

- `START_HERE.md`
- `ACTIVE_CONTINUATION_BIBLE.md`
- `CURRENT_RELEASE_NOTES.md`
- `INSTALL_AND_TEST.md`
- `UPSTREAM_PR_ROADMAP.md`
- `KNOWN_LIMITATIONS_AND_DEFERRED_WORK.md`
- `PACKAGE_INVENTORY.md`
- all five active Lua widgets
- `release_assets/BAR_Controller_Support_v0.4.6_AIO_RELEASE_NOTES.md`
- `archive_reference/OLD_CONTEXT_NOT_REQUIRED_FOR_NORMAL_CONTINUATION.md`

It contains no `.git` directory, engine archive, BAR archive, or AIO payload.

## SHA256 Hashes

| Asset | SHA256 |
| --- | --- |
| `Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat` | `C5771003ED4C1EB2290FF66700FB357959732164907D6D730D3AE27670D1A90A` |
| `README_AIO_CLEAN_INSTALL_v0.4.6.txt` | `34C1FB9D91A40D06AC6D7B84F3C5759ABCFA6150D836A09424BBE5AA337CCF2B` |
| `BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_1_OF_2.zip` | `A4B89A6BB336AED6AFA616B67F75E189B6673C4ACD6A5AEA7AE383DB7603A481` |
| `BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_2_OF_2.zip` | `B98EB75CC714F25B31E18778A502AD3E41CFCF0AAD424A2053CB781636B9172B` |
| `BAR_Controller_Support_v0.4.6_AIO_RELEASE_NOTES.md` | `E38EA1ADF11DFEF6429B6A19FCE63368CFB7B3F7FA4E91D921B958976D9D0464` |
| `BAR_Xbox_Controller_Support_AI_Continuation_Pack_v0.4.6_STREAMLINED.zip` | `4CCB1C2559C30DEF601BA7AAFFAD5855820E80D8C01047E81FF6B6F6F1BC2936` |

## Upstream References

BAR Area Mex API PR:
https://github.com/beyond-all-reason/Beyond-All-Reason/pull/7874

Recoil controller input support remains separate.
