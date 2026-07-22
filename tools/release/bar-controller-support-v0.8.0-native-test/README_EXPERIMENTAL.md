# BAR Controller Support v0.8.0 Hybrid Area / Idle Repair Test

**EXPERIMENTAL — HYBRID AREA TARGETING, GLOBAL RADIAL PAGING, AND VANILLA IDLE CONTROL TEST**

This local-only test package targets `Beyond All Reason test-30735-bf9c7bf` / upstream commit `bf9c7bfdba26704832157bba47f3653ba8bdd8d2`. The controller owns area/front/rectangle gestures while current BAR descriptors, transformations, `CommandNotify`, and final dispatch remain native. Build/Factory shoulders traverse one Economy → Combat → Utility page sequence, and controller idle navigation shares the live Idle Builders icon action. It is not a stable release and does not replace v0.7.0.

Close BAR, then validate compatibility:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1 -ValidateOnly
```

Install only after validation succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1
```

The installer refuses running BAR/controller processes, unknown BAR builds, and unrecognized native overrides. It prints a timestamped backup root and exact strict rollback command. It preserves personal BAR/controller configuration, keeps Native Experimental enabled with Legacy fallback available, and never launches or force-kills BAR.

Use `doc/controller-companion-v0.8.0/LIVE_TEST_CHECKLIST.md` for the focused 43-step gameplay pass. The packaged v0.8.0 documents describe hybrid ownership, exactly-once dispatch, global paging, shared vanilla idle actions, and rollback.
