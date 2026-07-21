[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BackupRoot,
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Stop-CompanionWindowCleanly([uint32]$ProcessId, [string]$ExpectedName) {
    $process = Get-Process -Id $ProcessId -ErrorAction Stop
    if ($process.ProcessName -ne $ExpectedName) { throw "Process $ProcessId is no longer $ExpectedName." }
    if (-not $process.CloseMainWindow()) { throw "$ExpectedName has no closeable window. Close it manually and retry." }
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) { return }
        Start-Sleep -Milliseconds 200
    }
    throw "$ExpectedName did not exit cleanly."
}

$BackupRoot = (Resolve-Path -LiteralPath $BackupRoot).Path
$manifestPath = Join-Path $BackupRoot 'deployment-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Deployment manifest is missing.' }
$manifest = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
if ($manifest.kind -ne 'bar-controller-local-deployment-backup' -or $manifest.schemaVersion -ne 1) { throw 'Unexpected deployment manifest format.' }
if (-not [IO.Path]::GetFullPath($manifest.backupRoot).Equals($BackupRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Manifest backup root does not match the requested path.' }

$processes = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -match '^(?i)(BARControllerBridge|BARControllerLauncher|BARControllerCompanionInstaller|BARControllerCompanionRestore|BARControllerUIDefaultsPublisher|spring|spring-headless|Beyond-All-Reason|BAR)\.exe$' -or
    $_.ExecutablePath -like ((Split-Path -Parent $manifest.barDataPath) + '\*')
})
$barProcesses = @($processes | Where-Object { $_.Name -match '^(?i)(spring|spring-headless|Beyond-All-Reason|BAR)\.exe$' })
if ($barProcesses.Count -gt 0) {
    $barProcesses | Select-Object ProcessId, Name, ExecutablePath | Format-List
    throw 'BAR is running. Close BAR manually before rollback.'
}
foreach ($item in @($processes | Where-Object { $_.Name -match '^(?i)(BARControllerBridge|BARControllerLauncher)\.exe$' })) {
    Stop-CompanionWindowCleanly -ProcessId $item.ProcessId -ExpectedName ([IO.Path]::GetFileNameWithoutExtension($item.Name))
}
$remaining = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(?i)(BARControllerBridge|BARControllerLauncher|BARControllerCompanionInstaller|BARControllerCompanionRestore|BARControllerUIDefaultsPublisher|spring|spring-headless|Beyond-All-Reason|BAR)\.exe$' })
if ($remaining.Count -gt 0) { throw 'A BAR/controller runtime process remains active.' }

