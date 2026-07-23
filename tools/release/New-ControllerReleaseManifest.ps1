[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$ExpectedPackageSha256,
    [Parameter(Mandatory = $true)][string]$Tag,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$DisplayVersion,
    [Parameter(Mandatory = $true)][long]$ReleaseSequence,
    [Parameter(Mandatory = $true)][string]$Commit,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Summary,
    [Parameter(Mandatory = $true)][string]$PublishedAtUtc,
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [string]$Channel = 'historical-experimental',
    [string]$KnownLimitations = 'Historical automated validation did not establish live gameplay success.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-Sha256([string]$Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Write-JsonUtf8([string]$Path, [object]$Value) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$actualHash = Get-Sha256 $PackagePath
if ($actualHash -ne $ExpectedPackageSha256.ToLowerInvariant()) { throw "Historical package SHA-256 mismatch for $Tag." }
if ($Commit -notmatch '^[a-fA-F0-9]{40}$') { throw 'Historical commit must be an exact SHA-1.' }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
[IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
$extractRoot = Join-Path ([IO.Path]::GetTempPath()) ('bar-controller-historical-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($extractRoot) | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($PackagePath)
$rootPrefix = [IO.Path]::GetFullPath($extractRoot).TrimEnd('\') + '\'
try {
    foreach ($entry in $archive.Entries) {
        $name = $entry.FullName.Replace('\', '/')
        if ($name.StartsWith('/') -or $name -match '^[A-Za-z]:' -or @($name.Split('/') | Where-Object { $_ -eq '..' }).Count) {
            throw "Unsafe historical ZIP entry: $name"
        }
        $destination = [IO.Path]::GetFullPath((Join-Path $extractRoot $name.Replace('/', '\')))
        if (-not $destination.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Historical ZIP entry escaped staging: $name" }
        if ($name.EndsWith('/')) { [IO.Directory]::CreateDirectory($destination) | Out-Null; continue }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
        $input = $entry.Open()
        try {
            $output = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try { $input.CopyTo($output) } finally { $output.Dispose() }
        } finally { $input.Dispose() }
    }
} finally { $archive.Dispose() }

try {
    $components = New-Object Collections.Generic.List[object]
    $destinations = @{}
    foreach ($file in Get-ChildItem -LiteralPath $extractRoot -Recurse -File | Sort-Object FullName) {
        $sourcePath = $file.FullName.Substring($extractRoot.Length + 1).Replace('\', '/')
        $match = [regex]::Match($sourcePath, '(?i)(?:^|/)luaui/(?<tail>(?:Widgets|Include|images)/.+)$')
        if (-not $match.Success) { continue }
        $destinationPath = 'LuaUI/' + $match.Groups['tail'].Value
        $destinationKey = $destinationPath.ToLowerInvariant()
        if ($destinations.ContainsKey($destinationKey)) { continue }
        $destinations[$destinationKey] = $true
        $type = if ($destinationPath -match '(?i)/Include/') { 'lua-include' } elseif ($file.Extension -eq '.lua') { 'lua-widget' } else { 'lua-asset' }
        $components.Add([ordered]@{
            componentId = 'historical-' + $components.Count.ToString('D3'); componentType = $type
            sourcePath = $sourcePath; destinationRoot = 'bar-data'; destinationPath = $destinationPath
            sha256 = Get-Sha256 $file.FullName; byteLength = $file.Length; installPolicy = 'replace'; replaceBehavior = 'replace'
            mayBeLockedByCompanion = $false; companionMustRestart = $false; barMustRunLuaUiReset = $true
            optional = $false; platform = 'any'; architecture = 'any'; configurationBehavior = 'package-owned'
        })
    }
    if ($components.Count -eq 0) { throw "Historical package has no compatible LuaUI payload: $Tag" }
    $preservation = @(
        [ordered]@{ ruleId='bar-luaui-config'; destinationRoot='bar-data'; relativePath='LuaUI/Config'; recursive=$true; behavior='preserve' },
        [ordered]@{ ruleId='bar-spring-settings'; destinationRoot='bar-data'; relativePath='springsettings.cfg'; recursive=$false; behavior='preserve' },
        [ordered]@{ ruleId='companion-launcher-config'; destinationRoot='companion'; relativePath='launcher-config.json'; recursive=$false; behavior='preserve' },
        [ordered]@{ ruleId='companion-user-data'; destinationRoot='companion'; relativePath='user-data'; recursive=$true; behavior='preserve' },
        [ordered]@{ ruleId='companion-recovery-backups'; destinationRoot='companion'; relativePath='recovery-backups'; recursive=$true; behavior='preserve' }
    )
    $manifest = [ordered]@{
        kind='bar-controller-release-manifest'; schemaVersion=1; releaseTag=$Tag; semanticVersion=$Version
        displayVersion=$DisplayVersion; releaseSequence=$ReleaseSequence; releaseChannel=$Channel; commitSha=$Commit
        publishedAtUtc=([DateTimeOffset]::Parse($PublishedAtUtc).ToUniversalTime().ToString('o'))
        repository='UnderarmCape/underarmcape-bar-controller-support-attempt-01'
        package=[ordered]@{ assetName=[IO.Path]::GetFileName($PackagePath); sha256=$actualHash; byteLength=(Get-Item $PackagePath).Length; format='zip'; detachedIdentity=$false }
        minimumUpdaterVersion='0.8.0'
        barCompatibility=[ordered]@{ buildManifest='historical packaged milestone'; upstreamCommit=''; nativeOverrideRebaseMayBeRequired=$true }
        compatibilityNotes='Historical compatibility install preserves the modern updater/recovery companion and switches verified LuaUI payloads.'
        requiresLuaUiReset=$true; releaseSummary=$Summary; releaseNotesAsset='RELEASE_NOTES.md'
        configurationPreservation=$preservation
        installLifecycle=[ordered]@{ backupBeforeInstall=$true; transactionalRollback=$true; allowWhileBarRunning=$true; restartCompanion=$false; reloadInstruction='/luaui reset' }
        components=@($components)
    }
    $manifestPath = Join-Path $OutputRoot 'controller-release-manifest.json'
    Write-JsonUtf8 $manifestPath $manifest
    $manifestHash = Get-Sha256 $manifestPath
    [IO.File]::WriteAllText(($manifestPath + '.sha256'), ($manifestHash + '  controller-release-manifest.json' + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $OutputRoot ([IO.Path]::GetFileName($PackagePath) + '.sha256')), ($actualHash + '  ' + [IO.Path]::GetFileName($PackagePath) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))

    $inventory = @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path=$_.FullName.Substring($extractRoot.Length + 1).Replace('\','/'); size=$_.Length; sha256=Get-Sha256 $_.FullName }
    })
    Write-JsonUtf8 (Join-Path $OutputRoot 'payload-sha256.json') $inventory
    $notes = @"
# $Title

Historical experimental milestone published for Recovery Mode.

- Tag: ``$Tag``
- Commit: ``$Commit``
- Package SHA-256: ``$actualHash``
- Focus: $Summary
- Known limitations: $KnownLimitations

Recovery Mode installs this exact verified LuaUI payload transactionally while preserving the modern updater/recovery companion and user configuration. Later fixes are not implied to be present in this historical package.
"@
    [IO.File]::WriteAllText((Join-Path $OutputRoot 'RELEASE_NOTES.md'), $notes, (New-Object Text.UTF8Encoding($false)))
    Write-Output "HISTORICAL_MANIFEST=$manifestPath"
    Write-Output "HISTORICAL_COMPONENTS=$($components.Count)"
    Write-Output "HISTORICAL_PACKAGE_SHA256=$actualHash"
} finally {
    if ([IO.Directory]::Exists($extractRoot)) { [IO.Directory]::Delete($extractRoot, $true) }
}
