# Installation Path and Shortcut Audit (`INSTALLATION_PATH_AND_SHORTCUTS.md`)

## System Directory & Executable Audit

- **Running Executable**: `BARControllerBridge.exe`
- **Managed Installation Root**: `%LocalAppData%\Programs\BARControllerCompanion`
- **BAR Data Directory**: `%LocalAppData%\Programs\Beyond-All-Reason\data`
- **Start Menu Shortcut**: `BAR Controller Companion.lnk` -> `%LocalAppData%\Programs\BARControllerCompanion\BARControllerLauncher.exe`
- **Desktop Shortcut**: `BAR Controller Companion.lnk` -> `%LocalAppData%\Programs\BARControllerCompanion\BARControllerLauncher.exe`
- **Helper Executable Target**: `%LocalAppData%\Programs\BARControllerCompanion\BARControllerUpdater.exe`

## Post-Update Verification & Rules

- Managed shortcuts point directly to the current installed bridge launcher.
- Diagnostics confirm running executable path matches the managed installation root.
- User downloads or unmanaged paths are never modified or deleted automatically.
