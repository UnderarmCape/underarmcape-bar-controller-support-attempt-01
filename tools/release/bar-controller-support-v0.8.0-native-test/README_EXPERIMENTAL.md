# BAR Controller Support v0.8.0 Experimental

**EXPERIMENTAL — V0.7 TACTICAL RESTORE, MIXED RADIAL SECTORS, NATIVE CELLS, AND IDLE CONTROL TEST**

This non-public package targets `Beyond All Reason test-30735-bf9c7bf` / upstream `bf9c7bfdba26704832157bba47f3653ba8bdd8d2`. It does not replace or modify the public v0.7.0 release.

Validate from an extracted package with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1 -ValidateOnly
```

Install only while BAR, Spring/Recoil, and controller processes are closed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1
```

The deployment refuses active BAR processes and unknown native bases, creates a timestamped hash-verified backup, preserves personal configuration, and prints the exact rollback command. It never launches or force-kills BAR. Use `doc/controller-companion-v0.8.0/LIVE_TEST_CHECKLIST.md` for the required 58 manual checks; automated tests do not establish live gameplay success.
