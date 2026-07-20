[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path,
    [string]$PackageRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path 'package'),
    [string]$RuntimeArtifactsRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path 'artifacts\v0.6.0\win-x64'),
    [switch]$BuildRuntimeArtifacts,
    [Alias('SkipBuild')]
    [switch]$StageOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$releaseVersion = '0.6.0'
$fileVersion = '0.6.0.0'
$runtimeIdentifier = 'win-x64'
$targetName = 'BAR_Controller_Support_v0.6.0_Widget_Companion'
$workspaceRootFull = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
$packageRootFull = [IO.Path]::GetFullPath($PackageRoot).TrimEnd('\')
$runtimeArtifactsRootFull = [IO.Path]::GetFullPath($RuntimeArtifactsRoot).TrimEnd('\')
$allowedArtifactsRoot = [IO.Path]::GetFullPath((Join-Path $workspaceRootFull 'artifacts')).TrimEnd('\') + '\'
$packagePrefix = $packageRootFull + '\'
$target = [IO.Path]::GetFullPath((Join-Path $packageRootFull $targetName))
$zipPath = Join-Path $packageRootFull ($targetName + '.zip')
$checksumPath = $zipPath + '.sha256'
$releaseBodyPath = Join-Path $packageRootFull 'BAR_Controller_Support_v0.6.0.release.md'
$runtimeManifestPath = Join-Path $runtimeArtifactsRootFull 'frozen-runtime-manifest.json'

if ($BuildRuntimeArtifacts -and $StageOnly) {
    throw 'Choose either -BuildRuntimeArtifacts or -StageOnly, not both.'
}
if (-not $runtimeArtifactsRootFull.StartsWith($allowedArtifactsRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Runtime artifacts must be under the repository artifacts directory: $runtimeArtifactsRootFull"
}
if (-not $target.StartsWith($packagePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to stage outside the package directory: $target"
}

function Invoke-Checked([string]$FilePath, [string[]]$Arguments, [string]$Label) {
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE." }
}

function Invoke-Captured([string]$FilePath, [string[]]$Arguments, [string]$Label) {
    $output = & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE." }
    return (($output | Out-String).Trim())
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-PeMachine([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $reader = New-Object IO.BinaryReader($stream)
    try {
        $stream.Position = 0x3c
        $peOffset = $reader.ReadInt32()
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) { throw "Invalid PE signature: $Path" }
        $machine = $reader.ReadUInt16()
        if ($machine -eq 0x8664) { return 'x64' }
        return ('0x{0:x4}' -f $machine)
    }
    finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

function Invoke-SmokeProcess([string]$Path, [string[]]$Arguments, [int]$ExpectedExitCode, [string]$Label) {
    $startParameters = @{
        FilePath = $Path
        PassThru = $true
        Wait = $true
        WindowStyle = 'Hidden'
    }
    if ($Arguments.Count -gt 0) { $startParameters.ArgumentList = $Arguments }
    $process = Start-Process @startParameters
    if ($process.ExitCode -ne $ExpectedExitCode) {
        throw "$Label smoke test returned $($process.ExitCode); expected $ExpectedExitCode."
    }
}

function Get-SourceCommit {
    return Invoke-Captured 'git' @('-C', $workspaceRootFull, 'rev-parse', 'HEAD') 'Read source commit'
}

function Assert-CommittedSource {
    $dirty = Invoke-Captured 'git' @('-C', $workspaceRootFull, 'status', '--porcelain', '--untracked-files=no') 'Inspect tracked source state'
    if (-not [string]::IsNullOrWhiteSpace($dirty)) {
        throw 'Frozen release artifacts require a clean tracked worktree so the source commit fully identifies their inputs.'
    }
}

$runtimeProjects = [ordered]@{
    bridge = [ordered]@{ project = 'tools\controller-companion\BarControllerCompanion.csproj'; file = 'BARControllerBridge.exe' }
    launcher = [ordered]@{ project = 'tools\controller-companion\Launcher\BARControllerLauncher.csproj'; file = 'BARControllerLauncher.exe' }
    installer = [ordered]@{ project = 'tools\controller-companion\Installer\BARControllerCompanionInstaller.csproj'; file = 'BAR_Controller_Companion_Installer_v0.6.0.exe' }
    restore = [ordered]@{ project = 'tools\controller-companion\Restore\BARControllerCompanionRestore.csproj'; file = 'BAR_Controller_Companion_Restore_v0.6.0.exe' }
}

function Build-FrozenRuntimeArtifacts {
    Assert-CommittedSource
    $sourceCommit = Get-SourceCommit
    $sdkVersion = Invoke-Captured 'dotnet' @('--version') 'Read .NET SDK version'
    $buildParent = Split-Path -Parent $runtimeArtifactsRootFull
    $buildRoot = Join-Path $buildParent ('.build-' + [Guid]::NewGuid().ToString('N'))
    $smokeRoot = Join-Path $buildParent ('.smoke-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $buildParent | Out-Null
    try {
        if (Test-Path -LiteralPath $runtimeArtifactsRootFull) {
            Remove-Item -LiteralPath $runtimeArtifactsRootFull -Recurse -Force
        }
        New-Item -ItemType Directory -Path $runtimeArtifactsRootFull | Out-Null
        New-Item -ItemType Directory -Path $buildRoot | Out-Null
        $artifactRecords = @()
        foreach ($name in $runtimeProjects.Keys) {
            $project = $runtimeProjects[$name]
            $publishDirectory = Join-Path $buildRoot $name
            Invoke-Checked 'dotnet' @(
                'publish', (Join-Path $workspaceRootFull $project.project),
                '-c', 'Release', '-r', $runtimeIdentifier, '--self-contained', 'true',
                '--force', '--nologo', '-o', $publishDirectory,
                '/p:Deterministic=true', '/p:ContinuousIntegrationBuild=true',
                '/p:DebugSymbols=false', '/p:DebugType=None',
                "/p:SourceRevisionId=$sourceCommit", "/p:RepositoryCommit=$sourceCommit",
                '/p:IncludeSourceRevisionInInformationalVersion=false',
                "/p:PathMap=$workspaceRootFull=/_/src"
            ) ("Publish frozen runtime " + $name)
            $publishedExe = Join-Path $publishDirectory $project.file
            if (-not (Test-Path -LiteralPath $publishedExe -PathType Leaf)) {
                throw "Publish did not produce the expected executable: $publishedExe"
            }
            $destinationDirectory = Join-Path $runtimeArtifactsRootFull $name
            New-Item -ItemType Directory -Path $destinationDirectory | Out-Null
            $destination = Join-Path $destinationDirectory $project.file
            Copy-Item -LiteralPath $publishedExe -Destination $destination
            $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($destination)
            if ($version.FileVersion -ne $fileVersion) {
                throw "$($project.file) has unexpected file version $($version.FileVersion)."
            }
            $machine = Get-PeMachine $destination
            if ($machine -ne 'x64') { throw "$($project.file) has unexpected PE machine $machine." }
            $artifactRecords += [pscustomobject][ordered]@{
                project = ([string]$project.project).Replace('\', '/')
                filename = [string]$project.file
                relativePath = (($name + '/' + $project.file).Replace('\', '/'))
                size = (Get-Item -LiteralPath $destination).Length
                sha256 = Get-Sha256 $destination
                fileVersion = [string]$version.FileVersion
                productVersion = [string]$version.ProductVersion
                architecture = $machine
            }
        }

        New-Item -ItemType Directory -Path $smokeRoot | Out-Null
        Invoke-SmokeProcess (Join-Path $runtimeArtifactsRootFull 'bridge\BARControllerBridge.exe') @('--release-smoke-test') 2 'Bridge'
        Invoke-SmokeProcess (Join-Path $runtimeArtifactsRootFull 'installer\BAR_Controller_Companion_Installer_v0.6.0.exe') @('--release-smoke-test') 2 'Installer'
        Invoke-SmokeProcess (Join-Path $runtimeArtifactsRootFull 'restore\BAR_Controller_Companion_Restore_v0.6.0.exe') @('--release-smoke-test') 2 'Restore'
        $smokeLauncher = Join-Path $smokeRoot 'BARControllerLauncher.exe'
        Copy-Item -LiteralPath (Join-Path $runtimeArtifactsRootFull 'launcher\BARControllerLauncher.exe') -Destination $smokeLauncher
        Copy-Item -LiteralPath (Join-Path $env:WINDIR 'System32\where.exe') -Destination (Join-Path $smokeRoot 'BARControllerBridge.exe')
        $launcherConfig = [ordered]@{
            OriginalTargetPath = (Join-Path $env:WINDIR 'System32\cmd.exe')
            OriginalArguments = '/d /c exit 0'
            OriginalWorkingDirectory = $smokeRoot
            OriginalIconLocation = ''
            BridgePath = 'BARControllerBridge.exe'
            SettingsPath = ''
            BridgeStartupDelayMilliseconds = 0
        }
        [IO.File]::WriteAllText((Join-Path $smokeRoot 'launcher-config.json'),
            ($launcherConfig | ConvertTo-Json -Depth 4) + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
        Invoke-SmokeProcess $smokeLauncher @() 0 'Launcher'

        $runtimeManifest = [ordered]@{
            kind = 'bar-controller-frozen-runtime-manifest'
            schemaVersion = 1
            version = $releaseVersion
            sourceCommit = $sourceCommit
            sdkVersion = $sdkVersion
            runtimeIdentifier = $runtimeIdentifier
            configuration = 'Release'
            selfContained = $true
            singleFile = $true
            deterministicCompilerSettings = [ordered]@{
                Deterministic = $true
                ContinuousIntegrationBuild = $true
                DebugSymbols = $false
                DebugType = 'None'
                SourceRevisionId = $sourceCommit
                PathMap = '/_/src'
            }
            buildReproducibility = 'Runtime executables are hash-frozen from this one publish. Independent .NET 5 single-file publishes are checked for integrity, not assumed byte-identical.'
            smokeTests = @(
                'bridge invalid-option startup returned expected exit 2',
                'launcher isolated fake-target startup returned expected exit 0',
                'installer invalid-option startup returned expected exit 2',
                'restore invalid-option startup returned expected exit 2'
            )
            artifacts = $artifactRecords
        }
        [IO.File]::WriteAllText($runtimeManifestPath,
            ($runtimeManifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
        Write-Host "Frozen runtime artifacts: $runtimeArtifactsRootFull"
    }
    finally {
        if (Test-Path -LiteralPath $buildRoot) { Remove-Item -LiteralPath $buildRoot -Recurse -Force }
        if (Test-Path -LiteralPath $smokeRoot) { Remove-Item -LiteralPath $smokeRoot -Recurse -Force }
    }
}

function Get-ValidatedRuntimeArtifacts {
    Assert-CommittedSource
    if (-not (Test-Path -LiteralPath $runtimeManifestPath -PathType Leaf)) {
        throw "Frozen runtime manifest is missing. Run once with -BuildRuntimeArtifacts: $runtimeManifestPath"
    }
    $manifest = Get-Content -Raw -LiteralPath $runtimeManifestPath | ConvertFrom-Json
    $sourceCommit = Get-SourceCommit
    if ([string]$manifest.kind -ne 'bar-controller-frozen-runtime-manifest' -or [int]$manifest.schemaVersion -ne 1) {
        throw 'Frozen runtime manifest kind or schema is invalid.'
    }
    if ([string]$manifest.version -ne $releaseVersion -or [string]$manifest.sourceCommit -ne $sourceCommit) {
        throw "Frozen runtime manifest is stale; expected version $releaseVersion at $sourceCommit."
    }
    if ([string]$manifest.runtimeIdentifier -ne $runtimeIdentifier -or -not [bool]$manifest.selfContained -or -not [bool]$manifest.singleFile) {
        throw 'Frozen runtime manifest does not describe the required win-x64 self-contained single-file build.'
    }
    $records = @($manifest.artifacts)
    if ($records.Count -ne $runtimeProjects.Count) { throw 'Frozen runtime manifest does not contain exactly four executables.' }
    $validated = [ordered]@{}
    foreach ($name in $runtimeProjects.Keys) {
        $expected = $runtimeProjects[$name]
        $matches = @($records | Where-Object { [string]$_.filename -eq [string]$expected.file })
        if ($matches.Count -ne 1) { throw "Frozen runtime manifest has missing or duplicate entry: $($expected.file)" }
        $record = $matches[0]
        if ([string]$record.project -ne ([string]$expected.project).Replace('\', '/')) {
            throw "Frozen runtime project mismatch for $($expected.file)."
        }
        $path = [IO.Path]::GetFullPath((Join-Path $runtimeArtifactsRootFull ([string]$record.relativePath)))
        if (-not $path.StartsWith($runtimeArtifactsRootFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Frozen runtime path escapes its root: $($record.relativePath)"
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Frozen runtime executable is missing: $path" }
        $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($path)
        if ((Get-Item -LiteralPath $path).Length -ne [long]$record.size -or
            (Get-Sha256 $path) -ne [string]$record.sha256 -or
            [string]$version.FileVersion -ne $fileVersion -or
            [string]$record.fileVersion -ne $fileVersion -or
            (Get-PeMachine $path) -ne 'x64') {
            throw "Frozen runtime executable failed size, hash, version, or architecture validation: $path"
        }
        $validated[$name] = $path
    }
    return $validated
}

if ($BuildRuntimeArtifacts) { Build-FrozenRuntimeArtifacts }
$outputs = Get-ValidatedRuntimeArtifacts

New-Item -ItemType Directory -Force -Path $packageRootFull | Out-Null
if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
foreach ($artifact in @($zipPath, $checksumPath, $releaseBodyPath)) {
    if (Test-Path -LiteralPath $artifact) { Remove-Item -LiteralPath $artifact -Force }
}

foreach ($directory in @(
    $target,
    (Join-Path $target 'companion'),
    (Join-Path $target 'luaui\Widgets'),
    (Join-Path $target 'luaui\Include'),
    (Join-Path $target 'luaui\Images\controller-glyphs'),
    (Join-Path $target 'controller-ui'),
    (Join-Path $target 'docs')
)) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }

$copies = [ordered]@{
    $outputs.installer = (Join-Path $target 'BAR_Controller_Companion_Installer_v0.6.0.exe')
    $outputs.restore = (Join-Path $target 'BAR_Controller_Companion_Restore_v0.6.0.exe')
    $outputs.bridge = (Join-Path $target 'companion\BARControllerBridge.exe')
    $outputs.launcher = (Join-Path $target 'companion\BARControllerLauncher.exe')
    $runtimeManifestPath = (Join-Path $target 'frozen-runtime-manifest.json')
    (Join-Path $PSScriptRoot 'manifest.json') = (Join-Path $target 'manifest.json')
    (Join-Path $workspaceRootFull 'LICENSE.md') = (Join-Path $target 'LICENSE.md')
    (Join-Path $workspaceRootFull 'controller-ui\shipping-defaults.json') = (Join-Path $target 'controller-ui\shipping-defaults.json')
    (Join-Path $workspaceRootFull 'controller-ui\shipping-defaults-manifest.json') = (Join-Path $target 'controller-ui\shipping-defaults-manifest.json')
    (Join-Path $workspaceRootFull 'luaui\Images\controller-glyphs\controller_glyph_atlas.png') = (Join-Path $target 'luaui\Images\controller-glyphs\controller_glyph_atlas.png')
    (Join-Path $workspaceRootFull 'luaui\Images\controller-glyphs\asset-manifest.json') = (Join-Path $target 'luaui\Images\controller-glyphs\asset-manifest.json')
    (Join-Path $workspaceRootFull 'luaui\Images\controller-glyphs\LICENSE.md') = (Join-Path $target 'luaui\Images\controller-glyphs\LICENSE.md')
    (Join-Path $workspaceRootFull 'doc\controller-companion-v0.6.0\README.md') = (Join-Path $target 'docs\README.md')
    (Join-Path $workspaceRootFull 'doc\controller-companion-v0.6.0\RELEASE_NOTES_v0.6.0.md') = (Join-Path $target 'docs\RELEASE_NOTES_v0.6.0.md')
    (Join-Path $workspaceRootFull 'doc\controller-companion-v0.6.0\PACKAGE_INVENTORY_v0.6.0.md') = (Join-Path $target 'docs\PACKAGE_INVENTORY_v0.6.0.md')
    (Join-Path $workspaceRootFull 'doc\controller-companion-v0.6.0\EDITOR_PROPERTY_WIRING_AUDIT.md') = (Join-Path $target 'docs\EDITOR_PROPERTY_WIRING_AUDIT.md')
    (Join-Path $workspaceRootFull 'doc\controller-companion-v0.6.0\RESTORE_OLD_UI_STYLE.md') = (Join-Path $target 'docs\RESTORE_OLD_UI_STYLE.md')
}
foreach ($name in @('controller_socket_bridge.lua', 'gui_controller_camera_test.lua', 'gui_pregameui.lua', 'cmd_area_mex.lua',
    'gui_controller_bindings_ui.lua', 'gui_controller_smartx_mouse_audit.lua', 'gui_controller_ui_layout.lua')) {
    $copies[(Join-Path $workspaceRootFull ('luaui\Widgets\' + $name))] = Join-Path $target ('luaui\Widgets\' + $name)
}
foreach ($name in @('controller_ui_editor_workspace.lua', 'controller_ui_editor_input.lua', 'controller_ui_shared_renderers.lua', 'controller_glyphs.lua')) {
    $copies[(Join-Path $workspaceRootFull ('luaui\Include\' + $name))] = Join-Path $target ('luaui\Include\' + $name)
}
foreach ($source in $copies.Keys) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Staging source is missing: $source" }
    Copy-Item -LiteralPath $source -Destination $copies[$source] -Force
}

$manifest = Get-Content -Raw -LiteralPath (Join-Path $target 'manifest.json') | ConvertFrom-Json
$required = @($manifest.requiredPublicFiles) + @($manifest.requiredLuaFiles) + @($manifest.requiredBarDataFiles) + @($manifest.requiredCompanionFiles)
# payload-sha256.json is generated immediately below.
foreach ($relativePath in @($required | Where-Object { $_ -ne 'payload-sha256.json' })) {
    if (-not (Test-Path -LiteralPath (Join-Path $target ([string]$relativePath)) -PathType Leaf)) {
        throw "Staged package validation failed; missing: $relativePath"
    }
}

$payloadFiles = @(Get-ChildItem -LiteralPath $target -Recurse -File | Sort-Object FullName | ForEach-Object {
    [pscustomobject][ordered]@{
        path = $_.FullName.Substring($target.Length + 1).Replace('\', '/')
        length = $_.Length
        sha256 = Get-Sha256 $_.FullName
    }
})
$payload = [ordered]@{
    kind = 'bar-controller-package-payload-manifest'
    version = $releaseVersion
    algorithm = 'SHA-256'
    excludes = @('payload-sha256.json')
    files = $payloadFiles
}
[IO.File]::WriteAllText((Join-Path $target 'payload-sha256.json'),
    ($payload | ConvertTo-Json -Depth 8) + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))

$forbiddenNames = @(Get-ChildItem -LiteralPath $target -Recurse -Force | Where-Object {
    $_.Name -match '(?i)(publisher|\.pdb$|\.git$|recovery|authoring.*draft|deployment-backup|test-output)'
})
if ($forbiddenNames.Count -gt 0) { throw ('Forbidden public package entries: ' + (($forbiddenNames | ForEach-Object FullName) -join ', ')) }
$textFiles = @(Get-ChildItem -LiteralPath $target -Recurse -File | Where-Object Extension -in @('.json', '.md', '.lua', '.txt'))
foreach ($file in $textFiles) {
    $content = [IO.File]::ReadAllText($file.FullName)
    if ($content -match '(?i)(ghp_[a-z0-9]{20,}|github_pat_[a-z0-9_]{20,}|AIza[0-9A-Za-z_-]{30,}|C:\\Users\\kaili)') {
        throw "Credential or private-path pattern found in $($file.FullName)"
    }
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    $fixedTime = [DateTimeOffset]::new(2026, 7, 20, 0, 0, 0, [TimeSpan]::Zero)
    foreach ($file in @(Get-ChildItem -LiteralPath $target -Recurse -File | Sort-Object FullName)) {
        $relative = $targetName + '/' + $file.FullName.Substring($target.Length + 1).Replace('\', '/')
        $entry = $archive.CreateEntry($relative, [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = $fixedTime
        $sourceStream = [IO.File]::OpenRead($file.FullName)
        $entryStream = $entry.Open()
        try { $sourceStream.CopyTo($entryStream) }
        finally {
            $entryStream.Dispose()
            $sourceStream.Dispose()
        }
    }
}
finally { $archive.Dispose() }

$hash = Get-Sha256 $zipPath
[IO.File]::WriteAllText($checksumPath, "$hash  $([IO.Path]::GetFileName($zipPath))`r`n", [Text.Encoding]::ASCII)
$releaseTemplate = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'controller-support-v0.6.0-ui-authoring.release.md'))
[IO.File]::WriteAllText($releaseBodyPath, $releaseTemplate.Replace('__FINAL_ZIP_SHA256__', $hash), (New-Object Text.UTF8Encoding($false)))

Write-Host "Staged from frozen runtime artifacts: $target"
Write-Host "Runtime manifest: $runtimeManifestPath"
Write-Host "ZIP: $zipPath"
Write-Host "Checksum: $checksumPath"
Write-Host "Release body: $releaseBodyPath"
Write-Host "SHA256: $hash"
