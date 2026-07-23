# BAR Controller Support v0.8.0 Experimental

Install with `BAR_Controller_Companion_Installer_v0.8.0_Experimental.exe` from the extracted package. The installer consumes `controller-release-manifest.json`, validates every dynamic component, creates a recovery backup, and never launches or terminates BAR.

When installing while BAR is running, enter `/luaui reset` after success. Use `BARControllerBridge.exe recover` for Recovery Mode or `BARControllerBridge.exe catalog` for a noninteractive catalog listing.

The detached manifest and checksum assets on the official GitHub release authenticate the outer ZIP. The embedded manifest authenticates every extracted payload file without relying on a fixed inventory size.
