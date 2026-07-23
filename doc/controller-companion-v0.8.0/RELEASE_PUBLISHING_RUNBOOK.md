# Release publishing runbook

1. Keep the release branch clean and verify exact historical/current package hashes.
2. Run all Lua/.NET/release tests and create the commit-bound validation stamp.
3. Build with `tools/release/Build-ControllerPublicRelease.ps1` and independently validate extraction/inventory.
4. Deploy with a timestamped backup, verify live hashes, and validate rollback without launching BAR.
5. Push the branch and confirm local/remote HEAD match.
6. Dry-run `Publish-HistoricalControllerReleases.ps1`, then publish missing milestones oldest-first.
7. Dry-run and invoke `Publish-ControllerRelease.ps1` for the current normal release with `-Latest`.
8. Verify release asset digests, GitHub Latest, live updater catalog, Installed/Latest markers, and final clean state.

The publisher hard-stops on dirty state, failed/missing validation, wrong tag commit, package/manifest/inventory mismatch, authentication failure, or conflicting assets. Correct existing releases are idempotently verified; only missing sidecars are added safely.

Current release command (run first with `-DryRun`, then remove it):

```powershell
tools/release/Publish-ControllerRelease.ps1 -Commit $commit -Version 0.8.0 -DisplayVersion 'v0.8.0 Experimental' -Tag controller-support-v0.8.0-v06-input-restore-ui-polish -Slug v06-input-restore-ui-polish -Title 'BAR Controller Support v0.8.0 — v0.6 Input Restore & UI Polish' -Channel experimental -ReleaseNotesPath artifacts/v0.8.0-public-release/RELEASE_NOTES_v0.8.0.md -PackagePath artifacts/v0.8.0-public-release/BAR_Controller_Support_v0.8.0_V06_INPUT_RESTORE_UI_POLISH.zip -ManifestPath artifacts/v0.8.0-public-release/controller-release-manifest.json -PayloadInventoryPath artifacts/v0.8.0-public-release/payload-sha256.json -ExpectedPackageSha256 $packageSha256 -ValidationStampPath artifacts/v0.8.0-public-release/controller-release-validation.json -Latest -DryRun
```

Historical exact-artifact command (run first with `-DryRun`, then remove it):

```powershell
tools/release/Publish-HistoricalControllerReleases.ps1 -DryRun
```

Manifest-driven live deployment and validation commands:

```powershell
tools/release/Deploy-ControllerPublicRelease.ps1 -PackagePath artifacts/v0.8.0-public-release/BAR_Controller_Support_v0.8.0_V06_INPUT_RESTORE_UI_POLISH.zip -ManifestPath artifacts/v0.8.0-public-release/controller-release-manifest.json -PayloadInventoryPath artifacts/v0.8.0-public-release/payload-sha256.json
tools/release/Test-ControllerReleaseSystem.ps1 -PackagePath artifacts/v0.8.0-public-release/BAR_Controller_Support_v0.8.0_V06_INPUT_RESTORE_UI_POLISH.zip -ManifestPath artifacts/v0.8.0-public-release/controller-release-manifest.json -PayloadInventoryPath artifacts/v0.8.0-public-release/payload-sha256.json -BackupRoot $backupRoot
```
