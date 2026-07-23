# BAR Controller Support v0.8.3 Experimental

Install with `BAR_Controller_Companion_Installer_v0.8.3_Experimental.exe` from the extracted package. The installer consumes `controller-release-manifest.json`, validates every dynamic component, creates a recovery backup, preserves user configuration, and never launches or terminates BAR.

This release repairs Smart X direct repair, unifies Insert Queue on RB+A, restores Disassemble chord priority, protects same-target double-tap selection, keeps Tactical state actions open, and preserves the protected Self Destruct flow.

Use `Install_v0.8.3.ps1` for a scripted install from an extracted package. Recovery Mode and the updater should still expose earlier public releases, including v0.8.2.
