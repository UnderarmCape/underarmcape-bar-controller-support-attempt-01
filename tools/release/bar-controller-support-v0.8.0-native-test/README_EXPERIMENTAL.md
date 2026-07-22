# BAR Controller Support v0.8.0 Native Hybrid Test

**EXPERIMENTAL — NATIVE PANELS AND FOCUS VISIBLE FOR VALIDATION**

This local test package targets `Beyond All Reason test-30714-2a9339d` / upstream commit `2a9339d0c587c1444b2b839ba29dc954f1a13b17`. It restores the v0.7 controller radial presentation over authoritative vanilla Build Menu and Order Menu state. It is not a stable release and must not replace v0.7.0.

Close BAR, then validate compatibility:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1 -ValidateOnly
```

Install only after validation succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1
```

The installer prints a timestamped backup root and exact rollback command. It refuses a running BAR process, an unrecognized BAR build, or an unrecognized loose vanilla widget. Recorded base, prior-test, and current-test hashes are accepted. The experiment enables BAR's patched Build Menu, disables the overlapping Grid Menu, and deliberately leaves native panels and their focus stroke visible for comparison. Rollback restores the exact prior `BYAR.lua`. It never launches or force-kills BAR.

Use `doc/controller-companion-v0.8.0/LIVE_TEST_CHECKLIST.md` for gameplay validation. Restore before rebasing onto a BAR update. See `HYBRID_RADIAL_REPAIR_DESIGN.md` and `NATIVE_OVERRIDE_MAINTENANCE.md` for architecture, compatibility, and rollback policy.
