# BAR Controller Support v0.8.0 — v0.6 Input Restore & UI Polish

**Experimental controller-support release. Risky and potentially game-breaking updates are intentionally permitted by project policy. Installation is always user-approved and never forced.**

This release restores the proven v0.6.1 tactical point/area state machine, deterministic single-A selection, intentional double-tap-A visible same-type selection, v0.6 idle traversal, and LB+D-pad Down idle same-type selection. It retains compact mixed Build/Factory radial pages, native BAR Build Menu cells, constructor/factory semantic categories, Tactical Self Destruct protection, state cycling, the redesigned bridge console, and Spring/Recoil session PID tracking.

The companion now checks the official public GitHub repository once at startup and every six hours, presents keyboard-only U/N/V/R choices, supports a paginated Recovery Mode through verified v0.6.0, and distinguishes same-version milestones by release sequence, publication time, tag, and commit. Downloads, detached manifests, ZIP boundaries, and every payload component are SHA-256 validated before installation.

Every update, downgrade, reinstall, or Recovery Mode switch creates a timestamped transaction backup. An external validated updater waits only for the current companion PID, atomically replaces locked files, validates final hashes, writes `installed-release.json`, restarts the companion when requested, and automatically restores the backup on failure. BAR is never terminated. If an install occurs while BAR is running, enter `/luaui reset`; native-override changes may still require an engine restart for non-Lua content.

Known risks:

- Native BAR updates can invalidate loose native overrides; rebase against the new upstream files before continuing.
- Recovery entries before the manifest format use a trusted compatibility adapter and preserve the modern recovery companion while switching verified LuaUI payloads.
- Controller menus, selections, or commands may reset after `/luaui reset`.
- Automated validation does not claim manual gameplay success.

Supported Recovery Mode floor: **v0.6.0**.

Commit and exact package SHA-256 are recorded in the detached `controller-release-manifest.json` release asset.
