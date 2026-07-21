# BAR Controller Support v0.8.0 Native Test

**EXPERIMENTAL — MAY REQUIRE REBASE AFTER BAR UPDATES**

This local test package targets `Beyond All Reason test-30714-2a9339d` / upstream commit `2a9339d0c587c1444b2b839ba29dc954f1a13b17`. It is not a stable release and must not replace v0.7.0.

Close BAR, then validate compatibility:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1 -ValidateOnly
```

Install only after validation succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1
```

The installer prints a timestamped backup root and exact rollback command. It refuses a running BAR process, an unrecognized BAR build, or an unknown loose vanilla widget. The experiment enables BAR's patched Build Menu and disables the overlapping Grid Menu; rollback restores the exact prior `BYAR.lua`. It never launches or force-kills BAR.

Use `doc/controller-companion-v0.8.0/LIVE_TEST_CHECKLIST.md` for gameplay validation. Restore before rebasing onto a BAR update. See `NATIVE_OVERRIDE_MAINTENANCE.md` for the exact update and rollback policy.
