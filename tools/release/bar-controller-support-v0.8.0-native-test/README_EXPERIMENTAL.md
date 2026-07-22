# BAR Controller Support v0.8.0 Native Hybrid Targeting Test

**EXPERIMENTAL — NATIVE CONTROLLER TARGETING AND COMPACT RADIAL TEST**

This local test package targets `Beyond All Reason test-30725-99351e5` / upstream commit `99351e53d26f5e55fa007ca1e208b936f22bd3ab`. It adds controller confirmation for BAR's real active target command and packs the authoritative Build/Factory models into compact eight-slot wheels. It is not a stable release and must not replace v0.7.0.

Close BAR, then validate compatibility:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1 -ValidateOnly
```

Install only after validation succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1
```

The installer prints a timestamped backup root and exact rollback command. It refuses a running BAR process, an unrecognized BAR build, or an unrecognized loose vanilla widget. It enables BAR's patched Build Menu, disables the overlapping Grid Menu, and leaves native panels and their focus stroke visible for comparison. Rollback preserves and restores the exact pre-deployment `BYAR.lua`; the scripts never launch or force-kill BAR.

Use `doc/controller-companion-v0.8.0/LIVE_TEST_CHECKLIST.md` for gameplay validation. Read `CONTROLLER_NATIVE_TARGETING.md` for command dispatch and limitation details and `RADIAL_COMPACTION.md` for the wheel invariants. Restore before rebasing onto a BAR update.