$allowedRoots = @(
    ([IO.Path]::GetFullPath([string]$manifest.barDataPath).TrimEnd('\') + '\')
    ([IO.Path]::GetFullPath([string]$manifest.companionInstallPath).TrimEnd('\') + '\')
)
function Assert-AllowedDestination([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    foreach ($root in $allowedRoots) {
        if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { return $full }
    }
    throw "Rollback destination escaped the recorded live roots: $Path"
}

$destinationSet = @{}
foreach ($deployed in @($manifest.deployedFiles)) {
    $destination = Assert-AllowedDestination ([string]$deployed.destination)
    if ($destinationSet.ContainsKey($destination)) { throw "Deployment manifest contains a duplicate destination: $destination" }
    $destinationSet[$destination] = $true
}

if ($ValidateOnly) {
    foreach ($deployed in @($manifest.deployedFiles)) {
        $destination = Assert-AllowedDestination ([string]$deployed.destination)
        if ([bool]$deployed.existedBefore) {
            $record = @($manifest.backedUpFiles | Where-Object { [IO.Path]::GetFullPath([string]$_.source).Equals($destination, [StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1
            if (-not $record -or -not (Test-Path -LiteralPath $record.backup -PathType Leaf)) { throw "Rollback backup is missing for $destination" }
            if ((Get-Sha256 $record.backup) -ne ([string]$record.sha256).ToLowerInvariant()) { throw "Rollback backup hash mismatch: $($record.backup)" }
        }
    }
    foreach ($relocated in @($manifest.relocatedWidgetBackups)) {
        [void](Assert-AllowedDestination ([string]$relocated.source))
        if (-not (Test-Path -LiteralPath $relocated.backup -PathType Container)) { throw "Relocated widget backup is missing: $($relocated.backup)" }
    }
    Write-Output ('ROLLBACK_VALID=' + $BackupRoot)
    return
}

$artifactRoot = Join-Path $BackupRoot ('rollback-artifacts-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $artifactRoot | Out-Null
foreach ($deployed in @($manifest.deployedFiles)) {
    $destination = Assert-AllowedDestination ([string]$deployed.destination)
    if ([bool]$deployed.existedBefore) {
        $record = @($manifest.backedUpFiles | Where-Object { [IO.Path]::GetFullPath([string]$_.source).Equals($destination, [StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1
        if (-not $record) { throw "No pre-deployment backup was recorded for $destination" }
        if (-not (Test-Path -LiteralPath $record.backup -PathType Leaf)) { throw "Backup file is missing: $($record.backup)" }
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $record.backup -Destination $destination -Force
        if ((Get-Sha256 $destination) -ne ([string]$record.sha256).ToLowerInvariant()) { throw "Restored hash mismatch: $destination" }
        Write-Output ('RESTORED=' + $destination)
    }
    elseif (Test-Path -LiteralPath $destination -PathType Leaf) {
        $relativeName = ([IO.Path]::GetFileName($destination) + '-' + [guid]::NewGuid().ToString('N'))
        $artifact = Join-Path $artifactRoot $relativeName
        Move-Item -LiteralPath $destination -Destination $artifact
        Write-Output ('REMOVED_NEW_FILE_TO=' + $artifact)
    }
}

if ([bool]$manifest.widgetConfigChanged) {
    $configDestination = Assert-AllowedDestination (Join-Path $manifest.barDataPath 'LuaUI\Config\BYAR.lua')
    $configRecord = @($manifest.backedUpFiles | Where-Object { [IO.Path]::GetFullPath([string]$_.source).Equals($configDestination, [StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1
    if (-not $configRecord) { throw 'Widget configuration backup is missing from the manifest.' }
    Copy-Item -LiteralPath $configRecord.backup -Destination $configDestination -Force
}
if ([bool]$manifest.cameraSettingChanged) {
    $settingsDestination = Assert-AllowedDestination (Join-Path $manifest.barDataPath 'springsettings.cfg')
    $settingsRecord = @($manifest.backedUpFiles | Where-Object { [IO.Path]::GetFullPath([string]$_.source).Equals($settingsDestination, [StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1
    if (-not $settingsRecord) { throw 'BAR settings backup is missing from the manifest.' }
    Copy-Item -LiteralPath $settingsRecord.backup -Destination $settingsDestination -Force
}

foreach ($relocated in @($manifest.relocatedWidgetBackups)) {
    $source = Assert-AllowedDestination ([string]$relocated.source)
    if (Test-Path -LiteralPath $source) { throw "Cannot restore relocated widget backup because the destination exists: $source" }
    if (-not (Test-Path -LiteralPath $relocated.backup -PathType Container)) { throw "Relocated widget backup is missing: $($relocated.backup)" }
    Copy-Item -LiteralPath $relocated.backup -Destination $source -Recurse
    Write-Output ('RESTORED_RELOCATED_BACKUP=' + $source)
}

$result = [ordered]@{
    kind = 'bar-controller-local-deployment-rollback-result'
    sourceDeployment = $manifestPath
    rolledBackAt = (Get-Date).ToString('o')
    artifacts = $artifactRoot
}
$resultPath = Join-Path $BackupRoot 'rollback-result.json'
[IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 6) + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
Write-Output ('ROLLBACK_COMPLETE=' + $BackupRoot)
Write-Output 'BAR was not launched. Widgets, Lua support modules, controller glyph assets, defaults, and runtime files were restored or moved to rollback artifacts from the deployment manifest.'
Write-Output 'Old recursively scanned widget backups were restored exactly; move them out of LuaUI\Widgets before starting BAR if the rollback is only for runtime binaries.'


