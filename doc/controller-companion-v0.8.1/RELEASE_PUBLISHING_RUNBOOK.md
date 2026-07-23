# Release Publishing Runbook

Release identity:

- tag: `controller-support-v0.8.1-disassemble-idle-hints-polish`
- version: `0.8.1`
- display: `v0.8.1 Experimental`
- asset: `BAR_Controller_Support_v0.8.1_DISASSEMBLE_IDLE_HINT_REPAIR.zip`
- title: `BAR Controller Support v0.8.1` plus Unicode em dash plus `Disassemble, Idle & Hint Repair`

Run order:

1. Build and test on the release branch.
2. Commit and rerun clean-tree deploy validation.
3. Build the public package with `tools/release/Build-ControllerPublicRelease.ps1`.
4. Deploy with `tools/release/Deploy-ControllerPublicRelease.ps1`.
5. Validate rollback and package state with `tools/release/Test-ControllerReleaseSystem.ps1`.
6. Push the branch.
7. Publish with `tools/release/Publish-ControllerRelease.ps1 -Latest`.
8. Verify GitHub Latest, updater catalog, Recovery Mode, installed state, hashes, remote HEAD, and clean worktree.

Encoding-safe publish shape:

```powershell
$commit = git rev-parse HEAD
$packageSha256 = (Get-Content artifacts\v0.8.1-public-release\BAR_Controller_Support_v0.8.1_DISASSEMBLE_IDLE_HINT_REPAIR.zip.sha256).Split(' ')[0]
$title = 'BAR Controller Support v0.8.1 ' + [char]0x2014 + ' Disassemble, Idle & Hint Repair'
tools\release\Publish-ControllerRelease.ps1 -Commit $commit -Version 0.8.1 -DisplayVersion 'v0.8.1 Experimental' -Tag controller-support-v0.8.1-disassemble-idle-hints-polish -Slug disassemble-idle-hints-polish -Title $title -Channel experimental -ReleaseNotesPath artifacts\v0.8.1-public-release\RELEASE_NOTES_v0.8.1.md -PackagePath artifacts\v0.8.1-public-release\BAR_Controller_Support_v0.8.1_DISASSEMBLE_IDLE_HINT_REPAIR.zip -ManifestPath artifacts\v0.8.1-public-release\controller-release-manifest.json -PayloadInventoryPath artifacts\v0.8.1-public-release\payload-sha256.json -ExpectedPackageSha256 $packageSha256 -ValidationStampPath artifacts\v0.8.1-public-release\controller-release-validation.json -Latest
```

The publisher hard-stops on dirty state, failed validation, tag/commit mismatch, digest mismatch, conflicting assets, or GitHub authentication failure.

