# Standalone Update Bootstrap (`STANDALONE_UPDATE_BOOTSTRAP.md`)

## Target & Purpose

Users trapped on defective legacy bridge builds (such as v0.8.0) whose update prompt loops prevent in-place self-updating can run `BAR_Controller_Update_Bootstrap.exe`.

## Key Capabilities

1. **Independent Execution**: Runs as a standalone console binary without relying on a running bridge.
2. **Official Repository Boundary**: Queries official releases from `UnderarmCape/underarmcape-bar-controller-support-attempt-01`.
3. **Hashes & Manifest Validation**:
   - Validates package SHA-256 hash before extraction.
   - Validates detached release manifest and component inventory.
4. **Transactional Backup & Rollback**:
   - Creates a timestamped recovery backup under `recovery-backups/`.
   - Preserves user configuration (`springsettings.cfg`, `LuaUI/Config`, `launcher-config.json`, `user-data`).
   - Stops running bridge processes cleanly.
   - Applies update components transactionally.
   - Automatically rolls back to the backup state if any component installation fails.
5. **Security**: Does not execute arbitrary remote scripts; only applies signed/hash-validated release components through the validated helper framework.
