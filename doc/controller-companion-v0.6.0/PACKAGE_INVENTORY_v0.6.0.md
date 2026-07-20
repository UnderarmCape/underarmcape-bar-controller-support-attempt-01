# v0.6.0 package inventory

The public package is EXE-first and contains:

- v0.6.0 self-contained win-x64 installer and restore executables;
- `companion/BARControllerBridge.exe` and `companion/BARControllerLauncher.exe`;
- the seven controller-owned Lua widgets listed by `manifest.json`;
- four shared Lua Include modules;
- the controller glyph atlas, asset manifest, and provenance/license file;
- schema-3 revision-3 bundled shipping defaults and hash manifest;
- installation, release, property-audit, and style-restoration documentation;
- project license and payload SHA-256 manifest.

It excludes publisher binaries/source, tests, PDBs, build directories, Git metadata, credentials, personal paths/settings, authoring/recovery data, logs, caches, and deployment backups. No custom engine executable is present.

