[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$OutputRoot,
    [switch]$AllowDirty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-JsonUtf8([string]$Path, [object]$Value, [int]$Depth = 32) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Get-Sha256([string]$Path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Copy-Payload([string]$Source, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { throw "Payload source missing: $Source" }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Destination)) | Out-Null
    [IO.File]::Copy($Source, $Destination, $true)
}
function New-Component(
    [string]$Id, [string]$Type, [string]$PackagePath, [string]$DestinationRoot,
    [string]$DestinationPath, [string]$FilePath, [bool]$MayLock, [bool]$Restart,
    [bool]$LuaReset, [string]$ConfigurationBehavior = 'package-owned') {
    return [ordered]@{
        componentId = $Id; componentType = $Type; sourcePath = $PackagePath.Replace('\', '/')
        destinationRoot = $DestinationRoot; destinationPath = $DestinationPath.Replace('\', '/')
        sha256 = Get-Sha256 $FilePath; byteLength = (Get-Item -LiteralPath $FilePath).Length
        installPolicy = 'replace'; replaceBehavior = 'replace'; mayBeLockedByCompanion = $MayLock
        companionMustRestart = $Restart; barMustRunLuaUiReset = $LuaReset; optional = $false
        platform = if ($DestinationRoot -eq 'companion') { 'windows' } else { 'any' }
        architecture = if ($DestinationRoot -eq 'companion') { 'x64' } else { 'any' }
        configurationBehavior = $ConfigurationBehavior
    }
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = Join-Path $RepositoryRoot 'artifacts\v0.8.1-public-release' }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
$branch = (& git -C $RepositoryRoot branch --show-current).Trim()
if ($branch -ne 'controller/v0.8.0-native-ui-integration-test') { throw "Unexpected branch: $branch" }
if (-not $AllowDirty -and @(& git -C $RepositoryRoot status --porcelain).Count -ne 0) { throw 'Worktree must be clean before public package creation.' }
$commit = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
if ($commit -notmatch '^[a-f0-9]{40}$') { throw 'Could not resolve source commit.' }

$specPath = Join-Path $RepositoryRoot 'tools\release\controller-release-payloads.json'
$spec = Get-Content -Raw -Encoding UTF8 -LiteralPath $specPath | ConvertFrom-Json
if ($spec.kind -ne 'bar-controller-release-payload-spec' -or $spec.schemaVersion -ne 1) { throw 'Unsupported release payload spec.' }
$workRoot = Join-Path $OutputRoot ('.build-' + [guid]::NewGuid().ToString('N'))
$stageRoot = Join-Path $workRoot 'stage'
$publishRoot = Join-Path $workRoot 'publish'
[IO.Directory]::CreateDirectory($stageRoot) | Out-Null
[IO.Directory]::CreateDirectory($publishRoot) | Out-Null
$components = New-Object Collections.Generic.List[object]

try {
    foreach ($build in @($spec.builds)) {
        $project = Join-Path $RepositoryRoot ([string]$build.project)
        $output = Join-Path $publishRoot ([string]$build.id)
        & dotnet publish $project -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o $output
        if ($LASTEXITCODE -ne 0) { throw "Publish failed: $project" }
        $source = Join-Path $output ([string]$build.outputFile)
        $packagePath = ([string]$build.packagePath).Replace('/', '\')
        $destination = Join-Path $stageRoot $packagePath
        Copy-Payload $source $destination
        if (-not ($build.PSObject.Properties.Name -contains 'packageOnly') -or -not [bool]$build.packageOnly) {
            $component = $build.component
            $components.Add((New-Component ([string]$build.id) ([string]$component.componentType) ([string]$build.packagePath) `
                ([string]$component.destinationRoot) ([string]$component.destinationPath) $destination `
                ([bool]$component.mayBeLockedByCompanion) ([bool]$component.companionMustRestart) ([bool]$component.barMustRunLuaUiReset)))
        }
    }

    foreach ($group in @($spec.sourceGroups)) {
        foreach ($relativeSource in @($group.sourcePaths)) {
            $source = Join-Path $RepositoryRoot ([string]$relativeSource)
            $fileName = [IO.Path]::GetFileName([string]$relativeSource)
            $packagePath = (([string]$group.packagePrefix).TrimEnd('/') + '/' + $fileName)
            $destinationPath = if ([string]::IsNullOrEmpty([string]$group.destinationPrefix)) { $fileName } else { ([string]$group.destinationPrefix).TrimEnd('/') + '/' + $fileName }
            $stageFile = Join-Path $stageRoot $packagePath.Replace('/', '\')
            Copy-Payload $source $stageFile
            $id = ([string]$group.idPrefix + '-' + [IO.Path]::GetFileNameWithoutExtension($fileName)).ToLowerInvariant().Replace('_', '-')
            $components.Add((New-Component $id ([string]$group.componentType) $packagePath ([string]$group.destinationRoot) `
                $destinationPath $stageFile $false ([string]$group.destinationRoot -eq 'companion') ([bool]$group.barMustRunLuaUiReset) `
                ($(if ([string]$group.componentType -eq 'release-metadata') { 'recovery-infrastructure' } else { 'package-owned' }))))
        }
    }

    $overrideManifestPath = Join-Path $RepositoryRoot ([string]$spec.nativeOverrideManifest)
    $overrideManifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $overrideManifestPath | ConvertFrom-Json
    foreach ($entry in @($overrideManifest.entries)) {
        $source = Join-Path $RepositoryRoot ([string]$entry.sourcePath)
        $fileName = [IO.Path]::GetFileName([string]$entry.livePath)
        $packagePath = 'luaui/Widgets/' + $fileName
        $stageFile = Join-Path $stageRoot $packagePath.Replace('/', '\')
        Copy-Payload $source $stageFile
        $components.Add((New-Component ('native-' + [IO.Path]::GetFileNameWithoutExtension($fileName).Replace('_', '-')) `
            'native-override' $packagePath 'bar-data' ([string]$entry.livePath) $stageFile $false $false $true))
    }

    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'native-overrides') -Destination (Join-Path $stageRoot 'native-overrides') -Recurse
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'doc\controller-companion-v0.8.1') -Destination (Join-Path $stageRoot 'doc\controller-companion-v0.8.1') -Recurse
    $companionSourceRoot = Join-Path $RepositoryRoot 'tools\controller-companion'
    foreach ($sourceFile in Get-ChildItem -LiteralPath $companionSourceRoot -Recurse -File | Where-Object {
        $_.FullName -notmatch '[\\/](bin|obj)[\\/]' -and $_.Extension -in @('.cs', '.csproj', '.props', '.md')
    }) {
        $relative = $sourceFile.FullName.Substring($companionSourceRoot.Length + 1)
        Copy-Payload $sourceFile.FullName (Join-Path $stageRoot ('source\tools\controller-companion\' + $relative))
    }
    foreach ($path in @('tools\release\Build-ControllerPublicRelease.ps1','tools\release\Deploy-ControllerPublicRelease.ps1',
        'tools\release\Test-ControllerReleaseSystem.ps1','tools\release\Publish-ControllerRelease.ps1','tools\release\Test-ControllerRelease.ps1',
        'tools\release\New-ControllerReleaseManifest.ps1','tools\release\Publish-HistoricalControllerReleases.ps1',
        'tools\release\controller-release-payloads.json','tools\release\controller-release-schema.json',
        'tools\release\legacy-release-catalog.json')) {
        $source = Join-Path $RepositoryRoot $path
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            Copy-Payload $source (Join-Path $stageRoot ('tools\release\' + [IO.Path]::GetFileName($source)))
        }
    }
    Copy-Payload (Join-Path $RepositoryRoot 'LICENSE.md') (Join-Path $stageRoot 'LICENSE.md')
    Copy-Payload (Join-Path $RepositoryRoot 'tools\release\bar-controller-support-v0.8.1\README.md') (Join-Path $stageRoot 'README.md')
    Copy-Payload (Join-Path $RepositoryRoot 'tools\release\bar-controller-support-v0.8.1\RELEASE_NOTES_v0.8.1.md') (Join-Path $stageRoot 'RELEASE_NOTES_v0.8.1.md')

    $manifest = [ordered]@{
        kind = 'bar-controller-release-manifest'; schemaVersion = 1
        releaseTag = [string]$spec.release.tag; semanticVersion = [string]$spec.release.semanticVersion
        displayVersion = [string]$spec.release.displayVersion; releaseSequence = [long]$spec.release.releaseSequence
        releaseChannel = [string]$spec.release.channel; commitSha = $commit; publishedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        repository = 'UnderarmCape/underarmcape-bar-controller-support-attempt-01'
        package = [ordered]@{ assetName = [string]$spec.release.assetName; sha256 = ('0' * 64); byteLength = 0; format = 'zip'; detachedIdentity = $true }
        minimumUpdaterVersion = '0.8.0'
        barCompatibility = [ordered]@{ buildManifest = 'Beyond All Reason test-30735-bf9c7bf'; upstreamCommit = 'bf9c7bfdba26704832157bba47f3653ba8bdd8d2'; nativeOverrideRebaseMayBeRequired = $true }
        compatibilityNotes = 'Experimental native overrides are build-specific and may require rebasing after BAR updates.'
        requiresLuaUiReset = $true
        releaseSummary = 'Disassemble one-shot reclaim repair, stable idle navigation, capability-aware hints, radial label polish, automatic updates, Recovery Mode, and transactional self-update.'
        releaseNotesAsset = [string]$spec.release.releaseNotesAsset
        configurationPreservation = @($spec.configurationPreservation)
        installLifecycle = [ordered]@{ backupBeforeInstall = $true; transactionalRollback = $true; allowWhileBarRunning = $true; restartCompanion = $true; reloadInstruction = '/luaui reset' }
        components = $components.ToArray()
    }
    Write-JsonUtf8 (Join-Path $stageRoot 'controller-release-manifest.json') $manifest

    $installedBootstrap = [ordered]@{
        kind = 'bar-controller-installed-release-bootstrap'; schemaVersion = 1
        releaseTag = [string]$manifest.releaseTag; semanticVersion = [string]$manifest.semanticVersion
        displayVersion = [string]$manifest.displayVersion; releaseSequence = [long]$manifest.releaseSequence
        commitSha = $commit; repository = [string]$manifest.repository
        packageIdentity = 'Resolve from the detached controller-release-manifest.json before installation.'
        components = @($components | ForEach-Object {
            [ordered]@{ componentId=$_.componentId; destinationRoot=$_.destinationRoot; destinationPath=$_.destinationPath; sha256=$_.sha256 }
        })
    }
    Write-JsonUtf8 (Join-Path $stageRoot 'installed-release-bootstrap.json') $installedBootstrap

    $compatibility = [ordered]@{
        packageName = 'BAR Controller Companion'; version = [string]$spec.release.semanticVersion; repository = 'UnderarmCape/underarmcape-bar-controller-support-attempt-01'
        requiredLuaFiles = @(); requiredBarDataFiles = @($components | Where-Object { $_.destinationRoot -eq 'bar-data' } | ForEach-Object { $_.sourcePath })
        requiredCompanionFiles = @($components | Where-Object { $_.destinationRoot -eq 'companion' } | ForEach-Object { $_.sourcePath })
        requiredPublicFiles = @('README.md','LICENSE.md','controller-release-manifest.json','installed-release-bootstrap.json')
    }
    Write-JsonUtf8 (Join-Path $stageRoot 'manifest.json') $compatibility

    $installScript = @'
[CmdletBinding()]
param([string]$BarDataPath=(Join-Path $env:LOCALAPPDATA 'Programs\Beyond-All-Reason\data'),[string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'Programs\BARControllerCompanion'))
& (Join-Path $PSScriptRoot 'BAR_Controller_Companion_Installer_v0.8.1_Experimental.exe') --package-root $PSScriptRoot --bar-data $BarDataPath --install-root $InstallRoot --no-pause
exit $LASTEXITCODE
'@
    [IO.File]::WriteAllText((Join-Path $stageRoot 'Install_v0.8.1.ps1'), $installScript, (New-Object Text.UTF8Encoding($false)))

    $inventory = @(
        Get-ChildItem -LiteralPath $stageRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
            [ordered]@{ path = $_.FullName.Substring($stageRoot.Length + 1).Replace('\', '/'); size = $_.Length; sha256 = Get-Sha256 $_.FullName }
        }
    )
    Write-JsonUtf8 (Join-Path $stageRoot 'payload-sha256.json') $inventory

    [IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
    $packagePath = Join-Path $OutputRoot ([string]$spec.release.assetName)
    if (Test-Path -LiteralPath $packagePath) { [IO.File]::Delete($packagePath) }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($stageRoot, $packagePath, [IO.Compression.CompressionLevel]::Optimal, $false)
    $packageHash = Get-Sha256 $packagePath
    $manifest.package.sha256 = $packageHash
    $manifest.package.byteLength = (Get-Item -LiteralPath $packagePath).Length
    $manifest.package.detachedIdentity = $false
    $manifestPath = Join-Path $OutputRoot 'controller-release-manifest.json'
    Write-JsonUtf8 $manifestPath $manifest
    $manifestHash = Get-Sha256 $manifestPath
    [IO.File]::WriteAllText(($packagePath + '.sha256'), ($packageHash + '  ' + [IO.Path]::GetFileName($packagePath) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText(($manifestPath + '.sha256'), ($manifestHash + '  controller-release-manifest.json' + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    [IO.File]::Copy((Join-Path $stageRoot 'payload-sha256.json'), (Join-Path $OutputRoot 'payload-sha256.json'), $true)
    [IO.File]::Copy((Join-Path $stageRoot 'RELEASE_NOTES_v0.8.1.md'), (Join-Path $OutputRoot 'RELEASE_NOTES_v0.8.1.md'), $true)

    & (Join-Path $RepositoryRoot 'tools\release\Test-ControllerRelease.ps1') -PackagePath $packagePath -ManifestPath $manifestPath -PayloadInventoryPath (Join-Path $OutputRoot 'payload-sha256.json') -ExpectedPackageSha256 $packageHash
    if ($LASTEXITCODE -ne 0) { throw 'Public release validation failed.' }
    Write-Output "PACKAGE=$packagePath"
    Write-Output "SHA256=$packageHash"
    Write-Output "MANIFEST=$manifestPath"
    Write-Output "MANIFEST_SHA256=$manifestHash"
    Write-Output "COMPONENTS=$($components.Count)"
} finally {
    if ([IO.Directory]::Exists($workRoot)) { [IO.Directory]::Delete($workRoot, $true) }
}
