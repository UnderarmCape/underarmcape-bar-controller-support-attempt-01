# External self-update helper

`BARControllerUpdater.exe` is copied to isolated validated staging before launch. It rereads the transaction plan, outer package digest, detached manifest digest, staging marker, and every component hash before waiting for the exact companion PID/path. It never kills a process and never waits for BAR.

After the companion exits voluntarily, the helper backs up all affected files/state, writes a journal, performs same-directory atomic replacements, validates final hashes, writes `installed-release.json`, and restarts the companion when requested. Any failure restores and revalidates the backup; a half-installed release is never marked Installed.

The same helper supports an already validated package/staging/manifest tuple for local deployment and `--validate-backup` for strict journal, backup, and preserved-snapshot verification. Those modes use the same transaction engine as online Update and Recovery Mode.
