# Native override maintenance

This experiment installs four loose LuaUI files over BAR's Rapid-packed production files. Loose VFS files win over the packed copies. Every override is pinned to BAR upstream commit `99351e53d26f5e55fa007ca1e208b936f22bd3ab`, live identity `Beyond All Reason test-30725-99351e5`, and Recoil `2026.06.12`.

`native-overrides/native-override-manifest.json` is authoritative for base hashes, patched hashes, source paths, and purpose.

| Live file | Base SHA-256 | Controller extension |
|---|---|---|
| `LuaUI/Widgets/unit_smart_select.lua` | `b0442a5549a8a74bffba7c77be536b90b81a6d77d2551664ce796235ce3d39e7` | Native selection/toggle/filter API |
| `LuaUI/Widgets/unit_smart_area_reclaim.lua` | `53241a515f92f73f061e253b49dff76e0327994178833067802b4409b434ef73` | Single/any-area/same-type-area reclaim API and controller radius |
| `LuaUI/Widgets/gui_ordermenu.lua` | `445053a54056dd82d5d348e43cbb6b0f534b6af3ef03cd2b479eca7eeef2caf3` | Actual descriptor export, activation, state cycling, focus |
| `LuaUI/Widgets/gui_buildmenu.lua` | `082298c94eb24c17db180d5be34ed4a79bccb7751450f76d685f44cf346a12dd` | Actual build cell navigation, activation, focus and stable gamepad grid |

## Deployment safety

Run `tools/dev-scripts/Deploy_v0.8.0_Native_Test.ps1`. If a loose target exists, its hash must equal the manifest's base or patched hash. If no loose target exists, deployment accepts the packed base only when `infolog.txt` identifies the pinned BAR build. An update or unknown override is refused before any write.

`-AllowUnknownBase` is an explicit development escape hatch, not an update mechanism. Inspect and rebase first. The deployment always backs up an existing unknown file when that switch is deliberately used.

The timestamped deployment manifest records whether each live file existed, its pre/post hash, and its exact backup. It also backs up `LuaUI/Config/BYAR.lua` and `springsettings.cfg`. For this experiment it records and applies `Build menu = 165` and `Grid menu = 0`, preventing duplicate build panels while ensuring the patched API loads. Rollback restores the user's exact former menu choice. BAR is never launched or force-killed.

## Expected BAR-update failure modes

- BAR changes a patched widget in the Rapid package: the build identity check fails for absent loose files.
- BAR or another mod installs a new loose copy: the loose-file hash check fails.
- A widget renames a local or changes its `WG` contract: a clean text rebase may still parse but fail the native harness or gameplay test.
- Recoil changes active-command argument order or reclaim parameter semantics: reclaim/build/order activation requires engine-source re-audit.
- BAR changes widget enablement or replaces Build Menu with Grid Menu: the controller API may not initialize and native paths safely report unavailable.

Leaving an old loose override installed after a BAR update can mask the updated packed widget. Restore before updating/rebasing whenever possible.

## Rebase procedure

1. Close BAR and the companion.
2. Run the recorded restore command and verify pre-deployment hashes.
3. Identify the new BAR build, Rapid package, Recoil version, and exact upstream commit.
4. Download/extract the four new upstream files without modifying them; record SHA-256 values.
5. Reapply only the marked `CONTROLLER NATIVE UI INTEGRATION` blocks, adapting to new native helpers rather than carrying old surrounding code.
6. Update the override directory name, manifest identities, base hashes, patched hashes, and audit.
7. Parse every Lua file, run all harnesses and .NET tests, and exercise deploy/actual restore/deploy in a sandbox or closed live installation.
8. Perform the manual checklist before treating the new base as compatible.

## Rollback

Use the exact command printed by deployment, or:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev-scripts/Restore_v0.8.0_Native_Test.ps1 -BackupRoot "<recorded backup root>"
```

The restore tool refuses if BAR/controller processes are active, if a backup hash is wrong, if a target escapes the recorded BAR data directory, or if an installed file changed after deployment. New files are moved into recoverable rollback artifacts rather than deleted. Use `-ValidateOnly` to audit the rollback set without changing live files.
