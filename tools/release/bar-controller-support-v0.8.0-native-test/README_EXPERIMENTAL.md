# BAR Controller Support v0.8.0 Native Input and Disassemble Test

**EXPERIMENTAL — INPUT STATE, FACTORY SHORTCUT, AND VANILLA DISASSEMBLE TEST**

This local-only test package targets `Beyond All Reason test-30725-99351e5` / upstream commit `99351e53d26f5e55fa007ca1e208b936f22bd3ab`. It repairs fresh A/X area confirmation, one-press build cancellation, native factory quantities, Queue Mode and Move State shortcuts, and constructor-cached Disassemble with actual vanilla target selection. It is not a stable release and does not replace v0.7.0.

Close BAR, then validate compatibility:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1 -ValidateOnly
```

Install only after validation succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1
```

The installer refuses running BAR/controller processes, unknown BAR builds, and unrecognized native overrides. It prints a timestamped backup root and exact strict rollback command. It preserves personal BAR/controller configuration, keeps Native Experimental enabled with Legacy fallback available, and never launches or force-kills BAR.

Use `doc/controller-companion-v0.8.0/LIVE_TEST_CHECKLIST.md` for the 49-step gameplay pass. The targeting, factory-shortcut, and vanilla-selection Disassemble documents describe input ownership and remaining native boundaries.
