# BAR Controller Support v0.8.0 Native Input Polish Test

**EXPERIMENTAL — AREA CONFIRMATION, DISASSEMBLE, AND HINT POLISH TEST**

This local-only test package targets `Beyond All Reason test-30725-99351e5` / upstream commit `99351e53d26f5e55fa007ca1e208b936f22bd3ab`. It repairs authoritative second-press A/X area confirmation, constructor-only Build Radial eligibility, repeatable Move State taps, chord arbitration, constructor-cached Disassemble selection/reclaim behavior, and readable runtime hints with Bindings UI controls. It is not a stable release and does not replace v0.7.0.

Close BAR, then validate compatibility:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1 -ValidateOnly
```

Install only after validation succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1
```

The installer refuses running BAR/controller processes, unknown BAR builds, and unrecognized native overrides. It prints a timestamped backup root and exact strict rollback command. It preserves personal BAR/controller configuration, keeps Native Experimental enabled with Legacy fallback available, and never launches or force-kills BAR.

Use `doc/controller-companion-v0.8.0/LIVE_TEST_CHECKLIST.md` for the 59-step gameplay pass. The targeting, radial eligibility, chord arbitration, Disassemble, reclaim-ordering, and hint-runtime documents describe input ownership and remaining native boundaries.
