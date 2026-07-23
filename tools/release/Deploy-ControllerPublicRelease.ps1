[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [string]$PayloadInventoryPath,
    [string]$RepositoryRoot,
    [string]$BarDataPath = (Join-Path $env:LOCALAPPDATA 'Programs\Beyond-All-Reason\data'),
    [string]$CompanionInstallPath = (Join-Path $env:LOCALAPPDATA 'Programs\BARControllerCompanion'),
    [switch]$AllowUnknownBase,
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ExpectedBranch = 'controller/v0.8.0-native-ui-integration-test'
$ExpectedBarBuild = 'Beyond All Reason test-30735-bf9c7bf'

function Get-Sha256([string]$Path) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Stop-ControllerRuntimesSafely {
    $all = @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^(?i)(BARControllerBridge|BARControllerLauncher|BARControllerUpdater|BARControllerCompanionInstaller|BARControllerCompanionRestore|spring|spring-headless|recoil|Beyond-All-Reason|BAR)\.exe$'
    })
    $bar = @($all | Where-Object { $_.Name -match '^(?i)(spring|spring-headless|recoil|Beyond-All-Reason|BAR)\.exe$' })
    if ($bar.Count -gt 0) {
        $bar | Select-Object ProcessId, Name, ExecutablePath | Format-List
        throw 'BAR is running. Close it manually; public deployment never terminates BAR.'
    }
    foreach ($item in @($all | Where-Object { $_.Name -match '^(?i)(BARControllerBridge|BARControllerLauncher)\.exe$' })) {
        $process = Get-Process -Id $item.ProcessId -ErrorAction Stop
        if (-not $process.CloseMainWindow()) {
            throw "$($item.Name) has no closeable window. Close it manually and retry."
        }
        for ($attempt = 0; $attempt -lt 50 -and (Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue); $attempt++) {
            Start-Sleep -Milliseconds 200
        }
        if (Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue) {
            throw "$($item.Name) did not exit cleanly."
        }
    }
    $remaining = @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^(?i)(BARControllerBridge|BARControllerLauncher|BARControllerUpdater|BARControllerCompanionInstaller|BARControllerCompanionRestore|spring|spring-headless|recoil|Beyond-All-Reason|BAR)\.exe$'
    })
    if ($remaining.Count -gt 0) { throw 'A BAR/controller deployment process remains active.' }
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$ManifestPath = (Resolve-Path -LiteralPath $ManifestPath).Path
$BarDataPath = (Resolve-Path -LiteralPath $BarDataPath).Path
$CompanionInstallPath = (Resolve-Path -LiteralPath $CompanionInstallPath).Path
if ($PayloadInventoryPath) { $PayloadInventoryPath = (Resolve-Path -LiteralPath $PayloadInventoryPath).Path }

$branch = (& git -C $RepositoryRoot branch --show-current).Trim()
if ($branch -ne $ExpectedBranch) { throw "Expected branch $ExpectedBranch, found $branch." }
if (@(& git -C $RepositoryRoot status --porcelain).Count -ne 0) {
    throw 'Public deployment requires a clean worktree.'
}

$testArguments = @('-PackagePath', $PackagePath, '-ManifestPath', $ManifestPath, '-KeepExtracted')
if ($PayloadInventoryPath) { $testArguments += @('-PayloadInventoryPath', $PayloadInventoryPath) }
$validation = @(& (Join-Path $PSScriptRoot 'Test-ControllerRelease.ps1') @testArguments)
$extractedRecord = @($validation | Where-Object { $_ -like 'EXTRACTED_ROOT=*' })
if ($extractedRecord.Count -ne 1) { throw 'Release validator did not return one isolated extraction root.' }
$stagingRoot = [string]$extractedRecord[0].Substring('EXTRACTED_ROOT='.Length)

