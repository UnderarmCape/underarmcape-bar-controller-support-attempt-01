# BAR Controller Support v0.8.0 Native Regression Repair Test

**EXPERIMENTAL — SMART X, RADIAL ROUTING, ENEMY DISASSEMBLE, AND AREA CONFIRMATION TEST**

This local-only test package targets `Beyond All Reason test-30725-99351e5` / upstream commit `99351e53d26f5e55fa007ca1e208b936f22bd3ab`. It restores the commit `95e4b907` Smart X decision tree, adds narrow native Repair/Reclaim routing, repairs Build/Factory paging and the Tactical toggle chord, calls the live Idle Builders API, supports enemy Disassemble targets, and keeps native area-command owners alive through final confirmation. It is not a stable release and does not replace v0.7.0.

Close BAR, then validate compatibility:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1 -ValidateOnly
```

Install only after validation succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1
```

The installer refuses running BAR/controller processes, unknown BAR builds, and unrecognized native overrides. It prints a timestamped backup root and exact strict rollback command. It preserves personal BAR/controller configuration, keeps Native Experimental enabled with Legacy fallback available, and never launches or force-kills BAR.

Use `doc/controller-companion-v0.8.0/LIVE_TEST_CHECKLIST.md` for the focused 47-step gameplay pass. The packaged v0.8.0 documents describe the input-priority rules, native owners, diagnostics, target representation, and rollback boundary.
