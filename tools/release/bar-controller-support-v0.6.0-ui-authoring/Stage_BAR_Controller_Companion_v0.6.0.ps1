[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path,
    [string]$PackageRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path 'package'),
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageRootFull = [IO.Path]::GetFullPath($PackageRoot)
$targetName = 'BAR_Controller_Support_v0.6.0_Widget_Companion'
$target = [IO.Path]::GetFullPath((Join-Path $packageRootFull $targetName))
$zipPath = Join-Path $packageRootFull ($targetName + '.zip')
$checksumPath = $zipPath + '.sha256'
$releaseBodyPath = Join-Path $packageRootFull 'BAR_Controller_Support_v0.6.0.release.md'
$buildRoot = [IO.Path]::GetFullPath((Join-Path $packageRootFull '_build-v0.6.0'))
$packagePrefix = $packageRootFull.TrimEnd('\') + '\'
foreach ($candidate in @($target, $buildRoot)) {
    if (-not $candidate.StartsWith($packagePrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to stage outside the package directory: $candidate"
    }
}

function Invoke-Checked([string]$FilePath, [string[]]$Arguments, [string]$Label) {
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE." }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

New-Item -ItemType Directory -Force -Path $packageRootFull | Out-Null
foreach ($candidate in @($target, $buildRoot)) {
    if (Test-Path -LiteralPath $candidate) { Remove-Item -LiteralPath $candidate -Recurse -Force }
}
foreach ($artifact in @($zipPath, $checksumPath, $releaseBodyPath)) {
    if (Test-Path -LiteralPath $artifact) { Remove-Item -LiteralPath $artifact -Force }
}

$outputs = [ordered]@{
    bridge = Join-Path $buildRoot 'bridge'
    launcher = Join-Path $buildRoot 'launcher'
    installer = Join-Path $buildRoot 'installer'
    restore = Join-Path $buildRoot 'restore'
}
if (-not $SkipBuild) {
    $projects = [ordered]@{
        bridge = 'tools\controller-companion\BarControllerCompanion.csproj'
        launcher = 'tools\controller-companion\Launcher\BARControllerLauncher.csproj'
        installer = 'tools\controller-companion\Installer\BARControllerCompanionInstaller.csproj'
        restore = 'tools\controller-companion\Restore\BARControllerCompanionRestore.csproj'
    }
    foreach ($name in $projects.Keys) {
        Invoke-Checked 'dotnet' @('publish', (Join-Path $WorkspaceRoot $projects[$name]), '-c', 'Release', '-r', 'win-x64',
            '--self-contained', 'true', '-o', $outputs[$name]) ("Publish " + $name)
    }
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
    (Join-Path $outputs.installer 'BAR_Controller_Companion_Installer_v0.6.0.exe') = (Join-Path $target 'BAR_Controller_Companion_Installer_v0.6.0.exe')
    (Join-Path $outputs.restore 'BAR_Controller_Companion_Restore_v0.6.0.exe') = (Join-Path $target 'BAR_Controller_Companion_Restore_v0.6.0.exe')
    (Join-Path $outputs.bridge 'BARControllerBridge.exe') = (Join-Path $target 'companion\BARControllerBridge.exe')
    (Join-Path $outputs.launcher 'BARControllerLauncher.exe') = (Join-Path $target 'companion\BARControllerLauncher.exe')
    (Join-Path $PSScriptRoot 'manifest.json') = (Join-Path $target 'manifest.json')
    (Join-Path $WorkspaceRoot 'LICENSE.md') = (Join-Path $target 'LICENSE.md')
    (Join-Path $WorkspaceRoot 'controller-ui\shipping-defaults.json') = (Join-Path $target 'controller-ui\shipping-defaults.json')
    (Join-Path $WorkspaceRoot 'controller-ui\shipping-defaults-manifest.json') = (Join-Path $target 'controller-ui\shipping-defaults-manifest.json')
    (Join-Path $WorkspaceRoot 'luaui\Images\controller-glyphs\controller_glyph_atlas.png') = (Join-Path $target 'luaui\Images\controller-glyphs\controller_glyph_atlas.png')
    (Join-Path $WorkspaceRoot 'luaui\Images\controller-glyphs\asset-manifest.json') = (Join-Path $target 'luaui\Images\controller-glyphs\asset-manifest.json')
    (Join-Path $WorkspaceRoot 'luaui\Images\controller-glyphs\LICENSE.md') = (Join-Path $target 'luaui\Images\controller-glyphs\LICENSE.md')
    (Join-Path $WorkspaceRoot 'doc\controller-companion-v0.6.0\README.md') = (Join-Path $target 'docs\README.md')
    (Join-Path $WorkspaceRoot 'doc\controller-companion-v0.6.0\RELEASE_NOTES_v0.6.0.md') = (Join-Path $target 'docs\RELEASE_NOTES_v0.6.0.md')
    (Join-Path $WorkspaceRoot 'doc\controller-companion-v0.6.0\PACKAGE_INVENTORY_v0.6.0.md') = (Join-Path $target 'docs\PACKAGE_INVENTORY_v0.6.0.md')
    (Join-Path $WorkspaceRoot 'doc\controller-companion-v0.6.0\EDITOR_PROPERTY_WIRING_AUDIT.md') = (Join-Path $target 'docs\EDITOR_PROPERTY_WIRING_AUDIT.md')
    (Join-Path $WorkspaceRoot 'doc\controller-companion-v0.6.0\RESTORE_OLD_UI_STYLE.md') = (Join-Path $target 'docs\RESTORE_OLD_UI_STYLE.md')
}
foreach ($name in @('controller_socket_bridge.lua', 'gui_controller_camera_test.lua', 'gui_pregameui.lua', 'cmd_area_mex.lua',
    'gui_controller_bindings_ui.lua', 'gui_controller_smartx_mouse_audit.lua', 'gui_controller_ui_layout.lua')) {
    $copies[(Join-Path $WorkspaceRoot ('luaui\Widgets\' + $name))] = Join-Path $target ('luaui\Widgets\' + $name)
}
foreach ($name in @('controller_ui_editor_workspace.lua', 'controller_ui_editor_input.lua', 'controller_ui_shared_renderers.lua', 'controller_glyphs.lua')) {
    $copies[(Join-Path $WorkspaceRoot ('luaui\Include\' + $name))] = Join-Path $target ('luaui\Include\' + $name)
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
    version = '0.6.0'
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
        $entry = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $relative, [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = $fixedTime
    }
}
finally { $archive.Dispose() }

$hash = Get-Sha256 $zipPath
[IO.File]::WriteAllText($checksumPath, "$hash  $([IO.Path]::GetFileName($zipPath))`r`n", [Text.Encoding]::ASCII)
$releaseTemplate = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'controller-support-v0.6.0-ui-authoring.release.md'))
[IO.File]::WriteAllText($releaseBodyPath, $releaseTemplate.Replace('__FINAL_ZIP_SHA256__', $hash), (New-Object Text.UTF8Encoding($false)))

if (Test-Path -LiteralPath $buildRoot) { Remove-Item -LiteralPath $buildRoot -Recurse -Force }
Write-Host "Staged: $target"
Write-Host "ZIP: $zipPath"
Write-Host "Checksum: $checksumPath"
Write-Host "Release body: $releaseBodyPath"
Write-Host "SHA256: $hash"
