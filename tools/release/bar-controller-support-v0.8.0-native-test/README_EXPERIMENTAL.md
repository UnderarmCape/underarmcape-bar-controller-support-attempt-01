# BAR Controller Support v0.8.4 Experimental

**EXPERIMENTAL - SMART X, INSERT, AND TACTICAL REPAIR TEST**

This native-test package targets `Beyond All Reason test-30735-bf9c7bf` / upstream `bf9c7bfdba26704832157bba47f3653ba8bdd8d2` and mirrors the v0.8.4 general command insertion, RT+RB suppression, Smart X repair/reclaim priority, Disassemble target ownership, expanded idle pools, and direct custom self-destruct payload before public release publication.

Validate from an extracted package with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1 -ValidateOnly
```

Install only while BAR, Spring/Recoil, and controller processes are closed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install_v0.8.0_NATIVE_TEST.ps1
```

The deployment refuses active BAR processes and unknown native bases, creates a timestamped hash-verified backup, preserves personal configuration, and prints the exact rollback command. It never launches or force-kills BAR. Use `doc/controller-companion-v0.8.4/LIVE_TEST_CHECKLIST.md` for manual gameplay checks; automated tests do not establish live gameplay success.