try {
    $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $ManifestPath | ConvertFrom-Json
    if ($manifest.commitSha -ne (& git -C $RepositoryRoot rev-parse HEAD).Trim()) {
        throw 'Release manifest does not identify the checked-out deployment commit.'
    }
    $infolog = Join-Path $BarDataPath 'infolog.txt'
    $buildMatches = (Test-Path -LiteralPath $infolog -PathType Leaf) -and
        ([IO.File]::ReadAllText($infolog).Contains($ExpectedBarBuild))
    if (-not $buildMatches -and -not $AllowUnknownBase) {
        throw "Live BAR build identity does not contain '$ExpectedBarBuild'."
    }

    $overrideManifestPath = Join-Path $stagingRoot 'native-overrides\native-override-manifest.json'
    if (-not (Test-Path -LiteralPath $overrideManifestPath -PathType Leaf)) {
        throw 'Packaged native override manifest is missing.'
    }
    $overrideManifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $overrideManifestPath | ConvertFrom-Json
    foreach ($component in @($manifest.components | Where-Object { $_.componentType -eq 'native-override' })) {
        $entry = @($overrideManifest.entries | Where-Object { [string]$_.livePath -eq [string]$component.destinationPath })
        if ($entry.Count -ne 1) { throw "Native component has no exact base record: $($component.componentId)" }
        $source = Join-Path $stagingRoot ([string]$component.sourcePath).Replace('/', '\')
        if ((Get-Sha256 $source) -ne ([string]$entry[0].patchedSha256).ToLowerInvariant()) {
            throw "Packaged native override hash conflicts with its base record: $($component.componentId)"
        }
        $destination = Join-Path $BarDataPath ([string]$component.destinationPath).Replace('/', '\')
        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            $liveHash = Get-Sha256 $destination
            $allowed = @(([string]$entry[0].baseSha256).ToLowerInvariant(), ([string]$entry[0].patchedSha256).ToLowerInvariant())
            if ($entry[0].PSObject.Properties.Name -contains 'previousPatchedSha256') {
                $allowed += ([string]$entry[0].previousPatchedSha256).ToLowerInvariant()
            }
            if ($liveHash -notin $allowed -and -not $AllowUnknownBase) {
                throw "Unknown loose native override ($liveHash): $destination"
            }
        }
    }

    Stop-ControllerRuntimesSafely
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupRoot = Join-Path $CompanionInstallPath ('recovery-backups\public-v0.8.0-' + $timestamp)
    $updater = Join-Path $stagingRoot 'BARControllerUpdater.exe'
    if (-not (Test-Path -LiteralPath $updater -PathType Leaf)) { throw 'Validated external updater helper is missing.' }
    $updaterArguments = @(
        '--package', $PackagePath,
        '--manifest', $ManifestPath,
        '--staging', $stagingRoot,
        '--bar-data', $BarDataPath,
        '--companion', $CompanionInstallPath,
        '--backup', $backupRoot
    )
    if ($ValidateOnly) { $updaterArguments += '--validate-only' }
    & $updater @updaterArguments
    if ($LASTEXITCODE -ne 0) { throw 'External updater rejected or failed the public deployment transaction.' }

    if ($ValidateOnly) {
        Write-Output "DEPLOYMENT_VALID=true"
        Write-Output "DEPLOYMENT_COMPONENTS=$(@($manifest.components).Count)"
        return
    }

    $statePath = Join-Path $CompanionInstallPath 'installed-release.json'
    $state = Get-Content -Raw -Encoding UTF8 -LiteralPath $statePath | ConvertFrom-Json
    if ($state.releaseTag -ne $manifest.releaseTag -or $state.commitSha -ne $manifest.commitSha -or
        $state.packageSha256 -ne $manifest.package.sha256 -or $state.manifestSha256 -ne (Get-Sha256 $ManifestPath)) {
        throw 'Installed-release state does not match the deployed package and manifest.'
    }
    foreach ($component in @($manifest.components | Where-Object { $_.installPolicy -ne 'remove' })) {
        $root = if ($component.destinationRoot -eq 'bar-data') { $BarDataPath } else { $CompanionInstallPath }
        $destination = Join-Path $root ([string]$component.destinationPath).Replace('/', '\')
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or
            (Get-Sha256 $destination) -ne ([string]$component.sha256).ToLowerInvariant()) {
            throw "Live installed hash mismatch: $($component.componentId)"
        }
    }
    & (Join-Path $CompanionInstallPath 'BARControllerUpdater.exe') --validate-backup $backupRoot
    if ($LASTEXITCODE -ne 0) { throw 'Strict rollback validation failed after deployment.' }
    Stop-ControllerRuntimesSafely
    Write-Output "BACKUP_ROOT=$backupRoot"
    Write-Output "INSTALLED_STATE=$statePath"
    Write-Output "DEPLOYED_HASHES=$(@($manifest.components).Count)"
    Write-Output 'BAR_REMAINS_CLOSED=true'
} finally {
    if ($stagingRoot -and [IO.Directory]::Exists($stagingRoot)) {
        [IO.Directory]::Delete($stagingRoot, $true)
    }
}
