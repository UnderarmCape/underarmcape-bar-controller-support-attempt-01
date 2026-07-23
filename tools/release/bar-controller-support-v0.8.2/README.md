# BAR Controller Support v0.8.2 Experimental

Install with `BAR_Controller_Companion_Installer_v0.8.2_Experimental.exe` from the extracted package. The installer consumes `controller-release-manifest.json`, validates every dynamic component, creates a recovery backup, preserves user configuration, and never launches or terminates BAR.

This release repairs controller input priority for Y Repair, Tactical state cycling, Wait, factory/front queue insertion, Disassemble cleanup shortcuts, visible same-type selection, v0.6 idle navigation, and protected Tactical Self Destruct.

After installation, run `/luaui reset` in BAR if BAR was already open while files were updated. Recovery Mode keeps older public releases, including v0.8.1, available for rollback.
